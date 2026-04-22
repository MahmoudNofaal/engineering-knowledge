# SQL Temporary Tables & Temp Storage

> A temporary table is a table that exists only for the duration of a session or transaction — it holds intermediate data without touching the permanent schema.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Session- or transaction-scoped table for intermediate data |
| **Use when** | Multi-step transformations; intermediate results too large or complex for a single CTE |
| **Avoid when** | A CTE is already readable and results are referenced once |
| **Standard** | SQL-92 (`CREATE TEMPORARY TABLE`); ON COMMIT behaviour varies |
| **PostgreSQL options** | `ON COMMIT PRESERVE ROWS` (default) · `ON COMMIT DELETE ROWS` · `ON COMMIT DROP` |
| **Alternative** | Unlogged tables: permanent but no WAL — fast writes, lost on crash |

---

## When To Use It

Use temporary tables when you need to store intermediate results that are too large or complex to express cleanly in a single CTE or subquery — multi-step ETL, staging data before bulk inserts, or when the same expensive intermediate result is needed multiple times in a session. They're also useful when the intermediate result needs an index for subsequent queries. Avoid them for results that fit cleanly in a CTE or when you're reaching for them just to avoid writing a complex query — that complexity doesn't disappear, it just moves.

---

## Core Concept

A temporary table behaves like a regular table for the duration of a session or transaction — you can INSERT, UPDATE, DELETE, index, and query it exactly like a permanent table. The database automatically drops it when the session ends (or the transaction ends if created with `ON COMMIT DROP`). Each session gets its own private copy — two sessions creating a temp table with the same name don't interfere with each other.

In PostgreSQL, temp tables live in a special per-session schema (`pg_temp_N`) that sits at the front of the search path, which is why they shadow permanent tables of the same name — a common gotcha.

Unlogged tables are a related concept: permanent tables that skip WAL logging. They're much faster to write to than regular tables (no transaction log overhead) but lose all data on crash. They're useful for intermediate processing in long-running pipelines where you want the table to survive across sessions but don't need crash safety.

---

## Version History

| PostgreSQL Version | What changed |
|---|---|
| SQL-92 | `CREATE TEMPORARY TABLE` and ON COMMIT behaviour standardized |
| PostgreSQL 9.1 | `UNLOGGED` table type added |
| PostgreSQL 12 | Temp table performance improvements in MVCC overhead |
| PostgreSQL 15 | Better temp table statistics handling |

---

## Performance

| Operation | Temp table | CTE | Notes |
|---|---|---|---|
| Single-use intermediate result | CTE (inline) | CTE | CTEs are cleaner for single use |
| Reused multiple times | Temp table | CTE (may re-execute) | Temp table computes once; inlined CTE may not |
| Large intermediate set | Temp table + index | CTE | Temp table can be indexed; CTEs cannot |
| Across multiple queries | Temp table | Not possible | CTEs are scoped to one query |
| Write-heavy intermediate | Unlogged table | N/A | Unlogged tables skip WAL; 2-5× faster writes |

**Allocation behaviour:** Temp tables use the shared buffer pool for reads but write to temp files under `temp_buffers` (default: 8MB per session). For large temp tables, increase `temp_buffers` per session before creating the table. Unlogged tables use the regular shared buffer pool but skip WAL — they're visible to all sessions after creation.

---

## The Code

**Basic temporary table — dropped at session end**
```sql
CREATE TEMP TABLE staging_orders (
    order_id        INT,
    user_id         INT,
    total_amount    NUMERIC,
    status          TEXT
);

INSERT INTO staging_orders
SELECT id, user_id, total_amount, status
FROM orders
WHERE created_at >= '2024-01-01';

-- Work with it like a normal table
SELECT user_id, SUM(total_amount) AS total
FROM staging_orders
WHERE status = 'completed'
GROUP BY user_id;

-- Dropped automatically when session closes
-- Or drop explicitly:
DROP TABLE IF EXISTS staging_orders;
```

**ON COMMIT DROP — dropped at transaction end**
```sql
BEGIN;

CREATE TEMP TABLE dedup_check (
    email TEXT
) ON COMMIT DROP;   -- gone as soon as transaction commits or rolls back

INSERT INTO dedup_check
SELECT DISTINCT email FROM raw_imports;

SELECT COUNT(*) FROM dedup_check;

COMMIT;
-- dedup_check is gone — no cleanup needed
```

