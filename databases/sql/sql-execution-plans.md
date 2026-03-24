# SQL Execution Plans

> An execution plan is the database's step-by-step description of how it will physically retrieve and process data to answer a query.

---

## When To Use It
Read execution plans any time a query is slower than expected, before adding an index to verify it will actually be used, and after schema or data changes to confirm the planner hasn't switched to a worse strategy. They're the only reliable way to know what the database is actually doing — not what you assume it's doing. Don't guess at performance problems and add indexes blindly; read the plan first.

---

## Core Concept
The query planner takes your SQL, considers available indexes, table statistics, and row count estimates, and produces the cheapest plan it can find. EXPLAIN shows you that plan without running the query. EXPLAIN ANALYZE actually runs it and shows real timings alongside estimates. Every node in the plan is an operation — Seq Scan, Index Scan, Hash Join, Sort, Aggregate — and each one has a cost estimate and, with ANALYZE, actual timing and row counts. The most important skill is spotting the gap between estimated rows and actual rows — a large mismatch means the planner's statistics are stale or wrong, and it's likely chosen a suboptimal plan as a result.

---

## The Code

**Basic EXPLAIN — see the plan without running the query**
```sql
EXPLAIN
SELECT * FROM orders WHERE user_id = 42 AND status = 'completed';

-- Output:
-- Index Scan using idx_orders_user_id on orders  (cost=0.43..18.50 rows=12 width=64)
--   Index Cond: (user_id = 42)
--   Filter: (status = 'completed')
```

**EXPLAIN ANALYZE — run the query and compare estimates to actuals**
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders WHERE user_id = 42 AND status = 'completed';

-- Output includes:
-- Actual Rows: 11    (estimated: 12  — close, planner is well-calibrated)
-- Actual Time: 0.123..0.456 ms
-- Buffers: shared hit=8     → pages served from cache
-- Buffers: shared read=2    → pages read from disk
```

**Reading cost notation**
```sql
-- cost=0.43..18.50 rows=12 width=64
--       ↑      ↑      ↑       ↑
--  startup  total   est.   avg row
--    cost   cost    rows   size (bytes)

-- Startup cost: work done before first row is returned (e.g. sorting)
-- Total cost:   work to return all rows
-- Lower is better — but costs are relative estimates, not milliseconds
```

**Seq Scan — no index used, full table read**
```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE status = 'completed';

-- Seq Scan on orders  (cost=0.00..4821.00 rows=48210 width=64)
--                      actual time=0.012..38.421 rows=48210 loops=1
-- No index on status — planner reads every row
-- If this is slow and selectivity is high, add an index on status
```

**Index Scan vs Bitmap Index Scan**
```sql
-- Index Scan: follows index one row at a time, fetches heap pages per row
-- Best for small result sets — random access is fast when few rows returned

-- Bitmap Index Scan: builds a bitmap of matching pages, then fetches in order
-- Best for medium result sets — batches heap access to reduce random I/O

EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 42;
-- Small result → Index Scan

EXPLAIN ANALYZE
SELECT * FROM orders WHERE created_at > NOW() - INTERVAL '30 days';
-- Larger result → Bitmap Index Scan → Bitmap Heap Scan
```

**Hash Join vs Nested Loop vs Merge Join**
```sql
EXPLAIN ANALYZE
SELECT u.email, o.total_amount
FROM orders o
INNER JOIN users u ON u.id = o.user_id
WHERE o.status = 'completed';

-- Nested Loop: for each outer row, probe inner — good for small outer sets
-- Hash Join: hash the smaller table, probe with the larger — good for big sets
-- Merge Join: sort both sides, merge — good when both sides are pre-sorted

-- Hash Join  (cost=1200.00..4800.00 rows=48000 width=48)
--   ->  Seq Scan on orders  (rows=48000)
--   ->  Hash
--         ->  Seq Scan on users  (rows=12000)
```

**Spotting estimate vs actual row count mismatch**
```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 42 AND created_at > '2024-01-01';

