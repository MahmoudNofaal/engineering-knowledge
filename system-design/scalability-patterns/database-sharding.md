# Database Sharding

> Splitting a database horizontally across multiple machines — each machine (shard) holds a subset of the rows, and together they hold the full dataset.

---

## When To Use It
When your dataset is too large for one machine, or your write throughput exceeds what one primary can handle, and you've already exhausted vertical scaling, read replicas, and caching. Sharding is a last resort — not a first step. It adds significant operational complexity and makes cross-shard queries, transactions, and schema changes painful. If you can solve the problem without sharding, do.

---

## Core Concept
Instead of one database holding all rows, you divide the data across N databases (shards), where each shard holds roughly 1/N of the data. A routing layer (your application or a proxy) determines which shard a given piece of data lives on, based on a shard key. The shard key is the most critical decision: it determines data distribution, query routing, and whether you end up with hotspots. Good shard keys distribute data uniformly and allow most queries to hit exactly one shard. Bad shard keys create hot shards (all traffic on one), or require scatter-gather queries (hit every shard, merge results) for common access patterns.

---

## The Code
```csharp
// ─ Shard routing by hash of shard key ─
using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;
using Npgsql;

public class ShardRouter
{
    private const int ShardCount = 4;
    private readonly Dictionary<int, NpgsqlConnection> _shardConnections = new();

    public ShardRouter()
    {
        for (int i = 0; i < ShardCount; i++)
            _shardConnections[i] = new NpgsqlConnection($"Server=shard-{i};Port=5432;Database=db");
    }

    private int GetShard(string shardKey)
    {
        // Map a shard key to a shard index using consistent hashing
        using (var md5 = MD5.Create())
        {
            byte[] hash = md5.ComputeHash(Encoding.UTF8.GetBytes(shardKey));
            long digest = BitConverter.ToInt64(hash, 0);
            return (int)(Math.Abs(digest) % ShardCount);
        }
    }

    public NpgsqlConnection GetConnection(string shardKey)
        => _shardConnections[GetShard(shardKey)];

    public void Example()
    {
        // All data for user_id="u_42" always routes to the same shard
        var conn = GetConnection("u_42");
        using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = "SELECT * FROM orders WHERE user_id = @uid";
            cmd.Parameters.AddWithValue("@uid", "u_42");
            using (var reader = cmd.ExecuteReader())
            {
                // Process orders
            }
        }
    }
}
```
```csharp
// ─ Scatter-gather: queries that must hit every shard ─
// Avoid this pattern on hot paths — it's expensive and slow.
// Example: "find all orders over $500 globally" — no single shard has the answer.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Npgsql;

public class ScatterGatherQuery
{
    private readonly Dictionary<int, NpgsqlConnection> _shardConnections;
    private const int ShardCount = 4;

    public async Task<List<object>> ScatterGatherAsync(string query, object[] parameters)
    {
        var results = new List<object>();
        var tasks = new Task<List<object>>[ShardCount];

        for (int shardId = 0; shardId < ShardCount; shardId++)
        {
            int id = shardId;  // Capture for closure
            tasks[id] = Task.Run(() => QueryShard(id, query, parameters));
        }

        await Task.WhenAll(tasks);

        foreach (var shardResults in tasks.Select(t => t.Result))
            results.AddRange(shardResults);

        return results;
    }

    private async Task<List<object>> QueryShard(int shardId, string query, object[] parameters)
    {
        var results = new List<object>();
        using (var conn = _shardConnections[shardId])
        using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = query;
            for (int i = 0; i < parameters.Length; i++)
                cmd.Parameters.AddWithValue($"@p{i}", parameters[i]);
            
            using (var reader = cmd.ExecuteReader())
            {
                while (reader.Read())
                    results.Add(reader);
            }
        }
        return results;
    }
}

// This works. But at SHARD_COUNT=64, you're making 64 parallel DB calls per request.
// Design your shard key so common queries don't need scatter-gather.
```
```csharp
// ─ Shard key selection analysis ─
// Before committing to a shard key, model the access patterns.

using System;
using System.Collections.Generic;
using System.Linq;

public class ShardKeyAnalysis
{
    public static void AnalyzeAccessPatterns()
    {
        var accessPatterns = new List<(string query, string shardKey, string result)>
        {
            ("Get user's orders", "user_id", "single shard — ideal"),
            ("Get order by order_id", "order_id", "single shard — ideal"),
            ("Get all orders for merchant", "merchant_id", "single shard if merchant_id is shard key, else scatter-gather"),
            ("Global revenue report", "user_id", "scatter-gather — unavoidable for analytics"),
            ("Orders by date range", "user_id", "scatter-gather — date is not the shard key"),
        };

        Console.WriteLine($"{"Query",-40} {"Shard Key",-15} {"Result"}");
        Console.WriteLine(new string('-', 80));
        foreach (var (query, key, result) in accessPatterns)
            Console.WriteLine($"{query,-40} {key,-15} {result}");
    }
}
```

---

## Gotchas
- **Cross-shard transactions don't exist natively.** An order that involves two users on different shards cannot be wrapped in a single ACID transaction across both shards. You need distributed transactions (two-phase commit — complex, slow) or sagas (eventual consistency with compensating actions). Most teams design around this rather than solving it.
- **Resharding is painful and often requires downtime or a complex migration.** When you add a new shard, data must move between shards. If you used `hash % N` as your routing, adding one shard changes the routing for a large fraction of keys. Consistent hashing reduces this problem but doesn't eliminate it.
- **Hot shards happen when shard key values are skewed.** If you shard by `celebrity_id` and one celebrity has 100M followers, that shard gets 100M requests. Always verify that your shard key has high cardinality and roughly uniform distribution before committing.
- **Schema changes become a multi-shard coordination event.** Running `ALTER TABLE` on a sharded system means running it on every shard, usually one at a time to avoid locking. This is slow, error-prone, and must be carefully sequenced.
- **Sharding by tenant (customer) is common for SaaS but creates noisy neighbor problems.** If one large customer generates 80% of the traffic and they land on one shard, you've just moved the bottleneck from one database to one shard. Plan for tenant rebalancing from the start.

---

## Interview Angle
**What they're really testing:** Whether you understand the operational complexity sharding introduces — not just the concept of splitting data.

**Common question form:** "Design Twitter's storage layer" or "How would you store and query billions of records efficiently?"

**The depth signal:** A junior candidate says "shard by user_id" and considers the problem solved. A senior candidate chooses the shard key by analyzing all access patterns first — "most queries are user-scoped, so user_id is a good shard key. But merchant reporting requires scatter-gather — we'd handle that with a separate analytics replica or a pre-aggregated reporting table so it doesn't pollute the transactional shard queries." They also flag the resharding problem ("we'd use consistent hashing to minimize key movement when adding shards") and cross-shard transactions ("we avoid them by design — operations that span users are handled asynchronously with event sourcing"). The separation is: juniors pick a shard key, seniors pick a shard key by modeling every query that will ever touch the data.

---

## Related Topics
- [[system-design/consistent-hashing.md]] — The algorithm that makes resharding practical by minimizing key movement.
- [[system-design/database-partitioning.md]] — Partitioning is sharding within one database instance — often the right first step before true sharding.
- [[system-design/database-scaling.md]] — The broader context: sharding is the last step in a scaling sequence.

---

## Source
https://www.postgresql.org/docs/current/ddl-partitioning.html

---
*Last updated: 2026-03-24*