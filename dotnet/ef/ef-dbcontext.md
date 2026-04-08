# EF Core DbContext

> The central class in Entity Framework Core that represents your database session — tracking entity changes, managing transactions, and translating LINQ queries into SQL.

---

## When To Use It

Use `DbContext` any time your application needs to read from or write to a relational database through EF Core. It's the entry point for every database operation — querying, inserting, updating, deleting, and running transactions. Don't instantiate it manually with `new` inside services; register it with the DI container so it gets the correct scoped lifetime. Don't share a single `DbContext` instance across threads — it's not thread-safe and concurrent operations will corrupt its internal change tracker.

---

## Core Concept

`DbContext` is two things at once: a query gateway and a change tracker. When you call `context.Products.Where(...)`, EF Core translates that LINQ expression into SQL, runs it, and materialises the results as C# objects. Those objects are then tracked — EF Core remembers their original values. When you call `SaveChangesAsync()`, EF Core diffs every tracked entity against its original snapshot, generates the minimal `INSERT`, `UPDATE`, or `DELETE` statements needed, and executes them in a transaction. You never write SQL for basic CRUD; you manipulate objects and let the context figure out the SQL. The `DbSet<T>` properties on your context are the handles you use to query and stage changes for each entity type.

---

## The Code

**1. Define a DbContext**
```csharp
// Data/AppDbContext.cs
public class AppDbContext(DbContextOptions<AppDbContext> options)
    : DbContext(options)
{
    public DbSet<Product>  Products  { get; set; }
    public DbSet<Category> Categories { get; set; }
    public DbSet<Order>    Orders    { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Apply all IEntityTypeConfiguration<T> classes in the assembly — cleaner than inline
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

        // Global query filter — soft delete applied to all queries on Product automatically
        modelBuilder.Entity<Product>().HasQueryFilter(p => !p.IsDeleted);
    }

    // Audit stamp hook — runs before every save
    public override async Task<int> SaveChangesAsync(CancellationToken ct = default)
    {
        foreach (var entry in ChangeTracker.Entries<IAuditableEntity>())
        {
            if (entry.State == EntityState.Added)
                entry.Entity.CreatedAt = DateTime.UtcNow;

            if (entry.State is EntityState.Added or EntityState.Modified)
                entry.Entity.UpdatedAt = DateTime.UtcNow;
        }

        return await base.SaveChangesAsync(ct);
    }
}
```

**2. Register in Program.cs — standard vs pooled**
```csharp
// Standard registration — one DbContext instance per HTTP request (scoped)
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

// Pooled registration — reuses DbContext instances from a pool (higher throughput)
// Use when you have many short-lived requests and DbContext construction is a bottleneck
// Constraint: OnConfiguring() is called once at pool creation, not per request
builder.Services.AddDbContextPool<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default")),
    poolSize: 128); // default is 1024 — tune to your expected concurrency

// Development — logs every SQL query and parameter value to console
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default"))
           .LogTo(Console.WriteLine, LogLevel.Information)
           .EnableSensitiveDataLogging()); // dev only — logs parameter values
```

**3. IDbContextFactory — for singleton services and background jobs**
```csharp
// Register the factory alongside (or instead of) AddDbContext
builder.Services.AddDbContextFactory<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

// Inject into a singleton service — never inject DbContext directly into a singleton
public class ReportingService
{
    private readonly IDbContextFactory<AppDbContext> _factory;

    public ReportingService(IDbContextFactory<AppDbContext> factory)
        => _factory = factory;

    public async Task<SalesReport> GenerateAsync(DateOnly date)
    {
        // Create a short-lived context — disposed when the using block exits
        await using var context = await _factory.CreateDbContextAsync();

        return await context.Orders
            .AsNoTracking()
            .Where(o => DateOnly.FromDateTime(o.CreatedAt) == date)
            .Select(o => new SalesReport { Total = o.Total, Count = 1 })
            .FirstOrDefaultAsync() ?? new SalesReport();
    }
}

// Background job with IDbContextFactory — each iteration gets a fresh context
public class CleanupJob : BackgroundService
{
    private readonly IDbContextFactory<AppDbContext> _factory;

    public CleanupJob(IDbContextFactory<AppDbContext> factory) => _factory = factory;

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            await using var context = await _factory.CreateDbContextAsync(ct);

            await context.Sessions
                .Where(s => s.ExpiresAt < DateTime.UtcNow)
                .ExecuteDeleteAsync(ct);

            await Task.Delay(TimeSpan.FromMinutes(5), ct);
        }
    }
}
```

