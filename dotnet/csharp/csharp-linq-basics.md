# C# — LINQ Basics

> A uniform query syntax built into C# that lets you filter, transform, and aggregate any sequence — collections, databases, XML, or anything that implements `IEnumerable<T>` or `IQueryable<T>`.

---

## When To Use It

Use LINQ whenever you need to query, filter, sort, group, or project data from any in-memory collection. It replaces hand-written `foreach` loops with declarative expressions that are easier to read and harder to get wrong. Don't use LINQ in tight, allocation-sensitive hot paths — method chaining creates iterator objects and deferred execution adds overhead that profilers will find. Don't use LINQ-to-Objects as a substitute for understanding SQL when your data actually lives in a database — use LINQ-to-EF there, and understand what SQL it generates.

---

## Core Concept

LINQ is two things that look similar but work differently. LINQ-to-Objects runs C# delegates in memory against `IEnumerable<T>` — the lambdas you write are actual code that executes in your process. LINQ-to-Provider (like Entity Framework) works against `IQueryable<T>` — the lambdas are never executed as C# code, they're parsed as expression trees and translated into SQL (or whatever the provider speaks) by the ORM. This distinction is the source of most LINQ confusion. On top of that, LINQ is lazy: building a query with `Where`, `Select`, and `OrderBy` does nothing — it just chains enumerators. The data only flows when you call a materializing operator like `ToList()`, `First()`, `Count()`, or iterate with `foreach`.

---

## The Code

### Method syntax vs query syntax — same result
```csharp
var numbers = new[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

// Method syntax (more common in practice)
var evenSquares = numbers
    .Where(n => n % 2 == 0)
    .Select(n => n * n);

// Query syntax (closer to SQL — compiles to the same IL)
var evenSquares2 =
    from n in numbers
    where n % 2 == 0
    select n * n;

foreach (var n in evenSquares)
    Console.WriteLine(n); // 4, 16, 36, 64, 100
```

### Core operators — filter, project, sort, take
```csharp
record Product(string Name, string Category, decimal Price);

var products = new List<Product>
{
    new("Laptop",  "Electronics", 999.99m),
    new("Phone",   "Electronics", 699.99m),
    new("Desk",    "Furniture",   349.99m),
    new("Chair",   "Furniture",   249.99m),
    new("Monitor", "Electronics", 449.99m),
};

var result = products
    .Where(p => p.Category == "Electronics")   // filter
    .OrderByDescending(p => p.Price)           // sort
    .Take(2)                                   // limit
    .Select(p => new { p.Name, p.Price });     // project to anonymous type

foreach (var p in result)
    Console.WriteLine($"{p.Name}: {p.Price}");
// Laptop: 999.99
// Phone: 699.99
```

### Grouping and aggregation
```csharp
var byCategory = products
    .GroupBy(p => p.Category)
    .Select(g => new
    {
        Category = g.Key,
        Count    = g.Count(),
        Average  = g.Average(p => p.Price),
        Cheapest = g.Min(p => p.Price)
    });

foreach (var cat in byCategory)
    Console.WriteLine($"{cat.Category}: {cat.Count} items, avg {cat.Average:C}");
```

### Deferred execution — the query runs when iterated
```csharp
var source = new List<int> { 1, 2, 3 };

// Nothing executes here — query is just a description
var query = source.Where(x =>
{
    Console.WriteLine($"Evaluating {x}");
    return x > 1;
});

source.Add(4); // added BEFORE iteration — will be included

Console.WriteLine("Starting iteration:");
var result2 = query.ToList(); // execution happens here
// Starting iteration:
// Evaluating 1
// Evaluating 2
// Evaluating 3
// Evaluating 4
```

### FirstOrDefault vs Single vs First — picking the right terminator
```csharp
var users = new[] { "alice", "bob", "charlie" };

// First      — throws if empty
// FirstOrDefault — returns null/default if empty
// Single     — throws if 0 OR more than 1 match
// SingleOrDefault — throws only if more than 1 match

string? found = users.FirstOrDefault(u => u.StartsWith("b")); // "bob"
string? missing = users.FirstOrDefault(u => u.StartsWith("z")); // null

// Use Single when business logic guarantees exactly one — e.g. lookup by ID
// Use First when you just want the top item from an ordered set
string unique = users.Single(u => u == "alice");
```

