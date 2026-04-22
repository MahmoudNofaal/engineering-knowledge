# SQL Subqueries

> A subquery is a SELECT statement nested inside another query — used to compute an intermediate value, filter rows against an aggregated condition, or produce a temporary result set.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Nested SELECT used as value, filter, or derived table |
| **Use when** | Intermediate result that the outer query depends on |
| **Avoid when** | More than two nesting levels — rewrite as a CTE |
| **Standard** | SQL-92 (scalar, list, EXISTS); SQL:1999 (LATERAL) |
| **Key forms** | Scalar, List (IN/NOT IN), Derived table (FROM), Correlated, EXISTS, LATERAL |
| **Performance trap** | Correlated subquery re-executes once per outer row — O(n × m) |

---

## When To Use It

Use subqueries when you need an intermediate result the outer query depends on — finding rows above the average, filtering by an aggregated condition, or checking existence in another table. They're often cleaner than joins when the relationship is one-directional and you don't need columns from the inner table in your output. Avoid deeply nested subqueries (more than two levels) — they become unreadable fast and are usually better rewritten as CTEs. Never use a correlated subquery where a JOIN or CTE with aggregation would work — correlated subqueries scale terribly.

---

## Core Concept

A subquery is a SELECT wrapped in parentheses, placed where a value, a list, or a table would normally go. That placement determines the type. Scalar subqueries return one value and go where a single value is expected. List subqueries return a column of values and pair with IN or NOT IN. Derived table subqueries return full rows and sit in the FROM clause like a temporary table. Correlated subqueries reference the outer query's columns and re-execute once per outer row — this is the expensive one. LATERAL subqueries are correlated derived tables that can reference earlier FROM items, enabling patterns like "top N per group" without window functions.

The distinction that matters most for performance: a non-correlated subquery executes once and its result is reused. A correlated subquery executes N times — once for every row in the outer query. On 100,000 rows, that's 100,000 inner executions.

---

## Version History

| Standard / Version | What changed |
|---|---|
| SQL-92 | Scalar, IN/NOT IN, EXISTS, derived table subqueries standardized |
| SQL:1999 | LATERAL introduced (subquery can reference preceding FROM items) |
| PostgreSQL 7.4 | Subquery optimization improved significantly |
| PostgreSQL 9.3 | LATERAL fully supported |
| MySQL 5.x | Correlated subqueries poorly optimized — materialised on each row |
| MySQL 8.0 | Lateral joins added; subquery optimizations improved substantially |

---

## Performance

| Subquery type | Complexity | Notes |
|---|---|---|
| Non-correlated scalar | O(m) once | Executes once; result cached for all outer rows |
| Non-correlated IN list | O(m) once | Inner result hashed; outer probes it |
| Correlated subquery | O(n × m) | Re-executes for every outer row — the dangerous one |
| Derived table (FROM) | O(m) | Executes once; acts as a temporary named relation |
| LATERAL | O(n × m) | Like correlated but explicit — planner can optimise it better |
| EXISTS | O(m) short-circuit | Stops on first match — faster than IN for large inner sets |

**Allocation behaviour:** Derived table subqueries are materialised in memory (or spilled to disk if large). Non-correlated subqueries in WHERE are typically hashed. Correlated subqueries run inline — no materialisation, but no sharing either.

**Benchmark notes:** On tables under ~10,000 rows the difference between a correlated subquery and a JOIN rewrite is often negligible. Above that, the correlated subquery path degrades linearly. Profile before rewriting — but always prefer the JOIN/CTE form in production code for predictability.

---

## The Code

**Scalar subquery — returns a single value**
```sql
-- Find all orders above the average order value
SELECT id, total_amount
FROM orders
WHERE total_amount > (
    SELECT AVG(total_amount)
    FROM orders
    WHERE status = 'completed'
);
-- Inner query executes once; result is reused for every outer row comparison
```

**List subquery with IN**
```sql
-- Find users who have placed at least one completed order
SELECT id, email
FROM users
WHERE id IN (
    SELECT DISTINCT user_id
    FROM orders
    WHERE status = 'completed'
);
```

