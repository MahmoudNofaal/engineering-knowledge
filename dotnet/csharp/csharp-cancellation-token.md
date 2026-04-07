# C# CancellationToken

> A struct that carries a cancellation signal through async and synchronous call chains — cooperative, one-way, and propagated via `CancellationTokenSource`.

---

## Quick Reference

| | |
|---|---|
| **Create** | `new CancellationTokenSource()` |
| **Cancel** | `cts.Cancel()` or `cts.CancelAfter(timeout)` |
| **Pass** | `cts.Token` — a `CancellationToken` struct |
| **Check** | `ct.ThrowIfCancellationRequested()` or `ct.IsCancellationRequested` |
| **Default** | `CancellationToken.None` — never cancelled |
| **C# version** | .NET 4.0 (C# 4.0) |

---

## When To Use It

Accept a `CancellationToken` in every async method. Pass it to every awaited method and every long-running loop. This gives callers the ability to cancel the operation cleanly — HTTP request timeout, user pressing Cancel, application shutdown via `IHostApplicationLifetime`.

Don't create `CancellationTokenSource` for a token you receive — that's the caller's responsibility. Your method only reads the token, it doesn't control it.

---

## Core Concept

`CancellationTokenSource` owns the signal and provides `Cancel()`. `CancellationToken` is a read-only view of that signal — passed to methods so they can observe and react to cancellation.

Cancellation is **cooperative**: the cancellation signal fires, and methods check it at convenient points using `ThrowIfCancellationRequested()`. Nothing is forcibly interrupted. A long-running loop without a check is uncancellable regardless of how many times you call `cts.Cancel()`.

When cancelled, methods should propagate `OperationCanceledException` (or `TaskCanceledException`) upward — not swallow it — unless they're the top-level handler cleaning up.

---

## The Code

**Accept and propagate — the standard pattern**
```csharp
public async Task<Order?> GetOrderAsync(int id, CancellationToken ct = default)
{
    return await dbContext.Orders
        .Where(o => o.Id == id)
        .FirstOrDefaultAsync(ct); // pass ct — EF Core will cancel the DB query
}

public async Task ProcessOrdersAsync(IEnumerable<int> ids, CancellationToken ct)
{
    foreach (int id in ids)
    {
        ct.ThrowIfCancellationRequested(); // cooperative check between iterations
        var order = await GetOrderAsync(id, ct);
        await ProcessAsync(order, ct);
    }
}
```

**`CancellationTokenSource` — timeout and composite**
```csharp
// Timeout
using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
await DoWorkAsync(cts.Token);

// Linked: cancel if EITHER the user cancels OR the timeout fires
using var linked = CancellationTokenSource.CreateLinkedTokenSource(userToken, timeoutToken);
await DoWorkAsync(linked.Token);
```

**Register a callback — clean up resources on cancellation**
```csharp
ct.Register(() => Console.WriteLine("Cancellation requested!"));

// More useful: signal a non-awaitable blocking operation
var tcs = new TaskCompletionSource<bool>();
ct.Register(() => tcs.TrySetCanceled(ct));
await tcs.Task; // unblocks when ct is cancelled
```

**Handling `OperationCanceledException`**
```csharp
async Task RunAsync(CancellationToken ct)
{
    try
    {
        await LongRunningAsync(ct);
    }
    catch (OperationCanceledException) when (ct.IsCancellationRequested)
    {
        // Clean cancellation — expected, log at debug, don't re-throw to user
        logger.LogDebug("Operation cancelled");
    }
    // Other exceptions propagate normally
}
```

---

## Real World Example

An ASP.NET Core endpoint cancels its database query and downstream calls when the HTTP request is aborted (client disconnects).

```csharp
[HttpGet("{id}")]
public async Task<IActionResult> GetOrderReport(int id, CancellationToken ct)
{
    // ct is automatically bound to the HTTP request lifetime by ASP.NET Core
    try
    {
        var order   = await orderService.GetAsync(id, ct);
        if (order is null) return NotFound();
        var report  = await reportService.GenerateAsync(order, ct);
        return Ok(report);
    }
    catch (OperationCanceledException)
    {
        // Client disconnected — no response needed
        return StatusCode(499); // client closed request
    }
}
```

---

## Gotchas

- **`CancellationToken.None` is never cancelled.** Use it as a default when you have no token from the caller.
- **`TaskCanceledException` is a subclass of `OperationCanceledException`.** Catch `OperationCanceledException` to handle both.
- **Don't catch cancellation and continue.** If you catch `OperationCanceledException` and don't re-throw, the operation continues despite cancellation being requested. Only catch it for cleanup or if you're the top-level handler.
- **`Register` callbacks run synchronously on the thread that calls `Cancel()`.** Keep them short and non-blocking.
- **Dispose `CancellationTokenSource`.** It holds a `WaitHandle`. Always wrap in `using`.

---

## Source

[Cancellation in managed threads — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/threading/cancellation-in-managed-threads)

---
*Last updated: 2026-04-06*