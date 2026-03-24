# ASP.NET Core Web API Versioning

> API versioning lets you evolve your API over time by running multiple versions simultaneously so existing clients don't break when you make changes.

---

## When To Use It

Use it from the start on any API consumed by clients you don't fully control — mobile apps, third-party integrations, or public APIs. Retrofitting versioning onto an existing API is painful and forces awkward URL changes. Don't bother for internal APIs where you deploy the client and server together and can change both at once. The problem it solves is the classic "I need to change this endpoint but clients are still using the old shape" — versioning gives you a migration path instead of a flag day.

---

## Core Concept

The standard library for this is `Asp.Versioning.Http` (formerly `Microsoft.AspNetCore.Mvc.Versioning`). You declare which version(s) a controller or endpoint supports with `[ApiVersion]`, register the versioning services, and tell the framework where to read the version from — URL segment (`/api/v2/orders`), query string (`?api-version=2.0`), or header (`Api-Version: 2.0`). The framework matches the requested version to a controller that supports it and returns 400 or 404 if no match is found. You can mark a version as deprecated so clients get a warning in the response headers without the version being removed yet. Controllers that share a route but differ only in version are called version groups — the library handles the disambiguation so you don't get ambiguous route errors.

---

## The Code
```csharp
// --- Setup in Program.cs ---
builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1, 0);
    options.AssumeDefaultVersionWhenUnspecified = true;   // clients without a version get v1
    options.ReportApiVersions = true;                     // adds api-supported-versions header to responses
    options.ApiVersionReader = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),                 // /api/v1/orders
        new QueryStringApiVersionReader("api-version"),   // ?api-version=1.0
        new HeaderApiVersionReader("Api-Version")         // Api-Version: 1.0
    );
})
.AddApiExplorer(options =>
{
    options.GroupNameFormat = "'v'VVV";                   // v1, v2 in Swagger groups
    options.SubstituteApiVersionInUrl = true;
});
```
```csharp
// --- URL segment versioning: two controllers for the same resource ---
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/orders")]
public class OrdersV1Controller : ControllerBase
{
    [HttpGet("{id:int}")]
    public IActionResult Get(int id) => Ok(new { id, version = "v1", status = "pending" });
}

[ApiController]
[ApiVersion("2.0")]
[Route("api/v{version:apiVersion}/orders")]
public class OrdersV2Controller : ControllerBase
{
    [HttpGet("{id:int}")]
    public IActionResult Get(int id) =>
        Ok(new { id, version = "v2", status = "pending", createdAt = DateTime.UtcNow });
}

// GET /api/v1/orders/5 → OrdersV1Controller.Get
// GET /api/v2/orders/5 → OrdersV2Controller.Get
```
```csharp
// --- Deprecating a version (still works, but clients are warned) ---
[ApiController]
[ApiVersion("1.0", Deprecated = true)]
[ApiVersion("2.0")]
[Route("api/v{version:apiVersion}/products")]
public class ProductsController : ControllerBase
{
    [HttpGet, MapToApiVersion("1.0")]
    public IActionResult GetV1() => Ok(new { shape = "v1" });

    [HttpGet, MapToApiVersion("2.0")]
    public IActionResult GetV2() => Ok(new { shape = "v2" });
}

// Response headers for v1 requests include:
// api-deprecated-versions: 1.0
// api-supported-versions: 1.0, 2.0
```
```csharp
// --- Query string versioning (no URL change required) ---
// GET /api/orders?api-version=2.0
[ApiController]
[ApiVersion("1.0")]
[ApiVersion("2.0")]
[Route("api/orders")]
public class OrdersController : ControllerBase
{
    [HttpGet, MapToApiVersion("1.0")]
    public IActionResult GetV1() => Ok("v1 response");

    [HttpGet, MapToApiVersion("2.0")]
    public IActionResult GetV2() => Ok("v2 response");
}
```
```csharp
// --- Minimal API versioning (.NET 7+) ---
var orders = app.NewVersionedApi("Orders");

var v1 = orders.MapGroup("/api/v{version:apiVersion}/orders").HasApiVersion(1.0);
var v2 = orders.MapGroup("/api/v{version:apiVersion}/orders").HasApiVersion(2.0);

v1.MapGet("/", () => Results.Ok("v1 orders"));
v2.MapGet("/", () => Results.Ok("v2 orders"));
```
```csharp
// --- Swagger / OpenAPI with versioned documents ---
// ConfigureSwaggerOptions generates one Swagger document per discovered API version
builder.Services.AddTransient<IConfigureOptions<SwaggerGenOptions>, ConfigureSwaggerOptions>();
builder.Services.AddSwaggerGen();

// In Configure / app setup:
var descriptions = app.DescribeApiVersions();

app.UseSwaggerUI(options =>
{
    foreach (var desc in descriptions)
    {
        options.SwaggerEndpoint(
            $"/swagger/{desc.GroupName}/swagger.json",
            desc.GroupName.ToUpperInvariant());
    }
});
```

