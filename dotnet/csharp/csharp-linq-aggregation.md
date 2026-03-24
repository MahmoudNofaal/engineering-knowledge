# C# — LINQ Aggregation

> Terminal operators that consume an entire sequence and reduce it to a single value — `Count`, `Sum`, `Min`, `Max`, `Average`, and the general-purpose `Aggregate`.

---

## When To Use It

Use aggregation operators when you need a scalar result from a sequence: totals, counts, extremes, or any custom fold operation. They're the LINQ equivalent of SQL aggregate functions and are appropriate anywhere you'd otherwise write an accumulator loop. Don't use `Count()` when you only need to check for emptiness — `Any()` short-circuits after the first element while `Count()` walks the entire sequence. In EF Core, aggregation operators translate to SQL and execute server-side, so they're efficient — but only when called before `ToList()`; calling them after pulls all rows into memory first.

---

## Core Concept

Every aggregation operator is a materializing call — it forces full enumeration of the sequence and returns a scalar, not another `IEnumerable<T>`. This is what makes them "terminal": nothing after them can be lazy. The built-in operators (`Sum`, `Min`, `Max`, `Average`, `Count`) are convenience wrappers over the general `Aggregate` method, which takes a seed value and an accumulator function and folds every element into it one at a time. Understanding `Aggregate` is understanding what all the other operators are doing internally. The subtlety is in empty sequences: `Sum` and `Count` return zero for empty input, but `Min`, `Max`, and `Average` throw `InvalidOperationException` on empty input — unless you use the `OrDefault` variants or the overloads that accept a seed.

---

## The Code

### Built-in aggregates — Count, Sum, Min, Max, Average
```csharp
record Sale(string Region, string Product, decimal Amount, int Quantity);

var sales = new List<Sale>
{
    new("North", "Laptop",  1200m, 3),
    new("South", "Phone",    800m, 5),
    new("North", "Monitor",  450m, 8),
    new("South", "Laptop",  1200m, 2),
    new("North", "Phone",    800m, 4),
};

int    count   = sales.Count();                       // 5
decimal total  = sales.Sum(s => s.Amount);            // 4450
decimal min    = sales.Min(s => s.Amount);            // 450
decimal max    = sales.Max(s => s.Amount);            // 1200
double  avg    = sales.Average(s => (double)s.Amount); // 890.0

// Count with predicate — equivalent to .Where(...).Count() but one pass
int northSales = sales.Count(s => s.Region == "North"); // 3
```

### Min/Max with MinBy/MaxBy — get the element, not just the value
```csharp
// Min() returns the smallest Amount value (a decimal)
decimal minAmount = sales.Min(s => s.Amount); // 450

// MinBy() returns the Sale with the smallest Amount (the whole object)
Sale cheapest = sales.MinBy(s => s.Amount)!;
Console.WriteLine(cheapest.Product); // Monitor

Sale mostExpensive = sales.MaxBy(s => s.Amount)!;
Console.WriteLine(mostExpensive.Product); // Laptop (first one found on tie)
```

### Empty sequence behavior — the silent exception source
```csharp
var empty = new List<Sale>();

int    count = empty.Count();   // 0 — safe
decimal sum  = empty.Sum(s => s.Amount); // 0 — safe

// These throw InvalidOperationException on empty input:
// empty.Min(s => s.Amount);
// empty.Max(s => s.Amount);
// empty.Average(s => s.Amount);
// empty.MinBy(s => s.Amount);

// Safe alternatives:
decimal? safeMin = empty.Any() ? empty.Min(s => s.Amount) : null;

// Or use nullable overloads (cast selector to decimal?):
decimal? nullableMin = empty.Min(s => (decimal?)s.Amount); // null, not throw
```

### Aggregate — the general fold operation
```csharp
var numbers = new[] { 1, 2, 3, 4, 5 };

// Sum reimplemented with Aggregate
// Seed = 0, accumulator adds each element to the running total
int sum = numbers.Aggregate(0, (acc, n) => acc + n); // 15

// Product of all elements
int product = numbers.Aggregate(1, (acc, n) => acc * n); // 120

// Running string join — same as string.Join but to show the pattern
string joined = numbers.Aggregate(
    seed: new System.Text.StringBuilder(),
    func: (sb, n) => { sb.Append(n).Append(','); return sb; },
    resultSelector: sb => sb.ToString().TrimEnd(',')
); // "1,2,3,4,5"
```

### Aggregate without a seed — uses first element as seed
```csharp
// No-seed overload: uses first element as initial accumulator
// Throws InvalidOperationException on empty sequence (no seed to fall back to)
int max = numbers.Aggregate((acc, n) => acc > n ? acc : n); // 5

// Useful for finding the "winner" by any custom comparison
Sale topSale = sales.Aggregate((best, s) => s.Amount > best.Amount ? s : best);
Console.WriteLine(topSale.Product); // Laptop
```

