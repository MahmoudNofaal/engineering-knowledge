# ASP.NET Core Web API Model Binding

> Model binding is how ASP.NET Core automatically extracts values from an HTTP request — URL segments, query strings, headers, and the body — and maps them to your action method parameters.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Automatic HTTP request → action parameter value extraction |
| **Use when** | Always — every action that receives input uses model binding |
| **Avoid when** | Never avoid — but use explicit `[From*]` attributes instead of relying on inference |
| **Introduced** | ASP.NET Core 1.0; `[FromServices]` added 1.1; `[AsParameters]` added .NET 7 |
| **Namespace** | `Microsoft.AspNetCore.Mvc`, `Microsoft.AspNetCore.Mvc.ModelBinding` |
| **Key types** | `IModelBinder`, `IModelBinderProvider`, `ModelBindingContext`, `BindingSource` |

---

## When To Use It

You're always using it. It matters most when you're debugging a parameter that's always null or default, designing a request contract, or dealing with complex binding scenarios like file uploads, custom types, or arrays in query strings. Understanding it helps you write explicit `[From*]` attributes instead of relying on inference that can silently bind the wrong source. You shouldn't need to read `HttpContext.Request` directly in most cases — if you're doing that, model binding probably covers what you need.

---

## Core Concept

When a request arrives and routing picks an action, the framework looks at each action parameter and asks: where should this value come from? The answer depends on the parameter's type and any `[From*]` attributes. Simple types (`int`, `string`, `Guid`) default to route values first, then query string. Complex types (classes, records) default to the request body, read once as JSON. `[ApiController]` makes `[FromBody]` implicit on complex parameters, but it's always cleaner to be explicit. Once the raw string is extracted from the right source, the framework tries to convert it to the parameter's type using type converters. If conversion fails or a required value is missing, model state is marked invalid and — with `[ApiController]` — a 400 is returned before your action runs.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | `[FromBody]`, `[FromQuery]`, `[FromRoute]`, `[FromHeader]`, `[FromForm]` introduced |
| ASP.NET Core 1.1 | `[FromServices]` added — inject DI service as action parameter |
| ASP.NET Core 2.1 | `[ApiController]` adds implicit `[FromBody]` inference on complex types |
| .NET 6 | `IFormFile` binding improved; minimal APIs parameter binding added |
| .NET 7 | `[AsParameters]` attribute — bind multiple parameters from a struct/record in minimal APIs |
| .NET 8 | `IParsable<T>` support — types implementing `IParsable<T>` bind from query strings automatically |

*Before `[ApiController]` (ASP.NET Core 2.1), complex type parameters defaulted to form binding, not body binding. Teams upgrading from Web API 2 (classic) were surprised to find their `[HttpPost]` actions ignoring the JSON body. `[FromBody]` had to be explicit everywhere.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Route value binding | O(1) | Already extracted during route matching |
| Query string binding | O(k) | k = number of query parameters |
| Body binding (JSON) | O(n) | n = body size; `System.Text.Json` is the default since .NET Core 3.0 |
| `IFormFile` binding | O(n) | Buffered to disk for large files; small files stay in memory |
| Custom `IModelBinder` | Varies | Depends on implementation |

**Allocation behaviour:** `System.Text.Json` deserialization allocates proportionally to the JSON payload size. For high-throughput APIs with large bodies, consider using `[FromBody]` with a `Stream` parameter and streaming deserialization. Route and query string values are pooled string slices — low allocation. `IFormFile` buffers to disk for files over 64 KB by default.

**Benchmark notes:** Model binding is not a bottleneck for typical payloads (<10 KB). For very large payloads or extremely high throughput, profile with `BenchmarkDotNet` — the binding pipeline compiles to delegates at startup so per-request overhead is minimal.

---

## The Code

**Explicit binding sources — always prefer explicit over inferred**
```csharp
[HttpGet("{id:int}")]
public IActionResult GetOrder(
    [FromRoute]  int id,                        // from /api/orders/42
    [FromQuery]  bool includeItems = false,     // from ?includeItems=true
    [FromHeader(Name = "X-Tenant-Id")] string? tenantId = null)  // from request header
{
    return Ok(new { id, includeItems, tenantId });
}

[HttpPost]
public IActionResult CreateOrder(
    [FromBody] CreateOrderRequest request)      // from JSON body
{
    return CreatedAtAction(nameof(GetOrder), new { id = 1 }, request);
}
```

