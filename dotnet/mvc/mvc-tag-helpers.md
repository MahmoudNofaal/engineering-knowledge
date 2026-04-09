# MVC Tag Helpers

> Server-side components in ASP.NET Core Razor views that look like HTML attributes but generate correct, route-aware HTML at render time — replacing the older `Html.BeginForm()` / `Html.TextBoxFor()` helper syntax.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Server-side HTML transformers that run at render time |
| **Use when** | Generating links, forms, inputs, validation messages in Razor views |
| **Avoid when** | Pure JSON APIs with no views; `.cshtml` files where `_ViewImports.cshtml` is missing |
| **Registered via** | `@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers` in `_ViewImports.cshtml` |
| **Namespace** | `Microsoft.AspNetCore.Mvc.TagHelpers` |
| **Key attributes** | `asp-for`, `asp-action`, `asp-controller`, `asp-route-*`, `asp-validation-for`, `asp-append-version` |

---

## When To Use It

Use Tag Helpers any time you're writing Razor views and need to generate links, forms, inputs, or validation messages that are tied to your routes or model properties. They're the default in every ASP.NET Core MVC template and produce cleaner, more readable `.cshtml` files than the older `HtmlHelper` methods. Don't use `Html.ActionLink()`, `Html.TextBoxFor()`, or `Html.BeginForm()` in new code — Tag Helpers replaced them and produce identical output with far less noise. If you're building a pure JSON API with no views, Tag Helpers are irrelevant.

---

## Core Concept

Tag Helpers are C# classes that target specific HTML elements or attributes and run on the server before the response is sent. They look like plain HTML — `<a asp-action="Details">` — but at render time the framework swaps in the correct URL, input name, validation message, or whatever the helper is responsible for. The key benefit over the old `Html.TextBoxFor(m => m.Name)` syntax is that Tag Helpers sit inside the HTML rather than replacing it, so designers can open the file in a browser and see something sensible, and developers can read the markup without mentally translating C# method chains into HTML output.

`asp-for` is the most powerful Tag Helper attribute. On an `<input>`, it reads the model property's type, data annotations, and display name to generate `id`, `name`, `type`, `value`, and every `data-val-*` attribute needed for client-side validation — all in one attribute. On a `<label>`, it generates the correct `for` attribute and display text. On `<span asp-validation-for>`, it generates the element where validation error messages appear.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | Tag Helpers introduced; replaced `HtmlHelper` as the recommended view syntax |
| ASP.NET Core 1.1 | .NET Core 1.1 | `<cache>` Tag Helper added for server-side output caching |
| ASP.NET Core 2.0 | .NET Core 2.0 | `<environment>` Tag Helper improved; `asp-append-version` stabilised |
| ASP.NET Core 2.1 | .NET Core 2.1 | `<partial>` Tag Helper added; Razor Class Library Tag Helpers support |
| ASP.NET Core 3.0 | .NET Core 3.0 | `<component>` Tag Helper added for Blazor components in Razor views |
| ASP.NET Core 6.0 | .NET 6 | `<persist-component-state>` Tag Helper added for Blazor SSR |
| ASP.NET Core 8.0 | .NET 8 | `<form-context>` and enhanced form Tag Helpers for Blazor/MVC hybrid scenarios |

*Before Tag Helpers, ASP.NET MVC 5 used `HtmlHelper` methods: `@Html.TextBoxFor(m => m.Name)`, `@Html.BeginForm()`, etc. These returned `IHtmlContent` objects — not actual HTML elements — which made views hard to read and impossible for HTML tools to parse correctly. Tag Helpers solved this by making the helpers look like HTML.*

---

## The Code

**1. Anchor Tag Helper — generates route-aware links**
```cshtml
@* Generates: <a href="/products/details/5">View</a> *@
<a asp-controller="Products" asp-action="Details" asp-route-id="5">View</a>

@* Uses current controller implicitly *@
<a asp-action="Index">Back to List</a>

@* Additional route values — maps to /products/search?keyword=chair&inStock=true *@
<a asp-action="Search" asp-route-keyword="chair" asp-route-inStock="true">Search chairs</a>

@* External link — no asp-* attributes, rendered as-is *@
<a href="https://example.com">External</a>
```

