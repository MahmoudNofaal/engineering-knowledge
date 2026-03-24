# Message Queues

> A buffer that holds messages between a producer and a consumer so they don't have to communicate directly or at the same time.

---

## When To Use It

Use message queues when you need to decouple services, smooth out traffic spikes, or handle work that doesn't need to happen synchronously. Classic uses: sending emails after a purchase, resizing images, processing payments in the background. Don't use them when the caller genuinely needs the result before it can continue — synchronous HTTP or gRPC is the right call there. Don't add a queue just because it sounds scalable; it adds operational complexity and a new failure point.

---

## Core Concept

Without a queue, Service A calls Service B directly. If B is slow or down, A waits or fails. With a queue in the middle, A drops a message and moves on. B picks it up whenever it's ready. They never need to be up at the same time. The queue also acts as a buffer — if B gets overwhelmed, messages pile up in the queue instead of crashing B. Consumers can scale independently, pulling messages at their own pace. The tradeoff is that the system becomes eventually consistent — you can't get an immediate result from a queued operation.

---

## The Code

**Producer — publishing a message (.NET with Azure Service Bus)**
```csharp
var client = new ServiceBusClient(connectionString);
var sender = client.CreateSender("orders-queue");

var message = new ServiceBusMessage(JsonSerializer.Serialize(new
{
    OrderId = 42,
    Product = "Widget"
}));

await sender.SendMessageAsync(message);
```

**Consumer — processing messages**
```csharp
var processor = client.CreateProcessor("orders-queue");

processor.ProcessMessageAsync += async args =>
{
    var body = args.Message.Body.ToString();
    var order = JsonSerializer.Deserialize<Order>(body);

    // Do the actual work
    await ProcessOrder(order);

    // Only acknowledge AFTER successful processing
    await args.CompleteMessageAsync(args.Message);
};

processor.ProcessErrorAsync += args =>
{
    Console.Error.WriteLine(args.Exception.Message);
    return Task.CompletedTask;
};

await processor.StartProcessingAsync();
```

**Dead-letter queue — handling poison messages**
```csharp
// Messages that fail repeatedly are moved to the DLQ automatically
// You process the DLQ separately for investigation and replay
var dlqReceiver = client.CreateReceiver(
    "orders-queue",
    new ServiceBusReceiverOptions
    {
        SubQueue = SubQueue.DeadLetter
    }
);
```

---

## Gotchas

- **At-least-once delivery means duplicates are normal.** If a consumer crashes after processing but before acknowledging, the message gets redelivered. Your consumers must be idempotent — processing the same message twice should produce the same result as processing it once.
- **Message ordering is not guaranteed by default.** Most queues process messages roughly in order but make no hard guarantee. If order matters, you need partitioned queues with a partition key, or a different tool entirely.
- **Dead-letter queues need active monitoring.** Messages end up there silently when they fail repeatedly. If nobody watches the DLQ, failures disappear and you lose data with no alert.
- **Large payloads don't belong in the message body.** Most queues have size limits (256KB for SQS, 1MB for Service Bus). Store the payload in blob storage and put only the reference in the message.
- **Consumer scaling requires coordination.** If you scale to 20 consumers on a queue with only 5 partitions, 15 consumers sit idle. Understand the concurrency model of your specific queue before scaling horizontally.

---

## Interview Angle

**What they're really testing:** Whether you understand eventual consistency tradeoffs and the operational realities of async systems.

**Common question form:** "How would you design an order processing system?" or "How do you handle failures in an async workflow?"

**The depth signal:** A junior says message queues decouple services and improve reliability. A senior specifies idempotency as a requirement (not an optimization), explains dead-letter queue monitoring as a production necessity, describes the exactly-once vs at-least-once delivery distinction and why most queues only offer the latter, and can explain how to handle poison messages that repeatedly fail without blocking the queue.

---

## Related Topics

- [[system-design/kafka.md]] — Kafka is a log-based alternative to traditional queues; understanding both lets you choose correctly
- [[system-design/rabbitmq.md]] — RabbitMQ is a classic broker with richer routing than most cloud queues
- [[system-design/event-driven-architecture.md]] — message queues are one of the building blocks of event-driven systems

---

## Source

https://aws.amazon.com/message-queue/

---

*Last updated: 2026-03-24*