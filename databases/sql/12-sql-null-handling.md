# SQL NULL Handling

> NULL in SQL means "unknown" or "absent" — not zero, not empty string — and it propagates through every comparison, arithmetic operation, and aggregate in ways that consistently surprise developers.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A three-valued logic marker meaning "unknown/absent" |
| **Use when** | A value is genuinely unknown or not applicable |
| **Avoid when** | You can use a sentinel value (0, empty string, false) and NULL has no semantic meaning |
| **Standard** | SQL-86 (introduced); SQL:1999 (IS DISTINCT FROM added) |
| **Key operators** | `IS NULL`, `IS NOT NULL`, `IS DISTINCT FROM`, `COALESCE`, `NULLIF`, `NULLIF`, `NVL` (Oracle) |
| **The trap** | `NULL = NULL` evaluates to NULL (unknown), not true |

---

## When To Use It

Use NULL when a value is genuinely absent or unknown — a user who hasn't provided a phone number, a shipment with no delivery date yet, an optional survey field. Avoid it when you're using NULL as a sentinel to mean "zero" or "no" — use 0 or false instead. The more NULLs in a table, the more defensive code every query needs. NULL in a column that joins to another table causes left-join silent row drops. NULL in aggregates skews averages. Think before NULLing.

---

## Core Concept

SQL uses three-valued logic: TRUE, FALSE, and NULL (unknown). Any comparison involving NULL evaluates to NULL — not true, not false. NULL rows are excluded from WHERE conditions because the condition evaluates to NULL (not TRUE). This is the single most important thing to internalise: NULL is not falsy — it's *unknown*, and unknown is neither true nor false.

This has cascading implications. `NULL = NULL` is NULL, not true. `NULL != NULL` is NULL. `NULL > 5` is NULL. `1 + NULL = NULL`. `'hello' || NULL = NULL`. The only operators that handle NULL as a defined value are `IS NULL`, `IS NOT NULL`, and `IS DISTINCT FROM`.

---

## Version History

| Standard / Version | What changed |
|---|---|
| SQL-86 | NULL and IS NULL introduced |
| SQL:1999 | `IS DISTINCT FROM` and `IS NOT DISTINCT FROM` added |
| SQL:2003 | `NULLIF` standardized |
| PostgreSQL (all) | Full SQL standard NULL behaviour |
| MySQL (all) | NULL-safe equality operator `<=>` (non-standard alternative to IS NOT DISTINCT FROM) |

---

## Performance

| Operation | NULL impact | Notes |
|---|---|---|
| B-tree index | NULLs are indexed | PostgreSQL indexes NULLs in B-tree; useful for IS NULL queries |
| COUNT(*) | No impact | Counts rows regardless |
| COUNT(col) | Skips NULLs | Only counts non-NULL values |
| AVG(col) | Excludes NULLs | Denominator is count of non-NULLs, not total rows |
| SUM(col) | Treats NULLs as 0 | Returns NULL only if *all* values are NULL |
| Partial index WHERE col IS NULL | Very efficient | Only indexes the NULL rows — tiny index |

**Allocation behaviour:** NULL values in PostgreSQL do not consume column storage — a NULL bit in the row header marks the value as absent. However, variable-length columns (TEXT, JSONB) store one bit per nullable column in the header, which adds overhead when a table has many nullable columns.

---

## The Code

**The fundamental trap: `= NULL` always fails**
```sql
-- WRONG: WHERE col = NULL never matches any rows
-- NULL = anything evaluates to NULL, which is not TRUE
SELECT * FROM users WHERE deleted_at = NULL;   -- returns 0 rows, always

-- RIGHT: use IS NULL
SELECT * FROM users WHERE deleted_at IS NULL;

-- RIGHT: IS NOT NULL
SELECT * FROM users WHERE deleted_at IS NOT NULL;
```

**IS DISTINCT FROM — NULL-safe equality**
```sql
-- Standard equality: NULL = NULL is NULL (unknown)
SELECT NULL = NULL;   -- NULL

-- IS DISTINCT FROM: NULL IS NOT DISTINCT FROM NULL is TRUE
SELECT NULL IS NOT DISTINCT FROM NULL;  -- TRUE

-- Use case: compare two nullable columns where NULL = NULL should mean "same"
SELECT *
FROM configs c1
JOIN configs c2 ON c1.key = c2.key
WHERE c1.value IS DISTINCT FROM c2.value;
-- Returns rows where values differ, INCLUDING cases where one is NULL and the other isn't
-- Standard equality (c1.value != c2.value) would miss those cases
```

**COALESCE — return first non-NULL value**
```sql
-- Return the first non-NULL argument
SELECT COALESCE(nickname, first_name, 'Anonymous') AS display_name
FROM users;
-- If nickname is NULL, tries first_name; if that's also NULL, returns 'Anonymous'

-- Common use: default NULL to 0 in arithmetic
SELECT
    user_id,
    COALESCE(total_spend, 0)  AS spend,    -- NULL → 0
    COALESCE(discount, 0)     AS discount
FROM user_summary;
```

