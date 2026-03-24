# C# Reflection

> Reflection is the ability of your code to inspect and manipulate its own types, methods, and properties at runtime — without knowing them at compile time.

---

## When To Use It

Use reflection when you need to work with types you don't know until runtime — building serializers, plugin loaders, dependency injection containers, or mapping libraries. It's also the right tool when you need to read custom attributes at runtime (e.g., validation or routing metadata).

Don't use it in hot paths. Reflection is 10–100x slower than direct calls. Also avoid it as a shortcut to bypass encapsulation — if you find yourself invoking private members in production code, it's a design smell, not a clever trick.

---

## Core Concept

When .NET compiles your code, it stores metadata about every type, method, field, and property inside the assembly (the `.dll`). Reflection is the API that lets you read and use that metadata while the program is running. You start with a `Type` object — either via `typeof(MyClass)` or `obj.GetType()` — and from there you can get handles to any member of that type. Once you have a handle (a `MethodInfo`, `PropertyInfo`, etc.), you can call it, read it, or write to it against any instance of that type. The key mental model: reflection treats your code as data.

---

## The Code
```csharp
// --- Basic: inspect a type's members ---
using System.Reflection;

public class Order
{
    public int Id { get; set; }
    public string? Status { get; private set; }

    public void Ship() => Status = "Shipped";
}

Type type = typeof(Order);

foreach (var prop in type.GetProperties(BindingFlags.Public | BindingFlags.Instance))
    Console.WriteLine($"{prop.Name}: {prop.PropertyType.Name}");

foreach (var method in type.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly))
    Console.WriteLine($"Method: {method.Name}");
```
```csharp
// --- Invoke a method dynamically ---
var order = new Order { Id = 1 };
MethodInfo? ship = typeof(Order).GetMethod("Ship");
ship?.Invoke(order, null);   // equivalent to order.Ship()
Console.WriteLine(order.Id); // 1
```
```csharp
// --- Read and write a private property setter ---
var order = new Order { Id = 42 };
PropertyInfo? status = typeof(Order).GetProperty("Status");
status?.SetValue(order, "Cancelled");          // bypasses private setter
Console.WriteLine(status?.GetValue(order));    // "Cancelled"
```
```csharp
// --- Create an instance without knowing the type at compile time ---
// (typical in plugin loaders / DI containers)
string typeName = "MyApp.Services.EmailService";
Type? serviceType = Type.GetType(typeName);
object? instance = serviceType is not null
    ? Activator.CreateInstance(serviceType)
    : null;
```
```csharp
// --- Read custom attributes (common for frameworks) ---
[AttributeUsage(AttributeTargets.Property)]
public class RequiredAttribute : Attribute { }

public class UserForm
{
    [Required] public string Email { get; set; } = "";
    public string? Nickname { get; set; }
}

foreach (var prop in typeof(UserForm).GetProperties())
{
    bool isRequired = prop.GetCustomAttribute<RequiredAttribute>() is not null;
    Console.WriteLine($"{prop.Name} required: {isRequired}");
}
```

---

## Gotchas

- **`BindingFlags` defaults exclude what you expect.** `GetMethods()` with no flags only returns `Public | Instance`. Private members, static members, and inherited members each require explicit flags. Forgetting `BindingFlags.DeclaredOnly` returns inherited `object` methods too, bloating your results.
- **`Invoke` boxes value types.** Passing an `int` or `struct` as an argument to `Invoke(obj, args[])` causes boxing allocations on every call. In tight loops this is a measurable GC hit — cache delegates via `MethodInfo.CreateDelegate` instead.
- **`Type.GetType(string)` silently returns null.** If the type name is wrong or the assembly isn't loaded, you get `null` — no exception. Always null-check, and for cross-assembly types use the assembly-qualified name: `"MyApp.Order, MyApp"`.
- **Reflection ignores access modifiers — intentionally.** `SetValue` on a private property works fine. That's not a bug; it's by design. Be deliberate: this is how serializers and mappers work, but accidentally mutating private state from arbitrary caller code is a real footgun.
- **AOT and trimming break reflection.** With Native AOT or aggressive IL trimming (Blazor, mobile, .NET 8+ publish modes), members accessed only via reflection can be stripped. You must annotate with `[DynamicallyAccessedMembers]` or the linker will silently remove your target and you'll get a `NullReferenceException` at runtime.

---

## Interview Angle

**What they're really testing:** Whether you understand the boundary between compile-time and runtime type systems, and the performance and safety trade-offs of bypassing the type system.

**Common question form:** "How would you build a lightweight DI container?" or "How does JSON serialization work under the hood?" or "When would you use reflection vs generics?"

**The depth signal:** A junior knows `typeof` and `GetProperties()`. A senior explains *why* production frameworks like System.Text.Json, EF Core, and ASP.NET route registration don't just run raw reflection — they cache `MethodInfo` / `PropertyInfo` objects in a `ConcurrentDictionary<Type, ...>` on first access, and then use compiled expression trees or `ILEmit` to get delegate-speed invocation without re-paying the reflection cost on every call. The senior also knows `[DynamicallyAccessedMembers]` and what breaks silently under AOT.

---

## Related Topics

- [[dotnet/expression-trees.md]] — the next step after reflection: compile a `MethodInfo` into a typed delegate for near-native performance
- [[dotnet/source-generators.md]] — move reflection-style code generation to compile time; eliminates runtime overhead and AOT issues entirely
- [[dotnet/dependency-injection.md]] — DI containers are the most common production use of reflection; understanding reflection explains how they work internally
- [[dotnet/attributes-and-metadata.md]] — reflection is how custom attributes are read at runtime; the two topics are inseparable

---

## Source

[https://learn.microsoft.com/en-us/dotnet/fundamentals/reflection/reflection](https://learn.microsoft.com/en-us/dotnet/fundamentals/reflection/reflection)

---
*Last updated: 2026-03-23*