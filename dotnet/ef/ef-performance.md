# EF Core Performance

> The set of practices that prevent EF Core from generating slow, wasteful, or runaway SQL queries in production.

---

## When To Use It

Performance considerations apply every time EF Core touches the database — not just when things are already slow. The mistakes compound: N+1 queries and over-fetching are invisible in development with small datasets and only surface under real load. Don't prematurely optimize simple CRUD on low-traffic paths, but always be deliberate about what SQL EF is actually generating.

---

## Core Concept

EF Core is a leaky abstraction — it generates SQL, but it doesn't always generate the SQL you'd write yourself. The biggest wins come from four places: loading only what you need (projection over full entity loads), loading it in the right shape (eager loading instead of N+1), not tracking entities you're never going to save (`AsNoTracking()`), and not loading data at all for bulk mutations (`ExecuteUpdateAsync`/`ExecuteDeleteAsync`). The change tracker is the silent cost most people forget — every entity you load gets snapshot-diffed on `SaveChanges()`, and that adds up on read-heavy endpoints. Profile first with `ToQueryString()` and EF query logs; optimise what you've measured.

---

## The Code

**1. AsNoTracking — eliminate change tracker overhead on reads**
```csharp
var products = await _context.Products
    .AsNoTracking()
    .Where(p => p.IsActive)
    .ToListAsync();
```

**2. Projection — select only the columns you need**
```csharp
var summaries = await _context.Orders
    .AsNoTracking()
    .Where(o => o.CustomerId == customerId)
    .Select(o => new OrderSummaryDto
    {
        Id        = o.Id,
        Total     = o.Total,
        CreatedAt = o.CreatedAt
    })
    .ToListAsync();
// Generates: SELECT Id, Total, CreatedAt FROM Orders WHERE CustomerId = @p0
// NOT SELECT *
```

**3. N+1 — the most common production EF bug**
```csharp
// BAD: N+1 — one SELECT per order
var orders = await _context.Orders.ToListAsync();
foreach (var order in orders)
    Console.WriteLine(order.Customer.Name); // triggers a new SELECT per iteration

// GOOD: single JOIN query
var orders = await _context.Orders
    .Include(o => o.Customer)
    .AsNoTracking()
    .ToListAsync();
```

**4. Split queries — avoiding cartesian explosion on multiple Includes**
```csharp
// Including two collections multiplies result rows (10 items × 5 tags = 50 rows per order)
// AsSplitQuery runs 3 targeted queries instead
var orders = await _context.Orders
    .Include(o => o.Items)
    .Include(o => o.Tags)
    .AsSplitQuery()
    .AsNoTracking()
    .ToListAsync();

// Configure globally — all queries split by default
options.UseSqlServer(connStr, sql =>
    sql.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery));
```

**5. Compiled queries — removing per-call translation cost**
```csharp
// Translation overhead is significant on hot paths (auth, product lookup, etc.)
// EF.CompileAsyncQuery pays the cost once; subsequent calls reuse the cached SQL plan
private static readonly Func<AppDbContext, int, Task<Product?>> GetProductById =
    EF.CompileAsyncQuery((AppDbContext ctx, int id) =>
        ctx.Products.AsNoTracking().FirstOrDefault(p => p.Id == id));

// Usage — fast, no expression tree re-translation
var product = await GetProductById(_context, productId);
```

**6. Bulk operations — EF Core 7+ ExecuteUpdateAsync / ExecuteDeleteAsync**
```csharp
// BAD: load all, modify in memory, SaveChanges — O(n) database round trips
var expired = await _context.Sessions
    .Where(s => s.ExpiresAt < DateTime.UtcNow)
    .ToListAsync();
_context.Sessions.RemoveRange(expired);
await _context.SaveChangesAsync();

// GOOD: single DELETE statement, zero rows loaded into memory
await _context.Sessions
    .Where(s => s.ExpiresAt < DateTime.UtcNow)
    .ExecuteDeleteAsync();

// Bulk UPDATE — also a single statement
await _context.Products
    .Where(p => p.CategoryId == oldCategoryId)
    .ExecuteUpdateAsync(p => p
        .SetProperty(x => x.CategoryId, newCategoryId)
        .SetProperty(x => x.UpdatedAt, DateTime.UtcNow));
```

**7. DbContext pooling — reducing allocation overhead**
```csharp
// Standard AddDbContext creates a new DbContext instance per request
// AddDbContextPool reuses instances from a pool — significant throughput gain
// for high-concurrency APIs where DbContext construction is measurable overhead
builder.Services.AddDbContextPool<AppDbContext>(options =>
    options.UseSqlServer(connectionString),
    poolSize: 256); // tune to match expected concurrent requests

// Constraint: if your DbContext has instance state fields (e.g. for multi-tenancy),
// you must implement IResettableService to clear that state between pool reuses
public class AppDbContext : DbContext, IResettableService
{
    private int _tenantId;

    public void ResetState()
    {
        _tenantId = 0; // cleared before the context returns to the pool
        ChangeTracker.Clear();
    }
}
```

**8. SaveChanges batching — EF Core 7+**
```csharp
// EF Core 7+ automatically batches multiple INSERT/UPDATE/DELETE into fewer round trips
// Default batch size is 42 — configurable per provider
options.UseSqlServer(connectionString, sql => sql.MaxBatchSize(100));

// For very high-volume inserts (thousands of rows), use EFCore.BulkExtensions
// which bypasses EF's insert path entirely and uses SqlBulkCopy
await context.BulkInsertAsync(products); // from Zack.EFCore.Batch or EFCore.BulkExtensions
```

