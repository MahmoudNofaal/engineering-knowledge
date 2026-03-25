# Rate Limiting

> Controlling how many requests a client can make to a service within a time window — to protect the service from abuse, overload, and uneven resource consumption.

---

## When To Use It
Any public-facing API, any endpoint that does expensive work (sends emails, charges cards, runs ML inference), and any service that could be weaponized for abuse. Rate limiting is also necessary internally — a misbehaving microservice should not be able to take down its dependencies. If you have no rate limiting, one bad actor or one runaway process can take down your entire service.

---

## Core Concept
Rate limiting tracks how many requests a client has made within some time window and rejects (or delays) requests that exceed the limit. The client is usually identified by API key, user ID, or IP address. The hard part isn't the concept — it's which algorithm to use and where to enforce the limit. Different algorithms have different properties: token bucket allows short bursts, fixed window is simple but allows 2× the intended rate at window boundaries, sliding window log is accurate but expensive, sliding window counter is a practical compromise. Where you enforce matters too: at the load balancer, in a middleware layer, or in a dedicated service — each with different consistency guarantees.

---

## The Code
```csharp
// ── Token bucket — allows bursts up to bucket capacity ──────────────────────────────────────────────────────────────
// Tokens refill at a fixed rate. Each request consumes one token.
// If bucket is empty, request is rejected. Burst-friendly.

using System;
using System.Threading;

public class TokenBucket
{
    private readonly int capacity;
    private readonly double refillRate;
    private double tokens;
    private long lastRefillTicks;
    private readonly object lockObj = new object();

    public TokenBucket(int capacity, double refillRate)
    {
        this.capacity = capacity;
        this.refillRate = refillRate;
        this.tokens = capacity;
        this.lastRefillTicks = DateTime.UtcNow.Ticks;
    }

    public bool Allow()
    {
        lock (lockObj)
        {
            long now = DateTime.UtcNow.Ticks;
            double elapsed = (now - lastRefillTicks) / (double)TimeSpan.TicksPerSecond;
            // Add tokens earned since last check, up to capacity
            tokens = Math.Min(capacity, tokens + elapsed * refillRate);
            lastRefillTicks = now;

            if (tokens >= 1)
            {
                tokens -= 1;
                return true;
            }
            return false;   // bucket empty — request rejected
        }
    }
}

// 10 req/s sustained, burst up to 50
var limiter = new TokenBucket(capacity: 50, refillRate: 10);

for (int i = 0; i < 60; i++)
{
    bool allowed = limiter.Allow();
    Console.WriteLine($"Request {i + 1:D2}: {(allowed ? "✓ allowed" : "✗ rejected")}");
}
```
```csharp
// ── Sliding window counter (Redis-backed, distributed) ────────────────────
// More accurate than fixed window. Practical for distributed systems.
// Uses two fixed windows (current + previous) weighted by overlap.

using System;
using StackExchange.Redis;

public class SlidingWindowRateLimiter
{
    private readonly IDatabase db;

    public SlidingWindowRateLimiter(IConnectionMultiplexer redis)
    {
        db = redis.GetDatabase();
    }

    public bool IsAllowed(string clientId, int limit, int windowSeconds)
    {
        long now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        long windowStart = (now / windowSeconds) * windowSeconds;   // current window start
        long prevStart = windowStart - windowSeconds;                // previous window start

        string currKey = $"ratelimit:{clientId}:{windowStart}";
        string prevKey = $"ratelimit:{clientId}:{prevStart}";

        var transaction = db.CreateTransaction();
        // Increment current window and set expiry
        transaction.StringIncrementAsync(currKey);
        transaction.KeyExpireAsync(currKey, TimeSpan.FromSeconds(windowSeconds * 2));
        // Get previous window count
        transaction.StringGetAsync(prevKey);
        var results = transaction.Execute();

        long currCount = (long)results[0];
        long prevCount = 0;
        if (results[2].HasValue)
            prevCount = long.Parse(results[2].ToString());

        // Weight previous window by how much of current window has elapsed
        double elapsedFraction = (now - windowStart) / (double)windowSeconds;
        double weightedCount = prevCount * (1 - elapsedFraction) + currCount;

        return weightedCount <= limit;
    }
}

// Usage: 100 requests per 60-second window
var multiplexer = ConnectionMultiplexer.Connect("localhost:6379");
var limiter = new SlidingWindowRateLimiter(multiplexer);

for (int i = 0; i < 110; i++)
{
    bool allowed = limiter.IsAllowed("user:42", limit: 100, windowSeconds: 60);
    if (!allowed)
    {
        Console.WriteLine($"Request {i + 1}: rate limited");
        break;
    }
}
```
```csharp
// ── HTTP response headers — tell clients how to behave ────────────────────
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;

public class RateLimitMiddleware
{
    private readonly SlidingWindowRateLimiter limiter;

    public RateLimitMiddleware(SlidingWindowRateLimiter limiter)
    {
        this.limiter = limiter;
    }

    public IResult GetApiData(HttpContext context)
    {
        var clientId = context.Request.Headers.TryGetValue("X-API-Key", out var apiKey)
            ? apiKey.ToString()
            : context.Connection.RemoteIpAddress?.ToString() ?? "unknown";

        bool allowed = limiter.IsAllowed(clientId, limit: 100, windowSeconds: 60);

        long resetTime = ((DateTimeOffset.UtcNow.ToUnixTimeSeconds() / 60) + 1) * 60;

        var headers = new Dictionary<string, string>
        {
            { "X-RateLimit-Limit", "100" },
            { "X-RateLimit-Remaining", allowed ? "..." : "0" },
            { "X-RateLimit-Reset", resetTime.ToString() },
        };

        if (!allowed)
        {
            return Results.StatusCode(429)  // Too Many Requests — the correct status code
                .WithHeaders(headers)
                .WithHeaders(("Retry-After", "60"))
                .WithContentType("application/json")
                .WithJsonContent(new { error = "rate limit exceeded" });
        }

        return Results.Ok(new { data = "..." }).WithHeaders(headers);
    }
}
```

