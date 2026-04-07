# C# — LINQ to SQL (EF Core)

> How LINQ operators translate to SQL when used against `IQueryable<T>` — and how to avoid the silent mistakes that cause full-table scans.

---

## Quick Reference

| Pattern | SQL generated | Efficient? |
|---|---|---|
| `dbSet.Where(x => x.Age > 18)` | `WHERE Age > 18` | ✅ |
| `dbSet.Select(x => x.Name)` | `SELECT Name` | ✅ |
| `dbSet.ToList().Where(...)` | `SELECT *` + C# filter | ❌ |
| `dbSet.Where(CustomMethod(x))` | May throw or client-eval | ⚠️ |
| `dbSet.Include(x => x.Orders)` | `LEFT JOIN` | ✅ |

---

## Core Concept

When you call `.Where()` on an `IQueryable<T>` (returned by EF Core's `DbSet<T>`), your lambda is **not compiled to IL** — it's compiled to an `Expression<Func<T, bool>>` data structure. EF Core walks that expression tree and generates SQL. Nothing runs in C# — the entire predicate executes in the database.

The split point is `AsEnumerable()`, `ToList()`, `ToArray()`, or any materialising call. Before these, operators translate to SQL. After these, operators run in-memory in C#.

Using a C# method that EF Core can't translate inside a pre-materialisation query either:
1. Throws `InvalidOperationException: "could not be translated"`
2. Silently evaluates on the client (EF Core 2.x legacy behaviour — gone in 3.x+)

---

## The Code

**Project before materialising — avoid SELECT ***
```csharp
// BAD: fetches all columns, discards most
var names = dbContext.Users.ToList().Select(u => u.Name);
// SQL: SELECT Id, Name, Email, PasswordHash, CreatedAt, ... FROM Users

// GOOD: projects in SQL
var names = dbContext.Users.Select(u => u.Name).ToList();
// SQL: SELECT Name FROM Users
```

**Filter server-side**
```csharp
// GOOD: WHERE in SQL
var active = dbContext.Users
    .Where(u => u.IsActive && u.CreatedAt >= DateTime.UtcNow.AddDays(-30))
    .ToList();

// BAD: loads all users, filters in C#
var active2 = dbContext.Users.ToList()
    .Where(u => u.IsActive && u.CreatedAt >= DateTime.UtcNow.AddDays(-30))
    .ToList();
```

**Pagination — always with deterministic ordering**
```csharp
var page = await dbContext.Orders
    .Where(o => o.CustomerId == customerId)
    .OrderByDescending(o => o.CreatedAt)  // deterministic order is required
    .Skip((pageNumber - 1) * pageSize)
    .Take(pageSize)
    .Select(o => new OrderDto(o.Id, o.Total, o.CreatedAt))
    .ToListAsync(ct);
```

**Eager loading vs lazy loading vs explicit**
```csharp
// Eager: JOIN in one query
var ordersWithItems = dbContext.Orders
    .Include(o => o.Items)
    .Include(o => o.Customer)
    .ToList();

// Projection: avoids tracking, efficient columns
var orderSummaries = dbContext.Orders
    .Select(o => new
    {
        o.Id,
        o.Total,
        ItemCount    = o.Items.Count,
        CustomerName = o.Customer.Name
    })
    .ToList();
// SQL: SELECT o.Id, o.Total, COUNT(i.Id), c.Name with implicit JOINs
```

**Debug generated SQL**
```csharp
// See exactly what SQL will be generated — BEFORE hitting the database
IQueryable<Order> query = dbContext.Orders
    .Where(o => o.Total > 100)
    .OrderBy(o => o.CreatedAt);

string sql = query.ToQueryString(); // EF Core 5+
Console.WriteLine(sql);
```

**N+1 query problem**
```csharp
// BAD: N+1 — one query per order's customer
var orders = dbContext.Orders.ToList();
foreach (var o in orders)
    Console.WriteLine(o.Customer.Name); // lazy load fires per order

// GOOD: one query with JOIN
var orders = dbContext.Orders.Include(o => o.Customer).ToList();
foreach (var o in orders)
    Console.WriteLine(o.Customer.Name); // already loaded
```

---

## Real World Example

A reporting query builds a complex filter without any intermediate `ToList()` calls — one round-trip to the database.

```csharp
public async Task<PagedResult<OrderReportRow>> GetReportAsync(
    OrderReportFilter filter, CancellationToken ct)
{
    IQueryable<Order> query = dbContext.Orders
        .Include(o => o.Customer)
        .AsNoTracking();               // no change tracking for read-only

    if (filter.CustomerId.HasValue)
        query = query.Where(o => o.CustomerId == filter.CustomerId.Value);

    if (!string.IsNullOrEmpty(filter.Region))
        query = query.Where(o => o.Customer.Region == filter.Region);

    if (filter.From.HasValue)
        query = query.Where(o => o.CreatedAt >= filter.From.Value);

    if (filter.To.HasValue)
        query = query.Where(o => o.CreatedAt <= filter.To.Value);

    int total = await query.CountAsync(ct);   // SELECT COUNT(*) — one SQL call

    var rows = await query
        .OrderByDescending(o => o.CreatedAt)
        .Skip((filter.Page - 1) * filter.PageSize)
        .Take(filter.PageSize)
        .Select(o => new OrderReportRow(      // projection in SQL
            o.Id, o.Customer.Name, o.Total, o.CreatedAt))
        .ToListAsync(ct);                     // one SQL call for the page

    return new PagedResult<OrderReportRow>(rows, total, filter.Page, filter.PageSize);
}
```

*Two SQL calls total regardless of filter combinations — a `COUNT(*)` and a paginated `SELECT`. The entire filter chain builds up an expression tree that EF Core translates in one pass.*

---

## Gotchas

- **Calling `ToList()` mid-query switches to in-memory LINQ.** Every operator after `ToList()` runs in C# on the already-loaded data.
- **Untranslatable methods cause an exception in EF Core 3+.** Functions EF Core can't convert to SQL throw `InvalidOperationException`. Use `EF.Functions.*` helpers for database-specific functions.
- **`DateTime.Now` inside a query is parameterised by EF Core.** `DateTime.UtcNow.AddDays(-7)` is evaluated in C# once and sent as a SQL parameter — not called per row.
- **N+1 queries are silent.** Loading a collection then accessing a navigation property in a loop causes one query per loop iteration. Use `Include()` or project with `Select`.
- **Change tracking has a cost.** Use `.AsNoTracking()` for read-only queries — smaller memory footprint and faster materialisation.

---

## Interview Angle

**What they're really testing:** Whether you understand the `IQueryable`/`IEnumerable` boundary and can predict when code executes SQL vs C#.

**Common question forms:**
- "What's the N+1 problem?"
- "Why is `ToList().Where(...)` worse than `Where().ToList()`?"
- "How does EF Core translate a lambda to SQL?"

**The depth signal:** A senior explains that EF Core receives an `Expression<Func<T, bool>>` — a data structure — not compiled IL, and walks the expression tree to emit SQL. They know `AsNoTracking()` for read-only, `ToQueryString()` for debugging, and can describe N+1 and its fix without being prompted.

---

## Related Topics

- [[dotnet/csharp/csharp-linq-basics.md]] — `IQueryable<T>` vs `IEnumerable<T>` is the foundation
- [[dotnet/csharp/csharp-expression-trees.md]] — The data structure EF Core traverses to generate SQL

---

## Source

[Querying Data — EF Core](https://learn.microsoft.com/en-us/ef/core/querying/)

---
*Last updated: 2026-04-06*