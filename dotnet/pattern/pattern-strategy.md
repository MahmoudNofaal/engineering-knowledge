# Strategy Pattern

> A strategy is a swappable behavior — you define a family of algorithms behind a common interface and choose which one to use at runtime.

---

## When To Use It

Use it when you have a decision that produces branching behavior and that branching is likely to grow — payment methods, shipping calculators, notification channels, export formats. The moment a `switch` statement on a type enum starts accumulating cases, that's the signal. Don't use it for one-off conditionals that won't grow — a simple `if/else` is clearer than an interface hierarchy with two implementations.

---

## Core Concept

**One sentence for the interview:** Strategy replaces a switch statement with polymorphism so adding a new behavior means adding a new class, not editing existing code.

The problem with `switch` on type is that every new case means editing existing code — a violation of Open/Closed. The strategy pattern replaces the switch with polymorphism: each branch becomes its own class implementing a shared interface. The caller holds a reference to `IPaymentStrategy`, not to `StripePaymentStrategy` directly. Which strategy runs is determined at the call site — either injected via DI, selected from a dictionary, or chosen by a factory. The key shift is that adding a new behavior means adding a new class, not editing an existing one. In .NET the pattern composes naturally with DI — you can register all strategies and let a factory or dictionary-based resolver pick the right one at runtime without a single `switch` statement in sight.

---

## The Code

```csharp
// 1. Interface — the contract all strategies share
public interface IPaymentStrategy
{
    string Method { get; }
    Task<PaymentResult> ProcessAsync(PaymentRequest request);
}
```

```csharp
// 2. Concrete strategies — one class per behavior, .NET 8 primary constructor
public class StripePaymentStrategy(IStripeClient stripe) : IPaymentStrategy
{
    public string Method => "stripe";

    public async Task<PaymentResult> ProcessAsync(PaymentRequest request)
    {
        var charge = await stripe.ChargeAsync(request.Amount, request.Token);
        return new PaymentResult(charge.Id, charge.Status);
    }
}

public class CashOnDeliveryStrategy : IPaymentStrategy
{
    public string Method => "cod";

    public Task<PaymentResult> ProcessAsync(PaymentRequest request) =>
        Task.FromResult(new PaymentResult(Guid.NewGuid().ToString(), "pending"));
}
```

```csharp
// 3. Dictionary-based resolver — eliminates switch at the selection site
public class PaymentStrategyResolver
{
    private readonly Dictionary<string, IPaymentStrategy> _strategies;

    public PaymentStrategyResolver(IEnumerable<IPaymentStrategy> strategies)
    {
        // Guard against duplicate keys at startup — fail loudly, not silently
        _strategies = new Dictionary<string, IPaymentStrategy>(StringComparer.OrdinalIgnoreCase);
        foreach (var s in strategies)
        {
            if (!_strategies.TryAdd(s.Method, s))
                throw new InvalidOperationException(
                    $"Duplicate payment strategy registered for method '{s.Method}'.");
        }
    }

    public IPaymentStrategy Resolve(string method) =>
        _strategies.TryGetValue(method, out var strategy) ? strategy
            : throw new ArgumentException($"No payment strategy registered for method '{method}'.");
}
```

```csharp
// 4. DI registration — register all strategies, then the resolver
builder.Services.AddScoped<IPaymentStrategy, StripePaymentStrategy>();
builder.Services.AddScoped<IPaymentStrategy, CashOnDeliveryStrategy>();
builder.Services.AddScoped<PaymentStrategyResolver>();

// .NET DI allows multiple registrations of the same interface —
// IEnumerable<IPaymentStrategy> in the resolver constructor receives all of them
```

```csharp
// 5. .NET 8 keyed services — built-in alternative to the dictionary resolver
builder.Services.AddKeyedScoped<IPaymentStrategy, StripePaymentStrategy>("stripe");
builder.Services.AddKeyedScoped<IPaymentStrategy, CashOnDeliveryStrategy>("cod");
builder.Services.AddKeyedScoped<IPaymentStrategy, PayPalPaymentStrategy>("paypal");

// Resolve at runtime by key — no resolver class needed
public class CheckoutService(IServiceProvider sp)
{
    public async Task<PaymentResult> CheckoutAsync(Order order, string paymentMethod)
    {
        var strategy = sp.GetRequiredKeyedService<IPaymentStrategy>(paymentMethod);
        return await strategy.ProcessAsync(new PaymentRequest(order.Total, order.PaymentToken));
    }
}
```

```csharp
// 6. Runtime strategy from appsettings — select strategy from configuration
// appsettings.json: { "Payments": { "DefaultMethod": "stripe" } }
builder.Services.AddScoped<CheckoutService>(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();
    var method = config["Payments:DefaultMethod"] ?? "stripe";
    var resolver = sp.GetRequiredService<PaymentStrategyResolver>();
    var strategy = resolver.Resolve(method);
    return new CheckoutService(strategy);
});
```

