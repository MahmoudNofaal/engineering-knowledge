# Dependency Injection

> DI is a technique where an object's dependencies are handed to it from outside rather than created inside — the container wires everything together so your classes never call `new` on their collaborators.

---

## When To Use It

Use it everywhere in an ASP.NET Core application — it's the backbone the framework is built on. The real question isn't whether to use DI, but how to register things correctly. It earns its cost when you need testability (swap real implementations for fakes), flexibility (change a database provider without touching business logic), and lifetime management (one database connection per request, not one per query). Don't reach for DI for pure value objects, simple utilities, or anything that has no external dependencies — `new EmailAddress("x@y.com")` doesn't need a container.

---

## Core Concept

**One sentence for the interview:** The container owns object creation; your classes declare what they need, and the container figures out how to build it.

The container holds a registry of type mappings: "when someone asks for `IOrderRepository`, give them an `OrderRepository`." When you resolve a type — either explicitly or via constructor injection — the container walks the dependency graph, builds everything in the right order, and manages how long each instance lives. The lifetime is the critical decision: Singleton means one instance ever, Scoped means one per HTTP request, Transient means a new one every time. Getting lifetimes wrong is the most common DI bug in .NET — a Singleton holding a reference to a Scoped service captures stale state across requests. The container won't stop you. You have to know the rules.

---

## The Code

```csharp
// 1. Basic registration — interface → implementation
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
builder.Services.AddSingleton<IEmailService, SmtpEmailService>();
builder.Services.AddTransient<IPaymentStrategy, StripePaymentStrategy>();
```

```csharp
// 2. Constructor injection — the standard pattern
public class OrderService
{
    private readonly IOrderRepository _orders;
    private readonly IEmailService _email;

    public OrderService(IOrderRepository orders, IEmailService email)
    {
        _orders = orders;
        _email = email;
    }
}

// .NET 8 primary constructor variant — same thing, less ceremony
public class OrderService(IOrderRepository orders, IEmailService email)
{
    public async Task PlaceOrderAsync(Order order)
    {
        await orders.AddAsync(order);
        await email.SendConfirmationAsync(order.CustomerEmail);
    }
}
```

```csharp
// 3. Lifetime registration — the most important decision
builder.Services.AddSingleton<T>();   // one instance for the app's entire lifetime
builder.Services.AddScoped<T>();      // one instance per HTTP request (most common for DB work)
builder.Services.AddTransient<T>();   // new instance every time it's resolved

// Captive dependency — the classic bug: Singleton holds Scoped → Scoped lives forever
builder.Services.AddSingleton<ReportCache>();    // lives forever
builder.Services.AddScoped<IOrderRepository, OrderRepository>(); // expects per-request lifetime

public class ReportCache(IOrderRepository orders) // ← BUG: captures first request's repo instance
{
    // orders is the same instance for every request now
}
```

```csharp
// 4. Factory registration — when construction needs runtime logic
builder.Services.AddScoped<INotificationSender>(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();
    var channel = config["Notifications:Channel"];

    return channel switch
    {
        "email" => sp.GetRequiredService<EmailNotificationSender>(),
        "sms"   => sp.GetRequiredService<SmsNotificationSender>(),
        _       => throw new InvalidOperationException($"Unknown channel: {channel}")
    };
});
```

```csharp
// 5. Multiple registrations of the same interface — IEnumerable<T> receives all
builder.Services.AddScoped<IPaymentStrategy, StripePaymentStrategy>();
builder.Services.AddScoped<IPaymentStrategy, PayPalPaymentStrategy>();
builder.Services.AddScoped<IPaymentStrategy, CashOnDeliveryStrategy>();

// Resolver receives all three
public class PaymentStrategyResolver(IEnumerable<IPaymentStrategy> strategies)
{
    private readonly Dictionary<string, IPaymentStrategy> _map =
        strategies.ToDictionary(s => s.Method, StringComparer.OrdinalIgnoreCase);

    public IPaymentStrategy Resolve(string method) =>
        _map.TryGetValue(method, out var s) ? s
            : throw new ArgumentException($"No strategy for '{method}'.");
}
```

```csharp
// 6. .NET 8 keyed services — built-in alternative to dictionary resolvers
builder.Services.AddKeyedScoped<IPaymentStrategy, StripePaymentStrategy>("stripe");
builder.Services.AddKeyedScoped<IPaymentStrategy, PayPalPaymentStrategy>("paypal");

// Resolve by key at the call site
public class CheckoutService([FromKeyedServices("stripe")] IPaymentStrategy stripe)
{
    // stripe is specifically StripePaymentStrategy — no resolver needed
}

// Or resolve dynamically from IServiceProvider
public class CheckoutService(IServiceProvider sp)
{
    public IPaymentStrategy GetStrategy(string method) =>
        sp.GetRequiredKeyedService<IPaymentStrategy>(method);
}
```

