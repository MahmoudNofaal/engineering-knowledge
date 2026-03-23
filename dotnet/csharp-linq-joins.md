# C# — LINQ Joins

> LINQ operators that correlate elements from two sequences by a matching key — the in-memory equivalent of SQL JOIN, with distinct behaviors for inner, group, and left joins.

---

## When To Use It

Use LINQ joins when you need to correlate two in-memory collections by a shared key — combining orders with customers, mapping IDs to names, or merging any two datasets that don't already have navigation properties set up. In Entity Framework, prefer navigation properties and `Include()` over explicit LINQ joins — the ORM can optimize the SQL better when it owns the join. Don't use nested `foreach` loops with manual matching as a substitute; that's O(n²) and LINQ's `join` uses hash-based lookup internally, making it O(n+m).

---

## Core Concept

SQL JOIN lives in the database engine. LINQ join lives in your process, over two `IEnumerable<T>` sequences already in memory. The mechanics are similar — you declare an outer sequence, an inner sequence, and the key each side uses to match — but the execution is different. LINQ's `join` builds a hash lookup of the inner sequence first, then probes it for each outer element, which is why it's O(n+m) rather than O(n²). The result of a plain `join` is an inner join: unmatched outer elements are silently dropped. Left outer joins require `join ... into` (a group join) combined with `DefaultIfEmpty()`, which is the part everyone forgets. There's no built-in right join or full outer join operator — you compose those yourself.

---

## The Code

### Inner join — method syntax
```csharp
record Customer(int Id, string Name);
record Order(int Id, int CustomerId, decimal Total);

var customers = new List<Customer>
{
    new(1, "Alice"),
    new(2, "Bob"),
    new(3, "Charlie"), // no orders — will be dropped in inner join
};

var orders = new List<Order>
{
    new(101, 1, 250.00m),
    new(102, 1, 89.99m),
    new(103, 2, 430.00m),
};

var result = customers.Join(
    orders,
    c => c.Id,           // outer key
    o => o.CustomerId,   // inner key
    (c, o) => new { c.Name, o.Id, o.Total } // result selector
);

foreach (var r in result)
    Console.WriteLine($"{r.Name} — Order {r.Id}: {r.Total:C}");
// Alice — Order 101: $250.00
// Alice — Order 102: $89.99
// Bob   — Order 103: $430.00
// Charlie: absent — inner join drops unmatched outer elements
```

### Inner join — query syntax (cleaner for multi-key joins)
```csharp
var result2 =
    from c in customers
    join o in orders on c.Id equals o.CustomerId
    select new { c.Name, o.Id, o.Total };

// Note: must use 'equals', not '==' — LINQ join keyword requires it
```

### Group join — one outer element, many matching inners
```csharp
// Group join: each customer paired with ALL their orders as a collection
var grouped =
    from c in customers
    join o in orders on c.Id equals o.CustomerId into customerOrders
    select new
    {
        c.Name,
        Orders     = customerOrders,              // IEnumerable<Order>
        OrderCount = customerOrders.Count(),
        Total      = customerOrders.Sum(o => o.Total)
    };

foreach (var g in grouped)
    Console.WriteLine($"{g.Name}: {g.OrderCount} orders, {g.Total:C} total");
// Alice:   2 orders, $339.99 total
// Bob:     1 orders, $430.00 total
// Charlie: 0 orders, $0.00 total  ← included, unlike inner join
```

### Left outer join — group join + DefaultIfEmpty()
```csharp
// The standard LINQ pattern for LEFT JOIN:
// group join gives you the inner collection (possibly empty),
// then DefaultIfEmpty() yields one null element when empty,
// so the outer element is always included.
var leftJoin =
    from c in customers
    join o in orders on c.Id equals o.CustomerId into customerOrders
    from o in customerOrders.DefaultIfEmpty() // flattens; null when no match
    select new
    {
        c.Name,
        OrderId = o?.Id,       // null for unmatched customers
        Total   = o?.Total
    };

foreach (var r in leftJoin)
    Console.WriteLine($"{r.Name} — Order: {r.OrderId?.ToString() ?? "none"}");
// Alice   — Order: 101
// Alice   — Order: 102
// Bob     — Order: 103
// Charlie — Order: none
```

