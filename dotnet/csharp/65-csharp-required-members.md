# C# Required Members

> The `required` modifier (C# 11) forces callers to set a property or field in an object initializer — making "must be provided at construction time" a compile-time constraint rather than a runtime check.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Compile-time enforcement that a member must be set during object initialisation |
| **Syntax** | `public required string Name { get; init; }` |
| **Works with** | `init`-only properties, mutable `set` properties, public fields |
| **Bypass** | `[SetsRequiredMembers]` on a constructor |
| **C# version** | C# 11 (.NET 7) |
| **Namespace** | `System.Runtime.CompilerServices.RequiredMemberAttribute` (implicit) |

---

## When To Use It

Use `required` when a type has properties that have no sensible default and must be explicitly provided by every caller — DTOs, configuration objects, request models, value objects that shouldn't be half-initialised.

`required` is the right choice when:
- The property has no meaningful default value — leaving it unset would mean `null` or `0` being silently used
- You want object initializer ergonomics (`new Order { Id = 1, CustomerName = "Alice" }`) rather than constructor parameter ergonomics
- The type might be created in multiple places and you want the compiler to catch every creation site

Use a constructor parameter instead of `required` when:
- You need to **validate** the value on assignment (constructors let you throw; `init` setters with `required` can too, but it's less conventional)
- You want to **hide** which implementation is used (constructor injection for DI)
- The type is used with a DI container that constructs via constructor, not object initializer

---

## Core Concept

Before C# 11, ensuring a property was always set meant either a constructor parameter (which the caller can't skip) or a runtime null check after construction (which fires too late). The `required` modifier fills the gap: it's enforced at the **call site at compile time**, not at runtime.

Any object initializer that creates the type must set all `required` members — missing one is a compile error. This constraint is part of the type's contract and is checked by any compiler that understands the attribute (including IDE analysers and CI builds).

**`[SetsRequiredMembers]`** is the escape hatch. A constructor annotated with it tells the compiler: "this constructor sets all required members itself — callers of this constructor don't need object initializer syntax." This is necessary for:
- Deserialization (System.Text.Json, EF Core) which constructs objects without object initializers
- Factory methods
- Test builders
- Any constructor that sets the required properties explicitly in its body

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 3.0 | .NET 3.5 | Object initializers — `new T { Prop = value }` |
| C# 8.0 | .NET Core 3.0 | `init` accessor — settable only in initializer |
| C# 9.0 | .NET 5 | Records with required-like semantics (positional constructor) |
| C# 11.0 | .NET 7 | `required` modifier on properties and fields |
| C# 12.0 | .NET 8 | Works with primary constructors |

---

## Performance

`required` is entirely a compile-time constraint. There is zero runtime overhead — the generated IL is identical to a property without `required`. The attribute `RequiredMemberAttribute` is embedded in metadata but never read at runtime in normal execution.

---

## The Code

**Basic `required` property**
```csharp
public class OrderRequest
{
    public required int    OrderId       { get; init; }
    public required string CustomerEmail { get; init; }
    public required decimal Total        { get; init; }

    // Optional — has a default
    public string? Notes    { get; init; }
    public DateTime Created { get; init; } = DateTime.UtcNow;
}

// CORRECT: all required members set
var request = new OrderRequest
{
    OrderId       = 42,
    CustomerEmail = "alice@example.com",
    Total         = 99.99m
};

// COMPILE ERROR: CustomerEmail and Total not set
var bad = new OrderRequest { OrderId = 1 };
// CS9035: Required member 'OrderRequest.CustomerEmail' must be set in the object initializer or attribute constructor.
```

**`required` with mutable `set` — less common but valid**
```csharp
// required works on mutable properties too — not just init
public class LogEntry
{
    public required string Level   { get; set; }
    public required string Message { get; set; }
    public DateTime Timestamp      { get; set; } = DateTime.UtcNow;
}

var entry = new LogEntry { Level = "ERROR", Message = "Something broke" };
entry.Level = "WARN"; // still mutable after construction
```

**`[SetsRequiredMembers]` — constructor that satisfies the contract**
```csharp
public class ProductDto
{
    public required int    Id       { get; init; }
    public required string Name     { get; init; }
    public required decimal Price   { get; init; }

    // Parameterless constructor for deserialisers — tells compiler: "I'll set them"
    [System.Diagnostics.CodeAnalysis.SetsRequiredMembers]
    public ProductDto() { }

    // Explicit full constructor — also satisfies required
    [System.Diagnostics.CodeAnalysis.SetsRequiredMembers]
    public ProductDto(int id, string name, decimal price)
    {
        Id    = id;
        Name  = name;
        Price = price;
    }
}

// Now all three construction styles work:
var a = new ProductDto { Id = 1, Name = "Widget", Price = 9.99m };  // object initializer
var b = new ProductDto(2, "Gadget", 14.99m);                         // explicit constructor
var c = JsonSerializer.Deserialize<ProductDto>(json);                // deserialiser (uses parameterless)
```

**EF Core and ORMs — `[SetsRequiredMembers]` on parameterless constructor**
```csharp
public class Order
{
    public int     Id             { get; private set; }
    public required string CustomerName { get; init; }
    public required decimal Total       { get; init; }
    public OrderStatus Status           { get; private set; }

    // EF Core materialises entities using a parameterless constructor + property setters
    // [SetsRequiredMembers] tells the compiler EF handles this — not the caller
    [System.Diagnostics.CodeAnalysis.SetsRequiredMembers]
    protected Order() { }   // protected — not for direct use by application code

    // Application code uses this constructor
    [System.Diagnostics.CodeAnalysis.SetsRequiredMembers]
    public Order(string customerName, decimal total)
    {
        CustomerName = customerName;
        Total        = total;
        Status       = OrderStatus.Pending;
    }
}
```

**`required` on a field — less common but valid**
```csharp
public class Config
{
    public required string ConnectionString;   // field, not property
    public int TimeoutSeconds = 30;            // optional field with default
}

var cfg = new Config { ConnectionString = "Server=..." };
```

**Combining `required` with validation in `init` setter**
```csharp
public class EmailAddress
{
    private string _value = "";

    public required string Value
    {
        get => _value;
        init
        {
            if (!value.Contains('@'))
                throw new ArgumentException("Invalid email address.", nameof(value));
            _value = value.ToLowerInvariant();
        }
    }
}

// Compile error if Value not set; runtime error if Value is invalid
var email = new EmailAddress { Value = "alice@example.com" }; // fine
var bad   = new EmailAddress { Value = "notanemail" };         // throws at runtime
var worse = new EmailAddress();                                 // compile error
```

---

## Real World Example

A CQRS command model uses `required` to guarantee every command carries its mandatory context. No command can be created half-initialised — the compiler enforces the full contract at every creation site.

```csharp
// Base command — every command must have correlation context
public abstract class Command
{
    public required Guid   CorrelationId { get; init; }
    public required string InitiatedBy   { get; init; }
    public DateTime IssuedAt             { get; init; } = DateTime.UtcNow;
}

public class CreateOrderCommand : Command
{
    public required string  CustomerEmail { get; init; }
    public required IReadOnlyList<OrderLineRequest> Items { get; init; }
    public string?          PromoCode     { get; init; }
}

public class CancelOrderCommand : Command
{
    public required Guid   OrderId { get; init; }
    public required string Reason  { get; init; }
}

// Usage — compiler ensures all required properties are set
var createCmd = new CreateOrderCommand
{
    CorrelationId = Guid.NewGuid(),
    InitiatedBy   = currentUser.Email,
    CustomerEmail = "alice@example.com",
    Items         = new[] { new OrderLineRequest(productId: 1, qty: 2) }
    // PromoCode is optional — can be omitted
};

// Compile error — CorrelationId and InitiatedBy inherited as required
var incomplete = new CancelOrderCommand
{
    OrderId = orderId,
    Reason  = "Customer requested"
    // Missing CorrelationId and InitiatedBy from base class — compile error
};
```

*The key insight: `required` on the base `Command` class propagates to all derived commands — every subclass creation must supply `CorrelationId` and `InitiatedBy`. This is impossible to enforce with virtual properties or runtime checks without a constructor parameter. The compile-time guarantee means a command can never reach the handler without its audit trail.*

---

## Common Misconceptions

**"`required` and `init` are the same thing"**
`init` restricts *when* a property can be set — only during object initialisation, not afterwards. `required` restricts *whether* it must be set — the caller must provide a value. They compose: `public required string Name { get; init; }` means "must be set, and only settable during initialisation." A plain `public required string Name { get; set; }` would require setting during initialisation *and* remain mutable afterwards.

**"`required` on a base class property is inherited but not enforceable"**
It is enforced on derived classes. Any `new DerivedClass { ... }` must set all `required` members from the base class as well as from the derived class. The compiler checks the full inheritance chain.

**"`[SetsRequiredMembers]` turns off all required checking"**
It tells the compiler that the annotated constructor satisfies all required members — callers of that specific constructor are exempt from setting required properties in an object initializer. Callers using the parameterless or other constructors still need the object initializer to set required members unless those constructors are also annotated.

---

## Gotchas

- **`required` on a base class forces all derived class object initializers to set it.** This is usually what you want, but it can surprise you when you add `required` to a widely-used base class — every creation site in the codebase becomes a compile error until all required members are provided.

- **Deserialisers need `[SetsRequiredMembers]` on a constructor or they'll throw.** `System.Text.Json` uses a parameterless constructor by default. Without `[SetsRequiredMembers]`, constructing via the deserialiser violates the `required` contract and throws a runtime exception. Add the attribute or use a `[JsonConstructor]` that sets the required members.

- **`required` doesn't imply non-null.** `public required string? Name { get; init; }` compiles — you must set `Name`, but you can set it to `null`. If you want non-null, use `public required string Name { get; init; }` (no `?`) with nullable reference types enabled.

- **Reflection-based construction bypasses `required` at runtime.** `Activator.CreateInstance` and `FormatterServices.GetUninitializedObject` don't check required members. The constraint is enforced only by the C# compiler, not the CLR.

---

## Interview Angle

**What they're really testing:** Whether you understand the gap `required` fills between constructor parameters (which force provision but don't allow object-initializer ergonomics) and plain properties (which allow object initializers but can be forgotten).

**Common question forms:**
- "What is the `required` modifier in C# 11?"
- "What's the difference between `required` and `init`?"
- "How do you make a class work with both `required` properties and a deserialiser?"

**The depth signal:** A junior says "`required` means you must set the property." A senior explains the exact gap it fills — it gives object-initializer ergonomics with constructor-like enforcement, which was impossible before. They know `[SetsRequiredMembers]` is needed for deserialisers and EF Core, that `required` propagates through inheritance, and that it doesn't imply non-null (that's the NRT system's job).

---

## Related Topics

- [csharp-encapsulation.md](csharp-encapsulation.md) — `init`, `private set`, and the spectrum of property access control
- [csharp-records.md](csharp-records.md) — Records provide similar "must-provide" guarantees via positional constructors; `required` fills the same need for non-record classes
- [csharp-nullable-types.md](csharp-nullable-types.md) — `required` doesn't imply non-null; NRT handles that separately
- [csharp-primary-constructors.md](csharp-primary-constructors.md) — Alternative approach for enforcing parameter provision; the tradeoff with `required` depends on whether you want constructor or initializer ergonomics
- [csharp-exceptions.md](csharp-exceptions.md) — `[SetsRequiredMembers]` constructor can still validate; `ArgumentNullException.ThrowIfNull` applies here

---

## Source

[Required Members — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-11#required-members)

---
*Last updated: 2026-05-13*
