# SQL Partitioning

> Table partitioning splits a single logical table into multiple physical pieces (partitions) — enabling the planner to skip entire partitions that don't match a query's filter conditions.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Physical splitting of a table into smaller pieces by a partition key |
| **Use when** | Tables > ~50-100M rows; time-series data; need to drop old data quickly |
| **Avoid when** | Tables that are small or queried across all partitions equally |
| **Standard** | SQL:2003 (conceptual); PostgreSQL: declarative partitioning since PG 10 |
| **Partition types** | `RANGE` (dates, IDs) · `LIST` (fixed values) · `HASH` (even distribution) |
| **Key win** | Partition pruning: planner skips irrelevant partitions entirely |

---

## When To Use It

Partition large tables (50M+ rows) where queries almost always filter by a specific column — typically a date or timestamp for time-series data, a region/country for geo-distributed data, or a tenant ID for multi-tenant applications. The payoff is partition pruning: when a query filters on the partition key, the planner skips every partition that can't contain matching rows — turning a 500M-row scan into a 10M-row scan. Also use partitioning when you need to efficiently drop old data: `DROP TABLE partition_2023` is instantaneous and doesn't generate dead rows; `DELETE FROM table WHERE year = 2023` locks rows and requires VACUUM.

Avoid partitioning when queries span all partitions equally (no pruning benefit), when the table is small (overhead outweighs gains), or when foreign key references to the partitioned table are critical (limited FK support across partitions).

---

## Core Concept

PostgreSQL's declarative partitioning (PG 10+) creates a parent table that holds no data — it's a logical container. Each partition is a real table that inherits the parent's structure. When you INSERT into the parent, PostgreSQL routes the row to the correct partition. When you SELECT from the parent, the planner uses partition pruning to skip irrelevant child tables.

Three partition strategies: RANGE divides rows based on a column value range (dates, numeric IDs). LIST assigns rows to specific partitions based on exact column values (country codes, status values). HASH distributes rows evenly across N partitions based on a hash of the partition key — useful when there's no natural range or list key but you want even distribution.

Partition pruning works at two levels: planning time (known constants) and execution time (bind parameters in PostgreSQL 11+). Both must be enabled for full benefit.

---

## Version History

| PostgreSQL Version | What changed |
|---|---|
| Pre-10 | Table inheritance only — manual triggers required; no first-class partitioning |
| 10 | Declarative partitioning introduced (`PARTITION BY RANGE/LIST`) |
| 11 | Hash partitioning; partition pruning at execution time (bind parameters) |
| 12 | `ATTACH/DETACH PARTITION`; improved partition-wise joins |
| 13 | Logical replication of partitioned tables |
| 14 | Partition-wise joins by default; `DETACH PARTITION ... CONCURRENTLY` |
| 15 | `MERGE` works with partitioned tables |

---

## Performance

| Scenario | Without partitioning | With partitioning |
|---|---|---|
| Query with date filter (last month) | Full 500M-row scan | 10M-row scan (only current partition) |
| Drop old year's data | `DELETE` + VACUUM (hours) | `DROP TABLE` on partition (instant) |
| Bulk load of current month | Regular insert | Insert to current partition only (faster vacuum) |
| Query across all time periods | Full scan | Full scan (no benefit; all partitions scanned) |
| Index on partitioned table | One large index | One index per partition (smaller, faster) |

**Partition pruning prerequisite:** the WHERE clause must filter on the partition key column. `WHERE created_at >= '2024-01-01'` prunes by range. `WHERE DATE_TRUNC('year', created_at) = '2024-01-01'` wraps the column in a function — pruning may not work. Always filter directly on the partition key column without wrapping functions.

---

## The Code

**RANGE partitioning — by date (most common)**
```sql
-- Create partitioned parent table (holds no data itself)
CREATE TABLE events (
    id          BIGINT GENERATED ALWAYS AS IDENTITY,
    user_id     INT NOT NULL,
    event_type  TEXT NOT NULL,
    payload     JSONB,
    occurred_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (id, occurred_at)   -- partition key must be in PK
) PARTITION BY RANGE (occurred_at);

-- Create partitions (one per month is common for event data)
CREATE TABLE events_2024_01
PARTITION OF events
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE events_2024_02
PARTITION OF events
FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Create a default partition to catch rows outside defined ranges
CREATE TABLE events_default
PARTITION OF events DEFAULT;

-- Insert routes to the correct partition automatically
INSERT INTO events (user_id, event_type, occurred_at)
VALUES (42, 'login', '2024-01-15 10:00:00');
-- Goes to events_2024_01

-- Query from parent — planner prunes irrelevant partitions
SELECT COUNT(*) FROM events
WHERE occurred_at >= '2024-01-01'
  AND occurred_at  < '2024-02-01';
-- Only scans events_2024_01 — all other partitions pruned
```

