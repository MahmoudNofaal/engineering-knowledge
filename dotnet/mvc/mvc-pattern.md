# MVC Pattern

> An architectural pattern that splits an application into three responsibilities — Model (data), View (UI), and Controller (request handling) — so each layer can change independently.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Three-layer request/response architecture |
| **Use when** | Building server-rendered HTML web apps |
| **Avoid when** | Pure JSON APIs, SPA backends, Minimal API fits |
| **Introduced** | ASP.NET Core 1.0 (.NET Core 1.0, 2016) |
| **Namespace** | `Microsoft.AspNetCore.Mvc` |
| **Key types** | `Controller`, `ControllerBase`, `IActionResult`, `ViewResult` |

---

## When To Use It

Use MVC when you're building a server-rendered web application that returns HTML — admin panels, dashboards, or any app where the server owns the page rendering. In ASP.NET Core, MVC also works well as the backbone for Web APIs, though Minimal APIs are now the lighter-weight alternative for pure JSON endpoints. Don't use the full MVC stack if you're building a pure API consumed by a SPA or mobile client — you get the View machinery for free but never use it, and Minimal APIs or controller-based Web APIs without views are a cleaner fit. Consider Razor Pages instead of MVC when each page maps cleanly to a single file and the controller-action-view split feels like overhead.

---

## Core Concept

MVC enforces a one-way flow: a request hits the router, the router picks a Controller action, the action talks to the Model (your domain logic, services, data), and then hands a result to the View for rendering. The Controller is intentionally thin — it translates HTTP into method calls and then hands off. It should not contain business logic. The Model is not just a database row; it's the entire domain layer including services, repositories, and validation. The View only knows how to render what it's given — it never fetches its own data.

When each layer respects this contract, you can swap a Razor view for a JSON response or replace a repository with a mock without touching the other two layers. The separation also has a testing payoff: a thin controller that delegates to a service is easy to unit test because there's no HTTP context to fake and no database to stub — just a plain method call with a plain return value.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | MVC and Web API unified into a single framework (`Microsoft.AspNetCore.Mvc`) |
| ASP.NET Core 2.1 | .NET Core 2.1 | Razor Pages introduced as a page-centric alternative to MVC |
| ASP.NET Core 3.0 | .NET Core 3.0 | Endpoint routing replaces route middleware; `app.UseMvc()` deprecated in favour of `app.UseRouting()` + `app.MapControllerRoute()` |
| ASP.NET Core 6.0 | .NET 6 | Minimal APIs introduced as a lightweight alternative; `Program.cs` top-level statements replace `Startup.cs` |
| ASP.NET Core 7.0 | .NET 7 | `[ApiController]` problem details format standardised (RFC 7807) |
| ASP.NET Core 8.0 | .NET 8 | Native AoT publishing support; `IExceptionHandler` interface added |

*Before ASP.NET Core 1.0, MVC and Web API were separate frameworks (`System.Web.Mvc` and `System.Web.Http`) that shared almost nothing. Unifying them into `Microsoft.AspNetCore.Mvc` meant one pipeline, one filter model, and one routing system for both HTML and JSON responses.*

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
```cshtml
@model IEnumerable<ProductViewModel>

@{
    ViewData["Title"] = "Products";
}

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
    public int    Id             { get; set; }
    public string Name           { get; set; } = string.Empty;
    public string FormattedPrice { get; set; } = string.Empty;
    public bool   IsInStock      { get; set; }
}

// In the controller action:
var viewModel = new ProductViewModel
{
    Id             = product.Id,
    Name           = product.Name,
    FormattedPrice = product.Price.ToString("C"),
    IsInStock      = product.Stock > 0
};
return View(viewModel);
```

**6. Post-Redirect-Get (PRG) — the correct POST handling pattern**
```csharp
[HttpPost]
[ValidateAntiForgeryToken]
public async Task<IActionResult> Create(CreateProductDto dto)
{
    if (!ModelState.IsValid)
        return View(dto); // re-render form — NOT a redirect, ModelState errors needed

    await productService.CreateAsync(dto);

    // Redirect after successful POST — prevents duplicate submission on browser refresh
    TempData["SuccessMessage"] = "Product created successfully.";
    return RedirectToAction(nameof(Index));
}

// Index reads TempData — available for exactly one request after the redirect
[HttpGet]
public async Task<IActionResult> Index()
{
    var products = await productService.GetAllAsync();
    return View(products);
    // In the view: @TempData["SuccessMessage"]
}
```

