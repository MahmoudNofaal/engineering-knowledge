# ASP.NET Core Web API Versioning

> API versioning lets you evolve your API over time by running multiple versions simultaneously so existing clients don't break when you make changes.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Multi-version endpoint dispatch — same URL namespace, different controller logic per version |
| **Use when** | Any API consumed by clients you don't fully control (mobile, third-party, public) |
| **Avoid when** | Internal APIs where you deploy client and server together and can change both at once |
| **Introduced** | Third-party `Asp.Versioning.Http` (formerly `Microsoft.AspNetCore.Mvc.Versioning`) |
| **Namespace** | `Asp.Versioning` |
| **Key types** | `ApiVersion`, `ApiVersionReader`, `IApiVersionDescriptionProvider`, `MapToApiVersion` |

---

## When To Use It

Use it from the start on any API consumed by clients you don't fully control — mobile apps, third-party integrations, or public APIs. Retrofitting versioning onto an existing API is painful and forces awkward URL changes. Don't bother for internal APIs where you deploy the client and server together and can change both at once. The problem it solves is the classic "I need to change this endpoint but clients are still using the old shape" — versioning gives you a migration path instead of a flag day.

---

## Core Concept

The standard library is `Asp.Versioning.Http`. You declare which version(s) a controller or endpoint supports with `[ApiVersion]`, register the versioning services, and tell the framework where to read the version from — URL segment (`/api/v2/orders`), query string (`?api-version=2.0`), or header (`Api-Version: 2.0`). The framework matches the requested version to a controller that supports it and returns 400 or 404 if no match is found. You can mark a version as deprecated so clients get a warning in response headers without the version being removed. Controllers that share a route but differ only in version are called version groups — the library handles disambiguation so you don't get ambiguous route errors.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | Third-party `Microsoft.AspNetCore.Mvc.Versioning` package |
| ASP.NET Core 3.0 | Endpoint routing integration improved |
| .NET 6 | `Asp.Versioning.Http` — new package name, improved minimal API support |
| .NET 7 | `NewVersionedApi()` for minimal API route groups with versioning |
| .NET 8 | `IApiVersionDescriptionProvider` improvements; better OpenAPI integration |

*`Asp.Versioning.Http` is a rename/rewrite of the older `Microsoft.AspNetCore.Mvc.Versioning`. If you see tutorials using the old package name, the concepts are the same but some type names differ.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Version extraction (URL) | O(1) | Route parameter already parsed |
| Version extraction (header/query) | O(1) | Dictionary lookup |
| Controller selection by version | O(log n) | n = number of versioned controller registrations |
| Deprecated version header write | ~1 µs | Simple header append |

**Allocation behaviour:** Version reading from URL segments is free — it reuses the route value already extracted during routing. Header and query string reading allocate string comparisons. Versioning adds negligible overhead to the action selection pipeline.

**Benchmark notes:** Versioning overhead is unmeasurable in practice. The version lookup is a compile-time compiled route + a dictionary key comparison. Optimise for correctness and maintainability, not versioning performance.

---

## The Code

**Setup in Program.cs**
```csharp
builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion                   = new ApiVersion(1, 0);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions                   = true;
    options.ApiVersionReader = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),
        new QueryStringApiVersionReader("api-version"),
        new HeaderApiVersionReader("Api-Version")
    );
})
.AddApiExplorer(options =>
{
    options.GroupNameFormat       = "'v'VVV";
    options.SubstituteApiVersionInUrl = true;
});
```

**URL segment versioning — two controllers for the same resource**
```csharp
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/orders")]
public class OrdersV1Controller : ControllerBase
{
    [HttpGet("{id:int}")]
    public IActionResult Get(int id) =>
        Ok(new { id, version = "v1", status = "pending" });
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
// GET /api/v1/orders/5 → V1
// GET /api/v2/orders/5 → V2
```

**Deprecated version**
```csharp
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
// v1 response headers include:
// api-deprecated-versions: 1.0
// api-supported-versions: 1.0, 2.0
```

**Minimal API versioning (.NET 7+)**
```csharp
var orders = app.NewVersionedApi("Orders");
var v1 = orders.MapGroup("/api/v{version:apiVersion}/orders").HasApiVersion(1.0);
var v2 = orders.MapGroup("/api/v{version:apiVersion}/orders").HasApiVersion(2.0);

v1.MapGet("/", () => Results.Ok("v1 orders"));
v2.MapGet("/", () => Results.Ok("v2 orders"));
```

**OpenAPI / Swagger with versioned documents**
```csharp
builder.Services.AddTransient<IConfigureOptions<SwaggerGenOptions>, ConfigureSwaggerOptions>();
builder.Services.AddSwaggerGen();

var descriptions = app.DescribeApiVersions();
app.UseSwaggerUI(options =>
{
    foreach (var desc in descriptions)
        options.SwaggerEndpoint(
            $"/swagger/{desc.GroupName}/swagger.json",
            desc.GroupName.ToUpperInvariant());
});
```

---

## Real World Example

A payment API has three clients: a web app (can update quickly), a mobile app (update cycle is weeks), and a third-party partner (locked to v1 contractually). V1 stays stable; v2 adds new fields; v3 restructures the response entirely. All three live simultaneously.

