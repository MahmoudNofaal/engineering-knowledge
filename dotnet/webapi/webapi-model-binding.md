# ASP.NET Core Web API Model Binding

> Model binding is how ASP.NET Core automatically extracts values from an HTTP request — URL segments, query strings, headers, and the body — and maps them to your action method parameters.

---

## When To Use It

You're always using it. It matters most when you're debugging a parameter that's always null or default, designing a request contract, or dealing with complex binding scenarios like file uploads, custom types, or arrays in query strings. Understanding it helps you write explicit `[From*]` attributes instead of relying on inference that can silently bind the wrong source. You shouldn't need to read `HttpContext.Request` directly in most cases — if you're doing that, model binding probably covers what you need.

---

## Core Concept

When a request arrives and routing picks an action, the framework looks at each action parameter and asks: where should this value come from? The answer depends on the parameter's type and any `[From*]` attributes. Simple types (`int`, `string`, `Guid`) default to route values first, then query string. Complex types (classes, records) default to the request body, read once as JSON. `[ApiController]` makes `[FromBody]` implicit on complex parameters, but it's always cleaner to be explicit. Once the raw string is extracted from the right source, the framework tries to convert it to the parameter's type using type converters. If conversion fails or a required value is missing, model state is marked invalid and — with `[ApiController]` — a 400 is returned before your action runs.

---

## The Code
```csharp
// --- Explicit binding sources: always prefer explicit over inferred ---
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
```csharp
// --- Request DTO with data annotations (validation runs automatically with [ApiController]) ---
public record CreateOrderRequest
{
    [Required]
    public string CustomerId { get; init; } = "";

    [Range(1, 1000)]
    public int Quantity { get; init; }

    [StringLength(500)]
    public string? Notes { get; init; }
}

// If CustomerId is missing or Quantity is 0, the framework returns:
// HTTP 400
// { "errors": { "CustomerId": ["The CustomerId field is required."] } }
// ...before the action method is called.
```
```csharp
// --- Binding arrays and collections from query string ---
// GET /api/orders?status=pending&status=processing
[HttpGet]
public IActionResult GetByStatus([FromQuery] List<string> status)
{
    return Ok(status);   // ["pending", "processing"]
}

// GET /api/orders?ids=1&ids=2&ids=3
[HttpGet("batch")]
public IActionResult GetBatch([FromQuery] int[] ids)
{
    return Ok(ids);
}
```
```csharp
// --- [FromForm] for multipart form data and file uploads ---
[HttpPost("upload")]
public async Task<IActionResult> Upload(
    [FromForm] string description,
    IFormFile file)                             // IFormFile is automatically bound from multipart
{
    using var stream = file.OpenReadStream();
    // process stream...
    return Ok(new { file.FileName, file.Length, description });
}
```
```csharp
// --- Custom model binder: parse a comma-separated query param into a list ---
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

// Usage:
[HttpGet("filter")]
public IActionResult Filter(
    [ModelBinder(typeof(CommaSeparatedBinder))] List<int> ids)  // ?ids=1,2,3
{
    return Ok(ids);
}
```
```csharp
// --- Checking ModelState manually (when [ApiController] auto-400 is disabled) ---
[HttpPost]
public IActionResult Create([FromBody] CreateOrderRequest req)
{
    if (!ModelState.IsValid)
    {
        return ValidationProblem(ModelState);   // produces the same ProblemDetails shape
    }
    return Ok();
}
```

---

## Gotchas

- **The request body is a forward-only stream — it can only be read once.** If middleware, a filter, or an action reads `Request.Body` before model binding runs, the binding gets an empty stream and your `[FromBody]` parameter is null or default with no error. To read the body multiple times you must call `Request.EnableBuffering()` early in the pipeline and reset `Request.Body.Position = 0` after the first read.
- **`[FromQuery]` array binding is not comma-separated by default.** `?ids=1,2,3` does not bind to `List<int> ids` — ASP.NET Core expects repeated keys: `?ids=1&ids=2&ids=3`. Passing a single comma-separated string is a common client-side mistake that results in a binding failure or a list with one unparseable element. If you need comma-separated, write a custom model binder or parse it manually from `[FromQuery] string ids`.
- **Nullable value types and missing query parameters behave differently than you expect.** If a query parameter is absent, `[FromQuery] int? page` gives you `null` (correct). But `[FromQuery] int page` gives you `0` — the default — not a binding error. If `0` is a valid value in your domain but "not provided" has different semantics, use nullable types and check for null explicitly.
- **`[FromBody]` silently returns `null` for reference types when `[ApiController]` is not present.** Without `[ApiController]`, a missing or malformed JSON body does not produce a 400. The parameter is just null and your action runs with null input. `[ApiController]` fixes this by turning model state errors into automatic 400 responses — but only if you have data annotations on the DTO. A plain class with no annotations will bind to a default instance, not null, even for an empty body.
- **`[FromServices]` lets you inject a service directly into an action parameter — but it's invisible to callers and OpenAPI.** It's occasionally useful to inject a scoped service into a single action without adding it to the constructor, but Swashbuckle/OpenAPI doesn't know to exclude it and may generate a confusing parameter in the API schema. Always mark it `[FromServices]` explicitly and verify your generated spec.

---

## Interview Angle

**What they're really testing:** Whether you understand the HTTP request structure well enough to know where data lives and how the framework extracts it — and whether you can debug binding failures without guessing.

**Common question form:** "Why is my `[FromBody]` parameter always null?" or "How would you accept an array from a query string?" or "What happens when model validation fails?"

**The depth signal:** A junior knows that `[FromBody]` reads JSON and `[FromQuery]` reads query strings. A senior can explain the binding *order of precedence* for parameters without explicit attributes (route values → query string → body), knows that the body stream is consumed once and must be buffered to re-read, understands why `[ApiController]`'s automatic 400 fires before the action via `ModelStateInvalidFilter` (an action filter, not middleware), and can implement a custom `IModelBinder` with `IModelBinderProvider` to handle non-standard input formats — and knows to register it via `MvcOptions.ModelBinderProviders.Insert(0, ...)` so it takes precedence over built-in binders.

---

## Related Topics

- [[dotnet/webapi-controllers.md]] — `[FromBody]`, `[FromQuery]`, and `[FromRoute]` are applied to controller action parameters; binding is how those parameters get populated
- [[dotnet/webapi-routing.md]] — routing runs before binding; route parameters extracted during matching are what `[FromRoute]` binds from
- [[dotnet/webapi-validation.md]] — model binding and validation are coupled: binding populates `ModelState`, validation checks it, and `[ApiController]` auto-returns 400 on failure
- [[dotnet/webapi-filters.md]] — `ModelStateInvalidFilter` is an action filter; understanding the filter pipeline explains exactly when the automatic 400 fires relative to your action code

---

## Source

[https://learn.microsoft.com/en-us/aspnet/core/mvc/models/model-binding](https://learn.microsoft.com/en-us/aspnet/core/mvc/models/model-binding)

---
*Last updated: 2026-03-24*