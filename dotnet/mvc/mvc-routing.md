# MVC Routing

> The ASP.NET Core system that matches incoming HTTP request URLs to controller action methods — using either convention-based route templates defined in `Program.cs` or attribute-based routes declared directly on controllers and actions.

---

## Quick Reference

| | |
|---|---|
| **What it is** | URL → controller action mapping system |
| **Use when** | Always — every MVC controller action is reached via routing |
| **Two styles** | Convention-based (`MapControllerRoute`) vs attribute-based (`[Route]`, `[HttpGet]`) |
| **Namespace** | `Microsoft.AspNetCore.Mvc`, `Microsoft.AspNetCore.Routing` |
| **Key attributes** | `[Route]`, `[HttpGet]`, `[HttpPost]`, `[HttpPut]`, `[HttpDelete]`, `[HttpPatch]` |
| **Route generation** | `Url.Action()`, `Url.RouteUrl()`, Tag Helper `asp-action` / `asp-controller` |

---

## When To Use It

Routing is always in play — there's no MVC without it. The question is which style to use. Convention-based routing (one template in `Program.cs`) works well for traditional HTML-returning MVC apps where the `/{controller}/{action}/{id?}` pattern fits most URLs naturally. Attribute routing is better for APIs where URL design is intentional and doesn't map cleanly to controller/action names, or where fine-grained control over HTTP methods and route parameters matters. Most real-world apps use convention-based routing for MVC views and attribute routing for API controllers — and they can coexist in the same project.

---

## Core Concept

When a request arrives, the routing middleware walks the registered route templates in order and finds the first match. For convention-based routes, templates are defined once in `Program.cs` with named segments (`{controller}`, `{action}`, `{id?}`) that the framework maps to controller and action names automatically. For attribute routing, each controller and action declares its own template — the framework builds a combined route table at startup from all the `[Route]` and `[Http*]` attributes it finds.

Route constraints narrow which URLs match a template: `{id:int}` only matches if the segment is an integer, `{slug:minlength(3)}` only matches slugs of three or more characters. The constraint affects routing — a non-matching constraint causes a 404, not a validation error. Route values extracted from matching templates are placed in `RouteData` and become available to model binding (as `[FromRoute]` values).

Link generation — producing a URL from a controller + action name — is the reverse process. The framework walks the route table to find a template that produces the right URL. Tag Helpers (`asp-action`, `asp-controller`) and `Url.Action()` use this same system. If no route matches the supplied action + controller, link generation returns null — a silent failure that produces broken links.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | Convention and attribute routing introduced; route constraints |
| ASP.NET Core 2.2 | .NET Core 2.2 | Endpoint routing introduced as opt-in (`UseEndpointRouting`) |
| ASP.NET Core 3.0 | .NET Core 3.0 | Endpoint routing becomes the default; `app.UseMvc()` deprecated in favour of `app.UseRouting()` + `app.UseEndpoints()` |
| ASP.NET Core 3.0 | .NET Core 3.0 | `[ApiController]` attribute routing inferred — `[Route]` on the class required |
| ASP.NET Core 5.0 | .NET 5 | `app.UseEndpoints()` simplified to `app.MapControllers()` / `app.MapControllerRoute()` |
| ASP.NET Core 6.0 | .NET 6 | Route groups and `MapGroup()` introduced for Minimal APIs |
| ASP.NET Core 7.0 | .NET 7 | Route constraints extended; `{**slug}` catch-all improvements |

*Before ASP.NET Core 2.2, routing was tightly coupled to the MVC middleware — you couldn't use routing metadata outside of MVC. Endpoint routing decoupled the route matching step from the MVC execution step, which is why middleware (like auth) can now see route data before MVC runs.*

---

## The Code

**1. Convention-based routing — defined once in Program.cs**
```csharp
// Program.cs
app.MapControllerRoute(
    name:    "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

// Examples of what this matches:
// /                         → HomeController.Index()
// /products                 → ProductsController.Index()
// /products/details/5       → ProductsController.Details(id: 5)
// /products/details/abc     → ProductsController.Details(id: "abc") if id is string
```

