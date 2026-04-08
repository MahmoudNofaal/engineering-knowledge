# EF Core Queries

> The LINQ-based system EF Core uses to translate C# expressions into SQL — letting you query the database using typed method chains that are compiled to efficient SQL at runtime.

---

## When To Use It

Use EF Core's LINQ provider for the majority of your data access — filtering, sorting, paging, projecting, and joining across related entities. It handles everyday queries cleanly and keeps your C# type-safe. Reach for raw SQL (`FromSqlRaw`, `ExecuteSqlRaw`) when EF can't translate a specific expression, when you need a stored procedure, or when the generated SQL for a complex query is measurably slower than hand-written SQL. Don't evaluate LINQ on the client side for large datasets — an unterminated query that accidentally pulls 100,000 rows into memory before filtering is a production incident.

---

## Core Concept

When you write `context.Products.Where(p => p.Price > 10).OrderBy(p => p.Name)`, nothing hits the database yet. EF Core builds an expression tree. The moment you call a terminal operator — `ToListAsync()`, `FirstOrDefaultAsync()`, `CountAsync()`, `AnyAsync()`, `SingleAsync()` — EF Core's query translator walks that tree and generates SQL. This deferred execution is the key behaviour to internalise: you can compose a query across multiple methods and it only runs once. Projections with `Select()` are especially important — they tell EF to generate a `SELECT` that fetches only the columns you need rather than pulling back the entire entity row. `AsNoTracking()` removes the change-tracker overhead for read-only queries. Getting these three right — deferred execution, `Select` projections, and `AsNoTracking` — covers 90% of EF query performance decisions.

---

## The Code

**1. Basic filtering, ordering, and paging**
```csharp
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
var dtos = await context.Products
    .Where(p => p.IsActive)
    .Select(p => new ProductDto
    {
        Id        = p.Id,
        Name      = p.Name,
        Price     = p.Price,
        IsInStock = p.Stock > 0  // computed in SQL, not C#
    })
    .AsNoTracking()
    .ToListAsync();
```

**3. Single-item queries — know which throws and which returns null**
```csharp
var product = await context.Products.FindAsync(id);                       // null if missing; hits identity cache first
var product = await context.Products.FirstOrDefaultAsync(p => p.Sku == sku);  // null if no match
var product = await context.Products.SingleOrDefaultAsync(p => p.Sku == sku); // throws if >1 row matches
var product = await context.Products.FirstAsync(p => p.Id == id);        // throws if zero rows
```

**4. Eager loading with Include and ThenInclude**
```csharp
var orders = await context.Orders
    .Include(o => o.Customer)
    .Include(o => o.Items)
        .ThenInclude(i => i.Product)
    .Where(o => o.Status == OrderStatus.Pending)
    .AsNoTracking()
    .ToListAsync();

// Filtered include — only non-cancelled items (EF Core 5+)
var orders = await context.Orders
    .Include(o => o.Items.Where(i => !i.IsCancelled))
    .ToListAsync();
```

**5. Split queries — avoiding cartesian explosion**
```csharp
// Loading two collections with Include generates a JOIN that multiplies rows
// 1 order × 10 items × 5 tags = 50 rows returned, then deduplicated in memory
// AsSplitQuery runs 3 separate queries instead — one per Include
var orders = await context.Orders
    .Include(o => o.Items)
    .Include(o => o.Tags)
    .AsSplitQuery()
    .AsNoTracking()
    .ToListAsync();

// Configure split queries globally (all queries use split mode by default)
options.UseSqlServer(connectionString, sql =>
    sql.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery));

// Override back to single query for a specific query
var order = await context.Orders
    .Include(o => o.Items)
    .AsSingleQuery() // override the global split setting
    .FirstOrDefaultAsync(o => o.Id == orderId);
```

**6. Aggregates and existence checks**
```csharp
var total  = await context.Products.CountAsync(p => p.IsActive);         // SELECT COUNT(*)
var exists = await context.Products.AnyAsync(p => p.Sku == sku);          // SELECT TOP 1
var revenue = await context.Orders
    .Where(o => o.CreatedAt >= startDate)
    .SumAsync(o => o.TotalAmount);
```

**7. Compiled queries — eliminating translation overhead on hot paths**
```csharp
// LINQ-to-SQL translation happens once and is cached — reused on every subsequent call
// Use for queries called hundreds of times per second (auth checks, product lookups, etc.)
private static readonly Func<AppDbContext, int, Task<Product?>> GetProductById =
    EF.CompileAsyncQuery((AppDbContext ctx, int id) =>
        ctx.Products
           .AsNoTracking()
           .FirstOrDefault(p => p.Id == id));

private static readonly Func<AppDbContext, int, IAsyncEnumerable<ProductDto>> GetProductsByCategory =
    EF.CompileAsyncQuery((AppDbContext ctx, int categoryId) =>
        ctx.Products
           .Where(p => p.CategoryId == categoryId && p.IsActive)
           .Select(p => new ProductDto { Id = p.Id, Name = p.Name, Price = p.Price })
           .AsNoTracking());

// Usage — translation cost paid once at startup, reused every call
var product = await GetProductById(_context, productId);

await foreach (var dto in GetProductsByCategory(_context, categoryId))
{
    // process dto
}
```

