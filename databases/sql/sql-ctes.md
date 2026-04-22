# SQL CTEs (Common Table Expressions)

> A CTE is a named, temporary result set defined at the top of a query with the WITH keyword — giving a complex subquery a readable name you can reference like a table within that query.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Named temporary result set scoped to one query |
| **Use when** | Multi-step logic, filtering window function results, recursive traversal |
| **Avoid when** | A simple subquery or JOIN is already readable |
| **Standard** | SQL:1999 (non-recursive); SQL:1999 (RECURSIVE) |
| **Key syntax** | `WITH name AS (...)`, `WITH RECURSIVE`, `AS MATERIALIZED`, `AS NOT MATERIALIZED` |
| **PostgreSQL behaviour** | 12+: CTEs inlined by default; use `MATERIALIZED` to force single computation |

---

## When To Use It

Use CTEs when a query has multiple logical steps that are clearer as named stages — data prep, filtering, then aggregation. They're the cleanest way to filter on a window function result, or to reference the same subquery more than once without duplicating it. They're the only way to write recursive queries (tree traversal, graph walks, sequential generation). Don't reach for a CTE when a simple JOIN or subquery is already readable — the WITH block adds visual overhead. For very large tables, always verify whether the CTE is being inlined or materialised, since that directly affects whether predicates push through.

---

## Core Concept

A CTE starts with WITH, gives the subquery a name, and lets the main query reference that name as if it were a real table. You can chain multiple CTEs — each can reference the ones defined before it. The result only exists for the duration of that query.

In PostgreSQL 12+, non-recursive CTEs are inlined by default. This means the planner folds the CTE body into the surrounding query and optimises it as a unit — which is usually what you want. The old behaviour (pre-12) materialised every CTE as a concrete temporary result, which prevented predicate pushdown but guaranteed single execution. You can force materialisation explicitly with `AS MATERIALIZED` when you need it.

Recursive CTEs follow a different model: a base case (non-recursive SELECT), then a UNION ALL with a recursive term that references the CTE itself. The engine iterates until the recursive term produces no new rows.

---

## Version History

| Standard / Version | What changed |
|---|---|
| SQL:1999 | WITH and WITH RECURSIVE introduced in the standard |
| PostgreSQL 8.4 | CTEs and recursive CTEs added |
| SQL Server 2005 | CTEs added |
| MySQL 8.0 | CTEs and recursive CTEs added (2018) |
| PostgreSQL 12 | CTE inlining as default; `MATERIALIZED` / `NOT MATERIALIZED` keywords added |
| PostgreSQL 14 | `SEARCH` and `CYCLE` clauses added for recursive CTE control |

*Before MySQL 8.0, MySQL had no CTE support — all multi-step queries required nested subqueries or temporary tables. This is a major compatibility break for older MySQL codebases.*

---

## Performance

| CTE behaviour | Cost | Notes |
|---|---|---|
| Inlined (default PG 12+) | Same as equivalent subquery | Planner optimises as a unit; predicates push through |
| Materialised (`MATERIALIZED`) | O(m) once | Computes once; result stored; predicates don't push through |
| Recursive (RECURSIVE) | O(depth × rows) | Each iteration scans previous result; unbounded without cycle detection |
| Referenced multiple times (inlined) | O(m × references) | May re-execute each reference unless materialised |
| Referenced multiple times (materialised) | O(m) once | Single computation shared across all references |

**Allocation behaviour:** Materialised CTEs store their result in memory (or spill to disk). For large result sets referenced multiple times, this is a memory trade-off — pay once to avoid recomputation. For small result sets, inlining is almost always better.

