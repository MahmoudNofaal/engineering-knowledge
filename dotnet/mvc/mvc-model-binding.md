# MVC Model Binding

> The ASP.NET Core process that automatically maps values from an HTTP request — route segments, query strings, form fields, headers, and JSON bodies — into the parameters and properties of controller action methods.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Automatic mapping from HTTP request data to action method parameters |
| **Use when** | Always — every controller action that receives data uses model binding |
| **Avoid when** | Reading raw request body manually (use `[FromBody]` instead) |
| **Namespace** | `Microsoft.AspNetCore.Mvc` |
| **Key attributes** | `[FromRoute]`, `[FromQuery]`, `[FromBody]`, `[FromForm]`, `[FromHeader]`, `[FromServices]` |
| **Binding order** | Form fields → Route values → Query string (when no attribute specified) |

---

## When To Use It

Model binding runs on every action method that receives data — you're always using it, even if implicitly. The question is whether you're specifying the binding source explicitly. For simple types (int, string, Guid) in the route segment or query string, binding source inference usually works without attributes. For complex types (DTOs, request objects), `[ApiController]` infers `[FromBody]` automatically. Use explicit binding source attributes whenever the source is ambiguous, when you want to be intentional about your contract, or when `[ApiController]` inference doesn't match your intent. Don't mix `[FromBody]` and manual `Request.Body` reading in the same action — they share the same stream.

---

## Core Concept

When a request arrives and the router selects an action, the model binding system walks the action's parameter list and tries to populate each one. For simple value types with no attribute, it checks three sources in order: form fields first, then route values, then query string. If the parameter name matches a key in any of those sources, the value is read and converted to the target type. If conversion fails, a `ModelState` error is added and the parameter gets its default value.

For complex types (classes with properties), the binder reads each property by name from the same three sources — unless an explicit `[From*]` attribute overrides where to look. `[ApiController]` changes this default for complex types: it infers `[FromBody]` so the entire object is bound from the JSON request body rather than from form fields.

Understanding the binding order and the `[ApiController]` inference rules is critical — confusing them is the source of most "my parameter is always null" bugs.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | Model binding system introduced; `[FromBody]`, `[FromRoute]`, `[FromQuery]`, `[FromForm]`, `[FromHeader]` |
| ASP.NET Core 2.1 | .NET Core 2.1 | `[ApiController]` introduces binding source inference — complex types infer `[FromBody]` automatically |
| ASP.NET Core 2.1 | .NET Core 2.1 | `[FromServices]` attribute added for injecting services directly into action parameters |
| ASP.NET Core 3.0 | .NET Core 3.0 | `[FromBody]` supports `System.Text.Json` by default; `Newtonsoft.Json` opt-in |
| ASP.NET Core 5.0 | .NET 5 | `[FromBody]` supports `JsonElement` and `JsonDocument` for dynamic JSON |
| ASP.NET Core 6.0 | .NET 6 | `[AsParameters]` attribute introduced for Minimal APIs parameter binding |
| ASP.NET Core 7.0 | .NET 7 | `[FromBody]` supports `IFormFile` and `IFormFileCollection` alongside JSON |

*Before `[ApiController]` in ASP.NET Core 2.1, you had to explicitly add `[FromBody]` to every complex parameter in an API controller. `[ApiController]` automated this inference, which is convenient but can surprise developers who don't know it applies.*

---

## The Code

**1. Default binding — no attributes, source inferred by type and name**
```csharp
// Simple types: checked against form fields, route values, then query string
// Complex types (without [ApiController]): bound from form fields by default

[HttpGet("products/{categoryId}")]
public IActionResult GetByCategory(
    int    categoryId,   // bound from route — matches {categoryId} segment
    string? keyword,     // bound from query string — ?keyword=chair
    int    page = 1)     // bound from query string — ?page=2; defaults to 1 if missing
    => Ok();
```

