# ASP.NET Core Web API Rate Limiting

> Rate limiting caps how many requests a client can make in a given time window, protecting your API from abuse, runaway clients, and accidental self-inflicted load.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Middleware that enforces per-client or global request caps, returning 429 when exceeded |
| **Use when** | Public-facing APIs, auth endpoints, expensive operations (reports, emails, external calls) |
| **Avoid when** | Internal service-to-service traffic on a trusted private network |
| **Introduced** | `System.Threading.RateLimiting` and ASP.NET Core middleware in .NET 7 |
| **Namespace** | `System.Threading.RateLimiting`, `Microsoft.AspNetCore.RateLimiting` |
| **Key types** | `RateLimiterOptions`, `FixedWindowRateLimiter`, `SlidingWindowRateLimiter`, `TokenBucketRateLimiter`, `ConcurrencyLimiter` |

---

## When To Use It

Use it on any public-facing API, any endpoint that triggers expensive work (report generation, email sending, external API calls), and any authentication endpoint to slow down brute-force attacks. .NET 7 introduced `System.Threading.RateLimiting` with built-in middleware — prefer it over third-party packages for new projects. Don't rely on rate limiting alone as a security control; it complements authentication and authorization but doesn't replace them. Also don't apply a single global limit blindly — different endpoints have very different load profiles and the same limit will either be too loose for sensitive endpoints or too strict for high-traffic read endpoints.

---

## Core Concept

The rate limiting middleware sits in the pipeline before routing resolves to your controllers. When a request arrives, the middleware checks the client's current usage against a configured policy and either allows the request through or rejects it with a 429 Too Many Requests response — without your controller ever seeing the request. .NET 7+ has four built-in algorithms: fixed window (N requests per window, counter resets at the boundary), sliding window (smoother — the window moves with time so there's no burst at reset), token bucket (requests consume tokens that refill at a steady rate — good for allowing short bursts), and concurrency (limits simultaneous in-flight requests rather than rate over time). Policies are named, registered in DI, and applied to endpoints or globally.

---

## Version History

| .NET Version | What changed |
|---|---|
| .NET 7 | `System.Threading.RateLimiting` namespace; `AddRateLimiter` middleware; all four built-in algorithms |
| .NET 7 | `[EnableRateLimiting]`, `[DisableRateLimiting]`, `.RequireRateLimiting()`, `.DisableRateLimiting()` |
| .NET 8 | `RateLimitPartition.GetConcurrencyLimiter` improved; keyed services integration |

*Before .NET 7, rate limiting required third-party packages (`AspNetCoreRateLimit`) or custom middleware. The built-in implementation in .NET 7 is deeply integrated with the endpoint routing system and supports per-endpoint policies natively.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Fixed/Sliding window check | O(1) | Atomic counter read/increment |
| Token bucket check | O(1) | Token count check + optional replenishment |
| Partitioned limiter lookup | O(1) average | Hash map by partition key |
| 429 response write | ~5 µs | Header write + optional body |

**Allocation behaviour:** Limiters allocate internal state on first use per partition key. For per-user partitioning, each unique user gets one limiter instance allocated. With large user counts this can be significant — configure `QueueLimit = 0` (reject immediately) to avoid queuing allocations. Use `RateLimitPartition.GetNoLimiter()` for trusted clients to skip allocation entirely.

**Benchmark notes:** Rate limiter check overhead is nanoseconds — negligible. The real performance consideration is the partition map growing unboundedly for APIs with many unique clients. Use `MemoryCache` with expiry or a Redis-backed limiter for distributed deployments to bound memory usage.

---

## The Code

**Setup in Program.cs — multiple named policies**
```csharp
builder.Services.AddRateLimiter(options =>
{
    // Fixed window: 100 requests per minute per IP
    options.AddFixedWindowLimiter("fixed", policy =>
    {
        policy.PermitLimit          = 100;
        policy.Window               = TimeSpan.FromMinutes(1);
        policy.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        policy.QueueLimit           = 0;  // reject immediately
    });

    // Sliding window: no burst at boundary — smoother than fixed
    options.AddSlidingWindowLimiter("sliding", policy =>
    {
        policy.PermitLimit          = 50;
        policy.Window               = TimeSpan.FromMinutes(1);
        policy.SegmentsPerWindow    = 6;
        policy.QueueLimit           = 0;
    });

    // Token bucket: allows short bursts then throttles
    options.AddTokenBucketLimiter("token-bucket", policy =>
    {
        policy.TokenLimit           = 10;
        policy.ReplenishmentPeriod  = TimeSpan.FromSeconds(1);
        policy.TokensPerPeriod      = 2;
        policy.QueueLimit           = 0;
    });

    // Concurrency: max 5 simultaneous in-flight requests
    options.AddConcurrencyLimiter("concurrency", policy =>
    {
        policy.PermitLimit = 5;
        policy.QueueLimit  = 0;
    });

    // Custom 429 response
    options.OnRejected = async (context, ct) =>
    {
        if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
            context.HttpContext.Response.Headers.RetryAfter =
                ((int)retryAfter.TotalSeconds).ToString();

        context.HttpContext.Response.StatusCode = 429;
        await context.HttpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = 429,
            Title  = "Too many requests.",
            Detail = "Please slow down and retry after the specified delay."
        }, ct);
    };
});
```

