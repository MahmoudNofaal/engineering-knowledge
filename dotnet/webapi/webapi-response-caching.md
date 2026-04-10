# ASP.NET Core Web API Response Caching & Output Caching

> Response caching stores a complete HTTP response and serves it directly for subsequent matching requests, bypassing the controller and any downstream work entirely.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Two complementary systems: `Cache-Control` header generation (client/CDN) and server-side response store |
| **Use when** | GET endpoints returning the same data for the same inputs over a predictable window |
| **Avoid when** | User-specific data without careful `Vary` headers; frequently-invalidated data |
| **Introduced** | `[ResponseCache]` ASP.NET Core 1.0; Output Caching middleware .NET 7 |
| **Namespace** | `Microsoft.AspNetCore.ResponseCaching`, `Microsoft.AspNetCore.OutputCaching` |
| **Key types** | `ResponseCacheAttribute`, `OutputCacheAttribute`, `IOutputCacheStore`, `OutputCacheOptions` |

---

## When To Use It

Use it for endpoints that return the same data for the same inputs over a predictable window: reference data, product catalogues, public dashboards, lookup tables. It's most effective on GET endpoints where the response is identical for all users (or all users in a segment). Don't use it for endpoints that return user-specific data unless you're careful with `Vary` headers — a cached response for user A leaking to user B is a serious security bug. Don't confuse response caching (client/CDN `Cache-Control` headers) with output caching (server-side store with tag-based invalidation) — they're different mechanisms that can work together.

---

## Core Concept

HTTP has a built-in caching model defined by `Cache-Control` headers. When a response has `Cache-Control: public, max-age=60`, any HTTP cache in the chain — the browser, a CDN, a reverse proxy — can store it and serve it for 60 seconds without hitting your server. ASP.NET Core's `[ResponseCache]` attribute generates those headers for you. The `ResponseCaching` middleware adds a server-side in-memory cache on top. Output Caching (.NET 7) is the modern replacement — more flexible, supports cache invalidation by tag, and doesn't have the middleware ordering pitfalls of `ResponseCaching`.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | `[ResponseCache]` attribute — generates `Cache-Control` headers |
| ASP.NET Core 1.1 | `ResponseCaching` middleware — server-side in-memory cache |
| .NET 7 | **Output Caching** middleware — server-side with tag-based invalidation, policies, `IOutputCacheStore` |
| .NET 8 | Redis `IOutputCacheStore` implementation available via `Microsoft.AspNetCore.OutputCaching.StackExchangeRedis` |

*Output Caching in .NET 7 supersedes `ResponseCaching` middleware for new projects. `ResponseCaching` still works but has no tag-based invalidation and stricter middleware ordering requirements. For any new server-side caching, use Output Caching.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Cache hit (Output Caching) | ~1 µs | Dictionary lookup + response write from store |
| Cache miss | Same as uncached | Controller runs normally |
| Tag-based invalidation | ~1 ms | Removes all cache entries matching the tag |
| `[ResponseCache]` header write | ~1 µs | String append; no server-side storage |

**Allocation behaviour:** `ResponseCaching` stores the full serialised response byte array per cache key. Output Caching does the same but with a structured store interface that can be backed by Redis for distributed caching. Memory usage scales with (number of unique URLs) × (average response size). Monitor memory pressure in services with high cardinality routes (`/api/products/{id}` caches one entry per product).

**Benchmark notes:** Cache hits eliminate all downstream work (DB queries, service calls, JSON serialisation). For read-heavy endpoints on stable data, caching is the single highest-leverage performance optimisation. A 5-second TTL on a product listing that takes 50 ms to generate means 98% of requests never touch the database.

---

## The Code

**`[ResponseCache]` — generates `Cache-Control` headers only**
```csharp
// The browser and CDN cache this for 60 seconds.
// The server itself does NOT cache unless ResponseCaching or OutputCaching middleware is added.
[HttpGet("categories")]
[ResponseCache(Duration = 60, Location = ResponseCacheLocation.Any, NoStore = false)]
public IActionResult GetCategories() => Ok(_catalog.GetCategories());
// Produces: Cache-Control: public, max-age=60
```

**Cache profiles — define once, apply by name**
```csharp
builder.Services.AddControllers(options =>
{
    options.CacheProfiles.Add("PublicShort", new CacheProfile
        { Duration = 60, Location = ResponseCacheLocation.Any });
    options.CacheProfiles.Add("PublicLong",  new CacheProfile
        { Duration = 3600, Location = ResponseCacheLocation.Any });
    options.CacheProfiles.Add("NoCache",     new CacheProfile { NoStore = true });
});

[HttpGet("countries")]
[ResponseCache(CacheProfileName = "PublicLong")]
public IActionResult GetCountries() => Ok(_reference.Countries);
```

