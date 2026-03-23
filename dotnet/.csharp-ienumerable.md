# C# — IEnumerable<T>

> The base interface for anything you can loop over in C# — it promises one thing: give me an enumerator that can walk your elements one at a time.

---

## When To Use It

Use `IEnumerable<T>` as a parameter or return type when the caller only needs to iterate — not count, not index, not add. It's the right contract for LINQ pipelines, lazy sequences, and any method that wants to stay collection-agnostic. Don't use it when the caller needs `Count`, random access, or multiple passes that are expensive to re-enumerate — expose `IReadOnlyList<T>` or `IReadOnlyCollection<T>` instead. The core problem it solves is decoupling producers of sequences from consumers: the consumer doesn't care if the source is a list, array, database cursor, or generator.

---

## Core Concept

`IEnumerable<T>` is just two things: a `GetEnumerator()` method that returns an `IEnumerator<T>`, and that enumerator has `MoveNext()`, `Current`, and `Reset()`. That's the whole contract. What makes it powerful is that it's pull-based and lazy — nothing happens until someone calls `MoveNext()`. This is why LINQ chains don't execute immediately: each operator wraps the previous in another enumerator, and the whole chain only runs when you iterate (with `foreach`, `ToList()`, `First()`, etc.). The flip side: every time you `foreach` over an `IEnumerable<T>`, it starts from scratch — there's no memory of the previous pass.

---

## The Code

### What IEnumerable<T> actually is under the hood
```csharp
// foreach desugars to exactly this
IEnumerable<int> numbers = new List<int> { 1, 2, 3 };
IEnumerator<int> enumerator = numbers.GetEnumerator();

while (enumerator.MoveNext())
{
    Console.WriteLine(enumerator.Current);
}
```

### Lazy evaluation — the pipeline doesn't run until iterated
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

// Output:
// start
// after 1
// after 2
// 2
// after 2 (Wait — actually each MoveNext pulls through the chain)
// after 3 ... etc.
```

### Double enumeration bug — the classic production mistake
```csharp
IEnumerable<string> GetUsers() => FetchFromDatabase(); // expensive

void Process(IEnumerable<string> users)
{
    if (!users.Any())   // first full pass (or at least one DB call)
        return;

    foreach (var u in users) // second full pass — DB hit again
        Console.WriteLine(u);
}

// Fix: materialize once
void ProcessSafe(IEnumerable<string> users)
{
    var list = users.ToList(); // single pass
    if (!list.Any())
        return;

    foreach (var u in list)
        Console.WriteLine(u);
}
```

### yield return — building a lazy sequence
```csharp
IEnumerable<int> FibonacciSequence()
{
    int a = 0, b = 1;
    while (true) // infinite sequence — safe because it's lazy
    {
        yield return a;
        (a, b) = (b, a + b);
    }
}

var first10 = FibonacciSequence().Take(10).ToList();
// [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
```

### Return type discipline — when NOT to return IEnumerable<T>
```csharp
// Bad: caller can't get Count without full enumeration
IEnumerable<Order> GetOrders() => _db.Orders.ToList();

// Better: signal that it's already materialized and has a count
IReadOnlyList<Order> GetOrders() => _db.Orders.ToList();

// Good use of IEnumerable<T>: truly lazy, one-pass, pipeline-style
IEnumerable<Order> StreamLargeOrders() 
{
    foreach (var order in _db.Orders.AsNoTracking())
        if (order.Total > 10_000)
            yield return order;
}
```

---

## Gotchas

- **Double enumeration is silent and expensive** — calling `Any()` then `foreach` on an `IEnumerable<T>` backed by a LINQ-to-DB query hits the database twice. The compiler won't warn you. Always call `ToList()` or `ToArray()` before multiple passes.
- **`yield return` methods can't have `out` parameters or `return` a value** — and they can't be `async`. If you need async streaming, use `IAsyncEnumerable<T>` with `yield return` inside an `async` method.
- **`Reset()` on most real enumerators throws `NotSupportedException`** — it exists for COM interop history reasons. Don't rely on it. If you need to restart, get a new enumerator.
- **Capturing variables in a lazy sequence captures by reference** — if you `yield return` something that closes over a loop variable, you'll get the classic "all values are the last one" bug unless you copy the variable first.
- **`IEnumerable<T>` hides whether the source is already materialized** — a `List<T>` implements `IEnumerable<T>`, but once you've upcast it, the caller has no way to know. If they call `.Count()` (LINQ extension), it actually checks for `ICollection<T>` and short-circuits — but only if the concrete type is still visible through the interface chain. Once it's wrapped in a generator, that optimization is gone.

---

## Interview Angle

**What they're really testing:** Whether you understand lazy evaluation, deferred execution, and what the contract of an interface actually means — not just that `foreach` works on it.

**Common question form:** "What's the difference between `IEnumerable<T>` and `IList<T>`?" or "What's wrong with this code?" (showing a double-enumeration bug), or "How does `yield return` work?"

**The depth signal:** A junior says `IEnumerable<T>` is read-only and used for LINQ. A senior explains deferred execution — that the sequence doesn't run until iterated, that each iteration restarts the pipeline from scratch, and that this is why double enumeration is dangerous on expensive sources. The senior also knows that `IEnumerable<T>` signals intent to the caller ("you get one forward pass"), while returning `IReadOnlyList<T>` signals "this is already in memory, feel free to count and index." The interface choice is a contract, not just a type.

---

## Related Topics

- [[dotnet/csharp-linq.md]] — LINQ is built entirely on `IEnumerable<T>`; understanding deferred execution here explains why LINQ chains behave the way they do.
- [[dotnet/csharp-yield-return.md]] — `yield return` is how you implement `IEnumerable<T>` without writing an enumerator class by hand; the state machine the compiler generates is worth understanding.
- [[dotnet/csharp-iasyncenumerable.md]] — The async counterpart; use this for streaming data from I/O sources without buffering everything into memory first.
- [[dotnet/csharp-collections-list-linkedlist.md]] — `List<T>` implements `IEnumerable<T>`; understanding both clarifies when to upcast and when to preserve the concrete type.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.ienumerable-1

---
*Last updated: 2026-03-23*