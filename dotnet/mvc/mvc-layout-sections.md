# MVC Layout & Sections

> The Razor system that lets all views share a common HTML shell (layout) while individual views inject their own content into named slots (sections) within that shell.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Shared HTML wrapper with named injection slots |
| **Use when** | Multiple views share the same outer HTML structure |
| **Avoid when** | Content is always the same across all views — put it directly in the layout |
| **Key file** | `Views/Shared/_Layout.cshtml` |
| **Key directives** | `@RenderBody()`, `@RenderSection()`, `@section`, Layout in `_ViewStart.cshtml` |
| **Namespace** | `Microsoft.AspNetCore.Mvc.Razor` |

---

## When To Use It

Use layouts any time more than one view shares the same outer HTML structure — `<html>`, `<head>`, nav bar, footer, global script tags. Without a layout, you'd duplicate that boilerplate in every `.cshtml` file. Use sections when a specific view needs to inject something into a part of the layout that other views don't — a page-specific `<script>` block, a sidebar, or a page title that varies per view. Don't create sections for content that every view always provides — that belongs directly in the layout itself.

---

## Core Concept

A layout is a wrapper template with one mandatory `@RenderBody()` call and any number of optional `@RenderSection()` slots. Every view that uses the layout gets its own content rendered at `@RenderBody()`. Sections are opt-in named slots — a view can fill them with `@section SectionName { ... }`, and the layout renders whatever the view put there.

The execution order matters: **the view runs first, the layout runs second**. This is why `ViewData["Title"] = "Products"` set inside a view is readable from the layout's `<title>` tag — the view executes first, populates `ViewData`, then the layout executes and reads it. Setting it the other way — in the layout, expecting the view to read it — doesn't work.

If a section is marked `required: true` and a view doesn't define it, the framework throws at render time. If it's `required: false`, views that skip it just leave that slot empty. The layout chain is configured in `_ViewStart.cshtml` globally, so individual views don't have to declare their layout unless they want to override or opt out.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | Layout and sections system carried over from ASP.NET MVC 5; `_ViewStart.cshtml` and `_ViewImports.cshtml` introduced |
| ASP.NET Core 2.1 | .NET Core 2.1 | Razor Class Libraries — layouts can be packaged in NuGet; override by placing a file at the same path in the consuming project |
| ASP.NET Core 3.0 | .NET Core 3.0 | Runtime Razor compilation opt-in; layout compilation errors caught at build time with `RazorCompileOnBuild` |
| ASP.NET Core 6.0 | .NET 6 | Hot reload for layouts in development; `asp-append-version` Tag Helper stable and well-documented |
| ASP.NET Core 8.0 | .NET 8 | Blazor SSR components can be embedded in layouts via `<component>` Tag Helper |

*The layout system has been largely unchanged since ASP.NET MVC 2. The main evolution in ASP.NET Core was moving configuration to `_ViewImports.cshtml` (replacing `App_Start/`) and introducing build-time compilation.*

---

## The Code

**1. Shared layout file**
```cshtml
@* Views/Shared/_Layout.cshtml *@
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title>@ViewData["Title"] — MyApp</title>
    <link rel="stylesheet" href="~/css/site.css" asp-append-version="true" />

    @* Optional section — views can inject page-specific <link> or <meta> tags *@
    @RenderSection("Head", required: false)
</head>
<body>
    <nav>
        <a asp-controller="Home" asp-action="Index">Home</a>
        <a asp-controller="Products" asp-action="Index">Products</a>
    </nav>

    <main class="container">
        @RenderBody()  @* every view's HTML renders here — mandatory, exactly once *@
    </main>

    <footer>
        <p>&copy; @DateTime.Now.Year MyApp</p>
    </footer>

    <script src="~/js/site.js" asp-append-version="true"></script>

    @* Optional section — views inject page-specific scripts here, after site.js *@
    @RenderSection("Scripts", required: false)
</body>
</html>
```

**2. _ViewStart.cshtml — sets the default layout for all views**
```cshtml
@* Views/_ViewStart.cshtml *@
@{
    Layout = "_Layout";
}
```

**3. A standard view using the layout**
```cshtml
@* Views/Products/Index.cshtml *@
@model ProductIndexViewModel

@{
    ViewData["Title"] = "Products"; // flows up into <title> in the layout
}

<h1>Products</h1>

@foreach (var product in Model.Products)
{
    <partial name="_ProductCard" model="product" />
}

@section Scripts {
    <script src="~/js/product-filter.js" asp-append-version="true"></script>
}
```

