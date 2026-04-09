# Observer Pattern

> An observer is an object that gets notified automatically when something it's watching changes state.

---

## When To Use It

Use it when a change in one part of the system needs to trigger reactions in other parts, and you don't want the source to know or care what those reactions are. It's the right move for event-driven side effects — sending emails when an order is placed, updating a cache when a record changes, pushing UI updates when data changes. Don't use it when the reaction is a single, fixed, synchronous step that belongs directly in the same flow — at that point you're adding indirection with no decoupling benefit.

---

## Core Concept

**One sentence for the interview:** The subject fires an event; observers react — the subject never imports or references any observer directly.

The subject (the thing being watched) holds a list of observers. When something meaningful happens, it loops through that list and calls a method on each one. The subject doesn't import or reference any observer directly — it only knows about the interface. Adding a new reaction means adding a new observer class and registering it, not editing the subject. In .NET this pattern has three common shapes: the built-in `IObservable<T>`/`IObserver<T>` interfaces (pull-based Rx-style), C# `event` and `EventHandler<T>` (built into the language, most familiar), and MediatR `INotification`/`INotificationHandler<T>` (in-process, DI-friendly, what most ASP.NET Core apps use). Each shape trades off ceremony for control.

---

## The Code

```csharp
// 1. C# events — language-native observer, best for UI or tightly scoped domains
public class OrderProcessor
{
    public event EventHandler<OrderPlacedEventArgs>? OrderPlaced;  // observers subscribe here

    public void PlaceOrder(Order order)
    {
        // ... process order ...
        OnOrderPlaced(new OrderPlacedEventArgs(order.Id));
    }

    protected virtual void OnOrderPlaced(OrderPlacedEventArgs e) =>
        OrderPlaced?.Invoke(this, e);                              // null-safe invocation
}

public class OrderPlacedEventArgs : EventArgs
{
    public int OrderId { get; }
    public OrderPlacedEventArgs(int orderId) => OrderId = orderId;
}

// Subscriber — wires up at runtime
var processor = new OrderProcessor();
processor.OrderPlaced += (sender, e) =>
    Console.WriteLine($"Email sent for order {e.OrderId}");
```

```csharp
// 2. Weak event pattern — prevents memory leaks from long-lived subjects
// Standard subscription holds a strong reference to the observer — observer never GCs
// Weak reference lets the observer be collected when nothing else holds it

public class WeakEventManager<TEventArgs>
{
    private readonly List<WeakReference<EventHandler<TEventArgs>>> _handlers = new();

    public void Subscribe(EventHandler<TEventArgs> handler) =>
        _handlers.Add(new WeakReference<EventHandler<TEventArgs>>(handler));

    public void Unsubscribe(EventHandler<TEventArgs> handler) =>
        _handlers.RemoveAll(wr =>
            !wr.TryGetTarget(out var h) || h == handler);

    public void Raise(object sender, TEventArgs args)
    {
        _handlers.RemoveAll(wr => !wr.TryGetTarget(out _));  // prune dead references
        foreach (var wr in _handlers)
            if (wr.TryGetTarget(out var handler))
                handler(sender, args);
    }
}
```

```csharp
// 3. IObservable<T> / IObserver<T> — for push-based data streams
public class TemperatureSensor : IObservable<float>
{
    private readonly List<IObserver<float>> _observers = new();

    public IDisposable Subscribe(IObserver<float> observer)
    {
        _observers.Add(observer);
        return new Unsubscriber(_observers, observer);             // caller disposes to unsubscribe
    }

    public void RecordReading(float celsius)
    {
        foreach (var o in _observers) o.OnNext(celsius);
    }

    private class Unsubscriber(
        List<IObserver<float>> observers,
        IObserver<float> observer) : IDisposable
    {
        public void Dispose() => observers.Remove(observer);
    }
}

public class TemperatureLogger : IObserver<float>
{
    public void OnNext(float value) => Console.WriteLine($"Temp: {value}°C");
    public void OnError(Exception e) => Console.WriteLine($"Error: {e.Message}");
    public void OnCompleted() => Console.WriteLine("Stream ended.");
}
```

```csharp
// 4. MediatR INotification — the idiomatic ASP.NET Core approach
public record OrderPlacedNotification(int OrderId, string CustomerEmail) : INotification;

// Observer 1
public class SendConfirmationEmailHandler(IEmailService email)
    : INotificationHandler<OrderPlacedNotification>
{
    public Task Handle(OrderPlacedNotification n, CancellationToken ct) =>
        email.SendAsync(n.CustomerEmail, $"Order {n.OrderId} confirmed.");
}

// Observer 2 — completely separate, same notification
public class UpdateInventoryHandler : INotificationHandler<OrderPlacedNotification>
{
    public Task Handle(OrderPlacedNotification n, CancellationToken ct)
    {
        Console.WriteLine($"Inventory updated for order {n.OrderId}");
        return Task.CompletedTask;
    }
}

// Publisher — knows nothing about handlers
public class OrderService(IMediator mediator)
{
    public async Task PlaceOrderAsync(Order order)
    {
        // ... save order ...
        await mediator.Publish(new OrderPlacedNotification(order.Id, order.CustomerEmail));
    }
}
```

