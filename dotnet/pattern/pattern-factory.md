# Factory Pattern

> A factory is an object or method whose only job is to create other objects, so the caller doesn't need to know how construction works.

---

## When To Use It

Use it when object creation is complex enough that putting it inline at the call site would be a distraction — multiple constructor arguments, conditional branching to pick a concrete type, or setup steps that must happen in a specific order. It's also the right move when you need to return an interface or abstract type and hide which concrete class was actually instantiated. Don't use it for simple `new Foo()` calls — adding a factory there is ceremony with no payoff.

---

## Core Concept

**One sentence for the interview:** A factory moves the construction decision out of the consumer so the consumer only knows the interface, not the implementation.

The problem factories solve is that `new` is a hard dependency. When you write `new SqlOrderRepository()` inside a service, that service is now locked to that implementation forever — you can't substitute it in tests or swap it out without editing the service. A factory moves the construction decision out of the consumer. The consumer asks for an `IOrderRepository`; the factory decides which concrete type to build and how. There are four common shapes in .NET: a static factory method on the class itself (simple, no DI needed), a factory class registered in the DI container (full DI support, injectable), a factory delegate (`Func<T>`) registered directly in DI (lightest weight, good for deferred or repeated creation), and .NET 8 keyed services (built-in alternative to dictionary factories). The right one depends on how much complexity you're hiding and whether the factory itself has dependencies.

---

## The Code

```csharp
// 1. Static factory method — construction logic lives on the class
public class ConnectionString
{
    public string Value { get; }

    private ConnectionString(string value) => Value = value; // private ctor forces factory use

    public static ConnectionString FromEnvironment() =>
        new(Environment.GetEnvironmentVariable("DB_CONNECTION")
            ?? throw new InvalidOperationException("DB_CONNECTION not set"));

    public static ConnectionString FromConfig(IConfiguration config) =>
        new(config.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Default connection string missing"));
}
```

```csharp
// 2. Factory interface + implementation — for factories that have their own dependencies
// .NET 8 primary constructor
public interface INotificationSenderFactory
{
    INotificationSender Create(string channel);  // "email" | "sms" | "push"
}

public class NotificationSenderFactory(IEmailService email, ISmsService sms)
    : INotificationSenderFactory
{
    public INotificationSender Create(string channel) => channel switch
    {
        "email" => new EmailNotificationSender(email),
        "sms"   => new SmsNotificationSender(sms),
        _       => throw new ArgumentException($"Unknown channel: {channel}")
    };
}

// Registration
builder.Services.AddScoped<INotificationSenderFactory, NotificationSenderFactory>();
```

```csharp
// 3. Func<T> factory delegate — lightweight, for deferred or repeated creation
builder.Services.AddTransient<IOrderRepository, OrderRepository>();
builder.Services.AddSingleton<Func<IOrderRepository>>(sp =>
    () => sp.GetRequiredService<IOrderRepository>()); // resolves a fresh instance each call

// Consumer — holds a factory, not an instance
public class OrderProcessor(Func<IOrderRepository> repoFactory)
{
    public async Task ProcessAsync(int orderId)
    {
        var repo = repoFactory();                    // create a fresh repo per operation
        var order = await repo.GetByIdAsync(orderId);
        // ...
    }
}
```

```csharp
// 4. Generic factory — when you need to create many types with the same pattern
public interface IHandlerFactory
{
    THandler Create<THandler>() where THandler : class;
}

public class HandlerFactory(IServiceProvider sp) : IHandlerFactory
{
    public THandler Create<THandler>() where THandler : class =>
        sp.GetRequiredService<THandler>();           // service locator — acceptable inside a factory
}
```

```csharp
// 5. .NET 8 keyed services — built-in alternative to switch/dictionary factory
builder.Services.AddKeyedScoped<INotificationSender, EmailNotificationSender>("email");
builder.Services.AddKeyedScoped<INotificationSender, SmsNotificationSender>("sms");
builder.Services.AddKeyedScoped<INotificationSender, PushNotificationSender>("push");

// Resolve by key — no factory class, no switch, no dictionary
public class NotificationService(IServiceProvider sp)
{
    public INotificationSender GetSender(string channel) =>
        sp.GetRequiredKeyedService<INotificationSender>(channel);
}

// Or inject a specific keyed implementation directly
public class OrderService([FromKeyedServices("email")] INotificationSender emailSender)
{
    // emailSender is specifically EmailNotificationSender — resolved by key at composition root
}
```

