# SQL Data Types

> A data type defines what kind of value a column can hold, how it's stored on disk, what operations are valid on it, and how the planner estimates its costs.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Column-level constraint defining valid values and storage format |
| **Use when** | Every column definition — type selection affects storage, performance, and correctness |
| **Avoid when** | N/A — always required |
| **Standard** | SQL-92 (core types); SQL:1999 (arrays, user-defined); SQL:2016 (JSON) |
| **Key families** | Integer, Numeric/Decimal, Float, Text, Boolean, Date/Time, UUID, JSONB, Array, Enum |

---

## When To Use It

Choosing the right data type is one of the highest-leverage decisions in schema design. The wrong type wastes storage, prevents index use, requires constant casting, and causes silent precision loss. Use the smallest type that holds your data correctly — `INTEGER` not `BIGINT` when IDs will never exceed 2 billion, `NUMERIC` not `FLOAT` for money, `TEXT` not `VARCHAR(255)` in PostgreSQL (same storage, less artificial constraint). Avoid `TEXT` for values with a known fixed set — use an ENUM or a lookup table instead.

---

## Core Concept

PostgreSQL's type system is richer than most databases. Every value has a type. Every operator and function is defined over specific types. When types don't match, PostgreSQL either casts automatically (implicit cast) or throws an error. Implicit casts can suppress index use — if your column is `INTEGER` and you filter `WHERE id = '42'` (string literal), PostgreSQL must cast the string to integer. In most cases this works; in edge cases it prevents index use or produces unexpected results. Being explicit with types and casts is always safer.

Types also affect storage: `INTEGER` is always 4 bytes; `TEXT` is variable length with a 1-4 byte length prefix; `JSONB` is stored in a decomposed binary form that allows key access without parsing. Choosing the right type is choosing the right storage and access pattern.

---

## Version History

| PostgreSQL Version | What changed |
|---|---|
| Pre-8.0 | Core types: int, numeric, float, text, varchar, date, timestamp, boolean |
| 8.3 | Full-text search types (tsvector, tsquery) |
| 8.4 | UUID type added natively |
| 9.2 | JSON type added (stored as text, validated as JSON) |
| 9.4 | JSONB type added (binary storage, indexable, operator-rich) |
| 9.6 | JSONB indexing and operators matured |
| 10 | Identity columns (`GENERATED ALWAYS AS IDENTITY`) |
| 14 | Range type improvements, multirange types |

---

## Performance

| Type | Storage | Notes |
|---|---|---|
| SMALLINT | 2 bytes | -32,768 to 32,767 |
| INTEGER | 4 bytes | -2.1B to 2.1B — default for most IDs |
| BIGINT | 8 bytes | -9.2×10¹⁸ to 9.2×10¹⁸ — use for large-scale IDs, timestamps as integers |
| NUMERIC(p,s) | Variable | Exact — use for money; slow for arithmetic |
| FLOAT8 / DOUBLE PRECISION | 8 bytes | Approximate — never for money |
| TEXT | Variable | Same as VARCHAR in PostgreSQL — no performance difference |
| CHAR(n) | n bytes | Pads with spaces — almost never preferable to TEXT |
| UUID | 16 bytes | Fixed-size; random UUIDs cause B-tree fragmentation |
| BOOLEAN | 1 byte | true/false/NULL |
| TIMESTAMP | 8 bytes | Without timezone — stores as UTC-relative |
| TIMESTAMPTZ | 8 bytes | With timezone — stores as UTC, displays in session timezone |
| JSONB | Variable | Binary decomposed — GIN-indexable; ~2× storage vs JSON |
| ARRAY | Variable | Overhead per element; GIN-indexable |

**Allocation behaviour:** PostgreSQL uses TOAST (The Oversized-Attribute Storage Technique) to compress and store values larger than ~2KB out-of-line. TEXT, JSONB, and ARRAY columns benefit from TOAST automatically. Very large JSONB documents may cause TOAST overhead; for very large JSON, consider a dedicated table instead.

---

## The Code

**Integer types — choose the smallest that fits**
```sql
-- SMALLINT: status codes, small lookup IDs
-- INTEGER: most primary keys, foreign keys, counts
-- BIGINT: high-volume tables where auto-increment exceeds 2 billion

CREATE TABLE events (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     INTEGER NOT NULL,
    event_type  SMALLINT NOT NULL,   -- maps to an enum table
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- SERIAL is the old way (still works but deprecated in favour of IDENTITY)
-- SERIAL = INTEGER with a sequence default; BIGSERIAL = BIGINT with sequence
```

