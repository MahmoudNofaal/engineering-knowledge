# MVC View Components

> Self-contained, reusable UI fragments in ASP.NET Core MVC that fetch their own data and render independently — the right tool when a partial view would need to call a service to populate itself.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Reusable UI component with its own data-fetching logic and Razor template |
| **Use when** | A UI fragment needs its own data that the parent controller shouldn't be responsible for |
| **Avoid when** | The parent already has the data — pass it to a partial view instead |
| **Base class** | `ViewComponent` |
| **Namespace** | `Microsoft.AspNetCore.Mvc` |
| **Key types** | `ViewComponent`, `IViewComponentHelper`, `ViewComponentResult` |
| **Invocation** | `@await Component.InvokeAsync("Name")` or `<vc:name />` Tag Helper syntax |

---

## When To Use It

Use View Components when a section of UI needs to fetch its own data from a service or repository — things like a shopping cart count in the nav bar, a "recently viewed" sidebar, a notification badge, or a dynamic breadcrumb trail. These are components that appear on many pages but aren't driven by the current page's controller action. If the parent controller already fetches the data and passes it to the view, use a partial view instead — View Components exist specifically to avoid polluting every controller action with unrelated data-fetching logic. Don't use View Components as a replacement for full page controllers — they render fragments, not full pages.

---

## Core Concept

A View Component has two parts: a C# class that inherits from `ViewComponent` and contains an `InvokeAsync` method (where you fetch data and return a view result), and a Razor template in `Views/Shared/Components/{ComponentName}/Default.cshtml` (the default view). The `InvokeAsync` method can accept parameters passed from the calling view, inject services via constructor injection, and return `View(model)` just like a controller action — but it has no concept of HTTP method, routing, or model binding from the request. It only knows what its caller explicitly passes it.

The key difference from a partial view: a partial view renders data that the parent passed to it. A View Component fetches its own data. The parent view calls `@await Component.InvokeAsync("ShoppingCart")` and the component queries the cart service internally — the controller that rendered the parent page knows nothing about the cart.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | View Components introduced as a replacement for ASP.NET MVC 5 child actions (`[ChildActionOnly]`) |
| ASP.NET Core 1.1 | .NET Core 1.1 | Synchronous `Invoke()` method supported alongside async `InvokeAsync()` |
| ASP.NET Core 2.1 | .NET Core 2.1 | Tag Helper syntax `<vc:component-name />` introduced as an alternative to `@await Component.InvokeAsync()` |
| ASP.NET Core 6.0 | .NET 6 | View Components work in Razor Pages with the same syntax |
| ASP.NET Core 8.0 | .NET 8 | Blazor SSR components introduced as an alternative for highly interactive fragments |

*Before ASP.NET Core, the equivalent feature in ASP.NET MVC 5 was "child actions" — controller actions decorated with `[ChildActionOnly]` that could be invoked from a view with `@Html.Action("ActionName", "ControllerName")`. View Components replaced child actions because child actions spun up the full MVC pipeline (routing, model binding, action filters) for every fragment render. View Components are lightweight — they skip the routing and model binding pipeline entirely.*

---

## The Code

**1. Basic View Component class**
```csharp
// ViewComponents/ShoppingCartSummaryViewComponent.cs
// Naming convention: class name ends with "ViewComponent"
public class ShoppingCartSummaryViewComponent(ICartService cartService) : ViewComponent
{
    public async Task<IViewComponentResult> InvokeAsync()
    {
        // Fetch data independently — the calling controller knows nothing about this
        var userId = HttpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);
        var summary = await cartService.GetSummaryAsync(userId);

        return View(summary); // renders Default.cshtml with the summary as model
    }
}
```

**2. The component's Razor template**
```cshtml
@* Views/Shared/Components/ShoppingCartSummary/Default.cshtml *@
@model CartSummaryViewModel

<div class="cart-icon">
    <a asp-controller="Cart" asp-action="Index">
        <span class="icon">🛒</span>
        @if (Model.ItemCount > 0)
        {
            <span class="badge">@Model.ItemCount</span>
        }
    </a>
</div>
```

