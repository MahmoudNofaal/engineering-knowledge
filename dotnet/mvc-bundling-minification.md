# MVC Bundling & Minification

> The process of combining multiple CSS or JavaScript files into fewer files (bundling) and stripping whitespace and comments from them (minification) to reduce the number and size of HTTP requests a browser makes when loading a page.

---

## When To Use It

Use it in production for any MVC app that serves its own static assets — CSS, JavaScript, and fonts. Every unbundled file is a separate HTTP request; on a page with ten CSS files and fifteen JS files, that's twenty-five round trips before the page can render. In development, keep assets unbundled so browser DevTools shows the original file names and line numbers when debugging. Don't apply this to assets already served from a CDN — they're already optimised and the CDN handles caching. If your frontend is a fully separate SPA built with Vite or webpack, those tools handle bundling themselves and this topic is irrelevant.

---

## Core Concept

ASP.NET Core doesn't have built-in bundling the way ASP.NET 4.x did with `System.Web.Optimization`. The modern replacement is the `BundlerMinifier` MSBuild task or, more commonly, the `WebOptimizer` middleware library. Both work by reading a config file that maps input files to an output bundle path, then producing a single minified file at build time or at startup. In the Razor layout, instead of six `<link>` or `<script>` tags, you reference the one bundle path. The `asp-append-version` Tag Helper adds a cache-busting hash to the URL so browsers fetch the new bundle on deploy without you manually incrementing a version number. In development the middleware can serve the originals unminified so stack traces are readable.

---

## The Code

**1. Install WebOptimizer (the most common approach)**
```bash
dotnet add package LigerShark.WebOptimizer.Core
```

**2. Register WebOptimizer in Program.cs**
```csharp
// Program.cs
builder.Services.AddWebOptimizer(pipeline =>
{
    // Bundle and minify multiple CSS files into one output path
    pipeline.AddCssBundle("/css/bundle.css",
        "css/site.css",
        "css/components.css",
        "css/overrides.css");

    // Bundle and minify JS files — order matters, dependencies first
    pipeline.AddJavaScriptBundle("/js/bundle.js",
        "js/vendor/jquery.js",
        "js/site.js",
        "js/product-filter.js");

    // Minify individual files without bundling (useful for per-page scripts)
    pipeline.MinifyCssFiles();
    pipeline.MinifyJsFiles();
});

var app = builder.Build();

// Must come before UseStaticFiles so the middleware intercepts bundle paths
app.UseWebOptimizer();
app.UseStaticFiles();
```

**3. Reference bundles in the layout**
```cshtml
@* Views/Shared/_Layout.cshtml *@
<head>
    @* asp-append-version adds a content hash — busts cache on deploy *@
    <link rel="stylesheet" href="~/css/bundle.css" asp-append-version="true" />
</head>
<body>
    @RenderBody()

    <script src="~/js/bundle.js" asp-append-version="true"></script>
    @RenderSection("Scripts", required: false)
</body>
```

**4. Environment-aware: unminified in dev, bundled in production**
```cshtml
@* Views/Shared/_Layout.cshtml *@

<environment include="Development">
    @* Individual files — full names visible in DevTools *@
    <link rel="stylesheet" href="~/css/site.css" />
    <link rel="stylesheet" href="~/css/components.css" />
    <script src="~/js/vendor/jquery.js"></script>
    <script src="~/js/site.js"></script>
</environment>

<environment exclude="Development">
    @* Bundled and minified for staging and production *@
    <link rel="stylesheet" href="~/css/bundle.css" asp-append-version="true" />
    <script src="~/js/bundle.js" asp-append-version="true"></script>
</environment>
```

**5. BundleConfig.json (alternative: BundlerMinifier MSBuild task)**
```json
// bundleconfig.json — processed at build time by the BundlerMinifier package
[
  {
    "outputFileName": "wwwroot/css/bundle.css",
    "inputFiles": [
      "wwwroot/css/site.css",
      "wwwroot/css/components.css"
    ]
  },
  {
    "outputFileName": "wwwroot/js/bundle.js",
    "inputFiles": [
      "wwwroot/js/vendor/jquery.js",
      "wwwroot/js/site.js"
    ],
    "minify": {
      "enabled": true,
      "renameLocals": true
    }
  }
]
```

