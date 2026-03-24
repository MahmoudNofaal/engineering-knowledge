# SQL Window Functions

> Window functions perform calculations across a set of rows related to the current row — without collapsing those rows into a single result the way GROUP BY does.

---

## When To Use It
Use window functions when you need both the detail row and a computed value across a group at the same time — running totals, rankings within a category, comparing each row to the group average, or fetching the previous/next row's value. They replace the pattern of joining a subquery back to the original table just to get an aggregated column alongside raw data. Avoid them when a simple GROUP BY gives you what you need — window functions are more powerful but also more expensive.

---

## Core Concept
Every window function has an OVER clause — that's what makes it a window function instead of a regular aggregate. The OVER clause defines the "window": which rows the function looks at when computing its result for each row. PARTITION BY splits rows into groups (like GROUP BY, but without collapsing them). ORDER BY inside OVER defines the sequence within each partition — critical for ranking and running totals. The key insight: the outer query still returns every row. The window function just adds a computed column alongside each one.

---

## The Code

**ROW_NUMBER, RANK, DENSE_RANK — ranking within a partition**
```sql
SELECT
    user_id,
    order_id,
    total_amount,
    ROW_NUMBER()  OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn,
    RANK()        OVER (PARTITION BY user_id ORDER BY total_amount DESC) AS rnk,
    DENSE_RANK()  OVER (PARTITION BY user_id ORDER BY total_amount DESC) AS dense_rnk
    -- ROW_NUMBER: always unique (1,2,3,4)
    -- RANK: ties get the same number, next rank skips (1,2,2,4)
    -- DENSE_RANK: ties get the same number, no gaps (1,2,2,3)
FROM orders;
```

**Get the most recent order per user (classic use case)**
```sql
SELECT user_id, order_id, total_amount, created_at
FROM (
    SELECT
        user_id,
        id AS order_id,
        total_amount,
        created_at,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn
    FROM orders
    WHERE status = 'completed'
) ranked
WHERE rn = 1;  -- one row per user: the most recent
```

**Running total with SUM OVER**
```sql
SELECT
    created_at::date        AS order_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY created_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_revenue
FROM orders
WHERE status = 'completed'
ORDER BY created_at;
```

**Aggregate window functions — value alongside the group summary**
```sql
SELECT
    id,
    country,
    monthly_spend,
    AVG(monthly_spend) OVER (PARTITION BY country)  AS country_avg,
    monthly_spend - AVG(monthly_spend) OVER (PARTITION BY country) AS diff_from_avg
FROM subscriptions;
-- Every row is preserved — no GROUP BY collapse
```

**LAG and LEAD — access adjacent rows**
```sql
SELECT
    order_date,
    daily_revenue,
    LAG(daily_revenue)  OVER (ORDER BY order_date) AS prev_day_revenue,
    LEAD(daily_revenue) OVER (ORDER BY order_date) AS next_day_revenue,
    daily_revenue - LAG(daily_revenue) OVER (ORDER BY order_date) AS day_over_day_change
FROM daily_revenue_summary
ORDER BY order_date;
```

**NTILE — divide rows into buckets**
```sql
-- Split users into 4 spend quartiles
SELECT
    user_id,
    total_spend,
    NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
FROM user_spend_summary;
```

---

## Gotchas

- **Window functions run after WHERE and GROUP BY, before ORDER BY** — you can't filter on a window function result in the same query's WHERE clause. Wrap the whole query in a subquery or CTE, then filter on the window column in the outer query.
- **PARTITION BY is optional — omitting it makes the whole table the window** — `SUM(amount) OVER ()` sums every row in the result set. That's sometimes what you want (percent of total), but accidentally omitting PARTITION BY when you needed it produces wrong numbers silently.
- **ORDER BY inside OVER changes SUM's behavior** — `SUM(amount) OVER (PARTITION BY x)` gives the total for the partition on every row. `SUM(amount) OVER (PARTITION BY x ORDER BY date)` gives a *running* total. Same function, completely different result depending on whether ORDER BY is present.
- **RANK vs DENSE_RANK gap behavior matters in pagination** — if you use RANK for top-N queries and there are ties at the boundary, you might get fewer rows than expected. DENSE_RANK avoids gaps; ROW_NUMBER ignores ties entirely. Know which one your use case requires.
- **Window functions are not supported in MySQL before version 8.0** — if you're on a legacy MySQL stack, window functions silently don't exist. You're forced into correlated subqueries or application-side logic, both of which are significantly worse.

---

## Interview Angle
**What they're really testing:** Whether you can think beyond GROUP BY — specifically, whether you understand that some problems require per-row computation across a group, not a collapsed result.

**Common question form:** "For each customer, find their most recent order" or "Rank products by sales within each category" or "Calculate a 7-day rolling average of daily signups."

**The depth signal:** A junior solves "most recent order per user" with a correlated subquery or a self-join with MAX — technically correct, often slow. A senior reaches for ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...) immediately, wraps it in a CTE or subquery, and filters on rn = 1. The senior also knows the difference between RANK and DENSE_RANK without pausing, explains why ORDER BY inside OVER turns SUM into a running total, and flags that window functions can't be filtered in the same WHERE clause — requiring a wrapping CTE.

---

## Related Topics
- [[databases/sql-aggregations.md]] — GROUP BY is the simpler tool; understand it before window functions
- [[databases/sql-subqueries.md]] — window results often need a wrapping subquery or CTE to filter on
- [[databases/sql-ctes.md]] — CTEs are the cleanest way to wrap a window function result and filter it
- [[databases/query-optimization.md]] — window functions over large unpartitioned tables are expensive; indexes on PARTITION BY columns help

---

## Source
https://www.postgresql.org/docs/current/tutorial-window.html

---
*Last updated: 2026-03-24*