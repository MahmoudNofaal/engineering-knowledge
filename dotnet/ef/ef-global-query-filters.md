# EF Core Global Query Filters

> Predicates configured in `OnModelCreating` that EF Core automatically appends to every LINQ query for a given entity type — invisible to query call sites, enforced at the infrastructure level.

---

## When To Use It

Use global query filters for behaviours that must apply to every query without exception by default — soft delete (`IsDeleted = 0`), multi-tenancy (`TenantId = @currentTenant`), and row-level access control. They're the right tool when the filter is a cross-cutting concern that every developer would otherwise need to remember to apply manually. Don't use them for business-logic filtering that legitimately varies per query (status-based filtering, date ranges, user preferences) — those belong in explicit `Where()` clauses where the intent is visible. Don't stack more than two or three filters on a single entity — the implicit behaviour becomes hard to reason about.

---

## Core Concept

`HasQueryFilter()` is called in `OnModelCreating` and registers a LINQ expression that EF Core appends to every query for that entity type as an additional `WHERE` clause. The filter runs at the SQL level — it's not applied in memory. Filters on navigation properties (via `Include()`) are also applied — if `OrderItem` has a soft-delete filter, included `OrderItems` will also exclude soft-deleted rows. The escape hatch is `IgnoreQueryFilters()` on a per-query basis, which removes all filters for that query. You can make filters dynamic by reading instance state from the `DbContext` — injecting a tenant provider into the context and referencing a field from it.

---

## The Code

**1. Soft delete filter — the most common use case**
```csharp
// Entity interface
public interface ISoftDeletable
{
    bool      IsDeleted { get; set; }
    DateTime? DeletedAt { get; set; }
}

public class Product : ISoftDeletable
{
    public int    Id        { get; set; }
    public string Name      { get; set; } = string.Empty;
    public bool   IsDeleted { get; set; }
    public DateTime? DeletedAt { get; set; }
}

// In OnModelCreating — filter applies to every Product query automatically
modelBuilder.Entity<Product>().HasQueryFilter(p => !p.IsDeleted);

// Now this query silently adds WHERE IsDeleted = 0:
var activeProducts = await context.Products.ToListAsync();
// Generated: SELECT * FROM Products WHERE IsDeleted = 0

// And this Include also filters:
var orders = await context.Orders
    .Include(o => o.Items) // Items with IsDeleted = 1 are excluded from the Include
    .ToListAsync();
```

**2. Applying filters to all soft-deletable entities at once**
```csharp
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    // Apply soft-delete filter to every entity that implements ISoftDeletable
    foreach (var entityType in modelBuilder.Model.GetEntityTypes())
    {
        if (typeof(ISoftDeletable).IsAssignableFrom(entityType.ClrType))
        {
            var parameter = Expression.Parameter(entityType.ClrType, "e");
            var property  = Expression.Property(parameter, nameof(ISoftDeletable.IsDeleted));
            var notDeleted = Expression.Not(property);
            var lambda    = Expression.Lambda(notDeleted, parameter);

            modelBuilder.Entity(entityType.ClrType).HasQueryFilter(lambda);
        }
    }
}
```

**3. Multi-tenancy filter — tenant-scoped data access**
```csharp
// DbContext holds the current tenant ID — injected via a scoped service
public class AppDbContext : DbContext
{
    private readonly ITenantService _tenantService;

    public AppDbContext(DbContextOptions<AppDbContext> options, ITenantService tenantService)
        : base(options)
    {
        _tenantService = tenantService;
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Filter references the DbContext field — evaluated per query
        modelBuilder.Entity<Order>().HasQueryFilter(
            o => o.TenantId == _tenantService.CurrentTenantId);

        modelBuilder.Entity<Product>().HasQueryFilter(
            p => p.TenantId == _tenantService.CurrentTenantId);
    }
}

// Every query is now tenant-scoped automatically
var orders = await context.Orders.ToListAsync();
// Generated: SELECT * FROM Orders WHERE TenantId = @tenantId

// No developer can accidentally query across tenants unless they explicitly bypass the filter
```

**4. Combining soft delete + multi-tenancy**
```csharp
modelBuilder.Entity<Order>().HasQueryFilter(
    o => !o.IsDeleted && o.TenantId == _tenantService.CurrentTenantId);
// Generated: WHERE IsDeleted = 0 AND TenantId = @tenantId
```

**5. Bypassing filters — IgnoreQueryFilters()**
```csharp
// Admin view — show all products including soft-deleted
var allProducts = await context.Products
    .IgnoreQueryFilters()
    .ToListAsync();

// Cross-tenant admin query
var allOrders = await context.Orders
    .IgnoreQueryFilters()
    .Where(o => o.CreatedAt >= DateTime.UtcNow.AddDays(-30))
    .ToListAsync();

// IgnoreQueryFilters removes ALL filters for that entity in that query
// There's no way to remove only one filter — all or nothing per query
```