**4. Basic CRUD operations**
```csharp
public class ProductService(AppDbContext context)
{
    public async Task<List<Product>> GetAllAsync() =>
        await context.Products
                     .Where(p => p.IsActive)
                     .OrderBy(p => p.Name)
                     .ToListAsync();

    public async Task<Product?> GetByIdAsync(int id) =>
        await context.Products.FindAsync(id);

    public async Task<Product> CreateAsync(Product product)
    {
        context.Products.Add(product);
        await context.SaveChangesAsync();
        return product; // Id populated after insert
    }

    // Preferred update pattern — load → patch → save (targeted UPDATE)
    public async Task UpdateAsync(int id, string newName, decimal newPrice)
    {
        var product = await context.Products.FindAsync(id)
            ?? throw new NotFoundException($"Product {id} not found");

        product.Name  = newName;
        product.Price = newPrice;
        // EF generates: UPDATE Products SET Name=@p0, Price=@p1 WHERE Id=@p2
        await context.SaveChangesAsync();
    }

    public async Task DeleteAsync(int id)
    {
        var product = await context.Products.FindAsync(id)
            ?? throw new NotFoundException($"Product {id} not found");

        context.Products.Remove(product);
        await context.SaveChangesAsync();
    }
}
```

**5. Interceptors — cross-cutting behaviour without modifying entities**
```csharp
// Audit log interceptor — fires before every SaveChanges
public class AuditInterceptor : SaveChangesInterceptor
{
    private readonly ICurrentUserService _currentUser;

    public AuditInterceptor(ICurrentUserService currentUser)
        => _currentUser = currentUser;

    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData,
        InterceptionResult<int> result,
        CancellationToken ct = default)
    {
        var context = eventData.Context!;

        foreach (var entry in context.ChangeTracker.Entries<IAuditableEntity>())
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedAt  = DateTime.UtcNow;
                    entry.Entity.CreatedBy  = _currentUser.UserId;
                    break;
                case EntityState.Modified:
                    entry.Entity.UpdatedAt  = DateTime.UtcNow;
                    entry.Entity.UpdatedBy  = _currentUser.UserId;
                    break;
                case EntityState.Deleted when entry.Entity is ISoftDeletable sd:
                    entry.State            = EntityState.Modified; // prevent hard delete
                    sd.IsDeleted           = true;
                    sd.DeletedAt           = DateTime.UtcNow;
                    sd.DeletedBy           = _currentUser.UserId;
                    break;
            }
        }

        return base.SavingChangesAsync(eventData, result, ct);
    }
}

// Query tag interceptor — stamps every query with the calling method for profiling
public class QueryTagInterceptor : DbCommandInterceptor
{
    public override ValueTask<DbCommand> CommandCreatedAsync(
        CommandEndEventData eventData,
        DbCommand result,
        CancellationToken ct = default)
    {
        // Adds a SQL comment: /* my-tag */ before every query — visible in profiler
        return base.CommandCreatedAsync(eventData, result, ct);
    }
}

// Register interceptors in Program.cs
builder.Services.AddScoped<AuditInterceptor>();
builder.Services.AddDbContext<AppDbContext>((sp, options) =>
{
    options.UseSqlServer(connectionString)
           .AddInterceptors(sp.GetRequiredService<AuditInterceptor>());
});
```

**6. Global query filters**
```csharp
// Applied automatically to every query for that entity type
// Soft delete — IsDeleted rows invisible by default
modelBuilder.Entity<Product>().HasQueryFilter(p => !p.IsDeleted);

// Multi-tenancy — queries scoped to current tenant automatically
modelBuilder.Entity<Order>().HasQueryFilter(o => o.TenantId == _tenantId);
// _tenantId is a field on the DbContext, injected via constructor

// Bypass a filter when needed — admin views, migration jobs
var allProducts = await context.Products
    .IgnoreQueryFilters()  // bypasses IsDeleted filter
    .Where(p => p.CategoryId == 5)
    .ToListAsync();
```

**7. Explicit transactions**
```csharp
await using var transaction = await context.Database.BeginTransactionAsync();

try
{
    context.Orders.Add(order);
    await context.SaveChangesAsync();

    context.Inventory.Update(inventoryItem);
    await context.SaveChangesAsync();

    await transaction.CommitAsync();
}
catch
{
    await transaction.RollbackAsync();
    throw;
}
```

