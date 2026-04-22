# SQL Query Optimization

> Query optimization is the process of making a slow SQL query faster — by understanding why it's slow, applying the right fix, and measuring the result.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Systematic process for diagnosing and fixing slow queries |
| **Use when** | A query is measurably slow in production or under load |
| **Avoid when** | Optimizing preemptively without evidence — write correct queries first |
| **Standard** | N/A — implementation-specific; this covers PostgreSQL |
| **Workflow** | Profile → EXPLAIN ANALYZE → identify root cause → fix → measure again |
| **Four root causes** | Missing index · Stale statistics · Too much data returned · Structural inefficiency |

---

## When To Use It

Optimize a query when it's measurably slow in production, when it's called frequently enough that its cost compounds, or when it blocks other operations through locks or resource contention. Don't optimize preemptively — write correct queries first, then profile. Premature optimization in SQL looks like adding indexes to every column, rewriting readable CTEs into unreadable subqueries, or denormalizing before you've confirmed the schema is actually the bottleneck.

---

## Core Concept

Most slow queries trace back to one of four root causes: missing index (the planner reads more rows than necessary), stale statistics (the planner chose the wrong strategy because its estimates were wrong), returning more data than needed (SELECT *, no LIMIT, wide rows), or structural inefficiency (correlated subqueries, functions on indexed columns, implicit type casts). The workflow is always: run EXPLAIN ANALYZE, find the most expensive node with the largest estimate-vs-actual gap, understand why it's expensive, apply the smallest fix that addresses the root cause, and measure again. The plan is the ground truth — everything else is a guess.

---

## Version History

| PostgreSQL Version | What changed |
|---|---|
| 9.4 | `FILTER` clause on aggregates; better expression pushdown |
| 9.6 | Parallel query execution (parallel seq scans) |
| 10 | Parallel index scans; hash joins can run in parallel |
| 11 | Parallel btree index builds; partition pruning at execution time |
| 12 | CTE inlining by default; improved partition-wise joins |
| 14 | Incremental sort; improved planner for complex queries |
| 15 | Better parallel query; improved statistics for extended statistics |

---

## Performance (Root Causes)

| Root cause | Symptom in plan | Fix |
|---|---|---|
| Missing index | Seq Scan + Rows Removed: N | CREATE INDEX CONCURRENTLY |
| Stale statistics | Estimated rows ≪ actual rows | ANALYZE table |
| Too much data | Wide rows, no LIMIT, SELECT * | Explicit columns, LIMIT, covering index |
| Correlated subquery | Nested loop, high "loops" count | Rewrite as JOIN or CTE |
| Function on column | Seq Scan despite index existing | Expression index or rewrite condition |
| Sort spill | "Sort Method: external merge Disk: NMB" | Index on ORDER BY column, or increase work_mem |

---

## The Code

**The optimization workflow**
```sql
-- Step 1: time the query
\timing on
SELECT ...;

-- Step 2: read the plan with full detail
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT ...;

-- Step 3: if estimate vs actual gap is large, refresh statistics
ANALYZE table_name;

-- Step 4: apply fix (index, rewrite, schema change)
-- Step 5: re-run EXPLAIN ANALYZE and compare
```

**Fix 1 — Add a missing index**
```sql
-- Plan shows: Seq Scan, Rows Removed by Filter: 900000, returned 12
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 42 AND status = 'pending';
-- Seq Scan on orders ... rows removed by filter: 982000

-- Fix:
CREATE INDEX CONCURRENTLY idx_orders_customer_status
ON orders (customer_id, status);

-- Verify:
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 42 AND status = 'pending';
-- Index Scan using idx_orders_customer_status ... actual rows=12
```

**Fix 2 — Rewrite a correlated subquery as a JOIN**
```sql
-- Slow: correlated subquery re-executes once per outer row
SELECT u.id, u.email,
    (SELECT MAX(created_at) FROM orders o WHERE o.user_id = u.id) AS last_order
FROM users u;

-- Fast: aggregate once, join once
SELECT u.id, u.email, agg.last_order
FROM users u
LEFT JOIN (
    SELECT user_id, MAX(created_at) AS last_order
    FROM orders
    GROUP BY user_id
) agg ON agg.user_id = u.id;
```

**Fix 3 — Replace SELECT \* with explicit columns**
```sql
-- Slow: fetches all columns including wide TEXT and JSONB fields
SELECT * FROM events WHERE user_id = 42;

-- Fast: fetch only what's needed + enables index-only scan
SELECT id, event_type, created_at
FROM events
WHERE user_id = 42;
-- Smaller rows = fewer pages read = faster + lower memory pressure
```

**Fix 4 — Fix a function suppressing index use**
```sql
-- Slow: function on column prevents index use
SELECT * FROM users WHERE lower(email) = 'ahmed@example.com';

-- Fix A: expression index matches the function
CREATE INDEX idx_users_lower_email ON users (lower(email));

-- Fix B: normalise storage — store email already lowercased at write time
-- Then query with plain equality — uses standard B-tree index
```

