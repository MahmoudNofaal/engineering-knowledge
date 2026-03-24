# EF Core Queries

> The LINQ-based system EF Core uses to translate C# expressions into SQL — letting you query the database using typed method chains that are compiled to efficient SQL at runtime.

---

## When To Use It

Use EF Core's LINQ provider for the majority of your data access — filtering, sorting, paging, projecting, and joining across related entities. It handles everyday queries cleanly and keeps your C# type-safe. Reach for raw SQL (`FromSqlRaw`, `ExecuteSqlRaw`) when EF can't translate a specific expression, when you need a stored procedure, or when the generated SQL for a complex query is measurably slower than hand-written SQL. Don't evaluate LINQ on the client side for large datasets — an unterminated query that accidentally pulls 100,000 rows into memory before filtering is a production incident.

---

## Core Concept

When you write `context.Products.Where(p => p.Price > 10).OrderBy(p => p.Name)`, nothing hits the database yet. EF Core builds an expression tree. The moment you call a terminal operator — `ToListAsync()`, `FirstOrDefaultAsync()`, `CountAsync()`, `AnyAsync()`, `SingleAsync()` — EF Core's query translator walks that tree and generates SQL. This deferred execution is the key behaviour to internalise: you can compose a query across multiple methods and it only runs once. Projections with `Select()` are especially important — they tell EF to generate a `SELECT` that fetches only the columns you need, rather than pulling back the entire entity row. `AsNoTracking()` removes the change-tracker overhead for read-only queries. Getting these three right — deferred execution, `Select` projections, and `AsNoTracking` — covers 90% of EF query performance decisions.

---

## The Code

**1. Basic filtering, ordering, and paging**
```csharp
// All three clauses combine into a single SQL query — nothing runs until ToListAsync
var products = await context.Products
    .Where(p => p.IsActive && p.Price > 10m)
    .OrderBy(p => p.Name)
    .Skip((page - 1) * pageSize)  // OFFSET
    .Take(pageSize)               // FETCH NEXT
    .ToListAsync();
```

**2. Projection with Select — fetch only what you need**
```csharp
// Generates: SELECT Id, Name, Price FROM Products WHERE IsActive = 1
// NOT: SELECT * FROM Products
var dtos = await context.Products
    .Where(p => p.IsActive)
    .Select(p => new ProductDto
    {
        Id    = p.Id,
        Name  = p.Name,
        Price = p.Price,
        // Computed in SQL — not in C#
        IsInStock = p.Stock > 0
    })
    .AsNoTracking()
    .ToListAsync();
```

**3. Single-item queries — know which throws and which returns null**
```csharp
// FindAsync — checks the identity cache first, then DB; returns null if missing
var product = await context.Products.FindAsync(id);

// FirstOrDefaultAsync — returns null if no match; does NOT throw
var product = await context.Products
    .FirstOrDefaultAsync(p => p.Sku == sku);

// SingleOrDefaultAsync — throws if MORE THAN ONE row matches
var product = await context.Products
    .SingleOrDefaultAsync(p => p.Sku == sku); // use when sku must be unique

// FirstAsync / SingleAsync — throws if ZERO rows match; use when absence is a bug
var product = await context.Products
    .FirstAsync(p => p.Id == id);
```

**4. Eager loading with Include and ThenInclude**
```csharp
// Generates JOINs — all data in one round trip
var orders = await context.Orders
    .Include(o => o.Customer)
    .Include(o => o.Items)
        .ThenInclude(i => i.Product)  // nested: Items → Product
    .Where(o => o.Status == OrderStatus.Pending)
    .AsNoTracking()
    .ToListAsync();

// Filtered include — only load non-cancelled items (EF Core 5+)
var orders = await context.Orders
    .Include(o => o.Items.Where(i => !i.IsCancelled))
    .ToListAsync();
```

**5. Aggregates and existence checks**
```csharp
// Count — generates SELECT COUNT(*) — never load a list just to count it
var total = await context.Products.CountAsync(p => p.IsActive);

// Any — generates SELECT TOP 1 — faster than Count when you only need yes/no
var exists = await context.Products.AnyAsync(p => p.Sku == sku);

// Sum, Average, Max, Min
var revenue = await context.Orders
    .Where(o => o.CreatedAt >= startDate)
    .SumAsync(o => o.TotalAmount);
```

**6. Raw SQL — when LINQ isn't enough**
```csharp
// FromSqlRaw — returns tracked entities; compose further LINQ on top
var products = await context.Products
    .FromSqlRaw("SELECT * FROM Products WHERE CONTAINS(Name, {0})", searchTerm)
    .Where(p => p.IsActive)    // additional LINQ clause applied on top
    .ToListAsync();

// ExecuteSqlRawAsync — for INSERT/UPDATE/DELETE that bypass the change tracker
var rows = await context.Database.ExecuteSqlRawAsync(
    "UPDATE Products SET IsActive = 0 WHERE ExpiresAt < {0}",
    DateTime.UtcNow);
```