**2. Form Tag Helper — action URL + anti-forgery token injection**
```cshtml
@model CreateProductDto

@*
  Generates: <form action="/products/create" method="post">
  Also injects the hidden __RequestVerificationToken field automatically.
  Do NOT also call @Html.AntiForgeryToken() — that writes a second token.
*@
<form asp-action="Create" asp-controller="Products" method="post">

    <div class="mb-3">
        @* asp-for sets id, name, type, value, and all data-val-* validation attributes *@
        <label asp-for="Name" class="form-label"></label>
        <input asp-for="Name" class="form-control" />
        <span asp-validation-for="Name" class="text-danger"></span>
    </div>

    <div class="mb-3">
        <label asp-for="Price" class="form-label"></label>
        <input asp-for="Price" class="form-control" />
        <span asp-validation-for="Price" class="text-danger"></span>
    </div>

    <button type="submit" class="btn btn-primary">Create</button>
</form>

@section Scripts {
    <partial name="_ValidationScriptsPartial" />
}
```

**3. Select Tag Helper — dropdown from a list**
```cshtml
@* In the ViewModel: *@
@* public SelectList CategoryOptions { get; set; } *@
@* public int SelectedCategoryId    { get; set; } *@

<select asp-for="SelectedCategoryId" asp-items="Model.CategoryOptions"
        class="form-control">
    <option value="">-- Select a Category --</option>
</select>
<span asp-validation-for="SelectedCategoryId" class="text-danger"></span>
```

**4. Image Tag Helper — cache-busted image src**
```cshtml
@* Appends a content hash to the image URL — same mechanism as asp-append-version on scripts/styles *@
<img asp-append-version="true" src="~/images/logo.png" alt="Logo" />
@* Renders as: <img src="/images/logo.png?v=R3QLPb8..." alt="Logo"> *@
```

**5. Environment Tag Helper — render blocks conditionally per environment**
```cshtml
@* Renders only in Development *@
<environment include="Development">
    <script src="~/js/app.js"></script>
</environment>

@* Renders in Staging and Production *@
<environment exclude="Development">
    <script src="~/js/app.min.js" asp-append-version="true"></script>
</environment>
```

**6. Cache Tag Helper — cache a partial render server-side**
```cshtml
@* Output of this block is cached for 60 seconds *@
<cache expires-after="@TimeSpan.FromSeconds(60)">
    <partial name="_PopularProducts" model="Model.Popular" />
</cache>

@* Vary cache by user claim (e.g., different content per role) *@
<cache vary-by-user="true" expires-after="@TimeSpan.FromMinutes(5)">
    <partial name="_PersonalisedWidget" model="Model.UserData" />
</cache>
```

**7. Custom Tag Helper**
```csharp
// TagHelpers/AlertTagHelper.cs
[HtmlTargetElement("alert")]
public class AlertTagHelper : TagHelper
{
    public string Type { get; set; } = "info";  // maps to type="danger", "success", etc.

    public override async Task ProcessAsync(
        TagHelperContext context,
        TagHelperOutput  output)
    {
        output.TagName = "div";
        output.Attributes.SetAttribute("class", $"alert alert-{Type} alert-dismissible");

        var content = await output.GetChildContentAsync();
        output.Content.SetHtmlContent(content.GetContent());
    }
}
```
```cshtml
@* Usage *@
<alert type="danger">Something went wrong.</alert>

@* Renders as: *@
@* <div class="alert alert-danger alert-dismissible">Something went wrong.</div> *@
```

**8. _ViewImports.cshtml — required for Tag Helpers to work**
```cshtml
@* Views/_ViewImports.cshtml *@
@using MyApp
@using MyApp.ViewModels
@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers  @* built-in helpers *@
@addTagHelper *, MyApp                                @* custom helpers in your assembly *@
```

**9. Opting out of Tag Helper processing on a specific element**
```cshtml
@* Prefix with ! to prevent Tag Helper processing — useful when you want a literal asp-for *@
<!a asp-action="Details">This renders as a literal <a> with asp-action as a plain attribute</!a>
```

---

## Real World Example

