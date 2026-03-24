# Unit of Work Pattern

> A unit of work tracks all the changes you make across multiple repositories and flushes them to the database in a single `SaveChanges()` call.

---

## When To Use It
Use it when you have multiple repositories that need to commit their changes together atomically — e.g., creating an order and decrementing inventory in one operation. It's the answer to the problem the repository pattern creates: if each repository owns its own `SaveChanges()`, you can't coordinate them. Skip it in simple applications with a single repository per operation, or when you're letting EF Core's `DbContext` serve as the implicit unit of work directly.

---

## Core Concept
EF Core's `DbContext` is already a unit of work — it tracks changes across all your entities and commits everything in one `SaveChanges()`. The pattern just makes that explicit and injectable. You wrap the `DbContext` in a `IUnitOfWork` interface that exposes your repositories and a single `SaveChangesAsync()`. Services talk to repositories through it, then call `unitOfWork.SaveChangesAsync()` once at the end. The key insight is that all repositories share the *same* `DbContext` instance — so they're all writing to the same change tracker, and one `SaveChanges()` flushes everything. It's coordination, not magic.

---

## The Code
```csharp
// 1. Interface — exposes repositories and one save method
public interface IUnitOfWork : IAsyncDisposable
{
    IOrderRepository Orders { get; }
    IInventoryRepository Inventory { get; }
    Task<int> SaveChangesAsync();
}
```
```csharp
// 2. EF Core implementation — all repositories share the same DbContext
public class UnitOfWork : IUnitOfWork
{
    private readonly AppDbContext _context;

    public IOrderRepository Orders { get; }
    public IInventoryRepository Inventory { get; }

    public UnitOfWork(AppDbContext context)
    {
        _context = context;
        Orders = new OrderRepository(context);       // same context instance
        Inventory = new InventoryRepository(context); // same context instance
    }

    public Task<int> SaveChangesAsync() =>
        _context.SaveChangesAsync();

    public async ValueTask DisposeAsync() =>
        await _context.DisposeAsync();
}
```
```csharp
// 3. DI registration
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
// DbContext registered separately as Scoped — UnitOfWork receives it via DI
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(connectionString));
```
```csharp
// 4. Service using IUnitOfWork — one save covers both repositories
public class OrderService
{
    private readonly IUnitOfWork _uow;

    public OrderService(IUnitOfWork uow) => _uow = uow;

    public async Task PlaceOrderAsync(CreateOrderDto dto)
    {
        var order = new Order { CustomerId = dto.CustomerId, Total = dto.Total };
        await _uow.Orders.AddAsync(order);

        var item = await _uow.Inventory.GetByProductIdAsync(dto.ProductId);
        item.Stock -= dto.Quantity;                  // EF tracks this change automatically

        await _uow.SaveChangesAsync();               // one commit, both changes persisted
    }
}
```
```csharp
// 5. Fake unit of work for unit tests
public class FakeUnitOfWork : IUnitOfWork
{
    public IOrderRepository Orders { get; } = new FakeOrderRepository();
    public IInventoryRepository Inventory { get; } = new FakeInventoryRepository();

    public int SaveCallCount { get; private set; }

    public Task<int> SaveChangesAsync()
    {
        SaveCallCount++;                             // assert this was called in tests
        return Task.FromResult(1);
    }

    public ValueTask DisposeAsync() => ValueTask.CompletedTask;
}
```

---

## Gotchas
- **Repositories must share the same `DbContext` instance.** If you accidentally register `OrderRepository` and `InventoryRepository` as separate scoped services (each getting their own `DbContext`), they're on different change trackers and `SaveChangesAsync()` on the unit of work only flushes one of them. Always pass the same `DbContext` into every repository inside the unit of work constructor.
- **Don't call `SaveChangesAsync()` inside a repository when using this pattern.** If any repository saves independently, you split the atomic commit. The only place `SaveChanges()` should be called is on the unit of work, by the service layer.
- **`IUnitOfWork` registered as Transient with a Scoped `DbContext` causes a captive dependency.** The `DbContext` must be Scoped, and `IUnitOfWork` must also be Scoped — otherwise the context's lifetime doesn't align with the HTTP request and you get shared state across requests.
- **Adding every repository to `IUnitOfWork` doesn't scale.** As the app grows, the interface becomes a dependency magnet. Consider splitting into multiple focused units of work per aggregate boundary, or accepting that for some operations you use `DbContext` directly.
- **Wrapping `IUnitOfWork` in an explicit `IDbContextTransaction` requires care.** The unit of work pattern and explicit transactions are orthogonal — you can combine them, but you need to begin the transaction on the `DbContext` before any repository calls, and commit it separately from `SaveChangesAsync()`.

---

## Interview Angle
**What they're really testing:** Whether you understand how EF Core's change tracker already implements this pattern, and why the explicit wrapper exists — testability and coordination, not raw functionality.

**Common question form:** *"What is the unit of work pattern and how does it relate to the repository pattern?"* or *"How do you ensure two repository operations are committed atomically?"*

**The depth signal:** A junior describes unit of work as "wrapping repositories to save together" without knowing why. A senior points out that `DbContext` *is* already a unit of work, explains that the pattern's real value is making it injectable and mockable in tests, identifies the shared-context requirement as the critical implementation detail, and knows the failure mode when repositories are resolved from DI independently instead of through the unit of work — silently breaking atomicity.

---

## Related Topics
- [[dotnet/pattern-repository.md]] — Unit of work solves the coordination problem that using multiple standalone repositories creates.
- [[dotnet/ef-transactions.md]] — Unit of work handles logical grouping of saves; explicit transactions handle isolation level and rollback — they layer on top of each other.
- [[dotnet/dbcontext-lifetime.md]] — The entire pattern depends on `DbContext` being Scoped correctly; a misconfigured lifetime silently breaks shared change tracking.
- [[system-design/clean-architecture.md]] — In clean architecture, `IUnitOfWork` lives in the application layer; the EF implementation lives in infrastructure — understanding the boundary explains why the interface exists at all.

---

## Source
https://martinfowler.com/eaaCatalog/unitOfWork.html

---
*Last updated: 2026-03-24*