**ON COMMIT DELETE ROWS — structure persists, data cleared**
```sql
-- Structure is reused per transaction; rows are cleared after each commit
-- Useful in stored procedures called repeatedly in a session

CREATE TEMP TABLE batch_results (
    id     INT,
    result TEXT
) ON COMMIT DELETE ROWS;

BEGIN;
INSERT INTO batch_results VALUES (1, 'ok'), (2, 'failed');
-- Process results...
COMMIT;
-- Rows gone, table still exists for the next transaction
```

**Indexing a temporary table for better query performance**
```sql
CREATE TEMP TABLE large_staging AS
SELECT * FROM raw_events WHERE event_date >= '2024-01-01';

-- Add indexes before querying — same syntax as permanent tables
CREATE INDEX ON large_staging (user_id);
CREATE INDEX ON large_staging (event_type, event_date);

-- Now queries against large_staging use these indexes
SELECT user_id, COUNT(*)
FROM large_staging
WHERE event_type = 'purchase'
GROUP BY user_id;
```

**Increase temp_buffers for large temp tables**
```sql
-- temp_buffers controls how much of a temp table stays in memory
-- Set per-session BEFORE creating temp tables (setting has no effect after)
SET temp_buffers = '256MB';   -- session-level

CREATE TEMP TABLE large_staging AS
SELECT * FROM large_table;   -- will use up to 256MB of memory before spilling to disk
```

**Temp table vs CTE — when to switch**
```sql
-- CTE: referenced once, simple intermediate result
WITH recent AS (
    SELECT * FROM orders WHERE created_at > NOW() - INTERVAL '7 days'
)
SELECT user_id, COUNT(*) FROM recent GROUP BY user_id;

-- Temp table: referenced multiple times, or result is expensive to compute
CREATE TEMP TABLE recent_orders AS
SELECT * FROM orders WHERE created_at > NOW() - INTERVAL '7 days';

CREATE INDEX ON recent_orders (user_id);

SELECT user_id, COUNT(*) FROM recent_orders GROUP BY user_id;          -- query 1
SELECT status, SUM(total_amount) FROM recent_orders GROUP BY status;   -- query 2
SELECT * FROM recent_orders WHERE total_amount > 500;                   -- query 3
-- Computed once, indexed, queried three times
```

**Unlogged table — permanent but no WAL**
```sql
-- Unlogged tables: visible across sessions, survive pg_ctl stop/start gracefully,
-- but lose all data on crash or unclean shutdown

CREATE UNLOGGED TABLE processing_queue (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payload     JSONB NOT NULL,
    status      TEXT NOT NULL DEFAULT 'pending',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Write performance is typically 2-5× faster than regular tables
-- because no WAL records are generated for DML

-- Add index like a regular table
CREATE INDEX ON processing_queue (status, created_at) WHERE status = 'pending';

-- Drop when done with the pipeline
DROP TABLE IF EXISTS processing_queue;
```

---

## Real World Example

A nightly ETL pipeline ingests 10 million event records, cleans them, deduplicates by user and event type, joins with user metadata, and writes summary records. Doing this in a single multi-join query is unreadable and can't be optimised per-step. Temporary tables let each step be developed, tested, and indexed independently.

```sql
-- Pipeline uses temp tables with ON COMMIT DELETE ROWS for clean state per run
-- (called from a stored procedure; each step is in its own transaction)

-- Step 1: stage raw events (deduplicated)
CREATE TEMP TABLE IF NOT EXISTS tmp_staged_events (
    user_id         INT,
    event_type      TEXT,
    event_date      DATE,
    event_count     INT,
    PRIMARY KEY (user_id, event_type, event_date)
) ON COMMIT DELETE ROWS;

BEGIN;
INSERT INTO tmp_staged_events (user_id, event_type, event_date, event_count)
SELECT
    user_id,
    event_type,
    event_date::DATE,
    COUNT(*)
FROM raw_events_ingest
WHERE ingested_at >= NOW() - INTERVAL '25 hours'   -- allow some overlap
GROUP BY user_id, event_type, event_date::DATE
ON CONFLICT (user_id, event_type, event_date)
DO UPDATE SET event_count = EXCLUDED.event_count;
COMMIT;

-- Step 2: enrich with user metadata (index the join key first)
CREATE INDEX IF NOT EXISTS idx_tmp_staged_user ON tmp_staged_events (user_id);

CREATE TEMP TABLE IF NOT EXISTS tmp_enriched (
    user_id         INT,
    country         TEXT,
    plan_tier       TEXT,
    event_type      TEXT,
    event_date      DATE,
    event_count     INT
) ON COMMIT DELETE ROWS;

BEGIN;
INSERT INTO tmp_enriched
SELECT
    s.user_id, u.country, u.plan_tier,
    s.event_type, s.event_date, s.event_count
FROM tmp_staged_events s
INNER JOIN users u ON u.id = s.user_id
WHERE u.is_active = true;
COMMIT;

-- Step 3: write to final summary table
BEGIN;
INSERT INTO event_summary_daily
    (user_id, country, plan_tier, event_type, event_date, event_count, updated_at)
SELECT *, NOW() FROM tmp_enriched
ON CONFLICT (user_id, event_type, event_date)
DO UPDATE SET
    event_count = EXCLUDED.event_count,
    updated_at  = EXCLUDED.updated_at;
COMMIT;
```