**7. Areas — organising large apps into sub-sections**
```csharp
// Program.cs — add area route before the default route
app.MapControllerRoute(
    name: "areas",
    pattern: "{area:exists}/{controller=Home}/{action=Index}/{id?}");

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");
```
```csharp
// Controllers/Admin/ProductsController.cs
[Area("Admin")]
[Authorize(Roles = "Admin")]
public class ProductsController(IProductService productService) : Controller
{
    // Accessible at /admin/products
    public async Task<IActionResult> Index() =>
        View(await productService.GetAllAsync());
}
```

---

## Real World Example

An internal stock management portal for a warehouse team. The team needs a server-rendered interface — they're on shared terminals, no SPA overhead, no API client to maintain. MVC was chosen over Razor Pages because multiple controllers share filters and the URL structure maps naturally to controller/action conventions.

```csharp
// Controllers/InventoryController.cs
[Authorize(Policy = "WarehouseStaff")]
public class InventoryController(
    IInventoryService inventoryService,
    ISupplierService  supplierService) : Controller
{
    [HttpGet]
    public async Task<IActionResult> Reorder(int productId)
    {
        var product  = await inventoryService.GetProductAsync(productId);
        var suppliers = await supplierService.GetApprovedSuppliersAsync(product.CategoryId);

        if (product is null)
            return NotFound();

        // ViewModel combines data from two services — the view gets exactly what it needs
        var vm = new ReorderViewModel
        {
            ProductId      = product.Id,
            ProductName    = product.Name,
            CurrentStock   = product.StockLevel,
            ReorderLevel   = product.ReorderThreshold,
            SupplierOptions = suppliers.Select(s => new SelectListItem(s.Name, s.Id.ToString()))
        };

        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Reorder(ReorderViewModel vm)
    {
        if (!ModelState.IsValid)
        {
            // Re-populate the supplier list — it doesn't survive the POST roundtrip
            var product  = await inventoryService.GetProductAsync(vm.ProductId);
            vm.SupplierOptions = (await supplierService
                .GetApprovedSuppliersAsync(product.CategoryId))
                .Select(s => new SelectListItem(s.Name, s.Id.ToString()));

            return View(vm);
        }

        var orderId = await inventoryService.PlaceReorderAsync(
            vm.ProductId, vm.SupplierId, vm.Quantity);

        TempData["Confirmation"] = $"Order #{orderId} placed with supplier.";
        return RedirectToAction(nameof(Dashboard));
    }

    [HttpGet]
    public async Task<IActionResult> Dashboard()
        => View(await inventoryService.GetDashboardAsync());
}
```

*The key insight here: the POST handler has to re-populate `SupplierOptions` before returning `View(vm)` on validation failure, because the dropdown options are not submitted with the form — only the selected value is. Forgetting this is one of the most common MVC bugs in real codebases. The ViewModel carries both the form data and the UI rendering data, so when model state fails, you need to rebuild the rendering data before handing back to the view.*

---

## Common Misconceptions

**"The Model in MVC is just the database entity / EF Core model"**
The Model layer is your entire domain — services, repositories, business rules, and validation logic. An EF Core entity is one small piece of the Model layer, not the whole thing. When people equate "Model" with "database row" they end up putting business logic in controllers, which makes testing hard and violates the separation MVC is designed to enforce.

**"MVC and Web API are different things in ASP.NET Core"**
They were separate frameworks in ASP.NET 4.x (`System.Web.Mvc` vs `System.Web.Http`). In ASP.NET Core they are the same framework — `Microsoft.AspNetCore.Mvc`. A controller inheriting `Controller` can return both `View()` and `Json()`. A controller inheriting `ControllerBase` skips view support but uses the identical routing, model binding, and filter pipeline. The split is a class hierarchy detail, not a framework boundary.

**"You should always use MVC over Razor Pages for serious apps"**
Razor Pages are not a simplified or junior version of MVC. They're a different page-centric model that collocates the handler and the view in one file. For page-focused workflows — CRUD screens, settings pages, forms — Razor Pages are often cleaner than MVC because there's no artificial controller-action-view split for operations that are inherently single-page. Large apps often use both: MVC for complex multi-step workflows and APIs, Razor Pages for straightforward CRUD.

```csharp
// Razor Pages equivalent of a simple Index + Create workflow —
// no controller class needed, handler is directly on the PageModel
public class ProductsModel : PageModel
{
    [BindProperty]
    public CreateProductDto Input { get; set; } = new();

    public IEnumerable<ProductViewModel> Products { get; set; } = [];

    public async Task OnGetAsync()
        => Products = await _productService.GetAllAsync();

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();
        await _productService.CreateAsync(Input);
        return RedirectToPage();
    }
}
```

