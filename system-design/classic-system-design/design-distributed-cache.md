# Distributed Cache

> A shared, in-memory key-value store that multiple application nodes read from and write to, reducing load on the primary database.

---

## When To Use It

Add a distributed cache when your DB is a read bottleneck — typically when the same data is fetched repeatedly and doesn't change every request. Don't use it for data that changes on every request (no benefit) or data where stale reads are unacceptable (financial balances, inventory counts). The design challenge is cache consistency: keeping the cache and DB in sync without introducing subtle bugs that silently serve wrong data.

---

## Core Concept

The cache sits between your app and your DB. On a read, check cache first — if the data is there (cache hit), return it without touching the DB. If not (cache miss), fetch from DB, store in cache with a TTL, then return. On a write, you have a choice: update the DB and invalidate the cache (cache-aside / lazy loading), or update both synchronously (write-through). Cache-aside is simpler and more common. The hard parts are choosing the right eviction policy (LRU is most common), handling cache stampedes (thundering herd when a popular key expires), and deciding what TTL makes stale data acceptable for your use case.

---

## The Code

```csharp
// Cache-aside pattern (most common in production)
using StackExchange.Redis;
using System.Text.Json;

public class CacheAsidePattern
{
    private readonly IDatabase _redis;
    private readonly IUserRepository _db;

    public async Task<User> GetUserAsync(int userId)
    {
        string cacheKey = $"user:{userId}";

        // 1. Try cache first
        var cached = _redis.StringGet(cacheKey);
        if (cached.HasValue)
            return JsonSerializer.Deserialize<User>(cached.ToString())!;

        // 2. Cache miss — fetch from DB
        var user = await _db.GetUserAsync(userId);
        if (user == null)
            return null!;

        // 3. Populate cache with TTL (1 hour)
        _redis.StringSet(cacheKey, JsonSerializer.Serialize(user), TimeSpan.FromHours(1));
        return user;
    }

    public async Task UpdateUserAsync(int userId, User data)
    {
        // 1. Write to DB first
        await _db.UpdateUserAsync(userId, data);

        // 2. Invalidate cache — don't update it, just delete
        _redis.StringDelete($"user:{userId}");
        // Next read will repopulate from DB (lazy re-population)
    }
}
```

```csharp
// Cache stampede prevention with probabilistic early expiration (XFetch)
using StackExchange.Redis;
using System.Text.Json;

public class CacheStampedeProtection
{
    private readonly IDatabase _redis;
    private readonly Random _random = new();

    public T GetWithStampedeProtection<T>(
        string key,
        int ttl,
        Func<T> fetchFn,
        double beta = 1.0)
    {
        // XFetch algorithm: recompute slightly before expiry with probability
        // proportional to how close we are to expiration.
        // beta > 1 = more aggressive early recomputation (less stampede risk)
        
        var cached = _redis.StringGet(key);
        if (cached.HasValue)
        {
            var data = JsonSerializer.Deserialize<T>(cached.ToString())!;
            long expiry = _redis.KeyTimeToLive(key)?.TotalSeconds ?? 0;
            double remaining = expiry > 0 ? (double)expiry / ttl : 0;

            // Probabilistically decide to recompute early
            double randomValue = _random.NextDouble();
            if (remaining > Math.Pow(randomValue, 1.0 / beta))
                return data;  // Still fresh enough
        }

        // Recompute (either expired or early recompute triggered)
        T value = fetchFn();
        _redis.StringSet(key, JsonSerializer.Serialize(value), TimeSpan.FromSeconds(ttl));
        return value;
    }
}
```

```csharp
// Consistent hashing for distributing keys across cache nodes
using System.Security.Cryptography;
using System.Collections.Generic;
using System.Linq;

public class ConsistentHashRing
{
    private readonly SortedDictionary<ulong, string> _ring = new();
    private const int VirtualNodes = 150;

    public ConsistentHashRing(List<string> nodes)
    {
        foreach (var node in nodes)
        {
            // Virtual nodes reduce hotspot risk
            for (int i = 0; i < VirtualNodes; i++)
            {
                ulong key = Hash($"{node}:{i}");
                _ring[key] = node;
            }
        }
    }

    private ulong Hash(string value)
    {
        using (var md5 = MD5.Create())
        {
            byte[] hash = md5.ComputeHash(System.Text.Encoding.UTF8.GetBytes(value));
            return System.BitConverter.ToUInt64(hash, 0);
        }
    }

    public string GetNode(string cacheKey)
    {
        // Find which node should hold this cache key
        if (_ring.Count == 0)
            return null!;

        ulong hash = Hash(cacheKey);
        var keys = _ring.Keys.Where(k => k >= hash).ToList();
        ulong nodeKey = keys.Count > 0 ? keys.First() : _ring.Keys.First();
        return _ring[nodeKey];
    }
}

// Usage
var ring = new ConsistentHashRing(new List<string> { "cache-1", "cache-2", "cache-3" });
string node1 = ring.GetNode("user:42");   // Deterministic
string node2 = ring.GetNode("user:43");
```

---

## Gotchas

- **Cache invalidation is the hard part**: "There are only two hard things in CS: cache invalidation and naming things." If you update the DB and then fail before invalidating the cache, you'll serve stale data indefinitely until TTL expires. Write DB first, then delete cache key — not update it. Deletion is safe; an incorrect update is not.
- **Cache stampede (thundering herd)**: When a popular key expires, hundreds of concurrent requests all miss cache simultaneously and hammer the DB. Solutions: mutex lock on the first miss (others wait), background refresh before expiry, or probabilistic early expiration (XFetch).
- **LRU vs LFU eviction**: LRU (Least Recently Used) evicts the key not accessed for the longest time. LFU (Least Frequently Used) evicts the key accessed fewest times. LRU is the default and usually correct. LFU is better for workloads where some keys are always popular (scan resistance).
- **Consistent hashing for sharding**: Simple modulo hashing (`key % N`) means when you add or remove a cache node, almost every key maps to a different node — massive cache invalidation. Consistent hashing limits the remapping to `keys/N` on average.
- **Cache is not a source of truth**: If your cache layer fails, your app should still work (degraded performance, not an outage). Design for graceful cache bypass — if Redis is down, fall through to DB, don't throw 500s.

---

## Interview Angle

**What they're really testing:** Cache patterns (aside vs write-through vs write-behind), eviction policies, sharding strategy, and consistency tradeoffs.

**Common question form:** "Design a distributed caching system. How would you handle cache eviction, sharding, and consistency?"

**The depth signal:** A junior answer describes "add Redis in front of the DB." A senior answer names the specific cache-aside vs write-through tradeoff and explains which to choose for read-heavy vs write-heavy workloads, explains the thundering herd problem and names at least one mitigation strategy, distinguishes LRU from LFU with a use case for each, explains *why* consistent hashing matters when scaling cache nodes (and specifically what breaks with naive modulo sharding), and discusses the failure mode where cache goes down — the app should degrade gracefully, not crash.

---

## Related Topics

- [[system-design/design-url-shortener]] — URL redirect lookup is a textbook cache-aside read pattern
- [[system-design/design-rate-limiter]] — Rate limiter uses Redis as an atomic counter store, not a cache
- [[system-design/design-news-feed]] — Feed pre-computation is stored entirely in Redis cache

---

## Source

[Redis Official Documentation — Caching Patterns](https://redis.io/docs/manual/patterns/)

---

*Last updated: 2026-03-24*