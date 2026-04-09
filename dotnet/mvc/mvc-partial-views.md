# MVC Partial Views

> Reusable chunks of Razor markup that render a fragment of HTML inside a parent view — without their own layout, lifecycle, or HTTP request.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Server-side HTML fragment rendered inline by a parent view |
| **Use when** | Reusing markup across views, or splitting a long view into named sections |
| **Avoid when** | The fragment needs its own data — use a View Component instead |
| **Convention** | Prefix filenames with `_` (e.g. `_ProductCard.cshtml`) |
| **Namespace** | `Microsoft.AspNetCore.Mvc.Razor` |
| **Key syntax** | `<partial name="_Name" model="..." />`, `@await Html.PartialAsync(...)` |

---

## When To Use It

Use partial views when the same block of HTML needs to appear in multiple views, or when a single view is getting long enough that splitting it into named sections makes it easier to read and maintain. Good candidates are product cards, comment threads, navigation menus, address blocks, and form sections that repeat across pages. Don't use partial views when the component needs its own data-fetching logic — that's what View Components are for. If the partial needs to call a service or query a database to get its own data, a partial view is the wrong tool because it can only work with what the parent passes it.

---

## Core Concept

A partial view is just a `.cshtml` file, conventionally prefixed with an underscore (`_ProductCard.cshtml`) to signal it's not a standalone page. The parent view renders it inline using the `<partial>` Tag Helper or `@await Html.PartialAsync()`, passing a model explicitly. The partial renders synchronously into the parent's output stream — there's no separate HTTP request, no separate route, no layout wrapping. It's a server-side include with typed data.

The underscore prefix is purely convention — the framework doesn't enforce it — but it keeps partials visually distinct from full views in the `Views/` folder and prevents accidental direct navigation to them. Partials placed in `Views/Shared/` are discoverable from any view in the project. Partials in controller-specific folders (e.g. `Views/Products/`) are only discoverable from views in that controller's folder.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | Partial views supported via `Html.Partial()` and `Html.PartialAsync()` |
| ASP.NET Core 2.1 | .NET Core 2.1 | `<partial>` Tag Helper introduced — preferred syntax over `Html.PartialAsync()` |
| ASP.NET Core 2.1 | .NET Core 2.1 | Razor Class Libraries — partials can be packaged in NuGet and shared across projects |
| ASP.NET Core 6.0 | .NET 6 | Hot reload works for partial views in development |
| ASP.NET Core 8.0 | .NET 8 | Blazor SSR components can coexist with partial views via `<component>` Tag Helper |

*Before the `<partial>` Tag Helper in ASP.NET Core 2.1, the only options were `@Html.Partial()` (sync) and `@await Html.PartialAsync()` (async). The Tag Helper syntax is cleaner and is the current default in all templates.*

---

## The Code

**1. A typed partial view**
```cshtml
@* Views/Shared/_ProductCard.cshtml *@
@model ProductSummary

<div class="card mb-3">
    <div class="card-body">
        <h5 class="card-title">@Model.Name</h5>
        <p class="card-text">@Model.FormattedPrice</p>

        <span class="badge @(Model.IsInStock ? "bg-success" : "bg-secondary")">
            @(Model.IsInStock ? "In Stock" : "Out of Stock")
        </span>

        <a asp-action="Details" asp-route-id="@Model.Id"
           class="btn btn-primary btn-sm">View</a>
    </div>
</div>
```

**2. Rendering a partial — three syntax options**
```cshtml
@* Views/Products/Index.cshtml *@
@model ProductIndexViewModel

@foreach (var product in Model.Products)
{
    @* Preferred: Tag Helper syntax — reads like HTML *@
    <partial name="_ProductCard" model="product" />

    @* Async HTML Helper — use when you need the return value *@
    @await Html.PartialAsync("_ProductCard", product)

    @* Sync version — avoid in async code paths, can deadlock in edge cases *@
    @Html.Partial("_ProductCard", product)
}
```

**3. Partial with ViewData (for passing secondary flags alongside the model)**
```cshtml
@{
    var viewData = new ViewDataDictionary(ViewData)
    {
        { "ShowActions", true }
    };
}
<partial name="_ProductCard" model="product" view-data="viewData" />
```
```cshtml
@* Inside _ProductCard.cshtml — reading the flag *@
@if ((bool)(ViewData["ShowActions"] ?? false))
{
    <a asp-action="Edit" asp-route-id="@Model.Id" class="btn btn-sm btn-outline-secondary">Edit</a>
}
```

