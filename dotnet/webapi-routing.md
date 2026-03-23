# ASP.NET Core Web API Routing

> Routing is how ASP.NET Core maps an incoming HTTP request to a specific controller action or minimal API endpoint.

---

## When To Use It

You're always using it — every Web API has routing. It matters most when you're designing URL structures, handling route conflicts, building versioned APIs, or debugging a 404 that shouldn't be happening. Understanding it deeply lets you avoid ambiguous route errors, write correct route constraints, and reason about why middleware order affects whether routing fires at all.

---

## Core Concept

When a request arrives, the routing middleware matches the URL path and HTTP method against a table of registered routes and picks the best match. There are two styles: conventional routing (a single template like `{controller}/{action}/{id?}` that applies to all controllers) and attribute routing (a `[Route]` or `[HttpGet]` attribute placed directly on the controller or action). Web APIs almost always use attribute routing because it keeps the URL contract explicit and co-located with the code. Once a route matches, the endpoint middleware calls the action. Route parameters in the URL (e.g., `{id}`) are extracted and bound to action parameters automatically. Constraints like `{id:int}` or `{id:guid}` narrow which requests match a given route.

---

## The Code
```csharp
// --- Attribute routing basics ---
[ApiController]
[Route("api/[controller]")]         // [controller] token resolves to "orders"
public class OrdersController : ControllerBase
{
    [HttpGet]                        // GET /api/orders
    public IActionResult GetAll() => Ok();

    [HttpGet("{id:int}")]            // GET /api/orders/42  (only matches integers)
    public IActionResult GetById(int id) => Ok(id);

    [HttpPost]                       // POST /api/orders
    public IActionResult Create([FromBody] OrderRequest req) => Created($"/api/orders/1", req);

    [HttpDelete("{id:int}")]         // DELETE /api/orders/42
    public IActionResult Delete(int id) => NoContent();
}
```
```csharp
// --- Route constraints ---
[HttpGet("{id:int:min(1)}")]         // must be int AND >= 1
public IActionResult GetById(int id) { ... }

[HttpGet("{slug:alpha:minlength(3)}")] // only letters, min 3 chars
public IActionResult GetBySlug(string slug) { ... }

[HttpGet("{**catchall}")]            // catch-all: matches anything, including slashes
public IActionResult Wildcard(string catchall) { ... }
```
```csharp
// --- Route tokens and custom prefixes ---
[Route("v1/products")]               // hard-coded prefix, not using [controller] token
public class ProductsController : ControllerBase
{
    [HttpGet("{id}")]                 // GET /v1/products/{id}
    public IActionResult Get(int id) => Ok();

    [HttpGet("featured")]            // GET /v1/products/featured
    public IActionResult GetFeatured() => Ok();
}
```
```csharp
// --- Minimal API routing (.NET 6+) ---
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/api/items/{id:int}", (int id) => Results.Ok(id));
app.MapPost("/api/items", (ItemRequest req) => Results.Created($"/api/items/1", req));

// Route groups reduce repetition
var items = app.MapGroup("/api/items").RequireAuthorization();
items.MapGet("/",    () => Results.Ok());
items.MapGet("/{id:int}", (int id) => Results.Ok(id));
items.MapDelete("/{id:int}", (int id) => Results.NoContent());

app.Run();
```
```csharp
// --- Resolving route conflicts: [HttpGet] with explicit name wins over ambiguous match ---
[HttpGet("search")]                  // GET /api/orders/search — matched BEFORE {id}
public IActionResult Search([FromQuery] string q) => Ok(q);

[HttpGet("{id:int}")]                // GET /api/orders/42 — int constraint prevents overlap
public IActionResult GetById(int id) => Ok(id);

// Without the :int constraint, /api/orders/search would be ambiguous between the two routes
```

---

## Gotchas

- **`[Route]` on the controller and `[HttpGet]` on the action are concatenated, not replaced.** If the controller has `[Route("api/orders")]` and an action has `[HttpGet("/refunds")]` (note the leading slash), the leading slash makes it an absolute path — the controller prefix is ignored and the route becomes `/refunds`. Leading slashes on action attributes are a silent override, not a relative path.
- **Conventional routing is registered with `MapControllerRoute`, attribute routing with `MapControllers` — they are not the same call.** Using `MapControllerRoute` without defining `[Route]` attributes and then adding `[HttpGet]` to actions often produces a 404 because the conventional route template doesn't match what attribute routing expects. In Web API projects, always use `MapControllers()`.
- **Route matching is case-insensitive by default, but route parameter names are case-sensitive in binding.** `/api/Orders/42` and `/api/orders/42` match the same route, but if your action parameter is named `Id` and you specify `[HttpGet("{id}")]`, the binding still works because parameter binding is case-insensitive too. The confusion arises when custom model binders or route constraints use exact casing.
- **Ambiguous route exceptions surface at startup, not at request time.** If two routes match the same URL pattern with the same HTTP method, ASP.NET Core throws `AmbiguousMatchException` when the first request arrives (or at startup in .NET 7+ with `RouteGroupBuilder`). Adding route constraints (`:int`, `:guid`) is the correct fix — adding `[NonAction]` or reordering registrations is not reliable.
- **`[ApiController]` changes 404 vs 400 behaviour for route vs body binding failures.** Without `[ApiController]`, a missing required route parameter silently passes `null` or default and your action runs with bad data. With it, the framework automatically returns 400 before your action is called. This is almost always what you want, but it can surprise you in tests where you expect your action to handle missing data itself.

---

## Interview Angle

**What they're really testing:** Whether you understand the request pipeline well enough to reason about routing failures, and whether you know the difference between conventional and attribute routing at a mechanical level.

**Common question form:** "Why is my route returning 404?" or "How would you version a REST API?" or "What's the difference between `[Route]` and `[HttpGet]`?"

**The depth signal:** A junior knows that `[HttpGet("{id}")]` maps a GET with a URL parameter. A senior can explain the full matching pipeline: `UseRouting()` builds the candidate set, `UseAuthorization()` / `UseAuthentication()` run in between, and `UseEndpoints()` / `MapControllers()` executes the match — and that putting middleware in the wrong order means auth runs before routing resolves the endpoint, so `HttpContext.GetEndpoint()` returns null and `[Authorize]` metadata is invisible. They also know how `LinkGenerator` produces URLs from route names programmatically without hardcoding strings, and why `[Route("~/absolute")]` exists.

---

## Related Topics

- [[dotnet/webapi-model-binding.md]] — route parameters, query strings, and body are all part of model binding; routing determines which action runs, binding determines what values it receives
- [[dotnet/webapi-middleware-pipeline.md]] — routing is middleware; the order of `UseRouting()`, `UseAuthentication()`, and `UseEndpoints()` determines what endpoint metadata is available to each middleware
- [[dotnet/webapi-versioning.md]] — API versioning (Asp.Versioning.Http) builds on top of routing; understanding route constraints and route templates is prerequisite
- [[dotnet/webapi-minimal-apis.md]] — minimal APIs use the same routing engine as controllers but with a different registration syntax; the constraints and matching rules are identical

---

## Source

[https://learn.microsoft.com/en-us/aspnet/core/fundamentals/routing](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/routing)

---
*Last updated: 2026-03-24*