# SQL Statistics

> Database statistics are metadata the query planner uses to estimate how many rows a query will return — driving every decision about which index to use, which join strategy to pick, and which plan costs less.

---

## When To Use It
Statistics matter any time the planner chooses a bad execution plan — wrong join order, skipping an index it should use, or choosing a sequential scan on a large table. The symptom is always the same: a large gap between estimated rows and actual rows in EXPLAIN ANALYZE. Statistics also degrade after bulk loads, large deletes, or any operation that changes the data distribution significantly. Understanding statistics is the prerequisite for diagnosing plan regressions — queries that were fast and then suddenly aren't, with no query or schema change.

---

## Core Concept
The planner never looks at raw table data when choosing a plan — it looks at statistics. PostgreSQL collects statistics per column: the number of distinct values, the most common values and their frequencies, a histogram of value distribution, and correlation between physical row order and column value order. These are stored in `pg_statistic` (raw) and `pg_stats` (human-readable). The autovacuum process refreshes statistics automatically when roughly 20% of a table's rows change. When statistics are stale or the data has an unusual distribution, the planner's row estimates go wrong — and a wrong estimate cascades into a wrong plan.

---

## The Code

**Read current statistics for a table's columns**
```sql
SELECT
    attname          AS column_name,
    n_distinct,      -- negative means fraction of total rows (e.g. -1 = all unique)
    most_common_vals,
    most_common_freqs,
    histogram_bounds,
    correlation      -- 1.0 = perfectly ordered, -1.0 = reverse, 0 = random
FROM pg_stats
WHERE tablename = 'orders'
ORDER BY attname;
```

**Check when a table was last analyzed**
```sql
SELECT
    relname                 AS table_name,
    last_analyze,
    last_autoanalyze,
    n_live_tup,             -- estimated live rows
    n_dead_tup,             -- dead rows waiting for vacuum
    n_mod_since_analyze     -- rows modified since last analyze
FROM pg_stat_user_tables
WHERE relname = 'orders';
```

**Manually refresh statistics**
```sql
-- Update statistics for one table (fast)
ANALYZE orders;

-- Update statistics for specific columns only
ANALYZE orders (user_id, status, created_at);

-- Update statistics for the entire database
ANALYZE;

-- Reclaim dead rows and update statistics together
VACUUM ANALYZE orders;
```

**Increase statistics target for a skewed column**
```sql
-- Default statistics target is 100 (samples ~300 most common values)
-- For high-cardinality or skewed columns, increase it

ALTER TABLE orders
ALTER COLUMN status SET STATISTICS 500;

-- Then re-analyze to collect at the new target
ANALYZE orders;

-- Verify the new target is reflected
SELECT attname, attstattarget
FROM pg_attribute
JOIN pg_class ON pg_class.oid = pg_attribute.attrelid
WHERE relname = 'orders' AND attname = 'status';
```

**Spot a stale statistics problem in EXPLAIN ANALYZE**
```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 42 AND status = 'completed';

-- Bad output (stale statistics):
-- Index Scan ... (cost=0.43..8.50 rows=3 width=64)
--               actual rows=48291 loops=1
-- Estimated 3 rows, got 48291 — planner had no idea

-- Fix:
ANALYZE orders;

-- Re-run plan — estimates should now be close to actuals
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 42 AND status = 'completed';
```

**Extended statistics — multi-column correlations**
```sql
-- PostgreSQL estimates multi-column conditions independently by default
-- This underestimates rows when columns are correlated

-- Example: country and city are correlated — most cities belong to one country
-- Without extended stats, planner multiplies their selectivities independently
-- and severely underestimates the result

CREATE STATISTICS orders_user_status_stats (dependencies)
ON user_id, status
FROM orders;

-- Collect the extended statistics
ANALYZE orders;

-- Now the planner accounts for correlation between user_id and status
-- Check what was collected:
SELECT * FROM pg_stats_ext WHERE statistics_name = 'orders_user_status_stats';
```

**Extended statistics types**
```sql
-- dependencies: detects functional dependency between columns
--   (e.g. zip code determines city)
CREATE STATISTICS zip_city_stats (dependencies) ON zip_code, city FROM addresses;

-- ndistinct: corrects distinct value estimates for column combinations
--   (e.g. (country, city) has fewer combinations than country * city)
CREATE STATISTICS country_city_stats (ndistinct) ON country, city FROM addresses;

-- mcv: most common value combinations across multiple columns
CREATE STATISTICS user_status_mcv (mcv) ON user_id, status FROM orders;

-- All three types at once:
CREATE STATISTICS full_stats (dependencies, ndistinct, mcv)
ON country, city, zip_code FROM addresses;
```

