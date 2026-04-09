# MVC Controllers

> The classes in ASP.NET Core that receive HTTP requests, coordinate with services, and return a response — acting as the thin entry point between the HTTP layer and your application logic.

---

## Quick Reference

| | |
|---|---|
| **What it is** | HTTP request handler + service coordinator |
| **Use when** | Grouping related endpoints with shared routing, filters, or auth |
| **Avoid when** | Simple one-off endpoints — use Minimal APIs instead |
| **Base classes** | `Controller` (MVC + views), `ControllerBase` (API only) |
| **Namespace** | `Microsoft.AspNetCore.Mvc` |
| **Key types** | `IActionResult`, `ActionResult<T>`, `ControllerBase`, `Controller` |

---

## When To Use It

Use controllers when you have a group of related endpoints that share a route prefix, filters, or authorization policy — a `ProductsController` that owns all `/api/products` routes, for example. Controllers are the right choice when you want attribute-based routing, model binding, action filters, and `IActionResult` return types all in one place. For simple one-off endpoints or lightweight APIs, Minimal APIs in `Program.cs` are less ceremony. Don't put business logic inside controller actions — the moment you find yourself writing if-else chains or calling a repository directly, that code belongs in a service.

---

## Core Concept

A controller is just a class that inherits from `Controller` (for MVC with views) or `ControllerBase` (for APIs — no view support). Each public method is a potential action. The framework matches incoming requests to actions using the HTTP method and route pattern, then uses model binding to pull values from the URL, query string, headers, and body into your action parameters automatically. Your action does the minimum: validate input, call a service, return a result. The result — `Ok()`, `NotFound()`, `Created()`, `BadRequest()` — is an `IActionResult` that tells the framework what status code and body to write. The controller never writes to the response directly.

`[ApiController]` is an attribute that turns on several behaviours by default: automatic 400 responses when `ModelState` is invalid, binding source inference (so `[FromBody]` is assumed for complex types), and problem details formatting for error responses. It's not required but it's the right default for any API controller.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | `Controller` and `ControllerBase` introduced; MVC and Web API unified |
| ASP.NET Core 2.1 | .NET Core 2.1 | `[ApiController]` attribute introduced; automatic model validation 400 responses |
| ASP.NET Core 2.2 | .NET Core 2.2 | `ActionResult<T>` introduced for typed responses with OpenAPI schema inference |
| ASP.NET Core 3.0 | .NET Core 3.0 | Endpoint routing replaces `IRouter`; `app.UseMvc()` deprecated |
| ASP.NET Core 5.0 | .NET 5 | `[ApiController]` problem details RFC 7807 compliance improved |
| ASP.NET Core 6.0 | .NET 6 | Primary constructor syntax supported; `MapControllers()` shorthand |
| ASP.NET Core 7.0 | .NET 7 | `TypedResults` added for Minimal APIs; `[ApiController]` ProblemDetails standardised |

*Before ASP.NET Core 2.1, there was no `[ApiController]` — you had to check `ModelState.IsValid` manually in every POST action. The attribute automated the most repetitive boilerplate in API controllers.*

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

**3. ActionResult\<T\> vs IActionResult**
```csharp
// ActionResult<T> lets the return type appear in Swagger/OpenAPI automatically
// IActionResult is untyped — use when you return different shapes (e.g. Ok or NotFound)

// Typed — Swagger knows the 200 response schema
public async Task<ActionResult<ProductDto>> GetById(int id) { ... }

// Untyped — fine when 200 returns nothing (NoContent) or shape varies per status code
public async Task<IActionResult> Delete(int id) { ... }

// ProducesResponseType documents multiple response shapes for OpenAPI
[ProducesResponseType(typeof(ProductDto), StatusCodes.Status200OK)]
[ProducesResponseType(StatusCodes.Status404NotFound)]
public async Task<IActionResult> GetById(int id) { ... }
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

**6. Returning problem details for errors**
```csharp
// [ApiController] does this automatically for ModelState failures.
// For manual error responses, use Problem() and ValidationProblem():

