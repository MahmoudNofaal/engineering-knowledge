# Database Normalization

> Normalization is the process of structuring a relational database schema to reduce data redundancy and ensure data integrity by organizing columns and tables according to dependency rules.

---

## When To Use It
Apply normalization when designing a new schema or refactoring one that has update anomalies — places where changing one fact requires updating multiple rows, or where deleting a row accidentally destroys unrelated information. Normalization is the default starting point for transactional systems (OLTP). Don't normalize blindly for analytical workloads (OLAP) — read-heavy reporting systems often deliberately denormalize to avoid expensive joins. The right level of normalization depends on your read/write ratio and how much data consistency matters relative to query simplicity.

---

## Core Concept
Normalization is organized into normal forms — each one building on the last, eliminating a specific class of redundancy. The practical goal is to ensure every fact is stored exactly once, so updating it requires changing exactly one row. First Normal Form (1NF) eliminates repeating groups and ensures atomic values. Second Normal Form (2NF) eliminates partial dependencies — non-key columns must depend on the whole primary key, not just part of it. Third Normal Form (3NF) eliminates transitive dependencies — non-key columns must depend directly on the primary key, not on another non-key column. Boyce-Codd Normal Form (BCNF) tightens 3NF for edge cases with multiple overlapping candidate keys. Most production schemas target 3NF — going further adds complexity without proportional benefit in the majority of systems.

---

## The Code

**Unnormalized table — everything in one place**
```sql
-- Order data with repeated customer and product info
CREATE TABLE orders_flat (
    order_id        INT,
    customer_name   TEXT,
    customer_email  TEXT,
    customer_city   TEXT,
    product_name    TEXT,
    product_price   NUMERIC,
    quantity        INT,
    order_date      DATE
);

-- Problems:
-- Updating customer email requires touching every row for that customer
-- Deleting the last order for a customer destroys their contact info
-- Product price changes require updating every order row
```

**First Normal Form (1NF) — atomic values, no repeating groups**
```sql
-- Violation: storing multiple products in one column
CREATE TABLE orders_bad (
    order_id    INT PRIMARY KEY,
    customer    TEXT,
    products    TEXT   -- 'Widget,Gadget,Doohickey' — not atomic
);

-- 1NF fix: one value per column, one row per entity
CREATE TABLE order_items (
    order_id    INT,
    product_id  INT,
    quantity    INT,
    PRIMARY KEY (order_id, product_id)   -- composite key, each row is unique
);
```

**Second Normal Form (2NF) — no partial dependencies**
```sql
-- Violation: composite key (order_id, product_id)
-- product_name depends only on product_id, not the full key
CREATE TABLE order_items_bad (
    order_id        INT,
    product_id      INT,
    product_name    TEXT,    -- depends only on product_id — partial dependency
    quantity        INT,
    PRIMARY KEY (order_id, product_id)
);

-- 2NF fix: move product_name to its own table
CREATE TABLE products (
    id      INT PRIMARY KEY,
    name    TEXT,
    price   NUMERIC
);

CREATE TABLE order_items (
    order_id    INT,
    product_id  INT REFERENCES products(id),
    quantity    INT,
    PRIMARY KEY (order_id, product_id)
);
```

**Third Normal Form (3NF) — no transitive dependencies**
```sql
-- Violation: city depends on zip_code, not directly on customer_id
CREATE TABLE customers_bad (
    id          INT PRIMARY KEY,
    name        TEXT,
    zip_code    TEXT,
    city        TEXT,    -- depends on zip_code, not on id — transitive dependency
    country     TEXT     -- depends on zip_code, not on id
);

-- 3NF fix: extract the transitive dependency
CREATE TABLE zip_codes (
    zip_code    TEXT PRIMARY KEY,
    city        TEXT,
    country     TEXT
);

CREATE TABLE customers (
    id          INT PRIMARY KEY,
    name        TEXT,
    zip_code    TEXT REFERENCES zip_codes(zip_code)
);
```

