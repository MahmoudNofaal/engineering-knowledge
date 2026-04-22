# SQL Statistics

> Database statistics are metadata the query planner uses to estimate how many rows a query will return — driving every decision about which index to use, which join strategy to pick, and which plan costs less.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Per-column metadata the planner uses for row count estimation |
| **Use when** | Diagnosing plan regressions; after bulk loads; on high-cardinality or skewed columns |
| **Avoid when** | Ignoring — stale statistics silently cause bad plans |
| **Standard** | Implementation-defined; PostgreSQL: `pg_stats`, `pg_statistic`, extended statistics |
| **Key commands** | `ANALYZE`, `VACUUM ANALYZE`, `CREATE STATISTICS` |
| **Symptom of stale stats** | Large gap between `rows=N` (estimate) and `actual rows=M` in EXPLAIN ANALYZE |

---

## When To Use It

Statistics matter any time the planner chooses a bad execution plan — wrong join order, skipping an index it should use, or choosing a sequential scan on a large table. The symptom is always the same: a large gap between estimated rows and actual rows in EXPLAIN ANALYZE. Statistics also degrade after bulk loads, large deletes, or any operation that significantly changes data distribution. Understanding statistics is the prerequisite for diagnosing plan regressions — queries that were fast and then suddenly aren't, with no query or schema change.

---

## Core Concept

The planner never looks at raw table data when choosing a plan — it looks at statistics. PostgreSQL collects per-column statistics: the number of distinct values, the most common values and their frequencies, a histogram of value distribution, and correlation between physical row order and column value. These live in `pg_statistic` (raw) and `pg_stats` (human-readable view). The autovacuum process refreshes statistics automatically when roughly 20% of a table's rows change. When statistics are stale or data has an unusual distribution, the planner's estimates go wrong — and a wrong estimate cascades into a wrong plan.

---

## Version History

| PostgreSQL Version | What changed |
|---|---|
| Pre-8.0 | Per-column statistics; configurable via default_statistics_target |
| 9.0 | Per-column statistics targets overrideable per column |
| 10 | Extended statistics (`CREATE STATISTICS`) — cross-column dependencies |
| 12 | Most common value (MCV) lists in extended statistics |
| 14 | Extended statistics for expressions |
| 15 | Better statistics for range types and partitioned tables |

---

## Performance

| Statistics operation | Cost | Notes |
|---|---|---|
| `ANALYZE table` | Fast — random sample | Does NOT read the full table; samples ~30,000 rows by default |
| `VACUUM ANALYZE` | Moderate — seq scan + sample | Reclaims dead rows AND refreshes statistics |
| `CREATE STATISTICS` | One-time cost | Collects extended stats; refreshed by subsequent ANALYZE |
| Autovacuum analyze | Background, low priority | May lag after bulk operations — run manually if needed |

**Autovacuum threshold:** By default, autovacuum triggers ANALYZE after 20% of rows change (`autovacuum_analyze_scale_factor = 0.2`). On a 100M-row table, that's 20M changes before statistics refresh. Plans can degrade badly long before autovacuum kicks in. Lower the scale factor for large, frequently-updated tables.

---

## The Code

**Read current statistics for a column**
```sql
SELECT
    attname              AS column_name,
    n_distinct,          -- negative = fraction of total rows (e.g. -1 = all unique)
    most_common_vals,
    most_common_freqs,
    histogram_bounds,
    correlation          -- 1.0 = perfectly correlated with physical order; 0 = random
FROM pg_stats
WHERE tablename = 'orders'
  AND attname   = 'status'
ORDER BY attname;
```

**Check when a table was last analyzed**
```sql
SELECT
    relname                  AS table_name,
    last_analyze,
    last_autoanalyze,
    n_live_tup,
    n_dead_tup,
    n_mod_since_analyze      -- rows modified since last analyze
FROM pg_stat_user_tables
WHERE relname = 'orders';
```

**Manually refresh statistics**
```sql
ANALYZE orders;                          -- one table, all columns
ANALYZE orders (user_id, status, created_at); -- specific columns only
ANALYZE;                                 -- entire database (slow — use carefully)
VACUUM ANALYZE orders;                   -- dead rows + statistics together
```

**Increase statistics target for a skewed or high-cardinality column**
```sql
-- Default target is 100 — samples up to 300 most common values
-- For high-cardinality or heavily skewed columns, increase it

ALTER TABLE orders
ALTER COLUMN status SET STATISTICS 500;

ANALYZE orders;  -- collect at the new target

-- Check the per-column target
SELECT attname, attstattarget
FROM pg_attribute
JOIN pg_class ON pg_class.oid = pg_attribute.attrelid
WHERE relname = 'orders'
  AND attnum > 0
  AND NOT attisdropped
ORDER BY attname;
```

