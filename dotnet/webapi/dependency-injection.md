# Dependency Injection

> A design pattern where a class receives its dependencies from outside rather than creating them itself — and in .NET, the built-in IoC container manages the creation and lifetime of those dependencies for you.

---

## Quick Reference

| | |
|---|---|
| **What it is** | IoC container that creates and injects dependencies automatically |
| **Use when** | Any class that needs a service — which is everywhere in .NET |
| **Avoid when** | Static utility classes with no external state or I/O |
| **Introduced** | ASP.NET Core 1.0 (built-in); `Keyed services` added .NET 8 |
| **Namespace** | `Microsoft.Extensions.DependencyInjection` |
| **Key types** | `IServiceCollection`, `IServiceProvider`, `IServiceScope`, `ServiceDescriptor` |

---

## When To Use It

Use it everywhere in .NET — it's the default way the framework is designed. Any time a class needs a service (a database context, a logger, an HTTP client, a custom service), you inject it through the constructor rather than instantiating it with `new` inside the class. The one place you *don't* use constructor injection is static classes or places where the DI container can't reach — in those cases you may need to use the service locator pattern directly via `IServiceProvider`, but treat that as a last resort. The service locator pattern hides dependencies and makes classes harder to test.

---

## Core Concept

A class should not be responsible for finding or building what it needs. It should just declare what it needs, and something else — the container — handles the rest. This does two things: it makes your class easier to test (you can swap real dependencies for fakes), and it makes your system easier to change (you can swap implementations without touching consumers). In .NET, you register services in `Program.cs` and the framework injects them automatically into constructors across controllers, services, middleware — anything it manages. The three lifetimes (Singleton, Scoped, Transient) control how long a resolved instance lives and whether it's shared across requests.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | Built-in DI container introduced; `AddSingleton`, `AddScoped`, `AddTransient` |
| ASP.NET Core 2.1 | `IServiceProviderFactory` introduced; Autofac integration improved |
| .NET 6 | `WebApplication.CreateBuilder` simplifies service registration in `Program.cs` |
| .NET 8 | **Keyed services** — `AddKeyedSingleton<T>("key")` / `[FromKeyedServices]` attribute |
| .NET 8 | `IServiceProviderIsService` interface added for runtime service existence checks |

*Before .NET 8, registering multiple implementations of the same interface required workarounds (factory delegates or named registration via third-party containers like Autofac). Keyed services solve this natively.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Singleton resolution | O(1) after first creation | Cached after first resolve; effectively free |
| Scoped resolution | O(1) per scope | One instance per scope; resolved from scope cache |
| Transient resolution | O(1) | New instance each time; cost is constructor execution |
| Open generic resolution | O(1) | Resolved at first use and cached per closed type |

**Allocation behaviour:** Singleton services allocate once for the app lifetime. Scoped services allocate once per request. Transient services allocate on every `GetService<T>()` call — overusing transient for heavy objects is a hidden allocation source. The container itself uses pooled internal structures and is not a significant allocator after warmup.

**Benchmark notes:** DI resolution overhead is typically 50–200 ns per resolve — negligible compared to any I/O. The main DI-related performance concern is not resolution speed but **lifetime mistakes**: a transient `DbContext` creates a new connection on every resolve; a scoped service captured in a singleton holds resources for the app lifetime.

---

## The Code

**Define the interface and implementation**
```csharp
// Always depend on an interface, not a concrete class.
// This is what makes the class testable and swappable.
public interface IOrderService
{
    Task<Order?> GetOrderAsync(int id);
    Task<Order> CreateAsync(CreateOrderRequest req);
}

public class OrderService : IOrderService
{
    private readonly AppDbContext _db;
    private readonly ILogger<OrderService> _logger;

    // OrderService itself uses DI — it receives its dependencies from the container
    public OrderService(AppDbContext db, ILogger<OrderService> logger)
    {
        _db     = db;
        _logger = logger;
    }

    public async Task<Order?> GetOrderAsync(int id)
        => await _db.Orders.FindAsync(id);

    public async Task<Order> CreateAsync(CreateOrderRequest req)
    {
        var order = new Order { /* map from req */ };
        _db.Orders.Add(order);
        await _db.SaveChangesAsync();
        _logger.LogInformation("Order {OrderId} created", order.Id);
        return order;
    }
}
```

**Register in Program.cs — choosing the right lifetime**
```csharp
// SCOPED — one instance per HTTP request. Right choice for DbContext, unit-of-work.
builder.Services.AddScoped<IOrderService, OrderService>();

// TRANSIENT — new instance every resolve. Right for lightweight stateless services.
builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();

// SINGLETON — one instance for the app lifetime. Right for caches, config wrappers.
builder.Services.AddSingleton<IFeatureFlags, FeatureFlagService>();

// DbContext shorthand — registers as Scoped automatically
builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseSqlServer(builder.Configuration.GetConnectionString("Default")));
```

