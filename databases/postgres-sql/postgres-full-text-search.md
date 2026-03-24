# PostgreSQL Full-Text Search

> A built-in Postgres feature that lets you search natural language text efficiently — ranking results by relevance, handling stemming, and ignoring stop words — without a separate search engine.

---

## When To Use It

Use Postgres FTS when you need keyword search over text columns and you're already on Postgres — blog posts, product descriptions, support tickets, documentation. It handles stemming, stop words, and relevance ranking out of the box. Don't use it when you need advanced search features like fuzzy matching, typo tolerance, faceted search, or sub-100ms search across millions of rows — that's when Elasticsearch or Typesense earns its keep.

---

## Core Concept

Postgres FTS works in two steps: convert text into a `tsvector` (a sorted list of normalized lexemes with position info), then match it against a `tsquery` (a parsed search expression). "Running" and "runs" both become the lexeme "run" — that's stemming. Common words like "the" and "is" are dropped — those are stop words. You store the `tsvector` in a generated column and put a GIN index on it. Queries then hit the index instead of scanning raw text.

---

## The Code

**Basic conversion — understanding tsvector and tsquery**
```sql
-- tsvector: normalized lexemes with positions
SELECT to_tsvector('english', 'The quick brown foxes are jumping');
-- 'brown':3 'fox':4 'jump':6 'quick':2

-- tsquery: search expression
SELECT to_tsquery('english', 'jumping & fox');
-- 'jump' & 'fox'

-- Match check
SELECT to_tsvector('english', 'The quick brown foxes are jumping')
    @@ to_tsquery('english', 'jumping & fox');
-- true
```

**Table setup with a generated tsvector column**
```sql
CREATE TABLE articles (
    id          SERIAL PRIMARY KEY,
    title       TEXT NOT NULL,
    body        TEXT NOT NULL,
    search_vec  TSVECTOR GENERATED ALWAYS AS (
                    to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
                ) STORED
);

-- GIN index on the generated column
CREATE INDEX idx_articles_search ON articles USING GIN (search_vec);
```

**Querying with ranking**
```sql
-- Basic match
SELECT title
FROM articles
WHERE search_vec @@ to_tsquery('english', 'postgres & index');

-- With relevance ranking (ts_rank)
SELECT title,
       ts_rank(search_vec, query) AS rank
FROM articles,
     to_tsquery('english', 'postgres & index') query
WHERE search_vec @@ query
ORDER BY rank DESC
LIMIT 10;
```

**Highlighting matched terms**
```sql
SELECT title,
       ts_headline('english', body, to_tsquery('english', 'postgres'),
           'MaxWords=20, MinWords=10, StartSel=<b>, StopSel=</b>'
       ) AS snippet
FROM articles
WHERE search_vec @@ to_tsquery('english', 'postgres');
```

**Phrase search and prefix matching**
```sql
-- Phrase search (words must appear adjacent, in order)
SELECT title FROM articles
WHERE search_vec @@ phraseto_tsquery('english', 'full text search');

-- Prefix match — useful for autocomplete
SELECT title FROM articles
WHERE search_vec @@ to_tsquery('english', 'postgr:*');
```

**Weighted search — title matches rank higher than body**
```sql
-- setweight: A > B > C > D
ALTER TABLE articles ADD COLUMN search_vec_weighted TSVECTOR
    GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(body,  '')), 'B')
    ) STORED;

CREATE INDEX idx_articles_weighted ON articles USING GIN (search_vec_weighted);

SELECT title,
       ts_rank(search_vec_weighted, query) AS rank
FROM articles,
     to_tsquery('english', 'postgres') query
WHERE search_vec_weighted @@ query
ORDER BY rank DESC;
```

---

## Gotchas

- **`to_tsquery` throws on invalid input.** If users type raw search terms, use `websearch_to_tsquery` instead — it tolerates natural language like `"postgres index" -slow` without erroring out.
- **The GIN index is on the `tsvector`, not the raw text column.** `WHERE body ILIKE '%postgres%'` ignores the index entirely. You must use the `@@` operator against the indexed `tsvector` column.
- **Stemming is language-specific.** `to_tsvector('english', ...)` and `to_tsvector('simple', ...)` produce different lexemes. If you index with `'english'` but query with `'simple'`, matches break silently.
- **`ts_headline` is slow — it re-parses raw text at query time.** Never call it on thousands of rows. Apply it only after you've already filtered and limited results.
- **Generated columns can't reference other generated columns.** You can't base `search_vec_weighted` on a separate `search_vec` column — you have to repeat the `to_tsvector` expression.

---

## Interview Angle

**What they're really testing:** Whether you understand how search indexing works and can reason about when to use a purpose-built search engine vs. staying in the DB.

**Common question form:** *"How would you implement search in a Postgres-backed app?"* or *"What's the difference between `ILIKE` and full-text search?"*

**The depth signal:** A junior reaches for `ILIKE '%term%'` and calls it search. A senior explains that `ILIKE` forces a full sequential scan (no index), while FTS uses a GIN index on pre-computed lexemes, handles stemming and stop words, and returns ranked results. They also know the tradeoff cutoff: Postgres FTS is solid up to a few million rows with moderate query load — beyond that, or when you need typo tolerance and faceting, you move to a dedicated engine like Elasticsearch or Typesense and sync via triggers or CDC.

---

## Related Topics

- [[databases/postgres-jsonb.md]] — Both use GIN indexes; understanding GIN in JSONB context carries over directly.
- [[databases/indexing-strategies.md]] — GIN vs GiST for tsvector; GiST is smaller but slower, GIN is faster but larger.
- [[databases/postgres-vs-sqlserver.md]] — SQL Server has a Full-Text Search feature too, but it requires a separate FTS catalog and service; Postgres FTS is fully integrated.

---

## Source

[PostgreSQL Full-Text Search documentation](https://www.postgresql.org/docs/current/textsearch.html)

---
*Last updated: 2026-03-24*