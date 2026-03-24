# Observer Pattern

> An observer is an object that gets notified automatically when something it's watching changes state.

---

## When To Use It
Use it when a change in one part of the system needs to trigger reactions in other parts, and you don't want the source to know or care what those reactions are. It's the right move for event-driven side effects — sending emails when an order is placed, updating a cache when a record changes, pushing UI updates when data changes. Don't use it when the reaction is a single, fixed, synchronous step that belongs directly in the same flow — at that point you're adding indirection with no decoupling benefit.

---

## Core Concept
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
// 2. IObservable<T> / IObserver<T> — for push-based data streams
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

    private class Unsubscriber : IDisposable
    {
        private readonly List<IObserver<float>> _observers;
        private readonly IObserver<float> _observer;

        public Unsubscriber(List<IObserver<float>> observers, IObserver<float> observer)
        {
            _observers = observers;
            _observer = observer;
        }

        public void Dispose() => _observers.Remove(_observer);
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
// 3. MediatR INotification — the idiomatic ASP.NET Core approach
public record OrderPlacedNotification(int OrderId, string CustomerEmail) : INotification;

// Observer 1
public class SendConfirmationEmailHandler : INotificationHandler<OrderPlacedNotification>
{
    private readonly IEmailService _email;
    public SendConfirmationEmailHandler(IEmailService email) => _email = email;

    public Task Handle(OrderPlacedNotification n, CancellationToken ct) =>
        _email.SendAsync(n.CustomerEmail, $"Order {n.OrderId} confirmed.");
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
public class OrderService
{
    private readonly IMediator _mediator;
    public OrderService(IMediator mediator) => _mediator = mediator;

    public async Task PlaceOrderAsync(Order order)
    {
        // ... save order ...
        await _mediator.Publish(new OrderPlacedNotification(order.Id, order.CustomerEmail));
    }
}
```
```csharp
// 4. Domain events — raise events on the entity, dispatch after SaveChanges
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

// In your repository or SaveChanges override — dispatch after commit
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
- **C# `event` subscriptions are strong references — forgetting to unsubscribe causes memory leaks.** If a short-lived observer subscribes to a long-lived subject's event and never unsubscribes, the subject holds a reference to the observer indefinitely. Always unsubscribe in `Dispose()` or use weak event patterns.
- **MediatR `Publish()` handlers run sequentially and exceptions in one handler abort the rest.** If `SendConfirmationEmailHandler` throws, `UpdateInventoryHandler` never runs. Wrap individual handlers in try/catch, or implement a custom `INotificationPublisher` that runs handlers in parallel with independent error handling.
- **Domain events dispatched before `SaveChanges` means side effects fire even if the commit fails.** If the email goes out but the database write rolls back, you've sent a confirmation for an order that doesn't exist. Always dispatch domain events *after* a successful commit.
- **`IObservable<T>` is correct for streaming data; it's overkill for discrete business events.** Implementing `IObservable<T>` manually is verbose and error-prone. Use it only when you genuinely need Rx operators (throttle, buffer, merge). For business events, MediatR notifications are the right tool.
- **Multiple `INotificationHandler<T>` registrations for the same notification are silent.** Unlike `IRequest<T>` (which throws if zero or multiple handlers exist), zero notification handlers is valid in MediatR — the publish call succeeds and nothing happens. A missing handler registration produces no error, only missing behavior.

---

## Interview Angle
**What they're really testing:** Whether you understand event-driven decoupling — specifically, how to let a subject trigger reactions without depending on what those reactions are — and the tradeoffs between the three .NET shapes.

**Common question form:** *"How would you design an order placement flow where placing an order triggers emails, inventory updates, and analytics logging?"* or *"What's the observer pattern and how does it appear in C#?"*

**The depth signal:** A junior describes C# `event` and shows a subscription. A senior distinguishes the three shapes — language events (tight scope, memory leak risk), `IObservable<T>` (streaming, Rx), and MediatR notifications (DI-friendly, async, most appropriate for business events in APIs) — and knows the domain event timing problem: dispatching before commit fires side effects against uncommitted state, so events must be collected on the entity and dispatched only after a successful `SaveChanges`.

---

## Related Topics
- [[dotnet/pattern-mediator.md]] — MediatR's `INotification` is the most common implementation of the observer pattern in ASP.NET Core; understanding mediator clarifies how dispatch works.
- [[dotnet/pattern-cqrs.md]] — Domain events raised on the write side are the bridge between CQRS commands and downstream read-model updates or side effects.
- [[dotnet/ef-transactions.md]] — Domain event dispatch timing is directly tied to transaction commit; dispatching inside vs outside a transaction changes whether side effects are safe.
- [[system-design/event-sourcing.md]] — Event sourcing takes the observer pattern to its logical extreme — every state change is an event, and the current state is reconstructed by replaying them.

---

## Source
https://learn.microsoft.com/en-us/dotnet/standard/events/observer-design-pattern

---
*Last updated: 2026-03-24*