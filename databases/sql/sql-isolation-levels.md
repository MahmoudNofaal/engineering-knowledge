# SQL Isolation Levels

> Isolation levels control how much a transaction can see from other concurrent transactions — defining the tradeoff between concurrency and consistency.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Per-transaction setting controlling visibility of concurrent changes |
| **Use when** | Read-then-write logic must be consistent; financial/booking/inventory systems |
| **Avoid when** | Read Committed is sufficient — higher levels add contention and retry complexity |
| **Standard** | SQL-92 (four levels); PostgreSQL uses MVCC (readers never block writers) |
| **Default** | Read Committed (PostgreSQL and MySQL) |
| **Anomalies ladder** | Dirty read → Non-repeatable read → Phantom read → Write skew |

---

## When To Use It

Isolation levels matter any time multiple transactions run concurrently against the same data — which is always in production. The default level (Read Committed) is safe for most OLTP workloads but leaves specific anomalies open. Reach for a higher isolation level when your transaction reads a value and later makes a decision based on it — especially in financial, inventory, or booking systems where a stale read causes a real-world problem (overdraft, oversell, double-booking). Drop to a lower level only when you understand exactly what anomalies you're accepting.

---

## Core Concept

Every database answers the same question: when transaction A is writing, what does transaction B see? The SQL standard defines four levels as a ladder — each preventing more anomalies than the one below it, at the cost of more contention or more retries.

The three anomalies the standard cares about:
- **Dirty read**: seeing another transaction's uncommitted data
- **Non-repeatable read**: the same row returns different values within one transaction
- **Phantom read**: a repeated range query returns different rows

A fourth anomaly the standard misses, but PostgreSQL's SERIALIZABLE prevents:
- **Write skew**: two transactions each read overlapping data, make independent decisions, and both write — producing a state neither would have allowed individually

PostgreSQL implements all isolation via MVCC snapshots. Readers never block writers and writers never block readers at any level. The cost of higher isolation is not read latency — it's serialization failures that require application-level retries.

---

## Version History

| Standard / Version | What changed |
|---|---|
| SQL-92 | Four isolation levels standardized; dirty read, non-repeatable read, phantom read defined |
| PostgreSQL (pre-9.1) | Only Read Committed and Serializable fully implemented |
| PostgreSQL 9.1 | SSI (Serializable Snapshot Isolation) introduced — true SERIALIZABLE via predicate locking |
| MySQL 5.x | All four levels via InnoDB; REPEATABLE READ is the default |

---

## Performance

| Level | Overhead | Concurrency impact | Notes |
|---|---|---|---|
| Read Uncommitted | Minimal | Highest | PostgreSQL upgrades to Read Committed |
| Read Committed | Low | High | Per-statement snapshot; default |
| Repeatable Read | Moderate | Medium | Per-transaction snapshot; no extra locks needed (MVCC) |
| Serializable | Higher | Lower | Predicate lock tracking; serialization failures → retries |

**Allocation behaviour:** PostgreSQL's MVCC keeps old row versions until no transaction needs them. Higher isolation levels hold their snapshots longer, keeping more old versions alive. Long SERIALIZABLE transactions can increase dead row accumulation. The performance cost of SERIALIZABLE is retry overhead under contention — not slower reads.

---

## The Code

**The four levels and their anomaly exposure**
```sql
-- Read Uncommitted: no protection
-- PostgreSQL silently upgrades this to Read Committed
BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- (behaves identically to READ COMMITTED in PostgreSQL)
COMMIT;

-- Read Committed (default): per-statement snapshot
-- Prevents: dirty reads
-- Allows: non-repeatable reads, phantom reads, write skew
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT balance FROM accounts WHERE id = 101;  -- snapshot 1
-- Concurrent transaction commits a change to id=101
SELECT balance FROM accounts WHERE id = 101;  -- snapshot 2 — may see a different value
COMMIT;

-- Repeatable Read: per-transaction snapshot
-- Prevents: dirty reads, non-repeatable reads
-- Allows: phantom reads in MySQL InnoDB (but NOT in PostgreSQL — MVCC prevents them)
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE id = 101;  -- takes a snapshot
-- Concurrent transaction commits a change
SELECT balance FROM accounts WHERE id = 101;  -- SAME value — snapshot is fixed
COMMIT;

-- Serializable: full isolation
-- Prevents: all anomalies including write skew
-- May produce serialization failures (error 40001) — must retry
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT SUM(balance) FROM accounts WHERE user_id = 42;  -- read
UPDATE accounts SET bonus = 100 WHERE user_id = 42;    -- write based on read
-- If concurrent transaction modified accounts for user 42 concurrently:
-- ERROR:  could not serialize access due to concurrent update
COMMIT;
```

