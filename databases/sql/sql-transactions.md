# SQL Transactions

> A transaction is a group of SQL statements that execute as a single atomic unit — either all succeed and are committed, or all fail and are rolled back.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Atomic, isolated unit of database work with ACID guarantees |
| **Use when** | Two or more writes must succeed or fail together |
| **Avoid when** | Single-statement writes (already implicitly wrapped); long-running operations |
| **Standard** | SQL-92 (BEGIN/COMMIT/ROLLBACK); SQL:1999 (SAVEPOINT) |
| **Key syntax** | `BEGIN`, `COMMIT`, `ROLLBACK`, `SAVEPOINT`, `RELEASE SAVEPOINT`, `ROLLBACK TO SAVEPOINT` |
| **PostgreSQL isolation default** | Read Committed |

---

## When To Use It

Use transactions any time two or more writes must succeed or fail together — transferring funds between accounts, creating an order and decrementing inventory, inserting a user and their default settings. A single-statement write is implicitly wrapped in a transaction already. Explicit transactions matter when you need to group multiple statements, hold locks across steps, or roll back on a business rule violation mid-way. Avoid long-running transactions — they hold locks, block other writers, prevent autovacuum from cleaning dead rows, and inflate the database's dead row count. The goal is to make transactions as short as possible while keeping all related writes atomic.

---

## Core Concept

A transaction gives you ACID guarantees. Atomicity: all statements commit or none do. Consistency: the database moves from one valid state to another. Isolation: concurrent transactions don't see each other's uncommitted changes (to a degree defined by the isolation level). Durability: once committed, the data survives a crash.

In practice you actively reason about two: Atomicity (controlled by BEGIN/COMMIT/ROLLBACK) and Isolation (controlled by isolation levels). PostgreSQL implements isolation through MVCC — each transaction sees a snapshot of the database at a specific point in time. Readers never block writers and writers never block readers. The cost of this model is that old row versions must be kept alive as long as any transaction might need them — which is why long transactions cause table bloat.

---

## Version History

| Standard / Version | What changed |
|---|---|
| SQL-92 | BEGIN, COMMIT, ROLLBACK standardized |
| SQL:1999 | SAVEPOINT and ROLLBACK TO SAVEPOINT standardized |
| PostgreSQL 11 | Explicit COMMIT/ROLLBACK inside stored procedures |
| PostgreSQL 14 | Improved WAL (Write-Ahead Log) performance under heavy write workloads |

---

## Performance

| Scenario | Impact | Notes |
|---|---|---|
| Short transactions (ms) | Minimal | Rows locked only briefly; autovacuum unblocked |
| Long transactions (seconds) | Significant | Holds locks; blocks autovacuum; accumulates dead rows |
| Very long transactions (minutes+) | Severe | Transaction ID wraparound risk on busy tables; emergency VACUUM may be needed |
| High concurrency, short txns | Near-linear scaling | MVCC allows concurrent readers/writers without blocking |
| Nested savepoints | Overhead per savepoint | Each SAVEPOINT adds overhead; avoid in tight loops |

**Allocation behaviour:** PostgreSQL's MVCC keeps old row versions (dead rows) for any transaction that might still need them. A transaction open for 1 hour prevents autovacuum from cleaning rows modified in that hour — on a busy table, this causes significant bloat. `idle_in_transaction_session_timeout` kills idle-in-transaction connections automatically; set it in production.

---

## The Code

**Basic transaction**
```sql
BEGIN;

UPDATE accounts SET balance = balance - 500 WHERE id = 101;
UPDATE accounts SET balance = balance + 500 WHERE id = 202;

COMMIT;   -- both updates land together

-- On error, roll back both
ROLLBACK; -- neither update lands
```

**SAVEPOINT — partial rollback within a transaction**
```sql
BEGIN;

INSERT INTO orders (user_id, total_amount) VALUES (42, 150.00);
SAVEPOINT after_order;

INSERT INTO order_items (order_id, product_id, quantity)
VALUES (currval('orders_id_seq'), 99, 1);

-- If the item insert fails:
ROLLBACK TO SAVEPOINT after_order;   -- undo just the item insert
                                      -- the order insert is still live

RELEASE SAVEPOINT after_order;       -- optional: free savepoint resources
COMMIT;
```

**Isolation level per transaction**
```sql
-- Read Committed (default): each statement sees a fresh snapshot
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- ...
COMMIT;

-- Repeatable Read: snapshot fixed at transaction start
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- ...
COMMIT;

-- Serializable: strongest; may produce serialization failures (must retry)
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- ...
COMMIT;
```

