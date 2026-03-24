# SQL Joins

> A JOIN combines rows from two or more tables based on a related column between them.

---

## When To Use It
Use joins whenever your answer lives across more than one table — orders + users, products + categories, employees + departments. Relational databases are designed for this. Avoid pulling data into application code and joining it manually — that's slower, harder to read, and moves work away from the engine that's optimized for it. The exception: if tables are enormous and the join is consistently slow, denormalization or caching may be the right call.

---

## Core Concept
Every join starts with a left table and a right table. The `ON` clause defines the condition that links them — usually a foreign key matching a primary key. The join *type* controls what happens when there's no match on one side. INNER keeps only matched rows. LEFT keeps all rows from the left table and fills NULLs where the right side has nothing. RIGHT is the mirror of that. FULL OUTER keeps everything from both sides. Most of what you'll write day-to-day is INNER JOIN and LEFT JOIN — get those two sharp and the others follow naturally.

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

**LEFT JOIN to find unmatched rows (anti-join pattern)**
```sql
-- Users who have never placed an order
SELECT u.id, u.email
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE o.id IS NULL;
```

**FULL OUTER JOIN — all rows from both sides**
```sql
-- All users and all orders, matched where possible
SELECT 
    u.email,
    o.id AS order_id
FROM users u
FULL OUTER JOIN orders o ON o.user_id = u.id;
-- NULLs appear on whichever side has no match
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

**Self JOIN — joining a table to itself**
```sql
-- Find employees and their manager's name (both rows live in the same table)
SELECT 
    e.name   AS employee,
    m.name   AS manager
FROM employees e
LEFT JOIN employees m ON m.id = e.manager_id;
-- LEFT JOIN so employees with no manager (CEO) still appear
```

---

## Gotchas

- **Filtering on the right table in a LEFT JOIN kills it** — `WHERE right.column = 'x'` silently converts your LEFT JOIN into an INNER JOIN because NULL rows fail the filter. Move that condition into the `ON` clause to keep unmatched left rows.
- **JOIN order affects readability, not always correctness** — the query planner may reorder joins internally, but writing them in a logical sequence (start with your primary table, join outward) makes the query far easier to debug.
- **Cartesian product from a missing ON clause** — if you write `FROM a, b` or forget the `ON`, you get every row in `a` matched with every row in `b`. On large tables this silently returns millions of rows and destroys performance.
- **Duplicate rows from one-to-many joins** — joining a user to their orders gives you one row *per order*, not per user. Aggregating before joining (or using a subquery) is often the right fix when you only want one row per left-side entity.
- **FULL OUTER JOIN is not supported in MySQL** — MySQL (and older MariaDB) don't implement `FULL OUTER JOIN`. You have to emulate it with a `UNION` of a LEFT JOIN and a RIGHT JOIN.

---

## Interview Angle
**What they're really testing:** Whether you understand *why* different join types exist — not just the syntax, but what the engine actually produces.

**Common question form:** "What's the difference between INNER JOIN and LEFT JOIN?" or "Write a query to find records in table A that don't exist in table B."

**The depth signal:** A junior recites definitions and maybe draws a Venn diagram. A senior explains the anti-join pattern (LEFT JOIN + WHERE right.id IS NULL), knows that putting a filter in `WHERE` vs `ON` produces different results on outer joins, and can reason about what happens to row counts when joining across one-to-many relationships. Bonus depth: mentioning that FULL OUTER JOIN doesn't exist in MySQL, or that EXISTS is sometimes a better tool than a join for existence checks.

---

## Related Topics
- [[databases/sql-basics.md]] — the SELECT, WHERE, and GROUP BY mechanics that wrap around every join
- [[databases/indexes.md]] — join columns (especially foreign keys) must be indexed or joins become full table scans
- [[databases/query-optimization.md]] — how to read EXPLAIN output and spot when a join is doing more work than it should
- [[databases/transactions-and-acid.md]] — joins inside transactions and how locking interacts with multi-table reads

---

## Source
https://www.postgresql.org/docs/current/queries-table-expressions.html

---
*Last updated: 2026-03-24*