**9. Connection resiliency — retry on transient failures**
```csharp
// SQL Azure and cloud databases have transient failures (network blips, throttling)
// EnableRetryOnFailure wraps every operation in automatic retry with backoff
options.UseSqlServer(connectionString, sql =>
    sql.EnableRetryOnFailure(
        maxRetryCount: 5,
        maxRetryDelay: TimeSpan.FromSeconds(30),
        errorNumbersToAdd: null));  // null = default transient error codes

// Manual retry with ExecutionStrategy (required when you use explicit transactions)
var strategy = _context.Database.CreateExecutionStrategy();

await strategy.ExecuteAsync(async () =>
{
    await using var transaction = await _context.Database.BeginTransactionAsync();
    try
    {
        _context.Orders.Add(order);
        await _context.SaveChangesAsync();
        await transaction.CommitAsync();
    }
    catch
    {
        await transaction.RollbackAsync();
        throw;
    }
});
```

**10. Offset vs keyset pagination — stop using SKIP at scale**
```csharp
// Offset pagination — SQL Server must scan all preceding rows to skip them
// 50,000 skips = 50,000 rows scanned and discarded — degrades linearly with page depth
var page = await _context.Products
    .OrderBy(p => p.Id)
    .Skip((pageNumber - 1) * pageSize) // slow at high page numbers
    .Take(pageSize)
    .ToListAsync();

// Keyset (cursor) pagination — uses an index seek, fast at any depth
var page = await _context.Products
    .Where(p => p.Id > lastSeenId)  // supply the last seen Id from the previous response
    .OrderBy(p => p.Id)
    .Take(pageSize)
    .ToListAsync();
```

**11. Query logging and slow query detection**
```csharp
// Development: log all SQL to console
options.LogTo(Console.WriteLine, LogLevel.Information)
       .EnableSensitiveDataLogging();

// Production: log only slow queries to structured logging
options.LogTo(
    (eventId, level) => eventId == RelationalEventId.CommandExecuted,
    (eventData) =>
    {
        if (eventData is CommandExecutedEventData cmd
            && cmd.Duration > TimeSpan.FromMilliseconds(500))
        {
            logger.LogWarning("Slow EF query ({Duration}ms): {Sql}",
                cmd.Duration.TotalMilliseconds,
                cmd.Command.CommandText);
        }
    });

// Inspect generated SQL without executing (dev / debugging)
var query = _context.Products.Where(p => p.IsActive);
Console.WriteLine(query.ToQueryString()); // first tool to reach for on slow queries
```

---

## Gotchas

- **`.ToList()` inside a loop is always N+1.** EF doesn't batch automatically. If you're calling any EF query inside a `foreach`, you have N+1 unless you restructured the query to load everything upfront with `Include()` or a separate query.
- **`Select()` with untranslatable C# methods forces client-side evaluation.** If you call a C# method inside a `Select()` that EF can't translate to SQL, it silently loads the full entity set into memory first and evaluates in-process. Always check the query log if a projection query feels slow.
- **`AsSplitQuery()` is not safe inside explicit transactions requiring consistent snapshots.** Split queries run as multiple round trips — data can change between them. If you're inside a `SERIALIZABLE` transaction and expecting a consistent view of the data, `AsSplitQuery` can return an inconsistent set. Use single queries inside strict transactions.
- **`ExecuteUpdateAsync` and `ExecuteDeleteAsync` bypass the change tracker.** Tracked entities in the same context scope won't reflect the bulk update — they still hold the old values. Either avoid querying those entities in the same scope, or reload them with `ReloadAsync()`.
- **`AddDbContextPool` + custom state fields = silent tenant data leaks.** If your context has a `_tenantId` field and you use `AddDbContextPool`, a pooled instance may serve the next request's tenant with the previous tenant's ID if you don't implement `IResettableService`. This is a security bug, not just a performance bug.
- **`EnableRetryOnFailure` conflicts with manual transactions.** The retry strategy wraps each operation, but it can't retry a partial transaction — it doesn't know which prior operations succeeded. Use `strategy.ExecuteAsync(lambda)` to wrap the entire transaction in the retry boundary.

---

## Interview Angle

**What they're really testing:** Whether you understand the boundary between LINQ and SQL — specifically, what EF evaluates server-side vs client-side, and the cost model of the change tracker.

**Common question form:** *"How would you optimize a slow EF Core query?"* or *"What's an N+1 problem and how do you fix it?"*

**The depth signal:** A junior fixes N+1 with `Include()` and calls it done. A senior knows that `Include()` with multiple collections can produce a cartesian product worse than N+1, reaches for `AsSplitQuery()` or projection to a DTO, disables tracking on read paths, uses `ExecuteDeleteAsync`/`ExecuteUpdateAsync` for bulk ops instead of load-modify-save, knows cursor pagination vs offset pagination and why offset degrades at depth, uses compiled queries on hot paths, configures `EnableRetryOnFailure` for cloud databases, and reaches for `ToQueryString()` and EF query logs before guessing at the cause of a slow query.

---

## Related Topics

- [[dotnet/ef/ef-queries.md]] — All the query patterns (compiled queries, split queries, projections, streaming) — this file covers measurement and tuning; that file covers the API.
- [[dotnet/ef/ef-tracking.md]] — `AsNoTracking()` and change tracker overhead are tracking topics; performance and tracking are tightly coupled.
- [[dotnet/ef/ef-transactions.md]] — `AsSplitQuery()` and `EnableRetryOnFailure` interact with transaction boundaries; read both together.
- [[dotnet/ef/ef-dbcontext.md]] — `AddDbContextPool`, `IResettableService`, and `IDbContextFactory` for background jobs are context configuration topics.
- [[databases/sql/sql-indexing.md]] — EF generating the right SQL is only half the story; the query still needs the right index behind it.

---

## Source

https://learn.microsoft.com/en-us/ef/core/performance/efficient-querying

---
*Last updated: 2026-04-08*