---

## Gotchas

- **Returning a domain entity directly to a view exposes fields you didn't intend to.** If your `Product` entity has navigation properties (e.g. `ICollection<OrderItem>`), serializing or binding it in a view can trigger lazy-load queries or serialize data you never meant to expose. Always project to a ViewModel before passing to the view.

- **`ModelState.IsValid` only validates data annotations on the input model — it does not run business rules.** A `[Required]` attribute failing sets `ModelState.IsValid = false`, but a duplicate product name or an invalid business rule won't. Check `ModelState` for input shape; run business validation in the service layer separately.

- **Missing `[ValidateAntiForgeryToken]` on POST actions is a CSRF vulnerability.** Razor forms include a hidden `__RequestVerificationToken` field automatically, but the controller must have the attribute to actually validate it. Skipping it on state-changing actions (Create, Edit, Delete) leaves those endpoints open to cross-site request forgery.

- **The default route `{controller}/{action}/{id?}` means controller and action names are part of your public URL contract.** Renaming `ProductsController` or its action methods breaks existing URLs and bookmarks. Once an MVC app is in production, treat those names like a public API — or use attribute routing (`[Route(...)]`) to decouple the URL from the class name.

- **`RedirectToAction` after a successful POST is not optional — it's the Post-Redirect-Get (PRG) pattern.** If you return `View()` directly after a successful POST, a browser refresh re-submits the form. `RedirectToAction` forces a GET, so a refresh just reloads the result page. Skipping PRG leads to duplicate form submissions.

- **Dropdown options and other UI lists in ViewModels are not submitted with the form and must be rebuilt on POST failure.** Only input field values come back in the POST body. If your ViewModel has a `SelectList CategoryOptions` for a dropdown, it will be null when the model binding runs on POST. You must re-populate it before returning `View(vm)` when `ModelState.IsValid` is false — forgetting this causes a `NullReferenceException` on the re-rendered page.

---

## Interview Angle

**What they're really testing:** Whether you understand separation of concerns — specifically that the Controller should be thin, the Model is the domain layer (not just a database row), and the View is purely presentational.

**Common question forms:**
- *"Explain the MVC pattern"*
- *"What goes in a Controller vs a Service in MVC?"*
- *"Why do we use ViewModels instead of passing entities directly to views?"*
- *"What is Post-Redirect-Get and why does it matter?"*

**The depth signal:** A junior answer describes the three layers and their names. A senior answer explains why Controllers must be thin (HTTP translation only, no business logic), why you project to ViewModels instead of passing entities to views (to avoid over-posting, lazy-load queries, and accidental data exposure), the Post-Redirect-Get pattern and why returning a View directly after POST causes duplicate submissions, and the CSRF implications of missing `[ValidateAntiForgeryToken]` on POST actions. Bonus: distinguishing when to use full MVC vs Razor Pages vs Minimal APIs vs controller-based Web APIs, and explaining that MVC and Web API share the same framework in ASP.NET Core.

**Follow-up questions to expect:**
- *"How is ASP.NET Core MVC different from ASP.NET 4.x MVC?"* (unified pipeline, no `System.Web` dependency)
- *"When would you pick Razor Pages over MVC?"* (page-centric CRUD vs complex multi-step workflows)

---

## Related Topics

- [[dotnet/dependency-injection.md]] — Controllers receive services (the Model layer) through constructor injection; understanding DI lifetimes explains why `DbContext` should be scoped, not singleton.
- [[dotnet/webapi-exception-handling.md]] — Unhandled exceptions in controller actions need a global handler; MVC and Web API share the same exception handling middleware.
- [[dotnet/middleware-pipeline.md]] — MVC routing (`MapControllerRoute`) is the last step in the middleware pipeline; understanding the pipeline explains why auth middleware must come before controllers.
- [[dotnet/webapi-authentication.md]] — `[Authorize]` works identically on MVC controllers and Web API controllers; the authentication middleware is shared between both.
- [[dotnet/mvc/mvc-controllers.md]] — Deep dive into controller internals: model binding sources, `ActionResult<T>` vs `IActionResult`, action filters, and route constraints.
- [[dotnet/mvc/mvc-models.md]] — Entities, DTOs, and ViewModels in detail; the mass assignment vulnerability that comes from binding request bodies directly to domain entities.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/overview

---
*Last updated: 2026-04-09*