A multi-step checkout form spread across three views (cart review, address entry, payment). Each step uses Tag Helpers heavily — the address form uses `asp-for` for every field, a `<select>` with `asp-items` for country, and a custom `<step-indicator>` Tag Helper that renders the three-step progress bar based on the current step value in `ViewData`.

```cshtml
@* Views/Checkout/Address.cshtml *@
@model CheckoutAddressDto

@{
    ViewData["Title"]       = "Delivery address";
    ViewData["CurrentStep"] = 2;
}

@* Custom Tag Helper reads CurrentStep from ViewData and renders progress dots *@
<step-indicator steps="3" current="@ViewData["CurrentStep"]" />

<form asp-action="Address" asp-controller="Checkout" method="post">

    <div class="row">
        <div class="col-md-6 mb-3">
            <label asp-for="FirstName" class="form-label"></label>
            <input asp-for="FirstName" class="form-control" autocomplete="given-name" />
            <span asp-validation-for="FirstName" class="text-danger"></span>
        </div>
        <div class="col-md-6 mb-3">
            <label asp-for="LastName" class="form-label"></label>
            <input asp-for="LastName" class="form-control" autocomplete="family-name" />
            <span asp-validation-for="LastName" class="text-danger"></span>
        </div>
    </div>

    <div class="mb-3">
        <label asp-for="CountryCode" class="form-label"></label>
        <select asp-for="CountryCode" asp-items="Model.CountryOptions" class="form-select">
            <option value="">-- Select country --</option>
        </select>
        <span asp-validation-for="CountryCode" class="text-danger"></span>
    </div>

    <div class="d-flex justify-content-between mt-4">
        <a asp-action="Cart" class="btn btn-outline-secondary">Back to cart</a>
        <button type="submit" class="btn btn-primary">Continue to payment</button>
    </div>

</form>

@section Scripts {
    <partial name="_ValidationScriptsPartial" />
}
```

```csharp
// TagHelpers/StepIndicatorTagHelper.cs
[HtmlTargetElement("step-indicator")]
public class StepIndicatorTagHelper : TagHelper
{
    public int Steps   { get; set; } = 3;
    public int Current { get; set; } = 1;

    public override void Process(TagHelperContext context, TagHelperOutput output)
    {
        output.TagName = "div";
        output.Attributes.SetAttribute("class", "step-indicator");

        var html = new StringBuilder();
        for (int i = 1; i <= Steps; i++)
        {
            var cls = i < Current ? "step done" : i == Current ? "step active" : "step";
            html.Append($"<span class=\"{cls}\">{i}</span>");
        }

        output.Content.SetHtmlContent(html.ToString());
    }
}
```

*The key insight: every form field in the view is two lines — a `<label asp-for>` and an `<input asp-for>` — and `asp-for` handles the `id`, `name`, `type`, `value`, autocomplete wiring, and all `data-val-*` attributes for client-side validation from the data annotations on the DTO. The custom `StepIndicatorTagHelper` keeps the checkout view clean — no inline C# loops for the progress bar.*

---

## Common Misconceptions

**"Tag Helpers and HTML Helpers produce different output"**
They produce identical HTML. `<a asp-action="Details" asp-route-id="5">View</a>` and `@Html.ActionLink("View", "Details", new { id = 5 })` both generate `<a href="/products/details/5">View</a>`. The difference is readability and tooling — Tag Helpers look like HTML so editors parse them correctly, and designers don't see C# method calls. The output is the same.

**"asp-for on an input only sets the name attribute"**
`asp-for` does far more than just the `name`. On an `<input>`, it sets `id`, `name`, `type` (inferred from the property type — `type="number"` for numeric types, `type="checkbox"` for bool), `value` (from the current model value), and every `data-val-*` attribute for client-side validation based on the property's data annotations. A single `asp-for="Price"` on an `<input>` can generate six or more attributes.

**"If my asp-* attributes aren't working I have a bug in my view"**
Unprocessed `asp-*` attributes appearing as literal HTML in the browser output are almost always caused by a missing or broken `_ViewImports.cshtml`, not a bug in the view itself. Check that `_ViewImports.cshtml` exists at `Views/_ViewImports.cshtml` and contains `@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers`. This is a silent failure — no exception, just literal attribute names in the rendered HTML.

