# URL Shortener

> A service that takes a long URL and returns a short, unique alias that redirects to the original.

---

## When To Use It

Use a URL shortener when you need shareable, compact links — for marketing campaigns, SMS messages, or analytics tracking. You should NOT design one from scratch when a SaaS solution (Bitly, TinyURL) covers your needs. This system is a classic interview topic because it forces you to reason about hashing, collisions, storage, and redirect latency at scale.

---

## Core Concept

You take a long URL, generate a short unique key (usually 6–8 alphanumeric characters), store the mapping, and serve a 301/302 redirect when someone hits the short URL. The hard parts are: how do you generate unique keys without collisions, how do you scale reads (redirects massively outnumber writes), and what happens when the same long URL is submitted twice. The key insight is that this is a read-heavy system — you optimize for fast lookups, not writes.

---

## The Code

```csharp
// Key generation: base62 encoding of an auto-increment ID
using System;
using System.Linq;

public class Base62Converter
{
    private const string BASE62 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    public string EncodeBase62(long num)
    {
        if (num == 0)
            return BASE62[0].ToString();
        
        var result = "";
        while (num > 0)
        {
            result = BASE62[(int)(num % 62)] + result;
            num /= 62;
        }
        return result;
    }

    public long DecodeBase62(string s)
    {
        long result = 0;
        foreach (var ch in s)
        {
            result = result * 62 + BASE62.IndexOf(ch);
        }
        return result;
    }
}

// Example
var converter = new Base62Converter();
Console.WriteLine(converter.EncodeBase62(1000000));   // → 4c92
Console.WriteLine(converter.DecodeBase62("4c92"));    // → 1000000
```

```csharp
// Redirect logic (ASP.NET Core pseudocode-style, real runnable)
using Microsoft.AspNetCore.Builder;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();
var cache = ConnectionMultiplexer.Connect("localhost:6379").GetDatabase();

var urlDb = new Dictionary<string, string>
{
    { "4c92", "https://example.com/very/long/url/here" }
};

app.MapGet("/{shortKey}", async (string shortKey) =>
{
    // Check cache first
    var cached = await cache.StringGetAsync(shortKey);
    if (cached.HasValue)
        return Results.Redirect(cached.ToString(), permanent: false);

    // Fall back to DB
    if (!urlDb.TryGetValue(shortKey, out var longUrl))
        return Results.NotFound();

    // Populate cache, TTL 24h
    await cache.StringSetAsync(shortKey, longUrl, TimeSpan.FromHours(24));
    return Results.Redirect(longUrl, permanent: false);
});

app.Run("http://0.0.0.0:8080");
```

```sql
-- Schema for URL mappings
CREATE TABLE url_mappings (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    short_key   VARCHAR(10) NOT NULL UNIQUE,
    long_url    TEXT NOT NULL,
    user_id     BIGINT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at  TIMESTAMP,
    click_count BIGINT DEFAULT 0,
    INDEX idx_short_key (short_key)
);
```

---

## Gotchas

- **301 vs 302**: A 301 (permanent) redirect is cached by browsers — analytics clicks won't reach your server. Use 302 (temporary) if you need click tracking.
- **Hash collision on MD5/SHA approach**: Hashing the long URL to generate the key causes collisions if two different URLs hash to the same prefix. The counter/base62 approach avoids this but requires a centralized counter or distributed ID generator (Snowflake).
- **Same URL submitted twice**: Decide upfront — do you return the same short key (requires a reverse lookup index on `long_url`) or generate a new one? Both are valid; be explicit.
- **Hot keys in cache**: Viral links create massive read spikes on a single cache key. Use local in-process caching (LRU) in front of Redis for the top N most-fetched keys.
- **Expiration + cleanup**: Expired URLs still occupy DB rows. Run a background job to purge them, or use TTL columns with a scheduled scan — don't let the table grow unbounded.

---

## Interview Angle

**What they're really testing:** Capacity estimation, read/write path design, and tradeoffs between hashing vs. counter-based key generation.

**Common question form:** "Design a URL shortening service like bit.ly. It should handle 100M URLs and 10B redirects/month."

**The depth signal:** A junior answer generates keys with `random.randint` and stores everything in one DB table. A senior answer distinguishes 301 vs 302 semantics and explains why, proposes a distributed ID generator (Snowflake) to avoid coordination overhead on the counter, adds a cache layer with LRU eviction for hot keys, and discusses partitioning the DB by short_key hash range — not by user_id — because reads are always by short_key.

---

## Related Topics

- [[system-design/design-distributed-cache]] — The read path for redirects depends entirely on cache design
- [[system-design/design-rate-limiter]] — Needed to prevent abuse of the shorten endpoint
- [[databases/partitioning]] — Sharding the URL table by key range vs hash

---

## Source

[System Design Interview – An Insider's Guide, Chapter 8 (Alex Xu)](https://www.amazon.com/System-Design-Interview-insiders-Second/dp/B08CMF2CQF)

---

*Last updated: 2026-03-24*