**NULLIF — return NULL when two values are equal**
```sql
-- Return NULL when the value equals the sentinel — prevents division by zero
SELECT
    revenue,
    orders,
    revenue / NULLIF(orders, 0) AS avg_order_value  -- if orders = 0, returns NULL not error
FROM daily_stats;

-- Also useful: turn empty strings into NULL
SELECT NULLIF(trim(phone_number), '') AS phone  -- '' → NULL
FROM users;
```

**NULL in aggregates**
```sql
-- COUNT(*) includes NULLs; COUNT(col) excludes NULLs
SELECT
    COUNT(*)           AS total_rows,         -- all rows
    COUNT(shipped_at)  AS shipped_rows,        -- only where shipped_at is not NULL
    AVG(rating)        AS avg_rating,          -- average of non-NULL ratings only
    SUM(discount)      AS total_discount       -- NULL discounts treated as absent (0 for SUM)
FROM orders;
-- If all values in a column are NULL, SUM returns NULL (not 0)
-- Wrap with COALESCE: COALESCE(SUM(discount), 0)
```

**NULL in JOINs — the silent row drop**
```sql
-- A LEFT JOIN on a nullable column silently loses rows where the column is NULL
-- because NULL = NULL is not TRUE in the ON condition

-- orders.promo_id is nullable
SELECT o.id, p.name
FROM orders o
LEFT JOIN promos p ON p.id = o.promo_id;
-- Orders with promo_id = NULL still appear (LEFT JOIN keeps them), p.name will be NULL

-- INNER JOIN silently drops those rows
SELECT o.id, p.name
FROM orders o
INNER JOIN promos p ON p.id = o.promo_id;
-- Orders with no promo are gone — may or may not be intended
```

**NULL in ORDER BY**
```sql
-- PostgreSQL: NULLs sort LAST in ASC, FIRST in DESC by default
SELECT name, score FROM players ORDER BY score DESC;
-- Players with NULL score appear first in DESC order

-- Control NULL position explicitly
SELECT name, score FROM players ORDER BY score DESC NULLS LAST;
SELECT name, score FROM players ORDER BY score ASC  NULLS FIRST;
```

**NULL in CASE expressions**
```sql
-- CASE with no ELSE returns NULL for unmatched rows
SELECT
    id,
    CASE status
        WHEN 'active'   THEN 'Active'
        WHEN 'inactive' THEN 'Inactive'
        -- no ELSE — returns NULL for any other status
    END AS status_label
FROM users;

-- Always add ELSE if you want a fallback
SELECT
    id,
    CASE status
        WHEN 'active' THEN 'Active'
        ELSE 'Other'    -- catches NULL status AND unknown values
    END AS status_label
FROM users;
```

**NULL with NOT IN — the silent empty result**
```sql
-- If the subquery returns ANY NULL, NOT IN returns no rows for any outer value
-- Because: 5 NOT IN (1, 2, NULL) → NOT (5=1 OR 5=2 OR 5=NULL) → NOT (FALSE OR FALSE OR NULL) → NOT NULL → NULL

SELECT id FROM users
WHERE id NOT IN (SELECT user_id FROM orders WHERE user_id IS NOT NULL);
-- The IS NOT NULL is essential — without it, any NULL in user_id empties the result

-- Safer pattern: use NOT EXISTS instead
SELECT u.id FROM users u
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);
```

---

## Real World Example

A CRM system tracks leads with optional values for phone, company, and deal size. A report needs to show all leads ranked by deal size, with NULLs treated as zero for ranking, and display a fallback label when fields are absent — while correctly flagging leads with no phone AND no email.

```sql
SELECT
    l.id,
    COALESCE(l.full_name, l.email, 'Unknown Contact')   AS display_name,
    COALESCE(l.company, '(No company)')                  AS company,
    COALESCE(l.deal_size, 0)                             AS deal_size_display,
    NULLIF(trim(l.phone), '')                            AS phone,

    -- Flag leads with no contact method at all
    CASE
        WHEN l.email IS NULL AND NULLIF(trim(l.phone), '') IS NULL
        THEN true
        ELSE false
    END AS no_contact_method,

    -- Rank by deal size — NULLs rank last
    RANK() OVER (
        ORDER BY COALESCE(l.deal_size, 0) DESC
    ) AS deal_rank

FROM leads l
WHERE l.status = 'open'
  AND l.deleted_at IS NULL          -- soft-delete check
ORDER BY COALESCE(l.deal_size, 0) DESC NULLS LAST;
```

