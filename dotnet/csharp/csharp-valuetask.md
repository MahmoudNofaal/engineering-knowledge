# C# ValueTask

> A struct-based alternative to `Task<T>` that avoids the heap allocation when an async method completes synchronously — important for hot-path methods that usually return a cached result.

---

## Quick Reference

| | `Task<T>` | `ValueTask<T>` |
|---|---|---|
| **Type** | Reference type (class) | Value type (struct) |
| **Allocation** | Always 1 heap alloc | 0 if completes synchronously |
| **Can be awaited** | ✅ | ✅ |
| **Can be awaited twice** | ✅ | ❌ — undefined behaviour |
| **Use when** | General async | Hot path, often sync result |
| **C# version** | .NET 4.5 | .NET Core 2.0 / C# 7.0 |

---

## When To Use It

Use `ValueTask<T>` when:
1. The method **frequently completes synchronously** (cache hit, value already available)
2. The method is called at **very high frequency** (millions of times/second)

Both conditions should hold. For a method that sometimes completes synchronously, `Task<T>` is fine — the allocation cost is negligible for occasional calls. `ValueTask` exists for the specific scenario where you measure allocation pressure from `Task` in a hot path.

---

## Core Concept

A `Task<T>` is always a heap-allocated object — even for `return Task.FromResult(value)` in most scenarios. `ValueTask<T>` is a struct: when the operation completes synchronously, it wraps the result value directly with no heap allocation. When it must truly go async (suspends), it internally allocates a task-like object — same cost as `Task<T>`.

The critical constraint: **await a `ValueTask<T>` at most once**. Unlike `Task<T>`, a `ValueTask<T>` may internally share state with a pooled object that gets recycled after one await. Awaiting it twice, or storing it and awaiting later, produces undefined behaviour. Convert with `.AsTask()` if you need to await multiple times or store it.

---

## The Code

**Returning `ValueTask<T>` from a cache-first method**
```csharp
private readonly ConcurrentDictionary<int, User> _cache = new();

// Returns cached value without any heap allocation in the hot (cache-hit) path
public ValueTask<User?> GetUserAsync(int id, CancellationToken ct = default)
{
    if (_cache.TryGetValue(id, out User? cached))
        return ValueTask.FromResult(cached); // zero allocation — synchronous path

    return new ValueTask<User?>(LoadFromDbAsync(id, ct)); // async path — allocates
}

private async Task<User?> LoadFromDbAsync(int id, CancellationToken ct)
{
    var user = await dbContext.Users.FindAsync(new object[] { id }, ct);
    if (user is not null) _cache[id] = user;
    return user;
}
```

**Interface implementations**
```csharp
// Many BCL interfaces now use ValueTask for hot-path implementations
public interface IOrderCache
{
    ValueTask<Order?> GetAsync(Guid id, CancellationToken ct);
    ValueTask SetAsync(Order order, CancellationToken ct);
}
```

**Converting for multiple-await scenarios**
```csharp
ValueTask<string> vt = GetValueAsync();

// WRONG: awaiting twice — undefined behaviour
await vt;
await vt; // don't do this

// CORRECT: convert to Task<T> first if you need multiple awaits
Task<string> task = vt.AsTask();
string result1 = await task;
string result2 = await task; // fine — Task can be awaited multiple times
```

---

## Gotchas

- **Never await a `ValueTask<T>` more than once.** Convert with `.AsTask()` for multi-await scenarios.
- **Don't store `ValueTask<T>` in a field.** It may become invalid when the underlying object is recycled by a pool.
- **`ValueTask<T>` is heavier to produce correctly.** A missed `ConfigureAwait(false)` or wrong synchronous path can cause subtle bugs. Default to `Task<T>` and only switch when profiling confirms allocation pressure.
- **`async ValueTask<T>` still allocates a state machine when it awaits.** The benefit is only for the synchronous-completion path.

---

## Interview Angle

**What they're really testing:** Whether you know when `ValueTask` is appropriate and its one-await limitation.

**Common question forms:**
- "What is `ValueTask` and when would you use it?"
- "What's the difference between `Task<T>` and `ValueTask<T>`?"

**The depth signal:** A senior names the two required conditions (sync-path frequent + hot path), knows about the one-await constraint, and defaults to `Task<T>` unless they have profiling evidence.

---

## Related Topics

- [[dotnet/csharp/csharp-async-await.md]] — `ValueTask` is an optimisation on top of the async/await machinery
- [[dotnet/csharp/csharp-garbage-collector.md]] — Allocation pressure from `Task<T>` is what `ValueTask` eliminates

---

## Source

[ValueTask — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.threading.tasks.valuetask-1)

---
*Last updated: 2026-04-06*