[HttpPost]
public async Task<IActionResult> Create(CreateProductDto dto)
{
    if (await productService.ExistsAsync(dto.Name))
    {
        // 409 Conflict with RFC 7807 problem details body
        return Problem(
            detail:     $"A product named '{dto.Name}' already exists.",
            statusCode: StatusCodes.Status409Conflict,
            title:      "Duplicate product");
    }

    var created = await productService.CreateAsync(dto);
    return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
}
```

**7. What NOT to do — business logic in a controller**
```csharp
// BAD: business logic, EF Core, and HTTP all tangled together
[HttpPost]
public async Task<IActionResult> Create(CreateProductDto dto)
{
    // Direct EF Core call — untestable, violates single responsibility
    var exists = await _context.Products.AnyAsync(p => p.Name == dto.Name);
    if (exists) return BadRequest("Already exists");

    // Manual price calculation in the controller — belongs in a domain service
    var price = dto.BasePrice * 1.2m;
    if (dto.IsPremium) price *= 1.5m;

    _context.Products.Add(new Product { Name = dto.Name, Price = price });
    await _context.SaveChangesAsync();
    return Ok();
}

// GOOD: controller delegates everything — thin, testable
[HttpPost]
public async Task<IActionResult> Create(CreateProductDto dto)
{
    var created = await productService.CreateAsync(dto);
    return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
}
```

---

## Real World Example

A multi-tenant SaaS billing API where each controller action must resolve the current tenant from a JWT claim, enforce tenant-level rate limits, and log the request for audit purposes. Rather than repeating that logic in every action, it lives in a base controller and a filter.

```csharp
// Controllers/Base/TenantControllerBase.cs
[ApiController]
[Authorize]
[ServiceFilter(typeof(TenantAuditFilter))]   // logs every request for the tenant
public abstract class TenantControllerBase : ControllerBase
{
    // Resolved once per request from the JWT claim; available to all derived controllers
    protected Guid TenantId =>
        Guid.Parse(User.FindFirstValue("tenant_id")
            ?? throw new InvalidOperationException("tenant_id claim missing"));
}

// Controllers/BillingController.cs
[Route("api/billing")]
public class BillingController(
    IBillingService    billingService,
    ISubscriptionCache subscriptionCache) : TenantControllerBase
{
    [HttpGet("invoices")]
    public async Task<ActionResult<IEnumerable<InvoiceDto>>> GetInvoices(
        [FromQuery] DateOnly? from,
        [FromQuery] DateOnly? to)
    {
        var invoices = await billingService.GetInvoicesAsync(TenantId, from, to);
        return Ok(invoices);
    }

    [HttpPost("subscriptions/{planId:guid}/upgrade")]
    public async Task<IActionResult> Upgrade(Guid planId)
    {
        // Cache invalidated here so the next request fetches the new plan
        var result = await billingService.UpgradePlanAsync(TenantId, planId);

        if (result.IsFailure)
            return Problem(result.Error, statusCode: StatusCodes.Status422UnprocessableEntity);

        await subscriptionCache.InvalidateAsync(TenantId);
        return NoContent();
    }
}

// Filters/TenantAuditFilter.cs
public class TenantAuditFilter(IAuditLogger auditLogger) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        var tenantId = context.HttpContext.User.FindFirstValue("tenant_id");
        var action   = context.ActionDescriptor.DisplayName;

        var executed = await next(); // run the action

        await auditLogger.LogAsync(tenantId, action,
            executed.Exception is null ? "success" : "error");
    }
}
```

*The key insight: `TenantId` is resolved once in the base class from the JWT claim rather than in every action, the audit filter handles cross-cutting concerns without touching action code, and the controller itself stays to three lines per action. When the billing logic changes, only `BillingService` changes — the controller is untouched.*

---

## Common Misconceptions

**"ControllerBase is for APIs and Controller is for full MVC — they work differently"**
`Controller` inherits from `ControllerBase` and adds only view-related helpers: `View()`, `PartialView()`, `ViewBag`, `ViewData`, and `TempData`. The routing, model binding, filter pipeline, and all `IActionResult` helpers are identical. Using `Controller` in an API project doesn't break anything — it just adds unused methods. The common guidance is to use `ControllerBase` for APIs purely to keep the class surface clean.

**"[ApiController] just adds some convenience — you can skip it"**
`[ApiController]` changes behaviour in ways that affect your error contract. Without it, an action with an invalid model body is called with `ModelState.IsValid == false` and must check manually. With it, the framework intercepts before the action runs and returns a `ValidationProblemDetails` 400. Mixing controllers with and without `[ApiController]` in the same project means some endpoints return your custom error format and others return the framework's default — an inconsistency that breaks API clients.

**"Route constraints like {id:int} validate and return 400 on bad input"**
Route constraints affect routing, not validation. `GET /api/products/abc` with `{id:int}` returns 404 because no route matched — the constraint excluded the path from matching — not 400 because the value was invalid. This is correct REST behaviour but surprises developers who expect a descriptive error. If you need a 400 for type mismatches, add a separate catch-all route or use a model binding approach that gives you `ModelState` control.

```csharp
// This returns 404, not 400, for /api/products/abc:
[HttpGet("{id:int}")]
public IActionResult GetById(int id) => Ok();

