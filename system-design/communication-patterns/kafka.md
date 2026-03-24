# Apache Kafka

> A distributed, append-only log that lets producers write events and multiple consumers read them independently, at their own pace, without the events being deleted after consumption.

---

## When To Use It

Use Kafka when you need high-throughput event streaming, when multiple independent consumers need to read the same events, or when you need to replay history. Classic uses: activity feeds, audit logs, real-time analytics pipelines, event sourcing backends. Don't use Kafka for simple background job queues — it's operationally heavy and overkill when a managed queue (SQS, Service Bus) would do. Don't use it when your team has no experience running it; misconfigured Kafka is a production incident waiting to happen.

---

## Core Concept

Kafka is fundamentally different from a traditional queue. A queue deletes a message once a consumer reads it. Kafka writes every event to an immutable, append-only log called a topic. Consumers track their own position (called an offset) in that log. Consumer A can be at offset 1000 while Consumer B is still at offset 200 — they don't interfere with each other. Events stay in the log for a configured retention period (days or weeks), so you can replay from any point in history. Topics are split into partitions for parallelism, and each partition is replicated across brokers for fault tolerance.

---

## The Code

**Producer — writing events (.NET with Confluent.Kafka)**
```csharp
var config = new ProducerConfig { BootstrapServers = "localhost:9092" };

using var producer = new ProducerBuilder<string, string>(config).Build();

await producer.ProduceAsync("orders", new Message<string, string>
{
    Key = "order-42",       // same key always goes to same partition
    Value = JsonSerializer.Serialize(new { OrderId = 42, Product = "Widget" })
});
```

**Consumer — reading events**
```csharp
var config = new ConsumerConfig
{
    BootstrapServers = "localhost:9092",
    GroupId = "order-processor",       // consumers in same group share partitions
    AutoOffsetReset = AutoOffsetReset.Earliest
};

using var consumer = new ConsumerBuilder<string, string>(config).Build();
consumer.Subscribe("orders");

while (true)
{
    var message = consumer.Consume();
    Console.WriteLine($"Received: {message.Message.Value}");

    // Commit offset AFTER processing to avoid data loss on crash
    consumer.Commit(message);
}
```

**Topic configuration (via CLI)**
```bash
# Create a topic with 6 partitions and 3 replicas
kafka-topics.sh --create \
  --topic orders \
  --partitions 6 \
  --replication-factor 3 \
  --bootstrap-server localhost:9092
```

---

## Gotchas

- **Ordering is guaranteed per partition, not per topic.** If Order 1 and Order 2 for the same customer land on different partitions, they can be processed out of order. Use a consistent partition key (customer ID, order ID) when order matters.
- **Auto-commit is dangerous.** The default consumer config commits offsets automatically on a timer. If your process crashes after the commit but before finishing the work, that event is lost. Disable auto-commit and commit manually after processing.
- **Consumer group rebalancing pauses all consumers.** When a new consumer joins or leaves a group, Kafka reassigns partitions. During the rebalance, no consumer in the group processes messages. Design for this pause — use cooperative rebalancing to minimize disruption.
- **Kafka is not a queue for RPC-style workflows.** If you need a response from the consumer (request-reply), Kafka makes this awkward. You'd need a reply topic and correlation IDs. A traditional queue or direct HTTP call is cleaner.
- **Retention is time-based, not consumption-based.** Events are deleted after the retention period regardless of whether anyone has consumed them. Late consumers that fall behind by more than the retention window will lose events permanently.

---

## Interview Angle

**What they're really testing:** Whether you understand the log abstraction and how it differs from traditional queues, and the operational implications of consumer groups.

**Common question form:** "How does Kafka differ from RabbitMQ or SQS?" or "How would you design a real-time event pipeline?"

**The depth signal:** A junior says Kafka is fast and handles high throughput. A senior explains the offset model and why it enables multiple independent consumers, describes the partition-key strategy for ordering guarantees, explains the rebalancing problem and cooperative rebalancing as a mitigation, and can articulate when Kafka is the wrong choice — specifically, when you need request-reply semantics or when operational overhead isn't justified.

---

## Related Topics

- [[system-design/message-queues.md]] — traditional queues delete on consumption; understanding the contrast clarifies when to use each
- [[system-design/event-driven-architecture.md]] — Kafka is the most common backbone for event-driven systems at scale
- [[system-design/rabbitmq.md]] — RabbitMQ solves a similar problem with a different model; knowing both is essential for making the right call

---

## Source

https://kafka.apache.org/documentation/

---

*Last updated: 2026-03-24*