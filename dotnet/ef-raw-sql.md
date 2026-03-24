# EF Core Raw SQL

> The escape hatch in EF Core that lets you write SQL directly when LINQ can't express what you need — while still returning typed entities or scalar results through the same DbContext infrastructure.

---

## When To Use It

Use raw SQL when EF Core's LINQ provider can't translate your expression — full-text search, window functions, complex CTEs, stored procedures, or provider-specific SQL features. Also use it when you've profiled a query and the EF-generated SQL is measurably slower than a hand-written equivalent. Don't reach for it by default because LINQ "feels harder" — every raw SQL call is a string that bypasses compile-time checking, breaks with schema renames, and is a SQL injection risk if parameterised incorrectly. Keep raw SQL at the boundary of your data layer, never scattered across services.

---

## Core Concept

EF Core offers two surfaces for raw SQL. `FromSqlRaw` and `FromSqlInterpolated` on a `DbSet<T>` return tracked entities, meaning EF still manages change tracking and you can compose additional LINQ on top of the result. `ExecuteSqlRaw` and `ExecuteSqlInterpolated` on `context.Database` execute non-query statements (INSERT, UPDATE, DELETE) and return the row count — they bypass the change tracker entirely. The interpolated variants (`FromSqlInterpolated`, `ExecuteSqlInterpolated`) are safe by default because C# interpolation is converted to parameterised SQL, not string concatenation. The `Raw` variants accept a format string and a `params object[]` — they're also parameterised, but only if you use the placeholder syntax correctly. Mixing user input directly into the raw string without placeholders is a SQL injection vulnerability regardless of which API you use.

---

## The Code

**1. FromSqlRaw — returns tracked entities, composable with LINQ**
```csharp
// Parameterised correctly — {0} becomes a SqlParameter, not string concat
var products = await context.Products
    .FromSqlRaw("SELECT * FROM Products WHERE CategoryId = {0}", categoryId)
    .Where(p => p.IsActive)      // LINQ clause composed on top — added to the SQL
    .OrderBy(p => p.Name)
    .ToListAsync();
```

**2. FromSqlInterpolated — preferred for safety and readability**
```csharp
// C# string interpolation is converted to parameterised SQL automatically
// This is NOT string concatenation — EF intercepts the FormattableString
var products = await context.Products
    .FromSqlInterpolated($"SELECT * FROM Products WHERE CategoryId = {categoryId}")
    .AsNoTracking()
    .ToListAsync();
```

**3. Stored procedure returning entities**
```csharp
// Stored proc must return all columns that the entity type maps to
var products = await context.Products
    .FromSqlInterpolated($"EXEC GetActiveProductsByCategory {categoryId}")
    .AsNoTracking()
    .ToListAsync();

// You cannot compose .Where() after a stored proc call — EF can't wrap it in a subquery
// Must be the terminal query or the proc handles all filtering itself
```

**4. ExecuteSqlRaw / ExecuteSqlInterpolated — for INSERT, UPDATE, DELETE**
```csharp
// Bypasses the change tracker — does not update tracked entities in memory
var rowsAffected = await context.Database.ExecuteSqlInterpolatedAsync(
    $"UPDATE Products SET IsActive = 0 WHERE ExpiresAt < {DateTime.UtcNow}");

// Use when bulk-updating rows that would be slow to load, modify, and save individually
var deleted = await context.Database.ExecuteSqlRawAsync(
    "DELETE FROM AuditLogs WHERE CreatedAt < {0}",
    cutoffDate);
```

**5. Scalar and non-entity results via ADO.NET through the same connection**
```csharp
// EF has no built-in "return a scalar" or "return an arbitrary shape" API
// Use the underlying connection for that
var connection = context.Database.GetDbConnection();
await connection.OpenAsync();

await using var command = connection.CreateCommand();
command.CommandText = "SELECT COUNT(*) FROM Orders WHERE CustomerId = @id";
command.Parameters.Add(new SqlParameter("@id", customerId));

var count = (int)(await command.ExecuteScalarAsync())!;
```

**6. SQL injection — the wrong way vs the right way**
```csharp
// WRONG — string concatenation — SQL injection vulnerability
var name = userInput; // could be: '; DROP TABLE Products; --
var products = await context.Products
    .FromSqlRaw($"SELECT * FROM Products WHERE Name = '{name}'") // NEVER do this
    .ToListAsync();

// RIGHT — parameterised via interpolation
var products = await context.Products
    .FromSqlInterpolated($"SELECT * FROM Products WHERE Name = {name}")
    .ToListAsync();

// RIGHT — parameterised via Raw with placeholder
var products = await context.Products
    .FromSqlRaw("SELECT * FROM Products WHERE Name = {0}", name)
    .ToListAsync();
```