**2. Multiple convention routes — more specific first**
```csharp
// More specific routes must come before more general ones
app.MapControllerRoute(
    name:    "blog",
    pattern: "blog/{year:int}/{month:int}/{slug}",
    defaults: new { controller = "Blog", action = "Post" });

app.MapControllerRoute(
    name:    "areas",
    pattern: "{area:exists}/{controller=Home}/{action=Index}/{id?}");

app.MapControllerRoute(
    name:    "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");
```

**3. Attribute routing on API controllers**
```csharp
[ApiController]
[Route("api/[controller]")]   // [controller] token = "products" (class name minus "Controller")
public class ProductsController : ControllerBase
{
    [HttpGet]                         // GET  api/products
    public IActionResult GetAll() => Ok();

    [HttpGet("{id:int}")]             // GET  api/products/5
    public IActionResult GetById(int id) => Ok();

    [HttpGet("{id:int}/variants")]    // GET  api/products/5/variants
    public IActionResult GetVariants(int id) => Ok();

    [HttpPost]                        // POST api/products
    public IActionResult Create() => Ok();

    [HttpPut("{id:int}")]             // PUT  api/products/5
    public IActionResult Update(int id) => Ok();

    [HttpDelete("{id:int}")]          // DELETE api/products/5
    public IActionResult Delete(int id) => Ok();
}
```

**4. Route constraints — narrowing which URLs match**
```csharp
[HttpGet("{id:int}")]               // only matches integers: /products/5 ✓  /products/abc ✗
[HttpGet("{id:guid}")]              // only matches GUIDs
[HttpGet("{name:minlength(3)}")]    // only matches strings of 3+ chars
[HttpGet("{name:maxlength(50)}")]
[HttpGet("{age:range(18,120)}")]    // only matches integers in range
[HttpGet("{code:alpha}")]           // only matches alphabetic strings
[HttpGet("{id:int:min(1)}")]        // combinable — int AND ≥ 1
[HttpGet("{version:regex(^v\\d+$)}")] // regex constraint

// Route with optional segment
[HttpGet("products/{id:int?}")]     // id is optional — matches /products and /products/5

// Catch-all — matches the rest of the path including slashes
[HttpGet("files/{**path}")]         // matches /files/docs/2024/report.pdf
```

**5. Named routes — used for URL generation**
```csharp
[HttpGet("{id:int}", Name = "GetProductById")]
public IActionResult GetById(int id) => Ok();

// Generate a URL to this named route
var url = Url.RouteUrl("GetProductById", new { id = 5 });
// url = "/api/products/5"

// Used in CreatedAtRoute
return CreatedAtRoute("GetProductById", new { id = created.Id }, created);
```

**6. Route tokens — [controller], [action], [area]**
```csharp
[Route("api/[controller]")]          // expands to "api/products" for ProductsController
[Route("[area]/[controller]/[action]")] // expands based on area, controller, and action names

// Suppress the token to use a literal name
[Route("api/catalogue")]             // always "api/catalogue" regardless of class name
```

**7. Convention vs attribute routing for MVC views**
```csharp
// Convention-based — works automatically with the default route
// Views/Products/Index.cshtml rendered by ProductsController.Index()
// URL: /products or /products/index

// Per-action attribute override — convention route still applies to other actions
public class ProductsController : Controller
{
    [HttpGet("shop/all-products")]   // custom URL for this action only
    public IActionResult Index() => View();

    public IActionResult Details(int id) => View(); // still uses convention route → /products/details/5
}
```

**8. Link generation — Tag Helpers and Url.Action()**
```cshtml
@* Tag Helper generates href from route table *@
<a asp-controller="Products" asp-action="Details" asp-route-id="5">View</a>
@* Output: <a href="/products/details/5">View</a> *@

@* With attribute routing — asp-route-* maps to route parameters *@
<a asp-controller="Products" asp-action="GetById" asp-route-id="5">View</a>
@* Output: <a href="/api/products/5">View</a> *@

@* Extra values not in the route become query string *@
<a asp-controller="Products" asp-action="Search"
   asp-route-keyword="chair" asp-route-page="2">Search</a>
@* Output: <a href="/products/search?keyword=chair&page=2">Search</a> *@
```

