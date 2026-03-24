# Decorator Pattern

> A decorator wraps an existing object to add behavior before or after its methods, without changing the original class.

---

## When To Use It
Use it when you need to add cross-cutting behavior — logging, caching, retry, validation — to an existing implementation without modifying it. It's the right move when you have an interface and multiple implementations that all need the same extra behavior, and you don't want to duplicate that behavior in each one. Don't use it when you're only wrapping a single class and subclassing would be simpler — inheritance is fine when the hierarchy is stable and shallow.

---

## Core Concept
The trick is that a decorator implements the same interface as the thing it wraps, and takes that interface as a constructor argument. From the outside, callers can't tell the difference between the real implementation and the decorator — they both look like `IOrderRepository`. Inside, the decorator does its extra work (log, cache, measure time) and then calls through to the real thing. You can stack decorators: a caching decorator wraps a logging decorator wraps the real repository. Each layer adds one concern and passes the call down the chain. In .NET, this composes naturally with DI — you register the decorators in the right order and the container wires the chain automatically. Scrutor is the common library that makes this registration clean.

---

## The Code
```csharp
// 1. The interface and real implementation
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(int id);
    Task<List<Order>> GetPendingAsync();
}

public class OrderRepository : IOrderRepository
{
    private readonly AppDbContext _context;
    public OrderRepository(AppDbContext context) => _context = context;

    public Task<Order?> GetByIdAsync(int id) =>
        _context.Orders.AsNoTracking().FirstOrDefaultAsync(o => o.Id == id);

    public Task<List<Order>> GetPendingAsync() =>
        _context.Orders.Where(o => o.Status == OrderStatus.Pending)
            .AsNoTracking().ToListAsync();
}
```
```csharp
// 2. Logging decorator — wraps IOrderRepository, adds logging, calls through
public class LoggingOrderRepository : IOrderRepository
{
    private readonly IOrderRepository _inner;
    private readonly ILogger<LoggingOrderRepository> _logger;

    public LoggingOrderRepository(IOrderRepository inner,
        ILogger<LoggingOrderRepository> logger)
    {
        _inner = inner;
        _logger = logger;
    }

    public async Task<Order?> GetByIdAsync(int id)
    {
        _logger.LogInformation("Fetching order {Id}", id);
        var result = await _inner.GetByIdAsync(id);       // call through to real impl
        _logger.LogInformation("Order {Id} {Found}", id, result is null ? "not found" : "found");
        return result;
    }

    public Task<List<Order>> GetPendingAsync()
    {
        _logger.LogInformation("Fetching pending orders");
        return _inner.GetPendingAsync();
    }
}
```
```csharp
// 3. Caching decorator — stacks on top of the logging decorator
public class CachingOrderRepository : IOrderRepository
{
    private readonly IOrderRepository _inner;
    private readonly IMemoryCache _cache;

    public CachingOrderRepository(IOrderRepository inner, IMemoryCache cache)
    {
        _inner = inner;
        _cache = cache;
    }

    public async Task<Order?> GetByIdAsync(int id)
    {
        var key = $"order:{id}";
        if (_cache.TryGetValue(key, out Order? cached))
            return cached;

        var order = await _inner.GetByIdAsync(id);
        if (order is not null)
            _cache.Set(key, order, TimeSpan.FromMinutes(5));  // cache hit for 5 min
        return order;
    }

    public Task<List<Order>> GetPendingAsync() =>
        _inner.GetPendingAsync();                             // no caching for list queries
}
```
```csharp
// 4. DI registration with Scrutor — decorators applied outermost-last
// dotnet add package Scrutor

builder.Services.AddScoped<IOrderRepository, OrderRepository>();

builder.Services.Decorate<IOrderRepository, LoggingOrderRepository>();  // wraps real impl
builder.Services.Decorate<IOrderRepository, CachingOrderRepository>();  // wraps logging impl

// Resolution order: CachingOrderRepository → LoggingOrderRepository → OrderRepository
```
```csharp
// 5. Manual DI registration without Scrutor
builder.Services.AddScoped<OrderRepository>();                // register concrete directly

builder.Services.AddScoped<IOrderRepository>(sp =>
{
    var inner = new LoggingOrderRepository(
        sp.GetRequiredService<OrderRepository>(),
        sp.GetRequiredService<ILogger<LoggingOrderRepository>>());

    return new CachingOrderRepository(
        inner,
        sp.GetRequiredService<IMemoryCache>());
});
```

---

## Gotchas
- **Scrutor's `Decorate()` order is innermost-first.** The first `Decorate()` call wraps the original registration; the second wraps the result of the first. So the last-registered decorator is the outermost one — the first to receive a call. Getting this backwards means your cache sits inside your logger and you log every cache miss twice.
- **Every method on the interface must be implemented in every decorator.** If `IOrderRepository` has six methods and your caching decorator only caches `GetByIdAsync`, you still have to implement the other five as pass-throughs. Forgetting one means the method silently does nothing or throws `NotImplementedException`.
- **Decorators break if you inject the concrete type directly instead of the interface.** If any class takes `OrderRepository` (the concrete) in its constructor, Scrutor's decoration chain is bypassed entirely — the logging and caching wrappers are never involved.
- **Stacking too many decorators makes stack traces unreadable.** Each layer adds a frame. Five decorators on a hot path means five extra frames in every exception, and debugging which layer caused a failure becomes non-trivial. Keep chains short and focused.
- **Caching decorators must be invalidated explicitly when writes happen.** If `PlaceOrderAsync()` lives on a different service and doesn't touch the cache, `GetByIdAsync()` will return stale data until the TTL expires. The decorator has no visibility into writes it doesn't intercept.

---

## Interview Angle
**What they're really testing:** Understanding of interface-based composition vs inheritance, and how cross-cutting concerns can be layered without modifying existing code.

**Common question form:** *"How would you add caching or logging to a repository without changing its implementation?"* or *"What's the difference between the decorator pattern and inheritance?"*

**The depth signal:** A junior answers "wrap the class in another class" and sketches a single decorator. A senior explains why the wrapped type must be injected as the *interface* (not the concrete), how DI registration order determines call order in a chain, the tradeoff between Scrutor and manual factory registration, and the specific failure mode of stale cache when writes bypass the decorator — then mentions that for cross-cutting concerns that need to span multiple interfaces, a pipeline behavior (MediatR) is often a cleaner fit than stacking decorators on every repository.

---

## Related Topics
- [[dotnet/pattern-repository.md]] — Repositories are the most common target for decorators in .NET; logging and caching decorators sit naturally on top of `IRepository` implementations.
- [[dotnet/pattern-mediator.md]] — MediatR pipeline behaviors solve the same cross-cutting concern problem as decorators but at the command/query level — worth knowing both and when each is the right fit.
- [[dotnet/dependency-injection.md]] — The decorator pattern depends entirely on interface-based DI; understanding lifetime scopes prevents captive dependency bugs in decorator chains.
- [[dotnet/ef-performance.md]] — Caching decorators are a common optimization layer on top of EF repositories; the cache TTL and invalidation strategy directly affect query behavior.

---

## Source
https://refactoring.guru/design-patterns/decorator

---
*Last updated: 2026-03-24*