# SQL Triggers

> A trigger is a function the database calls automatically when a specific event — INSERT, UPDATE, DELETE, or TRUNCATE — occurs on a table or view.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Automatic callback bound to a table event |
| **Use when** | Audit logging; enforcing derived columns; logic that must fire on every data change |
| **Avoid when** | Business logic that belongs in the service layer; anything with side effects or network calls |
| **Standard** | SQL:1999 (trigger syntax); implementation varies significantly |
| **Key syntax** | `CREATE TRIGGER`, `CREATE OR REPLACE FUNCTION ... RETURNS TRIGGER`, `NEW`, `OLD`, `TG_OP` |
| **BEFORE vs AFTER** | BEFORE can cancel/modify the row; AFTER can react to the committed row |

---

## When To Use It

Use triggers for logic that must fire unconditionally on every data change, regardless of which application or process caused it — audit logging, enforcing derived column values, maintaining a denormalized summary table, or cascading soft deletes. They're one of the few tools that work even when data changes come from migrations, bulk imports, or direct psql sessions that bypass application code. Avoid them for business logic that belongs in the service layer, or for anything that makes a network call or has significant side effects — triggers fire synchronously inside the transaction, and a slow or failing trigger rolls back the triggering statement.

---

## Core Concept

A trigger binds a function to a table event. When that event fires, the database calls the function automatically. The trigger function receives special variables: `NEW` holds the row being inserted or updated, `OLD` holds the row before an update or delete. `TG_OP` contains the operation name ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE').

Returning `NULL` from a BEFORE row-level trigger cancels the operation entirely. Returning `NEW` (possibly modified) lets it proceed. AFTER triggers cannot cancel the operation — they react to it. Statement-level triggers (`FOR EACH STATEMENT`) fire once per SQL statement and don't have access to `NEW` or `OLD`. Row-level triggers (`FOR EACH ROW`) fire once per affected row.

---

## Version History

| PostgreSQL Version | What changed |
|---|---|
| Pre-8.0 | Basic BEFORE/AFTER, FOR EACH ROW/STATEMENT |
| 8.4 | `WHEN` clause on triggers — conditional trigger firing |
| 9.0 | `RETURNING` now works with triggers; event trigger infrastructure |
| 9.3 | Event triggers (`CREATE EVENT TRIGGER`) for DDL events |
| 10 | Transition tables (`REFERENCING NEW TABLE AS`, `OLD TABLE AS`) for statement-level triggers |
| 14 | `OR REPLACE` for triggers |

---

## Performance

| Trigger type | Per-row overhead | Notes |
|---|---|---|
| BEFORE row-level | Low | Runs before row write; can modify NEW |
| AFTER row-level | Low-medium | Runs after row write; extra round trip for deferred |
| AFTER statement-level | Fixed per statement | Transition tables available for bulk access |
| Trigger with heavy logic | Can be significant | A slow trigger adds to every write on the table |
| Trigger that queries other tables | Variable | JOIN or SELECT in trigger body; must be indexed |

**The cost model:** every DML statement that touches a table with triggers pays the trigger overhead for every matching row. On a table receiving 50,000 rows/second, even a 0.1ms trigger body adds 5 seconds of trigger overhead per second — which is unsustainable. Keep trigger functions lean.

---

## The Code

**Step 1 — Create the trigger function**
```sql
-- Trigger functions return type TRIGGER and take no parameters
-- Row data is accessed via NEW and OLD variables
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;   -- must return NEW for BEFORE triggers on rows
END;
$$;
```

**Step 2 — Bind the trigger to a table**
```sql
CREATE TRIGGER trg_users_updated_at
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
```

**Audit log trigger — record every change**
```sql
CREATE TABLE user_audit_log (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     INT,
    operation   TEXT,     -- 'INSERT', 'UPDATE', 'DELETE'
    old_data    JSONB,
    new_data    JSONB,
    changed_at  TIMESTAMPTZ DEFAULT NOW(),
    changed_by  TEXT DEFAULT current_user
);

CREATE OR REPLACE FUNCTION log_user_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO user_audit_log (user_id, operation, old_data, new_data)
    VALUES (
        COALESCE(NEW.id, OLD.id),
        TG_OP,
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
    );
    RETURN NEW;  -- ignored for AFTER triggers but required by convention
END;
$$;

CREATE TRIGGER trg_users_audit
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW
EXECUTE FUNCTION log_user_changes();
```

