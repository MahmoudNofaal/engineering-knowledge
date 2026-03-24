# MVC Partial Views

> Reusable chunks of Razor markup that render a fragment of HTML inside a parent view — without their own layout, lifecycle, or HTTP request.

---

## When To Use It

Use partial views when the same block of HTML needs to appear in multiple views, or when a single view is getting long enough that splitting it into named sections makes it easier to read and maintain. Good candidates are product cards, comment threads, navigation menus, and form sections that repeat across pages. Don't use partial views when the component needs its own data-fetching logic — that's what View Components are for. If the partial needs to call a service or query a database to get its own data, a partial view is the wrong tool because it can only work with what the parent passes it.

---

## Core Concept

A partial view is just a `.cshtml` file, conventionally prefixed with an underscore (`_ProductCard.cshtml`) to signal it's not a standalone page. The parent view renders it inline using `<partial>` Tag Helper or `@await Html.PartialAsync()`, passing a model explicitly. The partial renders synchronously into the parent's output stream — there's no separate HTTP request, no separate route, no layout wrapping. It's a server-side include with typed data. The underscore prefix is purely convention — the framework doesn't enforce it — but it keeps partials visually distinct from full views in the `Views/` folder and prevents accidental direct navigation to them.

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

**2. Rendering a partial from a parent view — three equivalent ways**
```cshtml
@* Views/Products/Index.cshtml *@
@model ProductIndexViewModel

@foreach (var product in Model.Products)
{
    @* Preferred: Tag Helper syntax — reads like HTML *@
    <partial name="_ProductCard" model="product" />

    @* Async HTML Helper — use when you need the return value or can't use Tag Helper *@
    @await Html.PartialAsync("_ProductCard", product)

    @* Sync version — avoid in async controllers, can deadlock in some edge cases *@
    @Html.Partial("_ProductCard", product)
}
```

**3. Partial with ViewData (for passing secondary data alongside the model)**
```cshtml
@{
    var viewData = new ViewDataDictionary(ViewData)
    {
        { "ShowActions", true }  // flag the partial can read
    };
}
<partial name="_ProductCard" model="product" view-data="viewData" />
```
```cshtml
@* Inside _ProductCard.cshtml — reading from ViewData *@
@if ((bool)(ViewData["ShowActions"] ?? false))
{
    <a asp-action="Edit" asp-route-id="@Model.Id">Edit</a>
}
```

**4. Partial used for a form section (reused across Create and Edit views)**
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
    <button type="submit">Create</button>
</form>

@* Views/Products/Edit.cshtml *@
<form asp-action="Edit" method="post">
    <partial name="_ProductFormFields" model="Model" />
    <button type="submit">Save Changes</button>
</form>
```

**5. Placement convention — where to put partial files**
```
Views/
├── Shared/
│   ├── _Layout.cshtml
│   ├── _ProductCard.cshtml      ← shared across multiple controllers
│   └── _ValidationScriptsPartial.cshtml
├── Products/
│   ├── Index.cshtml
│   ├── _ProductFormFields.cshtml  ← only used within Products views
│   └── Details.cshtml
```

---

## Gotchas

- **Partials inherit `ViewData` from the parent but get a shallow copy of it — mutations inside the partial don't propagate back to the parent.** If a partial sets `ViewData["Title"]`, the parent view won't see that change after the partial renders. Use the explicit `view-data` parameter on the `<partial>` Tag Helper to pass data into a partial intentionally, and never rely on partial-to-parent data flow.
- **`@Html.Partial()` (synchronous) can deadlock in certain async controller scenarios.** The async version `@await Html.PartialAsync()` or the `<partial>` Tag Helper is always the safer choice. The sync version exists for legacy compatibility and Razor Pages where sync rendering is sometimes necessary, but `<partial>` should be the default in new code.
- **A partial view does not inherit the parent's `@model` type — it always renders against the model you explicitly pass it.** If you omit the `model` parameter from `<partial name="_ProductCard" />`, the partial receives the parent's full model object as-is. If the partial's `@model` type doesn't match, you get a runtime `InvalidCastException`. Always pass the model explicitly.
- **Partials in `Views/Shared/` are found automatically by the view engine. Partials in a controller-specific folder are only found when rendering views from that controller.** A `_ProductCard.cshtml` in `Views/Products/` won't be found when you try to render it from `Views/Orders/`. Move shared partials to `Views/Shared/` or provide the full path: `<partial name="~/Views/Products/_ProductCard.cshtml" model="product" />`.
- **Client-side validation (`data-val-*` attributes) inside a partial is generated correctly, but the validation scripts must be loaded in the parent layout or view.** If `_ValidationScriptsPartial` isn't included in the parent page that uses a form partial, server-side validation still works but client-side validation silently does nothing. The form submits without any browser-side checks.

---

## Interview Angle

**What they're really testing:** Whether you understand the rendering model — partials are server-side fragments with no independent data access — and whether you know when to use a partial vs a View Component.

**Common question form:** *"What's the difference between a partial view and a View Component?"* or *"When would you use a partial view vs duplicating markup across views?"*

**The depth signal:** A junior answer describes partials as "reusable HTML snippets" and mentions the `<partial>` Tag Helper. A senior answer explains that partials can only render data passed to them from the parent — they have no way to fetch their own data — which is the exact line that separates them from View Components. A partial that needs to call a service to populate itself is an architectural mistake; the parent controller should fetch that data and pass it down. A senior also knows about the `Views/Shared/` discovery rule vs controller-specific folders, the sync vs async rendering gotcha, and why mutations to `ViewData` inside a partial don't flow back to the parent.

---

## Related Topics

- [[dotnet/mvc-views.md]] — Partial views live inside and are rendered by full views; understanding the view layer — layouts, sections, `@model` — is the prerequisite.
- [[dotnet/mvc-tag-helpers.md]] — The `<partial>` Tag Helper is how you render partials in modern Razor syntax; `asp-for` and validation Tag Helpers inside partials depend on the same `_ViewImports.cshtml` setup.
- [[dotnet/mvc-models.md]] — Partials are strongly typed to a ViewModel; the model passed to a partial is usually a subset or child of the parent view's model.
- [[dotnet/mvc-view-components.md]] — View Components are the right tool when a partial-like fragment needs its own data-fetching logic; understanding both makes clear which to reach for.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/views/partial

---
*Last updated: 2026-03-24*