**Exact numeric — always for money**
```sql
-- NUMERIC(precision, scale): precision = total digits, scale = decimal places
-- FLOAT is IEEE 754 floating point — has rounding errors
-- 0.1 + 0.2 in FLOAT8 ≠ 0.3 exactly

CREATE TABLE transactions (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    amount      NUMERIC(12, 2) NOT NULL,   -- up to 9,999,999,999.99
    tax         NUMERIC(12, 2) NOT NULL DEFAULT 0,
    currency    CHAR(3) NOT NULL            -- ISO 4217: USD, EUR, GBP
);

-- Demonstrate the float trap
SELECT 0.1::FLOAT8 + 0.2::FLOAT8 = 0.3::FLOAT8;   -- FALSE
SELECT 0.1::NUMERIC + 0.2::NUMERIC = 0.3::NUMERIC; -- TRUE
```

**Text types — TEXT is usually right in PostgreSQL**
```sql
-- In PostgreSQL, TEXT and VARCHAR are identical in storage and performance
-- VARCHAR(n) adds a length check — useful as a constraint, not for performance
-- CHAR(n) pads with spaces — almost never useful

CREATE TABLE users (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       TEXT NOT NULL,
    username    VARCHAR(50) NOT NULL,  -- explicit length constraint makes intent clear
    bio         TEXT,                  -- unbounded — fine in PostgreSQL
    status      TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'suspended'))  -- or use ENUM
);
```

**Enum — for a fixed set of string values**
```sql
-- ENUM: stored efficiently (4 bytes), type-safe, adds ALTER TABLE cost to change
CREATE TYPE order_status AS ENUM ('pending', 'processing', 'shipped', 'delivered', 'cancelled');

CREATE TABLE orders (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status  order_status NOT NULL DEFAULT 'pending'
);

-- Add a value (fast — no table rewrite)
ALTER TYPE order_status ADD VALUE 'refunded' AFTER 'delivered';

-- Remove or rename a value: requires dropping and recreating the type (painful)
-- Consider a lookup table instead if the set changes frequently
```

**UUID — random vs sequential**
```sql
-- Random UUIDs (gen_random_uuid) cause B-tree fragmentation — pages fill non-sequentially
-- For large tables, consider ULID or UUIDv7 (time-ordered) to preserve insert order

CREATE TABLE sessions (
    id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id     INTEGER NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- UUIDv7 (PostgreSQL 17+ native, or use an extension earlier)
-- Time-ordered: inserts go near the end of the B-tree — less fragmentation
```

**Timestamps — always use TIMESTAMPTZ in application tables**
```sql
-- TIMESTAMP: stores datetime with no timezone info
-- TIMESTAMPTZ: converts to UTC at write time; converts back using session timezone at read

-- Common mistake: using TIMESTAMP when the app spans timezones
-- Symptom: queries "work" but events appear at wrong times for users in different zones

CREATE TABLE events (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    occurred_at TIMESTAMPTZ NOT NULL,           -- always use TIMESTAMPTZ
    processed_at TIMESTAMPTZ,                   -- nullable — not yet processed
    event_date  DATE NOT NULL                   -- if you only care about the calendar date
);

-- DATE, TIME, INTERVAL are separate types
SELECT
    NOW()::DATE,                          -- current date
    NOW()::TIME,                          -- current time
    AGE(NOW(), '1990-01-15'::DATE),       -- returns an INTERVAL
    NOW() - INTERVAL '7 days';            -- arithmetic with intervals
```

**JSONB — structured flexible data**
```sql
-- JSON: stores as text, validates on insert, no indexing of internals
-- JSONB: stores as binary, decomposed, GIN-indexable, operator-rich — almost always prefer JSONB

CREATE TABLE product_specs (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id  INTEGER NOT NULL,
    specs       JSONB NOT NULL
);

-- GIN index for fast key/value lookups inside JSONB
CREATE INDEX idx_product_specs_gin ON product_specs USING GIN (specs);

-- Query operators
SELECT * FROM product_specs
WHERE specs @> '{"color": "red"}';        -- contains key-value pair
WHERE specs ? 'weight';                    -- has key
WHERE specs ->> 'color' = 'red';           -- extract value as text

-- Nested access
SELECT specs -> 'dimensions' ->> 'height' AS height FROM product_specs;
--      ^                     ^^^
--  returns JSONB          returns TEXT
```

