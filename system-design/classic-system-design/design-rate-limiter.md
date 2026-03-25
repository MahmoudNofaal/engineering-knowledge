# Rate Limiter

> A component that controls how many requests a client can make to a service within a given time window.

---

## When To Use It

Use a rate limiter to protect APIs from abuse, prevent DDoS amplification, and enforce fair usage across tenants. You do NOT need to design your own if API Gateway (AWS/Kong/Nginx) covers your needs. The interesting design challenge is at scale: when you have multiple backend nodes, a local in-memory counter per node won't work — you need centralized or distributed counting.

---

## Core Concept

You track how many requests a caller (by IP, user ID, or API key) has made in a rolling or fixed window. If they exceed the limit, you reject the request — usually with HTTP 429. The tricky part is doing this accurately across distributed servers without making every request hit a slow centralized counter. Different algorithms make different tradeoffs between accuracy, memory, and speed. The token bucket is the most common in production; the sliding window log is the most accurate but most expensive.

---

## The Code

```csharp
// Token Bucket — allows bursts, smooths average rate
using System;
using System.Threading;

public class TokenBucket
{
    private readonly int _capacity;
    private readonly double _refillRate;  // tokens per second
    private double _tokens;
    private long _lastRefill;
    private readonly object _lockObject = new();

    public TokenBucket(int capacity, double refillRate)
    {
        // capacity: max tokens (= max burst size)
        // refillRate: tokens added per second
        _capacity = capacity;
        _refillRate = refillRate;
        _tokens = capacity;
        _lastRefill = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
    }

    public bool Allow()
    {
        lock (_lockObject)
        {
            long now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            double elapsed = (now - _lastRefill) / 1000.0;  // seconds
            // Add tokens for time passed
            _tokens = Math.Min(_capacity, _tokens + elapsed * _refillRate);
            _lastRefill = now;

            if (_tokens >= 1)
            {
                _tokens -= 1;
                return true;
            }
            return false;
        }
    }
}

// Usage
var limiter = new TokenBucket(capacity: 10, refillRate: 2);  // 2 req/sec, burst up to 10
for (int i = 0; i < 15; i++)
    Console.WriteLine($"Request {i}: {(limiter.Allow() ? "allowed" : "rejected")}");
```

```csharp
// Fixed Window Counter using Redis (distributed, safe)
using StackExchange.Redis;
using System;

public class FixedWindowLimiter
{
    private readonly IDatabase _redis;

    public bool IsAllowed(string userId, int limit, int windowSeconds)
    {
        long windowIndex = DateTimeOffset.UtcNow.ToUnixTimeSeconds() / windowSeconds;
        string key = $"rate:{userId}:{windowIndex}";
        long current = _redis.StringIncrement(key);
        
        if (current == 1)
            _redis.KeyExpire(key, TimeSpan.FromSeconds(windowSeconds));  // Set TTL on first request only
        
        return current <= limit;
    }
}

// Usage
var limiter = new FixedWindowLimiter();
Console.WriteLine(limiter.IsAllowed("user_123", limit: 100, windowSeconds: 60));
```

```csharp
// Sliding Window Log (most accurate, most memory)
using StackExchange.Redis;
using System;

public class SlidingWindowLimiter
{
    private readonly IDatabase _redis;

    public bool IsAllowedSliding(string userId, int limit, int windowSeconds)
    {
        double now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
        string key = $"log:{userId}";
        double windowStart = now - windowSeconds;

        var transaction = _redis.CreateTransaction();
        transaction.SortedSetRemoveRangeByScoreAsync(key, 0, windowStart);  // Remove old entries
        transaction.SortedSetAddAsync(key, now.ToString(), now);           // Add current request
        transaction.SortedSetLengthAsync(key);                              // Count entries in window
        transaction.KeyExpireAsync(key, TimeSpan.FromSeconds(windowSeconds));
        
        var results = transaction.Execute();
        
        // results[2] is the count from SortedSetLengthAsync
        if (results.Length > 2 && results[2] is int count)
            return count <= limit;
        
        return false;
    }
}
```

---

## Gotchas

- **Fixed window boundary spike**: With a fixed window, a client can make 100 requests at 11:59:59 and 100 more at 12:00:00 — 200 requests in 2 seconds while technically staying within limits. Sliding window counters fix this but cost more memory.
- **Race condition on Redis INCR + EXPIRE**: If your process crashes between `INCR` and `EXPIRE`, the key never expires. The fix shown above (set expire only when count == 1) is safer, but use a Lua script for true atomicity in production.
- **Where to put the rate limiter**: At the API Gateway level (before your app) vs. in-app middleware are very different. Gateway-level blocks at the edge but can't distinguish business-logic limits. In-app is more flexible but adds latency to every request.
- **Headers matter**: Always return `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `Retry-After` headers. Clients that don't get these will implement bad exponential backoff or just hammer retries.
- **Distributed counter drift**: If you use local in-memory counters per node and have 10 servers, a user can make 10x the intended limit by hitting different servers. Always use a shared store (Redis) for multi-node deployments.

---

## Interview Angle

**What they're really testing:** Understanding of distributed state, clock synchronization issues, and the tradeoffs between accuracy and performance in different algorithms.

**Common question form:** "Design a rate limiter for a REST API that supports 1000 requests per minute per user."

**The depth signal:** A junior answer picks one algorithm and implements it locally. A senior answer compares token bucket vs sliding window log vs sliding window counter by memory/accuracy tradeoffs, explains the fixed-window spike problem unprompted, describes why Redis INCR alone has a race condition and how a Lua script or the `SET NX + EXPIRE` pattern fixes it, and addresses where the limiter sits in the architecture (edge vs middleware) and what that means for multi-datacenter deployments.

---

## Related Topics

- [[system-design/design-distributed-cache]] — Redis is the backbone of any distributed rate limiter
- [[system-design/design-url-shortener]] — The shorten endpoint needs rate limiting to prevent abuse
- [[system-design/design-notification-system]] — Outbound notification systems use rate limiters to throttle sends per user

---

## Source

[System Design Interview – An Insider's Guide, Chapter 4 (Alex Xu)](https://www.amazon.com/System-Design-Interview-insiders-Second/dp/B08CMF2CQF)

---

*Last updated: 2026-03-24*