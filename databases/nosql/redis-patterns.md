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
```python
import redis, json

r = redis.Redis(decode_responses=True)

def get_user(user_id: int) -> dict:
    cache_key = f"user:{user_id}"

    cached = r.get(cache_key)
    if cached:
        return json.loads(cached)          # cache hit

    user = db.query("SELECT * FROM users WHERE id = %s", user_id)
    r.set(cache_key, json.dumps(user), ex=300)  # cache for 5 min
    return user

def update_user(user_id: int, data: dict):
    db.execute("UPDATE users SET ... WHERE id = %s", user_id)
    r.delete(f"user:{user_id}")            # invalidate, don't update
    # Delete > update: avoids stale writes racing with reads
```

**Pattern 2 — Rate Limiter (Fixed Window)**
```python
def is_rate_limited(user_id: str, limit: int = 100, window: int = 60) -> bool:
    key = f"rate:{user_id}:{int(time.time() // window)}"

    # INCR is atomic — no race between read and increment
    count = r.incr(key)

    if count == 1:
        r.expire(key, window)   # set TTL only on first increment
                                # avoids overwriting TTL on subsequent hits
    return count > limit
```

**Pattern 2b — Rate Limiter (Sliding Window with Sorted Set)**
```python
import time

def is_rate_limited_sliding(user_id: str, limit: int = 100, window: int = 60) -> bool:
    now = time.time()
    key = f"rate:sliding:{user_id}"

    pipe = r.pipeline()
    pipe.zremrangebyscore(key, 0, now - window)   # remove expired entries
    pipe.zadd(key, {str(now): now})               # add current request
    pipe.zcard(key)                               # count requests in window
    pipe.expire(key, window)
    results = pipe.execute()

    return results[2] > limit                     # results[2] = zcard result
```

**Pattern 3 — Distributed Lock**
```python
import uuid, time

class RedisLock:
    def __init__(self, r, key: str, ttl: int = 10):
        self.r   = r
        self.key = f"lock:{key}"
        self.ttl = ttl
        self.val = str(uuid.uuid4())   # unique owner token

    def acquire(self, timeout: int = 5) -> bool:
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.r.set(self.key, self.val, nx=True, ex=self.ttl):
                return True
            time.sleep(0.05)
        return False

    def release(self):
        # Lua script: check owner AND delete in one atomic operation
        # Without this, we might delete another owner's lock
        script = """
        if redis.call("get", KEYS[1]) == ARGV[1] then
            return redis.call("del", KEYS[1])
        else
            return 0
        end
        """
        self.r.eval(script, 1, self.key, self.val)

    def __enter__(self):
        if not self.acquire():
            raise TimeoutError(f"Could not acquire lock: {self.key}")
        return self

    def __exit__(self, *_):
        self.release()

# Usage
with RedisLock(r, "payment:user:42"):
    process_payment()
```

**Pattern 4 — Leaderboard**
```python
def submit_score(user_id: str, score: float):
    # ZADD with GT: only updates if new score is greater than existing
    r.zadd("leaderboard:global", {user_id: score}, gt=True)

def get_top(n: int = 10) -> list[dict]:
    # zrevrange: highest score first
    results = r.zrevrange("leaderboard:global", 0, n - 1, withscores=True)
    return [{"user": uid, "score": score} for uid, score in results]

def get_rank(user_id: str) -> int | None:
    rank = r.zrevrank("leaderboard:global", user_id)
    return rank + 1 if rank is not None else None   # 1-indexed

def get_around(user_id: str, radius: int = 2) -> list[dict]:
    rank = r.zrevrank("leaderboard:global", user_id)
    if rank is None:
        return []
    start = max(0, rank - radius)
    end   = rank + radius
    results = r.zrevrange("leaderboard:global", start, end, withscores=True)
    return [{"user": uid, "score": score} for uid, score in results]
```

**Pattern 5 — Reliable Queue with Streams**
```python
# Streams > Pub/Sub for reliable messaging — messages persist and can be replayed

# Producer
def enqueue(stream: str, payload: dict):
    r.xadd(stream, payload, maxlen=10_000)   # cap stream length

# Consumer with consumer group — each message delivered to one consumer
r.xgroup_create("jobs", "workers", id="0", mkstream=True)

def consume(stream: str, group: str, consumer: str):
    while True:
        messages = r.xreadgroup(
            group, consumer, {stream: ">"}, count=10, block=2000
        )
        for _, entries in (messages or []):
            for msg_id, data in entries:
                try:
                    process(data)
                    r.xack(stream, group, msg_id)   # ack only after success
                except Exception:
                    pass   # message stays pending — redelivered on timeout
```

**Pattern 6 — Session Storage**
```python
import uuid, json

def create_session(user_id: int, ttl: int = 86400) -> str:
    session_id = str(uuid.uuid4())
    r.hset(f"session:{session_id}", mapping={
        "user_id": user_id,
        "created": int(time.time()),
    })
    r.expire(f"session:{session_id}", ttl)
    return session_id

def get_session(session_id: str) -> dict | None:
    data = r.hgetall(f"session:{session_id}")
    if not data:
        return None
    r.expire(f"session:{session_id}", 86400)   # sliding expiry on access
    return data

def delete_session(session_id: str):
    r.delete(f"session:{session_id}")
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