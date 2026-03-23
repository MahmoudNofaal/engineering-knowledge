# Dependency Injection

> A design pattern where a class receives its dependencies from outside rather than creating them itself — and in .NET, the built-in IoC container manages the creation and lifetime of those dependencies for you.

---

## When To Use It

Use it everywhere in .NET — it's the default way the framework is designed. Any time a class needs a service (a database context, a logger, an HTTP client, a custom service), you inject it through the constructor rather than instantiating it with `new` inside the class. The one place you *don't* use constructor injection is static classes or places where the DI container can't reach — in those cases you may need to use the service locator pattern directly, but treat that as a last resort.

---

## Core Concept

A class should not be responsible for finding or building what it needs. It should just declare what it needs, and something else — the container — handles the rest. This does two things: it makes your class easier to test (you can swap real dependencies for fakes), and it makes your system easier to change (you can swap implementations without touching consumers). In .NET, you register services in `Program.cs` and the framework injects them automatically into constructors across controllers, services, middleware — anything it manages.

---

## The Code

### 1. Define the interface and implementation

```csharp
// Always depend on an interface, not a concrete class.
// This is what makes the class testable and swappable.
public interface IOrderService
{
    Task<Order> GetOrderAsync(int id);
}

public class OrderService : IOrderService
{
    private readonly AppDbContext _db;

    // OrderService itself uses DI — it receives AppDbContext from the container
    public OrderService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<Order> GetOrderAsync(int id)
        => await _db.Orders.FindAsync(id);
}
```

### 2. Register in Program.cs

```csharp
// Three lifetime options — choosing wrong here is the most common mistake
builder.Services.AddScoped<IOrderService, OrderService>();   // one per HTTP request
builder.Services.AddTransient<IEmailSender, EmailSender>();  // new instance every time
builder.Services.AddSingleton<IConfigProvider, ConfigProvider>(); // one for app lifetime
```

### 3. Inject into a controller

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

### 4. Testing — this is WHY you injected the interface

```csharp
// In your test project, swap the real service for a fake.
// No database needed. No HTTP stack. Pure, fast unit test.
public class OrdersControllerTests
{
    [Fact]
    public async Task Get_ReturnsNotFound_WhenOrderDoesNotExist()
    {
        var mockService = new Mock<IOrderService>();
        mockService.Setup(s => s.GetOrderAsync(99)).ReturnsAsync((Order?)null);

        var controller = new OrdersController(mockService.Object);
        var result = await controller.Get(99);

        Assert.IsType<NotFoundResult>(result);
    }
}
```

---

## Gotchas

- **Captive dependency problem:** registering a `Singleton` that depends on a `Scoped` service will cause the Scoped service to live as long as the Singleton — meaning it outlives a request and can hold stale data or connections. .NET will throw a runtime error in Development mode to catch this, but not always in Production. Always check: if a Singleton needs something, that something must also be Singleton.

- **Registering concrete types directly:** `AddScoped<OrderService>()` instead of `AddScoped<IOrderService, OrderService>()` means you can only inject `OrderService`, not `IOrderService`. Your controller then depends on a concrete class, which kills testability.

- **Over-injecting:** if a constructor has 6–8 parameters, the class is doing too much. DI makes this visible — treat it as a signal to split the class, not just a cosmetic problem.

- **Service locator anti-pattern:** calling `IServiceProvider.GetService<T>()` directly inside business logic hides dependencies, breaks testability, and defeats the point of DI. Use it only at the composition root (Program.cs or middleware).

---

## Interview Angle

**What they're really testing:** Whether you understand *why* DI exists (inversion of control, loose coupling, testability) — not just that you know how to wire it up in .NET.

**Common question form:** *"What is Dependency Injection and why do we use it?"* / *"What's the difference between AddScoped, AddTransient, and AddSingleton?"* / *"How would you test a class that has a database dependency?"*

**The depth signal:** A junior answer names the three lifetimes and says DI makes code "cleaner." A senior answer explains the *captive dependency problem*, talks about DI as an enabler for unit testing with mocks, explains the difference between the DI pattern and the service locator anti-pattern, and can describe what IoC (Inversion of Control) means at the principle level — that control over dependency creation is *inverted* from the class to the container.

---

## Related Topics

- [[dotnet/middleware-pipeline]] — middleware is resolved through DI and registered in the same `Program.cs`
- [[dotnet/entity-framework]] — `AppDbContext` is a Scoped service registered via `AddDbContext`, a common DI consumer
- [[algorithms/solid-principles]] — DI is the practical implementation of the Dependency Inversion Principle (the D in SOLID)

---

## Source

[.NET Dependency Injection — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection)

---

*Last updated: 2025-03-23*
