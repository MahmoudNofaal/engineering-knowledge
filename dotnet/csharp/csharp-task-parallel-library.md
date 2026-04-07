# C# Task Parallel Library (TPL)

> The set of types and methods — primarily `Task`, `Task<T>`, `Parallel`, and `Task.WhenAll/WhenAny` — that represent asynchronous and parallel operations and compose them.

---

## Quick Reference

| | |
|---|---|
| **Core type** | `Task` (void), `Task<T>` (returns value) |
| **CPU parallel** | `Parallel.For`, `Parallel.ForEach`, `Parallel.ForEachAsync` |
| **Task combinators** | `Task.WhenAll`, `Task.WhenAny`, `Task.WaitAll` (blocking) |
| **Thread pool offload** | `Task.Run(Func<T>)` |
| **C# version** | .NET 4.0 (TPL), C# 5.0 (async/await integration) |

---

## When To Use It

- **`Task.Run`**: Move CPU-intensive synchronous work off the calling thread to a thread pool thread — image processing, crypto, compression, heavy computation.
- **`Task.WhenAll`**: Fire multiple independent async operations concurrently and wait for all to finish.
- **`Task.WhenAny`**: Race multiple operations and act on whichever completes first — timeouts, fallback providers.
- **`Parallel.ForEach`**: Process a collection's elements in parallel across CPU cores for CPU-bound work. Not for async/await — use `Parallel.ForEachAsync` for that.

---

## Core Concept

`Task` represents a unit of work that may be pending, running, completed, or faulted. It's the return type for all async methods. You compose tasks with combinators:

- `WhenAll(tasks)`: complete when all tasks complete, aggregate all exceptions
- `WhenAny(tasks)`: complete when the first task completes — the others continue running
- `WhenAll` catches all exceptions; `await`ing a faulted `WhenAll` throws only the first (others in `task.Exception.InnerExceptions`)

`Parallel.ForEach` partitions the source collection across threads. It's synchronous (blocks until all work completes) and for CPU work only — using async delegates inside `Parallel.ForEach` leads to ignored tasks and wasted threads.

---

## The Code

**`Task.Run` — offload CPU work**
```csharp
// CPU-bound: run on thread pool thread, don't block UI/request thread
public async Task<byte[]> CompressAsync(byte[] data, CancellationToken ct)
{
    return await Task.Run(() =>
    {
        using var ms = new MemoryStream();
        using var gz = new GZipStream(ms, CompressionLevel.Optimal);
        gz.Write(data);
        gz.Flush();
        return ms.ToArray();
    }, ct);
}
```

**`Task.WhenAll` — concurrent async operations**
```csharp
// Sequential: total time = t1 + t2 + t3
var a = await FetchAAsync(ct);
var b = await FetchBAsync(ct);
var c = await FetchCAsync(ct);

// Concurrent: total time = max(t1, t2, t3)
var taskA = FetchAAsync(ct);
var taskB = FetchBAsync(ct);
var taskC = FetchCAsync(ct);
await Task.WhenAll(taskA, taskB, taskC);
string a = taskA.Result; string b = taskB.Result; string c = taskC.Result;
```

**`Task.WhenAny` — timeout and race patterns**
```csharp
// Timeout pattern
using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
cts.CancelAfter(TimeSpan.FromSeconds(5));

Task<string> workTask    = DoWorkAsync(cts.Token);
Task timeoutTask         = Task.Delay(Timeout.Infinite, cts.Token);

Task completed = await Task.WhenAny(workTask, timeoutTask);
if (completed == workTask)
    return workTask.Result;
throw new TimeoutException("Operation timed out");

// Fallback provider race — use whichever is fastest
Task<string> primary   = primaryProvider.GetAsync(key, ct);
Task<string> secondary = secondaryProvider.GetAsync(key, ct);
Task<string> winner    = (Task<string>)await Task.WhenAny(primary, secondary);
return await winner;
```

**`Parallel.ForEach` — CPU-parallel collection processing**
```csharp
// Good for CPU-bound: image resizing, encryption, compression
Parallel.ForEach(
    images,
    new ParallelOptions { MaxDegreeOfParallelism = Environment.ProcessorCount, CancellationToken = ct },
    image => ResizeImage(image, 800, 600));

// .NET 6+: async-capable parallel foreach
await Parallel.ForEachAsync(
    imageUrls,
    new ParallelOptions { MaxDegreeOfParallelism = 8, CancellationToken = ct },
    async (url, cancel) => await DownloadAndSaveAsync(url, cancel));
```

**Handling `WhenAll` exceptions**
```csharp
try
{
    await Task.WhenAll(taskA, taskB, taskC);
}
catch (Exception)
{
    // await only re-throws the FIRST exception
    // Inspect ALL exceptions:
    var allErrors = new[] { taskA, taskB, taskC }
        .Where(t => t.IsFaulted)
        .SelectMany(t => t.Exception!.InnerExceptions)
        .ToList();

    foreach (var ex in allErrors)
        logger.LogError(ex, "Task failed");
    throw;
}
```

---

## Gotchas

- **`Task.WhenAll` awaiting only re-throws the first exception.** Inspect `.Exception.InnerExceptions` on faulted tasks to see all failures.
- **`Parallel.ForEach` with async delegates doesn't work.** `Parallel.ForEach(items, async item => await ...)` — the lambda returns `Task` which Parallel treats as `object` and ignores. Use `Parallel.ForEachAsync` (.NET 6+) or `Task.WhenAll`.
- **`Task.Run` in ASP.NET Core is usually wrong.** ASP.NET Core already uses thread pool threads. Adding `Task.Run` context-switches for no benefit. Use it only for genuinely CPU-bound work.
- **Unbounded concurrency can exhaust resources.** `Task.WhenAll(orders.Select(o => ProcessAsync(o, ct)))` with 10,000 orders fires 10,000 simultaneous DB/HTTP requests. Use `SemaphoreSlim` or `Parallel.ForEachAsync` with `MaxDegreeOfParallelism` to throttle.

---

## Interview Angle

**What they're really testing:** Whether you understand when to use `Task.Run` vs `async`/`await` directly, and `WhenAll` vs sequential awaits.

**Common question forms:**
- "How do you run multiple async operations concurrently?"
- "When would you use `Task.Run`?"
- "What's the difference between `WhenAll` and `WaitAll`?"

**The depth signal:** A senior knows `WhenAll` is async (non-blocking), `WaitAll` is synchronous (blocks the thread), `Task.Run` is for CPU work (not I/O), and that `Parallel.ForEach` with async delegates silently ignores all the returned tasks.

---

## Related Topics

- [[dotnet/csharp/csharp-async-await.md]] — async/await is built on `Task`
- [[dotnet/csharp/csharp-cancellation-token.md]] — Cancellation flows through all TPL operations
- [[dotnet/csharp/csharp-channels.md]] — Pipelines for controlled async producer/consumer patterns

---

## Source

[Task Parallel Library — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/parallel-programming/task-parallel-library-tpl)

---
*Last updated: 2026-04-06*