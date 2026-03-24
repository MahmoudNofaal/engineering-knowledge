# C# — LINQ to SQL (IQueryable and EF Core Translation)

> Writing LINQ queries against `IQueryable<T>` that an ORM like EF Core translates into SQL and executes on the database — rather than running C# code in memory.

---

## When To Use It

Use LINQ-to-SQL (via EF Core's `IQueryable<T>`) whenever you need to filter, sort, project, or aggregate data that lives in a relational database and you want the database engine to do that work. The entire point is to push predicates, projections, and ordering into the SQL query rather than fetching all rows and processing them in C#. Don't mix untranslatable C# methods into `IQueryable<T>` queries — the provider either throws at runtime or silently evaluates client-side, loading far more data than needed. And don't confuse this with LINQ-to-Objects: the same syntax behaves completely differently depending on whether the source is `IEnumerable<T>` or `IQueryable<T>`.

---

## Core Concept

When you call `Where`, `Select`, or `OrderBy` on a `List<T>`, LINQ runs your lambda as a C# delegate in your process. When you call the same operators on a `DbSet<T>` from EF Core, those lambdas are never executed as C# code — they're captured as expression trees. An expression tree is a data structure representing the code as an object graph: nodes for method calls, member accesses, constants, and parameters. EF Core's query provider walks that tree, figures out what SQL it maps to, and sends the SQL to the database. The result comes back as data rows, which EF then materializes into C# objects. The deferred execution model is the same as LINQ-to-Objects — nothing happens until you call `ToList()`, `FirstOrDefault()`, or another materializing operator — but the execution happens in the database, not in the CLR.

---

## The Code

### IQueryable vs IEnumerable — the critical behavioral split
```csharp
// IQueryable<T> — EF Core; query runs in the DATABASE
IQueryable<Product> queryable = dbContext.Products
    .Where(p => p.Price > 100);   // becomes SQL WHERE Price > 100
// SQL: SELECT * FROM Products WHERE Price > 100

// IEnumerable<T> — once you call AsEnumerable() or ToList(),
// all remaining operators run IN MEMORY in C#
IEnumerable<Product> enumerable = dbContext.Products
    .AsEnumerable()               // fetches ALL rows from DB here
    .Where(p => p.Price > 100);   // filters 10,000 rows in C# memory
// SQL: SELECT * FROM Products  ← no WHERE clause — all rows fetched

// The source type determines where the work happens — not the syntax
```

### Basic EF Core query — filter, project, paginate
```csharp
record ProductDto(int Id, string Name, decimal Price);

// All operators before ToList() are translated to SQL
var results = await dbContext.Products
    .Where(p => p.Category == "Electronics" && p.IsActive)
    .OrderBy(p => p.Price)
    .Skip(20)                         // SQL OFFSET
    .Take(10)                         // SQL FETCH NEXT 10 ROWS
    .Select(p => new ProductDto(p.Id, p.Name, p.Price)) // SELECT Id, Name, Price only
    .ToListAsync();

// Generated SQL (approximate):
// SELECT p.Id, p.Name, p.Price
// FROM Products p
// WHERE p.Category = 'Electronics' AND p.IsActive = 1
// ORDER BY p.Price
// OFFSET 20 ROWS FETCH NEXT 10 ROWS ONLY
```

### Inspecting generated SQL — mandatory for non-trivial queries
```csharp
// ToQueryString() shows the SQL without executing — use this during development
var query = dbContext.Orders
    .Where(o => o.CustomerId == 42)
    .Select(o => new { o.Id, o.Total });

string sql = query.ToQueryString();
Console.WriteLine(sql);
// SELECT o.Id, o.Total FROM Orders o WHERE o.CustomerId = 42

// Or configure EF Core logging to see SQL in output automatically
// In Program.cs:
builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlServer(connectionString)
       .LogTo(Console.WriteLine, LogLevel.Information)
       .EnableSensitiveDataLogging()); // shows parameter values — dev only
```

### Untranslatable methods — the runtime exception source
```csharp
// THROWS at runtime: EF can't translate custom C# methods to SQL
var bad = await dbContext.Products
    .Where(p => IsExpensive(p))  // custom method — not an expression the provider knows
    .ToListAsync();              // InvalidOperationException

static bool IsExpensive(Product p) => p.Price > 500;

// FIX: inline the logic so EF can parse it as an expression tree
var good = await dbContext.Products
    .Where(p => p.Price > 500)  // pure expression — translates to SQL
    .ToListAsync();

// FIX 2: if the logic is complex, switch to client evaluation explicitly
var clientSide = await dbContext.Products
    .ToListAsync()              // fetch first — deliberate
    .ContinueWith(t => t.Result.Where(p => IsExpensive(p)).ToList());
```

### Client evaluation — when it's intentional vs accidental
```csharp
// ACCIDENTAL client evaluation — string method EF can't translate
var bad2 = await dbContext.Users
    .Where(u => u.Name.Normalize() == "alice") // Normalize() = not translatable
    .ToListAsync(); // may throw OR silently fetch all rows depending on EF version

// INTENTIONAL — fetch a manageable set, then refine in memory
var intentional = await dbContext.Products
    .Where(p => p.Category == "Electronics")  // SQL WHERE
    .ToListAsync();                            // materialize here

var filtered = intentional
    .Where(p => MyComplexBusinessRule(p))     // C# in-memory — explicit and visible
    .ToList();
```

### Composing queries dynamically
```csharp
// IQueryable<T> can be built up incrementally — each operator refines the SQL
IQueryable<Product> query = dbContext.Products.AsQueryable();

if (!string.IsNullOrEmpty(searchTerm))
    query = query.Where(p => p.Name.Contains(searchTerm)); // SQL LIKE %term%

if (maxPrice.HasValue)
    query = query.Where(p => p.Price <= maxPrice.Value);

if (sortByPrice)
    query = query.OrderBy(p => p.Price);

// Nothing has executed yet — one SQL query is sent when we materialize
var results = await query
    .Select(p => new ProductDto(p.Id, p.Name, p.Price))
    .ToListAsync();
```

### N+1 query problem — the most common EF performance mistake
```csharp
// BAD: N+1 — one query for orders, then one query per order for customer
var orders = await dbContext.Orders.ToListAsync();
foreach (var order in orders)
{
    // Each access to order.Customer triggers a separate SQL query
    Console.WriteLine(order.Customer.Name); // N additional queries
}

// FIX: eager load with Include — one JOIN query
var orders2 = await dbContext.Orders
    .Include(o => o.Customer)   // SQL JOIN — one query total
    .ToListAsync();

foreach (var order in orders2)
    Console.WriteLine(order.Customer.Name); // already loaded, no extra queries

// FIX 2: project to avoid loading full entities
var projected = await dbContext.Orders
    .Select(o => new { o.Id, CustomerName = o.Customer.Name })
    .ToListAsync(); // EF generates a JOIN automatically for the projection
```

---

## Gotchas

- **`ToString()`, custom methods, and most BCL methods are not translatable** — EF Core can translate a specific set of C# operations to SQL. Anything outside that set throws `InvalidOperationException: ... could not be translated` at runtime, not at compile time. There's no static analysis warning. Always call `ToQueryString()` or check logs when you're unsure whether a method will translate.
- **`AsEnumerable()` and `ToList()` mid-chain switch off SQL translation for all subsequent operators** — every LINQ operator after `AsEnumerable()` runs in C# memory. If you call `dbContext.Orders.AsEnumerable().Where(...)`, the `Where` is a C# loop over all rows, not a SQL `WHERE`. This is the most expensive accidental client evaluation pattern.
- **`IQueryable<T>` is composable but `IEnumerable<T>` is not** — once you've materialized to `IEnumerable<T>`, chaining more operators adds in-memory work, not SQL refinement. If you return `IQueryable<T>` from a repository method, the caller can add more filters before the query executes. If you return `IEnumerable<T>`, the SQL has already fired.
- **Lazy loading can silently trigger N+1 queries** — if you enable lazy loading proxies in EF Core, accessing a navigation property that isn't loaded fires a new SQL query per object. In a loop over 500 orders, that's 501 database round trips. Disable lazy loading in production or use `Include()` and `Select()` projections explicitly.
- **`Skip`/`Take` without `OrderBy` is non-deterministic** — SQL has no guaranteed row order without `ORDER BY`. Paginating without sorting can return the same rows on multiple pages or skip rows entirely depending on the query plan. EF Core warns about this, but older versions were silent. Always `OrderBy` before `Skip`/`Take`.

---

## Interview Angle

**What they're really testing:** Whether you understand that `IQueryable<T>` works through expression trees translated to SQL — not C# delegates — and whether you can identify the exact boundary where work shifts from database to memory.

**Common question form:** "What's the difference between `IQueryable<T>` and `IEnumerable<T>`?" or "Why is this query slow?" (showing N+1 or `ToList()` before a `Where`) or "What happens when you call a custom method inside a LINQ-to-EF query?"

**The depth signal:** A junior says `IQueryable<T>` runs on the server and `IEnumerable<T>` runs in memory. A senior explains the mechanism: `IQueryable<T>` captures lambdas as expression trees — data structures that describe the code — which the EF Core provider parses and converts to SQL. This is why you can write `Where(p => p.Price > 100)` and get SQL `WHERE Price > 100` instead of a C# loop — the lambda was never compiled to a delegate, it was compiled to an expression tree object. The senior also knows that returning `IQueryable<T>` from a repository keeps the query open for composition while returning `IEnumerable<T>` fires it immediately, and that `ToQueryString()` is the essential debugging tool for verifying what SQL is actually generated before shipping any non-trivial query.

---

## Related Topics

- [[dotnet/csharp-linq-deferred-execution.md]] — Deferred execution applies to `IQueryable<T>` too, but execution happens in SQL rather than C#; understanding both layers is essential.
- [[dotnet/csharp-linq-basics.md]] — The operators are syntactically identical between LINQ-to-Objects and LINQ-to-SQL; the difference is entirely in the source type and what happens at runtime.
- [[databases/ef-core-queries.md]] — Full EF Core query patterns: `Include`, `AsNoTracking`, `FromSql`, query splitting, and SQL inspection in depth.
- [[databases/sql-indexes.md]] — The SQL EF Core generates is only as fast as the indexes behind it; understanding indexes is the other half of EF query performance.

---

## Source

https://learn.microsoft.com/en-us/ef/core/querying/

---
*Last updated: 2026-03-23*