**A normalized schema — orders domain in 3NF**
```sql
CREATE TABLE customers (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    email       TEXT UNIQUE NOT NULL,
    zip_code    TEXT REFERENCES zip_codes(zip_code)
);

CREATE TABLE products (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    price       NUMERIC NOT NULL
);

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    order_date  DATE NOT NULL,
    status      TEXT NOT NULL
);

CREATE TABLE order_items (
    order_id    INT NOT NULL REFERENCES orders(id),
    product_id  INT NOT NULL REFERENCES products(id),
    quantity    INT NOT NULL,
    unit_price  NUMERIC NOT NULL,   -- snapshot of price at time of order
    PRIMARY KEY (order_id, product_id)
);
-- unit_price is intentionally denormalized — product price changes over time
-- storing it here preserves the historical record of what the customer paid
```

**Controlled denormalization — when to break the rules**
```sql
-- Fully normalized: requires joining orders → order_items → products every time
SELECT o.id, SUM(oi.quantity * oi.unit_price) AS total
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id;

-- Denormalized: store the total on the order row for fast lookup
ALTER TABLE orders ADD COLUMN total_amount NUMERIC;

-- Keep it in sync with a trigger
CREATE OR REPLACE FUNCTION sync_order_total()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE orders
    SET total_amount = (
        SELECT SUM(quantity * unit_price)
        FROM order_items
        WHERE order_id = NEW.order_id
    )
    WHERE id = NEW.order_id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_order_items_total
AFTER INSERT OR UPDATE OR DELETE ON order_items
FOR EACH ROW EXECUTE FUNCTION sync_order_total();
```

---

## Gotchas

- **Normalization doesn't mean no redundancy ever** — some redundancy is intentional and correct. `unit_price` on an order line item is a deliberate snapshot of the price at purchase time — normalizing it away by referencing the products table would break historical accuracy when prices change. Always ask whether a piece of data is a current fact or a historical record before normalizing it out.
- **Over-normalization creates join hell** — pushing every attribute into its own table produces schemas that require seven joins to answer a basic question. 3NF is almost always the right stopping point for OLTP. BCNF and 4NF are theoretically purer but rarely worth the operational complexity in practice.
- **Normalization doesn't enforce itself** — a normalized schema still allows garbage data without constraints. Foreign keys, NOT NULL, UNIQUE, and CHECK constraints are what actually enforce the integrity that normalization is designed to express. A schema in 3NF with no constraints is just a naming convention.
- **Denormalization for performance should be a deliberate, measured decision** — adding a cached total or a redundant column to avoid a join is sometimes the right call, but it introduces a synchronization problem. The derived value can go stale. Use triggers or application logic to keep it consistent, and document why the denormalization exists.
- **The normal form of your schema drifts over time** — columns get added, requirements change, and tables that started in 3NF accumulate transitive dependencies through organic growth. Schema review should be part of any significant feature that adds columns to an existing table.

---

## Interview Angle
**What they're really testing:** Whether you understand *why* normalization rules exist — the specific anomalies they prevent — not whether you can recite the definitions.

**Common question form:** "What is normalization and what are the normal forms?" or "Design a schema for an e-commerce order system" — then follow-up questions probing whether you've thought about redundancy and consistency.

**The depth signal:** A junior recites 1NF/2NF/3NF definitions from memory and draws a clean schema. A senior explains the three anomalies normalization prevents (insertion, update, deletion anomalies), knows that some denormalization is intentional (historical snapshots, performance), understands that constraints are what actually enforce integrity, and can explain why they'd stop at 3NF for OLTP but deliberately denormalize for analytics. They also flag that normalization drifts and treat schema review as an ongoing practice, not a one-time design decision.

---

## Related Topics
- [[databases/sql-joins.md]] — normalized schemas require joins; understanding join performance is the practical cost of normalization
- [[databases/sql-triggers.md]] — triggers are the common mechanism for keeping denormalized derived values in sync
- [[databases/sql-indexing.md]] — foreign key columns introduced by normalization must be indexed or joins become full table scans
- [[databases/sql-transactions.md]] — normalized multi-table writes must be wrapped in transactions to maintain consistency across tables

---

## Source
https://www.postgresql.org/docs/current/ddl.html

---
*Last updated: 2026-03-24*