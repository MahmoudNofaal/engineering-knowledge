# SQL Aggregations

> Aggregation functions collapse multiple rows into a single computed value — counts, sums, averages, mins, and maxes.

---

## When To Use It
Use aggregations whenever you need a summary instead of raw rows — total revenue by month, average session duration per user, number of orders per country. They're the backbone of any reporting or analytics query. Avoid pushing this work into application code — looping over thousands of rows in memory to compute a sum is always slower than letting the database do it.

---

## Core Concept
Aggregation functions operate on a set of rows and return one value. The moment you use one, you've changed the shape of your result — instead of individual rows, you're getting groups. `GROUP BY` defines what those groups are. Every column in your `SELECT` that isn't inside an aggregate function must appear in the `GROUP BY` — otherwise the database doesn't know which value to pick for that column. `HAVING` is just `WHERE` but for the grouped result — it runs after aggregation, so it can filter on computed values like `COUNT(*)`.

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

**Aggregation with JOIN**
```sql
SELECT
    u.country,
    COUNT(DISTINCT o.id)    AS total_orders,   -- DISTINCT avoids double-counting
    SUM(o.total_amount)     AS revenue
FROM users u
INNER JOIN orders o ON o.user_id = u.id
WHERE o.status = 'completed'
GROUP BY u.country
ORDER BY revenue DESC;
```

**Conditional aggregation with FILTER / CASE**
```sql
-- Count completed vs cancelled orders in one pass
SELECT
    COUNT(*) FILTER (WHERE status = 'completed')  AS completed,
    COUNT(*) FILTER (WHERE status = 'cancelled')  AS cancelled,

    -- Equivalent CASE approach (works in MySQL too)
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_alt
FROM orders;
```

---

## Gotchas

- **`COUNT(column)` skips NULLs, `COUNT(*)` doesn't** — if you're counting records and some column is nullable, these two return different numbers with no error or warning. Use `COUNT(*)` for row counts, `COUNT(column)` only when you explicitly want to exclude NULLs.
- **Every non-aggregated SELECT column must be in GROUP BY** — PostgreSQL enforces this strictly and throws an error. MySQL (in some modes) silently picks an arbitrary value from the group, which is a subtle data correctness bug.
- **`WHERE` can't see aggregated values** — you can't write `WHERE COUNT(*) > 5`. That filter belongs in `HAVING`. The order of execution is: `FROM` → `JOIN` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `ORDER BY`.
- **`DISTINCT` inside aggregates changes the result significantly** — `COUNT(DISTINCT user_id)` counts unique users; `COUNT(user_id)` counts total rows. When joining before aggregating, a missing `DISTINCT` inflates counts silently whenever there are one-to-many relationships.
- **`AVG` on integers truncates in some databases** — in PostgreSQL, `AVG` on an integer column returns a numeric, which is fine. In older MySQL versions it may truncate. Cast explicitly (`AVG(column::numeric)`) when precision matters.

---

## Interview Angle
**What they're really testing:** Whether you understand the execution order of a SQL query and the distinction between row-level filtering and group-level filtering.

**Common question form:** "Find the top 5 customers by total spend" or "Which product categories had more than 1,000 sales last quarter?"

**The depth signal:** A junior writes `GROUP BY` and `HAVING` correctly but can't explain *why* `WHERE` can't filter on `COUNT(*)`. A senior knows the full execution order by heart, reaches for `COUNT(DISTINCT ...)` when joins are involved to avoid inflated counts, uses conditional aggregation (`FILTER` or `CASE WHEN`) to pivot row data into columns in a single pass, and knows that heavy aggregations on large tables are a sign you should look at materialized views or a summary table.

---

## Related Topics
- [[databases/sql-basics.md]] — WHERE, ORDER BY, and LIMIT that wrap around every aggregation query
- [[databases/sql-joins.md]] — joins before aggregation change row counts and require DISTINCT awareness
- [[databases/indexes.md]] — GROUP BY columns benefit from indexes; without them you get full scans on large tables
- [[databases/query-optimization.md]] — aggregations on large tables are a common source of slow queries; EXPLAIN shows you where

---

## Source
https://www.postgresql.org/docs/current/functions-aggregate.html

---
*Last updated: 2026-03-24*