# SQL Server JSON Support

> SQL Server's JSON support lets you store JSON text in columns and query, transform, and index it using built-in functions — without a separate document database.

---

## When To Use It
Use JSON in SQL Server when your schema has genuinely variable or sparse attributes that differ per row — product specifications, event payloads, configuration objects, API request/response logging. It's also useful for returning query results as JSON directly from T-SQL for REST APIs. Avoid it as a replacement for a properly normalized schema — if you're storing structured, consistent data as JSON because it's convenient, you're giving up type safety, indexability, and query clarity for no real benefit. JSON in SQL Server is a tool for handling variability, not a way to avoid schema design.

---

## Core Concept
SQL Server doesn't have a native JSON data type — JSON is stored as NVARCHAR(MAX). The engine provides functions to parse, query, and modify JSON text at query time. `JSON_VALUE` extracts a scalar value. `JSON_QUERY` extracts an object or array. `JSON_MODIFY` returns a modified copy of the JSON string. `OPENJSON` shreds a JSON array into rows. `FOR JSON` serializes query results into JSON. Because JSON is plain text, you can't index a JSON property directly — but you can create a computed column that extracts the value and index that computed column. This is the key pattern for making JSON property queries fast.

---

## The Code

**Store and validate JSON**
```sql
-- JSON is stored as NVARCHAR — add a check constraint to enforce valid JSON
CREATE TABLE events (
    id          INT IDENTITY PRIMARY KEY,
    event_type  VARCHAR(50) NOT NULL,
    payload     NVARCHAR(MAX) NOT NULL,
    created_at  DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT chk_payload_is_json CHECK (ISJSON(payload) = 1)
);

INSERT INTO events (event_type, payload) VALUES
(
    'order_placed',
    '{"order_id": 42, "customer_id": 7, "amount": 149.99, "items": ["widget","gadget"]}'
);
```

**JSON_VALUE — extract a scalar property**
```sql
-- Extract top-level scalar values
SELECT
    id,
    JSON_VALUE(payload, '$.order_id')       AS order_id,
    JSON_VALUE(payload, '$.customer_id')    AS customer_id,
    JSON_VALUE(payload, '$.amount')         AS amount
FROM events
WHERE event_type = 'order_placed';

-- Nested property access
-- payload: {"user": {"name": "Ahmed", "city": "Cairo"}}
SELECT JSON_VALUE(payload, '$.user.name')   AS user_name,
       JSON_VALUE(payload, '$.user.city')   AS city
FROM events;

-- Array element by index (zero-based)
-- payload: {"items": ["widget", "gadget", "doohickey"]}
SELECT JSON_VALUE(payload, '$.items[0]')    AS first_item
FROM events;
```

**JSON_QUERY — extract an object or array**
```sql
-- Returns the raw JSON fragment (object or array), not a scalar
SELECT
    id,
    JSON_QUERY(payload, '$.items')      AS items_array,  -- returns '["widget","gadget"]'
    JSON_VALUE(payload, '$.items[0]')   AS first_item     -- returns 'widget'
FROM events;

-- JSON_VALUE returns NULL for objects/arrays; JSON_QUERY returns NULL for scalars
-- Use the right function for the right type
```

**JSON_MODIFY — return a modified copy**
```sql
-- Update a scalar property (returns new JSON string — does not mutate in place)
UPDATE events
SET payload = JSON_MODIFY(payload, '$.amount', 199.99)
WHERE id = 1;

-- Add a new property
UPDATE events
SET payload = JSON_MODIFY(payload, '$.processed', CAST(1 AS BIT))
WHERE id = 1;

-- Remove a property (set to NULL with JSON_MODIFY)
UPDATE events
SET payload = JSON_MODIFY(payload, '$.temp_field', NULL)
WHERE id = 1;

-- Append to an array
UPDATE events
SET payload = JSON_MODIFY(
    payload,
    'append $.items',
    'new_item'
)
WHERE id = 1;
```

**OPENJSON — shred JSON into rows**
```sql
-- Parse a JSON array into a relational result set
DECLARE @json NVARCHAR(MAX) = '
[
    {"id": 1, "name": "Widget",  "price": 9.99},
    {"id": 2, "name": "Gadget",  "price": 24.99},
    {"id": 3, "name": "Doohickey","price": 4.99}
]';

-- Without schema — returns key, value, type columns
SELECT * FROM OPENJSON(@json);

-- With schema — maps JSON properties to typed columns
SELECT id, name, price
FROM OPENJSON(@json)
WITH (
    id      INT             '$.id',
    name    NVARCHAR(100)   '$.name',
    price   DECIMAL(10,2)   '$.price'
);
```

**OPENJSON to shred a column value**
```sql
-- Expand items array from each event into individual rows
SELECT
    e.id            AS event_id,
    items.value     AS item_name
FROM events e
CROSS APPLY OPENJSON(e.payload, '$.items') items
WHERE e.event_type = 'order_placed';
```

