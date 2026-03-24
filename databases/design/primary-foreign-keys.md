# Primary & Foreign Keys

> A primary key uniquely identifies every row in a table. A foreign key links a row in one table to a row in another, enforcing that the reference is valid.

---

## When To Use It
Every table should have a primary key — no exceptions. Without one, you can't reliably identify, update, or delete a specific row, and most ORM frameworks require it. Foreign keys should be used wherever a column references rows in another table — they're the database's mechanism for enforcing referential integrity. Skip foreign keys only in specific, deliberate situations: very high write throughput systems where the constraint check cost is measured and unacceptable, or in denormalized analytical schemas where referential integrity is managed upstream in the pipeline.

---

## Core Concept
A primary key is a constraint that combines NOT NULL and UNIQUE on one or more columns. It's the canonical identifier for a row. Every table has exactly one primary key. A foreign key is a constraint that says "the value in this column must exist as a primary key (or unique key) in that other table." The database checks this on every INSERT and UPDATE to the child table, and on every DELETE and UPDATE to the parent table. This check is what prevents orphaned rows — orders with no customer, order items with no order. The tradeoff is a small write overhead on both sides of the relationship. Most systems pay it without hesitation because the alternative is silent data corruption.

---

## The Code

**Declaring primary keys**
```sql
-- Single column — most common
CREATE TABLE users (
    id      SERIAL PRIMARY KEY,   -- SERIAL = auto-incrementing integer
    email   TEXT NOT NULL
);

-- UUID primary key — useful for distributed systems
CREATE TABLE events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type  TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Composite primary key — when identity requires multiple columns
CREATE TABLE order_items (
    order_id    INT NOT NULL,
    product_id  INT NOT NULL,
    quantity    INT NOT NULL,
    PRIMARY KEY (order_id, product_id)   -- combination must be unique
);

-- Adding a primary key to an existing table
ALTER TABLE legacy_table ADD PRIMARY KEY (id);
```

**Declaring foreign keys**
```sql
-- Inline declaration
CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    status      TEXT NOT NULL
);

-- Explicit constraint name — easier to drop or reference later
CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    status      TEXT NOT NULL,
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
        REFERENCES customers(id)
);

-- Adding a foreign key to an existing table
ALTER TABLE orders
ADD CONSTRAINT fk_orders_customer
FOREIGN KEY (customer_id) REFERENCES customers(id);
```

**ON DELETE and ON UPDATE behavior**
```sql
-- RESTRICT (default): block delete of parent if children exist
CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id)
    -- deleting a customer with orders → error
);

-- CASCADE: delete children when parent is deleted
CREATE TABLE order_items (
    order_id    INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  INT NOT NULL REFERENCES products(id),
    quantity    INT NOT NULL,
    PRIMARY KEY (order_id, product_id)
    -- deleting an order → deletes all its order_items automatically
);

-- SET NULL: null out the FK when parent is deleted
CREATE TABLE posts (
    id          SERIAL PRIMARY KEY,
    author_id   INT REFERENCES users(id) ON DELETE SET NULL,
    -- deleting a user → posts remain, author_id becomes NULL
    content     TEXT NOT NULL
);

-- SET DEFAULT: set FK to default value when parent is deleted
CREATE TABLE tasks (
    id              SERIAL PRIMARY KEY,
    assigned_to     INT REFERENCES users(id) ON DELETE SET DEFAULT DEFAULT 0,
    -- deleting a user → tasks reassigned to user id=0 (unassigned)
    title           TEXT NOT NULL
);
```

**Deferrable constraints — check at transaction end**
```sql
-- DEFERRABLE INITIALLY DEFERRED: constraint checked at COMMIT, not per statement
-- Useful when inserting mutually dependent rows in the same transaction

CREATE TABLE nodes (
    id          SERIAL PRIMARY KEY,
    next_id     INT REFERENCES nodes(id) DEFERRABLE INITIALLY DEFERRED
    -- allows inserting a node that references a not-yet-inserted next_id
    -- as long as next_id exists by COMMIT
);

BEGIN;
INSERT INTO nodes (id, next_id) VALUES (1, 2);  -- next_id=2 doesn't exist yet
INSERT INTO nodes (id, next_id) VALUES (2, 1);  -- now both exist
COMMIT;  -- constraint checked here — passes
```