**Apply middleware and policies to endpoints**
```csharp
app.UseRateLimiter();   // before UseRouting / MapControllers

[ApiController]
[Route("api/[controller]")]
[EnableRateLimiting("fixed")]                   // applies to all actions
public class SearchController : ControllerBase
{
    [HttpGet]
    public IActionResult Search([FromQuery] string q) => Ok(q);

    [HttpGet("export")]
    [EnableRateLimiting("token-bucket")]         // override per-action
    public IActionResult Export() => Ok();

    [HttpGet("health")]
    [DisableRateLimiting]                        // exempt
    public IActionResult Health() => Ok("healthy");
}
```

**Partitioned limiter — per-user or per-IP**
```csharp
builder.Services.AddRateLimiter(options =>
{
    options.AddPolicy("per-user", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.User.Identity?.Name
                          ?? httpContext.Connection.RemoteIpAddress?.ToString()
                          ?? "anonymous",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 60,
                Window      = TimeSpan.FromMinutes(1),
                QueueLimit  = 0
            }));
});
```

**Minimal API rate limiting**
```csharp
app.MapPost("/api/auth/login", (LoginRequest req) => Results.Ok())
   .RequireRateLimiting("token-bucket");  // strict for auth endpoint

app.MapGet("/api/status", () => Results.Ok("up"))
   .DisableRateLimiting();
```

**Trusted client bypass**
```csharp
options.AddPolicy("adaptive", httpContext =>
{
    // Internal service accounts bypass rate limiting entirely
    if (httpContext.User.HasClaim("client_type", "internal-service"))
        return RateLimitPartition.GetNoLimiter("internal");

    return RateLimitPartition.GetSlidingWindowLimiter(
        partitionKey: httpContext.User.Identity?.Name ?? "anonymous",
        factory: _ => new SlidingWindowRateLimiterOptions
        {
            PermitLimit      = 100,
            Window           = TimeSpan.FromMinutes(1),
            SegmentsPerWindow = 6,
            QueueLimit       = 0
        });
});
```

---

## Real World Example

A public API has different rate limit requirements per endpoint tier: anonymous users get a strict global limit, authenticated users get a per-user limit, and a specific "generate report" endpoint has a token bucket to prevent abuse of the expensive operation.

```csharp
builder.Services.AddRateLimiter(options =>
{
    // Anonymous: 20 requests/minute globally — stops scraping
    options.AddPolicy("anonymous", httpContext =>
    {
        if (httpContext.User.Identity?.IsAuthenticated == true)
            return RateLimitPartition.GetNoLimiter("authenticated-skip");

        var ip = httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        return RateLimitPartition.GetFixedWindowLimiter(ip,
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window      = TimeSpan.FromMinutes(1),
                QueueLimit  = 0
            });
    });

    // Authenticated: 300 requests/minute per user
    options.AddPolicy("authenticated", httpContext =>
    {
        var userId = httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? "unknown";
        return RateLimitPartition.GetSlidingWindowLimiter(userId,
            _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit       = 300,
                Window            = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 6,
                QueueLimit        = 0
            });
    });

    // Report generation: 5 tokens, 1 token refills every 10 seconds
    options.AddPolicy("report-generation", httpContext =>
    {
        var userId = httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "unknown";
        return RateLimitPartition.GetTokenBucketLimiter($"report:{userId}",
            _ => new TokenBucketRateLimiterOptions
            {
                TokenLimit          = 5,
                ReplenishmentPeriod = TimeSpan.FromSeconds(10),
                TokensPerPeriod     = 1,
                QueueLimit          = 0
            });
    });

    options.OnRejected = async (ctx, ct) =>
    {
        ctx.HttpContext.Response.StatusCode = 429;
        if (ctx.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
            ctx.HttpContext.Response.Headers.RetryAfter = retryAfter.TotalSeconds.ToString("F0");

        await ctx.HttpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = 429,
            Title  = "Rate limit exceeded.",
            Extensions = { ["retryAfterSeconds"] = retryAfter.TotalSeconds }
        }, ct);
    };
});

// Apply per endpoint
app.MapGet("/api/products", ...).RequireRateLimiting("anonymous");
app.MapGet("/api/account",  ...).RequireRateLimiting("authenticated");
app.MapPost("/api/reports", ...).RequireRateLimiting("report-generation");
```

