# EF Core Concurrency

> Concurrency control is how you prevent two users or processes from overwriting each other's changes to the same row at the same time.

---

## When To Use It

Use it any time multiple users or processes can update the same record — booking systems, inventory, user profile edits, financial records. Without it, the last write silently wins and data is lost. Don't bother on append-only tables or data written by exactly one process. Choose optimistic concurrency (EF's default mechanism) when conflicts are rare and you want to avoid locking. Choose pessimistic locking (explicit `UPDLOCK` hints via raw SQL) when conflicts are frequent and the cost of retrying is too high — high-contention inventory decrements, for example.

---

## Core Concept

EF Core uses optimistic concurrency by default — it assumes conflicts are rare, so it doesn't lock the row when you read it. Instead, it checks at save time whether the row was changed since you loaded it. You mark a property as a concurrency token; EF includes that value in the `WHERE` clause of the generated `UPDATE`. If zero rows are affected (because the token changed), someone else changed the row first, and EF throws `DbUpdateConcurrencyException`. You then decide: reload and retry, merge the changes, or surface the conflict to the user. SQL Server's `rowversion` type (a byte array that auto-increments on every update, managed by the database) is the cleanest token — you never update it yourself and it never has false positives.

---

## The Code

**1. Configure a rowversion concurrency token (SQL Server)**
```csharp
public class Product
{
    public int    Id         { get; set; }
    public string Name       { get; set; } = string.Empty;
    public int    Stock      { get; set; }

    [Timestamp]                        // maps to rowversion column — DB manages it
    public byte[] RowVersion { get; set; } = [];
}

// Fluent API alternative
modelBuilder.Entity<Product>()
    .Property(p => p.RowVersion)
    .IsRowVersion();
```

**2. Manual concurrency token — for non-SQL Server providers**
```csharp
public class Article
{
    public int      Id           { get; set; }
    public string   Content      { get; set; } = string.Empty;

    [ConcurrencyCheck]             // EF includes this in WHERE on UPDATE
    public DateTime LastModified  { get; set; }
}

// You must update LastModified yourself before SaveChanges
article.Content      = updatedContent;
article.LastModified = DateTime.UtcNow;
await _context.SaveChangesAsync();
```

**3. Catching and resolving a conflict — three strategies**
```csharp
public async Task UpdateStockAsync(int productId, int quantity)
{
    var product = await _context.Products.FindAsync(productId);
    product!.Stock -= quantity;

    try
    {
        await _context.SaveChangesAsync();
    }
    catch (DbUpdateConcurrencyException ex)
    {
        var entry      = ex.Entries.Single();
        var dbValues   = await entry.GetDatabaseValuesAsync(); // current DB state

        if (dbValues is null)
            throw new InvalidOperationException("Product was deleted by another user.");

        // Strategy A: Client wins — overwrite DB with your values
        entry.OriginalValues.SetValues(dbValues); // refresh the token so EF retries cleanly
        await _context.SaveChangesAsync();

        // Strategy B: Database wins — discard your changes, take the DB values
        // entry.CurrentValues.SetValues(dbValues);
        // No SaveChangesAsync needed — nothing to write

        // Strategy C: Merge — combine both sets of changes
        // (see pattern 4 below)
    }
}
```

**4. Merge strategy — combining client + database changes**
```csharp
catch (DbUpdateConcurrencyException ex)
{
    var entry    = ex.Entries.Single<Product>();
    var dbValues = (await entry.GetDatabaseValuesAsync())!;
    var dbStock  = dbValues.GetValue<int>(nameof(Product.Stock));

    // Business merge: apply your change delta to the current DB value
    // rather than overwriting the DB value entirely
    var originalStock   = (int)entry.OriginalValues[nameof(Product.Stock)]!;
    var clientDelta     = product.Stock - originalStock;  // how much YOU changed it
    product.Stock       = dbStock + clientDelta;           // apply delta on top of DB value

    entry.OriginalValues.SetValues(dbValues); // update the token
    await _context.SaveChangesAsync();
}
```

**5. Retry loop with exponential backoff — production-grade pattern**
```csharp
public async Task UpdateStockWithRetryAsync(int productId, int quantity)
{
    const int maxRetries = 3;
    var retries = 0;

    while (true)
    {
        try
        {
            // Re-load on every attempt — get fresh data and a fresh token
            var product = await _context.Products.FindAsync(productId)
                ?? throw new NotFoundException($"Product {productId} not found");

            product.Stock -= quantity;
            await _context.SaveChangesAsync();
            return; // success
        }
        catch (DbUpdateConcurrencyException) when (retries < maxRetries)
        {
            retries++;
            // Exponential backoff — 100ms, 200ms, 400ms
            await Task.Delay(TimeSpan.FromMilliseconds(100 * Math.Pow(2, retries - 1)));

            // Clear the stale tracked entity before reloading
            _context.ChangeTracker.Clear();
        }
    }
}
```