*The key insight: every COALESCE and NULLIF here has a specific semantic job — defaulting for display, stripping empty strings, preventing NULL from poisoning sort order, and detecting the absence of both contact methods. Handling NULL correctly in this query requires applying four different NULL patterns in combination.*

---

## Common Misconceptions

**"An empty string and NULL are the same thing"**
They're completely different. `''` is a string with zero characters — it has a value, just a short one. NULL is the absence of a value. `'' = ''` is TRUE. `NULL = NULL` is NULL. `LENGTH('') = 0` is TRUE. `LENGTH(NULL)` is NULL. Many applications accidentally store both — use `NULLIF(trim(col), '')` to normalise empty strings to NULL on the way in or out.

**"NULL in a UNIQUE constraint allows only one NULL per column"**
Standard SQL says NULLs are distinct from each other for uniqueness — so multiple NULLs are allowed in a UNIQUE column. PostgreSQL follows this standard. SQL Server also follows it. MySQL traditionally allowed multiple NULLs in UNIQUE indexes too. PostgreSQL 15 added `UNIQUE NULLS NOT DISTINCT` to change this behaviour if you want at most one NULL.

```sql
-- Standard: multiple NULLs allowed in a UNIQUE column
CREATE TABLE contacts (email TEXT UNIQUE);
INSERT INTO contacts VALUES (NULL);  -- ok
INSERT INTO contacts VALUES (NULL);  -- also ok — NULLs are distinct from each other

-- PostgreSQL 15+: force NULL uniqueness
CREATE TABLE contacts (email TEXT UNIQUE NULLS NOT DISTINCT);
INSERT INTO contacts VALUES (NULL);  -- ok
INSERT INTO contacts VALUES (NULL);  -- ERROR: duplicate key
```

**"Filtering with WHERE col != 'value' excludes NULLs too"**
`WHERE col != 'active'` returns rows where col has a value other than 'active' — but NOT rows where col is NULL, because `NULL != 'active'` evaluates to NULL (not TRUE). To include NULLs in your filter: `WHERE col != 'active' OR col IS NULL`.

---

## Gotchas

- **`NULL = NULL` is always NULL** — use `IS NOT DISTINCT FROM` for NULL-safe equality checks. This is the most commonly forgotten NULL rule.

- **NOT IN with any NULL in the subquery returns no rows** — `WHERE id NOT IN (SELECT user_id FROM orders)` returns empty if any `user_id` is NULL. Always add `WHERE col IS NOT NULL` in the subquery, or rewrite using `NOT EXISTS`.

- **AVG silently changes denominator when NULLs are present** — if 30% of your rows have NULL for a column, `AVG(col)` averages only the 70% non-NULL rows. This may produce a misleading result if the NULLs should be treated as 0.

- **ORDER BY NULLS placement is database-specific** — PostgreSQL sorts NULLs last in ASC and first in DESC by default. MySQL and SQL Server differ. Always use `NULLS FIRST` or `NULLS LAST` explicitly when NULL position matters.

- **CASE without ELSE returns NULL for unmatched rows** — a CASE expression with conditions that don't cover all values silently produces NULLs. Always add an ELSE clause unless you explicitly want NULL for unmatched cases.

---

## Interview Angle

**What they're really testing:** Whether you understand three-valued logic and can write NULL-safe queries without introducing silent correctness bugs.

**Common question forms:**
- "Why does this NOT IN query return no results?"
- "What's the difference between NULL and empty string?"
- "How would you handle this JOIN where the column can be NULL?"

**The depth signal:** A junior knows `IS NULL` and `COALESCE` exist. A senior explains three-valued logic (TRUE/FALSE/NULL), knows the NOT IN + NULL trap by heart, uses `IS DISTINCT FROM` for NULL-safe comparison, and knows that AVG silently changes its denominator. They also know that PostgreSQL indexes NULLs in B-tree (useful for partial indexes on IS NULL queries), that `NULLIF` is the right tool for division-by-zero protection and empty-string normalisation, and that CASE without ELSE silently produces NULLs.

**Follow-up questions to expect:**
- "How would you write a query where NULL should equal NULL?"
- "Can you have multiple NULLs in a UNIQUE column?"

---

## Related Topics

- [[databases/sql/sql-basics.md]] — WHERE clause NULL behaviour affects every query
- [[databases/sql/sql-joins.md]] — outer joins produce NULLs; how you handle them determines correctness
- [[databases/sql/sql-aggregations.md]] — COUNT, AVG, and SUM all have specific NULL semantics
- [[databases/sql/sql-subqueries.md]] — NOT IN + NULL is one of SQL's most dangerous silent bugs
- [[databases/sql/sql-indexing.md]] — NULLs are indexed in PostgreSQL B-tree; partial indexes on IS NULL are efficient

---

## Source

https://www.postgresql.org/docs/current/functions-comparison.html

---
*Last updated: 2026-04-13*