**4. Partial used for a shared form section (reused across Create and Edit)**
```cshtml
@* Views/Shared/_ProductFormFields.cshtml *@
@model ProductFormDto

<div class="mb-3">
    <label asp-for="Name" class="form-label"></label>
    <input asp-for="Name" class="form-control" />
    <span asp-validation-for="Name" class="text-danger"></span>
</div>

<div class="mb-3">
    <label asp-for="Price" class="form-label"></label>
    <input asp-for="Price" class="form-control" />
    <span asp-validation-for="Price" class="text-danger"></span>
</div>
```
```cshtml
@* Views/Products/Create.cshtml *@
<form asp-action="Create" method="post">
    <partial name="_ProductFormFields" model="Model" />
    <button type="submit" class="btn btn-primary">Create</button>
</form>

@* Views/Products/Edit.cshtml *@
<form asp-action="Edit" method="post">
    <partial name="_ProductFormFields" model="Model" />
    <button type="submit" class="btn btn-primary">Save Changes</button>
</form>
```

**5. Placement convention — where to put partial files**
```
Views/
├── Shared/
│   ├── _Layout.cshtml
│   ├── _ProductCard.cshtml        ← shared across multiple controllers
│   └── _ValidationScriptsPartial.cshtml
├── Products/
│   ├── Index.cshtml
│   ├── _ProductFormFields.cshtml  ← only used within Products views
│   └── Details.cshtml
```

**6. Full path override — using a partial from outside its discoverable folder**
```cshtml
@* When a controller-specific partial is needed from a different controller's view,
   provide the full path instead of just the name *@
<partial name="~/Views/Products/_ProductFormFields.cshtml" model="Model" />
```

**7. Partial vs View Component — choosing the right tool**
```cshtml
@* Partial: parent fetches data and passes it down *@
@* Parent controller already loaded the supplier list *@
<partial name="_SupplierDropdown" model="Model.SupplierOptions" />

@* View Component: component fetches its own data *@
@* No data needed from the parent — the component calls a service internally *@
@await Component.InvokeAsync("ShoppingCart")
<vc:shopping-cart />
```

---

## Real World Example

A legal document management system where case files are reviewed on a detail page. The page combines a case summary, a list of attached documents (each with actions), and a comments thread. Each section is a partial — they each receive a slice of the case ViewModel, keeping the parent view readable and each partial independently maintainable.

```cshtml
@* Views/Cases/Detail.cshtml *@
@model CaseDetailViewModel

@{
    ViewData["Title"] = $"Case #{Model.CaseNumber}";
}

<div class="case-header">
    <h1>Case #@Model.CaseNumber</h1>
    <span class="badge @Model.StatusBadgeClass">@Model.StatusLabel</span>
</div>

@* Summary section — read-only, no actions *@
<partial name="_CaseSummary" model="Model.Summary" />

@* Documents section — shows edit/delete buttons only for the case owner *@
@{
    var docViewData = new ViewDataDictionary(ViewData) { { "IsOwner", Model.IsCurrentUserOwner } };
}
<partial name="_DocumentList" model="Model.Documents" view-data="docViewData" />

@* Comments — passes just the comments list, not the whole CaseDetailViewModel *@
<partial name="_CommentsThread" model="Model.Comments" />

@* Add comment form — only shown to authorised users *@
@if (Model.CanAddComments)
{
    <partial name="_AddCommentForm" model="new AddCommentDto { CaseId = Model.CaseId }" />
}

@section Scripts {
    <partial name="_ValidationScriptsPartial" />
}
```

```cshtml
@* Views/Cases/_DocumentList.cshtml *@
@model IEnumerable<DocumentSummary>

<div class="document-list mt-4">
    <h3>Documents (@Model.Count())</h3>

    @foreach (var doc in Model)
    {
        <div class="document-row d-flex justify-content-between align-items-center">
            <div>
                <strong>@doc.FileName</strong>
                <small class="text-muted ms-2">@doc.UploadedAt.ToString("d MMM yyyy")</small>
            </div>
            <div>
                <a asp-action="Download" asp-route-id="@doc.Id" class="btn btn-sm btn-outline-primary">Download</a>

                @if ((bool)(ViewData["IsOwner"] ?? false))
                {
                    <a asp-action="DeleteDocument" asp-route-id="@doc.Id"
                       class="btn btn-sm btn-outline-danger ms-1">Delete</a>
                }
            </div>
        </div>
    }
</div>
```

*The key insight: the parent view fetches all data once and passes each section exactly the slice it needs. `_DocumentList` receives only the documents, not the whole case. The `IsOwner` flag flows through `ViewData` because it's secondary context — a flag, not a model. This keeps the partial reusable: it can be used anywhere you need a document list, and the owner behaviour is controlled by the caller.*

---

## Common Misconceptions

