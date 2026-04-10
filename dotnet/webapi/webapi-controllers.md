# ASP.NET Core Web API Controllers

> A controller is a class that groups related HTTP endpoints, receives incoming requests, and returns HTTP responses.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Class that groups related HTTP endpoints and maps them to actions |
| **Use when** | Medium-to-large APIs with shared filters, auth, or injected services per resource |
| **Avoid when** | Tiny APIs with a handful of endpoints — use Minimal APIs instead |
| **Introduced** | ASP.NET Core 1.0; `[ApiController]` added ASP.NET Core 2.1 |
| **Namespace** | `Microsoft.AspNetCore.Mvc` |
| **Key types** | `ControllerBase`, `ApiController`, `IActionResult`, `ActionResult<T>` |

---

## When To Use It

Use controllers when you're building a structured REST API with multiple related endpoints that share authorization, routing prefixes, filters, or injected services. They're the right choice for medium-to-large APIs where grouping and convention matter. For small APIs or cloud functions with a handful of endpoints, minimal APIs are less ceremony. Don't put business logic inside controllers — they should be thin: validate input, call a service, return a response. A controller that does database queries, sends emails, and builds domain objects is a controller doing too much.

---

## Core Concept

A controller is just a C# class that inherits from `ControllerBase` and is decorated with `[ApiController]`. Each public method decorated with an HTTP verb attribute (`[HttpGet]`, `[HttpPost]`, etc.) becomes an endpoint. ASP.NET Core discovers these at startup via `MapControllers()` and wires them into the routing table. `[ApiController]` does three things automatically: it enforces attribute routing (you can't accidentally use conventional routing), it returns 400 with a `ValidationProblemDetails` body when model binding fails, and it infers `[FromBody]` on complex parameters so you don't have to write it everywhere. `ControllerBase` gives you helper methods like `Ok()`, `NotFound()`, `Created()`, and `BadRequest()` that wrap your data in the right `IActionResult`.

---

## Version History

| C# / .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | `ControllerBase` and `Controller` introduced; basic MVC pipeline |
| ASP.NET Core 2.1 | `[ApiController]` attribute added — automatic 400, binding inference, problem details |
| ASP.NET Core 2.2 | `ActionResult<T>` introduced — typed return for OpenAPI schema generation |
| .NET 5 | `[ApiController]` problem details improved; `ProblemDetails` factory added |
| .NET 6 | Minimal APIs introduced as an alternative; controllers unchanged but no longer the only option |
| .NET 7 | `TypedResults` introduced; `ProblemDetails` middleware added |

*Before `[ApiController]` (ASP.NET Core 2.1), you had to check `ModelState.IsValid` manually in every action and return `BadRequest(ModelState)` yourself. `[ApiController]` automated this, but it also changed the pipeline in ways that surprised teams upgrading from 2.0.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Controller instantiation per request | Low | Scoped by default; one new instance per request |
| Action method dispatch | ~1–5 µs | Reflection-based at startup, compiled to delegates at runtime |
| `IActionResult.ExecuteResultAsync` | Varies | Serialisation cost dominates; JSON write is the main cost |
| `ActionResult<T>` vs `IActionResult` | Identical at runtime | Difference is only in compile-time type visibility for OpenAPI |

**Allocation behaviour:** Each request creates a new controller instance (scoped). Constructor injection resolves from the scope cache — typically zero allocation for already-resolved services. The main allocation source is JSON serialisation of the response body. Use `System.Text.Json` (default since .NET Core 3.0) over Newtonsoft for lower allocations.

**Benchmark notes:** Controller overhead is negligible compared to I/O. The only scenario where controller dispatch matters is extremely high-frequency, no-I/O endpoints (health checks, ping routes) — where minimal APIs have a small measurable advantage due to skipping the MVC action filter pipeline.

---

## The Code

**Minimal correct controller structure**
```csharp
[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly IProductService _products;

    public ProductsController(IProductService products)
    {
        _products = products;
    }

    [HttpGet]                                   // GET /api/products
    public async Task<IActionResult> GetAll()
    {
        var items = await _products.GetAllAsync();
        return Ok(items);
    }

    [HttpGet("{id:int}")]                        // GET /api/products/5
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _products.GetByIdAsync(id);
        return item is null ? NotFound() : Ok(item);
    }

    [HttpPost]                                   // POST /api/products
    public async Task<IActionResult> Create(CreateProductRequest req)  // [FromBody] inferred
    {
        var created = await _products.CreateAsync(req);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]                        // PUT /api/products/5
    public async Task<IActionResult> Update(int id, UpdateProductRequest req)
    {
        var updated = await _products.UpdateAsync(id, req);
        return updated is null ? NotFound() : Ok(updated);
    }

    [HttpDelete("{id:int}")]                     // DELETE /api/products/5
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _products.DeleteAsync(id);
        return deleted ? NoContent() : NotFound();
    }
}
```

