# SQL Aggregations

> Aggregation functions collapse multiple rows into a single computed value — counts, sums, averages, mins, maxes, and more complex statistical summaries.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Row-collapsing summary functions |
| **Use when** | You need a summary rather than raw rows |
| **Avoid when** | Logic belongs in window functions (you need both row and summary) |
| **Standard** | SQL-92 (basic); SQL:2003 (advanced statistical); SQL:2016 (JSON agg) |
| **Key functions** | `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `STRING_AGG`, `ARRAY_AGG`, `JSONB_AGG` |
| **Key clauses** | `GROUP BY`, `HAVING`, `FILTER`, `DISTINCT` inside aggregates |

---

## When To Use It

Use aggregations whenever you need a summary instead of raw rows — total revenue by month, average session duration per user, number of orders per country. They're the backbone of any reporting or analytics query. Avoid pushing this work into application code — looping over thousands of rows in memory to compute a sum is always slower than letting the database do it. Switch to window functions when you need both the aggregated value *and* the individual rows in the same result — aggregations collapse rows, window functions don't.

---

## Core Concept

Aggregation functions operate on a set of rows and return one value per group. The moment you use one, you've changed the shape of your result. `GROUP BY` defines what those groups are — every unique combination of GROUP BY columns becomes one output row. Every column in your SELECT that isn't inside an aggregate function must appear in the GROUP BY — otherwise the database doesn't know which value to pick for that column (PostgreSQL enforces this strictly; MySQL in some modes silently picks an arbitrary value, which is a bug not a feature).

`HAVING` is the filter for groups. It runs after GROUP BY and can use aggregate results. `WHERE` runs before GROUP BY and can't. The full execution order: FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY.

---

## Version History

| Standard / Version | What changed |
|---|---|
| SQL-92 | COUNT, SUM, AVG, MIN, MAX standardized |
| SQL:1999 | GROUPING SETS, ROLLUP, CUBE introduced |
| SQL:2003 | Statistical aggregates: STDDEV, VARIANCE, CORR, REGR_* |
| PostgreSQL 9.4 | `FILTER (WHERE ...)` clause on aggregates |
| PostgreSQL 9.5 | JSONB_AGG, JSONB_OBJECT_AGG |
| PostgreSQL 14 | `DISTINCT` in more aggregate contexts |
| MySQL 8.0 | GROUP BY behaviour changed — removed non-standard implicit grouping |

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Hash aggregation | O(n) | Default for GROUP BY; builds hash table of groups |
| Sort aggregation | O(n log n) | Used when input is already sorted or sort is needed anyway |
| COUNT(*) on small table | O(1) in some DBs | MySQL MyISAM keeps a counter; PostgreSQL must count (MVCC) |
| STRING_AGG / ARRAY_AGG | O(n) | Builds string/array in memory; large groups cause memory pressure |
| DISTINCT inside aggregate | O(n log n) | Sorts the set before aggregating; more expensive than plain aggregate |

**Allocation behaviour:** Hash aggregation builds the hash table in `work_mem`. If the distinct group count exceeds what fits, PostgreSQL spills to disk — a significant slowdown on very high cardinality GROUP BY columns. For analytics queries on huge tables, materialized views or pre-aggregated summary tables are the right architecture.

**Benchmark notes:** `COUNT(*)` in PostgreSQL is not O(1) — it scans the table due to MVCC. For approximate counts on very large tables, `pg_class.reltuples` or the `hyperloglog` extension is faster. On tables under ~1M rows, this distinction rarely matters.

---

## The Code

**Basic aggregate functions**
```sql
SELECT
    COUNT(*)            AS total_orders,
    COUNT(shipped_at)   AS shipped_orders,   -- NULLs not counted
    SUM(total_amount)   AS revenue,
    AVG(total_amount)   AS avg_order_value,
    MIN(total_amount)   AS smallest_order,
    MAX(total_amount)   AS largest_order
FROM orders
WHERE status = 'completed';
```

**GROUP BY — one result row per group**
```sql
SELECT
    country,
    COUNT(*)        AS total_users,
    AVG(age)        AS avg_age
FROM users
WHERE is_active = true
GROUP BY country
ORDER BY total_users DESC;
```

**HAVING — filter on aggregated values**
```sql
-- Only countries with more than 500 active users
SELECT
    country,
    COUNT(*) AS total_users
