# SQL Indexing

> An index is a separate data structure the database maintains alongside a table to make specific queries faster — at the cost of storage space and slower writes.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Separate sorted structure mapping column values to row locations |
| **Use when** | Column appears in WHERE, JOIN ON, or ORDER BY on large tables |
| **Avoid when** | Write-heavy tables, low-selectivity columns, small tables |
| **Standard** | Implementation-defined (no SQL standard for index syntax) |
| **Default type** | B-tree (covers equality, range, ordering, NULLs) |
| **Other types** | GIN (arrays, JSONB, full-text), GiST (geometry, ranges), BRIN (append-only ordered), Hash (equality only) |

---

## When To Use It

Index columns that appear in WHERE clauses, JOIN conditions, and ORDER BY clauses on large tables. Without an index, every query against that column reads the entire table. Add indexes when query performance is provably slow and an EXPLAIN confirms the index would be used — not preemptively on every column. Avoid over-indexing: every index adds overhead to INSERT, UPDATE, and DELETE because the database must keep each index in sync with the table. Tables with very high write throughput and low read selectivity often perform better with fewer indexes. The test: does this index make a measurably selective query meaningfully faster, and is that worth the write overhead?

---

## Core Concept

Without an index, the database reads every row in the table to find matches — a sequential scan. An index is a sorted, separate structure (usually a B-tree) that maps column values to the physical location of matching rows. The query planner checks whether using the index is cheaper than scanning the whole table — for highly selective queries (returning a small fraction of rows), the index wins. For low-selectivity queries (returning most rows), the planner skips the index and scans anyway, because random I/O to follow index pointers costs more than sequential I/O to read the table straight through.

Indexes speed up reads but slow down writes because every write must update every index on the table. This is the core tradeoff, and it's non-negotiable — there is no free index.

---

## Version History

| PostgreSQL Version | What changed |
|---|---|
| Pre-8.0 | B-tree, Hash, GiST, R-tree indexes |
| 8.1 | GIN index added (arrays, full-text search) |
| 9.2 | Index-only scans (covering indexes via INCLUDE-like behaviour) |
| 9.5 | BRIN (Block Range Index) added |
| 11 | `INCLUDE` columns on B-tree indexes (true covering indexes) |
| 12 | `REINDEX CONCURRENTLY` added |
| 14 | Deduplification in B-tree (reduces size for repeated values) |
| 15 | Incremental sort improvements; better partial index use |

---

## Performance

| Operation | With index | Without index | Notes |
|---|---|---|---|
| Equality lookup | O(log n) | O(n) | B-tree seek |
| Range scan | O(log n + k) | O(n) | Seek + sequential leaf read |
| Index-only scan | O(log n) | O(n) | No heap access if all cols in index |
| INSERT | Slower by # of indexes | Baseline | Each index must be updated |
| UPDATE (indexed col) | Slower by # of indexes | Baseline | Old entry removed, new inserted |
| Bulk load | Very slow with indexes | Fast | Drop indexes, load, rebuild |

**Allocation behaviour:** B-tree indexes store data in fixed-size pages (8KB). Each page holds many entries. Index bloat occurs when entries are deleted but pages aren't reclaimed — use `VACUUM` (removes dead entries) and `REINDEX` (full rebuild) to address bloat.

**Benchmark notes:** The planner uses cost estimates to decide between an index scan and a sequential scan. For tables under ~10,000 rows, sequential scans often win even with an index — the overhead of B-tree traversal exceeds the benefit. Indexes pay off meaningfully when the query is highly selective (returning < ~5% of rows) on tables with tens of thousands of rows or more.

---

## The Code

**Create and drop a basic index**
```sql
-- B-tree index (default) on a single column
CREATE INDEX idx_orders_user_id ON orders (user_id);

-- Drop it
DROP INDEX idx_orders_user_id;

-- Safe for production: doesn't block reads or writes during build
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders (user_id);
```

**Unique index — enforces uniqueness and speeds lookups**
```sql
CREATE UNIQUE INDEX idx_users_email ON users (email);
-- Duplicate email inserts now fail with a constraint violation
-- PRIMARY KEY and UNIQUE constraints create unique B-tree indexes automatically
```

**Composite index — multiple columns, order matters**
```sql
CREATE INDEX idx_orders_user_status ON orders (user_id, status);

-- This index supports:
SELECT * FROM orders WHERE user_id = 42;                         -- yes (leftmost prefix)
SELECT * FROM orders WHERE user_id = 42 AND status = 'completed'; -- yes (full match)
SELECT * FROM orders WHERE status = 'completed';                  -- no (left prefix missing)
-- Leftmost prefix rule: the index is only usable from the leftmost column forward
```

