# SQL Subqueries

> A subquery is a SELECT statement nested inside another query, used to compute a value, filter rows, or produce a temporary result set.

---

## When To Use It
Use subqueries when you need an intermediate result that the outer query depends on — finding rows above the average, filtering by an aggregated condition, or checking existence in another table. They're often cleaner than joins when the relationship is one-directional and you don't need columns from the inner table in your output. Avoid deeply nested subqueries (more than two levels) — they become unreadable fast and are usually better rewritten as CTEs.

---

## Core Concept
A subquery is just a SELECT wrapped in parentheses, placed where a value, a list, or a table would normally go. That placement determines the type: scalar subqueries return one value and go where a single value is expected; list subqueries return a column of values and pair with IN or NOT IN; table subqueries return full rows and sit in the FROM clause like a temporary table; correlated subqueries reference the outer query's columns and re-execute once per outer row. The last one is the dangerous one — it looks innocent but scales terribly on large tables.

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
```

**List subquery with IN**
```sql
-- Find users who have placed at least one order
SELECT id, email
FROM users
WHERE id IN (
    SELECT DISTINCT user_id
    FROM orders
    WHERE status = 'completed'
);
```

**NOT IN — find unmatched rows**
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
```

**Correlated subquery — references the outer query**
```sql
-- For each user, get their most recent order date
SELECT 
    u.id,
    u.email,
    (
        SELECT MAX(o.created_at)
        FROM orders o
        WHERE o.user_id = u.id   -- references outer u.id — re-runs per row
    ) AS last_order_date
FROM users u;
-- Works, but re-executes the inner query for every user row
-- On large tables, rewrite this as a LEFT JOIN with GROUP BY
```

**EXISTS — better than IN for existence checks**
```sql
-- Users who have at least one completed order
SELECT u.id, u.email
FROM users u
WHERE EXISTS (
    SELECT 1                        -- SELECT 1 is conventional — the value doesn't matter
    FROM orders o
    WHERE o.user_id = u.id
      AND o.status = 'completed'
);
```

---

## Gotchas

- **`NOT IN` with NULLs returns no rows** — if the subquery result contains even one NULL, `NOT IN` evaluates to NULL for every comparison and the entire outer query returns empty. Always add `WHERE column IS NOT NULL` inside the subquery, or use `NOT EXISTS` instead, which handles NULLs correctly.
- **Correlated subqueries execute once per outer row** — they look like a simple nested query but are O(n) against the inner table for every outer row. On a table with 100k users this means 100k inner executions. Rewrite as a JOIN or CTE with aggregation whenever possible.
- **Subqueries in SELECT columns run per row too** — a scalar subquery in the SELECT list is also correlated. Fine for small result sets, a performance trap at scale.
- **Derived tables must be aliased** — in PostgreSQL and MySQL, every subquery in the FROM clause requires an alias (`AS subquery_name`). Forgetting it is a syntax error that's easy to miss when you're editing a long query.
- **`IN` vs `EXISTS` performance differs** — `IN` materializes the full inner result first, then checks membership. `EXISTS` short-circuits as soon as one match is found. For large inner sets where you only care about existence, `EXISTS` is consistently faster.

---

## Interview Angle
**What they're really testing:** Whether you understand query execution order, and whether you can identify when a subquery is the right tool versus when it will silently destroy performance.

**Common question form:** "Write a query to find customers whose order total is above average" or "Find all products that have never been ordered."

**The depth signal:** A junior writes a correlated subquery and calls it done. A senior recognizes the correlated subquery as an O(n) trap, rewrites it as a LEFT JOIN or CTE, and explains why. They also know the `NOT IN` + NULL footgun without being prompted, and reach for `NOT EXISTS` by default. Seniors also know when to push a subquery into a CTE for readability and when the query planner will inline it anyway — so the split is stylistic, not a performance win.

---

## Related Topics
- [[databases/sql-basics.md]] — WHERE, FROM, and SELECT mechanics that subqueries plug into
- [[databases/sql-aggregations.md]] — subqueries frequently wrap or feed into aggregation logic
- [[databases/sql-ctes.md]] — CTEs are the readable alternative to nested subqueries; know when to switch
- [[databases/query-optimization.md]] — correlated subqueries are one of the most common sources of slow queries

---

## Source
https://www.postgresql.org/docs/current/queries-table-expressions.html#QUERIES-SUBQUERIES

---
*Last updated: 2026-03-24*