**3. Invoking a View Component from a view — two syntax options**
```cshtml
@* Option 1: @await Component.InvokeAsync — works everywhere *@
@await Component.InvokeAsync("ShoppingCartSummary")

@* Option 2: Tag Helper syntax — cleaner, requires @addTagHelper in _ViewImports.cshtml *@
<vc:shopping-cart-summary />

@* Note: PascalCase class name ShoppingCartSummaryViewComponent
         becomes kebab-case vc:shopping-cart-summary in the Tag Helper *@
```

**4. Passing parameters to a View Component**
```csharp
// ViewComponents/RecentlyViewedViewComponent.cs
public class RecentlyViewedViewComponent(IProductService productService) : ViewComponent
{
    public async Task<IViewComponentResult> InvokeAsync(int count = 4)
    {
        var userId   = HttpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);
        var products = await productService.GetRecentlyViewedAsync(userId, count);

        return View(products);
    }
}
```
```cshtml
@* Passing parameters from the calling view *@
@await Component.InvokeAsync("RecentlyViewed", new { count = 6 })

@* Tag Helper syntax with parameter *@
<vc:recently-viewed count="6" />
```

**5. Multiple named views — not just Default.cshtml**
```csharp
public class NotificationBellViewComponent(INotificationService notificationService) : ViewComponent
{
    public async Task<IViewComponentResult> InvokeAsync(string variant = "full")
    {
        var count = await notificationService.GetUnreadCountAsync(
            HttpContext.User.FindFirstValue(ClaimTypes.NameIdentifier));

        var vm = new NotificationViewModel { UnreadCount = count };

        // Returns Views/Shared/Components/NotificationBell/{variant}.cshtml
        return View(variant, vm);  // "full" or "compact"
    }
}
```
```
Views/Shared/Components/NotificationBell/
├── Default.cshtml    ← returned by View() with no name argument
├── full.cshtml       ← returned by View("full", vm)
└── compact.cshtml    ← returned by View("compact", vm)
```

**6. Returning content without a view**
```csharp
public class MaintenanceBannerViewComponent : ViewComponent
{
    public IViewComponentResult Invoke()
    {
        var maintenanceWindow = Environment.GetEnvironmentVariable("MAINTENANCE_WINDOW");

        if (string.IsNullOrEmpty(maintenanceWindow))
            return Content(string.Empty); // renders nothing

        return Content($"<div class=\"alert alert-warning\">Maintenance: {maintenanceWindow}</div>",
                       "text/html");
    }
}
```

**7. Registering the Tag Helper syntax in _ViewImports.cshtml**
```cshtml
@* Views/_ViewImports.cshtml *@
@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers
@addTagHelper *, MyApp   @* required for <vc:...> Tag Helpers from your own assembly *@
```

**8. View Component discovery — folder structure**
```
Views/
└── Shared/
    └── Components/
        ├── ShoppingCartSummary/
        │   └── Default.cshtml
        ├── RecentlyViewed/
        │   └── Default.cshtml
        └── NotificationBell/
            ├── Default.cshtml
            ├── full.cshtml
            └── compact.cshtml

ViewComponents/                     ← class files conventionally go here
├── ShoppingCartSummaryViewComponent.cs
├── RecentlyViewedViewComponent.cs
└── NotificationBellViewComponent.cs
```

---

## Real World Example

A SaaS platform dashboard where the navigation bar shows three independent pieces of live data: the user's unread notification count, their current plan's usage percentage, and a "trial days remaining" banner. Each appears on every page of the app. Loading all three in every controller action would scatter unrelated data-fetching across the entire codebase. View Components isolate each widget completely.

