# SQL Temporary Tables & Temp Storage

> A temporary table is a table that exists only for the duration of a session or transaction — it holds intermediate data without touching permanent schema.

---

## When To Use It
Use temporary tables when you need to store intermediate results that are too large or too complex to express cleanly in a single CTE or subquery — multi-step ETL transformations, staging data before bulk inserts, or breaking a single monster query into auditable steps. They're also useful when the same intermediate result is needed multiple times in a session and recomputing it is expensive. Avoid them for results that fit cleanly in a CTE, or when you're reaching for them just to avoid writing a complex query — that complexity doesn't disappear, it just moves.

---

## Core Concept
A temporary table behaves like a regular table for the duration of a session or transaction — you can INSERT, UPDATE, DELETE, index, and query it exactly like a permanent table. The database automatically drops it when the session ends (or transaction ends, if created with ON COMMIT DROP). Each session gets its own private copy — two sessions creating a temp table with the same name don't interfere with each other. In PostgreSQL, temp tables live in a special per-session schema (`pg_temp_N`) that sits at the front of the search path, which is why they shadow permanent tables of the same name.

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
) ON COMMIT DROP;   -- gone as soon as this transaction commits or rolls back

INSERT INTO dedup_check
SELECT DISTINCT email FROM raw_imports;

-- Use within this transaction only
SELECT COUNT(*) FROM dedup_check;

COMMIT;
-- staging_orders is gone — no cleanup needed
```

**ON COMMIT DELETE ROWS — structure persists, data cleared**
```sql
-- Useful in stored procedures called repeatedly in a session
-- Table structure is reused; rows are cleared after each transaction

CREATE TEMP TABLE batch_results (
    id          INT,
    result      TEXT
) ON COMMIT DELETE ROWS;

BEGIN;
INSERT INTO batch_results VALUES (1, 'ok'), (2, 'failed');
-- Process results...
COMMIT;
-- Rows gone, table still exists for next call
```

**Indexing a temporary table**
```sql
CREATE TEMP TABLE large_staging AS
SELECT * FROM raw_events WHERE event_date >= '2024-01-01';

-- Add an index before querying — same syntax as permanent tables
CREATE INDEX ON large_staging (user_id);
CREATE INDEX ON large_staging (event_type, event_date);

-- Now queries against large_staging can use these indexes
SELECT user_id, COUNT(*)
FROM large_staging
WHERE event_type = 'purchase'
GROUP BY user_id;
```

**CREATE TEMP TABLE AS — create and populate in one step**
```sql
CREATE TEMP TABLE high_value_users AS
SELECT
    u.id,
    u.email,
    SUM(o.total_amount) AS lifetime_value
FROM users u
INNER JOIN orders o ON o.user_id = u.id
WHERE o.status = 'completed'
GROUP BY u.id, u.email
HAVING SUM(o.total_amount) > 1000;

-- Reuse multiple times in the session without recomputing
SELECT * FROM high_value_users WHERE lifetime_value > 5000;
SELECT COUNT(*) FROM high_value_users;
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

SELECT user_id, COUNT(*) FROM recent_orders GROUP BY user_id;
SELECT status, SUM(total_amount) FROM recent_orders GROUP BY status;
SELECT * FROM recent_orders WHERE total_amount > 500;
-- Computed once, queried three times — CTE would recompute each time
```

**Using temp tables in stored procedures**
```sql
CREATE OR REPLACE PROCEDURE process_daily_report(report_date DATE)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Stage the data
    CREATE TEMP TABLE daily_data ON COMMIT DROP AS
    SELECT user_id, SUM(total_amount) AS daily_spend
    FROM orders
    WHERE created_at::date = report_date
      AND status = 'completed'
    GROUP BY user_id;

    -- Apply tier logic
    UPDATE daily_data
    SET daily_spend = daily_spend * 0.9
    WHERE user_id IN (
        SELECT id FROM users WHERE plan_type = 'premium'
    );

    -- Write final result
    INSERT INTO daily_report_summary (report_date, user_id, adjusted_spend)
    SELECT report_date, user_id, daily_spend
    FROM daily_data;

    COMMIT;
END;
$$;
```

---

## Gotchas

- **Temp tables shadow permanent tables of the same name** — PostgreSQL puts `pg_temp_N` at the front of the search path. If you CREATE TEMP TABLE users, every reference to `users` in that session hits the temp table, not the real one. This causes silent wrong results with no error. Always use distinct, prefixed names for temp tables (`tmp_`, `staging_`, etc.).
- **Temp tables don't inherit autovacuum** — permanent tables get autovacuumed automatically; temp tables don't. If you insert and delete heavily from a temp table in a long session, dead rows accumulate and bloat the temp table. Run `VACUUM` manually on temp tables used heavily within a long session, or recreate them.
- **Indexes on temp tables are not created automatically** — unlike primary keys on permanent tables, a temp table created with `CREATE TEMP TABLE AS SELECT ...` has no indexes. On large staging tables, queries without indexes are full scans. Add indexes explicitly after creation if you'll query the temp table repeatedly.
- **ON COMMIT DROP doesn't work outside a transaction** — if you create a temp table with ON COMMIT DROP and you're in autocommit mode (outside an explicit BEGIN), the table is dropped immediately after creation. Always wrap ON COMMIT DROP usage in an explicit transaction.
- **Temp tables count against connection memory** — each temp table uses server memory and temp disk space (controlled by `temp_buffers`). In a connection pool where sessions are long-lived, forgotten temp tables from previous requests accumulate. Always drop temp tables explicitly when done, or use ON COMMIT DROP for transaction-scoped usage.

---

## Interview Angle
**What they're really testing:** Whether you know when intermediate storage is the right tool and understand the operational differences between temp tables, CTEs, and materialized views.

**Common question form:** "How would you handle a multi-step data transformation in SQL?" or "When would you use a temp table instead of a CTE?"

**The depth signal:** A junior knows temp tables exist and that they disappear after the session. A senior distinguishes the three ON COMMIT behaviors, knows that temp tables shadow permanent tables of the same name via search path priority, understands that autovacuum doesn't run on temp tables, and reaches for ON COMMIT DROP inside procedures to avoid manual cleanup. They also make the CTE vs temp table call based on whether the result is referenced once (CTE) or multiple times with large data (temp table), and know that `temp_buffers` controls how much of the temp table stays in memory before spilling to disk.

---

## Related Topics
- [[databases/sql-ctes.md]] — CTEs are the lightweight alternative for single-use intermediate results within one query
- [[databases/sql-views.md]] — materialized views are the persistent alternative when intermediate results need to survive across sessions
- [[databases/sql-stored-procedures.md]] — temp tables are frequently used inside procedures for multi-step transformations
- [[databases/query-optimization.md]] — large unindexed temp tables are a common performance trap; index them after creation

---

## Source
https://www.postgresql.org/docs/current/sql-createtable.html

---
*Last updated: 2026-03-24*