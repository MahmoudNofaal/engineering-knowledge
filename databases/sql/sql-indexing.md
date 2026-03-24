# SQL Indexing

> An index is a separate data structure the database maintains alongside a table to make specific queries faster — at the cost of storage and slower writes.

---

## When To Use It
Index columns that appear in WHERE clauses, JOIN conditions, and ORDER BY clauses on large tables. Without an index, every query against that column reads the entire table. Add indexes when query performance is provably slow and an index would be used — not preemptively on every column. Avoid over-indexing: every index adds overhead to INSERT, UPDATE, and DELETE because the database must keep each index in sync. Tables with very high write throughput and low read selectivity often perform better with fewer indexes.

---

## Core Concept
Without an index, the database reads every row in the table to find matches — a sequential scan. An index is a sorted, separate structure (usually a B-tree) that maps column values to the physical location of matching rows. The planner checks whether using the index is cheaper than scanning the whole table — for highly selective queries (returning a small fraction of rows), the index wins. For low-selectivity queries (returning most rows), the planner skips the index and scans anyway. Indexes speed up reads but slow down writes because every write must update every index on the table. This is the core tradeoff.

---

## The Code

**Create and drop a basic index**
```sql
-- B-tree index (default) on a single column
CREATE INDEX idx_orders_user_id ON orders (user_id);

-- Drop it
DROP INDEX idx_orders_user_id;

-- Create without blocking reads/writes (safe for production)
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders (user_id);
```

**Unique index — enforces uniqueness and speeds lookups**
```sql
CREATE UNIQUE INDEX idx_users_email ON users (email);
-- Duplicate inserts on email now raise a constraint violation
-- PRIMARY KEY constraints create a unique index automatically
```

**Composite index — multiple columns in one index**
```sql
-- Index on (user_id, status) — most selective column first
CREATE INDEX idx_orders_user_status ON orders (user_id, status);

-- This index is used for:
SELECT * FROM orders WHERE user_id = 42;                      -- yes, left-prefix match
SELECT * FROM orders WHERE user_id = 42 AND status = 'completed'; -- yes, full match
SELECT * FROM orders WHERE status = 'completed';              -- no, left prefix skipped
```

**Partial index — index only a subset of rows**
```sql
-- Only index active users — smaller, faster, covers the common query pattern
CREATE INDEX idx_users_active_email ON users (email)
WHERE is_active = true;

-- This index is used when:
SELECT * FROM users WHERE email = 'a@example.com' AND is_active = true;
-- Not used when is_active is not filtered or is false
```

**Expression index — index on a computed value**
```sql
-- Queries filtering on lower(email) can't use a plain email index
CREATE INDEX idx_users_lower_email ON users (lower(email));

-- Now this uses the index:
SELECT * FROM users WHERE lower(email) = 'ahmed@example.com';
```

**Covering index — include extra columns to avoid table lookup**
```sql
-- INCLUDE adds columns to the index leaf without making them part of the key
-- The query below can be answered entirely from the index — no table access
CREATE INDEX idx_orders_user_covering ON orders (user_id)
INCLUDE (total_amount, status, created_at);

SELECT total_amount, status, created_at
FROM orders
WHERE user_id = 42;
```

**Check whether an index is being used**
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE user_id = 42 AND status = 'completed';

-- Look for:
-- Index Scan using idx_orders_user_status   → index used
-- Seq Scan on orders                         → index not used
-- Buffers: shared hit=N                      → N pages read from cache
```

**Index types beyond B-tree**
```sql
-- GIN index — for array, JSONB, and full-text search columns
CREATE INDEX idx_products_tags ON products USING GIN (tags);

-- GiST index — for geometric data, ranges, and fuzzy text search
CREATE INDEX idx_events_range ON events USING GIST (date_range);

-- BRIN index — for naturally ordered columns (timestamps, sequential IDs)
-- Very small, low overhead, but only useful when physical order matches query order
CREATE INDEX idx_logs_created ON logs USING BRIN (created_at);

-- Hash index — for equality lookups only (no range, no sort)
CREATE INDEX idx_sessions_token ON sessions USING HASH (token);
```

---

## Gotchas

- **The planner ignores your index if selectivity is low** — an index on a boolean column like `is_active` with 95% true rows gives the planner no reason to use it for `WHERE is_active = true`. It's cheaper to scan the table. Partial indexes solve this — index only the minority case (`WHERE is_active = false`) where selectivity is high.
- **Column order in composite indexes is not arbitrary** — a composite index on `(a, b)` supports queries filtering on `a` alone or `a AND b`, but not `b` alone. The leftmost prefix rule is absolute. Put the most selective column first, and the column used in range conditions last.
- **Functions on indexed columns suppress index use** — `WHERE lower(email) = 'x'` cannot use a plain index on `email`. The function wraps the column and the planner can't map the index to the result. Fix with an expression index on `lower(email)`.
- **`CREATE INDEX` without CONCURRENTLY locks the table** — a plain `CREATE INDEX` takes an `AccessShareLock` that blocks writes for the duration of the build. On a busy production table this causes a write outage. Always use `CREATE INDEX CONCURRENTLY` in production — it takes longer but doesn't block.
- **Indexes are not free on write-heavy tables** — every INSERT, UPDATE, and DELETE must update every index on the table. A table with ten indexes pays ten index-write costs per row mutation. Bulk loads are often faster with indexes dropped first and rebuilt after.

---

## Interview Angle
**What they're really testing:** Whether you understand how the query planner decides to use an index — not just that indexes exist and make things faster.

**Common question form:** "Why is this query slow even though there's an index on that column?" or "How would you index a table for this query pattern?"

**The depth signal:** A junior knows indexes speed up reads and that you put them on WHERE columns. A senior knows the leftmost prefix rule for composite indexes, explains why low-selectivity columns make poor index candidates, reaches for partial indexes and expression indexes when appropriate, and knows that `CREATE INDEX` without CONCURRENTLY causes a write-blocking lock in production. They read EXPLAIN output fluently — distinguishing Index Scan, Bitmap Index Scan, and Seq Scan — and understand that the planner chooses based on cost estimates, not on whether an index exists. Knowing when NOT to add an index (write-heavy tables, low selectivity, small tables) is a strong senior signal.

---

## Related Topics
- [[databases/query-optimization.md]] — EXPLAIN ANALYZE is how you verify index usage and diagnose slow queries
- [[databases/sql-transactions.md]] — FOR UPDATE acquires row locks; index design determines how many rows get locked
- [[databases/sql-views.md]] — materialized views can be indexed; regular views cannot
- [[databases/sql-joins.md]] — JOIN columns are the most commonly missed index opportunity after WHERE columns

---

## Source
https://www.postgresql.org/docs/current/indexes.html

---
*Last updated: 2026-03-24*