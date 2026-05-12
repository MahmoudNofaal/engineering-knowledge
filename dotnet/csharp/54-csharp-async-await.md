# C# async / await

> `async` and `await` let you write asynchronous I/O-bound code that looks sequential — the compiler transforms the method into a state machine that suspends on `await` and resumes when the awaited work completes, freeing the thread for other work in between.

---

## Quick Reference

| | |
|---|---|
| **Return types** | `Task`, `Task<T>`, `ValueTask`, `ValueTask<T>`, `void` (events only) |
| **Use when** | Any I/O: database, HTTP, file, network |
| **Avoid** | CPU-bound work — use `Task.Run` to offload, or just synchronous code |
| **Deadlock trap** | `.Result` / `.Wait()` on a `Task` in synchronous context — blocks thread |
| **C# version** | C# 5.0 (.NET 4.5) |

---

## When To Use It

Use `async`/`await` for I/O-bound operations — anything that waits for an external resource (database query, HTTP call, file read). While waiting, the thread is returned to the pool to handle other requests.

Don't use `async` for CPU-bound work — `await` does not create a new thread. A CPU-heavy `async` method runs synchronously until the first `await`, then resumes on a thread pool thread. For CPU work that should run in parallel, wrap it with `Task.Run`.

---

## Core Concept

`await` does two things:
1. If the task is not yet complete: **suspends the method**, saves state, and returns control to the caller
2. When the task completes: **resumes the method** from where it paused, on a captured `SynchronizationContext` (e.g. UI thread) or thread pool thread

The compiler rewrites every `async` method into a state machine class. The method's local variables become fields on the class. Each `await` point becomes a state transition. The method returns a `Task` immediately; the state machine drives the task to completion.

**`async void`** is for event handlers only. It can't be awaited, exceptions escape to the `SynchronizationContext` (often crashing the app), and the caller has no way to know when it completes. Everywhere else, return `Task` or `ValueTask`.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 5.0 | .NET 4.5 | `async`/`await` introduced |
| C# 7.0 | .NET Core 1.0 | `ValueTask<T>` for allocation-free hot paths |
| C# 8.0 | .NET Core 3.0 | `IAsyncEnumerable<T>` — `await foreach` |
| C# 8.0 | .NET Core 3.0 | `IAsyncDisposable` — `await using` |
| .NET 5 | — | `Task.WaitAsync(timeout)`, `PeriodicTimer` |
| .NET 6 | — | `ValueTask`-returning socket APIs, `Parallel.ForEachAsync` |

---

## The Code

**Basic async method**
```csharp
public async Task<string> GetUserNameAsync(int userId, CancellationToken ct = default)
{
    // Awaiting suspends this method, releases the thread to handle other work
    User? user = await dbContext.Users.FindAsync(new object[] { userId }, ct);
    return user?.Name ?? "Unknown";
}
```

**Awaiting multiple tasks**
```csharp
// WRONG: sequential — second request waits for first to complete
var user  = await GetUserAsync(userId, ct);
var order = await GetOrderAsync(orderId, ct);

// RIGHT: concurrent — both requests in flight simultaneously
var userTask  = GetUserAsync(userId, ct);
var orderTask = GetOrderAsync(orderId, ct);
await Task.WhenAll(userTask, orderTask);

User user   = userTask.Result;   // already done — Result doesn't block
Order order = orderTask.Result;

// With WhenAll + deconstruct
var (u, o) = await (GetUserAsync(userId, ct), GetOrderAsync(orderId, ct)).WhenAll();
```

**`ConfigureAwait(false)` — library code**
```csharp
// Library code: don't capture SynchronizationContext
public async Task<Order?> FindOrderAsync(int id, CancellationToken ct)
{
    await Task.Delay(1, ct).ConfigureAwait(false); // won't resume on UI thread
    return await dbContext.FindAsync<Order>(id, ct).ConfigureAwait(false);
}
// In ASP.NET Core: ConfigureAwait(false) not required but doesn't hurt
// In WinForms/WPF libraries: required to avoid deadlocks with .Result on UI thread
```

**`CancellationToken` — cooperative cancellation**
```csharp
public async Task ProcessOrdersAsync(IEnumerable<int> ids, CancellationToken ct)
{
    foreach (int id in ids)
    {
        ct.ThrowIfCancellationRequested(); // cooperative check
        await ProcessOneOrderAsync(id, ct);
    }
}
```

**`async void` event handler — the only valid use**
```csharp
// OK: event handler — no way to await it from UI framework
private async void Button_Click(object? sender, EventArgs e)
{
    try
    {
        await SaveAsync();
        MessageBox.Show("Saved!");
    }
    catch (Exception ex)
    {
        MessageBox.Show($"Error: {ex.Message}"); // MUST catch in async void
    }
}
```

