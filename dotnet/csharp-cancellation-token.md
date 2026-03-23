# C# CancellationToken

> A struct that carries a cancellation signal from a `CancellationTokenSource` into async methods, letting you stop long-running work cooperatively.

---

## When To Use It

Use it any time an operation could outlive the caller's interest in the result — HTTP request handlers, background jobs, database queries, file I/O, or any loop that shouldn't run forever. The token lets the caller say "stop when you can" without killing a thread.

Do not use it for exceptions or error handling — cancellation means "the caller no longer wants this result," not "something went wrong." Don't create a `CancellationTokenSource` just to immediately cancel it; that's a code smell for logic that belongs in a plain `if` statement.

---

## Core Concept

There are two separate objects. The `CancellationTokenSource` is the sender — it owns the signal and calls `.Cancel()`. The `CancellationToken` is the receiver — it's a lightweight struct you pass into every method that needs to respect the cancellation. The source and token are linked; when you cancel the source, the token's `IsCancellationRequested` flips to `true` and any registered callbacks fire. The key word is *cooperative* — nothing stops forcefully. The method receiving the token has to actually check it. The runtime won't kill the operation for you.

---

## The Code
```csharp
// --- Basic: create source, pass token, cancel from outside ---
var cts = new CancellationTokenSource();
CancellationToken token = cts.Token;

Task work = DoWorkAsync(token);
await Task.Delay(2000);
cts.Cancel(); // signal the operation to stop

await work; // will throw OperationCanceledException if cancelled mid-flight

async Task DoWorkAsync(CancellationToken ct)
{
    for (int i = 0; i < 100; i++)
    {
        ct.ThrowIfCancellationRequested(); // throws if .Cancel() was called
        await Task.Delay(100, ct);         // also respects cancellation
    }
}

// --- Timeout: auto-cancel after a duration ---
using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
try
{
    string result = await FetchDataAsync(cts.Token);
}
catch (OperationCanceledException)
{
    Console.WriteLine("Timed out or cancelled");
}

// --- Linked tokens: combine user cancel + timeout into one token ---
using var userCts  = new CancellationTokenSource();          // e.g. from HTTP request
using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
using var linked = CancellationTokenSource.CreateLinkedTokenSource(
    userCts.Token, timeoutCts.Token);

await ProcessAsync(linked.Token); // fires if EITHER source cancels

// --- CPU-bound loop: poll instead of throw ---
async Task ProcessLargeFileAsync(CancellationToken ct)
{
    foreach (var chunk in ReadChunks())
    {
        if (ct.IsCancellationRequested)
        {
            // clean up before exiting
            break;
        }
        Process(chunk);
    }
}

// --- Register a callback to run on cancellation ---
using var cts = new CancellationTokenSource();
cts.Token.Register(() =>
{
    Console.WriteLine("Cancelled! Releasing external resource.");
});
```

---

## Gotchas

- **`OperationCanceledException` must not be swallowed.** If your `catch` block catches `Exception` broadly and does nothing with it, cancelled operations silently succeed from the caller's perspective. Always check `ex.CancellationToken == token` or let it propagate.
- **Passing `CancellationToken.None` is not the same as passing nothing.** `CancellationToken.None` can never be cancelled — it's the "don't support cancellation" sentinel. Swapping in `default` does the same thing. Both are fine intentionally, but passing them when you actually have a live token means your method will never stop.
- **`Task.Delay(ms, token)` throws `OperationCanceledException` immediately when the token is already cancelled before the delay starts.** The delay doesn't run. This is usually what you want, but surprises people who expect it to "start the delay and then cancel."
- **`CancellationTokenSource` is `IDisposable` and must be disposed.** If you use the timeout constructor (`new CancellationTokenSource(timeout)`), it registers a `Timer` internally. Failing to `Dispose` leaks that timer for the lifetime of the process.
- **Linked sources must also be disposed.** `CreateLinkedTokenSource` registers callbacks on both parent tokens. Without `Dispose`, those registrations sit on the parent tokens until they're cancelled or GC'd — which in ASP.NET means for the lifetime of the request, piling up if requests are frequent.

---

## Interview Angle

**What they're really testing:** Whether you understand the cooperative cancellation model and its propagation contract — not just "pass the token in."

**Common question form:** "How would you cancel an in-flight HTTP request if the user navigates away?" or "How do you make a long-running service respect shutdown signals in .NET?"

**The depth signal:** A junior answers "pass `CancellationToken` to `HttpClient.GetAsync`." A senior adds: that the `IHostApplicationLifetime.ApplicationStopping` token should be linked with any per-request token using `CreateLinkedTokenSource` so the operation cancels on *either* event; that `OperationCanceledException` should propagate up rather than being swallowed; and that in background services, `ExecuteAsync` receives a `stoppingToken` that fires on `IHostedService.StopAsync` — if you ignore it and do `await Task.Delay(Timeout.Infinite)`, the host shutdown will hang for its configured timeout before force-killing the process.

---

## Related Topics

- [[dotnet/csharp-task-parallel-library.md]] — `CancellationToken` is the primary way to stop `Task.Run`, `Parallel.For`, and `Task.WhenAll` chains; the two features are inseparable in production.
- [[dotnet/async-await-internals.md]] — Understanding how `await` suspension points interact with token checks explains why `ThrowIfCancellationRequested` works where it does.
- [[dotnet/hosted-services-background-tasks.md]] — `IHostedService.ExecuteAsync` receives `stoppingToken` directly; getting shutdown right depends on threading it through every awaited call.
- [[dotnet/httpclient-patterns.md]] — `HttpClient` methods accept a token and abort the underlying socket; the correct pattern for request-scoped timeouts uses a linked source.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/standard/threading/cancellation-in-managed-threads](https://learn.microsoft.com/en-us/dotnet/standard/threading/cancellation-in-managed-threads)

---
*Last updated: 2026-03-23*