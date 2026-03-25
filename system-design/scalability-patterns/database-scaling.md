# Database Scaling

> Strategies for increasing a database's capacity to handle more reads, more writes, or more data than a single instance can support.

---

## When To Use It
When your database is the bottleneck — query latency is rising, connection pools are saturated, disk I/O is maxed, or storage is running out. Before any of these strategies, rule out bad queries and missing indexes first. Scaling infrastructure around a slow query just distributes the slowness. The order of operations: optimize → cache → scale reads → scale writes → shard.

---

## Core Concept
Database scaling has two distinct axes: read scaling and write scaling. They require different solutions. Read scaling is relatively easy — you add read replicas that receive a copy of every write from the primary, and route read traffic across them. Write scaling is hard — all writes must go to one place to maintain consistency, so you either vertically scale the primary, reduce write volume with caching, or shard (split data across multiple primaries). Storage scaling is solved with distributed storage, object stores, or partitioning. Each step up in complexity adds operational overhead and often introduces consistency trade-offs.

---

## The Code
```csharp
// ── Read replica routing — most common first scaling step ─────────────────
using Npgsql;
using System;
using System.Collections.Generic;
using System.Linq;

public class DatabasePool
{
    private readonly NpgsqlConnection _primary;
    private readonly List<NpgsqlConnection> _replicas;
    private readonly Random _random = new();

    public DatabasePool(string primaryDsn, List<string> replicaDsns)
    {
        _primary = new NpgsqlConnection(primaryDsn);
        _primary.Open();
        _replicas = replicaDsns.Select(dsn => 
        {
            var conn = new NpgsqlConnection(dsn);
            conn.Open();
            return conn;
        }).ToList();
    }

    public NpgsqlConnection WriteConn()
    {
        // All writes go to primary — always.
        return _primary;
    }

    public NpgsqlConnection ReadConn()
    {
        // Reads distributed across replicas. Primary handles reads only on fallback.
        if (_replicas.Count > 0)
            return _replicas[_random.Next(_replicas.Count)];   // simple random; use least-connections in prod
        return _primary;                        // fallback if no replicas yet
    }
}

var pool = new DatabasePool(
    primaryDsn: "Server=primary;Port=5432;Database=db;",
    replicaDsns: new List<string>
    {
        "Server=replica-1;Port=5432;Database=db;",
        "Server=replica-2;Port=5432;Database=db;",
    }
);

// Write: goes to primary
using (var cmd = pool.WriteConn().CreateCommand())
{
    cmd.CommandText = "INSERT INTO orders (user_id, total) VALUES (@userId, @total)";
    cmd.Parameters.AddWithValue("@userId", 42);
    cmd.Parameters.AddWithValue("@total", 99.99);
    cmd.ExecuteNonQuery();
}

// Read: goes to a replica
using (var cmd = pool.ReadConn().CreateCommand())
{
    cmd.CommandText = "SELECT * FROM orders WHERE user_id = @userId";
    cmd.Parameters.AddWithValue("@userId", 42);
    var reader = cmd.ExecuteReader();
    while (reader.Read())
    {
        // Process row
    }
}
```
```sql
-- ── Connection pooling — mandatory before any other scaling step ──────────
-- Each DB connection costs ~5–10 MB of RAM on Postgres.
-- 1000 app servers × 10 connections each = 10,000 connections = ~50–100 GB RAM.
-- PgBouncer sits between app and Postgres, multiplexing connections.

-- PgBouncer config (pgbouncer.ini):
-- [databases]
-- mydb = host=primary port=5432 dbname=mydb
--
-- [pgbouncer]
-- pool_mode = transaction          ← connection released after each transaction
-- max_client_conn = 10000          ← app can open 10K connections to PgBouncer
-- default_pool_size = 20           ← PgBouncer uses only 20 real DB connections
```
```csharp
// ── CQRS: separate read and write models ──────────────────────────────────
// Write model: normalized, consistent, ACID
// Read model: denormalized, optimized for query patterns, eventually consistent

using System.Collections.Generic;
using Npgsql;

// Write side — strict, normalized
public string PlaceOrder(int userId, List<Dictionary<string, object>> items)
{
    string orderId;
    using (var cmd = pool.WriteConn().CreateCommand())
    {
        cmd.CommandText = "INSERT INTO orders (user_id) VALUES (@userId) RETURNING id";
        cmd.Parameters.AddWithValue("@userId", userId);
        orderId = cmd.ExecuteScalar()?.ToString();
    }

    foreach (var item in items)
    {
        using (var cmd = pool.WriteConn().CreateCommand())
        {
            cmd.CommandText = "INSERT INTO order_items (order_id, product_id, qty) VALUES (@orderId, @productId, @qty)";
            cmd.Parameters.AddWithValue("@orderId", orderId);
            cmd.Parameters.AddWithValue("@productId", item["product_id"]);
            cmd.Parameters.AddWithValue("@qty", item["qty"]);
            cmd.ExecuteNonQuery();
        }
    }

    // Publish event → async worker updates the read model
    PublishEvent("order.created", new { order_id = orderId, user_id = userId });
    return orderId;
}

// Read side — denormalized, fast
public Dictionary<string, object> GetOrderSummary(string orderId)
{
    // This table is pre-joined and pre-aggregated — single fast read
    var summary = new Dictionary<string, object>();
    using (var cmd = pool.ReadConn().CreateCommand())
    {
        cmd.CommandText = "SELECT * FROM order_summaries WHERE order_id = @orderId";
        cmd.Parameters.AddWithValue("@orderId", orderId);
        using (var reader = cmd.ExecuteReader())
        {
            while (reader.Read())
            {
                for (int i = 0; i < reader.FieldCount; i++)
                    summary[reader.GetName(i)] = reader.GetValue(i);
            }
        }
    }
    return summary;
}
```