**Output Caching (.NET 7+) — server-side with invalidation**
```csharp
// Program.cs
builder.Services.AddOutputCache(options =>
{
    options.AddBasePolicy(policy => policy.Expire(TimeSpan.FromSeconds(60)));

    options.AddPolicy("LongLived", policy =>
        policy.Expire(TimeSpan.FromHours(1))
              .SetVaryByQuery("q", "page")
              .Tag("reference-data"));
});

app.UseOutputCache();   // single placement — before MapControllers

// Apply to a controller action
[HttpGet("categories")]
[OutputCache(PolicyName = "LongLived")]
public async Task<IActionResult> GetCategories() =>
    Ok(await _catalog.GetCategoriesAsync());

// Apply to a minimal API endpoint
app.MapGet("/api/categories", async (ICatalogService svc) =>
    Results.Ok(await svc.GetCategoriesAsync()))
   .CacheOutput("LongLived");

// Invalidate by tag when data changes
[HttpPost("categories")]
[Authorize(Roles = "Admin")]
public async Task<IActionResult> Create(
    [FromBody] CreateCategoryRequest req,
    [FromServices] IOutputCacheStore store,
    CancellationToken ct)
{
    var category = await _catalog.CreateAsync(req);
    await store.EvictByTagAsync("reference-data", ct);  // clears all LongLived cache entries
    return CreatedAtAction(nameof(GetCategories), null, category);
}
```

**Vary by query string**
```csharp
[HttpGet("search")]
[OutputCache(VaryByQueryKeys = new[] { "q", "page", "pageSize" }, Duration = 30)]
public async Task<IActionResult> Search(
    [FromQuery] string q,
    [FromQuery] int page = 1,
    [FromQuery] int pageSize = 20) =>
    Ok(await _search.QueryAsync(q, page, pageSize));
```

**Distributed Output Caching with Redis (.NET 8)**
```csharp
// dotnet add package Microsoft.AspNetCore.OutputCaching.StackExchangeRedis
builder.Services.AddStackExchangeRedisOutputCache(options =>
{
    options.Configuration = builder.Configuration["Redis:ConnectionString"];
    options.InstanceName  = "OutputCache:";
});
builder.Services.AddOutputCache();
```

---

## Real World Example

A product catalogue API serves millions of requests daily. Category listing is static for hours; product search results vary by query and page. Tag-based invalidation allows admin edits to immediately clear the relevant cache without a TTL wait.

```csharp
// Output cache policies
builder.Services.AddOutputCache(options =>
{
    // Category list: cached for 4 hours, tagged for invalidation
    options.AddPolicy("categories", policy =>
        policy.Expire(TimeSpan.FromHours(4))
              .Tag("category-cache")
              .SetVaryByHeader("Accept-Language"));

    // Product search: 30 seconds, varies by query params
    options.AddPolicy("product-search", policy =>
        policy.Expire(TimeSpan.FromSeconds(30))
              .SetVaryByQuery("q", "page", "pageSize", "category", "sort"));

    // Product detail: 10 minutes per product ID
    options.AddPolicy("product-detail", policy =>
        policy.Expire(TimeSpan.FromMinutes(10))
              .SetVaryByRouteValue("id")
              .Tag("product-cache"));
});

[ApiController]
[Route("api/categories")]
public class CategoriesController : ControllerBase
{
    [HttpGet]
    [OutputCache(PolicyName = "categories")]
    public async Task<IActionResult> GetAll() =>
        Ok(await _categories.GetAllAsync());

    [HttpPost]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create(
        [FromBody] CreateCategoryRequest req,
        [FromServices] IOutputCacheStore store,
        CancellationToken ct)
    {
        var cat = await _categories.CreateAsync(req);
        await store.EvictByTagAsync("category-cache", ct);  // immediate invalidation
        return CreatedAtAction(nameof(GetAll), null, cat);
    }
}

[ApiController]
[Route("api/products")]
public class ProductsController : ControllerBase
{
    [HttpGet]
    [OutputCache(PolicyName = "product-search")]
    public async Task<IActionResult> Search(
        [FromQuery] string? q,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20) =>
        Ok(await _products.SearchAsync(q, page, pageSize));

    [HttpGet("{id:guid}")]
    [OutputCache(PolicyName = "product-detail")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var product = await _products.GetAsync(id);
        return product is null ? NotFound() : Ok(product);
    }

    [HttpPut("{id:guid}")]
    [Authorize]
    public async Task<IActionResult> Update(
        Guid id,
        [FromBody] UpdateProductRequest req,
        [FromServices] IOutputCacheStore store,
        CancellationToken ct)
    {
        var updated = await _products.UpdateAsync(id, req);
        await store.EvictByTagAsync("product-cache", ct);
        return Ok(updated);
    }
}
```