**Spot stale statistics in EXPLAIN ANALYZE**
```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 42 AND status = 'completed';

-- BAD output (stale):
-- Index Scan (cost=0.43..8.50 rows=3 width=64)
--             actual rows=48291                ← estimated 3, got 48,291

-- Fix:
ANALYZE orders;

-- Re-run — estimates should now be close to actuals:
-- Index Scan (cost=0.43..250.00 rows=48000 width=64)
--             actual rows=48291                ← much closer
```

**Extended statistics — multi-column correlations**
```sql
-- By default, the planner estimates multi-column WHERE conditions independently
-- by multiplying individual selectivities — assuming columns are independent.
-- If columns are correlated (e.g. status and country), this underestimates rows.

-- Create extended statistics to let the planner account for correlation
CREATE STATISTICS orders_user_status_stats (dependencies)
ON user_id, status
FROM orders;

ANALYZE orders;   -- collect the extended statistics

-- Verify what was collected
SELECT * FROM pg_stats_ext
WHERE statistics_name = 'orders_user_status_stats';

-- Also available: ndistinct (corrects cardinality estimates for combinations)
CREATE STATISTICS country_city_stats (ndistinct) ON country, city FROM addresses;

-- MCV (most common value combinations) for column pairs
CREATE STATISTICS user_status_mcv (mcv) ON user_id, status FROM orders;

-- Collect all three types at once
CREATE STATISTICS full_ext_stats (dependencies, ndistinct, mcv)
ON country, city, zip_code FROM addresses;
```

**Expression statistics (PostgreSQL 14+)**
```sql
-- If a query frequently filters on an expression, stats can be collected on it
CREATE STATISTICS expr_stats ON (lower(email)) FROM users;
ANALYZE users;
-- Now the planner has statistics for lower(email) just like a regular column
```

**Tune autovacuum for large high-write tables**
```sql
-- Default: analyze after 20% of rows change — too infrequent for large tables
-- Override per-table:
ALTER TABLE orders SET (
    autovacuum_analyze_scale_factor = 0.01,  -- analyze after 1% change (not 20%)
    autovacuum_analyze_threshold    = 1000    -- minimum 1000 rows changed
);

-- Check current settings
SELECT relname, reloptions
FROM pg_class
WHERE relname = 'orders';
```

---

## Real World Example

A reporting query that grouped orders by `(user_id, status)` was using a full sequential scan despite indexes on both columns. EXPLAIN ANALYZE showed the planner estimated 12 rows but the query returned 95,000. The root cause: `user_id` and `status` are correlated — most users have only one or two statuses — but the planner assumed they were independent and multiplied their individual selectivities, producing a badly wrong row estimate that caused it to choose a seq scan over the index.

```sql
-- Step 1: observe the bad plan
EXPLAIN (ANALYZE, BUFFERS)
SELECT user_id, status, COUNT(*), SUM(total_amount)
FROM orders
WHERE user_id BETWEEN 1000 AND 1100
  AND status IN ('completed', 'refunded')
GROUP BY user_id, status;

-- Seq Scan on orders  (cost=0.00..45000 rows=12 width=32)
--   actual rows=95000  ← planners assumed independence, badly wrong

-- Step 2: look at per-column statistics
SELECT attname, n_distinct, most_common_vals, most_common_freqs
FROM pg_stats WHERE tablename = 'orders' AND attname IN ('user_id', 'status');
-- user_id: n_distinct=-0.02  (2% of rows have unique user IDs)
-- status:  most_common = ['completed':0.85, 'refunded':0.05, 'pending':0.10]

-- Step 3: the planner estimated selectivity as:
-- P(user_id in range) * P(status in list) = 0.02 * 0.90 = 0.018 → 12 rows
-- Reality: nearly all users in that range have completed/refunded orders

-- Step 4: create extended statistics to model the dependency
CREATE STATISTICS orders_user_status (dependencies, mcv)
ON user_id, status
FROM orders;

ANALYZE orders;

-- Step 5: re-run plan
EXPLAIN (ANALYZE, BUFFERS)
SELECT user_id, status, COUNT(*), SUM(total_amount)
FROM orders WHERE user_id BETWEEN 1000 AND 1100 AND status IN ('completed', 'refunded')
GROUP BY user_id, status;

-- Index Scan using idx_orders_user_status  ← planner now chooses the index
--   actual rows=95000, estimated rows=94000  ← much closer
-- Execution time: 420ms → 18ms
```

