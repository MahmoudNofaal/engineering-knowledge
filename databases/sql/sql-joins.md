# SQL Joins

> A JOIN combines rows from two or more tables based on a related column, producing a new result set shaped by which rows match and which join type you use.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Multi-table row combination by matching condition |
| **Use when** | Answer requires columns from more than one table |
| **Avoid when** | Tables are enormous and join is consistently slow — consider denormalization |
| **Standard** | SQL-92 (JOIN syntax); LATERAL in SQL:1999 |
| **Key types** | `INNER`, `LEFT`, `RIGHT`, `FULL OUTER`, `CROSS`, `SELF`, `LATERAL` |
| **Performance trap** | Missing index on JOIN column → full table scan per outer row |

---

## When To Use It

Use joins whenever your answer lives across more than one table — orders + users, products + categories, employees + departments. Relational databases are designed for this. Avoid pulling data into application code and joining it manually — that's slower, harder to read, and moves work away from the engine that's optimized for it. The exception: if tables are enormous and the join is consistently slow after proper indexing, denormalization or caching may be the right call. Don't reach for a join when EXISTS is the right tool — if you only need to check whether a related row exists, not retrieve its columns, EXISTS is faster and clearer.

---

## Core Concept

Every join starts with a left table and a right table. The ON clause defines the condition that links them — usually a foreign key matching a primary key. The join *type* controls what happens when there's no match on one side. INNER keeps only matched rows. LEFT keeps all rows from the left table and fills NULLs where the right side has nothing. RIGHT is the mirror of LEFT. FULL OUTER keeps everything from both sides with NULLs wherever there's no match. CROSS produces every combination of rows from both tables — a Cartesian product.

The most important thing to internalize: a join multiplies rows when the relationship is one-to-many. Joining a user to their orders gives you one row *per order*, not per user. This is correct behaviour, not a bug, but forgetting it leads to inflated counts in aggregations.

---

## Version History

| SQL Standard | What changed |
|---|---|
| Pre-SQL-92 | Joins written as comma-separated FROM with WHERE conditions (implicit syntax) |
| SQL-92 | Explicit JOIN syntax standardized — INNER, LEFT, RIGHT, FULL OUTER, CROSS |
| SQL:1999 | LATERAL joins introduced — subquery can reference preceding FROM items |
| SQL:2003 | NATURAL JOIN and JOIN USING improved in standard |
| PostgreSQL 9.3 | LATERAL fully supported |
| MySQL 8.0 | LATERAL joins added (2018) |

*The old implicit syntax (`FROM a, b WHERE a.id = b.a_id`) still works everywhere but is considered bad practice — it's easy to accidentally produce a Cartesian product by forgetting the WHERE condition.*

---

## Performance

| Join type | Complexity | Notes |
|---|---|---|
| Nested loop (small outer) | O(n × log m) | With index on inner join column; best for small result sets |
| Nested loop (no index) | O(n × m) | Full scan of inner table per outer row — catastrophic at scale |
| Hash join | O(n + m) | Hashes smaller table into memory; best for large unsorted sets |
| Merge join | O(n log n + m log m) | Sorts both sides then merges; best when both sides pre-sorted |
| CROSS JOIN | O(n × m) | Always a full product — use deliberately, never accidentally |

**Allocation behaviour:** Hash joins allocate memory for the hash table (controlled by `work_mem` in PostgreSQL). If the hash table exceeds `work_mem`, it spills to disk — a 10–100× slowdown. For very large joins, increasing `work_mem` per session is sometimes the right fix.

**Benchmark notes:** The planner picks join strategy based on table size estimates. A wrong estimate (from stale statistics) can cause a hash join to be chosen when a nested loop with an index would be faster, or vice versa. Run `ANALYZE` on both tables if the chosen strategy looks wrong.

---

## The Code

**INNER JOIN — only matched rows from both tables**
```sql
SELECT
    o.id       AS order_id,
    u.email,
    o.total_amount
FROM orders o
INNER JOIN users u ON u.id = o.user_id;
-- Rows where o.user_id has no match in users are dropped entirely
```

