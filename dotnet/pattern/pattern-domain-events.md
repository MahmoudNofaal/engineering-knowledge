# Domain Events

> A domain event is a record of something meaningful that happened inside a domain aggregate — raised by the entity itself, dispatched after the transaction commits.

---

## When To Use It

Use domain events when a state change in one aggregate needs to trigger side effects in other parts of the system, and you want the aggregate to stay focused on its own invariants without knowing about those side effects. The right signal: you find yourself putting `emailService.Send()` or `inventoryService.Decrement()` inside a domain method, and it feels wrong. Those are side effects that belong elsewhere. Domain events let the aggregate say "this happened" and let handlers decide what to do about it. Don't use them for simple CRUD with no meaningful domain — if creating a record is just an INSERT with no business significance, a domain event is ceremony without value.

---

## Core Concept

**One sentence for the interview:** The aggregate raises the event; a handler — outside the aggregate — reacts to it after the transaction commits.

The pattern has three moving parts. First, the aggregate collects domain events in a list as part of executing business logic — it doesn't dispatch them immediately, it just records them. Second, after `SaveChanges()` commits the aggregate's state change, the infrastructure layer dispatches those collected events to handlers. Third, handlers react — sending emails, updating read models, triggering other aggregates — without the original aggregate knowing anything about them. The critical timing rule: dispatch after commit, not before. Dispatching before commit means side effects fire against state that may never persist. Dispatching after commit means the state is durable before any side effect runs.

The distinction between **domain events** and **integration events** matters at scale. Domain events are in-process signals within a bounded context — fast, synchronous, no serialization. Integration events cross service or process boundaries — they need to be serialized, durable, and delivered via a message broker. The Outbox pattern is what makes integration events reliable.

---

## The Code

```csharp
// 1. Base class for domain events
public abstract record DomainEvent
{
    public Guid EventId { get; init; } = Guid.NewGuid();
    public DateTime OccurredAt { get; init; } = DateTime.UtcNow;
}

// Concrete domain events — named in past tense (something that happened)
public record OrderPlacedEvent(int OrderId, int CustomerId, decimal Total) : DomainEvent;
public record OrderShippedEvent(int OrderId, string TrackingNumber) : DomainEvent;
public record OrderCancelledEvent(int OrderId, string Reason) : DomainEvent;
```

```csharp
// 2. Aggregate base — collects events, exposes them for dispatch
public abstract class AggregateRoot
{
    private readonly List<DomainEvent> _domainEvents = new();

    public IReadOnlyList<DomainEvent> DomainEvents => _domainEvents.AsReadOnly();

    protected void RaiseDomainEvent(DomainEvent @event) =>
        _domainEvents.Add(@event);

    public void ClearDomainEvents() =>
        _domainEvents.Clear();
}
```

```csharp
// 3. Aggregate — raises events as part of business logic, knows nothing about handlers
public class Order : AggregateRoot
{
    public int Id { get; private set; }
    public int CustomerId { get; private set; }
    public decimal Total { get; private set; }
    public OrderStatus Status { get; private set; }

    private Order() { }   // EF requires parameterless constructor

    public static Order Place(int customerId, decimal total)
    {
        if (total <= 0) throw new DomainException("Order total must be positive.");

        var order = new Order
        {
            CustomerId = customerId,
            Total = total,
            Status = OrderStatus.Pending
        };

        order.RaiseDomainEvent(new OrderPlacedEvent(order.Id, customerId, total));
        return order;
    }

    public void Ship(string trackingNumber)
    {
        if (Status != OrderStatus.Pending)
            throw new DomainException("Only pending orders can be shipped.");

        Status = OrderStatus.Shipped;
        RaiseDomainEvent(new OrderShippedEvent(Id, trackingNumber));
    }

    public void Cancel(string reason)
    {
        if (Status == OrderStatus.Shipped)
            throw new DomainException("Shipped orders cannot be cancelled.");

        Status = OrderStatus.Cancelled;
        RaiseDomainEvent(new OrderCancelledEvent(Id, reason));
    }
}
```