**2. Explicit binding source attributes**
```csharp
[HttpGet("search")]
public IActionResult Search(
    [FromQuery]  string  keyword,          // ?keyword=chair
    [FromQuery]  int     page    = 1,      // ?page=2
    [FromRoute]  int     storeId,          // /search/{storeId}/...
    [FromHeader] string? correlationId,    // X-Correlation-Id: abc123
    [FromHeader(Name = "X-Api-Version")] string? apiVersion) // custom header name
    => Ok();

[HttpPost("products")]
public IActionResult Create(
    [FromBody]  CreateProductDto dto,      // JSON request body
    [FromQuery] bool             dryRun)   // ?dryRun=true alongside the body
    => Ok();

[HttpPost("upload")]
public IActionResult Upload(
    [FromForm] IFormFile      file,        // multipart/form-data file upload
    [FromForm] string         description) // other form field alongside the file
    => Ok();
```

**3. [ApiController] binding source inference — what it changes**
```csharp
// WITHOUT [ApiController]: complex types bind from form fields by default
// WITH [ApiController]: complex types infer [FromBody] — binds from JSON body

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    // [ApiController] infers [FromBody] on CreateProductDto automatically
    [HttpPost]
    public IActionResult Create(CreateProductDto dto) => Ok();
    // Equivalent to: Create([FromBody] CreateProductDto dto)

    // Simple types still infer [FromRoute] or [FromQuery] as normal
    [HttpGet("{id:int}")]
    public IActionResult GetById(int id) => Ok();  // id from route

    // Mix: body + query string alongside it
    [HttpPut("{id:int}")]
    public IActionResult Update(int id, UpdateProductDto dto) => Ok();
    // id → [FromRoute] inferred; dto → [FromBody] inferred
}
```

**4. Binding complex types from query string — requires [FromQuery] explicitly**
```csharp
// Without [FromQuery], the filter object would try to bind from form fields
[HttpGet("products")]
public IActionResult GetAll([FromQuery] ProductFilterDto filter) => Ok();

public class ProductFilterDto
{
    public string?    Keyword    { get; set; }  // ?keyword=chair
    public decimal?   MinPrice   { get; set; }  // ?minPrice=10
    public decimal?   MaxPrice   { get; set; }  // ?maxPrice=100
    public bool       InStockOnly { get; set; } // ?inStockOnly=true
    public int        Page       { get; set; } = 1;
    public int        PageSize   { get; set; } = 20;
}
// Request: GET /products?keyword=chair&minPrice=10&inStockOnly=true&page=2
```

**5. [FromServices] — injecting a service directly into an action parameter**
```csharp
// Useful for one-off service dependencies that don't warrant a constructor injection
[HttpGet("{id:int}/report")]
public async Task<IActionResult> GenerateReport(
    int id,
    [FromServices] IReportGenerator reportGenerator,  // resolved from DI, not the request
    [FromServices] ILogger<ProductsController> logger)
{
    logger.LogInformation("Generating report for product {Id}", id);
    var report = await reportGenerator.GenerateAsync(id);
    return File(report.Content, "application/pdf", report.FileName);
}
```

**6. Custom model binder — binding a type the default binder can't handle**
```csharp
// Scenario: a comma-separated query string value ?tags=electronics,home,sale
// Default binder doesn't split CSV into a list automatically

public class CsvListModelBinder : IModelBinder
{
    public Task BindModelAsync(ModelBindingContext bindingContext)
    {
        var value = bindingContext.ValueProvider.GetValue(bindingContext.ModelName);

        if (value == ValueProviderResult.None)
        {
            bindingContext.Result = ModelBindingResult.Success(new List<string>());
            return Task.CompletedTask;
        }

        var items = value.FirstValue?
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .ToList() ?? [];

        bindingContext.Result = ModelBindingResult.Success(items);
        return Task.CompletedTask;
    }
}

// Register on the parameter via ModelBinder attribute
[HttpGet("products")]
public IActionResult GetByTags(
    [ModelBinder(typeof(CsvListModelBinder))] List<string> tags)
    => Ok();

// Request: GET /products?tags=electronics,home,sale
// tags = ["electronics", "home", "sale"]
```