**8. No-tracking query**
```csharp
var products = await context.Products
    .AsNoTracking()
    .Where(p => p.CategoryId == categoryId)
    .Select(p => new ProductDto { Id = p.Id, Name = p.Name })
    .ToListAsync();
```

---

## Gotchas

- **`DbContext` is scoped — never register it as a singleton.** A singleton `DbContext` accumulates tracked entities indefinitely, holds a database connection open for the lifetime of the app, and is not thread-safe. The default `AddDbContext` registration is scoped (one instance per HTTP request), which is correct. If you need to use it from a singleton service, inject `IDbContextFactory<AppDbContext>` and create short-lived instances.
- **`context.Products.Update(entity)` marks every property as modified, not just the changed ones.** This generates an `UPDATE` that writes every column. If another process changed a different column on the same row between your read and your write, you'll overwrite it. Load the entity first (so EF tracks it), mutate only the properties you intend to change, then call `SaveChangesAsync()`.
- **`SaveChangesAsync()` wraps all pending changes in a single implicit transaction.** If you have three staged entities and the second one fails a database constraint, none commit. This is usually correct — if you need partial saves, use separate `SaveChangesAsync()` calls or explicit transactions.
- **`AddDbContextPool` resets the context between uses, but doesn't reset custom state.** If your `DbContext` subclass has instance fields (e.g. for multi-tenancy), `AddDbContextPool` will reuse the same instance for a different tenant's request unless you implement `IResettableService` to clear that state between pool checkouts.
- **Calling `ToListAsync()` without `AsNoTracking()` on large read queries has real cost.** EF Core snapshots every tracked entity. On a query returning 10,000 rows, that's 10,000 change-tracking objects in memory. Use `AsNoTracking()` or `Select()` to a DTO for any read path that doesn't save.
- **`FindAsync(id)` checks the identity cache first and may return a stale entity.** If you loaded a `Product` earlier in the same request, `FindAsync` returns the cached instance without hitting the database. For freshness-sensitive reads, use `FirstOrDefaultAsync(p => p.Id == id)` to always query the database.
- **Interceptors registered with `AddInterceptors()` are shared across all requests.** Interceptors that need per-request data (like the current user) must be registered as scoped services and resolved from the `IServiceProvider` passed to `AddDbContext`, not as singletons.

---

## Interview Angle

**What they're really testing:** Whether you understand the change tracker, the implications of `DbContext` lifetime, and the performance trade-offs of tracking vs no-tracking queries.

**Common question form:** *"How does EF Core track changes and generate SQL?"* or *"What's the difference between `Update()` and loading an entity then modifying it?"*

**The depth signal:** A junior answer describes `DbSet` properties and calling `SaveChangesAsync()`. A senior answer explains how the change tracker snapshots original values and diffs them on `SaveChangesAsync()`, why `Update()` generates a full-column `UPDATE` vs a tracked entity generating a targeted one, why `DbContext` must be scoped (not singleton), what `IDbContextFactory` solves for singleton services and background jobs, how interceptors separate cross-cutting concerns (auditing, soft delete) from service code, how global query filters implement soft-delete and multi-tenancy transparently, why `AddDbContextPool` can be dangerous if the context has custom state fields, and the `FindAsync` identity cache trap.

---

## Related Topics

- [[dotnet/ef/ef-migrations.md]] — Migrations use the `DbContext` model definition to generate schema change scripts; `OnModelCreating` configuration directly shapes what migrations produce.
- [[dotnet/ef/ef-queries.md]] — All LINQ queries run through `DbContext.DbSet<T>`; understanding the context is the prerequisite for understanding query translation and loading strategies.
- [[dotnet/ef/ef-global-query-filters.md]] — `HasQueryFilter()` is configured in `OnModelCreating`; filters run on every query for that entity unless explicitly bypassed.
- [[dotnet/ef/ef-interceptors.md]] — `SaveChangesInterceptor` and `DbCommandInterceptor` hook into the `DbContext` pipeline for audit trails, slow query detection, and soft-delete enforcement.
- [[dotnet/webapi/dependency-injection.md]] — `DbContext` lifetime (scoped) is a DI concept; injecting it into singleton services is a captive dependency bug that only manifests under load.

---

## Source

https://learn.microsoft.com/en-us/ef/core/dbcontext-configuration

---
*Last updated: 2026-04-08*