**BEFORE trigger — enforce a business rule or modify the row**
```sql
CREATE OR REPLACE FUNCTION prevent_negative_balance()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.balance < 0 THEN
        RAISE EXCEPTION 'Account % cannot have a negative balance', NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_accounts_balance_check
BEFORE INSERT OR UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION prevent_negative_balance();
```

**WHEN clause — conditional trigger (PostgreSQL 8.4+)**
```sql
-- Only fire when the email column actually changes — avoid unnecessary work
CREATE TRIGGER trg_users_email_change
AFTER UPDATE ON users
FOR EACH ROW
WHEN (OLD.email IS DISTINCT FROM NEW.email)   -- only when email changed
EXECUTE FUNCTION queue_email_verification();
```

**Statement-level trigger with transition tables (PostgreSQL 10+)**
```sql
-- Access the full set of changed rows at once — more efficient for bulk operations
CREATE OR REPLACE FUNCTION update_order_stats_bulk()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update stats for all affected users in one query
    -- instead of one per row
    UPDATE user_stats us
    SET order_count = order_count + cnt.new_orders
    FROM (
        SELECT user_id, COUNT(*) AS new_orders
        FROM new_table   -- transition table: the rows just inserted
        GROUP BY user_id
    ) cnt
    WHERE us.user_id = cnt.user_id;

    RETURN NULL;   -- statement-level triggers must return NULL
END;
$$;

CREATE TRIGGER trg_orders_stats_bulk
AFTER INSERT ON orders
REFERENCING NEW TABLE AS new_table
FOR EACH STATEMENT
EXECUTE FUNCTION update_order_stats_bulk();
```

**Event trigger — DDL events (PostgreSQL 9.3+)**
```sql
-- Fire on DDL events (CREATE, ALTER, DROP) — not DML
CREATE OR REPLACE FUNCTION log_ddl_changes()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO ddl_audit_log (event, schema, object_type, object_identity, executed_at, executed_by)
    SELECT
        TG_EVENT,
        schema_name,
        object_type,
        object_identity,
        NOW(),
        session_user
    FROM pg_event_trigger_ddl_commands();
END;
$$;

CREATE EVENT TRIGGER log_ddl
ON ddl_command_end   -- fires after any DDL completes
EXECUTE FUNCTION log_ddl_changes();
```

**Drop a trigger**
```sql
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
-- Must specify the table — trigger names are scoped to the table
```

---

## Real World Example

A multi-region SaaS platform needs a complete audit trail for all user profile changes with before/after snapshots, change attribution, and the ability to reconstruct any past state. The audit must work even when database migrations or admin tools modify data directly — application-layer logging alone is insufficient. A trigger-based audit with a WHEN clause avoids logging no-op updates where no columns actually changed.

```sql
CREATE TABLE user_audit (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         INT NOT NULL,
    operation       TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    changed_fields  TEXT[],        -- which columns changed (UPDATE only)
    old_data        JSONB,
    new_data        JSONB,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by      TEXT NOT NULL DEFAULT COALESCE(
                        current_setting('app.current_user', true),
                        session_user
                    )
);

CREATE OR REPLACE FUNCTION audit_user_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_changed_fields TEXT[] := '{}';
    v_key TEXT;
BEGIN
    -- For UPDATE: compute which fields actually changed
    IF TG_OP = 'UPDATE' THEN
        FOR v_key IN SELECT jsonb_object_keys(to_jsonb(NEW)) LOOP
            IF (to_jsonb(OLD) -> v_key) IS DISTINCT FROM (to_jsonb(NEW) -> v_key) THEN
                v_changed_fields := array_append(v_changed_fields, v_key);
            END IF;
        END LOOP;
    END IF;

    INSERT INTO user_audit (user_id, operation, changed_fields, old_data, new_data)
    VALUES (
        COALESCE(NEW.id, OLD.id),
        TG_OP,
        CASE WHEN TG_OP = 'UPDATE' THEN v_changed_fields ELSE NULL END,
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
    );

    RETURN NEW;
END;
$$;

-- Only fire on actual data changes — skip no-op UPDATEs
CREATE TRIGGER trg_users_audit
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW
WHEN (
    TG_OP IN ('INSERT', 'DELETE') OR
    (TG_OP = 'UPDATE' AND to_jsonb(OLD) IS DISTINCT FROM to_jsonb(NEW))
)
EXECUTE FUNCTION audit_user_changes();
```

