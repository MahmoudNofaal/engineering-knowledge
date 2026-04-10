# ASP.NET Core Web API Routing

> Routing is how ASP.NET Core maps an incoming HTTP request to a specific controller action or minimal API endpoint.

---

## Quick Reference

| | |
|---|---|
| **What it is** | URL-to-action mapping engine built into the pipeline |
| **Use when** | Always — every Web API uses routing |
| **Avoid when** | N/A — but avoid conventional routing in API projects; use attribute routing |
| **Introduced** | ASP.NET Core 1.0; endpoint routing added ASP.NET Core 3.0 |
| **Namespace** | `Microsoft.AspNetCore.Routing`, `Microsoft.AspNetCore.Mvc` |
| **Key types** | `RouteAttribute`, `HttpMethodAttribute`, `LinkGenerator`, `IEndpointRouteBuilder` |

---

## When To Use It

You're always using it — every Web API has routing. It matters most when you're designing URL structures, handling route conflicts, building versioned APIs, or debugging a 404 that shouldn't be happening. Understanding it deeply lets you avoid ambiguous route errors, write correct route constraints, and reason about why middleware order affects whether routing fires at all.

---

## Core Concept

When a request arrives, the routing middleware matches the URL path and HTTP method against a table of registered routes and picks the best match. There are two styles: conventional routing (a single template like `{controller}/{action}/{id?}` that applies to all controllers) and attribute routing (a `[Route]` or `[HttpGet]` attribute placed directly on the controller or action). Web APIs almost always use attribute routing because it keeps the URL contract explicit and co-located with the code. Once a route matches, the endpoint middleware calls the action. Route parameters in the URL (e.g., `{id}`) are extracted and bound to action parameters automatically. Constraints like `{id:int}` or `{id:guid}` narrow which requests match a given route.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | Attribute routing and conventional routing both introduced |
| ASP.NET Core 2.2 | Endpoint routing introduced as preview |
| ASP.NET Core 3.0 | Endpoint routing became the default; `UseRouting` / `UseEndpoints` split |
| .NET 5 | Route constraints improved; `LinkGenerator` became the standard for URL generation |
| .NET 6 | Minimal API routing introduced; `MapGroup` added |
| .NET 7 | `RouteGroupBuilder` finalized; `[AsParameters]` attribute for parameter binding from groups |
| .NET 8 | `[Route]` on controller can be combined with `[HttpGet]` overrides; short-circuit routing added |

*The 3.0 split of `UseRouting` and `UseEndpoints` is significant: middleware placed between those two calls can inspect which endpoint was selected (via `HttpContext.GetEndpoint()`) without the endpoint having executed yet. This is what makes `UseAuthorization` work correctly — it sees the endpoint's `[Authorize]` metadata before the action runs.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Route matching | O(log n) to O(1) | Trie-based matching; effectively constant for typical route counts |
| Constraint evaluation | O(k) per segment | k = number of constraints on the segment |
| URL generation via `LinkGenerator` | O(log n) | Template lookup then parameter substitution |
| `CreatedAtAction` / `CreatedAtRoute` | O(log n) | Internally uses `LinkGenerator` |

**Allocation behaviour:** Route matching itself allocates minimally — route values are pooled in many cases. The main allocation comes from route parameter extraction and binding. Avoid catch-all routes (`{**catchall}`) on hot paths — they disable some optimisations in the trie matcher.

**Benchmark notes:** Routing is not a bottleneck in typical APIs. Trie matching handles thousands of routes with sub-microsecond performance. The only scenario where route count matters is services with 500+ routes — and even then, the bottleneck is usually template compilation at startup, not per-request matching.

---

## The Code

**Attribute routing basics**
```csharp
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

**Route constraints**
```csharp
[HttpGet("{id:int:min(1)}")]           // must be int AND >= 1
public IActionResult GetById(int id) { ... }

[HttpGet("{slug:alpha:minlength(3)}")] // only letters, min 3 chars
public IActionResult GetBySlug(string slug) { ... }

[HttpGet("{id:guid}")]                 // only valid Guids
public IActionResult GetByGuid(Guid id) { ... }

[HttpGet("{**catchall}")]              // catch-all: matches anything, including slashes
public IActionResult Wildcard(string catchall) { ... }
```

**Route tokens and hard-coded prefixes**
```csharp
[Route("v1/products")]               // hard-coded prefix, not using [controller] token
public class ProductsController : ControllerBase
{
    [HttpGet("{id}")]                 // GET /v1/products/{id}
    public IActionResult Get(int id) => Ok();

