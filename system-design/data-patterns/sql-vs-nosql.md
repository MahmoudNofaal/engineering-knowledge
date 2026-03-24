# SQL vs NoSQL

> A comparison of two database paradigms: relational (SQL) databases that enforce structure and relationships, versus non-relational (NoSQL) databases that trade structure for flexibility and scale.

---

## When To Use It

Use SQL when your data has clear relationships, you need ACID guarantees, and your schema is stable — financial systems, e-commerce orders, user accounts. Use NoSQL when you're dealing with high write throughput, unstructured or evolving data, or horizontal scale requirements that relational databases struggle to meet cheaply. Don't reach for NoSQL just because it feels modern — if your data is naturally relational, you'll end up rebuilding joins in application code. The real decision is about your consistency requirements and access patterns, not hype.

---

## Core Concept

SQL databases store data in tables with fixed schemas and use foreign keys to express relationships. The database engine enforces constraints, handles joins, and guarantees that a transaction either fully completes or fully rolls back. NoSQL databases come in several shapes — document stores (MongoDB), key-value (Redis), wide-column (Cassandra), graph (Neo4j) — but they all share the same trade: they relax consistency or structure in exchange for flexibility and the ability to scale horizontally across many machines. The CAP theorem is the underlying reason this trade-off exists: in a distributed system, you can't have consistency, availability, and partition tolerance all at once, so NoSQL systems often choose availability and partition tolerance over strict consistency.

---

## The Code

### SQL — Relational join between users and orders
```sql
-- Normalized schema: data lives in separate tables, joined at query time
SELECT u.name, o.total, o.created_at
FROM users u
INNER JOIN orders o ON o.user_id = u.id
WHERE u.id = 42
ORDER BY o.created_at DESC;
```

### NoSQL — Denormalized document in MongoDB (same use case)
```javascript
// Document store: all order data embedded directly in the user document
// No join needed — reads are fast, but updates to shared data are harder
db.users.findOne(
  { _id: 42 },
  { name: 1, orders: 1 }
);

// Example document shape:
// {
//   _id: 42,
//   name: "Ahmed",
//   orders: [
//     { total: 199.99, created_at: "2026-03-01" },
//     { total: 89.00,  created_at: "2026-03-15" }
//   ]
// }
```

### SQL — ACID transaction (money transfer)
```sql
BEGIN TRANSACTION;
  UPDATE accounts SET balance = balance - 500 WHERE id = 1;
  UPDATE accounts SET balance = balance + 500 WHERE id = 2;
COMMIT;
-- If either UPDATE fails, the whole transaction rolls back automatically
```

---

## Gotchas

- **NoSQL doesn't mean "no schema"** — it means schema-on-read. Your application code becomes the enforcer, which means schema bugs surface at runtime, not at insert time.
- **Horizontal scaling with SQL is possible** — read replicas, sharding, and tools like Vitess or CockroachDB exist. Defaulting to NoSQL for "scale" without measuring your actual bottleneck is premature optimization.
- **Eventual consistency is a product decision, not just a technical one** — if two users see different account balances for 200ms, that might be acceptable for a social feed but catastrophic for a payment system.
- **Document embedding creates update anomalies** — if you embed a product's price inside every order document and the price changes, you have stale data everywhere unless you planned for it.
- **Many NoSQL databases have added SQL-like features over time** (MongoDB has transactions, DynamoDB has transactions) — so the line is blurrier than it was in 2012. Evaluate current capabilities, not the original marketing.

---

## Interview Angle

**What they're really testing:** Whether you understand trade-offs at the data model and consistency level, not just surface-level syntax differences.

**Common question form:** "When would you choose MongoDB over PostgreSQL?" or "Design a system for X — what database would you use and why?"

**The depth signal:** A junior answer lists features ("NoSQL is faster and scales better"). A senior answer talks about access patterns first — what queries will dominate, how the data changes over time, and what consistency guarantees the business actually needs. A senior candidate also knows that "BASE vs ACID" is the real axis of comparison, can explain eventual consistency with a concrete example, and will ask clarifying questions before picking a database rather than defaulting to a favorite.

---

## Related Topics

- [[system-design/cap-theorem.md]] — The theoretical foundation explaining why NoSQL systems make the consistency trade-offs they do.
- [[databases/indexing.md]] — Index strategies differ significantly between SQL and NoSQL; understanding both is essential for query performance.
- [[system-design/caching.md]] — NoSQL stores like Redis are often used as caching layers on top of a primary SQL database.
- [[databases/acid-vs-base.md]] — The consistency model difference between relational and non-relational systems in detail.

---

## Source

https://www.mongodb.com/resources/basics/databases/nosql-explained

---

*Last updated: 2026-03-24*