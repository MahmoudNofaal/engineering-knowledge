# Caching

> Storing the result of an expensive operation in fast storage so subsequent requests can skip the expensive operation entirely.

---

## When To Use It
When you have data that is read far more often than it changes, and computing or fetching it is slower than acceptable. Good cache candidates: database query results, rendered HTML, API responses from third parties, session tokens, computed aggregates. Bad cache candidates: data that changes on every request, data where stale reads cause correctness bugs (financial balances, inventory counts), data that's cheap to compute.

---

## Core Concept
Every cache is a trade-off between speed and freshness. You're betting that the data you stored a moment ago is still valid now. The cache sits between the requester and the origin (database, API, compute) and returns stored results when available — a cache hit. When the data isn't in cache or has expired — a cache miss — the request falls through to the origin, and the result is stored for next time. The hard problems in caching aren't the happy path; they're what happens when the cache is cold, when the cache and origin disagree, and when every server hits the database at once because the cache expired.

---

## The Code
```python
# ── Cache-aside (lazy loading) — the most common pattern ─────────────────
# App checks cache first. On miss, loads from DB and populates cache.
# Cache never has data it wasn't asked for — no wasted memory.

import redis
import json
import hashlib

r = redis.Redis(host="localhost", port=6379, decode_responses=True)

def get_user(user_id: str) -> dict:
    cache_key = f"user:{user_id}"
    TTL_SECONDS = 300   # 5 minutes

    cached = r.get(cache_key)
    if cached:
        return json.loads(cached)   # cache hit

    # cache miss — fetch from origin
    user = db_fetch_user(user_id)   # slow DB call
    r.setex(cache_key, TTL_SECONDS, json.dumps(user))
    return user

def db_fetch_user(user_id: str) -> dict:
    # Simulated DB call
    return {"id": user_id, "name": "Alice", "plan": "pro"}
```
```python
# ── Write-through — cache is updated on every write ──────────────────────
# Cache is always warm. Reads are always fast. Writes are slightly slower.
# Use when read latency matters more than write latency.

def update_user(user_id: str, data: dict) -> None:
    db_update_user(user_id, data)              # write to DB first
    cache_key = f"user:{user_id}"
    r.setex(cache_key, 300, json.dumps(data))  # then update cache

def db_update_user(user_id: str, data: dict) -> None:
    pass  # DB update logic
```
```python
# ── Cache stampede prevention (probabilistic early expiration) ────────────
# Problem: cache key expires, 10K concurrent requests all hit the DB at once.
# Solution: stagger expiry by jittering TTL so they don't all expire together.

import random

def set_with_jitter(key: str, value: str, base_ttl: int) -> None:
    jitter = random.randint(0, base_ttl // 10)   # ±10% jitter
    r.setex(key, base_ttl + jitter, value)

# Alternative: mutex lock — only one request rebuilds the cache.
# Everyone else either waits or gets stale data during rebuild.
import threading
_rebuild_locks: dict[str, threading.Lock] = {}

def get_with_mutex(key: str, rebuild_fn) -> str:
    cached = r.get(key)
    if cached:
        return cached

    lock = _rebuild_locks.setdefault(key, threading.Lock())
    with lock:
        cached = r.get(key)      # double-check after acquiring lock
        if cached:
            return cached
        value = rebuild_fn()
        r.setex(key, 300, value)
        return value
```
```python
# ── Eviction policies — what gets removed when cache is full ──────────────

eviction_policies = {
    "LRU":    "Evict least recently used. Best general-purpose default.",
    "LFU":    "Evict least frequently used. Better for skewed access patterns.",
    "TTL":    "Evict expired keys. Explicit freshness control.",
    "RANDOM": "Evict random key. Simple, surprisingly effective under uniform access.",
    "NOEVICTION": "Reject writes when full. Use only for session stores where you control size.",
}
# Set in redis.conf: maxmemory-policy allkeys-lru
```

---

## Gotchas
- **Cache invalidation is the hard part, not cache population.** Knowing when cached data is stale — and purging it correctly across a distributed cache cluster — is where most cache bugs live. TTL is the blunt instrument; event-driven invalidation is precise but complex.
- **Cache stampede (thundering herd) will take down your database.** When a popular key expires and thousands of requests simultaneously miss the cache and hit the DB, you've effectively DDoS'd your own database. Mutex locking or probabilistic early expiration prevents this.
- **Hot keys are a distributed cache problem.** If one cache key gets 50K requests/second and you have 10 cache nodes, that one key still lands on one node, which becomes a bottleneck. Mitigate with key replication or local in-process caching for extreme hot keys.
- **Memory is finite — eviction is not an error, it's expected.** Under memory pressure, Redis will evict keys according to policy. If your cache hit rate is dropping, the first question is whether your cache is too small for your working set, not whether there's a bug.
- **Caching at the wrong layer amplifies bugs.** Caching before input validation, or caching error responses (a 500 that gets cached and served for 5 minutes to every user), are easy production mistakes. Always verify what you're actually storing in the cache.

---

## Interview Angle
**What they're really testing:** Whether you understand caching as a system component with failure modes — not just a performance shortcut.

**Common question form:** "How would you handle high read traffic on this service?" or "How would you design a leaderboard / user profile / feed system?"

**The depth signal:** A junior candidate says "add a cache in front of the database." A senior candidate specifies the pattern (cache-aside vs write-through), the TTL strategy and why, what happens on a cold start (cache warming), how cache invalidation is handled on writes, what the eviction policy is and why, and explicitly addresses the stampede problem for high-traffic keys. They also distinguish between local in-process caching (fast, no network hop, not shared) and distributed caching (shared state, one extra network hop, needed for horizontal scale). The separation is: juniors know caches exist, seniors know the failure modes.

---

## Related Topics
- [[system-design/cdn.md]] — CDN is caching at the network edge — same concept, different layer.
- [[system-design/database-scaling.md]] — Caching is the first lever to pull before scaling the database itself.
- [[system-design/consistent-hashing.md]] — How distributed caches decide which node owns which key.

---

## Source
https://redis.io/docs/manual/patterns/

---
*Last updated: 2026-03-24*