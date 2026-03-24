# Consistent Hashing

> A hashing strategy for distributing data across nodes such that adding or removing a node only remaps a small fraction of keys — not all of them.

---

## When To Use It
Any time you need to distribute data or load across a dynamic set of nodes: distributed caches (Redis Cluster, Memcached), database shards, load balancers that need request affinity. The alternative — `hash(key) % N` — is simple but catastrophic on topology changes: adding one node changes the mapping of ~(N-1)/N of all keys, causing a near-total cache miss storm or massive data movement. Consistent hashing keeps that to ~1/N of keys.

---

## Core Concept
Imagine a circle (the hash ring) spanning 0 to 2³². Every node is hashed to a point on this ring. Every key is also hashed to a point on the ring. To find which node owns a key, walk clockwise from the key's position until you hit a node — that's the owner. Adding a new node only takes ownership of keys between itself and the previous node on the ring — all other assignments are undisturbed. Removing a node only moves its keys to the next node clockwise. The problem with a basic ring is uneven distribution — one node might own 40% of the ring and another 5%. Virtual nodes (vnodes) fix this: each physical node is placed at multiple positions on the ring, producing a much more even distribution.

---

## The Code
```python
# ── Consistent hashing with virtual nodes ────────────────────────────────
import hashlib
import bisect

class ConsistentHashRing:
    def __init__(self, nodes: list[str] = [], replicas: int = 150):
        """
        replicas: number of virtual nodes per physical node.
        Higher = better distribution, more memory overhead.
        150 is a common production default.
        """
        self.replicas = replicas
        self.ring: dict[int, str] = {}   # hash position → physical node
        self.sorted_keys: list[int] = [] # sorted list of hash positions

        for node in nodes:
            self.add_node(node)

    def _hash(self, key: str) -> int:
        return int(hashlib.md5(key.encode()).hexdigest(), 16)

    def add_node(self, node: str) -> None:
        for i in range(self.replicas):
            vnode_key = f"{node}:vnode:{i}"
            position  = self._hash(vnode_key)
            self.ring[position] = node
            bisect.insort(self.sorted_keys, position)   # keep sorted

    def remove_node(self, node: str) -> None:
        for i in range(self.replicas):
            vnode_key = f"{node}:vnode:{i}"
            position  = self._hash(vnode_key)
            del self.ring[position]
            self.sorted_keys.remove(position)

    def get_node(self, key: str) -> str:
        """Find the node responsible for this key."""
        if not self.ring:
            raise RuntimeError("Ring is empty — no nodes available.")
        position = self._hash(key)
        # Find first node clockwise from this position
        idx = bisect.bisect(self.sorted_keys, position) % len(self.sorted_keys)
        return self.ring[self.sorted_keys[idx]]


# ── Usage ─────────────────────────────────────────────────────────────────
ring = ConsistentHashRing(nodes=["cache-1", "cache-2", "cache-3"])

keys = ["user:1001", "user:1002", "session:abc", "product:999", "feed:42"]
for key in keys:
    print(f"{key:20} → {ring.get_node(key)}")

print("\n--- Adding cache-4 ---")
ring.add_node("cache-4")
for key in keys:
    print(f"{key:20} → {ring.get_node(key)}")
# Only ~25% of keys should change nodes — the rest stay put.
```
```python
# ── Distribution analysis — verify vnodes are working ────────────────────
from collections import Counter

ring   = ConsistentHashRing(nodes=["cache-1", "cache-2", "cache-3"], replicas=150)
sample = [f"key:{i}" for i in range(10_000)]

distribution = Counter(ring.get_node(k) for k in sample)
for node, count in sorted(distribution.items()):
    bar = "█" * (count // 50)
    print(f"{node}: {count:>5} keys  {bar}")

# With replicas=150, expect roughly 33% ± 5% per node.
# With replicas=1, distribution will be wildly uneven.
```

---

## Gotchas
- **`hash % N` and consistent hashing are not interchangeable during resharding.** If you built your cache or shard routing on `hash % N` and then switch to consistent hashing, the key assignments change completely — effectively a full cache miss event. Commit to consistent hashing before you have data, or plan a migration window.
- **Virtual node count is a tuning decision with real trade-offs.** Too few vnodes (< 50) and distribution is uneven — one physical node handles significantly more keys than others. Too many (> 500) and memory usage and rebalancing time increase. 150 is a common default; measure your actual distribution before going to production.
- **Consistent hashing doesn't prevent hot keys.** If one key receives 80% of requests, the node that owns it is hot regardless of how well the ring distributes key ownership. Hot key mitigation (key replication, request routing randomization) is a separate problem.
- **Node failure and replacement are not the same operation.** Removing a failed node immediately causes its keys to move to the next clockwise node — that node now handles 2× the load temporarily. In production, you remove the failed node and add a replacement in quick succession, or use replication so adjacent nodes already have a copy.
- **Monotonic reads and read-your-writes don't come for free.** Consistent hashing tells you which node owns a key; it doesn't ensure that node has the latest version of the data. Replication factor, quorum reads, and consistency levels are additional considerations layered on top.

---

## Interview Angle
**What they're really testing:** Whether you understand why naive modulo hashing breaks on topology changes and how consistent hashing avoids the rehashing problem.

**Common question form:** "How does Redis Cluster distribute data?" or "Design a distributed cache. How do you handle adding/removing cache nodes?"

**The depth signal:** A junior candidate says "hash the key, mod by number of nodes." A senior candidate immediately flags the problem with that approach: "Modulo hashing remaps the majority of keys every time a node is added or removed — that's a cache miss storm. Consistent hashing bounds key movement to 1/N of keys per topology change." They then explain the ring, why vnodes are necessary for even distribution, and what the replica factor of each node means for fault tolerance. Bonus signal: they mention that Cassandra and Redis Cluster both use consistent hashing, and can explain how token ranges in Cassandra correspond to ring segments. The separation is: juniors know modulo hashing is simple, seniors know why it fails and what replaces it.

---

## Related Topics
- [[system-design/database-sharding.md]] — Consistent hashing is the standard algorithm for shard key routing.
- [[system-design/caching.md]] — Distributed caches use consistent hashing to assign keys to nodes.
- [[system-design/load-balancing.md]] — Consistent hashing enables stateful load balancing (session affinity) without lookup tables.

---

## Source
https://www.cs.princeton.edu/courses/archive/fall09/cos518/papers/chash.pdf

---
*Last updated: 2026-03-24*