**7. Binding collections and dictionaries from query string**
```csharp
// Arrays from repeated keys: ?ids=1&ids=2&ids=3
[HttpGet("products/batch")]
public IActionResult GetBatch([FromQuery] int[] ids) => Ok();

// Arrays from indexed syntax: ?ids[0]=1&ids[1]=2&ids[2]=3
[HttpPost("products/batch-delete")]
public IActionResult BatchDelete([FromBody] BatchDeleteDto dto) => Ok();

public class BatchDeleteDto
{
    public List<int> Ids { get; set; } = [];
    // Binds from JSON body: { "ids": [1, 2, 3] }
}
```

**8. What NOT to do — reading Request.Body manually alongside [FromBody]**
```csharp
// BAD: [FromBody] and manual body reading fight over the same stream
[HttpPost]
public async Task<IActionResult> Create([FromBody] CreateProductDto dto)
{
    // [FromBody] already consumed the stream — this reads an empty string
    var raw = await new StreamReader(Request.Body).ReadToEndAsync();
    return Ok();
}

// GOOD: Enable buffering if you need both
[HttpPost]
public async Task<IActionResult> Create([FromBody] CreateProductDto dto)
{
    Request.EnableBuffering();
    Request.Body.Position = 0;
    var raw = await new StreamReader(Request.Body).ReadToEndAsync();
    // Now both dto and raw are populated
    return Ok();
}
```

---

## Real World Example

A product search API where filtering, sorting, and pagination all arrive via query string, and the endpoint also accepts an optional saved-search ID from the route segment. A `ProductSearchRequest` DTO is bound from the query string as a whole object, while the route segment is bound as a simple type.

```csharp
// Controllers/SearchController.cs
[ApiController]
[Route("api/search")]
public class SearchController(ISearchService searchService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<ProductDto>>> Search(
        [FromQuery] ProductSearchRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var results = await searchService.SearchAsync(request);
        return Ok(results);
    }

    [HttpGet("saved/{searchId:guid}")]
    public async Task<ActionResult<PagedResult<ProductDto>>> RunSaved(
        Guid searchId,                              // from route
        [FromQuery] int page = 1,                   // override pagination from query string
        [FromQuery] int pageSize = 20,
        [FromServices] ISavedSearchService savedSearchService = null!)
    {
        var savedRequest = await savedSearchService.GetAsync(searchId);
        if (savedRequest is null) return NotFound();

        // Override pagination from the saved request with caller-supplied values
        savedRequest.Page     = page;
        savedRequest.PageSize = pageSize;

        var results = await searchService.SearchAsync(savedRequest);
        return Ok(results);
    }
}

// DTOs/ProductSearchRequest.cs
public class ProductSearchRequest
{
    [MaxLength(200)]
    public string?  Keyword       { get; set; }

    public decimal? MinPrice      { get; set; }
    public decimal? MaxPrice      { get; set; }

    [AllowedValues("name", "price", "rating", "newest")]
    public string   SortBy        { get; set; } = "newest";

    public bool     InStockOnly   { get; set; } = false;

    [Range(1, 100)]
    public int      PageSize      { get; set; } = 20;

    [Range(1, int.MaxValue)]
    public int      Page          { get; set; } = 1;

    // Computed — not bound from the request
    public int Skip => (Page - 1) * PageSize;
}
```

*The key insight: the entire filter state is captured in a single `ProductSearchRequest` DTO bound with `[FromQuery]`. This is cleaner than six individual `[FromQuery]` parameters — the DTO is reusable, testable independently of HTTP, and carries data annotations that validate the search parameters. The `Skip` computed property means the controller and service never calculate pagination offsets manually.*

---

## Common Misconceptions

**"If I don't add [FromBody], [ApiController] will still bind from form fields for complex types"**
With `[ApiController]`, complex types infer `[FromBody]` — not form fields. If you're building a form-posting endpoint on a controller decorated with `[ApiController]` and you want to bind from form fields, you must explicitly add `[FromForm]`. Without it, the binder looks for a JSON body and finds nothing, leaving all properties null.

**"Model binding happens after the action runs"**
Model binding happens before the action runs. By the time your action method executes, all parameters have already been bound (or have failed to bind, with errors recorded in `ModelState`). With `[ApiController]`, if `ModelState` is invalid after binding, the framework returns a 400 before your action runs at all — your action code is never called for invalid input.