**6. Filters on navigation properties via Include**
```csharp
// If OrderItem has a soft-delete filter, included items respect the filter automatically
var orders = await context.Orders
    .Include(o => o.Items) // soft-deleted Items are excluded from the result
    .ToListAsync();

// To include soft-deleted items too:
var orders = await context.Orders
    .Include(o => o.Items)
    .IgnoreQueryFilters()   // bypasses both Order and OrderItem filters
    .ToListAsync();

// EF Core 7+ filtered include — combine explicit filter + global filter bypass:
var orders = await context.Orders
    .Include(o => o.Items.IgnoreQueryFilters()) // bypass filter only on the Include nav
    .ToListAsync();
// Note: IgnoreQueryFilters inside Include is EF Core 8+ only
```

**7. Verifying filter SQL with ToQueryString**
```csharp
// Always verify what SQL the filter generates — especially for complex expressions
var query = context.Products.Where(p => p.Price > 10);
Console.WriteLine(query.ToQueryString());
// Output: SELECT * FROM Products WHERE IsDeleted = 0 AND Price > 10
// Both the explicit Where and the global filter appear in the SQL
```

---

## Gotchas

- **`IgnoreQueryFilters()` removes ALL filters for that entity type — not just one.** There's no API to bypass a single filter and keep others. If you have both a soft-delete and a tenant filter, `IgnoreQueryFilters()` removes both. Design your admin queries accordingly, and be explicit in code reviews about why `IgnoreQueryFilters` appears.
- **Filters on navigation properties are applied at the SQL level — they run even when you don't `Include()`.** If `OrderItem` has a soft-delete filter and you access `order.Items` after loading via a lazy load or explicit load, the filter still applies. Soft-deleted items are never returned regardless of how you load the navigation.
- **Dynamic filters referencing DbContext fields require the field to be non-null at query time.** If `_tenantService.CurrentTenantId` is `null` when a query runs (e.g., in a background job with no HTTP context), EF generates `WHERE TenantId IS NULL` — which returns no rows for most real tenants. Add a null check or bypass the filter for background jobs: `context.Products.IgnoreQueryFilters().Where(...)`.
- **Filters interact with migrations — they don't affect the schema, only queries.** A soft-delete filter doesn't create an `IsDeleted` column — you still need the property and column in your entity. The filter just ensures the column is used in every query.
- **Owned types inherit query filters from their owner but can't have independent filters.** If `Order` has a soft-delete filter and `OrderAddress` is owned by `Order`, the filter applies when loading orders (and their addresses). You can't configure a separate filter on `OrderAddress` directly.
- **Query filters slow down every query by adding a WHERE clause.** For tables with millions of rows, always ensure the filtered column (`IsDeleted`, `TenantId`) is indexed — either individually or as part of a composite index with the most common query columns. Without an index, EF generates a full table scan with a filter applied in the storage engine.

---

## Interview Angle

**What they're really testing:** Whether you understand how to implement cross-cutting data access concerns without polluting every query call site — specifically soft delete and multi-tenancy — and the trade-offs of implicit vs explicit filtering.

**Common question form:** *"How would you implement soft delete in EF Core?"* or *"How do you implement multi-tenancy in EF Core?"*

**The depth signal:** A junior adds `Where(!p.IsDeleted)` to every query. A senior configures `HasQueryFilter()` in `OnModelCreating` so the filter is enforced at the infrastructure level, explains that the filter applies to `Include()` navigations too, knows the `IgnoreQueryFilters()` escape hatch and its all-or-nothing behaviour, explains the dynamic filter pattern for multi-tenancy (DbContext field referencing a scoped tenant service), pairs the read-side filter with a write-side `SaveChangesInterceptor` that converts `Remove()` to a flag update, and knows to index the filter column for performance on large tables.

---

## Related Topics

- [[dotnet/ef/ef-dbcontext.md]] — `HasQueryFilter()` is configured in `OnModelCreating`; the context is the host for all filter configuration.
- [[dotnet/ef/ef-interceptors.md]] — Write-side soft delete (converting `Remove()` to a flag update) is handled by a `SaveChangesInterceptor`; filters handle the read side. Both are needed for a complete soft-delete implementation.
- [[dotnet/ef/ef-queries.md]] — `IgnoreQueryFilters()` is a per-query modifier; `ToQueryString()` is how you verify the filter SQL is applied correctly.
- [[dotnet/ef/ef-migrations.md]] — Filters don't affect the schema; the `IsDeleted` or `TenantId` column must exist via a migration before the filter can reference it.

---

## Source

https://learn.microsoft.com/en-us/ef/core/querying/filters

---
*Last updated: 2026-04-08*