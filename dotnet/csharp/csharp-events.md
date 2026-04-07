# C# Events

> An event is a multicast delegate field wrapped with access control so external subscribers can only add and remove handlers — never invoke the list or replace it entirely.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Multicast delegate with restricted external access (`+=`/`-=` only) |
| **Use when** | One object needs to notify unknown listeners that something happened |
| **Avoid when** | Return value needed from subscribers; you control both publisher and subscriber |
| **C# version** | C# 1.0 |
| **Namespace** | `System` |
| **Standard signature** | `EventHandler<TEventArgs>` where `TEventArgs : EventArgs` |

---

## When To Use It

Use events when an object needs to notify one or more unknown listeners that something happened, without knowing or caring who is listening. The classic cases: UI interactions (button clicked), domain model notifications (order placed, payment received), progress reporting in long-running operations.

**Don't use events when:**
- You need a return value from subscribers — use a delegate or interface method instead
- You control both publisher and subscriber in the same class — a direct method call is simpler
- The notification pattern requires guaranteed delivery order — events don't guarantee order
- You're building async notification — consider `IObservable<T>` or `Channel<T>` instead

**The memory leak risk:** Event subscribers create a GC root on the publisher. If a short-lived subscriber subscribes to an event on a long-lived publisher and never unsubscribes, the publisher holds a delegate reference keeping the subscriber alive indefinitely. Always unsubscribe when the subscriber is disposed.

---

## Core Concept

When you write `public event Action<string> Clicked`, the compiler generates:
1. A `private` multicast delegate field (the actual subscriber list)
2. A `public void add_Clicked(Action<string> handler)` method (called by `+=`)
3. A `public void remove_Clicked(Action<string> handler)` method (called by `-=`)

External code can only reach `add` and `remove` — it cannot read the current subscriber list, invoke the event, or replace it with `=`. The class that declares the event is the only one that can fire it by calling the private delegate field directly. This enforced asymmetry is the entire point of the `event` keyword.

Without `event`, a bare `public Func<string>` field lets any caller invoke it, replace it (`obj.Transform = null`), and wipe all subscribers silently.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | `event` keyword, multicast delegates, `EventHandler` pattern |
| C# 2.0 | .NET 2.0 | `EventHandler<TEventArgs>` generic — eliminates custom delegate types |
| C# 6.0 | .NET 4.6 | `?.Invoke()` — null-safe, thread-safe invocation pattern |
| C# 8.0 | .NET Core 3.0 | Nullable reference types — event fields now `event Action? Clicked` |

*Before C# 6's `?.Invoke()`, safe event invocation required copying the delegate to a local variable first, then null-checking the copy. `?.Invoke()` does this atomically in one operation and is now the standard.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Subscribe (`+=`) | O(1) — creates new multicast chain | Small allocation for new delegate |
| Unsubscribe (`-=`) | O(n) invocation list scan | Finds and removes the matching delegate |
| Fire event (`?.Invoke`) | O(n) subscribers | Each subscriber called in order |
| No subscribers | O(1) — null check exits immediately | `?.Invoke()` short-circuits on null |
| Thread-safe subscription | Requires `lock` or `Interlocked` | Default event is not thread-safe |

**Allocation behaviour:** Each `+=` subscription creates a new multicast delegate chain. Each handler closure allocates a display class if it captures variables. The `?.Invoke()` pattern makes a null-check copy internally but doesn't allocate.

**Benchmark notes:** Event invocation is O(n) subscribers. For events fired at high frequency (e.g., per-frame game events), the subscriber count directly impacts performance. For UI and domain events fired occasionally, the cost is negligible.

---

## The Code

