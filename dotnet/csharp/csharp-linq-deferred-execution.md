# C# — LINQ Deferred Execution

> The behavior where a LINQ query is defined now but doesn't run until something iterates it — separating the description of work from the execution of it.

---

## Quick Reference

| Deferred operators | `Where`, `Select`, `OrderBy`, `GroupBy`, `Take`, `Skip`, `SelectMany` |
|---|---|
| Materialising operators | `ToList()`, `ToArray()`, `Count()`, `First()`, `Any()`, `Sum()`, `Max()` |
| Re-execute on each enumeration | Yes — unless materialised |
| IQueryable difference | Same defer, but execution is SQL — not C# |

---

## Core Concept

When you write `var query = source.Where(x => x.Active).Select(x => x.Name)`, nothing happens. You get back an object that *describes* the pipeline. Work only happens when someone calls `MoveNext()` — which happens inside `foreach`, `ToList()`, `Count()`, etc.

This means: the query runs against whatever `source` contains at the **moment of enumeration**, not definition. Modifying the source between definition and iteration changes the results.

Iterating the query **twice** runs it **twice** — there is no caching.

---

## The Code

**Deferred vs immediate**
```csharp
var numbers = new List<int> { 1, 2, 3, 4, 5 };
IEnumerable<int> query = numbers.Where(n =>
{
    Console.WriteLine($"  Filtering {n}");
    return n > 2;
});
Console.WriteLine("Query defined. Nothing has run yet.");
Console.WriteLine("Iterating:");
foreach (var n in query) Console.WriteLine($"  Got: {n}");
// Output shows interleaved filtering and output
```

**Source mutation between definition and enumeration**
```csharp
var source = new List<string> { "alice", "bob" };
IEnumerable<string> query = source.Where(s => s.Length > 3);

source.Add("charlie");   // AFTER query definition
source.Remove("alice");

var result = query.ToList(); // ["charlie"] — sees current state of source
```

**Double enumeration — the most common unintentional cost**
```csharp
IEnumerable<Order> GetPending() => dbContext.Orders.Where(o => o.Status == "Pending");

var pending = GetPending();
if (pending.Any())           // DB hit #1
{
    Log($"Processing {pending.Count()}");  // DB hit #2
    foreach (var o in pending) Process(o); // DB hit #3
}

// Fix: materialise once
var pendingList = GetPending().ToList(); // one DB hit
if (pendingList.Count > 0) { ... }
```

**Closure capture in deferred queries**
```csharp
int threshold = 3;
IEnumerable<int> query = Enumerable.Range(1, 5).Where(n => n > threshold);

threshold = 1; // mutate before iteration
var result = query.ToList(); // [2, 3, 4, 5] — uses threshold = 1 at execution time
```

---

## Gotchas

- **Source mutated between definition and iteration** — query sees the modified source.
- **Iterating twice runs twice** — DB queries, file reads, expensive computations repeat.
- **Closures capture the variable reference** — not the value at definition time.
- **`IQueryable<T>` differs**: operators added before `ToList()` refine the SQL; operators added after `ToList()` run in-memory.

---

## Interview Angle

**The depth signal:** A senior explains the pull model — each operator wraps the previous in a new enumerator, `MoveNext()` pulls through the chain on demand. They distinguish `IEnumerable<T>` (C# delegate execution) from `IQueryable<T>` (SQL translation).

---

## Related Topics

- [[dotnet/csharp/csharp-ienumerable.md]] — The pull model underlying deferred execution
- [[dotnet/csharp/csharp-linq-to-sql.md]] — `IQueryable<T>` deferred execution with SQL translation

---

## Source

[Deferred Execution — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/linq/get-started/introduction-to-linq-queries#deferred-execution)

---
*Last updated: 2026-04-06*