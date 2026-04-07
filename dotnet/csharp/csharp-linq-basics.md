# C# — LINQ Basics

> A uniform query syntax built into C# that lets you filter, transform, and aggregate any sequence — collections, databases, XML — in a readable, composable, lazy style.

---

## Quick Reference

| | |
|---|---|
| **IEnumerable source** | Runs C# delegates in memory |
| **IQueryable source** | Runs expression trees translated to SQL (EF Core) |
| **Execution** | Deferred — runs on first enumeration |
| **Materialise** | `ToList()`, `ToArray()`, `First()`, `Count()`, `Any()` |
| **C# version** | C# 3.0 (.NET 3.5) |

---

## When To Use It

Use LINQ whenever you need to query, filter, sort, group, or project in-memory data. It replaces hand-written `foreach` loops with declarative expressions that are easier to read and harder to get wrong.

Don't use LINQ in tight, allocation-sensitive hot paths — method chaining creates iterator objects. For those paths, manual `for` loops or `Span<T>`-based processing is more appropriate.

---

## Core Concept

LINQ is two things that share the same syntax:

**LINQ-to-Objects** runs C# delegates in memory against `IEnumerable<T>`. Your lambdas are actual code that executes in your process.

**LINQ-to-Provider** (EF Core) works against `IQueryable<T>`. Your lambdas are parsed as expression trees and translated to SQL — never executed as C# code. This is why the same `Where(x => x.Price > 100)` syntax produces a C# loop against a list but a SQL `WHERE Price > 100` against a DbSet.

LINQ is **lazy**: building a query with `Where`, `Select`, and `OrderBy` does nothing. Data only flows when you call a materialising operator (`ToList()`, `First()`, `Count()`) or iterate with `foreach`.

---

## The Code

**Method syntax vs query syntax**
```csharp
var numbers = new[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

// Method syntax — more common, more composable
var evenSquares = numbers.Where(n => n % 2 == 0).Select(n => n * n);

// Query syntax — sometimes cleaner for joins and grouping
var evenSquares2 =
    from n in numbers
    where n % 2 == 0
    select n * n;

foreach (var n in evenSquares) Console.Write(n + " "); // 4 16 36 64 100
```

**Core operators**
```csharp
record Product(string Name, string Category, decimal Price);
var products = new List<Product> { /* ... */ };

var result = products
    .Where(p => p.Category == "Electronics")  // filter
    .OrderByDescending(p => p.Price)          // sort
    .Take(2)                                  // limit
    .Select(p => new { p.Name, p.Price });    // project

// Aggregation
int    count = products.Count(p => p.Category == "Electronics");
decimal total = products.Sum(p => p.Price);
decimal max   = products.Max(p => p.Price);
Product? best = products.MaxBy(p => p.Price);

// Element access
var first = products.First(p => p.Price > 100);        // throws if none
var safe  = products.FirstOrDefault(p => p.Price > 100); // null if none
var only  = products.Single(p => p.Name == "Widget");   // throws if 0 or >1
```

**SelectMany — flatten nested sequences**
```csharp
var orders = new[] {
    new { Id = 1, Items = new[] { "apple", "banana" } },
    new { Id = 2, Items = new[] { "cherry", "date" } },
};
var allItems = orders.SelectMany(o => o.Items); // apple, banana, cherry, date
```

**Grouping**
```csharp
var byCategory = products
    .GroupBy(p => p.Category)
    .Select(g => new { Category = g.Key, Count = g.Count(), Total = g.Sum(p => p.Price) });
```

**`IQueryable` vs `IEnumerable` — the critical split**
```csharp
// IQueryable: builds SQL — efficient
IQueryable<Product> q1 = dbContext.Products.Where(p => p.Price > 100);
// SELECT * FROM Products WHERE Price > 100

// IEnumerable: fetches all, filters in C#  — dangerous
IEnumerable<Product> q2 = dbContext.Products.AsEnumerable().Where(p => p.Price > 100);
// SELECT * FROM Products  (all rows!)  then filter in memory
```

---

## Gotchas

- **Deferred execution means the source is re-evaluated on every iteration.** Two calls to `Count()` then `foreach` on a DB-backed query = two round-trips. Materialise with `ToList()` first.
- **`OrderBy` then `OrderBy` discards the first sort.** Use `.ThenBy()` for multi-key sorts.
- **Anonymous types from `Select` can't cross method boundaries.** Use a named `record` or `ValueTuple` when the projection needs to leave local scope.
- **EF Core silently ignores untranslatable methods.** Calling a custom helper inside an EF LINQ query either throws or loads the whole table. Check generated SQL with `.ToQueryString()`.

---

## Interview Angle

**What they're really testing:** Whether you understand deferred execution and the `IEnumerable<T>` vs `IQueryable<T>` distinction.

**Common question forms:**
- "What's the difference between `IEnumerable` and `IQueryable`?"
- "When does a LINQ query actually execute?"

**The depth signal:** A senior explains that `IQueryable<T>` lambdas become expression trees translated by the provider to SQL, while `IEnumerable<T>` lambdas are compiled IL delegates. The same syntax, completely different execution paths.

---

## Related Topics

- [[dotnet/csharp/csharp-linq-deferred-execution.md]] — Why queries don't run until enumerated
- [[dotnet/csharp/csharp-linq-to-sql.md]] — How EF Core translates LINQ to SQL
- [[dotnet/csharp/csharp-ienumerable.md]] — The interface underlying all LINQ-to-Objects

---

## Source

[LINQ — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/linq/)

---
*Last updated: 2026-04-06*