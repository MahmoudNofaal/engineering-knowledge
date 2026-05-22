# SQL Window Functions

> Window functions perform calculations across a set of rows related to the current row — without collapsing those rows into a group the way aggregate functions do.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Per-row computation across a defined window of rows |
| **Use when** | You need both individual row detail and a computed summary in the same result |
| **Avoid when** | A simple GROUP BY produces what you need — window functions are more expensive |
| **Standard** | SQL:2003 (core window functions); SQL:2011 (frame clauses enhanced) |
| **Key functions** | `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `LAG`, `LEAD`, `FIRST_VALUE`, `LAST_VALUE`, `NTH_VALUE`, `NTILE`, `SUM/AVG/COUNT OVER` |
| **Key clauses** | `OVER (PARTITION BY ... ORDER BY ... ROWS/RANGE BETWEEN ...)` |

---

## When To Use It

Use window functions when you need both the detail row and a computed value across a group at the same time — running totals, rankings within a category, comparing each row to its group average, or fetching the previous/next row's value. They replace the painful pattern of joining a subquery back to the original table to get an aggregated column alongside raw data. Avoid them when a simple GROUP BY gives you what you need — window functions are more powerful but also heavier. On very large tables with no partitioning, a window function over all rows can be extremely expensive.

---

## Core Concept

Every window function has an OVER clause — that's the defining feature. The OVER clause defines the "window": which rows the function considers when computing its result for the current row. PARTITION BY splits rows into groups (like GROUP BY, but without collapsing). ORDER BY inside OVER defines the sequence within each partition — critical for ranking and running totals. An optional frame clause (ROWS BETWEEN / RANGE BETWEEN) further narrows which rows within the partition are included.

The key insight: the outer query still returns every row. The window function adds a computed column alongside each one. This is fundamentally different from GROUP BY, which returns one row per group.

Window functions execute after WHERE, GROUP BY, and HAVING — so they see the already-filtered, already-grouped result set. They execute before the final ORDER BY and LIMIT.

---

## Version History

| Standard / Version | What changed |
|---|---|
| SQL:2003 | Window functions standardized: RANK, DENSE_RANK, ROW_NUMBER, NTILE, LAG, LEAD, FIRST_VALUE, LAST_VALUE, NTH_VALUE |
| SQL:2011 | Frame clause improvements; RANGE with numeric offsets |
| PostgreSQL 8.4 | Window functions added |
| SQL Server 2005 | ROW_NUMBER added; full window support in 2012 |
| MySQL 8.0 | Window functions added (2018) |
| PostgreSQL 11 | `GROUPS` frame mode added |

*MySQL 5.7 and below have no window function support — a significant compatibility gap for legacy applications.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Window function (partitioned) | O(n log n) | Sort by PARTITION BY + ORDER BY columns |
| Window function (no partition) | O(n log n) | Sorts entire result set |
| Running sum (ROWS frame) | O(n) amortised | Incremental accumulation after sort |
| LAG/LEAD | O(1) per row | After sort — O(n log n) total for the sort |
| FIRST_VALUE/LAST_VALUE | O(1) per row | After sort |
| Multiple windows same spec | O(n log n) once | Planner reuses the sort for same OVER clause |

**Allocation behaviour:** Window functions require sorting or hashing the window partition. This uses `work_mem`. Large unpartitioned windows on wide tables can easily spill to disk. Adding an index on the PARTITION BY + ORDER BY columns can let the planner use a presorted index instead of sorting at runtime.

**Benchmark notes:** The most expensive window function pattern is a large OVER clause with no PARTITION BY — the entire result set becomes one window. Always partition when the data has natural groups. Multiple window functions with identical OVER clauses share a single sort — the planner is smart about this.

---

## The Code

**ROW_NUMBER, RANK, DENSE_RANK**
```sql
SELECT
    user_id,
    order_id,
    total_amount,
    ROW_NUMBER()  OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn,
    RANK()        OVER (PARTITION BY user_id ORDER BY total_amount DESC) AS rnk,
    DENSE_RANK()  OVER (PARTITION BY user_id ORDER BY total_amount DESC) AS dense_rnk
    -- ROW_NUMBER: always unique (1,2,3,4,5)
    -- RANK: ties share a rank, next rank skips (1,2,2,4,5)
    -- DENSE_RANK: ties share a rank, no gaps (1,2,2,3,4)
