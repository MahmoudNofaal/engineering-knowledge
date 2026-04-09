# Unit of Work Pattern

> A unit of work tracks all the changes you make across multiple repositories and flushes them to the database in a single `SaveChanges()` call.

---

## When To Use It

Use it when you have multiple repositories that need to commit their changes together atomically — e.g., creating an order and decrementing inventory in one operation. It's the answer to the problem the repository pattern creates: if each repository owns its own `SaveChanges()`, you can't coordinate them. Skip it in simple applications with a single repository per operation, or when you're letting EF Core's `DbContext` serve as the implicit unit of work directly.

---

## Core Concept

**One sentence for the interview:** EF Core's DbContext is already a unit of work — this pattern just makes that explicit and injectable.

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
// 2. EF Core implementation — .NET 8 primary constructor
// All repositories share the same DbContext instance
public class UnitOfWork(AppDbContext context) : IUnitOfWork
{
    public IOrderRepository Orders { get; } = new OrderRepository(context);
    public IInventoryRepository Inventory { get; } = new InventoryRepository(context);

    public Task<int> SaveChangesAsync() =>
        context.SaveChangesAsync();

    public async ValueTask DisposeAsync() =>
        await context.DisposeAsync();
}
```

```csharp
// 3. DI registration
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(connectionString));
```

```csharp
// 4. Service using IUnitOfWork — one save covers both repositories
public class OrderService(IUnitOfWork uow)
{
    public async Task PlaceOrderAsync(CreateOrderDto dto)
    {
        var order = new Order { CustomerId = dto.CustomerId, Total = dto.Total };
        await uow.Orders.AddAsync(order);

        var item = await uow.Inventory.GetByProductIdAsync(dto.ProductId);
        item.Stock -= dto.Quantity;                  // EF tracks this change automatically

        await uow.SaveChangesAsync();               // one commit, both changes persisted
    }
}
```

```csharp
// 5. Wrapping in an explicit transaction — for when you need isolation level control
public class OrderService(IUnitOfWork uow, AppDbContext context)
{
    public async Task PlaceOrderWithTransactionAsync(CreateOrderDto dto)
    {
        await using var tx = await context.Database.BeginTransactionAsync(
            IsolationLevel.ReadCommitted);           // begin BEFORE any repo calls

        try
        {
            var order = new Order { CustomerId = dto.CustomerId, Total = dto.Total };
            await uow.Orders.AddAsync(order);

            var item = await uow.Inventory.GetByProductIdAsync(dto.ProductId);
            item.Stock -= dto.Quantity;

            await uow.SaveChangesAsync();            // flush changes within the transaction
            await tx.CommitAsync();                  // commit separately from SaveChanges
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }
    }
}
```

```csharp
// 6. Fake unit of work for unit tests — .NET 8 primary constructor
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

- **Disposing the unit of work before calling `SaveChangesAsync()` silently loses all changes.** If `DisposeAsync()` is called — e.g., the `using` block exits early due to an exception path you didn't anticipate — any uncommitted changes tracked by the `DbContext` are gone. Always ensure `SaveChangesAsync()` is called before the `UnitOfWork` goes out of scope.

- **EF Core already IS a unit of work — the pattern adds testability, not new capability.** Saying in an interview that `IUnitOfWork` enables "atomic commits" that EF Core otherwise can't do is incorrect. EF Core's `SaveChanges()` already commits everything in one transaction. The interface exists so tests can inject a `FakeUnitOfWork`. Framing it otherwise is a signal you don't understand what EF Core does out of the box.

---

## Interview Angle

**What they're really testing:** Whether you understand how EF Core's change tracker already implements this pattern, and why the explicit wrapper exists — testability and coordination, not raw functionality.

**Common question form:** *"What is the unit of work pattern and how does it relate to the repository pattern?"* or *"How do you ensure two repository operations are committed atomically?"*

**The depth signal:** A junior describes unit of work as "wrapping repositories to save together" without knowing why. A senior points out that `DbContext` *is* already a unit of work, explains that the pattern's real value is making it injectable and mockable in tests, identifies the shared-context requirement as the critical implementation detail, and knows the failure mode when repositories are resolved from DI independently instead of through the unit of work — silently breaking atomicity.

**Follow-up the interviewer asks next:** *"How does the unit of work pattern relate to distributed transactions across multiple databases?"*

The honest answer: it doesn't. The unit of work pattern coordinates commits within a single `DbContext` — a single database connection. If you have two databases, two microservices, or two different providers (e.g., SQL Server and MongoDB), `SaveChangesAsync()` on a single `DbContext` can't span them. Distributed atomicity requires a different approach entirely: the Saga pattern (compensating transactions), the Outbox pattern (reliable event publishing after local commit), or a distributed transaction coordinator like MSDTC — which is rarely the right answer in modern systems. Knowing where the pattern's guarantees end is as important as knowing how it works.

---

## Related Topics

- [[dotnet/pattern/pattern-repository.md]] — Unit of work solves the coordination problem that using multiple standalone repositories creates.
- [[dotnet/ef/ef-transactions.md]] — Unit of work handles logical grouping of saves; explicit transactions handle isolation level and rollback — they layer on top of each other.
- [[dotnet/pattern/dependency-injection.md]] — The entire pattern depends on `DbContext` being Scoped correctly; a misconfigured lifetime silently breaks shared change tracking.
- [[dotnet/pattern/pattern-clean-architecture.md]] — In clean architecture, `IUnitOfWork` lives in the application layer; the EF implementation lives in infrastructure — understanding the boundary explains why the interface exists at all.

---

## Source

https://martinfowler.com/eaaCatalog/unitOfWork.html

---

*Last updated: 2026-04-09*