**Typed results with `ActionResult<T>` — enables OpenAPI schema generation**
```csharp
// ActionResult<T> lets Swashbuckle know the response type without [ProducesResponseType] everywhere
[HttpGet("{id:int}")]
public async Task<ActionResult<ProductDto>> GetById(int id)
{
    var item = await _products.GetByIdAsync(id);
    if (item is null) return NotFound();        // still IActionResult under the hood
    return item;                                // implicit conversion to Ok(item)
}
```

**Explicit binding attributes when inference isn't enough**
```csharp
[HttpGet("search")]
public IActionResult Search(
    [FromQuery] string term,
    [FromQuery] int page = 1,
    [FromQuery] int pageSize = 20)
{
    return Ok(_products.Search(term, page, pageSize));
}

[HttpPost("bulk")]
public IActionResult Bulk(
    [FromHeader(Name = "X-Idempotency-Key")] string idempotencyKey,
    [FromBody] List<CreateProductRequest> requests)
{
    return Accepted();
}
```

**Returning ProblemDetails for errors (RFC 7807)**
```csharp
[HttpGet("{id:int}")]
public async Task<IActionResult> GetById(int id)
{
    if (id <= 0)
        return Problem(
            title: "Invalid ID",
            detail: "ID must be a positive integer.",
            statusCode: StatusCodes.Status400BadRequest);

    var item = await _products.GetByIdAsync(id);
    return item is null
        ? NotFound(new ProblemDetails
            { Title = "Product not found", Detail = $"No product with id {id}" })
        : Ok(item);
}
```

**Registration in Program.cs**
```csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();              // registers controller infrastructure
builder.Services.AddScoped<IProductService, ProductService>();

var app = builder.Build();
app.UseRouting();
app.UseAuthorization();
app.MapControllers();                           // discovers and registers all controller routes
app.Run();
```

---

## Real World Example

An inventory management API has a `ProductsController` where some actions are public, some require authentication, and one requires an admin role. The controller stays thin — all business logic lives in `IProductService` — and the controller handles only HTTP concerns: status codes, routing, and auth.

```csharp
[ApiController]
[Route("api/v1/products")]
[Produces("application/json")]
public class ProductsController : ControllerBase
{
    private readonly IProductService _products;
    private readonly ILogger<ProductsController> _logger;

    public ProductsController(IProductService products, ILogger<ProductsController> logger)
    {
        _products = products;
        _logger   = logger;
    }

    // Public — no auth required
    [HttpGet]
    [ResponseCache(Duration = 60, Location = ResponseCacheLocation.Any)]
    public async Task<ActionResult<PagedResult<ProductSummaryDto>>> GetAll(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? category = null)
    {
        var result = await _products.GetPagedAsync(page, pageSize, category);
        return Ok(result);
    }

    [HttpGet("{id:guid}", Name = "GetProduct")]
    public async Task<ActionResult<ProductDetailDto>> GetById(Guid id)
    {
        var product = await _products.GetDetailAsync(id);
        return product is null ? NotFound() : Ok(product);
    }

    // Requires authentication
    [HttpPost]
    [Authorize]
    public async Task<ActionResult<ProductDetailDto>> Create([FromBody] CreateProductRequest req)
    {
        var created = await _products.CreateAsync(req, User);
        _logger.LogInformation("Product {ProductId} created by {UserId}",
            created.Id, User.FindFirstValue(ClaimTypes.NameIdentifier));
        return CreatedAtRoute("GetProduct", new { id = created.Id }, created);
    }

    // Requires admin role
    [HttpDelete("{id:guid}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var success = await _products.DeleteAsync(id);
        if (!success)
            return NotFound(new ProblemDetails
            {
                Title  = "Product not found",
                Detail = $"No product with id {id} exists.",
                Status = 404
            });
        return NoContent();
    }
}
```

*The key insight: the controller is entirely about HTTP — status codes, route names for `CreatedAtRoute`, auth attributes, and caching headers. Zero business logic. Swap `IProductService` for a mock in tests and the entire controller is testable without a database or web server.*

---

## Common Misconceptions

**"I should inherit from `Controller`, not `ControllerBase`, to get full features."**
`Controller` inherits from `ControllerBase` and adds Razor view support (`View()`, `ViewBag`, `ViewData`). In a pure Web API project, you never render views — that's dead weight. Always use `ControllerBase` for APIs. The confusion comes from older tutorials that predate the Web API / MVC split.

