# Redis Patterns

> The six production patterns that Redis is actually used for — caching, rate limiting, distributed locks, leaderboards, queues, and sessions — with the exact implementation for each.

---

## When To Use It

Use this as a reference when you know Redis is the right tool and need the correct implementation pattern. Each pattern here has a wrong way that looks right and a right way that's non-obvious. The wrong implementations work in development and fail in production under concurrency or network partition. These are the production-correct versions.

---

## Core Concept

Redis patterns are compositions of its atomic primitives. The key insight is that Redis's single-threaded command execution makes individual commands atomic — but multi-step operations are not atomic unless you use Lua scripts or transactions. Every pattern below that involves a read-then-write uses either a single command, a Lua script, or a pipeline to close the race window. That's the thread that connects all of them.

---

## The Code

**Pattern 1 — Cache-Aside (Lazy Loading)**
```csharp
using StackExchange.Redis;
using System.Text.Json;

var redis = ConnectionMultiplexer.Connect("localhost:6379");
var db = redis.GetDatabase();

public Dictionary<string, object>? GetUser(int userId)
{
    string cacheKey = $"user:{userId}";
    
    var cached = db.StringGet(cacheKey);
    if (cached.HasValue)
        return JsonSerializer.Deserialize<Dictionary<string, object>>(cached.ToString());  // cache hit
    
    var user = db.ExecuteRead("SELECT * FROM users WHERE id = @id", userId);  // pseudo-code
    db.StringSet(cacheKey, JsonSerializer.Serialize(user), TimeSpan.FromSeconds(300));  // cache for 5 min
    return user;
}

public void UpdateUser(int userId, Dictionary<string, object> data)
{
    db.ExecuteWrite("UPDATE users SET ... WHERE id = @id", userId);  // pseudo-code
    db.KeyDelete($"user:{userId}");  // invalidate, don't update
    // Delete > update: avoids stale writes racing with reads
}
```

**Pattern 2 — Rate Limiter (Fixed Window)**
```csharp
public bool IsRateLimited(string userId, int limit = 100, int window = 60)
{
    string key = $"rate:{userId}:{(int)(DateTimeOffset.UtcNow.ToUnixTimeSeconds() / window)}";
    
    // INCR is atomic — no race between read and increment
    long count = db.StringIncrement(key);
    
    if (count == 1)
        db.KeyExpire(key, TimeSpan.FromSeconds(window));  // set TTL only on first increment
                                                           // avoids overwriting TTL on subsequent hits
    return count > limit;
}
```

**Pattern 2b — Rate Limiter (Sliding Window with Sorted Set)**
```csharp
public bool IsRateLimitedSliding(string userId, int limit = 100, int window = 60)
{
    double now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
    string key = $"rate:sliding:{userId}";
    
    var trans = db.CreateTransaction();
    trans.AddCondition(Condition.StringEqual("__unused__", "__unused__"));  // dummy condition
    
    // Remove expired entries
    trans.SortedSetRemoveByScoreAsync(key, double.NegativeInfinity, now - (window * 1000));
    // Add current request
    trans.SortedSetAddAsync(key, now.ToString(), now);
    // Count requests in window
    trans.SortedSetLengthAsync(key);
    // Set expiry
    trans.KeyExpireAsync(key, TimeSpan.FromSeconds(window));
    
    var results = trans.Execute();
    long count = (long)results[2];  // results[2] = ZCARD result
    
    return count > limit;
}
```

**Pattern 3 — Distributed Lock**
```csharp
using System;
using StackExchange.Redis;

public class RedisLock : IDisposable
{
    private readonly IDatabase _db;
    private readonly string _key;
    private readonly int _ttl;
    private readonly string _val;

    public RedisLock(IDatabase db, string key, int ttl = 10)
    {
        _db = db;
        _key = $"lock:{key}";
        _ttl = ttl;
        _val = Guid.NewGuid().ToString();  // unique owner token
    }

    public bool Acquire(int timeout = 5)
    {
        var deadline = DateTimeOffset.UtcNow.AddSeconds(timeout);
        while (DateTimeOffset.UtcNow < deadline)
        {
            if (_db.StringSet(_key, _val, TimeSpan.FromSeconds(_ttl), When.NotExists))
                return true;
            System.Threading.Thread.Sleep(50);
        }
        return false;
    }

    public void Release()
    {
        // Lua script: check owner AND delete in one atomic operation
        // Without this, we might delete another owner's lock
        var script = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end";
        _db.ScriptEvaluate(script, new RedisKey[] { _key }, new RedisValue[] { _val });
    }

    public void Dispose()
    {
        Release();
    }
}

// Usage
var db = ConnectionMultiplexer.Connect("localhost:6379").GetDatabase();
using (var @lock = new RedisLock(db, "payment:user:42"))
{
    if (@lock.Acquire())
    {
        // ProcessPayment();
    }
}
```