*The key insight: the problem wasn't a missing index or stale single-column statistics — it was missing cross-column statistics. The planner's independence assumption was wrong for these two correlated columns. Extended statistics taught the planner about the real joint distribution, fixing the estimate and the plan choice.*

---

## Common Misconceptions

**"ANALYZE reads the full table — it's expensive"**
ANALYZE takes a random sample of ~30,000 rows (controlled by `default_statistics_target`), not a full table scan. It's fast even on large tables. The 30-second query slowdown caused by stale statistics is almost always more expensive than the 2-second ANALYZE that would have prevented it. Don't avoid ANALYZE because the table is large.

**"Autovacuum keeps statistics up to date"**
Autovacuum's analyze trigger fires after 20% of rows change — which is 20 million rows on a 100M-row table. After a bulk load, large delete, or data backfill, statistics are immediately stale until autovacuum catches up. After any significant bulk data change, run `ANALYZE` manually. Don't wait for autovacuum.

**"Statistics are per-table"**
Statistics in PostgreSQL are per-column within a table. The planner has independent statistics for `user_id` and for `status`, but doesn't know about their joint distribution unless you create extended statistics. Multi-column queries can be estimated incorrectly even when single-column statistics are fresh and accurate.

---

## Gotchas

- **Autovacuum uses a percentage threshold — too slow for large tables** — the default `autovacuum_analyze_scale_factor` is 0.2 (20%). On a 100M-row table, that's 20M row changes before analyze runs. Lower the per-table threshold for large, frequently-modified tables.

- **Statistics are per-column by default — multi-column conditions need extended statistics** — the planner estimates `WHERE a = x AND b = y` by multiplying P(a=x) × P(b=y), assuming independence. If a and b are correlated, this is wrong. Create `CREATE STATISTICS` to fix multi-column estimates.

- **High-cardinality columns with skewed distribution need higher statistics targets** — the default target of 100 collects at most ~300 most common values. For a `user_id` column with millions of distinct values skewed toward a few heavy users, the histogram is too coarse. Increase per column with `ALTER TABLE ... ALTER COLUMN ... SET STATISTICS 500`.

- **Statistics don't survive a table rebuild** — `VACUUM FULL`, `CLUSTER`, or `ALTER TABLE` that rewrites the table resets statistics. Always run `ANALYZE` immediately after any table-rewriting operation.

- **Extended statistics must be explicitly created — they don't exist by default** — even if `user_id` and `status` are the two most commonly co-filtered columns in your application, PostgreSQL won't collect joint statistics unless you run `CREATE STATISTICS`. This is a manual, deliberate step.

---

## Interview Angle

**What they're really testing:** Whether you understand that the query planner is a cost-based optimizer that depends on statistics — and whether you can trace a bad plan back to its statistical root cause.

**Common question forms:**
- "A query that was fast last week is now slow and nothing changed in the code — how do you investigate?"
- "The planner keeps choosing a sequential scan even though there's an index — why?"
- "What are extended statistics and when would you use them?"

**The depth signal:** A junior knows ANALYZE exists and runs it when things are slow. A senior reads `pg_stats` to check actual column statistics, identifies the estimate vs actual row gap in EXPLAIN ANALYZE as a statistics problem (not necessarily an index problem), knows that multi-column correlations require extended statistics, lowers autovacuum scale factors for large high-write tables, and understands that increasing the statistics target for a skewed column gives the planner a more accurate histogram. Knowing that statistics don't survive table rebuilds and that extended statistics must be explicitly created is a strong senior signal.

**Follow-up questions to expect:**
- "What does `n_distinct = -0.5` mean in pg_stats?"
- "How does the planner estimate the selectivity of `WHERE status = 'active'`?"

---

## Related Topics

- [[databases/sql/sql-execution-plans.md]] — the estimated vs actual row count gap in EXPLAIN ANALYZE is the primary signal that statistics are stale
- [[databases/sql/sql-indexing.md]] — the planner uses statistics to decide whether an index scan or seq scan is cheaper
- [[databases/sql/sql-query-optimization.md]] — stale statistics are one of the four root causes of slow queries
- [[databases/sql/sql-locking-blocking.md]] — VACUUM ANALYZE reclaims dead rows and refreshes statistics; both topics connect here

---

## Source

https://www.postgresql.org/docs/current/planner-stats.html

---
*Last updated: 2026-04-13*