**Fix 5 — Replace NOT IN with NOT EXISTS**
```sql
-- Dangerous: NOT IN breaks silently if subquery contains any NULL
SELECT id FROM users
WHERE id NOT IN (SELECT user_id FROM orders WHERE user_id IS NOT NULL);

-- Fast and correct: NOT EXISTS short-circuits on first match
SELECT u.id FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.user_id = u.id
);
```

**Fix 6 — Push filters before joins with CTEs**
```sql
-- Slow: joins full tables, then filters
SELECT u.email, o.total_amount
FROM users u
INNER JOIN orders o ON o.user_id = u.id
WHERE o.status = 'completed'
  AND o.created_at > NOW() - INTERVAL '30 days'
  AND u.country = 'EG';

-- Often better: pre-filter in CTEs (especially when inlining is disabled)
WITH recent_orders AS MATERIALIZED (
    SELECT user_id, total_amount
    FROM orders
    WHERE status = 'completed'
      AND created_at > NOW() - INTERVAL '30 days'
),
egyptian_users AS MATERIALIZED (
    SELECT id, email FROM users WHERE country = 'EG'
)
SELECT eu.email, ro.total_amount
FROM recent_orders ro
INNER JOIN egyptian_users eu ON eu.id = ro.user_id;
```

**Fix 7 — Use LIMIT to short-circuit**
```sql
-- Without LIMIT: reads and sorts all matching rows
SELECT id, total_amount
FROM orders
WHERE user_id = 42
ORDER BY created_at DESC;

-- With LIMIT: index scan stops after N rows
SELECT id, total_amount
FROM orders
WHERE user_id = 42
ORDER BY created_at DESC
LIMIT 1;
-- Planner uses index, stops after one row — dramatically faster
```

**Fix 8 — Refresh stale statistics**
```sql
-- Symptom: estimated rows=5, actual rows=50000
ANALYZE orders;             -- update stats for one table (fast — random sample)
VACUUM ANALYZE orders;      -- reclaim dead rows and update stats

-- Check when last analyzed
SELECT relname, last_analyze, last_autoanalyze, n_mod_since_analyze
FROM pg_stat_user_tables
WHERE relname = 'orders';
```

**Fix 9 — Materialized view for repeated expensive aggregations**
```sql
-- Slow: heavy aggregation query hit many times per minute
SELECT country, COUNT(*) AS users, SUM(spend) AS revenue
FROM user_spend_summary
GROUP BY country;

-- Fix: materialize and refresh on a schedule
CREATE MATERIALIZED VIEW country_stats AS
SELECT country, COUNT(*) AS users, SUM(spend) AS revenue
FROM user_spend_summary
GROUP BY country;

CREATE UNIQUE INDEX ON country_stats (country);
-- Refresh via scheduler
REFRESH MATERIALIZED VIEW CONCURRENTLY country_stats;
```

**Fix 10 — Increase work_mem for sort/hash operations**
```sql
-- Symptom in plan: "Sort Method: external merge  Disk: 12288kB"
-- Root cause: sort spilled to disk because it exceeded work_mem

-- Per-session increase (don't set globally without careful thought)
SET work_mem = '256MB';

-- Then re-run the query — if sort now fits in memory:
-- "Sort Method: quicksort  Memory: 128kB"
-- The sort is now 10-100× faster
```

---

## Real World Example

A SaaS analytics endpoint was returning in 4 seconds under load. The query joined three tables, filtered by date range and account_id, and returned paginated results. Standard suspects (missing index, SELECT *) were already addressed. The real problem turned out to be a combination of two issues: an implicit type cast suppressing index use, and the sort column not covered by the index.

```sql
-- Original slow query (4 seconds):
SELECT
    e.id, e.event_type, e.properties, e.occurred_at,
    u.email
FROM events e
INNER JOIN users u ON u.id = e.user_id
WHERE e.account_id = :account_id      -- account_id is BIGINT in events table
  AND e.occurred_at >= :start         -- :start is passed as TEXT from app layer
  AND e.occurred_at  < :end
ORDER BY e.occurred_at DESC
LIMIT 50 OFFSET :page * 50;

-- EXPLAIN ANALYZE reveals:
-- Seq Scan on events (cost=0.00..95000.00 rows=82000)
--   Filter: ((account_id = '42'::text::bigint) AND ...)  ← implicit cast on account_id
-- Sort  (cost=45000.00..45200.00 rows=82000)
--   Sort Method: external merge  Disk: 45056kB           ← spilling to disk

-- Diagnosis:
-- 1. account_id parameter passed as text, not bigint — implicit cast prevents index use
-- 2. Sort on occurred_at not covered by any index with account_id
-- 3. OFFSET pagination reading and discarding many rows

-- Fix 1: cast parameter explicitly in application layer (or use parameterized queries)
-- Fix 2: create composite index matching the filter + sort pattern
CREATE INDEX CONCURRENTLY idx_events_account_occurred
ON events (account_id, occurred_at DESC);

-- Fix 3: replace OFFSET with cursor-based pagination
-- (pass last seen occurred_at instead of a page number)
SELECT
    e.id, e.event_type, e.properties, e.occurred_at, u.email
FROM events e
INNER JOIN users u ON u.id = e.user_id
WHERE e.account_id = :account_id::BIGINT     -- explicit cast
  AND e.occurred_at >= :start::TIMESTAMPTZ   -- explicit cast
  AND e.occurred_at  < :end::TIMESTAMPTZ
  AND e.occurred_at < :last_seen_at          -- cursor: last value from previous page
ORDER BY e.occurred_at DESC
LIMIT 50;

-- After fixes: 4 seconds → 18ms
-- Plan: Index Scan using idx_events_account_occurred
-- Sort: never happens — index provides pre-sorted order
```