**"`[ApiController]` is optional — it just adds convenience."**
`[ApiController]` fundamentally changes the pipeline. Without it, model validation failures are silent (the action still runs with invalid data), `[FromBody]` is not inferred on complex parameters, and the automatic 400 `ValidationProblemDetails` response is absent. It's not a convenience attribute — it's a correctness attribute. Every API controller should have it.

**"`ActionResult<T>` and `IActionResult` are interchangeable."**
At runtime they behave identically. The difference is that `ActionResult<T>` exposes the response type to OpenAPI generators (Swashbuckle, NSwag) — they can infer `200 ProductDto` from the return type without requiring `[ProducesResponseType(typeof(ProductDto), 200)]` on every action. Use `ActionResult<T>` for actions that return a specific type; use `IActionResult` only when an action can return fundamentally different types that share no common base.

---

## Gotchas

- **`[ApiController]` silently short-circuits your action on model validation failure.** If a request body fails data annotation validation, the framework returns a 400 `ValidationProblemDetails` response before your action method is called. Any logging, custom error handling, or logic at the top of the action won't run for invalid requests. If you need to handle validation yourself, suppress this behaviour globally: `builder.Services.Configure<ApiBehaviorOptions>(o => o.SuppressModelStateInvalidFilter = true)`.

- **`CreatedAtAction` silently returns 500 if the action name doesn't exist.** `CreatedAtAction(nameof(GetById), ...)` generates the `Location` header by looking up the named action. If you rename `GetById` and forget to update the `nameof`, the route lookup fails at runtime. Use `nameof` consistently and verify the `Location` header in integration tests.

- **Returning `Ok(null)` sends a 200 with an empty body, not a 204.** If your service returns null for "not found" and you accidentally call `Ok(null)`, the client gets a 200 with no content — not a 404. Always null-check before returning `Ok()` and return `NotFound()` explicitly.

- **`async void` action methods swallow exceptions.** If you accidentally declare an action as `async void` instead of `async Task<IActionResult>`, any exception thrown inside it is not caught by the framework's exception handling middleware — it propagates on a thread pool thread and can crash the process. Always use `async Task` or `async Task<IActionResult>`.

- **`[FromBody]` can only be applied to one parameter per action.** The request body is a stream that can only be read once. If you bind two `[FromBody]` parameters, the second always gets the default value silently. Wrap multiple values in a single request DTO.

- **`[Route]` on the controller and `[HttpGet]` with a leading slash on the action override each other.** `[HttpGet("/refunds")]` on an action (note the leading slash) is an absolute path — it ignores the controller's `[Route]` prefix entirely. The route becomes `/refunds`, not `/api/products/refunds`. This is intentional but trips up almost every developer the first time.

---

## Interview Angle

**What they're really testing:** Whether you understand HTTP semantics (correct status codes, idempotency, the `Location` header), what `[ApiController]` actually does under the hood, and how the controller fits into the broader middleware and filter pipeline.

**Common question forms:**
- "Walk me through what happens when a POST request hits your API."
- "What's the difference between `Controller` and `ControllerBase`?"
- "When would you return `ActionResult<T>` vs `IActionResult`?"
- "What does `[ApiController]` actually do?"

**The depth signal:** A junior knows the verb attributes and can write a CRUD controller. A senior knows that `Controller` adds Razor view support which has no place in an API project, that `ActionResult<T>` is preferred over `IActionResult` for OpenAPI schema generation without `[ProducesResponseType]` attributes, that `[ApiController]`'s automatic 400 behaviour uses `ModelStateInvalidFilter` (an action filter at order `-2000`), and that `CreatedAtAction` generates the `Location` header by doing a route lookup — which fails silently at runtime if the action name is wrong.

**Follow-up questions to expect:**
- "How would you customise the 400 validation error response shape?"
- "Why shouldn't controllers contain business logic?"
- "What's the difference between a controller action and a minimal API endpoint?"

---

## Related Topics

- [[dotnet/webapi/webapi-routing.md]] — routing determines which controller and action handles a given request; `[Route]` and `[HttpGet]` attributes are part of the routing system
- [[dotnet/webapi/webapi-model-binding.md]] — `[FromBody]`, `[FromQuery]`, `[FromRoute]` are model binding attributes; understanding binding explains how action parameters get their values
- [[dotnet/webapi/webapi-filters.md]] — action filters, exception filters, and result filters are the correct place for cross-cutting concerns like logging and error formatting that should not live inside the controller
- [[dotnet/webapi/webapi-minimal-apis.md]] — the lightweight alternative to controllers; comparing the two reveals exactly what MVC adds on top of the shared routing and middleware infrastructure

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/web-api/

---
*Last updated: 2026-04-10*