    [HttpGet("featured")]            // GET /v1/products/featured
    public IActionResult GetFeatured() => Ok();
}
```

**Minimal API routing (.NET 6+)**
```csharp
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/api/items/{id:int}", (int id) => Results.Ok(id));
app.MapPost("/api/items", (ItemRequest req) => Results.Created($"/api/items/1", req));

// Route groups reduce repetition
var items = app.MapGroup("/api/items").RequireAuthorization();
items.MapGet("/",         () => Results.Ok());
items.MapGet("/{id:int}", (int id) => Results.Ok(id));
items.MapDelete("/{id:int}", (int id) => Results.NoContent());

app.Run();
```

**Resolving route conflicts**
```csharp
[HttpGet("search")]                  // GET /api/orders/search — matched BEFORE {id}
public IActionResult Search([FromQuery] string q) => Ok(q);

[HttpGet("{id:int}")]                // GET /api/orders/42 — int constraint prevents overlap
public IActionResult GetById(int id) => Ok(id);

// Without the :int constraint, /api/orders/search would be ambiguous between the two routes
```

**URL generation with `LinkGenerator`**
```csharp
// Generate URLs programmatically without hardcoding strings
public class NotificationService
{
    private readonly LinkGenerator _links;

    public NotificationService(LinkGenerator links) => _links = links;

    public string GetOrderUrl(HttpContext ctx, int orderId)
    {
        // Generates an absolute URL to the GetById action in OrdersController
        return _links.GetUriByAction(ctx,
            action: "GetById",
            controller: "Orders",
            values: new { id = orderId })!;
    }
}
```

---

## Real World Example

An e-commerce API supports two resource hierarchies: orders have line items, and products have variants. Routes are designed so child resources always appear under their parent, constraints prevent invalid IDs from reaching the action, and a named route enables `Location` header generation in POST responses.

```csharp
[ApiController]
[Route("api/orders")]
public class OrdersController : ControllerBase
{
    private readonly IOrderService _orders;

    public OrdersController(IOrderService orders) => _orders = orders;

    [HttpGet(Name = "GetOrder")]                         // GET /api/orders
    public async Task<IActionResult> GetAll(
        [FromQuery] OrderStatus? status,
        [FromQuery] int page = 1) =>
        Ok(await _orders.GetPagedAsync(status, page));

    [HttpGet("{orderId:guid}", Name = "GetOrderById")]   // GET /api/orders/{guid}
    public async Task<IActionResult> GetById(Guid orderId)
    {
        var order = await _orders.GetAsync(orderId);
        return order is null ? NotFound() : Ok(order);
    }

    [HttpPost]                                           // POST /api/orders
    public async Task<IActionResult> Create([FromBody] CreateOrderRequest req)
    {
        var order = await _orders.CreateAsync(req);
        return CreatedAtRoute("GetOrderById", new { orderId = order.Id }, order);
    }

    // Nested resource: line items under a specific order
    [HttpGet("{orderId:guid}/items")]                    // GET /api/orders/{guid}/items
    public async Task<IActionResult> GetItems(Guid orderId) =>
        Ok(await _orders.GetItemsAsync(orderId));

    [HttpPost("{orderId:guid}/items")]                   // POST /api/orders/{guid}/items
    public async Task<IActionResult> AddItem(
        Guid orderId,
        [FromBody] AddOrderItemRequest req)
    {
        var item = await _orders.AddItemAsync(orderId, req);
        return item is null
            ? NotFound(new ProblemDetails { Title = "Order not found" })
            : Ok(item);
    }
}
```

*The key insight: the `:guid` constraint on `{orderId}` means `/api/orders/search` never conflicts with `/api/orders/{orderId:guid}` — "search" is not a valid Guid so the constraint eliminates any ambiguity without needing explicit ordering. Constraints are the primary tool for conflict-free route design, not route order.*

---

## Common Misconceptions

**"Route order in `Program.cs` determines which route wins."**
For attribute routing, route order doesn't matter the way it does with conventional routing. The router evaluates all candidates and picks the most specific match based on the template — literal segments beat parameterised segments, and constrained parameters beat unconstrained ones. Only when specificity is genuinely equal does registration order act as a tiebreaker — and in that case the correct fix is adding constraints, not relying on order.

**"Conventional routing and attribute routing work the same way in Web APIs."**
Conventional routing (registering `{controller}/{action}/{id?}` as a template) is designed for MVC with views. Web APIs should use attribute routing exclusively — `[ApiController]` actually enforces this by requiring explicit route attributes. With conventional routing you can accidentally expose actions you didn't intend to, because the route template matches anything that looks like `controller/action`.

**"I can use `[Route]` on an action to override the controller prefix."**
A `[Route]` attribute on an action is combined with the controller's `[Route]` prefix by default — it doesn't replace it. To create an absolute route that ignores the controller prefix, use a leading slash: `[HttpGet("/absolute/path")]`. The leading slash is easy to miss and the resulting behaviour (prefix ignored) is the opposite of what most developers expect.

```csharp
[Route("api/orders")]
public class OrdersController : ControllerBase
{
    [HttpGet("list")]          // → /api/orders/list   (combined)
    public IActionResult List() => Ok();

