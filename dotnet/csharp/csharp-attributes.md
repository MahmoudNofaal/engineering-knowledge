# C# Attributes

> Declarative metadata tags you attach to types, methods, properties, or parameters — read at runtime via reflection or at compile time by source generators, analyzers, and the compiler itself.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Compile-time metadata attached to code elements |
| **Read at** | Runtime (reflection) or compile time (source generator/analyzer) |
| **Syntax** | `[AttributeName]` or `[AttributeName(args)]` before the decorated element |
| **Base class** | Must inherit from `System.Attribute` |
| **C# version** | C# 1.0 |
| **Namespace** | `System` + many specific namespaces |

---

## When To Use It

Use attributes to attach metadata that code can't express as types or values — validation rules (`[Required]`, `[Range]`), serialisation hints (`[JsonPropertyName]`), DI registration (`[FromServices]`), ORM column mappings, test markers (`[Fact]`, `[Test]`), and code analysis hints (`[Obsolete]`, `[DynamicallyAccessedMembers]`).

Write a custom attribute when you need to mark code elements for a framework (DI, serialiser, validator, source generator) that will discover and act on them at build time or startup.

---

## Core Concept

An attribute is a class that inherits from `Attribute`. Constructor arguments become positional parameters in the attribute syntax; public properties can be set as named arguments. The `AttributeUsage` attribute on the attribute class controls which elements it can target (class, method, property, etc.) and whether multiple are allowed.

Attributes compile into the assembly's metadata tables. They're **not executed** at compile time (unless a source generator or analyzer reads them). At runtime, reflection methods like `GetCustomAttributes()` and `IsDefined()` read them from the metadata.

---

## The Code

**Using BCL attributes**
```csharp
[Obsolete("Use GetOrderAsync instead", error: false)] // compiler warning on use
public Order GetOrder(int id) { /* ... */ }

[Flags]
public enum OrderStatus { None = 0, Pending = 1, Processing = 2, Shipped = 4, Delivered = 8 }

[Serializable]
public class OrderSnapshot { /* ... */ }

// JSON serialisation hints
using System.Text.Json.Serialization;
public class OrderDto
{
    [JsonPropertyName("order_id")]
    public int Id { get; set; }

    [JsonIgnore]
    public string InternalRef { get; set; } = "";
}
```

**Custom attribute — creating and using**
```csharp
[AttributeUsage(AttributeTargets.Property, AllowMultiple = false, Inherited = true)]
public sealed class AuditAttribute : Attribute
{
    public string? Description { get; }

    public AuditAttribute(string? description = null)
        => Description = description;
}

public class Order
{
    [Audit("Changed when customer modifies the order")]
    public string CustomerName { get; set; } = "";

    [Audit]
    public decimal Total { get; set; }

    public OrderStatus Status { get; set; } // not audited
}
```

**Reading attributes at runtime via reflection**
```csharp
// Discover all audited properties
var auditedProperties = typeof(Order)
    .GetProperties()
    .Where(p => p.IsDefined(typeof(AuditAttribute), inherit: true))
    .Select(p => new
    {
        Property  = p,
        Attribute = p.GetCustomAttribute<AuditAttribute>()!
    })
    .ToList();

foreach (var a in auditedProperties)
    Console.WriteLine($"{a.Property.Name}: {a.Attribute.Description ?? "(no description)"}");
```

**Attribute parameter types — what's allowed**
```csharp
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public class ExampleAttribute : Attribute
{
    // Constructor parameters must be compile-time constants:
    public ExampleAttribute(
        string name,          // string literal
        int count,            // numeric literal
        Type type,            // typeof(T)
        bool flag = false)    // optional with default
    { }

    // Named properties — set at usage site: [Example("x", 1, typeof(T), Flag = true)]
    public string? Tag { get; set; }
}
```

---

## Real World Example

A validation framework uses attributes to define rules that a generic validator reads at startup and compiles for each type.