**Benchmark notes:** The biggest CTE performance trap is referencing an expensive materialised CTE twice thinking it will compute once — in PG 12+ it may actually re-execute twice if inlined. Use `AS MATERIALIZED` explicitly when you need the single-execution guarantee.

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
-- Window functions can't be filtered in the same WHERE clause — wrap in a CTE
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
WHERE rn = 1;   -- most recent order per user
```

**Forcing materialisation (PostgreSQL 12+)**
```sql
-- MATERIALIZED forces the CTE to compute once and store the result
-- Use when the CTE is expensive AND referenced more than once
WITH expensive_agg AS MATERIALIZED (
    SELECT region, SUM(revenue) AS total
    FROM sales
    GROUP BY region
)
SELECT * FROM expensive_agg WHERE total > 50000
UNION ALL
SELECT * FROM expensive_agg WHERE total < 1000;
-- Without MATERIALIZED this might execute twice (once per UNION branch)
```

**Recursive CTE — walk a hierarchy**
```sql
-- Traverse an employee org chart from a given root down
WITH RECURSIVE org_chart AS (
    -- Base case: start at the root
    SELECT id, name, manager_id, 0 AS depth
    FROM employees
    WHERE id = 1           -- root node

    UNION ALL

    -- Recursive case: join each employee to their direct manager row already in the CTE
    SELECT e.id, e.name, e.manager_id, oc.depth + 1
    FROM employees e
    INNER JOIN org_chart oc ON oc.id = e.manager_id
    -- Implicit termination: when no more employees match, UNION ALL produces no rows
)
SELECT id, name, depth
FROM org_chart
ORDER BY depth, name;
```

**Recursive CTE — generate a date series**
```sql
-- Generate every date in a range without a calendar table
WITH RECURSIVE date_series AS (
    SELECT '2024-01-01'::date AS d

    UNION ALL

    SELECT d + INTERVAL '1 day'
    FROM date_series
    WHERE d < '2024-01-31'
)
SELECT d FROM date_series;
-- Useful for filling gaps in time-series data via a LEFT JOIN
```

**SEARCH and CYCLE clauses (PostgreSQL 14+)**
```sql
-- SEARCH BREADTH FIRST: control traversal order
-- CYCLE: detect and break infinite loops in cyclic graphs
WITH RECURSIVE graph_walk AS (
    SELECT id, parent_id, name
    FROM nodes
    WHERE id = 1

    UNION ALL

    SELECT n.id, n.parent_id, n.name
    FROM nodes n
    INNER JOIN graph_walk g ON g.id = n.parent_id
)
SEARCH BREADTH FIRST BY id SET ordercol
CYCLE id SET is_cycle USING path
SELECT * FROM graph_walk WHERE NOT is_cycle
ORDER BY ordercol;
```

---

## Real World Example

A multi-level reseller platform needs to calculate total downline revenue for each reseller — summing all revenue from direct and indirect recruits at every level of the tree. A flat JOIN can't do this because the tree depth is variable and unknown.

```sql
WITH RECURSIVE reseller_tree AS (
    -- Base case: start with the target reseller
    SELECT
        id,
        name,
        parent_id,
        id AS root_id,       -- track which root we started from
        0  AS depth
    FROM resellers
    WHERE parent_id IS NULL  -- all root resellers

    UNION ALL

    SELECT
        r.id,
        r.name,
        r.parent_id,
        rt.root_id,
        rt.depth + 1
    FROM resellers r
    INNER JOIN reseller_tree rt ON rt.id = r.parent_id
),
reseller_revenue AS (
    SELECT
        reseller_id,
        SUM(amount) AS direct_revenue
    FROM transactions
    WHERE status = 'completed'
    GROUP BY reseller_id
)
SELECT
    rt.root_id,
    r_root.name         AS reseller_name,
    COUNT(rt.id)        AS total_downline_count,
    SUM(COALESCE(rev.direct_revenue, 0)) AS total_downline_revenue
