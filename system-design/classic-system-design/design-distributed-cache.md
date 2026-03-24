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

```python
# Cache-aside pattern (most common in production)
import redis
import json
from typing import Optional

r = redis.Redis(host='localhost', port=6379, db=0)

def get_user(user_id: int, db) -> Optional[dict]:
    cache_key = f"user:{user_id}"

    # 1. Try cache first
    cached = r.get(cache_key)
    if cached:
        return json.loads(cached)  # Cache hit

    # 2. Cache miss — fetch from DB
    user = db.query("SELECT * FROM users WHERE id = %s", user_id)
    if not user:
        return None

    # 3. Populate cache with TTL
    r.setex(cache_key, 3600, json.dumps(user))  # 1 hour TTL
    return user

def update_user(user_id: int, data: dict, db):
    # 1. Write to DB first
    db.execute("UPDATE users SET ... WHERE id = %s", user_id)

    # 2. Invalidate cache — don't update it, just delete
    r.delete(f"user:{user_id}")
    # Next read will repopulate from DB (lazy re-population)
```

```python
# Cache stampede prevention with probabilistic early expiration
import time
import random
import json
import redis

r = redis.Redis(host='localhost', port=6379, db=0)

def get_with_stampede_protection(key: str, ttl: int, fetch_fn, beta: float = 1.0):
    """
    XFetch algorithm: recompute slightly before expiry with probability
    proportional to how close we are to expiration.
    beta > 1 = more aggressive early recomputation (less stampede risk)
    """
    cached = r.get(key)
    if cached:
        data = json.loads(cached)
        expiry = r.ttl(key)
        remaining = expiry / ttl  # Fraction of TTL remaining

        # Probabilistically decide to recompute early
        if remaining > random.uniform(0, 1) ** (1 / beta):
            return data  # Still fresh enough

    # Recompute (either expired or early recompute triggered)
    value = fetch_fn()
    r.setex(key, ttl, json.dumps(value))
    return value
```

```python
# Consistent hashing for distributing keys across cache nodes
import hashlib
import bisect

class ConsistentHashRing:
    def __init__(self, nodes: list[str], virtual_nodes: int = 150):
        self.ring = {}
        self.sorted_keys = []

        for node in nodes:
            for i in range(virtual_nodes):
                # Virtual nodes reduce hotspot risk
                key = self._hash(f"{node}:{i}")
                self.ring[key] = node
                bisect.insort(self.sorted_keys, key)

    def _hash(self, value: str) -> int:
        return int(hashlib.md5(value.encode()).hexdigest(), 16)

    def get_node(self, cache_key: str) -> str:
        """Find which node should hold this cache key."""
        if not self.ring:
            return None
        h = self._hash(cache_key)
        idx = bisect.bisect(self.sorted_keys, h) % len(self.sorted_keys)
        return self.ring[self.sorted_keys[idx]]

# Usage
ring = ConsistentHashRing(["cache-1", "cache-2", "cache-3"])
print(ring.get_node("user:42"))       # → "cache-2" (deterministic)
print(ring.get_node("user:43"))       # → "cache-1"
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