# C# lock and Mutex

> `lock` is a shorthand for `Monitor.Enter`/`Monitor.Exit` that protects a block of code so only one thread can run it at a time; `Mutex` is the OS-level equivalent that also works across processes.

---

## When To Use It

Use `lock` whenever multiple threads share mutable state within the same process — a shared cache, a counter, a collection. It is the right default: cheap, simple, and scoped to the process. Use `Mutex` only when you need cross-process mutual exclusion — preventing two instances of an application from running simultaneously, or coordinating access to a named shared resource across process boundaries. Do not use `Mutex` for in-process synchronization; it is 20–30× slower than `lock` due to kernel transitions and carries additional ownership rules that make it easy to misuse.

---

## Core Concept

`lock(obj)` compiles to a `Monitor.Enter` on entry and a `Monitor.Exit` inside a `finally` block. Only one thread can hold the monitor on a given object at a time; every other thread that tries to `lock` the same object blocks until the holder exits. The object you pass is just a token — its identity is what matters, not its value, which is why you always lock on a dedicated private `readonly object` rather than `this` or a string. A `Mutex` does the same job but through the operating system's named kernel object system, so two separate processes locking on a `Mutex` with the same name genuinely block each other. The OS also tracks which thread owns the mutex, which means only that exact thread can release it — a constraint `lock` does not have.

---

## The Code
```csharp
// --- lock: basic in-process mutual exclusion ---
public class Counter
{
    private readonly object _sync = new(); // dedicated lock object, never exposed
    private int _count;

    public void Increment()
    {
        lock (_sync)
        {
            _count++;
        }
    }

    public int Read()
    {
        lock (_sync) { return _count; }
    }
}

// --- What lock compiles to (equivalent manual form) ---
Monitor.Enter(_sync);
try
{
    _count++;
}
finally
{
    Monitor.Exit(_sync); // guaranteed even if an exception is thrown
}

// --- Monitor.TryEnter: non-blocking attempt with timeout ---
bool acquired = false;
Monitor.TryEnter(_sync, TimeSpan.FromMilliseconds(500), ref acquired);
if (!acquired)
{
    // another thread holds the lock — log and back off instead of deadlocking
    throw new TimeoutException("Could not acquire lock within 500ms.");
}
try { /* work */ }
finally { if (acquired) Monitor.Exit(_sync); }

// --- Monitor.Wait / Pulse: producer-consumer signalling inside a lock ---
private readonly object _gate = new();
private Queue<int> _queue = new();

void Producer()
{
    lock (_gate)
    {
        _queue.Enqueue(42);
        Monitor.Pulse(_gate); // wake one waiting consumer
    }
}

void Consumer()
{
    lock (_gate)
    {
        while (_queue.Count == 0)
            Monitor.Wait(_gate); // releases lock and suspends; re-acquires on wake

        int item = _queue.Dequeue();
    }
}

// --- Mutex: named, cross-process single-instance guard ---
const string MutexName = "Global\\MyApp_SingleInstance";

using var mutex = new Mutex(initiallyOwned: false, name: MutexName,
                            out bool createdNew);
if (!createdNew)
{
    Console.WriteLine("Another instance is already running.");
    return;
}

// Only one process reaches here at a time.
RunApplication();
// Mutex released automatically when disposed or process exits.

// --- Mutex: cross-process file access coordination ---
using var fileMutex = new Mutex(initiallyOwned: false, "Global\\SharedFileAccess");
fileMutex.WaitOne();
try
{
    File.AppendAllText("shared.log", "entry\n");
}
finally
{
    fileMutex.ReleaseMutex(); // must be called on the same thread that called WaitOne
}
```

---

## Gotchas

- **Never lock on `this`, a public object, or a string literal.** Any external code that holds a reference to the same object can lock on it too, creating unexpected contention or deadlocks. Always lock on a `private readonly object` created specifically for that purpose.
- **`Mutex.ReleaseMutex()` must be called from the thread that acquired it.** Unlike `lock`, a `Mutex` has thread affinity. If the acquiring thread exits without releasing — due to an exception that skips the `finally`, or a thread abort in .NET Framework — the mutex becomes "abandoned" and waiters receive an `AbandonedMutexException` on their next `WaitOne`. This is the OS signalling that protected state may be corrupt.
- **`lock` is not async-compatible.** You cannot `await` inside a `lock` block. The compiler blocks it because a thread switch could occur between `Enter` and `Exit`, releasing on a different thread than acquired — which Monitor forbids. Use `SemaphoreSlim.WaitAsync` instead.
- **Locking on `typeof(T)` or a shared static field causes cross-assembly contention.** If two unrelated libraries both lock on `typeof(SomeCommonType)`, they silently block each other. A private `static readonly object _sync = new()` within your class is always the safe choice for static-level locking.
- **`Monitor.Wait` must be called inside the lock, but it releases it.** This surprises people: `Wait` atomically releases the lock and suspends the thread. When `Pulse` wakes it, it re-acquires the lock before returning. Forgetting that `Wait` releases the lock leads to reasoning errors about what state is protected during the wait.

---

## Interview Angle

**What they're really testing:** Whether you understand what a lock actually compiles to, the rules around what object to lock on, and when a kernel primitive is warranted over a managed one.

**Common question form:** "What's the difference between `lock` and `Mutex`?" or "What are the rules for choosing a good lock object?"

**The depth signal:** A junior says "`lock` is for threads, `Mutex` is for processes." A senior adds: that `lock` compiles to `Monitor.Enter`/`Exit` in a `finally`; that the lock object must be private, readonly, and never a value type (boxing a struct creates a new object each time, so every `lock` on it succeeds — no mutual exclusion at all); that `Mutex` carries thread affinity and `AbandonedMutexException` semantics that `lock` does not; and that for async code neither `lock` nor `Mutex` applies — `SemaphoreSlim.WaitAsync` is the correct tool because it yields the thread rather than blocking it.

---

## Related Topics

- [[dotnet/csharp-deadlocks.md]] — Inconsistent lock ordering across two `lock` blocks is the classic two-thread deadlock; understanding both together prevents it.
- [[dotnet/csharp-thread-synchronization.md]] — `ReaderWriterLockSlim`, `Interlocked`, and `SemaphoreSlim` sit alongside `lock` in the synchronization toolkit; knowing when each applies matters.
- [[dotnet/csharp-threads.md]] — `lock` only makes sense once you understand that multiple threads can reach the same code simultaneously and why that is dangerous.
- [[dotnet/csharp-cancellation-token.md]] — `SemaphoreSlim.WaitAsync(ct)` is the async-safe replacement for `lock` in async contexts and accepts a token for timeout/cancellation.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/standard/threading/overview-of-synchronization-primitives](https://learn.microsoft.com/en-us/dotnet/standard/threading/overview-of-synchronization-primitives)

---
*Last updated: 2026-03-23*