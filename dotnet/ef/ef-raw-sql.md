# EF Core Raw SQL

> The escape hatch in EF Core that lets you write SQL directly when LINQ can't express what you need — while still returning typed entities or scalar results through the same DbContext infrastructure.

---

## When To Use It

Use raw SQL when EF Core's LINQ provider can't translate your expression — full-text search, window functions, complex CTEs, stored procedures, or provider-specific SQL features. Also use it when you've profiled a query and the EF-generated SQL is measurably slower than hand-written SQL. Don't reach for it by default because LINQ "feels harder" — every raw SQL call is a string that bypasses compile-time checking, breaks with schema renames, and is a SQL injection risk if parameterised incorrectly. Keep raw SQL at the boundary of your data layer, never scattered across services.

---

## Core Concept

EF Core offers three surfaces for raw SQL. `FromSqlRaw` and `FromSqlInterpolated` on a `DbSet<T>` return tracked entities, meaning EF still manages change tracking and you can compose additional LINQ on top. `ExecuteSqlRaw` and `ExecuteSqlInterpolated` on `context.Database` execute non-query statements (INSERT, UPDATE, DELETE) and return the row count — bypassing the change tracker entirely. `SqlQueryRaw` (EF Core 7+) on `context.Database` returns typed scalar or DTO results without a `DbSet` or keyless entity. The interpolated variants are safe by default because C# interpolation is converted to parameterised SQL. The `Raw` variants require manual placeholder syntax — mixing user input directly into the string is a SQL injection vulnerability.

---

## The Code

**1. FromSqlRaw — tracked entities, composable with LINQ**
```csharp
// {0} becomes a SqlParameter — not string concatenation
var products = await context.Products
    .FromSqlRaw("SELECT * FROM Products WHERE CategoryId = {0}", categoryId)
    .Where(p => p.IsActive)      // additional LINQ composed on top — added to the SQL
    .OrderBy(p => p.Name)
    .ToListAsync();
```

**2. FromSqlInterpolated — preferred: safe and readable**
```csharp
// C# interpolation is converted to parameterised SQL automatically — NOT string concat
var products = await context.Products
    .FromSqlInterpolated($"SELECT * FROM Products WHERE CategoryId = {categoryId}")
    .AsNoTracking()
    .ToListAsync();
```

**3. Stored procedure returning entities**
```csharp
var products = await context.Products
    .FromSqlInterpolated($"EXEC GetActiveProductsByCategory {categoryId}")
    .AsNoTracking()
    .ToListAsync();

// You cannot compose .Where() after a stored proc call — EF can't wrap it in a subquery
// The proc handles all filtering internally
```

**4. ExecuteSqlRaw / ExecuteSqlInterpolated — for INSERT, UPDATE, DELETE**
```csharp
var rowsAffected = await context.Database.ExecuteSqlInterpolatedAsync(
    $"UPDATE Products SET IsActive = 0 WHERE ExpiresAt < {DateTime.UtcNow}");

var deleted = await context.Database.ExecuteSqlRawAsync(
    "DELETE FROM AuditLogs WHERE CreatedAt < {0}", cutoffDate);
```

**5. SqlQueryRaw — typed scalars and DTOs without a DbSet (EF Core 7+)**
```csharp
// Returns a typed scalar directly — no need for a keyless entity or ADO.NET
var count = await context.Database
    .SqlQueryRaw<int>("SELECT COUNT(*) FROM Orders WHERE CustomerId = {0}", customerId)
    .SingleAsync();

// Returns a DTO shape — no DbSet<T> required, no keyless entity configuration
var report = await context.Database
    .SqlQueryRaw<SalesReportDto>(@"
        SELECT c.Name AS Category,
               SUM(oi.UnitPrice * oi.Quantity) AS TotalRevenue,
               COUNT(DISTINCT o.Id) AS OrderCount
        FROM Orders o
        JOIN OrderItems oi ON oi.OrderId = o.Id
        JOIN Categories c  ON c.Id = oi.CategoryId
        GROUP BY c.Name")
    .ToListAsync();

// No configuration needed — SalesReportDto is a plain class with matching property names
public class SalesReportDto
{
    public string Category     { get; set; } = string.Empty;
    public decimal TotalRevenue { get; set; }
    public int OrderCount      { get; set; }
}
```

**6. Keyless entities — for EF Core 6 and earlier (SqlQueryRaw not yet available)**
```csharp
// Register as a keyless entity in OnModelCreating
modelBuilder.Entity<SalesReport>().HasNoKey().ToView(null);

// Query via DbSet
var report = await context.Set<SalesReport>()
    .FromSqlRaw("SELECT c.Name, SUM(oi.Total) FROM ...")
    .ToListAsync();
```

**7. Dapper integration — using Dapper on the same EF connection**
```csharp
// Dapper and EF can share the same connection and transaction
// Useful when EF handles writes and Dapper handles complex read queries

public async Task<IEnumerable<OrderSummary>> GetSummariesAsync(int customerId)
{
    var connection = _context.Database.GetDbConnection();

    // Ensure connection is open — EF manages its lifecycle, but Dapper needs it open
    if (connection.State == ConnectionState.Closed)
        await connection.OpenAsync();

    return await connection.QueryAsync<OrderSummary>(@"
        SELECT o.Id, o.Total, COUNT(oi.Id) AS ItemCount
        FROM Orders o
        JOIN OrderItems oi ON oi.OrderId = o.Id
        WHERE o.CustomerId = @CustomerId
        GROUP BY o.Id, o.Total",
        new { CustomerId = customerId });
}

// Dapper + EF inside the same transaction
await using var transaction = await _context.Database.BeginTransactionAsync();

var conn = _context.Database.GetDbConnection();
await conn.ExecuteAsync(
    "INSERT INTO AuditLog (Action, EntityId) VALUES (@Action, @Id)",
    new { Action = "OrderCreated", order.Id },
    transaction: transaction.GetDbTransaction()); // share the transaction

_context.Orders.Add(order);
await _context.SaveChangesAsync();

await transaction.CommitAsync();
```

