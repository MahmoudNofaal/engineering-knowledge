# EF Core Change Tracking

> The mechanism by which EF Core remembers the original state of every entity it loads, so it can detect what changed and generate only the minimal SQL needed when you call SaveChanges.

---

## When To Use It

Tracking is on by default and is what you want any time you load an entity, modify it, and call `SaveChangesAsync()` — EF computes the diff and writes only the changed columns. Turn tracking off with `AsNoTracking()` for read-only queries where you're projecting to a DTO or returning data you'll never modify — it's measurably faster because EF skips all snapshot allocation. Don't leave tracking on for bulk read endpoints that serve hundreds of rows to an API response; the overhead accumulates fast and provides no benefit when nothing is being saved.

---

## Core Concept

Every entity loaded through a tracked query gets registered in the `ChangeTracker` with a state — `Unchanged`, `Modified`, `Added`, or `Deleted` — and a snapshot of its original property values. When you call `SaveChangesAsync()`, EF Core compares each tracked entity's current values against the snapshot. Properties that differ get included in an `UPDATE` statement; ones that match are left out. Entities you `Add()` get `INSERT`, ones you `Remove()` get `DELETE`. The key insight is that you never have to tell EF what changed — you just change properties normally and EF figures out the SQL. This is powerful but has a cost: snapshot memory, change detection CPU, and the identity cache mean tracking adds overhead to every query that isn't eventually used for a write.

---

## The Code

**1. How tracking states work**
```csharp
// State: Unchanged — loaded but not yet modified
var product = await context.Products.FindAsync(id);
Console.WriteLine(context.Entry(product).State); // EntityState.Unchanged

// State: Modified — after changing a property
product.Price = 29.99m;
Console.WriteLine(context.Entry(product).State); // EntityState.Modified

// State: Added — after calling Add()
var newProduct = new Product { Name = "Widget", Price = 9.99m };
context.Products.Add(newProduct);
Console.WriteLine(context.Entry(newProduct).State); // EntityState.Added

// State: Deleted — after calling Remove()
context.Products.Remove(product);
Console.WriteLine(context.Entry(product).State); // EntityState.Deleted
```

**2. SaveChanges generates targeted SQL from tracked diffs**
```csharp
var product = await context.Products.FindAsync(id);
// product: { Name = "Widget", Price = 9.99, IsActive = true }

product.Price = 19.99m; // only Price changes

await context.SaveChangesAsync();
// Generated SQL: UPDATE Products SET Price = 19.99 WHERE Id = @id
// NOT: UPDATE Products SET Name = 'Widget', Price = 19.99, IsActive = 1 WHERE Id = @id
// EF only updates the columns that changed
```

**3. AsNoTracking — read-only queries without overhead**
```csharp
// No snapshot created, no change tracker registration
// Faster for large result sets returned as DTOs
var products = await context.Products
    .AsNoTracking()
    .Where(p => p.IsActive)
    .Select(p => new ProductDto { Id = p.Id, Name = p.Name })
    .ToListAsync();

// AsNoTrackingWithIdentityResolution — deduplicates objects in results
// (use when your query joins produce repeated rows for the same entity)
var orders = await context.Orders
    .AsNoTrackingWithIdentityResolution()
    .Include(o => o.Items)
    .ToListAsync();
```

**4. Attaching a detached entity (loaded in a different scope)**
```csharp
// Entity arrived from an API request body or a different DbContext instance
// It's not tracked — EF doesn't know about it yet
public async Task UpdateAsync(Product product)
{
    // Option A: Attach and mark as modified — generates UPDATE for ALL columns
    context.Products.Update(product);
    await context.SaveChangesAsync();

    // Option B: Load → patch → save — generates UPDATE only for changed columns
    var existing = await context.Products.FindAsync(product.Id);
    existing!.Price = product.Price;
    existing.Name   = product.Name;
    await context.SaveChangesAsync(); // EF diffs against original snapshot
}
```

