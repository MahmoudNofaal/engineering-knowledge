# SQL Locking & Blocking

> Locks are how the database serializes concurrent access to the same data — blocking is what happens when one transaction has to wait for another to release a lock before it can proceed.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Mechanism for serializing concurrent access; blocking is the wait that results |
| **Use when** | Understanding is mandatory — the database acquires locks automatically |
| **Avoid when** | Long transactions; DDL in production without `lock_timeout`; holding locks across I/O |
| **Standard** | Implementation-defined; PostgreSQL uses MVCC for reads + explicit locks for writes |
| **Key views** | `pg_locks`, `pg_stat_activity`, `pg_blocking_pids()` |
| **Key settings** | `lock_timeout`, `statement_timeout`, `idle_in_transaction_session_timeout` |

---

## When To Use It

Understanding locking matters any time you have concurrent writes, long-running transactions, or DDL operations on live tables. Blocking is the most common cause of query timeouts and connection pool exhaustion that isn't explained by the query itself being slow. You don't choose to use locking — the database does it automatically — but you choose how long your transactions are, what isolation level you use, and how you sequence operations. All of these determine how much blocking you cause.

---

## Core Concept

Every write acquires a lock. Most locks are held only for the duration of a statement in autocommit mode; transaction-level locks are held until COMMIT or ROLLBACK. Locks have modes — some are compatible with each other (multiple readers don't block each other), some aren't (a writer blocks other writers on the same row). When transaction A holds a lock that transaction B needs, B waits. If A never releases it, B waits forever — or until a `lock_timeout` fires.

Lock queues amplify the problem. If A holds a lock and B is waiting, any new transaction C that needs even a compatible lock on the same table must also wait behind B. A single long-running transaction at the front of the queue can cause connection pool exhaustion within seconds on a high-traffic table.

Deadlock is a special case: A waits for B, B waits for A. PostgreSQL detects deadlocks and aborts one transaction — the prevention is consistent lock ordering in application code.

---

## Version History

| PostgreSQL Version | What changed |
|---|---|
| Pre-8.0 | Table-level and row-level locking, basic lock modes |
| 9.0 | `pg_blocking_pids()` function (simplified blocking detection) |
| 9.1 | Skip locked rows: `FOR UPDATE SKIP LOCKED` / `FOR SHARE SKIP LOCKED` |
| 9.5 | `FOR NO KEY UPDATE`, `FOR KEY SHARE` lock modes added |
| 12 | `REINDEX CONCURRENTLY` avoids strong index lock |
| 14 | Improvements to lock contention under high concurrency |

---

## Performance

| Lock type | Strength | Blocks | Notes |
|---|---|---|---|
| `FOR KEY SHARE` | Weakest row lock | Only `FOR UPDATE` | Used by FK checks |
| `FOR SHARE` | Row read lock | `FOR UPDATE`, `FOR NO KEY UPDATE` | Blocks writers, not readers |
| `FOR NO KEY UPDATE` | Row write lock | Most write locks | UPDATE that doesn't change PK |
| `FOR UPDATE` | Strongest row lock | All other row locks | Full exclusive row lock |
| `AccessShareLock` | Table | `AccessExclusiveLock` only | SELECT acquires this |
| `RowShareLock` | Table | `ExclusiveLock`, `AccessExclusiveLock` | SELECT FOR UPDATE |
| `ShareUpdateExclusiveLock` | Table | Most DDL | VACUUM, `CREATE INDEX CONCURRENTLY` |
| `AccessExclusiveLock` | Strongest table lock | Everything | ALTER TABLE, DROP, TRUNCATE |

**The critical number:** `ALTER TABLE` takes `AccessExclusiveLock` — the strongest possible lock. It blocks all reads and writes on the table for the duration. On a busy production table, even a fast `ADD COLUMN` can cause a minutes-long outage if there are long-running queries already holding weaker locks in the queue.

---

## The Code

**Diagnose live blocking right now**
```sql
-- Who is blocked and by whom?
SELECT
    blocked.pid                         AS blocked_pid,
    blocked.query                        AS blocked_query,
    blocking.pid                         AS blocking_pid,
    blocking.query                       AS blocking_query,
    now() - blocked.query_start          AS blocked_duration,
    now() - blocking.query_start         AS blocking_duration
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.wait_event_type = 'Lock';
```

**View all current locks**
```sql
SELECT
    pid,
    relation::regclass  AS table_name,
    mode,
    granted,
    left(query, 80)     AS query
FROM pg_locks
JOIN pg_stat_activity USING (pid)
WHERE relation IS NOT NULL
ORDER BY granted, pid;
```

**Row-level locking — FOR UPDATE**
```sql
BEGIN;

-- Lock the row exclusively
SELECT balance FROM accounts WHERE id = 101 FOR UPDATE;

-- Safe to update: no concurrent transaction can modify this row
UPDATE accounts SET balance = balance - 200 WHERE id = 101;

COMMIT;
-- Lock released — other transactions can now proceed
```

**FOR UPDATE SKIP LOCKED — job queue pattern**
```sql
-- Multiple workers processing a job queue without blocking each other
BEGIN;

SELECT id, payload
FROM jobs
WHERE status = 'pending'
ORDER BY created_at
LIMIT 1
FOR UPDATE SKIP LOCKED;  -- skip rows already locked by another worker

UPDATE jobs SET status = 'processing' WHERE id = :job_id;

COMMIT;
```

**FOR SHARE — read lock, allows other readers, blocks writers**
```sql
BEGIN;

-- Other transactions can also SELECT FOR SHARE (compatible)
-- But nobody can UPDATE or DELETE this row until we commit
SELECT * FROM orders WHERE id = 55 FOR SHARE;

-- Use when you need a stable read for a multi-step computation
-- without needing exclusive write access
COMMIT;
```

**Setting timeouts to prevent indefinite waits**
```sql
-- Per-session: fail if waiting for a lock more than 2 seconds
SET lock_timeout = '2s';

-- Per-transaction only
BEGIN;
SET LOCAL lock_timeout = '500ms';
SET LOCAL statement_timeout = '10s';
UPDATE accounts SET balance = balance - 100 WHERE id = 101;
COMMIT;

-- Idle-in-transaction timeout — kills sessions open but doing nothing
-- Critical for preventing accidental lock holding
SET idle_in_transaction_session_timeout = '60s';
```

**Deadlock: example and prevention**
```sql
-- Transaction A (concurrent with B):
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;  -- locks row 1
-- At this point B has locked row 2 and is waiting for row 1
UPDATE accounts SET balance = balance + 100 WHERE id = 2;  -- waits for row 2
-- DEADLOCK: A waits for B, B waits for A
-- PostgreSQL detects this and aborts one transaction with:
-- ERROR:  deadlock detected

-- PREVENTION: always acquire locks in the same order across all transactions
-- If both A and B always update id=1 before id=2, no deadlock is possible
UPDATE accounts SET balance = balance - 100 WHERE id = LEAST(:a, :b);
UPDATE accounts SET balance = balance + 100 WHERE id = GREATEST(:a, :b);
```

**Advisory locks — application-level mutex**
```sql
-- Useful for coordinating across application instances
-- without locking actual table rows (e.g., ensure only one cron job runs at a time)

-- Session-level (must be released explicitly or connection closes)
SELECT pg_try_advisory_lock(12345);      -- returns true if acquired, false if not
SELECT pg_advisory_lock(12345);          -- blocks until acquired
SELECT pg_advisory_unlock(12345);

-- Transaction-level (auto-released at COMMIT/ROLLBACK — safer)
SELECT pg_advisory_xact_lock(12345);     -- blocks
SELECT pg_try_advisory_xact_lock(12345); -- non-blocking
```

**Kill a blocking process**
```sql
-- Find the blocker
SELECT pid, query, query_start, state
FROM pg_stat_activity
WHERE pid IN (
    SELECT unnest(pg_blocking_pids(pid))
    FROM pg_stat_activity
    WHERE wait_event_type = 'Lock'
);

-- Terminate gracefully (cancels the current query, keeps connection)
SELECT pg_cancel_backend(blocking_pid);

-- Terminate immediately (rolls back the transaction, closes connection)
SELECT pg_terminate_backend(blocking_pid);
```

**Zero-downtime DDL pattern — avoiding AccessExclusiveLock outages**
```sql
-- WRONG: ALTER TABLE directly blocks all reads/writes
ALTER TABLE orders ADD COLUMN notes TEXT;   -- AccessExclusiveLock for full duration

-- BETTER for PG 11+ with default values: still takes AccessExclusiveLock but instantly
-- (PG 11+: adding nullable column with a default doesn't rewrite the table)
ALTER TABLE orders ADD COLUMN notes TEXT DEFAULT '';  -- fast in PG 11+

-- FOR INDEXES: always use CONCURRENTLY
CREATE INDEX CONCURRENTLY idx_orders_notes ON orders (notes);
-- Takes ShareUpdateExclusiveLock — doesn't block reads/writes during build

-- FOR CONSTRAINTS: add NOT VALID, then validate separately
ALTER TABLE orders ADD CONSTRAINT fk_promo
    FOREIGN KEY (promo_id) REFERENCES promos(id) NOT VALID;
-- NOT VALID skips historical row scan — fast, low lock
ALTER TABLE orders VALIDATE CONSTRAINT fk_promo;
-- VALIDATE takes ShareUpdateExclusiveLock — doesn't block reads/writes
```

---

## Real World Example

A high-traffic e-commerce platform experienced periodic 30-second outages every night at 2am. The database connection pool exhausted within 10 seconds each time, causing cascading failures. Root cause: a nightly reporting job ran a SELECT with no timeout that held a `RowShareLock` for 4 minutes — and during that time, a background migration attempted an `ALTER TABLE ADD COLUMN`, which took an `AccessExclusiveLock` request. The ALTER queued behind the report, and every subsequent SELECT on the same table queued behind the ALTER.

```sql
-- Step 1: detect the incident in real time
SELECT
    pid,
    wait_event_type,
    wait_event,
    state,
    now() - query_start     AS duration,
    left(query, 100)         AS query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;

-- Step 2: identify the lock queue
SELECT
    a.pid,
    a.state,
    a.wait_event_type,
    l.mode,
    l.granted,
    left(a.query, 80) AS query
FROM pg_locks l
JOIN pg_stat_activity a USING (pid)
WHERE l.relation = 'orders'::regclass
ORDER BY l.granted DESC, a.query_start;

-- Step 3: terminate the blocking report query (not the migration — it's already queued)
SELECT pg_cancel_backend(
    (SELECT pid FROM pg_stat_activity
     WHERE wait_event_type = 'Lock'
       AND query ILIKE '%orders%'
     ORDER BY query_start
     LIMIT 1)
);

-- Step 4: add protections to prevent recurrence
-- In reporting connection setup:
SET statement_timeout = '120s';       -- report can't run more than 2 minutes
SET lock_timeout = '5s';              -- fail fast if blocked waiting for a lock

-- In migration scripts:
SET lock_timeout = '3s';              -- don't queue behind long-running queries
-- If ALTER fails: script exits, try during lower-traffic window
```

*The key insight: the outage was caused not by the ALTER TABLE itself being slow, but by the lock queue amplification effect. The ALTER's `AccessExclusiveLock` request blocked all subsequent SELECTs — which then piled up until the connection pool exhausted. The fix was two `lock_timeout` settings that prevented either operation from holding or waiting for a lock too long.*

---

## Common Misconceptions

**"Row locks don't affect other tables"**
Row-level locks from `SELECT FOR UPDATE` are row-level, not table-level. But every `SELECT FOR UPDATE` also acquires a `RowShareLock` at the table level — which is compatible with reads and writes, but blocks DDL. DDL then blocks everything else. Understand both levels.

**"VACUUM holds a table lock"**
Regular autovacuum holds a `ShareUpdateExclusiveLock` — compatible with reads and writes. It only blocks `VACUUM FULL` and DDL. `VACUUM FULL` holds `AccessExclusiveLock` (blocks everything) and should almost never be run on live production tables. Use `VACUUM` (without FULL) and `REINDEX CONCURRENTLY` instead.

**"Deadlocks are a database bug"**
Deadlocks are an application code problem. They occur when application code acquires locks in inconsistent orders across concurrent transactions. PostgreSQL detects and resolves them (by aborting one transaction), but the real fix is ensuring all code paths that touch the same rows do so in a consistent order.

---

## Gotchas

- **`ALTER TABLE` takes `AccessExclusiveLock` — the strongest lock** — it blocks all reads and writes on the table for the duration. On a busy table, even a fast DDL statement can cause a minutes-long outage if there are long-running queries already in the queue. Always set `lock_timeout` before running DDL in production.

- **Lock queues amplify blocking exponentially** — if transaction A holds a lock and transaction B is waiting, any new transaction C that needs even a compatible lock on the same table must wait behind B. One long-running transaction at the front creates a pile-up that exhausts connection pools quickly.

- **Idle-in-transaction connections hold locks indefinitely** — a connection in `idle in transaction` state is holding its locks with no active query. The timeout `idle_in_transaction_session_timeout` kills these automatically. Set it in production — a forgotten psql session or application bug can otherwise hold a lock until the connection is manually killed.

- **Deadlocks are caused by inconsistent lock ordering** — PostgreSQL resolves deadlocks by aborting one transaction, but the prevention is application-level: always acquire locks on the same resources in the same order across all code paths.

- **`FOR UPDATE SKIP LOCKED` is the right tool for queues, not `FOR UPDATE`** — using `FOR UPDATE` without SKIP LOCKED in a job queue causes all workers to queue behind the worker that grabbed the first row. SKIP LOCKED lets each worker grab a different row without waiting.

---

## Interview Angle

**What they're really testing:** Whether you understand that blocking is a transaction design problem, can diagnose a live locking incident, and know the lock implications of DDL.

**Common question forms:**
- "Your deployment caused a production outage where queries started timing out — how do you investigate?"
- "What causes a deadlock and how do you prevent it?"
- "How would you add a column to a 500M row production table without downtime?"

**The depth signal:** A junior knows locks exist and that deadlocks are bad. A senior knows that `ALTER TABLE` takes `AccessExclusiveLock` and how lock queue amplification turns a single blocked ALTER into a connection pool exhaustion incident, uses `lock_timeout` as a production safeguard for both DDL and long-running queries, uses `pg_blocking_pids` to diagnose live incidents, and knows the SKIP LOCKED pattern for job queues. They also know that deadlocks are an ordering problem — the fix is consistent lock acquisition order in application code. Knowing the difference between `ShareUpdateExclusiveLock` (VACUUM, CONCURRENTLY operations) and `AccessExclusiveLock` (ALTER TABLE, DROP) is a strong senior signal.

**Follow-up questions to expect:**
- "What's the difference between pg_cancel_backend and pg_terminate_backend?"
- "How does FOR UPDATE SKIP LOCKED work for a job queue?"

---

## Related Topics

- [[databases/sql/sql-transactions.md]] — locks are held for the transaction duration; short transactions minimize blocking
- [[databases/sql/sql-isolation-levels.md]] — higher isolation levels use more lock modes and increase contention
- [[databases/sql/sql-indexing.md]] — `CREATE INDEX` without CONCURRENTLY takes a write-blocking lock
- [[databases/sql/sql-query-optimization.md]] — slow queries hold locks longer; query speed directly reduces blocking windows

---

## Source

https://www.postgresql.org/docs/current/explicit-locking.html

---
*Last updated: 2026-04-13*