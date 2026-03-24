# PostgreSQL vs SQL Server

> Two enterprise-grade relational databases that solve the same core problem differently — one open-source and flexible, one Microsoft-native and tightly integrated.

---

## When To Use It

Choose **PostgreSQL** when you're on Linux/cloud-native infrastructure, need advanced types (JSONB, arrays, custom types), or want zero licensing cost. Choose **SQL Server** when you're deep in the Microsoft ecosystem (Azure, .NET, Active Directory, SSIS/SSRS) or your organization already has SQL Server licenses. Don't treat this as a technical purity debate — integration cost, licensing, and team familiarity often outweigh raw feature differences.

---

## Core Concept

Both are ACID-compliant relational databases that speak SQL, but they diverge fast once you go past basic queries. PostgreSQL treats everything as an extension point — you can define your own types, operators, and index types. SQL Server is more opinionated and ships with a richer built-in tooling ecosystem (profiler, SSMS, Agent jobs, replication GUI). The biggest practical difference: Postgres uses MVCC (Multi-Version Concurrency Control) for reads that never block writes, while SQL Server uses a mix of lock-based and snapshot isolation that you have to opt into explicitly. This changes how you think about read-heavy workloads.

---

## The Code

**Postgres: JSONB column with index (no equivalent in SQL Server without workarounds)**
```sql
-- Postgres
CREATE TABLE events (
    id          SERIAL PRIMARY KEY,
    payload     JSONB NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Index a specific key inside the JSON — SQL Server can't do this natively
CREATE INDEX idx_events_type ON events ((payload->>'event_type'));

-- Query using the index
SELECT * FROM events
WHERE payload->>'event_type' = 'purchase';
```

**SQL Server: Same table, JSON stored as NVARCHAR — no native JSONB**
```sql
-- SQL Server
CREATE TABLE events (
    id          INT IDENTITY PRIMARY KEY,
    payload     NVARCHAR(MAX) NOT NULL,  -- just a string, not a real type
    created_at  DATETIME2 DEFAULT GETUTCDATE()
);

-- JSON_VALUE parses at query time — no real index on the value
SELECT * FROM events
WHERE JSON_VALUE(payload, '$.event_type') = 'purchase';
```

**Snapshot isolation — opt-in on SQL Server, default behavior in Postgres**
```sql
-- SQL Server: you must explicitly enable snapshot isolation per database
ALTER DATABASE MyDb SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE MyDb SET READ_COMMITTED_SNAPSHOT ON;

-- Then readers don't block writers. In Postgres, this is always true.
```

**Upsert syntax comparison**
```sql
-- Postgres (INSERT ... ON CONFLICT)
INSERT INTO users (email, name)
VALUES ('a@b.com', 'Ali')
ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name;

-- SQL Server (MERGE — verbose, more error-prone)
MERGE users AS target
USING (VALUES ('a@b.com', 'Ali')) AS src(email, name)
ON target.email = src.email
WHEN MATCHED THEN UPDATE SET name = src.name
WHEN NOT MATCHED THEN INSERT (email, name) VALUES (src.email, src.name);
```

---

## Gotchas

- **SQL Server's `READ_COMMITTED_SNAPSHOT` is off by default.** Without it, readers block writers and vice versa. Most teams are surprised their "default" SQL Server setup has more contention than expected. Enabling it requires an exclusive lock on the DB briefly.
- **Postgres `SERIAL` / `BIGSERIAL` are not true sequences under the hood** — they're syntactic sugar over `CREATE SEQUENCE`. If you delete rows and restart, gaps appear. Don't assume ID continuity.
- **SQL Server `NOLOCK` hints are almost always a mistake.** They return dirty reads and phantom rows. Teams use them to "fix" blocking issues without realizing they're trading correctness for speed.
- **Postgres case-sensitivity on identifiers.** Unquoted names are lowercased. `SELECT * FROM Users` and `SELECT * FROM users` are the same — but `SELECT * FROM "Users"` is different. SQL Server is case-insensitive by default (collation-dependent).
- **SQL Server licenses are per-core and expensive.** Scaling up a SQL Server instance can hit five-figure annual costs fast. Postgres is free — the cost is operational expertise, not licensing.

---

## Interview Angle

**What they're really testing:** Whether you understand concurrency models and can reason about tradeoffs beyond syntax differences.

**Common question form:** *"When would you choose Postgres over SQL Server?"* or *"How does SQL Server handle concurrent reads and writes?"*

**The depth signal:** A junior says "Postgres is open-source and SQL Server costs money." A senior explains that SQL Server's default isolation level (`READ COMMITTED` without snapshot) uses shared locks, so readers can block writers — and then describes how enabling `READ_COMMITTED_SNAPSHOT` switches it to a row-versioning model similar to Postgres's default MVCC behavior. They also know that Postgres's MVCC means `VACUUM` is a real operational concern (dead tuple bloat), which has no equivalent in SQL Server.

---

## Related Topics

- [[databases/mvcc-and-isolation-levels.md]] — The concurrency model underlying both databases; essential to understand before choosing between them.
- [[databases/indexing-strategies.md]] — Index types differ significantly: Postgres supports partial, expression, and GIN/GiST indexes; SQL Server has columnstore and filtered indexes.
- [[databases/jsonb-postgres.md]] — Deep dive into Postgres's native JSON document storage, which is a major differentiator.
- [[system-design/database-selection.md]] — Higher-level framework for choosing a database in system design interviews.

---

## Source

[PostgreSQL vs SQL Server — official feature comparison](https://www.postgresql.org/about/featurematrix/)

---
*Last updated: 2026-03-24*