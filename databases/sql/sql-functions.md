# SQL Functions

> A SQL function is a named, reusable block of logic stored in the database that accepts inputs, performs a computation, and returns a value — usable directly inside a SELECT, WHERE, or any expression.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Named reusable logic that returns a value, usable in any expression |
| **Use when** | Reusable calculation; derived value from columns; logic that belongs close to data |
| **Avoid when** | Multi-step workflows that modify data across tables — use a procedure instead |
| **Standard** | SQL:1999 (PSM); PostgreSQL: `LANGUAGE sql`, `LANGUAGE plpgsql`, `LANGUAGE c` |
| **Key variants** | Scalar, Set-returning (SRF), Aggregate, Window, Trigger |
| **Volatility** | `IMMUTABLE` · `STABLE` · `VOLATILE` (default) — affects planner optimization |

---

## When To Use It

Use functions when you need reusable logic that returns a value and can live inside a query expression — formatting, calculation, deriving a value from columns, or encapsulating a complex expression used in multiple places. They're the right tool when the logic belongs close to the data and the output slots naturally into a query. Avoid functions for multi-step workflows that modify data across several tables — that's a stored procedure's job. Also avoid functions that get called per-row on large tables without careful thought — a function in a WHERE clause on an unindexed column forces a full table scan.

---

## Core Concept

A function takes zero or more input parameters, runs some logic, and returns a value. What separates a function from a procedure is that a function has a return type and plugs into expressions — you can call it anywhere a value is valid: SELECT list, WHERE clause, ORDER BY, HAVING, as a default column value, inside another function. Functions are classified by volatility: IMMUTABLE (same inputs always produce same output, no DB access — planner can inline and cache), STABLE (same inputs return same output within a transaction — planner can cache per query), and VOLATILE (can return different results each call, can modify data — planner cannot cache). The volatility classification directly affects how many times the planner calls the function and whether it can optimise around it.

---

## Version History

| PostgreSQL Version | What changed |
|---|---|
| Pre-8.0 | PL/pgSQL, SQL, and C language functions |
| 8.3 | Default parameter values |
| 9.1 | `DO` block for anonymous functions |
| 9.3 | LATERAL allows SRFs in FROM clause to reference preceding tables |
| 11 | Procedures added as separate object (`CREATE PROCEDURE`) |
| 14 | `CREATE STATISTICS` on expressions (extends function-column statistics) |

---

## Performance

| Volatility | Planner behaviour | Use when |
|---|---|---|
| `IMMUTABLE` | Can inline, cache, push into index | Pure computation, no DB access, deterministic |
| `STABLE` | Cache per query execution | Reads DB but stable within a transaction |
| `VOLATILE` | Never cache — call every time | Random values, NOW(), writes, non-deterministic |

**The performance trap:** A function in a WHERE clause on an unindexed column is called once per row — O(n) regardless of function cost. A function marked IMMUTABLE incorrectly (claims no DB access when it actually reads data) can produce stale cached results — wrong answers, no error. Always declare the correct volatility.

---

## The Code

**Simple scalar function**
```sql
CREATE OR REPLACE FUNCTION full_name(first_name TEXT, last_name TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT first_name || ' ' || last_name;
$$;

SELECT full_name(first_name, last_name) AS name, email
FROM users;
```

**Function with conditional logic (PL/pgSQL)**
```sql
CREATE OR REPLACE FUNCTION discount_rate(total_spend NUMERIC)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF    total_spend >= 10000 THEN RETURN 0.20;
    ELSIF total_spend >= 5000  THEN RETURN 0.10;
    ELSIF total_spend >= 1000  THEN RETURN 0.05;
    ELSE                            RETURN 0.00;
    END IF;
END;
$$;

SELECT user_id, total_spend,
       discount_rate(total_spend) AS rate
FROM user_spend_summary;
```

**Function that queries the database (STABLE)**
```sql
CREATE OR REPLACE FUNCTION get_user_country(p_user_id INT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE   -- reads DB but same result within a transaction
AS $$
DECLARE
    v_country TEXT;
BEGIN
    SELECT country INTO v_country FROM users WHERE id = p_user_id;
    RETURN v_country;
END;
$$;
```

