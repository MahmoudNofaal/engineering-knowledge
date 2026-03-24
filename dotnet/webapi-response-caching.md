# ASP.NET Core Web API Response Caching

> Response caching stores a complete HTTP response and serves it directly for subsequent matching requests, bypassing the controller and any downstream work entirely.

---

## When To Use It

Use it for endpoints that return the same data for the same inputs over a predictable window: reference data, product catalogues, public dashboards, lookup tables. It's most effective on GET endpoints where the response is identical for all users (or all users in a segment). Don't use it for endpoints that return user-specific data unless you're careful with `Vary` headers — a cached response for user A leaking to user B is a serious security bug. Don't confuse it with output caching (server-side) vs response caching (`Cache-Control` headers driving client/proxy caching) — they are different mechanisms that can work together.

---

## Core Concept

HTTP has a built-in caching model defined by `Cache-Control` headers. When a response has `Cache-Control: public, max-age=60`, any HTTP cache in the chain — the browser, a CDN, a reverse proxy — can store it and serve it for 60 seconds without hitting your server. ASP.NET Core's `[ResponseCache]` attribute generates those headers for you. The `ResponseCaching` middleware adds a server-side cache on top: it stores the response in memory on your server and short-circuits subsequent matching requests before they reach your controller. Output Caching (introduced in .NET 7) is the modern replacement for the middleware approach — it's more flexible, supports cache invalidation, and doesn't have the middleware ordering pitfalls of the older `ResponseCaching`.

---

## The Code
```csharp
// --- [ResponseCache] attribute: generates Cache-Control headers ---
// The browser and any CDN/proxy will cache this for 60 seconds.
// The server itself does NOT cache unless ResponseCaching middleware is added.
[HttpGet("categories")]
[ResponseCache(Duration = 60, Location = ResponseCacheLocation.Any, NoStore = false)]
public IActionResult GetCategories()
{
    return Ok(_catalogService.GetCategories());
}

// Equivalent Cache-Control header produced:
// Cache-Control: public, max-age=60
```
```csharp
// --- Cache profiles: define once, apply by name ---
// In Program.cs:
builder.Services.AddControllers(options =>
{
    options.CacheProfiles.Add("PublicShort",  new CacheProfile { Duration = 60,   Location = ResponseCacheLocation.Any });
    options.CacheProfiles.Add("PublicLong",   new CacheProfile { Duration = 3600, Location = ResponseCacheLocation.Any });
    options.CacheProfiles.Add("NoCache",      new CacheProfile { NoStore = true });
});

// On actions:
[HttpGet("countries")]
[ResponseCache(CacheProfileName = "PublicLong")]
public IActionResult GetCountries() => Ok(_referenceData.Countries);

[HttpGet("account")]
[ResponseCache(CacheProfileName = "NoCache")]       // user-specific — never cache
public IActionResult GetAccount() => Ok(_userService.GetCurrentUser());
```
```csharp
// --- Vary headers: cache separate copies per header value ---
// Without Vary: all clients get the same cached response regardless of Accept-Language.
// With Vary: a separate cache entry is stored per language value.
[HttpGet("labels")]
[ResponseCache(Duration = 300, Location = ResponseCacheLocation.Any, VaryByHeader = "Accept-Language")]
public IActionResult GetLabels() => Ok(_i18n.GetLabels(Request.Headers["Accept-Language"]));

// VaryByQueryKeys requires the ResponseCaching middleware (server-side):
[HttpGet("search")]
[ResponseCache(Duration = 30, VaryByQueryKeys = new[] { "q", "page" })]
public IActionResult Search([FromQuery] string q, [FromQuery] int page = 1) => Ok();
```
```csharp
// --- ResponseCaching middleware (server-side, in-memory) ---
// Program.cs — order matters: UseResponseCaching must come before UseRouting
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddResponseCaching();
builder.Services.AddControllers();

var app = builder.Build();
app.UseResponseCaching();           // must be before routing for cache to intercept requests
app.UseRouting();
app.UseAuthorization();
app.MapControllers();
app.Run();
```
```csharp
// --- Output Caching (.NET 7+): the modern server-side approach ---
// Supports tagging, imperative invalidation, and policies without the ordering gotchas.
builder.Services.AddOutputCache(options =>
{
    options.AddBasePolicy(policy => policy.Expire(TimeSpan.FromSeconds(60)));

    options.AddPolicy("LongLived", policy =>
        policy.Expire(TimeSpan.FromHours(1))
              .SetVaryByQuery("q", "page")
              .Tag("reference-data"));           // allows invalidation by tag
});

var app = builder.Build();
app.UseOutputCache();               // single correct placement — before MapControllers

app.MapGet("/api/categories", async (ICatalogService svc) =>
{
    var data = await svc.GetCategoriesAsync();
    return Results.Ok(data);
}).CacheOutput("LongLived");

// Invalidate by tag when data changes (e.g., in an admin endpoint):
app.MapPost("/api/categories/invalidate", async (IOutputCacheStore store, CancellationToken ct) =>
{
    await store.EvictByTagAsync("reference-data", ct);
    return Results.NoContent();
});
```

