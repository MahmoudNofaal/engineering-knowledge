# PostgreSQL JSONB

> A binary-stored JSON column type in Postgres that lets you query, index, and manipulate JSON data as if it were a first-class relational type.

---

## When To Use It

Use JSONB when part of your data is genuinely schema-flexible — user preferences, event payloads, product attributes that vary by category. Don't use it as a lazy alternative to proper schema design — if the data is structured and consistent, put it in columns. JSONB shines at the boundary between relational and document data, not as a replacement for either.

---

## Core Concept

Postgres stores JSONB in a decomposed binary format, not as raw text. That means it parses the JSON once on insert, discards duplicate keys, and doesn't preserve key order or whitespace. The payoff: you can index into it, query specific keys efficiently, and use operators that work like SQL expressions. Regular `JSON` type just stores the raw string and re-parses on every read — JSONB is almost always what you want in production.

---

## The Code

**Basic column and insert**
```sql
CREATE TABLE products (
    id      SERIAL PRIMARY KEY,
    name    TEXT NOT NULL,
    attrs   JSONB
);

INSERT INTO products (name, attrs) VALUES
('Laptop', '{"brand": "Dell", "ram_gb": 16, "tags": ["portable", "work"]}'),
('Phone',  '{"brand": "Apple", "ram_gb": 6, "tags": ["mobile"]}');
```

**Querying — key access operators**
```sql
-- -> returns JSONB, ->> returns text
SELECT attrs -> 'brand'   AS brand_json,
       attrs ->> 'brand'  AS brand_text
FROM products;

SELECT name FROM products
WHERE attrs ->> 'brand' = 'Dell';

SELECT attrs #>> '{specs, cpu}' FROM products;
```

**Indexing — the main performance lever**
```sql
-- GIN index: covers @>, ?, ?|, ?& operators
CREATE INDEX idx_products_attrs ON products USING GIN (attrs);

-- Btree on a specific key
CREATE INDEX idx_products_brand ON products ((attrs ->> 'brand'));
```

**Containment operator `@>` — most useful with GIN**
```sql
SELECT name FROM products
WHERE attrs @> '{"brand": "Apple"}';

SELECT name FROM products
WHERE attrs ? 'ram_gb';

SELECT name FROM products
WHERE attrs ?| ARRAY['ram_gb', 'color'];
```

**Updating a specific key without replacing the whole object**
```sql
UPDATE products
SET attrs = jsonb_set(attrs, '{ram_gb}', '32', false)
WHERE name = 'Laptop';

UPDATE products
SET attrs = attrs - 'tags'
WHERE name = 'Phone';
```

**Expanding JSONB arrays into rows**
```sql
SELECT name, jsonb_array_elements_text(attrs -> 'tags') AS tag
FROM products;
```

---

## Gotchas

- **`->` vs `->>` confusion causes silent type mismatches.** `->>` returns `text`, so `WHERE attrs ->> 'ram_gb' > 8` compares strings, not numbers. Cast explicitly: `(attrs ->> 'ram_gb')::int > 8`.
- **GIN index doesn't help equality on a single key path.** `WHERE attrs ->> 'brand' = 'Dell'` won't use a GIN index — it needs a separate expression index on `(attrs ->> 'brand')`. GIN is for containment (`@>`) and key existence (`?`).
- **JSONB silently drops duplicate keys on insert.** If you insert `{"a": 1, "a": 2}`, you get `{"a": 2}` stored. No error, no warning.
- **`jsonb_set` on a missing path does nothing unless you pass `true` as the 4th argument.** Default is `false` — it won't create intermediate keys.
- **JSONB indexes don't compress well.** A GIN index on a wide JSONB column can be 2–3x the size of the column itself. Monitor index bloat on write-heavy tables.

---

## Interview Angle

**What they're really testing:** Whether you understand when to break schema normalization and how Postgres indexes work beyond basic B-tree.

**Common question form:** *"How would you store and query semi-structured data in Postgres?"* or *"When would you use JSONB over a separate table?"*

**The depth signal:** A junior says "use JSONB for flexible data." A senior explains the `->` vs `->>` type difference, knows that GIN indexes cover containment queries but not equality on a single extracted field (which needs an expression index), and can articulate when JSONB is the wrong call — specifically, when you're querying the same keys consistently, you should just add columns, because JSONB queries can't benefit from statistics-based query planning the same way typed columns can.

---

## Related Topics

- [[databases/postgres-vs-sqlserver.md]] — JSONB is one of the sharpest differentiators between the two; SQL Server has no native equivalent.
- [[databases/indexing-strategies.md]] — GIN vs GiST vs B-tree index selection is central to JSONB performance.
- [[databases/mvcc-and-isolation-levels.md]] — JSONB updates follow the same MVCC rules as any row update; partial key updates still write a new row version.

---

## Source

[PostgreSQL JSONB documentation](https://www.postgresql.org/docs/current/datatype-json.html)

---
*Last updated: 2026-03-24*