**Set-returning function (SRF) — returns multiple rows**
```sql
CREATE OR REPLACE FUNCTION orders_for_user(p_user_id INT)
RETURNS TABLE (
    order_id     INT,
    total_amount NUMERIC,
    status       TEXT,
    created_at   TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
        SELECT id, total_amount, status, created_at
        FROM orders
        WHERE user_id = p_user_id
        ORDER BY created_at DESC;
END;
$$;

-- Call in FROM clause — correct pattern for SRFs
SELECT * FROM orders_for_user(42);

-- LATERAL: SRF that references an outer query row
SELECT u.id, u.email, recent.*
FROM users u
CROSS JOIN LATERAL orders_for_user(u.id) recent
WHERE u.is_active = true
LIMIT 100;
```

**Function used in a WHERE clause (watch performance)**
```sql
-- Fine for small tables:
SELECT id FROM orders WHERE is_high_value(total_amount);

-- On large tables: forces full scan (function evaluated per row)
-- Fix A: expression index
CREATE INDEX idx_orders_high_value ON orders (total_amount) WHERE total_amount > 500;

-- Fix B: inline the logic (remove function from WHERE entirely)
SELECT id FROM orders WHERE total_amount > 500;
```

**Volatility: correct vs incorrect declaration**
```sql
-- IMMUTABLE: safe — pure computation, no DB access
CREATE OR REPLACE FUNCTION celsius_to_fahrenheit(c NUMERIC)
RETURNS NUMERIC LANGUAGE sql IMMUTABLE AS $$
    SELECT c * 9.0 / 5 + 32;
$$;

-- STABLE: correct — reads DB but stable within transaction
CREATE OR REPLACE FUNCTION get_config_value(key TEXT)
RETURNS TEXT LANGUAGE plpgsql STABLE AS $$
DECLARE v TEXT;
BEGIN
    SELECT value INTO v FROM app_config WHERE config_key = key;
    RETURN v;
END;
$$;

-- VOLATILE: correct — returns different values each call
CREATE OR REPLACE FUNCTION random_order_suffix()
RETURNS TEXT LANGUAGE sql VOLATILE AS $$
    SELECT 'ORD-' || floor(random() * 1000000)::text;
$$;

-- IMMUTABLE declared INCORRECTLY — will cache wrong result:
CREATE OR REPLACE FUNCTION get_setting(key TEXT)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $$  -- WRONG: reads DB, not immutable
DECLARE v TEXT;
BEGIN
    SELECT value INTO v FROM settings WHERE k = key;  -- result may change
    RETURN v;  -- planner caches this — stale result, no error
END;
$$;
```

**Default parameter values**
```sql
CREATE OR REPLACE FUNCTION paginated_orders(
    p_user_id   INT,
    p_limit     INT  DEFAULT 20,
    p_offset    INT  DEFAULT 0
)
RETURNS SETOF orders
LANGUAGE sql
STABLE
AS $$
    SELECT * FROM orders
    WHERE user_id = p_user_id
    ORDER BY created_at DESC
    LIMIT p_limit OFFSET p_offset;
$$;

-- Call with defaults
SELECT * FROM paginated_orders(42);
-- Call with custom limit
SELECT * FROM paginated_orders(42, p_limit := 50);
```

**Drop a function**
```sql
DROP FUNCTION IF EXISTS full_name(TEXT, TEXT);
-- Must include parameter types when overloaded versions exist
```

---

## Real World Example

A multi-currency billing system needs to display all amounts in the user's preferred currency. Rather than doing currency conversion in application code (which requires a round trip to fetch the rates) or duplicating the conversion logic across dozens of queries, a STABLE function encapsulates it and lets it be called inline in any SELECT.

```sql
-- Currency rates table (updated hourly)
-- CREATE TABLE fx_rates (from_currency CHAR(3), to_currency CHAR(3), rate NUMERIC, updated_at TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION convert_currency(
    amount          NUMERIC,
    from_currency   CHAR(3),
    to_currency     CHAR(3)
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE  -- reads DB (fx_rates); stable within a transaction
AS $$
DECLARE
    v_rate NUMERIC;
BEGIN
    -- Same currency: no conversion needed
    IF from_currency = to_currency THEN
        RETURN amount;
    END IF;

    SELECT rate INTO v_rate
    FROM fx_rates
    WHERE fx_rates.from_currency = convert_currency.from_currency
      AND fx_rates.to_currency   = convert_currency.to_currency
      AND updated_at >= NOW() - INTERVAL '2 hours';

    IF v_rate IS NULL THEN
        RAISE EXCEPTION 'No current rate for %/%', from_currency, to_currency;
    END IF;

    RETURN ROUND(amount * v_rate, 2);
END;
$$;

-- Usage: inline in any SELECT across the codebase
SELECT
    i.id,
    i.amount                                AS original_amount,
    i.currency                              AS original_currency,
    convert_currency(i.amount, i.currency, u.preferred_currency) AS display_amount,
    u.preferred_currency                    AS display_currency
FROM invoices i
JOIN users u ON u.id = i.user_id
WHERE i.user_id = 42
  AND i.status  = 'paid';
```

