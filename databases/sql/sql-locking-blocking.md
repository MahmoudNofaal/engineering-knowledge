# SQL Locking & Blocking

> Locks are how the database serializes concurrent access to the same data — blocking is what happens when one transaction has to wait for another to release a lock before it can proceed.

---

## When To Use It
Understanding locking matters any time you have concurrent writes, long-running transactions, or operations that modify schema in production. Blocking is the most common cause of query timeouts and connection pool exhaustion that isn't explained by the query itself being slow. You don't choose to use locking — the database does it automatically — but you choose how long your transactions are, what isolation level you use, and how you sequence operations, all of which determine how much blocking you cause.

---

## Core Concept
Every read and write acquires a lock. Most locks are held only for the duration of a statement; transaction-level locks are held until COMMIT or ROLLBACK. Locks have modes — some are compatible with each other (multiple readers don't block each other), some aren't (a writer blocks other writers on the same row). When transaction A holds a lock that transaction B needs, B waits. If A never releases it, B waits forever — or until a lock timeout fires. Deadlock is a special case: A waits for B, B waits for A, and neither can proceed. PostgreSQL detects deadlocks automatically and aborts one of the transactions. The practical goal is to keep transactions short, acquire locks in consistent order, and avoid holding locks across slow operations like network calls.

---

## The Code

**See who is blocking whom right now**
```sql
-- Active locks and their waiters
SELECT
    blocking.pid                    AS blocking_pid,
    blocking.query                  AS blocking_query,
    blocked.pid                     AS blocked_pid,
    blocked.query                   AS blocked_query,
    blocked.wait_event_type,
    blocked.wait_event,
    now() - blocking.query_start    AS blocking_duration
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.wait_event_type = 'Lock';
```

**See all current locks**
```sql
SELECT
    pid,
    relation::regclass  AS table_name,
    mode,
    granted,
    query
FROM pg_locks
JOIN pg_stat_activity USING (pid)
WHERE relation IS NOT NULL
ORDER BY granted, pid;
```

**Row-level locking — FOR UPDATE**
```sql
BEGIN;

-- Lock the row exclusively — other transactions block on this row
SELECT balance FROM accounts WHERE id = 101 FOR UPDATE;

-- Safe to update: no concurrent transaction can modify this row
UPDATE accounts SET balance = balance - 200 WHERE id = 101;

COMMIT;
-- Lock released — blocked transactions can now proceed
```

**FOR UPDATE SKIP LOCKED — queue processing pattern**
```sql
-- Multiple workers processing a job queue without blocking each other
BEGIN;

SELECT id, payload
FROM jobs
WHERE status = 'pending'
ORDER BY created_at
LIMIT 1
FOR UPDATE SKIP LOCKED;  -- skip rows already locked by another worker

-- Process the job, then mark it done
UPDATE jobs SET status = 'processing' WHERE id = :job_id;

COMMIT;
```

**FOR SHARE — read lock, block writers but not readers**
```sql
BEGIN;

-- Other transactions can also SELECT FOR SHARE (compatible)
-- But nobody can UPDATE or DELETE this row until we commit
SELECT * FROM orders WHERE id = 55 FOR SHARE;

-- Use when you need to read a row and ensure it isn't modified
-- while you do further work in the same transaction
COMMIT;
```

**Setting lock timeouts to avoid indefinite waits**
```sql
-- Session-level: all locks in this session timeout after 2 seconds
SET lock_timeout = '2s';

-- Transaction-level: applies only to this transaction
BEGIN;
SET LOCAL lock_timeout = '500ms';
UPDATE accounts SET balance = balance - 100 WHERE id = 101;
-- If the row is locked by another transaction, error after 500ms
-- instead of waiting forever
COMMIT;
```

**Statement timeout — kill slow queries before they pile up**
```sql
-- Kill any query that runs longer than 5 seconds
SET statement_timeout = '5s';

-- Useful in application connection setup to prevent runaway queries
-- from holding locks and exhausting connection pools
```

**Deadlock example and prevention**
```sql
-- Transaction A:
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;  -- locks row 1
UPDATE accounts SET balance = balance + 100 WHERE id = 2;  -- waits for row 2

-- Transaction B (concurrent):
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 2;  -- locks row 2
UPDATE accounts SET balance = balance + 100 WHERE id = 1;  -- waits for row 1
-- Deadlock: A waits for B, B waits for A
-- PostgreSQL detects this and aborts one transaction with:
-- ERROR: deadlock detected

-- Prevention: always acquire locks in the same order
-- Both transactions should update id=1 first, then id=2
```

**Advisory locks — application-level mutex**
```sql
-- Useful for coordinating across application instances
-- without locking actual table rows

-- Try to acquire a session-level advisory lock (non-blocking)
SELECT pg_try_advisory_lock(12345);  -- returns true if acquired, false if not

-- Acquire and block until available
SELECT pg_advisory_lock(12345);

-- Release
SELECT pg_advisory_unlock(12345);

-- Transaction-scoped: auto-released on COMMIT/ROLLBACK
SELECT pg_advisory_xact_lock(12345);
```

**Finding and killing a blocking process**
```sql
-- Identify the blocker
SELECT pid, query, query_start, state
FROM pg_stat_activity
WHERE pid IN (
    SELECT unnest(pg_blocking_pids(pid))
    FROM pg_stat_activity
    WHERE wait_event_type = 'Lock'
);

-- Terminate gracefully (waits for the query to finish)
SELECT pg_cancel_backend(blocking_pid);

-- Terminate immediately (rolls back the transaction)
SELECT pg_terminate_backend(blocking_pid);
```

---

## Gotchas

- **`ALTER TABLE` takes an `AccessExclusiveLock` — the strongest lock** — it blocks all reads and writes on the table for the duration. On a busy production table, even a fast `ALTER TABLE ADD COLUMN` can cause a minutes-long outage if there are long-running queries already holding weaker locks. Always check for active queries before running DDL in production, and use lock_timeout to fail fast rather than pile up behind a blocker.
- **Lock queues amplify blocking** — if transaction A holds a lock and transaction B is waiting for it, any new transaction C that needs even a compatible lock on the same table must also wait behind B. A single long-running transaction at the front of the queue can cause connection pool exhaustion within seconds on a high-traffic table.
- **Idle transactions hold locks indefinitely** — a transaction that issues BEGIN and then sits idle (application bug, forgotten psql session, connection pool issue) holds its locks until the connection is closed or the transaction is terminated. `idle_in_transaction_session_timeout` kills these automatically — set it in production.
- **Row-level vs table-level locks are both real** — `SELECT FOR UPDATE` acquires row-level locks, which is fine for targeted updates. But `LOCK TABLE` and DDL statements acquire table-level locks that conflict with everything. Mixing DDL and DML in the same deploy window is a common source of production lock incidents.
- **Deadlocks are a symptom of inconsistent lock ordering** — PostgreSQL resolves deadlocks by aborting one transaction, but the real fix is always to ensure all transactions acquire locks on the same resources in the same order. If deadlocks are frequent, it's a code architecture problem, not a database problem.

---

## Interview Angle
**What they're really testing:** Whether you understand that blocking is a transaction design problem — not just a database problem — and whether you can diagnose and resolve a live locking incident.

**Common question form:** "Your deployment caused a production outage where queries started timing out — how do you investigate?" or "What causes a deadlock and how do you prevent it?"

**The depth signal:** A junior knows locks exist and that deadlocks are bad. A senior knows that `ALTER TABLE` takes an `AccessExclusiveLock` and how to run zero-downtime migrations around it, understands that lock queues amplify blocking exponentially, reaches for `lock_timeout` and `idle_in_transaction_session_timeout` as production safeguards, uses `pg_blocking_pids` to diagnose live incidents, and knows the SKIP LOCKED pattern for job queues. They also understand that deadlocks are an ordering problem — the fix is consistent lock acquisition order in application code, not database configuration.

---

## Related Topics
- [[databases/sql-transactions.md]] — locks are held for the duration of a transaction; short transactions minimize blocking
- [[databases/sql-isolation-levels.md]] — higher isolation levels acquire more locks and increase contention
- [[databases/sql-indexing.md]] — index design affects which rows get locked and whether a FOR UPDATE scan is narrow or wide
- [[databases/query-optimization.md]] — slow queries hold locks longer; optimizing query speed directly reduces blocking windows

---

## Source
https://www.postgresql.org/docs/current/explicit-locking.html

---
*Last updated: 2026-03-24*