**LIST partitioning — by discrete values**
```sql
-- Partition by region (known set of values)
CREATE TABLE orders (
    id          BIGINT GENERATED ALWAYS AS IDENTITY,
    region      TEXT NOT NULL,
    customer_id INT NOT NULL,
    total       NUMERIC NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, region)
) PARTITION BY LIST (region);

CREATE TABLE orders_us PARTITION OF orders FOR VALUES IN ('US', 'CA');
CREATE TABLE orders_eu PARTITION OF orders FOR VALUES IN ('GB', 'DE', 'FR', 'NL');
CREATE TABLE orders_apac PARTITION OF orders FOR VALUES IN ('AU', 'JP', 'SG');
CREATE TABLE orders_other PARTITION OF orders DEFAULT;
```

**HASH partitioning — even distribution**
```sql
-- Partition by tenant_id hash when no natural range/list key
CREATE TABLE audit_logs (
    id          BIGINT GENERATED ALWAYS AS IDENTITY,
    tenant_id   INT NOT NULL,
    action      TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, tenant_id)
) PARTITION BY HASH (tenant_id);

-- 4 partitions — each gets ~25% of tenants
CREATE TABLE audit_logs_0 PARTITION OF audit_logs FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE audit_logs_1 PARTITION OF audit_logs FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE audit_logs_2 PARTITION OF audit_logs FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE audit_logs_3 PARTITION OF audit_logs FOR VALUES WITH (MODULUS 4, REMAINDER 3);
```

**Automate partition creation**
```sql
-- Create next month's partition — run as a scheduled job
CREATE OR REPLACE PROCEDURE create_next_month_partition(table_name TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start DATE := DATE_TRUNC('month', NOW() + INTERVAL '1 month');
    v_end   DATE := v_start + INTERVAL '1 month';
    v_partition_name TEXT := table_name || '_' || TO_CHAR(v_start, 'YYYY_MM');
BEGIN
    EXECUTE FORMAT(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
        v_partition_name, table_name, v_start, v_end
    );
    RAISE NOTICE 'Created partition: %', v_partition_name;
END;
$$;

-- Run monthly via pg_cron or external scheduler
CALL create_next_month_partition('events');
```

**Drop old partitions — instant data deletion**
```sql
-- DROP TABLE on a partition is instantaneous — no DELETE + VACUUM needed
DROP TABLE IF EXISTS events_2022_01;

-- Or DETACH first (keeps the data, removes from partitioned table)
-- DETACH CONCURRENTLY (PG 14+) doesn't block reads/writes
ALTER TABLE events DETACH PARTITION events_2022_01 CONCURRENTLY;
-- Now events_2022_01 is a standalone table — archive, dump, then drop
DROP TABLE events_2022_01;
```

**Indexes on partitioned tables**
```sql
-- Index on parent automatically creates matching indexes on all partitions
CREATE INDEX idx_events_user_occurred
ON events (user_id, occurred_at DESC);
-- Creates idx_events_2024_01_user_occurred, idx_events_2024_02_user_occurred, etc.

-- Unique indexes must include the partition key
CREATE UNIQUE INDEX ON events (id, occurred_at);  -- occurred_at is the partition key
-- Cannot enforce uniqueness across partitions without including the partition key
```

**Verify partition pruning is working**
```sql
-- Check that the planner prunes irrelevant partitions
EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT COUNT(*)
FROM events
WHERE occurred_at >= '2024-01-01'
  AND occurred_at  < '2024-02-01';

-- Good: only scans one partition
-- Seq Scan on events_2024_01 (actual rows=...)
-- Partitions excluded: 23   ← 23 partitions skipped

-- Bad: no pruning (likely function wrapping the column)
-- Append
--   Seq Scan on events_2024_01
--   Seq Scan on events_2024_02
--   ...  (all partitions scanned)
```

---

## Real World Example

A telemetry platform collects 200M events per day. After a year the events table has 70 billion rows. Queries for the current month take 45 minutes even with indexes. The team needs to: speed up recent-data queries, expire data older than 18 months, and enable efficient archival of monthly snapshots.

```sql
-- Convert the existing events table to a partitioned table
-- Step 1: create partitioned version
CREATE TABLE events_partitioned (
    id          BIGINT,
    user_id     INT NOT NULL,
    event_type  TEXT NOT NULL,
    payload     JSONB,
    occurred_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

-- Step 2: create partitions for all existing data months
-- (automated via the stored procedure above — run for each past month)

-- Step 3: migrate data in batches (no downtime needed — source table still live)
INSERT INTO events_partitioned
SELECT * FROM events
WHERE occurred_at >= '2024-01-01' AND occurred_at < '2024-02-01';
-- repeat for each month...

-- Step 4: create indexes on partitioned table
CREATE INDEX idx_ep_user_occurred ON events_partitioned (user_id, occurred_at DESC);

-- Step 5: swap atomically with a brief lock
BEGIN;
ALTER TABLE events RENAME TO events_old;
ALTER TABLE events_partitioned RENAME TO events;
COMMIT;

-- After migration: query performance
EXPLAIN ANALYZE
SELECT user_id, COUNT(*), SUM(payload->>'bytes')::BIGINT
FROM events
WHERE occurred_at >= NOW() - INTERVAL '30 days'
GROUP BY user_id
ORDER BY 2 DESC LIMIT 100;
-- Before: 45 minutes (70B row scan)
-- After:  8 seconds (only current month partition, ~6B rows)

-- Monthly maintenance: drop oldest partition, create next month's
DROP TABLE IF EXISTS events_2022_01;  -- instant — no VACUUM needed
CALL create_next_month_partition('events');
```