**4. A required section — layout enforces every view fills it**
```cshtml
@* In the layout: *@
@RenderSection("PageHeader", required: true)

@* In a view — MUST define PageHeader or the framework throws at render time *@
@section PageHeader {
    <div class="page-header">
        <h1>@ViewData["Title"]</h1>
        <p class="lead">Manage your product catalogue</p>
    </div>
}
```

**5. Overriding the layout per view**
```cshtml
@* Views/Account/Login.cshtml — use a different layout: no nav, no footer *@
@{
    Layout = "_AuthLayout";
}

<h1>Sign In</h1>
@* ... *@
```
```cshtml
@* Opt out of a layout entirely — renders bare HTML with no shell *@
@{
    Layout = null;
}
```

**6. Nested layouts — a layout that itself uses another layout**
```cshtml
@* Views/Shared/_AdminLayout.cshtml *@
@{
    Layout = "_Layout"; // _AdminLayout wraps inside the main _Layout
}

<div class="admin-sidebar">
    <a asp-action="Dashboard">Dashboard</a>
    <a asp-action="Users">Users</a>
</div>

@RenderBody() @* admin views render here, inside the sidebar wrapper *@

@* CRITICAL: forward any sections the outer layout declares.
   Without this, a view's @section Scripts { } is silently swallowed. *@
@section Scripts {
    @RenderSection("Scripts", required: false)
}
```

**7. `asp-append-version` on static assets — cache busting**
```cshtml
@* Appends a content-derived hash to bust the browser cache on deploy *@
<link rel="stylesheet" href="~/css/site.css" asp-append-version="true" />
@* Renders as: <link href="/css/site.css?v=X7a9k2..." rel="stylesheet"> *@

@* The hash is derived from file content, not a timestamp —
   it only changes when the file actually changes *@
<script src="~/js/site.js" asp-append-version="true"></script>
```

**8. _ViewStart.cshtml scoping — per-folder override**
```
Views/
├── _ViewStart.cshtml       ← Layout = "_Layout" — applies to all views
├── _ViewImports.cshtml
├── Home/
│   └── Index.cshtml        ← uses _Layout (inherited)
├── Admin/
│   ├── _ViewStart.cshtml   ← Layout = "_AdminLayout" — overrides for admin views only
│   └── Dashboard.cshtml    ← uses _AdminLayout
```

---

## Real World Example

A multi-section e-commerce site with three distinct layout contexts: the public storefront (full nav, promotional banners), the customer account area (condensed nav, breadcrumbs), and the admin panel (sidebar nav, no promotional content). Each uses a different layout, and all three are nested inside a single root layout that provides the `<html>`, `<head>`, fonts, and global styles.

```cshtml
@* Views/Shared/_Layout.cshtml — root layout *@
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title>@ViewData["Title"] — ShopName</title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="stylesheet" href="~/css/base.css" asp-append-version="true" />
    @RenderSection("Head", required: false)
</head>
<body class="@ViewData["BodyClass"]">
    @RenderBody()
    <script src="~/js/base.js" asp-append-version="true"></script>
    @RenderSection("Scripts", required: false)
</body>
</html>

@* Views/Shared/_StorefrontLayout.cshtml — wraps inside _Layout *@
@{
    Layout    = "_Layout";
    ViewData["BodyClass"] = "storefront";
}

<header class="storefront-header">
    <div class="promo-banner">@ViewData["PromoBanner"]</div>
    <nav><!-- storefront nav --></nav>
</header>

<main class="storefront-main">
    @RenderBody()
</main>

<footer class="storefront-footer">
    <!-- links, legal, socials -->
</footer>

@* Forward sections — without this, storefront views can't inject into _Layout *@
@section Head    { @RenderSection("Head",    required: false) }
@section Scripts { @RenderSection("Scripts", required: false) }

@* Views/_ViewStart.cshtml — storefront views use StorefrontLayout by default *@
@{ Layout = "_StorefrontLayout"; }

@* Views/Products/Index.cshtml — a storefront view *@
@model ProductIndexViewModel
@{
    ViewData["Title"]       = "All Products";
    ViewData["PromoBanner"] = "Free shipping on orders over £50";
}

<h1>Products</h1>
@* ...product listing... *@

@section Scripts {
    <script src="~/js/product-filter.js" asp-append-version="true"></script>
}
```

*The key insight: `ViewData["PromoBanner"]` is set in the view and read in `_StorefrontLayout` — this works because the view executes first. The `@section Scripts { @RenderSection(...) }` forwarding in `_StorefrontLayout` is critical — without it, any `@section Scripts { }` block defined in a product view would be silently discarded rather than passed through to `_Layout`'s script slot.*

---

## Common Misconceptions

**"@RenderBody() can go anywhere in the layout, and you can call it multiple times"**
`@RenderBody()` can only appear once and must appear exactly once. Omitting it means the view's content is silently discarded — the layout renders but the page body is blank. Adding it twice throws an `InvalidOperationException` at startup. It can go anywhere in the layout markup, but most layouts put it inside the main content wrapper element.