### Multi-key join — matching on composite keys
```csharp
record Shipment(int OrderId, int WarehouseId, string Status);

var shipments = new List<Shipment>
{
    new(101, 10, "Shipped"),
    new(102, 20, "Pending"),
};

// Match on both OrderId AND WarehouseId using anonymous type keys
var multiKey = orders.Join(
    shipments,
    o => new { o.Id, WarehouseId = 10 },           // outer composite key
    s => new { OrderId = s.OrderId, s.WarehouseId }, // inner composite key
    (o, s) => new { o.Total, s.Status }
);
```

### Lookup — when you need to join the same inner set multiple times
```csharp
// ILookup is like a pre-built hash of the inner sequence.
// Use it when you're joining the same inner collection against
// multiple outer sequences — avoids rebuilding the hash each time.
ILookup<int, Order> ordersByCustomer = orders.ToLookup(o => o.CustomerId);

foreach (var customer in customers)
{
    var customerOrders = ordersByCustomer[customer.Id]; // O(1), no allocation
    Console.WriteLine($"{customer.Name}: {customerOrders.Count()} orders");
}
```

---

## Gotchas

- **`join` requires `equals`, not `==`** — in query syntax, `on c.Id == o.CustomerId` is a compile error; it must be `on c.Id equals o.CustomerId`. The left side of `equals` must be the outer key and the right side the inner key — swapping them compiles fine but can confuse the optimizer and is inconsistent with convention.
- **Inner join silently drops unmatched outer elements** — there's no warning when a customer has no orders and disappears from the result. If you expect all outer elements to appear, you need a left outer join with `DefaultIfEmpty()`. This is the most common join bug in production LINQ code.
- **`DefaultIfEmpty()` yields `null` for reference types, `default` for value types** — when you flatten a group join with `DefaultIfEmpty()`, the `o` in `from o in customerOrders.DefaultIfEmpty()` is nullable. Forgetting null checks on `o?.Id` causes `NullReferenceException` on the unmatched rows, not on the matched ones — which makes it a hard bug to spot in testing if your test data always has matches.
- **LINQ join builds a hash on the inner (right) sequence** — if you have a small outer set and a large inner set, the large set becomes the hash table. Swapping which collection is outer vs inner can have a measurable memory impact for large datasets. Put the larger collection on the inner side so the hash covers the most elements.
- **In EF Core, explicit `join` bypasses change tracking and navigation fixup** — EF can't wire up navigation properties on the result of a manual `join`. If you need tracked entities with their related data, use `Include()` instead. Manual joins in EF are best for projections (`select new { ... }`) where you don't need tracked objects.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between join types and their behavior on unmatched elements, and whether you know what's actually happening at the algorithm level — not just the syntax.

**Common question form:** "How do you do a left join in LINQ?" or "What's the difference between `join` and `GroupJoin`?" or "Why is your join returning duplicate/missing rows?"

**The depth signal:** A junior writes an inner join and doesn't notice Charlie disappeared. A senior knows that LINQ's plain `join` is always an inner join, reaches for `join ... into` + `DefaultIfEmpty()` for left joins without prompting, and can explain *why* the pattern works — the group join collects all matching inners into a sub-collection (possibly empty), and `DefaultIfEmpty()` ensures that even an empty sub-collection produces one iteration with a null value, preserving the outer element. The senior also knows that `ToLookup()` is the right move when the same inner collection is joined against multiple outer sequences, and that in EF Core, `Include()` is almost always better than an explicit LINQ `join` for related entities.

---

## Related Topics

- [[dotnet/csharp-linq-basics.md]] — Foundation operators (`Where`, `Select`, `GroupBy`) that compose with joins; deferred execution applies to joins the same way.
- [[dotnet/csharp-collections-dictionary.md]] — `Dictionary` and `ILookup` are the manual equivalents of what LINQ join builds internally; understanding hash-based lookup clarifies join performance.
- [[databases/ef-core-queries.md]] — In EF, `Include()` and navigation properties replace most explicit joins; knowing when to use each is a key production skill.
- [[algorithms/hash-tables.md]] — LINQ join is a hash join algorithm under the hood; the complexity analysis (O(n+m) vs O(n²) nested loops) lives here.

---

## Source

https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/join-operations

---
*Last updated: 2026-03-23*