---

## Gotchas
- **Fixed window allows 2× the intended rate at window boundaries.** If your limit is 100 requests per minute, a client can make 100 requests at 11:59:59 and 100 more at 12:00:00 — 200 requests in two seconds. Sliding window algorithms prevent this; fixed window is only acceptable when boundary bursts are not a safety concern.
- **IP-based rate limiting is easy to bypass and easy to over-apply.** Shared NAT (corporate offices, university networks, mobile carriers) routes thousands of users through one IP — rate limiting by IP bans all of them for one user's behavior. Always prefer authenticated identifiers (API key, user ID) when available.
- **Distributed rate limiting requires a shared store — and that store becomes a dependency.** A Redis-backed rate limiter that goes down either stops all traffic (if you fail closed) or allows unlimited traffic (if you fail open). Decide which failure mode is acceptable before the Redis incident happens.
- **Clients must handle 429 correctly — and many don't.** A client that retries immediately on a 429 makes the problem worse. Always include `Retry-After` headers and document expected client behavior. Exponential backoff with jitter is the correct client response.
- **Rate limiting is not the same as authentication.** Rate limiting an unauthenticated endpoint by IP doesn't stop a distributed attacker with many IPs. Defense-in-depth means rate limiting + CAPTCHA + anomaly detection + blocking at the network layer for real abuse scenarios.

---

## Interview Angle
**What they're really testing:** Whether you can design a rate limiter end-to-end — algorithm choice, data store, distributed consistency, and failure behavior — not just name the concept.

**Common question form:** "Design a rate limiter" — one of the most common system design interview questions.

**The depth signal:** A junior candidate describes what a rate limiter does and maybe names the token bucket. A senior candidate walks through: algorithm selection and trade-offs (token bucket for burst-friendly, sliding window for accuracy), client identification strategy (API key > user ID > IP, and why), data store choice (Redis with atomic Lua scripts or pipeline to avoid race conditions), failure mode decision (fail open vs closed, and the business reasoning for each), HTTP response semantics (429, Retry-After, X-RateLimit-* headers), and where to enforce (load balancer for unauthenticated endpoints, application middleware for per-user limits, API gateway for multi-service enforcement). The separation is: juniors describe a rate limiter, seniors design one with all the operational considerations.

---

## Related Topics
- [[system-design/load-balancing.md]] — Rate limiting is often enforced at the load balancer or API gateway layer.
- [[system-design/caching.md]] — Rate limit counters are typically stored in an in-memory cache (Redis).
- [[system-design/consistent-hashing.md]] — Distributing rate limit counter storage across a Redis cluster uses consistent hashing.

---

## Source
https://stripe.com/blog/rate-limiters

---
*Last updated: 2026-03-24*