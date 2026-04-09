# Repository Pattern

> A repository is a class that wraps your data access logic so the rest of your application never talks to the database directly.

---

## When To Use It

Use it when you want to decouple business logic from data access — making services testable without a real database, and making it possible to swap persistence mechanisms without touching domain code. It earns its cost in medium-to-large applications with real test suites. Don't use it as a reflexive layer on top of EF Core in simple CRUD apps — you end up with `ProductRepository.GetById()` that just calls `_context.Products.FindAsync()`, which is indirection with no payoff.

---

## Core Concept

**One sentence for the interview:** The repository owns the query; the service owns the decision.

The idea is simple: instead of your service class holding a `DbContext` and writing `_context.Orders.Where(...).ToListAsync()`, it holds an `IOrderRepository` and calls `_repository.GetPendingOrdersAsync()`. The repository owns the query; the service owns the decision. The real benefit isn't abstraction for its own sake — it's that you can inject a fake repository in tests and never spin up a database. The debate in .NET is whether this is redundant on top of EF Core, since `DbContext` is already a unit of work and `DbSet` is already a repository. The honest answer: EF Core is hard to mock at the `DbContext` level cleanly, so the pattern still has practical value for testability even if it's architecturally redundant.

---

## The Code

```csharp
// 1. Interface — what the domain sees
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(int id);
    Task<List<Order>> GetPendingAsync();
    Task AddAsync(Order order);
    Task SaveChangesAsync();
}
```

```csharp
// 2. EF Core implementation — .NET 8 primary constructor
public class OrderRepository(AppDbContext context) : IOrderRepository
{
    public Task<Order?> GetByIdAsync(int id) =>
        context.Orders.FirstOrDefaultAsync(o => o.Id == id);

    public Task<List<Order>> GetPendingAsync() =>
        context.Orders
            .Where(o => o.Status == OrderStatus.Pending)
            .AsNoTracking()
            .ToListAsync();

    public async Task AddAsync(Order order) =>
        await context.Orders.AddAsync(order);

    public Task SaveChangesAsync() =>
        context.SaveChangesAsync();
}
```

```csharp
// 3. Registration in DI
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
```

```csharp
// 4. Service consuming the repository — no EF dependency here
public class OrderService(IOrderRepository orders)
{
    public async Task<List<Order>> GetPendingOrdersAsync() =>
        await orders.GetPendingAsync();
}
```

```csharp
// 5. Fake in-memory repository for unit tests — .NET 8 primary constructor
public class FakeOrderRepository : IOrderRepository
{
    private readonly List<Order> _store = new();

    public Task<Order?> GetByIdAsync(int id) =>
        Task.FromResult(_store.FirstOrDefault(o => o.Id == id));

    public Task<List<Order>> GetPendingAsync() =>
        Task.FromResult(_store.Where(o => o.Status == OrderStatus.Pending).ToList());

    public Task AddAsync(Order order) { _store.Add(order); return Task.CompletedTask; }

    public Task SaveChangesAsync() => Task.CompletedTask; // no-op in tests
}
```

```csharp
// 6. Generic vs specific repositories — why generic leaks query concern
// BAD: generic repository pushes filtering back to the caller
public interface IRepository<T>
{
    Task<T?> FindAsync(Expression<Func<T, bool>> predicate); // caller writes the query
    Task<IEnumerable<T>> GetAllAsync();
}

// Usage — query logic bleeds into the service layer, defeating the pattern
var pending = await _repo.FindAsync(o => o.Status == OrderStatus.Pending && !o.IsDeleted);

// GOOD: named methods — the repository owns what "pending" means
public interface IOrderRepository
{
    Task<List<Order>> GetPendingAsync();   // query logic is encapsulated here
}
```

```csharp
// 7. Soft-delete guard — easy to forget in base queries
// If your Order has an IsDeleted flag, every query must filter it
// BAD: GetPendingAsync returns deleted orders too
public Task<List<Order>> GetPendingAsync() =>
    context.Orders
        .Where(o => o.Status == OrderStatus.Pending)  // ← IsDeleted check missing
        .ToListAsync();

// GOOD: either add the filter explicitly, or use EF Core global query filters
protected override void OnModelCreating(ModelBuilder mb)
{
    mb.Entity<Order>().HasQueryFilter(o => !o.IsDeleted);  // applied to every query automatically
}
// With global filter in place, GetPendingAsync() above is now correct.
// Watch out: AsNoTracking() still applies the filter; IgnoreQueryFilters() bypasses it.
```

