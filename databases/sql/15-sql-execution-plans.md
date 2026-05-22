# SQL Execution Plans

> An execution plan is the database's step-by-step description of how it will physically retrieve and process data to answer a query — the ground truth for performance diagnosis.

---

## Quick Reference

| | |
|---|---|
| **What it is** | The planner's chosen strategy for executing a query |
| **Use when** | Any query is slower than expected; before adding an index; after data changes |
| **Avoid when** | Guessing at performance — always read the plan first |
| **Standard** | Implementation-defined; PostgreSQL: `EXPLAIN`, `EXPLAIN ANALYZE`, `EXPLAIN (FORMAT JSON)` |
| **Key tool** | `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` — runs the query and shows real timings |
| **Key signal** | Large gap between estimated rows and actual rows = stale statistics |

---

## When To Use It

Read execution plans any time a query is slower than expected, before adding an index to verify it will be used, and after data or schema changes to confirm the planner hasn't switched to a worse strategy. The plan is the only reliable way to know what the database is actually doing — not what you assume it's doing. Don't guess at performance problems and add indexes blindly. Read the plan first.

---

## Core Concept

The query planner takes your SQL, considers available indexes, table statistics, and row count estimates, and produces the cheapest plan it can find. EXPLAIN shows you that plan without running the query. EXPLAIN ANALYZE actually executes it and shows real timings alongside estimates.

Every node in the plan is an operation — Seq Scan, Index Scan, Hash Join, Sort, Aggregate — and each one shows cost estimates and, with ANALYZE, actual timing and row counts. The plan is a tree: outer nodes feed into inner nodes. Execution starts at the deepest leaf nodes and flows upward.

The most important diagnostic skill is spotting the gap between estimated rows and actual rows. A large mismatch (estimated 5 rows, got 50,000) means the planner's statistics are stale or wrong — and a wrong estimate cascades into a wrong plan choice.

---

## Version History

| PostgreSQL Version | What changed |
|---|---|
| Pre-9.0 | Basic EXPLAIN and EXPLAIN ANALYZE |
| 9.0 | `EXPLAIN (FORMAT JSON/XML/YAML)` structured output |
| 9.1 | `BUFFERS` option added — shows cache hits vs disk reads |
| 9.2 | `TIMING` option; index-only scans appear in plans |
| 11 | Parallel query nodes appear in plans |
| 14 | `GENERIC_PLAN` option; incremental sort appears |
| 15 | `MEMORY` option shows memory usage per node |
| 16 | `auto_explain` improvements; better parallel plan display |

---

## Performance

| Plan node | When chosen | Cost profile |
|---|---|---|
| Seq Scan | Low selectivity, no usable index, small table | O(n) — reads all pages sequentially |
| Index Scan | High selectivity with matching index | O(log n + k) — random I/O to heap |
| Bitmap Index Scan + Heap Scan | Medium selectivity | Batches heap I/O — between seq and index scan |
| Index Only Scan | All needed cols in index (covering) | O(log n) — no heap access |
| Nested Loop | Small outer set, indexed inner | O(n log m) with index |
| Hash Join | Large unsorted sets | O(n + m) — builds hash in memory |
| Merge Join | Pre-sorted inputs | O(n log n + m log m) with sort |

**Reading cost notation:**
```
cost=0.43..18.50 rows=12 width=64
      ↑      ↑      ↑       ↑
 startup  total  est.   avg row
   cost   cost   rows   bytes

Startup cost: work done before first row returned (e.g. sort must complete)
Total cost:   work to return all rows
These are planner units — relative within one plan, not milliseconds
```

---

## The Code

**EXPLAIN — see the plan without running the query**
```sql
EXPLAIN
SELECT * FROM orders WHERE user_id = 42 AND status = 'completed';
-- Output:
-- Index Scan using idx_orders_user_status on orders  (cost=0.43..18.50 rows=12 width=64)
--   Index Cond: ((user_id = 42) AND (status = 'completed'))
```

**EXPLAIN ANALYZE — run the query and compare estimates to actuals**
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders WHERE user_id = 42 AND status = 'completed';