**7. Explicit loading — load navigation after the fact**
```csharp
var order = await context.Orders.FindAsync(orderId);

// Loads the collection navigation if it wasn't included in the original query
await context.Entry(order)
             .Collection(o => o.Items)
             .LoadAsync();

// Loads a reference navigation
await context.Entry(order)
             .Reference(o => o.Customer)
             .LoadAsync();
```

**8. Checking the generated SQL (development only)**
```csharp
// Log all SQL to console — add to AddDbContext options in dev
options.LogTo(Console.WriteLine, LogLevel.Information)
       .EnableSensitiveDataLogging(); // shows parameter values

// Or inspect a single query without executing it
var query = context.Products.Where(p => p.IsActive);
Console.WriteLine(query.ToQueryString()); // prints the SQL EF would generate
```

---

## Gotchas

- **Calling `.ToList()` before `.Where()` executes the query immediately and filters in memory.** `context.Products.ToList().Where(p => p.IsActive)` loads every product row into memory first. The correct form is `context.Products.Where(p => p.IsActive).ToList()`. This is the most common EF performance mistake and it's silent — no exception, just unexpectedly high memory and slow queries.
- **`SingleOrDefaultAsync` throws if more than one row matches — not just if zero rows match.** If your filter isn't as selective as you assume, a `SingleOrDefaultAsync` that returns one row in dev will throw `InvalidOperationException` in production when a second matching row exists. Use `FirstOrDefaultAsync` unless you specifically want the uniqueness assertion, and back it up with a unique index.
- **`Include` followed by a LINQ `Where` on the included collection does not filter the Include — it filters the root.** `context.Orders.Include(o => o.Items).Where(i => i.Items.Any(i => !i.IsCancelled))` filters which `Orders` are returned, but still loads all their `Items`. To filter what gets loaded into the navigation, use filtered include: `.Include(o => o.Items.Where(i => !i.IsCancelled))`.
- **EF Core cannot translate arbitrary C# methods inside a LINQ expression.** Calling `p => p.Name.ToTitleCase()` where `ToTitleCase` is your own extension method throws `InvalidOperationException: could not be translated` at runtime. EF can only translate methods it knows how to map to SQL (`Contains`, `StartsWith`, `ToLower`, etc.). Move untranslatable logic to after `ToListAsync()` — but be aware you're then filtering in memory.
- **`AsNoTracking()` breaks navigation property lazy loading if you later enable it.** Untracked entities aren't in the change tracker, so even with lazy loading proxies enabled, navigations on untracked entities stay null. This catches people who enable `UseLazyLoadingProxies()` and then wonder why navigations are null after `AsNoTracking` queries.

---

## Interview Angle

**What they're really testing:** Whether you understand deferred execution, the N+1 query problem, and the performance difference between server-side and client-side evaluation.

**Common question form:** *"What is the N+1 problem and how do you solve it in EF Core?"* or *"What's the difference between deferred and immediate query execution?"*

**The depth signal:** A junior answer describes `Include` as the fix for N+1 and lists `ToListAsync` as how to run a query. A senior answer explains that N+1 comes from accessing a navigation property inside a loop without `Include` (each access triggers a separate `SELECT`), that `Include` generates a `JOIN` in a single round trip, that `Select` projections outperform `Include` for read-only data because they only fetch the columns needed, why `ToList()` before `Where()` is a silent full-table scan, and how `ToQueryString()` lets you inspect exactly what SQL EF is generating without running it — the first tool to reach for when a query is slower than expected.

---

## Related Topics

- [[dotnet/ef-dbcontext.md]] — All queries run through `DbContext`; understanding the change tracker explains why `AsNoTracking` improves read performance and what `FindAsync`'s identity cache does.
- [[dotnet/ef-relationships.md]] — `Include` and `ThenInclude` depend on correctly configured relationships; a misconfigured FK produces wrong JOINs or missing data in query results.
- [[dotnet/ef-fluent-api.md]] — Indexes configured in Fluent API directly affect query performance; a query filtering on an unindexed column generates a full table scan regardless of how well-written the LINQ is.
- [[databases/sql-indexes.md]] — EF translates LINQ to SQL, but the database executes it; understanding indexes explains why a well-written EF query can still be slow without the right index on the underlying table.

---

## Source

https://learn.microsoft.com/en-us/ef/core/querying

---
*Last updated: 2026-03-24*