---

## Gotchas

- **`[ResponseCache]` alone does not cache anything on the server.** The attribute only emits `Cache-Control` headers. Whether anything is actually cached depends on what reads those headers: the client browser, a CDN, or the `ResponseCaching` middleware. A common mistake is adding `[ResponseCache(Duration = 60)]` and then wondering why the server is still hitting the database on every request — you need the middleware too, or switch to Output Caching.
- **`VaryByQueryKeys` silently does nothing without the `ResponseCaching` middleware.** It's a server-side feature. If you use it without `app.UseResponseCaching()`, no error is thrown — the `Vary` header just never appears in responses and every request goes to the controller.
- **`ResponseCaching` middleware will not cache responses with `Set-Cookie` headers or `Authorization` request headers.** Any authenticated request is excluded from the server-side cache by design. This means if your auth middleware adds a `Set-Cookie` on responses (session cookies, auth tokens), those responses won't be cached even if `[ResponseCache]` says they should be. Use Output Caching with an explicit policy that ignores auth headers if you genuinely need to cache authenticated-route responses.
- **`UseResponseCaching` must be placed before `UseRouting` in the middleware pipeline.** If it comes after, the cache middleware sees only the response on the way out but can't intercept the request on the way in — so it stores responses but never serves them from cache. This is a silent failure with no error. Output Caching doesn't have this ordering requirement.
- **Cached responses are served with stale data until the TTL expires — there is no automatic invalidation in `ResponseCaching`.** If you cache a product list for 5 minutes and someone updates a product in the admin panel, clients will see the old data until the TTL expires. Output Caching's tag-based invalidation (`EvictByTagAsync`) solves this; `ResponseCaching` does not.

---

## Interview Angle

**What they're really testing:** Whether you understand HTTP caching semantics at the protocol level, not just the ASP.NET API surface — and whether you know where in the request pipeline caching fits.

**Common question form:** "How would you cache this endpoint's response?" or "What's the difference between `Cache-Control: public` and `Cache-Control: private`?" or "How would you invalidate a cached response when the underlying data changes?"

**The depth signal:** A junior knows `[ResponseCache(Duration = 60)]` and that it "caches the response." A senior can explain the full caching chain — browser cache → CDN/reverse proxy → server-side middleware — and which layer each approach targets. They know that `Cache-Control: public` allows intermediate proxies to cache the response (dangerous for user-specific data), that `ETag` / `Last-Modified` enable conditional requests where the server returns 304 Not Modified instead of the full body, and that Output Caching's tag-based invalidation is the correct solution for cache invalidation — not setting a short TTL and hoping for the best.

---

## Related Topics

- [[dotnet/webapi-middleware-pipeline.md]] — `UseResponseCaching` and `UseOutputCache` are middleware; their position in the pipeline determines whether they intercept requests correctly
- [[dotnet/webapi-filters.md]] — result filters are an alternative place to set cache headers imperatively when `[ResponseCache]` isn't flexible enough
- [[dotnet/webapi-controllers.md]] — `[ResponseCache]` is applied as an attribute on controller actions; cache profiles are configured through `AddControllers` options
- [[databases/redis-caching.md]] — distributed caching with Redis is the complement to response caching: Redis stores deserialized objects server-side across multiple app instances; response caching stores complete serialized HTTP responses

---

## Source

[https://learn.microsoft.com/en-us/aspnet/core/performance/caching/response](https://learn.microsoft.com/en-us/aspnet/core/performance/caching/response)

---
*Last updated: 2026-03-24*