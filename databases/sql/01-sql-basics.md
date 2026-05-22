# SQL Basics

> SQL (Structured Query Language) is the standard language for querying and manipulating data stored in relational databases.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Declarative language for relational data |
| **Use when** | Structured data, strong consistency, complex filtering |
| **Avoid when** | Unstructured data, massive horizontal write throughput |
| **Standard** | SQL:2023 (ISO/IEC 9075) |
| **Namespace** | N/A — language-level, not library |
| **Key clauses** | `SELECT`, `FROM`, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`, `LIMIT` |

---

## When To Use It

Use SQL whenever your data has clear relationships, needs strong consistency, or requires complex filtering, aggregation, or joins across structured tables. It's the default choice for transactional systems — e-commerce, finance, user accounts. Avoid it when your data is unstructured, schema-less, or when you need horizontal write scaling at massive throughput — that's where NoSQL wins. SQL is a 50-year-old standard; every relational database speaks it, but each has its own dialect extensions that don't port cleanly.

---

## Core Concept

A relational database stores data in tables — rows and columns, like a spreadsheet, but with strict schema rules. SQL lets you ask questions against those tables: give me all users who signed up last month, sum the revenue by region, find orders that don't have a matching shipment. The engine figures out *how* to get the data; you just describe *what* you want. This is the declarative model — you specify the result shape, not the retrieval steps.

The four operations you'll use 95% of the time are SELECT, INSERT, UPDATE, and DELETE (CRUD). Everything else — joins, aggregations, subqueries, CTEs, window functions — is layered on top of SELECT. The mental model that matters: SQL executes in a specific logical order that differs from how you write it. Writing order is SELECT → FROM → WHERE → GROUP BY → HAVING → ORDER BY. Execution order is FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT. That gap is the source of most beginner mistakes.

---

## Version History

| SQL Standard | What changed |
|---|---|
| SQL-86 | Original ANSI standard — basic SELECT, INSERT, UPDATE, DELETE |
| SQL-92 | JOINs formalized, CASE expressions, CAST, string functions |
| SQL:1999 | CTEs (WITH), recursive queries, OLAP functions introduced |
| SQL:2003 | Window functions, MERGE, XML support |
| SQL:2008 | TRUNCATE, FETCH FIRST (standard LIMIT) |
| SQL:2011 | Temporal tables (system-versioned) |
| SQL:2016 | JSON support standardized |
| SQL:2023 | Property graph queries, improved JSON, UNIQUE NULLS NOT DISTINCT |

*PostgreSQL tracks standard compliance closely. MySQL historically lagged (window functions only in 8.0, CTEs in 8.0). SQL Server has good standard coverage but with T-SQL extensions.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Full table scan (no index) | O(n) | Reads every page; unavoidable without an index |
| Point lookup (indexed) | O(log n) | B-tree traversal to matching row(s) |
| Range scan (indexed) | O(log n + k) | B-tree seek + k sequential reads |
| Sort (no pre-sorted index) | O(n log n) | In-memory if fits work_mem, spills to disk otherwise |
| Hash join | O(n + m) | Hashes smaller table; probes with larger |
| Nested loop join | O(n × m) | Fine for small outer; catastrophic at scale without index on inner |

**Allocation behaviour:** SQL queries operate on pages (8KB in PostgreSQL). The planner estimates how many pages to read. Everything goes through the shared buffer cache first; cache misses cause disk reads, which are 10–100× slower.

**Benchmark notes:** On tables under ~10,000 rows the performance difference between a sequential scan and an index scan is often negligible — the planner may even prefer the seq scan. Indexes start paying for themselves meaningfully above ~50,000 rows for selective queries.

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

**Aggregation with GROUP BY and HAVING**
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

**LEFT JOIN to find missing relationships (anti-join)**
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

-- Update with a condition
UPDATE users
SET is_active = false
WHERE last_login_at < NOW() - INTERVAL '90 days';

-- Targeted delete
DELETE FROM sessions
WHERE expires_at < NOW();
```

**CASE expression — conditional value in SELECT**
```sql
SELECT
    id,
    total_amount,
    CASE
        WHEN total_amount >= 1000 THEN 'high'
        WHEN total_amount >= 100  THEN 'medium'
        ELSE 'low'
    END AS order_tier
FROM orders;
```

**The wrong way — and the fix**
```sql
-- BAD: WHERE on an aggregated column — syntax error
SELECT country, COUNT(*) AS total
FROM users
WHERE COUNT(*) > 100   -- ERROR: aggregate not allowed in WHERE
GROUP BY country;

-- GOOD: HAVING filters after aggregation
SELECT country, COUNT(*) AS total
FROM users
GROUP BY country
HAVING COUNT(*) > 100;
```

---

## Real World Example

A SaaS platform needs a dashboard query: for each active subscription plan, show total subscribers, average account age in days, and monthly recurring revenue — but only for plans with more than 50 active subscribers, sorted by MRR descending.

