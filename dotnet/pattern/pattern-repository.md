# Repository Pattern

> A repository is a class that wraps your data access logic so the rest of your application never talks to the database directly.

---

## When To Use It
Use it when you want to decouple business logic from data access — making services testable without a real database, and making it possible to swap persistence mechanisms without touching domain code. It earns its cost in medium-to-large applications with real test suites. Don't use it as a reflexive layer on top of EF Core in simple CRUD apps — you end up with `ProductRepository.GetById()` that just calls `_context.Products.FindAsync()`, which is indirection with no payoff.

---

## Core Concept
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
// 2. EF Core implementation
public class OrderRepository : IOrderRepository
{
    private readonly AppDbContext _context;

    public OrderRepository(AppDbContext context) => _context = context;

    public Task<Order?> GetByIdAsync(int id) =>
        _context.Orders.FirstOrDefaultAsync(o => o.Id == id);

    public Task<List<Order>> GetPendingAsync() =>
        _context.Orders
            .Where(o => o.Status == OrderStatus.Pending)
            .AsNoTracking()
            .ToListAsync();

    public async Task AddAsync(Order order) =>
        await _context.Orders.AddAsync(order);

    public Task SaveChangesAsync() =>
        _context.SaveChangesAsync();
}
```
```csharp
// 3. Registration in DI
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
```
```csharp
// 4. Service consuming the repository — no EF dependency here
public class OrderService
{
    private readonly IOrderRepository _orders;

    public OrderService(IOrderRepository orders) => _orders = orders;

    public async Task<List<Order>> GetPendingOrdersAsync() =>
        await _orders.GetPendingAsync();
}
```
```csharp
// 5. Fake in-memory repository for unit tests
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

---

## Gotchas
- **Generic repositories (`IRepository<T>`) leak persistence concerns.** Methods like `GetAll()`, `Find(Expression<Func<T, bool>>)` push query logic back into the service layer. The whole point is to keep query logic inside the repository — behind a named, intention-revealing method.
- **Calling `SaveChangesAsync()` inside the repository breaks unit-of-work semantics.** If two repositories each call `SaveChanges()` separately, you can't wrap them in one transaction. Either expose `SaveChangesAsync()` on a shared unit-of-work interface, or let the service call it directly on the `DbContext`.
- **The interface doesn't save you if it returns `IQueryable<T>`.** Returning `IQueryable` from a repository method lets callers chain `.Where()` on it, which means EF-specific LINQ leaks out of the repository. Always return materialized results (`List<T>`, `T?`).
- **Mocking `DbContext` directly with Moq is painful and fragile.** This is the practical reason the pattern exists in .NET — it's far easier to implement `IOrderRepository` as a fake than to mock `DbSet<Order>` correctly.
- **One repository per aggregate, not per table.** If `Order` owns `OrderItem`, the `OrderRepository` handles both. Creating a separate `OrderItemRepository` breaks aggregate boundaries and encourages queries that bypass invariants.

---

## Interview Angle
**What they're really testing:** Whether you understand the *reason* for the pattern — testability and separation of concerns — versus cargo-culting it as boilerplate.

**Common question form:** *"What is the repository pattern and why would you use it in a .NET application?"* or *"Is the repository pattern still relevant with EF Core?"*

**The depth signal:** A junior describes the pattern structurally ("it wraps database calls behind an interface") and treats it as mandatory architecture. A senior debates its value honestly: EF Core's `DbContext` is already a unit of work and `DbSet` is already a repository, so the pattern adds a layer — but that layer enables clean unit tests without in-memory SQLite or mocking `DbSet`. They also know the failure modes: generic repositories, `IQueryable` leakage, and `SaveChanges()` placement breaking transaction boundaries.

---

## Related Topics
- [[dotnet/ef-transactions.md]] — `SaveChangesAsync()` placement in repositories directly affects whether you can wrap multiple operations in one transaction.
- [[dotnet/ef-performance.md]] — Repositories that return `IQueryable` defeat `AsNoTracking()` and projection optimizations that should live inside the repository.
- [[dotnet/pattern-unit-of-work.md]] — The natural companion pattern; coordinates multiple repositories under a single `SaveChanges()` call.
- [[system-design/clean-architecture.md]] — Repository pattern is a dependency inversion mechanism; understanding clean architecture explains why the interface lives in the domain layer, not the infrastructure layer.

---

## Source
https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-design

---
*Last updated: 2026-03-24*