```csharp
// Url.Action() in controller code
var url = Url.Action("Details", "Products", new { id = 5 });
// url = "/products/details/5"

// Absolute URL with scheme and host
var absoluteUrl = Url.Action("Details", "Products", new { id = 5 }, Request.Scheme);
// url = "https://myapp.com/products/details/5"
```

---

## Real World Example

An e-commerce site with three routing contexts: a public storefront using convention routing, an API surface using attribute routing, and an admin area using area-based convention routing. All three coexist in the same `Program.cs`.

```csharp
// Program.cs
var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

// 1. API controllers — use attribute routing declared on the controllers themselves
app.MapControllers();

// 2. Admin area — convention routing scoped to the Admin area
app.MapControllerRoute(
    name:    "admin",
    pattern: "admin/{controller=Dashboard}/{action=Index}/{id?}",
    defaults: new { area = "Admin" },
    constraints: new { area = "Admin" });

// 3. Storefront — default convention routing
app.MapControllerRoute(
    name:    "product-slug",
    pattern: "shop/{category}/{slug}",
    defaults: new { controller = "Products", action = "BySlug" });

app.MapControllerRoute(
    name:    "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");
```

```csharp
// Controllers/Api/OrdersController.cs — attribute-routed API
[ApiController]
[Route("api/v{version:int}/orders")]  // versioned API URL: /api/v1/orders
[Authorize]
public class OrdersController : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] OrderFilterDto filter) => Ok();

    [HttpGet("{orderId:guid}", Name = "GetOrderById")]
    public async Task<IActionResult> GetById(Guid orderId) => Ok();

    [HttpPost]
    public async Task<IActionResult> Create(CreateOrderDto dto)
    {
        // Link generation using the named route
        var order = await orderService.CreateAsync(dto);
        return CreatedAtRoute("GetOrderById", new { orderId = order.Id, version = 1 }, order);
    }
}

// Controllers/ProductsController.cs — convention-routed storefront
public class ProductsController : Controller
{
    // Matched by the "product-slug" route: /shop/electronics/samsung-tv-55
    public async Task<IActionResult> BySlug(string category, string slug)
    {
        var product = await productService.GetBySlugAsync(category, slug);
        if (product is null) return NotFound();
        return View(product);
    }

    // Matched by default convention route: /products/details/5
    public async Task<IActionResult> Details(int id) => View(await productService.GetAsync(id));
}
```

*The key insight: `MapControllers()` handles all attribute-routed API controllers in one call. The area route and default convention route handle the MVC views. The three systems don't conflict because the API controllers use attribute routing (no convention route matches `/api/...` format), the admin area matches only `/admin/...` URLs, and the storefront handles everything else. Route specificity matters — `product-slug` is registered before `default` so `/shop/electronics/samsung-tv-55` matches the slug route, not the default.*

---

## Common Misconceptions

**"Convention routing and attribute routing can't be used in the same project"**
They coexist cleanly. The common pattern is exactly what the real world example shows: attribute routing on `[ApiController]` controllers (via `MapControllers()`), convention routing for MVC view controllers (via `MapControllerRoute()`). The framework matches routes in the order they're registered, so conflicts are resolved by ordering.

**"Route constraints validate user input and return 400 on mismatch"**
Route constraints affect route matching, not input validation. `{id:int}` means "this route only matches URLs where `id` is an integer." If the URL is `/products/abc`, the route doesn't match at all and the framework returns 404 — it doesn't try to bind `abc` and return a 400 validation error. The 400 behaviour only happens if binding runs and fails, which requires the route to match first.