**`async` streams — `IAsyncEnumerable<T>` (C# 8)**
```csharp
async IAsyncEnumerable<Order> GetOrdersAsync(
    [EnumeratorCancellation] CancellationToken ct = default)
{
    int page = 1;
    while (true)
    {
        var orders = await FetchPageAsync(page++, ct);
        if (!orders.Any()) yield break;
        foreach (var o in orders) yield return o;
    }
}

await foreach (var order in GetOrdersAsync(ct))
    await ProcessAsync(order, ct);
```

---

## Real World Example

An order processing service handles multiple async operations concurrently, with proper cancellation and error handling.

```csharp
public class OrderProcessingService
{
    private readonly IOrderRepository    _orders;
    private readonly IPaymentGateway     _payment;
    private readonly INotificationService _notify;
    private readonly ILogger<OrderProcessingService> _logger;

    public async Task<ProcessResult> ProcessAsync(
        Guid orderId, CancellationToken ct = default)
    {
        // Load order — let cancellation propagate naturally
        var order = await _orders.FindAsync(orderId, ct)
            ?? throw new OrderNotFoundException(orderId);

        if (order.Status != OrderStatus.Pending)
            return ProcessResult.AlreadyProcessed(order.Status);

        // Charge payment
        PaymentResult payment;
        try
        {
            payment = await _payment.ChargeAsync(order.PaymentToken, order.Total, ct);
        }
        catch (PaymentException ex)
        {
            _logger.LogWarning(ex, "Payment failed for order {Id}", orderId);
            return ProcessResult.PaymentFailed(ex.Message);
        }

        // Update order and send notification concurrently
        var updateTask = _orders.UpdateStatusAsync(orderId, OrderStatus.Processing, ct);
        var notifyTask = _notify.SendConfirmationAsync(order.CustomerEmail, orderId, ct);

        await Task.WhenAll(updateTask, notifyTask); // both in flight simultaneously

        _logger.LogInformation("Order {Id} processed: txn {Txn}", orderId, payment.TransactionId);
        return ProcessResult.Success(payment.TransactionId);
    }
}
```

*The key insight: `Task.WhenAll(updateTask, notifyTask)` fires both I/O operations simultaneously rather than waiting for each in turn. If both take 50 ms, the sequential version takes 100 ms; the concurrent version takes ~50 ms.*

---

## Common Misconceptions

**"`async` makes code faster"**
`async` makes code non-blocking — it releases threads while waiting for I/O. A single request still takes the same wall-clock time. The benefit is throughput under load: a server can handle more concurrent requests when threads aren't blocked waiting for I/O.

**"`async void` is fine for fire-and-forget"**
`async void` exceptions crash the process. Use `Task.Run` with proper exception handling, or a background job queue for true fire-and-forget.

**"`await` creates a new thread"**
`await` does not create threads. It suspends the current method and returns the thread to the pool. Resumption happens on an available thread pool thread (or the captured context). `Task.Run` is what moves CPU work to a thread pool thread.

---

## Gotchas

- **Calling `.Result` or `.Wait()` on a `Task` in a synchronous context deadlocks** in environments with a `SynchronizationContext` (WPF, WinForms, some ASP.NET configurations). The caller blocks the thread; the awaiting continuation needs that thread to resume; deadlock.
- **`async void` swallows exceptions.** Exceptions thrown after the first `await` in an `async void` go to `SynchronizationContext.UnhandledException` — often fatal. Always catch exceptions inside `async void` event handlers.
- **`await` in a `catch` or `finally` block is valid since C# 6.** Before that, it was a compile error. Don't work around it with convoluted try-finally nesting in modern code.
- **Async state machine allocates.** Every `async` method that actually suspends allocates the state machine on the heap. `ValueTask` reduces this for hot paths that often complete synchronously.
- **`Task.Result` on a faulted task wraps the exception in `AggregateException`.** Use `await` to get the original exception directly.

---

## Interview Angle

**What they're really testing:** Whether you understand what `await` actually does mechanically — not just "it's asynchronous" — and the deadlock scenario.

**Common question forms:**
- "What does `await` do?"
- "Why can't you use `.Result` on a Task in ASP.NET?"
- "What's the difference between `Task.WhenAll` and sequential `await`?"
- "What is `async void` and when is it acceptable?"

**The depth signal:** A senior explains the state machine — the compiler creates a class with the method's locals as fields and `MoveNext()` advancing through `await` points. They explain the `.Result` deadlock: the calling thread blocks; the continuation needs to resume on that thread (due to `SynchronizationContext`); deadlock. They know `ConfigureAwait(false)` avoids the context capture in library code, and distinguish I/O-bound (`async`/`await`) from CPU-bound (`Task.Run`).

---

## Related Topics

- [[dotnet/csharp/csharp-task-parallel-library.md]] — `Task`, `Task.WhenAll`, `Task.WhenAny` — the types that async/await builds on
- [[dotnet/csharp/csharp-cancellation-token.md]] — Cooperative cancellation through async chains
- [[dotnet/csharp/csharp-valuetask.md]] — Allocation-free async for hot paths that often complete synchronously
- [[dotnet/csharp/csharp-channels.md]] — Async producer/consumer pipelines

---

## Source

[Asynchronous programming — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/asynchronous-programming/)

---
*Last updated: 2026-04-06*