-- Output includes:
-- Rows Removed by Filter: 0
-- Actual Rows: 11     (estimated 12 — close, planner is well-calibrated)
-- Actual Time: 0.123..0.456 ms
-- Buffers: shared hit=8    → pages from memory cache
-- Buffers: shared read=2   → pages from disk (cache miss)
-- Planning Time: 0.8 ms
-- Execution Time: 0.6 ms
```

**Reading the critical signals**
```sql
-- SIGNAL 1: Seq Scan on a large table = no usable index
-- Seq Scan on orders  (cost=0.00..4821.00 rows=48210 width=64)
--   actual rows=48210 → reading the full table

-- SIGNAL 2: Large estimate vs actual gap = stale statistics
-- Index Scan using idx_orders on orders
--   (cost=0.43..8.50 rows=3 width=64)  ← estimated 3 rows
--   actual rows=48291                   ← got 48,291 — factor of 16,000 off
-- Fix: ANALYZE orders;

-- SIGNAL 3: Buffers: shared read = disk I/O (cold cache or large scan)
-- Buffers: shared hit=12, read=4500   ← 4500 pages from disk — cache miss

-- SIGNAL 4: Sort node with large cost = missing index for ORDER BY
-- Sort  (cost=1200.00..1250.00 rows=20000 width=64)
--   Sort Key: created_at DESC
--   Sort Method: external merge  Disk: 1024kB  ← spilled to disk
```

**Identify a missing index from the plan**
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_email = 'ahmed@example.com';

-- Seq Scan on orders  (cost=0.00..9821.00 rows=1 width=64)
--   actual time=0.012..87.432 rows=1 loops=1
--   Filter: (customer_email = 'ahmed@example.com')
--   Rows Removed by Filter: 982099

-- Reading 982,099 rows to return 1 — classic missing index
-- Fix:
CREATE INDEX CONCURRENTLY idx_orders_customer_email ON orders (customer_email);
```

**Bitmap Index Scan vs Index Scan vs Index Only Scan**
```sql
-- Index Scan: follows index one pointer at a time, random heap access
-- Used when: small result set (few rows, random access is acceptable)
EXPLAIN SELECT * FROM orders WHERE user_id = 42;
-- → Index Scan using idx_orders_user on orders ...

-- Bitmap Index Scan: builds a bitmap of matching pages, then reads heap in order
-- Used when: medium result set where batching heap I/O saves work
EXPLAIN SELECT * FROM orders WHERE created_at > NOW() - INTERVAL '7 days';
-- → Bitmap Heap Scan on orders
--     → Bitmap Index Scan on idx_orders_created

-- Index Only Scan: all needed columns are in the index — heap never touched
EXPLAIN SELECT user_id, status, created_at FROM orders WHERE user_id = 42;
-- (only if user_id, status, created_at are all in the index via INCLUDE)
-- → Index Only Scan using idx_orders_covering on orders
```

**Join strategy signals**
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT u.email, o.total_amount
FROM orders o
INNER JOIN users u ON u.id = o.user_id
WHERE o.status = 'completed';

-- Nested Loop  (cost=0.43..1200.00 rows=150 width=48)
--   → Index Scan on orders (outer)
--   → Index Scan on users by id (inner) — one lookup per order row
-- Good for small outer sets

-- Hash Join  (cost=1200.00..4800.00 rows=48000 width=48)
--   → Hash
--         → Seq Scan on users
--   → Seq Scan on orders
-- Good for large unsorted sets

-- Merge Join  (cost=2400.00..3600.00 rows=48000 width=48)
-- Good when both sides are already sorted on the join key
```

**Refresh stale statistics — the most common fix**
```sql
-- Symptom: estimated rows=5, actual rows=50000 in EXPLAIN ANALYZE
-- Root cause: autovacuum hasn't run since a large data change

ANALYZE orders;            -- update stats for one table (fast — takes a sample)
VACUUM ANALYZE orders;     -- reclaim dead rows AND update stats

