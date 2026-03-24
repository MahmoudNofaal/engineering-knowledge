# NoSQL Database Types

> A map of the four main NoSQL database categories — document, key-value, column-family, and graph — what each one actually is, and when each one is the right call.

---

## When To Use It

Use this as a decision framework when a relational model is a poor fit: the data has no fixed schema, the access pattern is too narrow for a full row fetch, the relationship graph is the data itself, or you need horizontal write scaling that Postgres can't give you. Don't reach for NoSQL to avoid thinking about data modeling — bad NoSQL schemas are harder to fix than bad relational ones because there are no joins to bail you out.

---

## Core Concept

NoSQL doesn't mean "no schema" — it means "not organized around tables and joins." Each type optimizes for a specific data shape and access pattern. Key-value stores optimize for single-key lookup speed. Document stores optimize for flexible, self-contained records. Column-family stores optimize for wide, sparse data with high write throughput. Graph databases optimize for traversing relationships. Picking the wrong type doesn't just hurt performance — it makes queries that should be simple become application-level loops.

---

## The Code

**Key-Value — Redis**
```python
import redis

r = redis.Redis()

# O(1) get/set — the entire value is opaque to the DB
r.set("session:abc123", '{"user_id": 42, "role": "admin"}', ex=3600)
val = r.get("session:abc123")

# Redis also supports typed values: lists, sets, sorted sets, hashes
r.zadd("leaderboard", {"alice": 1500, "bob": 1200})  # sorted set
top3 = r.zrevrange("leaderboard", 0, 2, withscores=True)
```

**Document — MongoDB**
```python
from pymongo import MongoClient

db = MongoClient()["shop"]

# Documents are schema-free — fields vary per document
db.products.insert_many([
    {"name": "Laptop", "brand": "Dell", "specs": {"ram": 16, "ssd": 512}},
    {"name": "Phone",  "brand": "Apple", "color": "black"},  # different shape
])

# Query on nested field
db.products.find({"specs.ram": {"$gte": 16}})

# Index on a nested field
db.products.create_index("specs.ram")
```

**Column-Family — Apache Cassandra**
```python
from cassandra.cluster import Cluster

session = Cluster().connect("analytics")

# Schema defined upfront, but rows are sparse — missing columns cost nothing
session.execute("""
    CREATE TABLE IF NOT EXISTS events (
        user_id  UUID,
        event_ts TIMESTAMP,
        type     TEXT,
        payload  TEXT,
        PRIMARY KEY (user_id, event_ts)  -- partition key + clustering key
    )
""")

# Writes are extremely fast — appended to commit log, no read-before-write
session.execute("""
    INSERT INTO events (user_id, event_ts, type, payload)
    VALUES (%s, toTimestamp(now()), %s, %s)
""", (user_id, "click", '{"page": "/home"}'))

# Queries MUST align with the primary key — no arbitrary WHERE clauses
session.execute("""
    SELECT * FROM events
    WHERE user_id = %s AND event_ts > %s
""", (user_id, since))
```

**Graph — Neo4j**
```python
from neo4j import GraphDatabase

driver = GraphDatabase.driver("bolt://localhost:7687")

with driver.session() as session:
    # Nodes and relationships are first-class — not foreign keys
    session.run("""
        MERGE (a:User {id: $uid})
        MERGE (b:Product {id: $pid})
        MERGE (a)-[:PURCHASED {at: datetime()}]->(b)
    """, uid="u1", pid="p42")

    # Traverse relationships — no joins, no N+1
    result = session.run("""
        MATCH (u:User {id: $uid})-[:PURCHASED]->(p:Product)
              <-[:PURCHASED]-(other:User)
        RETURN DISTINCT other.id AS similar_user
        LIMIT 10
    """, uid="u1")
```

---

## Gotchas

- **Document stores still need a data model.** Embedding everything in one document feels flexible until you need to update a nested field across 10M documents, or query a field you never indexed. Think about access patterns before you insert anything.
- **Cassandra's primary key is a query contract, not just an identifier.** Every query must include the partition key. Designing a table without knowing the query first produces a table you can't query without `ALLOW FILTERING` — which is a full scan.
- **Redis is not durable by default.** AOF and RDB persistence exist but are off or lossy depending on config. Using Redis as a primary data store without understanding its persistence model is a production incident waiting to happen.
- **Graph databases don't scale writes horizontally the way document or column-family stores do.** Neo4j's native clustering is read-heavy. If your graph is write-intensive at massive scale, you're in difficult territory.
- **"NoSQL scales better" is a myth without context.** MongoDB and Cassandra scale writes horizontally, but they do so by giving up joins and transactions (or making them expensive). You're trading query flexibility for write throughput — make that tradeoff consciously.

---

## Interview Angle

**What they're really testing:** Whether you can match a data problem to a storage primitive — not just recite a list of database names.

**Common question form:** *"What database would you use for X?"* or *"When would you pick MongoDB over Postgres?"* or *"Design a system for real-time leaderboards."*

**The depth signal:** A junior lists database names and vague adjectives ("MongoDB is flexible, Redis is fast"). A senior maps the choice to the access pattern: key-value for O(1) single-key reads with no query flexibility needed; document for self-contained records with variable shape queried by content; column-family for append-heavy time-series or event data queried by partition; graph when relationship traversal depth is the query itself and a join chain of 5+ levels would be needed in SQL. They also know the failure modes — what each type makes hard, not just what it makes easy.

---

## Related Topics

- [[databases/postgres-vs-sqlserver.md]] — Relational baseline to compare against before choosing NoSQL.
- [[databases/postgres-jsonb.md]] — Postgres with JSONB covers a large subset of the document store use case without leaving the relational world.
- [[databases/mvcc-and-isolation-levels.md]] — Most NoSQL stores sacrifice ACID transactions; understanding what you're giving up requires knowing what MVCC gives you.
- [[system-design/database-selection.md]] — Higher-level framework that incorporates NoSQL type selection into broader architecture decisions.

---

## Source

[Martin Fowler — NoSQL Distilled (overview)](https://martinfowler.com/books/nosql.html)

---
*Last updated: 2026-03-24*