**Arrays — when to use them**
```sql
-- Arrays: useful for a known-bound list of same-type values
-- Don't use for data that needs to be joined or individually queried frequently

CREATE TABLE articles (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title   TEXT NOT NULL,
    tags    TEXT[] NOT NULL DEFAULT '{}'
);

CREATE INDEX idx_articles_tags ON articles USING GIN (tags);

-- Query operators
SELECT * FROM articles WHERE tags @> ARRAY['postgresql', 'performance'];  -- contains all
SELECT * FROM articles WHERE tags && ARRAY['postgresql', 'sql'];           -- overlaps any
SELECT * FROM articles WHERE 'postgresql' = ANY(tags);                     -- contains one
```

**Type casting**
```sql
-- Explicit cast: always preferred for clarity and safety
SELECT '2024-01-15'::DATE;
SELECT '42'::INTEGER;
SELECT 3.14::NUMERIC(10, 2);

-- CAST() function: standard SQL
SELECT CAST('2024-01-15' AS DATE);

-- Implicit cast (use carefully — can suppress index use)
SELECT * FROM users WHERE id = '42';  -- PostgreSQL casts '42' to INTEGER — works here
-- But: WHERE created_at = '2024-01-15' on a TIMESTAMPTZ column may not use the index cleanly
-- Explicit is always safer: WHERE created_at = '2024-01-15'::TIMESTAMPTZ
```

---

## Real World Example

A payments platform is designing the core transactions table. Each transaction has a status, an amount in a specific currency, optional metadata, and timestamps. Getting the types wrong here — using FLOAT for amount, TEXT for status, or TIMESTAMP instead of TIMESTAMPTZ — creates correctness bugs that are painful to fix after the table has billions of rows.

```sql
CREATE TYPE payment_status AS ENUM (
    'initiated', 'processing', 'succeeded', 'failed', 'refunded', 'disputed'
);

CREATE TABLE payments (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Never FLOAT for money — rounding errors compound
    amount          NUMERIC(19, 4) NOT NULL CHECK (amount > 0),
    refunded_amount NUMERIC(19, 4) NOT NULL DEFAULT 0 CHECK (refunded_amount >= 0),
    currency        CHAR(3) NOT NULL,   -- ISO 4217

    status          payment_status NOT NULL DEFAULT 'initiated',

    -- TIMESTAMPTZ: essential for a global payments platform
    initiated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,        -- NULL until terminal state reached

    -- Structured flexible metadata without a separate table
    processor_data  JSONB,              -- gateway response, reference IDs, etc.

    -- Human-readable external ID — TEXT, not INTEGER (may have leading zeros, prefixes)
    external_ref    TEXT,

    user_id         BIGINT NOT NULL,
    CONSTRAINT fk_payments_users FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Index patterns appropriate to each type
CREATE INDEX idx_payments_user_status   ON payments (user_id, status);
CREATE INDEX idx_payments_initiated_at  ON payments (initiated_at DESC);
CREATE INDEX idx_payments_processor     ON payments USING GIN (processor_data);
```

*The key insight: every type choice here is deliberate. NUMERIC(19,4) handles international micro-transactions. CHAR(3) enforces ISO currency codes. ENUM gives the planner better statistics than TEXT. TIMESTAMPTZ is non-negotiable for global users. JSONB on processor_data avoids a schema migration every time a payment gateway changes its response format.*

---

## Common Misconceptions

**"VARCHAR(255) is a good default for string columns in PostgreSQL"**
In PostgreSQL, `VARCHAR(n)` and `TEXT` have identical storage and performance. The only difference is `VARCHAR(n)` enforces a length limit. Using `VARCHAR(255)` as a reflexive default (a MySQL habit) adds an artificial constraint with no benefit. Use `TEXT` unless you have a specific reason to enforce a maximum length. If you do enforce a length, make it meaningful — `VARCHAR(50)` for a username, not `VARCHAR(255)` as a habit.