FROM orders;
```

**Get the most recent order per user — the classic pattern**
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
WHERE rn = 1;
-- Window functions can't be filtered in WHERE of the same query — wrap in a subquery or CTE
```

**SUM OVER — running total**
```sql
SELECT
    created_at::date    AS order_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY created_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_revenue
FROM orders
WHERE status = 'completed'
ORDER BY created_at;
```

**AVG OVER — moving average (7-day window)**
```sql
SELECT
    order_date,
    daily_revenue,
    AVG(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW    -- current + 6 prior = 7 rows
    ) AS moving_avg_7d
FROM daily_revenue_summary
ORDER BY order_date;
```

**Aggregate window function — value alongside group summary**
```sql
-- Each row keeps its individual data PLUS the country-level average
SELECT
    id,
    country,
    monthly_spend,
    AVG(monthly_spend) OVER (PARTITION BY country)                     AS country_avg,
    monthly_spend - AVG(monthly_spend) OVER (PARTITION BY country)     AS diff_from_avg,
    monthly_spend / SUM(monthly_spend) OVER (PARTITION BY country)     AS pct_of_country
FROM subscriptions;
```

**LAG and LEAD — access adjacent rows**
```sql
SELECT
    order_date,
    daily_revenue,
    LAG(daily_revenue, 1)  OVER (ORDER BY order_date) AS prev_day,
    LEAD(daily_revenue, 1) OVER (ORDER BY order_date) AS next_day,
    daily_revenue - LAG(daily_revenue) OVER (ORDER BY order_date) AS day_over_day
FROM daily_revenue_summary
ORDER BY order_date;
-- LAG/LEAD second argument: offset (default 1); third argument: default if out of range
```

**FIRST_VALUE, LAST_VALUE, NTH_VALUE**
```sql
SELECT
    user_id,
    order_id,
    total_amount,
    created_at,
    FIRST_VALUE(total_amount)   OVER w AS first_order_amount,
    LAST_VALUE(total_amount)    OVER w AS last_order_amount,    -- see Gotchas
    NTH_VALUE(total_amount, 2)  OVER w AS second_order_amount
FROM orders
WINDOW w AS (
    PARTITION BY user_id
    ORDER BY created_at
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING   -- required for LAST_VALUE
)
ORDER BY user_id, created_at;
```

**NTILE — divide rows into equal buckets**
```sql
-- Split users into 4 spend quartiles
SELECT
    user_id,
    total_spend,
    NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
FROM user_spend_summary;
-- Q1 = highest spenders; Q4 = lowest
```

**Named window — reuse OVER definition**
```sql
-- Define the window once, reference it multiple times
SELECT
    user_id,
    total_amount,
    ROW_NUMBER() OVER w    AS rn,
    RANK()       OVER w    AS rnk,
    SUM(total_amount) OVER w AS running_total
FROM orders
WINDOW w AS (PARTITION BY user_id ORDER BY created_at)
ORDER BY user_id, created_at;
```

**RANGE vs ROWS frame mode**
```sql
-- ROWS: physical row positions — precise
SUM(amount) OVER (ORDER BY created_at ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
-- Sums exactly 3 rows: current + 2 before it

-- RANGE: logical value range — includes all rows with matching ORDER BY value
SUM(amount) OVER (ORDER BY created_at RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW)
-- Sums all rows within 7 days of the current row's date — handles ties correctly
```

---

## Real World Example

A SaaS billing dashboard needs to show, for every invoice: the customer's total spend to date (running total), their rank among all customers by total spend, and the percentage each invoice represents of their overall lifetime spend — all in one query, preserving individual invoice rows.

```sql
WITH invoice_data AS (
    SELECT
        i.id            AS invoice_id,
        i.customer_id,
        c.name          AS customer_name,
        i.amount,
        i.issued_at
    FROM invoices i
    INNER JOIN customers c ON c.id = i.customer_id
    WHERE i.status = 'paid'
)
SELECT
    invoice_id,
    customer_id,
    customer_name,
    amount,
    issued_at,

    -- Running total per customer (chronological)
    SUM(amount) OVER (
        PARTITION BY customer_id
        ORDER BY issued_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                       AS cumulative_spend,

    -- Customer's total lifetime spend (constant per customer)
    SUM(amount) OVER (PARTITION BY customer_id)             AS lifetime_spend,

    -- This invoice as % of lifetime spend
    ROUND(
        100.0 * amount / SUM(amount) OVER (PARTITION BY customer_id),
        2
    )                                                       AS pct_of_lifetime,

    -- Rank this customer among all customers by total spend (dense so no gaps)
    DENSE_RANK() OVER (
        ORDER BY SUM(amount) OVER (PARTITION BY customer_id) DESC
    )                                                       AS customer_spend_rank

FROM invoice_data
ORDER BY customer_id, issued_at;
```

