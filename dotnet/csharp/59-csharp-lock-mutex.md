# C# lock and Mutex

> `lock` provides mutual exclusion within one process — only one thread at a time can execute the protected block. `Mutex` extends this across processes.

---

## Quick Reference

| | `lock` | `SemaphoreSlim` | `Mutex` |
|---|---|---|---|
| **Scope** | In-process | In-process | Cross-process |
| **Async support** | ❌ | ✅ `WaitAsync` | ❌ |
| **Max concurrency** | 1 | N | 1 |
| **IDisposable** | No | Yes | Yes |
| **Overhead** | Minimal | Small | High |

---

## When To Use It

Use `lock` when multiple threads share mutable state and you need to prevent concurrent modification — updating a cache, modifying a shared list, compound read-modify-write operations. Use `SemaphoreSlim` when you need to `await` inside the protected block (lock doesn't support async). Use `Mutex` only for cross-process coordination.

---

## Core Concept

`lock(obj) { ... }` compiles to `Monitor.Enter(obj)` / `Monitor.Exit(obj)`. Only one thread can hold the monitor on `obj` at a time; others block. The lock object must be a reference type, private, and should not be `this`, a `Type`, or a `string` (public objects let external code deadlock you or create unintended contention).

**`SemaphoreSlim(1, 1)`** is the async-compatible alternative — `await semaphore.WaitAsync()` suspends the method without blocking the thread while waiting.

---

## The Code

**`lock` — basic critical section**
```csharp
private readonly object _lock = new(); // private object — never expose it
private int _count;

public void Increment()
{
    lock (_lock)
    {
        _count++; // one thread at a time
    }
}
```

**`SemaphoreSlim` — async-compatible lock**
```csharp
private readonly SemaphoreSlim _sem = new(initialCount: 1, maxCount: 1);
private Cache _cache = new();

public async Task<string> GetAsync(string key, CancellationToken ct)
{
    await _sem.WaitAsync(ct);      // async wait — doesn't block the thread
    try
    {
        if (_cache.TryGet(key, out var v)) return v;
        string value = await _db.LoadAsync(key, ct); // async inside the lock
        _cache.Set(key, value);
        return value;
    }
    finally
    {
        _sem.Release(); // ALWAYS release — even on exception
    }
}
```

**`SemaphoreSlim(N)` — limit concurrency to N**
```csharp
// Allow max 4 concurrent downloads
var throttle = new SemaphoreSlim(4);

async Task DownloadAsync(string url, CancellationToken ct)
{
    await throttle.WaitAsync(ct);
    try   { await _client.DownloadAsync(url, ct); }
    finally { throttle.Release(); }
}

await Task.WhenAll(urls.Select(url => DownloadAsync(url, ct)));
```

---

## Gotchas

- **Never `await` inside a `lock` block.** `lock` holds a monitor on the thread — `await` may resume on a different thread, which doesn't hold the monitor. The compiler disallows `await` inside `lock`. Use `SemaphoreSlim` for async-safe locking.
- **Lock on `this`, `typeof(T)`, or string literals creates contention.** Multiple code paths that lock on `this` can interfere with each other. Use a dedicated private `object _lock = new()`.
- **Forgetting `finally` leaks the semaphore.** Always use try/finally with `SemaphoreSlim.Release()`. `lock` handles this automatically.
- **`lock` is not re-entrant in a useful way via `SemaphoreSlim(1,1)`.** The same thread calling `WaitAsync` twice deadlocks itself. Use `AsyncLocal<bool>` for re-entrant tracking if needed.

---

## Interview Angle

**What they're really testing:** Whether you know the `await`-inside-`lock` prohibition and its `SemaphoreSlim` fix.

**Common question forms:**
- "Can you `await` inside a `lock` block?"
- "How do you limit concurrent access to a resource in async code?"

**The depth signal:** A senior immediately explains why `await` inside `lock` is disallowed — the continuation may resume on a different thread that doesn't own the monitor — and reaches for `SemaphoreSlim(1,1)`.

---

## Related Topics

- [[dotnet/csharp/csharp-deadlocks.md]] — Lock ordering and how incorrect locking causes deadlocks
- [[dotnet/csharp/csharp-interlocked.md]] — Lock-free atomic operations for counters and flags

---

## Source

[lock statement — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/statements/lock)

---
*Last updated: 2026-04-06*