**NOT IN — find unmatched rows (handle NULLs carefully)**
```sql
-- Users who have never ordered
SELECT id, email
FROM users
WHERE id NOT IN (
    SELECT user_id
    FROM orders
    WHERE user_id IS NOT NULL  -- critical: see Gotchas
);
```

**Subquery in FROM clause (derived table)**
```sql
-- Average revenue per country, computed from a grouped subquery
SELECT country, AVG(user_revenue) AS avg_revenue
FROM (
    SELECT u.country, SUM(o.total_amount) AS user_revenue
    FROM users u
    INNER JOIN orders o ON o.user_id = u.id
    GROUP BY u.id, u.country
) AS user_totals
GROUP BY country
ORDER BY avg_revenue DESC;
-- The derived table must be aliased — required in PostgreSQL and MySQL
```

**Correlated subquery — references the outer query**
```sql
-- For each user, get their most recent order date (SLOW on large tables)
SELECT
    u.id,
    u.email,
    (
        SELECT MAX(o.created_at)
        FROM orders o
        WHERE o.user_id = u.id   -- references outer u.id — re-runs per row
    ) AS last_order_date
FROM users u;

-- FAST rewrite: aggregate in a subquery, join once
SELECT
    u.id,
    u.email,
    last_orders.last_order_date
FROM users u
LEFT JOIN (
    SELECT user_id, MAX(created_at) AS last_order_date
    FROM orders
    GROUP BY user_id
) last_orders ON last_orders.user_id = u.id;
```

**EXISTS — better than IN for existence checks**
```sql
-- Users who have at least one completed order
SELECT u.id, u.email
FROM users u
WHERE EXISTS (
    SELECT 1                        -- SELECT 1 is conventional; value doesn't matter
    FROM orders o
    WHERE o.user_id = u.id
      AND o.status = 'completed'
);
-- EXISTS short-circuits on first match; IN materialises the full result first
```

**NOT EXISTS — unmatched rows (safer than NOT IN)**
```sql
-- Users who have never ordered — the NULL-safe version
SELECT u.id, u.email
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.user_id = u.id
);
-- Handles NULLs correctly unlike NOT IN — preferred pattern
```

**LATERAL subquery — correlated derived table**
```sql
-- Top 3 most recent orders per user (PostgreSQL / SQL:1999+)
SELECT u.id, u.email, recent.order_id, recent.total_amount, recent.created_at
FROM users u
CROSS JOIN LATERAL (
    SELECT id AS order_id, total_amount, created_at
    FROM orders o
    WHERE o.user_id = u.id          -- can reference u because it's LATERAL
    ORDER BY created_at DESC
    LIMIT 3
) recent;

-- Equivalent to a window function but works in databases with no window support
-- and can apply complex logic (not just ranking)
```

**Subquery in SELECT list — use sparingly**
```sql
-- Scalar subquery in SELECT: runs once per output row — fine for small results
SELECT
    u.id,
    u.email,
    (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id) AS order_count
FROM users u;

-- On a table with 100,000 users this runs 100,000 inner queries
-- Rewrite with a LEFT JOIN + COUNT for anything over a few thousand rows
```

---

## Real World Example

A fraud detection service needs to flag orders placed from IP addresses that have also been associated with previously charged-back accounts — without a direct foreign key relationship between the tables. A JOIN won't work cleanly here; a correlated EXISTS is the natural fit.

```sql
SELECT
    o.id           AS order_id,
    o.user_id,
    o.total_amount,
    o.ip_address,
    o.created_at
FROM orders o
WHERE o.status = 'pending'
  AND o.created_at >= NOW() - INTERVAL '24 hours'
  AND EXISTS (
      SELECT 1
      FROM chargebacks cb
      INNER JOIN orders prev_o ON prev_o.id = cb.order_id
      WHERE prev_o.ip_address = o.ip_address    -- correlated: same IP
        AND cb.status         = 'upheld'
        AND prev_o.user_id   != o.user_id        -- different user — not a repeat purchase
  )
ORDER BY o.total_amount DESC;
```

*The key insight: EXISTS stops scanning chargebacks the moment it finds one match — it never retrieves the chargeback data, only checks for its existence. A JOIN would multiply order rows by chargeback count and require a DISTINCT to clean up. The correlated EXISTS is both the most readable and the most efficient form for this access pattern.*