*The key insight: using `ON COMMIT DELETE ROWS` instead of `ON COMMIT DROP` means the table structure and its index are created once and reused across daily runs — only the data is cleared. The index on `user_id` is created after step 1's bulk insert rather than before, avoiding the overhead of maintaining the index during the insert. Each step is a separate committed transaction, so a failure in step 3 doesn't roll back the expensive step 1 deduplication work.*

---

## Common Misconceptions

**"Temp tables shadow permanent tables of the same name silently"**
PostgreSQL puts `pg_temp_N` at the front of the search path. If you `CREATE TEMP TABLE users`, every reference to `users` in that session hits the temp table — not the real one. This causes silent wrong results with no error. Always use distinct, prefixed names for temp tables (`tmp_`, `staging_`, `work_`).

**"ON COMMIT DROP is the safest default"**
It depends on usage. ON COMMIT DROP means the table disappears when the transaction commits — useful for transaction-scoped work. But if used inside a stored procedure that calls COMMIT partway through, the temp table created earlier is gone before subsequent steps run. ON COMMIT DELETE ROWS is safer for procedures that COMMIT mid-execution and want to reuse the table structure.

**"Temp tables don't need VACUUM"**
Regular tables get autovacuumed; temp tables don't. If you insert and delete heavily from a temp table in a long session, dead rows accumulate and the table bloats. For temp tables used intensively within a long session, running `VACUUM` manually keeps them lean. For short-lived temp tables (dropped after each use), this doesn't matter.

---

## Gotchas

- **Temp tables shadow permanent tables of the same name** — PostgreSQL's `pg_temp_N` schema sits first in the search path. Name all temp tables with a prefix to prevent accidental shadowing.

- **Indexes on temp tables are not created automatically** — a temp table created with `CREATE TEMP TABLE AS SELECT ...` has no indexes. On large staging tables, unindexed queries are full scans. Add indexes explicitly after creation if you'll query the table repeatedly.

- **`ON COMMIT DROP` doesn't work outside an explicit transaction** — if you're in autocommit mode (outside `BEGIN`), the table is dropped immediately after creation. Always wrap ON COMMIT DROP usage in an explicit transaction block.

- **`temp_buffers` must be set before creating temp tables** — the setting has no effect on temp tables that already exist. Set it at the beginning of the session before any temp table creation.

- **Unlogged tables lose data on crash** — unlike regular tables which are crash-safe via WAL, unlogged tables are truncated on crash recovery. Use them for intermediate processing, never for data you can't reconstruct.

---

## Interview Angle

**What they're really testing:** Whether you know when intermediate storage is the right tool and understand the operational differences between temp tables, CTEs, and unlogged tables.

**Common question forms:**
- "How would you handle a multi-step data transformation in SQL?"
- "When would you use a temp table instead of a CTE?"
- "What's an unlogged table and when would you use one?"

**The depth signal:** A junior knows temp tables exist and that they disappear after the session. A senior distinguishes the three ON COMMIT behaviours, knows temp tables shadow permanent tables of the same name via search path priority, understands that autovacuum doesn't run on temp tables, and reaches for ON COMMIT DELETE ROWS inside procedures to reuse table structure. They also know the CTE vs temp table call: CTE for single-use intermediate results within one query, temp table when the result is expensive, referenced multiple times, or needs to be indexed. Knowing unlogged tables and their crash-unsafe tradeoff is a strong differentiator.

**Follow-up questions to expect:**
- "What are the three ON COMMIT options and when would you use each?"
- "How do you find out if a temp table is using memory vs spilling to disk?"

---

## Related Topics

- [[databases/sql/sql-ctes.md]] — CTEs are the lightweight alternative for single-use intermediate results
- [[databases/sql/sql-views.md]] — materialized views are the persistent alternative for cross-session reuse
- [[databases/sql/sql-stored-procedures.md]] — temp tables are frequently used inside procedures for multi-step transformations
- [[databases/sql/sql-query-optimization.md]] — large unindexed temp tables are a common performance trap

---

## Source

https://www.postgresql.org/docs/current/sql-createtable.html

---
*Last updated: 2026-04-13*