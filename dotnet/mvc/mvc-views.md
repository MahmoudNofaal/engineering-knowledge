# MVC Views

> Razor `.cshtml` files in ASP.NET Core MVC that receive a model from a controller and render it into HTML — the presentation layer that knows nothing about where data came from.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Server-side HTML template with typed model binding |
| **Use when** | Returning server-rendered HTML from an MVC app |
| **Avoid when** | JSON APIs; SPA frontends; pure Razor Pages workflows |
| **File extension** | `.cshtml` (C# HTML) |
| **Namespace** | `Microsoft.AspNetCore.Mvc.Razor` |
| **Key directives** | `@model`, `@using`, `@inject`, `@section`, `@addTagHelper` |

---

## When To Use It

Use Razor views when your ASP.NET Core app serves server-rendered HTML — admin portals, internal tools, email templates, or any UI where the server assembles the full page before sending it. Don't use them for APIs that return JSON; that's `ControllerBase` territory with no view involved. If your frontend is a SPA (React, Vue, Angular), views are the wrong tool — your controllers should return data and let the client handle rendering. Razor Pages is a lighter alternative to MVC views when each page maps to a single file and you don't need the full controller-action-view split.

---

## Core Concept

A Razor view is a C# template. It's mostly HTML, but you can drop into C# anywhere with `@`. The controller passes a typed model — usually a ViewModel — and the view renders it. The `@model` directive at the top declares what type the view expects, which gives you IntelliSense and compile-time checking on `Model.PropertyName`. Razor also has a layout system: a shared `_Layout.cshtml` defines the chrome (nav, footer, scripts), and individual views slot their content into it via `@RenderBody()`. Partial views and Tag Helpers let you break the UI into reusable pieces and write HTML-like syntax for links, forms, and inputs that generate correct URLs and anti-forgery tokens automatically.

Views execute before the layout. This is why `ViewData["Title"] = "Products"` set inside a view is readable from the layout's `<title>` tag — the view runs first, populates `ViewData`, then the layout runs and reads it. The execution order is always: view first, layout second.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | Razor views unified between MVC and Web Pages; `_ViewImports.cshtml` introduced |
| ASP.NET Core 1.1 | .NET Core 1.1 | View compilation at runtime by default; optional pre-compilation via `RazorPrecompile` |
| ASP.NET Core 2.1 | .NET Core 2.1 | Razor Class Libraries — views packaged in NuGet; `<PartialTagHelper>` added |
| ASP.NET Core 3.0 | .NET Core 3.0 | Runtime Razor compilation moved to opt-in (`Microsoft.AspNetCore.Mvc.Razor.RuntimeCompilation`) |
| ASP.NET Core 6.0 | .NET 6 | Hot reload for Razor views in development; `_ViewImports.cshtml` inherits down folder tree |
| ASP.NET Core 8.0 | .NET 8 | Blazor SSR components can be embedded in Razor views via `<component>` Tag Helper |

*Before ASP.NET Core 3.0, Razor views were recompiled at runtime on every change by default — convenient in development but slow in production. From 3.0 onward, views are compiled at build time and runtime compilation is an opt-in dev dependency.*

---

## The Code

**1. Basic typed view**
```cshtml
@* Views/Products/Index.cshtml *@
@model IEnumerable<ProductViewModel>

@{
    ViewData["Title"] = "Products"; // flows up to _Layout.cshtml's <title>
}

<h1>Products</h1>

@foreach (var product in Model)
{
    <div class="product-card">
        <h2>@product.Name</h2>
        <p>@product.FormattedPrice</p>

        @* asp-* Tag Helpers generate correct href from route data *@
        <a asp-controller="Products" asp-action="Details" asp-route-id="@product.Id">
            View Details
        </a>
    </div>
}
```

**2. Shared layout (Views/Shared/_Layout.cshtml)**
```cshtml
<!DOCTYPE html>
<html lang="en">
<head>
    <title>@ViewData["Title"] — MyApp</title>
    <link rel="stylesheet" href="~/css/site.css" asp-append-version="true" />
    @RenderSection("Head", required: false)
</head>
<body>
    <nav>
        <a asp-controller="Home" asp-action="Index">Home</a>
        <a asp-controller="Products" asp-action="Index">Products</a>

        @* Conditionally render auth links — User context available in views *@
        @if (User.Identity?.IsAuthenticated == true)
        {
            <a asp-controller="Account" asp-action="Logout">Sign out</a>
        }
        else
        {
            <a asp-controller="Account" asp-action="Login">Sign in</a>
        }
    </nav>

    <main class="container">
        @RenderBody()  @* each view's content renders here — mandatory, exactly once *@
    </main>

    <footer>&copy; @DateTime.Now.Year MyApp</footer>

    <script src="~/js/site.js" asp-append-version="true"></script>
    @RenderSection("Scripts", required: false)
</body>
</html>
```

**3. _ViewImports.cshtml — registers Tag Helpers and namespaces for all views**
```cshtml
@* Views/_ViewImports.cshtml *@
@* Applied to all views in this folder and subfolders — this file is required *@

@using MyApp
@using MyApp.ViewModels
@using MyApp.Models

@* Registers all built-in Tag Helpers (asp-for, asp-action, asp-controller, etc.) *@
@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers

@* Registers custom Tag Helpers in your own assembly *@
@addTagHelper *, MyApp
```

**4. _ViewStart.cshtml — sets the default layout for all views**
```cshtml
@* Views/_ViewStart.cshtml *@
@{
    Layout = "_Layout"; // every view uses this unless it overrides
}
```

**5. Form with Tag Helpers and client-side validation**
```cshtml
@* Views/Products/Create.cshtml *@
@model CreateProductDto

<form asp-action="Create" method="post">
    @* asp-for binds to model property — generates id, name, type, value, data-val-* *@
    <div class="mb-3">
        <label asp-for="Name" class="form-label"></label>
        <input asp-for="Name" class="form-control" />
        <span asp-validation-for="Name" class="text-danger"></span>
    </div>

    <div class="mb-3">
        <label asp-for="Price" class="form-label"></label>
        <input asp-for="Price" type="number" step="0.01" class="form-control" />
        <span asp-validation-for="Price" class="text-danger"></span>
    </div>

    @* <form asp-action> already injects the anti-forgery token automatically *@
    <button type="submit" class="btn btn-primary">Create</button>
</form>

@section Scripts {
    @* Loads jquery.validate.unobtrusive — reads data-val-* attrs generated by asp-for *@
    <partial name="_ValidationScriptsPartial" />
}
```

**6. Partial view for a reusable component**
```cshtml
@* Views/Shared/_ProductCard.cshtml *@
@model ProductViewModel

<div class="card">
    <h3>@Model.Name</h3>
    <p>@Model.FormattedPrice</p>
    <span class="badge @(Model.IsInStock ? "bg-success" : "bg-secondary")">
        @(Model.IsInStock ? "In Stock" : "Out of Stock")
    </span>
</div>
```
```cshtml
@* Invoke the partial from any view — pass a subset of the parent's model *@
@foreach (var product in Model.Products)
{
    <partial name="_ProductCard" model="product" />
}
```

**7. ViewData vs ViewBag vs strongly-typed ViewModel**
```cshtml
@* ViewData — dictionary, requires casting, typos fail silently at runtime *@
@{
    var title = ViewData["Title"] as string; // "Titel" typo = null, no error
}

@* ViewBag — dynamic wrapper over ViewData, no casting but no IntelliSense *@
@{ var count = ViewBag.ProductCount; }

@* ViewModel — always prefer for real data; typed, IntelliSense, compile-time safe *@
@model ProductIndexViewModel
@Model.TotalCount   @* IntelliSense works; "TotalCont" typo = compile error *@
```

**8. Injecting a service directly into a view (use sparingly)**
```cshtml
@* For truly view-specific data that doesn't belong in the ViewModel *@
@inject IStringLocalizer<SharedResources> Localizer
@inject IOptionsSnapshot<FeatureFlags> FeatureFlags

@if (FeatureFlags.Value.NewDashboardEnabled)
{
    <a asp-action="NewDashboard">@Localizer["Try the new dashboard"]</a>
}
```

---

## Real World Example

An HR portal where managers review and approve leave requests. Each leave request detail page combines data from three sources: the request itself, the employee's leave balance, and the team calendar. The ViewModel is assembled by the service layer so the view is purely presentational.

```cshtml
@* Views/LeaveRequests/Review.cshtml *@
@model LeaveRequestReviewViewModel

@{
    ViewData["Title"] = $"Review — {Model.EmployeeName}";
}

<div class="review-header">
    <h1>Leave Request — @Model.EmployeeName</h1>
    <span class="badge @Model.StatusBadgeClass">@Model.StatusLabel</span>
</div>

<div class="row">
    <div class="col-md-6">
        <dl>
            <dt>Period</dt>
            <dd>@Model.StartDate.ToString("d MMM yyyy") to @Model.EndDate.ToString("d MMM yyyy")</dd>

            <dt>Duration</dt>
            <dd>@Model.WorkingDaysCount working days</dd>

            <dt>Remaining balance after approval</dt>
            @* View decision: show warning style when balance would go below 5 days *@
            <dd class="@(Model.RemainingBalanceAfterApproval < 5 ? "text-warning" : "")">
                @Model.RemainingBalanceAfterApproval days
            </dd>
        </dl>
    </div>

    <div class="col-md-6">
        <h4>Team calendar — @Model.StartDate.ToString("MMMM yyyy")</h4>
        @* Partial receives just the calendar slice the view needs *@
        <partial name="_TeamCalendarPartial" model="Model.TeamCalendarSlice" />
    </div>
</div>

@if (Model.CanApprove)
{
    <form asp-action="Approve" asp-route-id="@Model.RequestId" method="post">
        <button type="submit" class="btn btn-success">Approve</button>
    </form>

    <form asp-action="Decline" asp-route-id="@Model.RequestId" method="post">
        <div class="mb-2">
            <textarea name="reason" class="form-control" placeholder="Reason for decline"></textarea>
        </div>
        <button type="submit" class="btn btn-danger">Decline</button>
    </form>
}

@section Scripts {
    <partial name="_ValidationScriptsPartial" />
}
```

*The key insight: `StatusBadgeClass`, `RemainingBalanceAfterApproval`, `WorkingDaysCount`, and `CanApprove` are all computed in the service/ViewModel layer — not in the view. The view makes no calculations and calls no services. Even the CSS class for the warning colour is a ViewModel property, not an inline `@if` computing business logic. The view is a pure template.*

---

## Common Misconceptions

**"@model and @Model are the same thing"**
They're different. `@model` (lowercase) is a directive that declares the type of the view's model — it goes at the top of the file and is processed at compile time. `@Model` (uppercase) is the property you use to access the model instance at runtime. Writing `@model` twice or confusing the two produces confusing compiler errors about model type mismatches.

```cshtml
@model IEnumerable<ProductViewModel>  @* directive — declares the type *@

@foreach (var p in Model)  @* Model — the actual instance *@
{ ... }
```

**"ViewBag is fine for passing data to the view — it's the same as ViewData"**
ViewBag is a dynamic wrapper over ViewData — they share the same underlying dictionary. Neither gives you compile-time safety or IntelliSense. A typo in `ViewBag.ProductCout` instead of `ViewBag.ProductCount` fails silently at runtime with a null value. For anything beyond layout-level metadata (like page title), use a strongly-typed ViewModel property.

**"You need @Html.AntiForgeryToken() inside every form"**
The `<form asp-action="...">` Tag Helper injects the anti-forgery token automatically. Adding `@Html.AntiForgeryToken()` inside the same form writes a second hidden field. It's redundant, not harmful — but it signals the developer didn't know the Tag Helper was already doing this. Pick one or the other; in new code the Tag Helper is the correct choice.

---

## Gotchas

- **`@model` is singular even when passing a collection.** Write `@model IEnumerable<ProductViewModel>`, not `@models`. Getting it wrong produces a confusing runtime error about the model type not matching, not a typo error.

- **`ViewData` and `ViewBag` bypass the type system entirely.** Typos in the key (`ViewData["Titel"]`) fail silently at runtime — the value is just null. For anything beyond passing the page title to the layout, use a strongly-typed ViewModel property instead.

- **Tag Helpers only work if `@addTagHelper` is declared — usually in `_ViewImports.cshtml`.** If your `asp-for`, `asp-action`, or `asp-controller` attributes are rendering as literal HTML attributes instead of being processed, check that `_ViewImports.cshtml` contains `@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers`. Missing this file or missing that line is a silent no-op.

- **`@Html.AntiForgeryToken()` and `<form asp-action>` both inject the token — using both writes it twice.** The Tag Helper already handles this. Adding `@Html.AntiForgeryToken()` inside the same form adds a second token field, which is redundant.

- **Razor view compilation errors surface at first request, not at build time, unless you enable compile-on-build.** By default in development, a typo in a `.cshtml` file won't fail the build — it throws a `RazorCompilationException` when you first navigate to that page. Add `<RazorCompileOnBuild>true</RazorCompileOnBuild>` to your `.csproj` to catch view errors at build time in CI.

- **`@inject` in a view creates a tight coupling between the view and the DI container.** If the injected service is not registered, the view throws at render time with a service resolution error — not at startup. Use `@inject` only for truly view-specific concerns (localisation, feature flags). Real data should come through the ViewModel.

---

## Interview Angle

**What they're really testing:** Whether you understand the View's responsibility boundary — it renders, it doesn't fetch — and whether you know the Razor tooling (Tag Helpers, layouts, partials) well enough to build maintainable server-rendered UI.

**Common question forms:**
- *"What is a Razor view and how does data get into it?"*
- *"What's the difference between ViewData, ViewBag, and a ViewModel?"*
- *"What is _ViewImports.cshtml and why is it needed?"*

**The depth signal:** A junior answer describes `@model`, `@Model.Property`, and `ViewBag`. A senior answer explains why ViewData and ViewBag are runtime-fragile and should only be used for layout-level metadata like page titles, why strongly-typed ViewModels are always preferred for real data, how Tag Helpers differ from `Html.BeginForm()` / `Html.TextBoxFor()` (Tag Helpers produce readable HTML syntax and integrate with routing), the anti-forgery token duplication trap when mixing Tag Helpers with `Html.AntiForgeryToken()`, how to enable compile-time Razor view compilation to catch errors in CI rather than at runtime, and the view-executes-before-layout execution order that explains why `ViewData["Title"]` set in a view is readable in the layout.

**Follow-up questions to expect:**
- *"How does the layout know what title to display?"* (ViewData set in view, read in layout — view executes first)
- *"What's the difference between a partial view and a View Component?"* (partials can't fetch data; View Components can)

---

## Related Topics

- [[dotnet/mvc/mvc-pattern.md]] — Views are the presentation layer of MVC; understanding the full pattern makes clear why the View must never fetch its own data or contain business logic.
- [[dotnet/mvc/mvc-controllers.md]] — Controllers pass the model to views via `return View(viewModel)`; the controller–view contract is the `@model` declaration at the top of the file.
- [[dotnet/mvc/mvc-tag-helpers.md]] — Tag Helpers power the `asp-for`, `asp-action`, `asp-validation-for` attributes; they require `_ViewImports.cshtml` registration to work.
- [[dotnet/mvc/mvc-layout-sections.md]] — Layouts and sections are the shell that wraps every view; understanding them is a prerequisite for knowing how views compose.
- [[dotnet/webapi-authentication.md]] — `User.Identity.IsAuthenticated` is available inside Razor views for conditionally rendering UI; understanding authentication explains where that context comes from.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/views/overview

---
*Last updated: 2026-04-09*