*The key insight: three separate issues combined to produce the slowdown. The implicit type cast was the most subtle — it looked correct and worked, but silently prevented index use. The cursor-based pagination replaced `OFFSET N` which re-scanned the entire preceding result set on every page request. Each fix had to be applied and verified independently.*

---

## Common Misconceptions

**"Optimization means adding indexes"**
Adding an index is the fix for one root cause (missing index). The other three root causes (stale statistics, too much data returned, structural inefficiency) aren't fixed by indexes. Always diagnose before fixing. Running ANALYZE costs almost nothing and fixes stale statistics in seconds — it should be the first thing you try.

**"Rewriting for performance at the cost of readability is always worth it"**
A correlated subquery that runs in 20ms on a table with 10,000 rows is not a problem. Rewriting it as a JOIN saves nothing and costs maintainability. Measure first. Optimize only when the cost is proven and the query runs often enough to matter.

**"Connection pool exhaustion is a slow query problem"**
If EXPLAIN ANALYZE shows the query itself is fast but wall-clock time is high, the problem isn't the query. It's waiting for a connection, waiting on a lock held by another transaction, or I/O saturation at the host level. Query optimization won't fix infrastructure problems — profile the right layer.

---

## Gotchas

- **Fixing the wrong node wastes time** — EXPLAIN ANALYZE shows the full tree. The slowest node isn't always the last one or the most obvious one. Look for the node with the largest actual time AND the largest estimate-vs-actual row gap. That's where the planner's model diverged.

- **ANALYZE before concluding the planner is broken** — a bad plan that looks like a planner bug is almost always stale statistics. Run ANALYZE on the table, re-run the plan, and check whether estimates improved before touching anything else.

- **Implicit type casts suppress index use silently** — passing a BIGINT column value as TEXT, or a TIMESTAMPTZ column value as TIMESTAMP, can force a cast that prevents index use. Always use explicitly typed parameters in application queries.

- **OFFSET pagination reads all preceding rows** — `OFFSET 900 LIMIT 50` reads 950 rows and discards 900. For deep pagination, use cursor-based pagination (WHERE id > :last_seen_id or equivalent). OFFSET is fine for the first few pages; it becomes a performance trap beyond page 10-20 on large tables.

- **work_mem setting applies per operation, not per query** — a query with multiple sort or hash operations can use `work_mem` multiple times. Setting it very high globally can cause memory exhaustion under concurrent load. Set it per session for specific heavy queries, not as a global default.

---

## Interview Angle

**What they're really testing:** Whether you have a systematic process for diagnosing slow queries — not whether you've memorised a list of tips.

**Common question forms:**
- "Walk me through how you would debug a slow query in production"
- "This query was fast last month and is slow now — what do you do?"
- "Why is this query slow even though there's an index on that column?"

**The depth signal:** A junior says "add an index" or "avoid SELECT *" without any diagnostic process. A senior starts with EXPLAIN ANALYZE, reads actual vs estimated rows, checks Buffers for disk vs cache hits, and narrows to a root cause before touching anything. They know the four common root causes, reach for ANALYZE before concluding the planner is broken, and understand that connection pool exhaustion and lock contention look like slow queries but aren't. They also know that the most readable fix is usually preferred over the most clever one — maintainability is part of optimization.

**Follow-up questions to expect:**
- "You've tried everything and the query is still slow — what next?"
- "How do you find the slowest queries in a production system you just inherited?"

---

## Related Topics

- [[databases/sql/sql-execution-plans.md]] — reading EXPLAIN ANALYZE is the prerequisite for all optimization work
- [[databases/sql/sql-indexing.md]] — most optimizations involve adding, modifying, or restructuring indexes
- [[databases/sql/sql-statistics.md]] — stale statistics are one of the four root causes; ANALYZE is the first fix
- [[databases/sql/sql-views.md]] — materialized views are the fix for repeated expensive aggregations
- [[databases/sql/sql-locking-blocking.md]] — long transactions cause lock contention that surfaces as slow queries

---

## Source

https://www.postgresql.org/docs/current/performance-tips.html

---
*Last updated: 2026-04-13*