    [HttpGet("/all-orders")]   // → /all-orders        (absolute — prefix ignored)
    public IActionResult All() => Ok();
}
```

---

## Gotchas

- **`[Route]` on the controller and `[HttpGet]` on the action are concatenated, not replaced.** If the controller has `[Route("api/orders")]` and an action has `[HttpGet("/refunds")]` (leading slash), the leading slash makes it an absolute path — the controller prefix is ignored and the route becomes `/refunds`. Leading slashes on action attributes are a silent override, not a relative path.

- **Conventional routing is registered with `MapControllerRoute`, attribute routing with `MapControllers` — they are not the same call.** Using `MapControllerRoute` without defining `[Route]` attributes and then adding `[HttpGet]` to actions produces a 404 because the conventional route template doesn't match what attribute routing expects. In Web API projects, always use `MapControllers()`.

- **Route matching is case-insensitive by default, but route parameter names are case-sensitive in binding.** `/api/Orders/42` and `/api/orders/42` match the same route, but if your action parameter is `Id` and you specify `[HttpGet("{id}")]`, the binding works because parameter binding is also case-insensitive. The confusion arises with custom model binders that use exact casing.

- **Ambiguous route exceptions surface at request time, not at startup (in most cases).** If two routes match the same URL pattern with the same HTTP method, ASP.NET Core throws `AmbiguousMatchException` when the first request arrives. Adding route constraints (`:int`, `:guid`) is the correct fix. In .NET 7+ with route groups, some ambiguity is detected at startup.

- **`[ApiController]` changes 404 vs 400 behaviour for route vs body binding failures.** Without `[ApiController]`, a missing required route parameter silently passes `null` or default and your action runs with bad data. With it, the framework automatically returns 400 before your action is called. This is almost always what you want, but it can surprise you in tests where you expect your action to handle missing data itself.

- **`HttpContext.GetEndpoint()` returns `null` between `UseRouting` and endpoint execution.** Actually, it returns the matched endpoint *after* `UseRouting` sets it. Middleware between `UseRouting` and `MapControllers` can inspect endpoint metadata (auth policies, route name) by calling `context.GetEndpoint()`. Middleware placed *before* `UseRouting` cannot.

---

## Interview Angle

**What they're really testing:** Whether you understand the request pipeline well enough to reason about routing failures, and whether you know the difference between conventional and attribute routing at a mechanical level.

**Common question forms:**
- "Why is my route returning 404?"
- "How would you version a REST API?"
- "What's the difference between `[Route]` and `[HttpGet]`?"
- "How does route matching work when two routes could match the same URL?"

**The depth signal:** A junior knows that `[HttpGet("{id}")]` maps a GET with a URL parameter. A senior can explain the full matching pipeline: `UseRouting()` builds the candidate set, `UseAuthorization()` runs in between and can see endpoint metadata, and `MapControllers()` executes the match — and that putting middleware in the wrong order means auth runs before routing resolves the endpoint, so `HttpContext.GetEndpoint()` returns null and `[Authorize]` metadata is invisible. They also know how `LinkGenerator` produces URLs from route names programmatically without hardcoding strings, and why `[Route("~/absolute")]` exists.

**Follow-up questions to expect:**
- "How do you resolve a conflict between two routes that match the same URL?"
- "What's the difference between `MapControllers()` and `MapControllerRoute()`?"
- "How would you generate a URL to another action programmatically?"

---

## Related Topics

- [[dotnet/webapi/webapi-model-binding.md]] — route parameters, query strings, and body are all part of model binding; routing determines which action runs, binding determines what values it receives
- [[dotnet/webapi/middleware-pipeline.md]] — routing is middleware; the order of `UseRouting`, `UseAuthentication`, and `MapControllers` determines what endpoint metadata is available to each middleware
- [[dotnet/webapi/webapi-versioning.md]] — API versioning builds on top of routing; understanding route constraints and route templates is prerequisite
- [[dotnet/webapi/webapi-minimal-apis.md]] — minimal APIs use the same routing engine as controllers but with a different registration syntax; the constraints and matching rules are identical

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/fundamentals/routing

---
*Last updated: 2026-04-10*