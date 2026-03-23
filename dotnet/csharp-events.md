# C# Events

> An event is a multicast delegate field wrapped with access control so that external subscribers can only add and remove handlers — never invoke or replace the list.

---

## When To Use It

Use events when an object needs to notify one or more unknown listeners that something happened, without knowing or caring who is listening. The classic cases are UI interactions (button clicked, text changed), domain model notifications (order placed, stock level changed), and progress reporting in long-running operations. Do not use events for request/response patterns where the caller needs a return value — delegates or interfaces are cleaner there. Do not use events when you control both publisher and subscriber in the same class; a direct method call is simpler.

---

## Core Concept

An event is syntactic sugar over a private multicast delegate field. When you write `public event Action<string> Clicked`, the compiler generates a private delegate field and two public methods: `add_Clicked` (what `+=` calls) and `remove_Clicked` (what `-=` calls). External code can only reach the add and remove accessors — it cannot invoke the event, read the current subscriber list, or replace it with `=`. The class that declares the event is the only one that can fire it by calling the private delegate field directly. This is the core difference from exposing a bare `public Func<string>` field: the `event` keyword enforces publisher/subscriber separation at compile time.

---

## The Code
```csharp
// --- Minimal event with Action ---
public class DownloadService
{
    public event Action<int>? ProgressChanged;   // int = percent 0-100
    public event Action<string>? Completed;
    public event Action<Exception>? Failed;

    public async Task DownloadAsync(string url)
    {
        try
        {
            for (int i = 0; i <= 100; i += 10)
            {
                await Task.Delay(50);
                ProgressChanged?.Invoke(i);      // null-check: no subscribers = null
            }
            Completed?.Invoke(url);
        }
        catch (Exception ex)
        {
            Failed?.Invoke(ex);
        }
    }
}

// --- Subscribing and unsubscribing ---
var svc = new DownloadService();

Action<int> onProgress = pct => Console.WriteLine($"{pct}%");
svc.ProgressChanged += onProgress;
svc.Completed       += url => Console.WriteLine($"Done: {url}");

await svc.DownloadAsync("https://example.com/file");

svc.ProgressChanged -= onProgress;  // unsubscribe — must be same delegate instance

// --- Standard pattern: EventHandler<TEventArgs> ---
// Preferred in library/framework code; matches the convention used across .NET.
public class OrderService
{
    public event EventHandler<OrderPlacedEventArgs>? OrderPlaced;

    protected virtual void OnOrderPlaced(OrderPlacedEventArgs e)
    {
        OrderPlaced?.Invoke(this, e);  // sender = this; 'virtual' allows subclass override
    }

    public void PlaceOrder(string product, int qty)
    {
        // business logic...
        OnOrderPlaced(new OrderPlacedEventArgs(product, qty));
    }
}

public class OrderPlacedEventArgs : EventArgs
{
    public string Product { get; }
    public int Quantity   { get; }
    public OrderPlacedEventArgs(string product, int qty) =>
        (Product, Quantity) = (product, qty);
}

// Subscribe using EventHandler<T>
var orders = new OrderService();
orders.OrderPlaced += (sender, e) =>
    Console.WriteLine($"Order: {e.Quantity}x {e.Product}");

orders.PlaceOrder("Widget", 3);

// --- Custom add/remove accessors: thread-safe event with explicit lock ---
public class ThreadSafePublisher
{
    private readonly object _lock = new();
    private EventHandler? _handler;

    public event EventHandler Fired
    {
        add    { lock (_lock) { _handler += value; } }
        remove { lock (_lock) { _handler -= value; } }
    }

    public void Fire()
    {
        EventHandler? snapshot;
        lock (_lock) { snapshot = _handler; }  // copy under lock, invoke outside
        snapshot?.Invoke(this, EventArgs.Empty);
    }
}

// --- Unsubscribing inside the handler (safe pattern) ---
Action<int>? selfRemovingHandler = null;
selfRemovingHandler = pct =>
{
    if (pct >= 100)
        svc.ProgressChanged -= selfRemovingHandler; // clean up after one completion
    Console.WriteLine(pct);
};
svc.ProgressChanged += selfRemovingHandler;
```

---

## Gotchas

- **Events are `null` when there are no subscribers — always null-check before invoking.** The `?.Invoke(...)` pattern is the safe, thread-safe way to do this. The alternative `if (MyEvent != null) MyEvent(...)` has a TOCTOU race: a subscriber could unsubscribe between the null check and the invocation. `?.Invoke` copies the reference atomically before calling, avoiding the race.
- **You cannot unsubscribe a lambda you didn't store.** `myEvent -= x => DoThing(x)` creates a new delegate instance that does not match the one added, so nothing is unsubscribed. Always assign the lambda to a variable before subscribing if you intend to unsubscribe later.
- **Subscribers that throw stop the remaining handlers from running.** Event invocation iterates the multicast delegate chain; the first unhandled exception propagates to the publisher and remaining subscribers never fire. For resilient fan-out, iterate `MyEvent.GetInvocationList()` and wrap each call in a try/catch.
- **Event subscribers create a GC root on the publisher.** If a short-lived subscriber subscribes to an event on a long-lived publisher and never unsubscribes, the publisher holds a delegate reference that keeps the subscriber alive indefinitely. This is the most common managed memory leak pattern in .NET. Always unsubscribe when the subscriber is disposed or no longer needed.
- **The `OnXxx` virtual method pattern is not just convention.** Making `protected virtual void OnOrderPlaced(...)` virtual lets derived classes intercept and suppress events, add pre/post logic, or call base to fire normally. Sealing it or inlining the `?.Invoke` call directly removes that extensibility — a meaningful design decision in library code.

---

## Interview Angle

**What they're really testing:** Whether you understand what the `event` keyword actually compiles to and enforces — not just "events notify subscribers."

**Common question form:** "What's the difference between a delegate and an event?" or "How do you prevent a memory leak with events?" or "Is event invocation thread-safe?"

**The depth signal:** A junior says "events are for notifications, delegates are function pointers." A senior explains that `event` compiles to a private delegate field plus `add`/`remove` accessors, restricting external callers to `+=`/`-=` only — they cannot invoke or reassign; names the subscriber-as-GC-root memory leak and that the fix is always unsubscribing in `Dispose`; explains why `?.Invoke` is safer than a null check followed by invocation; and knows the copy-under-lock, invoke-outside-lock pattern needed when writing custom thread-safe `add`/`remove` accessors.

---

## Related Topics

- [[dotnet/csharp-delegates.md]] — Events are delegates with restricted access; you need to understand multicast delegates, closure capture, and `GetInvocationList` before events make full sense.
- [[dotnet/csharp-idisposable.md]] — The event memory leak is fixed by unsubscribing in `Dispose`; the two topics appear together every time a subscriber has a shorter lifetime than its publisher.
- [[dotnet/csharp-concurrent-collections.md]] — Firing events concurrently from multiple threads requires the copy-under-lock pattern or a thread-safe event wrapper; concurrent collections use the same snapshot-under-lock idea.
- [[dotnet/csharp-channels.md]] — Channels are the modern async-native alternative when you need to push data between producer and consumer without the GC-root and unsubscribe problems that events carry.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/events/](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/events/)

---
*Last updated: 2026-03-23*