// This returns 400 with a validation error for /api/products/abc:
[HttpGet("{id}")]
public IActionResult GetById([FromRoute] int id) => Ok();
// ModelState will be invalid if 'abc' can't bind to int
```

---

## Gotchas

- **`[ApiController]` changes model validation behaviour silently.** Without it, an invalid model reaches your action and `ModelState.IsValid` is false — you check manually. With it, the framework intercepts before your action runs and returns a 400 `ValidationProblemDetails` automatically. Both are valid, but mixing controllers with and without `[ApiController]` in the same project creates inconsistent validation behaviour that surprises teammates.

- **`CreatedAtAction` requires the action name as a string — it breaks silently if you rename the method.** `CreatedAtAction(nameof(GetById), ...)` is safe. `CreatedAtAction("GetById", ...)` is a runtime bug waiting for a refactor. Always use `nameof`.

- **Route constraints like `{id:int}` return 404, not 400, for type mismatches.** `GET /api/products/abc` with `{id:int}` returns 404, not "invalid id format." This is correct per REST conventions but surprises API consumers who expect a 400. Document it or add a catch-all route that returns a descriptive 400 if this matters for your clients.

- **Injecting `DbContext` directly into a controller instead of a service couples HTTP concerns to data access.** The controller becomes hard to test (you need a real or mocked `DbContext`), and you lose the ability to compose or reuse that data access logic elsewhere. Always inject an interface to a service, not a repository or `DbContext` directly.

- **`[FromBody]` consumes the request stream once.** If you try to read `Request.Body` manually and also have a `[FromBody]` parameter, one of them gets an empty stream. Don't mix manual body reading with model binding. If you need the raw body (e.g. for signature verification), enable buffering with `Request.EnableBuffering()` before reading.

- **Action methods must be `public` to be discoverable by the framework.** A `private` or `protected` method on a controller is not treated as an action — it won't be routed to and won't appear in OpenAPI output. This is usually the cause when an endpoint seems correctly defined but returns 404 at runtime.

---

## Interview Angle

**What they're really testing:** Whether you understand the controller's role as a thin HTTP adapter — not a place for logic — and whether you know the subtleties of model binding, routing constraints, and action result types.

**Common question forms:**
- *"What's the difference between Controller and ControllerBase?"*
- *"How does model binding work in ASP.NET Core?"*
- *"When would you use ActionResult\<T\> vs IActionResult?"*
- *"What does [ApiController] actually do?"*

**The depth signal:** A junior answer describes inheriting from `Controller` or `ControllerBase` and using `Ok()` / `NotFound()`. A senior answer explains why `[ApiController]` changes validation behaviour and what `ValidationProblemDetails` is, when to use `ActionResult<T>` over `IActionResult` for OpenAPI schema generation, why `CreatedAtAction` uses `nameof`, how route constraints affect status codes (404 not 400 on type mismatch), and why injecting `DbContext` directly into a controller is an architecture smell — not a compilation error, but a testability and separation-of-concerns failure.

**Follow-up questions to expect:**
- *"How would you share logic across multiple controllers?"* (base controller, filters, or a service)
- *"What's the execution order of action filters?"* (authorization → resource → action → result → exception)

---

## Related Topics

- [[dotnet/mvc/mvc-pattern.md]] — Controllers are one of three layers in MVC; understanding the full pattern clarifies what does and doesn't belong in a controller action.
- [[dotnet/dependency-injection.md]] — Services reach controllers through constructor injection; DI lifetime mismatches (injecting a scoped service into a singleton filter, for example) cause subtle runtime bugs.
- [[dotnet/webapi-exception-handling.md]] — Unhandled exceptions from controller actions are caught by the global exception handler; knowing both systems prevents gaps in your error contract.
- [[dotnet/webapi-authorization.md]] — `[Authorize]` and `[AllowAnonymous]` are applied at the controller and action level; authorization policy enforcement is part of the controller's attribute surface.
- [[dotnet/mvc/mvc-action-filters.md]] — The full filter pipeline: IActionFilter, IResultFilter, IExceptionFilter, execution order, and ServiceFilter vs TypeFilter.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/actions

---
*Last updated: 2026-04-09*