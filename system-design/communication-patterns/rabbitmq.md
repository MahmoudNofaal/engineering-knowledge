# RabbitMQ

> A message broker that routes messages from producers to consumers using exchanges and queues, with flexible routing rules and strong delivery guarantees.

---

## When To Use It

Use RabbitMQ when you need flexible message routing (fan-out, topic-based, direct), strong per-message acknowledgment, or task queues with retry logic. It fits well for background jobs, microservice communication, and workflows where each message should be processed by exactly one consumer. Don't use it when you need event replay or multiple independent consumers reading the same stream — that's Kafka's domain. Avoid it for very high-throughput pipelines where raw write speed is the primary concern.

---

## Core Concept

RabbitMQ uses a broker model: producers send messages to an exchange, and the exchange routes them to one or more queues based on routing rules. Consumers subscribe to queues. The key insight is that producers never send directly to queues — the exchange is the routing layer in between. There are four exchange types: direct (exact key match), topic (wildcard key match), fanout (broadcast to all bound queues), and headers (match on message headers). Messages are acknowledged per-delivery, and unacknowledged messages are requeued if the consumer disconnects — giving you at-least-once delivery with clear failure semantics.

---

## The Code

**Producer — publishing to an exchange (.NET with RabbitMQ.Client)**
```csharp
var factory = new ConnectionFactory { HostName = "localhost" };
using var connection = factory.CreateConnection();
using var channel = connection.CreateModel();

// Declare exchange and queue (idempotent — safe to run on every startup)
channel.ExchangeDeclare("orders", ExchangeType.Topic, durable: true);
channel.QueueDeclare("orders.new", durable: true, exclusive: false, autoDelete: false);
channel.QueueBind("orders.new", "orders", routingKey: "order.created");

var body = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new { OrderId = 42 }));

var props = channel.CreateBasicProperties();
props.Persistent = true; // survive broker restart

channel.BasicPublish("orders", routingKey: "order.created", basicProperties: props, body: body);
```

**Consumer — processing with manual acknowledgment**
```csharp
channel.BasicQos(prefetchSize: 0, prefetchCount: 1, global: false); // one message at a time

var consumer = new EventingBasicConsumer(channel);

consumer.Received += (model, args) =>
{
    var body = Encoding.UTF8.GetString(args.Body.ToArray());

    try
    {
        ProcessOrder(body);
        channel.BasicAck(args.DeliveryTag, multiple: false); // acknowledge success
    }
    catch
    {
        // requeue: false sends to dead-letter exchange instead of infinite retry
        channel.BasicNack(args.DeliveryTag, multiple: false, requeue: false);
    }
};

channel.BasicConsume("orders.new", autoAck: false, consumer: consumer);
```

**Dead-letter exchange setup**
```csharp
var args = new Dictionary<string, object>
{
    { "x-dead-letter-exchange", "orders.dlx" },
    { "x-message-ttl", 30000 } // optional: expire messages after 30s
};

channel.QueueDeclare("orders.new", durable: true, exclusive: false, autoDelete: false, arguments: args);
```

---

## Gotchas

- **`autoAck: true` is a data-loss trap.** With auto-ack, RabbitMQ marks the message as delivered the moment it's sent to the consumer. If the consumer crashes mid-processing, the message is gone. Always use manual acknowledgment in production.
- **Prefetch count of 0 means unlimited.** Setting `prefetchCount: 0` tells RabbitMQ to send all queued messages to the consumer at once. If processing is slow, the consumer's memory fills up and nothing is left for other consumers. Set it to 1–10 depending on processing time.
- **Queues and exchanges must be declared identically on every reconnect.** If you change a queue's durability or arguments after it's already created, RabbitMQ throws a channel error. The only fix is to delete and recreate the queue — which loses messages.
- **Unroutable messages are silently dropped by default.** If you publish to an exchange with no matching queue binding, the message disappears. Enable the `mandatory` flag and handle returned messages, or use an alternate exchange.
- **RabbitMQ is not designed for event replay.** Once a message is acknowledged, it's gone. If you realize you need to reprocess historical events, you're out of luck — you'd need to have stored them separately.

---

## Interview Angle

**What they're really testing:** Whether you understand broker routing models and delivery guarantee mechanics, not just that RabbitMQ is a "message queue."

**Common question form:** "Compare RabbitMQ and Kafka" or "How would you design a reliable background job system?"

**The depth signal:** A junior describes RabbitMQ as a queue for async processing. A senior explains the exchange-binding-queue model, the four exchange types and when to use each, why `prefetchCount` matters for fair dispatch under load, and the fundamental architectural difference from Kafka — RabbitMQ deletes on acknowledgment while Kafka retains — which makes them suited for completely different use cases.

---

## Related Topics

- [[system-design/kafka.md]] — Kafka is the right tool when you need retention, replay, or multiple independent consumers on the same stream
- [[system-design/message-queues.md]] — RabbitMQ is one implementation of the broader message queue pattern
- [[system-design/event-driven-architecture.md]] — RabbitMQ is commonly used as the broker in event-driven microservice systems

---

## Source

https://www.rabbitmq.com/documentation.html

---

*Last updated: 2026-03-24*