# Database Scaling

> Strategies for increasing a database's capacity to handle more reads, more writes, or more data than a single instance can support.

---

## When To Use It
When your database is the bottleneck — query latency is rising, connection pools are saturated, disk I/O is maxed, or storage is running out. Before any of these strategies, rule out bad queries and missing indexes first. Scaling infrastructure around a slow query just distributes the slowness. The order of operations: optimize → cache → scale reads → scale writes → shard.

---

## Core Concept
Database scaling has two distinct axes: read scaling and write scaling. They require different solutions. Read scaling is relatively easy — you add read replicas that receive a copy of every write from the primary, and route read traffic across them. Write scaling is hard — all writes must go to one place to maintain consistency, so you either vertically scale the primary, reduce write volume with caching, or shard (split data across multiple primaries). Storage scaling is solved with distributed storage, object stores, or partitioning. Each step up in complexity adds operational overhead and often introduces consistency trade-offs.

---

## The Code
```python
# ── Read replica routing — most common first scaling step ─────────────────
import random
import psycopg2

class DatabasePool:
    def __init__(self, primary_dsn: str, replica_dsns: list[str]):
        self.primary  = psycopg2.connect(primary_dsn)
        self.replicas = [psycopg2.connect(dsn) for dsn in replica_dsns]

    def write_conn(self):
        """All writes go to primary — always."""
        return self.primary

    def read_conn(self):
        """Reads distributed across replicas. Primary handles reads only on fallback."""
        if self.replicas:
            return random.choice(self.replicas)   # simple random; use least-connections in prod
        return self.primary                        # fallback if no replicas yet

pool = DatabasePool(
    primary_dsn  = "postgresql://primary:5432/db",
    replica_dsns = [
        "postgresql://replica-1:5432/db",
        "postgresql://replica-2:5432/db",
    ]
)

# Write: goes to primary
with pool.write_conn().cursor() as cur:
    cur.execute("INSERT INTO orders (user_id, total) VALUES (%s, %s)", (42, 99.99))
    pool.write_conn().commit()

# Read: goes to a replica
with pool.read_conn().cursor() as cur:
    cur.execute("SELECT * FROM orders WHERE user_id = %s", (42,))
    rows = cur.fetchall()
```
```sql
-- ── Connection pooling — mandatory before any other scaling step ──────────
-- Each DB connection costs ~5–10 MB of RAM on Postgres.
-- 1000 app servers × 10 connections each = 10,000 connections = ~50–100 GB RAM.
-- PgBouncer sits between app and Postgres, multiplexing connections.

-- PgBouncer config (pgbouncer.ini):
-- [databases]
-- mydb = host=primary port=5432 dbname=mydb
--
-- [pgbouncer]
-- pool_mode = transaction          ← connection released after each transaction
-- max_client_conn = 10000          ← app can open 10K connections to PgBouncer
-- default_pool_size = 20           ← PgBouncer uses only 20 real DB connections
```
```python
# ── CQRS: separate read and write models ──────────────────────────────────
# Write model: normalized, consistent, ACID
# Read model: denormalized, optimized for query patterns, eventually consistent

# Write side — strict, normalized
def place_order(user_id: int, items: list[dict]) -> str:
    with pool.write_conn().cursor() as cur:
        cur.execute("INSERT INTO orders (user_id) VALUES (%s) RETURNING id", (user_id,))
        order_id = cur.fetchone()[0]
        for item in items:
            cur.execute(
                "INSERT INTO order_items (order_id, product_id, qty) VALUES (%s, %s, %s)",
                (order_id, item["product_id"], item["qty"])
            )
        pool.write_conn().commit()
    # Publish event → async worker updates the read model
    publish_event("order.created", {"order_id": order_id, "user_id": user_id})
    return order_id

# Read side — denormalized, fast
def get_order_summary(order_id: str) -> dict:
    # This table is pre-joined and pre-aggregated — single fast read
    with pool.read_conn().cursor() as cur:
        cur.execute("SELECT * FROM order_summaries WHERE order_id = %s", (order_id,))
        return dict(zip([d[0] for d in cur.description], cur.fetchone()))
```

---

## Gotchas
- **Replication lag is not theoretical.** Under write load, replicas can lag the primary by seconds. A user who writes data and immediately reads it from a replica may see stale results. Mitigate with read-your-writes routing (route the requesting user's reads to the primary for a short window after a write).
- **Connection count is a scaling bottleneck most teams hit before they expect it.** PostgreSQL's connection limit is typically 100–200 on default configs. Without a connection pooler (PgBouncer, RDS Proxy), 50 app instances with 10 connections each can saturate the database before you've even loaded it.
- **Vertical scaling the primary has a hard ceiling — and the ceiling is lower than you think.** Postgres on a 96-core machine doesn't scale linearly past 32 cores for many workloads due to lock contention. Adding more CPU past a certain point returns diminishing results.
- **Read replicas don't help write-heavy workloads.** If 90% of your database load is writes, adding replicas does nothing — the primary is still the bottleneck. Write scaling requires architectural changes: write batching, async writes, or sharding.
- **Never scale before profiling.** The most common database scaling mistake is adding replicas or sharding when the actual problem is a missing index or an N+1 query. Run `EXPLAIN ANALYZE` before any infrastructure change.

---

## Interview Angle
**What they're really testing:** Whether you can diagnose a database bottleneck and prescribe the right scaling strategy — rather than jumping straight to the most complex solution.

**Common question form:** "Your database can't keep up with traffic. How do you scale it?" or "Design a system that handles 100K writes per second."

**The depth signal:** A junior candidate immediately says "shard it" or "use NoSQL." A senior candidate asks what the bottleneck actually is: "Is it read-heavy or write-heavy? What does the query profile look like? Is connection count the issue or actual query time?" Then they prescribe in order: "First, connection pooler if not in place. Then read replicas for read-heavy load. Then caching to reduce read amplification. Then if write throughput is the actual limit, we look at write batching, async writes, or sharding — with sharding being the last resort because of the operational complexity." The separation is: juniors name a technique, seniors prescribe a sequence based on diagnosis.

---

## Related Topics
- [[system-design/database-sharding.md]] — The next step when vertical scaling and replicas aren't enough.
- [[system-design/caching.md]] — Reducing database read load before scaling the database itself.
- [[system-design/horizontal-vs-vertical-scaling.md]] — The general scaling framework that database scaling lives inside.

---

## Source
https://use-the-index-luke.com/

---
*Last updated: 2026-03-24*