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
        // Fluent API config — preferred over data annotations for non-trivial mappings
        modelBuilder.Entity<Product>(entity =>
        {
            entity.HasKey(p => p.Id);
            entity.Property(p => p.Name).IsRequired().HasMaxLength(200);
            entity.Property(p => p.Price).HasColumnType("decimal(18,2)");

            entity.HasOne(p => p.Category)
                  .WithMany(c => c.Products)
                  .HasForeignKey(p => p.CategoryId)
                  .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
```

**2. Register in Program.cs**
```csharp
// Program.cs
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

// For development — logs every SQL query to the console
// Never use in production; it's very chatty
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default"))
           .LogTo(Console.WriteLine, LogLevel.Information)
           .EnableSensitiveDataLogging()); // shows parameter values — dev only
```

**3. Basic CRUD operations**
```csharp
// Services/ProductService.cs
public class ProductService(AppDbContext context)
{
    // Query
    public async Task<List<Product>> GetAllAsync() =>
        await context.Products
                     .Where(p => p.IsActive)
                     .OrderBy(p => p.Name)
                     .ToListAsync();

    // Find by primary key — hits the identity cache first, then database
    public async Task<Product?> GetByIdAsync(int id) =>
        await context.Products.FindAsync(id);

    // Insert
    public async Task<Product> CreateAsync(Product product)
    {
        context.Products.Add(product); // stages the INSERT
        await context.SaveChangesAsync(); // executes it
        return product; // Id is populated by EF after insert
    }

    // Update
    public async Task UpdateAsync(Product product)
    {
        // If tracked: just call SaveChanges — EF detects the diff
        // If detached (loaded in a different scope): attach and mark modified
        context.Products.Update(product); // marks ALL properties as modified
        await context.SaveChangesAsync();
    }

    // Delete
    public async Task DeleteAsync(int id)
    {
        var product = await context.Products.FindAsync(id)
            ?? throw new NotFoundException($"Product {id} not found");

        context.Products.Remove(product);
        await context.SaveChangesAsync();
    }
}
```

**4. Explicit transactions**
```csharp
// Use when multiple SaveChanges calls must succeed or fail together
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

**5. No-tracking query (read-only — faster, no change tracking overhead)**
```csharp
// Use AsNoTracking when you don't need to update the results
var products = await context.Products
    .AsNoTracking()
    .Where(p => p.CategoryId == categoryId)
    .Select(p => new ProductDto { Id = p.Id, Name = p.Name })
    .ToListAsync();
```

---

## Gotchas

- **`DbContext` is scoped — never register it as a singleton.** A singleton `DbContext` accumulates tracked entities indefinitely, holds a database connection open for the lifetime of the app, and is not thread-safe. The default `AddDbContext` registration is scoped (one instance per HTTP request), which is correct. If you need to use it from a singleton service, inject `IDbContextFactory<AppDbContext>` instead and create short-lived instances manually.
- **`context.Products.Update(entity)` marks every property as modified, not just the changed ones.** This generates an `UPDATE` statement that writes every column, even unchanged ones. If another process updated a different column on the same row between your read and your write, you'll overwrite it. For partial updates, load the entity first (so EF tracks it), mutate only the properties you intend to change, then call `SaveChangesAsync()` — EF will generate a targeted `UPDATE` for only the changed columns.
- **`SaveChangesAsync()` wraps all pending changes in a single implicit transaction.** If you have three entities staged for insert and the second one fails a database constraint, none of the three are committed. This is usually the behaviour you want, but if you intentionally need partial saves you need separate `SaveChangesAsync()` calls or explicit transactions.
- **Calling `ToListAsync()` without `AsNoTracking()` on large read queries has real memory and CPU cost.** EF Core snapshots every tracked entity's original property values for change detection. On a query returning 10,000 rows, that's 10,000 change-tracking objects allocated. Use `AsNoTracking()` or project to a DTO with `Select()` for any query where you don't need to update the results.
- **`FindAsync(id)` checks the identity cache first and may return a stale entity.** If you loaded a `Product` earlier in the same request, `FindAsync` returns the cached instance without hitting the database — even if the row was updated by another process in the meantime. For scenarios where freshness matters, use `FirstOrDefaultAsync(p => p.Id == id)` to always go to the database.

---

## Interview Angle

**What they're really testing:** Whether you understand the change tracker, the implications of `DbContext` lifetime, and the performance trade-offs of tracking vs no-tracking queries.

**Common question form:** *"How does EF Core track changes and generate SQL?"* or *"What's the difference between `Update()` and loading an entity then modifying it?"*

**The depth signal:** A junior answer describes `DbSet` properties and calling `SaveChangesAsync()`. A senior answer explains how the change tracker snapshots original values and diffs them on `SaveChangesAsync()`, why `Update()` generates a full-column `UPDATE` vs a tracked entity generating a targeted one, why `DbContext` must be scoped (not singleton) and what `IDbContextFactory` solves for singleton services, the `AsNoTracking()` performance win for read-only queries and why it matters at scale, and the `FindAsync` identity cache trap where stale data can be returned without a database round-trip.

---

## Related Topics

- [[dotnet/ef-migrations.md]] — Migrations use the `DbContext` model definition to generate schema change scripts; `OnModelCreating` configuration directly shapes what migrations produce.
- [[dotnet/ef-querying.md]] — All LINQ queries run through `DbContext.DbSet<T>`; understanding the context is the prerequisite for understanding query translation and loading strategies.
- [[dotnet/dependency-injection.md]] — `DbContext` lifetime (scoped) is a DI concept; injecting it into singleton services is a captive dependency bug that only manifests under load.
- [[dotnet/webapi-exception-handling.md]] — Database constraint violations surface as `DbUpdateException` from `SaveChangesAsync()`; the global exception handler maps these to 409 Conflict or 400 Bad Request responses.

---

## Source

https://learn.microsoft.com/en-us/ef/core/dbcontext-configuration

---
*Last updated: 2026-03-24*