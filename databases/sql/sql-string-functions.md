# SQL String Functions

> SQL string functions manipulate, search, and transform text values — from simple concatenation and trimming to pattern matching and regular expressions.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Built-in functions for text transformation and pattern matching |
| **Use when** | Cleaning input, formatting output, searching text columns |
| **Avoid when** | Full-text search at scale — use tsvector/tsquery or Elasticsearch instead |
| **Standard** | SQL-92 (LIKE, SUBSTRING, TRIM, UPPER/LOWER); extensions vary by database |
| **Key functions** | `LIKE`, `ILIKE`, `SIMILAR TO`, `~` (regex), `LENGTH`, `SUBSTRING`, `SPLIT_PART`, `TRIM`, `CONCAT`, `FORMAT`, `REPLACE`, `REGEXP_REPLACE` |

---

## When To Use It

Use string functions for data cleaning (trimming whitespace, normalising case), output formatting (building display names, constructing labels), and pattern matching (finding rows by partial string match). Avoid using LIKE with a leading wildcard (`LIKE '%search%'`) on large tables without a trigram index — it forces a full sequential scan. For serious full-text search requirements, use PostgreSQL's built-in `tsvector`/`tsquery` or a dedicated search engine.

---

## Core Concept

String functions in PostgreSQL are NULL-propagating: most functions return NULL if any argument is NULL. `CONCAT('hello', NULL)` returns NULL in standard SQL — PostgreSQL's `CONCAT` is an exception (it silently skips NULLs), but `||` concatenation is not. The other critical behaviour: string comparison and pattern matching is case-sensitive by default in PostgreSQL (unlike MySQL's default). `'Hello' = 'hello'` is FALSE. `'Hello' ILIKE 'hello'` is TRUE.

LIKE uses two wildcards: `%` (any sequence of characters) and `_` (any single character). It can use a B-tree index only when the pattern is left-anchored (starts with a literal prefix: `LIKE 'prefix%'`). A leading wildcard (`LIKE '%suffix'` or `LIKE '%middle%'`) always forces a sequential scan unless a reverse index or trigram index exists.

---

## Version History

| Standard / Version | What changed |
|---|---|
| SQL-92 | LIKE, SUBSTRING, TRIM, UPPER, LOWER, CHAR_LENGTH standardized |
| SQL:1999 | SIMILAR TO (regex-like pattern matching) added |
| PostgreSQL (all) | `~` and `~*` for POSIX regex; `pg_trgm` extension for trigram search |
| PostgreSQL 9.1 | `FORMAT()` function added |
| PostgreSQL 14 | `SPLIT_PART` improvements; `UNISTR` function |

---

## Performance

| Pattern | Index use | Notes |
|---|---|---|
| `LIKE 'prefix%'` | B-tree | Left-anchored — can use standard index |
| `LIKE '%suffix'` | None | Leading wildcard — full seq scan |
| `LIKE '%middle%'` | None (or GIN + trigram) | Full scan without `pg_trgm` extension |
| `ILIKE 'prefix%'` | Expression index on lower() | Case-insensitive prefix — needs lower() index |
| `~ 'regex'` | None (or GIN + trigram) | Full regex — full scan without trigram index |
| `= 'exact'` | B-tree | Standard equality — fastest |

**Allocation behaviour:** String functions operate in memory on text values. For large TEXT columns, the value is loaded from TOAST storage before the function runs. Processing millions of rows with string transformations in SELECT is fine; doing it in WHERE to filter is expensive — it must evaluate the function for every row before it can filter.

---

## The Code

**Case functions**
```sql
SELECT
    UPPER('hello world'),   -- 'HELLO WORLD'
    LOWER('Hello World'),   -- 'hello world'
    INITCAP('hello world')  -- 'Hello World' (capitalises first letter of each word)
FROM users;

-- Common use: normalise email for comparison
SELECT * FROM users WHERE LOWER(email) = LOWER('Ahmed@Example.com');
-- Better: store email already lowercased and query with plain equality
```