**LEFT JOIN — all left rows, NULLs where right has no match**
```sql
SELECT
    u.id,
    u.email,
    o.id AS order_id    -- NULL if the user has never ordered
FROM users u
LEFT JOIN orders o ON o.user_id = u.id;
```

**LEFT JOIN anti-join — find unmatched rows**
```sql
-- Users who have never placed an order
SELECT u.id, u.email
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE o.id IS NULL;
-- The WHERE on the right-side column filters to only the NULL (unmatched) rows
```

**FULL OUTER JOIN — all rows from both sides**
```sql
SELECT
    u.email,
    o.id AS order_id
FROM users u
FULL OUTER JOIN orders o ON o.user_id = u.id;
-- NULLs on whichever side has no match
-- Not supported in MySQL — emulate with UNION of LEFT and RIGHT joins
```

**CROSS JOIN — every combination (Cartesian product)**
```sql
-- Generate all possible size/colour combinations for a product
SELECT s.name AS size, c.name AS colour
FROM sizes s
CROSS JOIN colours c;
-- 5 sizes × 8 colours = 40 rows — use deliberately, never accidentally
```

**Self JOIN — join a table to itself**
```sql
-- Find employees and their manager's name (both live in the same table)
SELECT
    e.name   AS employee,
    m.name   AS manager
FROM employees e
LEFT JOIN employees m ON m.id = e.manager_id;
-- LEFT JOIN so employees with no manager (the CEO) still appear
```

**Multi-table join**
```sql
SELECT
    u.email,
    o.id          AS order_id,
    p.name        AS product_name,
    oi.quantity
FROM orders o
INNER JOIN users u        ON u.id = o.user_id
INNER JOIN order_items oi ON oi.order_id = o.id
INNER JOIN products p     ON p.id = oi.product_id
WHERE o.status = 'completed';
```

**LATERAL JOIN — subquery that references preceding table**
```sql
-- For each user, get their 3 most recent orders (PostgreSQL / SQL:1999)
SELECT u.id, u.email, recent.id AS order_id, recent.created_at
FROM users u
CROSS JOIN LATERAL (
    SELECT id, created_at
    FROM orders o
    WHERE o.user_id = u.id          -- references u from the outer FROM
    ORDER BY created_at DESC
    LIMIT 3
) recent;
-- LATERAL allows the subquery to see u — a regular subquery cannot
```

**Filtering on the right side — the gotcha**
```sql
-- BAD: WHERE on right-side column converts LEFT JOIN to INNER JOIN
SELECT u.id, u.email, o.id AS order_id
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE o.status = 'completed';   -- drops all users with no orders (NULLs fail the filter)

-- GOOD: filter inside ON clause keeps unmatched left rows
SELECT u.id, u.email, o.id AS order_id
FROM users u
LEFT JOIN orders o ON o.user_id = u.id AND o.status = 'completed';
-- Users with no completed orders still appear — o.id is NULL for them
```

---

## Real World Example

A reporting service needs to show every sales rep alongside their total closed revenue this quarter — including reps with zero deals closed, so managers can see who isn't converting. A naive INNER JOIN would silently drop reps with no deals.

```sql
WITH this_quarter_deals AS (
    SELECT
        d.owner_id,
        SUM(d.amount)    AS closed_revenue,
        COUNT(d.id)      AS deal_count
    FROM deals d
    WHERE d.stage     = 'closed_won'
      AND d.closed_at >= DATE_TRUNC('quarter', NOW())
      AND d.closed_at  < DATE_TRUNC('quarter', NOW()) + INTERVAL '3 months'
    GROUP BY d.owner_id
)
SELECT
    u.id,
    u.full_name,
    u.team,
    COALESCE(q.closed_revenue, 0)  AS closed_revenue,
    COALESCE(q.deal_count, 0)      AS deal_count
FROM users u
LEFT JOIN this_quarter_deals q ON q.owner_id = u.id
WHERE u.role = 'sales_rep'
  AND u.is_active = true
ORDER BY closed_revenue DESC;
```

*The key insight: the CTE aggregates deals first so the LEFT JOIN produces one row per rep — not one row per deal. COALESCE converts NULLs (reps with zero deals) to 0, making the result safe for display and sorting.*

---

