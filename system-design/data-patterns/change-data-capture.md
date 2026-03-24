# Change Data Capture (CDC)

> A technique for tracking row-level changes in a database (inserts, updates, deletes) and streaming those changes to other systems in near real time.

---

## When To Use It

Use CDC when you need to keep multiple systems in sync with a primary database without coupling them through direct API calls — syncing a search index, populating a data warehouse, invalidating a cache, or feeding an event stream. It's the right tool when you can't (or don't want to) modify the application that writes to the database. Don't use it as a substitute for a proper event-driven architecture in greenfield systems — if you own the write path, emit domain events explicitly instead.

---

## Core Concept

Most relational databases maintain a write-ahead log (WAL) or binary log (binlog) for crash recovery. CDC taps into that log and turns it into a stream of change events. Because it reads from the log rather than polling tables, it captures every change in order without missing anything and without adding load to the database's query path. Tools like Debezium sit between the database and consumers: they read the log, convert changes into structured events (usually JSON), and publish them to a message broker like Kafka. Consumers then process those events independently at their own pace.

---

## The Code

### Debezium connector config (Postgres source → Kafka)
```json
{
  "name": "orders-cdc-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "cdc_user",
    "database.password": "secret",
    "database.dbname": "shop",
    "database.server.name": "shop",
    "table.include.list": "public.orders",
    "plugin.name": "pgoutput"
  }
}
```

### Sample CDC event payload (published to Kafka)
```json
{
  "before": { "id": 99, "status": "pending" },
  "after":  { "id": 99, "status": "shipped" },
  "op": "u",
  "ts_ms": 1711267200000,
  "source": { "table": "orders", "lsn": 24045056 }
}
```

### Consuming CDC events in C# (Kafka consumer)
```csharp
using Confluent.Kafka;

var config = new ConsumerConfig
{
    BootstrapServers = "kafka:9092",
    GroupId = "search-index-updater",
    AutoOffsetReset = AutoOffsetReset.Earliest
};

using var consumer = new ConsumerBuilder<string, string>(config).Build();
consumer.Subscribe("shop.public.orders");

while (true)
{
    var result = consumer.Consume();
    var change = JsonSerializer.Deserialize<OrderChangeEvent>(result.Message.Value);

    if (change.Op == "u" && change.After.Status == "shipped")
    {
        await searchIndex.UpdateOrderStatusAsync(change.After.Id, "shipped");
    }
}
```

---

## Gotchas

- **WAL / binlog retention must be configured explicitly** — by default many databases don't keep the log long enough for a CDC consumer that falls behind. If the consumer is offline and the log rolls over, you've lost events and must re-snapshot.
- **Schema changes break consumers silently** — if you add or rename a column in the source table, the event shape changes. Consumers deserializing into a fixed model will either crash or silently drop the new field. A schema registry (like Confluent's) mitigates this.
- **"At least once" delivery means duplicate events are normal** — consumers must be idempotent. Applying the same update twice must produce the same result as applying it once.
- **Initial snapshot is a separate problem** — CDC only captures changes from the moment you connect. For a pre-existing table with 50M rows, you need an initial bulk load before the stream catches up. Most CDC tools support this, but it's operationally heavy.
- **Debezium requires database-level permissions** — specifically replication permissions on Postgres. This is often a friction point in locked-down production environments.

---

## Interview Angle

**What they're really testing:** Whether you understand how to propagate state changes across distributed systems reliably without tight coupling.

**Common question form:** "How would you keep your Elasticsearch index in sync with your Postgres database?" or "How do you propagate database changes to downstream services?"

**The depth signal:** A junior says "poll the database every few seconds for changes." A senior describes WAL-based CDC, explains why polling misses rapid updates and adds DB load, discusses idempotent consumers, mentions the initial snapshot problem, and knows about schema evolution challenges. Extra credit for mentioning the outbox pattern as an alternative when you own the write path.

---

## Related Topics

- [[system-design/event-sourcing.md]] — Event sourcing makes all changes explicit as domain events; CDC retrofits that capability onto a traditional database.
- [[system-design/data-lake-vs-warehouse.md]] — CDC is a common ingestion pattern for streaming live data into a warehouse or lake.
- [[system-design/indexing-strategy.md]] — Search index sync is one of the most common CDC use cases.

---

## Source

https://debezium.io/documentation/reference/stable/index.html

---

*Last updated: 2026-03-24*