**"Partials can fetch their own data if you use @inject inside them"**
You can inject a service into a partial with `@inject`, and it will work — but it's an architectural mistake. A partial that fetches its own data is a View Component with extra steps, without the testability or clear contract that a View Component provides. The parent controller should fetch the data and pass it down. If a component genuinely needs to be self-contained with its own data, make it a View Component.

**"Mutations to ViewData inside a partial flow back to the parent"**
Partials get a shallow copy of `ViewData` — they do not share the same dictionary instance. If a partial sets `ViewData["Title"] = "Something"`, the parent view will not see that change after the partial renders. Data flows one way: from parent to partial via the `model` and `view-data` parameters.

**"The underscore prefix on partial filenames is enforced by the framework"**
The framework doesn't care about the underscore. It's a naming convention that makes partials visually distinct and signals "not a standalone page" to developers. A partial named `ProductCard.cshtml` without an underscore works identically — you could navigate directly to it in the browser if there's a matching route, which is usually not what you want.

---

## Gotchas

- **Partials inherit `ViewData` from the parent but get a shallow copy — mutations inside the partial don't propagate back.** Use the explicit `view-data` parameter on the `<partial>` Tag Helper to pass data into a partial intentionally, and never rely on partial-to-parent data flow.

- **`@Html.Partial()` (synchronous) can deadlock in certain async controller scenarios.** The async version `@await Html.PartialAsync()` or the `<partial>` Tag Helper is always the safer choice. The sync version exists for legacy compatibility; `<partial>` should be the default in all new code.

- **A partial view does not inherit the parent's `@model` type — it always renders against the model you explicitly pass it.** If you omit the `model` parameter from `<partial name="_ProductCard" />`, the partial receives the parent's full model object as-is. If the partial's `@model` type doesn't match, you get a runtime `InvalidCastException`. Always pass the model explicitly.

- **Partials in `Views/Shared/` are found automatically by the view engine. Partials in a controller-specific folder are only found when rendering views from that controller.** A `_ProductCard.cshtml` in `Views/Products/` won't be found when you try to render it from `Views/Orders/`. Move shared partials to `Views/Shared/` or provide the full path: `<partial name="~/Views/Products/_ProductCard.cshtml" model="product" />`.

- **Client-side validation inside a partial is generated correctly, but the validation scripts must be loaded in the parent layout or view.** If `_ValidationScriptsPartial` isn't included in the parent page that uses a form partial, server-side validation still works but client-side validation silently does nothing.

- **Section blocks (`@section Scripts { }`) inside a partial are silently ignored.** Sections only work in full views that are directly rendered by a layout. If a partial tries to define a section, the section is discarded without error. Scripts needed by a partial must be included in the parent view's `@section Scripts { }` block.

---

## Interview Angle

**What they're really testing:** Whether you understand the rendering model — partials are server-side fragments with no independent data access — and whether you know when to use a partial vs a View Component.

**Common question forms:**
- *"What's the difference between a partial view and a View Component?"*
- *"When would you use a partial view vs duplicating markup across views?"*
- *"Can a partial view fetch its own data?"*

**The depth signal:** A junior answer describes partials as "reusable HTML snippets" and mentions the `<partial>` Tag Helper. A senior answer explains that partials can only render data passed to them from the parent — they have no way to fetch their own data — which is the exact line that separates them from View Components. A partial that needs to call a service to populate itself is an architectural mistake; the parent controller should fetch that data and pass it down. A senior also knows about the `Views/Shared/` discovery rule vs controller-specific folders, the sync vs async rendering gotcha, why mutations to `ViewData` inside a partial don't flow back to the parent, and why `@section` blocks inside partials are silently ignored.

**Follow-up questions to expect:**
- *"How do you pass secondary data to a partial alongside the model?"* (ViewData dictionary parameter)
- *"What happens if you define @section Scripts inside a partial?"* (silently ignored — sections only work in full views)

---

## Related Topics

- [[dotnet/mvc/mvc-views.md]] — Partial views live inside and are rendered by full views; understanding the view layer — layouts, sections, `@model` — is the prerequisite.
- [[dotnet/mvc/mvc-tag-helpers.md]] — The `<partial>` Tag Helper is how you render partials in modern Razor syntax; `asp-for` and validation Tag Helpers inside partials depend on the same `_ViewImports.cshtml` setup.
- [[dotnet/mvc/mvc-models.md]] — Partials are strongly typed to a ViewModel; the model passed to a partial is usually a subset or child of the parent view's model.
- [[dotnet/mvc/mvc-view-components.md]] — View Components are the right tool when a partial-like fragment needs its own data-fetching logic; understanding both makes clear which to reach for.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/views/partial

---
*Last updated: 2026-04-09*