**Inject into a controller**
```csharp
[ApiController]
[Route("api/orders")]
public class OrdersController : ControllerBase
{
    private readonly IOrderService _orderService;

    // The container sees this constructor, resolves IOrderService, injects it.
    // You never call 'new OrderService()' yourself.
    public OrdersController(IOrderService orderService)
    {
        _orderService = orderService;
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(int id)
    {
        var order = await _orderService.GetOrderAsync(id);
        return order is null ? NotFound() : Ok(order);
    }
}
```

**Resolving scoped services from a singleton (IServiceScopeFactory)**
```csharp
// Singleton services cannot directly inject scoped services.
// Use IServiceScopeFactory to create a scope manually.
public class ReportCacheService : IHostedService
{
    private readonly IServiceScopeFactory _scopeFactory;

    public ReportCacheService(IServiceScopeFactory scopeFactory)
        => _scopeFactory = scopeFactory;

    public async Task StartAsync(CancellationToken ct)
    {
        await using var scope   = _scopeFactory.CreateAsyncScope();
        var reportService       = scope.ServiceProvider.GetRequiredService<IReportService>();
        await reportService.WarmCacheAsync(ct);
    }

    public Task StopAsync(CancellationToken ct) => Task.CompletedTask;
}
```

**Keyed services (.NET 8+) — multiple implementations of the same interface**
```csharp
// Register two implementations under different keys
builder.Services.AddKeyedScoped<IPaymentProcessor, StripeProcessor>("stripe");
builder.Services.AddKeyedScoped<IPaymentProcessor, PayPalProcessor>("paypal");

// Resolve by key in a controller or service
public class CheckoutService(
    [FromKeyedServices("stripe")] IPaymentProcessor stripe,
    [FromKeyedServices("paypal")] IPaymentProcessor paypal)
{
    public Task ProcessAsync(Order order, string gateway) =>
        gateway == "stripe" ? stripe.ChargeAsync(order) : paypal.ChargeAsync(order);
}
```

**Testing — this is WHY you injected the interface**
```csharp
// In your test project, swap the real service for a fake.
// No database. No HTTP stack. Pure, fast unit test.
public class OrdersControllerTests
{
    [Fact]
    public async Task Get_ReturnsNotFound_WhenOrderDoesNotExist()
    {
        var mockService = new Mock<IOrderService>();
        mockService.Setup(s => s.GetOrderAsync(99)).ReturnsAsync((Order?)null);

        var controller = new OrdersController(mockService.Object);
        var result     = await controller.Get(99);

        Assert.IsType<NotFoundResult>(result);
    }
}
```

---

## Real World Example

A multi-tenant SaaS API uses three different payment processors depending on the tenant's region. Before keyed services, this required a factory class. With .NET 8 keyed services, each processor is registered under its region key and resolved directly at the injection site.

```csharp
// Domain
public interface IPaymentProcessor
{
    Task<PaymentResult> ChargeAsync(decimal amount, string currency, string token);
}

public class StripeProcessor(IOptions<StripeSettings> opts, ILogger<StripeProcessor> logger)
    : IPaymentProcessor
{
    public async Task<PaymentResult> ChargeAsync(decimal amount, string currency, string token)
    {
        logger.LogInformation("Charging {Amount} {Currency} via Stripe", amount, currency);
        // Real Stripe SDK call here
        return new PaymentResult(Success: true, TransactionId: Guid.NewGuid().ToString());
    }
}

public class AdyenProcessor(IOptions<AdyenSettings> opts, ILogger<AdyenProcessor> logger)
    : IPaymentProcessor
{
    public async Task<PaymentResult> ChargeAsync(decimal amount, string currency, string token)
    {
        logger.LogInformation("Charging {Amount} {Currency} via Adyen", amount, currency);
        return new PaymentResult(Success: true, TransactionId: Guid.NewGuid().ToString());
    }
}

// Registration
builder.Services.AddKeyedScoped<IPaymentProcessor, StripeProcessor>("stripe");
builder.Services.AddKeyedScoped<IPaymentProcessor, AdyenProcessor>("adyen");

// Service that uses the right processor based on tenant region
public class OrderPaymentService(IServiceProvider sp)
{
    public async Task<PaymentResult> ProcessAsync(Order order, Tenant tenant)
    {
        var processorKey = tenant.Region == "EU" ? "adyen" : "stripe";
        var processor    = sp.GetRequiredKeyedService<IPaymentProcessor>(processorKey);
        return await processor.ChargeAsync(order.Total, order.Currency, order.PaymentToken);
    }
}

// Program.cs
builder.Services.AddScoped<OrderPaymentService>();
```

*The key insight: the service layer selects the right payment processor by key at runtime based on tenant data — without knowing about Stripe or Adyen concretely. Adding a new processor is a registration change, not a code change in `OrderPaymentService`.*

---

## Common Misconceptions

**"Transient is always safe because you get a fresh instance every time."**
Transient services are only safe if they're stateless and cheap to construct. Registering `DbContext` as Transient means a new database connection on every `GetService<T>()` call — including multiple times within a single controller. Transient `DbContext` is one of the most common sources of "too many open connections" bugs in production.

