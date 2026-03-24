# Redis Distributed Lock

> A mechanism for ensuring only one process across multiple machines can execute a critical section at a time, implemented using Redis's atomic SET NX command and the Redlock algorithm.

---

## When To Use It

Use a distributed lock when you have multiple application instances (horizontal scaling) and need to guarantee that exactly one of them executes a piece of code at a time — payment processing, inventory decrement, scheduled job execution, or any operation where running twice causes data corruption. Don't use it as a substitute for database transactions when the work you're protecting is purely database operations — a DB transaction with proper isolation is stronger and simpler. Distributed locks are for coordinating across processes, not for replacing ACID guarantees.

---

## Core Concept

A distributed lock has three requirements: only one owner at a time, automatic release if the owner crashes (TTL), and only the owner can release it. The naive `SETNX` + `EXPIRE` implementation looks correct but isn't — between the two commands, the process can crash leaving no TTL and a permanent lock. The fix is a single atomic `SET key value NX EX ttl` command. The release problem is subtler: if you just `DEL` the key, you might delete a lock owned by a different process that acquired it after yours expired. The fix is a Lua script that checks ownership before deleting — atomically. Redlock extends this to multiple Redis nodes for failure tolerance, at significant added complexity.

---

## The Code

**Single-node lock — production correct**
```python
import redis
import uuid
import time

r = redis.Redis(decode_responses=True)

UNLOCK_SCRIPT = """
if redis.call("get", KEYS[1]) == ARGV[1] then
    return redis.call("del", KEYS[1])
else
    return 0
end
"""

def acquire_lock(resource: str, ttl: int = 10) -> str | None:
    """
    Returns a lock token if acquired, None if not.
    ttl: seconds before lock auto-releases (must exceed critical section duration)
    """
    token = str(uuid.uuid4())
    key   = f"lock:{resource}"

    # SET NX EX is atomic — no gap between existence check and TTL set
    acquired = r.set(key, token, nx=True, ex=ttl)
    return token if acquired else None

def release_lock(resource: str, token: str) -> bool:
    """
    Only releases the lock if we still own it.
    Returns True if released, False if already expired or stolen.
    """
    key = f"lock:{resource}"
    result = r.eval(UNLOCK_SCRIPT, 1, key, token)
    return bool(result)

# Usage — manual
token = acquire_lock("payment:user:42", ttl=15)
if token is None:
    raise Exception("Could not acquire lock — another process holds it")
try:
    process_payment()
finally:
    release_lock("payment:user:42", token)
```

**Context manager — cleaner usage**
```python
from contextlib import contextmanager

@contextmanager
def redis_lock(resource: str, ttl: int = 10, retry: int = 3, delay: float = 0.1):
    token = None
    for attempt in range(retry):
        token = acquire_lock(resource, ttl)
        if token:
            break
        time.sleep(delay * (attempt + 1))   # linear backoff

    if token is None:
        raise TimeoutError(f"Failed to acquire lock for: {resource}")

    try:
        yield token
    finally:
        release_lock(resource, token)

# Usage
with redis_lock("inventory:item:88", ttl=10):
    decrement_inventory(item_id=88)
```

**Watchdog — extend TTL if work takes longer than expected**
```python
import threading

class WatchdogLock:
    def __init__(self, r, resource: str, ttl: int = 10):
        self.r        = r
        self.key      = f"lock:{resource}"
        self.ttl      = ttl
        self.token    = None
        self._stop    = threading.Event()
        self._thread  = None

    def acquire(self) -> bool:
        self.token = str(uuid.uuid4())
        acquired = self.r.set(self.key, self.token, nx=True, ex=self.ttl)
        if acquired:
            self._start_watchdog()
        return bool(acquired)

    def _start_watchdog(self):
        def renew():
            # Renew at 1/3 of TTL interval so there's always headroom
            interval = self.ttl / 3
            while not self._stop.wait(interval):
                # Only extend if we still own the lock
                current = self.r.get(self.key)
                if current == self.token:
                    self.r.expire(self.key, self.ttl)
                else:
                    break   # lock was lost — stop renewing

        self._thread = threading.Thread(target=renew, daemon=True)
        self._thread.start()

    def release(self):
        self._stop.set()
        release_lock(self.key.removeprefix("lock:"), self.token)

    def __enter__(self):
        if not self.acquire():
            raise TimeoutError(f"Could not acquire: {self.key}")
        return self

    def __exit__(self, *_):
        self.release()
```

