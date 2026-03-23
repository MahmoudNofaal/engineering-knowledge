# C# — LINQ Projection

> Transforming each element of a sequence into a new shape using `Select` and `SelectMany` — mapping inputs to outputs, flattening nested sequences, or extracting specific fields.

---

## When To Use It

Use projection whenever you need to transform a sequence from one shape to another — pulling specific fields from a large object, mapping domain models to DTOs, computing derived values, or flattening nested collections. It's the LINQ equivalent of SQL `SELECT`. Don't project to anonymous types when the result needs to cross a method boundary or be returned from a public API — use named records or classes instead. In EF Core, projecting with `Select` before hitting the database is one of the most important performance habits: it limits the columns fetched to only what you need.

---

## Core Concept

`Select` is a one-to-one transformation: for every element in, exactly one element comes out. `SelectMany` is a one-to-many flattening: each element maps to a sub-sequence, and all those sub-sequences are concatenated into a single flat output. Both are lazy — nothing runs until the result is enumerated. The key mental model for `SelectMany` is that it does what two nested `foreach` loops do: outer loop produces collections, inner loop iterates each collection, and the output is all the inner elements in one flat stream. In query syntax, `SelectMany` is expressed naturally as multiple `from` clauses, which is why query syntax is sometimes cleaner for complex projections.

---

## The Code

### Select — transform each element
```csharp
record Product(string Name, string Category, decimal Price);

var products = new List<Product>
{
    new("Laptop",  "Electronics", 999.99m),
    new("Phone",   "Electronics", 699.99m),
    new("Desk",    "Furniture",   349.99m),
    new("Chair",   "Furniture",   249.99m),
};

// Project to anonymous type — shape the output, not the source
var names = products.Select(p => p.Name);
// "Laptop", "Phone", "Desk", "Chair"

// Project to a computed value
var discounted = products.Select(p => new
{
    p.Name,
    Original   = p.Price,
    Discounted = Math.Round(p.Price * 0.9m, 2)
});
```

### Select with index — when position matters
```csharp
var ranked = products
    .OrderByDescending(p => p.Price)
    .Select((p, index) => new          // second parameter is the 0-based index
    {
        Rank  = index + 1,
        p.Name,
        p.Price
    });

foreach (var r in ranked)
    Console.WriteLine($"#{r.Rank} {r.Name}: {r.Price:C}");
// #1 Laptop: $999.99
// #2 Phone:  $699.99
// #3 Desk:   $349.99
// #4 Chair:  $249.99
```

### Projecting to a named record — when anonymous types aren't enough
```csharp
record ProductDto(string Name, decimal Price, bool IsExpensive);

// Use named types when the projection crosses a method boundary
IEnumerable<ProductDto> GetDtos(IEnumerable<Product> products) =>
    products.Select(p => new ProductDto(
        p.Name,
        p.Price,
        p.Price > 500m
    ));
```

### SelectMany — flatten nested collections
```csharp
record Order(int Id, string Customer, List<string> Items);

var orders = new List<Order>
{
    new(1, "Alice", new() { "apple", "banana" }),
    new(2, "Bob",   new() { "cherry", "date", "elderberry" }),
    new(3, "Alice", new() { "fig" }),
};

// SelectMany: one order → many items → all items in one flat sequence
var allItems = orders.SelectMany(o => o.Items);
// apple, banana, cherry, date, elderberry, fig

// SelectMany with result selector — keep context from the outer element
var itemsWithOwner = orders.SelectMany(
    o => o.Items,                            // collection selector
    (o, item) => new { o.Customer, item }    // result selector — pairs each item with its order
);

foreach (var x in itemsWithOwner)
    Console.WriteLine($"{x.Customer}: {x.item}");
// Alice: apple
// Alice: banana
// Bob:   cherry  ...etc
```

### SelectMany in query syntax — multiple from clauses
```csharp
// Same as the result-selector overload above, but more readable for complex cases
var itemsWithOwner2 =
    from o in orders
    from item in o.Items          // second from = SelectMany
    select new { o.Customer, item };
```

