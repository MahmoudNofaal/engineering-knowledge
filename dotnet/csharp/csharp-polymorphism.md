# C# Polymorphism

> Polymorphism is the ability to call a method on a base-typed reference and get the correct subclass behaviour at runtime — without the caller knowing which subclass it holds.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Runtime method dispatch based on actual object type |
| **Use when** | A collection of related but varying types all need the same operation |
| **Avoid when** | Only one concrete type ever exists; or types are unrelated |
| **C# version** | C# 1.0 (virtual dispatch), C# 8.0 (pattern matching switch expressions) |
| **Namespace** | N/A — language mechanism |
| **Key mechanism** | Vtable (virtual method table) — pointer per type to each virtual method |

---

## When To Use It

Use polymorphism when you have a collection of related types that all respond to the same operation — a list of `Shape` objects each computing their `Area()`, a set of `NotificationChannel` objects each sending a message, a pipeline of `IValidator<T>` each validating a field.

Without polymorphism, you write `if`/`switch` chains that check the concrete type at runtime. These chains break silently every time you add a new subtype — you have to find every switch and add a case. Polymorphism replaces the switch with virtual dispatch: adding a new type means adding one new class, and every existing call site already handles it.

Don't force polymorphism when a simple `if` statement is clearer, or when the types aren't genuinely related.

---

## Core Concept

The runtime keeps a **vtable** (virtual method table) per type. Each entry in the vtable is a pointer to a method. When you declare a method `virtual`, you create a slot in the vtable that subclasses can replace. When a subclass uses `override`, it replaces that slot with its own method pointer. When you call a virtual method on a base-typed reference, the runtime looks up the *actual* object's vtable and calls whatever method pointer is in that slot — which might be the subclass version.

The key: the caller never has to know which concrete type it holds. The vtable lookup handles the dispatch automatically. This is why adding a new `EmailNotification` to a `List<Notification>` "just works" — the `foreach` doesn't need to change.

C# supports three forms of polymorphism:
1. **Subtype polymorphism** — virtual/override dispatch (runtime)
2. **Interface polymorphism** — calling through an interface (runtime)
3. **Generic polymorphism** — type parameters resolved at compile time (no runtime dispatch cost)

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | `virtual`, `override`, interface dispatch |
| C# 7.0 | .NET Core 1.0 | Pattern matching on types (`is T x`) |
| C# 8.0 | .NET Core 3.0 | `switch` expression with type and property patterns |
| C# 9.0 | .NET 5 | `and`, `or`, `not` logical patterns |
| C# 11.0 | .NET 7 | `abstract static` on interfaces (static polymorphism) |

*C# 11's `abstract static` interface members enable a new form of compile-time polymorphism: requiring that each implementing type provides a specific static method or operator. This is the foundation of the generic math interfaces (`INumber<T>`, `IAdditionOperators<T,T,T>`).*

---

## Performance

| Form | Dispatch mechanism | Cost |
|---|---|---|
| `virtual` + `override` | Vtable lookup | ~1–2 ns per call |
| Interface dispatch | Interface method table | ~1–2 ns per call |
| Generic constraint | Compiled to direct call | Zero — same as non-virtual |
| Pattern matching (`switch`) | Sequential type checks | O(n) arms |
| `sealed` override | JIT devirtualises | Zero — inlined |

**Allocation behaviour:** Polymorphism itself allocates nothing. The objects being dispatched to were already allocated. Generic polymorphism (`where T : IAnimal`) avoids even the vtable lookup — the JIT generates specialised code for each `T`.

**Benchmark notes:** Vtable dispatch is negligible for business logic. It only shows up in profilers for extremely hot inner loops (millions of calls per second). If you're at that level, `sealed` + devirtualisation, or generic constraints, are the tools.

---

## The Code

**Subtype polymorphism — virtual dispatch**
```csharp
public abstract class PaymentProcessor
{
    public abstract decimal ProcessingFee(decimal amount);
    public abstract Task<string> ChargeAsync(string cardToken, decimal amount, CancellationToken ct);

    // Template method — shared logic, virtual variation point
    public async Task<PaymentResult> ProcessAsync(string cardToken, decimal amount, CancellationToken ct)
    {
        decimal fee   = ProcessingFee(amount);
        decimal total = amount + fee;

        string transactionId = await ChargeAsync(cardToken, total, ct);
        return new PaymentResult(transactionId, total, fee);
    }
}

public sealed class StripeProcessor : PaymentProcessor
{
    public override decimal ProcessingFee(decimal amount) => amount * 0.029m + 0.30m;
    public override async Task<string> ChargeAsync(string cardToken, decimal amount, CancellationToken ct)
    {
        // Stripe-specific implementation
        return await StripeApi.ChargeAsync(cardToken, amount, ct);
    }
}

public sealed class PayPalProcessor : PaymentProcessor
{
    public override decimal ProcessingFee(decimal amount) => amount * 0.034m + 0.49m;
    public override async Task<string> ChargeAsync(string cardToken, decimal amount, CancellationToken ct)
        => await PayPalApi.ChargeAsync(cardToken, amount, ct);
}

// Caller doesn't know or care which processor it has
PaymentProcessor processor = GetProcessorForUser(user);
var result = await processor.ProcessAsync(token, 99.99m, ct);
```

