# ASP.NET Core Web API File Upload & Download

> The mechanisms for receiving binary file data from clients (multipart form upload, raw body streaming) and serving files back as HTTP responses with correct content types and headers.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Request/response handling for binary file data in HTTP APIs |
| **Use when** | Any endpoint that accepts or serves files — documents, images, CSVs, exports |
| **Avoid when** | Very large files (>100 MB) without streaming — buffering them exhausts memory |
| **Introduced** | ASP.NET Core 1.0 (`IFormFile`); streaming improvements .NET 6+ |
| **Namespace** | `Microsoft.AspNetCore.Http`, `Microsoft.AspNetCore.Mvc` |
| **Key types** | `IFormFile`, `IFormFileCollection`, `FileResult`, `PhysicalFileResult`, `FileStreamResult` |

---

## When To Use It

Any time your API needs to accept files from clients (profile photos, document uploads, CSV imports) or return files to clients (PDF reports, image thumbnails, data exports). The key decisions are: buffer vs stream (small files can be buffered; large files must be streamed), where to store uploaded files (local disk, blob storage, database), and how to serve downloads (directly from disk, streamed from blob storage, or generated on the fly).

---

## Core Concept

**Upload:** The browser or API client sends a `multipart/form-data` request. ASP.NET Core buffers the parts into `IFormFile` objects — you access the file stream, metadata (name, size, content type), and can copy it to any destination. For large files, buffering to memory is dangerous — use streaming with `EnableBuffering()` or read the raw request body directly. **Download:** The server returns a `FileResult` subtype — `PhysicalFileResult` for files on disk, `FileStreamResult` for streams, or `FileContentResult` for in-memory byte arrays. The `Content-Disposition` header controls whether the browser displays the file inline or triggers a download dialog.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | `IFormFile`, `FileResult`, `PhysicalFileResult`, `FileStreamResult` |
| ASP.NET Core 2.0 | `FormOptions` — configurable buffer size, file size limits |
| ASP.NET Core 3.0 | `[RequestSizeLimit]`, `[RequestFormLimits]` attributes |
| .NET 6 | `IFormFile` improvements; minimal API form binding |
| .NET 8 | `[FromForm]` on minimal APIs; `DisableAntiforgery()` for multipart endpoints |

*Before `[RequestFormLimits]` (ASP.NET Core 3.0), file size limits required Kestrel-level configuration only. The attribute makes per-endpoint limit configuration straightforward.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `IFormFile` (buffered, <64KB) | O(n) | Buffered to memory; fast for small files |
| `IFormFile` (buffered, >64KB) | O(n) | Buffered to temp disk file; slower than memory |
| Streaming upload (no buffer) | O(1) memory | Reads directly from network; constant memory usage |
| `PhysicalFileResult` | O(1) | OS-level sendfile; efficient direct disk read |
| `FileStreamResult` | O(n) | Copies stream to response; allocates buffer |

**Allocation behaviour:** `IFormFile` for files under 64 KB uses `MemoryStream` — all bytes in heap. Above 64 KB, ASP.NET Core buffers to a temp file on disk. For large file uploads (>10 MB), skip `IFormFile` entirely and stream the raw request body to avoid memory pressure. `PhysicalFileResult` uses kernel-level `sendfile` syscall on Linux — zero copy, no heap allocation for the file data.

**Benchmark notes:** For downloads, `PhysicalFileResult` is the fastest option (kernel sendfile). For uploads, streaming to Azure Blob Storage directly from the request body is the right approach for files over a few MB — buffering a 500 MB upload to memory or disk before sending to blob storage doubles memory/disk usage unnecessarily.

---

## The Code

**Simple single-file upload**
```csharp
[HttpPost("upload")]
[RequestSizeLimit(10 * 1024 * 1024)]          // 10 MB limit for this endpoint
[RequestFormLimits(MultipartBodyLengthLimit = 10 * 1024 * 1024)]
public async Task<IActionResult> Upload(IFormFile file)
{
    if (file.Length == 0)
        return BadRequest(new ProblemDetails { Title = "File is empty." });

    if (!IsAllowedContentType(file.ContentType))
        return BadRequest(new ProblemDetails { Title = "File type not allowed." });

    var fileName  = Path.GetRandomFileName() + Path.GetExtension(file.FileName);
    var savePath  = Path.Combine(_options.UploadPath, fileName);

    await using var stream = File.Create(savePath);
    await file.CopyToAsync(stream);

    return Ok(new { fileName, size = file.Length });
}

private static bool IsAllowedContentType(string contentType) =>
    contentType is "image/jpeg" or "image/png" or "application/pdf";
```