**Partial index — index only a subset of rows**
```sql
-- Index only unprocessed jobs — smaller, faster, laser-focused
CREATE INDEX idx_jobs_unprocessed ON jobs (created_at)
WHERE status = 'pending';

-- Used only when the query includes the partial index predicate:
SELECT * FROM jobs WHERE status = 'pending' ORDER BY created_at;
-- Dramatically smaller than a full index on created_at — fewer pages, faster scans
```

**Expression index — index on a computed value**
```sql
-- WHERE lower(email) = 'x' cannot use a plain index on email
CREATE INDEX idx_users_lower_email ON users (lower(email));

-- Now this uses the index:
SELECT * FROM users WHERE lower(email) = 'ahmed@example.com';
```

**Covering index — include extra columns to avoid heap access**
```sql
-- INCLUDE adds columns to index leaf pages without making them part of the key
-- The query below can be answered entirely from the index — no table access needed
CREATE INDEX idx_orders_user_covering ON orders (user_id)
INCLUDE (total_amount, status, created_at);

SELECT total_amount, status, created_at
FROM orders
WHERE user_id = 42;
-- Index Scan → Index Only Scan: reads only index pages, skips the heap
```

**Verify an index is being used**
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE user_id = 42 AND status = 'completed';

-- Signals:
-- Index Scan using idx_orders_user_status    → index used
-- Seq Scan on orders                         → index not used
-- Buffers: shared hit=N                      → N pages from cache
-- Buffers: shared read=N                     → N pages from disk (cache miss)
```

**Index types beyond B-tree**
```sql
-- GIN: for arrays, JSONB, and full-text search
CREATE INDEX idx_products_tags   ON products USING GIN (tags);
CREATE INDEX idx_events_metadata ON events   USING GIN (metadata);    -- JSONB

-- GiST: for geometric data, ranges, fuzzy text (trigram via pg_trgm)
CREATE INDEX idx_events_range    ON events   USING GIST (date_range);
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_users_name_trgm ON users    USING GIST (name gist_trgm_ops);  -- LIKE '%...'

-- BRIN: for very large append-only tables where data is physically ordered
-- Tiny index (~200× smaller than B-tree) — only works when column order ≈ physical order
CREATE INDEX idx_logs_created    ON logs     USING BRIN (created_at);

-- Hash: for equality-only lookups (no range, no sort benefit)
CREATE INDEX idx_sessions_token  ON sessions USING HASH (token);
```

**Check index bloat and size**
```sql
-- Index sizes
SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE tablename = 'orders'
ORDER BY pg_relation_size(indexname::regclass) DESC;

-- Index usage stats — find unused indexes
SELECT
    indexname,
    idx_scan,       -- times index was used by queries
    idx_tup_read,   -- rows read via index
    idx_tup_fetch   -- rows fetched from heap via index
FROM pg_stat_user_indexes
WHERE relname = 'orders'
ORDER BY idx_scan ASC;  -- low idx_scan = possibly unused
```

**Rebuild a bloated index**
```sql
-- Rebuild without blocking reads/writes (PostgreSQL 12+)
REINDEX INDEX CONCURRENTLY idx_orders_user_id;

-- Rebuild all indexes on a table concurrently
REINDEX TABLE CONCURRENTLY orders;
```

---

## Real World Example

A logistics platform has a shipments table (80M rows). A support query — "show all shipments for carrier X with status Y, ordered by scheduled delivery" — started taking 45 seconds. The table had individual indexes on carrier_id and status separately, but the planner chose a sequential scan because neither alone was selective enough.

```sql
-- Step 1: diagnose
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, tracking_number, scheduled_delivery, actual_delivery
FROM shipments
WHERE carrier_id = 12
  AND status     = 'in_transit'
ORDER BY scheduled_delivery DESC
LIMIT 50;
-- Seq Scan on shipments (cost=0.00..2,450,000 rows=8,200 width=48)
-- actual time=0.020..38,241 ms  ← 38 seconds

-- Step 2: fix — composite index matching the query's filter + sort pattern
CREATE INDEX CONCURRENTLY idx_shipments_carrier_status_delivery
ON shipments (carrier_id, status, scheduled_delivery DESC);

-- Step 3: verify
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, tracking_number, scheduled_delivery, actual_delivery
FROM shipments
WHERE carrier_id = 12
  AND status     = 'in_transit'
ORDER BY scheduled_delivery DESC
LIMIT 50;
-- Index Scan using idx_shipments_carrier_status_delivery
-- actual time=0.128..0.412 ms  ← under 1ms

