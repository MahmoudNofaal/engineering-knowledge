# SQL Functions

> A SQL function is a named, reusable block of logic stored in the database that accepts inputs, performs a computation, and returns a value — usable directly inside a SELECT, WHERE, or any expression.

---

## When To Use It
Use functions when you need reusable logic that returns a value and can live inside a query expression — formatting, calculation, deriving a value from columns, or encapsulating a complex expression used in multiple places. They're the right tool when the logic belongs close to the data and the output slots naturally into a query. Avoid them for multi-step workflows that modify data across several tables — that's a stored procedure's job. Also avoid functions that get called per-row on large tables without careful thought — a function in a WHERE clause on an unindexed column forces a full table scan.

---

## When To Use It
Functions shine when the logic is deterministic, reusable, and needs to compose with SQL naturally. The moment you need transaction control (COMMIT/ROLLBACK mid-execution), switch to a procedure instead — PostgreSQL functions cannot issue explicit commits.

---

## Core Concept
A function takes zero or more input parameters, runs some logic, and returns exactly one value — a scalar, a row, or a set of rows depending on the return type. The database stores the definition and compiles an execution plan. What separates a function from a procedure is that a function has a return value and plugs into expressions; you can call it anywhere a value is valid. Functions are also classified by volatility: IMMUTABLE (same inputs always produce same output, no DB access), STABLE (same inputs return same output within a transaction), and VOLATILE (can return different results each call, can modify data). The planner uses volatility to decide whether it can cache or optimize calls.

---

## The Code

**Simple scalar function**
```sql
CREATE OR REPLACE FUNCTION full_name(first_name TEXT, last_name TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE  -- same inputs always return same output
AS $$
    SELECT first_name || ' ' || last_name;
$$;

-- Use it anywhere a value fits
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
    IF total_spend >= 10000 THEN RETURN 0.20;
    ELSIF total_spend >= 5000 THEN RETURN 0.10;
    ELSIF total_spend >= 1000 THEN RETURN 0.05;
    ELSE RETURN 0.00;
    END IF;
END;
$$;

SELECT
    user_id,
    total_spend,
    discount_rate(total_spend)              AS rate,
    total_spend * discount_rate(total_spend) AS discount_amount
FROM user_spend_summary;
```

**Function that queries the database (STABLE)**
```sql
CREATE OR REPLACE FUNCTION get_user_country(p_user_id INT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE  -- queries DB but returns same result within a transaction
AS $$
DECLARE
    v_country TEXT;
BEGIN
    SELECT country INTO v_country
    FROM users
    WHERE id = p_user_id;

    RETURN v_country;
END;
$$;
```

**Set-returning function — returns multiple rows**
```sql
CREATE OR REPLACE FUNCTION orders_for_user(p_user_id INT)
RETURNS TABLE (
    order_id        INT,
    total_amount    NUMERIC,
    status          TEXT,
    created_at      TIMESTAMPTZ
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

-- Call like a table
SELECT * FROM orders_for_user(42);
```

**Function used in a WHERE clause**
```sql
CREATE OR REPLACE FUNCTION is_high_value_order(amount NUMERIC)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT amount > 500;
$$;

SELECT id, total_amount
FROM orders
WHERE is_high_value_order(total_amount);
-- Fine on small tables; on large tables this prevents index use on total_amount
-- A plain WHERE total_amount > 500 is faster and indexable
```

**Drop a function**
```sql
DROP FUNCTION IF EXISTS full_name(TEXT, TEXT);
-- Parameter types required when overloaded versions exist
```

---

## Gotchas

- **A function in a WHERE clause on a large table kills index usage** — wrapping a column in a function call (`WHERE my_func(column) = x`) prevents the planner from using an index on that column. The function must be evaluated per-row, forcing a full scan. Use expression indexes (`CREATE INDEX ON t (my_func(column))`) or rewrite the condition if you need both.
- **VOLATILE is the default volatility — and it's the most conservative** — if you don't declare IMMUTABLE or STABLE, PostgreSQL assumes the function can return different results each call and cannot optimize repeated calls. Always declare the correct volatility; incorrect IMMUTABLE declarations cause wrong query results from stale cached values.
- **PostgreSQL functions cannot COMMIT or ROLLBACK** — transaction control is reserved for stored procedures. If you try to call COMMIT inside a function, PostgreSQL throws an error. If your logic needs explicit transaction boundaries, it belongs in a procedure, not a function.
- **Overloaded functions are resolved by parameter types** — PostgreSQL allows multiple functions with the same name but different parameter types. `DROP FUNCTION name` without parameter types fails if overloads exist. This also means an ambiguous call can silently resolve to the wrong overload.
- **Set-returning functions in SELECT can produce unexpected row multiplication** — calling a set-returning function in the SELECT list alongside other set-returning functions produces a cross-join of their outputs (in older PostgreSQL versions). In PostgreSQL 10+, multiple set-returning functions in SELECT are zipped instead, but the behavior is still surprising. Put set-returning functions in FROM with LATERAL for predictable results.

---

## Interview Angle
**What they're really testing:** Whether you understand the difference between functions and procedures, and whether you know how function volatility and placement affect query planning and performance.

**Common question form:** "What's the difference between a function and a stored procedure?" or "Why is this query slow when it wasn't slow before you added that function call?"

**The depth signal:** A junior says functions return values and procedures don't, and stops there. A senior explains the three volatility levels and why marking a function IMMUTABLE incorrectly causes wrong cached results, knows that functions in WHERE clauses suppress index use and why, and is clear that PostgreSQL functions cannot issue COMMIT — so anything needing explicit transaction control is a procedure. They also know that set-returning functions belong in FROM rather than SELECT for predictable behavior, and can explain when an expression index rescues a function-wrapped column in a WHERE clause.

---

## Related Topics
- [[databases/sql-stored-procedures.md]] — procedures vs functions: transaction control, return values, and when each applies
- [[databases/sql-triggers.md]] — triggers call functions (specifically trigger functions) automatically on table events
- [[databases/indexes.md]] — expression indexes are the fix when you must filter on a function-wrapped column
- [[databases/query-optimization.md]] — function volatility directly affects how the planner caches and optimizes repeated calls

---

## Source
https://www.postgresql.org/docs/current/sql-createfunction.html

---
*Last updated: 2026-03-24*