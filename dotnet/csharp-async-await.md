# C# — async / await

> A compiler transformation that lets you write asynchronous I/O-bound code in a straight-line, readable style — without blocking a thread while waiting for the result.

---

## When To Use It

Use `async`/`await` for any operation that waits on something external: database queries, HTTP calls, file reads, message queue operations. The payoff is that the calling thread is released back to the thread pool while the wait happens, so the same thread can handle other work — critical for server throughput under load. Don't use it for CPU-bound work that keeps the processor busy the whole time; `async`/`await` doesn't help there and adds overhead — use `Task.Run` to offload CPU work to a thread pool thread, then await that. Don't add `async` to a method just because it returns a `Task` — only add it when you actually need to `await` something inside.

---

## Core Concept

`async`/`await` is a compiler rewrite, not a runtime feature. When you mark a method `async`, the compiler transforms it into a state machine — a class that implements `IAsyncStateMachine`. Every `await` point becomes a suspension point: the state machine saves its current position and local variables, registers a continuation, and returns control to the caller. When the awaited operation completes, the continuation resumes the state machine from exactly where it left off. No thread is blocked during the wait — the thread is returned to the thread pool and a (possibly different) thread picks up the continuation. This is why `async` scales better than blocking: a server that blocks threads on I/O needs as many threads as concurrent requests, while one that uses `async`/`await` can handle far more concurrent requests with far fewer threads.

---

## The Code

### Basic async method — the pattern
```csharp
// async methods must return void, Task, Task<T>, ValueTask, or ValueTask<T>
// Return Task<T> when there's a result; Task when there isn't
public async Task<string> FetchUserNameAsync(int userId)
{
    // await suspends this method without blocking the thread
    var user = await dbContext.Users.FindAsync(userId);

    if (user is null)
        throw new KeyNotFoundException($"User {userId} not found");

    return user.Name; // compiler wraps this in Task.FromResult automatically
}

// Caller awaits the result — propagates the suspension up the call chain
public async Task<IActionResult> GetUser(int id)
{
    var name = await FetchUserNameAsync(id);
    return Ok(name);
}
```

### ConfigureAwait — context and when to use it
```csharp
// In ASP.NET Core / library code: use ConfigureAwait(false)
// It tells the runtime not to resume on the original synchronization context
// Avoids overhead, prevents deadlocks in legacy frameworks (WinForms, WPF, ASP.NET classic)
public async Task<string> FetchDataAsync()
{
    var response = await httpClient.GetStringAsync("https://api.example.com/data")
        .ConfigureAwait(false); // don't capture the sync context

    return response.Trim();
}

// In UI code (WPF/WinForms/MAUI): do NOT use ConfigureAwait(false)
// You need to resume on the UI thread to update controls
private async void Button_Click(object sender, EventArgs e)
{
    var data = await FetchDataAsync(); // resumes on UI thread — correct for UI update
    label.Text = data;
}
```

### Parallel async — running multiple tasks concurrently
```csharp
// WRONG: sequential — each awaits before the next starts
// Total time = time(A) + time(B) + time(C)
var a = await GetAAsync();
var b = await GetBAsync();
var c = await GetCAsync();

// CORRECT: concurrent — all three start immediately, then wait for all
// Total time = max(time(A), time(B), time(C))
var taskA = GetAAsync();
var taskB = GetBAsync();
var taskC = GetCAsync();
var (a2, b2, c2) = await (taskA, taskB, taskC); // ValueTuple deconstruct

// Or with WhenAll for collections
var tasks = userIds.Select(id => FetchUserAsync(id));
var users = await Task.WhenAll(tasks);
```

### ValueTask — avoiding allocations for hot sync-completing paths
```csharp
// Task always allocates a heap object — fine for most cases
// ValueTask is a struct; if the operation completes synchronously (cache hit),
// it returns without allocating — only allocates when it actually has to await
public async ValueTask<string> GetCachedOrFetchAsync(string key)
{
    if (_cache.TryGetValue(key, out var cached))
        return cached; // no allocation — ValueTask wraps the value directly

    var result = await FetchFromDbAsync(key).ConfigureAwait(false);
    _cache[key] = result;
    return result;
}
```

### Cancellation — every async method should support it
```csharp
public async Task<List<Order>> GetOrdersAsync(
    int customerId,
    CancellationToken ct = default) // always add CancellationToken as last parameter
{
    // Pass ct to every awaitable — lets the operation abort cleanly
    var orders = await dbContext.Orders
        .Where(o => o.CustomerId == customerId)
        .ToListAsync(ct);          // EF Core, HttpClient, etc. all accept CancellationToken

    return orders;
}

// Caller can cancel after a timeout
using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
try
{
    var orders = await GetOrdersAsync(42, cts.Token);
}
catch (OperationCanceledException)
{
    Console.WriteLine("Request timed out");
}
```