```csharp
// 5. Custom INotificationPublisher — parallel execution with independent error handling
// Default MediatR runs handlers sequentially; one failure aborts the rest
public class ParallelNotificationPublisher : INotificationPublisher
{
    public async Task Publish(
        IEnumerable<NotificationHandlerExecutor> handlerExecutors,
        INotification notification,
        CancellationToken ct)
    {
        var tasks = handlerExecutors.Select(async executor =>
        {
            try
            {
                await executor.HandlerCallback(notification, ct);
            }
            catch (Exception ex)
            {
                // Log but don't propagate — other handlers still run
                Console.WriteLine($"Handler failed: {ex.Message}");
            }
        });

        await Task.WhenAll(tasks);
    }
}

// Registration
builder.Services.AddMediatR(cfg =>
{
    cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly());
    cfg.NotificationPublisher = new ParallelNotificationPublisher();
});
```

```csharp
// 6. Domain events — raise on the entity, dispatch after SaveChanges
public class Order
{
    private readonly List<INotification> _domainEvents = new();
    public IReadOnlyList<INotification> DomainEvents => _domainEvents;

    public void Place()
    {
        // ... business logic ...
        _domainEvents.Add(new OrderPlacedNotification(Id, CustomerEmail));
    }

    public void ClearDomainEvents() => _domainEvents.Clear();
}

// In your DbContext SaveChanges override — dispatch AFTER commit
public override async Task<int> SaveChangesAsync(CancellationToken ct = default)
{
    var events = ChangeTracker.Entries<Order>()
        .SelectMany(e => e.Entity.DomainEvents)
        .ToList();

    var result = await base.SaveChangesAsync(ct);          // commit first

    foreach (var e in events)
        await _mediator.Publish(e, ct);                    // then dispatch events

    return result;
}
```

---

## Gotchas

- **C# `event` subscriptions are strong references — forgetting to unsubscribe causes memory leaks.** If a short-lived observer subscribes to a long-lived subject's event and never unsubscribes, the subject holds a reference to the observer indefinitely. Always unsubscribe in `Dispose()` or use the weak event pattern.

- **MediatR `Publish()` handlers run sequentially by default and exceptions in one handler abort the rest.** If `SendConfirmationEmailHandler` throws, `UpdateInventoryHandler` never runs. Wrap individual handlers in try/catch, or implement a custom `INotificationPublisher` that runs handlers in parallel with independent error handling.

- **Domain events dispatched before `SaveChanges` means side effects fire even if the commit fails.** If the email goes out but the database write rolls back, you've sent a confirmation for an order that doesn't exist. Always dispatch domain events *after* a successful commit.

- **`IObservable<T>` is correct for streaming data; it's overkill for discrete business events.** Implementing `IObservable<T>` manually is verbose and error-prone. Use it only when you genuinely need Rx operators (throttle, buffer, merge). For business events, MediatR notifications are the right tool.

- **MediatR `Publish()` with zero handlers registered succeeds silently.** Unlike `IRequest<T>` (which throws if no handler exists), zero `INotificationHandler<T>` registrations is valid — the publish call returns with no error and nothing happens. A missing handler registration produces no warning; you only discover it when the expected side effect doesn't occur.

- **Parallel handlers that modify shared state are not thread-safe.** If two handlers both write to the same `Dictionary` or in-memory list in a parallel publisher, you get race conditions. Handlers in a parallel publisher must be independently stateless, or use thread-safe collections.

---

## Interview Angle

**What they're really testing:** Whether you understand event-driven decoupling — specifically, how to let a subject trigger reactions without depending on what those reactions are — and the tradeoffs between the three .NET shapes.

**Common question form:** *"How would you design an order placement flow where placing an order triggers emails, inventory updates, and analytics logging?"* or *"What's the observer pattern and how does it appear in C#?"*

**The depth signal:** A junior describes C# `event` and shows a subscription. A senior distinguishes the three shapes — language events (tight scope, memory leak risk), `IObservable<T>` (streaming, Rx), and MediatR notifications (DI-friendly, async, most appropriate for business events in APIs) — and knows the domain event timing problem: dispatching before commit fires side effects against uncommitted state, so events must be collected on the entity and dispatched only after a successful `SaveChanges`.

**Follow-up the interviewer asks next:** *"How does the Transactional Outbox pattern solve the domain event timing problem?"*

The domain event approach (dispatch after `SaveChanges`) still has a gap: if the process crashes after `SaveChanges` but before `mediator.Publish()`, the event is lost — the order is saved but no email goes out. The Outbox pattern closes this gap by writing the event to an `OutboxMessages` table *in the same transaction* as the domain change. A separate background process (or MassTransit/NServiceBus Outbox feature) reads and publishes unprocessed outbox messages reliably. The event delivery is now at-least-once rather than at-most-once. For in-process handlers (MediatR) this gap is usually acceptable. For cross-service events that must not be lost, the outbox is the right answer.

---

## Related Topics

- [[dotnet/pattern/pattern-mediator.md]] — MediatR's `INotification` is the most common implementation of the observer pattern in ASP.NET Core; understanding mediator clarifies how dispatch works.
- [[dotnet/pattern/pattern-cqrs.md]] — Domain events raised on the write side are the bridge between CQRS commands and downstream read-model updates or side effects.
- [[dotnet/ef/ef-transactions.md]] — Domain event dispatch timing is directly tied to transaction commit; dispatching inside vs outside a transaction changes whether side effects are safe.

---

## Source

https://learn.microsoft.com/en-us/dotnet/standard/events/observer-design-pattern

---

*Last updated: 2026-04-09*