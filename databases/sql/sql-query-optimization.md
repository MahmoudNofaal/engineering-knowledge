# SQL Query Optimization

> Query optimization is the process of making a slow SQL query faster — by understanding why it's slow, then applying the right fix.

---

## When To Use It
Optimize a query when it's measurably slow in production, when it's called frequently enough that its cost compounds, or when it blocks other operations through locks or resource contention. Don't optimize preemptively — write correct queries first, then profile. Premature optimization in SQL looks like adding indexes to every column, rewriting readable CTEs into unreadable subqueries, or denormalizing before you've confirmed the schema is actually the bottleneck.

---

## Core Concept
Most slow queries have one of four root causes: missing index (the planner reads more rows than necessary), bad row count estimate (the planner chose the wrong strategy because its statistics are stale), returning more data than needed (SELECT *, no LIMIT, wide rows), or structural inefficiency (correlated subqueries, functions on indexed columns, implicit type casts). The workflow is always the same: run EXPLAIN ANALYZE, find the most expensive node, understand why it's expensive, apply the smallest fix that addresses the root cause, and measure again. The plan is the ground truth — everything else is a guess.

---

## The Code

**The optimization workflow**
```sql
-- Step 1: time the query
\timing on
SELECT ...;

-- Step 2: read the plan
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT ...;

-- Step 3: refresh statistics if estimates are wildly off
ANALYZE table_name;

-- Step 4: apply fix (index, rewrite, schema change)
-- Step 5: re-run EXPLAIN ANALYZE and compare
```

**Fix 1 — Add a missing index**
```sql
-- Plan shows: Seq Scan, Rows Removed by Filter: 900000, returned: 12
-- Root cause: no index on the filter column

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

-- Fast: lateral join or window function — executes once
SELECT DISTINCT ON (u.id)
    u.id,
    u.email,
    o.created_at AS last_order
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
ORDER BY u.id, o.created_at DESC;

-- Or with a window function:
SELECT user_id, MAX(created_at) AS last_order
FROM orders
GROUP BY user_id;
-- Then join back to users if email is needed
```

**Fix 3 — Replace SELECT * with explicit columns**
```sql
-- Slow: fetches all columns including wide TEXT and JSONB fields
SELECT * FROM events WHERE user_id = 42;

-- Fast: fetch only what the caller needs
SELECT id, event_type, created_at
FROM events
WHERE user_id = 42;
-- Smaller rows = fewer pages read = faster query + lower memory pressure
```

**Fix 4 — Fix a function suppressing index use**
```sql
-- Slow: function on column prevents index use — forces Seq Scan
SELECT * FROM users WHERE lower(email) = 'ahmed@example.com';

-- Fix option A: expression index
CREATE INDEX idx_users_lower_email ON users (lower(email));

-- Fix option B: store email already lowercased at write time
-- Then query with plain equality — uses the existing btree index
```

**Fix 5 — Replace NOT IN with NOT EXISTS**
```sql
-- Slow and dangerous: NOT IN breaks silently with NULLs
SELECT id FROM users
WHERE id NOT IN (SELECT user_id FROM orders WHERE user_id IS NOT NULL);

-- Fast and correct: NOT EXISTS short-circuits on first match
SELECT u.id FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.user_id = u.id
);
```

**Fix 6 — Push filters before joins with CTEs or subqueries**
```sql
-- Slow: joins full tables, then filters
SELECT u.email, o.total_amount
FROM users u
INNER JOIN orders o ON o.user_id = u.id
WHERE o.status = 'completed'
  AND o.created_at > NOW() - INTERVAL '30 days'
  AND u.country = 'EG';

-- Fast: filter early, join smaller sets
WITH recent_orders AS (
    SELECT user_id, total_amount
    FROM orders
    WHERE status = 'completed'
      AND created_at > NOW() - INTERVAL '30 days'
),
egyptian_users AS (
    SELECT id, email
    FROM users
    WHERE country = 'EG'
)
SELECT eu.email, ro.total_amount
FROM recent_orders ro
INNER JOIN egyptian_users eu ON eu.id = ro.user_id;
```

