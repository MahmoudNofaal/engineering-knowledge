# C# — LINQ Grouping

> The `GroupBy` operator that partitions a sequence into sub-collections sharing a common key — the in-memory equivalent of SQL `GROUP BY`.

---

## When To Use It

Use `GroupBy` when you need to partition a flat sequence into buckets by some key and then aggregate or iterate within each bucket — counting orders per customer, averaging scores per category, or building lookup structures from flat data. Don't use it when you only need a lookup by key and don't care about the grouping structure — `ToDictionary` or `ToLookup` are faster and cleaner for that. In EF Core, `GroupBy` translates to SQL `GROUP BY` for simple aggregations but silently falls back to client-side evaluation for complex projections — always verify the generated SQL.

---

## Core Concept

`GroupBy` iterates the source once and builds a hash table where each key maps to a list of matching elements. What it returns is not a flat sequence — it's a sequence of `IGrouping<TKey, TElement>` objects. Each `IGrouping` is itself an `IEnumerable<TElement>` with a `.Key` property. Nothing is aggregated automatically — you get the buckets, and then you decide what to do with them: count, sum, project, or iterate. The common mistake is treating the output of `GroupBy` as if it's already a dictionary — it's not, it's still a lazy sequence of groups that gets re-evaluated each time you enumerate it unless you materialize it.

---

## The Code

### Basic GroupBy — partitioning a flat list
```csharp
record Order(int Id, string Customer, string Category, decimal Total);

var orders = new List<Order>
{
    new(1, "Alice", "Electronics", 999.99m),
    new(2, "Bob",   "Furniture",   349.99m),
    new(3, "Alice", "Furniture",   149.99m),
    new(4, "Bob",   "Electronics", 499.99m),
    new(5, "Alice", "Electronics", 299.99m),
};

// Each group is IGrouping<string, Order> — a key + a sequence of orders
var byCustomer = orders.GroupBy(o => o.Customer);

foreach (var group in byCustomer)
{
    Console.WriteLine($"{group.Key}:"); // Key is the customer name
    foreach (var order in group)
        Console.WriteLine($"  Order {order.Id}: {order.Total:C}");
}
```

### Aggregating within groups — the most common pattern
```csharp
var summary = orders
    .GroupBy(o => o.Customer)
    .Select(g => new
    {
        Customer   = g.Key,
        Count      = g.Count(),
        Total      = g.Sum(o => o.Total),
        Average    = g.Average(o => o.Total),
        MaxOrder   = g.Max(o => o.Total)
    });

foreach (var s in summary)
    Console.WriteLine($"{s.Customer}: {s.Count} orders, {s.Total:C} total");
// Alice: 3 orders, $1,449.97 total
// Bob:   2 orders, $  848.99 total
```

### Composite key — grouping by multiple fields
```csharp
// Group by both Customer AND Category using an anonymous type as the key
var byCustomerAndCategory = orders
    .GroupBy(o => new { o.Customer, o.Category })
    .Select(g => new
    {
        g.Key.Customer,
        g.Key.Category,
        Total = g.Sum(o => o.Total)
    })
    .OrderBy(x => x.Customer)
    .ThenBy(x => x.Category);

foreach (var r in byCustomerAndCategory)
    Console.WriteLine($"{r.Customer} / {r.Category}: {r.Total:C}");
// Alice / Electronics: $1,299.98
// Alice / Furniture:   $  149.99
// Bob   / Electronics: $  499.99
// Bob   / Furniture:   $  349.99
```

### Query syntax — readable for grouped projections
```csharp
var result =
    from o in orders
    group o by o.Category into g
    select new
    {
        Category = g.Key,
        Count    = g.Count(),
        Total    = g.Sum(o => o.Total)
    };
```

### GroupBy vs ToLookup — when you don't need the group structure
```csharp
// GroupBy is lazy — re-enumerates source on each iteration
var grouped = orders.GroupBy(o => o.Customer); // nothing runs yet

// ToLookup is eager — builds the hash table immediately, one pass
// Use when you need O(1) repeated access by key
ILookup<string, Order> lookup = orders.ToLookup(o => o.Customer);

var aliceOrders = lookup["Alice"];   // O(1), no re-enumeration
var missing     = lookup["Nobody"];  // empty sequence — never throws
```