-- Check when a table was last analyzed
SELECT
    relname,
    last_analyze,
    last_autoanalyze,
    n_live_tup,
    n_dead_tup,
    n_mod_since_analyze
FROM pg_stat_user_tables
WHERE relname = 'orders';
```

**Use auto_explain to log slow query plans automatically**
```sql
-- Add to postgresql.conf:
-- shared_preload_libraries = 'auto_explain'
-- auto_explain.log_min_duration = '1s'    -- log plans for queries > 1 second
-- auto_explain.log_analyze = true
-- auto_explain.log_buffers = true
-- auto_explain.log_format = 'json'        -- or 'text'

-- Or enable for a session only:
LOAD 'auto_explain';
SET auto_explain.log_min_duration = 0;   -- log all queries in this session
SET auto_explain.log_analyze = true;
```

**pg_stat_statements — find the slowest queries overall**
```sql
-- Enable: add 'pg_stat_statements' to shared_preload_libraries
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Top 10 queries by total execution time
SELECT
    LEFT(query, 80)                                 AS query,
    calls,
    ROUND(total_exec_time::NUMERIC, 2)              AS total_ms,
    ROUND(mean_exec_time::NUMERIC, 2)               AS avg_ms,
    ROUND(stddev_exec_time::NUMERIC, 2)             AS stddev_ms
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Queries with high variance — inconsistent performance (often plan flipping)
SELECT
    LEFT(query, 80)                                  AS query,
    calls,
    ROUND(mean_exec_time::NUMERIC, 2)                AS avg_ms,
    ROUND(stddev_exec_time / NULLIF(mean_exec_time, 0), 2) AS coeff_variation
FROM pg_stat_statements
WHERE calls > 100
ORDER BY coeff_variation DESC
LIMIT 10;
```

---

## Real World Example

A team reports that a product listing query that took 50ms last month now takes 8 seconds. No code changes were deployed. The table received 5 million new rows from a bulk import two weeks ago — but nobody ran ANALYZE afterward. The planner's statistics are still calibrated to the old row count.

```sql
-- Step 1: check what the planner thinks it's doing
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.id, p.name, p.price, c.name AS category
FROM products p
INNER JOIN categories c ON c.id = p.category_id
WHERE p.is_active = true
  AND p.price BETWEEN 10 AND 100
ORDER BY p.price ASC
LIMIT 50;

-- Observed output (bad):
-- Sort  (cost=52000.00..52050.00 rows=20000 width=80)
--   actual time=7842.123..7843.221 ms
--   Sort Method: external merge  Disk: 12288kB
--   → Nested Loop  (cost=0.00..48000.00 rows=20000)
--       estimated rows=20000, actual rows=3        ← massive overestimate
--       → Seq Scan on products (cost=0.00..42000.00 rows=20000)
--         Filter: (is_active = true AND price BETWEEN 10 AND 100)
--         Rows Removed by Filter: 4999997

-- Diagnosis: estimated 20,000 rows, actual 3 — stale statistics causing
-- the planner to choose Seq Scan + Sort instead of Index Scan
-- The sort spills to disk (12MB) because it expected 20,000 rows

-- Step 2: refresh statistics
ANALYZE products;
ANALYZE categories;

-- Step 3: re-run plan
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id, p.name, p.price, c.name AS category
FROM products p
INNER JOIN categories c ON c.id = p.category_id
WHERE p.is_active = true AND p.price BETWEEN 10 AND 100
ORDER BY p.price ASC LIMIT 50;