*The key insight: the partition key strategy determines fairness. Anonymous users are partitioned by IP — one abusive IP can't block others. Authenticated users are partitioned by user ID — one heavy user can't affect others. The report endpoint uses a token bucket per user to allow short bursts (5 queued reports) with controlled refill, rather than a hard per-minute wall.*

---

## Common Misconceptions

**"A single global limiter without partitioning is fair to all clients."**
A shared counter means one abusive client exhausts the budget for all others. If your global fixed window allows 1000 req/min and one client sends 1000 requests, every other client is locked out. Always partition by user ID or IP for client-level fairness.

**"Rate limiting works the same across multiple API instances."**
In-memory limiters maintain state per-process. In a multi-instance deployment, a client can send requests to four instances and effectively get 4× the limit. For accurate distributed rate limiting you need a shared store — Redis — with a custom `IRateLimiterPolicy` backed by a library like `RedisRateLimiting`.

**"Queuing requests is friendlier than rejecting them."**
`QueueLimit > 0` makes clients wait in a queue instead of getting an immediate 429. Under real load this ties up server threads waiting for permit slots, which can exhaust the thread pool faster than rejecting. For APIs, reject immediately and let clients implement exponential backoff — don't queue on the server side.

---

## Gotchas

- **`UseRateLimiter` must be placed before `UseRouting` and `MapControllers`, but after `UseAuthentication` if partitioning by user identity.** If before `UseAuthentication`, `HttpContext.User` is unauthenticated and per-user partition keys fall back to anonymous for every request.

- **Fixed window allows a burst of 2× the limit at window boundaries.** 100 req/min fixed window allows 100 requests in the last second of window N and 100 more in the first second of window N+1 — 200 requests in 2 seconds. Use sliding window or token bucket for sensitive endpoints (login, password reset).

- **`QueueLimit = 0` rejects immediately; `QueueLimit > 0` holds threads.** Under real load, queuing exhausts the thread pool. Reject immediately and return a `Retry-After` header so clients can implement backoff.

- **Rate limiting state is in-memory and per-process.** Multi-instance deployments need Redis-backed distributed limiting. Without it, each instance has its own counter and clients effectively get n× the limit across n instances.

- **The `OnRejected` callback is the only place to add `Retry-After` response headers.** The middleware does not add this header automatically. Without it, clients that hit the limit have no information about when to retry and often immediately retry — turning a protection mechanism into a DDoS amplifier.

---

## Interview Angle

**What they're really testing:** Whether you understand the trade-offs between rate limiting algorithms and the operational realities of enforcing limits in a distributed system — not just "add the middleware."

**Common question forms:**
- "How would you protect a login endpoint from brute force?"
- "What's the difference between fixed window and sliding window rate limiting?"
- "How would you rate limit per user in a load-balanced API?"
- "Why is a global in-memory limiter insufficient in production?"

**The depth signal:** A junior knows to return 429 and has seen `[EnableRateLimiting]`. A senior explains the fixed-window boundary burst problem and why token bucket is better for sensitive endpoints, knows in-memory limiters don't work in multi-instance deployments and describes a Redis-backed distributed solution, understands the thread-pool implications of queuing vs rejecting, and knows to include `Retry-After` in 429 responses so clients can implement exponential backoff.

**Follow-up questions to expect:**
- "How would you implement distributed rate limiting across multiple API instances?"
- "What's the difference between token bucket and sliding window algorithms?"
- "How do you exempt health check endpoints from rate limiting?"

---

## Related Topics

- [[dotnet/webapi/middleware-pipeline.md]] — rate limiting is middleware; its position relative to authentication and routing determines whether per-user partitioning works correctly
- [[dotnet/webapi/webapi-authentication.md]] — per-user rate limiting requires the user to be authenticated first; `UseAuthentication` must precede `UseRateLimiter`
- [[dotnet/webapi/webapi-problem-details.md]] — 429 responses should return `ProblemDetails`; the `OnRejected` callback is where you produce the consistent error body
- [[databases/nosql/redis-fundamentals.md]] — distributed rate limiting across multiple API instances requires Redis as a shared counter store

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit

---
*Last updated: 2026-04-10*