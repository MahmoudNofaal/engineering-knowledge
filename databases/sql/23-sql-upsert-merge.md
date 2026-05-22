# SQL Upsert & MERGE

> An upsert is an operation that INSERTs a new row if it doesn't exist, or UPDATEs the existing row if it does — atomically, without a race condition.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Atomic insert-or-update operation on a conflict |
| **Use when** | Idempotent writes, syncing external data, maintaining running aggregates |
| **Avoid when** | A plain INSERT is sufficient and conflicts won't occur |
| **Standard** | SQL:2003 (MERGE); PostgreSQL-specific: `INSERT ... ON CONFLICT` (PG 9.5+) |
| **Key syntax** | `INSERT INTO ... ON CONFLICT (col) DO UPDATE SET ...` |
| **MERGE added** | PostgreSQL 15 |

---

## When To Use It

Use upserts when you're syncing data from an external source (each sync re-inserts all records), maintaining counters or aggregates (increment if exists, create if not), or processing event streams where the same event might arrive twice (idempotent writes). Upserts eliminate the classic read-then-write race condition: without them, two concurrent transactions could both check "does this row exist?", both find no, and both INSERT — causing a duplicate key error or a duplicate row. The `ON CONFLICT` clause makes this atomic.

---

## Core Concept

`INSERT ... ON CONFLICT` targets a specific constraint (a unique index or primary key). When the INSERT would violate that constraint, PostgreSQL takes the alternate path: either do nothing (ON CONFLICT DO NOTHING) or run an UPDATE on the conflicting row (ON CONFLICT DO UPDATE). The UPDATE has access to both `EXCLUDED` (the row that was trying to be inserted) and the existing row in the table — which enables patterns like "only update if the new value is newer."

MERGE (PostgreSQL 15+, SQL:2003 standard) is more expressive: it can handle INSERT, UPDATE, and DELETE in a single statement based on whether rows match or don't match between a source and a target. It's the right tool for complex synchronisation patterns, but ON CONFLICT is simpler and sufficient for most upsert needs.

---

## Version History

| Standard / Version | What changed |
|---|---|
| SQL:2003 | MERGE statement standardized |
| PostgreSQL 9.5 | `INSERT ... ON CONFLICT` added |
| PostgreSQL 15 | `MERGE` statement added (SQL:2003 compliant) |
| MySQL 5.x | `INSERT ... ON DUPLICATE KEY UPDATE` (non-standard) |
| SQL Server | `MERGE` statement (non-standard extensions) |

---

## Performance

| Pattern | Cost | Notes |
|---|---|---|
| `ON CONFLICT DO NOTHING` | INSERT cost + index check | Cheap — no UPDATE overhead on conflict |
| `ON CONFLICT DO UPDATE` | INSERT cost + UPDATE on conflict | Slightly heavier — UPDATE acquires a row lock |
| `MERGE` | Depends on join size | Full table scan of source; appropriate for bulk sync |
| Read-then-write (without ON CONFLICT) | 2× round trips + race condition risk | Never correct for concurrent workloads |

**Allocation behaviour:** `ON CONFLICT DO UPDATE` creates a dead row for the old version of the updated row (MVCC). On high-upsert tables, this accumulates dead rows faster than on plain INSERT tables. Autovacuum settings may need tuning: lower `autovacuum_vacuum_scale_factor` for tables with heavy upsert traffic.

---

## The Code

**ON CONFLICT DO NOTHING — idempotent insert**
```sql
-- Insert if not exists; silently skip if it already does
INSERT INTO user_preferences (user_id, key, value)
VALUES (42, 'theme', 'dark')
ON CONFLICT (user_id, key) DO NOTHING;
-- Requires a UNIQUE constraint on (user_id, key)
```

**ON CONFLICT DO UPDATE — insert or update**
```sql
-- Insert or update: EXCLUDED refers to the row that was trying to be inserted
INSERT INTO user_preferences (user_id, key, value, updated_at)
VALUES (42, 'theme', 'dark', NOW())
ON CONFLICT (user_id, key)
DO UPDATE SET
    value      = EXCLUDED.value,
    updated_at = EXCLUDED.updated_at;
```

**ON CONFLICT — only update if the new data is actually newer**
```sql
-- Conditional update: don't overwrite a newer value with an older one
INSERT INTO product_prices (product_id, price, price_date)
VALUES (101, 29.99, '2024-04-13')
ON CONFLICT (product_id)
DO UPDATE SET
    price      = EXCLUDED.price,
    price_date = EXCLUDED.price_date
WHERE product_prices.price_date < EXCLUDED.price_date;  -- only update if newer
-- If the WHERE is false, the row is NOT updated — the conflict is silently ignored
```

