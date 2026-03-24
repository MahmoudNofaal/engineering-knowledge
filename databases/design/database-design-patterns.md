# Database Design Patterns

> Database design patterns are reusable solutions to common schema problems — recurring structures that appear across different domains and solve a specific modeling challenge cleanly.

---

## When To Use It
Reach for a named pattern when you recognize the problem it solves — not before. Patterns like audit logging, soft deletes, and polymorphic associations appear in almost every production system eventually. Knowing the pattern means you spend your time on implementation details rather than reinventing the solution from scratch. Avoid applying patterns preemptively — a soft delete column on a table that never needs deleted record recovery is unnecessary complexity.

---

## Core Concept
Design patterns in databases are schema-level idioms: specific column combinations, table structures, or relationship shapes that solve a class of problem. Unlike application code patterns, database patterns are expensive to change after data exists — adding a column is easy, restructuring a table with millions of rows under live traffic is hard. Choosing the right pattern at design time matters more than it does in application code. Each pattern has a tradeoff between query simplicity, write complexity, storage cost, and schema flexibility.

---

## The Code

**Pattern 1 — Audit Log (track every change)**
```sql
-- Separate audit table per entity
CREATE TABLE users_audit (
    audit_id        SERIAL PRIMARY KEY,
    user_id         INT NOT NULL,
    operation       TEXT NOT NULL,       -- 'INSERT', 'UPDATE', 'DELETE'
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by      TEXT NOT NULL DEFAULT current_user,
    old_values      JSONB,               -- NULL for INSERT
    new_values      JSONB                -- NULL for DELETE
);

-- Trigger to populate it automatically
CREATE OR REPLACE FUNCTION audit_users()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO users_audit (user_id, operation, old_values, new_values)
    VALUES (
        COALESCE(NEW.id, OLD.id),
        TG_OP,
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_audit
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW EXECUTE FUNCTION audit_users();

-- Query: what changed for user 42 in the last 7 days?
SELECT operation, changed_at, changed_by, old_values, new_values
FROM users_audit
WHERE user_id = 42
  AND changed_at > NOW() - INTERVAL '7 days'
ORDER BY changed_at DESC;
```

