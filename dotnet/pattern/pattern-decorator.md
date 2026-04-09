# Decorator Pattern

> A decorator wraps an existing object to add behavior before or after its methods, without changing the original class.

---

## When To Use It

Use it when you need to add cross-cutting behavior — logging, caching, retry, validation — to an existing implementation without modifying it. It's the right move when you have an interface and multiple implementations that all need the same extra behavior, and you don't want to duplicate that behavior in each one. Don't use it when you're only wrapping a single class and subclassing would be simpler — inheritance is fine when the hierarchy is stable and shallow.

---

## Core Concept

**One sentence for the interview:** A decorator implements the same interface as what it wraps, so callers can't tell the difference — they just get extra behavior transparently.

The trick is that a decorator implements the same interface as the thing it wraps, and takes that interface as a constructor argument. From the outside, callers can't tell the difference between the real implementation and the decorator — they both look like `IOrderRepository`. Inside, the decorator does its extra work (log, cache, measure time) and then calls through to the real thing. You can stack decorators: a caching decorator wraps a logging decorator wraps the real repository. Each layer adds one concern and passes the call down the chain. In .NET, this composes naturally with DI — you register the decorators in the right order and the container wires the chain automatically. Scrutor is the common library that makes this registration clean.

---

## The Code

```csharp
// 1. The interface and real implementation — .NET 8 primary constructor
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(int id);
    Task<List<Order>> GetPendingAsync();
}

public class OrderRepository(AppDbContext context) : IOrderRepository
{
    public Task<Order?> GetByIdAsync(int id) =>
        context.Orders.AsNoTracking().FirstOrDefaultAsync(o => o.Id == id);

    public Task<List<Order>> GetPendingAsync() =>
        context.Orders.Where(o => o.Status == OrderStatus.Pending)
            .AsNoTracking().ToListAsync();
}
```

```csharp
// 2. Logging decorator — wraps IOrderRepository, adds logging, calls through
public class LoggingOrderRepository(
    IOrderRepository inner,
    ILogger<LoggingOrderRepository> logger) : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(int id)
    {
        logger.LogInformation("Fetching order {Id}", id);
        var result = await inner.GetByIdAsync(id);        // call through to real impl
        logger.LogInformation("Order {Id} {Found}", id, result is null ? "not found" : "found");
        return result;
    }

    public Task<List<Order>> GetPendingAsync()
    {
        logger.LogInformation("Fetching pending orders");
        return inner.GetPendingAsync();
    }
}
```

```csharp
// 3. Caching decorator — stacks on top of the logging decorator
public class CachingOrderRepository(
    IOrderRepository inner,
    IMemoryCache cache) : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(int id)
    {
        var key = $"order:{id}";
        if (cache.TryGetValue(key, out Order? cached))
            return cached;

        var order = await inner.GetByIdAsync(id);
        if (order is not null)
            cache.Set(key, order, TimeSpan.FromMinutes(5));
        return order;
    }

    public Task<List<Order>> GetPendingAsync() =>
        inner.GetPendingAsync();                          // no caching for list queries
}
```

```csharp
// 4. Retry decorator — wraps an HTTP client call with Polly retry logic
public class RetryHttpOrderClient(IOrderRepository inner) : IOrderRepository
{
    private static readonly AsyncRetryPolicy _policy = Policy
        .Handle<HttpRequestException>()
        .WaitAndRetryAsync(3, attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt)));

    public Task<Order?> GetByIdAsync(int id) =>
        _policy.ExecuteAsync(() => inner.GetByIdAsync(id));

    public Task<List<Order>> GetPendingAsync() =>
        _policy.ExecuteAsync(() => inner.GetPendingAsync());
}
```

```csharp
// 5. DI registration with Scrutor — decorators applied outermost-last
// dotnet add package Scrutor

builder.Services.AddScoped<IOrderRepository, OrderRepository>();         // innermost: real impl
builder.Services.Decorate<IOrderRepository, LoggingOrderRepository>();   // wraps real impl
builder.Services.Decorate<IOrderRepository, CachingOrderRepository>();   // wraps logging impl

// Resolution call chain (outermost → innermost):
// CachingOrderRepository → LoggingOrderRepository → OrderRepository

// The last Decorate() call is the outermost decorator — the first to receive a call.
// Think of it as wrapping: each Decorate() puts a new layer around whatever was there before.
```

```csharp
// 6. Manual DI registration without Scrutor
builder.Services.AddScoped<OrderRepository>();                           // register concrete

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

- **Decorator vs middleware — same idea, different scope.** ASP.NET Core middleware is the decorator pattern applied to the HTTP pipeline globally. A decorator on `IOrderRepository` is scoped to one interface. If you need the behavior for every request regardless of which repository is called, middleware is the right tool. If you need it for one specific interface, a decorator is cleaner.

- **Scrutor `Decorate()` on Transient vs Scoped — mismatched lifetimes cause captive dependency bugs.** If the inner implementation is Scoped and the decorator is accidentally registered as Singleton (or vice versa), the lifetime mismatch captures a short-lived instance inside a long-lived one. Always ensure decorator and inner implementation share the same lifetime.

---

## Interview Angle

**What they're really testing:** Understanding of interface-based composition vs inheritance, and how cross-cutting concerns can be layered without modifying existing code.

**Common question form:** *"How would you add caching or logging to a repository without changing its implementation?"* or *"What's the difference between the decorator pattern and inheritance?"*

**The depth signal:** A junior answers "wrap the class in another class" and sketches a single decorator. A senior explains why the wrapped type must be injected as the *interface* (not the concrete), how DI registration order determines call order in a chain, the tradeoff between Scrutor and manual factory registration, and the specific failure mode of stale cache when writes bypass the decorator — then mentions that for cross-cutting concerns that need to span multiple interfaces, a pipeline behavior (MediatR) is often a cleaner fit than stacking decorators on every repository.

**Follow-up the interviewer asks next:** *"When would you use a MediatR pipeline behavior instead of a decorator?"*

Use a pipeline behavior when the cross-cutting concern applies to all commands or queries regardless of which repository or service they use — validation, logging every request, performance timing, exception handling. The behavior sits at the use-case boundary and runs once per request regardless of how many repositories are called internally. Use a decorator when the concern is specific to one interface — caching `IOrderRepository.GetByIdAsync()` but not every other service method in the system. The two approaches aren't mutually exclusive: logging at the behavior level (coarse-grained, per command) and caching at the decorator level (fine-grained, per method) compose naturally.

---

## Related Topics

- [[dotnet/pattern/pattern-repository.md]] — Repositories are the most common target for decorators in .NET; logging and caching decorators sit naturally on top of `IRepository` implementations.
- [[dotnet/pattern/pattern-mediator.md]] — MediatR pipeline behaviors solve the same cross-cutting concern problem as decorators but at the command/query level — worth knowing both and when each is the right fit.
- [[dotnet/pattern/dependency-injection.md]] — The decorator pattern depends entirely on interface-based DI; understanding lifetime scopes prevents captive dependency bugs in decorator chains.
- [[dotnet/ef/ef-performance.md]] — Caching decorators are a common optimization layer on top of EF repositories; the cache TTL and invalidation strategy directly affect query behavior.

---

## Source

https://refactoring.guru/design-patterns/decorator

---

*Last updated: 2026-04-09*