-- Fixed output:
-- Limit  (cost=0.56..18.92 rows=50 width=80)
--   actual time=0.234..0.891 ms    ← 8 seconds → under 1ms
--   → Index Scan using idx_products_price on products
--       estimated rows=3, actual rows=3  ← now correct
--       Index Cond: (price BETWEEN 10 AND 100)
--       Filter: (is_active = true)
```

*The key insight: the entire 8-second slowdown was caused by stale statistics making the planner overestimate rows by a factor of 6,600. The planner chose a sequential scan and a disk-spilling sort. After ANALYZE, it correctly chose an index scan that returns 3 rows and needs no sort. The fix took 30 seconds and changed nothing about the schema or indexes.*

---

## Common Misconceptions

**"EXPLAIN without ANALYZE shows actual performance"**
EXPLAIN without ANALYZE shows only the planner's estimates — cost numbers and row counts are guesses based on statistics. They can be wildly wrong. Always use `EXPLAIN ANALYZE` when diagnosing a real performance problem. The difference: `EXPLAIN` = the planner's prediction; `EXPLAIN ANALYZE` = what actually happened.

**"The node with the highest cost is always the problem"**
The most expensive-looking node isn't always the root cause. Look for the largest gap between estimated rows and actual rows — that's where the planner's model diverges from reality, and where cascading wrong decisions start. A Hash Join that expected 10 rows but got 10,000 may be the downstream symptom of a bad estimate at an earlier Seq Scan.

**"Adding an index will definitely make the query use it"**
The planner may still choose a Seq Scan if: the index has low selectivity, statistics are stale, or the query returns too many rows for index access to be cheaper than a sequential scan. Run EXPLAIN ANALYZE after adding an index to confirm it's being used. If it's not, read the plan to understand why.

---

## Gotchas

- **`EXPLAIN ANALYZE` actually runs the query** — for SELECT this is safe. For INSERT, UPDATE, or DELETE, it executes the mutation. Wrap destructive statements in a transaction and ROLLBACK: `BEGIN; EXPLAIN ANALYZE DELETE ...; ROLLBACK;`

- **Cost numbers are planner units, not milliseconds** — a cost of 10,000 on one server means nothing compared to 10,000 on another. What matters is the relative cost between nodes in the same plan, and the ratio of estimated to actual rows.

- **A large estimate vs actual mismatch is the primary diagnostic signal** — if estimated rows=5 and actual rows=50,000, the planner chose a strategy based on completely wrong assumptions. The fix is almost always `ANALYZE` to refresh statistics.

- **The planner may ignore a valid index** — low selectivity, stale statistics, or a function wrapping the indexed column all cause the planner to prefer a Seq Scan. Before adding another index, read the plan to understand why the existing one isn't being used.

- **`auto_explain` logs plans for queries that already completed slowly** — it's reactive, not preventive. For proactive monitoring, use `pg_stat_statements` to identify which queries are consuming the most total time, then run EXPLAIN ANALYZE on those specifically.

---

## Interview Angle

**What they're really testing:** Whether you can actually diagnose a slow query — not just describe what indexes are, but demonstrate a systematic process for finding and fixing the problem.

**Common question forms:**
- "How would you investigate a slow query in production?"
- "This query was fast last month and is slow now — what do you do?"
- "What does Seq Scan mean in an EXPLAIN output?"

**The depth signal:** A junior says "add an index" without looking at the plan first. A senior starts with `EXPLAIN ANALYZE`, reads actual vs estimated rows, checks Buffers for disk vs cache hits, and identifies whether the bottleneck is a missing index, a bad join strategy, or stale statistics. They run `ANALYZE` before concluding the planner is broken, know the difference between Index Scan, Bitmap Index Scan, and Index Only Scan, and understand that cost numbers are not milliseconds. Knowing `auto_explain` and `pg_stat_statements` for production-scale query discovery is a strong senior signal.

**Follow-up questions to expect:**
- "What's the difference between Index Scan and Index Only Scan?"
- "Why would the planner choose a Seq Scan even when an index exists?"

---

## Related Topics

- [[databases/sql/sql-indexing.md]] — execution plans are how you verify an index is actually being used
- [[databases/sql/sql-statistics.md]] — stale statistics cause the planner to choose wrong strategies
- [[databases/sql/sql-query-optimization.md]] — execution plans are the primary tool for the full optimization workflow
- [[databases/sql/sql-joins.md]] — join strategy (Nested Loop, Hash, Merge) is visible in the plan

---

## Source

https://www.postgresql.org/docs/current/using-explain.html

---
*Last updated: 2026-04-13*