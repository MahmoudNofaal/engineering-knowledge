# C# Threads

> A thread is the smallest unit of execution the OS schedules — raw, manually managed, long-lived, and expensive compared to tasks or thread pool work items.

---

## When To Use It

Reach for raw `Thread` when you need explicit control that the thread pool won't give you: setting `IsBackground`, `ApartmentState` (for COM interop or WinForms), or a fixed thread affinity. You also need a dedicated thread when the work runs for the entire lifetime of the process — like a message pump or a pinned hardware I/O loop — because the thread pool reclaims idle workers and is not designed for permanent occupancy.

Do not use raw threads for general async work, parallelism over data, or anything that completes in under a few seconds. `Task.Run` and `Parallel.For` handle those cases with less overhead and better scheduling. Every `new Thread()` costs roughly 1 MB of reserved stack space by default.

---

## Core Concept

A `Thread` object maps 1-to-1 to an OS thread. You create it, you start it, and it runs until its method returns — or you abort it (which you shouldn't). The thread pool is a collection of pre-created threads that the runtime lends out for short work items and reclaims when done. When you write `Task.Run(...)`, you are scheduling a work item on the pool, not creating a thread. The pool auto-tunes its size based on throughput. A raw `Thread` bypasses all of that: you own it completely, which means you're responsible for its lifetime, exception handling, and ensuring it actually terminates. That control is rarely worth the cost unless you have a specific reason the pool can't serve you.

---

## The Code
```csharp
// --- Create and start a thread ---
var thread = new Thread(() =>
{
    Console.WriteLine($"Running on thread {Thread.CurrentThread.ManagedThreadId}");
    Thread.Sleep(500);
});

thread.Name = "WorkerThread";      // shows up in debugger and logs
thread.IsBackground = true;        // process can exit without waiting for this thread
thread.Start();
thread.Join();                     // block caller until thread finishes

// --- Passing data in (use a lambda, not the object overload) ---
int input = 42;
var t = new Thread(() => Process(input));
t.Start();

// --- Thread with explicit stack size (reduce from 1 MB default) ---
var smallStack = new Thread(() => DoWork(), maxStackSize: 256 * 1024);
smallStack.Start();

// --- ThreadLocal<T>: per-thread state without locks ---
ThreadLocal<Random> threadRng = new(() => new Random());

var threads = Enumerable.Range(0, 4).Select(_ => new Thread(() =>
{
    int val = threadRng.Value!.Next(100); // each thread gets its own Random instance
    Console.WriteLine(val);
})).ToList();

threads.ForEach(t => t.Start());
threads.ForEach(t => t.Join());
threadRng.Dispose();

// --- Foreground vs background: what happens at process exit ---
var fg = new Thread(() => { Thread.Sleep(5000); Console.WriteLine("fg done"); });
fg.IsBackground = false; // DEFAULT — process waits for this to finish
fg.Start();

var bg = new Thread(() => { Thread.Sleep(5000); Console.WriteLine("bg done"); });
bg.IsBackground = true;  // process exits without waiting — "bg done" may never print
bg.Start();

// --- ApartmentState for COM interop (WinForms, Shell dialogs) ---
var sta = new Thread(() =>
{
    // OpenFileDialog and many COM components require STA
    var dlg = new System.Windows.Forms.OpenFileDialog();
    dlg.ShowDialog();
});
sta.SetApartmentState(ApartmentState.STA);
sta.Start();
sta.Join();

// --- Volatile for a shared cancellation flag across threads ---
volatile bool _stop = false;

var worker = new Thread(() =>
{
    while (!_stop)          // without volatile, JIT may cache this in a register
    {
        DoWork();
    }
});
worker.Start();
Thread.Sleep(2000);
_stop = true;
worker.Join();
```

---

## Gotchas

- **Foreground threads silently keep the process alive.** `IsBackground` defaults to `false`, so a thread you forgot to join or signal holds the process open indefinitely. Always set `IsBackground = true` for threads that aren't critical to a clean shutdown, or wire them into a `CancellationToken`.
- **`Thread.Abort()` is removed in .NET Core and later.** It existed in .NET Framework and worked by injecting a `ThreadAbortException` at an arbitrary point — a notoriously unsafe mechanism that corrupted state. The replacement is cooperative cancellation via `CancellationToken`. Code that relies on `Abort` will not compile on modern .NET.
- **Unhandled exceptions on a background thread crash the process in .NET 4.0+.** Before 4.0, they were silently swallowed. Now, any exception that escapes a thread's entry method triggers `AppDomain.UnhandledException` and then terminates the process. Wrap thread bodies in a `try/catch` if you want to handle errors gracefully.
- **`ThreadLocal<T>` values are not automatically disposed when the thread exits.** If `T` implements `IDisposable`, you must call `threadLocal.Dispose()` explicitly on the owning thread or accept the leak. This is particularly easy to miss in thread pool scenarios where you don't control thread lifetime.
- **Shared mutable state requires explicit synchronization even for simple reads.** Without `volatile`, `Interlocked`, or a `lock`, the JIT and CPU are free to reorder reads and writes or cache values in registers. A `bool` flag shared between threads without `volatile` can result in an infinite loop on release builds even though debug builds behave correctly.

---

## Interview Angle

**What they're really testing:** Whether you know the difference between a thread, the thread pool, and a task — and when the raw primitive is actually the right tool.

**Common question form:** "What's the difference between `Thread` and `Task`?" or "When would you use `new Thread()` instead of `Task.Run`?"

**The depth signal:** A junior says "`Task` is newer and easier." A senior explains that `Task.Run` schedules onto the thread pool which auto-tunes and recycles workers, making it wrong for permanent/long-running occupancy; names the specific cases where raw threads win — STA apartment state for COM, explicit `IsBackground` control, pinned hardware I/O loops; knows that every `new Thread()` reserves ~1 MB of stack by default; and understands that `volatile` and `Interlocked` are the lightweight alternatives to `lock` for simple shared flags, and why the JIT makes them necessary.

---

## Related Topics

- [[dotnet/csharp-task-parallel-library.md]] — Tasks are the right default for almost everything threads used to be used for; understanding both shows where each belongs.
- [[dotnet/csharp-deadlocks.md]] — Most deadlocks involve threads contending for locks; the failure modes are clearer once you understand the thread model.
- [[dotnet/csharp-cancellation-token.md]] — The correct way to stop a long-running thread loop in modern .NET, replacing the removed `Thread.Abort`.
- [[dotnet/csharp-thread-synchronization.md]] — `lock`, `Monitor`, `Interlocked`, `SemaphoreSlim` — the tools you reach for the moment two threads share state.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/standard/threading/threads-and-threading](https://learn.microsoft.com/en-us/dotnet/standard/threading/threads-and-threading)

---
*Last updated: 2026-03-23*