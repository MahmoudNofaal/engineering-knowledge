# ASP.NET Core Web API Controllers

> A controller is a class that groups related HTTP endpoints, receives incoming requests, and returns HTTP responses.

---

## When To Use It

Use controllers when you're building a structured REST API with multiple related endpoints that share authorization, routing prefixes, filters, or injected services. They're the right choice for medium-to-large APIs where grouping and convention matter. For small APIs or cloud functions with a handful of endpoints, minimal APIs are less ceremony. Don't put business logic inside controllers — they should be thin: validate input, call a service, return a response.

---

## Core Concept

A controller is just a C# class that inherits from `ControllerBase` and is decorated with `[ApiController]`. Each public method decorated with an HTTP verb attribute (`[HttpGet]`, `[HttpPost]`, etc.) becomes an endpoint. ASP.NET Core discovers these at startup via `MapControllers()` and wires them into the routing table. `[ApiController]` does three things automatically: it enforces attribute routing (you can't accidentally use conventional routing), it returns 400 with a `ValidationProblemDetails` body when model binding fails, and it infers `[FromBody]` on complex parameters so you don't have to write it everywhere. `ControllerBase` gives you helper methods like `Ok()`, `NotFound()`, `Created()`, and `BadRequest()` that wrap your data in the right `IActionResult`.

---

## The Code
```csharp
// --- Minimal correct controller structure ---
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
```csharp
// --- Typed results with ActionResult<T> (enables OpenAPI schema generation) ---
[HttpGet("{id:int}")]
public async Task<ActionResult<ProductDto>> GetById(int id)
{
    var item = await _products.GetByIdAsync(id);
    if (item is null) return NotFound();        // still returns IActionResult under the hood
    return item;                                // implicit conversion to Ok(item)
}
```
```csharp
// --- [FromQuery], [FromRoute], [FromBody], [FromHeader] when inference isn't enough ---
[HttpGet("search")]
public IActionResult Search(
    [FromQuery] string term,                    // /api/products/search?term=phone
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
```csharp
// --- Returning ProblemDetails for errors (RFC 7807 standard) ---
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
        ? NotFound(new ProblemDetails { Title = "Product not found", Detail = $"No product with id {id}" })
        : Ok(item);
}
```
```csharp
// --- Registration in Program.cs ---
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

## Gotchas

- **`[ApiController]` silently short-circuits your action on model validation failure.** If a request body fails data annotation validation (`[Required]`, `[Range]`, etc.), the framework returns a 400 `ValidationProblemDetails` response before your action method is even called. This means logging, custom error handling, or any logic at the top of the action won't run for invalid requests. If you need to handle validation yourself, disable the behaviour per-controller with `[ApiController]` removed, or globally via `builder.Services.Configure<ApiBehaviorOptions>(o => o.SuppressModelStateInvalidFilter = true)`.
- **`CreatedAtAction` silently returns 500 if the action name doesn't exist.** `CreatedAtAction(nameof(GetById), ...)` generates the `Location` header by looking up the named action. If you rename `GetById` and forget to update the `nameof`, the route lookup fails at runtime and throws an `InvalidOperationException`. Use `nameof` consistently and verify the `Location` header in integration tests.
- **Returning `Ok(null)` sends a 200 with an empty body, not a 204.** If your service returns null for "not found" and you call `Ok(null)` accidentally, the client gets a 200 with no content — not a 404. Always null-check before returning `Ok()` and return `NotFound()` explicitly.
- **Async void action methods swallow exceptions.** If you accidentally declare an action as `async void` instead of `async Task<IActionResult>`, any exception thrown inside it is not caught by the framework's exception handling middleware — it propagates on a thread pool thread and can crash the process. Always use `async Task` or `async Task<IActionResult>`.
- **`[FromBody]` can only be applied to one parameter per action.** The request body is a stream that can only be read once. If you try to bind two `[FromBody]` parameters, the second one always gets the default value silently. If you need multiple values from the body, wrap them in a single request DTO.

---

## Interview Angle

**What they're really testing:** Whether you understand HTTP semantics (correct status codes, idempotency, the `Location` header), what `[ApiController]` actually does under the hood, and how the controller fits into the broader middleware pipeline.

**Common question form:** "Walk me through what happens when a POST request hits your API" or "What's the difference between `Controller` and `ControllerBase`?" or "When would you return `ActionResult<T>` vs `IActionResult`?"

**The depth signal:** A junior knows the verb attributes and can write a CRUD controller. A senior knows that `Controller` (not `ControllerBase`) adds Razor view support — which is dead weight in a pure API project and should never be used. They also know that `ActionResult<T>` is preferred over `IActionResult` because it exposes the response type to OpenAPI/Swashbuckle schema generation without requiring `[ProducesResponseType]` attributes everywhere, and they understand that `[ApiController]`'s automatic 400 behaviour uses `IActionFilter` under the hood (specifically `ModelStateInvalidFilter`), which means it can be replaced or extended with a custom filter.

---

## Related Topics

- [[dotnet/webapi-routing.md]] — routing determines which controller and action handles a given request; the `[Route]` and `[HttpGet]` attributes here are part of that system
- [[dotnet/webapi-model-binding.md]] — `[FromBody]`, `[FromQuery]`, and `[FromRoute]` are model binding attributes; understanding binding explains how action parameters get their values
- [[dotnet/webapi-filters.md]] — action filters, exception filters, and result filters are the correct place for cross-cutting concerns like logging and error formatting that should not live inside the controller
- [[dotnet/dependency-injection.md]] — services are injected via constructor; knowing DI lifetimes (scoped, transient, singleton) is essential when injecting `DbContext` or `HttpClient` into controllers

---

## Source

[https://learn.microsoft.com/en-us/aspnet/core/web-api/](https://learn.microsoft.com/en-us/aspnet/core/web-api/)

---
*Last updated: 2026-03-24*