**Minimal event with `Action` — simple scenarios**
```csharp
public class DownloadService
{
    // Null when no subscribers — always use ?.Invoke()
    public event Action<int>?     ProgressChanged; // percent 0–100
    public event Action<string>?  Completed;
    public event Action<Exception>? Failed;

    public async Task DownloadAsync(string url, CancellationToken ct = default)
    {
        try
        {
            for (int i = 0; i <= 100; i += 10)
            {
                await Task.Delay(50, ct);
                ProgressChanged?.Invoke(i); // ?.Invoke: null-safe AND thread-safe
            }
            Completed?.Invoke(url);
        }
        catch (Exception ex)
        {
            Failed?.Invoke(ex);
        }
    }
}

// Subscribing and unsubscribing
var svc = new DownloadService();

Action<int> onProgress = pct => Console.WriteLine($"{pct}%");
svc.ProgressChanged += onProgress;
svc.Completed       += url => Console.WriteLine($"Done: {url}");

await svc.DownloadAsync("https://example.com/file");

svc.ProgressChanged -= onProgress; // unsubscribe — must be SAME delegate instance
```

**Standard pattern: `EventHandler<TEventArgs>` — for library/framework code**
```csharp
// Custom EventArgs carries event data
public class OrderPlacedEventArgs : EventArgs
{
    public Guid   OrderId   { get; }
    public string Product   { get; }
    public int    Quantity  { get; }
    public DateTime PlacedAt { get; } = DateTime.UtcNow;

    public OrderPlacedEventArgs(Guid orderId, string product, int quantity)
        => (OrderId, Product, Quantity) = (orderId, product, quantity);
}

public class OrderService
{
    // Standard pattern: EventHandler<T> — matches .NET convention
    public event EventHandler<OrderPlacedEventArgs>? OrderPlaced;

    // Protected virtual: allows subclasses to intercept or suppress the event
    protected virtual void OnOrderPlaced(OrderPlacedEventArgs e)
        => OrderPlaced?.Invoke(this, e); // sender = this

    public async Task<Guid> PlaceOrderAsync(string product, int qty, CancellationToken ct)
    {
        // ... business logic ...
        var orderId = Guid.NewGuid();
        OnOrderPlaced(new OrderPlacedEventArgs(orderId, product, qty));
        return orderId;
    }
}

// Subscribe using EventHandler<T>
var service = new OrderService();
service.OrderPlaced += (sender, e) =>
    Console.WriteLine($"Order {e.OrderId}: {e.Quantity}x {e.Product}");
```

**Thread-safe event with custom add/remove**
```csharp
public class ThreadSafePublisher
{
    private readonly object _lock = new();
    private EventHandler? _handler;

    // Custom accessors give full control over subscription management
    public event EventHandler Fired
    {
        add    { lock (_lock) { _handler += value; } }
        remove { lock (_lock) { _handler -= value; } }
    }

    public void Fire()
    {
        // CRITICAL: Copy under lock, invoke OUTSIDE lock
        // Invoking inside lock risks deadlock if a subscriber tries to subscribe
        EventHandler? snapshot;
        lock (_lock) { snapshot = _handler; }
        snapshot?.Invoke(this, EventArgs.Empty);
    }
}
```

**The memory leak pattern — and the fix**
```csharp
// LEAK: LongLivedService holds a reference to ShortLivedSubscriber via the delegate
public class LongLivedService
{
    public event EventHandler? DataChanged;
}

public class ShortLivedSubscriber : IDisposable
{
    private readonly LongLivedService _service;

    public ShortLivedSubscriber(LongLivedService service)
    {
        _service = service;
        _service.DataChanged += OnDataChanged; // subscriber is now GC-rooted via _service
    }

    private void OnDataChanged(object? sender, EventArgs e) { /* process */ }

    // FIX: always unsubscribe in Dispose
    public void Dispose()
    {
        _service.DataChanged -= OnDataChanged; // break the GC root
    }
}

// Usage pattern that prevents leaks:
using var subscriber = new ShortLivedSubscriber(longLivedService);
// when using-scope exits, Dispose is called, event is unsubscribed
```