**"[Route] on a controller replaces the default convention route for that controller"**
`[Route]` on a controller opts that controller into attribute routing — the convention routes defined in `Program.cs` no longer apply to it. This is intentional but can be surprising. If you add `[Route("api/[controller]")]` to a controller that was previously reached via `/products`, the `/products` URL stops working because the convention route no longer applies.

---

## Gotchas

- **Convention routes are matched in the order they're registered — more specific routes must come before more general ones.** The default `{controller}/{action}/{id?}` route matches almost anything. If it's registered before a more specific route like `blog/{year}/{month}/{slug}`, the specific route never matches. Always register specific routes first.

- **Link generation returns null if no route matches.** `Url.Action("Details", "Products", new { id = 5 })` returns `null` if the routing system can't find a template that produces that URL. `asp-action` in a Tag Helper produces an empty `href=""` in the same case. This is a silent failure — no exception, just a broken link. Test link generation in views, don't assume it works.

- **`[ApiController]` requires attribute routing — convention routes don't apply.** Controllers decorated with `[ApiController]` must have a `[Route]` attribute (on the class or every action). If you add `[ApiController]` to a convention-routed controller and remove the `[Route]` attributes, all actions return 404 because the convention route no longer applies.

- **The `[controller]` token in `[Route("api/[controller]")]` is the class name minus "Controller" — renaming the class changes the URL.** `ProductsController` produces `api/products`. Renaming to `CatalogueController` changes the URL to `api/catalogue`. If the old URL was public, this is a breaking change. Use a literal route string (`[Route("api/products")]`) to decouple the URL from the class name.

- **Area routes require both the controller attribute `[Area("Admin")]` AND a route template that includes the area.** If you add `[Area("Admin")]` to a controller but don't register an area route in `Program.cs`, the controller's actions are unreachable. Both sides of the configuration must be in place.

- **Catch-all parameters (`{**path}`) must be the last segment in a route template.** `{**path}/suffix` is invalid. Catch-alls consume the rest of the URL including slashes — nothing can follow them.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between convention and attribute routing, how route matching order affects URL resolution, and how link generation works (and fails silently).

**Common question forms:**
- *"What's the difference between convention-based and attribute-based routing?"*
- *"Why does my route return 404 — is it a routing issue or a model binding issue?"*
- *"How do route constraints work?"*

**The depth signal:** A junior answer describes `[HttpGet]`, `[Route]`, and the default `{controller}/{action}/{id?}` convention. A senior answer explains that convention and attribute routing coexist and are typically used together (API controllers → attribute, MVC view controllers → convention), the route matching order (specific before general, first match wins), why route constraints return 404 rather than 400 (they affect matching, not validation), that `[ApiController]` requires attribute routing and disables convention routes for that controller, and that link generation silently returns null when no route matches — producing broken links without an exception.

**Follow-up questions to expect:**
- *"How do you generate an absolute URL (with scheme and host) from a controller?"* (`Url.Action("Action", "Controller", routeValues, Request.Scheme)`)
- *"What happens if you rename a controller class that has `[Route("api/[controller]")]`?"* (the URL changes — breaking change — use a literal route to avoid coupling)

---

## Related Topics

- [[dotnet/mvc/mvc-controllers.md]] — Route templates are declared on controllers and actions; `[ApiController]` changes how attribute routing behaves.
- [[dotnet/mvc/mvc-pattern.md]] — Routing is the first step in the MVC request lifecycle; understanding the full flow from URL to action clarifies where routing fits.
- [[dotnet/mvc/mvc-areas.md]] — Areas add a namespace layer to routing; controllers in an area use a different route prefix and require area-specific route registration.
- [[dotnet/webapi/middleware-pipeline.md]] — `app.UseRouting()` is a middleware step; endpoint routing separates route matching from action execution, which is why auth middleware can access route data before the action runs.
- [[dotnet/mvc/mvc-model-binding.md]] — Route values extracted by routing are made available to model binding as `[FromRoute]` values; routing and binding are closely coupled.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/routing

---
*Last updated: 2026-04-09*