# ASP.NET Core Web API Rate Limiting

> Rate limiting caps how many requests a client can make in a given time window, protecting your API from abuse, runaway clients, and accidental self-inflicted load.

---

## When To Use It

Use it on any public-facing API, any endpoint that triggers expensive work (report generation, email sending, external API calls), and any authentication endpoint to slow down brute-force attacks. .NET 7 introduced `System.Threading.RateLimiting` with built-in middleware — prefer it over third-party packages for new projects. Don't rely on rate limiting alone as a security control; it complements authentication and authorization but doesn't replace them. Also don't apply a single global limit blindly — different endpoints have very different load profiles and the same limit will either be too loose for sensitive endpoints or too strict for high-traffic read endpoints.

---

## Core Concept

The rate limiting middleware sits in the pipeline before routing resolves to your controllers. When a request arrives, the middleware checks the client's current usage against a configured policy and either allows the request through or rejects it with a 429 Too Many Requests response — without your controller ever seeing the request. .NET 7+ has four built-in algorithms: fixed window (N requests per window, counter resets at the boundary), sliding window (smoother — the window moves with time so there's no burst at reset), token bucket (requests consume tokens that refill at a steady rate — good for allowing short bursts), and concurrency (limits simultaneous in-flight requests rather than rate over time). Policies are named, registered in DI, and applied to endpoints or globally.

---

## The Code
```csharp
// --- Setup in Program.cs: multiple named policies ---
builder.Services.AddRateLimiter(options =>
{
    // Fixed window: 100 requests per minute per IP
    options.AddFixedWindowLimiter("fixed", policy =>
    {
        policy.PermitLimit         = 100;
        policy.Window              = TimeSpan.FromMinutes(1);
        policy.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        policy.QueueLimit          = 0;          // no queuing — reject immediately when over limit
    });

    // Sliding window: 50 requests per minute, divided into 6 segments of 10s each
    options.AddSlidingWindowLimiter("sliding", policy =>
    {
        policy.PermitLimit         = 50;
        policy.Window              = TimeSpan.FromMinutes(1);
        policy.SegmentsPerWindow   = 6;
        policy.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        policy.QueueLimit          = 0;
    });

    // Token bucket: 10 tokens, refills 2 per second — allows short bursts
    options.AddTokenBucketLimiter("token-bucket", policy =>
    {
        policy.TokenLimit          = 10;
        policy.ReplenishmentPeriod = TimeSpan.FromSeconds(1);
        policy.TokensPerPeriod     = 2;
        policy.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        policy.QueueLimit          = 0;
    });

    // Concurrency: max 5 simultaneous requests (not time-based)
    options.AddConcurrencyLimiter("concurrency", policy =>
    {
        policy.PermitLimit = 5;
        policy.QueueLimit  = 0;
    });

    // Custom 429 response body
    options.OnRejected = async (context, cancellationToken) =>
    {
        context.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        context.HttpContext.Response.Headers.RetryAfter = "60";
        await context.HttpContext.Response.WriteAsJsonAsync(
            new { error = "Too many requests. Please retry after 60 seconds." },
            cancellationToken);
    };
});
```
```csharp
// --- Apply middleware and policies to endpoints ---
var app = builder.Build();

app.UseRateLimiter();               // must come before UseRouting / MapControllers

app.MapControllers();

// Apply to a specific controller:
[ApiController]
[Route("api/[controller]")]
[EnableRateLimiting("fixed")]       // applies the "fixed" policy to all actions in this controller
public class SearchController : ControllerBase
{
    [HttpGet]
    public IActionResult Search([FromQuery] string q) => Ok(q);

    [HttpGet("export")]
    [EnableRateLimiting("token-bucket")]    // override per-action
    public IActionResult Export() => Ok("export started");

    [HttpGet("health")]
    [DisableRateLimiting]                  // exempt this action entirely
    public IActionResult Health() => Ok("healthy");
}
```
```csharp
// --- Partitioned limiter: per-user or per-IP limits ---
// Different clients get independent counters — essential for fairness
builder.Services.AddRateLimiter(options =>
{
    options.AddPolicy("per-user", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            // Partition key: authenticated user ID, or fall back to IP
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

// Apply to a controller:
[EnableRateLimiting("per-user")]
[ApiController]
[Route("api/reports")]
public class ReportsController : ControllerBase
{
    [HttpPost]
    public IActionResult Generate() => Accepted();
}
```
```csharp
// --- Minimal API: apply policy inline ---
app.MapPost("/api/auth/login", (LoginRequest req) => Results.Ok())
   .RequireRateLimiting("fixed");

app.MapGet("/api/public/status", () => Results.Ok("up"))
   .DisableRateLimiting();
```
```csharp
// --- Reading rate limit headers in responses ---
// When OnRejected fires, add Retry-After so clients know when to retry:
options.OnRejected = async (context, ct) =>
{
    if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
    {
        context.HttpContext.Response.Headers.RetryAfter =
            ((int)retryAfter.TotalSeconds).ToString();
    }
    context.HttpContext.Response.StatusCode = 429;
    await context.HttpContext.Response.WriteAsync("Rate limit exceeded.", ct);
};
```

