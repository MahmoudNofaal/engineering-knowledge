# C# — IEnumerable\<T\>

> The base interface for anything you can loop over in C# — it promises one thing: give me an enumerator that can walk elements one at a time, on demand.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Pull-based lazy sequence contract |
| **Core method** | `GetEnumerator()` → `IEnumerator<T>` with `MoveNext()` / `Current` |
| **Use when** | Caller only needs to iterate — not count, not index, not add |
| **Avoid when** | Caller needs `Count`, random access, or multiple passes on expensive source |
| **Prefer instead** | `IReadOnlyList<T>` when materialised; `IReadOnlyCollection<T>` when count needed |
| **C# version** | C# 2.0 (generic), `IAsyncEnumerable<T>`: C# 8.0 |

---

## When To Use It

Use `IEnumerable<T>` as a parameter or return type when the caller only needs to iterate — not count, not index, not add. It keeps the method collection-agnostic: the caller can pass any source (`List`, array, database cursor, generator).

**Return `IReadOnlyList<T>` instead when:**
- The data is already materialised and the caller might need `Count` or indexing
- Multiple passes would re-execute expensive logic

**Return `IEnumerable<T>` when:**
- Producing a potentially infinite or large lazy sequence
- The caller may stop consuming early (`Take(3)` on an infinite sequence)

---

## Core Concept

`IEnumerable<T>` is just `GetEnumerator()` which returns an `IEnumerator<T>` with `MoveNext()`, `Current`, and `Reset()`. That's the entire contract. `foreach` calls `GetEnumerator()` then calls `MoveNext()` until it returns false.

What makes it powerful: it's **pull-based and lazy** — nothing happens until someone calls `MoveNext()`. This is why LINQ chains don't execute immediately, why an infinite `Fibonacci()` sequence is safe, and why `Take(3)` on that sequence only produces three elements without generating the rest.

The flip side: every time you enumerate an `IEnumerable<T>`, it starts from scratch. There's no memory of the previous pass.

---

## The Code

**What `foreach` actually desugars to**
```csharp
IEnumerable<int> numbers = new List<int> { 1, 2, 3 };
// foreach is exactly this:
IEnumerator<int> enumerator = numbers.GetEnumerator();
while (enumerator.MoveNext())
    Console.WriteLine(enumerator.Current);
```

**Lazy evaluation — nothing runs until iterated**
```csharp
IEnumerable<int> GetNumbers()
{
    Console.WriteLine("start");
    yield return 1;
    Console.WriteLine("after 1");
    yield return 2;
    Console.WriteLine("after 2");
    yield return 3;
}

var query = GetNumbers().Where(x => x > 1); // nothing printed yet

foreach (var n in query) // now it runs, interleaved
    Console.WriteLine(n);
// start → after 1 → after 2 → 2 → after 2 → 3
```

**Double enumeration bug — the classic production mistake**
```csharp
IEnumerable<string> GetUsers() => FetchFromDatabase(); // expensive call

void ProcessBad(IEnumerable<string> users)
{
    if (!users.Any())   // first DB hit (at least partial scan)
        return;
    foreach (var u in users) // SECOND DB hit — full scan
        Console.WriteLine(u);
}

// Fix: materialise once
void ProcessGood(IEnumerable<string> users)
{
    var list = users.ToList();  // one DB hit
    if (!list.Any()) return;    // free — in memory
    foreach (var u in list) Console.WriteLine(u);
}
```

**Return type discipline**
```csharp
// Bad: caller can't get Count without full enumeration
IEnumerable<Order> GetOrders() => _db.Orders.ToList();

// Better: signal it's already materialised
IReadOnlyList<Order> GetOrders() => _db.Orders.ToList();

// Correct use of IEnumerable: truly lazy, one-pass
IEnumerable<Order> StreamLargeOrders()
{
    foreach (var order in _db.Orders.AsNoTracking())
        if (order.Total > 10_000)
            yield return order;
}
```

---

## Gotchas

- **Double enumeration is silent and expensive.** Calling `Any()` then `foreach` on a DB-backed `IEnumerable<T>` hits the database twice. Always `ToList()` before multiple passes.
- **`Reset()` on most real enumerators throws `NotSupportedException`.** Don't call it.
- **`IEnumerable<T>` hides whether the source is already materialised.** Callers can't tell if it's a `List` or a DB query — exposing `IReadOnlyList<T>` when appropriate is more honest.
- **Closures captured in deferred sequences capture by reference.** A loop variable captured in a `yield return` sequence uses the final value by the time it's enumerated.

---

## Interview Angle

**What they're really testing:** Whether you understand lazy evaluation and what the interface's contract actually means.

**Common question forms:**
- "What's the difference between `IEnumerable<T>` and `IList<T>`?"
- "What's wrong with this code?" (showing double-enumeration)
- "How does `yield return` work?"

**The depth signal:** A senior explains deferred execution — each LINQ operator wraps the previous in a new enumerator, and `MoveNext()` pulls values through the chain on demand. They know that `IEnumerable<T>` signals intent (one forward pass), while `IReadOnlyList<T>` signals the data is already in memory.

---

## Related Topics

- [[dotnet/csharp/csharp-iterators.md]] — `yield return` implements `IEnumerable<T>` lazily
- [[dotnet/csharp/csharp-linq-basics.md]] — LINQ is built entirely on `IEnumerable<T>` and `IQueryable<T>`
- [[dotnet/csharp/csharp-linq-deferred-execution.md]] — Why LINQ queries don't execute immediately

---

## Source

[IEnumerable\<T\> — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.ienumerable-1)

---
*Last updated: 2026-04-06*