**Request DTO with data annotations**
```csharp
// Validation runs automatically with [ApiController]
public record CreateOrderRequest
{
    [Required]
    public string CustomerId { get; init; } = "";

    [Range(1, 1000)]
    public int Quantity { get; init; }

    [StringLength(500)]
    public string? Notes { get; init; }
}
// If CustomerId is missing or Quantity is 0 → HTTP 400 before the action runs
```

**Binding arrays from query string**
```csharp
// GET /api/orders?status=pending&status=processing
[HttpGet]
public IActionResult GetByStatus([FromQuery] List<string> status) => Ok(status);

// GET /api/orders?ids=1&ids=2&ids=3
[HttpGet("batch")]
public IActionResult GetBatch([FromQuery] int[] ids) => Ok(ids);
```

**`[FromForm]` for multipart form data and file uploads**
```csharp
[HttpPost("upload")]
public async Task<IActionResult> Upload(
    [FromForm] string description,
    IFormFile file)
{
    using var stream = file.OpenReadStream();
    return Ok(new { file.FileName, file.Length, description });
}
```

**Custom model binder — comma-separated query param into a list**
```csharp
public class CommaSeparatedBinder : IModelBinder
{
    public Task BindModelAsync(ModelBindingContext context)
    {
        var value = context.ValueProvider.GetValue(context.ModelName).FirstValue;
        if (string.IsNullOrEmpty(value))
        {
            context.Result = ModelBindingResult.Success(new List<int>());
            return Task.CompletedTask;
        }

        var parsed = value
            .Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Select(s => int.TryParse(s.Trim(), out var n) ? (int?)n : null)
            .Where(n => n.HasValue)
            .Select(n => n!.Value)
            .ToList();

        context.Result = ModelBindingResult.Success(parsed);
        return Task.CompletedTask;
    }
}

[HttpGet("filter")]
public IActionResult Filter(
    [ModelBinder(typeof(CommaSeparatedBinder))] List<int> ids)  // ?ids=1,2,3
{
    return Ok(ids);
}
```

**`[AsParameters]` in minimal APIs (.NET 7+)**
```csharp
// Bundle query/route params into a record without [FromQuery] on each property
record OrderQuery(
    [property: FromQuery] int Page,
    [property: FromQuery] int PageSize,
    [property: FromQuery] string? Status);

app.MapGet("/api/orders", ([AsParameters] OrderQuery q) =>
    Results.Ok(q));
```

---

## Real World Example

A reporting API accepts a complex filter from the query string — date ranges, multi-value status arrays, and a comma-separated list of customer IDs. A custom model binder handles the comma-separated IDs; everything else uses standard binding.

```csharp
// The filter object — populated entirely from query string
public class ReportFilter
{
    [FromQuery(Name = "from")]
    public DateTime? From { get; set; }

    [FromQuery(Name = "to")]
    public DateTime? To { get; set; }

    [FromQuery(Name = "status")]
    public List<string> Statuses { get; set; } = new();

    // Bound via custom binder — accepts ?customerIds=101,102,103
    [ModelBinder(typeof(CommaSeparatedIntBinder))]
    public List<int> CustomerIds { get; set; } = new();
}

// Custom binder registered globally
public class CommaSeparatedIntBinder : IModelBinder
{
    public Task BindModelAsync(ModelBindingContext ctx)
    {
        var raw = ctx.ValueProvider.GetValue(ctx.ModelName).FirstValue;
        var result = raw?
            .Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Select(s => int.TryParse(s.Trim(), out var n) ? n : (int?)null)
            .Where(n => n.HasValue)
            .Select(n => n!.Value)
            .ToList() ?? new List<int>();

        ctx.Result = ModelBindingResult.Success(result);
        return Task.CompletedTask;
    }
}

// Register globally so [ModelBinder] attribute isn't needed on every property
builder.Services.AddControllers(opts =>
    opts.ModelBinderProviders.Insert(0, new CommaSeparatedIntBinderProvider()));

// Controller action — the entire filter binds from query string parameters
[HttpGet("reports")]
public async Task<IActionResult> GetReport([FromQuery] ReportFilter filter)
{
    var report = await _reportService.GenerateAsync(filter);
    return Ok(report);
}
// GET /api/reports?from=2026-01-01&to=2026-03-31&status=completed&status=pending&customerIds=101,102,103
```

*The key insight: by combining standard `[FromQuery]` binding for simple types and arrays with a custom binder for the comma-separated IDs, the entire complex filter is populated before the action runs — with no `HttpContext.Request.Query` reads inside the action. The controller stays clean.*

---

## Common Misconceptions