-- Rows Removed by Filter: 0
-- Planning Time: 0.8 ms
-- Execution Time: 142.3 ms

-- If estimated rows=5 but actual rows=50000 — the planner underestimated
-- This usually means stale statistics — run ANALYZE to refresh them
ANALYZE orders;
-- Or for the whole database:
ANALYZE;
```

**Forcing ANALYZE to update statistics**
```sql
-- Statistics are used by the planner to estimate row counts
-- After bulk inserts or deletes, statistics can be stale

ANALYZE orders;                    -- update stats for one table
VACUUM ANALYZE orders;             -- reclaim dead rows AND update stats
```

**Identifying a missing index from the plan**
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_email = 'ahmed@example.com';

-- Seq Scan on orders  (cost=0.00..9821.00 rows=1 width=64)
--   actual time=0.012..87.432 rows=1 loops=1
--   Filter: (customer_email = 'ahmed@example.com')
--   Rows Removed by Filter: 982099

-- Reading 982099 rows to return 1 — a classic missing index signal
-- Fix:
CREATE INDEX CONCURRENTLY idx_orders_customer_email ON orders (customer_email);
```

---

## Gotchas

- **EXPLAIN without ANALYZE shows estimates only** — costs and row counts in a plain EXPLAIN are the planner's guesses based on statistics. They can be wildly wrong. Always use EXPLAIN ANALYZE when diagnosing a real performance problem — otherwise you're debugging a model, not the actual execution.
- **EXPLAIN ANALYZE actually runs the query** — for SELECT this is safe. For INSERT, UPDATE, or DELETE, it executes the mutation. Wrap destructive statements in a transaction and roll back if you only want the plan: `BEGIN; EXPLAIN ANALYZE DELETE ...; ROLLBACK;`
- **Cost numbers are not milliseconds** — costs are arbitrary planner units used for comparison between plans. A cost of 10000 on one server means nothing on another. What matters is relative cost between nodes in the same plan, and the gap between estimated and actual rows.
- **A large estimate vs actual mismatch is the most important signal** — if the planner estimated 5 rows and got 50,000, it probably chose the wrong join strategy or skipped an index. The fix is usually `ANALYZE` to refresh statistics, or creating a more specific index. The planner can't make good decisions with bad statistics.
- **The planner may ignore your index even when it exists** — low selectivity, stale statistics, or a function wrapping the column all cause the planner to prefer a Seq Scan. Before adding another index, read the plan to understand why the existing one isn't being used.

---

## Interview Angle
**What they're really testing:** Whether you can actually diagnose a slow query — not just describe what indexes are, but demonstrate a systematic process for finding and fixing the problem.

**Common question form:** "How would you investigate a slow query?" or "This query was fast last week and is slow now — how do you debug it?"

**The depth signal:** A junior says "add an index" without looking at the plan first. A senior starts with EXPLAIN ANALYZE, reads the actual vs estimated row counts, checks Buffers for disk vs cache hits, identifies whether the bottleneck is a missing index, a bad join strategy, or stale statistics, and runs ANALYZE before concluding the planner has bad data. They know the difference between Index Scan and Bitmap Index Scan and when each appears, understand that EXPLAIN without ANALYZE is estimates only, and know to wrap destructive EXPLAIN ANALYZE calls in a transaction. They treat the execution plan as the ground truth — not their assumptions about what the planner should do.

---

## Related Topics
- [[databases/sql-indexing.md]] — execution plans are how you verify an index is actually being used
- [[databases/sql-joins.md]] — join strategy (Nested Loop, Hash Join, Merge Join) is visible in the plan and directly tied to table sizes
- [[databases/sql-aggregations.md]] — aggregations show up as HashAggregate or GroupAggregate nodes; plans reveal which was chosen
- [[databases/query-optimization.md]] — execution plans are the primary tool for the full optimization workflow

---

## Source
https://www.postgresql.org/docs/current/using-explain.html

---
*Last updated: 2026-03-24*