**Demonstrating write skew — the anomaly only SERIALIZABLE prevents**
```sql
-- Scenario: Hospital on-call system. Rule: at least one doctor must be on call.
-- Two transactions run concurrently:

-- Transaction A:
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM doctors WHERE on_call = true;   -- returns 2
UPDATE doctors SET on_call = false WHERE id = 1;      -- "I'll go off call"
COMMIT;

-- Transaction B (concurrent):
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM doctors WHERE on_call = true;   -- also returns 2 (same snapshot)
UPDATE doctors SET on_call = false WHERE id = 2;      -- "I'll go off call too"
COMMIT;

-- Result: zero doctors on call — both transactions read 2, both decided it was safe
-- ONLY SERIALIZABLE prevents this by detecting the conflicting read-write dependency
```

**Handling serialization failures with retry**
```sql
-- Application code MUST detect and retry on error code 40001
-- This is not optional — PostgreSQL will not retry automatically

-- Example: retry with exponential backoff
DO $$
DECLARE
    attempts  INT := 0;
    max_tries INT := 5;
    done      BOOLEAN := false;
BEGIN
    WHILE NOT done AND attempts < max_tries LOOP
        BEGIN
            BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            -- Your transaction logic here
            UPDATE account_balances
            SET bonus = CASE WHEN total_spend > 1000 THEN 100 ELSE 0 END
            WHERE user_id = 42;

            COMMIT;
            done := true;

        EXCEPTION WHEN sqlstate '40001' THEN
            ROLLBACK;
            attempts := attempts + 1;
            IF attempts < max_tries THEN
                PERFORM pg_sleep(0.1 * (2 ^ (attempts - 1)));  -- exponential backoff
            END IF;
        END;
    END LOOP;

    IF NOT done THEN
        RAISE EXCEPTION 'Transaction failed after % attempts', max_tries;
    END IF;
END $$;
```

**FOR UPDATE: row-level lock as an alternative to higher isolation**
```sql
-- When you can't raise the isolation level globally,
-- use FOR UPDATE to lock specific rows for the duration of the transaction

BEGIN;

-- Lock these rows: no other transaction can UPDATE them until we COMMIT
SELECT balance
FROM accounts
WHERE user_id = 42
FOR UPDATE;

-- Safe: the values we read cannot change before our UPDATE
UPDATE accounts
SET balance = balance - 200
WHERE user_id = 42;

COMMIT;
-- FOR UPDATE prevents non-repeatable reads and write skew on the locked rows
-- but doesn't prevent phantom reads from new rows being inserted
```

**Check and set isolation level**
```sql
SHOW transaction_isolation;          -- current transaction's level
SHOW default_transaction_isolation;  -- session default

-- Set for a single transaction
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Set session default (all subsequent transactions use this level)
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL SERIALIZABLE;
```

---

## Real World Example

A seat reservation system must prevent two users from booking the same last seat simultaneously. This is a write skew scenario — both read "1 seat available," both decide to book, both insert a reservation. Read Committed can't prevent this. Repeatable Read can't prevent it (inserts of new rows are phantoms). SERIALIZABLE prevents it — but requires retry logic.

```sql
-- With SERIALIZABLE isolation:
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT COUNT(*) AS available
FROM seats
WHERE event_id = :event_id
  AND status = 'available';

-- Application checks: if available > 0, proceed
INSERT INTO reservations (user_id, event_id, seat_id, reserved_at)
SELECT :user_id, :event_id, id, NOW()
FROM seats
WHERE event_id = :event_id AND status = 'available'
LIMIT 1;

UPDATE seats
SET status = 'reserved'
WHERE id = (SELECT seat_id FROM reservations WHERE user_id = :user_id AND event_id = :event_id ORDER BY reserved_at DESC LIMIT 1);

COMMIT;
-- If concurrent transaction reserved the same seat: ERROR 40001 → retry
-- On retry: SELECT finds 0 available → application returns "sold out" to user

-- Alternative: skip SERIALIZABLE and use SELECT FOR UPDATE instead
BEGIN;
SELECT id
FROM seats
WHERE event_id = :event_id AND status = 'available'
LIMIT 1
FOR UPDATE SKIP LOCKED;  -- grab exactly one available seat, skip locked ones
-- ... insert reservation, update seat status ...
COMMIT;
-- FOR UPDATE SKIP LOCKED: each concurrent transaction grabs a different seat
-- No serialization failures, no retries — but doesn't work for a single last seat
```