**FOR JSON — serialize query results as JSON**
```sql
-- Auto mode: infers structure from column names
SELECT id, event_type, created_at
FROM events
FOR JSON AUTO;

-- Path mode: explicit control over output structure
SELECT
    id          AS 'event.id',
    event_type  AS 'event.type',
    created_at  AS 'event.timestamp'
FROM events
FOR JSON PATH;

-- Wrap in a root element
SELECT id, event_type
FROM events
FOR JSON PATH, ROOT('events');

-- Include NULL values (omitted by default)
SELECT id, event_type, NULL AS optional_field
FROM events
FOR JSON PATH, INCLUDE_NULL_VALUES;
```

**Indexing JSON properties via computed columns**
```sql
-- Direct index on JSON_VALUE is not supported
-- Solution: computed column + index on the computed column

ALTER TABLE events
ADD customer_id_computed AS CAST(JSON_VALUE(payload, '$.customer_id') AS INT);

CREATE INDEX idx_events_customer_id
ON events (customer_id_computed)
WHERE customer_id_computed IS NOT NULL;  -- partial index — skip NULLs

-- Now this query uses the index
SELECT id, payload
FROM events
WHERE CAST(JSON_VALUE(payload, '$.customer_id') AS INT) = 7;
-- SQL Server matches the expression to the computed column and uses the index
```

**Validate and query nested JSON**
```sql
-- Check if a property exists (JSON_VALUE returns NULL if missing)
SELECT id
FROM events
WHERE JSON_VALUE(payload, '$.order_id') IS NOT NULL;

-- Filter on a JSON property value
SELECT id, JSON_VALUE(payload, '$.amount') AS amount
FROM events
WHERE JSON_VALUE(payload, '$.customer_id') = '7'
  AND CAST(JSON_VALUE(payload, '$.amount') AS DECIMAL(10,2)) > 100;
```

---

## Gotchas

- **JSON_VALUE always returns NVARCHAR — cast explicitly for numeric comparisons** — comparing `JSON_VALUE(payload, '$.amount') > 100` compares strings, not numbers. `'9'` sorts greater than `'100'` in string comparison. Always `CAST` or `CONVERT` JSON values to the correct type before using them in numeric or date comparisons.
- **JSON properties are case-sensitive in SQL Server** — `JSON_VALUE(payload, '$.OrderId')` and `JSON_VALUE(payload, '$.orderId')` return different results. This catches developers coming from case-insensitive SQL column names. Standardize on a casing convention and enforce it at insert time.
- **Filtering on JSON_VALUE without an index does a full table scan** — `WHERE JSON_VALUE(payload, '$.customer_id') = '7'` parses every JSON value in every row. On a large table this is catastrophically slow. Always create a computed column with an index for any JSON property you filter on frequently.
- **ISJSON does not validate schema — only syntax** — `ISJSON(payload) = 1` confirms the text is valid JSON but says nothing about whether the expected properties are present or correctly typed. A payload with `amount` as a string instead of a number passes `ISJSON` without issue. Application-layer validation or CHECK constraints on computed columns are needed for structural guarantees.
- **FOR JSON PATH silently omits NULL values by default** — if a column is NULL, it doesn't appear in the JSON output unless you add `INCLUDE_NULL_VALUES`. This surprises consumers who expect a key to always be present. Be explicit about null handling in your API contracts.

---

## Interview Angle
**What they're really testing:** Whether you understand the limitations of JSON in a relational database — specifically that it's NVARCHAR under the hood — and whether you know how to make JSON property queries fast.

**Common question form:** "How would you store and query semi-structured data in SQL Server?" or "How do you index a JSON property in SQL Server?"

**The depth signal:** A junior knows JSON_VALUE exists and can write basic extraction queries. A senior knows JSON is stored as NVARCHAR and that all JSON_VALUE results must be cast for typed comparisons, reaches immediately for computed columns + indexes when asked about performance on JSON properties, knows the difference between JSON_VALUE (scalar) and JSON_QUERY (object/array), and uses OPENJSON WITH schema for typed shredding rather than relying on the untyped key/value output. They also know that FOR JSON omits NULLs by default and flag the case-sensitivity behavior upfront.

---

## Related Topics
- [[databases/sql-indexing.md]] — computed column indexes are the only way to make JSON property filters fast
- [[databases/normalization.md]] — JSON columns are deliberate schema flexibility; understanding when to normalize vs when to use JSON is the real design decision
- [[databases/database-design-patterns.md]] — the EAV vs JSONB pattern comparison applies directly here; JSON columns are the SQL Server equivalent of PostgreSQL's JSONB
- [[databases/sql-query-optimization.md]] — unindexed JSON_VALUE calls in WHERE clauses are a common source of unexpectedly slow queries

---

## Source
https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server

---
*Last updated: 2026-03-24*