---

## Common Misconceptions

**"A subquery in FROM is the same as a CTE"**
They're semantically similar but behave differently under the planner. A derived table in FROM is always inlined — the planner folds it into the surrounding query. A CTE in PostgreSQL 12+ is also inlined by default, but can be forced to materialise with `AS MATERIALIZED`. The distinction matters when the inner query is expensive and referenced multiple times — a materialised CTE computes once, a derived table may recompute.

**"IN and EXISTS always return the same result"**
They return the same rows in normal cases, but NOT IN and NOT EXISTS behave differently when NULLs are present. NOT IN with any NULL in the inner result returns no rows at all (because NULL comparison is never true). NOT EXISTS always works correctly. Use NOT EXISTS by default.

```sql
-- If orders contains even ONE row with user_id = NULL:
-- This returns ZERO rows for every user
WHERE id NOT IN (SELECT user_id FROM orders)

-- This works correctly regardless of NULLs
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id)
```

**"Subqueries are always slower than JOINs"**
Non-correlated subqueries often produce identical plans to equivalent JOINs — the planner rewrites them internally. The performance problem is specifically with *correlated* subqueries that re-execute per row. For existence checks, EXISTS is often faster than a JOIN because it short-circuits.

---

## Gotchas

- **`NOT IN` with NULLs returns no rows** — if the subquery result contains even one NULL, `NOT IN` evaluates to NULL for every comparison and the entire outer query returns empty. Always add `WHERE column IS NOT NULL` inside the subquery, or use `NOT EXISTS` instead.

- **Correlated subqueries execute once per outer row** — they look like a simple nested query but scale O(n × m). A correlated subquery on a 100k-row table with a 10k-row inner table runs 100,000 inner queries. Rewrite as a JOIN or CTE with aggregation whenever possible.

- **Derived tables must be aliased** — in PostgreSQL and MySQL, every subquery in the FROM clause requires an alias (`AS name`). Forgetting it is a syntax error.

- **`IN` vs `EXISTS` performance differs** — `IN` materialises the full inner result first, then checks membership. `EXISTS` short-circuits on first match. For large inner sets where you only care about existence, `EXISTS` is consistently faster.

- **Scalar subqueries that return more than one row throw an error** — a subquery in a position expecting a scalar value (WHERE col = (subquery)) will error if the subquery returns more than one row. Guard with `LIMIT 1` or ensure the result is unique, or use `= ANY(subquery)` which handles multiple rows.

---

## Interview Angle

**What they're really testing:** Whether you understand query execution order and can identify when a subquery will silently destroy performance.

**Common question forms:**
- "Write a query to find customers whose order total is above average"
- "Find all products that have never been ordered"
- "Why is this query slow?" (points to a correlated subquery in SELECT)

**The depth signal:** A junior writes a correlated subquery and calls it done. A senior recognises the correlated subquery as an O(n) trap, rewrites it as a LEFT JOIN or CTE, and explains why. They know the NOT IN + NULL footgun without being prompted, reach for NOT EXISTS by default, and understand when EXISTS is faster than IN. They also know when a subquery and a JOIN produce the same plan — the planner is often smart enough to rewrite one into the other. Knowing LATERAL and when to use it instead of a window function is a strong senior signal.

**Follow-up questions to expect:**
- "How would you rewrite this correlated subquery as a JOIN?"
- "What's the difference between a derived table and a CTE?"

---

## Related Topics

- [[databases/sql/sql-basics.md]] — WHERE, FROM, and SELECT mechanics that subqueries plug into
- [[databases/sql/sql-ctes.md]] — CTEs are the readable, reusable alternative to deeply nested subqueries
- [[databases/sql/sql-joins.md]] — most correlated subqueries can be rewritten as JOINs with better performance
- [[databases/sql/sql-null-handling.md]] — NOT IN with NULLs is one of the most dangerous SQL traps
- [[databases/sql/sql-query-optimization.md]] — correlated subqueries are one of the most common sources of slow queries

---

## Source

https://www.postgresql.org/docs/current/queries-table-expressions.html#QUERIES-SUBQUERIES

---
*Last updated: 2026-04-13*