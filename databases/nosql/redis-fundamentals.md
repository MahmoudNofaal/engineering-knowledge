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
```python
import redis

r = redis.Redis(decode_responses=True)

# Basic get/set with TTL (seconds)
r.set("user:42:name", "Ali", ex=3600)
r.get("user:42:name")  # "Ali"

# Atomic increment — no read-modify-write race condition
r.set("api:hits", 0)
r.incr("api:hits")       # 1
r.incrby("api:hits", 5)  # 6
```

**Hashes — structured objects**
```python
# Store a user object — one key, multiple fields
r.hset("user:42", mapping={
    "name":  "Ali",
    "email": "ali@example.com",
    "plan":  "pro"
})

r.hget("user:42", "plan")      # "pro"
r.hgetall("user:42")           # full dict
r.hincrby("user:42", "logins", 1)  # atomic field increment
```

**Lists — queues and stacks**
```python
# LPUSH + RPOP = queue (FIFO)
r.lpush("jobs", "job:1", "job:2", "job:3")
r.rpop("jobs")   # "job:1"

# BLPOP = blocking pop — waits until an item appears (timeout in seconds)
r.blpop("jobs", timeout=5)

# LPUSH + LPOP = stack (LIFO)
r.lpush("history", "page:home")
r.lpop("history")
```

**Sets — unique membership**
```python
r.sadd("online_users", "u1", "u2", "u3")
r.sismember("online_users", "u2")   # True
r.smembers("online_users")          # {"u1", "u2", "u3"}

# Set operations — who's online in both groups?
r.sadd("group:a", "u1", "u2")
r.sadd("group:b", "u2", "u3")
r.sinter("group:a", "group:b")      # {"u2"}
```

**Sorted Sets — leaderboards and ranked data**
```python
# zadd: key → {member: score}
r.zadd("leaderboard", {"alice": 1500, "bob": 1200, "carol": 1800})

# Top 3 — highest score first
r.zrevrange("leaderboard", 0, 2, withscores=True)
# [("carol", 1800.0), ("alice", 1500.0), ("bob", 1200.0)]

# Rank of a specific member (0-indexed, ascending)
r.zrevrank("leaderboard", "alice")  # 1

# Atomic score update
r.zincrby("leaderboard", 100, "bob")  # bob now has 1300
```

**Expiry and TTL**
```python
r.set("otp:u42", "839201")
r.expire("otp:u42", 300)        # 5 minute TTL
r.ttl("otp:u42")                # seconds remaining
r.persist("otp:u42")            # remove TTL, key lives forever

# Set with expiry in one call
r.set("session:abc", "data", ex=3600)   # seconds
r.set("session:xyz", "data", px=60000)  # milliseconds
```

**Distributed lock — SETNX pattern**
```python
import uuid

lock_key = "lock:resource:payments"
lock_val = str(uuid.uuid4())   # unique value so only we can release it

# Acquire: SET only if Not eXists, with TTL to prevent deadlock
acquired = r.set(lock_key, lock_val, nx=True, ex=10)

if acquired:
    try:
        # critical section
        pass
    finally:
        # Release only if we still own it — use a Lua script for atomicity
        script = """
        if redis.call("get", KEYS[1]) == ARGV[1] then
            return redis.call("del", KEYS[1])
        else
            return 0
        end
        """
        r.eval(script, 1, lock_key, lock_val)
```

**Pub/Sub — fire and forget messaging**
```python
# Publisher
r.publish("notifications", '{"user": 42, "msg": "welcome"}')

# Subscriber (blocking)
pubsub = r.pubsub()
pubsub.subscribe("notifications")
for message in pubsub.listen():
    if message["type"] == "message":
        print(message["data"])
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