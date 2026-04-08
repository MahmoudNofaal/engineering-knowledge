# EF Core Change Tracking

> The mechanism by which EF Core remembers the original state of every entity it loads, so it can detect what changed and generate only the minimal SQL needed when you call SaveChanges.

---

## When To Use It

Tracking is on by default and is what you want any time you load an entity, modify it, and call `SaveChangesAsync()` — EF computes the diff and writes only the changed columns. Turn tracking off with `AsNoTracking()` for read-only queries where you're projecting to a DTO or returning data you'll never modify — it's measurably faster. Don't leave tracking on for bulk read endpoints that serve hundreds of rows; the overhead accumulates fast and provides no benefit when nothing is being saved.

---

## Core Concept

Every entity loaded through a tracked query gets registered in the `ChangeTracker` with a state — `Unchanged`, `Modified`, `Added`, or `Deleted` — and a snapshot of its original property values. When you call `SaveChangesAsync()`, EF Core compares each tracked entity's current values against the snapshot. Properties that differ get included in an `UPDATE`; ones that match are left out. Entities you `Add()` get `INSERT`, ones you `Remove()` get `DELETE`. The key insight is that you never have to tell EF what changed — you just change properties normally and EF figures out the SQL. This is powerful but has a cost: snapshot memory, change detection CPU, and the identity cache mean tracking adds overhead to every query that isn't eventually used for a write.

---

## The Code

**1. How tracking states work**
```csharp
var product = await context.Products.FindAsync(id);
Console.WriteLine(context.Entry(product).State); // EntityState.Unchanged

product.Price = 29.99m;
Console.WriteLine(context.Entry(product).State); // EntityState.Modified

var newProduct = new Product { Name = "Widget", Price = 9.99m };
context.Products.Add(newProduct);
Console.WriteLine(context.Entry(newProduct).State); // EntityState.Added

context.Products.Remove(product);
Console.WriteLine(context.Entry(product).State); // EntityState.Deleted
```

**2. SaveChanges generates targeted SQL from diffs**
```csharp
var product = await context.Products.FindAsync(id);
product.Price = 19.99m; // only Price changes

await context.SaveChangesAsync();
// Generated: UPDATE Products SET Price = 19.99 WHERE Id = @id
// NOT: UPDATE Products SET Name = 'Widget', Price = 19.99, IsActive = 1 WHERE Id = @id
```

**3. AsNoTracking — read-only queries**
```csharp
var products = await context.Products
    .AsNoTracking()
    .Where(p => p.IsActive)
    .Select(p => new ProductDto { Id = p.Id, Name = p.Name })
    .ToListAsync();

// AsNoTrackingWithIdentityResolution — deduplicates when the same entity appears
// multiple times in JOIN results (e.g. same Customer referenced by multiple Orders)
var orders = await context.Orders
    .AsNoTrackingWithIdentityResolution()
    .Include(o => o.Customer)
    .ToListAsync();
```

**4. Attaching a detached entity**
```csharp
// Entity arrived from an API request body — not tracked by any context
public async Task UpdateAsync(Product product)
{
    // Option A: Attach + Update — marks ALL properties Modified, full-column UPDATE
    context.Products.Update(product);
    await context.SaveChangesAsync();

    // Option B: Load → patch → save — targeted UPDATE for only changed columns
    var existing = await context.Products.FindAsync(product.Id);
    existing!.Price = product.Price;
    existing.Name   = product.Name;
    await context.SaveChangesAsync(); // EF diffs against original snapshot
}
```

**5. Disconnected entity graph — reattaching a complex object tree from an API**
```csharp
// Incoming DTO contains an Order with its Items — need to apply changes intelligently
public async Task UpdateOrderAsync(Order incomingOrder)
{
    var existingOrder = await context.Orders
        .Include(o => o.Items)
        .FirstAsync(o => o.Id == incomingOrder.Id);

    // Update the root
    context.Entry(existingOrder).CurrentValues.SetValues(incomingOrder);

    // Handle Items — added, updated, or removed
    foreach (var incomingItem in incomingOrder.Items)
    {
        var existingItem = existingOrder.Items
            .FirstOrDefault(i => i.Id == incomingItem.Id);

        if (existingItem == null)
        {
            existingOrder.Items.Add(incomingItem); // Added — EF marks as EntityState.Added
        }
        else
        {
            context.Entry(existingItem).CurrentValues.SetValues(incomingItem); // Modified
        }
    }

    // Delete items that are no longer in the incoming list
    foreach (var existingItem in existingOrder.Items.ToList())
    {
        if (!incomingOrder.Items.Any(i => i.Id == existingItem.Id))
            context.Remove(existingItem); // EntityState.Deleted
    }

    await context.SaveChangesAsync(); // generates targeted INSERTs, UPDATEs, DELETEs
}
```

**6. TrackGraph — for complex detached graphs you can't load first**
```csharp
// TrackGraph lets you walk an entire object graph and set each entity's state manually
// Useful for import scenarios where you've built an object tree and need to persist it

context.ChangeTracker.TrackGraph(order, node =>
{
    var entity = node.Entry.Entity;

    if (entity is ITrackable trackable)
    {
        // Apply state based on your own convention or DTO flag
        node.Entry.State = trackable.IsNew
            ? EntityState.Added
            : EntityState.Modified;
    }
    else
    {
        node.Entry.State = EntityState.Unchanged; // default for unknown types
    }
});

await context.SaveChangesAsync();
```

