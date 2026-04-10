# Outbox Pattern

> The outbox pattern guarantees that a message is published if and only if the local database transaction commits — by writing the message to the database in the same transaction, then delivering it asynchronously.

---

## When To Use It

Use it when you need to reliably publish an event or message after a database write, and you can't tolerate losing that message if the process crashes between the write and the publish. The classic failure case: `SaveChanges()` succeeds, then the process crashes before `mediator.Publish()` fires — the order is saved but no confirmation email goes out, no inventory is decremented, no downstream service is notified. The outbox closes that gap. Don't use it when your side effects are idempotent and occasional delivery failure is acceptable, or when you're publishing to an in-process MediatR handler that doesn't cross a durability boundary — in those cases the overhead isn't justified.

---

## Core Concept

**One sentence for the interview:** Write the event to the database in the same transaction as the business change — a background process delivers it after the fact, so the event is never lost even if the process crashes.

The idea is simple. Instead of publishing an event immediately after saving, you write the event as a row into an `OutboxMessages` table in the same database transaction as your domain change. Both commits or both roll back — atomically. A separate background worker polls the `OutboxMessages` table, picks up unprocessed rows, publishes them to the real destination (message broker, event bus, another service), and marks them as processed. The hard part isn't the pattern — it's the delivery guarantee. The outbox gives you **at-least-once** delivery, not exactly-once. The worker may publish a message, then crash before marking it processed — so it gets published again on the next run. Every consumer must be **idempotent**: processing the same message twice must produce the same result as processing it once.

---

## The Code

```csharp
// 1. OutboxMessage entity — lives in the same database as your domain
public class OutboxMessage
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public string Type { get; init; } = default!;       // fully qualified event type name
    public string Payload { get; init; } = default!;    // JSON-serialized event
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;
    public DateTime? ProcessedAt { get; set; }          // null = not yet delivered
    public string? Error { get; set; }                  // last error if processing failed
    public int RetryCount { get; set; }
}
```

```csharp
// 2. EF Core configuration
public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OutboxMessage> OutboxMessages => Set<OutboxMessage>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<OutboxMessage>(e =>
        {
            e.HasKey(m => m.Id);
            e.HasIndex(m => m.ProcessedAt);  // index on ProcessedAt — worker queries unprocessed
            e.Property(m => m.Payload).HasMaxLength(8000);
        });
    }
}
```

```csharp
// 3. Writing to the outbox in the same transaction as the domain change
public class CreateOrderHandler(AppDbContext context) : IRequestHandler<CreateOrderCommand, int>
{
    public async Task<int> Handle(CreateOrderCommand cmd, CancellationToken ct)
    {
        var order = new Order { CustomerId = cmd.CustomerId, Total = cmd.Total };
        context.Orders.Add(order);

        // Serialize the domain event into the outbox — same transaction as the order insert
        var outboxMessage = new OutboxMessage
        {
            Type = typeof(OrderCreatedEvent).AssemblyQualifiedName!,
            Payload = JsonSerializer.Serialize(new OrderCreatedEvent(order.Id, cmd.CustomerId))
        };
        context.OutboxMessages.Add(outboxMessage);

        await context.SaveChangesAsync(ct);  // both order AND outbox message commit atomically
        return order.Id;
    }
}
```

```csharp
// 4. Outbox processor — background worker that delivers messages
public class OutboxProcessor(
    IServiceScopeFactory scopeFactory,
    ILogger<OutboxProcessor> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await ProcessBatchAsync(stoppingToken);
            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        }
    }

    private async Task ProcessBatchAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var publisher = scope.ServiceProvider.GetRequiredService<IEventPublisher>();

        // Fetch a batch of unprocessed messages — ordered by creation time
        var messages = await context.OutboxMessages
            .Where(m => m.ProcessedAt == null && m.RetryCount < 5)
            .OrderBy(m => m.CreatedAt)
            .Take(20)
            .ToListAsync(ct);

        foreach (var message in messages)
        {
            try
            {
                await publisher.PublishAsync(message.Type, message.Payload, ct);

                message.ProcessedAt = DateTime.UtcNow;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to publish outbox message {Id}", message.Id);
                message.Error = ex.Message;
                message.RetryCount++;
            }
        }

        await context.SaveChangesAsync(ct);  // mark processed in one batch save
    }
}
```