**Interface polymorphism — across unrelated types**
```csharp
public interface IExporter
{
    string ContentType { get; }
    byte[] Export(IEnumerable<Order> orders);
}

// Completely unrelated class hierarchy — both implement IExporter
public sealed class CsvExporter : IExporter
{
    public string ContentType => "text/csv";
    public byte[] Export(IEnumerable<Order> orders)
        => Encoding.UTF8.GetBytes(string.Join("\n", orders.Select(o => $"{o.Id},{o.Total}")));
}

public sealed class PdfExporter : IExporter
{
    public string ContentType => "application/pdf";
    public byte[] Export(IEnumerable<Order> orders) { /* PDF generation */ return Array.Empty<byte>(); }
}

// Factory maps request format to exporter — caller uses IExporter
IExporter exporter = format switch
{
    "csv" => new CsvExporter(),
    "pdf" => new PdfExporter(),
    _     => throw new NotSupportedException($"Format '{format}' not supported")
};

byte[] data = exporter.Export(orders);
```

**Generic polymorphism — compile-time, zero dispatch cost**
```csharp
// Without generic constraint: requires boxing if T is a value type
void PrintOld(object item) => Console.WriteLine(item); // boxes int, bool, etc.

// With generic constraint: direct call, no boxing, no runtime dispatch
void Print<T>(T item) where T : IFormattable
    => Console.WriteLine(item.ToString("G", null));

// Static polymorphism (C# 11): abstract static interface members
public interface IParser<T>
{
    // Each implementing type must provide a static Parse method
    static abstract T Parse(string input);
}

public record Temperature(double Celsius) : IParser<Temperature>
{
    public static Temperature Parse(string input)
        => new Temperature(double.Parse(input));
}

// Generic code that works with any IParser<T> — no runtime dispatch
T ParseValue<T>(string input) where T : IParser<T> => T.Parse(input);
```