FROM users
WHERE is_active = true
GROUP BY country
HAVING COUNT(*) > 500
ORDER BY total_users DESC;
```

**GROUP BY multiple columns**
```sql
SELECT
    country,
    plan_type,
    COUNT(*)            AS users,
    SUM(monthly_spend)  AS mrr
FROM subscriptions
GROUP BY country, plan_type
ORDER BY country, mrr DESC;
```

**Aggregation with JOIN — DISTINCT prevents double-counting**
```sql
SELECT
    u.country,
    COUNT(DISTINCT o.id)    AS total_orders,   -- without DISTINCT, one-to-many join inflates this
    SUM(o.total_amount)     AS revenue
FROM users u
INNER JOIN orders o ON o.user_id = u.id
WHERE o.status = 'completed'
GROUP BY u.country
ORDER BY revenue DESC;
```

**Conditional aggregation with FILTER (PostgreSQL)**
```sql
-- Count and sum split by status in a single pass — no subqueries
SELECT
    COUNT(*) FILTER (WHERE status = 'completed')   AS completed_count,
    COUNT(*) FILTER (WHERE status = 'cancelled')   AS cancelled_count,
    SUM(total_amount) FILTER (WHERE status = 'completed') AS completed_revenue
FROM orders;
```

**Conditional aggregation with CASE (works everywhere)**
```sql
SELECT
    SUM(CASE WHEN status = 'completed' THEN total_amount ELSE 0 END) AS completed_revenue,
    SUM(CASE WHEN status = 'refunded'  THEN total_amount ELSE 0 END) AS refunded_revenue,
    COUNT(CASE WHEN status = 'completed' THEN 1 END)                 AS completed_count
FROM orders;
```

**STRING_AGG — collect values into a delimited string**
```sql
-- Comma-separated list of product names per order
SELECT
    order_id,
    STRING_AGG(product_name, ', ' ORDER BY product_name) AS products
FROM order_items oi
INNER JOIN products p ON p.id = oi.product_id
GROUP BY order_id;
```

**ARRAY_AGG — collect values into an array (PostgreSQL)**
```sql
-- Array of tag IDs per article
SELECT
    article_id,
    ARRAY_AGG(tag_id ORDER BY tag_id) AS tag_ids
FROM article_tags
GROUP BY article_id;
```

**GROUPING SETS, ROLLUP, CUBE — multi-level aggregations**
```sql
-- ROLLUP: subtotals + grand total in one query
SELECT
    country,
    city,
    SUM(revenue) AS total
FROM sales
GROUP BY ROLLUP(country, city);
-- Returns: (country, city) rows + (country, NULL) subtotals + (NULL, NULL) grand total

-- GROUPING SETS: explicit combinations — same as UNION ALL of GROUP BYs
SELECT
    country,
    plan_type,
    SUM(mrr)
FROM subscriptions
GROUP BY GROUPING SETS (
    (country, plan_type),  -- full detail
    (country),             -- by country only
    ()                     -- grand total
);
```

---

## Real World Example

A subscription analytics service needs a single query for its monthly executive report: for each plan tier, show subscriber count, total MRR, average tenure, churn count this month, and revenue at risk — all in one pass, no application-side post-processing.

```sql
SELECT
    p.tier,
    COUNT(s.id)                                                   AS active_subscribers,
    SUM(p.monthly_price)                                          AS mrr,
    ROUND(AVG(EXTRACT(DAY FROM NOW() - s.started_at) / 30.0), 1) AS avg_tenure_months,

    -- Churn this month via conditional aggregation
    COUNT(*) FILTER (
        WHERE s.cancelled_at >= DATE_TRUNC('month', NOW())
          AND s.cancelled_at  < DATE_TRUNC('month', NOW()) + INTERVAL '1 month'
    )                                                             AS churned_this_month,

    -- Revenue at risk: sum MRR for subs unpaid > 14 days
    COALESCE(
        SUM(p.monthly_price) FILTER (
            WHERE s.payment_status = 'overdue'
              AND s.payment_due_at < NOW() - INTERVAL '14 days'
        ), 0
    )                                                             AS revenue_at_risk