**7. Inspecting and manipulating the ChangeTracker**
```csharp
// See everything currently tracked
foreach (var entry in context.ChangeTracker.Entries())
    Console.WriteLine($"{entry.Entity.GetType().Name}: {entry.State}");

// Detach a specific entity — stops tracking without deleting
context.Entry(product).State = EntityState.Detached;

// Clear all tracked entities — critical for long-running batch jobs
context.ChangeTracker.Clear();

// Disable auto-detect during bulk operations (it runs before every SaveChanges)
context.ChangeTracker.AutoDetectChangesEnabled = false;
// Add 10,000 entities in a loop...
context.ChangeTracker.AutoDetectChangesEnabled = true;
context.ChangeTracker.DetectChanges(); // run once at the end
await context.SaveChangesAsync();
```

**8. Auditing with ChangeTracker — via SaveChangesAsync override**
```csharp
// In DbContext — stamp timestamps before every save, no service-layer code needed
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

// Cleaner alternative: use a SaveChangesInterceptor (see ef-interceptors.md)
// Interceptors are testable in isolation and don't require subclassing DbContext
```

**9. Identity cache — FindAsync vs FirstOrDefaultAsync**
```csharp
// FindAsync — checks identity cache first, then DB (fast but can return stale data)
var product1 = await context.Products.FindAsync(42); // hits DB
var product2 = await context.Products.FindAsync(42); // returns cached — NO DB call

// FirstOrDefaultAsync — always hits the database
var fresh = await context.Products.FirstOrDefaultAsync(p => p.Id == 42); // always DB

// Reload a tracked entity with fresh data from DB
await context.Entry(product).ReloadAsync();
```

---

## Gotchas

- **`context.Products.Update(entity)` marks every property as modified.** When you attach a detached entity with `Update()`, EF has no snapshot to diff against — it marks all columns dirty and generates a full-column `UPDATE`. This can overwrite changes made by another process between your read and your write. Load the entity first, patch specific properties, then `SaveChangesAsync()` to get a targeted update.
- **The identity cache in `FindAsync` can return stale data.** If you loaded `Product 42` earlier in the same scope, `FindAsync(42)` returns the cached instance without a database round-trip — even if the row was updated by another request. Use `FirstOrDefaultAsync` or `ReloadAsync()` for freshness-sensitive reads.
- **Tracking a large number of entities in a long-running scope grows memory unboundedly.** A batch job processing 50,000 rows in one `DbContext` accumulates 50,000 tracked snapshots. Call `context.ChangeTracker.Clear()` after each batch, use `AsNoTracking()` with explicit logic, or create a new context per batch via `IDbContextFactory<T>`.
- **`AsNoTracking` entities can't be used with `Update()` or `Remove()` without re-attaching.** If you load with `AsNoTracking()` and then call `context.Remove(entity)`, EF throws `InvalidOperationException`. Attach the entity first with `context.Attach(entity)` before removing, or reload it as a tracked query.
- **`DetectChanges()` inside a loop is quadratic cost.** EF's auto-detection scans every tracked entity. Calling it manually in a loop that adds entities re-scans all previously added entities on every iteration. Disable auto-detection with `AutoDetectChangesEnabled = false` and call it once at the end.
- **`TrackGraph` sets state on every node including navigation entities you didn't intend to modify.** Walk the graph carefully — if you call `TrackGraph` on an order that has a `Customer` navigation, the `Customer` entity also goes through your state-setting callback. Set `EntityState.Unchanged` for entities you don't want to write.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between tracked and untracked entities, the performance implications of each, and the bugs that arise with `Update()` on detached entities.

**Common question form:** *"What is the EF Core change tracker and how does it work?"* or *"When would you use AsNoTracking?"*

**The depth signal:** A junior answer says `AsNoTracking` is faster and the change tracker generates SQL on `SaveChanges`. A senior answer explains that `Update()` on a detached entity marks all columns dirty (full-column UPDATE + concurrency risk), why `FindAsync` hits the identity cache and can return stale data, the quadratic cost of `DetectChanges()` inside a loop, why long-running scopes accumulate tracking memory and how `ChangeTracker.Clear()` or `IDbContextFactory` solves it, how the `SaveChangesAsync` override or a `SaveChangesInterceptor` stamps audit fields cross-cuttingly, how `TrackGraph` handles complex disconnected object trees from APIs, and the difference between `AsNoTracking` and `AsNoTrackingWithIdentityResolution` for JOIN queries that reference the same entity multiple times.

---

## Related Topics

- [[dotnet/ef/ef-dbcontext.md]] — The `DbContext` hosts the `ChangeTracker`; understanding context lifetime explains why tracking state accumulates and when it resets.
- [[dotnet/ef/ef-queries.md]] — `AsNoTracking` and `AsNoTrackingWithIdentityResolution` are query-level tracking opt-outs; query design and tracking decisions are tightly coupled.
- [[dotnet/ef/ef-interceptors.md]] — `SaveChangesInterceptor` is a cleaner alternative to overriding `SaveChangesAsync` for audit stamps — testable in isolation, no DbContext subclassing required.
- [[dotnet/ef/ef-relationships.md]] — Navigation properties on tracked entities are populated and maintained by the change tracker; understanding tracking explains why accessing an unloaded navigation returns null.

---

## Source

https://learn.microsoft.com/en-us/ef/core/change-tracking

---
*Last updated: 2026-04-08*