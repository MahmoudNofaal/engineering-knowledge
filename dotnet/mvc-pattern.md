# MVC Pattern

> An architectural pattern that splits an application into three responsibilities — Model (data), View (UI), and Controller (request handling) — so each layer can change independently.

---

## When To Use It

Use MVC when you're building a server-rendered web application that returns HTML — think admin panels, dashboards, or any app where the server owns the page rendering. In ASP.NET Core, MVC also works well as the backbone for Web APIs, though Minimal APIs are now the lighter-weight alternative for pure JSON endpoints. Don't use the full MVC stack if you're building a pure API consumed by a SPA or mobile client — you get the View machinery for free but never use it, and Minimal APIs or controller-based Web APIs without views are a cleaner fit.

---

## Core Concept

MVC enforces a one-way flow: a request hits the router, the router picks a Controller action, the action talks to the Model (your domain logic, services, data), and then hands a result to the View for rendering. The Controller is intentionally thin — it translates HTTP into method calls and then hands off. It should not contain business logic. The Model is not just a database row; it's the entire domain layer including services, repositories, and validation. The View only knows how to render what it's given — it never fetches its own data. When each layer respects this contract, you can swap a Razor view for a JSON response or replace a repository with a mock without touching the other two layers.

---

## The Code

**1. Minimal MVC setup in Program.cs**
```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews(); // registers MVC with Razor view support
// Use AddControllers() instead if you only want API controllers with no views

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

// Default route: /{controller=Home}/{action=Index}/{id?}
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
```

**2. A thin controller — no business logic**
```csharp
// Controllers/ProductsController.cs
public class ProductsController(IProductService productService) : Controller
{
    [HttpGet]
    public async Task<IActionResult> Index()
    {
        var products = await productService.GetAllAsync();
        return View(products); // passes model to Views/Products/Index.cshtml
    }

    [HttpGet]
    public async Task<IActionResult> Details(int id)
    {
        var product = await productService.GetByIdAsync(id);

        if (product is null)
            return NotFound();

        return View(product);
    }

    [HttpPost]
    [ValidateAntiForgeryToken] // protects against CSRF on POST actions
    public async Task<IActionResult> Create(CreateProductDto dto)
    {
        if (!ModelState.IsValid)
            return View(dto); // re-render form with validation errors

        await productService.CreateAsync(dto);
        return RedirectToAction(nameof(Index)); // Post-Redirect-Get pattern
    }
}
```

**3. A typed Razor view (Views/Products/Index.cshtml)**
```html
@model IEnumerable<Product>

<h1>Products</h1>

@foreach (var product in Model)
{
    <div>
        <h2>@product.Name</h2>
        <p>@product.Price.ToString("C")</p>
        <a asp-action="Details" asp-route-id="@product.Id">View</a>
    </div>
}

<a asp-action="Create">Add Product</a>
```

**4. Returning JSON from a controller action (same controller, different result)**
```csharp
// The same controller can serve both HTML and JSON depending on the action
[HttpGet("api/products")]
public async Task<IActionResult> GetJson()
{
    var products = await productService.GetAllAsync();
    return Json(products); // Content-Type: application/json
}
```

**5. ViewModels — never pass domain entities directly to views**
```csharp
// ViewModels/ProductViewModel.cs
// Shapes data specifically for the view — no EF navigation properties,
// no fields the view doesn't need, no fields you don't want exposed
public class ProductViewModel
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string FormattedPrice { get; set; } = string.Empty;
    public bool IsInStock { get; set; }
}

// In the controller action
var viewModel = new ProductViewModel
{
    Id             = product.Id,
    Name           = product.Name,
    FormattedPrice = product.Price.ToString("C"),
    IsInStock      = product.Stock > 0
};
return View(viewModel);
```

---

## Gotchas

- **Returning a domain entity directly to a view exposes fields you didn't intend to.** If your `Product` entity has navigation properties (e.g. `ICollection<OrderItem>`), serializing or binding it in a view can trigger lazy-load queries or serialize data you never meant to expose. Always project to a ViewModel before passing to the view.
- **`ModelState.IsValid` only validates data annotations on the input model — it does not run business rules.** A `[Required]` attribute failing sets `ModelState.IsValid = false`, but a duplicate product name or an invalid business rule won't. Check `ModelState` for input shape, run business validation in the service layer separately.
- **Missing `[ValidateAntiForgeryToken]` on POST actions is a CSRF vulnerability.** Razor forms include a hidden `__RequestVerificationToken` field automatically, but the controller must have the attribute to actually validate it. Skipping it on state-changing actions (Create, Edit, Delete) leaves those endpoints open to cross-site request forgery.
- **The default route `{controller}/{action}/{id?}` means controller and action names are part of your public URL contract.** Renaming `ProductsController` or its action methods breaks existing URLs and bookmarks. Once an MVC app is in production, treat those names like a public API — or use attribute routing (`[Route(...)]`) to decouple the URL from the class name.
- **`RedirectToAction` after a successful POST is not optional — it's the Post-Redirect-Get (PRG) pattern.** If you return `View()` directly after a successful POST, a browser refresh re-submits the form. `RedirectToAction` forces a GET, so a refresh just reloads the result page. Skipping PRG leads to duplicate form submissions.

---

## Interview Angle

**What they're really testing:** Whether you understand separation of concerns — specifically that the Controller should be thin, the Model is the domain layer (not just a database row), and the View is purely presentational.

**Common question form:** *"Explain the MVC pattern"* or *"What goes in a Controller vs a Service in MVC?"*

**The depth signal:** A junior answer describes the three layers and their names. A senior answer explains why Controllers must be thin (HTTP translation only, no business logic), why you project to ViewModels instead of passing entities to views (to avoid over-posting, lazy-load queries, and accidental data exposure), the Post-Redirect-Get pattern and why returning a View directly after POST causes duplicate submissions, and the CSRF implications of missing `[ValidateAntiForgeryToken]` on POST actions. Bonus: distinguishing when to use full MVC vs Minimal APIs vs controller-based Web APIs.

---

## Related Topics

- [[dotnet/dependency-injection.md]] — Controllers receive services (the Model layer) through constructor injection; understanding DI lifetimes explains why `DbContext` should be scoped, not singleton.
- [[dotnet/webapi-exception-handling.md]] — Unhandled exceptions in controller actions need a global handler; MVC and Web API share the same exception handling middleware.
- [[dotnet/middleware-pipeline.md]] — MVC routing (`MapControllerRoute`) is the last step in the middleware pipeline; understanding the pipeline explains why auth middleware must come before controllers.
- [[dotnet/webapi-authentication.md]] — `[Authorize]` works identically on MVC controllers and Web API controllers; the authentication middleware is shared between both.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/overview

---
*Last updated: 2026-03-24*