---

## Gotchas

- **If `asp-*` attributes render as literal HTML instead of being processed, `_ViewImports.cshtml` is missing or incomplete.** Tag Helpers are opt-in per the `@addTagHelper` directive. A missing `_ViewImports.cshtml`, or a file that exists but doesn't include the right assembly, silently leaves all `asp-*` attributes as plain text in the output.

- **`<form asp-action="Create">` injects an anti-forgery token automatically — adding `@Html.AntiForgeryToken()` inside the same form writes a second token.** Two tokens in one form isn't a breaking error, but it's redundant and indicates the developer didn't know the Tag Helper was already doing this.

- **`asp-for` on an `<input>` uses the full model path for `name`, including nested objects.** If your ViewModel has a nested object `Address.City`, the generated `name` is `Address.City` — which is what model binding expects for nested types. If you rename the property, the generated `name` changes too, silently breaking form binding until you notice.

- **The `<environment>` Tag Helper reads `ASPNETCORE_ENVIRONMENT` case-sensitively on Linux.** `include="development"` (lowercase) will never match `Development` on a Linux host. Always use exact casing: `Development`, `Staging`, `Production`.

- **Custom Tag Helpers in a class library won't be discovered unless the assembly is explicitly added to `@addTagHelper`.** Adding `@addTagHelper *, MyApp` only scans the `MyApp` assembly. If your Tag Helper lives in `MyApp.UI`, you need a separate `@addTagHelper *, MyApp.UI` line.

- **Tag Helper processing can be suppressed per-element with the `!` prefix.** If you need a literal `<a>` element with an `asp-*` attribute that should not be processed, prefix the tag name with `!`: `<!a asp-action="...">`. This is rarely needed but is the escape hatch when Tag Helpers conflict with non-ASP.NET templating tools.

---

## Interview Angle

**What they're really testing:** Whether you understand what Tag Helpers actually do at render time and how they differ from the older `HtmlHelper` API — and whether you know the `_ViewImports.cshtml` wiring that makes them work.

**Common question forms:**
- *"What are Tag Helpers and how are they different from HTML Helpers?"*
- *"How does `asp-for` know what to generate for an input field?"*
- *"Why are my asp-* attributes showing up as literal text in the browser?"*

**The depth signal:** A junior answer says Tag Helpers "generate HTML for you" and describes `asp-action` and `asp-for`. A senior answer explains that Tag Helpers are server-side components that transform the element at render time, that `asp-for` reads the model metadata (data annotations, display names, property type) to set `id`, `name`, `type`, `value`, and all `data-val-*` attributes for client-side validation in one shot, that the `<form>` Tag Helper injects the anti-forgery token automatically, and that nothing works without the `@addTagHelper` directive in `_ViewImports.cshtml` — a silent failure that wastes hours if you don't know where to look.

**Follow-up questions to expect:**
- *"How do you create a custom Tag Helper?"* (inherit `TagHelper`, override `ProcessAsync`, use `[HtmlTargetElement]`)
- *"What's the difference between `asp-append-version` and a CDN URL?"* (content hash vs CDN cache invalidation)

---

## Related Topics

- [[dotnet/mvc/mvc-views.md]] — Tag Helpers live inside Razor views; understanding the view layer is the prerequisite for knowing when and where to use each helper.
- [[dotnet/mvc/mvc-models.md]] — `asp-for` reads model metadata — data annotations, property names, types — to generate input attributes; the ViewModel design directly affects what Tag Helpers emit.
- [[dotnet/mvc/mvc-controllers.md]] — `asp-action` and `asp-controller` generate URLs that must match actual controller action routes; mismatches produce 404s at runtime, not compile errors.
- [[dotnet/mvc/mvc-bundling-minification.md]] — `asp-append-version` on bundles in the layout is a Tag Helper; it requires `_ViewImports.cshtml` registration like all other Tag Helpers.
- [[dotnet/webapi-authentication.md]] — The anti-forgery token injected by the form Tag Helper is validated by `[ValidateAntiForgeryToken]` on the controller action; understanding both sides makes the CSRF protection mechanism clear.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/views/tag-helpers/intro

---
*Last updated: 2026-04-09*