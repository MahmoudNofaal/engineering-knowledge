# C# Deadlocks

> A deadlock is when two or more threads block each other permanently because each is waiting for a resource the other holds.

---

## When To Use It

This isn't a pattern to use — it's a failure mode to understand and avoid. It matters any time you mix synchronous blocking (`.Result`, `.Wait()`, `lock`) with async code, or when multiple threads acquire shared locks in inconsistent order. Understanding deadlocks is essential when writing ASP.NET middleware, library code that may be called from any synchronization context, or anything that touches shared state across threads.

---

## Core Concept

A deadlock needs four conditions to exist simultaneously: mutual exclusion (only one thread can hold a resource), hold and wait (a thread holds one resource while waiting for another), no preemption (you can't forcibly take a resource from a thread), and circular wait (thread A waits on thread B which waits on thread A). In .NET, the most common deadlock isn't the classic two-lock circular wait — it's sync-over-async: you call `.Result` or `.Wait()` on a `Task` on a thread that owns a `SynchronizationContext` (like an ASP.NET Framework request thread or a UI thread). The `await` continuation needs that same thread to resume, but it's blocked waiting for the task. Neither can proceed.

---

## The Code
```csharp
// --- Classic sync-over-async deadlock (ASP.NET Framework / UI thread) ---
// This DEADLOCKS on any SynchronizationContext that marshals continuations
// back to the original thread (WinForms, WPF, ASP.NET Framework).
public string GetData()
{
    return FetchAsync().Result; // blocks the thread that owns the context
}

private async Task<string> FetchAsync()
{
    await Task.Delay(100); // tries to resume on the captured context — which is blocked
    return "data";
}

// Fix 1: go async all the way up
public async Task<string> GetDataAsync()
{
    return await FetchAsync();
}

// Fix 2: use ConfigureAwait(false) in library code so the continuation
// does NOT need the original context to resume
private async Task<string> FetchAsync()
{
    await Task.Delay(100).ConfigureAwait(false);
    return "data";
}

// --- Classic two-lock deadlock ---
private static readonly object _lockA = new();
private static readonly object _lockB = new();

// Thread 1: acquires A then tries to acquire B
void Thread1()
{
    lock (_lockA)
    {
        Thread.Sleep(50); // gives Thread 2 time to grab B
        lock (_lockB) { /* work */ }
    }
}

// Thread 2: acquires B then tries to acquire A
void Thread2()
{
    lock (_lockB)
    {
        lock (_lockA) { /* work */ }
    }
}

// Fix: always acquire locks in the same order everywhere
void Thread1Fixed()
{
    lock (_lockA) { lock (_lockB) { /* work */ } }
}
void Thread2Fixed()
{
    lock (_lockA) { lock (_lockB) { /* work */ } }
}

// --- Using Monitor.TryEnter to detect and bail instead of blocking forever ---
bool gotA = false, gotB = false;
try
{
    Monitor.TryEnter(_lockA, TimeSpan.FromSeconds(1), ref gotA);
    Monitor.TryEnter(_lockB, TimeSpan.FromSeconds(1), ref gotB);

    if (!gotA || !gotB)
    {
        // couldn't acquire both — log, retry, or throw
        throw new TimeoutException("Could not acquire locks; possible deadlock.");
    }
    // do work
}
finally
{
    if (gotB) Monitor.Exit(_lockB);
    if (gotA) Monitor.Exit(_lockA);
}

// --- SemaphoreSlim async-friendly locking (avoids sync deadlock entirely) ---
private static readonly SemaphoreSlim _sem = new(1, 1);

public async Task DoWorkAsync(CancellationToken ct)
{
    await _sem.WaitAsync(ct); // yields instead of blocking the thread
    try
    {
        await SomeAsyncOperation().ConfigureAwait(false);
    }
    finally
    {
        _sem.Release();
    }
}
```

---

## Gotchas

- **`.Result` and `.Wait()` are safe in ASP.NET Core but dangerous in ASP.NET Framework and UI apps.** ASP.NET Core has no `SynchronizationContext` by default, so sync-over-async won't deadlock there — but the code is still wrong to write because it blocks a thread pool thread under load, and it will deadlock the moment you run the same code in a context that does have one.
- **`ConfigureAwait(false)` only helps if every `await` in the call chain uses it.** One missing `ConfigureAwait(false)` deep in a library recaptures the context and the deadlock risk returns. This is why library code must use it consistently, and application code generally doesn't need to bother.
- **`lock` is not async-compatible.** You cannot `await` inside a `lock` block — the compiler blocks it. If you try to work around this with `Monitor.Enter`/`Monitor.Exit` manually, you introduce the risk of exceptions leaving the lock held. Use `SemaphoreSlim` with `WaitAsync` instead.
- **Thread.Sleep inside a lock is a deadlock waiting to happen in tests.** It's common in integration tests to add sleeps to simulate timing — doing so while holding a lock holds it longer than intended and can trigger the circular-wait condition with other test threads.
- **Visual Studio's parallel stacks window is the fastest way to diagnose a live deadlock.** Debug → Windows → Parallel Stacks. Look for two threads each blocked in a `Monitor.Enter` or `WaitOne` pointing at each other. In production, capture a memory dump and analyse with WinDbg `!dlk` or dotnet-dump.

---

## Interview Angle

**What they're really testing:** Whether you understand both the classic multi-lock deadlock and the async-specific sync-over-async variant — and how to prevent each.

**Common question form:** "Have you ever caused a deadlock? How did you find it?" or "Why does calling `.Result` on a `Task` sometimes deadlock?"

**The depth signal:** A junior describes the two-thread, two-lock textbook scenario. A senior explains the sync-over-async variant — naming `SynchronizationContext` as the mechanism, explaining why ASP.NET Framework and UI threads are affected but ASP.NET Core is not, why `ConfigureAwait(false)` must be applied at every level in library code to actually break the capture, and that `SemaphoreSlim.WaitAsync` is the correct replacement for `lock` whenever you need to await inside a critical section.

---

## Related Topics

- [[dotnet/csharp-task-parallel-library.md]] — Most async deadlocks originate from misusing `Task`; understanding TPL is the prerequisite.
- [[dotnet/csharp-cancellation-token.md]] — `SemaphoreSlim.WaitAsync` accepts a `CancellationToken`; without one, a deadlocked semaphore wait blocks forever with no escape.
- [[dotnet/csharp-thread-synchronization.md]] — `Monitor`, `Mutex`, `ReaderWriterLockSlim` — the full set of locking primitives and their ordering rules.
- [[dotnet/async-await-internals.md]] — `SynchronizationContext` capture is the root cause of sync-over-async deadlocks; understanding how `await` captures context makes the failure mode obvious.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/standard/threading/overview-of-synchronization-primitives](https://learn.microsoft.com/en-us/dotnet/standard/threading/overview-of-synchronization-primitives)

---
*Last updated: 2026-03-23*