# C# — LINQ Joins

> LINQ operators that correlate elements from two sequences by a matching key — inner join, group join (one-to-many), and left outer join.

---

## Quick Reference

| Join type | Pattern | Unmatched outer? |
|---|---|---|
| Inner | `join ... on ... equals ...` | Dropped silently |
| Group join | `join ... into ...` | Included with empty collection |
| Left outer | Group join + `DefaultIfEmpty()` | Included with null inner |

---

## Core Concept

LINQ joins work in-memory over two `IEnumerable<T>` sequences. Internally, LINQ builds a hash lookup of the inner sequence, then probes it for each outer element — O(n+m) rather than O(n²) nested loops.

An inner join drops unmatched outer elements silently. A **left outer join** requires `join ... into` (group join) combined with `DefaultIfEmpty()` — the part everyone forgets.

---

## The Code

**Inner join**
```csharp
record Customer(int Id, string Name);
record Order(int Id, int CustomerId, decimal Total);
var customers = new List<Customer> { /* ... */ };
var orders    = new List<Order>    { /* ... */ };

var result = customers.Join(
    orders,
    c => c.Id,               // outer key
    o => o.CustomerId,       // inner key
    (c, o) => new { c.Name, o.Id, o.Total });
// Customers with no orders are DROPPED
```

**Left outer join — group join + DefaultIfEmpty**
```csharp
var leftJoin =
    from c in customers
    join o in orders on c.Id equals o.CustomerId into customerOrders
    from o in customerOrders.DefaultIfEmpty()  // null when no match
    select new { c.Name, OrderId = o?.Id, Total = o?.Total };
// All customers appear — null for those without orders
```

**Group join — one customer with ALL their orders**
```csharp
var grouped =
    from c in customers
    join o in orders on c.Id equals o.CustomerId into customerOrders
    select new
    {
        c.Name,
        Orders     = customerOrders,
        OrderCount = customerOrders.Count(),
        Total      = customerOrders.Sum(o => o.Total)
    };
// Charlie with 0 orders: OrderCount = 0, Total = 0 (not dropped)
```

**`ToLookup` — pre-build hash for repeated joins**
```csharp
// If joining the same orders against multiple customer sets:
ILookup<int, Order> ordersByCustomer = orders.ToLookup(o => o.CustomerId);

foreach (var c in customers)
{
    var co = ordersByCustomer[c.Id]; // O(1) per customer
    Console.WriteLine($"{c.Name}: {co.Count()} orders");
}
```

---

## Gotchas

- **`join` requires `equals`, not `==`.** `on c.Id == o.CustomerId` is a compile error.
- **Inner join silently drops unmatched outer elements.** If you expect all customers, you need a left outer join.
- **`DefaultIfEmpty()` yields `null` for reference types.** Forgetting null-checks on `o?.Id` causes NRE on unmatched rows.
- **LINQ join builds a hash on the inner (right) sequence.** Put the larger collection on the inner side for better memory usage.
- **In EF Core, prefer `Include()` over explicit joins.** Manual joins bypass change tracking and navigation property fixup.

---

## Source

[Join Operations — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/join-operations)

---
*Last updated: 2026-04-06*