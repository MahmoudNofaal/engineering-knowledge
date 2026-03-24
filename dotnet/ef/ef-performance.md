# EF Core Performance

> The set of practices that prevent EF Core from generating slow, wasteful, or runaway SQL queries in production.

---

## When To Use It
Performance considerations apply every time EF Core touches the database — not just when things are already slow. The mistakes compound: N+1 queries and over-fetching are invisible in development with small datasets and only surface under real load. Don't prematurely optimize simple CRUD on low-traffic paths, but always be deliberate about what SQL EF is actually generating.

---

## Core Concept
EF Core is a leaky abstraction — it generates SQL, but it doesn't always generate the SQL you'd write yourself. The biggest wins come from three places: loading only what you need (projection over full entity loads), loading it in the right shape (eager loading instead of N+1), and not tracking entities you're never going to save (`.AsNoTracking()`). The change tracker is the silent cost most people forget — every entity you load gets snapshot-diffed on `SaveChanges()`, and that adds up. If you're reading data to display it, not to update it, you're paying for tracking you don't need.

---

## The Code
```csharp
// 1. AsNoTracking — read-only queries, no change tracker overhead
var products = await _context.Products
    .AsNoTracking()
    .Where(p => p.IsActive)
    .ToListAsync();
```
```csharp
// 2. Projection — select only the columns you actually need
var summaries = await _context.Orders
    .AsNoTracking()
    .Where(o => o.CustomerId == customerId)
    .Select(o => new OrderSummaryDto        // EF translates this to SELECT Id, Total, CreatedAt
    {
        Id = o.Id,
        Total = o.Total,
        CreatedAt = o.CreatedAt
    })
    .ToListAsync();
```
```csharp
// 3. Eager loading vs N+1 — the difference between 1 query and 1000
// BAD: N+1 — one query per order to fetch customer
var orders = await _context.Orders.ToListAsync();
foreach (var order in orders)
{
    Console.WriteLine(order.Customer.Name); // triggers a new SELECT per iteration
}

// GOOD: Include — single JOIN query
var orders = await _context.Orders
    .Include(o => o.Customer)
    .AsNoTracking()
    .ToListAsync();
```
```csharp
// 4. Split queries — avoid cartesian explosion with multiple collection Includes
var orders = await _context.Orders
    .Include(o => o.Items)
    .Include(o => o.Tags)
    .AsSplitQuery()                         // runs 3 separate queries instead of one huge JOIN
    .AsNoTracking()
    .ToListAsync();
```
```csharp
// 5. Compiled queries — eliminates LINQ-to-SQL translation overhead on hot paths
private static readonly Func<AppDbContext, int, Task<Product?>> GetProductById =
    EF.CompileAsyncQuery((AppDbContext ctx, int id) =>
        ctx.Products.AsNoTracking().FirstOrDefault(p => p.Id == id));

// Usage — translation cost paid once, reused every call
var product = await GetProductById(_context, productId);
```
```csharp
// 6. Bulk operations — EF Core 7+ ExecuteUpdateAsync / ExecuteDeleteAsync
// BAD: load all, modify in memory, SaveChanges — O(n) round trips
var expired = await _context.Sessions.Where(s => s.ExpiresAt < DateTime.UtcNow).ToListAsync();
_context.Sessions.RemoveRange(expired);
await _context.SaveChangesAsync();

// GOOD: single DELETE statement, nothing loaded into memory
await _context.Sessions
    .Where(s => s.ExpiresAt < DateTime.UtcNow)
    .ExecuteDeleteAsync();
```

---

## Gotchas
- **`.ToList()` inside a loop is always N+1.** EF doesn't batch automatically. If you're calling any EF query inside a `foreach`, you have N+1 unless you restructured the query to load everything upfront.
- **`Select()` with unmapped computed properties forces client-side evaluation.** If you call a C# method inside a `Select()` that EF can't translate to SQL, it silently loads the full entity set into memory first and evaluates in-process. Check the query log.
- **`AsSplitQuery()` runs in multiple round trips — not a free lunch.** It avoids cartesian explosion but introduces inconsistency risk if data changes between the split queries. Don't use it inside an explicit transaction expecting a consistent snapshot.
- **`Include()` on a filtered child collection doesn't filter in SQL pre-EF 5.** Before EF Core 5, `Include()` always loaded the full child collection. Even in EF 5+, filtered includes have restrictions — they can't be combined with certain projections.
- **Compiled queries break if you change the `DbContextOptions`.** The compiled query captures the model at compile time. If you swap providers in tests (e.g., SQLite vs SQL Server), compiled queries may throw or silently misbehave.

---

## Interview Angle
**What they're really testing:** Whether you understand the boundary between LINQ and SQL — specifically, what EF evaluates server-side vs client-side, and the cost model of the change tracker.

**Common question form:** *"How would you optimize a slow EF Core query?" or "What's an N+1 problem and how do you fix it?"*

**The depth signal:** A junior fixes N+1 with `Include()` and calls it done. A senior knows that `Include()` with multiple collections can produce a cartesian product worse than N+1, reaches for `AsSplitQuery()` or manual projection to a DTO, disables tracking on read paths, uses `ExecuteDeleteAsync`/`ExecuteUpdateAsync` for bulk ops instead of load-modify-save, and knows how to read the EF query log to verify what SQL actually ran.

---

## Related Topics
- [[dotnet/ef-transactions.md]] — `AsSplitQuery()` and transaction isolation interact; split queries inside transactions can read inconsistent state.
- [[dotnet/ef-concurrency.md]] — Over-fetching full entities just to check a concurrency token is a common performance anti-pattern.
- [[databases/indexes.md]] — EF generating the right SQL is only half the story; the query still needs the right index behind it.
- [[dotnet/dbcontext-lifetime.md]] — A long-lived `DbContext` accumulates tracked entities and degrades `SaveChanges()` performance over time.

---

## Source
https://learn.microsoft.com/en-us/ef/core/performance/efficient-querying

---
*Last updated: 2026-03-24*