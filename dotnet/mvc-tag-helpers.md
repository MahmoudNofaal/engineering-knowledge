# MVC Tag Helpers

> Server-side components in ASP.NET Core Razor views that look like HTML attributes but generate correct, route-aware HTML at render time — replacing the older `Html.BeginForm()` / `Html.TextBoxFor()` helper syntax.

---

## When To Use It

Use Tag Helpers any time you're writing Razor views and need to generate links, forms, inputs, or validation messages that are tied to your routes or model properties. They're the default in every ASP.NET Core MVC template and produce cleaner, more readable `.cshtml` files than the older `HtmlHelper` methods. Don't use `Html.ActionLink()`, `Html.TextBoxFor()`, or `Html.BeginForm()` in new code — Tag Helpers replaced them and produce identical output with less noise. If you're building a pure JSON API with no views, Tag Helpers are irrelevant.

---

## Core Concept

Tag Helpers are C# classes that target specific HTML elements or attributes and run on the server before the response is sent. They look like plain HTML — `<a asp-action="Details">` — but at render time the framework swaps in the correct URL, input name, validation message, or whatever the helper is responsible for. The key benefit over the old `Html.TextBoxFor(m => m.Name)` syntax is that Tag Helpers sit inside the HTML rather than replacing it, so designers can open the file in a browser and see something sensible, and developers can read the markup without mentally translating C# method chains into HTML output. The `asp-for`, `asp-action`, `asp-controller`, `asp-route-*`, and `asp-validation-for` attributes are the ones you'll use on almost every form.

---

## The Code

**1. Anchor Tag Helper — generates route-aware links**
```cshtml
@* Generates: <a href="/products/details/5">View</a> *@
<a asp-controller="Products" asp-action="Details" asp-route-id="5">View</a>

@* Generates the same href but uses the current controller implicitly *@
<a asp-action="Index">Back to List</a>

@* External link — no asp-* attributes, rendered as-is *@
<a href="https://example.com">External</a>
```

**2. Form Tag Helper — action URL + anti-forgery token**
```cshtml
@model CreateProductDto

@*
  Generates: <form action="/products/create" method="post">
  Also injects the hidden __RequestVerificationToken field automatically
*@
<form asp-action="Create" asp-controller="Products" method="post">

    <div class="form-group">
        @* asp-for sets id, name, type, value, and data-val-* validation attrs *@
        <label asp-for="Name"></label>
        <input asp-for="Name" class="form-control" />
        <span asp-validation-for="Name" class="text-danger"></span>
    </div>

    <div class="form-group">
        <label asp-for="Price"></label>
        <input asp-for="Price" class="form-control" />
        <span asp-validation-for="Price" class="text-danger"></span>
    </div>

    <button type="submit">Create</button>
</form>

@section Scripts {
    <partial name="_ValidationScriptsPartial" />
}
```

**3. Select Tag Helper — dropdown from a list**
```cshtml
@* In the ViewModel: *@
@* public SelectList CategoryOptions { get; set; } *@
@* public int SelectedCategoryId { get; set; } *@

<select asp-for="SelectedCategoryId" asp-items="Model.CategoryOptions"
        class="form-control">
    <option value="">-- Select a Category --</option>
</select>
<span asp-validation-for="SelectedCategoryId" class="text-danger"></span>
```

**4. Environment Tag Helper — render blocks conditionally per environment**
```cshtml
@* Renders only in Development *@
<environment include="Development">
    <script src="~/js/app.js"></script>
</environment>

@* Renders in Staging and Production *@
<environment exclude="Development">
    <script src="~/js/app.min.js"></script>
</environment>
```

**5. Cache Tag Helper — cache a partial render server-side**
```cshtml
@* Output of this block is cached for 60 seconds *@
<cache expires-after="@TimeSpan.FromSeconds(60)">
    <partial name="_ExpensiveWidget" model="Model.WidgetData" />
</cache>
```