**"A section defined in a view is automatically available to all layouts in the chain"**
Sections do not bubble up through nested layouts automatically. If `_AdminLayout` wraps inside `_Layout`, and `_Layout` declares `@RenderSection("Scripts", required: false)`, a view using `_AdminLayout` can define `@section Scripts { }` — but `_AdminLayout` must explicitly forward it with its own `@RenderSection("Scripts", required: false)`. Without the forwarding line, the view's scripts section is silently swallowed at `_AdminLayout` and never reaches `_Layout`.

**"ViewData["Title"] set in the layout is readable by the view"**
It's the opposite. The view executes first, then the layout. `ViewData` set in the view is readable by the layout. `ViewData` set in the layout is not readable by the view that has already finished executing.

---

## Gotchas

- **`@RenderBody()` can only appear once in a layout and is not optional.** Every layout must have exactly one `@RenderBody()` call. Omitting it means the view's content is silently discarded — the layout renders but the page body is blank.

- **A view that defines a section not declared in its layout throws a runtime error.** If a view has `@section Sidebar { ... }` but the layout has no `@RenderSection("Sidebar", ...)`, the framework throws `InvalidOperationException: The following sections have been defined but have not been rendered`. The section name must match exactly — including casing.

- **`_ViewStart.cshtml` applies to all views in its folder and subfolders recursively.** A `_ViewStart.cshtml` in `Views/` applies to every view in the project. A second `_ViewStart.cshtml` in `Views/Admin/` applies only to admin views and overrides the parent for that folder. Unexpected layout changes when adding views are usually caused by a missing or misplaced `_ViewStart.cshtml`.

- **`@section` blocks are not forwarded through nested layouts automatically.** If `_AdminLayout` uses `_Layout`, and `_Layout` declares `@RenderSection("Scripts", required: false)`, `_AdminLayout` must also include `@section Scripts { @RenderSection("Scripts", required: false) }`. Without the forwarding call, the view's scripts section is silently swallowed.

- **`ViewData["Title"]` set in the view is only available to the layout because the view renders first.** The execution order is: view runs first, layout runs second with the view's output available. Setting `ViewData` in the layout and expecting the view to read it doesn't work.

- **`asp-append-version` requires the file to exist at render time.** If the static file doesn't exist (first build on a clean machine, or the file path is wrong), the Tag Helper silently omits the version query string — the URL renders without the hash, which means stale cache in production. Verify the file path exists before deploying.

---

## Interview Angle

**What they're really testing:** Whether you understand the Razor rendering model — specifically that views execute before layouts, and that sections are opt-in named injection points rather than inheritance.

**Common question forms:**
- *"How do layouts work in ASP.NET Core MVC?"*
- *"How do you include a page-specific script in only one view without putting it in the global layout?"*
- *"Why does ViewData["Title"] set in the view show up in the layout's `<title>` tag?"*

**The depth signal:** A junior answer describes `_Layout.cshtml` and `@RenderBody()`. A senior answer explains the execution order (view first, layout second — which is why `ViewData` set in a view is readable in the layout), the difference between `required: true` and `required: false` sections and the runtime exception each triggers, why a view defining an undeclared section throws while a view skipping an optional section silently renders nothing, how `_ViewStart.cshtml` scoping works per folder, and the nested layout section-forwarding trap where a middle layout must explicitly forward sections or they're silently swallowed.

**Follow-up questions to expect:**
- *"How would you use a completely different layout for a login page?"* (`Layout = "_AuthLayout"` in the view's `@{ }` block)
- *"How does asp-append-version work under the hood?"* (content hash query string, not timestamp — only changes when file changes)

---

## Related Topics

- [[dotnet/mvc/mvc-views.md]] — Layouts wrap views; understanding the view layer — `@model`, `ViewData`, Razor syntax — is the prerequisite for working with layouts and sections.
- [[dotnet/mvc/mvc-partial-views.md]] — Partials and layouts are both composition mechanisms; knowing when to use a partial (reusable fragment) vs a section (layout injection point) prevents over-engineering views.
- [[dotnet/mvc/mvc-tag-helpers.md]] — `asp-append-version` on `<link>` and `<script>` in layouts is a Tag Helper; the anchor and form helpers inside layout nav bars also depend on Tag Helper registration in `_ViewImports.cshtml`.
- [[dotnet/mvc/mvc-bundling-minification.md]] — Bundle `<link>` and `<script>` tags live in the layout; sections let individual views inject page-specific scripts after the bundle without touching the layout.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/views/layout

---
*Last updated: 2026-04-09*