### async void — when it's allowed and when it destroys you
```csharp
// async void is ONLY acceptable for event handlers
// Exceptions in async void cannot be caught by the caller — they go unobserved
// and crash the process (or are swallowed, depending on the host)
private async void SaveButton_Click(object sender, EventArgs e)
{
    await SaveDataAsync(); // exception here will crash the app
}

// WRONG: non-event-handler async void — exception is uncatchable
public async void FireAndForget() // never do this
{
    await SomeOperationAsync();
}

// RIGHT: return Task and let the caller handle it
public async Task FireAndForgetSafeAsync()
{
    await SomeOperationAsync();
}

// If you truly need fire-and-forget with no caller context,
// handle exceptions explicitly inside
_ = Task.Run(async () =>
{
    try { await SomeOperationAsync(); }
    catch (Exception ex) { logger.LogError(ex, "Background task failed"); }
});
```

### Avoiding deadlocks — the classic blocking-over-async mistake
```csharp
// DEADLOCK in ASP.NET classic / WinForms / WPF:
// .Result and .Wait() block the current thread, which holds the sync context.
// The continuation needs the sync context to resume — it can never get it.
var result = FetchDataAsync().Result;   // DEADLOCK
FetchDataAsync().Wait();                // DEADLOCK

// SAFE: await all the way up — never mix sync blocking with async
var result2 = await FetchDataAsync();   // correct

// If you must call async from sync context (rare, legitimate cases only):
// Use a dedicated thread with no sync context
var result3 = Task.Run(() => FetchDataAsync()).GetAwaiter().GetResult();
// This moves execution off the sync-context-holding thread first
```

---

## Gotchas

- **Awaiting in a loop creates sequential execution** — `foreach (var id in ids) { var r = await FetchAsync(id); }` runs one request at a time. If you want concurrency, start all tasks with `Select`, then `await Task.WhenAll(...)`. Sequential is sometimes intentional (rate limiting, ordered processing), but it's often an accidental bottleneck.
- **`async void` swallows or crashes on exceptions** — the exception doesn't propagate to the caller because there's no `Task` for the caller to observe. In ASP.NET Core, unhandled exceptions from `async void` are logged but the request continues as if nothing happened. In desktop apps, they crash the process. Always return `Task` unless you're writing an event handler.
- **`Task.Result` and `.Wait()` deadlock in sync-context environments** — any code running inside a synchronization context (ASP.NET classic, WPF, WinForms) that blocks on a `Task` will deadlock if the continuation needs that same context to resume. The fix is `ConfigureAwait(false)` in library code or, better, making the entire call chain async.
- **`ValueTask` can only be awaited once** — unlike `Task`, which caches its result and can be awaited multiple times, `ValueTask` is not safe to await more than once or to store and await later. If you need to share or re-await a result, call `.AsTask()` to convert it to a regular `Task` first.
- **Exceptions in `Task.WhenAll` — only the first is surfaced by default** — if three tasks fail, `await Task.WhenAll(t1, t2, t3)` throws only the first exception. To see all of them, catch the exception and inspect `task.Exception.InnerExceptions` on each task, or use `WhenAll` and check each task individually after awaiting.

---

## Interview Angle

**What they're really testing:** Whether you understand what `async`/`await` actually does mechanically — the state machine, thread release, and continuation model — not just that it's "for async operations."

**Common question form:** "What happens under the hood when you `await` a method?" or "Why does this code deadlock?" (showing `.Result` on a sync context) or "What's the difference between `Task` and `ValueTask`?"

**The depth signal:** A junior says `async`/`await` makes code non-blocking and runs it on a background thread. A senior corrects both halves: `await` doesn't move code to a background thread — it releases the current thread back to the pool and registers a continuation. The continuation may resume on the same thread or a different one, depending on the synchronization context. The senior explains that the compiler rewrites the `async` method as a state machine class where each `await` point is a state, and `MoveNext()` is called to advance it. They know that `ConfigureAwait(false)` prevents capturing the sync context and is why library code uses it to avoid deadlocks in callers that do block. They also know that `Task.WhenAll` starts tasks concurrently while sequential `await` in a loop is serial — and that this difference can be the entire performance gap in an I/O-heavy service.

---

## Related Topics

- [[dotnet/csharp-task-parallel-library.md]] — `Task`, `Task<T>`, `Task.Run`, `Task.WhenAll`, and `Task.WhenAny` are the underlying primitives `async`/`await` builds on.
- [[dotnet/csharp-cancellationtoken.md]] — `CancellationToken` is the standard way to propagate cancellation through async call chains; every async method should accept one.
- [[dotnet/csharp-iasyncenumerable.md]] — `IAsyncEnumerable<T>` with `await foreach` is the async equivalent of `IEnumerable<T>` for streaming sequences from I/O sources.
- [[dotnet/csharp-valuetask.md]] — `ValueTask` vs `Task` allocation tradeoffs; when to use each and the constraints on `ValueTask` reuse.

---

## Source

https://learn.microsoft.com/en-us/dotnet/csharp/asynchronous-programming/async-in-depth

---
*Last updated: 2026-03-23*