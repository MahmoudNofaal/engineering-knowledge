# C# Threads

> A `Thread` is the lowest-level unit of concurrent execution — a managed wrapper around an OS thread with its own stack, scheduled by the OS kernel.

---

## Quick Reference

| | |
|---|---|
| **Thread pool** | `Task.Run`, `ThreadPool.QueueUserWorkItem` — preferred |
| **Explicit thread** | `new Thread(() => ...)` — for long-running, dedicated work |
| **Thread-local** | `ThreadLocal<T>`, `[ThreadStatic]` — per-thread state |
| **Current context** | `Thread.CurrentThread`, `Thread.CurrentManagedThreadId` |
| **C# version** | C# 1.0 |

---

## When To Use It

Use `Thread` only when you need a **dedicated long-running thread** — a background service that runs for the application lifetime. For most concurrent work, use `Task.Run` (thread pool), `async`/`await` (I/O), or `Parallel.ForEach` (CPU parallelism). Thread pool threads are reused; explicit threads add OS overhead.

---

## Core Concept

A `Thread` maps 1:1 to an OS thread with a dedicated stack (~1 MB by default). The OS scheduler preemptively switches between threads — you have no control over when a thread runs or is preempted. Thread creation is expensive (~1 ms, ~1 MB of stack); the thread pool amortises this by reusing a pool of pre-created threads.

Every managed thread can be:
- **Foreground** (default): the CLR keeps the process alive until all foreground threads finish
- **Background**: killed when the last foreground thread exits

---

## The Code

**Thread basics**
```csharp
// Foreground thread — process waits for it
var t = new Thread(() =>
{
    Console.WriteLine($"Running on thread {Thread.CurrentThread.ManagedThreadId}");
    Thread.Sleep(1000);
});
t.Name = "Worker";
t.Start();
t.Join(); // block until thread finishes

// Background thread — process doesn't wait
var bg = new Thread(BackgroundWork) { IsBackground = true };
bg.Start();
```

**`ThreadLocal<T>` — per-thread state**
```csharp
var counter = new ThreadLocal<int>(() => 0); // each thread starts at 0
Parallel.For(0, 4, _ =>
{
    counter.Value++;
    Console.WriteLine($"Thread {Thread.CurrentThread.ManagedThreadId}: {counter.Value}");
    // Each thread sees its own counter — always 1
});
```

**`Thread.Sleep` vs `Task.Delay`**
```csharp
Thread.Sleep(1000);  // blocks the thread — wastes a thread for 1 second
await Task.Delay(1000); // suspends the method — thread returned to pool during wait
```

---

## Gotchas

- **`Thread.Sleep(0)` yields to other threads; `Thread.Sleep(1)` is ≥ 1 timer-tick (~15 ms on Windows).** Don't use `Thread.Sleep` for precise timing.
- **Unhandled exceptions on non-pool threads crash the process.** Wrap thread entry points in try/catch.
- **Background threads are killed abruptly.** Any cleanup in their body may not run. Use `CancellationToken` + graceful shutdown.

---

## Source

[Threads — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/threading/threads-and-threading)

---
*Last updated: 2026-04-06*