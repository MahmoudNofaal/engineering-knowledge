# SQL Isolation Levels

> Isolation levels control how much a transaction can see from other concurrent transactions that haven't committed yet.

---

## When To Use It
Isolation levels matter any time multiple transactions run concurrently against the same data — which is always in production. The default level (Read Committed in PostgreSQL and MySQL) is safe for most OLTP workloads but leaves specific anomalies open that can cause subtle correctness bugs. Reach for a higher isolation level when your transaction reads a value and later makes a decision based on it — especially in financial, inventory, or booking systems where a stale read causes a real-world problem. Drop to a lower level only when you understand exactly what anomalies you're accepting and why.

---

## Core Concept
Every database has to answer the same question: when transaction A is in the middle of writing, what does transaction B see? The SQL standard defines four isolation levels as a ladder — each one preventing more anomalies than the one below it, at the cost of more contention or more complexity. The three anomalies the standard cares about are dirty reads (seeing another transaction's uncommitted data), non-repeatable reads (the same row returns different values within one transaction), and phantom reads (a repeated range query returns different rows). PostgreSQL implements isolation through MVCC — each transaction sees a snapshot of the database, so readers never block writers. The tradeoff is that at Serializable, conflicting transactions may be aborted and must be retried.

---

## The Code

**Read Uncommitted — dirty reads allowed**
```sql
-- Theoretically the weakest level
-- PostgreSQL does not actually implement this — it silently upgrades to Read Committed
-- MySQL InnoDB supports it but it's almost never appropriate
BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT balance FROM accounts WHERE id = 101;
-- Could see balance = -500 from a concurrent transaction that hasn't committed yet
COMMIT;
```

**Read Committed — default in PostgreSQL and MySQL**
```sql
-- Each statement sees a fresh snapshot of committed data
-- Dirty reads: prevented
-- Non-repeatable reads: possible
-- Phantom reads: possible
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT balance FROM accounts WHERE id = 101;  -- returns 1000

-- Concurrent transaction commits: UPDATE accounts SET balance = 500 WHERE id = 101

SELECT balance FROM accounts WHERE id = 101;  -- returns 500 — different value, same transaction
COMMIT;
```

**Repeatable Read — snapshot fixed at transaction start**
```sql
-- All reads within the transaction see the same snapshot
-- Dirty reads: prevented
-- Non-repeatable reads: prevented
-- Phantom reads: prevented in PostgreSQL (MVCC), possible in MySQL InnoDB
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT balance FROM accounts WHERE id = 101;  -- returns 1000

-- Concurrent transaction commits: UPDATE accounts SET balance = 500 WHERE id = 101

SELECT balance FROM accounts WHERE id = 101;  -- still returns 1000 — snapshot is fixed
COMMIT;
```

**Serializable — strongest isolation**
```sql
-- Transactions behave as if executed one at a time, in some serial order
-- Prevents all anomalies including write skew
-- May abort transactions with a serialization failure (error 40001) — must retry

BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT SUM(balance) FROM accounts WHERE user_id = 42;  -- reads total
UPDATE accounts SET bonus = 100 WHERE user_id = 42;    -- writes based on read

-- If a concurrent transaction modified accounts for user 42 concurrently,
-- PostgreSQL may abort this transaction with:
-- ERROR: could not serialize access due to concurrent update
COMMIT;
```

**Handling serialization failure with retry (application pattern)**
```sql
-- Pseudocode pattern — implement in application layer
LOOP
    BEGIN;
    -- ... your transaction statements ...
    COMMIT;
    EXIT;  -- success, break the loop

EXCEPTION WHEN sqlstate '40001' THEN
    -- Serialization failure — wait briefly and retry
    ROLLBACK;
    PERFORM pg_sleep(0.05);
END LOOP;
```

**FOR UPDATE — explicit row lock within Read Committed**
```sql
-- When you can't raise the isolation level but need a stable read-then-write
BEGIN;

SELECT balance FROM accounts WHERE id = 101 FOR UPDATE;
-- Row is now locked — concurrent transactions block on this row until COMMIT

UPDATE accounts SET balance = balance - 200 WHERE id = 101;

COMMIT;
```

**Checking current isolation level**
```sql
SHOW transaction_isolation;           -- current transaction
SHOW default_transaction_isolation;   -- session default
```

---

## Gotchas

- **Read Committed doesn't protect read-then-write logic** — if you SELECT a value, make a decision, then UPDATE based on it, another transaction can modify that row between your SELECT and UPDATE. The second SELECT in the same transaction sees the new committed value, not the one you made your decision on. Use FOR UPDATE or raise to Repeatable Read.
- **Write skew is not prevented below Serializable** — write skew is when two transactions each read overlapping data, make decisions independently, and both write — producing a state neither would have allowed alone. Classic example: two doctors both check on-call coverage, see one doctor is available, both mark themselves as off-call. Result: no coverage. FOR UPDATE on individual rows doesn't help here. Only Serializable prevents it.
- **PostgreSQL silently upgrades Read Uncommitted to Read Committed** — PostgreSQL's MVCC model makes dirty reads impossible by design, so it doesn't bother implementing Read Uncommitted separately. If you set it explicitly, you get Read Committed behavior. Don't rely on Read Uncommitted behavior in PostgreSQL.
- **Serializable failure requires application retry — not database retry** — when PostgreSQL aborts a transaction with error 40001, it does not retry automatically. The application must catch the error, roll back, and resubmit the entire transaction. Application code that doesn't handle this silently drops writes with no error surfaced to the user.
- **Higher isolation doesn't mean slower reads — it means more aborts** — PostgreSQL's MVCC means readers don't block writers at any isolation level. The performance cost of Serializable isn't slower reads — it's the overhead of conflict detection and the cost of retrying aborted transactions under high contention.

---

## Interview Angle
**What they're really testing:** Whether you understand the specific anomalies each level prevents — not just the names — and whether you can reason about which level a real scenario requires.

**Common question form:** "What's the difference between Repeatable Read and Serializable?" or "You're building a booking system — two users try to reserve the last seat at the same time. How do you handle it?"

**The depth signal:** A junior lists the four isolation levels and associates them with dirty/non-repeatable/phantom reads from memory. A senior can describe write skew by example, explain why Serializable is the only level that prevents it, and knows that preventing write skew with lower isolation requires application-level logic like SELECT FOR UPDATE with careful lock ordering. They know PostgreSQL doesn't implement Read Uncommitted, understand that Serializable's cost is retry overhead not read latency, and can sketch the retry pattern for serialization failures. Mentioning that Repeatable Read in PostgreSQL prevents phantoms (due to MVCC snapshots) while MySQL InnoDB still allows them is a strong differentiator.

---

## Related Topics
- [[databases/sql-transactions.md]] — isolation levels are set per-transaction; understanding BEGIN/COMMIT is prerequisite
- [[databases/sql-stored-procedures.md]] — procedures that span multiple reads and writes often need explicit isolation level control
- [[databases/indexes.md]] — FOR UPDATE acquires row locks; index design affects which rows get locked and how many
- [[databases/query-optimization.md]] — long transactions at high isolation levels increase abort rates under contention; query speed directly affects transaction duration

---

## Source
https://www.postgresql.org/docs/current/transaction-iso.html

---
*Last updated: 2026-03-24*