**Pattern 4 — Leaderboard**
```csharp
public void SubmitScore(string userId, double score)
{
    // ZADD with GT: only updates if new score is greater than existing
    db.SortedSetAdd("leaderboard:global", userId, score, flags: CommandFlags.FireAndForget);
}

public List<(string userId, double score)> GetTop(int n = 10)
{
    // ZREVRANGE: highest score first
    var results = db.SortedSetRangeByRankWithScores("leaderboard:global", 0, n - 1, Order.Descending);
    var list = new List<(string, double)>();
    foreach (var item in results)
        list.Add((item.Element.ToString()!, item.Score));
    return list;
}

public int? GetRank(string userId)
{
    long? rank = db.SortedSetRank("leaderboard:global", userId, Order.Descending);
    return rank.HasValue ? (int)(rank + 1) : null;  // 1-indexed
}

public List<(string userId, double score)> GetAround(string userId, int radius = 2)
{
    long? rank = db.SortedSetRank("leaderboard:global", userId, Order.Descending);
    if (!rank.HasValue)
        return new List<(string, double)>();
    int start = Math.Max(0, (int)(rank - radius));
    int end = (int)(rank + radius);
    var results = db.SortedSetRangeByRankWithScores("leaderboard:global", start, end, Order.Descending);
    var list = new List<(string, double)>();
    foreach (var item in results)
        list.Add((item.Element.ToString()!, item.Score));
    return list;
}
```

**Pattern 5 — Reliable Queue with Streams**
```csharp
// Streams > Pub/Sub for reliable messaging — messages persist and can be replayed

// Producer
public void Enqueue(string stream, string payload)
{
    db.StreamAdd(stream, "payload", payload, maxLength: 10_000);  // cap stream length
}

// Consumer setup
var streamKey = "jobs";
var groupName = "workers";
db.StreamCreateConsumerGroup(streamKey, groupName, StreamPosition.NewMessages, createStream: true);

public void Consume(string stream, string group, string consumer)
{
    while (true)
    {
        var messages = db.StreamReadGroup(stream, group, consumer, count: 10, noAck: false);
        foreach (var msg in messages)
        {
            try
            {
                // Process(msg.Values);
                db.StreamAcknowledge(stream, group, msg.Id);  // ack only after success
            }
            catch (Exception)
            {
                // message stays pending — redelivered on timeout
            }
        }
    }
}
```

**Pattern 6 — Session Storage**
```csharp
using System;
using StackExchange.Redis;

public string CreateSession(int userId, int ttl = 86400)
{
    string sessionId = Guid.NewGuid().ToString();
    var hashKey = $"session:{sessionId}";
    var hashEntry = new HashEntry[] 
    {
        new HashEntry("user_id", userId),
        new HashEntry("created", DateTimeOffset.UtcNow.ToUnixTimeSeconds())
    };
    db.HashSet(hashKey, hashEntry);
    db.KeyExpire(hashKey, TimeSpan.FromSeconds(ttl));
    return sessionId;
}

public Dictionary<string, string>? GetSession(string sessionId)
{
    string hashKey = $"session:{sessionId}";
    var data = db.HashGetAll(hashKey);
    if (data.Length == 0)
        return null;
    var dict = new Dictionary<string, string>();
    foreach (var entry in data)
        dict[entry.Name.ToString()] = entry.Value.ToString();
    db.KeyExpire(hashKey, TimeSpan.FromSeconds(86400));  // sliding expiry on access
    return dict;
}

public void DeleteSession(string sessionId)
{
    db.KeyDelete($"session:{sessionId}");
}
```

---

## Gotchas

- **Cache-aside: delete on write, never update.** If you write the new value to cache on update, a concurrent read that started before the DB write can overwrite the cache with stale data. Delete instead — the next read repopulates from the source of truth.
- **Fixed window rate limiter has a boundary burst problem.** A user can make `limit` requests at 11:59:59 and another `limit` at 12:00:00 — double the rate in two seconds. Use the sliding window pattern when burst prevention matters.
- **Distributed lock: the TTL must exceed your critical section.** If your payment processing takes 15 seconds and the lock TTL is 10, the lock expires while you're still holding it and another process enters. Add a watchdog thread that extends the TTL if the work is still running, or just set TTL conservatively high.
- **Streams: always XACK after processing, not before.** If you ack before processing and then crash, the message is gone. If you don't ack at all, messages pile up in the Pending Entries List (PEL) — use `XAUTOCLAIM` to reclaim them after a timeout.
- **Pipeline is not a transaction.** `r.pipeline()` batches commands for network efficiency but doesn't guarantee atomicity — other clients can interleave between commands. Use `pipe.watch()` + `MULTI/EXEC` for optimistic locking, or Lua for true atomicity.

---

## Interview Angle

**What they're really testing:** Whether you can implement concurrent-safe patterns — not just describe them at a high level.

**Common question form:** *"Implement a rate limiter"*, *"How do you prevent cache stampede?"*, *"Design a distributed lock."*

**The depth signal:** A junior describes the pattern in prose. A senior writes the code and explains the race conditions: why `INCR` is safe but `GET` + `SET` isn't; why the lock release needs a Lua script (check-and-delete must be atomic or another owner's lock gets deleted); why Pub/Sub loses messages on subscriber disconnect but Streams don't; why cache-aside deletes on write instead of updating. The depth signal is knowing which step in each pattern is the dangerous one and why.

---

## Related Topics

- [[databases/redis-fundamentals.md]] — The data type primitives (sorted sets, streams, hashes) that these patterns are built on.
- [[system-design/caching-strategies.md]] — Cache-aside is one of three caching topologies; write-through and write-behind are the others.
- [[system-design/rate-limiting.md]] — Token bucket and sliding window algorithms and how they map to Redis primitives.
- [[system-design/distributed-locks.md]] — Redlock algorithm, clock skew failure modes, and when a single-node lock is good enough.

---

## Source

[Redis documentation — patterns](https://redis.io/docs/manual/patterns/)

---
*Last updated: 2026-03-24*