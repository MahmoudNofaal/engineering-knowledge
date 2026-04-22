# SQL Views

> A view is a saved SELECT query stored in the database under a name — queryable like a table, but holding no data of its own unless materialized.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Named saved query that acts as a virtual table |
| **Use when** | Stable abstraction over complex joins; access control; repeated complex query |
| **Avoid when** | The underlying query is expensive and called frequently — use a materialized view instead |
| **Standard** | SQL-92 (regular views); SQL:2003 (recursive views) |
| **Key variants** | Regular view, Materialized view, Updatable view, Security barrier view |
| **PostgreSQL key syntax** | `CREATE [MATERIALIZED] VIEW`, `REFRESH MATERIALIZED VIEW [CONCURRENTLY]` |

---

## When To Use It

Use views to give a stable, named interface to a complex query that multiple consumers need — reports, application queries, or other views that build on top of it. They're also the right tool for access control: expose a view to a user or role instead of the underlying table to hide sensitive columns or restrict which rows are visible. Use materialized views when the underlying query is expensive and called frequently — they snapshot the result for fast repeated access. Avoid views to paper over a bad schema — they hide complexity but don't fix it.

---

## Core Concept

A regular view is a stored query. When you SELECT from it, the database substitutes the view's definition inline — as if you had typed that SELECT yourself. Nothing is stored except the query text. The data always comes live from the underlying tables. This means the view is always up to date, but it carries the full cost of the underlying query on every access.

A materialized view breaks this rule. It computes the query once, stores the result physically like a real table, and serves subsequent queries from that stored snapshot. It's stale until you explicitly refresh it. The tradeoff is freshness vs speed. For reporting queries that run hundreds of times per minute on millions of rows, the materialized view is the architecture — not an optimisation.

---

## Version History

| Standard / Version | What changed |
|---|---|
| SQL-92 | Regular views standardized |
| PostgreSQL 9.3 | Materialized views added |
| PostgreSQL 9.4 | `REFRESH MATERIALIZED VIEW CONCURRENTLY` added |
| PostgreSQL 14 | Security invoker views added (`SECURITY INVOKER`) |
| PostgreSQL 15 | `CREATE OR REPLACE` for materialized views |

---

## Performance

| View type | Query cost | Freshness | Indexable |
|---|---|---|---|
| Regular view | Same as inline query | Always current | No (virtual) |
| Materialized view | O(1) index lookup on cached data | Stale until REFRESH | Yes |
| `REFRESH MATERIALIZED VIEW` | O(n) full recompute | Blocks reads during refresh | N/A |
| `REFRESH MATERIALIZED VIEW CONCURRENTLY` | O(n) + diff overhead | No read blocking | Requires unique index |

**Allocation behaviour:** Materialized views consume disk space proportional to their result set, just like a regular table. They also have their own visibility (MVCC) overhead. `REFRESH CONCURRENTLY` computes the new result in a temp structure, diffs it against the current snapshot, and applies the delta — slower than a full refresh but doesn't block reads.

---

## The Code

**Create a basic regular view**
```sql
CREATE VIEW active_users AS
SELECT id, email, country, created_at
FROM users
WHERE is_active = true;

-- Query like a table
SELECT * FROM active_users WHERE country = 'EG';

-- The database substitutes: SELECT * FROM (SELECT id, email, country, created_at FROM users WHERE is_active = true) WHERE country = 'EG'
```

**View joining multiple tables**
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

SELECT email, SUM(total_amount) AS total_spent
FROM order_summary
WHERE status = 'completed'
GROUP BY email
ORDER BY total_spent DESC;
```

**Replace or drop a view**
```sql
-- Add a column without breaking dependents
CREATE OR REPLACE VIEW active_users AS
SELECT id, email, country, created_at, plan_type   -- added plan_type
FROM users
WHERE is_active = true;

-- Cannot REMOVE a column with CREATE OR REPLACE — must DROP and recreate
DROP VIEW active_users;
DROP VIEW active_users CASCADE;  -- also drops dependent views
```

**Updatable view — write through the view**
```sql
-- Simple single-table views with no aggregation are usually updatable
CREATE VIEW uk_users AS
SELECT id, email, country, is_active
FROM users
WHERE country = 'GB';

INSERT INTO uk_users (email, country, is_active)
VALUES ('alice@example.com', 'GB', true);   -- goes into users table

-- WITH CHECK OPTION: prevent writes that violate the view's WHERE condition
CREATE OR REPLACE VIEW uk_users AS
SELECT id, email, country, is_active
FROM users
WHERE country = 'GB'
WITH CHECK OPTION;  -- INSERT of country != 'GB' now raises an error
```

**Security barrier view — prevent filter pushdown for row-level security**
```sql
-- WITHOUT SECURITY_BARRIER: the planner can push outer WHERE into the view definition,
-- potentially exposing data the view was meant to hide via error messages or timing attacks

CREATE VIEW user_orders AS
SELECT o.*
FROM orders o
WHERE o.user_id = current_setting('app.current_user_id')::INTEGER
WITH (security_barrier = true);
-- SECURITY_BARRIER prevents the planner from running outer WHERE conditions
-- before the view's own WHERE — correct for row-level security use cases
```

**Security invoker view (PostgreSQL 14+)**
```sql
-- Default: SECURITY DEFINER — view runs with the OWNER's permissions
-- SECURITY INVOKER: view runs with the calling user's permissions
CREATE VIEW sensitive_report
WITH (security_invoker = true)
AS
SELECT customer_id, SUM(amount) AS total
FROM payments
GROUP BY customer_id;
-- Now the caller must have SELECT on payments themselves — not just the view
```

**Materialized view — snapshot for performance**
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

-- Must refresh manually — never auto-updates
REFRESH MATERIALIZED VIEW country_revenue;

-- Non-blocking refresh (requires a unique index on the view)
REFRESH MATERIALIZED VIEW CONCURRENTLY country_revenue;
```