**6. Verify the cache-busting hash in output**
```html
<!-- asp-append-version generates a fingerprinted URL -->
<!-- Changes automatically when the file content changes -->
<link rel="stylesheet" href="/css/bundle.css?v=pELkTejOutd7Xg4MsIOqqg">
<script src="/js/bundle.js?v=R3QLPb8HaU2tyeRNMsTVzA"></script>
```

---

## Gotchas

- **`app.UseWebOptimizer()` must be registered before `app.UseStaticFiles()`.** If the order is reversed, `UseStaticFiles` intercepts the bundle path first, finds no file at that path in `wwwroot`, and returns 404. The bundle middleware never gets a chance to serve the assembled file.
- **JavaScript bundle order is not alphabetical — it's the order you declare in the pipeline.** If `site.js` calls a function defined in `jquery.js` but you put `site.js` first in the bundle, you get a runtime `$ is not defined` error that only appears after bundling — it works fine in development when files load in separate `<script>` tags. Always put dependencies first.
- **`asp-append-version` requires the file to exist on disk at render time when using `BundlerMinifier`.** If you reference `/css/bundle.css` with `asp-append-version="true"` but the bundle hasn't been generated yet (first `dotnet build` on a clean machine, for example), the Tag Helper can't hash the file and silently omits the version query string. Run a build before testing the layout in CI.
- **Minification can break JavaScript that relies on implicit global variable names or non-strict property access.** Variable renaming during minification turns `function calculateTotal()` into `function a()`, which breaks any code outside the bundle that calls `calculateTotal()` by name. Expose public APIs through a module pattern or a namespaced object (`window.MyApp.calculateTotal`) so the minifier only renames internals.
- **The `<environment>` Tag Helper reads `ASPNETCORE_ENVIRONMENT` case-sensitively on Linux.** `exclude="development"` (lowercase) never matches `Development` on a Linux host, so your production server serves the un-bundled individual files. Use exact casing: `Development`, `Staging`, `Production`.

---

## Interview Angle

**What they're really testing:** Whether you understand why bundling and minification matter (HTTP request count and payload size), and whether you know the practical wiring — middleware order, cache busting, and environment-aware serving.

**Common question form:** *"How do you handle static asset bundling in ASP.NET Core MVC?"* or *"What is cache busting and how does `asp-append-version` implement it?"*

**The depth signal:** A junior answer describes combining files to make pages faster. A senior answer explains the HTTP/1.1 parallel request limit that makes bundle count matter (less relevant under HTTP/2 but still real for HTTP/1.1 clients), why `UseWebOptimizer` must precede `UseStaticFiles` in the pipeline, the JS ordering trap where dependencies must be listed first in the bundle, how `asp-append-version` generates a content-derived hash (not a timestamp) so the URL only changes when the file actually changes, and why minification-driven variable renaming can break external callers — and what module patterns prevent it.

---

## Related Topics

- [[dotnet/mvc-layout-sections.md]] — Bundle `<link>` and `<script>` tags live in the layout; sections let individual views inject page-specific scripts after the bundle without touching the layout.
- [[dotnet/mvc-views.md]] — The `<environment>` Tag Helper used to switch between bundled and unbundled assets is a Razor view feature; understanding Razor syntax and Tag Helpers is the prerequisite.
- [[dotnet/mvc-tag-helpers.md]] — `asp-append-version` is a Tag Helper; it must be registered via `_ViewImports.cshtml` like all other Tag Helpers.
- [[devops/static-asset-cdn.md]] — In production, bundles are often pushed to a CDN rather than served by Kestrel; the bundle path becomes a CDN URL, and cache busting becomes the CDN's invalidation strategy.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/client-side/bundling-and-minification

---
*Last updated: 2026-03-24*