**8. Global query filters — applied automatically**
```csharp
// Configured in OnModelCreating — filters every query for this entity type
modelBuilder.Entity<Product>().HasQueryFilter(p => !p.IsDeleted);
modelBuilder.Entity<Order>().HasQueryFilter(o => o.TenantId == _tenantId);

// Querying — IsDeleted = true rows invisible by default
var products = await context.Products.ToListAsync(); // WHERE IsDeleted = 0

// Bypass the filter when needed — admin views, data corrections
var allProducts = await context.Products
    .IgnoreQueryFilters()
    .ToListAsync(); // no WHERE IsDeleted clause

// Filter applies to Include() as well
var orders = await context.Orders
    .Include(o => o.Items) // Items with IsDeleted = 1 are excluded from the Include
    .ToListAsync();
```

**9. Streaming large result sets — AsAsyncEnumerable**
```csharp
// For processing large datasets without loading everything into memory at once
// Useful for: batch jobs, exports, ETL pipelines
public async Task ExportProductsAsync(Stream outputStream)
{
    var writer = new StreamWriter(outputStream);

    // Streams rows one at a time — doesn't materialise the full list
    await foreach (var product in context.Products
        .AsNoTracking()
        .Where(p => p.IsActive)
        .Select(p => new { p.Sku, p.Name, p.Price })
        .AsAsyncEnumerable())
    {
        await writer.WriteLineAsync($"{product.Sku},{product.Name},{product.Price}");
    }
}

// Chunked processing — process 1000 rows at a time, clear memory between chunks
public async Task ProcessAllOrdersAsync()
{
    var lastId = 0;

    while (true)
    {
        var chunk = await context.Orders
            .AsNoTracking()
            .Where(o => o.Id > lastId)
            .OrderBy(o => o.Id)
            .Take(1000)
            .ToListAsync();

        if (!chunk.Any()) break;

        foreach (var order in chunk) ProcessOrder(order);

        lastId = chunk.Last().Id;
    }
}
```

**10. Temporal table queries — EF Core 6+**
```csharp
// SQL Server temporal tables — query historical state
// Requires: entity configured with .IsTemporal() in OnModelCreating

// State at a specific point in time
var productAtYearStart = await context.Products
    .TemporalAsOf(new DateTime(2026, 1, 1))
    .FirstOrDefaultAsync(p => p.Id == 42);

// All versions of a row between two timestamps
var history = await context.Products
    .TemporalBetween(DateTime.UtcNow.AddMonths(-6), DateTime.UtcNow)
    .Where(p => p.Id == 42)
    .ToListAsync();

// All changes ever made to a row (full history)
var allVersions = await context.Products
    .TemporalAll()
    .Where(p => p.Id == 42)
    .OrderBy(p => EF.Property<DateTime>(p, "PeriodStart"))
    .ToListAsync();

// Configure temporal table in OnModelCreating
modelBuilder.Entity<Product>().ToTable(t => t.IsTemporal(tt =>
{
    tt.HasPeriodStart("PeriodStart");
    tt.HasPeriodEnd("PeriodEnd");
    tt.UseHistoryTable("ProductsHistory");
}));
```

**11. Keyset (cursor) pagination — replacing offset pagination**
```csharp
// Offset pagination — slow at high offsets (database must skip all preceding rows)
var page = await context.Products
    .OrderBy(p => p.Id)
    .Skip(50000)   // scans 50,000 rows to skip them — gets slower as page increases
    .Take(20)
    .ToListAsync();

// Keyset pagination — fast at any depth (uses an index seek)
// Pass the last Id seen from the previous page
var page = await context.Products
    .Where(p => p.Id > lastSeenId)   // seeks directly to the next batch
    .OrderBy(p => p.Id)
    .Take(20)
    .ToListAsync();

// For multi-column ordering, use a composite cursor
var page = await context.Products
    .Where(p => p.CreatedAt > lastSeenDate
             || (p.CreatedAt == lastSeenDate && p.Id > lastSeenId))
    .OrderBy(p => p.CreatedAt).ThenBy(p => p.Id)
    .Take(20)
    .ToListAsync();
```