*The key insight: four different window computations — one running total, one partition total used twice, and one rank across the whole dataset — all computed in a single pass over the invoices. No self-joins, no correlated subqueries, no application-side post-processing. The WINDOW clause could be used to DRY up the repeated OVER clauses.*

---

## Common Misconceptions

**"Window functions run after ORDER BY"**
They run *before* the final ORDER BY and LIMIT. This is why you can't filter on a window function result in the same query's WHERE clause — it hasn't been computed yet when WHERE runs. Wrap in a CTE or subquery, then filter in the outer query.

**"LAST_VALUE always gives you the last value in the partition"**
The default frame is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` — which only looks at rows up to the current one. LAST_VALUE of this frame is just the current row's value. To get the true last value in the partition, explicitly set `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.

```sql
-- Wrong: returns current row's value, not last in partition
LAST_VALUE(amount) OVER (PARTITION BY user_id ORDER BY created_at)

-- Correct: full partition frame
LAST_VALUE(amount) OVER (
    PARTITION BY user_id ORDER BY created_at
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
```

**"PARTITION BY is required"**
It's optional. Omitting it makes the entire result set the window. `SUM(amount) OVER ()` sums all rows. This is useful for percent-of-total calculations but accidentally omitting PARTITION BY when you meant to partition is a common source of wrong results.

---

## Gotchas

- **Window functions can't be filtered in the same WHERE clause** — they execute after WHERE. Wrap the query in a CTE or subquery and filter in the outer query.

- **ORDER BY inside OVER changes SUM's behaviour** — `SUM(amount) OVER (PARTITION BY x)` gives the total for the partition on every row. `SUM(amount) OVER (PARTITION BY x ORDER BY date)` gives a *running* total. Same function, completely different results.

- **LAST_VALUE default frame stops at the current row** — without an explicit `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`, LAST_VALUE is almost always not what you want. This trips up even experienced developers.

- **RANK vs DENSE_RANK gap behaviour matters for pagination** — if you use RANK for top-N queries and there are ties at the boundary, you might get fewer results than expected. DENSE_RANK avoids gaps; ROW_NUMBER ignores ties entirely.

- **MySQL before 8.0 has no window functions** — complete redesign required for pre-8.0 MySQL: correlated subqueries or application-side computation. Know your target database version.

---

## Interview Angle

**What they're really testing:** Whether you can think beyond GROUP BY — whether you understand that some problems require per-row computation across a group, not a collapsed result.

**Common question forms:**
- "For each customer, find their most recent order"
- "Rank products by sales within each category"
- "Calculate a 7-day rolling average of daily signups"

**The depth signal:** A junior solves "most recent order per user" with a correlated subquery or self-join with MAX — correct but slow. A senior reaches for `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` immediately, wraps it in a CTE, and filters on `rn = 1`. They know the difference between RANK and DENSE_RANK without pausing, explain why ORDER BY inside OVER turns SUM into a running total, flag the LAST_VALUE default frame trap, and know that window functions execute after WHERE. Named windows (WINDOW clause) and the RANGE vs ROWS frame distinction are strong senior signals.

**Follow-up questions to expect:**
- "Why can't you filter on a window function in WHERE?"
- "What's the difference between RANGE BETWEEN and ROWS BETWEEN?"

---

## Related Topics

- [[databases/sql/sql-aggregations.md]] — GROUP BY is the simpler tool; understand it before window functions
- [[databases/sql/sql-ctes.md]] — CTEs are the cleanest way to wrap window results and filter on them
- [[databases/sql/sql-subqueries.md]] — window results often need a wrapping subquery to filter
- [[databases/sql/sql-indexing.md]] — indexes on PARTITION BY + ORDER BY columns eliminate runtime sorts
- [[databases/sql/sql-query-optimization.md]] — large unpartitioned windows are expensive; EXPLAIN shows the sort node

---

## Source

https://www.postgresql.org/docs/current/tutorial-window.html

---
*Last updated: 2026-04-13*