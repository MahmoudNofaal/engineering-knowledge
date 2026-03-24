# C# — LINQ Deferred Execution

> The behavior where a LINQ query is defined now but doesn't actually run until something iterates it — separating the description of work from the execution of it.

---

## When To Use It

Deferred execution is not a feature you opt into — it's how LINQ works by default, and understanding it is mandatory for writing correct LINQ code. It matters most when your source data changes between query definition and iteration, when you're building pipelines that should only process elements on demand, and when you're deciding whether to call `ToList()` or not. The bugs it causes — double enumeration, stale data, unexpected re-execution — are among the most common production LINQ mistakes. You can't avoid it, but you can control it by knowing exactly which operators are deferred and which are not.

---

## Core Concept

When you write `var query = source.Where(x => x.Active).Select(x => x.Name)`, nothing happens. No element is touched. What you get back is an object that describes the pipeline — a chain of enumerator wrappers, each holding a reference to the previous one and a delegate. The work only happens when someone calls `MoveNext()` on that chain, which happens when you `foreach` over it, call `ToList()`, call `Count()`, or use any other materializing operator. This means the query runs against whatever `source` contains at the moment of iteration, not at the moment of definition. It also means that iterating the query twice runs it twice — there's no caching. Every LINQ operator in the middle of a pipeline (`Where`, `Select`, `OrderBy`, `Take`, etc.) is deferred. Every terminal operator at the end (`ToList`, `Count`, `First`, `Any`, `Sum`) materializes and ends the laziness.

---

## The Code

### Deferred vs immediate — the fundamental split
```csharp
var numbers = new List<int> { 1, 2, 3, 4, 5 };

// Deferred — no execution yet, just a pipeline description
IEnumerable<int> query = numbers.Where(n =>
{
    Console.WriteLine($"  Filtering {n}");
    return n > 2;
});

Console.WriteLine("Query defined. Nothing has run yet.");

// Execution happens here — foreach drives MoveNext()
Console.WriteLine("Starting foreach:");
foreach (var n in query)
    Console.WriteLine($"  Got: {n}");

// Output:
// Query defined. Nothing has run yet.
// Starting foreach:
//   Filtering 1
//   Filtering 2
//   Filtering 3
//   Got: 3
//   Filtering 4
//   Got: 4
//   Filtering 5
//   Got: 5
```

### Source mutation between definition and iteration
```csharp
var source = new List<string> { "alice", "bob" };

// Query defined against source at this point
IEnumerable<string> query = source.Where(s => s.Length > 3);

// Source is mutated AFTER query definition, BEFORE iteration
source.Add("charlie");
source.Remove("alice");

// Query iterates against the CURRENT state of source — not the state at definition
var result = query.ToList();
// ["charlie"] — alice is gone, charlie is included
// This surprises people who expect the query to be a snapshot
```

### Double enumeration — the silent performance bug
```csharp
IEnumerable<int> Expensive()
{
    Console.WriteLine("  [DB hit]");
    return new[] { 1, 2, 3, 4, 5 };
}

IEnumerable<int> query = Expensive().Where(n => n > 2);

// First enumeration
if (query.Any())           // [DB hit] — full or partial pass
    Console.WriteLine($"Count: {query.Count()}"); // [DB hit] — second full pass

// Third pass
foreach (var n in query)   // [DB hit] — third full pass
    Console.WriteLine(n);

// Fix: materialize once
var list = query.ToList(); // [DB hit] — one pass only
if (list.Any())
    Console.WriteLine($"Count: {list.Count}"); // free — Count property, not LINQ
```

### Materializing operators — what ends deferred execution
```csharp
var source = Enumerable.Range(1, 1_000_000);
var query  = source.Where(n => n % 2 == 0).Select(n => n * n);

// All of these materialize — execution happens now:
List<int>  list  = query.ToList();       // all elements into a List<T>
int[]      arr   = query.ToArray();      // all elements into an array
int        count = query.Count();        // walks everything, returns count
int        first = query.First();        // stops after finding first match
bool       any   = query.Any();          // stops after first element exists
int        sum   = query.Sum();          // walks everything, accumulates

// These stay deferred — execution is still pending:
IEnumerable<int> stillLazy = query.Where(n => n > 100);
IEnumerable<int> alsoLazy  = query.Take(10);  // Take is deferred until iterated
```