**"`[FromQuery]` handles comma-separated values automatically."**
It does not. `?ids=1,2,3` does not bind to `List<int> ids` — ASP.NET Core expects repeated keys: `?ids=1&ids=2&ids=3`. Passing a comma-separated string results in a binding failure or a list with one unparseable element. If you need comma-separated, write a custom model binder or parse it manually from `[FromQuery] string ids`.

**"Complex types always bind from the body."**
Without `[ApiController]`, complex types default to form binding, not body binding. With `[ApiController]`, the inference changes to `[FromBody]` for complex types on actions with body-supporting HTTP methods (POST, PUT, PATCH). Even with `[ApiController]`, be explicit — the inference rules are subtle enough that relying on them leads to bugs when you add parameters of mixed types.

**"Model binding and model validation are the same step."**
They're two sequential steps. Binding extracts and converts values from the request sources into `ModelState`. Validation then checks `ModelState` against data annotations and `IValidatableObject` rules. Binding failure (wrong type, unparseable value) and validation failure (value out of range) both produce 400 with `[ApiController]` — but they happen at different points and can be diagnosed differently in `ModelState.Errors`.

---

## Gotchas

- **The request body is a forward-only stream — it can only be read once.** If middleware, a filter, or an action reads `Request.Body` before model binding runs, the binding gets an empty stream and your `[FromBody]` parameter is null or default with no error. To read the body multiple times call `Request.EnableBuffering()` early in the pipeline and reset `Request.Body.Position = 0` after the first read.

- **`[FromQuery]` array binding is not comma-separated by default.** `?ids=1,2,3` does not bind to `List<int> ids` — ASP.NET Core expects repeated keys: `?ids=1&ids=2&ids=3`. If you need comma-separated, write a custom model binder or parse it manually.

- **Nullable value types and missing query parameters behave differently than you expect.** If a query parameter is absent, `[FromQuery] int? page` gives you `null`. But `[FromQuery] int page` gives you `0` — the default — not a binding error. If `0` is a valid value but "not provided" has different semantics, use nullable types and check for null explicitly.

- **`[FromBody]` silently returns default for reference types when `[ApiController]` is not present.** Without `[ApiController]`, a missing or malformed JSON body does not produce a 400. The parameter is just `null` and your action runs with null input. `[ApiController]` turns model state errors into automatic 400 responses — but only if you have data annotations on the DTO.

- **`[FromServices]` lets you inject a DI service as an action parameter — but it's invisible to OpenAPI.** Swashbuckle doesn't know to exclude it and may generate a confusing parameter in the API schema. Always mark it `[FromServices]` explicitly and verify your generated spec excludes it.

- **`IFormFile` and `[FromBody]` cannot be combined on the same action.** File uploads use multipart form data; JSON bodies use `application/json`. You cannot mix them. If you need file upload with metadata, use `[FromForm]` for both the file and the metadata fields.

---

## Interview Angle

**What they're really testing:** Whether you understand the HTTP request structure well enough to know where data lives and how the framework extracts it — and whether you can debug binding failures without guessing.

**Common question forms:**
- "Why is my `[FromBody]` parameter always null?"
- "How would you accept an array from a query string?"
- "What happens when model validation fails?"
- "How do you handle comma-separated query parameters?"

**The depth signal:** A junior knows that `[FromBody]` reads JSON and `[FromQuery]` reads query strings. A senior can explain the binding *order of precedence* for parameters without explicit attributes (route values → query string → body), knows that the body stream is consumed once and must be buffered to re-read, understands why `[ApiController]`'s automatic 400 fires before the action via `ModelStateInvalidFilter` (an action filter, not middleware), and can implement a custom `IModelBinder` with `IModelBinderProvider` — registered via `MvcOptions.ModelBinderProviders.Insert(0, ...)` so it takes precedence over built-in binders.

**Follow-up questions to expect:**
- "How would you write a custom model binder?"
- "What's the difference between model binding and model validation?"
- "How do you bind complex objects from the query string?"

---

## Related Topics

- [[dotnet/webapi/webapi-controllers.md]] — `[FromBody]`, `[FromQuery]`, and `[FromRoute]` are applied to controller action parameters; binding is how those parameters get populated
- [[dotnet/webapi/webapi-routing.md]] — routing runs before binding; route parameters extracted during matching are what `[FromRoute]` binds from
- [[dotnet/webapi/webapi-model-validation.md]] — model binding and validation are coupled: binding populates `ModelState`, validation checks it, and `[ApiController]` auto-returns 400 on failure
- [[dotnet/webapi/webapi-filters.md]] — `ModelStateInvalidFilter` is an action filter; understanding the filter pipeline explains exactly when the automatic 400 fires relative to your action code

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/models/model-binding

---
*Last updated: 2026-04-10*