**8. SQL injection — wrong vs right**
```csharp
// WRONG — string interpolation into FromSqlRaw = SQL injection
var name = userInput; // could be: '; DROP TABLE Products; --
var products = await context.Products
    .FromSqlRaw($"SELECT * FROM Products WHERE Name = '{name}'") // NEVER
    .ToListAsync();

// RIGHT — use FromSqlInterpolated (EF extracts parameters from FormattableString)
var products = await context.Products
    .FromSqlInterpolated($"SELECT * FROM Products WHERE Name = {name}")
    .ToListAsync();

// RIGHT — use Raw with placeholder
var products = await context.Products
    .FromSqlRaw("SELECT * FROM Products WHERE Name = {0}", name)
    .ToListAsync();
```

**9. When raw SQL temptation is actually a dynamic filter problem**
```csharp
// Often raw SQL is reached for when the real problem is dynamic filtering
// Use IQueryable composition instead — no raw SQL, fully parameterised

public async Task<List<Product>> SearchAsync(ProductFilter filter)
{
    var query = context.Products.AsQueryable();

    if (filter.CategoryId.HasValue)
        query = query.Where(p => p.CategoryId == filter.CategoryId.Value);

    if (!string.IsNullOrEmpty(filter.Name))
        query = query.Where(p => p.Name.Contains(filter.Name));

    if (filter.MinPrice.HasValue)
        query = query.Where(p => p.Price >= filter.MinPrice.Value);

    return await query.AsNoTracking().ToListAsync();
    // EF generates a single parameterised SQL with only the active WHERE clauses
}
```

---

## Gotchas

- **`FromSqlRaw` with C# string interpolation is a SQL injection hole.** `FromSqlRaw($"...{variable}")` interpolates the value into the string before EF sees it — EF receives a completed string with no parameters. Use `FromSqlInterpolated` for interpolation syntax, or `FromSqlRaw` with `{0}` placeholders.
- **`FromSqlRaw` must return all columns the entity maps to.** If your SQL `SELECT`s a subset of columns, EF throws at materialisation time — not at query build time. Use `SELECT *` or explicitly name all mapped columns. For partial results, use `SqlQueryRaw<TDto>` (EF Core 7+) or a keyless entity.
- **LINQ clauses after `FromSql` wrap the raw SQL in a subquery.** `context.Products.FromSqlRaw("SELECT * FROM Products").Where(p => p.IsActive)` generates `SELECT ... FROM (SELECT * FROM Products) AS p WHERE p.IsActive = 1`. Stored procedure calls can't be wrapped — composing LINQ after `EXEC ...` throws at runtime.
- **`ExecuteSqlRaw` doesn't update entities already tracked in the same context.** If you loaded `Product 5` earlier and then call `ExecuteSqlRaw("UPDATE Products SET Price = 20 WHERE Id = 5")`, the in-memory tracked entity still has the old price. A subsequent `SaveChangesAsync()` may overwrite your raw SQL update. Reload with `context.Entry(product).ReloadAsync()` after the raw update.
- **`SqlQueryRaw<T>` property name matching is case-insensitive but column name must match.** If your SQL returns `TotalRevenue` but your DTO has `Revenue`, the mapping silently fails — the property stays at its default value. Match names exactly or use `AS` aliases in the SQL.
- **Dapper shares the connection but not the change tracker.** Records inserted by Dapper on the same connection are not known to EF's change tracker. If you insert via Dapper and then try to `FindAsync` the same row in the same context, EF may return a cached (stale or missing) instance. Use `FirstOrDefaultAsync` to bypass the cache.

---

## Interview Angle

**What they're really testing:** Whether you know when raw SQL is appropriate, how to use it safely without SQL injection, and what the change tracker implications are.

**Common question form:** *"How do you execute raw SQL in EF Core?"* or *"How do you prevent SQL injection when using raw SQL in EF Core?"*

**The depth signal:** A junior describes `FromSqlRaw` and `ExecuteSqlRaw`. A senior explains the injection vulnerability of `FromSqlRaw($"...{var}")` vs `FromSqlInterpolated`, introduces `SqlQueryRaw<T>` (EF Core 7+) as the clean way to query arbitrary shapes without keyless entity configuration, explains Dapper integration on the shared EF connection with a shared transaction, why `ExecuteSqlRaw` doesn't update tracked entities, and knows that most "I need raw SQL for dynamic filters" problems are actually solvable with composable `IQueryable` — reaching for raw SQL is the last resort, not the first.

---

## Related Topics

- [[dotnet/ef/ef-queries.md]] — Raw SQL is the escape hatch from LINQ translation; knowing what EF's LINQ provider can and can't translate tells you when to reach for raw SQL.
- [[dotnet/ef/ef-tracking.md]] — `ExecuteSqlRaw` bypasses the change tracker; understanding tracking explains the stale-entity bug from mixing raw SQL updates with tracked entities.
- [[dotnet/ef/ef-transactions.md]] — Raw SQL executes through the same connection; `GetDbTransaction()` shares the EF transaction with Dapper or ADO.NET operations.
- [[databases/sql/sql-indexing.md]] — Raw SQL queries are often written for performance reasons; the index strategy on the underlying tables determines whether the hand-written SQL actually outperforms EF's generated version.

---

## Source

https://learn.microsoft.com/en-us/ef/core/querying/sql-queries

---
*Last updated: 2026-04-08*