*The key insight: the WHEN clause prevents the trigger from firing on no-op UPDATEs (where a row is written with identical values) — which are common in ORM-generated queries. The `changed_fields` array tracks exactly which columns changed, enabling efficient queries like "show me all rows where the email changed" without scanning the full JSONB diff. The `app.current_user` session setting allows the application to pass the authenticated user's identity to the database layer.*

---

## Common Misconceptions

**"Triggers fire after a TRUNCATE"**
Row-level triggers (`FOR EACH ROW`) do NOT fire on TRUNCATE — TRUNCATE bypasses the row-level trigger mechanism entirely. If you need to catch a TRUNCATE, you must create a statement-level trigger (`FOR EACH STATEMENT`) with an event type of `TRUNCATE`. Most audit log implementations miss this.

**"A BEFORE trigger can't see the final committed state"**
A BEFORE trigger fires before the write is committed. It sees the proposed new values in `NEW` and can modify them or raise an exception to cancel. It cannot prevent the change from the outside — it can only work with `NEW` directly. If you want to validate against other tables, a BEFORE trigger is the right place (before the row is written); an AFTER trigger validates after the row is written and can see the full committed state of other tables.

**"Trigger names are globally unique"**
Trigger names are scoped to their table, not the database. Two different tables can have triggers with the same name. This is why `DROP TRIGGER name` requires the table name: `DROP TRIGGER trg_audit ON orders`. Forgetting the table name is a common syntax error.

---

## Gotchas

- **Triggers fire synchronously inside the triggering transaction** — a slow trigger adds latency to every write on the table. A failing trigger rolls back the triggering INSERT/UPDATE/DELETE. A network call, long computation, or external API call inside a trigger is a write-path reliability problem.

- **Recursive trigger loops are silent and dangerous** — if trigger A on table X modifies table Y, and trigger B on table Y modifies table X, you get infinite recursion until the stack overflows. PostgreSQL eventually throws an error, but it's hard to diagnose. Always check whether your trigger's action could re-trigger itself or create a cycle.

- **FOR EACH STATEMENT triggers don't see NEW or OLD** — statement-level triggers fire once per statement regardless of row count, and `NEW` and `OLD` are NULL in the trigger body. Use transition tables (`REFERENCING NEW TABLE AS`) to access the affected rows in a statement-level trigger.

- **TRUNCATE bypasses row-level triggers** — always document this limitation when building audit systems. If TRUNCATE is possible (admin operations, bulk deletes), add a TRUNCATE event trigger or prohibit TRUNCATE on audited tables.

- **Performance: one heavy trigger on a high-write table** — a trigger that does a JOIN or subquery runs that query for every affected row. On a table receiving thousands of writes per second, trigger performance must be measured, not assumed. Use statement-level triggers with transition tables for bulk operations.

---

## Interview Angle

**What they're really testing:** Whether you understand the transactional implications of triggers and can reason about when they're the right tool versus application-layer hooks.

**Common question forms:**
- "How would you automatically update an `updated_at` column?"
- "How would you implement an audit log for a users table?"
- "What's the difference between a BEFORE and AFTER trigger?"

**The depth signal:** A junior knows triggers exist and can describe BEFORE vs AFTER. A senior understands that triggers run synchronously inside the transaction — so a slow or failing trigger directly impacts write performance and reliability, distinguishes BEFORE triggers (can cancel or modify the row) from AFTER triggers (react to the committed row, cannot cancel), knows that statement-level triggers don't expose NEW/OLD but can use transition tables (PG 10+), and flags that TRUNCATE bypasses row-level triggers entirely. The WHEN clause for conditional trigger firing and the recursive loop risk are strong senior signals.

**Follow-up questions to expect:**
- "How would you make an audit trigger fire only when specific columns change?"
- "What happens if a trigger raises an exception?"

---

## Related Topics

- [[databases/sql/sql-functions.md]] — triggers call functions; the trigger function must be created first
- [[databases/sql/sql-stored-procedures.md]] — procedures vs triggers: procedures are called explicitly, triggers fire automatically
- [[databases/sql/sql-transactions.md]] — triggers execute inside the triggering transaction; failure rolls everything back

---

## Source

https://www.postgresql.org/docs/current/sql-createtrigger.html

---
*Last updated: 2026-04-13*