```csharp
// ViewComponents/TrialBannerViewComponent.cs
public class TrialBannerViewComponent(
    ISubscriptionService subscriptionService,
    IHttpContextAccessor httpContextAccessor) : ViewComponent
{
    public async Task<IViewComponentResult> InvokeAsync()
    {
        var tenantId = HttpContext.User.FindFirstValue("tenant_id");
        if (tenantId is null)
            return Content(string.Empty);

        var subscription = await subscriptionService.GetAsync(Guid.Parse(tenantId));

        // If not on trial or trial has expired, render nothing
        if (!subscription.IsOnTrial || subscription.TrialEndsAt < DateTime.UtcNow)
            return Content(string.Empty);

        var vm = new TrialBannerViewModel
        {
            DaysRemaining    = (int)(subscription.TrialEndsAt - DateTime.UtcNow).TotalDays,
            UpgradeUrl       = Url.Action("Upgrade", "Billing"),
            PlanName         = subscription.PlanName,
        };

        // Urgent styling when 3 or fewer days remain
        return View(vm.DaysRemaining <= 3 ? "urgent" : "default", vm);
    }
}
```

```cshtml
@* Views/Shared/Components/TrialBanner/default.cshtml *@
@model TrialBannerViewModel

<div class="alert alert-info alert-dismissible d-flex justify-content-between">
    <span>
        Your <strong>@Model.PlanName trial</strong> ends in
        <strong>@Model.DaysRemaining day@(Model.DaysRemaining == 1 ? "" : "s")</strong>.
    </span>
    <a href="@Model.UpgradeUrl" class="btn btn-sm btn-primary ms-3">Upgrade now</a>
</div>
```

```cshtml
@* Views/Shared/Components/TrialBanner/urgent.cshtml *@
@model TrialBannerViewModel

<div class="alert alert-danger alert-dismissible d-flex justify-content-between">
    <span>
        ⚠️ Only <strong>@Model.DaysRemaining day@(Model.DaysRemaining == 1 ? "" : "s")</strong>
        left on your trial — upgrade to avoid losing access.
    </span>
    <a href="@Model.UpgradeUrl" class="btn btn-sm btn-danger ms-3">Upgrade now</a>
</div>
```

```cshtml
@* Views/Shared/_Layout.cshtml — single line, no data plumbing needed in controllers *@
<header>
    <nav>...</nav>
    <vc:trial-banner />
    <vc:notification-bell />
    <vc:usage-meter />
</header>
```

*The key insight: the layout invokes three View Components with zero parameters and zero controller involvement. Each component owns its own service dependency and data-fetching logic. If the `TrialBanner` logic changes, only `TrialBannerViewComponent.cs` changes — not a single controller action. The two named views (`default` and `urgent`) let the component drive its own presentation styling based on business logic, without an `@if` branch in the Razor template.*

---

## Common Misconceptions

**"View Components are just fancy partial views"**
They're architecturally different. A partial view is a dumb template — it can only render data handed to it by its parent. A View Component is a mini-controller with its own service dependencies, its own `InvokeAsync` method, and its own Razor template. The distinction matters when the UI fragment needs data that no controller in the app should be responsible for fetching on every request.

**"You need to register View Components in Program.cs"**
View Components are discovered automatically by convention — any class that inherits `ViewComponent` (or is decorated with `[ViewComponent]`, or has a name ending in `ViewComponent`) is registered automatically when you call `AddControllersWithViews()`. No explicit `builder.Services.AddTransient<ShoppingCartViewComponent>()` is needed. The services the component depends on must be registered — but the component itself doesn't need to be.

**"The Tag Helper name matches the class name exactly"**
The Tag Helper name is the kebab-case version of the class name with `ViewComponent` stripped. `ShoppingCartSummaryViewComponent` becomes `<vc:shopping-cart-summary />`. Getting this wrong produces a "tag not found" error that looks like a missing `@addTagHelper` directive when it's actually a naming mismatch.

```csharp
// Class: ShoppingCartSummaryViewComponent
// Tag Helper: <vc:shopping-cart-summary />
// NOT: <vc:ShoppingCartSummaryViewComponent /> ← wrong
// NOT: <vc:shoppingcartsummary />              ← wrong
```