```csharp
// 7. Scrutor — decorator registration without manual factory wiring
// dotnet add package Scrutor

builder.Services.AddScoped<IOrderRepository, OrderRepository>();
builder.Services.Decorate<IOrderRepository, LoggingOrderRepository>();   // wraps real impl
builder.Services.Decorate<IOrderRepository, CachingOrderRepository>();   // wraps logging impl

// Resolution chain: CachingOrderRepository → LoggingOrderRepository → OrderRepository
```

```csharp
// 8. Resolving from IServiceProvider directly — service locator (use sparingly)
// Acceptable inside factories and middleware. Smell everywhere else.
public class HandlerFactory(IServiceProvider sp)
{
    public THandler Create<THandler>() where THandler : class =>
        sp.GetRequiredService<THandler>();
}

// In middleware — resolving a Scoped service from a Singleton-lifetime component
public class MyMiddleware(RequestDelegate next)  // Singleton lifetime
{
    public async Task InvokeAsync(HttpContext ctx, IOrderRepository repo)  // Scoped — injected per call
    {
        // repo is correctly scoped here because it's resolved from the request scope,
        // not from the middleware's constructor
        await next(ctx);
    }
}
```

---

## Gotchas

- **Captive dependency is the most common production DI bug.** A Singleton that takes a Scoped service in its constructor captures that instance forever — the Scoped service never gets replaced, even across requests. The container won't throw. You get subtle data leakage across users. The rule: a service can only depend on services with the same or longer lifetime.

- **`GetRequiredService<T>()` vs `GetService<T>()`** — `GetRequiredService` throws `InvalidOperationException` if the type isn't registered. `GetService` returns null. Always use `GetRequiredService` in production code so missing registrations fail loudly at startup, not silently in a null reference downstream.

- **Transient `IDisposable` services are a memory leak.** If you register a Transient that implements `IDisposable`, the container tracks it and disposes it only when the scope ends — not when it's "done being used." In a long-lived scope (or Singleton scope), these accumulate. Either make them Scoped, or dispose them yourself with a factory pattern.

- **`AddScoped` in a console app with no HTTP request needs a manual scope.** There's no request scope in a background service or console app. If you resolve a Scoped service from the root provider, you get an exception. Create an explicit scope: `using var scope = sp.CreateScope(); var repo = scope.ServiceProvider.GetRequiredService<IRepository>();`

- **Keyed services (`AddKeyedScoped`) require .NET 8.** If you're on .NET 6 or 7, you need a dictionary-based resolver or Scrutor. Don't assume the API is available — check the target framework before recommending it.

- **Open-generic registrations are powerful but easy to get wrong.** `builder.Services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>))` applies to every closed generic variant. If you accidentally register the same open generic twice, both run. Order matters — behaviors registered first wrap outermost.

---

## Interview Angle

**What they're really testing:** Whether you understand lifetime management and the captive dependency trap — not just that DI exists.

**Common question form:** *"What are the DI lifetimes in .NET and when would you use each one?"* or *"What is a captive dependency and how do you avoid it?"*

**The depth signal:** A junior lists Singleton/Scoped/Transient and gives the textbook definitions. A senior explains the captive dependency failure mode concretely — Singleton holding Scoped means the Scoped instance is reused across requests, leaking state — and knows the detection strategy (runtime `InvalidOperationException` in development with scope validation enabled, silent bug in production). They also know that `IMiddleware` vs inline middleware have different lifetime behaviors, and that Transient `IDisposable` is a subtle leak.

**Follow-up the interviewer asks next:** *"How would you detect a captive dependency in an existing codebase that's already in production?"*

The answer: enable `ValidateScopes` and `ValidateOnBuild` in development (`builder.Host.UseDefaultServiceProvider(o => { o.ValidateScopes = true; o.ValidateOnBuild = true; })`). `ValidateOnBuild` catches mismatched lifetimes at startup. In production, look for stale data appearing across requests — users seeing each other's data is a classic Singleton-holds-Scoped symptom.

---

## Related Topics

- [[dotnet/pattern/pattern-factory.md]] — Factories are the safe way to create Scoped objects from Singleton context; understanding DI lifetimes explains why factories exist.
- [[dotnet/pattern/pattern-decorator.md]] — Scrutor's `Decorate()` depends entirely on interface-based DI; lifetime mismatches in decorator chains produce captive dependency bugs.
- [[dotnet/pattern/pattern-strategy.md]] — `IEnumerable<IStrategy>` and keyed services are both DI features; the strategy dictionary resolver is a pattern built on top of how DI handles multiple registrations.
- [[dotnet/pattern/pattern-repository.md]] — `AddScoped<IOrderRepository, OrderRepository>()` is the most common registration in any .NET app; repository lifetime must match `DbContext` lifetime.
- [[dotnet/pattern/pattern-mediator.md]] — MediatR handler registration (`RegisterServicesFromAssembly`) is DI under the hood; understanding handler lifetimes explains why handlers should be Scoped or Transient, never Singleton.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection

---

*Last updated: 2026-04-09*