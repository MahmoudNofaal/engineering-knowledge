# Redis Fundamentals

> An in-memory data structure store that operates as a cache, message broker, and primary database — built around the idea that your data structures live in RAM and every operation is O(1) or close to it.

---

## When To Use It

Use Redis for session storage, caching expensive queries, rate limiting, leaderboards, pub/sub messaging, and distributed locks. Don't use it as your primary database for data you can't afford to lose without careful persistence configuration — it's memory-bound and persistence is a tradeoff, not a guarantee. The sweet spot is data that's expensive to compute, accessed frequently, and tolerable to lose or rebuild.

---

## Core Concept

Redis keeps everything in RAM. That's the whole model — not a cache layer on top of disk, not a write-through buffer. RAM. Every data type is a named key pointing to a value that has structure: strings, lists, sets, sorted sets, hashes, streams. Commands on these types are atomic. Redis is single-threaded for command execution, which means no race conditions on individual commands but also means one slow command blocks everything. Expiry is built in at the key level — you don't need a cleanup job, you just set a TTL.

---

## The Code

**Strings — the foundation**
```csharp
using StackExchange.Redis;

IConnectionMultiplexer redis = ConnectionMultiplexer.Connect("localhost:6379");
IDatabase db = redis.GetDatabase();

// Basic get/set with TTL (seconds)
db.StringSet("user:42:name", "Ali", TimeSpan.FromSeconds(3600));
string value = db.StringGet("user:42:name");  // "Ali"

// Atomic increment — no read-modify-write race condition
db.StringSet("api:hits", "0");
db.StringIncrement("api:hits");       // 1
db.StringIncrement("api:hits", 5);    // 6
```

**Hashes — structured objects**
```csharp
// Store a user object — one key, multiple fields
db.HashSet("user:42", new[]
{
    new HashEntry("name", "Ali"),
    new HashEntry("email", "ali@example.com"),
    new HashEntry("plan", "pro")
});

RedisValue plan = db.HashGet("user:42", "plan");      // "pro"
HashEntry[] allFields = db.HashGetAll("user:42");     // full dict
db.HashIncrement("user:42", "logins", 1);  // atomic field increment
```

**Lists — queues and stacks**
```csharp
// LPUSH + RPOP = queue (FIFO)
db.ListLeftPush("jobs", new RedisValue[] { "job:1", "job:2", "job:3" });
RedisValue job = db.ListRightPop("jobs");   // "job:1"

// BLPOP = blocking pop — waits until an item appears (timeout in seconds)
RedisValue blockedJob = db.ListLeftPop("jobs", TimeSpan.FromSeconds(5));

// LPUSH + LPOP = stack (LIFO)
db.ListLeftPush("history", "page:home");
RedisValue historyItem = db.ListLeftPop("history");
```

**Sets — unique membership**
```csharp
db.SetAdd("online_users", new RedisValue[] { "u1", "u2", "u3" });
bool isMember = db.SetContains("online_users", "u2");   // true
RedisValue[] members = db.SetMembers("online_users");   // {"u1", "u2", "u3"}

// Set operations — who's online in both groups?
db.SetAdd("group:a", new RedisValue[] { "u1", "u2" });
db.SetAdd("group:b", new RedisValue[] { "u2", "u3" });
RedisValue[] intersection = db.SetCombine(SetOperation.Intersect, "group:a", "group:b");  // {"u2"}
```

**Sorted Sets — leaderboards and ranked data**
```csharp
// zadd: key → {member: score}
db.SortedSetAdd("leaderboard", new[]
{
    new SortedSetEntry("alice", 1500),
    new SortedSetEntry("bob", 1200),
    new SortedSetEntry("carol", 1800)
});

// Top 3 — highest score first
SortedSetEntry[] top3 = db.SortedSetRangeByRankWithScores("leaderboard", 0, 2, Order.Descending);
// [("carol", 1800), ("alice", 1500), ("bob", 1200)]

// Rank of a specific member (0-indexed, ascending)
long? rank = db.SortedSetRank("leaderboard", "alice", Order.Descending);  // 1

// Atomic score update
db.SortedSetIncrement("leaderboard", "bob", 100);  // bob now has 1300
```