**Pattern 2 — Soft Delete (mark deleted, don't remove)**
```sql
-- Add deleted_at timestamp instead of removing rows
ALTER TABLE orders ADD COLUMN deleted_at TIMESTAMPTZ DEFAULT NULL;

-- Delete: set the timestamp
UPDATE orders SET deleted_at = NOW() WHERE id = 55;

-- All queries filter it out
SELECT * FROM orders WHERE deleted_at IS NULL;

-- Partial index — keeps the active-rows index small
CREATE INDEX idx_orders_active ON orders (customer_id)
WHERE deleted_at IS NULL;

-- View to hide the column from consumers
CREATE VIEW active_orders AS
SELECT * FROM orders WHERE deleted_at IS NULL;

-- Recover a deleted record
UPDATE orders SET deleted_at = NULL WHERE id = 55;

-- Hard delete old soft-deleted rows after retention period
DELETE FROM orders
WHERE deleted_at < NOW() - INTERVAL '90 days';
```

**Pattern 3 — Temporal / Versioned Records (full history)**
```sql
-- Track the full history of a record with validity periods
CREATE TABLE product_prices (
    id              SERIAL PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(id),
    price           NUMERIC NOT NULL,
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to        TIMESTAMPTZ,         -- NULL = current record
    created_by      TEXT NOT NULL DEFAULT current_user
);

-- Only one current price per product
CREATE UNIQUE INDEX idx_product_prices_current
ON product_prices (product_id)
WHERE valid_to IS NULL;

-- Insert new price: close the old one, open a new one
BEGIN;

UPDATE product_prices
SET valid_to = NOW()
WHERE product_id = 7 AND valid_to IS NULL;

INSERT INTO product_prices (product_id, price)
VALUES (7, 29.99);

COMMIT;

-- Query: current price
SELECT price FROM product_prices
WHERE product_id = 7 AND valid_to IS NULL;

-- Query: price at a specific point in time
SELECT price FROM product_prices
WHERE product_id = 7
  AND valid_from <= '2024-06-15'
  AND (valid_to > '2024-06-15' OR valid_to IS NULL);
```

**Pattern 4 — Status Machine (explicit state transitions)**
```sql
-- Model allowed transitions as a constraint
CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    status      TEXT NOT NULL DEFAULT 'pending',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_order_status
        CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled'))
);

-- Enforce transitions in a function — not just valid states, but valid moves
CREATE OR REPLACE FUNCTION transition_order_status(
    p_order_id  INT,
    p_new_status TEXT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_current TEXT;
BEGIN
    SELECT status INTO v_current FROM orders WHERE id = p_order_id FOR UPDATE;

    IF NOT (
        (v_current = 'pending'   AND p_new_status IN ('confirmed', 'cancelled')) OR
        (v_current = 'confirmed' AND p_new_status IN ('shipped',   'cancelled')) OR
        (v_current = 'shipped'   AND p_new_status = 'delivered')
    ) THEN
        RAISE EXCEPTION 'Invalid transition: % → %', v_current, p_new_status;
    END IF;

    UPDATE orders SET status = p_new_status WHERE id = p_order_id;
END;
$$;

SELECT transition_order_status(42, 'confirmed');
```

**Pattern 5 — Polymorphic Association (one FK to many tables)**
```sql
-- Comments that can belong to posts, videos, or products
-- Option A: nullable foreign keys — simple but grows with each new type
CREATE TABLE comments (
    id          SERIAL PRIMARY KEY,
    body        TEXT NOT NULL,
    post_id     INT REFERENCES posts(id),
    video_id    INT REFERENCES videos(id),
    product_id  INT REFERENCES products(id),
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_one_parent CHECK (
        (post_id IS NOT NULL)::int +
        (video_id IS NOT NULL)::int +
        (product_id IS NOT NULL)::int = 1
    )
);

-- Option B: generic type + ID — flexible but no FK enforcement
CREATE TABLE comments (
    id              SERIAL PRIMARY KEY,
    body            TEXT NOT NULL,
    commentable_type TEXT NOT NULL,   -- 'post', 'video', 'product'
    commentable_id   INT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_comments_parent ON comments (commentable_type, commentable_id);
-- No FK constraint possible — referential integrity must be managed in app code

-- Option C: base table with inheritance (cleanest FK integrity)
CREATE TABLE commentable (
    id  SERIAL PRIMARY KEY
);
CREATE TABLE posts    (id INT PRIMARY KEY REFERENCES commentable(id), ...);
CREATE TABLE videos   (id INT PRIMARY KEY REFERENCES commentable(id), ...);
CREATE TABLE comments (
    id              SERIAL PRIMARY KEY,
    commentable_id  INT NOT NULL REFERENCES commentable(id),
    body            TEXT NOT NULL
);
```

**Pattern 6 — Hierarchical Data (trees in SQL)**
```sql
-- Option A: adjacency list — simple, hard to query deeply
CREATE TABLE categories (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    parent_id   INT REFERENCES categories(id)   -- NULL = root
);
-- Querying full hierarchy requires recursive CTE

-- Option B: closure table — fast reads, more storage
CREATE TABLE category_paths (
    ancestor_id     INT NOT NULL REFERENCES categories(id),
    descendant_id   INT NOT NULL REFERENCES categories(id),
    depth           INT NOT NULL,   -- 0 = self-reference
    PRIMARY KEY (ancestor_id, descendant_id)
);

-- Insert a new category under parent_id=3
INSERT INTO category_paths (ancestor_id, descendant_id, depth)
SELECT ancestor_id, :new_id, depth + 1
FROM category_paths
WHERE descendant_id = 3   -- all ancestors of the parent
UNION ALL
SELECT :new_id, :new_id, 0;   -- self-reference

-- Get all descendants of category 3
SELECT descendant_id FROM category_paths
WHERE ancestor_id = 3 AND depth > 0;

-- Option C: ltree extension (PostgreSQL) — path-based, fast subtree queries
CREATE EXTENSION IF NOT EXISTS ltree;
CREATE TABLE categories (
    id      SERIAL PRIMARY KEY,
    name    TEXT NOT NULL,
    path    ltree NOT NULL
);
CREATE INDEX idx_categories_path ON categories USING GIST (path);

-- Query all descendants of node at path 'electronics'
SELECT * FROM categories WHERE path <@ 'electronics';
```

**Pattern 7 — Key-Value / EAV (Entity-Attribute-Value)**
```sql
-- Flexible attributes without schema changes
-- Use sparingly — querying is painful at scale
CREATE TABLE product_attributes (
    product_id  INT NOT NULL REFERENCES products(id),
    key         TEXT NOT NULL,
    value       TEXT,
    PRIMARY KEY (product_id, key)
);

INSERT INTO product_attributes VALUES
    (1, 'color', 'red'),
    (1, 'weight_kg', '1.5'),
    (1, 'warranty_years', '2');

-- Pivot: get all attributes for a product as columns (ugly)
SELECT
    MAX(CASE WHEN key = 'color' THEN value END)         AS color,
    MAX(CASE WHEN key = 'weight_kg' THEN value END)     AS weight_kg,
    MAX(CASE WHEN key = 'warranty_years' THEN value END) AS warranty_years
FROM product_attributes
WHERE product_id = 1;

-- Modern alternative: JSONB column on the product row
ALTER TABLE products ADD COLUMN attributes JSONB DEFAULT '{}';
-- Far easier to query, index, and evolve than EAV
```

---

## Gotchas

- **Soft delete leaks into every query** — once you add `deleted_at`, every SELECT that doesn't filter `WHERE deleted_at IS NULL` silently returns deleted rows. This infects joins, counts, and aggregations. Use a view or row-level security policy to enforce the filter automatically — don't rely on every developer remembering to add it.
- **Temporal patterns need a unique constraint on the current record** — a `valid_to IS NULL` pattern for current records only works if you enforce that exactly one row per entity has `valid_to IS NULL`. Without a partial unique index on that condition, concurrent writes can produce two "current" records with no error.
- **Polymorphic associations with type+ID have no FK enforcement** — the `commentable_type` + `commentable_id` pattern is flexible but the database can't enforce that the referenced row actually exists. Orphaned references accumulate silently. This is a deliberate tradeoff — know you're accepting it.
- **EAV is a schema design smell in most cases** — EAV tables look flexible but are slow to query, impossible to index effectively, and force type coercion on every read. Modern PostgreSQL's JSONB column solves the same problem better in almost every case. Reach for EAV only when JSONB genuinely can't serve the use case.
- **State machine transitions enforced only in application code get violated** — any direct SQL UPDATE can bypass application-layer transition logic. Enforce transitions in a database function or trigger if the state machine has real business consequences. An order that jumps from `pending` to `delivered` without going through `shipped` is a data integrity problem, not just an application bug.

---

## Interview Angle
**What they're really testing:** Whether you recognize common schema problems by name and can choose between solutions based on their tradeoffs — not just whether you can write the DDL.

**Common question form:** "How would you implement soft deletes?" or "Design a schema that tracks the full history of price changes" or "How would you model a commenting system where comments can belong to posts, videos, or products?"

**The depth signal:** A junior implements soft delete with a boolean `is_deleted` flag, misses the query infection problem, and doesn't add a partial index. A senior uses `deleted_at` for recovery timestamps, adds a partial index on active rows, creates a view to enforce the filter automatically, and flags that every query must include the filter or return corrupted results. For polymorphic associations, a senior knows all three options (nullable FKs, type+ID, base table inheritance), explains the FK enforcement tradeoff of each, and picks based on the system's integrity requirements. Knowing that EAV is almost always worse than JSONB in PostgreSQL is a strong differentiator.

---

## Related Topics
- [[databases/normalization.md]] — design patterns are structured departures from or extensions of normalized schema design
- [[databases/sql-triggers.md]] — audit logs and denormalized sync columns rely on triggers for automatic maintenance
- [[databases/sql-ctes.md]] — recursive CTEs are required to query adjacency list hierarchies
- [[databases/sql-indexing.md]] — partial indexes are essential for soft delete and temporal patterns to stay performant

---

## Source
https://www.postgresql.org/docs/current/ddl.html

---
*Last updated: 2026-03-24*