**Multiple files upload**
```csharp
[HttpPost("upload/batch")]
public async Task<IActionResult> UploadMultiple(IFormFileCollection files)
{
    if (files.Count == 0)
        return BadRequest(new ProblemDetails { Title = "No files provided." });

    var results = new List<object>();
    foreach (var file in files)
    {
        var fileName = Guid.NewGuid() + Path.GetExtension(file.FileName);
        await using var stream = File.Create(Path.Combine(_options.UploadPath, fileName));
        await file.CopyToAsync(stream);
        results.Add(new { originalName = file.FileName, savedAs = fileName, size = file.Length });
    }

    return Ok(results);
}
```

**File upload with metadata in the same request**
```csharp
// Client sends: Content-Type: multipart/form-data
// Parts: "description" (text) + "file" (binary)
public record UploadWithMetadata
{
    [Required, MaxLength(500)]
    public string Description { get; init; } = "";

    [Required]
    public string Category { get; init; } = "";
}

[HttpPost("documents")]
public async Task<IActionResult> UploadDocument(
    [FromForm] UploadWithMetadata metadata,
    IFormFile file)
{
    // metadata and file bound from separate multipart parts
    var doc = await _storage.SaveAsync(file, metadata);
    return CreatedAtAction(nameof(GetDocument), new { id = doc.Id }, doc);
}
```

**Streaming large file upload directly to blob storage (no buffering)**
```csharp
[HttpPost("upload/large")]
[DisableRequestSizeLimit]                      // remove the 30MB Kestrel default
[RequestFormLimits(MultipartBodyLengthLimit = long.MaxValue)]
public async Task<IActionResult> UploadLarge()
{
    if (!Request.HasFormContentType)
        return BadRequest(new ProblemDetails { Title = "Expected multipart/form-data." });

    var boundary = MultipartRequestHelper.GetBoundary(
        MediaTypeHeaderValue.Parse(Request.ContentType), lengthLimit: 70);

    var reader = new MultipartReader(boundary, Request.Body);
    MultipartSection? section;

    while ((section = await reader.ReadNextSectionAsync()) != null)
    {
        var contentDisposition = ContentDispositionHeaderValue.Parse(section.ContentDisposition);
        if (!contentDisposition.IsFileDisposition()) continue;

        var fileName  = contentDisposition.FileName.Value ?? "upload";
        var blobName  = Guid.NewGuid() + Path.GetExtension(fileName);

        // Stream directly from the HTTP request to Azure Blob Storage
        // Memory usage: constant (buffer-sized chunks), not file-sized
        await _blobStorage.UploadAsync(blobName, section.Body);

        return Ok(new { blobName, originalName = fileName });
    }

    return BadRequest(new ProblemDetails { Title = "No file found in request." });
}
```

**File download — from disk**
```csharp
[HttpGet("documents/{id:guid}/download")]
[Authorize]
public async Task<IActionResult> Download(Guid id)
{
    var doc = await _documents.GetAsync(id);
    if (doc is null) return NotFound();

    var filePath = Path.Combine(_options.StoragePath, doc.StoredFileName);
    if (!System.IO.File.Exists(filePath)) return NotFound();

    // PhysicalFileResult uses kernel sendfile — most efficient for disk files
    return PhysicalFile(filePath, doc.ContentType,
        fileDownloadName: doc.OriginalFileName);   // triggers browser download dialog
}
```

**File download — generated on the fly (CSV export)**
```csharp
[HttpGet("orders/export")]
[Authorize]
public async Task<IActionResult> ExportOrders([FromQuery] DateOnly from, [FromQuery] DateOnly to)
{
    var orders = await _orders.GetForExportAsync(from, to);

    // Use a MemoryStream for small exports; for large exports, stream directly
    var stream = new MemoryStream();
    await using var writer = new StreamWriter(stream, leaveOpen: true);

    await writer.WriteLineAsync("OrderId,CustomerId,Total,Status,CreatedAt");
    foreach (var order in orders)
        await writer.WriteLineAsync(
            $"{order.Id},{order.CustomerId},{order.Total:F2},{order.Status},{order.CreatedAt:O}");

    await writer.FlushAsync();
    stream.Position = 0;

    var fileName = $"orders_{from:yyyyMMdd}_{to:yyyyMMdd}.csv";
    return File(stream, "text/csv", fileName);   // FileStreamResult
}
```