**12. Raw SQL — when LINQ isn't enough**
```csharp
var products = await context.Products
    .FromSqlRaw("SELECT * FROM Products WHERE CONTAINS(Name, {0})", searchTerm)
    .Where(p => p.IsActive)
    .ToListAsync();

var rows = await context.Database.ExecuteSqlRawAsync(
    "UPDATE Products SET IsActive = 0 WHERE ExpiresAt < {0}", DateTime.UtcNow);
```

**13. Checking the generated SQL**
```csharp
var query = context.Products.Where(p => p.IsActive);
Console.WriteLine(query.ToQueryString()); // prints SQL without running it — first tool to reach for when debugging slow queries
```

---

## Gotchas

- **Calling `.ToList()` before `.Where()` executes the query immediately and filters in memory.** `context.Products.ToList().Where(p => p.IsActive)` loads every product row into memory first. The correct form is `context.Products.Where(p => p.IsActive).ToList()`. This is the most common EF performance mistake — silent, no exception, just unexpectedly high memory and slow queries.
- **`SingleOrDefaultAsync` throws if more than one row matches — not just if zero rows match.** If your filter isn't as selective as you assume, a `SingleOrDefaultAsync` that returns one row in dev throws `InvalidOperationException` in production when a second matching row exists. Use `FirstOrDefaultAsync` unless you specifically want the uniqueness assertion.
- **`AsSplitQuery()` runs in multiple round trips — not a free lunch.** It avoids cartesian explosion but introduces inconsistency risk if data changes between the split queries. Don't use it inside an explicit transaction expecting a consistent snapshot.
- **`Include` with a LINQ `Where` on the root does not filter what gets included.** `context.Orders.Include(o => o.Items).Where(o => o.Items.Any(i => !i.IsCancelled))` filters which `Orders` are returned, but still loads all their `Items`. To filter what gets loaded into the navigation, use filtered include: `.Include(o => o.Items.Where(i => !i.IsCancelled))`.
- **EF Core cannot translate arbitrary C# methods inside a LINQ expression.** Calling `p => p.Name.ToTitleCase()` where `ToTitleCase` is a custom extension method throws `InvalidOperationException: could not be translated` at runtime. EF only knows how to map specific methods (`Contains`, `StartsWith`, `ToLower`, etc.) to SQL. Move untranslatable logic to after `ToListAsync()`.
- **Compiled queries break if you change `DbContextOptions` between compilation and use.** Compiled queries capture the provider model at creation time. Swapping providers in tests (SQLite vs SQL Server) can cause compiled queries to misbehave silently or throw. Isolate compiled queries from test contexts or recompile per provider.
- **`AsAsyncEnumerable()` holds the database connection open for the duration of the iteration.** Unlike `ToListAsync()` which fetches everything and releases the connection, streaming keeps the connection open. Don't perform other database operations on the same context while streaming — open reader + open connection = conflict.

---

## Interview Angle

**What they're really testing:** Whether you understand deferred execution, the N+1 query problem, and the performance difference between server-side and client-side evaluation.

**Common question form:** *"What is the N+1 problem and how do you solve it in EF Core?"* or *"What's the difference between deferred and immediate query execution?"*

**The depth signal:** A junior answer describes `Include` as the fix for N+1 and lists `ToListAsync` as how to run a query. A senior answer explains that N+1 comes from accessing a navigation property inside a loop without `Include`, that `Include` on two collections generates a cartesian product worse than N+1 (use `AsSplitQuery`), that `Select` projections outperform `Include` for read-only data, why `ToList()` before `Where()` is a silent full-table scan, the difference between offset and keyset pagination and why offset degrades at scale, how compiled queries eliminate per-call LINQ translation overhead, why `AsAsyncEnumerable()` keeps a connection open and when chunked pagination is safer, and how `ToQueryString()` is the first debugging tool for slow EF queries.

---

## Related Topics

- [[dotnet/ef/ef-dbcontext.md]] — All queries run through `DbContext.DbSet<T>`; understanding the context is the prerequisite for query translation, `AsNoTracking`, and global query filters.
- [[dotnet/ef/ef-relationships.md]] — `Include` and `ThenInclude` depend on correctly configured relationships; a misconfigured FK produces wrong JOINs or missing data.
- [[dotnet/ef/ef-performance.md]] — Compiled queries, split queries, and keyset pagination are performance topics — this file covers the query API, performance covers the measurement and tuning.
- [[dotnet/ef/ef-global-query-filters.md]] — `HasQueryFilter()` applies automatic WHERE clauses to every query; `IgnoreQueryFilters()` is the per-query escape hatch.
- [[databases/sql/sql-indexing.md]] — EF translates LINQ to SQL, but the database executes it; the right index is what makes a well-written EF query fast.

---

## Source

https://learn.microsoft.com/en-us/ef/core/querying

---
*Last updated: 2026-04-08*