```csharp
// 5. IEventPublisher — delivers the serialized message to the real destination
public interface IEventPublisher
{
    Task PublishAsync(string type, string payload, CancellationToken ct);
}

// MediatR implementation — in-process delivery
public class MediatREventPublisher(IMediator mediator) : IEventPublisher
{
    public async Task PublishAsync(string type, string payload, CancellationToken ct)
    {
        var eventType = Type.GetType(type)
            ?? throw new InvalidOperationException($"Cannot resolve type: {type}");

        var @event = JsonSerializer.Deserialize(payload, eventType) as INotification
            ?? throw new InvalidOperationException($"Cannot deserialize as INotification: {type}");

        await mediator.Publish(@event, ct);
    }
}

// Message broker implementation — cross-service delivery
public class ServiceBusEventPublisher(ServiceBusClient client) : IEventPublisher
{
    public async Task PublishAsync(string type, string payload, CancellationToken ct)
    {
        var sender = client.CreateSender(TopicFor(type));
        var message = new ServiceBusMessage(payload)
        {
            Subject = type,
            MessageId = Guid.NewGuid().ToString()   // idempotency key for the broker
        };
        await sender.SendMessageAsync(message, ct);
    }

    private static string TopicFor(string type) =>
        type.Split('.').Last().ToLowerInvariant();  // e.g., "OrderCreatedEvent" → "ordercreatedevent"
}
```

```csharp
// 6. Idempotency on the consumer side — processing twice = same result as processing once
public class OrderCreatedEventHandler : INotificationHandler<OrderCreatedEvent>
{
    private readonly IInventoryRepository _inventory;
    private readonly IProcessedEventRepository _processedEvents;

    public OrderCreatedEventHandler(
        IInventoryRepository inventory,
        IProcessedEventRepository processedEvents)
    {
        _inventory = inventory;
        _processedEvents = processedEvents;
    }

    public async Task Handle(OrderCreatedEvent notification, CancellationToken ct)
    {
        // Check if already processed — idempotency guard
        if (await _processedEvents.ExistsAsync(notification.EventId, ct))
            return;

        await _inventory.DecrementAsync(notification.ProductId, notification.Quantity, ct);

        // Record that this event was processed — prevent duplicate side effects
        await _processedEvents.RecordAsync(notification.EventId, ct);
    }
}
```

```csharp
// 7. MassTransit Outbox — library-level outbox if you don't want to hand-roll
// dotnet add package MassTransit.EntityFrameworkCore
builder.Services.AddMassTransit(x =>
{
    x.AddEntityFrameworkOutbox<AppDbContext>(o =>
    {
        o.UseSqlServer();
        o.UseBusOutbox();                           // automatically writes to outbox on publish
    });

    x.UsingRabbitMq((ctx, cfg) =>
    {
        cfg.Host("rabbitmq://localhost");
        cfg.ConfigureEndpoints(ctx);
    });
});

// With MassTransit Outbox configured, publishing an event inside a handler
// automatically goes through the outbox — no manual OutboxMessage rows needed
public class CreateOrderHandler(IPublishEndpoint publisher, AppDbContext context)
    : IRequestHandler<CreateOrderCommand, int>
{
    public async Task<int> Handle(CreateOrderCommand cmd, CancellationToken ct)
    {
        var order = new Order { CustomerId = cmd.CustomerId, Total = cmd.Total };
        context.Orders.Add(order);

        // MassTransit writes this to the outbox table automatically, in the same transaction
        await publisher.Publish(new OrderCreatedEvent(order.Id, cmd.CustomerId), ct);

        await context.SaveChangesAsync(ct);
        return order.Id;
    }
}
```

---

## Gotchas

