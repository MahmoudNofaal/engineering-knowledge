# SQL Basics

> SQL (Structured Query Language) is the standard language for querying and manipulating data stored in relational databases.

---

## When To Use It
Use SQL whenever your data has clear relationships, needs strong consistency, or requires complex filtering, aggregation, or joins across structured tables. It's the default choice for transactional systems (e-commerce, finance, user accounts). Avoid it when your data is unstructured, schema-less, or when you need horizontal write scaling at massive throughput — that's where NoSQL wins.

---

## Core Concept
A relational database stores data in tables — rows and columns, like a spreadsheet, but with strict rules. SQL lets you ask questions against those tables: give me all users who signed up last month, sum the revenue by region, find orders that don't have a matching shipment. The engine figures out *how* to get the data; you just describe *what* you want. The four operations you'll use 95% of the time are SELECT, INSERT, UPDATE, and DELETE — everything else builds on top of those.

---

## The Code

**Basic SELECT with filtering and sorting**
```sql
SELECT first_name, last_name, email
FROM users
WHERE created_at >= '2024-01-01'
  AND is_active = true
ORDER BY created_at DESC
LIMIT 50;
```

**Aggregation with GROUP BY**
```sql
SELECT 
    country,
    COUNT(*)         AS total_users,
    AVG(age)         AS avg_age
FROM users
WHERE is_active = true
GROUP BY country
HAVING COUNT(*) > 100   -- filters on the aggregated result, not the raw rows
ORDER BY total_users DESC;
```

**INNER JOIN across two tables**
```sql
SELECT 
    o.id         AS order_id,
    u.email,
    o.total_amount
FROM orders o
INNER JOIN users u ON u.id = o.user_id
WHERE o.status = 'pending'
  AND o.created_at >= NOW() - INTERVAL '7 days';
```

**LEFT JOIN to find missing relationships**
```sql
-- Find users who have never placed an order
SELECT u.id, u.email
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE o.id IS NULL;
```

**INSERT, UPDATE, DELETE**
```sql
-- Insert
INSERT INTO users (first_name, email, created_at)
VALUES ('Ahmed', 'ahmed@example.com', NOW());

-- Update
UPDATE users
SET is_active = false
WHERE last_login_at < NOW() - INTERVAL '90 days';

-- Delete
DELETE FROM sessions
WHERE expires_at < NOW();
```

---

## Gotchas

- **`WHERE` runs before `HAVING`** — you can't filter on an aggregated column (like `COUNT(*)`) using `WHERE`. That's what `HAVING` is for. Mixing these up silently returns wrong results.
- **`NULL` comparisons always fail with `=`** — `WHERE deleted_at = NULL` returns nothing. You must use `IS NULL` or `IS NOT NULL`. This trips up everyone at least once.
- **`LEFT JOIN` + `WHERE` on the right table converts it to an `INNER JOIN`** — if you filter `WHERE right_table.column = 'x'` after a LEFT JOIN, rows with no match (which would be NULL) get dropped. Put that filter in the `ON` clause instead.
- **`COUNT(*)` vs `COUNT(column)`** — `COUNT(*)` counts all rows including NULLs. `COUNT(column)` only counts non-NULL values in that column. Subtle difference that produces different numbers with no error.
- **`LIMIT` without `ORDER BY` is non-deterministic** — the database can return any 50 rows it feels like. Always pair `LIMIT` with an explicit `ORDER BY` if result order matters.

---

## Interview Angle
**What they're really testing:** Whether you understand how the database *executes* your query — not just whether you can write one.

**Common question form:** "Write a query to find the top 3 products by revenue per category" — or any variation of join + aggregate + rank.

**The depth signal:** A junior writes a query that works on the happy path. A senior thinks about NULLs, index usage, whether `HAVING` vs `WHERE` is correct, and what happens with ties in a `LIMIT` scenario. Seniors also know that `SELECT *` in production is a problem — it breaks when columns are added or reordered, and it pulls more data than needed. They'll also mention execution plans (`EXPLAIN ANALYZE`) when talking about a slow query.

---

## Related Topics
- [[databases/indexes.md]] — SQL queries are only fast when indexes back your WHERE and JOIN columns
- [[databases/joins-deep-dive.md]] — INNER vs LEFT vs RIGHT vs FULL OUTER, and when each one applies
- [[databases/transactions-and-acid.md]] — how INSERT/UPDATE/DELETE behave when combined inside a transaction
- [[databases/query-optimization.md]] — what the query planner does and how to read EXPLAIN output

---

## Source
https://www.postgresql.org/docs/current/sql.html

---
*Last updated: 2026-03-24*