*The key insight: tag-based invalidation means cached product data is always consistent with the database — no "stale data for up to N minutes" problem. When an admin updates a product, the update endpoint evicts `"product-cache"` immediately. The next request to that product gets a fresh database read and populates a new cache entry.*

---

## Common Misconceptions

**"`[ResponseCache]` caches on the server."**
It only generates `Cache-Control` response headers. Whether anything is stored depends on what reads those headers: the client browser, a CDN, or the `ResponseCaching` middleware. Without the middleware or Output Caching, every request still hits the controller. This is the most common response caching mistake.

**"Short TTLs solve the stale data problem."**
Short TTLs reduce the staleness window but don't eliminate it. A 30-second TTL still serves 30 seconds of stale data after an update. Tag-based invalidation via Output Caching's `EvictByTagAsync` eliminates staleness entirely — the update and invalidation happen in the same operation.

**"Response caching and output caching are interchangeable."**
`[ResponseCache]` produces `Cache-Control` headers for client/CDN caching. Output Caching stores responses server-side with tag-based invalidation. They target different layers of the caching chain and have different invalidation models. Output Caching is superior for server-side caching in new projects; `[ResponseCache]` is still useful for CDN cache control.

---

## Gotchas

- **`[ResponseCache]` alone does not cache on the server.** Generates headers only. Requires `ResponseCaching` middleware or Output Caching for server-side storage.

- **`VaryByQueryKeys` does nothing without `ResponseCaching` middleware.** Server-side feature. Without `app.UseResponseCaching()`, no Vary header appears and every request goes to the controller.

- **`UseResponseCaching` must be placed before `UseRouting`.** If after, the cache stores responses but never intercepts requests on the way in — silent failure. Output Caching doesn't have this ordering requirement.

- **Cached responses are served stale until TTL expires in `ResponseCaching`.** No automatic invalidation. Output Caching's `EvictByTagAsync` solves this.

- **`AllowAnyOrigin` CORS + `ResponseCaching` can serve the wrong `Access-Control-Allow-Origin` to clients.** If a request with `Origin: A` is cached, the cached response (with `Origin: A` in the CORS header) may be served to a request with `Origin: B`. Use `[DisableCors]` or don't cache endpoints that have CORS responses unless all origins are identical.

- **Output Caching with Redis requires all server instances to share the same Redis instance.** Without a distributed store, each pod has its own cache and clients round-robined to different pods see inconsistent cache states.

---

## Interview Angle

**What they're really testing:** Whether you understand HTTP caching semantics at the protocol level and where in the request pipeline caching fits — and the difference between client/CDN and server-side caching.

**Common question forms:**
- "How would you cache this endpoint's response?"
- "What's the difference between `Cache-Control: public` and `Cache-Control: private`?"
- "How would you invalidate a cached response when the underlying data changes?"

**The depth signal:** A junior knows `[ResponseCache(Duration = 60)]` and that it "caches the response." A senior explains the full caching chain — browser → CDN → server middleware — and which layer each approach targets. They know `[ResponseCache]` only generates headers, that Output Caching's tag-based invalidation is the correct solution for cache invalidation, and that `ETag` / `Last-Modified` enable conditional requests where the server returns 304 Not Modified instead of the full body.

**Follow-up questions to expect:**
- "How would you share the output cache across multiple API instances?"
- "What's the difference between `ResponseCaching` middleware and Output Caching?"
- "How does Output Caching interact with authentication?"

---

## Related Topics

- [[dotnet/webapi/middleware-pipeline.md]] — `UseResponseCaching` and `UseOutputCache` are middleware; their position determines whether they intercept requests correctly
- [[dotnet/webapi/webapi-filters.md]] — result filters are an alternative for imperatively setting cache headers when `[ResponseCache]` isn't flexible enough
- [[databases/nosql/redis-fundamentals.md]] — distributed caching with Redis is the complement to response caching across multiple API instances
- [[dotnet/webapi/webapi-cors.md]] — CORS headers in cached responses can be served to the wrong origin; be careful when caching CORS-enabled endpoints

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/performance/caching/output

---
*Last updated: 2026-04-10*