**Trimming whitespace**
```sql
SELECT
    TRIM('  hello  '),         -- 'hello' (both sides)
    LTRIM('  hello  '),        -- 'hello  ' (left only)
    RTRIM('  hello  '),        -- '  hello' (right only)
    TRIM(BOTH 'x' FROM 'xxxhelloxxx'),  -- 'hello' (custom character)
    BTRIM('  hello  ');        -- same as TRIM in PostgreSQL
```

**Length**
```sql
SELECT
    LENGTH('hello'),           -- 5 (character count — handles multibyte UTF-8)
    CHAR_LENGTH('hello'),      -- 5 (SQL standard synonym)
    OCTET_LENGTH('héllo'),     -- 6 (byte count — é is 2 bytes in UTF-8)
    BIT_LENGTH('hello');       -- 40 (bit count)
```

**Concatenation**
```sql
-- || operator: NULL-propagating (returns NULL if either side is NULL)
SELECT first_name || ' ' || last_name AS full_name FROM users;

-- CONCAT function: NULL-safe (NULLs treated as empty string)
SELECT CONCAT(first_name, ' ', last_name) AS full_name FROM users;

-- CONCAT_WS: with separator — skips NULLs entirely
SELECT CONCAT_WS(', ', city, state, country) AS location FROM addresses;
-- If city is NULL: 'New York, USA' not ', New York, USA'
```

**Substring extraction**
```sql
-- SUBSTRING(string FROM start FOR length) — SQL standard
SELECT
    SUBSTRING('hello world' FROM 1 FOR 5),  -- 'hello'
    SUBSTRING('hello world' FROM 7),         -- 'world' (to end)
    LEFT('hello world', 5),                  -- 'hello' (PostgreSQL shorthand)
    RIGHT('hello world', 5),                 -- 'world' (PostgreSQL shorthand)
    SUBSTR('hello world', 7, 5);             -- 'world' (alternate syntax)
```

**Splitting strings**
```sql
-- SPLIT_PART: split by delimiter and return Nth part (1-indexed)
SELECT
    SPLIT_PART('2024-01-15', '-', 1),  -- '2024'
    SPLIT_PART('2024-01-15', '-', 2),  -- '01'
    SPLIT_PART('2024-01-15', '-', 3);  -- '15'

-- STRING_TO_ARRAY: split into an array
SELECT STRING_TO_ARRAY('a,b,c', ',');   -- ARRAY['a','b','c']

-- STRING_TO_TABLE (PG 16+): split into rows — useful for unnesting CSV values
SELECT * FROM STRING_TO_TABLE('a,b,c', ',');  -- three rows: a, b, c

-- REGEXP_SPLIT_TO_TABLE: split by regex
SELECT REGEXP_SPLIT_TO_TABLE('one  two   three', '\s+');  -- splits on whitespace
```

**Search and replace**
```sql
SELECT
    REPLACE('hello world', 'world', 'SQL'),   -- 'hello SQL'
    REGEXP_REPLACE('order-123-abc', '\d+', 'N', 'g'),  -- 'order-N-abc' (g = global)
    TRANSLATE('hello', 'aeiou', '*****');      -- 'h*ll*' (char-by-char substitution)
```

**Pattern matching**
```sql
-- LIKE: SQL standard, two wildcards: % (any sequence), _ (any single char)
SELECT * FROM products WHERE name LIKE 'iPhone%';       -- starts with 'iPhone'
SELECT * FROM products WHERE sku LIKE 'A__-001';        -- 'A' + 2 chars + '-001'

-- ILIKE: case-insensitive LIKE (PostgreSQL only)
SELECT * FROM users WHERE email ILIKE '%@gmail.com';

-- SIMILAR TO: SQL:1999 standard, regex-like but more limited
SELECT * FROM users WHERE phone SIMILAR TO '\+?[0-9]{10,15}';

-- POSIX regex: ~ (match), ~* (match case-insensitive), !~ (not match)
SELECT * FROM users WHERE email ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

-- NOT LIKE, NOT ILIKE, !~
SELECT * FROM users WHERE email NOT ILIKE '%@internal.company.com';
```