### yield return — deferred execution in your own methods
```csharp
// This method is deferred — nothing inside runs until someone iterates the result
IEnumerable<int> EvenNumbers(int max)
{
    Console.WriteLine("Generator started");
    for (int i = 0; i <= max; i++)
    {
        if (i % 2 == 0)
        {
            Console.WriteLine($"  Yielding {i}");
            yield return i;
        }
    }
    Console.WriteLine("Generator finished");
}

// Just calling the method does nothing — the body hasn't executed yet
IEnumerable<int> evens = EvenNumbers(10);

// Take(3) means the generator stops after yielding 3 elements — never finishes
foreach (var n in evens.Take(3))
    Console.WriteLine($"Got: {n}");
// Generator started
//   Yielding 0
// Got: 0
//   Yielding 2
// Got: 2
//   Yielding 4
// Got: 4
// (Generator finished is never printed — Take stopped iteration early)
```

### Capturing variables in deferred queries — closure gotcha
```csharp
var threshold = 3;

IEnumerable<int> query = Enumerable.Range(1, 5).Where(n => n > threshold);

threshold = 1; // mutating the captured variable BEFORE iteration

var result = query.ToList(); // threshold is now 1 at time of execution
// [2, 3, 4, 5] — not [4, 5] — the lambda captures the variable, not its value
```

---

## Gotchas

- **The query runs against the source at the time of iteration, not definition** — modifying the source collection between `var query = ...` and `foreach (var x in query)` means the query sees the modified source. This is intentional but consistently surprises people, especially when the source is a shared field modified concurrently.
- **Iterating a deferred query twice executes it twice** — there's no internal caching. `query.Any()` followed by `query.Count()` followed by `foreach (var x in query)` is three executions. If the source is a database query, that's three round trips. Materialize with `ToList()` as soon as you know you'll need multiple passes.
- **Lambdas capture variables by reference, not by value** — a loop variable captured in a deferred query holds a reference to the variable slot, not a copy of the value at the time the lambda was created. By the time the query iterates, the variable may have a completely different value. Copy the value to a local variable inside the loop before capturing it.
- **`ToList()` inside a LINQ chain doesn't make the rest of the chain deferred** — `source.ToList().Where(x => x.Active)` materializes `source` into a list first and then applies `Where` lazily over the list. This can be useful (forces a snapshot) or harmful (unnecessary full materialization before filtering). Know which you intend.
- **`IQueryable<T>` deferred execution works differently than `IEnumerable<T>`** — both are lazy, but `IEnumerable<T>` defers C# delegate execution while `IQueryable<T>` defers expression tree translation. Adding operators to an `IQueryable<T>` before calling `ToList()` refines the SQL query; adding operators after `ToList()` runs them in-memory on the fully loaded result. This is the most expensive LINQ mistake in EF Core applications.

---

## Interview Angle

**What they're really testing:** Whether you actually understand how LINQ works internally — not just the syntax — and whether you can predict behavior when source data changes or a query is iterated multiple times.

**Common question form:** "What does this code output?" (showing a query defined before a source mutation), or "Why is this code hitting the database three times?" or "What's the difference between `IEnumerable<T>` and `IQueryable<T>`?"

**The depth signal:** A junior knows LINQ is lazy and that `ToList()` forces execution. A senior can explain the mechanics: each deferred operator wraps the previous in a new `IEnumerator<T>`, and `MoveNext()` propagates through the chain pulling one element at a time — which is why `Take(3)` on an infinite sequence terminates, and why a `yield return` generator's body can be suspended mid-execution. The senior also distinguishes `IEnumerable<T>` deferred execution (delegates, runs in C#) from `IQueryable<T>` (expression trees, translated to SQL by a provider) — and knows that operators added to a query before `ToList()` in EF Core refine the SQL, while operators added after run in the CLR against the full result set. That distinction is the one that separates developers who write accidentally slow EF queries from those who don't.

---

## Related Topics

- [[dotnet/csharp-ienumerable.md]] — `IEnumerable<T>` and its enumerator chain are the mechanical foundation of deferred execution; the `MoveNext()` pull model is explained there.
- [[dotnet/csharp-yield-return.md]] — `yield return` is how you implement deferred execution in your own methods; the compiler-generated state machine is what makes suspension possible.
- [[dotnet/csharp-linq-basics.md]] — Covers which operators are deferred vs materializing; deferred execution applies to every pipeline built with those operators.
- [[databases/ef-core-queries.md]] — `IQueryable<T>` deferred execution with expression tree translation is the most consequential place deferred execution decisions are made in production .NET code.

---

## Source

https://learn.microsoft.com/en-us/dotnet/csharp/linq/get-started/introduction-to-linq-queries#deferred-execution

---
*Last updated: 2026-03-23*