### Flattening with SelectMany
```csharp
var orders = new[]
{
    new { Id = 1, Items = new[] { "apple", "banana" } },
    new { Id = 2, Items = new[] { "cherry", "date", "elderberry" } },
};

// SelectMany flattens one level — projects each element to a sequence, then merges
var allItems = orders.SelectMany(o => o.Items);
// apple, banana, cherry, date, elderberry
```

---

## Gotchas

- **Deferred execution means the source is re-evaluated on every iteration** — if you iterate the same LINQ query twice (e.g. call `Count()` then `foreach`), it runs twice against the source. If the source is a database query, that's two round-trips. Materialize with `ToList()` when you need multiple passes or want to snapshot the data at a point in time.
- **`Single()` throws on duplicates, not just on empty** — using `Single()` for a lookup by non-unique field in a real dataset will throw `InvalidOperationException` with a confusing message when two records match. Reserve it for primary key lookups where uniqueness is guaranteed by the schema.
- **`OrderBy` followed by `OrderBy` replaces the first sort** — to sort by multiple fields, chain `OrderBy(...).ThenBy(...)`, not `OrderBy(...).OrderBy(...)`. The second `OrderBy` restarts the sort and discards the first.
- **Anonymous types from `Select` can't cross method boundaries** — `new { p.Name, p.Price }` is a compiler-generated type with no name. You can't return it from a method or store it in a typed field. Use a named `record` or `tuple` when the projection needs to leave the local scope.
- **LINQ-to-EF silently ignores unsupported methods** — calling a C# method inside a LINQ-to-EF query that the provider can't translate (e.g. a custom helper) either throws at runtime or (in older EF versions) silently evaluates client-side, pulling the entire table into memory first. Always check the generated SQL with `ToQueryString()` or logging when writing EF LINQ queries.

---

## Interview Angle

**What they're really testing:** Whether you understand deferred execution and the difference between `IEnumerable<T>` (in-memory, delegates) and `IQueryable<T>` (expression trees, translated to SQL) — not just whether you can write a `Where` clause.

**Common question form:** "What's the difference between `IEnumerable` and `IQueryable`?" or "What's wrong with this code?" (showing double-enumeration or a broken multi-sort), or "When does a LINQ query actually execute?"

**The depth signal:** A junior knows that LINQ is lazy and that `ToList()` materializes it. A senior explains *why* it's lazy — each LINQ operator wraps the previous in a new `IEnumerator<T>`, and `MoveNext()` pulls values through the chain on demand — and knows that `IQueryable<T>` works completely differently: lambdas become expression trees that the provider inspects and translates, which is why you can write `Where(u => u.Name == name)` and get a SQL `WHERE` clause instead of a C# loop. The senior also knows that mixing untranslatable C# methods into an EF LINQ query causes either a runtime exception or a catastrophic client-side evaluation, and always verifies generated SQL in non-trivial queries.

---

## Related Topics

- [[dotnet/csharp-ienumerable.md]] — `IEnumerable<T>` is the foundation LINQ-to-Objects is built on; deferred execution and the enumerator chain are explained there in detail.
- [[dotnet/csharp-linq-advanced.md]] — Covers `Join`, `Zip`, `Aggregate`, `Lookup`, and expression tree basics for when basic operators aren't enough.
- [[databases/ef-core-queries.md]] — LINQ-to-EF in practice: how expression trees become SQL, what the provider can and can't translate, and how to inspect generated queries.
- [[dotnet/csharp-immutable-collections.md]] — Immutable collections work seamlessly with LINQ; understanding both clarifies when to materialize vs keep lazy.

---

## Source

https://learn.microsoft.com/en-us/dotnet/csharp/linq/

---
*Last updated: 2026-03-23*