-- Step 4: make it a covering index to eliminate heap access
CREATE INDEX CONCURRENTLY idx_shipments_carrier_status_delivery_covering
ON shipments (carrier_id, status, scheduled_delivery DESC)
INCLUDE (id, tracking_number, actual_delivery);
-- Index Only Scan — never touches the heap
```

*The key insight: column order in the composite index was chosen to match query execution — equality filters first (carrier_id, status), range/sort column last (scheduled_delivery). Including the SELECT columns in INCLUDE converts a regular index scan into an index-only scan, eliminating all heap I/O.*

---

## Common Misconceptions

**"An index on a column means every query filtering that column uses the index"**
The planner decides based on cost estimates, not just index existence. A low-selectivity column (like a boolean with 90% true), stale statistics, or a function wrapping the column all cause the planner to prefer a sequential scan. Read the EXPLAIN output — it tells you what the planner actually chose and why.

**"More indexes is always better"**
Every index on a table adds overhead to every INSERT, UPDATE, and DELETE. On a table receiving thousands of writes per second, ten indexes can make write throughput collapse. Check `pg_stat_user_indexes` for `idx_scan = 0` — those are candidates for removal. An unused index that costs write overhead provides no benefit.

```sql
-- Find indexes that haven't been used since last stats reset
SELECT indexname, idx_scan
FROM pg_stat_user_indexes
WHERE relname = 'orders'
  AND idx_scan = 0
ORDER BY indexname;
-- Drop unused indexes after confirming they're truly not needed
```

**"Composite indexes work for any combination of their columns"**
Only if the query uses a left-prefix of the index columns. An index on `(a, b, c)` supports queries filtering on `a`, `a+b`, or `a+b+c` — but not `b` alone, `c` alone, or `b+c`. Column order is fundamental to composite index design.

---

## Gotchas

- **`CREATE INDEX` without CONCURRENTLY locks writes for the entire build** — on a busy production table, this causes a write outage. Always use `CREATE INDEX CONCURRENTLY` in production — it takes longer but doesn't block.

- **Functions on indexed columns prevent index use** — `WHERE lower(email) = 'x'` cannot use a plain index on `email`. The function wraps the column and breaks the B-tree lookup. Fix with an expression index on `lower(email)`.

- **Partial indexes are invisible to queries without the matching predicate** — a partial index `WHERE status = 'pending'` is not used by `WHERE status = 'pending' OR status = 'failed'`. The predicate must be a subset of the index predicate.

- **Index bloat accumulates silently** — after heavy UPDATE/DELETE traffic, B-tree index pages fill with dead entries. `VACUUM` removes them but doesn't reclaim pages (they stay allocated). `REINDEX CONCURRENTLY` rebuilds the index compactly. On high-update tables, monitor index size and bloat.

- **The planner ignores indexes on small tables** — under ~1,000 rows, a sequential scan is almost always cheaper than a B-tree lookup. Adding an index to a small table helps nothing and adds write overhead.

---

## Interview Angle

**What they're really testing:** Whether you understand how the query planner decides to use an index — not just that indexes exist and make things faster.

**Common question forms:**
- "Why is this query slow even though there's an index on that column?"
- "How would you index a table for this query pattern?"
- "What's the difference between a covering index and a regular index?"

**The depth signal:** A junior knows indexes speed up reads and that you put them on WHERE columns. A senior knows the leftmost prefix rule for composite indexes, explains why low-selectivity columns make poor candidates, reaches for partial and expression indexes when appropriate, and knows that `CREATE INDEX` without CONCURRENTLY causes a write-blocking lock in production. They read EXPLAIN output fluently — distinguishing Index Scan, Bitmap Index Scan, Index Only Scan, and Seq Scan — and understand that the planner chooses based on cost estimates, not on whether an index exists. Knowing when NOT to add an index (write-heavy tables, low selectivity, small tables) and how to find and remove unused indexes is a strong senior signal.

**Follow-up questions to expect:**
- "This index exists but the planner isn't using it — why?"
- "How would you handle an index on a column that stores lowercase email vs mixed case?"

---

## Related Topics

- [[databases/sql/sql-execution-plans.md]] — EXPLAIN ANALYZE is how you verify index usage and diagnose slow queries
- [[databases/sql/sql-query-optimization.md]] — most optimizations involve adding, removing, or restructuring indexes
- [[databases/sql/sql-statistics.md]] — stale statistics cause the planner to ignore valid indexes
- [[databases/sql/sql-locking-blocking.md]] — CREATE INDEX without CONCURRENTLY takes an AccessShareLock that blocks writes

---

## Source

https://www.postgresql.org/docs/current/indexes.html

---
*Last updated: 2026-04-13*