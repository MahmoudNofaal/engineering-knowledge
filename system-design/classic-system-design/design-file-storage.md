# File Storage

> A system that allows users to upload, store, retrieve, and share files reliably at any scale.

---

## When To Use It

Build a dedicated file storage system when your application needs to handle binary files (images, documents, videos) that don't belong in a relational DB. Use managed object storage (S3, GCS) whenever possible — only design the underlying system in interviews or if you're building cloud infrastructure. The interesting design problems are: how to handle large file uploads without blocking your API server, how to deduplicate files, and how to distribute reads globally.

---

## Core Concept

Files are not stored in your application DB — they're stored in an object store (or distributed blob store). Your DB stores metadata only: filename, size, owner, storage key, content hash. For uploads, never stream the file through your API server — generate a pre-signed URL and let the client upload directly to the object store. This keeps your API servers stateless and your upload throughput unlimited by your server count. For large files, use chunked/multipart upload: split the file into parts, upload each part in parallel, then tell the object store to assemble them. The content-addressable storage pattern (key = hash of content) gives you free deduplication.

---

## The Code

```csharp
// Generate pre-signed upload URL — client uploads directly to S3
using Amazon.S3;
using Amazon.S3.Model;
using System;
using System.Threading.Tasks;

public class S3UploadService
{
    private readonly IAmazonS3 _s3Client;
    private const string Bucket = "my-file-storage";

    public async Task<(string uploadUrl, string storageKey)> CreateUploadUrlAsync(
        int userId,
        string filename,
        string contentType)
    {
        // Returns a pre-signed URL the client uses to upload directly to S3.
        // Our server never touches the file bytes.
        
        string storageKey = $"uploads/{userId}/{Guid.NewGuid()}/{filename}";

        var request = new GetPreSignedUrlRequest
        {
            BucketName = Bucket,
            Key = storageKey,
            ContentType = contentType,
            Verb = HttpVerb.PUT,
            Expires = DateTime.UtcNow.AddHours(1)
        };

        string presignedUrl = _s3Client.GetPreSignedURL(request);

        return (presignedUrl, storageKey);
    }

    public async Task ConfirmUploadAsync(
        int userId,
        string storageKey,
        string filename,
        long sizeBytes,
        IFileRepository db)
    {
        // Called by client after upload succeeds — store metadata in DB
        await db.InsertFileAsync(userId, storageKey, filename, sizeBytes);
    }
}
```

```csharp
// Content-addressable storage for deduplication
using Amazon.S3;
using Amazon.S3.Model;
using System;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

public class DedupUploadService
{
    private readonly IAmazonS3 _s3Client;
    private const string Bucket = "my-file-storage";

    public async Task<(int fileId, string storageKey)> UploadWithDedupAsync(
        byte[] fileBytes,
        int userId,
        string filename,
        IFileRepository db)
    {
        // Use SHA-256 of content as storage key.
        // If two users upload identical files, only one copy is stored.
        
        using (var sha256 = SHA256.Create())
        {
            byte[] hash = sha256.ComputeHash(fileBytes);
            string contentHash = BitConverter.ToString(hash).Replace("-", "").ToLower();
            string storageKey = $"content/{contentHash}";

            // Check if this exact file already exists
            var existing = await db.GetFileByHashAsync(contentHash);

            if (existing == null)
            {
                // New unique file — upload to object store
                await _s3Client.PutObjectAsync(new PutObjectRequest
                {
                    BucketName = Bucket,
                    Key = storageKey,
                    InputStream = new System.IO.MemoryStream(fileBytes)
                });
            }

            // Always create a new metadata record for this user's file
            int fileId = await db.InsertFileAsync(userId, storageKey, filename, contentHash);
            return (fileId, storageKey);
        }
    }
}
```

