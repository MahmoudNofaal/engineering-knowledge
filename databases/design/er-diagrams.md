# Entity-Relationship Diagrams

> An ER diagram is a visual map of a database schema — showing entities (tables), their attributes (columns), and the relationships between them.

---

## When To Use It
Draw an ER diagram before writing schema DDL on any system with more than three or four tables. They're the fastest way to spot missing foreign keys, incorrect cardinalities, and junction tables that should exist but don't — before you've written a line of SQL. Use them in design reviews to communicate schema decisions to teammates who don't read SQL fluently. Revisit them when onboarding onto an unfamiliar codebase or when a schema has grown organically and nobody is sure what connects to what anymore.

---

## Core Concept
An ER diagram has three building blocks. Entities are the things you're modeling — usually tables. Attributes are the properties of those entities — usually columns. Relationships are the connections between entities — usually foreign keys. The most important thing an ER diagram communicates is cardinality: how many of one entity relate to how many of another. One-to-one, one-to-many, and many-to-many are the three relationships every schema is built from. Many-to-many relationships can't be expressed directly as a foreign key — they require a junction table (also called a join table or associative table). Spotting that requirement early, in a diagram, is cheaper than refactoring it out of a live schema.

---

## The Code

**Schema used for the diagrams below**
```sql
CREATE TABLE customers (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    email       TEXT UNIQUE NOT NULL
);

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    status      TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE products (
    id      SERIAL PRIMARY KEY,
    name    TEXT NOT NULL,
    price   NUMERIC NOT NULL
);

-- Junction table — resolves many-to-many between orders and products
CREATE TABLE order_items (
    order_id    INT NOT NULL REFERENCES orders(id),
    product_id  INT NOT NULL REFERENCES products(id),
    quantity    INT NOT NULL,
    unit_price  NUMERIC NOT NULL,
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE categories (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL
);

-- Products belong to many categories; categories contain many products
CREATE TABLE product_categories (
    product_id  INT NOT NULL REFERENCES products(id),
    category_id INT NOT NULL REFERENCES categories(id),
    PRIMARY KEY (product_id, category_id)
);
```

**Crow's foot notation — cardinality symbols**
```
One (and only one):     ──|
Zero or one:            ──○|
One or many:            ──
Zero or many:           ──○
Exactly one to many:    |──
Zero or one to many:    ○|──
```

**Reading a relationship line**
```
customers ||──○< orders

Read left to right:  one customer has zero or many orders
Read right to left:  each order belongs to exactly one customer

orders ||──○< order_items

Read left to right:  one order has zero or many order_items
Read right to left:  each order_item belongs to exactly one order

orders >○──○< products   (via order_items junction table)

Read: orders and products have a many-to-many relationship
      resolved by the order_items junction table
```

**Mermaid ER diagram syntax**
```
erDiagram
    CUSTOMERS {
        int id PK
        text name
        text email
    }

    ORDERS {
        int id PK
        int customer_id FK
        text status
        timestamptz created_at
    }

    PRODUCTS {
        int id PK
        text name
        numeric price
    }

    ORDER_ITEMS {
        int order_id FK
        int product_id FK
        int quantity
        numeric unit_price
    }

    CATEGORIES {
        int id PK
        text name
    }

    PRODUCT_CATEGORIES {
        int product_id FK
        int category_id FK
    }

    CUSTOMERS ||--o{ ORDERS : "places"
    ORDERS ||--o{ ORDER_ITEMS : "contains"
    PRODUCTS ||--o{ ORDER_ITEMS : "included in"
    PRODUCTS }o--o{ CATEGORIES : "belongs to"
```

**One-to-one relationship**
```sql
-- A user has exactly one profile; a profile belongs to exactly one user
CREATE TABLE users (
    id      SERIAL PRIMARY KEY,
    email   TEXT UNIQUE NOT NULL
);

CREATE TABLE user_profiles (
    user_id     INT PRIMARY KEY REFERENCES users(id),  -- PK enforces one-to-one
    bio         TEXT,
    avatar_url  TEXT
);

-- Mermaid notation:
-- USERS ||--|| USER_PROFILES : "has"
```

**Self-referencing relationship — hierarchies**
```sql
-- An employee can manage other employees — same table, foreign key to itself
CREATE TABLE employees (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    manager_id  INT REFERENCES employees(id)   -- nullable: CEO has no manager
);

-- Mermaid notation:
-- EMPLOYEES ||--o{ EMPLOYEES : "manages"
```

**Identifying vs non-identifying relationships**
```
Identifying relationship:
  Child's primary key includes the parent's foreign key
  The child cannot exist without the parent
  Example: order_items — (order_id, product_id) is the PK
  Shown as a solid line in ER diagrams

Non-identifying relationship:
  Child has its own independent primary key
  The foreign key is just an attribute
  Example: orders.customer_id — orders have their own id
  Shown as a dashed line in ER diagrams
```

---

## Gotchas

- **Many-to-many without a junction table is a schema smell** — storing comma-separated IDs in a column (`product_ids = '1,3,7'`) is a 1NF violation disguised as a shortcut. It prevents joins, breaks foreign key constraints, and makes queries painful. Any many-to-many relationship needs a proper junction table with its own primary key and two foreign keys.
- **Cardinality on the diagram doesn't enforce itself in the database** — marking a relationship as "exactly one" in an ER diagram doesn't add a NOT NULL constraint to the foreign key column in your DDL. The diagram is documentation; the schema is enforcement. Both must be correct independently.
- **ER diagrams drift from the actual schema** — diagrams drawn at design time become stale as the schema evolves. An outdated ER diagram is worse than no diagram because it's confidently wrong. Treat schema diagrams as living documents or generate them automatically from the live schema using tools like `pg_dump` + schema visualization tools.
- **Junction tables often need extra attributes** — an `order_items` junction table between orders and products needs `quantity` and `unit_price`. A `user_roles` junction between users and roles might need `granted_at` and `granted_by`. Treating junction tables as pure mapping tables and forgetting to model their own attributes is a common early schema mistake.
- **Mixing logical and physical ER diagrams causes confusion** — a logical ER diagram shows entities and relationships without implementation details (no data types, no indexes). A physical ER diagram shows the actual table columns, types, and constraints. Mixing them produces a diagram that's neither useful for communication nor accurate as documentation.

---

## Interview Angle
**What they're really testing:** Whether you can translate a real-world domain into a clean relational schema — specifically whether you identify cardinalities correctly and handle many-to-many relationships properly.

**Common question form:** "Design a database schema for [Airbnb / Twitter / an e-commerce store]" — then follow-up questions probing your cardinality choices and whether you've accounted for junction tables.

**The depth signal:** A junior draws tables and arrows without labeling cardinalities, and misses junction tables for many-to-many relationships. A senior labels every relationship with explicit cardinality, identifies all many-to-many relationships upfront and creates junction tables for them, distinguishes identifying from non-identifying relationships, and notes that junction tables often carry their own attributes. They also separate the logical model (what the domain looks like) from the physical model (how it maps to tables and types) and know that diagrams need to stay in sync with the actual schema or they become liabilities.

---

## Related Topics
- [[databases/normalization.md]] — ER diagrams are the visual tool for applying normalization rules before writing DDL
- [[databases/sql-joins.md]] — every relationship line in an ER diagram maps to a JOIN in queries
- [[databases/sql-indexing.md]] — foreign key columns on the many side of a relationship need indexes
- [[databases/sql-transactions.md]] — inserting across multiple related tables (resolving an ER relationship in code) must be wrapped in a transaction

---

## Source
https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK

---
*Last updated: 2026-03-24*