**Trigram search — LIKE '%middle%' with an index (requires pg_trgm)**
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- GIN trigram index: supports LIKE '%...%', ILIKE, and regex matching
CREATE INDEX idx_products_name_trgm ON products USING GIN (name gin_trgm_ops);

-- Now this uses the index instead of a full scan
SELECT * FROM products WHERE name ILIKE '%wireless headphones%';
SELECT * FROM products WHERE name ~ 'wireless.*headphone';
```

**FORMAT — sprintf-style string building**
```sql
-- Useful for dynamic messages, log entries, display strings
SELECT FORMAT('Order #%s placed by %s on %s',
    id::TEXT,
    customer_name,
    TO_CHAR(created_at, 'YYYY-MM-DD')
) AS order_summary
FROM orders;

-- %s = string, %I = identifier (quoted), %L = literal (quoted for SQL)
-- %I and %L are especially useful in dynamic SQL to prevent injection
```

**REGEXP_MATCHES — extract capture groups**
```sql
-- Extract area code from phone numbers
SELECT
    phone,
    (REGEXP_MATCH(phone, '^\+?1?\s*\(?(\d{3})\)?'))[1] AS area_code
FROM users
WHERE phone IS NOT NULL;

-- REGEXP_MATCHES returns all matches (use when pattern can match multiple times)
SELECT match[1]
FROM users,
LATERAL REGEXP_MATCHES(tags_string, '([a-z]+)', 'g') AS match(match);
```

---

## Real World Example

A user data migration pipeline ingests contact records from a legacy CRM where data quality is poor: names have inconsistent casing, phone numbers have mixed formatting, emails have trailing spaces, and some "full name" fields contain comma-separated "LastName, FirstName" format that needs flipping.

```sql
WITH raw_contacts AS (
    SELECT
        id,
        TRIM(LOWER(email))                                AS email_clean,

        -- Normalise phone: strip everything but digits and leading +
        REGEXP_REPLACE(TRIM(phone), '[^\d+]', '', 'g')    AS phone_clean,

        -- Handle both "First Last" and "Last, First" formats
        CASE
            WHEN full_name LIKE '%,%'
            THEN INITCAP(TRIM(SPLIT_PART(full_name, ',', 2)))
                 || ' ' ||
                 INITCAP(TRIM(SPLIT_PART(full_name, ',', 1)))
            ELSE INITCAP(TRIM(full_name))
        END                                               AS name_clean,

        -- Convert empty strings to NULL
        NULLIF(TRIM(company), '')                         AS company_clean

    FROM legacy_contacts
    WHERE id > :last_processed_id
),
validated AS (
    SELECT *,
        -- Flag invalid emails for manual review rather than rejecting silently
        email_clean ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' AS email_valid,
        LENGTH(phone_clean) BETWEEN 10 AND 15                              AS phone_valid
    FROM raw_contacts
    WHERE email_clean IS NOT NULL
)
INSERT INTO contacts (email, phone, full_name, company, needs_review, imported_at)
SELECT
    email_clean,
    CASE WHEN phone_valid THEN phone_clean ELSE NULL END,
    name_clean,
    company_clean,
    NOT email_valid OR NOT phone_valid,
    NOW()
FROM validated
ON CONFLICT (email) DO UPDATE
    SET phone      = EXCLUDED.phone,
        full_name  = EXCLUDED.full_name,
        company    = EXCLUDED.company,
        updated_at = NOW();
