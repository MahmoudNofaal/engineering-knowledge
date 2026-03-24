# Indexing Strategy

> An index is a separate data structure the database maintains to make lookups faster — at the cost of slower writes and extra storage.

---

## When To Use It

Use indexes on columns that appear frequently in WHERE clauses, JOIN conditions, or ORDER BY clauses. Don't index every column — each index adds overhead to every INSERT, UPDATE, and DELETE. The problem indexes solve is full table scans: without them, the database reads every row to find matches. At small scale this is invisible; at millions of rows it becomes the bottleneck.

---

## Core Concept

Without an index, finding a row means scanning the whole table. An index is like a sorted copy of one or more columns, stored as a B-tree (for range queries) or a hash (for exact lookups), with pointers back to the actual row. The database uses it to jump directly to the right rows instead of reading everything. The trade-off is real: indexes consume disk space, and every write must also update all relevant indexes. A table with 10 indexes on it writes data 11 times per INSERT. Query planners use statistics to decide whether an index is even worth using — sometimes a full scan is cheaper than an index lookup on a low-cardinality column.

---

## The Code

### SQL — Basic single-column index
```sql
-- Without this, filtering by email does a full table scan
CREATE INDEX idx_users_email ON users(email);

-- The query below now uses the index
SELECT id, name FROM users WHERE email = 'ahmed@example.com';
```

### SQL — Composite index (column order matters)
```sql
-- Covers queries that filter by (status), or (status + created_at)
-- Does NOT efficiently cover queries that filter by created_at alone
CREATE INDEX idx_orders_status_created ON orders(status, created_at);

-- Uses the index
SELECT * FROM orders WHERE status = 'pending' ORDER BY created_at DESC;

-- Does NOT use the index efficiently — leading column is missing
SELECT * FROM orders WHERE created_at > '2026-01-01';
```

### SQL — Partial index (index a subset of rows)
```sql
-- Only indexes unprocessed jobs — keeps the index small and fast
CREATE INDEX idx_jobs_unprocessed ON jobs(created_at)
WHERE processed = false;
```

### SQL — Check if a query uses an index
```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE status = 'pending' AND created_at > '2026-01-01';
-- Look for "Index Scan" vs "Seq Scan" in the output
```

---

## Gotchas

- **Leading column rule for composite indexes** — a composite index on `(a, b, c)` only helps queries that filter on `a`, or `a + b`, or `a + b + c`. A filter on just `b` or `c` won't use it.
- **Low-cardinality columns are often not worth indexing** — a boolean `is_active` column with 95% of rows being `true` means the index points to almost every row; the planner may ignore it and scan anyway.
- **Indexes don't help if the column is wrapped in a function** — `WHERE LOWER(email) = 'x'` won't use an index on `email`. You need a functional index: `CREATE INDEX ON users(LOWER(email))`.
- **Unused indexes are pure overhead** — query planners track index usage in `pg_stat_user_indexes` (Postgres). Indexes with zero scans are just slowing down writes.
- **Index bloat after heavy updates/deletes** — B-tree indexes don't auto-shrink. A table with heavy churn needs periodic `REINDEX` or `VACUUM` to reclaim space and maintain performance.

---

## Interview Angle

**What they're really testing:** Whether you understand how databases physically execute queries, not just that "indexes make things faster."

**Common question form:** "This query is slow — how would you fix it?" or "What indexes would you put on this schema?"

**The depth signal:** A junior says "add an index on the WHERE column." A senior talks about cardinality, composite index column ordering, the cost of index maintenance on write-heavy tables, and asks to see the query plan before recommending anything. A senior also knows when NOT to add an index — and can explain why a query planner might ignore one.

---

## Related Topics

- [[system-design/sql-vs-nosql.md]] — Index structures differ between SQL and NoSQL; understanding the storage engine matters for both.
- [[system-design/denormalization.md]] — Denormalization and indexing are often used together to optimize read performance.
- [[databases/acid-vs-base.md]] — Index maintenance is part of what makes ACID writes more expensive.

---

## Source

https://use-the-index-luke.com

---

*Last updated: 2026-03-24*