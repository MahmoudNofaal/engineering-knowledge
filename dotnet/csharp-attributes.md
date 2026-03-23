# C# Attributes

> An attribute is a declarative annotation you attach to a type, method, property, or parameter that embeds metadata into the assembly, readable at runtime via reflection or at compile time via source generators.

---

## When To Use It

Use attributes when a framework or tool needs to know something about your code without you having to write glue code — serialization hints, validation rules, routing, test markers, authorization policies, compiler warnings. They are the right mechanism when the metadata is orthogonal to the logic: `[Required]`, `[HttpGet]`, `[Fact]`, `[JsonIgnore]` all annotate without changing what the method or property actually does. Do not use attributes for runtime business logic that other developers need to find and understand — logic buried in attribute-driven pipelines is hard to trace. Do not create custom attributes unless you have the reflection or source-generator infrastructure to consume them; an attribute nobody reads is dead weight.

---

## Core Concept

An attribute is just a class that inherits from `System.Attribute`. When you write `[Serializable]` above a class, the compiler embeds a reference to `SerializableAttribute` in the assembly's metadata. Nothing runs at that point — the attribute is data, not code. At runtime, any code that has a reference to the type (a framework, a validator, a test runner) can call `GetCustomAttributes()` via reflection to find the attribute and read its properties. The `AttributeUsage` attribute on the attribute class itself controls where it can be applied and whether multiple instances are allowed. Source generators take this further — they read attributes at compile time and generate new code, eliminating the reflection cost entirely.

---

## The Code
```csharp
// --- Using built-in attributes ---
[Obsolete("Use NewMethod() instead.", error: false)] // warning at call site
public void OldMethod() { }

[Flags]
public enum Permissions
{
    None    = 0,
    Read    = 1,
    Write   = 2,
    Execute = 4,
    All     = Read | Write | Execute
}

// --- Custom attribute definition ---
[AttributeUsage(
    AttributeTargets.Class | AttributeTargets.Method,
    AllowMultiple = false,   // only one instance per target
    Inherited = true)]       // subclasses inherit it
public sealed class AuditAttribute : Attribute
{
    public string Category { get; }
    public bool   LogArgs  { get; init; }

    public AuditAttribute(string category) => Category = category;
}

// --- Applying the custom attribute ---
[Audit("Orders", LogArgs = true)]
public class OrderService
{
    [Audit("Payment")]
    public void ProcessPayment(decimal amount) { }
}

// --- Reading attributes via reflection ---
Type type = typeof(OrderService);

AuditAttribute? classAttr = type.GetCustomAttribute<AuditAttribute>();
Console.WriteLine(classAttr?.Category);  // Orders

MethodInfo method = type.GetMethod(nameof(OrderService.ProcessPayment))!;
AuditAttribute? methodAttr = method.GetCustomAttribute<AuditAttribute>();
Console.WriteLine(methodAttr?.Category); // Payment

// All attributes on a type (multiple)
foreach (Attribute attr in type.GetCustomAttributes(inherit: true))
    Console.WriteLine(attr.GetType().Name);

// --- Attribute on a parameter (caller info) ---
using System.Runtime.CompilerServices;

public static void Log(
    string message,
    [CallerMemberName] string member = "",
    [CallerFilePath]   string file   = "",
    [CallerLineNumber] int    line   = 0)
{
    Console.WriteLine($"[{file}:{line} {member}] {message}");
}

Log("Starting"); // compiler fills in member, file, line automatically

// --- Data annotation attributes (validation) ---
using System.ComponentModel.DataAnnotations;

public class CreateUserRequest
{
    [Required]
    [StringLength(50, MinimumLength = 2)]
    public string Name { get; set; } = "";

    [EmailAddress]
    public string Email { get; set; } = "";

    [Range(18, 120)]
    public int Age { get; set; }
}

var request = new CreateUserRequest { Name = "A", Email = "bad", Age = 15 };
var context  = new ValidationContext(request);
var results  = new List<ValidationResult>();
bool valid   = Validator.TryValidateObject(request, context, results, validateAllProperties: true);

foreach (ValidationResult r in results)
    Console.WriteLine(r.ErrorMessage);

// --- Assembly-level attribute ---
[assembly: System.CLSCompliant(true)]
```