```csharp
// 6. Abstract Factory — families of related objects
// Use when you need to swap entire groups of related implementations together
public interface IDbProviderFactory
{
    IOrderRepository CreateOrderRepository();
    IInventoryRepository CreateInventoryRepository();
}

public class SqlServerDbProviderFactory(SqlServerDbContext context) : IDbProviderFactory
{
    public IOrderRepository CreateOrderRepository() => new SqlOrderRepository(context);
    public IInventoryRepository CreateInventoryRepository() => new SqlInventoryRepository(context);
}

public class PostgresDbProviderFactory(PostgresDbContext context) : IDbProviderFactory
{
    public IOrderRepository CreateOrderRepository() => new PostgresOrderRepository(context);
    public IInventoryRepository CreateInventoryRepository() => new PostgresInventoryRepository(context);
}

// Registration — swap the entire provider family by changing one line
builder.Services.AddScoped<IDbProviderFactory, SqlServerDbProviderFactory>();
```

---

## Gotchas

- **A factory that takes `IServiceProvider` directly is a service locator — acceptable only inside the factory itself.** Injecting `IServiceProvider` into a service or handler so you can call `GetRequiredService<T>()` is a hidden dependency smell. Factories are the one place this is legitimate because their whole job is resolving types.

- **Static factory methods can't be mocked.** If you use a static factory in production code, tests can't substitute a fake. Reserve static factories for value objects and configuration parsing — not for anything with side effects or external dependencies.

- **Registering the factory as Singleton when it creates Scoped services causes captive dependencies.** If `Func<IOrderRepository>` is registered as Singleton but `IOrderRepository` is Scoped, the factory captures the root scope and every call returns the same instance, leaking state across requests. The `Func<T>` must resolve from the *request* scope, not the root. Use `IServiceScopeFactory` if you need to create scoped instances from a singleton context.

- **Forgetting to register the concrete types the factory creates.** If your factory calls `sp.GetRequiredService<EmailNotificationSender>()` but `EmailNotificationSender` was never registered in DI, you get a runtime `InvalidOperationException` — not a compile-time error.

- **Switch-based factories break Open/Closed if types are added frequently.** A `channel switch` that grows a new case every time a new sender is added becomes a maintenance burden. At that point, use keyed services (.NET 8) or a dictionary-based registry (`Dictionary<string, Func<INotificationSender>>`) populated at startup instead.

- **Thread safety in Singleton factories.** If a Singleton factory holds mutable state (e.g., a cache of built instances), concurrent requests can produce race conditions. Either make factory state immutable after construction, use `ConcurrentDictionary`, or make the factory itself Scoped.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between construction complexity and business logic, and how factories interact with dependency injection.

**Common question form:** *"When would you use a factory pattern?"* or *"How do you create objects conditionally in a DI-based application?"*

**The depth signal:** A junior describes a factory as "a class that creates objects" and gives a textbook example. A senior explains the concrete problem it solves in a DI context — you can't inject a conditional type directly, so a factory makes the runtime decision — and knows the four shapes (static method, factory class, `Func<T>` delegate, keyed services), when each applies, and the captive dependency trap when factory and product have mismatched lifetimes. They also know when *not* to use it: simple construction that `new` handles cleanly doesn't need a factory.

**Follow-up the interviewer asks next:** *"What is the difference between a Factory Method and an Abstract Factory?"*

Factory Method: one interface, one product, one creation method — the concrete type returned varies by implementation. The caller gets an `INotificationSender` and doesn't know if it's email or SMS. Abstract Factory: a family of related creation methods grouped behind one interface — swapping the factory swaps the entire family of products at once. Use Abstract Factory when you need `IOrderRepository` *and* `IInventoryRepository` *and* `IShippingRepository` to all come from the same provider family (SQL Server vs Postgres vs in-memory) and you want to swap them all in one registration change.

---

## Related Topics

- [[dotnet/pattern/dependency-injection.md]] — Factories exist to fill the gap where DI can't resolve a type at registration time; understanding DI lifetimes is essential to using factories correctly.
- [[dotnet/pattern/pattern-strategy.md]] — Switch-based factories commonly produce strategy objects; the two patterns are frequently used together.
- [[dotnet/pattern/pattern-repository.md]] — Repositories are a common thing factories create, especially when the concrete implementation depends on runtime context.
- [[dotnet/pattern/pattern-cqrs.md]] — MediatR's handler resolution is itself a factory — understanding both clarifies when to use explicit factories vs convention-based dispatch.

---

## Source

https://refactoring.guru/design-patterns/factory-method

---

*Last updated: 2026-04-09*