### Filtering groups with Having-equivalent
```csharp
// SQL: SELECT customer, COUNT(*) FROM orders GROUP BY customer HAVING COUNT(*) > 1
var multiOrderCustomers = orders
    .GroupBy(o => o.Customer)
    .Where(g => g.Count() > 1)  // filter on the group — equivalent to HAVING
    .Select(g => new { Customer = g.Key, Count = g.Count() });
```

---

## Gotchas

- **`GroupBy` is lazy — the source is re-evaluated on every enumeration** — unlike `ToLookup`, which materializes immediately, `GroupBy` defers execution. If you enumerate the result twice (e.g. once for count, once for rendering), you rebuild the groups twice. Call `ToList()` on the `GroupBy` result or switch to `ToLookup` when you need stable, repeatable access.
- **Composite keys use anonymous type equality, which is structural** — `new { o.Customer, o.Category }` works as a group key because the compiler generates `Equals` and `GetHashCode` for anonymous types based on property values. Named types (classes) don't get this for free — you must override `Equals`/`GetHashCode` or use records, otherwise grouping by a class instance groups by reference identity, not value.
- **`g.Count()` inside `Select` re-enumerates the group** — calling `g.Count()`, `g.Sum()`, and `g.Max()` in the same `Select` each walk the group's elements independently. For large groups with many aggregates, call `g.ToList()` inside the `Select` first and aggregate from the list to avoid multiple passes over the same elements.
- **EF Core `GroupBy` falls back to client evaluation for non-trivial projections** — simple `GroupBy(...).Select(g => new { Key = g.Key, Count = g.Count() })` translates to SQL. Anything more complex — like accessing navigation properties inside the group or calling unsupported methods — may pull the entire table into memory before grouping. Always check the generated SQL with `ToQueryString()` or EF logging.
- **`ToLookup` returns an empty sequence for missing keys, never throws** — `lookup["NonExistentKey"]` returns an empty `IEnumerable`, while `dictionary["NonExistentKey"]` throws `KeyNotFoundException`. This is usually the right behavior for grouped data, but it can mask bugs where you expect a key to always exist.

---

## Interview Angle

**What they're really testing:** Whether you understand the shape of `GroupBy`'s output, know the difference between lazy grouping and eager lookup structures, and can translate SQL aggregation patterns into LINQ correctly.

**Common question form:** "Replicate this SQL GROUP BY / HAVING query in LINQ," or "What's the difference between `GroupBy` and `ToLookup`?" or "Why is your group-by query slow?"

**The depth signal:** A junior returns the `IGrouping<TKey, TElement>` sequence directly and calls it done. A senior knows that the output of `GroupBy` is a sequence of sequences — not a dictionary — and that each aggregate call (`Count()`, `Sum()`, `Max()`) inside a `Select` independently re-enumerates the group's elements. The senior reaches for `ToLookup` when the hash table needs to be stable and accessed repeatedly, knows that composite keys require anonymous types or records (not plain classes) for correct equality semantics, and verifies EF Core `GroupBy` output with `ToQueryString()` before shipping any grouped database query.

---

## Related Topics

- [[dotnet/csharp-linq-basics.md]] — Covers deferred execution and core operators; `GroupBy` inherits all of LINQ's laziness behavior.
- [[dotnet/csharp-linq-joins.md]] — Group join (`join ... into`) produces a similar grouped structure to `GroupBy`; understanding both clarifies when each applies.
- [[dotnet/csharp-collections-dictionary.md]] — `ToDictionary` and `ToLookup` are the eager, key-access alternatives to `GroupBy`; the tradeoffs are explained there.
- [[databases/ef-core-queries.md]] — EF Core's translation of `GroupBy` to SQL has specific limitations; this is where the client-evaluation risk is covered in full.

---

## Source

https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/grouping-data

---
*Last updated: 2026-03-23*