```csharp
// V1 — legacy contract, deprecated but contractually required
[ApiController]
[ApiVersion("1.0", Deprecated = true)]
[Route("api/v{version:apiVersion}/payments")]
public class PaymentsV1Controller : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Charge([FromBody] ChargeRequestV1 req)
    {
        var result = await _payments.ChargeAsync(req.Amount, req.CardToken);
        return Ok(new { success = result.Success, transactionId = result.Id });
    }
}

// V2 — adds currency and metadata fields
[ApiController]
[ApiVersion("2.0")]
[Route("api/v{version:apiVersion}/payments")]
public class PaymentsV2Controller : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Charge([FromBody] ChargeRequestV2 req)
    {
        var result = await _payments.ChargeAsync(req.Amount, req.Currency, req.CardToken, req.Metadata);
        return Ok(new { success = result.Success, transactionId = result.Id, currency = req.Currency });
    }
}

// V3 — restructured response with payment intent model
[ApiController]
[ApiVersion("3.0")]
[Route("api/v{version:apiVersion}/payments")]
public class PaymentsV3Controller : ControllerBase
{
    [HttpPost("intents")]
    public async Task<IActionResult> CreateIntent([FromBody] PaymentIntentRequest req)
    {
        var intent = await _payments.CreateIntentAsync(req);
        return CreatedAtAction(nameof(GetIntent), new { id = intent.Id }, intent);
    }

    [HttpGet("intents/{id:guid}", Name = "GetIntent")]
    public async Task<IActionResult> GetIntent(Guid id) =>
        Ok(await _payments.GetIntentAsync(id));
}
```

*The key insight: V1 is deprecated but not removed — the `Deprecated = true` flag adds a warning header that clients can detect and act on. The partner sees the deprecation header and knows they need to migrate, but their existing integration still works. V3's restructured design (payment intents) doesn't break V1 or V2 clients.*

---

## Common Misconceptions

**"Deprecated versions stop working automatically."**
`Deprecated = true` only adds a response header warning. It does not restrict routing, set a removal deadline, or enforce a sunset date. Without explicit enforcement (a middleware that rejects deprecated version requests after a date), deprecated versions stay in production indefinitely.

**"`AssumeDefaultVersionWhenUnspecified = true` is safe to leave on permanently."**
Useful during rollout, but it means clients that forget to send a version silently get v1 forever. When all clients are updated, turn it off so unversioned requests get a clear 400 rather than silently routing to an outdated version.

**"URL segment versioning and query string versioning have the same trade-offs."**
URL versioning (`/v1/orders`) is cacheable at the CDN level — `/v1/orders` and `/v2/orders` are different URLs with independent cache entries. Query string versioning (`?api-version=1.0`) uses the same URL, which CDNs may not vary on. Header versioning (`Api-Version: 1.0`) is the most RESTful but the least discoverable and hardest to test in a browser.

---

## Gotchas

- **`{version:apiVersion}` in the route template is required — plain `{version}` is ignored.** Using `{version}` makes it a regular route parameter that the versioning middleware ignores. The `apiVersion` constraint connects the URL token to the versioning system. This is the most common setup mistake and produces 404 for all versioned requests.

- **`[MapToApiVersion]` is required when multiple versions share one controller.** If you have `[ApiVersion("1.0")]` and `[ApiVersion("2.0")]` on the same controller with two `[HttpGet]` methods and no `[MapToApiVersion]`, the framework throws `AmbiguousMatchException`.

- **Swagger won't generate separate documents without `AddApiExplorer` configured correctly.** All versions collapse into one Swagger document. `SubstituteApiVersionInUrl = true` is also needed, or Swagger UI shows the literal `{version}` placeholder in URL examples.

- **Deprecated versions still need to be removed eventually.** Without a defined sunset policy enforced in code or infrastructure, deprecated versions stay in production indefinitely.

- **`AssumeDefaultVersionWhenUnspecified = true` masks missing version headers.** Unversioned requests silently route to v1 forever. Turn it off once all clients are migrated.

---

## Interview Angle

**What they're really testing:** Whether you understand the trade-offs between versioning strategies and can reason about backward compatibility as an API design discipline.

**Common question forms:**
- "How would you version a REST API?"
- "What's the difference between URL versioning and header versioning?"
- "How do you handle breaking changes without breaking existing clients?"

**The depth signal:** A junior knows to put `v1` in the URL. A senior compares the three strategies: URL versioning is cacheable (CDNs treat `/v1/` and `/v2/` as different resources), query string versioning is least disruptive but bypasses CDN caching, header versioning is most RESTful but least discoverable. They also know when to use a single controller with `[MapToApiVersion]` vs separate controller classes, and how to wire `ConfigureSwaggerOptions` with `IApiVersionDescriptionProvider` to generate versioned OpenAPI documents automatically.

**Follow-up questions to expect:**
- "How would you enforce a sunset date for a deprecated API version?"
- "How do you generate separate Swagger documents per API version?"
- "How does versioning interact with authentication middleware?"

---

## Related Topics

- [[dotnet/webapi/webapi-routing.md]] — URL segment versioning builds on route constraints; `{version:apiVersion}` is the key constraint
- [[dotnet/webapi/webapi-controllers.md]] — `[ApiVersion]` and `[MapToApiVersion]` are applied at the controller and action level
- [[dotnet/webapi/middleware-pipeline.md]] — a sunset middleware that rejects deprecated version requests after a date belongs in the pipeline
- [[dotnet/webapi/webapi-openapi.md]] — versioned APIs need one Swagger document per version; `AddApiExplorer` ties versioning to OpenAPI generation

---

## Source

https://github.com/dotnet/aspnet-api-versioning/wiki

---
*Last updated: 2026-04-10*