**"I can inject any service lifetime into a Singleton."**
You can only safely inject services with an equal or longer lifetime into a Singleton. Injecting Scoped or Transient services into a Singleton captures them at construction time — they live for the app's entire lifetime, holding whatever state, connections, or resources they had at first resolve. .NET's built-in container throws a `InvalidOperationException` for this in Development, but only if scope validation is enabled. Always check: if you're injecting into a Singleton, the dependency must also be Singleton.

**"The service locator pattern and DI are the same thing."**
DI injects dependencies at construction time — the class declares what it needs. The service locator pattern calls `serviceProvider.GetService<T>()` at runtime inside the class body — hiding the dependency from the constructor. Service locator makes classes harder to test (you must configure the provider in tests), hides the dependency graph, and is the anti-pattern DI was designed to replace. Use it only at the composition root (`Program.cs`) or in infrastructure code like middleware factories.

```csharp
// SERVICE LOCATOR — avoid in business logic
public class OrderService(IServiceProvider sp)
{
    public void Process() {
        var db = sp.GetService<AppDbContext>();  // hidden dependency
    }
}

// DI — correct
public class OrderService(AppDbContext db)       // explicit, testable
{
    public void Process() { /* use db */ }
}
```

---

## Gotchas

- **Captive dependency problem.** Registering a `Singleton` that depends on a `Scoped` service causes the Scoped service to live as long as the Singleton — meaning it outlives a request and can hold stale data or open connections. .NET will throw a `InvalidOperationException` in Development with scope validation enabled, but **not always in Production**. Always check: if a Singleton needs something, that something must also be Singleton or resolved via `IServiceScopeFactory`.

- **Registering concrete types directly.** `AddScoped<OrderService>()` instead of `AddScoped<IOrderService, OrderService>()` means you can only inject `OrderService`, not `IOrderService`. Your controller then depends on a concrete class, which kills testability and violates the Dependency Inversion Principle.

- **Multiple registrations of the same interface — last registration wins for `GetService<T>`.** If you call `AddScoped<IMyService, ImplA>()` and then `AddScoped<IMyService, ImplB>()`, injecting `IMyService` gives you `ImplB`. But `GetServices<IMyService>()` returns both. If you need multiple implementations, use keyed services (.NET 8) or inject `IEnumerable<IMyService>` for all registrations.

- **Over-injecting.** If a constructor has 6–8 parameters, the class is doing too much. DI makes this visible — treat it as a signal to split the class, not just a cosmetic problem. Large constructors are a code smell that DI surfaces clearly.

- **`GetRequiredService<T>()` vs `GetService<T>()`.** `GetService<T>()` returns `null` if the service isn't registered. `GetRequiredService<T>()` throws `InvalidOperationException`. In application code, always use `GetRequiredService` — a missing registration is a configuration bug that should fail loudly, not silently return null and crash later with a `NullReferenceException`.

---

## Interview Angle

**What they're really testing:** Whether you understand *why* DI exists (inversion of control, loose coupling, testability) — not just that you know how to wire it up in .NET. And whether you can reason about the captive dependency problem without looking it up.

**Common question forms:**
- "What is Dependency Injection and why do we use it?"
- "What's the difference between AddScoped, AddTransient, and AddSingleton?"
- "How would you test a class that has a database dependency?"
- "What is the captive dependency problem?"

**The depth signal:** A junior names the three lifetimes and says DI makes code "cleaner." A senior explains the *captive dependency problem* by example, distinguishes DI from the service locator anti-pattern, explains that `IServiceScopeFactory` is the correct pattern for resolving scoped services from singletons (background services, hosted services), and understands that `IServiceCollection` is just a list of `ServiceDescriptor` objects — the actual container is built when `builder.Build()` is called and becomes an `IServiceProvider`. They also know that .NET's built-in container intentionally lacks some features (interceptors, named registrations pre-.NET 8) and when to reach for Autofac or Scrutor instead.

**Follow-up questions to expect:**
- "How do you register multiple implementations of the same interface?"
- "How do you inject a service into middleware?"
- "When would you use IOptions vs IOptionsMonitor?"

---

## Related Topics

- [[dotnet/webapi/middleware-pipeline.md]] — middleware constructors use DI for singleton dependencies; scoped services must go in `InvokeAsync` parameters, not the constructor
- [[dotnet/webapi/webapi-background-services.md]] — background services are singletons; the `IServiceScopeFactory` pattern is mandatory for accessing scoped services like `DbContext`
- [[dotnet/webapi/webapi-configuration.md]] — `IOptions<T>`, `IOptionsMonitor<T>`, and `IOptionsSnapshot<T>` are all DI-registered services; choosing the right one depends on singleton vs scoped context
- [[dotnet/pattern/solid-principles.md]] — DI is the practical implementation of the Dependency Inversion Principle (the D in SOLID); understanding the principle explains why constructor injection over concrete types is wrong

---

## Source

https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection

---
*Last updated: 2026-04-10*