**Redlock — multi-node lock for failure tolerance**
```python
# Redlock: acquire on majority of N independent Redis nodes
# If Redis master fails, a single-node lock can be acquired twice.
# Redlock requires a majority (N//2 + 1) to consider the lock held.

import time

nodes = [
    redis.Redis(host="redis-1", decode_responses=True),
    redis.Redis(host="redis-2", decode_responses=True),
    redis.Redis(host="redis-3", decode_responses=True),
]

def redlock_acquire(resource: str, ttl: int = 10) -> tuple[str, int] | None:
    token      = str(uuid.uuid4())
    key        = f"lock:{resource}"
    quorum     = len(nodes) // 2 + 1
    start      = time.monotonic()
    acquired   = 0

    for node in nodes:
        try:
            if node.set(key, token, nx=True, ex=ttl):
                acquired += 1
        except redis.RedisError:
            pass   # treat node failure as a non-acquire

    elapsed     = time.monotonic() - start
    validity_ms = int(ttl * 1000 - elapsed * 1000)

    if acquired >= quorum and validity_ms > 0:
        return token, validity_ms   # lock held with remaining validity time

    # Failed to get quorum — release whatever we did acquire
    redlock_release(resource, token)
    return None

def redlock_release(resource: str, token: str):
    key = f"lock:{resource}"
    for node in nodes:
        try:
            node.eval(UNLOCK_SCRIPT, 1, key, token)
        except redis.RedisError:
            pass   # best effort — TTL will clean up
```

**What goes wrong — failure scenarios in code**
```python
# WRONG: two separate commands — crash between them = permanent lock
r.setnx("lock:payments", token)   # acquires
r.expire("lock:payments", 10)     # crash here → lock never expires

# WRONG: DEL without ownership check — deletes another owner's lock
r.delete("lock:payments")         # dangerous if our TTL already expired

# WRONG: checking then deleting — race between check and delete
if r.get("lock:payments") == token:   # another process could acquire here
    r.delete("lock:payments")         # we just deleted their lock

# CORRECT: atomic SET NX EX + Lua release (shown above)
```

---

## Gotchas

- **TTL shorter than critical section = two owners simultaneously.** If payment processing takes 12 seconds and TTL is 10, the lock expires and another process acquires it while you're still running. Either use a watchdog to extend TTL, or set TTL to the worst-case execution time plus a safety margin.
- **Redlock is controversial.** Martin Kleppmann argued that Redlock is unsafe under process pauses (GC, VM suspension) — the lock can expire while the process is paused, another acquires it, then the first resumes and both think they hold it. The fix is a fencing token (monotonic counter) that the downstream resource validates. If you need that level of correctness, use ZooKeeper or etcd instead.
- **Redis failover breaks single-node lock guarantees.** If a Redis master fails before replicating the lock key to the replica, and the replica is promoted, the lock is gone — another process can acquire it. Redlock was designed to address this but carries its own tradeoffs (see above).
- **Never use `KEYS lock:*` to inspect locks in production.** It blocks Redis for the duration of the full keyspace scan. Use `SCAN` with a match pattern instead.
- **Clock drift matters in Redlock.** Redlock subtracts elapsed acquisition time from the validity window to account for drift, but significant clock skew between nodes can still cause the calculated validity to be wrong. Keep NTP synchronized across all Redis nodes.

---

## Interview Angle

**What they're really testing:** Whether you understand the failure modes of distributed systems and can reason about atomicity, TTL, and split-brain scenarios.

**Common question form:** *"How would you implement a distributed lock?"* or *"What happens if the process holding a lock crashes?"* or *"Is Redlock safe?"*

**The depth signal:** A junior says "use SETNX and set a TTL." A senior explains why those must be a single atomic command, why release needs a Lua script (check-and-delete atomicity), what happens when the TTL is shorter than the work (two owners), and what happens on Redis failover (replica promotion loses the key). At the senior+ level: they know Kleppmann's critique of Redlock — that a GC pause can cause a process to resume after its lock expired and proceed anyway — and that the real solution is a fencing token validated by the protected resource, not just the lock itself.

---

## Related Topics

- [[databases/redis-fundamentals.md]] — SET NX EX, Lua scripting, and TTL mechanics that the lock is built on.
- [[databases/redis-patterns.md]] — The lock pattern in context alongside rate limiting, caching, and queues.
- [[system-design/distributed-locks.md]] — Fencing tokens, ZooKeeper vs Redis tradeoffs, and when you need stronger guarantees than Redlock.
- [[databases/mvcc-and-isolation-levels.md]] — Understanding what DB transactions give you clarifies when a distributed lock is actually needed vs. when a serializable transaction suffices.

---

## Source

[Martin Kleppmann — How to do distributed locking](https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html)

---
*Last updated: 2026-03-24*