### Conditional projection — null-safe mapping
```csharp
record UserProfile(string Username, Address? Address);
record Address(string City, string Country);

var users = new List<UserProfile>
{
    new("alice", new("Cairo",  "EG")),
    new("bob",   null),
    new("charlie", new("London", "UK")),
};

// Safe projection — null-conditional handles missing Address
var locations = users.Select(u => new
{
    u.Username,
    City    = u.Address?.City    ?? "Unknown",
    Country = u.Address?.Country ?? "Unknown"
});
```

### EF Core — project early to limit columns fetched
```csharp
// BAD: fetches entire entity (all columns) then discards most in memory
var names1 = dbContext.Products
    .ToList()
    .Select(p => p.Name);

// GOOD: Select before ToList/First — EF translates this to SELECT Name FROM Products
var names2 = dbContext.Products
    .Select(p => p.Name)
    .ToList();

// GOOD: project to DTO — EF generates SELECT Name, Price FROM Products
var dtos = dbContext.Products
    .Where(p => p.Price > 100)
    .Select(p => new ProductDto(p.Name, p.Price, p.Price > 500))
    .ToList();
```

---

## Gotchas

- **Anonymous types can't leave the method scope** — `Select(p => new { p.Name, p.Price })` produces a compiler-generated type with no accessible name. You can't return it from a non-generic method, store it in a `List<?>`, or use it as a parameter type. Switch to a named `record` or `ValueTuple` the moment the projection needs to cross a boundary.
- **`Select` is not `ForEach`** — `Select` is a pure transformation that returns a new sequence; it has no side effects by design. Using `Select` to run side-effecting code (logging, writing to a database) is a code smell. The side effects won't even run unless someone enumerates the result. Use an explicit `foreach` for side effects.
- **EF Core can't translate arbitrary C# methods inside `Select`** — calling a custom helper method, `ToString()` overloads, or any method the EF provider doesn't know about inside a `Select` either throws at runtime or triggers a full client-side evaluation. Keep EF projections to simple property access, arithmetic, and string operations the provider explicitly supports.
- **`SelectMany` on an empty outer sequence returns empty, not an error** — if no orders exist, `orders.SelectMany(o => o.Items)` yields nothing. But if the inner collection property itself is `null` (not empty), `SelectMany` throws `NullReferenceException` when it tries to enumerate it. Always initialize collection properties to empty rather than null, or guard with `.Where(o => o.Items != null)` before the `SelectMany`.
- **Projecting inside `Select` doesn't change the source** — the source collection is never modified. Each call to `Select` produces a new lazy sequence. If you want to update objects in place, you need `foreach` with mutation, not `Select`.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between transforming and flattening, can reason about when projections execute, and know the EF Core implication of projecting before vs after materialization.

**Common question form:** "Flatten this nested collection," or "Convert this list of entities to DTOs," or "Why is this EF query fetching more columns than it needs?"

**The depth signal:** A junior uses `Select` for simple field extraction and reaches for nested `foreach` loops when collections are nested. A senior knows `SelectMany` flattens one level of nesting and can use the result-selector overload to preserve outer context — and explains it as the two-nested-`foreach` pattern collapsed into one operator. The senior also knows that in EF Core, `Select` before `ToList` is translated to a column-restricted SQL `SELECT`, while `Select` after `ToList` runs in memory against fully loaded entities — and that this distinction is the difference between fetching 3 columns and fetching 30.

---

## Related Topics

- [[dotnet/csharp-linq-basics.md]] — Covers deferred execution and core operators; `Select` and `SelectMany` inherit all lazy evaluation behavior described there.
- [[dotnet/csharp-linq-joins.md]] — `SelectMany` with a result selector is the functional equivalent of a cross join; join operators compose naturally with projection.
- [[dotnet/csharp-linq-grouping.md]] — `GroupBy` is almost always followed by a `Select` to project the group key and aggregates into a flat result shape.
- [[databases/ef-core-queries.md]] — Column projection via `Select` is one of the most impactful EF Core performance techniques; the translation rules and limitations are covered there.

---

## Source

https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/projection-operations

---
*Last updated: 2026-03-23*