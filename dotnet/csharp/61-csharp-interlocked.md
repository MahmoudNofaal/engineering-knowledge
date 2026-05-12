# C# Interlocked

> Atomic CPU-level operations on shared variables — read-modify-write in a single uninterruptible instruction, with no lock overhead.

---

## Quick Reference

| Method | What it does |
|---|---|
| `Interlocked.Increment(ref n)` | `n++` atomically |
| `Interlocked.Decrement(ref n)` | `n--` atomically |
| `Interlocked.Add(ref n, v)` | `n += v` atomically |
| `Interlocked.Exchange(ref n, v)` | Set `n = v`, return old value |
| `Interlocked.CompareExchange(ref n, v, comp)` | If `n == comp`, set `n = v` — CAS |
| `Interlocked.Read(ref n)` | Atomic read of `long` on 32-bit |

---

## When To Use It

Use `Interlocked` for **single-variable atomic counters and flags** where a `lock` block would be the only content. It's faster than a lock (no contention, no context switch) but only works for single-variable operations. Any multi-variable compound operations still need a lock.

---

## Core Concept

On modern x86/x64, operations like `inc [memory]` are atomic if the data is properly aligned — the CPU guarantees no other CPU core can read a half-updated value. `Interlocked` exposes these instructions. The key constraint: each method operates on exactly one variable.

`CompareExchange` (CAS) is the foundation of all lock-free data structures. "If the value is still what I read, update it; if something changed it, retry." All `ConcurrentDictionary` and `ConcurrentQueue` internals use CAS loops.

---

## The Code

**Atomic counter**
```csharp
private long _requestCount;

public void OnRequest()
    => Interlocked.Increment(ref _requestCount);

public long GetCount()
    => Interlocked.Read(ref _requestCount); // safe on 32-bit platforms
```

**Thread-safe lazy initialisation with `CompareExchange`**
```csharp
private static ConnectionPool? _instance;
private static readonly object _initLock = new();

public static ConnectionPool Instance
{
    get
    {
        // Double-checked locking — Interlocked.CompareExchange for atomicity
        if (_instance == null)
        {
            var newPool = new ConnectionPool();
            Interlocked.CompareExchange(ref _instance, newPool, null);
            // If two threads both get here, one wins and the loser's pool is abandoned
        }
        return _instance;
    }
}
```

**Implementing a spin-lock with CAS**
```csharp
private int _locked; // 0 = free, 1 = taken

void Enter()
{
    while (Interlocked.CompareExchange(ref _locked, 1, 0) != 0)
        Thread.SpinWait(10); // spin briefly before yielding
}
void Exit() => Interlocked.Exchange(ref _locked, 0);
```

---

## Gotchas

- **`Interlocked` only applies to one variable.** `Interlocked.Increment(ref a); Interlocked.Increment(ref b);` is NOT atomic as a pair — use `lock` for multi-variable operations.
- **`volatile` is not enough for read-modify-write.** `volatile int x; x++;` is still not atomic — two separate instructions (read, write). Use `Interlocked.Increment`.
- **CAS ABA problem.** A value that changes from A → B → A between your read and your CAS looks unchanged. Use `Interlocked.CompareExchange<T>` with reference types or versioned structs.

---

## Interview Angle

**What they're really testing:** Whether you know when atomics are sufficient and when a lock is still needed.

**Common question forms:**
- "How do you safely increment a counter from multiple threads?"
- "What's the difference between `Interlocked` and `lock`?"

**The depth signal:** A senior reaches for `Interlocked.Increment` for a simple counter, but immediately switches to `lock` (or `SemaphoreSlim`) for any multi-step compound operation — and explains why.

---

## Related Topics

- [[dotnet/csharp/csharp-lock-mutex.md]] — `lock` for multi-variable compound operations
- [[dotnet/csharp/csharp-concurrent-collections.md]] — `ConcurrentDictionary` uses CAS internally

---

## Source

[Interlocked — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.threading.interlocked)

---
*Last updated: 2026-04-06*