**Fix 7 — Use LIMIT to short-circuit large result sets**
```sql
-- If you only need the top result, tell the planner
SELECT id, total_amount
FROM orders
WHERE user_id = 42
ORDER BY created_at DESC
LIMIT 1;
-- Planner uses an index scan and stops after one row
-- Without LIMIT it reads and sorts all matching rows
```

**Fix 8 — Refresh stale statistics**
```sql
-- Symptom: estimated rows=5, actual rows=50000 in EXPLAIN ANALYZE
-- Root cause: statistics not updated after bulk insert or delete

ANALYZE orders;          -- update stats for one table, fast
VACUUM ANALYZE orders;   -- reclaim dead rows and update stats

-- Check when a table was last analyzed:
SELECT relname, last_analyze, last_autoanalyze, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'orders';
```

**Fix 9 — Materialized view for repeated expensive aggregations**
```sql
-- Slow: heavy aggregation query hit dozens of times per minute
SELECT country, COUNT(*) AS users, SUM(spend) AS revenue
FROM user_spend_summary
GROUP BY country;

-- Fix: materialize it and refresh on a schedule
CREATE MATERIALIZED VIEW country_stats AS
SELECT country, COUNT(*) AS users, SUM(spend) AS revenue
FROM user_spend_summary
GROUP BY country;

CREATE UNIQUE INDEX ON country_stats (country);

-- Refresh every hour via pg_cron or external scheduler
REFRESH MATERIALIZED VIEW CONCURRENTLY country_stats;
```

---

## Gotchas

- **Fixing the wrong node wastes time** — EXPLAIN ANALYZE shows the full tree. The slowest node isn't always the last one or the most obvious one. Look for the node with the highest actual time and the largest rows estimate vs actual gap — that's where the problem is. Adding an index to a fast node does nothing.
- **ANALYZE before concluding the planner is wrong** — a bad plan that looks like a planner bug is almost always stale statistics. Run ANALYZE on the table, re-run the plan, and check whether estimates improved before touching anything else.
- **Rewriting for performance at the cost of readability is often the wrong trade** — a correlated subquery that runs in 20ms on a table with 10,000 rows is not a problem. Rewriting it saves nothing and costs maintainability. Measure first — optimize only when the cost is proven.
- **Index improvements have diminishing returns past a point** — adding a composite index with five columns to cover one query while hurting INSERT performance on a write-heavy table is a net loss. Always weigh read gain against write cost.
- **Connection pool exhaustion and lock contention look like slow queries** — if EXPLAIN ANALYZE shows the query itself is fast but wall-clock time is high, the problem isn't the query. It's waiting for a connection, waiting on a lock held by another transaction, or I/O saturation. Query optimization won't fix infrastructure problems.

---

## Interview Angle
**What they're really testing:** Whether you have a systematic process for diagnosing slow queries — not whether you've memorized a list of tips.

**Common question form:** "Walk me through how you would debug a slow query in production" or "This query was fast last month and is slow now — what do you do?"

**The depth signal:** A junior says "add an index" or "avoid SELECT *" without any diagnostic process. A senior starts with EXPLAIN ANALYZE, reads actual vs estimated rows, checks Buffers for disk vs cache hits, and narrows to a root cause before touching anything. They know the four common root causes (missing index, stale stats, too much data returned, structural inefficiency), reach for ANALYZE before concluding the planner is broken, and understand that connection pool exhaustion and lock contention produce symptoms that look like slow queries but aren't. They also know that the most readable fix is usually preferred over the most clever one — maintainability is part of the optimization.

---

## Related Topics
- [[databases/sql-execution-plans.md]] — reading EXPLAIN ANALYZE output is the prerequisite skill for all optimization work
- [[databases/sql-indexing.md]] — most query optimizations involve adding, modifying, or removing indexes
- [[databases/sql-views.md]] — materialized views are the fix for repeated expensive aggregations
- [[databases/sql-transactions.md]] — long transactions cause lock contention and table bloat that surface as slow queries

---

## Source
https://www.postgresql.org/docs/current/performance-tips.html

---
*Last updated: 2026-03-24*