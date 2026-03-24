# Event-Driven Architecture

> A design pattern where services communicate by emitting and reacting to events rather than calling each other directly.

---

## When To Use It

Use event-driven architecture when you want services to be truly independent — able to deploy, scale, and fail without affecting each other. It's well-suited for workflows that involve multiple downstream systems reacting to the same thing (order placed → billing, inventory, email all react). Don't use it when you need a synchronous response — if the user is waiting on screen for a result, a direct call is simpler and more appropriate. Avoid it in small systems where the added complexity of brokers, schemas, and eventual consistency outweighs the benefits.

---

## Core Concept

In a traditional system, Service A calls Service B directly. A knows about B, waits for B's response, and fails if B is down. In an event-driven system, A emits an event ("OrderPlaced") to a broker and moves on. B, C, and D each listen for that event and react in their own way, independently. A doesn't know they exist. This means you can add new consumers without touching the producer, scale each service separately, and absorb failures — if D is down, it catches up when it comes back. The cost is that the system is eventually consistent: you can't guarantee all consumers have processed the event by the time A finishes.

---

## The Code

**Event definition — shared contract**
```csharp
// Shared library or NuGet package — both producer and consumers reference this
public record OrderPlacedEvent(
    Guid OrderId,
    string CustomerId,
    decimal Total,
    DateTimeOffset PlacedAt
);
```

**Producer — emit event after business logic**
```csharp
public class OrderService
{
    private readonly IMessageBus _bus;

    public async Task PlaceOrderAsync(PlaceOrderCommand cmd)
    {
        var order = await SaveOrderToDatabase(cmd);

        // Emit — don't call billing, inventory, email directly
        await _bus.PublishAsync(new OrderPlacedEvent(
            OrderId: order.Id,
            CustomerId: cmd.CustomerId,
            Total: order.Total,
            PlacedAt: DateTimeOffset.UtcNow
        ));
    }
}
```

**Consumer — react independently**
```csharp
public class InventoryService : IEventHandler<OrderPlacedEvent>
{
    public async Task HandleAsync(OrderPlacedEvent evt)
    {
        await ReserveInventory(evt.OrderId);
    }
}

public class EmailService : IEventHandler<OrderPlacedEvent>
{
    public async Task HandleAsync(OrderPlacedEvent evt)
    {
        await SendConfirmationEmail(evt.CustomerId, evt.OrderId);
    }
}
```

**Idempotency guard — handle duplicate delivery**
```csharp
public async Task HandleAsync(OrderPlacedEvent evt)
{
    // Check if already processed before doing work
    if (await _processedEvents.ExistsAsync(evt.OrderId)) return;

    await ReserveInventory(evt.OrderId);

    await _processedEvents.MarkAsync(evt.OrderId);
}
```

---

## Gotchas

- **Eventual consistency is not optional — it's the contract.** When Order Service emits an event and returns success to the user, Inventory may not have updated yet. UI, support workflows, and SLAs all need to account for this lag.
- **Event schema changes break consumers silently.** Renaming a field or changing a type in an event doesn't cause a compile error in the consumer — it causes a runtime deserialization failure or silent data corruption. Treat event schemas like public APIs: add fields, never remove or rename.
- **The Outbox pattern is necessary for true reliability.** If your service saves to the database and then publishes to the broker in two separate steps, a crash between the two causes data inconsistency. Write the event to an outbox table in the same transaction, then publish from there via a background job.
- **Debugging is hard.** A request that used to be one HTTP call is now an event flowing through multiple services. Distributed tracing (correlation IDs on every event, OpenTelemetry) is not optional in production — it's how you answer "why did this order not get an email?"
- **Consumer failures need explicit handling.** If a consumer fails processing an event, do you retry? How many times? With what backoff? Where do poison events go? These decisions must be made upfront, not after the first production incident.

---

## Interview Angle

**What they're really testing:** Whether you understand the decoupling tradeoffs and the operational complexity that comes with them — not just that "events are async."

**Common question form:** "Design an order processing system" or "How would you decouple microservices?"

**The depth signal:** A junior says event-driven means services are decoupled and don't depend on each other. A senior introduces the Outbox pattern as the solution to dual-write inconsistency, explains idempotency as a consumer requirement (not a nice-to-have), describes correlation IDs and distributed tracing as operational necessities, and can articulate exactly what "eventual consistency" means for a user-facing feature and how the product must be designed around it.

---

## Related Topics

- [[system-design/kafka.md]] — Kafka is the most common event backbone for high-throughput event-driven systems
- [[system-design/rabbitmq.md]] — RabbitMQ is a common broker choice for event-driven systems with complex routing needs
- [[system-design/message-queues.md]] — message queues are the transport layer underlying most event-driven implementations
- [[system-design/websockets.md]] — WebSockets are often how event-driven backend changes are pushed to the frontend in real time

---

## Source

https://martinfowler.com/articles/201701-event-driven.html

---

*Last updated: 2026-03-24*