```csharp
// 4. Dispatching after SaveChanges — in the DbContext override
public class AppDbContext(
    DbContextOptions<AppDbContext> options,
    IMediator mediator) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();

    public override async Task<int> SaveChangesAsync(CancellationToken ct = default)
    {
        // Collect events BEFORE saving — entities may be detached after save
        var events = ChangeTracker
            .Entries<AggregateRoot>()
            .SelectMany(e => e.Entity.DomainEvents)
            .ToList();

        // Commit the state change first
        var result = await base.SaveChangesAsync(ct);

        // Dispatch events AFTER commit — side effects run against committed state
        foreach (var domainEvent in events)
            await mediator.Publish(domainEvent, ct);

        // Clear after dispatch — prevents double-dispatch on a second SaveChanges
        ChangeTracker
            .Entries<AggregateRoot>()
            .ToList()
            .ForEach(e => e.Entity.ClearDomainEvents());

        return result;
    }
}
```

```csharp
// 5. Domain event handlers — react to events, know nothing about the aggregate internals
public class SendOrderConfirmationHandler(IEmailService email)
    : INotificationHandler<OrderPlacedEvent>
{
    public async Task Handle(OrderPlacedEvent notification, CancellationToken ct)
    {
        await email.SendAsync(
            to: $"customer-{notification.CustomerId}@example.com",
            subject: $"Order {notification.OrderId} confirmed",
            body: $"Your order of ${notification.Total} has been placed.");
    }
}

public class UpdateInventoryOnOrderPlacedHandler(IInventoryRepository inventory)
    : INotificationHandler<OrderPlacedEvent>
{
    public async Task Handle(OrderPlacedEvent notification, CancellationToken ct)
    {
        await inventory.ReserveForOrderAsync(notification.OrderId, ct);
    }
}

// Multiple handlers for the same event — each adds a reaction without modifying Order
public class CreateShipmentHandler(IShippingService shipping)
    : INotificationHandler<OrderShippedEvent>
{
    public async Task Handle(OrderShippedEvent notification, CancellationToken ct)
    {
        await shipping.CreateShipmentAsync(notification.OrderId, notification.TrackingNumber, ct);
    }
}
```

```csharp
// 6. Domain events vs integration events — the boundary matters
// Domain event — in-process, fast, no serialization needed
public record OrderPlacedEvent(int OrderId, int CustomerId, decimal Total) : DomainEvent;

// Integration event — crosses process/service boundary, needs to be serialized and durable
// Typically raised by a domain event handler that converts the domain event to an integration event
public record OrderPlacedIntegrationEvent(int OrderId, string CustomerEmail, decimal Total);

public class PublishOrderPlacedIntegrationEventHandler(IEventPublisher publisher)
    : INotificationHandler<OrderPlacedEvent>
{
    public async Task Handle(OrderPlacedEvent @event, CancellationToken ct)
    {
        // Convert domain event → integration event and publish to the outbox/message broker
        var integrationEvent = new OrderPlacedIntegrationEvent(
            @event.OrderId,
            CustomerEmail: $"customer-{@event.CustomerId}@example.com",
            @event.Total);

        await publisher.PublishAsync(integrationEvent, ct);
    }
}
```

```csharp
// 7. Alternative dispatch — domain event dispatcher as a separate service
// Useful when you don't want dispatch logic in DbContext
public interface IDomainEventDispatcher
{
    Task DispatchAsync(IEnumerable<DomainEvent> events, CancellationToken ct);
}

public class MediatRDomainEventDispatcher(IMediator mediator) : IDomainEventDispatcher
{
    public async Task DispatchAsync(IEnumerable<DomainEvent> events, CancellationToken ct)
    {
        foreach (var @event in events)
            await mediator.Publish(@event, ct);
    }
}

// In the command handler — explicit control over when dispatch happens
public class ShipOrderHandler(
    IOrderRepository orders,
    IDomainEventDispatcher dispatcher) : IRequestHandler<ShipOrderCommand>
{
    public async Task Handle(ShipOrderCommand cmd, CancellationToken ct)
    {
        var order = await orders.GetByIdAsync(cmd.OrderId, ct)
            ?? throw new NotFoundException($"Order {cmd.OrderId} not found.");

        order.Ship(cmd.TrackingNumber);
        await orders.SaveChangesAsync(ct);           // commit first

        await dispatcher.DispatchAsync(order.DomainEvents, ct); // dispatch after
        order.ClearDomainEvents();
    }
}
```

