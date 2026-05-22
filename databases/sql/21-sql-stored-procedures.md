# SQL Stored Procedures

> A stored procedure is a named block of SQL (and optional procedural logic) saved in the database and executed by name — encapsulating multi-step database logic that must run atomically.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Named, reusable block of logic stored in the database |
| **Use when** | Multi-step atomic operations; enforcing logic close to data; reducing round trips |
| **Avoid when** | Team lives in application code — procedures scatter logic across two layers |
| **Standard** | SQL:1999 (PSM — Persistent Stored Modules); each DB has its own dialect |
| **Key syntax** | `CREATE OR REPLACE PROCEDURE`, `CALL`, `COMMIT`, `ROLLBACK` inside procedure |
| **vs Function** | Procedures can COMMIT/ROLLBACK; functions return a value and can't |

---

## When To Use It

Use stored procedures when you need to encapsulate multi-step database logic that must run atomically, enforce business rules close to the data, or reduce round trips between application and database. They're common in financial systems, legacy enterprise codebases, and anywhere the DBA owns business logic. Avoid them when your team lives in application code and treats the database as a dumb store — stored procedures scatter logic across two places, make version control harder, complicate testing, and require the DBA to be in every deployment pipeline. Modern application stacks increasingly push this logic into the service layer.

---

## Core Concept

A stored procedure is code that lives inside the database server. You define it once with CREATE PROCEDURE, then call it by name with CALL. It can accept input parameters, run multiple SQL statements in sequence, use conditional logic, loop, handle errors, and manage transactions explicitly with COMMIT and ROLLBACK. Unlike a function, a procedure doesn't have to return a value — it performs actions.

The key distinction from functions: procedures can issue explicit COMMIT and ROLLBACK (in PostgreSQL 11+), which means they can control transaction boundaries from within. A function runs inside the caller's transaction and cannot commit or roll back independently.

---

## Version History

| Standard / Version | What changed |
|---|---|
| SQL:1999 | PSM (Persistent Stored Modules) standardized procedures |
| PostgreSQL pre-11 | No native CREATE PROCEDURE — only functions |
| PostgreSQL 11 | `CREATE PROCEDURE` added; explicit COMMIT/ROLLBACK inside procedures |
| PostgreSQL 14 | Improved procedure error handling and OUT parameter support |

*Before PostgreSQL 11, procedures were simulated using functions with LANGUAGE plpgsql. Since 11, `CREATE PROCEDURE` is the correct form when transaction control is needed.*

---

## Performance

| Scenario | Benefit | Notes |
|---|---|---|
| Repeated multi-statement logic | Reduced round trips | One CALL instead of N statements |
| Plan caching | Execution plan cached | Repeated calls reuse cached plan |
| Row-by-row loops in procedures | Performance trap | Always slower than set-based SQL; avoid loops |
| Large stored procedure bodies | Maintenance cost | Debugging is harder than application code |

**The RBAR trap:** "Row By Agonizing Row" — processing rows in a loop inside a procedure is the most common performance mistake made by developers coming from application code. A cursor loop processing 100,000 rows executes 100,000 individual SQL statements. A set-based UPDATE or INSERT...SELECT processes them in one operation. Always ask: can this loop be replaced with a set-based statement?

---

## The Code

**Basic stored procedure (PostgreSQL PL/pgSQL)**
```sql
CREATE OR REPLACE PROCEDURE deactivate_inactive_users(cutoff_days INT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE users
    SET is_active = false
    WHERE last_login_at < NOW() - (cutoff_days || ' days')::INTERVAL
      AND is_active = true;

    RAISE NOTICE 'Deactivated users inactive for more than % days', cutoff_days;
END;
$$;

CALL deactivate_inactive_users(90);
```

**Procedure with transaction control (PostgreSQL 11+)**
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

    COMMIT;  -- explicit commit inside procedure

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;   -- re-raise original error to caller
END;
$$;