**6. PostgreSQL — xmin as concurrency token**
```csharp
// Npgsql uses the system column xmin (transaction ID) as a built-in rowversion equivalent
// Install: Npgsql.EntityFrameworkCore.PostgreSQL

modelBuilder.Entity<Product>()
    .UseXminAsConcurrencyToken(); // Npgsql extension method

// Behaviour is identical to rowversion — EF includes xmin in UPDATE WHERE clause
// No [Timestamp] attribute; no explicit property needed on the entity
```

**7. Pessimistic locking — when conflicts are frequent**
```csharp
// UPDLOCK + HOLDLOCK — locks the row for the duration of the transaction
// No other transaction can update or lock the same row until yours commits
// Use when conflicts are common enough that optimistic retry is wasteful
// (e.g. inventory in a flash sale)

await using var transaction = await _context.Database.BeginTransactionAsync();

var product = await _context.Products
    .FromSqlInterpolated(
        $"SELECT * FROM Products WITH (UPDLOCK, HOLDLOCK) WHERE Id = {productId}")
    .FirstAsync();

product.Stock -= quantity;
await _context.SaveChangesAsync();
await transaction.CommitAsync();

// With UPDLOCK the row is locked at read time — concurrent SELECT ... WITH (UPDLOCK)
// blocks until the transaction commits, preventing concurrent writes
// Trade-off: serialises access, reduces throughput, risk of deadlocks under load
```

---

## Gotchas

- **`[ConcurrencyCheck]` only works if you update the token field yourself.** If you forget to set `LastModified` before saving, EF compares the old value to itself and never detects a conflict. SQL Server `rowversion` avoids this entirely — the database updates it, not your code.
- **`DbUpdateConcurrencyException` contains stale entries.** After catching it, you must call `GetDatabaseValuesAsync()` to see the current DB state — `entry.CurrentValues` is still your in-memory version.
- **Retrying without refreshing `OriginalValues` causes an infinite loop.** If you call `SaveChangesAsync()` again without updating `OriginalValues` with the latest DB token, EF keeps comparing against the original token and keeps failing. Always `entry.OriginalValues.SetValues(dbValues)` before retrying.
- **`FindAsync` returns a cached entity if already tracked.** If you loaded the same product twice in the same scope, the second `FindAsync` returns the cached instance with the old `RowVersion`. Your `SaveChangesAsync` then compares against a stale token and throws even if no concurrent write happened. Call `ChangeTracker.Clear()` before re-loading on each retry attempt.
- **Pessimistic locking can cause deadlocks.** Two transactions each holding `UPDLOCK` on different rows and then trying to acquire locks on the other's rows will deadlock. SQL Server detects this and kills one transaction. Design lock acquisition order carefully and keep transactions short.
- **PostgreSQL `xmin` is a transaction ID, not a timestamp — it wraps around.** In theory (after ~2 billion transactions), `xmin` can wrap and produce a false "not modified" result. In practice this doesn't happen, but it's why `xmin` isn't identical to `rowversion` conceptually. Npgsql handles this correctly.

---

## Interview Angle

**What they're really testing:** Understanding of optimistic vs pessimistic concurrency, how EF detects conflicts, and how to resolve them in production.

**Common question form:** *"How would you handle two users updating the same record at the same time in EF Core?"*

**The depth signal:** A junior says "use `[Timestamp]` or `rowversion`" and stops. A senior explains why optimistic concurrency works (the token in the WHERE clause + zero rows affected = conflict), walks through the three resolution strategies (client wins, database wins, merge delta), explains the retry loop pattern with `ChangeTracker.Clear()` before each reload and exponential backoff, knows when to switch to pessimistic locking (high contention, retry cost is too high), understands the `UPDLOCK + HOLDLOCK` SQL Server pattern, knows the PostgreSQL `xmin` equivalent via Npgsql, and can articulate the deadlock risk of pessimistic locking and how to mitigate it with consistent lock ordering and short transactions.

---

## Related Topics

- [[dotnet/ef/ef-transactions.md]] — Concurrency conflicts are often resolved inside a transaction; isolation level determines what concurrent reads and writes are visible during resolution.
- [[dotnet/ef/ef-tracking.md]] — `FindAsync` identity cache returns stale entities in retry loops; `ChangeTracker.Clear()` is required between retry attempts.
- [[dotnet/ef/ef-raw-sql.md]] — Pessimistic locking with `UPDLOCK`/`HOLDLOCK` requires raw SQL since EF has no fluent API for lock hints.
- [[databases/sql/sql-isolation-levels.md]] — Optimistic concurrency operates at READ COMMITTED; pessimistic locking behaviour varies by isolation level.

---

## Source

https://learn.microsoft.com/en-us/ef/core/saving/concurrency

---
*Last updated: 2026-04-08*