**Resilient fan-out — all subscribers run even if one throws**
```csharp
public void FireResilently(EventHandler? handler, object sender, EventArgs args)
{
    if (handler is null) return;

    // Default invocation: first exception stops remaining subscribers
    // handler(sender, args); // dangerous

    // Resilient: each subscriber isolated
    foreach (EventHandler subscriber in handler.GetInvocationList())
    {
        try
        {
            subscriber(sender, args);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Event subscriber {Subscriber} threw", subscriber.Method.Name);
        }
    }
}
```

**Self-removing handler — subscribe to fire once**
```csharp
// Subscribes, handles once, then unsubscribes automatically
EventHandler<OrderPlacedEventArgs>? oneTimeHandler = null;
oneTimeHandler = (sender, e) =>
{
    service.OrderPlaced -= oneTimeHandler;  // remove before processing
    Console.WriteLine($"First order: {e.OrderId}");
};
service.OrderPlaced += oneTimeHandler;
```

---

## Real World Example

A domain-driven design aggregate publishes domain events after state changes. The event is defined on the aggregate, and multiple subscribers handle different concerns (email, inventory, analytics) — all unknown to the `Order` class itself.

```csharp
// Domain event args — carry all context needed by subscribers
public class OrderShippedEventArgs : EventArgs
{
    public Guid     OrderId        { get; init; }
    public string   CustomerEmail  { get; init; } = "";
    public string   TrackingNumber { get; init; } = "";
    public DateTime ShippedAt      { get; init; }
}

// Aggregate publishes events — knows nothing about subscribers
public class Order
{
    public Guid          Id          { get; }
    public OrderStatus   Status      { get; private set; }
    public string        CustomerEmail { get; }

    public event EventHandler<OrderShippedEventArgs>? Shipped;

    public Order(Guid id, string customerEmail)
        => (Id, CustomerEmail, Status) = (id, customerEmail, OrderStatus.Pending);

    protected virtual void OnShipped(OrderShippedEventArgs e) => Shipped?.Invoke(this, e);

    public void Ship(string trackingNumber)
    {
        if (Status != OrderStatus.Processing)
            throw new InvalidOperationException($"Cannot ship order in status {Status}");

        Status = OrderStatus.Shipped;
        OnShipped(new OrderShippedEventArgs
        {
            OrderId        = Id,
            CustomerEmail  = CustomerEmail,
            TrackingNumber = trackingNumber,
            ShippedAt      = DateTime.UtcNow
        });
    }
}

// Multiple independent subscribers — each handles its own concern
public class ShippingEmailNotifier : IDisposable
{
    private readonly Order _order;
    private readonly IEmailService _email;

    public ShippingEmailNotifier(Order order, IEmailService email)
    {
        _order = order;
        _email = email;
        _order.Shipped += OnShipped;
    }

    private async void OnShipped(object? sender, OrderShippedEventArgs e)
    {
        await _email.SendAsync(e.CustomerEmail, "Your order shipped",
            $"Tracking: {e.TrackingNumber}");
    }

    public void Dispose() => _order.Shipped -= OnShipped;
}

public class InventoryUpdater : IDisposable
{
    private readonly Order _order;
    private readonly IInventoryService _inventory;

    public InventoryUpdater(Order order, IInventoryService inventory)
    {
        _order = order;
        _inventory = inventory;
        _order.Shipped += OnShipped;
    }

    private void OnShipped(object? sender, OrderShippedEventArgs e)
        => _inventory.MarkFulfilled(e.OrderId);

    public void Dispose() => _order.Shipped -= OnShipped;
}
```

*The key insight: `Order` is completely decoupled from email and inventory. It just fires `Shipped` — it doesn't know or care who's listening. Adding analytics, audit logging, or any other concern requires adding a new subscriber class and registering it — zero changes to `Order`. Each subscriber implements `IDisposable` and unsubscribes in `Dispose`, preventing the memory leak that would otherwise keep `Order` instances alive indefinitely.*

---

## Common Misconceptions

**"Events are `null` only when there are no subscribers — always use `?.Invoke()`"**
Correct, but the reason matters: a subscriber could unsubscribe between a null check and an invocation, creating a race condition. `?.Invoke()` is atomic — it takes a null-safe snapshot internally before calling. `if (MyEvent != null) MyEvent(...)` has a TOCTOU race. Always use `?.Invoke()`.