**File download — from blob storage with streaming**
```csharp
[HttpGet("documents/{id:guid}/stream")]
public async Task<IActionResult> StreamFromBlob(Guid id)
{
    var doc  = await _documents.GetAsync(id);
    if (doc is null) return NotFound();

    // Get a stream from blob storage — data flows from blob to client
    // without loading the entire file into memory
    var blobStream = await _blobStorage.OpenReadAsync(doc.BlobName);

    // FileStreamResult will dispose the stream after sending
    return new FileStreamResult(blobStream, doc.ContentType)
    {
        FileDownloadName  = doc.OriginalFileName,
        EnableRangeProcessing = true            // supports HTTP Range requests (resume, seeking)
    };
}
```

**Minimal API file upload (.NET 8)**
```csharp
app.MapPost("/api/documents", async (
    [FromForm] string description,
    IFormFile file,
    IStorageService storage) =>
{
    var result = await storage.SaveAsync(file, description);
    return Results.Created($"/api/documents/{result.Id}", result);
})
.DisableAntiforgery()                           // required for multipart in minimal APIs
.WithName("UploadDocument")
.Accepts<IFormFile>("multipart/form-data");
```

---

## Real World Example

A document management system accepts PDF uploads up to 50 MB, validates file type by magic bytes (not just extension), stores metadata in a database and the binary in Azure Blob Storage, and serves downloads with proper `Content-Disposition` and range support for in-browser PDF viewing.

```csharp
public class DocumentUploadService(
    BlobServiceClient blob,
    AppDbContext db,
    ILogger<DocumentUploadService> logger)
{
    private static readonly byte[] PdfMagicBytes = { 0x25, 0x50, 0x44, 0x46 }; // %PDF

    public async Task<Document> UploadAsync(
        IFormFile file, string description, string userId, CancellationToken ct)
    {
        // Validate by magic bytes — not just ContentType or extension
        await using var fileStream = file.OpenReadStream();
        var header = new byte[4];
        await fileStream.ReadExactlyAsync(header, ct);
        fileStream.Position = 0;

        if (!header.SequenceEqual(PdfMagicBytes))
            throw new ValidationException("File must be a PDF.");

        var blobName = $"{userId}/{Guid.NewGuid()}.pdf";
        var container = blob.GetBlobContainerClient("documents");

        // Stream directly from HTTP request to blob — no temp file on disk
        await container.UploadBlobAsync(blobName, fileStream, ct);
        logger.LogInformation("Blob uploaded: {BlobName} ({Size} bytes)", blobName, file.Length);

        var doc = new Document
        {
            Id           = Guid.NewGuid(),
            OwnerId      = userId,
            OriginalName = file.FileName,
            BlobName     = blobName,
            ContentType  = "application/pdf",
            SizeBytes    = file.Length,
            Description  = description,
            UploadedAt   = DateTimeOffset.UtcNow
        };

        db.Documents.Add(doc);
        await db.SaveChangesAsync(ct);
        return doc;
    }
}

[ApiController]
[Route("api/documents")]
[Authorize]
public class DocumentsController(DocumentUploadService uploader, AppDbContext db, BlobServiceClient blob)
    : ControllerBase
{
    [HttpPost]
    [RequestSizeLimit(50 * 1024 * 1024)]        // 50 MB
    [RequestFormLimits(MultipartBodyLengthLimit = 50 * 1024 * 1024)]
    public async Task<IActionResult> Upload(
        IFormFile file,
        [FromForm] string description,
        CancellationToken ct)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        var doc    = await uploader.UploadAsync(file, description, userId, ct);
        return CreatedAtAction(nameof(Download), new { id = doc.Id }, new
        {
            doc.Id, doc.OriginalName, doc.SizeBytes, doc.UploadedAt
        });
    }

    [HttpGet("{id:guid}/download")]
    public async Task<IActionResult> Download(Guid id, CancellationToken ct)
    {
        var doc = await db.Documents.FindAsync([id], ct);
        if (doc is null || doc.OwnerId != User.FindFirstValue(ClaimTypes.NameIdentifier))
            return NotFound();

        var container = blob.GetBlobContainerClient("documents");
        var blobClient = container.GetBlobClient(doc.BlobName);

        var download = await blobClient.DownloadStreamingAsync(cancellationToken: ct);

        return new FileStreamResult(download.Value.Content, doc.ContentType)
        {
            FileDownloadName      = doc.OriginalName,
            EnableRangeProcessing = true    // allows in-browser PDF viewing with seek
        };
    }
}
```