### Combining aggregation with grouping
```csharp
// Aggregate within each group — the SQL GROUP BY + aggregate pattern
var regionSummary = sales
    .GroupBy(s => s.Region)
    .Select(g => new
    {
        Region      = g.Key,
        TotalAmount = g.Sum(s => s.Amount),
        TotalUnits  = g.Sum(s => s.Quantity),
        TopProduct  = g.MaxBy(s => s.Amount)!.Product
    })
    .OrderByDescending(r => r.TotalAmount);

foreach (var r in regionSummary)
    Console.WriteLine($"{r.Region}: {r.TotalAmount:C}, top: {r.TopProduct}");
// North: $2,450.00, top: Laptop
// South: $2,000.00, top: Laptop
```

### EF Core — aggregate server-side vs client-side
```csharp
// GOOD: Count executes as SELECT COUNT(*) FROM Orders WHERE CustomerId = 1
int orderCount = dbContext.Orders
    .Where(o => o.CustomerId == 1)
    .Count();

// GOOD: Sum executes as SELECT SUM(Total) FROM Orders WHERE ...
decimal revenue = dbContext.Orders
    .Where(o => o.Status == "Completed")
    .Sum(o => o.Total);

// BAD: ToList() pulls all rows into memory, then Count() runs in C#
int bad = dbContext.Orders.ToList().Count();
```

---

## Gotchas

- **`Min`, `Max`, `Average`, and `MinBy`/`MaxBy` throw on empty sequences** — `Count` and `Sum` safely return zero for empty input, but the others throw `InvalidOperationException`. In production code that might see empty datasets, always guard with `Any()` first or cast the selector to a nullable type (`decimal?`) to get `null` instead of an exception.
- **`Count()` on a materialized `List<T>` still works via `ICollection<T>` short-circuit, but `Count()` on a chained LINQ query enumerates everything** — `someList.Count()` is O(1) because LINQ detects `ICollection<T>` and reads `.Count` directly. `someList.Where(x => x.Active).Count()` is O(n) because the `Where` wraps the list in an iterator that LINQ can't short-circuit. There's no free lunch once any operator is chained.
- **`Aggregate` without a seed throws on empty input** — the no-seed overload uses the first element as the accumulator seed, so an empty sequence has nothing to start with and throws. Always provide a seed when the input might be empty: `sequence.Aggregate(0, (acc, n) => acc + n)` is safe; `sequence.Aggregate((acc, n) => acc + n)` is not.
- **`Average` returns `double`, not `decimal`** — even if the selector projects to `decimal`, `Average(s => s.Amount)` returns `double`. For financial calculations, use `Sum` divided by `Count` with explicit `decimal` arithmetic to preserve precision: `sales.Sum(s => s.Amount) / sales.Count()`.
- **In EF Core, calling `ToList()` before an aggregate defeats server-side execution** — `dbContext.Orders.Sum(o => o.Total)` sends `SELECT SUM(Total)` to the database. `dbContext.Orders.ToList().Sum(o => o.Total)` fetches every row first. The aggregate operator must appear before any materializing call to stay server-side.

---

## Interview Angle

**What they're really testing:** Whether you understand that aggregation is terminal, can reason about empty-sequence edge cases, and know the difference between LINQ's convenience operators and the general `Aggregate` fold — plus the EF Core server-side vs client-side execution distinction.

**Common question form:** "Find the highest/lowest/total from this collection," or "Implement a custom aggregation without using Sum/Max," or "Why is this EF query slow?" (showing `ToList()` before `Count()`).

**The depth signal:** A junior uses `Min()` and `Max()` without guarding against empty sequences, and reaches for a `foreach` loop when the built-in operators don't fit. A senior knows that `Min`/`Max`/`Average` throw on empty while `Sum`/`Count` don't — and explains why: they have no sensible zero value to return. The senior implements custom reductions with `Aggregate`, understands that all the built-in operators are just `Aggregate` with a specific seed and accumulator, and knows that `MinBy`/`MaxBy` (added in .NET 6) returns the whole element rather than just the key value — which matters when you need the object, not the scalar. In EF Core contexts, the senior always verifies generated SQL and knows that any materializing call before the aggregate sends all rows across the wire.

---

## Related Topics

- [[dotnet/csharp-linq-basics.md]] — Aggregation operators are terminal calls that end a LINQ pipeline; understanding deferred execution explains why they force full enumeration.
- [[dotnet/csharp-linq-grouping.md]] — Aggregation almost always follows `GroupBy`; the two are the LINQ equivalent of SQL `GROUP BY` + aggregate functions.
- [[dotnet/csharp-linq-projection.md]] — `Select` often shapes data before aggregation, and group projections combine `Select` with `Sum`/`Count`/`Max` in a single pass.
- [[databases/ef-core-queries.md]] — Server-side vs client-side aggregation execution is covered in detail there; the `ToList()`-before-aggregate anti-pattern is a recurring EF performance issue.

---

## Source

https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/aggregation-operations

---
*Last updated: 2026-03-23*