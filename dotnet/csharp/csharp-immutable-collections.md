# C# — Immutable Collections

> Collections from `System.Collections.Immutable` that can never be modified after creation — any "change" returns a new collection, leaving the original untouched.

---

## When To Use It

Use immutable collections when you need to share a collection across threads without locking, when you want to guarantee a collection won't be changed by the code you pass it to, or when you need structural sharing (cheap snapshots of state). They're also the right call in functional-style pipelines and event sourcing where previous states must be preserved. Don't use them as a general-purpose replacement for `List<T>` or `Dictionary<TKey, TValue>` — every modification allocates a new collection (or shares structure, depending on the type), and the overhead adds up fast in tight loops or hot write paths.

---

## Core Concept

A normal `List<T>` is a mutable array — you call `Add()` and the list changes in place. An `ImmutableList<T>` is a tree under the hood — when you call `Add()`, it builds a new tree that shares most nodes with the old one and returns it to you. The original is untouched. This structural sharing is what makes immutable collections not completely insane in terms of allocations — you're not copying the entire collection on every operation, you're copying only the path from the root to the changed node (O(log n) nodes). The tradeoff is that reads are slower than a plain array because you're traversing a tree instead of indexing into contiguous memory. For thread safety, this is powerful: multiple threads can hold references to the same immutable collection with zero synchronization needed, because nothing ever changes.

---

## The Code

### Basic usage — every mutation returns a new instance
```csharp
using System.Collections.Immutable;

var original = ImmutableList<string>.Empty;
var withOne  = original.Add("alice");
var withTwo  = withOne.Add("bob");
var withThree = withTwo.Add("charlie");

Console.WriteLine(original.Count);  // 0 — untouched
Console.WriteLine(withThree.Count); // 3

var removed = withThree.Remove("bob");
Console.WriteLine(withThree.Count); // 3 — still 3, original unchanged
Console.WriteLine(removed.Count);   // 2
```

### Builder pattern — batch mutations without intermediate allocations
```csharp
// Creating 10,000 items one Add() at a time = 10,000 allocations
// Builder accumulates changes, then produces one immutable result
var builder = ImmutableList.CreateBuilder<int>();

for (int i = 0; i < 10_000; i++)
    builder.Add(i); // mutates the builder in place, like a List<T>

ImmutableList<int> result = builder.ToImmutable(); // one allocation
```

### ImmutableDictionary — thread-safe read-heavy lookup tables
```csharp
var config = ImmutableDictionary<string, string>.Empty
    .Add("host", "localhost")
    .Add("port", "5432")
    .Add("db",   "orders");

// Safe to read from any thread — no lock needed
string host = config["host"];

// "Updating" produces a new dictionary — original untouched
var updatedConfig = config.SetItem("host", "prod-db-01");

Console.WriteLine(config["host"]);        // localhost
Console.WriteLine(updatedConfig["host"]); // prod-db-01
```

### ImmutableArray<T> — when you want immutability + array performance
```csharp
// ImmutableArray<T> is a struct wrapping a plain array — no tree overhead
// Reads are O(1) like a normal array. Writes still allocate.
// Use when the collection is built once and read many times.
ImmutableArray<int> primes = ImmutableArray.Create(2, 3, 5, 7, 11);

Console.WriteLine(primes[2]); // 5 — direct index, no tree traversal

// Builder applies here too
var arrBuilder = ImmutableArray.CreateBuilder<int>();
arrBuilder.Add(1);
arrBuilder.Add(2);
ImmutableArray<int> arr = arrBuilder.ToImmutable();
```

### Sharing state across threads without locking
```csharp
// Pattern: volatile reference swap — publish a new immutable snapshot atomically
private volatile ImmutableList<string> _activeUsers = ImmutableList<string>.Empty;

public void AddUser(string user)
{
    // Interlocked.CompareExchange for true CAS if contention is high;
    // volatile write is sufficient for single-writer scenarios
    _activeUsers = _activeUsers.Add(user);
}

public ImmutableList<string> GetSnapshot() => _activeUsers; // safe, no lock
```

---

## Gotchas

- **`ImmutableList<T>` is a tree, not an array — index access is O(log n)** — if you're iterating with `for (int i = 0; i < list.Count; i++)` in a hot path, you're paying tree traversal cost on every `list[i]`. Use `foreach` (which uses an optimized enumerator) or switch to `ImmutableArray<T>` if you need O(1) reads.
- **Chaining `.Add().Add().Add()` in a loop is an allocation per call** — each returns a new immutable instance. If you're building from many items, always use the builder pattern. This is the single most common performance mistake with immutable collections.
- **`ImmutableArray<T>` default is not empty — it's null-equivalent** — `default(ImmutableArray<T>)` produces an uninitialized struct where `.IsDefault` is true and any operation throws `NullReferenceException`. Always initialize with `ImmutableArray<T>.Empty` or `ImmutableArray.Create(...)`.
- **`IReadOnlyList<T>` is not the same as immutable** — a `List<T>` cast to `IReadOnlyList<T>` can still be mutated by whoever holds the original reference. `ImmutableList<T>` is a guarantee; `IReadOnlyList<T>` is just a read-only view. Don't conflate them when designing APIs.
- **Equality is reference equality by default** — two `ImmutableList<T>` instances with the same elements are not `==` equal. If you're using them as dictionary keys or checking equality between snapshots, you need `SequenceEqual` or a custom comparer.

---

## Interview Angle

**What they're really testing:** Whether you understand the relationship between immutability, thread safety, and allocation cost — and that you know immutability isn't free.

**Common question form:** "How would you share state between threads without locking?" or "What's the difference between `IReadOnlyList<T>` and `ImmutableList<T>`?" or "When would you choose immutable collections over concurrent collections?"

**The depth signal:** A junior says immutable collections are thread-safe because they can't be modified. A senior explains the structural sharing model — that `ImmutableList<T>` is a balanced tree where mutations share O(log n) nodes with the original, making it cheap but not free, and that `ImmutableArray<T>` exists specifically for the case where you need O(1) reads and only build once. The senior also knows the volatile-swap pattern for publishing immutable snapshots and understands that `ConcurrentDictionary` is better when writes are frequent, while immutable collections win when reads dominate and snapshots matter.

---

## Related Topics

- [[dotnet/csharp-concurrent-collections.md]] — `ConcurrentDictionary` and friends are the alternative for high-write concurrent scenarios; understanding both clarifies the read-heavy vs write-heavy tradeoff.
- [[dotnet/csharp-readonly-ref.md]] — `readonly` fields and `in` parameters are compile-time immutability enforcement at the value level; complements collection-level immutability.
- [[dotnet/csharp-collections-list-linkedlist.md]] — The mutable baseline; comparing `List<T>` to `ImmutableList<T>` makes the tree vs array tradeoff concrete.
- [[system-design/event-sourcing.md]] — Immutable collections map naturally to event sourcing's append-only state model; previous states are preserved by design.

---

## Source

https://learn.microsoft.com/en-us/dotnet/standard/collections/thread-safe/immutable-collections

---
*Last updated: 2026-03-23*