**6. Custom Tag Helper**
```csharp
// TagHelpers/AlertTagHelper.cs
[HtmlTargetElement("alert")]  // targets <alert> elements
public class AlertTagHelper : TagHelper
{
    public string Type { get; set; } = "info"; // maps to type="danger" etc.

    public override async Task ProcessAsync(
        TagHelperContext context,
        TagHelperOutput output)
    {
        output.TagName = "div";  // <alert> becomes <div>
        output.Attributes.SetAttribute("class", $"alert alert-{Type}");

        var content = await output.GetChildContentAsync();
        output.Content.SetHtmlContent(content.GetContent());
    }
}
```
```cshtml
@* Usage — reads cleanly in markup *@
<alert type="danger">Something went wrong.</alert>

@* Renders as: *@
@* <div class="alert alert-danger">Something went wrong.</div> *@
```

**7. _ViewImports.cshtml — required for Tag Helpers to work**
```cshtml
@* Views/_ViewImports.cshtml *@
@using MyApp
@using MyApp.ViewModels
@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers  @* built-in helpers *@
@addTagHelper *, MyApp                                @* your custom helpers *@
```

---

## Gotchas

- **If `asp-*` attributes render as literal HTML instead of being processed, `_ViewImports.cshtml` is missing or incomplete.** Tag Helpers are opt-in per the `@addTagHelper` directive. A missing `_ViewImports.cshtml`, or a file that exists but doesn't include the right assembly, silently leaves all `asp-*` attributes as plain text in the output. Check the file exists at `Views/_ViewImports.cshtml` and includes both the built-in and your custom assembly.
- **`<form asp-action="Create">` injects an anti-forgery token automatically — adding `@Html.AntiForgeryToken()` inside the same form writes a second token.** Two tokens in one form isn't a breaking error, but it's redundant and indicates the developer didn't know the Tag Helper was already doing this. Use one or the other, not both.
- **`asp-for` on an `<input>` uses the property's display name for the `id` and `name` attributes, which follow the full model path.** If your ViewModel has a nested object `Address.City`, the generated `name` is `Address.City` — which is what model binding expects for nested types. If you rename the property, the generated `name` changes too, silently breaking form binding until you re-check.
- **The `<environment>` Tag Helper reads `ASPNETCORE_ENVIRONMENT` exactly — it's case-sensitive on Linux.** `include="development"` (lowercase) will never match `Development` on a Linux host. Always use the exact casing you set in your environment variable (`Development`, `Staging`, `Production`).
- **Custom Tag Helpers in a class library won't be discovered unless the assembly is explicitly added to `@addTagHelper`.** Adding `@addTagHelper *, MyApp` only scans the `MyApp` assembly. If your Tag Helper lives in `MyApp.UI`, you need a separate `@addTagHelper *, MyApp.UI` line. The wildcard is per-assembly, not recursive across your whole solution.

---

## Interview Angle

**What they're really testing:** Whether you understand what Tag Helpers actually do at render time and how they differ from the older `HtmlHelper` API — and whether you know the `_ViewImports.cshtml` wiring that makes them work.

**Common question form:** *"What are Tag Helpers and how are they different from HTML Helpers?"* or *"How does `asp-for` know what to generate for an input field?"*

**The depth signal:** A junior answer says Tag Helpers "generate HTML for you" and describes `asp-action` and `asp-for`. A senior answer explains that Tag Helpers are server-side components that transform the element at render time, that `asp-for` reads the model metadata (data annotations, display names, property type) to set `id`, `name`, `type`, `value`, and all `data-val-*` attributes for client-side validation in one shot, that the `<form>` Tag Helper injects the anti-forgery token automatically, and that nothing works without the `@addTagHelper` directive in `_ViewImports.cshtml` — a silent failure that wastes hours if you don't know where to look.

---

## Related Topics

- [[dotnet/mvc-views.md]] — Tag Helpers live inside Razor views; understanding the view layer is the prerequisite for knowing when and where to use each helper.
- [[dotnet/mvc-models.md]] — `asp-for` reads model metadata — data annotations, property names, types — to generate input attributes; the ViewModel design directly affects what Tag Helpers emit.
- [[dotnet/mvc-controllers.md]] — `asp-action` and `asp-controller` generate URLs that must match actual controller action routes; mismatches produce 404s at runtime, not compile errors.
- [[dotnet/webapi-authentication.md]] — The anti-forgery token injected by the form Tag Helper is validated by `[ValidateAntiForgeryToken]` on the controller action; understanding both sides makes the CSRF protection mechanism clear.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/views/tag-helpers/intro

---
*Last updated: 2026-03-24*