**Pattern matching as an escape hatch (when you don't own the types)**
```csharp
// When you CAN'T add virtual methods to the types (third-party types, primitives),
// pattern matching is the correct fallback
static string Describe(object value) => value switch
{
    int n when n < 0 => $"negative int: {n}",
    int n            => $"positive int: {n}",
    double d         => $"double: {d:F2}",
    string { Length: 0 } => "empty string",
    string s         => $"string ({s.Length} chars): {s}",
    null             => "null",
    _                => $"unknown: {value.GetType().Name}"
};

// Pattern matching on a sealed hierarchy (exhaustive, compiler-checked)
public abstract record Shape;
public sealed record Circle(double Radius) : Shape;
public sealed record Rectangle(double W, double H) : Shape;

static double Area(Shape shape) => shape switch
{
    Circle c    => Math.PI * c.Radius * c.Radius,
    Rectangle r => r.W * r.H,
    // Compiler warns here if Shape gains a new subtype
};
```

---

## Real World Example

An order processing pipeline applies multiple validators to an order. Each validator is an independent class, all implementing the same interface. Adding a new validation rule means adding one new class — nothing else changes.

```csharp
public interface IOrderValidator
{
    ValidationResult Validate(Order order);
}

public record ValidationResult(bool IsValid, string? ErrorMessage = null)
{
    public static ValidationResult Ok() => new(true);
    public static ValidationResult Fail(string message) => new(false, message);
}

// Independent validators — each owns its own logic
public sealed class StockValidator : IOrderValidator
{
    private readonly IInventoryService _inventory;
    public StockValidator(IInventoryService inventory) => _inventory = inventory;

    public ValidationResult Validate(Order order)
    {
        foreach (var item in order.Items)
        {
            int available = _inventory.GetStock(item.ProductId);
            if (available < item.Quantity)
                return ValidationResult.Fail($"Insufficient stock for product {item.ProductId}");
        }
        return ValidationResult.Ok();
    }
}

public sealed class AddressValidator : IOrderValidator
{
    public ValidationResult Validate(Order order)
    {
        if (string.IsNullOrWhiteSpace(order.ShippingAddress))
            return ValidationResult.Fail("Shipping address is required");
        return ValidationResult.Ok();
    }
}

public sealed class MaxOrderValueValidator : IOrderValidator
{
    private const decimal MaxValue = 10_000m;

    public ValidationResult Validate(Order order)
        => order.Total > MaxValue
            ? ValidationResult.Fail($"Order total exceeds maximum of {MaxValue:C}")
            : ValidationResult.Ok();
}

// The pipeline — polymorphism in action
public class OrderValidationPipeline
{
    private readonly IEnumerable<IOrderValidator> _validators;

    public OrderValidationPipeline(IEnumerable<IOrderValidator> validators)
        => _validators = validators;

    public IReadOnlyList<string> Validate(Order order)
        => _validators
            .Select(v => v.Validate(order))
            .Where(r => !r.IsValid)
            .Select(r => r.ErrorMessage!)
            .ToList();
}
```

*The key insight: adding a new validation rule requires adding one new class that implements `IOrderValidator`. The `OrderValidationPipeline` never changes. Every existing validator is unaffected. This is the Open/Closed Principle enabled by polymorphism — the pipeline is open for extension (add a class) but closed for modification (no existing code changes).*

---

## Common Misconceptions

**"Method overloading is polymorphism"**
Overloading (multiple methods with the same name but different parameter types) is resolved at **compile time** based on the declared type of the argument — not the runtime type. Calling `Process(animal)` where `animal` is declared as `Animal` calls `Process(Animal)`, not `Process(Dog)`, even if the runtime type is `Dog`. True polymorphism (virtual dispatch) resolves at **runtime** based on the actual object type.

**"You need inheritance for polymorphism"**
Interface polymorphism works across completely unrelated class hierarchies. `Dog` and `Printer` can both implement `IPrintable` without any shared base class. Polymorphism is about shared contracts, not shared ancestry. In modern C#, interface-based polymorphism is often preferred over class inheritance for this reason.

**"`new` on a method also overrides it"**
`new` hides the base method for callers using the derived type directly. But through a base-typed reference, the base method is always called. `new` breaks polymorphism for that method — it's not an override, it's a shadow. The only legitimate use of `new` is to resolve an accidental name collision with a base method added after the derived class was written.

---

## Gotchas

- **Forgetting `virtual` means no polymorphism — silently.** If the base method isn't `virtual`, no subclass can override it (only hide it with `new`). Calling through a base-typed reference always calls the base version, even when the object is a subclass. The compiler gives no warning — the call just goes to the wrong place.

- **Overloading is resolved at compile time, overriding at runtime.** If you have `void Process(Animal a)` and `void Process(Dog d)`, calling `Process(animalRef)` where `animalRef` is declared `Animal` will call `Process(Animal)` — even if the runtime type is `Dog`. People who expect polymorphic overload resolution are always surprised by this.

- **Pattern matching on open hierarchies is fragile.** A `switch` expression over a non-sealed hierarchy has no compiler-enforced exhaustiveness. Adding a new subtype doesn't generate a warning at the switch site — you only find out at runtime when the `_` arm fires (or when there is no `_` arm and it throws). Seal your hierarchies when the set of subtypes is fixed.

- **Calling virtual methods from a constructor.** Already covered in Inheritance, but worth repeating: if a base class constructor calls a virtual method, the derived class override runs against an uninitialized object. The derived constructor hasn't run yet, so derived fields are at default values.

- **Interface polymorphism boxes value types.** When a struct implements an interface and is accessed through the interface variable, it's boxed. `IComparable x = 42` allocates a heap wrapper. Use generic constraints (`where T : IComparable`) to get interface polymorphism on value types without boxing.

---

## Interview Angle

**What they're really testing:** Whether you understand the vtable mechanism at a conceptual level and can predict method dispatch behaviour across variable types, not just whether you've memorised "polymorphism means multiple forms."

**Common question forms:**
- "What is polymorphism and how does C# implement it?"
- "What's the difference between method overriding and method hiding?"
- "How does virtual dispatch work internally?"
- "What happens when you call an overridden method through a base-typed reference vs a derived-typed reference?"

**The depth signal:** A junior says "polymorphism means a subclass can change a method." A senior explains the vtable: `virtual` creates a slot; `override` replaces the slot in the subclass table; calling through a base reference looks up the *runtime* type's slot — dispatching to the derived version. They distinguish this from overloading (compile-time, declared type) and from `new` (hiding, doesn't touch the vtable). They know that interface dispatch works the same way via an interface method table, and that generic constraints eliminate dispatch entirely at the cost of static type resolution.

**Follow-up questions to expect:**
- "Can you have polymorphism without inheritance in C#?"
- "Why is pattern matching on a type hierarchy an anti-pattern in OOP?"
- "What does `sealed` do to virtual dispatch performance?"

---

## Related Topics

- [[dotnet/csharp/csharp-inheritance.md]] — Virtual dispatch and `override` are set up through inheritance
- [[dotnet/csharp/csharp-interfaces.md]] — Interface polymorphism works across unrelated hierarchies
- [[dotnet/csharp/csharp-abstract-classes.md]] — Abstract classes define the variation point without a base implementation
- [[dotnet/csharp/csharp-pattern-matching.md]] — The explicit-type-dispatch escape hatch when true polymorphism isn't available

---

## Source

[Polymorphism — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/polymorphism)

---

*Last updated: 2026-04-06*