```

*The key insight: almost every string function in this pipeline has a specific data quality job. TRIM cleans whitespace. REGEXP_REPLACE strips non-digit characters from phone numbers. SPLIT_PART flips name format. INITCAP normalises casing. NULLIF turns empty strings into NULLs. Regex validation flags records for review rather than silently dropping them. Each transformation is composable and testable independently.*

---

## Common Misconceptions

**"LIKE is case-insensitive"**
LIKE in PostgreSQL is case-sensitive. `WHERE name LIKE 'john%'` does not match `'John Smith'`. Use ILIKE for case-insensitive matching in PostgreSQL. In MySQL, LIKE is case-insensitive by default (depends on collation) — a portability trap.

**"LENGTH() counts bytes"**
In PostgreSQL, `LENGTH()` counts characters (code points), not bytes. A UTF-8 character like `é` counts as 1 character but 2 bytes. Use `OCTET_LENGTH()` for byte counts. This matters when you're checking whether a string fits in a column defined with a byte limit.

**"CONCAT is the same as ||"**
They differ on NULLs. `'hello' || NULL` returns NULL. `CONCAT('hello', NULL)` returns `'hello'`. In practice, always use `CONCAT_WS` with a separator when building strings from nullable columns — it silently skips NULLs and is the most defensive option.

---

## Gotchas

- **Leading wildcard LIKE forces a full sequential scan** — `LIKE '%search%'` reads every row. On a 10M row table, this takes seconds. The fix is a trigram GIN index via `pg_trgm` — which turns any LIKE pattern into an indexed lookup.

- **String comparison is case-sensitive in PostgreSQL** — always normalise case in both the stored value and the query, or use ILIKE. Don't rely on collation defaults — they vary by database, operating system, and version.

- **`||` returns NULL if any operand is NULL** — use `CONCAT_WS` when building strings from nullable columns, or wrap each nullable part in `COALESCE(col, '')`.

- **REGEXP_REPLACE default replaces only the first match** — pass `'g'` as the fourth argument (`flags`) to replace all occurrences. Without `'g'`, `REGEXP_REPLACE('aababab', 'ab', 'X')` returns `'aXabab'` not `'aXXX'`.

- **SIMILAR TO is rarely the right choice** — it uses SQL's limited regex syntax, not POSIX. It's less powerful than `~` and slower than LIKE. Use LIKE for simple patterns and `~` for real regex. SIMILAR TO exists for SQL standard compliance and is almost never the best option.

---

## Interview Angle

**What they're really testing:** Whether you know which function to reach for in data cleaning and ETL contexts, and whether you understand the performance implications of pattern matching.

**Common question forms:**
- "How would you find all users whose email ends with @gmail.com?"
- "How would you extract the domain from an email address?"
- "Why is this LIKE query slow, and how would you fix it?"

**The depth signal:** A junior knows LIKE, UPPER/LOWER, and CONCAT. A senior knows that leading-wildcard LIKE is a full-table-scan unless a trigram index exists, uses CONCAT_WS for NULL-safe string building, reaches for REGEXP_REPLACE with the `'g'` flag for global replacement, and knows SPLIT_PART for structured-string parsing. They also know that `||` and CONCAT differ on NULLs, and that PostgreSQL is case-sensitive by default while MySQL is not — a portability trap worth flagging in cross-database contexts.

**Follow-up questions to expect:**
- "How do you search for a substring efficiently on a large table?"
- "What's the difference between LIKE and ILIKE in terms of index use?"

---

## Related Topics

- [[databases/sql/sql-null-handling.md]] — CONCAT vs `||` null behaviour; NULLIF for empty-string normalisation
- [[databases/sql/sql-indexing.md]] — trigram indexes (GIN + pg_trgm) are the fix for `LIKE '%...'` patterns
- [[databases/sql/sql-date-functions.md]] — date formatting often uses TO_CHAR which shares string formatting patterns
- [[databases/postgres-sql/postgres-full-text-search.md]] — when LIKE isn't enough: tsvector, tsquery, and ranking

---

## Source

https://www.postgresql.org/docs/current/functions-string.html

---
*Last updated: 2026-04-13*