## Common Misconceptions

**"RIGHT JOIN is just a syntax preference — use whichever reads more naturally"**
In practice, RIGHT JOIN signals a design smell. Almost any RIGHT JOIN can be rewritten as a LEFT JOIN by swapping table order, and LEFT JOIN is what readers expect. If you reach for RIGHT JOIN, consider whether you've ordered your tables wrong. Code reviewers will often flag it.

**"NATURAL JOIN is a safe shortcut"**
NATURAL JOIN automatically joins on all columns with matching names — no ON clause needed. It's a trap. When a new column is added to either table that happens to share a name with a column in the other (like `created_at`, `id`, `name`), the join condition changes silently. Never use NATURAL JOIN in production code.

```sql
-- Dangerous: if both tables gain a 'status' column, this query breaks silently
SELECT * FROM orders NATURAL JOIN users;

-- Safe: explicit is always correct
SELECT * FROM orders o INNER JOIN users u ON u.id = o.user_id;
```

**"A join that returns more rows than expected is a bug"**
It's expected behaviour when the relationship is one-to-many. Joining users to orders returns one row per order. If you want one row per user, aggregate before joining or use a window function. The join itself is correct — your mental model of the result shape was off.

---

## Gotchas

- **Filtering on the right table in a LEFT JOIN kills it** — `WHERE right.column = 'x'` silently converts your LEFT JOIN to an INNER JOIN because NULLs fail the filter. Move that condition into the `ON` clause to keep unmatched left rows.

- **Cartesian product from a missing ON clause** — `FROM a, b` without a WHERE condition, or `FROM a CROSS JOIN b` without meaning to, matches every row in `a` against every row in `b`. On large tables this silently returns millions of rows.

- **Duplicate rows from one-to-many joins inflate aggregates** — joining users (1) to orders (many) then doing `SUM(o.total)` gives you the correct sum per user. But joining users to orders to order_items creates multiple copies of the order row — one per item — and `SUM(o.total)` will double/triple-count. Aggregate at the right level before joining.

- **Missing index on the JOIN column** — the join column on the inner table (the right-side table in a nested loop) must be indexed or every outer row causes a full scan of the inner table. Foreign key columns are the most commonly missed index opportunity.

- **FULL OUTER JOIN not supported in MySQL** — MySQL and some older MariaDB versions don't implement FULL OUTER JOIN. Emulate it: `LEFT JOIN UNION ALL RIGHT JOIN WHERE left.id IS NULL`.

---

## Interview Angle

**What they're really testing:** Whether you understand *what each join type produces* — not just the syntax — and whether you can reason about row counts, NULLs, and aggregation across joined sets.

**Common question forms:**
- "What's the difference between INNER JOIN and LEFT JOIN?"
- "Write a query to find all products that have never been ordered"
- "Why does this COUNT query return a higher number than expected?"

**The depth signal:** A junior recites definitions and draws a Venn diagram. A senior explains the anti-join pattern (LEFT JOIN + WHERE right.id IS NULL), knows that putting a filter in WHERE vs ON produces different results on outer joins, can explain why one-to-many joins multiply rows and how that inflates aggregates, and knows FULL OUTER JOIN doesn't exist in MySQL. The strongest seniors bring up LATERAL without being asked when the topic is "get the top N per group."

**Follow-up questions to expect:**
- "How would you get the most recent order for each user efficiently?"
- "What does the planner choose — nested loop, hash join, or merge join — and when?"

---

## Related Topics

- [[databases/sql/sql-basics.md]] — SELECT, WHERE, and GROUP BY mechanics that wrap every join
- [[databases/sql/sql-aggregations.md]] — one-to-many joins require aggregation awareness to avoid double-counting
- [[databases/sql/sql-subqueries.md]] — EXISTS is often the right tool when you only need to check existence, not retrieve columns
- [[databases/sql/sql-indexing.md]] — join columns must be indexed or joins become full table scans
- [[databases/sql/sql-null-handling.md]] — NULLs from outer joins affect WHERE, aggregates, and CASE expressions

---

## Source

https://www.postgresql.org/docs/current/queries-table-expressions.html

---
*Last updated: 2026-04-13*