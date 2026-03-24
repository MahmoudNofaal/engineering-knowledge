# Denormalization

> Denormalization is the deliberate introduction of redundancy into a schema to improve read performance — trading data consistency guarantees for query speed.

---

## When To Use It
Reach for denormalization when profiling proves that joins or aggregations are the bottleneck, not before. It's appropriate for read-heavy workloads where query speed matters more than write simplicity — reporting tables, analytics pipelines, dashboards, and search indexes. Avoid it in transactional systems where consistency is critical and writes are frequent — the synchronization burden compounds quickly. Denormalization is always a conscious tradeoff, not a shortcut. If you haven't measured the performance problem, you haven't earned the denormalization.

---

## Core Concept
A fully normalized schema stores every fact once. Denormalization stores some facts more than once, in a shape that answers specific queries faster. The benefit is fewer joins, smaller result sets, and simpler queries. The cost is that every place a fact is stored must be updated when the fact changes — and keeping those copies in sync is now your problem, not the database's. The synchronization mechanism (triggers, application logic, batch jobs, event streams) is the hard part of denormalization. Getting the read path fast is easy. Keeping the redundant copies correct under concurrent writes is what determines whether the denormalization was worth doing.

---

## The Code

**Pattern 1 — Cached aggregate column**
```sql
-- Normalized: total must be computed from order_items every time
SELECT o.id, SUM(oi.quantity * oi.unit_price) AS total
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id;

-- Denormalized: store total directly on the orders row
ALTER TABLE orders ADD COLUMN total_amount NUMERIC DEFAULT 0;

-- Keep it in sync with a trigger
CREATE OR REPLACE FUNCTION sync_order_total()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE orders
    SET total_amount = (
        SELECT COALESCE(SUM(quantity * unit_price), 0)
        FROM order_items
        WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
    )
    WHERE id = COALESCE(NEW.order_id, OLD.order_id);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_order_total
AFTER INSERT OR UPDATE OR DELETE ON order_items
FOR EACH ROW EXECUTE FUNCTION sync_order_total();

-- Read is now free — no join, no aggregation
SELECT id, total_amount FROM orders WHERE id = 42;
```

**Pattern 2 — Duplicated column to avoid a join**
```sql
-- Normalized: every query for order + customer email requires a join
SELECT o.id, u.email, o.status
FROM orders o
JOIN users u ON u.id = o.user_id;

-- Denormalized: copy email onto the orders table
ALTER TABLE orders ADD COLUMN customer_email TEXT;

-- Populate existing rows
UPDATE orders o
SET customer_email = u.email
FROM users u
WHERE u.id = o.user_id;

-- Keep in sync when email changes
CREATE OR REPLACE FUNCTION sync_customer_email()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE orders
    SET customer_email = NEW.email
    WHERE user_id = NEW.id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_customer_email
AFTER UPDATE OF email ON users
FOR EACH ROW EXECUTE FUNCTION sync_customer_email();

-- Read requires no join
SELECT id, customer_email, status FROM orders WHERE id = 42;
```

**Pattern 3 — Flattened summary table**
```sql
-- Normalized: dashboard query joins three tables and aggregates millions of rows
SELECT
    u.country,
    DATE_TRUNC('month', o.created_at) AS month,
    COUNT(DISTINCT o.id)              AS order_count,
    SUM(oi.quantity * oi.unit_price)  AS revenue
FROM orders o
JOIN users u        ON u.id = o.user_id
JOIN order_items oi ON oi.order_id = o.id
WHERE o.status = 'completed'
GROUP BY u.country, DATE_TRUNC('month', o.created_at);

-- Denormalized: precompute into a summary table, refresh periodically
CREATE TABLE revenue_by_country_month (
    country         TEXT,
    month           DATE,
    order_count     INT,
    revenue         NUMERIC,
    last_updated    TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (country, month)
);

-- Refresh via scheduled job or materialized view
INSERT INTO revenue_by_country_month (country, month, order_count, revenue)
SELECT
    u.country,
    DATE_TRUNC('month', o.created_at)::date,
    COUNT(DISTINCT o.id),
    SUM(oi.quantity * oi.unit_price)
FROM orders o
JOIN users u        ON u.id = o.user_id
JOIN order_items oi ON oi.order_id = o.id
WHERE o.status = 'completed'
GROUP BY u.country, DATE_TRUNC('month', o.created_at)
ON CONFLICT (country, month) DO UPDATE
    SET order_count  = EXCLUDED.order_count,
        revenue      = EXCLUDED.revenue,
        last_updated = NOW();

-- Dashboard query is now a point lookup
SELECT country, month, order_count, revenue
FROM revenue_by_country_month
ORDER BY month DESC, revenue DESC;
```

