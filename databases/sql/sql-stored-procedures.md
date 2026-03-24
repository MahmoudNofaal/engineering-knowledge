# SQL Stored Procedures

> A stored procedure is a named block of SQL (and optional procedural logic) saved in the database and executed by name — like a function you call instead of a query you write.

---

## When To Use It
Use stored procedures when you need to encapsulate multi-step database logic that must run atomically, enforce business rules close to the data, or reduce round trips between application and database. They're common in financial systems, legacy enterprise codebases, and anywhere the DBA owns business logic. Avoid them when your team lives in application code and treats the database as a dumb store — stored procedures scatter logic across two places, make version control harder, and complicate testing. Modern application stacks increasingly push this logic into the service layer instead.

---

## Core Concept
A stored procedure is code that lives inside the database server. You define it once with CREATE PROCEDURE, then call it by name with CALL. It can accept input parameters, run multiple SQL statements in sequence, use conditional logic, loop, handle errors, and manage transactions explicitly. Unlike a function, a procedure doesn't have to return a value — it performs actions. The database compiles and caches the execution plan, which can be faster than sending raw SQL repeatedly. The tradeoff is that this logic now lives outside your application's version control, test suite, and deployment pipeline unless you actively manage it.

---

## The Code

**Basic stored procedure (PostgreSQL with PL/pgSQL)**
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

-- Call it
CALL deactivate_inactive_users(90);
```

**Procedure with transaction control**
```sql
CREATE OR REPLACE PROCEDURE transfer_funds(
    sender_id   INT,
    receiver_id INT,
    amount      NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Deduct from sender
    UPDATE accounts
    SET balance = balance - amount
    WHERE id = sender_id;

    -- Raise error if sender goes negative
    IF (SELECT balance FROM accounts WHERE id = sender_id) < 0 THEN
        RAISE EXCEPTION 'Insufficient funds for account %', sender_id;
    END IF;

    -- Credit receiver
    UPDATE accounts
    SET balance = balance + amount
    WHERE id = receiver_id;

    COMMIT;  -- explicit commit inside procedure (PostgreSQL 11+)

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;  -- re-raise the original error to the caller
END;
$$;

CALL transfer_funds(101, 202, 500.00);
```

**Procedure with output parameter**
```sql
CREATE OR REPLACE PROCEDURE get_user_order_count(
    p_user_id   INT,
    OUT p_count INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT COUNT(*)
    INTO p_count
    FROM orders
    WHERE user_id = p_user_id
      AND status = 'completed';
END;
$$;

-- Call with output parameter
CALL get_user_order_count(42, NULL);
```

**Procedure with loop and conditional logic**
```sql
CREATE OR REPLACE PROCEDURE apply_tier_discounts()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT user_id, SUM(total_amount) AS total_spend
        FROM orders
        WHERE status = 'completed'
        GROUP BY user_id
    LOOP
        IF rec.total_spend >= 10000 THEN
            UPDATE users SET discount_tier = 'gold'   WHERE id = rec.user_id;
        ELSIF rec.total_spend >= 5000 THEN
            UPDATE users SET discount_tier = 'silver' WHERE id = rec.user_id;
        ELSE
            UPDATE users SET discount_tier = 'bronze' WHERE id = rec.user_id;
        END IF;
    END LOOP;

    COMMIT;
END;
$$;
```

**Drop a procedure**
```sql
DROP PROCEDURE IF EXISTS deactivate_inactive_users(INT);
-- Must include parameter types if overloaded versions exist
```

---

## Gotchas

- **Stored procedures live outside your normal deployment pipeline** — application code gets deployed via CI/CD; procedures often don't. Schema migrations that include procedure changes are easy to forget, leaving production running an older version than staging. Treat procedure definitions as migration files and version-control them explicitly.
- **Error handling differences across databases are significant** — PostgreSQL uses `RAISE EXCEPTION` and `EXCEPTION WHEN OTHERS THEN`. MySQL uses `DECLARE ... HANDLER`. SQL Server uses `TRY...CATCH`. Procedures are not portable — rewriting for a different database is a full rewrite.
- **Implicit vs explicit transaction control varies by database** — in PostgreSQL, a procedure can issue `COMMIT` and `ROLLBACK` explicitly (since version 11). In older versions and some other databases, transaction control inside procedures behaves differently or is unavailable entirely. Know your version.
- **Debugging is painful compared to application code** — there's no breakpoint, no stack trace in your IDE, and logging requires explicit `RAISE NOTICE` or equivalent. A bug inside a deeply nested procedure call is significantly harder to trace than application-layer code.
- **Performance isn't automatically better** — cached execution plans help for repeated identical calls, but a poorly written procedure with row-by-row loops (RBAR — row by agonizing row) is slower than a well-written set-based SQL query. Loops inside procedures are a common performance trap that developers coming from application code fall into.

---

## Interview Angle
**What they're really testing:** Whether you understand the tradeoffs of putting logic inside the database versus the application layer — not just whether you can write the syntax.

**Common question form:** "What's the difference between a stored procedure and a function?" or "When would you use a stored procedure over application-layer code?"

**The depth signal:** A junior describes stored procedures as "reusable SQL blocks" and lists syntax. A senior discusses the real tradeoffs: logic fragmentation across app and DB layers, version control and deployment complexity, the RBAR performance trap with loops versus set-based operations, and the fact that explicit transaction control inside procedures (COMMIT/ROLLBACK) behaves differently across databases and PostgreSQL versions. They also know the distinction between a procedure (performs actions, no required return value, can control transactions) and a function (returns a value, typically cannot COMMIT mid-execution in PostgreSQL, usable inside SELECT).

---

## Related Topics
- [[databases/transactions-and-acid.md]] — procedures often own transaction boundaries; understanding ACID is prerequisite
- [[databases/sql-functions.md]] — functions vs procedures: return values, transaction control, and when to use each
- [[databases/sql-triggers.md]] — triggers call functions automatically; often confused with procedures
- [[databases/query-optimization.md]] — loops inside procedures are a common performance trap; set-based rewrites are almost always faster

---

## Source
https://www.postgresql.org/docs/current/sql-createprocedure.html

---
*Last updated: 2026-03-24*