---

## Gotchas

- **`AssumeDefaultVersionWhenUnspecified = true` masks missing version headers silently.** It's useful during rollout, but it means clients that forget to send a version get v1 forever with no error. When all clients are updated, turn it off so unversioned requests get a clear 400 rather than silently routing to an outdated version.
- **URL segment versioning requires `{version:apiVersion}` in the route template — not just `{version}`.** Using the plain `{version}` token makes it a regular route parameter that the versioning middleware ignores entirely. The route constraint `apiVersion` is what connects the URL token to the versioning system. This is the most common setup mistake and produces a 404 for all versioned requests.
- **`[MapToApiVersion]` is required when multiple versions share one controller class.** If you have `[ApiVersion("1.0")]` and `[ApiVersion("2.0")]` on the same controller with two `[HttpGet]` methods and no `[MapToApiVersion]`, the framework throws `AmbiguousMatchException` because it can't decide which action to use for either version. You must tag each action explicitly.
- **Deprecated versions still need to be removed eventually.** Marking a version `Deprecated = true` only adds a response header warning — it does not stop routing or set a removal deadline. Without a defined sunset policy enforced in code or infrastructure (a middleware that rejects requests after a date), deprecated versions tend to stay in production indefinitely.
- **Swagger won't generate separate documents unless you configure `AddApiExplorer` correctly.** Just calling `AddApiVersioning` without `AddApiExplorer(o => o.GroupNameFormat = "'v'VVV")` means all versions collapse into a single undifferentiated Swagger document. The `SubstituteApiVersionInUrl = true` option is also needed, or the Swagger UI shows the literal `{version}` placeholder in URL examples instead of the actual version number.

---

## Interview Angle

**What they're really testing:** Whether you understand the trade-offs between versioning strategies and can reason about backward compatibility as an API design discipline — not just the mechanics of a library.

**Common question form:** "How would you version a REST API?" or "What's the difference between URL versioning and header versioning?" or "How do you handle breaking changes without breaking existing clients?"

**The depth signal:** A junior knows to put `v1` in the URL. A senior can compare the three strategies on their merits: URL versioning is the most visible and cacheable (CDNs treat `/v1/orders` and `/v2/orders` as different resources), query string versioning is the least disruptive for existing URLs but bypasses caching, and header versioning is the most RESTful (the URL identifies the resource, the header identifies the representation) but the least discoverable and hardest to test in a browser. They also know when to use a single controller with `[MapToApiVersion]` vs separate controller classes, and how to wire `ConfigureSwaggerOptions` with `IApiVersionDescriptionProvider` to generate versioned OpenAPI documents automatically.

---

## Related Topics

- [[dotnet/webapi-routing.md]] — URL segment versioning (`/api/v{version:apiVersion}/...`) is built on top of the routing system; understanding route constraints explains how `apiVersion` works
- [[dotnet/webapi-controllers.md]] — versioning is applied at the controller level with `[ApiVersion]`; controller discovery and the `MapControllers()` call are what make multiple versioned controllers work
- [[dotnet/webapi-middleware-pipeline.md]] — a sunset middleware that rejects requests to deprecated versions after a date belongs in the middleware pipeline, not in a filter or controller
- [[dotnet/webapi-openapi.md]] — versioned APIs need one Swagger document per version; the `AddApiExplorer` configuration and `IApiVersionDescriptionProvider` tie versioning to OpenAPI generation

---

## Source

[https://github.com/dotnet/aspnet-api-versioning/wiki](https://github.com/dotnet/aspnet-api-versioning/wiki)

---
*Last updated: 2026-03-24*