FROM subscriptions s
INNER JOIN plans p ON p.id = s.plan_id
WHERE s.status IN ('active', 'past_due')
GROUP BY p.tier
ORDER BY mrr DESC;
```

*The key insight: conditional aggregation with FILTER replaces five separate subqueries. One pass over the subscriptions table, five computed columns. The COALESCE around the revenue_at_risk handles the case where no overdue subscriptions exist in that tier — without it, the column would be NULL rather than 0.*

---

## Common Misconceptions

**"GROUP BY and ORDER BY columns must match"**
They're completely independent. GROUP BY defines the groups. ORDER BY sorts the output. You can GROUP BY country and ORDER BY total_revenue DESC — these are different columns with different purposes.

**"AVG is always safe for numeric columns"**
AVG silently excludes NULLs from both the numerator and denominator. If 3 out of 10 rows have NULL for `age`, AVG computes across the 7 non-NULL rows — which may or may not be what you want. When NULLs should count as 0, use `AVG(COALESCE(age, 0))` explicitly.

```sql
-- 7 rows with values, 3 NULLs
-- AVG(score) = sum of 7 values / 7   (NULLs excluded)
-- AVG(COALESCE(score, 0)) = sum of 7 values / 10  (NULLs counted as 0)
-- These are different numbers — know which one you want
```

**"COUNT(\*) and COUNT(1) are different"**
They're identical in every major database. Both count rows. `COUNT(*)` is the SQL standard. `COUNT(1)` is a historical holdover from times when some engines optimised it differently. They produce the same result and the same query plan. Use `COUNT(*)`.

---

## Gotchas

- **`COUNT(column)` skips NULLs, `COUNT(*)` doesn't** — if you're counting records and some column is nullable, these return different numbers with no error. Use `COUNT(*)` for row counts, `COUNT(column)` only when you explicitly want to exclude NULLs.

- **Every non-aggregated SELECT column must be in GROUP BY** — PostgreSQL enforces this strictly and throws an error. MySQL in some modes silently picks an arbitrary value from the group — a silent correctness bug that produces different results on each execution.

- **`WHERE` can't see aggregated values** — you can't write `WHERE COUNT(*) > 5`. That filter belongs in `HAVING`. Execution order: FROM → WHERE → GROUP BY → HAVING.

- **`DISTINCT` inside aggregates is expensive** — `COUNT(DISTINCT user_id)` sorts or hashes the set before counting. On large tables, it's significantly slower than `COUNT(user_id)`. When approximate counts are acceptable, `pg_hll` (HyperLogLog) is orders of magnitude faster.

- **`STRING_AGG` / `ARRAY_AGG` on large groups exhaust memory** — aggregating 100,000 values into one string will use significant memory and produce an enormous result. Add a `LIMIT` inside via a subquery, or reconsider whether you really need the full list.

---

## Interview Angle

**What they're really testing:** Whether you understand the execution order of a SQL query and the distinction between row-level filtering and group-level filtering.

**Common question forms:**
- "Find the top 5 customers by total spend"
- "Which product categories had more than 1,000 sales last quarter?"
- "Why can't I use WHERE to filter on COUNT(\*)?"

**The depth signal:** A junior writes GROUP BY and HAVING correctly but can't explain *why* WHERE can't filter on COUNT(*). A senior knows the full execution order by heart, reaches for `COUNT(DISTINCT ...)` when joins are involved to avoid inflated counts, uses conditional aggregation (FILTER or CASE WHEN) to pivot row data into columns in a single pass, and knows that heavy aggregations on large tables are a sign you should look at materialized views or summary tables. Knowing the difference between ROLLUP, CUBE, and GROUPING SETS is a strong senior signal.

**Follow-up questions to expect:**
- "How would you calculate a running total? What about a 7-day moving average?"
- "This GROUP BY on 500M rows is slow — how do you approach fixing it?"

---

## Related Topics

- [[databases/sql/sql-basics.md]] — WHERE, ORDER BY, and LIMIT that wrap around every aggregation query
- [[databases/sql/sql-joins.md]] — joins before aggregation change row counts and require DISTINCT awareness
- [[databases/sql/sql-window-functions.md]] — when you need both the aggregate value and the individual rows simultaneously
- [[databases/sql/sql-null-handling.md]] — AVG, COUNT, and SUM all have specific NULL behaviours that affect results
- [[databases/sql/sql-query-optimization.md]] — aggregations on large tables are a common source of slow queries

---

## Source

https://www.postgresql.org/docs/current/functions-aggregate.html

---
*Last updated: 2026-04-13*