**Expiry and TTL**
```csharp
db.StringSet("otp:u42", "839201");
db.KeyExpire("otp:u42", TimeSpan.FromSeconds(300));        // 5 minute TTL
TimeSpan? ttl = db.KeyTimeToLive("otp:u42");               // seconds remaining
db.KeyPersist("otp:u42");                                  // remove TTL, key lives forever

// Set with expiry in one call
db.StringSet("session:abc", "data", TimeSpan.FromSeconds(3600));    // seconds
db.StringSet("session:xyz", "data", TimeSpan.FromMilliseconds(60000));  // milliseconds
```

**Distributed lock — SETNX pattern**
```csharp
using System;
using StackExchange.Redis;

var lockKey = "lock:resource:payments";
var lockVal = Guid.NewGuid().ToString();   // unique value so only we can release it

// Acquire: SET only if Not eXists, with TTL to prevent deadlock
bool acquired = db.StringSet(lockKey, lockVal, TimeSpan.FromSeconds(10), When.NotExists);

if (acquired)
{
    try
    {
        // critical section
    }
    finally
    {
        // Release only if we still own it — use a Lua script for atomicity
        var script = @"
            if redis.call(\"get\", KEYS[1]) == ARGV[1] then
                return redis.call(\"del\", KEYS[1])
            else
                return 0
            end";
        db.ScriptEvaluate(script, new RedisKey[] { lockKey }, new RedisValue[] { lockVal });
    }
}
```

**Pub/Sub — fire and forget messaging**
```csharp
// Publisher
db.Publish("notifications", "{\"user\": 42, \"msg\": \"welcome\"}");

// Subscriber (blocking)
var subscriber = redis.GetSubscriber();
subscriber.Subscribe("notifications", (channel, message) =>
{
    if (!message.IsNull)
    {
        Console.WriteLine(message.ToString());
    }
});

// Keep listening
while (true)
{
    System.Threading.Thread.Sleep(1000);
}
```

---

## Gotchas

- **Redis is single-threaded for commands — one slow Lua script or `KEYS *` blocks everything.** Never run `KEYS` in production; use `SCAN` with a cursor instead. Never write Lua scripts with loops over large datasets.
- **Persistence is off or lossy by default.** RDB snapshots can lose minutes of data on crash. AOF with `fsync=always` is safe but slower. AOF with `fsync=everysec` (default) can lose 1 second of writes. Know which mode you're running.
- **Memory is the hard limit.** When Redis hits `maxmemory`, it either rejects writes or evicts keys depending on `maxmemory-policy`. The default is `noeviction` — writes start failing. Set an eviction policy (`allkeys-lru` is common for caches) and monitor memory before you hit the ceiling.
- **TTL is not inherited.** If you overwrite a key with `SET`, its TTL is gone unless you pass `EX` again. `GETSET` and `SET ... KEEPTTL` exist but are easy to forget.
- **Pub/Sub has no message persistence.** If a subscriber is offline when a message is published, it's lost. For reliable messaging use Redis Streams (`XADD`/`XREAD`) which persist messages and support consumer groups.

---

## Interview Angle

**What they're really testing:** Whether you understand Redis as a data structure toolkit, not just a cache — and whether you know its failure modes.

**Common question form:** *"How would you implement a rate limiter?"* or *"How do you handle cache invalidation?"* or *"Design a leaderboard for 10M users."*

**The depth signal:** A junior says "use Redis to cache things." A senior knows which data type to reach for and why — sorted sets for leaderboards (O(log n) insert and rank lookup), `INCR` with `EXPIRE` for rate limiting (atomic, no race condition), `SETNX` with a unique value and Lua script for distributed locks (so only the owner can release). They also know what Redis is bad at: it's not a message queue with guaranteed delivery (use Streams, not Pub/Sub, for that), it's not durable by default, and `KEYS *` is a production outage in disguise.

---

## Related Topics

- [[databases/nosql-types.md]] — Redis is the key-value type; understanding where it fits in the NoSQL landscape prevents misuse.
- [[system-design/caching-strategies.md]] — Cache-aside, write-through, and write-behind patterns are all implemented on top of Redis primitives.
- [[system-design/rate-limiting.md]] — The `INCR` + `EXPIRE` and sliding window patterns are the standard Redis rate limiter implementations.
- [[system-design/distributed-locks.md]] — The SETNX + Lua release pattern and its failure modes (clock skew, network partition) are a common system design deep dive.

---

## Source

[Redis documentation — data types and commands](https://redis.io/docs/data-types/)

---
*Last updated: 2026-03-24*