**"You can unsubscribe any lambda with `-=`"**
Only if it's the *same delegate instance*. `event -= x => DoThing(x)` creates a new lambda instance that doesn't match the one subscribed. Nothing is unsubscribed. Store the lambda in a variable, subscribe with that variable, unsubscribe with the same variable.

**"The `event` keyword just marks the delegate for documentation"**
`event` changes the compiler output: without it, external code can call `obj.MyDelegate()` directly, or set `obj.MyDelegate = null` wiping all subscribers. With `event`, external code can only `+=` and `-=`. The difference is enforced by the compiler.

---

## Gotchas

- **Subscribers that throw stop the remaining handlers from running.** Standard event invocation is sequential — the first unhandled exception propagates to the publisher and remaining subscribers never fire. Use `GetInvocationList()` with per-subscriber try/catch for resilient fan-out.

- **Event subscribers create a GC root on the publisher.** The most common managed memory leak in .NET. A short-lived object subscribing to a long-lived publisher's event will never be GC'd unless it unsubscribes. Always unsubscribe in `Dispose()`.

- **`async void` event handlers swallow exceptions.** An event handler declared as `async void` (which is required if the event's delegate type is `void`-returning) will swallow exceptions thrown after the first `await`. The exception doesn't propagate to the publisher. Log all exceptions inside async event handlers.

- **Thread-safe subscription requires custom add/remove with lock.** The default compiler-generated event accessors use `Interlocked.CompareExchange` for lock-free updates on some platforms, but invoking inside a lock creates deadlock risk. The correct pattern is: lock to copy the delegate snapshot, then invoke outside the lock.

- **`OnXxx` virtual method pattern is not just convention.** Making `protected virtual void OnOrderPlaced(...)` virtual lets derived classes intercept and suppress events, add pre/post logic, or call base to fire normally. Sealing it removes that extensibility point — a meaningful design decision in library code.

---

## Interview Angle

**What they're really testing:** Whether you understand what the `event` keyword actually compiles to and enforces — and whether you know the memory leak risk and thread-safety nuances.

**Common question forms:**
- "What's the difference between a delegate and an event?"
- "What does the `event` keyword actually do to the generated code?"
- "How do you prevent a memory leak with events?"
- "Is event invocation thread-safe?"

**The depth signal:** A junior says "events are for notifications, delegates are function pointers." A senior explains that `event` compiles to a private delegate field plus `add`/`remove` accessors — restricting external callers to `+=`/`-=` only. They name the subscriber-as-GC-root memory leak (the most common managed memory leak in .NET) and explain that the fix is always unsubscribing in `Dispose`. They know why `?.Invoke()` is safer than a null check followed by invocation (TOCTOU race), and can describe the copy-under-lock, invoke-outside-lock pattern for thread-safe custom accessors.

**Follow-up questions to expect:**
- "What happens if two threads subscribe to an event simultaneously?"
- "Why does `-=` sometimes fail to unsubscribe a lambda?"
- "What is the `GetInvocationList()` method for?"

---

## Related Topics

- [[dotnet/csharp/csharp-delegates.md]] — Events are delegates with restricted access; multicast delegates, closures, and `GetInvocationList` are the foundation
- [[dotnet/csharp/csharp-idisposable.md]] — The event memory leak is fixed by unsubscribing in `Dispose`; the two topics appear together whenever a subscriber has a shorter lifetime than its publisher
- [[dotnet/csharp/csharp-concurrent-collections.md]] — Thread-safe event wrappers use the same snapshot-under-lock pattern used in concurrent collection internals
- [[dotnet/csharp/csharp-channels.md]] — `Channel<T>` is the modern async-native alternative when you need producer/consumer patterns without the GC-root and unsubscribe problems that events carry

---

## Source

[Events — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/events/)

---

*Last updated: 2026-04-06*