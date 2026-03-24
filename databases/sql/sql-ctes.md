# SQL CTEs (Common Table Expressions)

> A CTE is a named, temporary result set defined at the top of a query with the WITH keyword — giving a complex subquery a readable name you can reference like a table.

---

## When To Use It
Use CTEs when a query has multiple logical steps that are clearer as named stages than as nested subqueries — data prep, filtering, then aggregation, for example. They're also the cleanest way to filter on a window function result, or to reference the same subquery more than once without duplicating it. Don't reach for a CTE when a simple JOIN or subquery is already readable — the WITH block adds visual overhead that isn't always worth it. For very large tables, check whether the CTE is being materialized or inlined by the query planner, since that affects performance.

---

## Core Concept
A CTE starts with WITH, gives the subquery a name, and then lets the main query reference that name as if it were a real table. You can chain multiple CTEs in one WITH block — each one can reference the ones defined before it. The result only exists for the duration of that query. It doesn't create an index, it doesn't get cached between queries, and it isn't stored anywhere. The query planner in PostgreSQL decides whether to inline the CTE (treat it like a subquery) or materialize it (compute it once and store the result temporarily) — in PostgreSQL 12+, inlining is the default for non-recursive CTEs unless you force materialization explicitly.

---

## The Code

**Basic CTE — name a subquery for clarity**
```sql
WITH completed_orders AS (
    SELECT user_id, total_amount, created_at
    FROM orders
    WHERE status = 'completed'
)
SELECT
    user_id,
    COUNT(*)            AS order_count,
    SUM(total_amount)   AS total_spent
FROM completed_orders
GROUP BY user_id
ORDER BY total_spent DESC;
```

**Chained CTEs — multiple named stages**
```sql
WITH 
completed_orders AS (
    SELECT user_id, total_amount
    FROM orders
    WHERE status = 'completed'
),
user_spend AS (
    SELECT user_id, SUM(total_amount) AS total_spent
    FROM completed_orders           -- references the first CTE
    GROUP BY user_id
),
high_value AS (
    SELECT user_id, total_spent
    FROM user_spend
    WHERE total_spent > 1000
)
SELECT u.email, h.total_spent
FROM high_value h
INNER JOIN users u ON u.id = h.user_id
ORDER BY h.total_spent DESC;
```

**CTE to filter on a window function result**
```sql
WITH ranked_orders AS (
    SELECT
        user_id,
        id          AS order_id,
        total_amount,
        created_at,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn
    FROM orders
)
SELECT user_id, order_id, total_amount, created_at
FROM ranked_orders
WHERE rn = 1;   -- most recent order per user, cleanly expressed
```

**Recursive CTE — walk a hierarchy**
```sql
-- Traverse an employee org chart from a given manager down
WITH RECURSIVE org_chart AS (
    -- Base case: start with the root manager
    SELECT id, name, manager_id, 1 AS depth
    FROM employees
    WHERE id = 1

    UNION ALL

    -- Recursive case: join each employee to their manager row
    SELECT e.id, e.name, e.manager_id, oc.depth + 1
    FROM employees e
    INNER JOIN org_chart oc ON oc.id = e.manager_id
)
SELECT id, name, depth
FROM org_chart
ORDER BY depth, name;
```

**Forcing materialization (PostgreSQL 12+)**
```sql
-- MATERIALIZED forces the CTE to compute once and store the result
-- Useful when the CTE is expensive and referenced multiple times
WITH expensive_aggregation AS MATERIALIZED (
    SELECT region, SUM(revenue) AS total
    FROM sales
    GROUP BY region
)
SELECT * FROM expensive_aggregation WHERE total > 50000
UNION ALL
SELECT * FROM expensive_aggregation WHERE total < 1000;
```

---

## Gotchas

- **CTEs are not always computed once** — in PostgreSQL 12+, non-recursive CTEs are inlined by default, meaning the planner may execute the CTE body multiple times if referenced multiple times. If the CTE is expensive and referenced more than once, use `AS MATERIALIZED` to force a single computation.
- **Recursive CTEs need a termination condition** — without a base case that eventually produces no rows, a recursive CTE loops forever (or until the server hits a recursion limit). Always verify your UNION ALL recursive step will eventually stop producing matches.
- **CTEs don't push predicates through by default when materialized** — if you write `WHERE` conditions on the outer query, they won't filter inside a materialized CTE. The CTE computes its full result first. This is a common performance trap when people expect the planner to "see through" the CTE.
- **MySQL didn't support CTEs before version 8.0** — on older MySQL, WITH doesn't exist. SQL Server and PostgreSQL have had them far longer. Know your database version before reaching for CTEs in a legacy codebase.
- **Naming CTEs the same as real tables causes silent shadowing** — if you name a CTE `users` and there's a real `users` table, the CTE takes precedence within that query. No error, just silently different data. Use specific, descriptive names.

---

## Interview Angle
**What they're really testing:** Whether you can structure a complex query clearly, and whether you understand the difference between a CTE as a readability tool versus a performance tool.

**Common question form:** "Refactor this nested subquery" or "How would you walk a tree structure in SQL?" or "What's the difference between a CTE and a subquery?"

**The depth signal:** A junior knows CTEs exist and can write a basic WITH block. A senior explains that CTEs are primarily a readability tool — not a performance guarantee — and knows that PostgreSQL 12+ inlines them by default so they don't automatically compute once. They reach for `MATERIALIZED` when referencing an expensive CTE multiple times, know that recursive CTEs require a UNION ALL with a terminating base case, and understand that predicates on the outer query don't filter inside a materialized CTE. Recursive CTE knowledge for hierarchical data (org charts, category trees) is a strong senior signal.

---

## Related Topics
- [[databases/sql-subqueries.md]] — CTEs are the readable alternative to deeply nested subqueries; know when to switch
- [[databases/sql-window-functions.md]] — CTEs are the standard wrapper for filtering on window function results
- [[databases/sql-aggregations.md]] — chained CTEs often break a complex aggregation into named, auditable steps
- [[databases/query-optimization.md]] — materialization vs inlining behavior directly affects CTE performance on large tables

---

## Source
https://www.postgresql.org/docs/current/queries-with.html

---
*Last updated: 2026-03-24*