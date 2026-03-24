# Denormalization

> Intentionally introducing redundancy into a database schema to make reads faster by reducing or eliminating joins.

---

## When To Use It

Use denormalization when query performance is the bottleneck and you've already optimized indexes and query structure. It's most justified in read-heavy systems where the same expensive join runs thousands of times per second. Don't denormalize prematurely — it trades write complexity and data consistency risk for read speed. Normalized schemas are easier to reason about, easier to change, and less likely to have silent data inconsistencies.

---

## Core Concept

Normalization removes redundancy by splitting data across tables and linking them with foreign keys. That's clean and correct, but it means every read must reassemble the data via joins. Denormalization puts some of that data back together — you store a copy of frequently-read fields directly on the row that needs them, so reads become single-table lookups. The cost is that now the same piece of information lives in multiple places, and you're responsible for keeping it in sync. The moment you update one copy and forget the other, you have a consistency bug that's silent and hard to find.

---

## The Code

### Normalized schema — join required on every read
```sql
-- To show a comment with the author's name, you always need a join
SELECT c.body, u.name
FROM comments c
INNER JOIN users u ON u.id = c.user_id
WHERE c.post_id = 101;
```

### Denormalized schema — author name stored directly on the comment
```sql
-- author_name is redundant — it also lives in the users table
-- But now this query needs no join
ALTER TABLE comments ADD COLUMN author_name VARCHAR(100);

SELECT body, author_name
FROM comments
WHERE post_id = 101;
```

### Keeping denormalized data in sync (application-level)
```sql
-- When a user changes their name, you must update all their comments too
-- This is the maintenance burden denormalization creates
UPDATE comments SET author_name = 'Ahmed Kamal' WHERE user_id = 42;
UPDATE posts   SET author_name = 'Ahmed Kamal' WHERE user_id = 42;
```

### Denormalization via materialized view (database-managed)
```sql
-- Let the DB maintain the denormalized copy instead of doing it manually
CREATE MATERIALIZED VIEW post_summary AS
SELECT p.id, p.title, u.name AS author_name, COUNT(c.id) AS comment_count
FROM posts p
JOIN users u ON u.id = p.user_id
LEFT JOIN comments c ON c.post_id = p.id
GROUP BY p.id, p.title, u.name;

-- Refresh when underlying data changes
REFRESH MATERIALIZED VIEW post_summary;
```

---

## Gotchas

- **Update anomalies are silent** — if you update a user's name in `users` but forget `comments.author_name`, both values coexist in the database with no error. Your app shows wrong data with no warning.
- **Materialized views have staleness windows** — they don't update in real time. If freshness matters, you need to refresh them on a schedule or trigger, and during that window reads are stale.
- **Denormalization increases migration complexity** — when a denormalized field's source schema changes, you have to find and migrate every place that copied it.
- **It's not a substitute for bad query design** — an N+1 query problem won't be fixed by denormalization; it needs to be fixed at the query level first.
- **Document databases make this the default** — MongoDB embedding is denormalization by design. The same trade-offs apply; they just hide behind a different mental model.

---

## Interview Angle

**What they're really testing:** Whether you understand the normalization trade-off and can reason about consistency vs. performance in a real schema.

**Common question form:** "How would you optimize this schema for high read traffic?" or "Design a comments system that scales to millions of reads per second."

**The depth signal:** A junior answer is "store the data together so you don't need joins." A senior answer explains the consistency maintenance burden, proposes a strategy to keep copies in sync (triggers, materialized views, event-driven updates), and knows when normalized + indexed is actually faster than denormalized due to cache behavior and smaller row sizes.

---

## Related Topics

- [[system-design/indexing-strategy.md]] — Always try indexing before denormalizing; it's lower risk.
- [[system-design/sql-vs-nosql.md]] — Document databases are built around denormalized data models by default.
- [[system-design/caching.md]] — Caching is often a better alternative to denormalization for read-heavy workloads.
- [[system-design/event-sourcing.md]] — Event sourcing uses projections which are a form of intentional denormalization.

---

## Source

https://www.postgresql.org/docs/current/sql-creatematerializedview.html

---

*Last updated: 2026-03-24*