# C# Reflection

> The ability to inspect and invoke types, methods, properties, and attributes at runtime — examine the structure of a type without knowing it at compile time, create instances dynamically, and call methods by name.

---

## Quick Reference

| | |
|---|---|
| **Entry point** | `typeof(T)` or `obj.GetType()` |
| **Key types** | `Type`, `MethodInfo`, `PropertyInfo`, `FieldInfo`, `ConstructorInfo` |
| **Cost** | Expensive — avoid in hot paths |
| **Alternatives** | Source generators, compiled delegates, `dynamic` |
| **C# version** | C# 1.0 |
| **Namespace** | `System.Reflection` |

---

## When To Use It

Use reflection when the types you need to work with are genuinely unknown at compile time — serialisers, dependency injection containers, ORMs, plugin architectures, test frameworks. These are infrastructure tools that must be generic across all user-defined types.

Don't use reflection in hot paths or application-level code where the types are known. The overhead (10–1000× slower than direct calls), the loss of compile-time safety, and the `ArgumentException`/`NullReferenceException` mines make it painful to maintain.

---

## Core Concept

At runtime, every type in .NET has a corresponding `Type` object in a metadata table. `typeof(Order)` and `new Order().GetType()` both return a reference to that same `Type` object. From it, you can enumerate members, get `MethodInfo`/`PropertyInfo` objects, and invoke them.

The cost model: `GetType()` is fast; `GetMethod` / `GetProperty` is moderate; `MethodInfo.Invoke()` is expensive — roughly 10–100× slower than a direct call due to boxing, argument array allocation, and security checks. Cache `MethodInfo` objects across calls; never call `GetMethod` in a loop.

For production infrastructure, compile reflection discoveries to delegates once using `Expression.Lambda`, `Delegate.CreateDelegate`, or source generators.

---

## The Code

**Inspecting types and members**
```csharp
Type t = typeof(Order);
Console.WriteLine(t.FullName);           // "MyApp.Models.Order"
Console.WriteLine(t.IsClass);            // true
Console.WriteLine(t.GetInterfaces()[0]); // first implemented interface

// Properties
foreach (PropertyInfo prop in t.GetProperties())
    Console.WriteLine($"{prop.Name}: {prop.PropertyType.Name}");

// Methods (public instance only by default)
MethodInfo? method = t.GetMethod("CalculateTotal");
```

**Invoking methods dynamically**
```csharp
Type t       = typeof(Calculator);
object calc  = Activator.CreateInstance(t)!;
MethodInfo m = t.GetMethod("Add", new[] { typeof(int), typeof(int) })!;

int result = (int)m.Invoke(calc, new object[] { 3, 4 })!; // 7
// Boxing int args, array allocation, security check — expensive
```

**Reading and writing properties**
```csharp
object order = Activator.CreateInstance(typeof(Order))!;
PropertyInfo totalProp = typeof(Order).GetProperty("Total")!;

totalProp.SetValue(order, 99.99m); // boxing decimal — expensive
decimal val = (decimal)totalProp.GetValue(order)!;
```

**Compiling reflection to a delegate — cache the cost**
```csharp
// For a method that will be called many times, compile once to a delegate
MethodInfo method = typeof(Order).GetMethod("CalculateTotal")!;
var compiled = (Func<Order, decimal>)Delegate.CreateDelegate(
    typeof(Func<Order, decimal>), method);

// Subsequent calls are direct delegate invocations — fast
decimal total = compiled(order);
```

**Reading custom attributes**
```csharp
[AttributeUsage(AttributeTargets.Property)]
public class RequiredAttribute : Attribute { }

public class Order
{
    [Required] public string CustomerName { get; set; } = "";
    public decimal Total { get; set; }
}

// Discover properties marked [Required]
var requiredProps = typeof(Order)
    .GetProperties()
    .Where(p => p.IsDefined(typeof(RequiredAttribute), inherit: true))
    .ToList();
```

---

## Real World Example

A simple object mapper uses reflection to copy properties between two types with matching names — cached for performance.

```csharp
public static class PropertyMapper
{
    private static readonly ConcurrentDictionary<(Type, Type), Action<object, object>> _cache = new();

    public static TDest Map<TSource, TDest>(TSource source) where TDest : new()
    {
        var mapAction = _cache.GetOrAdd((typeof(TSource), typeof(TDest)), CreateMapper);
        var dest = new TDest();
        mapAction(source!, dest);
        return dest;
    }

    private static Action<object, object> CreateMapper((Type src, Type dst) key)
    {
        var srcProps = key.src.GetProperties(BindingFlags.Public | BindingFlags.Instance);
        var dstProps = key.dst.GetProperties(BindingFlags.Public | BindingFlags.Instance)
            .ToDictionary(p => p.Name);

        var pairs = srcProps
            .Where(sp => dstProps.TryGetValue(sp.Name, out var dp) && dp.PropertyType == sp.PropertyType)
            .Select(sp => (sp, dstProps[sp.Name]))
            .ToList();

        // Build and compile Expression tree — reflects once, runs fast thereafter
        var srcParam = Expression.Parameter(typeof(object), "src");
        var dstParam = Expression.Parameter(typeof(object), "dst");

        var assignments = pairs.Select(p =>
            (Expression)Expression.Assign(
                Expression.Property(Expression.Convert(dstParam, key.dst), p.Item2),
                Expression.Property(Expression.Convert(srcParam, key.src), p.Item1)));

        var body   = Expression.Block(assignments);
        var lambda = Expression.Lambda<Action<object, object>>(body, srcParam, dstParam);
        return lambda.Compile();
    }
}
```

*The insight: reflection runs once per type pair (discovery + compilation). Subsequent mappings invoke the compiled lambda — direct property reads and writes, no reflection overhead.*

---

## Gotchas

- **`GetMethod` with ambiguous name throws.** If a method is overloaded, pass the parameter types: `GetMethod("Add", new[] { typeof(int), typeof(int) })`.
- **`Invoke` returns `object` — must cast.** The cast can fail if the return type doesn't match expectations.
- **`Activator.CreateInstance` requires a public parameterless constructor.** Types with DI constructor parameters need a custom factory.
- **Reflection doesn't see private members by default.** Pass `BindingFlags.NonPublic | BindingFlags.Instance` to access private state.
- **Trimming (AOT/Native AOT) removes unused members.** Reflection depends on metadata that linker trimming can remove. Annotate with `[DynamicallyAccessedMembers]` or prefer source generators.

---

## Interview Angle

**What they're really testing:** Whether you understand the cost model and know when to cache or compile reflection discoveries.

**Common question forms:**
- "How does dependency injection work under the hood?"
- "When would you use reflection and what are the risks?"
- "How would you make reflection calls faster?"

**The depth signal:** A senior names the cost model (discovery slow, invoke expensive), always caches `MethodInfo` and compiles to delegates for repeated calls, and mentions source generators or `[DynamicallyAccessedMembers]` as the AOT-safe alternative.

---

## Related Topics

- [[dotnet/csharp/csharp-expression-trees.md]] — The bridge between reflection and compiled performance
- [[dotnet/csharp/csharp-attributes.md]] — The primary reason to read type metadata at runtime
- [[dotnet/csharp/csharp-generics.md]] — Generics often replace reflection for type-parameterised code

---

## Source

[Reflection — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/reflection-and-attributes/)

---
*Last updated: 2026-04-06*