*The key insight: validating file type by magic bytes instead of extension or `ContentType` is critical — a malicious client can send `Content-Type: application/pdf` for any file. The stream goes directly from the HTTP request to blob storage without touching disk or loading the entire file into memory, keeping memory usage constant regardless of file size.*

---

## Common Misconceptions

**"Checking `file.ContentType == "application/pdf"` validates the file type."**
`ContentType` is set by the client and can be anything — including a lie. A malicious user can upload a `.exe` with `Content-Type: application/pdf`. Always validate by reading the file's magic bytes (first 4–16 bytes) which are set by the file format itself, not the client.

**"`IFormFile` is fine for large file uploads."**
For files under a few MB, `IFormFile` is convenient. For files over 10–20 MB, buffering to memory or temp disk before processing adds latency and memory pressure. Stream large files directly from the request body to the destination (blob storage, S3) using `MultipartReader` to keep memory usage constant.

**"I should set `DisableRequestSizeLimit` to accept any file size."**
Removing size limits entirely exposes the API to denial-of-service attacks via gigabyte uploads that exhaust disk or memory. Set explicit per-endpoint limits with `[RequestSizeLimit]` that reflect your actual business requirements. Use `[DisableRequestSizeLimit]` only on endpoints you've designed specifically to handle large files with streaming.

---

## Gotchas

- **`[DisableAntiforgery]` is required for multipart endpoints in minimal APIs (.NET 8).** Without it, form POST requests return 400. Controller-based endpoints don't have this requirement.

- **`IFormFile.OpenReadStream()` can only be read once and only during the request.** The stream is backed by the buffered temp file or memory buffer, both of which are disposed after the request completes. Copy the stream to your destination storage before the action returns.

- **`PhysicalFileResult` with a path outside `wwwroot` requires explicit configuration.** By default, `PhysicalFile()` doesn't restrict paths — a path traversal bug in your filename handling can serve arbitrary files. Always sanitise the file path with `Path.GetFullPath` and verify it starts within your expected storage directory.

- **File download without `fileDownloadName` displays the file inline (if the browser supports the content type).** PDF, images, and HTML display inline in the browser. Set `fileDownloadName` (which sets `Content-Disposition: attachment; filename=...`) to force a download dialog.

- **`EnableRangeProcessing = true` on `FileStreamResult` enables HTTP `Range` requests.** This is required for in-browser media players and PDF viewers that seek within the file. Without it, the entire file must be downloaded before it can be displayed.

- **Concurrent large file uploads can exhaust the Kestrel connection pool.** Each in-flight upload holds a connection and a thread (or at least an `async` continuation). Rate limit file upload endpoints with a concurrency limiter to protect the server from being saturated by simultaneous large uploads.

---

## Interview Angle

**What they're really testing:** Whether you understand the memory implications of buffered vs streaming file handling, how to validate file types securely, and how to serve files efficiently.

**Common question forms:**
- "How do you handle file uploads in ASP.NET Core?"
- "How would you upload a 500 MB file without running out of memory?"
- "How do you validate that an uploaded file is actually a PDF and not a renamed executable?"
- "What's the difference between `PhysicalFileResult` and `FileStreamResult`?"

**The depth signal:** A junior knows `IFormFile` and `file.CopyToAsync`. A senior explains that `IFormFile` buffers to memory/disk and is inappropriate for large files, knows to use `MultipartReader` for streaming directly to blob storage, validates file type by magic bytes instead of `ContentType` or extension, understands that `PhysicalFileResult` uses kernel `sendfile` for maximum download efficiency, and knows `EnableRangeProcessing = true` is required for seekable media (PDF viewers, video players).

**Follow-up questions to expect:**
- "How would you implement resumable file uploads?"
- "How do you prevent path traversal attacks in file download endpoints?"
- "How would you generate a pre-signed URL for direct client-to-blob-storage upload?"

---

## Related Topics

- [[dotnet/webapi/webapi-model-binding.md]] — `IFormFile` binding is a special case of model binding; understanding how multipart form data is parsed explains why `[FromForm]` and `IFormFile` can coexist on the same action
- [[dotnet/webapi/webapi-model-validation.md]] — file upload endpoints need explicit validation (size, type, count) since `[ApiController]` automatic validation doesn't cover `IFormFile` properties
- [[dotnet/webapi/webapi-rate-limiting.md]] — large file upload endpoints should have concurrency limits to prevent server saturation from simultaneous uploads
- [[dotnet/webapi/webapi-minimal-apis.md]] — minimal API file uploads require `.DisableAntiforgery()` — a gotcha unique to minimal APIs vs controllers

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/models/file-uploads

---
*Last updated: 2026-04-10*