**Locking a row explicitly within a transaction**
```sql
BEGIN;

-- Lock the row for update — no concurrent modification until we commit
SELECT balance FROM accounts WHERE id = 101 FOR UPDATE;

-- Now safe: no other transaction can modify this row before we commit
UPDATE accounts SET balance = balance - 200 WHERE id = 101;

COMMIT;
```

**Transaction with error handling in PL/pgSQL**
```sql
CREATE OR REPLACE PROCEDURE transfer_funds(
    sender_id   INT,
    receiver_id INT,
    amount      NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE accounts SET balance = balance - amount WHERE id = sender_id;

    IF (SELECT balance FROM accounts WHERE id = sender_id) < 0 THEN
        RAISE EXCEPTION 'Insufficient funds for account %', sender_id;
    END IF;

    UPDATE accounts SET balance = balance + amount WHERE id = receiver_id;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;   -- re-raise the original error to the caller
END;
$$;
```

**Detecting and handling serialization failures (application pattern)**
```sql
-- At SERIALIZABLE isolation, PostgreSQL may abort a transaction with code 40001
-- The application MUST detect this and retry — PostgreSQL will not retry automatically

-- Pattern: retry loop with backoff
DO $$
DECLARE
    max_retries  INT := 3;
    attempt      INT := 0;
    succeeded    BOOLEAN := false;
BEGIN
    WHILE attempt < max_retries AND NOT succeeded LOOP
        BEGIN
            -- Your serializable transaction here
            BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
            -- ... statements ...
            COMMIT;
            succeeded := true;

        EXCEPTION WHEN sqlstate '40001' THEN
            -- Serialization failure — rollback and retry
            ROLLBACK;
            attempt := attempt + 1;
            PERFORM pg_sleep(0.05 * attempt);  -- backoff
        END;
    END LOOP;

    IF NOT succeeded THEN
        RAISE EXCEPTION 'Transaction failed after % retries', max_retries;
    END IF;
END;
$$;
```

**Setting transaction-level timeouts**
```sql
-- Kill this transaction if it waits too long for a lock
BEGIN;
SET LOCAL lock_timeout = '2s';       -- fail fast if a lock is blocked for 2s
SET LOCAL statement_timeout = '10s'; -- kill any statement running over 10s
-- ... statements ...
COMMIT;

-- Session-level (applies to all transactions in this session)
SET lock_timeout = '2s';
SET idle_in_transaction_session_timeout = '60s';  -- kill idle-in-transaction after 60s
```

**Two-phase commit (distributed transactions)**
```sql
-- Used when a transaction spans multiple database instances
-- Phase 1: prepare (durably writes intent to commit)
BEGIN;
-- ... statements ...
PREPARE TRANSACTION 'txn_order_12345';   -- named global transaction ID

-- Phase 2: commit or rollback from any connection
COMMIT PREPARED 'txn_order_12345';
-- or
ROLLBACK PREPARED 'txn_order_12345';

-- Find orphaned prepared transactions (shouldn't linger)
SELECT gid, prepared, owner FROM pg_prepared_xacts;
```

---

## Real World Example

An e-commerce checkout service must atomically: reserve inventory, create the order record, create order items, and charge the payment — rolling back everything cleanly if the payment fails, with a savepoint so a partial retry can re-attempt payment without re-creating the order.

```sql
BEGIN;

-- Reserve inventory (with row locks to prevent overselling)
UPDATE inventory
SET reserved = reserved + 1,
    available = available - 1
WHERE product_id = ANY(:product_ids)
  AND available >= 1;   -- guard: fails silently if not enough stock

-- Verify all products were reserved
DO $$
BEGIN
    IF (
        SELECT COUNT(*) FROM inventory
        WHERE product_id = ANY(:product_ids)
          AND available < 0    -- negative means we over-reserved
    ) > 0 THEN
        RAISE EXCEPTION 'Insufficient stock for one or more products';
    END IF;
END $$;

-- Create order (this succeeds or the whole thing rolls back)
INSERT INTO orders (user_id, status, total_amount, created_at)
VALUES (:user_id, 'pending', :total, NOW())
RETURNING id INTO :order_id;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT :order_id, product_id, :quantities[i], unit_price
FROM products WHERE product_id = ANY(:product_ids);

-- Savepoint: if payment fails, roll back to here and retry payment
-- without re-creating the order
SAVEPOINT before_payment;

-- Attempt payment (result comes back from application layer)
UPDATE orders SET status = 'paid', paid_at = NOW()
WHERE id = :order_id;

-- If we reach here, commit everything
COMMIT;

-- On payment failure in the application layer:
-- ROLLBACK TO SAVEPOINT before_payment;
-- (retry payment, or release inventory and ROLLBACK fully)
```