- **At-least-once delivery is the guarantee — not exactly-once.** The outbox worker may publish a message and then crash before marking it as processed. On restart it publishes again. Every consumer must be idempotent. If your consumer isn't idempotent, you don't have a reliable system — you just moved the problem downstream.

- **The outbox table grows without a cleanup job.** Processed messages accumulate. Add a scheduled job (a second `BackgroundService` or a SQL Agent job) that deletes rows older than your retention window (e.g., 7 days). Without this, the table becomes a performance liability for the processor's `WHERE ProcessedAt IS NULL` query.

- **Concurrent workers produce duplicate delivery.** If you run two instances of the processor and both pick up the same unprocessed message, both will try to publish it. Use optimistic concurrency (`ROWVERSION`) or pessimistic locking (`SELECT ... WITH (UPDLOCK, READPAST)` in SQL Server) to ensure a message is claimed by exactly one worker per delivery attempt.

- **Long polling intervals mean delayed delivery.** A 5-second poll means events may be delivered up to 5 seconds after the transaction commits. If your domain requires near-realtime delivery, use Change Data Capture (CDC) with Debezium to watch the outbox table and publish on insert — sub-second latency without polling overhead.

- **`Type.GetType()` on `AssemblyQualifiedName` breaks across assembly versions.** If you store `MyApp.Events.OrderCreatedEvent, MyApp, Version=1.0.0.0, ...` and then rename the class or bump the assembly version, deserialization fails for all unprocessed messages at the time of deployment. Use a stable type discriminator string (e.g., `"order.created"`) mapped to the actual type, not the CLR type name directly.

- **Don't use the outbox for in-process MediatR handlers.** If your "side effect" is a MediatR notification handler in the same process that runs synchronously and in-memory, the outbox adds database overhead for a problem that doesn't need database durability. The outbox is for crossing a durability boundary — process restart, network call, external service.

---

## Interview Angle

**What they're really testing:** Whether you understand the gap in the naive "save then publish" approach, and that solving it requires atomic writes, not just careful ordering.

**Common question form:** *"How do you reliably publish an event after saving to the database?"* or *"What is the Transactional Outbox pattern?"* or *"How do you prevent losing domain events on process crash?"*

**The depth signal:** A junior says "publish the event after `SaveChanges()`." A senior identifies the gap immediately — the window between `SaveChanges()` and `Publish()` where a crash loses the event — then describes the outbox: write the event to a table in the same transaction, deliver via a background worker, accept at-least-once delivery, and make consumers idempotent. They also know the polling vs CDC tradeoff and can name MassTransit as a library-level alternative to hand-rolling.

**Follow-up the interviewer asks next:** *"How do you handle duplicate message delivery on the consumer side?"*

The standard answer is an idempotency key — a unique identifier on the event (e.g., `EventId: Guid`) that the consumer records in a `ProcessedEvents` table after handling. Before processing, the consumer checks if the ID was already recorded. If yes, skip. If no, process and record. The check-then-process must itself be atomic (a database transaction or an upsert with a unique constraint on `EventId`) or a concurrent duplicate delivery can slip through the check. Libraries like MassTransit handle this for you with their built-in consumer outbox.

---

## Related Topics

- [[dotnet/pattern/pattern-observer.md]] — Domain events dispatched in-process (MediatR `Publish`) have no durability guarantee; the outbox is the solution when durability is required.
- [[dotnet/pattern/pattern-domain-events.md]] — Domain events are what go into the outbox; understanding how entities raise and collect them is the prerequisite.
- [[dotnet/ef/ef-transactions.md]] — The outbox relies on writing both the domain change and the outbox row in a single transaction; understanding EF transaction scope is essential.
- [[dotnet/webapi/webapi-background-services.md]] — The outbox processor is a `BackgroundService`; understanding hosted service lifetime and `IServiceScopeFactory` is required to implement it correctly.

---

## Source

https://microservices.io/patterns/data/transactional-outbox.html

---

*Last updated: 2026-04-09*