**5. Inspecting and manipulating the ChangeTracker directly**
```csharp
// See everything currently tracked
foreach (var entry in context.ChangeTracker.Entries())
{
    Console.WriteLine($"{entry.Entity.GetType().Name}: {entry.State}");
}

// Detach a specific entity — stops tracking without deleting
context.Entry(product).State = EntityState.Detached;

// Clear all tracked entities — useful in long-running batch jobs
context.ChangeTracker.Clear();

// Force EF to re-detect changes (runs automatically before SaveChanges,
// but can be called manually if you've mutated entities in bulk)
context.ChangeTracker.DetectChanges();
```

**6. Auditing with ChangeTracker — set timestamps automatically before save**
```csharp
// Override SaveChangesAsync in your DbContext
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
```

---

## Gotchas

- **`context.Products.Update(entity)` marks every property as modified — not just the ones that changed.** When you attach a detached entity with `Update()`, EF has no original snapshot to diff against, so it marks all columns dirty and generates an `UPDATE` that writes every column. If another process changed a different column on the same row between your read and write, you overwrite it. Load the entity first, patch specific properties, then `SaveChangesAsync()` to get a column-targeted update.
- **The identity cache means `FindAsync(id)` can return a stale entity.** If you load `Product 42` earlier in the same request scope, a subsequent `FindAsync(42)` returns the cached instance without touching the database — even if the row was updated by another request. For freshness-sensitive reads, use `FirstOrDefaultAsync(p => p.Id == id)` to always hit the database, or reload the entity with `await context.Entry(product).ReloadAsync()`.
- **Tracking a large number of entities in a long-running scope grows memory unboundedly.** A batch job that processes 50,000 rows in a loop inside a single `DbContext` instance accumulates 50,000 tracked snapshots. Call `context.ChangeTracker.Clear()` after each batch, or use `AsNoTracking()` with explicit insert/update logic, or create a new `DbContext` per batch via `IDbContextFactory<T>`.
- **`AsNoTracking` entities cannot be used with `Update()` or `Remove()` without re-attaching.** If you load an entity with `AsNoTracking()` and then call `context.Remove(entity)`, EF throws `InvalidOperationException` because the entity is not tracked. Either load it as tracked, or attach it first with `context.Attach(entity)` before removing.
- **`DetectChanges()` runs automatically before every `SaveChangesAsync()` — calling it manually in a loop is quadratic cost.** EF's auto-detection scans every tracked entity. Inside a loop that adds entities and calls `DetectChanges()` manually, you re-scan all previously added entities on every iteration. Disable auto-detection with `context.ChangeTracker.AutoDetectChangesEnabled = false` during bulk operations and call it once at the end.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between tracked and untracked entities, the performance implications of each, and the specific bugs that arise when you bypass the change tracker with `Update()`.

**Common question form:** *"What is the EF Core change tracker and how does it work?"* or *"When would you use AsNoTracking and what are the trade-offs?"*

**The depth signal:** A junior answer says `AsNoTracking` is faster for reads and the change tracker generates SQL on `SaveChanges`. A senior answer explains that `Update()` on a detached entity marks all columns dirty (causing full-column `UPDATE` and concurrency risk), why `FindAsync` hits the identity cache and can return stale data, the quadratic cost of calling `DetectChanges()` inside a loop, why long-running scopes accumulate tracking memory and how `ChangeTracker.Clear()` or `IDbContextFactory` solves it, and how to use the `ChangeTracker.Entries()` loop in `SaveChangesAsync` for cross-cutting audit stamps without touching every service.

---

## Related Topics

- [[dotnet/ef-dbcontext.md]] — The `DbContext` hosts the `ChangeTracker`; understanding context lifetime (scoped vs singleton) explains why tracking state accumulates and when it resets.
- [[dotnet/ef-queries.md]] — `AsNoTracking` and `AsNoTrackingWithIdentityResolution` are query-level opt-outs from tracking; query design and tracking decisions are tightly coupled.
- [[dotnet/ef-relationships.md]] — Navigation properties on tracked entities are populated and maintained by the change tracker; understanding tracking explains why accessing an unloaded navigation on a tracked entity returns null instead of fetching from the database.
- [[dotnet/ef-code-first.md]] — `SaveChangesAsync` is where change tracking produces its SQL output; understanding Code First migrations explains what schema those INSERT/UPDATE/DELETE statements target.

---

## Source

https://learn.microsoft.com/en-us/ef/core/change-tracking

---
*Last updated: 2026-03-24*