*The key insight: the SAVEPOINT creates a recovery point specifically for the payment step — the most failure-prone part. If payment fails, the order record, items, and inventory reservation are preserved and can be retried without re-running the entire transaction. Inventory reservation uses `FOR UPDATE` implicitly via the `UPDATE` lock and checks for negative availability in a single pass — avoiding a separate SELECT + UPDATE that would be a race condition.*

---

## Common Misconceptions

**"Transactions are only needed for financial operations"**
Transactions are needed any time two or more writes must be consistent — which includes: creating a user + their default settings, publishing a blog post + its tags, updating a configuration + logging the change. Any multi-table write without a transaction is a potential data consistency bug.

**"ROLLBACK only works on DML — DDL is auto-committed"**
In MySQL and SQL Server, DDL (CREATE TABLE, ALTER TABLE, DROP) implicitly commits any open transaction — you can't roll back DDL. PostgreSQL is the exception: it supports transactional DDL fully. You can CREATE TABLE inside a BEGIN and roll it back. This is extremely useful for migrations — run the migration in a transaction, test it, then commit or roll back.

```sql
-- PostgreSQL only: transactional DDL
BEGIN;
ALTER TABLE orders ADD COLUMN promo_code TEXT;
-- ... verify things look right ...
ROLLBACK;  -- column is gone — no schema change committed
```

**"A transaction is a lock on the whole table"**
PostgreSQL's MVCC means a transaction doesn't lock the whole table unless you explicitly request it (`LOCK TABLE`). Row-level locking via `SELECT FOR UPDATE` locks only the rows you touch. Other transactions can read and modify different rows in the same table concurrently — which is how PostgreSQL achieves high concurrency.

---

## Gotchas

- **Long transactions block autovacuum** — PostgreSQL can't vacuum dead rows while a transaction that predates them is still open. A transaction open for hours on a busy table causes dead row accumulation, table bloat, and eventually index and query slowdown. Set `idle_in_transaction_session_timeout` to automatically kill stuck idle-in-transaction connections.

- **Read Committed doesn't prevent non-repeatable reads** — the same SELECT within the same transaction can return different values if another transaction commits between the two reads. If your logic depends on a value staying stable across multiple reads in one transaction, use `REPEATABLE READ` or lock the row with `FOR UPDATE`.

- **Serializable transactions require application retry logic** — PostgreSQL aborts conflicting serializable transactions with error code 40001. Application code that doesn't handle and retry this silently drops writes. This is a code architecture requirement, not optional.

- **ROLLBACK in error handling must happen before re-raising** — if an exception handler doesn't ROLLBACK before re-raising, the outer caller receives the error but the transaction is still open and dirty. Always ROLLBACK before re-raising in catch blocks.

- **Two-phase commit orphans must be monitored** — if a coordinator crashes between PREPARE TRANSACTION and COMMIT PREPARED, the prepared transaction sits in `pg_prepared_xacts` holding locks indefinitely. Monitor this table in production and have a recovery procedure.

---

## Interview Angle

**What they're really testing:** Whether you understand ACID at a practical level — specifically Atomicity and Isolation — and can reason about the tradeoffs between isolation levels, concurrency, and consistency.

**Common question forms:**
- "What is ACID? Explain each property in practical terms."
- "How would you implement a fund transfer safely?"
- "What's the difference between Read Committed and Serializable isolation?"

**The depth signal:** A junior recites the ACID acronym and describes BEGIN/COMMIT. A senior explains which isolation anomalies each level prevents, knows that Read Committed doesn't prevent non-repeatable reads, reaches for `FOR UPDATE` when they need to hold a lock across a read-then-write, knows that long transactions block autovacuum and cause bloat, and understands that SERIALIZABLE requires application-level retry logic. Mentioning MVCC as the mechanism behind PostgreSQL's non-blocking reads, and knowing that PostgreSQL supports transactional DDL unlike MySQL and SQL Server, are strong senior signals.

**Follow-up questions to expect:**
- "What happens if a SERIALIZABLE transaction fails — does PostgreSQL retry it?"
- "How would you safely run a schema migration on a live production table?"

---

## Related Topics

- [[databases/sql/sql-isolation-levels.md]] — deep dive into the four isolation levels and their anomalies
- [[databases/sql/sql-locking-blocking.md]] — locks are held for the transaction duration; short transactions reduce blocking
- [[databases/sql/sql-stored-procedures.md]] — procedures own transaction boundaries with explicit COMMIT/ROLLBACK

---

## Source

https://www.postgresql.org/docs/current/tutorial-transactions.html

---
*Last updated: 2026-04-13*