**"[FromQuery] and query string binding are the same thing"**
For simple types with no attribute, ASP.NET Core will check the query string as one of the fallback sources. But for complex types, the default binding source is form fields — not query string. `[FromQuery]` on a complex type explicitly tells the binder to read each property from the query string. Without `[FromQuery]`, a DTO parameter on a GET endpoint will silently have all null properties because GET requests have no form body.

---

## Gotchas

- **Complex types without `[ApiController]` bind from form fields, not query string.** If you have a `[FromQuery]`-less DTO parameter on a GET endpoint without `[ApiController]`, all properties will be null. Explicitly add `[FromQuery]` to complex types on GET endpoints.

- **`[FromBody]` can only be used once per action.** Only one parameter per action can have `[FromBody]` — the request body is a stream that can only be read once. If you need multiple values from the body, wrap them in a single DTO. If you need both a body and other sources, combine `[FromBody]` with `[FromQuery]` or `[FromRoute]` for the other parameters.

- **Binding source inference with `[ApiController]` can break form-posting MVC controllers.** If you accidentally add `[ApiController]` to a controller that uses Razor form posts (`method="post"` with `[FromForm]` implicit), the complex type parameters will suddenly try to bind from the JSON body instead of form fields. This is one of the most confusing bugs when migrating between API and MVC controller patterns.

- **Null vs missing for reference types: a missing query parameter is null, a present empty string is `""`**.  `?keyword=` (present but empty) binds to `""` on a `string` property. `?keyword` absent binds to `null`. These are different values and have different `[Required]` validation behaviour — `[Required]` rejects null but accepts empty string unless you also add `[MinLength(1)]`.

- **Route constraint `{id:int}` returns 404, not a binding error, when the value can't be converted.** If `id` is `abc` and the route is `{id:int}`, the route simply doesn't match and the framework returns 404 — it never reaches model binding. A 400 with a binding error only occurs when binding runs and fails (e.g. a plain `{id}` route with an `int id` parameter, where binding tries and fails to parse `abc`).

- **Custom model binders registered globally via `MvcOptions.ModelBinderProviders` run for every matching type.** A binder registered globally for `List<string>` will be used for every `List<string>` parameter in the entire app — not just where you intended. Use `[ModelBinder(typeof(...))]` on the specific parameter unless you genuinely want global behaviour.

---

## Interview Angle

**What they're really testing:** Whether you understand where values come from in an HTTP request and how the binding order works — and specifically the `[ApiController]` inference rules that change default binding behaviour.

**Common question forms:**
- *"How does model binding work in ASP.NET Core?"*
- *"Why is my DTO parameter always null on a GET request?"*
- *"What's the difference between [FromQuery] and [FromBody]?"*

**The depth signal:** A junior answer describes `[FromBody]` and `[FromQuery]` as "they come from different places." A senior answer explains the default binding order (form → route → query) for simple types without attributes, why complex types on GET endpoints need explicit `[FromQuery]` or they bind from the empty form body, what `[ApiController]` changes about binding source inference (complex types infer `[FromBody]`), why `[FromBody]` can only appear once per action (single-read stream), and the 404 vs 400 distinction between route constraint failures and model binding failures.

**Follow-up questions to expect:**
- *"How would you bind a comma-separated query string value to a `List<string>`?"* (custom `IModelBinder`)
- *"What happens when model binding fails?"* (error added to `ModelState`; with `[ApiController]` the action never runs and a 400 is returned automatically)

---

## Related Topics

- [[dotnet/mvc/mvc-models.md]] — The DTOs and ViewModels that model binding populates; data annotations on those classes drive validation after binding.
- [[dotnet/mvc/mvc-model-validation.md]] — What happens after binding: `ModelState` validation, data annotations, FluentValidation, and the difference between binding failures and validation failures.
- [[dotnet/mvc/mvc-controllers.md]] — Controllers declare the action parameters that model binding targets; `[ApiController]` on the controller changes binding inference rules.
- [[dotnet/webapi/webapi-model-binding.md]] — Web API-specific model binding details including minimal API parameter binding and `[AsParameters]`.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/models/model-binding

---
*Last updated: 2026-04-09*