**ON CONFLICT — increment a counter atomically**
```sql
-- Maintain a daily page view counter — increment on each event
INSERT INTO page_view_counts (page_id, view_date, view_count)
VALUES (:page_id, CURRENT_DATE, 1)
ON CONFLICT (page_id, view_date)
DO UPDATE SET
    view_count = page_view_counts.view_count + 1;
    -- page_view_counts.view_count = current value in the table
    -- EXCLUDED.view_count = 1 (what we tried to insert)
    -- Using the table-prefixed name gives us the current stored value
```

**ON CONFLICT with WHERE on conflict target (partial unique index)**
```sql
-- A partial unique index: unique only on active records
CREATE UNIQUE INDEX idx_emails_active
ON users (email) WHERE is_active = true;

-- Upsert targeting that partial index
INSERT INTO users (email, is_active, created_at)
VALUES ('ahmed@example.com', true, NOW())
ON CONFLICT (email) WHERE is_active = true   -- must match the partial index predicate
DO UPDATE SET
    is_active  = EXCLUDED.is_active,
    updated_at = NOW();
```

**RETURNING — get the upserted row back**
```sql
INSERT INTO tags (name, slug)
VALUES ('PostgreSQL', 'postgresql')
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name
RETURNING id, name, slug;
-- Returns the row whether it was inserted or updated
-- Useful to get the ID without a separate SELECT
```

**Bulk upsert from a staging table**
```sql
-- Efficient for syncing large external datasets
INSERT INTO products (sku, name, price, updated_at)
SELECT sku, name, price, NOW()
FROM staging_products_import
ON CONFLICT (sku)
DO UPDATE SET
    name       = EXCLUDED.name,
    price      = EXCLUDED.price,
    updated_at = EXCLUDED.updated_at
WHERE products.price       IS DISTINCT FROM EXCLUDED.price
   OR products.name        IS DISTINCT FROM EXCLUDED.name;
-- IS DISTINCT FROM handles NULLs correctly — only update rows that actually changed
```

**MERGE (PostgreSQL 15+) — full sync with insert, update, and delete**
```sql
-- Synchronise a target table from a source — insert new, update changed, delete removed
MERGE INTO products AS target
USING staging_products AS source
    ON target.sku = source.sku

WHEN MATCHED AND target.price != source.price THEN
    UPDATE SET
        price      = source.price,
        updated_at = NOW()

WHEN MATCHED THEN
    -- Matched and price is the same — do nothing (implicit in MERGE)
    DO NOTHING

WHEN NOT MATCHED BY TARGET THEN
    -- In source but not target — insert
    INSERT (sku, name, price, created_at)
    VALUES (source.sku, source.name, source.price, NOW())

WHEN NOT MATCHED BY SOURCE THEN
    -- In target but not source — delete (product was removed upstream)
    DELETE;
```

---

## Real World Example

A data pipeline syncs product catalogue records from an upstream ERP system every 15 minutes. The pipeline downloads all active products and upserts them into the local database — inserting new ones, updating changed ones, and preserving local enrichment fields (like internal_notes) that the ERP doesn't know about.

```sql
-- Staging: raw import from ERP
CREATE TEMP TABLE erp_import (
    sku         TEXT NOT NULL,
    name        TEXT NOT NULL,
    category    TEXT,
    msrp        NUMERIC(10, 2),
    is_active   BOOLEAN NOT NULL DEFAULT true
) ON COMMIT DROP;

-- (populate staging_products from ERP API response here)

-- Upsert: sync ERP data without clobbering local enrichment fields
WITH upsert AS (
    INSERT INTO products (sku, name, category, msrp, is_active, erp_synced_at, created_at)
    SELECT
        sku, name, category, msrp, is_active, NOW(), NOW()
    FROM erp_import
    ON CONFLICT (sku)
    DO UPDATE SET
        name          = EXCLUDED.name,
        category      = EXCLUDED.category,
        msrp          = EXCLUDED.msrp,
        is_active     = EXCLUDED.is_active,
        erp_synced_at = EXCLUDED.erp_synced_at
    -- internal_notes is NOT updated — it's local enrichment the ERP doesn't own
    WHERE (products.name, products.category, products.msrp, products.is_active)
       IS DISTINCT FROM
          (EXCLUDED.name, EXCLUDED.category, EXCLUDED.msrp, EXCLUDED.is_active)
    RETURNING id, sku, (xmax = 0) AS was_inserted  -- xmax = 0 means it was inserted, not updated
)
SELECT
    COUNT(*) FILTER (WHERE was_inserted)     AS new_products,
    COUNT(*) FILTER (WHERE NOT was_inserted) AS updated_products
FROM upsert;
```

