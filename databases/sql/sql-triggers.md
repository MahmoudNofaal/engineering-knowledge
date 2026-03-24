# SQL Triggers

> A trigger is a function the database calls automatically when a specific event — INSERT, UPDATE, or DELETE — occurs on a table.

---

## When To Use It
Use triggers for logic that must fire unconditionally on every data change, regardless of which application or process causes it — audit logging, enforcing derived column values, maintaining a denormalized summary table, or cascading soft deletes. They're one of the few tools that work even when data changes come from migrations, bulk imports, or direct psql sessions that bypass application code. Avoid them for business logic that belongs in the service layer, or for anything that makes a network call or has significant side effects — triggers fire synchronously inside the transaction, and a slow or failing trigger rolls back the triggering statement.

---

## Core Concept
A trigger binds a function to a table event. When that event fires, the database calls the function automatically — before or after the row is written, once per row or once per statement. The trigger function gets access to special variables: `NEW` holds the row being inserted or updated, `OLD` holds the row before an update or delete. Returning `NULL` from a BEFORE trigger cancels the operation entirely. Returning `NEW` (possibly modified) lets it proceed. AFTER triggers can't cancel the operation but can react to it. The trigger function must be created separately from the trigger itself — the function first, then the binding.

---

## The Code

**Step 1 — Create the trigger function**
```sql
-- Trigger functions return type TRIGGER, take no arguments
-- Arguments are passed via TG_ARGV[] if needed, not function parameters
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();  -- modify the row before it's written
    RETURN NEW;               -- must return NEW for BEFORE triggers on rows
END;
$$;
```

**Step 2 — Bind the trigger to a table**
```sql
CREATE TRIGGER trg_users_updated_at
BEFORE INSERT OR UPDATE ON users   -- fires before the write
FOR EACH ROW                        -- once per affected row
EXECUTE FUNCTION set_updated_at();
```

**Audit log trigger — record every change**
```sql
-- Audit table
CREATE TABLE user_audit_log (
    id          SERIAL PRIMARY KEY,
    user_id     INT,
    action      TEXT,           -- 'INSERT', 'UPDATE', 'DELETE'
    old_data    JSONB,
    new_data    JSONB,
    changed_at  TIMESTAMPTZ DEFAULT NOW(),
    changed_by  TEXT DEFAULT current_user
);

-- Trigger function
CREATE OR REPLACE FUNCTION log_user_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO user_audit_log (user_id, action, old_data, new_data)
    VALUES (
        COALESCE(NEW.id, OLD.id),
        TG_OP,                          -- 'INSERT', 'UPDATE', or 'DELETE'
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
    );
    RETURN NEW;  -- ignored for AFTER triggers but required by convention
END;
$$;

-- Bind to table
CREATE TRIGGER trg_users_audit
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW
EXECUTE FUNCTION log_user_changes();
```

**BEFORE trigger to enforce a business rule**
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

**AFTER trigger to maintain a summary table**
```sql
CREATE OR REPLACE FUNCTION update_user_order_summary()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO user_order_summary (user_id, order_count, total_spent)
    VALUES (NEW.user_id, 1, NEW.total_amount)
    ON CONFLICT (user_id) DO UPDATE
        SET order_count  = user_order_summary.order_count + 1,
            total_spent  = user_order_summary.total_spent + NEW.total_amount;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_orders_summary
AFTER INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION update_user_order_summary();
```

**Drop a trigger**
```sql
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
-- Must specify the table — trigger names are scoped to the table, not global
```

---

## Gotchas

- **Triggers fire inside the triggering transaction** — if the trigger function raises an exception or fails, the entire transaction rolls back, including the INSERT/UPDATE/DELETE that caused it. A slow trigger adds latency to every write on that table. A crashing trigger breaks writes entirely until it's fixed.
- **Trigger names are scoped to the table, not the database** — two tables can have a trigger named `trg_audit` without conflict. But `DROP TRIGGER trg_audit` without specifying the table fails. Always include the table name when dropping.
- **FOR EACH STATEMENT triggers receive NULL for NEW and OLD** — statement-level triggers fire once per SQL statement regardless of how many rows were affected, and they don't have access to individual row values. For row-level access you need `FOR EACH ROW`.
- **Triggers don't fire on TRUNCATE by default the same way** — TRUNCATE bypasses row-level triggers entirely. If you need to catch a TRUNCATE, you must create a statement-level trigger specifically for `TRUNCATE` events. Many audit log implementations miss this.
- **Recursive trigger loops are silent and dangerous** — if a trigger on table A modifies table B, and a trigger on table B modifies table A, you get infinite recursion until the stack overflows. PostgreSQL will eventually throw an error, but it can be hard to diagnose. Always check whether your trigger's action could re-trigger itself or create a cycle.

---

## Interview Angle
**What they're really testing:** Whether you understand the transactional implications of triggers and can reason about when they're the right tool versus an application-layer hook.

**Common question form:** "How would you automatically update an `updated_at` column?" or "How would you implement an audit log for a users table?"

**The depth signal:** A junior knows triggers exist and can describe BEFORE vs AFTER. A senior understands that triggers run synchronously inside the transaction — so a slow or failing trigger directly impacts write performance and reliability. They distinguish BEFORE triggers (can cancel or modify the row) from AFTER triggers (react to the committed row, can't cancel), know that statement-level triggers don't expose NEW/OLD, and flag that TRUNCATE bypasses row-level triggers entirely. They also know the recursive loop risk and mention it unprompted when discussing trigger design.

---

## Related Topics
- [[databases/sql-functions.md]] — triggers call functions; the trigger function must be created before the trigger binding
- [[databases/sql-stored-procedures.md]] — procedures vs triggers: procedures are called explicitly, triggers fire automatically
- [[databases/transactions-and-acid.md]] — triggers execute inside the triggering transaction; failure rolls everything back
- [[databases/query-optimization.md]] — triggers add overhead to every write on the table; high-frequency tables need careful evaluation

---

## Source
https://www.postgresql.org/docs/current/sql-createtrigger.html

---
*Last updated: 2026-03-24*