**Autovacuum statistics settings**
```sql
-- View current autovacuum thresholds for a table
SELECT
    relname,
    reloptions   -- per-table storage options including autovacuum settings
FROM pg_class
WHERE relname = 'orders';

-- Override autovacuum analyze threshold for a high-write table
-- Default: analyze after 20% of rows change (too infrequent for large tables)
ALTER TABLE orders SET (
    autovacuum_analyze_scale_factor = 0.01,  -- analyze after 1% change
    autovacuum_analyze_threshold = 1000       -- minimum 1000 rows changed
);
```

**Check statistics target per column**
```sql
SELECT
    attname,
    attstattarget   -- -1 means use default (100); 0 means disabled
FROM pg_attribute
JOIN pg_class ON pg_class.oid = pg_attribute.attrelid
WHERE relname = 'orders'
  AND attnum > 0
  AND NOT attisdropped
ORDER BY attname;
```

---

## Gotchas

- **Autovacuum uses a percentage threshold — it's too slow for large tables** — the default `autovacuum_analyze_scale_factor` is 0.2, meaning analyze runs after 20% of rows change. On a table with 100 million rows, that's 20 million changes before statistics refresh. Plans can degrade badly long before autovacuum kicks in. Lower the scale factor for large, frequently updated tables.
- **Statistics are per-column, not per-combination by default** — the planner estimates multi-column WHERE clauses by multiplying individual column selectivities, assuming independence. If columns are correlated (status and country, user_id and plan_type), estimates are wildly off. Extended statistics (`CREATE STATISTICS`) fix this but must be created explicitly — they don't exist by default.
- **High-cardinality columns with skewed distribution need a higher statistics target** — the default target of 100 collects at most ~300 most common values. For a column like `user_id` with millions of distinct values skewed toward a few heavy users, the planner's histogram is too coarse. Increase the target with `ALTER TABLE ... ALTER COLUMN ... SET STATISTICS 500` and re-analyze.
- **ANALYZE on a large table can be slow — but not as slow as a bad plan** — ANALYZE does a random sample of the table, not a full scan, so it's usually fast even on large tables. Don't avoid it because the table is big. The cost of a bad plan from stale statistics is almost always worse.
- **Statistics don't survive a table rebuild** — operations like `VACUUM FULL`, `CLUSTER`, or `ALTER TABLE` that rewrite the table reset statistics. Always run `ANALYZE` immediately after any table-rewriting operation, or the planner starts with no data about the new layout.

---

## Interview Angle
**What they're really testing:** Whether you understand that the query planner is a cost-based optimizer that depends on statistics — and whether you can trace a bad plan back to its statistical root cause.

**Common question form:** "A query that was fast last week is now slow and nothing changed in the code — how do you investigate?" or "The planner keeps choosing a sequential scan even though there's an index on that column — why?"

**The depth signal:** A junior knows ANALYZE exists and runs it when things are slow. A senior reads `pg_stats` to check actual column statistics, identifies the mismatch between estimated and actual rows in EXPLAIN ANALYZE as a statistics problem rather than an index problem, knows that multi-column correlations require extended statistics, lowers the autovacuum scale factor for large high-write tables rather than running ANALYZE manually on a cron, and understands that increasing the statistics target for a skewed column gives the planner a more accurate histogram. Knowing that statistics don't survive table rebuilds and that extended statistics must be explicitly created is a strong senior signal.

---

## Related Topics
- [[databases/sql-execution-plans.md]] — the estimated vs actual row count gap in EXPLAIN ANALYZE is the primary signal that statistics are stale
- [[databases/sql-indexing.md]] — the planner uses statistics to decide whether an index scan or seq scan is cheaper
- [[databases/sql-query-optimization.md]] — stale statistics are one of the four root causes of slow queries; ANALYZE is the first fix to try
- [[databases/sql-locking-blocking.md]] — VACUUM ANALYZE reclaims dead rows and refreshes statistics together; understanding bloat connects both topics

---

## Source
https://www.postgresql.org/docs/current/planner-stats.html

---
*Last updated: 2026-03-24*