**"FLOAT is fine for storing prices"**
FLOAT uses IEEE 754 binary floating-point, which cannot represent most decimal fractions exactly. `0.1` stored as FLOAT8 is actually `0.1000000000000000055511151231257827021181583404541015625`. For money, this causes rounding errors that compound — a sum of a million transactions can be off by dollars. Always use `NUMERIC` for currency values.

```sql
SELECT 0.1::FLOAT8 + 0.2::FLOAT8;         -- 0.30000000000000004
SELECT 0.1::NUMERIC + 0.2::NUMERIC;       -- 0.3
SELECT (0.1::FLOAT8 + 0.2::FLOAT8) = 0.3; -- FALSE
SELECT (0.1::NUMERIC + 0.2::NUMERIC) = 0.3::NUMERIC; -- TRUE
```

**"TIMESTAMP and TIMESTAMPTZ are the same — timezone doesn't matter if everyone is in the same zone"**
This works until it doesn't. When the server changes timezone, when DST shifts, or when a user travels, TIMESTAMP values are suddenly wrong. TIMESTAMPTZ converts to UTC at write time and applies the session timezone at read time — it's always unambiguous. Use TIMESTAMPTZ for all application timestamps. TIMESTAMP is for cases where you explicitly want a "wall clock" value with no timezone semantics (rare).

---

## Gotchas

- **NUMERIC arithmetic is significantly slower than FLOAT** — NUMERIC is arbitrary precision, computed in software. FLOAT uses hardware floating-point units. For analytics/aggregations where precision doesn't matter (click counts, percentages), FLOAT is fine and much faster. For financial amounts, NUMERIC is required regardless.

- **Random UUIDs fragment B-tree indexes** — each insert goes to a random leaf node rather than the end of the index. On high-insert tables, this causes frequent page splits and index bloat. Use sequential IDs (BIGINT IDENTITY) or time-ordered UUIDs (UUIDv7) for primary keys on large tables.

- **ENUM types are hard to modify** — adding a value is safe. Removing or renaming a value requires dropping and recreating the type, which is often blocked by dependencies. For frequently-changing sets, a lookup table with a FOREIGN KEY is more flexible. ENUM pays off when the set is stable and the planner statistics benefit matters.

- **JSONB stores a decomposed binary representation that is ~2× the size of equivalent JSON text** — the binary format enables fast key access and indexing, but if you're storing millions of large documents, the storage overhead is real. For JSON you only read and never query internally, plain JSON is more space-efficient.

- **Implicit casts can suppress index use** — `WHERE status = 1` on a TEXT column forces a cast that may disable index use. `WHERE created_at > '2024-01-01'` on a TIMESTAMPTZ column works but the cast behaviour is version-dependent. Always cast explicitly in production queries.

---

## Interview Angle

**What they're really testing:** Whether you understand that type selection is a performance and correctness decision — not just a schema formality.

**Common question forms:**
- "What type would you use to store a monetary amount?"
- "What's the difference between TIMESTAMP and TIMESTAMPTZ?"
- "When would you use JSONB vs a normalised table?"

**The depth signal:** A junior says "use VARCHAR for strings and INT for IDs." A senior explains why NUMERIC is required for money (FLOAT precision loss), why TIMESTAMPTZ is the only correct choice for application timestamps in multi-timezone systems, when ENUM is appropriate vs a lookup table, and why random UUIDs fragment indexes on high-insert tables. They also know that in PostgreSQL, TEXT and VARCHAR are identical in storage and performance — the VARCHAR(255) default is a MySQL habit with no benefit in PostgreSQL.

**Follow-up questions to expect:**
- "What's the storage size difference between INTEGER and BIGINT, and when does it matter?"
- "What JSONB operators do you know, and when would you use a GIN index?"

---

## Related Topics

- [[databases/sql/sql-null-handling.md]] — NULL behaviour is tied to type: NULLs have a type in PostgreSQL
- [[databases/sql/sql-indexing.md]] — type choice directly affects which index types are applicable
- [[databases/design/normalization.md]] — proper type selection is foundational to normalization
- [[databases/postgres-sql/postgres-jsonb.md]] — deep dive into JSONB operators and indexing patterns

---

## Source

https://www.postgresql.org/docs/current/datatype.html

---
*Last updated: 2026-04-13*