# CAP Theorem

> A distributed system can guarantee at most two of three properties — Consistency, Availability, and Partition Tolerance — never all three simultaneously.

---

## When To Use It
Any time you're designing or evaluating a distributed system that spans multiple nodes or machines. It's the lens you use when deciding between databases, when reasoning about what happens during a network failure, and when answering "what does the system do when things go wrong?" If your system runs on a single machine, CAP doesn't apply — there's no partition to tolerate.

---

## Core Concept
In a distributed system, network partitions — where nodes can't talk to each other — are not hypothetical, they're inevitable. When a partition happens, you're forced to choose: do you keep serving requests (availability) even though different nodes might give different answers, or do you stop serving requests (sacrifice availability) to ensure every response is correct (consistency)? Partition Tolerance isn't a choice you make — it's a fact of distributed systems. So the real trade-off is always CP vs AP: consistent-but-sometimes-unavailable, or available-but-sometimes-stale. Most real systems let you tune this per operation rather than picking one for everything.

---

## The Code
```python
# ── Simulating CP vs AP behavior during a partition ───────────────────────

from enum import Enum

class Mode(Enum):
    CP = "consistent"    # refuse writes during partition to stay correct
    AP = "available"     # accept writes during partition, reconcile later

class DistributedNode:
    def __init__(self, node_id: str, mode: Mode):
        self.node_id = node_id
        self.mode = mode
        self.data: dict = {}
        self.partitioned = False   # simulates a network split

    def write(self, key: str, value: str) -> dict:
        if self.partitioned and self.mode == Mode.CP:
            # CP: refuse the write — can't confirm other nodes agree
            return {"ok": False, "error": "Partition detected. Write rejected to preserve consistency."}

        # AP: accept the write locally, reconcile with peers later
        self.data[key] = value
        return {"ok": True, "node": self.node_id, "note": "Written locally. May conflict with peers."}

    def read(self, key: str) -> dict:
        return {"ok": True, "value": self.data.get(key), "node": self.node_id}


cp_node = DistributedNode("primary", Mode.CP)
ap_node = DistributedNode("replica", Mode.AP)

cp_node.partitioned = True
ap_node.partitioned = True

print(cp_node.write("user:1", "Alice"))   # rejected
print(ap_node.write("user:1", "Alice"))   # accepted, may diverge
```
```python
# ── Real-world database positioning on the CAP triangle ──────────────────

databases = {
    # CP — consistent, may be unavailable during partitions
    "HBase":       "CP — refuses reads/writes when quorum not reached",
    "Zookeeper":   "CP — coordination system, correctness over availability",
    "MongoDB":     "CP (default) — primary-only writes; goes unavailable without quorum",

    # AP — available, may serve stale data during partitions
    "Cassandra":   "AP — always writable, eventual consistency, tunable per query",
    "CouchDB":     "AP — accepts writes everywhere, resolves conflicts on sync",
    "DynamoDB":    "AP (default) — eventually consistent reads; strongly consistent optional",

    # CA — only possible without partitions (i.e., single node or trusted network)
    "PostgreSQL":  "CA — single node only; distributed Postgres gives up C or A",
}

for db, position in databases.items():
    print(f"{db:<14} {position}")
```

---

## Gotchas
- **CA is not a real option in distributed systems.** Choosing CA means you're not distributed — you're running on one machine or an unrealistically reliable network. Any system that claims CA at scale is misrepresenting itself.
- **CAP is binary in theory, tunable in practice.** Cassandra's consistency level per query (ONE, QUORUM, ALL) is exactly this — you're sliding between AP and CP on a per-operation basis. Most modern databases give you this knob.
- **"Consistent" in CAP means linearizability, not just "no bugs."** It means every read returns the result of the most recent write, globally. This is a very strong guarantee — much stronger than what most databases provide by default.
- **Availability in CAP means every request gets a response — not that the response is fast.** A node that responds in 30 seconds is technically "available" in the CAP sense. This is why PACELC (which adds latency as an axis) is a more complete model.
- **Network partitions are rare but not theoretical.** Cloud provider AZ outages, misconfigured firewalls, rolling deployments, and flaky NICs all cause real partitions. "We'll never partition" is not a design assumption — it's wishful thinking.

---

## Interview Angle
**What they're really testing:** Whether you understand that every distributed system makes an implicit trade-off during failures — and whether you can reason about that trade-off for a specific use case.

**Common question form:** "Would you use Cassandra or PostgreSQL for this?" or "What happens to your system when a node goes down?"

**The depth signal:** A junior candidate recites the definition: "CAP stands for Consistency, Availability, Partition Tolerance and you can only have two." A senior candidate applies it: "For a shopping cart, I'd lean AP — a slightly stale cart is acceptable, and refusing writes to a cart while a node is down would cost revenue. But for payment processing, I want CP — I'd rather the request fail than charge someone twice. And I'd add an idempotency key at the application layer on top of that." The separation is: juniors define the theorem, seniors apply it to trade-offs in a specific system.

---

## Related Topics
- [[system-design/acid-vs-base.md]] — ACID and BASE are the database-level expressions of CP and AP trade-offs.
- [[system-design/requirements-gathering.md]] — Consistency and availability requirements must be established before picking a database.
- [[databases/sql-vs-nosql.md]] — SQL vs NoSQL choices are partially driven by where each sits on the CAP triangle.

---

## Source
https://www.infoq.com/articles/cap-twelve-years-later-how-the-rules-have-changed/

---
*Last updated: 2026-03-24*