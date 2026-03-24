# Strategy Pattern

> A strategy is a swappable behavior — you define a family of algorithms behind a common interface and choose which one to use at runtime.

---

## When To Use It
Use it when you have a decision that produces branching behavior and that branching is likely to grow — payment methods, shipping calculators, notification channels, export formats. The moment a `switch` statement on a type enum starts accumulating cases, that's the signal. Don't use it for one-off conditionals that won't grow — a simple `if/else` is clearer than an interface hierarchy with two implementations.

---

## Core Concept
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
// 2. Concrete strategies — one class per behavior
public class StripePaymentStrategy : IPaymentStrategy
{
    private readonly IStripeClient _stripe;
    public string Method => "stripe";

    public StripePaymentStrategy(IStripeClient stripe) => _stripe = stripe;

    public async Task<PaymentResult> ProcessAsync(PaymentRequest request)
    {
        var charge = await _stripe.ChargeAsync(request.Amount, request.Token);
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
        // Build lookup from all registered strategies — keyed by Method property
        _strategies = strategies.ToDictionary(s => s.Method, StringComparer.OrdinalIgnoreCase);
    }

    public IPaymentStrategy Resolve(string method)
    {
        if (_strategies.TryGetValue(method, out var strategy))
            return strategy;

        throw new ArgumentException($"No payment strategy registered for method '{method}'.");
    }
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
// 5. Service consuming the resolver — no switch, no concrete type references
public class CheckoutService
{
    private readonly PaymentStrategyResolver _resolver;

    public CheckoutService(PaymentStrategyResolver resolver) => _resolver = resolver;

    public async Task<PaymentResult> CheckoutAsync(Order order, string paymentMethod)
    {
        var strategy = _resolver.Resolve(paymentMethod);
        return await strategy.ProcessAsync(new PaymentRequest(order.Total, order.PaymentToken));
    }
}
```
```csharp
// 6. Inline strategy via delegate — for lightweight cases that don't need a full class
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
- **`IEnumerable<IPaymentStrategy>` registration order is not guaranteed across DI containers.** If two strategies match the same key and you call `.ToDictionary()` without duplicate handling, it throws at startup. Always guard with `.GroupBy()` or check for duplicates explicitly.
- **Strategies registered as Scoped can't be held by a Singleton resolver.** If `PaymentStrategyResolver` is Singleton and its strategies are Scoped, you get a captive dependency — the Singleton holds references to the first request's Scoped instances forever. Register the resolver as Scoped too, or use a factory delegate.
- **The `Method` property key on the interface is a convention, not a framework feature.** If you rename a strategy's `Method` value, callers passing the old string break silently at runtime. Consider using a `[PaymentMethod("stripe")]` attribute or a dedicated registration call to make the key explicit and grep-able.
- **Delegate strategies (`Func<T>`) look clean but lose DI.** A `Func<decimal, decimal>` can't have `ILogger` or `IHttpClientFactory` injected into it. The moment a behavior needs infrastructure, promote it to a proper class implementing the interface.
- **Forgetting to register a new strategy is a runtime error, not a compile error.** When you add `PaypalPaymentStrategy` and forget to register it in DI, `Resolve("paypal")` throws in production. Add an integration test that resolves all registered strategy keys to catch missing registrations at build time.

---

## Interview Angle
**What they're really testing:** Whether you understand Open/Closed Principle in practice — adding behavior without editing existing code — and how to replace conditional branching with polymorphism.

**Common question form:** *"How would you handle multiple payment methods in a checkout system?"* or *"How do you avoid large switch statements that keep growing?"*

**The depth signal:** A junior replaces a `switch` with a strategy interface and stops there. A senior wires the selection mechanism through DI using `IEnumerable<IStrategy>` and a dictionary resolver, eliminating the switch at the selection site too — not just inside each branch. They also know the captive dependency trap when strategies are Scoped and the resolver is Singleton, and can articulate when a delegate strategy (`Func<T>`) is sufficient versus when a full class is needed.

---

## Related Topics
- [[dotnet/pattern-factory.md]] — Factories are the natural mechanism for selecting which strategy to instantiate at runtime; the two patterns are frequently combined.
- [[dotnet/pattern-decorator.md]] — Strategies swap behavior wholesale; decorators layer behavior on top of an existing implementation — both use interfaces but solve different problems.
- [[dotnet/dependency-injection.md]] — The dictionary-based resolver depends on DI allowing multiple registrations for the same interface; understanding how `IEnumerable<T>` resolution works is essential.
- [[dotnet/pattern-cqrs.md]] — MediatR handler dispatch is itself a strategy resolution — each `IRequest<T>` maps to exactly one `IRequestHandler<T>` resolved at runtime.

---

## Source
https://refactoring.guru/design-patterns/strategy

---
*Last updated: 2026-03-24*