**Pattern 4 — JSONB column for flexible attributes**
```sql
-- Normalized: every new product attribute requires a schema change
CREATE TABLE product_attributes (
    product_id  INT REFERENCES products(id),
    key         TEXT,
    value       TEXT,
    PRIMARY KEY (product_id, key)
);

-- Denormalized: store variable attributes as JSONB on the product row
ALTER TABLE products ADD COLUMN attributes JSONB DEFAULT '{}';

UPDATE products
SET attributes = '{"color": "red", "weight_kg": 1.2, "warranty_years": 2}'
WHERE id = 7;

-- Query specific attributes
SELECT id, name, attributes->>'color' AS color
FROM products
WHERE attributes->>'color' = 'red';

-- Index a frequently queried JSONB field
CREATE INDEX idx_products_color ON products ((attributes->>'color'));
```

**Pattern 5 — Materialized view as managed denormalization**
```sql
-- Let PostgreSQL manage the denormalized copy
CREATE MATERIALIZED VIEW order_summary AS
SELECT
    o.id            AS order_id,
    u.email,
    u.country,
    o.status,
    o.created_at,
    SUM(oi.quantity * oi.unit_price) AS total_amount
FROM orders o
JOIN users u        ON u.id = o.user_id
JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id, u.email, u.country, o.status, o.created_at;

CREATE UNIQUE INDEX ON order_summary (order_id);

-- Refresh on a schedule (accepts some staleness)
REFRESH MATERIALIZED VIEW CONCURRENTLY order_summary;
```

---

## Gotchas

- **Synchronization bugs are silent** — when a denormalized column drifts out of sync with its source, queries return wrong answers with no error. A missing trigger branch (forgetting to handle DELETE in a trigger that handles INSERT and UPDATE) is enough to cause silent data drift. Test every write path that touches the source data, not just the happy path.
- **Denormalization multiplies write complexity** — every table that holds a copy of a fact must be updated when the fact changes. A customer email stored in five places requires five updates (or a trigger that fans out). Under high concurrent write load, this fan-out creates contention and slows the original write.
- **Batch refresh creates a staleness window** — summary tables refreshed on a schedule are stale between refreshes. If the dashboard shows yesterday's revenue to a user who is looking at today's data, that's a product problem, not just a technical one. The acceptable staleness window must be defined before choosing batch refresh over trigger-based sync.
- **Denormalized columns still need indexes** — copying `customer_email` to the orders table doesn't automatically make it fast to query. If you filter on the denormalized column, it needs an index just like any other column. The join is gone but the index requirement isn't.
- **Rolling back a denormalization is hard** — once application code, reports, and dashboards are built against the denormalized schema, removing the redundant columns requires migrating all consumers simultaneously. Treat denormalization decisions as difficult to reverse and model the long-term maintenance burden before committing.

---

## Interview Angle
**What they're really testing:** Whether you understand denormalization as a deliberate engineering tradeoff — not a performance trick — and whether you can reason about the consistency mechanisms required to make it safe.

**Common question form:** "How would you optimize a slow dashboard query that joins five tables?" or "When would you denormalize a database schema?"

**The depth signal:** A junior says "denormalization makes reads faster by avoiding joins" and stops there. A senior immediately asks what the write pattern looks like, identifies the synchronization mechanism required (trigger, application logic, batch job, event stream), quantifies the acceptable staleness window, and flags that synchronization bugs are silent — wrong data with no error. They also know that materialized views are managed denormalization and are often the right first step before hand-rolling summary tables. Mentioning that denormalization decisions are hard to reverse, and should be treated as architectural commitments, is a strong senior signal.

---

## Related Topics
- [[databases/normalization.md]] — normalization is the baseline; denormalization is a deliberate departure from it
- [[databases/sql-views.md]] — materialized views are the lowest-risk form of denormalization; the database manages the copy
- [[databases/sql-triggers.md]] — triggers are the primary mechanism for keeping denormalized columns in sync on writes
- [[databases/sql-statistics.md]] — denormalized summary tables need fresh statistics; heavy writes skew the planner's estimates

---

## Source
https://www.postgresql.org/docs/current/ddl.html

---
*Last updated: 2026-03-24*