```csharp
[AttributeUsage(AttributeTargets.Property, AllowMultiple = true)]
public abstract class ValidationAttribute : Attribute
{
    public abstract (bool Valid, string? Error) Validate(object? value);
}

public sealed class RequiredAttribute : ValidationAttribute
{
    public override (bool, string?) Validate(object? value)
        => value is not null && value.ToString() != ""
            ? (true, null)
            : (false, "Field is required");
}

public sealed class RangeAttribute : ValidationAttribute
{
    public double Min { get; }
    public double Max { get; }
    public RangeAttribute(double min, double max) => (Min, Max) = (min, max);

    public override (bool, string?) Validate(object? value)
    {
        if (value is not IComparable c) return (false, "Cannot compare");
        return (c.CompareTo(Min) >= 0 && c.CompareTo(Max) <= 0)
            ? (true, null)
            : (false, $"Must be between {Min} and {Max}");
    }
}

public class OrderRequest
{
    [Required]
    public string CustomerName { get; set; } = "";

    [Range(0.01, 10_000)]
    public decimal Total { get; set; }
}

public class AttributeValidator<T>
{
    // Pre-built at startup — reflection runs once per type
    private readonly List<(PropertyInfo Prop, ValidationAttribute[] Rules)> _rules;

    public AttributeValidator()
    {
        _rules = typeof(T).GetProperties()
            .Select(p => (p, p.GetCustomAttributes<ValidationAttribute>(inherit: true).ToArray()))
            .Where(x => x.Item2.Length > 0)
            .ToList();
    }

    public IReadOnlyList<string> Validate(T instance)
    {
        var errors = new List<string>();
        foreach (var (prop, rules) in _rules)
        {
            object? value = prop.GetValue(instance);
            foreach (var rule in rules)
            {
                var (valid, error) = rule.Validate(value);
                if (!valid) errors.Add($"{prop.Name}: {error}");
            }
        }
        return errors;
    }
}

var validator = new AttributeValidator<OrderRequest>(); // startup — reflects once
var errors    = validator.Validate(new OrderRequest { CustomerName = "", Total = 0 });
// ["CustomerName: Field is required", "Total: Must be between 0.01 and 10000"]
```

---

## Gotchas

- **Attribute constructor arguments must be compile-time constants.** You can't pass a variable or runtime value as an attribute argument.
- **Attributes are not executed at compile time.** They're just metadata. A source generator or analyzer must read them to act on them at build time; reflection reads them at runtime.
- **`GetCustomAttribute<T>()` returns null if absent, `GetCustomAttributes<T>()` returns empty array.** Don't confuse the two.
- **`IsDefined(type, inherit: true)` checks the inheritance chain.** `inherit: false` only checks the declared type.
- **Attribute instances are re-created on every `GetCustomAttributes` call.** Cache them if you need to call this frequently — build your list at startup.

---

## Interview Angle

**What they're really testing:** Whether you understand the compile-time metadata nature of attributes and how frameworks use reflection to discover them.

**Common question forms:**
- "What is an attribute in C# and how does it work?"
- "How does `[Required]` validation work?"
- "Can you create your own attribute?"

**The depth signal:** A senior explains attributes as metadata in the assembly, not code that executes — they only become active when something reads them via reflection, an analyzer, or a source generator. They know constructor argument types are limited to compile-time constants, that `GetCustomAttributes` creates new instances on each call (so cache them), and that `AttributeUsage` controls which elements the attribute can target.

---

## Related Topics

- [[dotnet/csharp/csharp-reflection.md]] — The runtime API for reading attributes from type metadata
- [[dotnet/csharp/csharp-expression-trees.md]] — Source generators that read attributes can emit expression trees or IL for zero-runtime-overhead validation

---

## Source

[Attributes — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/reflection-and-attributes/attribute-tutorial)

---
*Last updated: 2026-04-06*