*The key insight: partition pruning cuts the scan from 70 billion rows to ~6 billion — a 12× reduction — with no query changes. Dropping old partitions is instantaneous vs running a DELETE that would take hours and generate massive WAL. The migration to a partitioned schema can be done online by renaming tables atomically.*

---

## Common Misconceptions

**"Partitioning always speeds up queries"**
Partitioning only helps queries that filter on the partition key. A query like `SELECT COUNT(*) FROM events GROUP BY user_id` (no date filter) scans all partitions. A query like `SELECT COUNT(*) FROM events WHERE occurred_at > NOW() - INTERVAL '7 days'` prunes all older partitions. If most of your queries don't filter by the partition key, partitioning adds overhead (cross-partition planning cost) without benefit.

**"Unique constraints work normally on partitioned tables"**
PostgreSQL can only enforce uniqueness within a single partition, not across the whole table — unless the unique index includes the partition key. This is a major constraint: a global unique index on `email` is impossible on a table partitioned by `created_at`. Design your unique constraints before committing to a partition strategy.

**"Partitioning replaces indexing"**
Partitioning and indexing solve different problems. Partitioning eliminates entire partitions from consideration (coarse-grained elimination). Indexes find specific rows within a partition (fine-grained lookup). Both are needed: partition pruning narrows the scan to the relevant partition, the index finds the right rows within it.

---

## Gotchas

- **The partition key column must be in every unique index and primary key** — PostgreSQL can't enforce cross-partition uniqueness. If you want a PRIMARY KEY on just `id`, you must partition by `id` or include the partition key in the PK. This often requires including `occurred_at` or `tenant_id` in the PK — which changes application assumptions.

- **Foreign keys pointing TO a partitioned table are restricted** — you can create a FK from another table to the partitioned table's PK, but only if the FK includes the partition key. This significantly limits relational integrity between partitioned tables and their dependants.

- **Functions on partition key column prevent pruning** — `WHERE DATE_TRUNC('month', occurred_at) = '2024-01-01'` wraps `occurred_at` in a function, preventing partition pruning. Always filter directly: `WHERE occurred_at >= '2024-01-01' AND occurred_at < '2024-02-01'`.

- **Missing a partition for a date range causes INSERT to fail (or go to DEFAULT)** — if no partition covers the incoming row's partition key value and there's no DEFAULT partition, the INSERT raises an error. Always maintain a DEFAULT partition or automate partition creation ahead of time.

- **Partition pruning requires statistics on the parent table** — run `ANALYZE events` (the parent) to keep planner statistics current. Statistics on individual partitions are also collected, but parent-level statistics drive partition pruning decisions.

---

## Interview Angle

**What they're really testing:** Whether you understand when partitioning helps, what partition pruning requires, and the constraints that make partitioning a non-trivial design decision.

**Common question forms:**
- "How would you design a database for 1 billion rows of time-series data?"
- "How does partition pruning work?"
- "What are the tradeoffs of partitioning?"

**The depth signal:** A junior says "use partitioning for large tables." A senior explains that pruning only works when queries filter on the partition key without wrapping functions, knows that unique indexes must include the partition key, understands that dropping a partition is instantaneous while DELETE requires VACUUM, and flags the FK constraint limitation. They also know that partition-wise joins and aggregates (PG 14+) let two partitioned tables be joined partition by partition — a further performance multiplier for partition-aligned queries.

**Follow-up questions to expect:**
- "How would you migrate an existing 100M-row table to a partitioned table with zero downtime?"
- "Why can't you have a global unique index on a partitioned table?"

---

## Related Topics

- [[databases/sql/sql-indexing.md]] — indexes are created per-partition; partition key must be in unique indexes
- [[databases/sql/sql-query-optimization.md]] — partition pruning is visible in EXPLAIN as "Partitions excluded"
- [[databases/sql/sql-execution-plans.md]] — the Append node in execution plans shows which partitions were scanned
- [[databases/sql/sql-tempdb.md]] — temp tables and unlogged tables for intermediate ETL work on large partitioned datasets

---

## Source

https://www.postgresql.org/docs/current/ddl-partitioning.html

---
*Last updated: 2026-04-13*