```csharp
// Multipart upload for large files (>100MB)
using Amazon.S3;
using Amazon.S3.Model;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

public class MultipartUploadService
{
    private readonly IAmazonS3 _s3Client;
    private const string Bucket = "my-file-storage";
    private const int ChunkSize = 5 * 1024 * 1024;  // 5MB minimum part size for S3

    public async Task MultipartUploadAsync(string filePath, string storageKey)
    {
        // Upload large file in parallel chunks
        var initResponse = await _s3Client.InitiateMultipartUploadAsync(
            new InitiateMultipartUploadRequest
            {
                BucketName = Bucket,
                Key = storageKey
            }
        );
        string uploadId = initResponse.UploadId;

        var parts = new List<PartETag>();
        using (var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read))
        {
            int partNumber = 1;
            byte[] buffer = new byte[ChunkSize];
            int bytesRead;

            while ((bytesRead = fileStream.Read(buffer, 0, ChunkSize)) > 0)
            {
                var uploadPartResponse = await _s3Client.UploadPartAsync(
                    new UploadPartRequest
                    {
                        BucketName = Bucket,
                        Key = storageKey,
                        UploadId = uploadId,
                        PartNumber = partNumber,
                        InputStream = new MemoryStream(buffer, 0, bytesRead)
                    }
                );
                parts.Add(new PartETag
                {
                    PartNumber = partNumber,
                    ETag = uploadPartResponse.ETag
                });
                partNumber++;
            }
        }

        // Assemble the parts
        await _s3Client.CompleteMultipartUploadAsync(
            new CompleteMultipartUploadRequest
            {
                BucketName = Bucket,
                Key = storageKey,
                UploadId = uploadId,
                PartETags = parts
            }
        );
    }
}
```

```sql
-- File metadata schema
CREATE TABLE files (
    id              BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id         BIGINT NOT NULL,
    storage_key     VARCHAR(512) NOT NULL,   -- S3 object key
    content_hash    CHAR(64),                -- SHA-256, for deduplication
    filename        VARCHAR(255) NOT NULL,
    size_bytes      BIGINT,
    content_type    VARCHAR(100),
    is_deleted      BOOLEAN DEFAULT FALSE,   -- Soft delete
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_content_hash (content_hash)   -- Enables dedup lookup
);
```

---

## Gotchas

- **Never stream files through your API server**: If you proxy uploads/downloads through your app server, your server's network bandwidth and memory become the bottleneck. Use pre-signed URLs to route traffic directly between client and object store.
- **Multipart upload orphans**: If a multipart upload starts but the client crashes, incomplete uploads sit in S3 indefinitely accruing storage costs. Set a lifecycle rule to abort incomplete multipart uploads after 24 hours.
- **Soft deletes vs hard deletes**: Deleting the DB record doesn't delete the object in S3. Use soft deletes (is_deleted flag) and run a background job to actually remove S3 objects. This also enables an "undo delete" feature.
- **Download URLs need to be signed or authenticated**: If your S3 bucket is public, anyone with the URL can download any file forever. Use pre-signed download URLs with short expiry (15 minutes), or serve through your CDN with token validation.
- **Content-type spoofing**: A user uploads a `.html` file disguised as an `.jpg`. Always validate and set `ContentType` explicitly on the S3 object based on actual content inspection (magic bytes), not the filename extension provided by the user.

---

## Interview Angle

**What they're really testing:** Understanding of object storage architecture, how to handle large binary data without bottlenecking API servers, and data deduplication.

**Common question form:** "Design a file storage system like Dropbox or Google Drive that supports file upload, download, sync, and sharing."

**The depth signal:** A junior answer describes an API endpoint that accepts a file in a multipart HTTP request and writes it to disk or DB. A senior answer explains pre-signed URLs and *why* they're used (server never touches bytes, unlimited upload throughput), describes chunked upload and why the 5MB minimum chunk size exists in S3, proposes content-addressable storage with SHA-256 for deduplication, discusses the delta sync problem for large frequently-updated files (rsync-style block-level diffing), and addresses download security via signed URLs with short TTLs.

---

## Related Topics

- [[system-design/design-video-streaming]] — Video streaming is file storage with additional transcoding, chunking, and CDN delivery requirements
- [[system-design/design-distributed-cache]] — File metadata (not content) benefits from caching; content goes to CDN
- [[system-design/design-rate-limiter]] — Upload endpoints need per-user rate limits to prevent storage abuse

---

## Source

[AWS S3 Developer Guide — Multipart Upload](https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html)

---

*Last updated: 2026-03-24*