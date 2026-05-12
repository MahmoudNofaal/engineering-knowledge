# C# — LINQ Projection

> Transforming each element of a sequence into a new shape using `Select` and `SelectMany`.

---

## Quick Reference

| Operator | What it does |
|---|---|
| `Select(x => ...)` | 1-to-1 transform |
| `Select((x, i) => ...)` | Transform with index |
| `SelectMany(x => x.Collection)` | Flatten nested sequences |
| `SelectMany(outer, (o, i) => ...)` | Flatten + preserve outer context |

---

## Core Concept

`Select` is one-to-one: for every element in, exactly one comes out. `SelectMany` is one-to-many flattening: each element maps to a sub-sequence, all concatenated into a single flat output. Both are lazy — nothing runs until the result is enumerated.

The mental model for `SelectMany`: two nested `foreach` loops. The outer loop produces collections, the inner loop iterates each collection, and the output is all inner elements in one flat stream.

---

## The Code

**`Select` — transform each element**
```csharp
record Product(string Name, string Category, decimal Price);
var products = new List<Product> { /* ... */ };

// Project to anonymous type
var names      = products.Select(p => p.Name);
var discounted = products.Select(p => new { p.Name, Discounted = Math.Round(p.Price * 0.9m, 2) });

// Select with index
var ranked = products
    .OrderByDescending(p => p.Price)
    .Select((p, i) => new { Rank = i + 1, p.Name, p.Price });
```

**`SelectMany` — flatten nested collections**
```csharp
record Order(int Id, string Customer, List<string> Items);
var orders = new List<Order> { /* ... */ };

// All items flat
var allItems = orders.SelectMany(o => o.Items);

// Keep context from outer element
var itemsWithOwner = orders.SelectMany(
    o => o.Items,                               // collection selector
    (o, item) => new { o.Customer, item });     // result selector

// Query syntax
var itemsQuery =
    from o in orders
    from item in o.Items         // second 'from' = SelectMany
    select new { o.Customer, item };
```

**EF Core — project early to limit columns fetched**
```csharp
// BAD: fetches all columns then discards most in memory
var names1 = dbContext.Products.ToList().Select(p => p.Name);

// GOOD: Select before ToList — generates SELECT Name FROM Products
var names2 = dbContext.Products.Select(p => p.Name).ToList();
```

---

## Gotchas

- **Anonymous types can't leave the method scope.** Use a `record` or `ValueTuple` when the projection crosses a method boundary.
- **`Select` is not `ForEach`.** `Select` is a pure transform — side effects inside it won't run unless the sequence is enumerated.
- **EF Core can't translate arbitrary C# methods inside `Select`.** Keep EF projections to property access and simple arithmetic.
- **`SelectMany` throws on null inner collections.** Guard with `.Where(o => o.Items != null)` or initialize collections to empty.

---

## Source

[Projection Operations — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/projection-operations)

---
*Last updated: 2026-04-06*