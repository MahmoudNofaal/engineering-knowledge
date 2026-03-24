# SQL Transactions

> A transaction is a group of SQL statements that execute as a single unit — either all succeed and are committed, or all fail and are rolled back.

---

## When To Use It
Use transactions any time two or more writes must succeed or fail together — transferring funds between accounts, creating an order and decrementing inventory, inserting a user and their default settings. A single-statement write is implicitly wrapped in a transaction already. Explicit transactions matter when you need to group multiple statements, hold locks across steps, or roll back on a business rule violation mid-way. Avoid long-running transactions — they hold locks, block other writers, and inflate the database's undo log.

---

## Core Concept
A transaction gives you four guarantees known as ACID: Atomicity (all statements commit or none do), Consistency (the database moves from one valid state to another), Isolation (concurrent transactions don't see each other's uncommitted changes), and Durability (once committed, the data survives a crash). In practice, the ones you actively reason about are Atomicity and Isolation. Atomicity is what BEGIN/COMMIT/ROLLBACK controls. Isolation is what isolation levels control — how much a transaction can see from other concurrent transactions before they commit. The default isolation level in PostgreSQL is Read Committed, which is safe for most workloads but not all.

---

## The Code

**Basic transaction — explicit BEGIN, COMMIT, ROLLBACK**
```sql
BEGIN;

UPDATE accounts SET balance = balance - 500 WHERE id = 101;
UPDATE accounts SET balance = balance + 500 WHERE id = 202;

COMMIT;   -- both updates land together

-- If something goes wrong mid-way:
ROLLBACK; -- neither update lands
```

**SAVEPOINT — partial rollback within a transaction**
```sql
BEGIN;

INSERT INTO orders (user_id, total_amount) VALUES (42, 150.00);

SAVEPOINT after_order;  -- checkpoint inside the transaction

INSERT INTO order_items (order_id, product_id, quantity)
VALUES (currval('orders_id_seq'), 99, 1);

-- If the item insert fails or violates a rule:
ROLLBACK TO SAVEPOINT after_order;  -- undo just the item insert
                                     -- the order insert is still live

-- Continue with corrected data or just commit what we have
COMMIT;
```

**Transaction with error handling (PL/pgSQL)**
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
        RAISE EXCEPTION 'Insufficient funds';
    END IF;

    UPDATE accounts SET balance = balance + amount WHERE id = receiver_id;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;
```

**Isolation levels**
```sql
-- Read Committed (default) — sees only committed rows at each statement
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT balance FROM accounts WHERE id = 101;
COMMIT;

-- Repeatable Read — same rows return same values for entire transaction
-- Prevents non-repeatable reads; still allows phantom reads in some DBs
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE id = 101;
-- ... other statements ...
COMMIT;

-- Serializable — strongest; transactions behave as if run one at a time
-- Prevents phantom reads; may cause serialization failures requiring retry
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT SUM(balance) FROM accounts WHERE user_id = 42;
UPDATE accounts SET balance = balance + 100 WHERE user_id = 42;
COMMIT;
```

**Locking rows explicitly**
```sql
BEGIN;

-- Lock the row for update — other transactions block until this commits
SELECT balance FROM accounts WHERE id = 101 FOR UPDATE;

-- Now safe to update without a concurrent transaction modifying it first
UPDATE accounts SET balance = balance - 200 WHERE id = 101;

COMMIT;
```

**Transaction in application code pattern (conceptual SQL)**
```sql
-- Pattern: always check and handle failure at the application layer
BEGIN;

UPDATE inventory SET stock = stock - 1 WHERE product_id = 7 AND stock > 0;

-- If 0 rows affected, stock was already zero — rollback and surface error
-- Application checks affected row count before proceeding
INSERT INTO order_items (order_id, product_id, quantity) VALUES (55, 7, 1);

COMMIT;
```

---

## Gotchas

- **Read Committed doesn't prevent all anomalies** — at the default isolation level, a transaction can read different values for the same row across two SELECT statements within the same transaction if another transaction commits between them. This is a non-repeatable read. If your logic depends on a value staying stable across multiple reads, use REPEATABLE READ or lock the row with FOR UPDATE.
- **Long transactions block autovacuum and bloat tables** — PostgreSQL's MVCC model keeps old row versions alive as long as any transaction might need them. A transaction open for hours prevents vacuuming, inflates table size, and can cause query slowdowns that look unrelated. Always close transactions as quickly as possible.
- **ROLLBACK only works on DML — DDL is auto-committed in most databases** — in MySQL and SQL Server, DDL statements (CREATE TABLE, DROP INDEX, ALTER TABLE) implicitly commit any open transaction. PostgreSQL is the exception — it supports transactional DDL. Don't assume DDL inside a BEGIN block will roll back on other databases.
- **Savepoints are not free** — each SAVEPOINT adds overhead. In tight loops, creating a savepoint per iteration creates performance problems. Use them surgically for known risky steps, not as a default pattern everywhere.
- **Serializable transactions can fail with serialization errors** — at SERIALIZABLE isolation level, PostgreSQL may abort a transaction that would have caused a consistency anomaly and return error code 40001 (serialization failure). Your application must detect this and retry. Code that doesn't handle retries silently loses writes.

---

## Interview Angle
**What they're really testing:** Whether you understand ACID at a practical level — specifically Atomicity and Isolation — and can reason about the tradeoffs between isolation levels and concurrency.

**Common question form:** "What is ACID?" or "How would you implement a fund transfer safely?" or "What's the difference between Read Committed and Serializable isolation?"

**The depth signal:** A junior recites the ACID acronym and describes BEGIN/COMMIT. A senior explains which isolation anomalies each level prevents — dirty reads, non-repeatable reads, phantom reads — and knows that Read Committed is the PostgreSQL default but doesn't prevent non-repeatable reads. They reach for FOR UPDATE when they need to hold a lock across a read-then-write pattern, know that long transactions block autovacuum and inflate table bloat, and understand that SERIALIZABLE requires application-level retry logic for serialization failures. Mentioning MVCC as the mechanism behind PostgreSQL's isolation model is a strong senior signal.

---

## Related Topics
- [[databases/sql-stored-procedures.md]] — procedures often own transaction boundaries with explicit COMMIT and ROLLBACK
- [[databases/sql-triggers.md]] — triggers execute inside the triggering transaction; a failing trigger rolls back the whole operation
- [[databases/indexes.md]] — FOR UPDATE acquires row-level locks; understanding indexes helps reason about lock contention
- [[databases/query-optimization.md]] — long-running transactions cause table bloat and autovacuum issues that surface as slow queries

---

## Source
https://www.postgresql.org/docs/current/tutorial-transactions.html

---
*Last updated: 2026-03-24*