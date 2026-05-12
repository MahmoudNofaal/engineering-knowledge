# C# — LINQ Grouping

> `GroupBy` partitions a sequence into sub-collections sharing a common key — the in-memory equivalent of SQL `GROUP BY`.

---

## Quick Reference

| | |
|---|---|
| **Returns** | `IEnumerable<IGrouping<TKey, TElement>>` — lazy |
| **`IGrouping<K,T>`** | Has `.Key` property + is `IEnumerable<T>` |
| **Eager alternative** | `ToLookup()` — builds hash table immediately, O(1) repeated access |
| **Mutates?** | No — returns new sequence |

---

## Core Concept

`GroupBy` iterates the source once and builds a hash table where each key maps to a list of matching elements. It returns a sequence of `IGrouping<TKey, TElement>` — each group has a `.Key` and is itself an `IEnumerable<T>`. Nothing is aggregated automatically — you get the buckets and decide what to do with them.

`GroupBy` is **lazy** — re-evaluates source on each enumeration. `ToLookup()` is **eager** — builds the hash table once, stable, O(1) repeated key access.

---

## The Code

**Basic grouping and aggregation**
```csharp
record Order(int Id, string Customer, string Category, decimal Total);
var orders = new List<Order> { /* ... */ };

var byCustomer = orders
    .GroupBy(o => o.Customer)
    .Select(g => new
    {
        Customer = g.Key,
        Count    = g.Count(),
        Total    = g.Sum(o => o.Total),
        MaxOrder = g.Max(o => o.Total)
    });
```

**Composite key — group by multiple fields**
```csharp
var byCustomerAndCategory = orders
    .GroupBy(o => new { o.Customer, o.Category })
    .Select(g => new { g.Key.Customer, g.Key.Category, Total = g.Sum(o => o.Total) });
// Anonymous type keys work because compiler generates structural equality
```

**Having-equivalent — filter groups**
```csharp
// SQL: GROUP BY customer HAVING COUNT(*) > 1
var multiOrderCustomers = orders
    .GroupBy(o => o.Customer)
    .Where(g => g.Count() > 1)      // filter on the group — equivalent to HAVING
    .Select(g => new { Customer = g.Key, Count = g.Count() });
```

**`ToLookup` — eager, stable, O(1) re-access**
```csharp
ILookup<string, Order> lookup = orders.ToLookup(o => o.Customer);

var aliceOrders = lookup["Alice"];    // O(1) — no re-enumeration
var nobody      = lookup["Nobody"];   // empty sequence — never throws
```

---

## Gotchas

- **`GroupBy` is lazy** — re-evaluates source on every enumeration. Use `ToLookup()` when you need stable, repeatable access.
- **Composite keys require anonymous types or records** — plain classes use reference equality, which groups by instance not value.
- **Multiple aggregates in `Select` re-enumerate the group** — `g.Count()` and `g.Sum()` each walk elements. Call `g.ToList()` first for multiple aggregates on large groups.
- **EF Core `GroupBy` falls back to client evaluation for complex projections.** Check generated SQL with `.ToQueryString()`.
- **`ToLookup` returns empty sequence for missing keys, never throws.** Different from `Dictionary` which throws.

---

## Source

[Grouping Data — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/grouping-data)

---
*Last updated: 2026-04-06*