---

## Gotchas

- **Attribute instances are not created until you call `GetCustomAttribute()`** — and a new instance is created each time you call it. If you read attributes in a hot path (per-request, per-item), cache the result. Reflection is expensive; reading attributes in a tight loop is a performance problem that doesn't show up until load testing.
- **`AttributeUsage(Inherited = true)` does not mean the attribute appears on the derived type's `GetCustomAttributes()` by default.** You must pass `inherit: true` to `GetCustomAttributes(inherit: true)` at the call site. If you pass `false` (the default overload), inherited attributes are invisible, which causes silent misconfiguration in frameworks that forget the flag.
- **`[Flags]` enums require power-of-two values to work correctly.** `[Flags]` only affects `ToString()` and `Enum.HasFlag()` formatting — it does not automatically assign values. If you write `Read = 1, Write = 2, Execute = 3` instead of `Execute = 4`, bitwise combinations produce wrong results and `HasFlag` returns false negatives.
- **You cannot pass arbitrary objects as attribute constructor arguments.** Attribute parameters must be compile-time constants: primitives, strings, `Type` objects, enums, or arrays of those. Passing a `List<string>`, a class instance, or a runtime value is a compile error. Work around this by passing a `Type` and resolving it via reflection inside the consuming infrastructure.
- **`sealed` on a custom attribute class matters.** If your attribute is not sealed, derived attribute classes inherit from it, and `GetCustomAttribute<MyAttribute>()` will miss subclasses — it returns `null` even if a derived attribute is present. Either seal the attribute to prevent subclassing, or use `GetCustomAttributes(typeof(MyAttribute), inherit: true)` and check with `is`.

---

## Interview Angle

**What they're really testing:** Whether you understand that attributes are passive metadata — not executed code — and that something has to actively read them to have any effect.

**Common question form:** "How does `[Authorize]` work in ASP.NET Core?" or "What is an attribute and when would you create a custom one?" or "How do you read attribute metadata at runtime?"

**The depth signal:** A junior says "attributes add metadata to code and frameworks read them." A senior explains the full chain: attribute class inherits `Attribute`, compiler embeds metadata in the assembly, framework calls `GetCustomAttributes()` via reflection at startup or per-request to build a pipeline — and names the concrete cost: reflection allocates a new attribute instance per call, so production code caches results (ASP.NET Core builds its filter pipeline once at startup, not per request); knows `AttributeUsage(Inherited = true)` still requires `inherit: true` at the call site; and can describe source generators as the compile-time alternative that eliminates the reflection cost entirely by generating code during build rather than reading attributes at runtime.

---

## Related Topics

- [[dotnet/csharp-reflection.md]] — Reflection is the runtime mechanism that reads attribute metadata; understanding both together completes the picture of how attribute-driven frameworks actually work.
- [[dotnet/csharp-source-generators.md]] — Source generators read attributes at compile time and emit new code, giving you the expressiveness of attributes without the runtime reflection overhead.
- [[dotnet/aspnetcore-filters-and-middleware.md]] — ASP.NET Core action filters (`[Authorize]`, `[ValidateAntiForgeryToken]`, custom `IActionFilter`) are the most common real-world use of attributes read at startup and applied per-request.
- [[dotnet/csharp-records.md]] — Records make heavy use of attributes like `[JsonPropertyName]`, `[Required]`, and `[JsonIgnore]` on properties; understanding attributes explains why the serializer behaves the way it does.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/reflection-and-attributes/](https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/reflection-and-attributes/)

---
*Last updated: 2026-03-23*