*The key insight: `IS DISTINCT FROM` on a tuple compares all columns at once and handles NULLs correctly — the WHERE clause ensures we only write to rows that actually changed, avoiding unnecessary dead row creation. The `xmax = 0` trick in RETURNING distinguishes inserts from updates without a second query.*

---

## Common Misconceptions

**"ON CONFLICT DO UPDATE updates the row unconditionally"**
The DO UPDATE SET clause can include a WHERE condition. If that condition is false, no update happens — the conflict is silently resolved by doing nothing. This is distinct from ON CONFLICT DO NOTHING, which never runs the SET expressions at all.

**"MERGE and upsert are interchangeable"**
ON CONFLICT handles insert-or-update against a single target row identified by a unique constraint. MERGE can do insert, update, AND delete in one statement based on a full join between source and target — it's designed for full sync patterns where rows not in the source should be deleted. For simple upserts, ON CONFLICT is simpler and less error-prone.

**"Upserts prevent all duplicate-insert races"**
ON CONFLICT correctly handles concurrent inserts on the same key — only one wins, the other triggers the conflict action. However, if you have a compound unique constraint and the values arrive in different transactions concurrently, the conflict detection is limited to rows that fully match the constraint columns. Design your unique indexes carefully to cover exactly the right scope.

---

## Gotchas

- **You must have a UNIQUE constraint or index for ON CONFLICT to target** — ON CONFLICT requires a specific conflict target (column name, constraint name, or expression). If the constraint doesn't exist, the statement fails. Create the constraint or unique index first.

- **`EXCLUDED` refers to the row that was trying to be inserted, not the existing row** — the existing row in the table is referenced by the table name. `EXCLUDED.price` = new price. `products.price` = current stored price. Mixing these up produces subtle incorrect updates.

- **DO UPDATE creates dead rows** — every ON CONFLICT DO UPDATE that actually updates generates a dead row. On high-frequency upsert tables this causes table bloat faster than plain inserts. Tune autovacuum scale factors down for these tables.

- **MERGE in PostgreSQL 15 doesn't support RETURNING** — unlike ON CONFLICT, MERGE cannot return the modified rows. If you need the affected row IDs, use ON CONFLICT with RETURNING, or run a separate query after the MERGE.

- **IS DISTINCT FROM for conditional update is important** — without it, you may update rows to identical values on every sync cycle, generating unnecessary dead rows and WAL traffic. Always add a WHERE clause to ON CONFLICT DO UPDATE that checks whether anything actually changed.

---

## Interview Angle

**What they're really testing:** Whether you know how to write atomically correct idempotent writes and understand the race conditions that make "check then insert" patterns incorrect.

**Common question forms:**
- "How would you implement a counter that increments when a row exists or inserts with a starting value when it doesn't?"
- "How do you avoid duplicate inserts when two concurrent requests come in for the same record?"
- "What's the difference between ON CONFLICT DO NOTHING and ON CONFLICT DO UPDATE?"

**The depth signal:** A junior reaches for a SELECT then INSERT pattern. A senior goes straight to ON CONFLICT, knows that EXCLUDED refers to the proposed insert row (not the existing row), understands that ON CONFLICT requires a unique constraint, and knows that the WHERE clause on DO UPDATE makes it conditional. They also know the xmax = 0 trick to detect inserts vs updates in RETURNING, use IS DISTINCT FROM for NULL-safe change detection, and can explain when MERGE is more appropriate than ON CONFLICT for full sync patterns.

**Follow-up questions to expect:**
- "What happens if two concurrent transactions both try to upsert the same row?"
- "How would you use MERGE to synchronise a table and delete rows no longer in the source?"

---

## Related Topics

- [[databases/sql/sql-transactions.md]] — upserts run inside transactions; conflict resolution is atomic
- [[databases/sql/sql-null-handling.md]] — `IS DISTINCT FROM` is the NULL-safe comparison for conditional updates
- [[databases/sql/sql-indexing.md]] — ON CONFLICT requires a unique index to target
- [[databases/sql/sql-locking-blocking.md]] — ON CONFLICT DO UPDATE acquires a row lock on conflict

---

## Source

https://www.postgresql.org/docs/current/sql-insert.html

---
*Last updated: 2026-04-13*