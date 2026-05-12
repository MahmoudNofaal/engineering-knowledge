# C# — LINQ Aggregation

> Terminal operators that consume an entire sequence and reduce it to a single scalar value.

---

## Quick Reference

| Operator | Empty sequence | Returns |
|---|---|---|
| `Count()` | 0 | `int` |
| `Sum()` | 0 | numeric type |
| `Min()` | **throws** | element type |
| `Max()` | **throws** | element type |
| `Average()` | **throws** | `double` |
| `MinBy()` | **throws** | element (whole object) |
| `MaxBy()` | **throws** | element (whole object) |
| `Any()` | `false` | `bool` |
| `All()` | `true` | `bool` |

---

## Core Concept

Every aggregation operator forces full enumeration — they are **materialising** (terminal) operators. Nothing after them can be lazy.

`Min`, `Max`, `Average`, `MinBy`, `MaxBy` throw `InvalidOperationException` on empty input — unlike `Sum` and `Count` which safely return zero. Always guard with `Any()` first, or cast the selector to a nullable type to get `null` instead of a throw.

`Aggregate` is the general fold operation that all the above are built on.

---

## The Code

**Built-in aggregates**
```csharp
record Sale(string Region, string Product, decimal Amount, int Qty);
var sales = new List<Sale> { /* ... */ };

int    count  = sales.Count();
decimal total = sales.Sum(s => s.Amount);
decimal min   = sales.Min(s => s.Amount);          // throws if empty!
decimal max   = sales.Max(s => s.Amount);
double  avg   = sales.Average(s => (double)s.Amount);

int northSales = sales.Count(s => s.Region == "North"); // count with predicate
```

**`MinBy`/`MaxBy` — get the whole element, not just the value (NET 6)**
```csharp
Sale cheapest    = sales.MinBy(s => s.Amount)!;   // whole Sale object
Sale mostExpensive = sales.MaxBy(s => s.Amount)!;
```

**Safe aggregation on potentially empty sequences**
```csharp
var empty = new List<Sale>();

// Safe — returns 0
decimal sum = empty.Sum(s => s.Amount);

// These THROW — guard first or use nullable selector
decimal? safeMin = empty.Any() ? empty.Min(s => s.Amount) : null;
decimal? nullableMin = empty.Min(s => (decimal?)s.Amount); // null, not throw
```

**`Aggregate` — general fold**
```csharp
var nums = new[] { 1, 2, 3, 4, 5 };

int sum     = nums.Aggregate(0,  (acc, n) => acc + n);   // 15
int product = nums.Aggregate(1,  (acc, n) => acc * n);   // 120

// No-seed overload: uses first element as initial accumulator
int max = nums.Aggregate((acc, n) => acc > n ? acc : n); // 5
// THROWS on empty — no seed to fall back to
```

**EF Core — server-side vs client-side**
```csharp
// GOOD: executes as SELECT COUNT(*) FROM Orders WHERE CustomerId = 1
int count = dbContext.Orders.Where(o => o.CustomerId == 1).Count();

// BAD: fetches ALL rows then counts in C#
int bad = dbContext.Orders.ToList().Count();
```

---

## Gotchas

- **`Min`, `Max`, `Average` throw on empty.** `Sum` and `Count` return zero. Guard with `Any()` or use nullable selectors.
- **`Count()` on a chained LINQ query is O(n).** `list.Count` (property) is O(1); `list.Where(...).Count()` is O(n) — always.
- **`Aggregate` without a seed throws on empty input.**
- **`Average` returns `double`, not `decimal`.** For financial calculations use `Sum / Count` with explicit `decimal` math.
- **In EF Core, `ToList()` before an aggregate defeats server-side execution.** The aggregate must appear before any materialising call.

---

## Source

[Aggregation Operations — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/aggregation-operations)

---
*Last updated: 2026-04-06*