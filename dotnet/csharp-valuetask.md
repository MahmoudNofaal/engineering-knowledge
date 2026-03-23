# C# ValueTask

> A struct-based alternative to `Task<T>` that avoids a heap allocation when an async method can return synchronously most of the time.

---

## When To Use It

Use `ValueTask<T>` when a method is async by signature but frequently completes synchronously — cache lookups, buffer reads when data is already available, hot-path operations called millions of times per second. The allocation savings matter at scale.

Do not use it as a general replacement for `Task<T>`. If the result is almost always truly async, `Task<T>` is cheaper overall because the runtime caches common `Task<bool>` and `Task<int>` results and you lose that with `ValueTask`. Never store a `ValueTask` in a field or await it more than once — it is a single-use, consume-immediately type.

---

## Core Concept

Every `Task<T>` is a heap-allocated object. In hot paths — think a cache that hits 99% of the time — allocating a new `Task<bool>` for every call that returns `true` is pure GC pressure with no benefit. `ValueTask<T>` is a struct that can hold either a plain `T` (the synchronous result) or a reference to a real `Task<T>` (the async case). When the method completes synchronously, no heap object is created at all. When it actually has to go async, it falls back to a regular `Task<T>` under the hood. The trade-off is that `ValueTask` comes with usage constraints that `Task` doesn't have.

---

## The Code
```csharp
// --- Typical pattern: sync fast-path, async slow-path ---
private Dictionary<string, string> _cache = new();

public ValueTask<string> GetAsync(string key, CancellationToken ct = default)
{
    if (_cache.TryGetValue(key, out string? cached))
        return new ValueTask<string>(cached); // no allocation

    return new ValueTask<string>(FetchFromDbAsync(key, ct)); // wraps a real Task
}

private async Task<string> FetchFromDbAsync(string key, CancellationToken ct)
{
    await Task.Delay(50, ct); // simulate I/O
    string value = $"value:{key}";
    _cache[key] = value;
    return value;
}

// --- Awaiting: identical syntax to Task ---
string result = await GetAsync("user:42");

// --- IValueTaskSource: advanced pool-based pattern (avoids even the Task fallback) ---
// Used by System.IO.Pipelines and System.Net.Sockets internally.
// Only implement this if you're writing infrastructure-level code.
public ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken ct = default)
{
    if (_pipe.TryRead(out int bytesRead))
        return new ValueTask<int>(bytesRead);

    return new ValueTask<int>(_source, _source.Version); // reusable source
}

// --- What NOT to do ---
ValueTask<string> vt = GetAsync("user:42");
string a = await vt;
string b = await vt; // ILLEGAL: ValueTask may already be consumed/returned to pool

// Also illegal: storing and awaiting later
_storedTask = GetAsync("user:42"); // don't do this
```

---

## Gotchas

- **Awaiting a `ValueTask` twice is undefined behaviour.** If the underlying implementation uses `IValueTaskSource` (like `System.IO.Pipelines` does), the source may have been recycled and returned to a pool by the time you await it a second time. You get corrupt data, not an exception. Convert with `.AsTask()` first if you need to await multiple times.
- **`ValueTask` without `<T>` (non-generic) exists but is rare.** It represents a void-returning async operation. The same single-use rules apply, and it's easy to forget it exists — most developers only reach for `ValueTask<T>`.
- **Benchmarking is required to justify it.** The allocation savings only matter under sustained high throughput. In a typical CRUD API doing a few hundred RPS, switching from `Task<T>` to `ValueTask<T>` produces no measurable difference and adds cognitive overhead for the team.
- **`async` methods returning `ValueTask<T>` still allocate a state machine object on the heap when they actually go async.** The win is *only* on the synchronous fast-path. If your method has the `async` keyword and always hits an `await`, you saved nothing over `Task<T>`.
- **You cannot use `Task.WhenAll` or `Task.WhenAny` directly with `ValueTask`.** You must call `.AsTask()` on each one first, which defeats the allocation savings entirely. Design accordingly — if you need fan-out, stick to `Task<T>`.

---

## Interview Angle

**What they're really testing:** Whether you understand the cost model of async in .NET — specifically heap allocations, GC pressure, and when the runtime's `Task` caching already covers you.

**Common question form:** "When would you use `ValueTask` instead of `Task`?" or "What's the performance difference between `Task<T>` and `ValueTask<T>`?"

**The depth signal:** A junior says "`ValueTask` is faster because it's a struct." A senior explains *why* the struct matters only on the synchronous path, names the single-use constraint and what breaks if you violate it, mentions that `Task<bool>` and `Task<int>` are cached by the runtime making `ValueTask` irrelevant for those types in most cases, and knows that `IValueTaskSource` is the deeper pattern used by `System.IO.Pipelines` to recycle completion sources from a pool — eliminating allocations even in the async path.

---

## Related Topics

- [[dotnet/csharp-task-parallel-library.md]] — `ValueTask` is a drop-in at the call site but a different beast internally; understanding `Task` first is a prerequisite.
- [[dotnet/async-await-internals.md]] — The async state machine behaviour explains exactly when `ValueTask` saves an allocation and when it doesn't.
- [[dotnet/csharp-memory-and-span.md]] — `Span<T>`, `Memory<T>`, and `ValueTask` are the three pillars of zero-allocation hot-path design in .NET; they appear together in `System.IO.Pipelines`.
- [[dotnet/csharp-cancellation-token.md]] — `ValueTask`-returning methods should still accept `CancellationToken`; the token plumbing is identical to `Task`-based methods.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/api/system.threading.tasks.valuetask-1](https://learn.microsoft.com/en-us/dotnet/api/system.threading.tasks.valuetask-1)

---
*Last updated: 2026-03-23*