---

## Gotchas

- **Dispatch before commit fires side effects against uncommitted state.** If `mediator.Publish()` runs before `SaveChanges()`, the email goes out for an order that may never be saved. Always commit first, dispatch second. If `SaveChanges()` fails, the events should be silently dropped — they represent state that didn't happen.

- **`DomainEvents` must be collected before `SaveChanges()` in the DbContext override.** After `base.SaveChangesAsync()`, EF may detach or clear entity state. Collect the events list before the base call, dispatch after. Getting this order wrong means dispatching an empty event list.

- **Forgetting to call `ClearDomainEvents()` causes double-dispatch on a second `SaveChanges()`.** If a command handler calls `SaveChanges()` twice (once for the order, once for a separate concern), the events from the first save get dispatched again on the second. Always clear after dispatch.

- **Domain event handlers that throw abort the entire dispatch sequence.** MediatR's `Publish()` runs handlers sequentially by default. If `SendOrderConfirmationHandler` throws, `UpdateInventoryOnOrderPlacedHandler` never runs — and the order is already committed. Use a parallel publisher with per-handler exception isolation, or wrap each handler in try/catch.

- **Domain events carry value object data, not entity references.** The handler receives `OrderPlacedEvent(OrderId: 42, CustomerId: 7, Total: 150m)` — not an `Order` entity. The handler loads whatever it needs from its own repositories using those IDs. Passing entity references into events creates tight coupling between aggregates and risks working with stale data.

- **In-process domain events provide no durability across process boundaries.** A domain event dispatched via MediatR dies with the process. If the side effect must survive a crash or reach another service, the domain event handler should write to an Outbox, not perform the side effect directly. Domain events + Outbox are a common combination — domain events for internal reactions, Outbox for external integration events.

---

## Interview Angle

**What they're really testing:** Whether you understand aggregate boundaries, event timing, and the distinction between in-process domain events and durable integration events.

**Common question form:** *"How do you trigger side effects after saving a domain aggregate without coupling the aggregate to those side effects?"* or *"What is a domain event and how does it differ from an integration event?"*

**The depth signal:** A junior injects `IEmailService` into the aggregate or the handler calls downstream services directly. A senior raises a domain event on the aggregate, dispatches after `SaveChanges()`, and keeps handlers decoupled. They also distinguish domain events (in-process, fast, no durability guarantee) from integration events (cross-service, serialized, delivered via outbox or message broker) — and explain the timing rule: commit first, dispatch second.

**Follow-up the interviewer asks next:** *"What happens if a domain event handler throws — how do you prevent one failing handler from aborting the others?"*

Two options. First, implement a custom `INotificationPublisher` in MediatR that runs handlers in parallel with independent try/catch per handler — failures are logged but don't propagate. Second, use the Outbox pattern: the domain event handler writes to the outbox rather than performing the side effect directly, and the outbox processor retries failed deliveries with backoff. The second approach is more robust because it also handles process crashes between dispatch and handler execution — something the in-process parallel publisher can't help with.

---

## Related Topics

- [[dotnet/pattern/pattern-outbox.md]] — The outbox is how domain events become durable integration events; the two patterns are the standard combination for reliable cross-service communication.
- [[dotnet/pattern/pattern-observer.md]] — Domain events are the DDD-specific application of the observer pattern; `INotification` + `INotificationHandler<T>` is the MediatR implementation of that.
- [[dotnet/pattern/pattern-cqrs.md]] — Domain events are raised on the command side and drive updates on the read side; the two patterns are complementary in any CQRS architecture.
- [[dotnet/pattern/pattern-clean-architecture.md]] — Domain events belong in the Domain layer; handlers belong in the Application layer; the infrastructure (DbContext dispatch, outbox) belongs in Infrastructure.

---

## Source

https://martinfowler.com/eaaDev/DomainEvent.html

---

*Last updated: 2026-04-09*