CALL transfer_funds(101, 202, 500.00);
```

**Procedure with OUT parameter**
```sql
CREATE OR REPLACE PROCEDURE get_user_order_count(
    p_user_id   INT,
    OUT p_count INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT COUNT(*) INTO p_count
    FROM orders
    WHERE user_id = p_user_id AND status = 'completed';
END;
$$;

CALL get_user_order_count(42, NULL);
```

**Procedure with conditional logic and loop (use sparingly)**
```sql
-- ACCEPTABLE use of a loop: iterating over a cursor for batch processing
-- where the work per row is genuinely non-trivial
CREATE OR REPLACE PROCEDURE apply_tier_discounts()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT user_id, SUM(total_amount) AS total_spend
        FROM orders WHERE status = 'completed'
        GROUP BY user_id
    LOOP
        UPDATE users
        SET discount_tier = CASE
            WHEN rec.total_spend >= 10000 THEN 'gold'
            WHEN rec.total_spend >= 5000  THEN 'silver'
            ELSE 'bronze'
        END
        WHERE id = rec.user_id;
    END LOOP;

    COMMIT;
END;
$$;

-- BETTER: replace the loop with a single set-based UPDATE
UPDATE users u
SET discount_tier = CASE
    WHEN spend.total >= 10000 THEN 'gold'
    WHEN spend.total >= 5000  THEN 'silver'
    ELSE 'bronze'
END
FROM (
    SELECT user_id, SUM(total_amount) AS total
    FROM orders WHERE status = 'completed'
    GROUP BY user_id
) spend
WHERE u.id = spend.user_id;
```

**Version-controlling procedures — treat as migration files**
```sql
-- Store procedure definitions in version-controlled SQL files, e.g.:
-- migrations/V42__update_transfer_funds_procedure.sql

CREATE OR REPLACE PROCEDURE transfer_funds(...)
LANGUAGE plpgsql AS $$
...
$$;

-- Use a migration tool (Flyway, Liquibase, sqitch) to deploy
-- Repeatable migration syntax in Flyway: R__transfer_funds.sql
-- (runs whenever the file content changes)
```

**Drop a procedure**
```sql
DROP PROCEDURE IF EXISTS deactivate_inactive_users(INT);
-- Must include parameter types if overloaded versions exist
```

---

## Real World Example

A fintech platform processes end-of-day settlement: it calculates fees for each merchant, creates fee transactions, adjusts merchant balances, and logs the settlement run — all atomically. If any step fails, everything rolls back. This is the canonical case for a stored procedure: multiple tables, must be atomic, called nightly by a scheduler.

```sql
CREATE OR REPLACE PROCEDURE run_daily_settlement(settlement_date DATE)
LANGUAGE plpgsql
AS $$
DECLARE
    v_settlement_id     BIGINT;
    v_merchant_count    INT := 0;
    v_total_fees        NUMERIC := 0;
BEGIN
    -- Create settlement record
    INSERT INTO settlement_runs (run_date, status, started_at)
    VALUES (settlement_date, 'processing', NOW())
    RETURNING id INTO v_settlement_id;

    -- Calculate and apply fees in one set-based operation (not a loop)
    WITH merchant_fees AS (
        SELECT
            t.merchant_id,
            SUM(t.amount * m.fee_rate)  AS fee_amount
        FROM transactions t
        JOIN merchants m ON m.id = t.merchant_id
        WHERE t.transaction_date = settlement_date
          AND t.status = 'completed'
          AND t.settled = false
        GROUP BY t.merchant_id
    ),
    fee_records AS (
        INSERT INTO fee_transactions (merchant_id, settlement_id, amount, created_at)
        SELECT merchant_id, v_settlement_id, fee_amount, NOW()
        FROM merchant_fees
        RETURNING merchant_id, amount
    )
    UPDATE merchant_accounts ma
    SET balance = balance - fr.amount
    FROM fee_records fr
    WHERE ma.merchant_id = fr.merchant_id;

    GET DIAGNOSTICS v_merchant_count = ROW_COUNT;

    SELECT SUM(amount) INTO v_total_fees FROM fee_transactions
    WHERE settlement_id = v_settlement_id;

    -- Mark transactions as settled
    UPDATE transactions
    SET settled = true, settlement_id = v_settlement_id
    WHERE transaction_date = settlement_date AND status = 'completed' AND settled = false;

    -- Complete the settlement run
    UPDATE settlement_runs
    SET status        = 'completed',
        merchant_count = v_merchant_count,
        total_fees     = v_total_fees,
        completed_at   = NOW()
    WHERE id = v_settlement_id;

    COMMIT;

    RAISE NOTICE 'Settlement % complete: % merchants, % total fees',
        v_settlement_id, v_merchant_count, v_total_fees;

EXCEPTION
    WHEN OTHERS THEN
        -- Mark settlement as failed and roll back financial changes
        UPDATE settlement_runs
        SET status = 'failed', error_message = SQLERRM, completed_at = NOW()
        WHERE id = v_settlement_id;

        ROLLBACK;
        RAISE;
END;
$$;
```

*The key insight: the fee calculation and balance update are done set-based (CTEs + UPDATE...FROM) rather than in a cursor loop — the entire settlement processes in two SQL statements regardless of merchant count. The explicit COMMIT and ROLLBACK in the EXCEPTION handler ensure atomicity even if the procedure is called multiple times (idempotent retry is handled at the settlement_runs status level).*

---

## Common Misconceptions

**"Stored procedures are faster than application-layer code"**
Procedures save round-trip latency (one CALL vs N statements). They do NOT automatically produce faster SQL. A poorly-written procedure with a row-by-row cursor loop is significantly slower than a well-written set-based UPDATE in application code. The performance win is in reducing network round trips and allowing the database to batch the work — not in any magic optimisation of the SQL inside.

**"Stored procedures and functions are the same thing"**
The key differences: procedures can issue explicit COMMIT and ROLLBACK (transaction control); functions cannot. Functions return a value and can be used inside SELECT expressions; procedures cannot. Functions have IMMUTABLE/STABLE/VOLATILE volatility classifications that affect planner optimisation; procedures do not.

**"The database compiles and caches procedure plans permanently"**
PostgreSQL caches the execution plan for a procedure on the first call per session and reuses it for subsequent calls within the same session. Plans are NOT permanently compiled across sessions. If data distribution changes significantly, the cached plan may become suboptimal. `CALL` with literal values can also cause plan generalisation issues similar to bind parameters in prepared statements.

---

## Gotchas

- **Stored procedures live outside your normal deployment pipeline** — application code gets deployed via CI/CD; procedures often don't. Treat procedure definitions as migration files and version-control them explicitly. A schema migration that includes a procedure change is easy to forget, leaving production running an older version.

- **Error handling differences across databases are significant** — PostgreSQL uses `RAISE EXCEPTION` and `EXCEPTION WHEN OTHERS THEN`. MySQL uses `DECLARE ... HANDLER`. SQL Server uses `TRY...CATCH`. Procedures are not portable — rewriting for a different database is a full rewrite.

- **Loops inside procedures are the most common performance trap** — a cursor loop that processes 100,000 rows runs 100,000 individual statements. The set-based equivalent runs one statement. Always try to replace loops with set-based SQL.

- **Debugging is painful compared to application code** — there's no breakpoint, no stack trace in your IDE, and logging requires explicit `RAISE NOTICE` or equivalent. A bug inside a deeply nested procedure call is significantly harder to trace than application-layer code.

- **Implicit vs explicit transaction control varies by database and version** — in PostgreSQL, a procedure can issue COMMIT and ROLLBACK explicitly (since version 11). In older versions and some other databases, transaction control inside procedures behaves differently or is unavailable. Know your version.

---

## Interview Angle

**What they're really testing:** Whether you understand the tradeoffs of putting logic inside the database versus the application layer — not just whether you can write the syntax.

**Common question forms:**
- "What's the difference between a stored procedure and a function?"
- "When would you use a stored procedure over application-layer code?"
- "What's the RBAR pattern and why is it a performance trap?"

**The depth signal:** A junior describes stored procedures as "reusable SQL blocks" and lists syntax differences from functions. A senior discusses the real tradeoffs: logic fragmentation across app and DB layers, version control and deployment complexity, the RBAR performance trap with cursor loops versus set-based operations, and the fact that explicit transaction control (COMMIT/ROLLBACK) inside procedures was only added to PostgreSQL in version 11. They also know the distinction between a procedure (actions, transaction control, no required return value) and a function (returns a value, runs inside caller's transaction, usable in SELECT).

**Follow-up questions to expect:**
- "How would you handle a procedure that needs to partially succeed — commit some work and roll back the rest?"
- "How do you version-control stored procedures in a CI/CD pipeline?"

---

## Related Topics

- [[databases/sql/sql-transactions.md]] — procedures often own transaction boundaries; understanding ACID is prerequisite
- [[databases/sql/sql-functions.md]] — functions vs procedures: return values, transaction control, when to use each
- [[databases/sql/sql-triggers.md]] — triggers call functions automatically; often used alongside procedures

---

## Source

https://www.postgresql.org/docs/current/sql-createprocedure.html

---
*Last updated: 2026-04-13*