**Checking constraint violations**
```sql
-- Find orphaned rows — FK references that no longer have a parent
SELECT oi.order_id
FROM order_items oi
LEFT JOIN orders o ON o.id = oi.order_id
WHERE o.id IS NULL;
-- Should return nothing if FK constraints are enforced
-- If it returns rows, constraints were disabled or bypassed

-- List all foreign keys on a table
SELECT
    conname         AS constraint_name,
    conrelid::regclass  AS table_name,
    confrelid::regclass AS referenced_table,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE contype = 'f'
  AND conrelid = 'orders'::regclass;
```

**Surrogate vs natural keys**
```sql
-- Surrogate key: system-generated, no business meaning
CREATE TABLE customers (
    id      SERIAL PRIMARY KEY,   -- surrogate
    email   TEXT UNIQUE NOT NULL  -- natural key — also indexed via UNIQUE
);

-- Natural key: has business meaning, used directly as PK
CREATE TABLE countries (
    code    CHAR(2) PRIMARY KEY,  -- 'US', 'EG', 'GB' — meaningful and stable
    name    TEXT NOT NULL
);

-- Composite natural key
CREATE TABLE exchange_rates (
    from_currency   CHAR(3),
    to_currency     CHAR(3),
    rate            NUMERIC NOT NULL,
    recorded_at     DATE NOT NULL,
    PRIMARY KEY (from_currency, to_currency, recorded_at)
);
```

---

## Gotchas

- **Foreign keys are not indexed automatically** — PostgreSQL creates an index on the primary key automatically. It does NOT create an index on the foreign key column in the child table. A query joining orders to customers on `orders.customer_id` without an index on `customer_id` does a full scan of orders every time. Always index foreign key columns on the many side of a relationship.
- **ON DELETE CASCADE silently deletes data** — cascade deletes are convenient but dangerous. Deleting a parent row can cascade through multiple levels of child tables and remove thousands of rows with no warning. Always know your cascade depth. For critical data, prefer RESTRICT and handle deletes explicitly in application code.
- **Surrogate keys hide duplicate business entities** — using a surrogate `id` as the only key means you can insert two rows for the same customer email without error. The surrogate key ensures row uniqueness, not business entity uniqueness. Always add UNIQUE constraints on natural identifiers (`email`, `code`, etc.) alongside the surrogate key.
- **Deferrable constraints can mask integrity bugs** — deferring FK checks to COMMIT is occasionally necessary but hides violations until the end of a transaction. A bug that inserts an invalid reference is harder to trace when the error fires at COMMIT rather than at the INSERT. Use deferrable constraints only when genuinely needed, not as a default.
- **UUID primary keys cause index fragmentation** — random UUIDs as primary keys insert in random order, which fragments the B-tree index over time and increases page splits. For write-heavy tables, sequential UUIDs (`gen_random_uuid()` in PostgreSQL 13+ uses UUIDv4; consider ULIDs or UUIDv7 for sequential generation) or integer sequences are cheaper on write performance.

---

## Interview Angle
**What they're really testing:** Whether you understand referential integrity as a database-enforced guarantee — and whether you know the operational implications of foreign key behavior under deletes and updates.

**Common question form:** "What's the difference between a primary key and a unique constraint?" or "What happens when you delete a parent row that has child rows referencing it?"

**The depth signal:** A junior knows primary keys are unique identifiers and foreign keys link tables. A senior knows that foreign key columns are not auto-indexed (and the performance implication), can explain all four ON DELETE behaviors and when each is appropriate, knows that CASCADE deletes are dangerous and should be used sparingly, understands the surrogate vs natural key tradeoff, and knows that UUID primary keys cause index fragmentation on write-heavy tables. They also know that deferrable constraints exist, why you'd use them, and why they're the exception rather than the rule.

---

## Related Topics
- [[databases/sql-indexing.md]] — foreign key columns must be manually indexed; primary keys are indexed automatically
- [[databases/normalization.md]] — foreign keys are the physical implementation of the relationships defined in a normalized schema
- [[databases/er-diagrams.md]] — every relationship line in an ER diagram maps to a foreign key constraint in DDL
- [[databases/sql-transactions.md]] — multi-table inserts resolving FK relationships must be wrapped in transactions to maintain consistency

---

## Source
https://www.postgresql.org/docs/current/ddl-constraints.html

---
*Last updated: 2026-03-24*