---

## Gotchas
- **Replication lag is not theoretical.** Under write load, replicas can lag the primary by seconds. A user who writes data and immediately reads it from a replica may see stale results. Mitigate with read-your-writes routing (route the requesting user's reads to the primary for a short window after a write).
- **Connection count is a scaling bottleneck most teams hit before they expect it.** PostgreSQL's connection limit is typically 100–200 on default configs. Without a connection pooler (PgBouncer, RDS Proxy), 50 app instances with 10 connections each can saturate the database before you've even loaded it.
- **Vertical scaling the primary has a hard ceiling — and the ceiling is lower than you think.** Postgres on a 96-core machine doesn't scale linearly past 32 cores for many workloads due to lock contention. Adding more CPU past a certain point returns diminishing results.
- **Read replicas don't help write-heavy workloads.** If 90% of your database load is writes, adding replicas does nothing — the primary is still the bottleneck. Write scaling requires architectural changes: write batching, async writes, or sharding.
- **Never scale before profiling.** The most common database scaling mistake is adding replicas or sharding when the actual problem is a missing index or an N+1 query. Run `EXPLAIN ANALYZE` before any infrastructure change.

---

## Interview Angle
**What they're really testing:** Whether you can diagnose a database bottleneck and prescribe the right scaling strategy — rather than jumping straight to the most complex solution.

**Common question form:** "Your database can't keep up with traffic. How do you scale it?" or "Design a system that handles 100K writes per second."

**The depth signal:** A junior candidate immediately says "shard it" or "use NoSQL." A senior candidate asks what the bottleneck actually is: "Is it read-heavy or write-heavy? What does the query profile look like? Is connection count the issue or actual query time?" Then they prescribe in order: "First, connection pooler if not in place. Then read replicas for read-heavy load. Then caching to reduce read amplification. Then if write throughput is the actual limit, we look at write batching, async writes, or sharding — with sharding being the last resort because of the operational complexity." The separation is: juniors name a technique, seniors prescribe a sequence based on diagnosis.

---

## Related Topics
- [[system-design/database-sharding.md]] — The next step when vertical scaling and replicas aren't enough.
- [[system-design/caching.md]] — Reducing database read load before scaling the database itself.
- [[system-design/horizontal-vs-vertical-scaling.md]] — The general scaling framework that database scaling lives inside.

---

## Source
https://use-the-index-luke.com/

---
*Last updated: 2026-03-24*