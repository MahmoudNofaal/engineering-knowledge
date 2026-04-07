# C# Immutable Collections

> Collections from `System.Collections.Immutable` that can never be modified after creation — any "change" returns a new collection via structural sharing, leaving the original untouched.

---

## Quick Reference

| Type | Notes |
|---|---|
| `ImmutableList<T>` | Balanced tree — O(log n) reads/writes, O(1) sharing |
| `ImmutableArray<T>` | Plain array wrapper — O(1) reads, O(n) writes, no GC per item |
| `ImmutableDictionary<K,V>` | Hash-array mapped trie — O(log n) |
| `ImmutableHashSet<T>` | Same as ImmutableDictionary, set semantics |
| Builder pattern | Batch mutations cheaply, produce immutable result |

---

## When To Use It

Use immutable collections when you need to share a collection across threads without locking, preserve snapshots of state (event sourcing, undo history), or guarantee that passed data can never be mutated.

Don't use them as a general-purpose replacement for mutable collections — every modification allocates (or shares structure), which adds up in write-heavy code.

---

## Core Concept

A standard `List<T>` mutates in place. An `ImmutableList<T>` is a balanced tree. When you call `Add()`, it builds a new tree that shares most nodes with the old one — structural sharing means you're not copying the whole collection, just the path from root to changed node (O(log n) nodes). The original is untouched.

**`ImmutableArray<T>`** is different: it's a struct wrapping a plain array. Reads are O(1) like a regular array. Mutations (Add, Remove) copy the entire array — O(n). Use it when you build once and read many times.

Thread safety: multiple threads can hold references to the same immutable collection with zero synchronisation because nothing ever changes.

---

## The Code

**Basic usage — mutations return new instances**
```csharp
using System.Collections.Immutable;

var original = ImmutableList<string>.Empty;
var withOne  = original.Add("alice");
var withTwo  = withOne.Add("bob");

Console.WriteLine(original.Count); // 0 — untouched
Console.WriteLine(withTwo.Count);  // 2

var removed = withTwo.Remove("bob");
Console.WriteLine(withTwo.Count);  // 2 — still 2
Console.WriteLine(removed.Count);  // 1
```

**Builder — batch mutations without intermediate allocations**
```csharp
// Building 10,000 items one Add() at a time = 10,000 tree allocations
// Builder accumulates changes efficiently, then produces one immutable result
var builder = ImmutableList.CreateBuilder<int>();
for (int i = 0; i < 10_000; i++)
    builder.Add(i);                      // mutates builder in place (like List<T>)
ImmutableList<int> result = builder.ToImmutable(); // one final allocation
```

**`ImmutableArray<T>` — O(1) reads**
```csharp
ImmutableArray<int> primes = ImmutableArray.Create(2, 3, 5, 7, 11);
Console.WriteLine(primes[2]); // 5 — O(1) direct index

// Builder pattern applies here too
var arrBuilder = ImmutableArray.CreateBuilder<int>(initialCapacity: 100);
arrBuilder.Add(1); arrBuilder.Add(2);
ImmutableArray<int> arr = arrBuilder.ToImmutable();
```

**Thread-safe snapshot publishing**
```csharp
// Volatile reference swap: readers always see a consistent snapshot
private volatile ImmutableList<string> _users = ImmutableList<string>.Empty;

public void AddUser(string user)
    => _users = _users.Add(user); // single volatile write — safe for single writer

public ImmutableList<string> GetSnapshot() => _users; // no lock needed
```

---

## Real World Example

A feature flag service uses an `ImmutableDictionary` as its in-memory store. Reader threads access flags with zero locking; a background refresh thread replaces the whole dictionary atomically.

```csharp
public class FeatureFlagService
{
    private volatile ImmutableDictionary<string, bool> _flags
        = ImmutableDictionary<string, bool>.Empty;

    // Readers: lock-free, no allocation
    public bool IsEnabled(string feature)
        => _flags.GetValueOrDefault(feature, false);

    // Writer: replaces entire snapshot atomically
    public void Refresh(Dictionary<string, bool> newFlags)
        => _flags = newFlags.ToImmutableDictionary(StringComparer.OrdinalIgnoreCase);
}
```

---

## Gotchas

- **`ImmutableList<T>` index access is O(log n)** not O(1). Don't use `for (int i = 0; i < list.Count; i++) list[i]` — use `foreach`.
- **`ImmutableArray<T>` default is uninitialized — not empty.** `default(ImmutableArray<T>).IsDefault` is `true`; any operation throws. Always use `ImmutableArray<T>.Empty` or `ImmutableArray.Create(...)`.
- **Chaining `.Add().Add().Add()` in a loop is an allocation per call.** Use the builder pattern for bulk construction.
- **`IReadOnlyList<T>` is not immutable.** A `List<T>` cast to `IReadOnlyList<T>` is still mutable by whoever holds the original reference.
- **Equality is reference equality by default.** Two `ImmutableList<T>` with the same elements are not `==`. Use `SequenceEqual` to compare contents.

---

## Interview Angle

**What they're really testing:** Whether you understand immutability, structural sharing, and when the allocation cost is justified.

**Common question forms:**
- "How would you share state between threads without locking?"
- "What's the difference between `IReadOnlyList<T>` and `ImmutableList<T>`?"

**The depth signal:** A senior explains structural sharing (O(log n) nodes shared, not O(n) copy), knows `ImmutableArray<T>` is for build-once-read-many, and reaches for a builder for bulk construction.

---

## Related Topics

- [[dotnet/csharp/csharp-concurrent-collections.md]] — `ConcurrentDictionary` for high-write concurrent scenarios

---

## Source

[Immutable Collections — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/collections/thread-safe/immutable-collections)

---
*Last updated: 2026-04-06*