```sql
SELECT
    p.name                                          AS plan_name,
    COUNT(s.id)                                     AS active_subscribers,
    ROUND(AVG(EXTRACT(DAY FROM NOW() - u.created_at)))  AS avg_account_age_days,
    SUM(p.monthly_price)                            AS mrr
FROM subscriptions s
INNER JOIN users u        ON u.id = s.user_id
INNER JOIN plans p        ON p.id = s.plan_id
WHERE s.status    = 'active'
  AND s.cancelled_at IS NULL
  AND u.is_active  = true
GROUP BY p.id, p.name, p.monthly_price
HAVING COUNT(s.id) > 50
ORDER BY mrr DESC;
```

*The key insight here is that three concerns layer cleanly: join conditions wire the tables together (ON clauses), row-level filters narrow the dataset before grouping (WHERE), and group-level filters narrow the result after grouping (HAVING) — each doing the job it was designed for, in the order the engine actually executes them.*

---

## Common Misconceptions

**"SELECT \* is fine for quick queries"**
In production, `SELECT *` is a liability. It breaks when columns are added or reordered, pulls more data across the network than needed, and prevents the planner from using index-only scans. Always name columns explicitly in code that runs in production.

**"WHERE and HAVING are interchangeable — just pick one"**
They filter at different stages. WHERE runs before grouping and can't see aggregate values. HAVING runs after grouping and can filter on COUNT, SUM, etc. Using HAVING where WHERE belongs forces the engine to group all rows before filtering — unnecessary work on large tables.

```sql
-- Slow: groups all rows, then discards inactive ones
SELECT country, COUNT(*) FROM users
GROUP BY country
HAVING is_active = true;  -- WRONG — is_active is a row value, not an aggregate

-- Fast: filters rows before grouping
SELECT country, COUNT(*) FROM users
WHERE is_active = true     -- RIGHT
GROUP BY country;
```

**"ORDER BY guarantees a stable sort for ties"**
SQL makes no guarantee about row order for tied values unless every tie-breaking column is explicitly included in ORDER BY. Two identical queries can return rows in different orders across executions. If deterministic pagination matters, include a unique column (usually `id`) as the final ORDER BY term.

---

## Gotchas

- **`WHERE` runs before `HAVING`** — you can't filter on an aggregated column (like `COUNT(*)`) using `WHERE`. That's what `HAVING` is for. Mixing these up silently returns wrong results or throws an error.

- **`NULL` comparisons always fail with `=`** — `WHERE deleted_at = NULL` returns nothing. You must use `IS NULL` or `IS NOT NULL`. NULL represents "unknown" — comparing unknown to anything, including another NULL, evaluates to NULL (not true or false), and NULL rows are dropped from results.

- **`LEFT JOIN` + `WHERE` on the right table converts it to an `INNER JOIN`** — if you filter `WHERE right_table.column = 'x'` after a LEFT JOIN, rows with no match (which would be NULL) get dropped. Put that filter in the `ON` clause instead if you want to keep unmatched left rows.

- **`COUNT(*)` vs `COUNT(column)`** — `COUNT(*)` counts all rows including NULLs. `COUNT(column)` counts only non-NULL values in that column. Same query, different number, no error — a silent data correctness bug.

- **`LIMIT` without `ORDER BY` is non-deterministic** — the database can return any rows it wants. Always pair `LIMIT` with an explicit `ORDER BY` if result order or pagination correctness matters.

- **String comparison is case-sensitive in PostgreSQL** — `WHERE email = 'Ahmed@Example.com'` won't match `'ahmed@example.com'`. Use `lower()` on both sides, or `ILIKE` for pattern matching. MySQL's default collation is case-insensitive, which creates portability traps.

---

## Interview Angle

**What they're really testing:** Whether you understand how the database *executes* your query — the logical execution order — not just whether you can write one that looks right.

**Common question forms:**
- "Why can't I use a WHERE clause to filter on a COUNT?"
- "Write a query to find customers with more than 5 orders in the last 30 days"
- "What's the difference between WHERE and HAVING?"

**The depth signal:** A junior writes a query that works on the happy path. A senior thinks about NULLs, understands the logical execution order (FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY), knows that `SELECT *` in production is a problem, and reaches for HAVING vs WHERE correctly without hesitation. They'll also mention execution plans (`EXPLAIN ANALYZE`) when talking about a slow query — not as a reflex, but because they know the plan is the ground truth.

**Follow-up questions to expect:**
- "What happens if a GROUP BY column is NULL — does it get its own group?"
- "How would you rewrite that query if the table had 500 million rows?"

---

## Related Topics

- [[databases/sql/sql-joins.md]] — SQL queries are only useful when you can combine tables; joins are the primary tool
- [[databases/sql/sql-aggregations.md]] — GROUP BY and HAVING are the aggregation layer on top of basic SELECT
- [[databases/sql/sql-indexing.md]] — SQL queries are only fast when indexes back your WHERE and JOIN columns
- [[databases/sql/sql-null-handling.md]] — NULL behaviour touches every clause; deserves its own deep dive
- [[databases/sql/sql-execution-plans.md]] — EXPLAIN ANALYZE is how you verify what your query is actually doing

---

## Source

https://www.postgresql.org/docs/current/sql.html

---
*Last updated: 2026-04-13*