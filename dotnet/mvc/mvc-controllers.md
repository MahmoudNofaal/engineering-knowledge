# MVC Controllers

> The classes in ASP.NET Core that receive HTTP requests, coordinate with services, and return a response — acting as the thin entry point between the HTTP layer and your application logic.

---

## When To Use It

Use controllers when you have a group of related endpoints that share a route prefix, filters, or authorization policy — a `ProductsController` that owns all `/api/products` routes, for example. Controllers are the right choice when you want attribute-based routing, model binding, action filters, and `IActionResult` return types all in one place. For simple one-off endpoints or lightweight APIs, Minimal APIs in `Program.cs` are less ceremony. Don't put business logic inside controller actions — the moment you find yourself writing if-else chains or calling a repository directly, that code belongs in a service.

---

## Core Concept

A controller is just a class that inherits from `Controller` (for MVC with views) or `ControllerBase` (for APIs — no view support). Each public method is a potential action. The framework matches incoming requests to actions using the HTTP method and route pattern, then uses model binding to pull values from the URL, query string, headers, and body into your action parameters automatically. Your action does the minimum: validate input, call a service, return a result. The result — `Ok()`, `NotFound()`, `Created()`, `BadRequest()` — is an `IActionResult` that tells the framework what status code and body to write. The controller never writes to the response directly.

---

## The Code

**1. Basic API controller structure**
```csharp
// Controllers/ProductsController.cs
[ApiController]                      // enables automatic model validation + problem details
[Route("api/[controller]")]          // resolves to api/products
public class ProductsController(IProductService productService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IEnumerable<ProductDto>>> GetAll()
    {
        var products = await productService.GetAllAsync();
        return Ok(products);
    }

    [HttpGet("{id:int}")]            // :int constrains the route — non-int returns 404
    public async Task<ActionResult<ProductDto>> GetById(int id)
    {
        var product = await productService.GetByIdAsync(id);
        return product is null ? NotFound() : Ok(product);
    }

    [HttpPost]
    public async Task<ActionResult<ProductDto>> Create(CreateProductDto dto)
    {
        // [ApiController] already returned 400 if ModelState is invalid
        var created = await productService.CreateAsync(dto);

        // 201 Created with Location header pointing to the new resource
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, UpdateProductDto dto)
    {
        var success = await productService.UpdateAsync(id, dto);
        return success ? NoContent() : NotFound();
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var success = await productService.DeleteAsync(id);
        return success ? NoContent() : NotFound();
    }
}
```

**2. Model binding sources — where parameters come from**
```csharp
[HttpGet("search")]
public IActionResult Search(
    [FromQuery]  string keyword,        // ?keyword=chair
    [FromHeader] string? correlationId, // X-Correlation-Id header
    [FromRoute]  int categoryId)        // part of the route pattern
    => Ok();

[HttpPost("{id:int}/upload")]
public IActionResult Upload(
    int id,                             // [FromRoute] inferred for simple types
    [FromBody]  CreateProductDto dto,   // JSON body — [FromBody] inferred with [ApiController]
    [FromForm]  IFormFile? file)        // multipart form upload
    => Ok();
```

**3. ActionResult<T> vs IActionResult**
```csharp
// ActionResult<T> lets the return type appear in Swagger/OpenAPI automatically
// IActionResult is untyped — use when you return different types (e.g. Ok or NotFound)

// Typed — Swagger knows the 200 response shape
public async Task<ActionResult<ProductDto>> GetById(int id) { ... }

// Untyped — fine when 200 returns nothing (NoContent) or shape varies
public async Task<IActionResult> Delete(int id) { ... }
```

**4. Action filters for cross-cutting concerns**
```csharp
// A reusable filter — applied per-action, per-controller, or globally
public class LogActionFilter : IActionFilter
{
    public void OnActionExecuting(ActionExecutingContext context)
        => Console.WriteLine($"Executing: {context.ActionDescriptor.DisplayName}");

    public void OnActionExecuted(ActionExecutedContext context)
        => Console.WriteLine($"Executed: {context.ActionDescriptor.DisplayName}");
}

// Apply to one controller
[ServiceFilter(typeof(LogActionFilter))]
public class ProductsController : ControllerBase { }

// Or register globally in Program.cs
builder.Services.AddControllers(options =>
    options.Filters.Add<LogActionFilter>());
```