---

## Gotchas

- **A single global limiter without partitioning shares the counter across all clients.** If your global fixed window allows 1000 requests per minute and one client sends 1000 requests, every other client is locked out for the rest of the window. Always partition by user ID or IP for per-client fairness — a shared limit is only appropriate for protecting a resource from aggregate overload, not for client-level fairness.
- **`UseRateLimiter` must be placed before `UseRouting` and `MapControllers` in the pipeline, but after `UseAuthentication` if you're partitioning by user identity.** If it's placed before `UseAuthentication`, `HttpContext.User` is unauthenticated and your per-user partition key falls back to IP or anonymous for every request — silently applying the wrong limit to authenticated users.
- **`QueueLimit = 0` rejects immediately; `QueueLimit > 0` makes clients wait in a queue, which holds server threads.** Queuing sounds friendlier but under real load it ties up threads waiting for a permit slot, which can exhaust the thread pool faster than rejecting with 429. For APIs, reject immediately and let clients implement retry with backoff — don't queue on the server.
- **Rate limiting state is in-memory and per-process by default.** In a multi-instance deployment behind a load balancer, each instance has its own counter. A client sending 100 requests spread across 4 instances effectively gets a 4× limit. For accurate distributed rate limiting you need a shared store — typically Redis — with a custom `IRateLimiterPolicy` backed by a library like `RedisRateLimiting`.
- **Fixed window allows a burst of 2× the limit at window boundaries.** A 100 req/min fixed window allows 100 requests in the last second of window N and 100 more in the first second of window N+1 — 200 requests in 2 seconds with no violation. Sliding window and token bucket eliminate this burst pattern. For abuse prevention on sensitive endpoints (login, password reset), token bucket is a better choice than fixed window.

---

## Interview Angle

**What they're really testing:** Whether you understand the trade-offs between rate limiting algorithms and the operational realities of enforcing limits in a distributed system — not just "add a NuGet package."

**Common question form:** "How would you protect a login endpoint from brute force?" or "What's the difference between fixed window and sliding window rate limiting?" or "How would you rate limit per user in a load-balanced API?"

**The depth signal:** A junior knows to return 429 and has seen `[EnableRateLimiting]`. A senior can explain the fixed-window boundary burst problem and why token bucket is better for protecting sensitive endpoints, knows that in-memory limiters don't work in multi-instance deployments and can describe a Redis-backed distributed solution, understands the thread-pool implications of queuing vs rejecting, and knows to include `Retry-After` in 429 responses so clients can implement exponential backoff rather than immediately hammering again — turning a protection mechanism into a self-inflicted DDoS.

---

## Related Topics

- [[dotnet/webapi-middleware-pipeline.md]] — rate limiting is middleware; its position relative to authentication and routing determines whether per-user partitioning works correctly
- [[dotnet/webapi-filters.md]] — filters are the wrong place for rate limiting (they run after routing and model binding, too late to cheaply short-circuit); middleware is always the right layer
- [[dotnet/webapi-authentication.md]] — per-user rate limiting requires the user to be authenticated first; `UseAuthentication` must precede `UseRateLimiter` in the pipeline
- [[databases/redis-caching.md]] — distributed rate limiting across multiple API instances requires a shared counter store; Redis is the standard choice

---

## Source

[https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit](https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit)

---
*Last updated: 2026-03-24*