*The key insight: marking the function STABLE (not IMMUTABLE) is correct and important — it reads `fx_rates` which can change between queries. STABLE means the planner caches the result within a single query execution but re-evaluates between queries. If marked IMMUTABLE incorrectly, the planner would cache the rate for an entire session — returning stale rates after an hourly update with no error.*

---

## Common Misconceptions

**"VOLATILE is the safe default — just use it everywhere"**
VOLATILE is the most conservative and disables all planner optimisation. Marking a function STABLE or IMMUTABLE when appropriate lets the planner inline it, cache results within a query, and push it into index scans. An IMMUTABLE function can even be used in an expression index — which is impossible for VOLATILE or STABLE functions. Declare the most permissive correct volatility.

**"Functions in WHERE clauses always suppress index use"**
A plain function call on a column (`WHERE lower(email) = 'x'`) suppresses index use on `email`. But if you create an expression index on `lower(email)`, the function in WHERE can use that expression index. The rule is: a function on a column without a matching expression index suppresses index use. The fix is an expression index, not always a rewrite.

**"PostgreSQL functions cannot COMMIT or ROLLBACK"**
This was true before PostgreSQL 11. Since version 11, procedures (created with CREATE PROCEDURE) can issue explicit COMMIT and ROLLBACK. Functions (created with CREATE FUNCTION) still cannot — they run inside the caller's transaction. If you need transaction control, create a PROCEDURE, not a FUNCTION.

---

## Gotchas

- **Incorrect IMMUTABLE declaration causes stale cached results** — marking a function IMMUTABLE when it reads DB data tells the planner it can cache the result across queries, sessions, and even compile it into index definitions. If the underlying data changes, queries silently return stale results with no error. Always declare the minimum permissive volatility that's actually correct.

- **Functions in WHERE clauses are called once per row** — a VOLATILE or STABLE function in WHERE evaluates once per row regardless of how fast the function is. On a 10M-row table this means 10M function calls. Use expression indexes or inline the logic when filtering large tables.

- **Set-returning functions in SELECT produce cross-joins in old PostgreSQL** — in PostgreSQL versions before 10, multiple SRFs in the SELECT list produce a cross product. In 10+, they're zipped. Put SRFs in FROM with LATERAL for predictable and correct results in all versions.

- **Overloaded functions resolved by parameter types** — PostgreSQL allows multiple functions with the same name but different parameter types. `DROP FUNCTION name` without parameter types fails if overloads exist. Ambiguous calls can silently resolve to the wrong overload.

- **Default parameters are positional by default** — when calling a function with defaults, you can skip trailing parameters but not middle ones unless you use named parameter syntax (`func(p_limit := 50)`). Know the named parameter syntax to avoid passing in the wrong positional order.

---

## Interview Angle

**What they're really testing:** Whether you understand function volatility and its implications for planner optimisation, and whether you know the difference between functions and procedures.

**Common question forms:**
- "What's the difference between a function and a stored procedure?"
- "Why is this query slow when it wasn't slow before you added that function call?"
- "What does IMMUTABLE mean and when would you use it?"

**The depth signal:** A junior says functions return values and procedures don't, and stops there. A senior explains the three volatility levels and why marking a function IMMUTABLE incorrectly causes stale cached results, knows that functions in WHERE clauses suppress index use on the wrapped column and that expression indexes are the fix, and is clear that PostgreSQL functions (not procedures) cannot issue COMMIT. They also know that SRFs belong in FROM with LATERAL for predictable results, and understand that overloaded functions require parameter types in DROP and may cause ambiguous call resolution.

**Follow-up questions to expect:**
- "When would you use a set-returning function vs a view?"
- "What's the difference between STABLE and IMMUTABLE in terms of when the planner can cache?"

---

## Related Topics

- [[databases/sql/sql-stored-procedures.md]] — procedures vs functions: transaction control, return values, when to use each
- [[databases/sql/sql-triggers.md]] — triggers call trigger functions automatically; the function must be created first
- [[databases/sql/sql-indexing.md]] — expression indexes are the fix for function-in-WHERE performance problems

---

## Source

https://www.postgresql.org/docs/current/sql-createfunction.html

---
*Last updated: 2026-04-13*