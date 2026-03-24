# MVC Layout & Sections

> The Razor system that lets all views share a common HTML shell (layout) while individual views inject their own content into named slots (sections) within that shell.

---

## When To Use It

Use layouts any time more than one view shares the same outer HTML structure — `<html>`, `<head>`, nav bar, footer, global script tags. Without a layout, you'd duplicate that boilerplate in every `.cshtml` file. Use sections when a specific view needs to inject something into a part of the layout that other views don't — a page-specific `<script>` block, a sidebar, or a page title that varies per view. Don't create sections for content that every view always provides — that belongs directly in the layout itself.

---

## Core Concept

A layout is a wrapper template with one mandatory `@RenderBody()` call and any number of optional `@RenderSection()` slots. Every view that uses the layout gets its own content rendered at `@RenderBody()`. Sections are opt-in named slots — a view can fill them with `@section SectionName { ... }`, and the layout renders whatever the view put there. If a section is marked `required: true` and a view doesn't define it, the framework throws at render time. If it's `required: false`, views that skip it just leave that slot empty. The layout chain is configured in `_ViewStart.cshtml` globally, so individual views don't have to declare their layout unless they want to override or opt out.

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
        @RenderBody()  @* every view's HTML renders here — this call is mandatory *@
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
@* Every view in the project uses _Layout unless it overrides this *@
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

@* Everything here renders at @RenderBody() in the layout *@
<h1>Products</h1>

@foreach (var product in Model.Products)
{
    <partial name="_ProductCard" model="product" />
}

@* Fills the Scripts section defined in the layout *@
@section Scripts {
    <script src="~/js/product-filter.js"></script>
}
```

**4. A required section — layout enforces that every view fills it**
```cshtml
@* In the layout: *@
@RenderSection("PageHeader", required: true)

@* In a view that uses this layout — MUST define PageHeader or throws *@
@section PageHeader {
    <div class="page-header">
        <h1>@ViewData["Title"]</h1>
        <p class="lead">Manage your product catalogue</p>
    </div>
}
```

**5. Overriding the layout per view**
```cshtml
@* Views/Account/Login.cshtml *@
@{
    Layout = "_AuthLayout"; // use a different layout — no nav, no footer
}

<h1>Sign In</h1>
@* ... *@
```
```cshtml
@* To opt out of a layout entirely (renders bare HTML with no shell) *@
@{
    Layout = null;
}
```

**6. Nested layouts — a layout that itself uses another layout**
```cshtml
@* Views/Shared/_AdminLayout.cshtml *@
@{
    Layout = "_Layout"; // _AdminLayout wraps inside _Layout
}

@* Admin-specific sidebar added here *@
<div class="admin-sidebar">
    <a asp-action="Dashboard">Dashboard</a>
    <a asp-action="Users">Users</a>
</div>

@RenderBody() @* admin views render here, inside the sidebar wrapper *@
```

**7. `asp-append-version` on static assets**
```cshtml
@* Appends a content hash query string to bust the browser cache on deploy *@
<link rel="stylesheet" href="~/css/site.css" asp-append-version="true" />
@* Renders as: <link href="/css/site.css?v=X7a9k2..." rel="stylesheet"> *@
```

---

## Gotchas

- **`@RenderBody()` can only appear once in a layout and is not optional.** Every layout must have exactly one `@RenderBody()` call. Omitting it means the view's content is silently discarded — the layout renders but the page is blank. Adding it twice throws at startup.
- **A view that defines a section not declared in its layout throws a runtime error.** If a view has `@section Sidebar { ... }` but the layout has no `@RenderSection("Sidebar", ...)`, the framework throws `InvalidOperationException: The following sections have been defined but have not been rendered`. The section name must match exactly — including casing.
- **`_ViewStart.cshtml` applies to all views in its folder and subfolders recursively.** A `_ViewStart.cshtml` in `Views/` applies to every view in the project. A second `_ViewStart.cshtml` in `Views/Admin/` applies only to admin views and overrides the parent for that folder. This is useful but confusing if you forget the file is there — unexpected layout changes when adding admin views are usually caused by a missing or misplaced `_ViewStart.cshtml`.
- **`@section` blocks are not inherited through nested layouts.** If `_AdminLayout` uses `_Layout`, and `_Layout` declares `@RenderSection("Scripts", required: false)`, a view using `_AdminLayout` can still define `@section Scripts { }` — but `_AdminLayout` itself must forward it with its own `@RenderSection("Scripts", required: false)`. If it doesn't, the view's scripts section is silently swallowed.
- **`ViewData["Title"]` set in the view is only available to the layout because the view renders first.** The execution order is: view runs first, layout runs second with the view's output available. This is why setting `ViewData["Title"]` in the view and reading it in the layout's `<title>` tag works. Setting it the other way — in the layout, expecting the view to read it — doesn't.

---

## Interview Angle

**What they're really testing:** Whether you understand the Razor rendering model — specifically that views execute before layouts, and that sections are opt-in named injection points rather than inheritance.

**Common question form:** *"How do layouts work in ASP.NET Core MVC?"* or *"How do you include a page-specific script in only one view without putting it in the global layout?"*

**The depth signal:** A junior answer describes `_Layout.cshtml` and `@RenderBody()`. A senior answer explains the execution order (view first, layout second — which is why `ViewData` set in a view is readable in the layout), the difference between `required: true` and `required: false` sections and the runtime exception each triggers, why a view defining an undeclared section throws while a view skipping an optional section silently renders nothing, how `_ViewStart.cshtml` scoping works per folder, and the nested layout section-forwarding trap where a middle layout must explicitly forward sections or they're swallowed.

---

## Related Topics

- [[dotnet/mvc-views.md]] — Layouts wrap views; understanding the view layer — `@model`, `ViewData`, Razor syntax — is the prerequisite for working with layouts and sections.
- [[dotnet/mvc-partial-views.md]] — Partials and layouts are both composition mechanisms; knowing when to use a partial (reusable fragment) vs a section (layout injection point) prevents over-engineering views.
- [[dotnet/mvc-tag-helpers.md]] — `asp-append-version` on `<link>` and `<script>` in layouts is a Tag Helper; the anchor and form helpers inside layout nav bars also depend on Tag Helper registration in `_ViewImports.cshtml`.
- [[dotnet/webapi-authentication.md]] — Layout nav bars often conditionally render login/logout links based on `User.Identity.IsAuthenticated`; the auth middleware must run before the view renders for this to work correctly.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/views/layout

---
*Last updated: 2026-03-24*