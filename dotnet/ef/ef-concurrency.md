# EF Core Concurrency

> Concurrency control is how you prevent two users from overwriting each other's changes to the same row at the same time.

---

## When To Use It
Use it any time multiple users or processes can update the same record — booking systems, inventory, user profile edits, financial records. Without it, the last write silently wins and data is lost. Don't bother on append-only tables or data that's only ever written by one process.

---

## Core Concept
EF Core uses optimistic concurrency by default — it assumes conflicts are rare, so it doesn't lock the row when you read it. Instead, it checks at save time whether the row was changed since you loaded it. You mark a property as a concurrency token; EF includes that value in the `WHERE` clause of the `UPDATE`. If zero rows are affected, someone else changed the row first, and EF throws a `DbUpdateConcurrencyException`. You then decide: reload and retry, merge changes, or surface the conflict to the user. SQL Server has a native `rowversion` type (byte array that auto-increments on every update) that makes this effortless — you never update it manually.

---

## The Code
```csharp
// 1. Configure a rowversion concurrency token (SQL Server)
public class Product
{
    public int Id { get; set; }
    public string Name { get; set; }
    public int Stock { get; set; }

    [Timestamp]                          // maps to rowversion column in SQL Server
    public byte[] RowVersion { get; set; }
}

// In OnModelCreating (Fluent API alternative):
modelBuilder.Entity<Product>()
    .Property(p => p.RowVersion)
    .IsRowVersion();
```
```csharp
// 2. Catching and resolving a concurrency conflict
public async Task UpdateStockAsync(int productId, int newStock)
{
    var product = await _context.Products.FindAsync(productId);
    product.Stock = newStock;

    try
    {
        await _context.SaveChangesAsync();
    }
    catch (DbUpdateConcurrencyException ex)
    {
        var entry = ex.Entries.Single();
        var dbValues = await entry.GetDatabaseValuesAsync(); // what's actually in the DB now

        if (dbValues == null)
        {
            throw new InvalidOperationException("Product was deleted by another user.");
        }

        // Option A: client wins — overwrite with your values
        entry.OriginalValues.SetValues(dbValues); // update the token so EF retries clean
        await _context.SaveChangesAsync();

        // Option B: database wins — discard your changes
        // entry.CurrentValues.SetValues(dbValues);
    }
}
```
```csharp
// 3. Manual concurrency token (non-SQL Server / no rowversion)
public class Article
{
    public int Id { get; set; }
    public string Content { get; set; }

    [ConcurrencyCheck]                   // EF includes this in WHERE on UPDATE
    public DateTime LastModified { get; set; }
}

// You must update LastModified yourself before SaveChanges
article.Content = updatedContent;
article.LastModified = DateTime.UtcNow;
await _context.SaveChangesAsync();
```

---

## Gotchas
- **`[ConcurrencyCheck]` only works if you update the token field yourself.** If you forget to set `LastModified` before saving, EF compares the old value to itself and never detects a conflict. `rowversion` avoids this because SQL Server manages it.
- **`DbUpdateConcurrencyException` contains stale entries.** After catching it, you must call `GetDatabaseValuesAsync()` to see the current DB state — `entry.CurrentValues` is still your in-memory version, not what lost.
- **Retrying blindly after "client wins" can cause an infinite loop.** If you loop on `SaveChangesAsync()` without refreshing `OriginalValues` first, EF keeps comparing against the original token and keeps failing.
- **`FindAsync` returns a cached entity if it's already tracked.** If you load the same product twice in the same `DbContext` scope, the second load hits the change tracker, not the DB — you won't see the latest `RowVersion`.
- **PostgreSQL uses `xmin` (system column) instead of `rowversion`.** With Npgsql, configure `.UseXminAsConcurrencyToken()` — the SQL Server `[Timestamp]` pattern doesn't translate directly.

---

## Interview Angle
**What they're really testing:** Understanding of optimistic vs pessimistic concurrency, and how EF detects and surfaces conflicts at the infrastructure level.

**Common question form:** *"How would you handle two users updating the same record at the same time in EF Core?"*

**The depth signal:** A junior says "use `[Timestamp]` or `rowversion`" and considers it done. A senior explains *why* optimistic concurrency works (the WHERE clause row-count check), walks through what `DbUpdateConcurrencyException` actually contains, describes the three resolution strategies (client wins, database wins, merge), and knows when to reach for pessimistic locking via `UPDLOCK` hints instead — e.g., in a high-contention inventory decrement where conflicts aren't rare at all.

---

## Related Topics
- [[dotnet/ef-transactions.md]] — Concurrency conflicts are often resolved inside a transaction; understanding both together matters for atomic retry logic.
- [[databases/isolation-levels.md]] — Isolation level determines whether you even *see* committed changes from other sessions before your transaction ends.
- [[dotnet/ef-raw-sql.md]] — Pessimistic locking with `UPDLOCK`/`HOLDLOCK` hints requires raw SQL since EF has no fluent API for lock hints.
- [[system-design/optimistic-vs-pessimistic-locking.md]] — The architectural tradeoff between the two strategies, beyond what EF exposes.

---

## Source
https://learn.microsoft.com/en-us/ef/core/saving/concurrency

---
*Last updated: 2026-03-24*