**7. Mapping to a keyless entity for arbitrary query shapes**
```csharp
// For results that don't map to a real table — reports, aggregations, projections
public class SalesReport
{
    public string Category { get; set; } = string.Empty;
    public decimal TotalRevenue { get; set; }
    public int OrderCount { get; set; }
}

// Register as a keyless entity in OnModelCreating
modelBuilder.Entity<SalesReport>().HasNoKey().ToView(null);

// Query it with FromSqlRaw
var report = await context.Set<SalesReport>()
    .FromSqlRaw(@"
        SELECT c.Name AS Category,
               SUM(oi.UnitPrice * oi.Quantity) AS TotalRevenue,
               COUNT(DISTINCT o.Id) AS OrderCount
        FROM Orders o
        JOIN OrderItems oi ON oi.OrderId = o.Id
        JOIN Categories c  ON c.Id = oi.CategoryId
        GROUP BY c.Name")
    .ToListAsync();
```

---

## Gotchas

- **`FromSqlRaw` with C# string interpolation is a SQL injection hole.** `FromSqlRaw($"SELECT * FROM Products WHERE Name = '{name}'")`  interpolates the value into the string before EF sees it — EF receives a completed string with no parameters. Use `FromSqlInterpolated` when you want interpolation syntax, or use `FromSqlRaw` with `{0}` placeholders. The method names are your guide: `Raw` = you manage parameterisation, `Interpolated` = EF manages it.
- **`FromSqlRaw` / `FromSqlInterpolated` must return all columns the entity maps to.** If your SQL `SELECT`s a subset of columns, EF throws at materialisation time — not at query build time. Use `SELECT *` or explicitly name all mapped columns. If you want a subset, use a keyless entity type or project via ADO.NET.
- **LINQ clauses composed after `FromSql` wrap the raw SQL in a subquery.** `context.Products.FromSqlRaw("SELECT * FROM Products").Where(p => p.IsActive)` generates `SELECT ... FROM (SELECT * FROM Products) AS p WHERE p.IsActive = 1`. This is correct but can surprise you when reading execution plans. Stored procedures cannot be wrapped this way — composing LINQ after a `EXEC ...` call throws at runtime.
- **`ExecuteSqlRaw` doesn't update entities already tracked in the same context.** If you loaded `Product 5` earlier in the request and then call `ExecuteSqlRaw("UPDATE Products SET Price = 20 WHERE Id = 5")`, the in-memory tracked entity still has the old price. Any subsequent `SaveChangesAsync()` may overwrite your raw SQL update with the stale tracked value. Either use raw SQL exclusively for that entity in that scope, or reload it with `context.Entry(product).ReloadAsync()` after the raw update.
- **Scalar results and arbitrary shapes have no first-class EF API — you need ADO.NET or a keyless entity.** There's no `context.Database.ExecuteScalarAsync<int>()` in EF Core. For reporting queries that return custom shapes, the keyless entity pattern (`HasNoKey()`) is the cleanest option. For true scalars, drop to `GetDbConnection()` and use ADO.NET directly — it's two lines and more honest about what you're doing.

---

## Interview Angle

**What they're really testing:** Whether you know when raw SQL is appropriate, how to use it safely without SQL injection, and what the change tracker implications are when you bypass LINQ.

**Common question form:** *"How do you execute raw SQL in EF Core?"* or *"How do you prevent SQL injection when using raw SQL in EF Core?"*

**The depth signal:** A junior answer describes `FromSqlRaw` and `ExecuteSqlRaw`. A senior answer explains the critical distinction between `FromSqlRaw($"...{variable}")` (injection vulnerability — EF receives a completed string) and `FromSqlInterpolated($"...{variable}")` (safe — EF extracts parameters from the `FormattableString`), why `ExecuteSqlRaw` doesn't update tracked entities and what `ReloadAsync` does to fix that, the subquery wrapping behaviour when composing LINQ after `FromSql` and why it breaks stored procedure calls, and why keyless entities via `HasNoKey()` are the right pattern for report-shape queries rather than dropping all the way to raw ADO.NET.

---

## Related Topics

- [[dotnet/ef-queries.md]] — Raw SQL is the escape hatch from LINQ translation; knowing what EF's LINQ provider can and can't translate tells you when to reach for raw SQL.
- [[dotnet/ef-tracking.md]] — `ExecuteSqlRaw` bypasses the change tracker; understanding tracking explains the stale-entity bug that results from mixing raw SQL updates with tracked entities in the same scope.
- [[dotnet/ef-dbcontext.md]] — Raw SQL executes through the same `DbContext` connection and transaction; understanding the context explains how to share a transaction between raw SQL and EF operations.
- [[databases/sql-indexes.md]] — Raw SQL queries are often written for performance reasons; the index strategy on the underlying tables determines whether the hand-written SQL actually outperforms EF's generated version.

---

## Source

https://learn.microsoft.com/en-us/ef/core/querying/sql-queries

---
*Last updated: 2026-03-24*