**Index a materialized view**
```sql
-- Required for CONCURRENTLY refresh; also speeds queries against the view
CREATE UNIQUE INDEX ON country_revenue (country);
CREATE INDEX ON country_revenue (revenue DESC);  -- support ORDER BY revenue queries
```

---

## Real World Example

A multi-tenant analytics platform needs to expose per-tenant dashboard data. Each tenant should only see their own data. Using a security-barrier view with `current_setting` eliminates per-tenant schema proliferation while ensuring row-level isolation at the database layer.

```sql
-- Set tenant context at the start of each connection/session
-- (done by the application connection setup)
-- SET app.tenant_id = '42';

-- Security barrier view: tenant-filtered, planner cannot bypass the WHERE
CREATE VIEW tenant_events
WITH (security_barrier = true)
AS
SELECT
    id,
    event_type,
    user_id,
    properties,
    occurred_at
FROM events
WHERE tenant_id = current_setting('app.tenant_id', true)::INTEGER;

-- Materialized view for the expensive weekly summary
-- (refreshed by a scheduled job, not real-time)
CREATE MATERIALIZED VIEW weekly_event_summary AS
SELECT
    tenant_id,
    DATE_TRUNC('week', occurred_at)    AS week_start,
    event_type,
    COUNT(*)                            AS event_count,
    COUNT(DISTINCT user_id)             AS unique_users
FROM events
WHERE occurred_at >= NOW() - INTERVAL '90 days'
GROUP BY tenant_id, DATE_TRUNC('week', occurred_at), event_type;

CREATE UNIQUE INDEX ON weekly_event_summary (tenant_id, week_start, event_type);

-- Refresh on a schedule (pg_cron or external scheduler)
REFRESH MATERIALIZED VIEW CONCURRENTLY weekly_event_summary;
```

*The key insight: the security barrier view handles real-time tenant isolation at the row level with zero application-layer enforcement. The materialized view handles the expensive weekly aggregation — computed once for all tenants, refreshed on a schedule, queried instantly by individual tenant ID via the unique index.*

---

## Common Misconceptions

**"Regular views cache their results between queries"**
They don't. A regular view re-executes its underlying query every time it's accessed. There is no caching. If the underlying query takes 5 seconds, the view takes 5 seconds. Materialized views are the cached version — regular views are purely a readability and abstraction layer.

**"`CREATE OR REPLACE VIEW` can change anything"**
You can add columns and change expressions, but you cannot remove a column that already exists in the view definition. To remove a column you must DROP the view and recreate it — which breaks any dependent objects (other views, functions, queries stored in application code). This is why adding extra columns to views is a common backward-compatible choice.

**"Materialized views update automatically"**
They never update automatically in PostgreSQL unless you schedule the refresh yourself. A common architecture is a pg_cron job running `REFRESH MATERIALIZED VIEW CONCURRENTLY view_name` on a schedule appropriate to your freshness requirements (hourly, daily, after each batch job).

---

## Gotchas

- **Regular views re-execute on every query** — there is no caching. A view wrapping a heavy aggregation across millions of rows will be just as slow as running that aggregation directly. Use a materialized view if the result doesn't need to be real-time.

- **`REFRESH MATERIALIZED VIEW` without CONCURRENTLY blocks all reads** — during a non-concurrent refresh, every SELECT against the materialized view is blocked. On a production system this causes query pileups. Always use CONCURRENTLY in production — but it requires a unique index on the view first.

- **Materialized views are not automatically refreshed** — data goes stale after your source tables change. If freshness matters, build a refresh mechanism. Triggering REFRESH after a batch job completes is a common pattern.

- **`SELECT *` in a view doesn't pick up new base table columns** — the `*` is expanded at view creation time, not at query time. If you add a column to the underlying table, the view doesn't see it until you recreate it.

- **Security invoker vs security definer matters for row security** — by default, views run with the owner's permissions. If you create a view on a table you own and grant SELECT on the view to another role, that role can read rows through the view even if they couldn't read the table directly. `SECURITY INVOKER` flips this — the caller's permissions are checked. Know which you need.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between a view as a query alias versus a materialized view as a physical cache — and when each is appropriate.

**Common question forms:**
- "What is a view and when would you use one?"
- "How would you speed up a reporting query that runs every few minutes against a large table?"
- "What's the difference between a view and a materialized view?"

**The depth signal:** A junior describes a view as "a saved query" and stops there. A senior distinguishes regular views (always fresh, always re-executed) from materialized views (stale until refreshed, but indexable and fast), knows that `REFRESH MATERIALIZED VIEW` blocks reads unless CONCURRENTLY is used, and that CONCURRENTLY requires a unique index. They also flag the `SELECT *` expansion gotcha, know that CREATE OR REPLACE can't remove columns, and understand the security invoker/definer distinction for row-level security patterns.

**Follow-up questions to expect:**
- "How would you schedule a materialized view refresh?"
- "Can you INSERT into a view? What are the rules?"

---

## Related Topics

- [[databases/sql/sql-ctes.md]] — CTEs are per-query equivalents; views persist across queries
- [[databases/sql/sql-aggregations.md]] — materialized views are the standard solution for expensive repeated aggregations
- [[databases/sql/sql-indexing.md]] — materialized views can be indexed; regular views cannot
- [[databases/sql/sql-query-optimization.md]] — understanding when the planner inlines a view affects performance tuning

---

## Source

https://www.postgresql.org/docs/current/sql-createview.html

---
*Last updated: 2026-04-13*