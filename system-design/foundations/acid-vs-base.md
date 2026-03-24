# ACID vs BASE

> Two competing consistency models for databases — ACID prioritizes correctness and guarantees, BASE prioritizes availability and accepts temporary inconsistency.

---

## When To Use It
Whenever you're choosing a database or designing a data layer, you're implicitly choosing between these models. ACID is the right choice when correctness is non-negotiable — financial transactions, inventory systems, any operation where partial failure must be invisible to the user. BASE is the right choice when scale and availability matter more than instant consistency — user activity feeds, view counters, recommendation systems, anything where "eventually right" is good enough.

---

## Core Concept
ACID (Atomicity, Consistency, Isolation, Durability) is the set of guarantees traditional relational databases make. A transaction either fully succeeds or fully fails, the database is always left in a valid state, concurrent transactions don't step on each other, and committed data survives crashes. BASE (Basically Available, Soft state, Eventually consistent) is what most distributed NoSQL systems offer instead. They'll always respond to requests (basically available), the data might be in flux as updates propagate (soft state), and given enough time without new writes, all nodes will agree (eventually consistent). The trade-off is real: ACID buys you correctness at the cost of coordination overhead; BASE buys you scale and uptime at the cost of having to handle inconsistency in your application code.

---

## The Code
```sql
-- ── ACID: bank transfer that must never partially complete ────────────────

BEGIN;

UPDATE accounts
SET balance = balance - 500
WHERE account_id = 'acc_alice'
  AND balance >= 500;           -- guard: fail if insufficient funds

-- If Alice didn't have enough, the row count is 0 — we abort
-- If we crash here, the UPDATE above is rolled back automatically

UPDATE accounts
SET balance = balance + 500
WHERE account_id = 'acc_bob';

COMMIT;
-- Either both updates are visible to all readers, or neither is. No in-between.
```
```python
# ── BASE: distributed counter that accepts temporary inconsistency ─────────
# Example: YouTube view counter. Exact count doesn't matter; approximate is fine.

import redis
import uuid

r = redis.Redis()

def record_view(video_id: str) -> None:
    # Each web server increments its local shard — no locking, no coordination
    shard_key = f"views:{video_id}:{uuid.uuid4().hex[:4]}"  # random shard
    r.incr(shard_key)
    # A background job periodically sums all shards into a final count.
    # During this window, different users see different totals — that's acceptable.

def get_approximate_view_count(video_id: str) -> int:
    keys = r.keys(f"views:{video_id}:*")
    return sum(int(r.get(k) or 0) for k in keys)
```
```python
# ── Comparing isolation levels (ACID spectrum within SQL databases) ────────

isolation_levels = {
    "READ UNCOMMITTED": {
        "dirty_read":          True,   # can see uncommitted data from other transactions
        "non_repeatable_read": True,
        "phantom_read":        True,
        "use_case":            "Almost never. Dirty reads are almost always a bug.",
    },
    "READ COMMITTED": {
        "dirty_read":          False,  # default in PostgreSQL
        "non_repeatable_read": True,
        "phantom_read":        True,
        "use_case":            "Most OLTP workloads where repeatable reads aren't required.",
    },
    "REPEATABLE READ": {
        "dirty_read":          False,
        "non_repeatable_read": False,
        "phantom_read":        True,   # MySQL InnoDB actually prevents this via MVCC
        "use_case":            "Reports that read multiple rows and must see a stable snapshot.",
    },
    "SERIALIZABLE": {
        "dirty_read":          False,
        "non_repeatable_read": False,
        "phantom_read":        False,  # full isolation — highest cost
        "use_case":            "Financial operations, anything where phantom reads cause bugs.",
    },
}
```

---

## Gotchas
- **"Eventually consistent" doesn't tell you how eventually.** In a healthy Cassandra cluster, propagation is milliseconds. During a partition or under heavy load, it can be seconds or longer. Your application code must handle reading stale data — not just know it might happen.
- **ACID transactions don't cross service boundaries.** A database transaction can atomically update two tables. It cannot atomically update a database and send a message to Kafka. Cross-service consistency requires distributed transactions (two-phase commit), sagas, or outbox patterns — each with significant trade-offs.
- **BASE systems push complexity to the application.** Conflict resolution, idempotency, and stale-read handling aren't solved by the database — you have to write that logic. This is the hidden cost that doesn't show up in database benchmarks.
- **Isolation ≠ Consistency in ACID.** These are separate guarantees. Consistency in ACID means your data integrity constraints are never violated. Isolation means concurrent transactions don't interfere with each other. A database can be consistent but have low isolation (READ COMMITTED still allows non-repeatable reads).
- **Serializable isolation is rarely the default for a reason.** SERIALIZABLE prevents all anomalies but requires locking or complex MVCC coordination that tanks throughput under contention. Most production systems run READ COMMITTED and handle edge cases explicitly rather than paying the SERIALIZABLE tax everywhere.

---

## Interview Angle
**What they're really testing:** Whether you understand the practical consequences of consistency choices — not just the acronym definitions.

**Common question form:** "How would you design a payment system?" or "What database would you use and why?"

**The depth signal:** A junior candidate says "I'd use a SQL database because it's ACID compliant." A senior candidate says "For the payment ledger I'd use Postgres at SERIALIZABLE isolation — phantom reads on balance checks can cause double-spend bugs and the transaction volume is low enough that serializable throughput isn't a bottleneck. For the activity feed showing recent transactions, I'd use an eventually consistent read replica or a denormalized table in Cassandra — users don't need to see a transfer they just made within the same millisecond, and I don't want feed reads competing with write locks on the ledger." The separation is: juniors pick ACID or BASE, seniors pick the right model for each part of the system.

---

## Related Topics
- [[system-design/cap-theorem.md]] — ACID maps to CP; BASE maps to AP. They're the same trade-off at different layers.
- [[databases/sql-vs-nosql.md]] — SQL databases default to ACID; most NoSQL databases implement BASE.
- [[databases/transactions-and-locking.md]] — The mechanics of how ACID isolation levels are actually enforced.

---

## Source
https://www.postgresql.org/docs/current/transaction-iso.html

---
*Last updated: 2026-03-24*