---

## Gotchas

- **The Razor template must live at `Views/Shared/Components/{ComponentName}/Default.cshtml`.** The `{ComponentName}` folder name is the class name with `ViewComponent` stripped — `ShoppingCartSummaryViewComponent` → `ShoppingCartSummary`. If the folder name doesn't match, the framework throws a `ViewComponentNotFoundException` at render time, not at startup.

- **`InvokeAsync` must return `Task<IViewComponentResult>` — not `Task<IActionResult>`.** Returning `Task<IActionResult>` compiles but the framework can't process it as a View Component result and throws at runtime. The return type distinction is easy to miss when copying patterns from controller actions.

- **View Components do not participate in the MVC filter pipeline.** Action filters, authorization filters, and exception filters applied to controllers do not run for View Component invocations. If you need authorization inside a View Component, check `HttpContext.User` manually or inject an `IAuthorizationService`.

- **`HttpContext` is available in View Components but `RouteData` reflects the parent request's route, not the component's invocation.** Don't use `RouteData.Values["controller"]` inside a View Component expecting it to return the component's "controller" — there isn't one. It returns the controller that rendered the parent page.

- **The `<vc:...>` Tag Helper syntax requires `@addTagHelper *, YourAssembly` in `_ViewImports.cshtml`.** If the `<vc:>` tags render as literal HTML, the `@addTagHelper` directive for your assembly is missing. `@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers` covers built-in helpers but not `<vc:>` — you need your own assembly registered separately.

- **View Components are synchronous by default if you implement `Invoke()` instead of `InvokeAsync()`.** The sync version works but can cause thread-pool exhaustion on high-traffic sites if it blocks on async operations internally (e.g. calling `.Result` on a `Task`). Always implement `InvokeAsync()` and use `await` throughout.

---

## Interview Angle

**What they're really testing:** Whether you understand the boundary between partial views and View Components — specifically that View Components exist to prevent data-fetching logic from leaking into every controller action for fragments that appear on many pages.

**Common question forms:**
- *"What's the difference between a partial view and a View Component?"*
- *"How would you implement a shopping cart icon in the nav bar that shows the item count on every page?"*
- *"What replaced child actions from ASP.NET MVC 5?"*

**The depth signal:** A junior answer says View Components are "like partial views but more powerful." A senior answer explains the architectural difference precisely: a partial view can only render data the parent passed; a View Component fetches its own data via injected services. The senior knows the folder convention (`Views/Shared/Components/{Name}/Default.cshtml`), why `InvokeAsync` returns `IViewComponentResult` not `IActionResult`, that View Components don't participate in the filter pipeline (so authorization must be handled manually), and that the `<vc:>` Tag Helper requires the assembly registered in `_ViewImports.cshtml` — a silent failure if missing.

**Follow-up questions to expect:**
- *"How do you pass parameters to a View Component?"* (constructor = services via DI; `InvokeAsync(param)` = caller-supplied values)
- *"Do action filters apply to View Components?"* (no — they bypass the filter pipeline entirely)

---

## Related Topics

- [[dotnet/mvc/mvc-partial-views.md]] — Partial views are the right tool when the parent already has the data; View Components are the right tool when the fragment needs to fetch its own. Understanding both makes the choice clear.
- [[dotnet/mvc/mvc-views.md]] — View Components are invoked from Razor views; understanding the view layer — layouts, sections, `@model` — is the prerequisite.
- [[dotnet/mvc/mvc-tag-helpers.md]] — The `<vc:>` syntax is a Tag Helper; it requires `@addTagHelper *, YourAssembly` in `_ViewImports.cshtml` to work.
- [[dotnet/dependency-injection.md]] — View Component constructors receive services via DI; the same lifetime rules apply — don't inject a singleton that holds scoped state.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/views/view-components

---
*Last updated: 2026-04-09*