FROM reseller_tree rt
LEFT JOIN reseller_revenue rev  ON rev.reseller_id = rt.id
INNER JOIN resellers r_root     ON r_root.id = rt.root_id
GROUP BY rt.root_id, r_root.name
ORDER BY total_downline_revenue DESC;
```

*The key insight: the recursive CTE handles the variable-depth tree traversal in one pass. The second CTE pre-aggregates transactions so the final join doesn't multiply rows. Without CTEs, this would require either a stored procedure with a loop or application-side tree walking — both slower and harder to maintain.*

---

## Common Misconceptions

**"CTEs always compute once — that's their whole point"**
Before PostgreSQL 12, yes — CTEs were always materialised. Since PostgreSQL 12, non-recursive CTEs are inlined by default and may re-execute for each reference. If you need the single-execution guarantee, you must write `AS MATERIALIZED` explicitly. This is the most common CTE performance surprise on modern PostgreSQL.

**"A CTE is the same as a temporary table"**
A CTE is scoped to one query and disappears immediately. A temporary table persists for a session and can be indexed. For results needed across multiple queries in a session, or for large intermediate sets that benefit from indexing, a temp table is more appropriate. A CTE for a one-time use within one query is cleaner.

```sql
-- CTE: gone after this query
WITH staged AS (SELECT * FROM raw_data WHERE processed = false)
SELECT COUNT(*) FROM staged;

-- Temp table: persists, indexable, usable in next query
CREATE TEMP TABLE staged AS SELECT * FROM raw_data WHERE processed = false;
CREATE INDEX ON staged (user_id);
SELECT COUNT(*) FROM staged;  -- uses the index
```

**"Recursive CTEs can loop forever"**
PostgreSQL has a `max_recursion_depth` guard (default: not set — but terminates when the recursive term produces zero rows). The real danger is cycles in the data — a graph where node A points to B and B points back to A. The recursive term will loop indefinitely. Use the CYCLE clause (PG 14+) or a manually tracked `path` array to detect and break cycles.

---

## Gotchas

- **CTEs in PG 12+ are inlined by default — predicates push through** — this means `WHERE` conditions on the outer query can filter inside the CTE. Good for performance, but it changes behaviour if you relied on the CTE materialising its full result before the outer filter runs.

- **`MATERIALIZED` prevents predicate pushdown** — if you force materialisation, the CTE computes its full result first. An outer `WHERE` that could have pruned rows inside the CTE is applied after the fact. On large tables this can be dramatically slower than the inlined version.

- **Recursive CTEs need a termination condition** — the recursive term must eventually produce no rows. If every iteration always produces at least one row, the query runs forever. Always verify that the join condition in the recursive term converges.

- **MySQL didn't support CTEs before version 8.0** — on MySQL 5.7 or older, WITH doesn't exist at all. This breaks any code that uses CTEs when targeting MySQL compatibility.

- **Naming a CTE the same as a real table shadows it silently** — if you name a CTE `users` and there's a real `users` table, the CTE takes precedence within that query. No error. Use distinct, prefixed names (`cte_`, `staged_`, etc.).

---

## Interview Angle

**What they're really testing:** Whether you can structure a complex query clearly, and whether you understand the difference between a CTE as a readability tool versus a performance tool.

**Common question forms:**
- "Refactor this nested subquery"
- "How would you walk a tree structure in SQL?"
- "What's the difference between a CTE and a subquery?"

**The depth signal:** A junior knows CTEs exist and can write a basic WITH block. A senior explains that in PostgreSQL 12+ CTEs are inlined by default — so they don't automatically compute once — and knows that `MATERIALIZED` is needed to force single-execution. They reach for recursive CTEs for tree/graph traversal without hesitation, know that the CYCLE clause prevents infinite loops on cyclic data, and understand that predicates on the outer query push through inlined CTEs but not materialised ones. Knowing the MySQL 8.0 compatibility boundary is a practical signal of real production experience.

**Follow-up questions to expect:**
- "How does a recursive CTE know when to stop?"
- "When would you use a CTE vs a temporary table?"

---

## Related Topics

- [[databases/sql/sql-subqueries.md]] — CTEs are the readable alternative to deeply nested subqueries
- [[databases/sql/sql-window-functions.md]] — CTEs are the standard wrapper for filtering on window function results
- [[databases/sql/sql-aggregations.md]] — chained CTEs break complex aggregations into named, auditable steps
- [[databases/sql/sql-tempdb.md]] — temp tables are the persistent, indexable alternative when CTEs aren't enough
- [[databases/sql/sql-query-optimization.md]] — materialisation vs inlining directly affects CTE performance on large tables

---

## Source

https://www.postgresql.org/docs/current/queries-with.html

---
*Last updated: 2026-04-13*