**5. Grouping routes and applying shared policy**
```csharp
// Controllers/Admin/ReportsController.cs
[ApiController]
[Route("api/admin/[controller]")]
[Authorize(Policy = "AdminOnly")]    // all actions require Admin — defined once here
public class ReportsController(IReportService reportService) : ControllerBase
{
    [HttpGet("sales")]
    public async Task<IActionResult> Sales() =>
        Ok(await reportService.GetSalesReportAsync());

    [HttpGet("users")]
    public async Task<IActionResult> Users() =>
        Ok(await reportService.GetUserReportAsync());
}
```

---

## Gotchas

- **`[ApiController]` changes model validation behaviour silently.** Without it, an invalid model reaches your action and `ModelState.IsValid` is false — you check manually. With it, the framework intercepts before your action runs and returns a 400 `ValidationProblemDetails` automatically. Both are valid, but mixing controllers with and without `[ApiController]` in the same project creates inconsistent validation behaviour that surprises teammates.
- **`CreatedAtAction` requires the action name as a string — it breaks silently if you rename the method.** `CreatedAtAction(nameof(GetById), ...)` is safe. `CreatedAtAction("GetById", ...)` is a runtime bug waiting for a refactor. Always use `nameof`.
- **Route constraints like `{id:int}` return 404, not 400, for type mismatches.** `GET /api/products/abc` with `{id:int}` returns 404, not "invalid id format." This is correct per REST conventions but surprises API consumers who expect a 400. Document it or add a catch-all route that returns a descriptive 400 if this matters for your clients.
- **Injecting `DbContext` directly into a controller instead of a service couples HTTP concerns to data access.** The controller becomes hard to test (you need a real or mocked `DbContext`), and you lose the ability to compose or reuse that data access logic elsewhere. Always inject an interface to a service, not a repository or `DbContext` directly.
- **`[FromBody]` consumes the request stream once.** If you try to read `Request.Body` manually and also have a `[FromBody]` parameter, one of them gets an empty stream. Don't mix manual body reading with model binding. If you need the raw body (e.g. for signature verification), enable buffering with `Request.EnableBuffering()` before reading.

---

## Interview Angle

**What they're really testing:** Whether you understand the controller's role as a thin HTTP adapter — not a place for logic — and whether you know the subtleties of model binding, routing constraints, and action result types.

**Common question form:** *"What's the difference between Controller and ControllerBase?"* or *"How does model binding work in ASP.NET Core?"* or *"When would you use ActionResult<T> vs IActionResult?"*

**The depth signal:** A junior answer describes inheriting from `Controller` or `ControllerBase` and using `Ok()` / `NotFound()`. A senior answer explains why `[ApiController]` changes validation behaviour and what `ValidationProblemDetails` is, when to use `ActionResult<T>` over `IActionResult` for OpenAPI schema generation, why `CreatedAtAction` uses `nameof`, how route constraints affect status codes (404 not 400 on type mismatch), and why injecting `DbContext` directly into a controller is an architecture smell — not a compilation error, but a testability and separation-of-concerns failure.

---

## Related Topics

- [[dotnet/mvc-pattern.md]] — Controllers are one of three layers in MVC; understanding the full pattern clarifies what does and doesn't belong in a controller action.
- [[dotnet/dependency-injection.md]] — Services reach controllers through constructor injection; DI lifetime mismatches (injecting a scoped service into a singleton filter, for example) cause subtle runtime bugs.
- [[dotnet/webapi-exception-handling.md]] — Unhandled exceptions from controller actions are caught by the global exception handler; knowing both systems prevents gaps in your error contract.
- [[dotnet/webapi-authorization.md]] — `[Authorize]` and `[AllowAnonymous]` are applied at the controller and action level; authorization policy enforcement is part of the controller's attribute surface.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/actions

---
*Last updated: 2026-03-24*