```csharp
// 7. Service consuming the resolver — no switch, no concrete type references
public class CheckoutService(PaymentStrategyResolver resolver)
{
    public async Task<PaymentResult> CheckoutAsync(Order order, string paymentMethod)
    {
        var strategy = resolver.Resolve(paymentMethod);
        return await strategy.ProcessAsync(new PaymentRequest(order.Total, order.PaymentToken));
    }
}
```

```csharp
// 8. Inline strategy via delegate — for lightweight cases that don't need a full class
public class DiscountCalculator
{
    private Func<decimal, decimal> _strategy = price => price; // default: no discount

    public void SetStrategy(Func<decimal, decimal> strategy) => _strategy = strategy;

    public decimal Calculate(decimal price) => _strategy(price);
}

// Usage
var calc = new DiscountCalculator();
calc.SetStrategy(price => price * 0.9m);    // 10% off
var final = calc.Calculate(100m);           // 90
```

---

## Gotchas

- **`IEnumerable<IPaymentStrategy>` registration order in .NET DI is not guaranteed.** If two strategies have the same `Method` key and you call `.ToDictionary()` without a duplicate check, it throws at startup — but only if you're lucky. Always guard with an explicit duplicate check so the error message names the offending key.

- **Strategies registered as Scoped can't be held by a Singleton resolver.** If `PaymentStrategyResolver` is Singleton and its strategies are Scoped, you get a captive dependency — the Singleton holds references to the first request's Scoped instances forever. Register the resolver as Scoped, or use keyed services resolved from `IServiceProvider` at call time.

- **The `Method` property key on the interface is a convention, not a framework feature.** If you rename a strategy's `Method` value, callers passing the old string break silently at runtime. Consider using a `[PaymentMethod("stripe")]` attribute or a dedicated registration call to make the key explicit and grep-able.

- **Delegate strategies (`Func<T>`) look clean but lose DI.** A `Func<decimal, decimal>` can't have `ILogger` or `IHttpClientFactory` injected into it. The moment a behavior needs infrastructure, promote it to a proper class implementing the interface.

- **Forgetting to register a new strategy is a runtime error, not a compile error.** When you add `PaypalPaymentStrategy` and forget to register it in DI, `Resolve("paypal")` throws in production. Add an integration test that resolves all registered strategy keys to catch missing registrations at build time.

---

## Interview Angle

**What they're really testing:** Whether you understand Open/Closed Principle in practice — adding behavior without editing existing code — and how to replace conditional branching with polymorphism.

**Common question form:** *"How would you handle multiple payment methods in a checkout system?"* or *"How do you avoid large switch statements that keep growing?"*

**The depth signal:** A junior replaces a `switch` with a strategy interface and stops there. A senior wires the selection mechanism through DI using `IEnumerable<IStrategy>` and a dictionary resolver, eliminating the switch at the selection site too — not just inside each branch. They also know the captive dependency trap when strategies are Scoped and the resolver is Singleton, and can articulate when a delegate strategy (`Func<T>`) is sufficient versus when a full class is needed.

**Follow-up the interviewer asks next:** *"How would you make strategies configurable per-tenant at runtime?"*

The answer involves two moving parts. First, store the tenant's preferred strategy key (e.g., `"stripe"`) in a tenant configuration table or claims. Second, resolve the strategy at call time rather than at registration time — either by passing the key from the tenant context to the resolver, or by using a `ITenantContext` service injected into `CheckoutService` that provides the key. The DI container doesn't change; the selection logic moves to runtime based on tenant identity. If strategies themselves have different configurations per tenant (different API keys, different fee structures), a factory that takes a tenant-aware configuration and builds the concrete strategy is the next step.

---

## Related Topics

- [[dotnet/pattern/pattern-factory.md]] — Factories are the natural mechanism for selecting which strategy to instantiate at runtime; the two patterns are frequently combined.
- [[dotnet/pattern/pattern-decorator.md]] — Strategies swap behavior wholesale; decorators layer behavior on top of an existing implementation — both use interfaces but solve different problems.
- [[dotnet/pattern/dependency-injection.md]] — The dictionary-based resolver depends on DI allowing multiple registrations for the same interface; understanding keyed services is the .NET 8 evolution of this.
- [[dotnet/pattern/pattern-cqrs.md]] — MediatR handler dispatch is itself a strategy resolution — each `IRequest<T>` maps to exactly one `IRequestHandler<T>` resolved at runtime.

---

## Source

https://refactoring.guru/design-patterns/strategy

---

*Last updated: 2026-04-09*