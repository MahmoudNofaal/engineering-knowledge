# Database Partitioning

> Dividing a single database table into smaller, physically separate pieces — while still appearing as one table to queries.

---

## When To Use It
When a table has grown so large that queries are slow even with proper indexes, maintenance operations (VACUUM, index rebuilds) take too long, or you need to efficiently drop old data. Partitioning works within a single database instance — it's a way to manage large tables, not a way to scale across machines. Use it before sharding. If the table has a natural time axis (logs, events, orders by date), range partitioning by date is almost always the right call.

---

## Core Concept
Instead of storing all rows in one massive table, the database splits rows across multiple physical partitions based on a partition key and strategy. From your application's perspective, you query the parent table normally — the database routes to the right partition automatically. The payoff: queries that filter on the partition key only scan the relevant partition, not the whole table (partition pruning). Old partitions can be dropped in milliseconds (no row-by-row DELETE). Index sizes per partition are smaller and fit more easily in memory. The downside: partition key choice is permanent and determines which queries benefit.

---

## The Code
```sql
-- ── Range partitioning by date (PostgreSQL) ───────────────────────────────
-- Common for logs, events, orders — any time-series data.

CREATE TABLE events (
    id          BIGSERIAL,
    user_id     BIGINT        NOT NULL,
    event_type  VARCHAR(50)   NOT NULL,
    created_at  TIMESTAMPTZ   NOT NULL,
    payload     JSONB
) PARTITION BY RANGE (created_at);

-- Create one partition per month
CREATE TABLE events_2026_01 PARTITION OF events
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE events_2026_02 PARTITION OF events
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE events_2026_03 PARTITION OF events
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

-- Index is created per partition — smaller, faster than one index on the full table
CREATE INDEX ON events_2026_01 (user_id, created_at);
CREATE INDEX ON events_2026_02 (user_id, created_at);
CREATE INDEX ON events_2026_03 (user_id, created_at);
```
```sql
-- ── Partition pruning in action ────────────────────────────────────────────
-- This query only scans events_2026_03 — not all partitions.
-- EXPLAIN shows "Partitions: events_2026_03"

EXPLAIN SELECT *
FROM events
WHERE created_at BETWEEN '2026-03-01' AND '2026-03-31'
  AND user_id = 42;

-- This query scans ALL partitions — no pruning — always slower.
-- Avoid queries that can't filter on the partition key.
EXPLAIN SELECT * FROM events WHERE event_type = 'click';
```
```sql
-- ── Hash partitioning — for uniform distribution without a time axis ───────

CREATE TABLE users (
    id       BIGSERIAL PRIMARY KEY,
    email    TEXT NOT NULL,
    username TEXT NOT NULL
) PARTITION BY HASH (id);

CREATE TABLE users_p0 PARTITION OF users FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE users_p1 PARTITION OF users FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE users_p2 PARTITION OF users FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE users_p3 PARTITION OF users FOR VALUES WITH (MODULUS 4, REMAINDER 3);

-- ── Dropping an old partition — O(1), no row scanning ────────────────────
-- This is the primary reason to range-partition time-series data.
DROP TABLE events_2024_01;
-- Compare to: DELETE FROM events WHERE created_at < '2024-02-01';
-- The DELETE locks rows, generates WAL, takes minutes. The DROP takes milliseconds.
```
```sql
-- ── Automating partition creation (pg_partman approach) ──────────────────
-- In production, use the pg_partman extension to auto-create and retire partitions.
-- Manual partition creation is error-prone and easy to forget.

-- SELECT partman.create_parent(
--     p_parent_table => 'public.events',
--     p_control      => 'created_at',
--     p_type         => 'native',
--     p_interval     => 'monthly',
--     p_premake      => 3              -- pre-create 3 future months
-- );
```

---

## Gotchas
- **Partition pruning only works when the query filter is on the partition key.** Queries that filter on any other column scan all partitions, which is often slower than a non-partitioned table with a good index. Partitioning is not a substitute for indexes.
- **Unique constraints must include the partition key.** In PostgreSQL, a unique constraint or primary key on a partitioned table must include the partition key column. A plain `UNIQUE(email)` on a hash-partitioned users table is a DDL error. This forces awkward primary key designs.
- **Partition key values cannot be updated.** Updating a row's `created_at` (the partition key) in most databases requires deleting and re-inserting the row in the correct partition. This is often not supported natively and must be handled in application code.
- **Default partitions accumulate unexpected data.** PostgreSQL allows a DEFAULT partition to catch rows that don't match any explicit partition. Without it, inserting a row with a date outside all defined ranges causes an error. With it, the default partition quietly accumulates data and queries against it scan the full default partition.
- **Foreign keys to and from partitioned tables have restrictions.** PostgreSQL (pre-16) doesn't support foreign keys that reference a partitioned table. Cross-partition referential integrity often has to be enforced at the application layer.

---

## Interview Angle
**What they're really testing:** Whether you understand the difference between partitioning (intra-database table management) and sharding (inter-database horizontal scaling) — and when each is appropriate.

**Common question form:** "How would you handle a table with 10 billion rows?" or "How do you design efficient data retention/TTL for a high-volume event stream?"

**The depth signal:** A junior candidate confuses partitioning with sharding or treats them as synonyms. A senior candidate cleanly separates them: "Partitioning is within one database instance — it's a table management strategy that helps with query performance and maintenance. Sharding is across multiple database instances — it's a write-scaling strategy. I'd reach for partitioning first — specifically range partitioning on `created_at` for event data — because it makes data retention trivial (drop old partitions in O(1)) and keeps partition indexes small enough to fit in memory. I'd only move to sharding if write throughput exceeded what one primary could handle after vertical scaling and partitioning." The separation is: juniors treat them as interchangeable, seniors know which problem each solves.

---

## Related Topics
- [[system-design/database-sharding.md]] — The next step when partitioning within one instance isn't enough.
- [[system-design/database-scaling.md]] — The full sequence: partitioning sits between indexing and sharding.
- [[databases/sql-indexing.md]] — Partitioning and indexing work together; good indexes on each partition are still required.

---

## Source
https://www.postgresql.org/docs/current/ddl-partitioning.html

---
*Last updated: 2026-03-24*