---

## Gotchas

- **Generic repositories (`IRepository<T>`) leak persistence concerns.** Methods like `GetAll()`, `Find(Expression<Func<T, bool>>)` push query logic back into the service layer. The whole point is to keep query logic inside the repository — behind a named, intention-revealing method.

- **Calling `SaveChangesAsync()` inside the repository breaks unit-of-work semantics.** If two repositories each call `SaveChanges()` separately, you can't wrap them in one transaction. Either expose `SaveChangesAsync()` on a shared unit-of-work interface, or let the service call it directly on the `DbContext`.

- **The interface doesn't save you if it returns `IQueryable<T>`.** Returning `IQueryable` from a repository method lets callers chain `.Where()` on it, which means EF-specific LINQ leaks out of the repository. Always return materialized results (`List<T>`, `T?`). Who owns materialization — the repository or the caller — must have a clear answer, and the answer should always be the repository.

- **Mocking `DbContext` directly with Moq is painful and fragile.** This is the practical reason the pattern exists in .NET — it's far easier to implement `IOrderRepository` as a fake than to mock `DbSet<Order>` correctly.

- **One repository per aggregate, not per table.** If `Order` owns `OrderItem`, the `OrderRepository` handles both. Creating a separate `OrderItemRepository` breaks aggregate boundaries and encourages queries that bypass invariants.

- **Soft-delete filters are silently missing from base queries.** If your entities have an `IsDeleted` flag and you forget to include `!o.IsDeleted` in every `Where()` clause, deleted records appear in results. Use EF Core's `HasQueryFilter()` on the model to apply the filter globally — then you only need to remember `IgnoreQueryFilters()` when you explicitly want deleted records.

---

## Interview Angle

**What they're really testing:** Whether you understand the *reason* for the pattern — testability and separation of concerns — versus cargo-culting it as boilerplate.

**Common question form:** *"What is the repository pattern and why would you use it in a .NET application?"* or *"Is the repository pattern still relevant with EF Core?"*

**The depth signal:** A junior describes the pattern structurally ("it wraps database calls behind an interface") and treats it as mandatory architecture. A senior debates its value honestly: EF Core's `DbContext` is already a unit of work and `DbSet` is already a repository, so the pattern adds a layer — but that layer enables clean unit tests without in-memory SQLite or mocking `DbSet`. They also know the failure modes: generic repositories, `IQueryable` leakage, and `SaveChanges()` placement breaking transaction boundaries.

**Follow-up the interviewer asks next:** *"If EF Core's DbContext is already a repository, when would you still add the pattern on top?"*

The honest answer is: when testability is a real requirement. If you need to unit test services without spinning up a database — and you should — the fake repository approach is the cleanest option. In-memory SQLite works but tests the wrong thing (it tests EF behavior, not your service logic). Mocking `DbContext` is possible but produces brittle, noisy test setup. A fake `IOrderRepository` with a `List<Order>` in memory tests exactly what the service does with the data it gets — no database, no EF, no connection string. That's the argument. If you have no unit tests and rely entirely on integration tests, the repository pattern adds cost with no benefit.

---

## Related Topics

- [[dotnet/pattern/pattern-unit-of-work.md]] — The natural companion pattern; coordinates multiple repositories under a single `SaveChanges()` call.
- [[dotnet/ef/ef-transactions.md]] — `SaveChangesAsync()` placement in repositories directly affects whether you can wrap multiple operations in one transaction.
- [[dotnet/ef/ef-performance.md]] — Repositories that return `IQueryable` defeat `AsNoTracking()` and projection optimizations that should live inside the repository.
- [[dotnet/pattern/pattern-clean-architecture.md]] — The repository interface lives in the Application layer; the EF Core implementation lives in Infrastructure — clean architecture explains why the split exists.

---

## Source

https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-design

---

*Last updated: 2026-04-09*