*The key insight: FOR UPDATE SKIP LOCKED is more efficient than SERIALIZABLE for the "grab any available seat" pattern. SERIALIZABLE is needed when the constraint is "the total count across all seats must not go below zero" — a condition that can't be enforced by locking a single row.*

---

## Common Misconceptions

**"Read Uncommitted lets me read uncommitted data in PostgreSQL"**
PostgreSQL doesn't implement Read Uncommitted — its MVCC model makes dirty reads impossible by design. If you set `ISOLATION LEVEL READ UNCOMMITTED`, PostgreSQL silently gives you Read Committed behaviour. Don't rely on Read Uncommitted in PostgreSQL.

**"REPEATABLE READ prevents all consistency problems"**
Repeatable Read prevents non-repeatable reads and phantoms (in PostgreSQL). It does NOT prevent write skew. Two transactions can both read the same data, make independent decisions, and both commit in a way that violates a business rule — each transaction individually looks consistent, but the combined effect is not.

**"Higher isolation = slower reads"**
In PostgreSQL, higher isolation does not slow reads — MVCC means reads always take a snapshot without blocking. The performance cost is serialization failures (error 40001 at SERIALIZABLE level), which require application retries. Retry overhead under high contention can be significant, but a single read is no slower at SERIALIZABLE than at Read Committed.

---

## Gotchas

- **Serializable failures require application retry — not database retry** — PostgreSQL aborts the transaction with error 40001. The application must detect this error, roll back, and resubmit the entire transaction. Code that doesn't handle this silently drops writes with no error surfaced to the user.

- **REPEATABLE READ in PostgreSQL prevents phantom reads — MySQL InnoDB does not** — PostgreSQL's MVCC snapshot prevents phantom reads at REPEATABLE READ level. MySQL InnoDB allows phantom reads at REPEATABLE READ. This is a portability difference that affects correctness.

- **FOR UPDATE prevents write skew on specific rows but not new rows** — `SELECT ... FOR UPDATE` locks the rows you read, preventing another transaction from updating them. But it doesn't prevent another transaction from INSERT-ing a new row that would have changed your decision. FOR UPDATE prevents update-based write skew; SERIALIZABLE prevents all write skew including insert-based.

- **SET SESSION CHARACTERISTICS applies to future transactions, not the current one** — to change the isolation level for the current transaction, use `BEGIN TRANSACTION ISOLATION LEVEL x`. The session-level setting only affects transactions started after the SET.

- **Long serializable transactions increase abort rates** — the longer a SERIALIZABLE transaction runs, the more likely it is to conflict with concurrent work and be aborted. Keep serializable transactions short and focused.

---

## Interview Angle

**What they're really testing:** Whether you understand the specific anomalies each level prevents — not just the names — and whether you can reason about which level a real scenario requires.

**Common question forms:**
- "What's the difference between REPEATABLE READ and SERIALIZABLE?"
- "You're building a booking system — two users try to reserve the last seat. How do you handle it?"
- "What is write skew, and how do you prevent it?"

**The depth signal:** A junior lists the four isolation levels and associates them with dirty/non-repeatable/phantom reads from memory. A senior can describe write skew by concrete example, explain why it's the anomaly only SERIALIZABLE prevents, and knows that preventing write skew with lower isolation requires `SELECT FOR UPDATE` with careful lock ordering or application-level serialization. They know PostgreSQL doesn't actually implement Read Uncommitted, understand that SERIALIZABLE's cost is retry overhead (not read latency), can sketch the retry pattern for serialization failures, and know that REPEATABLE READ prevents phantoms in PostgreSQL but not MySQL InnoDB.

**Follow-up questions to expect:**
- "What is SSI (Serializable Snapshot Isolation) and how does PostgreSQL implement it?"
- "How is write skew different from a lost update?"

---

## Related Topics

- [[databases/sql/sql-transactions.md]] — isolation levels are set per-transaction; understanding BEGIN/COMMIT is prerequisite
- [[databases/sql/sql-locking-blocking.md]] — FOR UPDATE is the row-lock alternative to raising isolation level
- [[databases/sql/sql-upsert-merge.md]] — upserts under concurrent load often need isolation level awareness

---

## Source

https://www.postgresql.org/docs/current/transaction-iso.html

---
*Last updated: 2026-04-13*