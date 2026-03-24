# SQL Views

> A view is a saved SELECT query stored in the database under a name — queryable like a table, but holding no data of its own.

---

## When To Use It
Use views to give a stable, named interface to a complex query that multiple consumers need — reports, application queries, or other views that build on top of it. They're also useful for access control: expose a view to a user instead of the underlying table to hide sensitive columns. Avoid views when the underlying query is expensive and called frequently — a regular view re-executes the query every time it's hit. For that case, use a materialized view instead. Don't use views to paper over a bad schema — they hide complexity but don't fix it.

---

## Core Concept
A view is just a stored query. When you SELECT from it, the database substitutes the view's definition inline — as if you had typed that SELECT yourself. Nothing is stored except the query text. The data always comes live from the underlying tables. This means a view is always up to date, but it also means it carries the full cost of the underlying query on every access. Materialized views break this rule — they snapshot the result and store it physically, trading freshness for speed.

---

## The Code

**Create a basic view**
```sql
CREATE VIEW active_users AS
SELECT id, email, country, created_at
FROM users
WHERE is_active = true;

-- Query it like a table
SELECT * FROM active_users WHERE country = 'EG';
```

**View that joins multiple tables**
```sql
CREATE VIEW order_summary AS
SELECT
    o.id            AS order_id,
    u.email,
    u.country,
    o.total_amount,
    o.status,
    o.created_at
FROM orders o
INNER JOIN users u ON u.id = o.user_id;

-- Consumers don't need to know about the join
SELECT email, SUM(total_amount) AS total_spent
FROM order_summary
WHERE status = 'completed'
GROUP BY email
ORDER BY total_spent DESC;
```

**Replace or drop a view**
```sql
-- Replace the definition without dropping dependents first
CREATE OR REPLACE VIEW active_users AS
SELECT id, email, country, created_at, plan_type   -- added plan_type
FROM users
WHERE is_active = true;

-- Drop it entirely
DROP VIEW active_users;

-- Drop it and anything that depends on it
DROP VIEW active_users CASCADE;
```

**Updatable view — write through the view to the base table**
```sql
-- Simple views on a single table with no aggregation are often updatable
CREATE VIEW uk_users AS
SELECT id, email, country, is_active
FROM users
WHERE country = 'GB';

-- This INSERT goes directly into the users table
INSERT INTO uk_users (email, country, is_active)
VALUES ('alice@example.com', 'GB', true);

-- Add WITH CHECK OPTION to prevent inserts that would fall outside the view
CREATE OR REPLACE VIEW uk_users AS
SELECT id, email, country, is_active
FROM users
WHERE country = 'GB'
WITH CHECK OPTION;  -- blocks inserts where country != 'GB'
```

**Materialized view — snapshot the result for performance**
```sql
CREATE MATERIALIZED VIEW country_revenue AS
SELECT
    u.country,
    COUNT(DISTINCT o.id)    AS total_orders,
    SUM(o.total_amount)     AS revenue
FROM orders o
INNER JOIN users u ON u.id = o.user_id
WHERE o.status = 'completed'
GROUP BY u.country;

-- Must refresh manually — data does not update automatically
REFRESH MATERIALIZED VIEW country_revenue;

-- Refresh without locking reads (requires a unique index on the view)
REFRESH MATERIALIZED VIEW CONCURRENTLY country_revenue;
```

**Index a materialized view**
```sql
-- Materialized views can be indexed like real tables
CREATE UNIQUE INDEX ON country_revenue (country);
-- Required for CONCURRENTLY refresh, and speeds up queries against the view
```

---

## Gotchas

- **Regular views re-execute on every query** — there is no caching. If the underlying query is slow, the view is slow. A view wrapping a heavy aggregation across millions of rows will be just as slow as running that aggregation directly. Use a materialized view if the result doesn't need to be real-time.
- **`CREATE OR REPLACE VIEW` can't remove columns** — you can add columns or change expressions, but you cannot remove a column that already exists in the view definition. To do that you must DROP and recreate, which breaks any dependent objects.
- **Materialized views don't refresh automatically** — unlike regular views, materialized views hold stale data until you explicitly run `REFRESH`. If freshness matters, you need a scheduled job or a trigger to refresh on a schedule. Forgetting this is a common production mistake.
- **`REFRESH MATERIALIZED VIEW` without CONCURRENTLY locks the view** — during a non-concurrent refresh, reads against the materialized view are blocked. On a production system under load, this causes query pileups. Always use CONCURRENTLY in production — but it requires a unique index on the view first.
- **Views don't automatically pick up new base table columns** — if you `SELECT *` in a view definition and then add a column to the underlying table, the view does not see the new column until it's recreated. The `*` is expanded at view creation time, not at query time.

---

## Interview Angle
**What they're really testing:** Whether you understand the difference between a view as a query alias versus a materialized view as a physical cache — and when each one is appropriate.

**Common question form:** "What is a view and when would you use one?" or "How would you speed up a reporting query that runs every few minutes against a large table?"

**The depth signal:** A junior describes a view as "a saved query" and stops there. A senior distinguishes regular views (always fresh, always re-executed) from materialized views (stale until refreshed, but indexable and fast), knows that `REFRESH MATERIALIZED VIEW` locks reads unless CONCURRENTLY is used, and understands that CONCURRENTLY requires a unique index. They also flag the `SELECT *` expansion gotcha and know that views are primarily an abstraction and access-control tool — not a performance optimization unless materialized.

---

## Related Topics
- [[databases/sql-ctes.md]] — CTEs are the per-query alternative to views; views persist, CTEs don't
- [[databases/sql-aggregations.md]] — materialized views are the standard solution for expensive aggregations hit repeatedly
- [[databases/indexes.md]] — materialized views can be indexed; regular views cannot
- [[databases/query-optimization.md]] — understanding when the planner inlines a view vs treats it as a barrier affects performance tuning

---

## Source
https://www.postgresql.org/docs/current/sql-createview.html

---
*Last updated: 2026-03-24*