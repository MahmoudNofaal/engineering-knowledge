# C# Variables

> A named storage location in memory that holds a value of a specific type, locked in at compile time — either declared explicitly or inferred by the compiler via `var`.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Named typed memory location |
| **Use when** | Always — variables are fundamental |
| **Avoid when** | N/A — but choose the right *kind* |
| **C# version** | C# 1.0 (var: C# 3.0, nullable refs: C# 8.0) |
| **Namespace** | N/A — language primitive |
| **Key keywords** | `var`, `const`, `readonly`, `static`, `volatile` |

---

## When To Use It

Variables are unavoidable — every non-trivial program uses them. The real decisions are *which kind*:

- Use `const` for values that are truly compile-time constants (pi, max retries, string keys). If the value could ever differ between environments, it is not a `const`.
- Use `readonly` for values set once at runtime (config, injected dependencies, constructor arguments).
- Use `var` when the type is obvious from the right-hand side. Avoid it when the type is unclear — `var result = Process()` tells a reader nothing.
- Use `int?` / `string?` when a value is genuinely optional. Never use sentinel values (`-1`, `""`, `"N/A"`) to represent "no value."

---

## Core Concept

C# is statically typed — every variable has a type that is fixed at compile time, not at runtime. When you write `var x = 5`, the compiler infers `int` immediately. `var` is not dynamic typing; it is just the compiler writing the type for you. The IL emitted is identical to `int x = 5`.

The most important thing to understand about variables is the **value vs reference split**. Value types (`int`, `bool`, `double`, structs) store their data directly in the variable's memory slot. Assigning one to another copies the data. Reference types (classes, `string`, arrays) store a pointer — the variable holds an address, not the data itself. Assigning one to another copies the pointer, so both variables now point at the same object. This distinction drives a whole category of bugs.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Basic typed variables, `const`, `readonly` |
| C# 3.0 | .NET 3.5 | `var` type inference introduced |
| C# 7.0 | .NET Core 1.0 | `out` variables inline (`TryParse("x", out int n)`) |
| C# 8.0 | .NET Core 3.0 | Nullable reference types (`string?`) as opt-in |
| C# 9.0 | .NET 5 | `nint` / `nuint` native-sized integers |
| C# 10.0 | .NET 6 | `global using`, `const` interpolated strings |
| C# 11.0 | .NET 7 | `required` modifier on fields and properties |

*Before C# 3.0, every variable had to be explicitly typed. Before C# 8.0, all reference type variables implicitly allowed `null` with no compiler warning.*

---

## Performance

| Variable kind | Storage | GC involved? | Notes |
|---|---|---|---|
| Value type local | Stack | No | Freed when scope exits |
| Reference type local | Heap (object) + stack (pointer) | Yes | GC tracks the heap object |
| `const` | Baked into IL | No | No runtime storage at all |
| `static` field | Heap (static segment) | No (roots) | Lives for AppDomain lifetime |
| Captured variable (closure) | Heap (display class) | Yes | Moves off stack when captured |

**Allocation behaviour:** Local value types (`int`, `bool`, `struct`) cost zero heap allocations. Every `new SomeClass()` is a heap allocation. Closures that capture local variables secretly allocate a compiler-generated class on the heap to hold those variables.

**Benchmark notes:** For the vast majority of code, variable *kind* has no measurable performance impact. It matters in tight loops (avoid boxing value types), in hot-path code that runs millions of times per second (prefer stack-allocated values), and when diagnosing GC pressure (captured variables in long-lived lambdas root objects indefinitely).

---

## The Code

**Basic declaration, inference, and `const` vs `readonly`**
```csharp
// Explicit type
int age = 30;
string name = "Alice";

// Inferred type — compiler writes 'int' in the IL
var score = 98.6;    // inferred as double, not float
var items = new List<string>(); // obvious from right side — var is fine here

// const: compile-time constant, baked into the caller's IL
public const int MaxRetries = 3;
public const string DefaultCurrency = "USD";

// readonly: set once at runtime, only in constructor or field initializer
public class Config
{
    public readonly string ConnectionString;

    public Config(string connStr)
    {
        ConnectionString = connStr; // only valid here
    }
}
```

**Value type vs reference type assignment**
```csharp
// Value type: copied — changes to b don't affect a
int a = 10;
int b = a;
b = 99;
Console.WriteLine(a); // 10 — unchanged

// Reference type: shared pointer — both variables point at same object
var listA = new List<int> { 1, 2, 3 };
var listB = listA;   // copies the pointer, not the list
listB.Add(4);
Console.WriteLine(listA.Count); // 4 — same object was mutated

// String exception: reference type that behaves like value type (immutable)
string s1 = "hello";
string s2 = s1;
s2 = "world";        // creates new string, rebinds s2 — s1 untouched
Console.WriteLine(s1); // "hello"
```

**Nullable types and null-handling operators**
```csharp
int? maybeAge = null;           // Nullable<int> — value or no value
int definite = maybeAge ?? 0;   // null-coalescing: fallback to 0

string? maybeNull = GetFromConfig();
int length = maybeNull?.Length ?? 0; // null-conditional + coalescing
maybeNull ??= "default";        // assign only if null (C# 8+)

// Inline out variable (C# 7+)
if (int.TryParse(userInput, out int parsed))
    Console.WriteLine(parsed);
// 'parsed' is scoped to the if block and beyond
```

**`const` vs `readonly static` — the deployment trap**
```csharp
// In a library:
public const int Version = 3;
public static readonly int RuntimeVersion = ComputeVersion();

// const is baked into the CALLER'S IL at compile time.
// If you change Version to 4 and recompile only the library,
// consuming assemblies still see 3 until THEY are also recompiled.
// readonly static is resolved at runtime — always fresh.
```

---

## Real World Example

In a production ASP.NET Core application, an `OrderService` receives configuration through dependency injection and uses a mix of `const`, `readonly`, and nullable variables to enforce correct semantics throughout its lifetime.

```csharp
public class OrderService
{
    // const: truly fixed rule, safe to bake into callers
    private const int MaxItemsPerOrder = 100;
    private const string DefaultCurrency = "GBP";

    // readonly: set once from DI — never changes after construction
    private readonly IOrderRepository _repository;
    private readonly ILogger<OrderService> _logger;
    private readonly string _region;

    public OrderService(
        IOrderRepository repository,
        ILogger<OrderService> logger,
        IOptions<OrderOptions> options)
    {
        _repository = repository;
        _logger = logger;
        _region = options.Value.Region ?? DefaultCurrency; // ?? for optional config
    }

    public async Task<OrderResult> PlaceOrderAsync(
        OrderRequest request,
        CancellationToken ct = default)
    {
        // var: type is obvious from right-hand side
        var existingOrder = await _repository.FindAsync(request.ReferenceId, ct);

        // int?: genuinely nullable — user may not have a loyalty account
        int? loyaltyPoints = await _repository.GetLoyaltyPointsAsync(request.UserId, ct);
        decimal discount = loyaltyPoints.HasValue
            ? CalculateDiscount(loyaltyPoints.Value)
            : 0m;

        if (request.Items.Count > MaxItemsPerOrder)
        {
            _logger.LogWarning("Order {Id} exceeds max items", request.ReferenceId);
            return OrderResult.Failed($"Cannot exceed {MaxItemsPerOrder} items");
        }

        return OrderResult.Success(discount);
    }

    private static decimal CalculateDiscount(int points) => points * 0.001m;
}
```

*The key insight: each variable kind carries a semantic contract — `const` says "this never changes anywhere", `readonly` says "this is set once and then immutable", `var` says "the type is obvious from context", and `int?` says "the absence of a value is a legitimate state, not an error."*

---

## Common Misconceptions

**"`var` is dynamic typing — the type can change at runtime"**
`var` is resolved entirely at compile time. The IL is byte-for-byte identical to writing the explicit type. `var x = 5` makes `x` permanently an `int`. You cannot later write `x = "hello"` — the compiler rejects it. `dynamic` is the keyword for actual runtime typing.

**"`const` and `static readonly` are interchangeable"**
They're not, and the difference bites you in library code. `const` values are embedded directly into the consuming assembly's IL — if you ship a library with `const int Version = 3` and later change it to `4`, any code compiled against the old library still sees `3` until it is recompiled. `static readonly` is read at runtime from the declaring assembly, so it's always current. Use `const` only for truly universal truths (math constants, fixed protocol values); use `static readonly` for everything else.

**"A `readonly` field means the object it points to can't be mutated"**
`readonly` prevents the field from being *reassigned*. The object itself can still be mutated. `private readonly List<string> _items = new()` means `_items` can't be pointed at a different list — but `_items.Add("x")` works fine. True deep immutability requires `IReadOnlyList<T>` or immutable collection types.

---

## Gotchas

- **`var` with numeric literals defaults to `double`, not `float`.** `var x = 1.5` is a `double`. `float x = 1.5` is a compile error — you need `1.5f`. This bites people coming from Python where floats are the default decimal type.

- **Captured variables in lambdas are captured by reference, not by value.** In a `for` loop, every lambda that captures `i` captures the *same* variable `i`. By the time the lambdas execute, `i` has its final loop value. Fix: copy to a local inside the loop: `int copy = i; actions.Add(() => Process(copy));`

- **Assigning a reference type does not clone it.** `var b = a` when `a` is a class gives you two variables pointing at one object. If you want independence, call `a.Clone()`, use a copy constructor, or use `new SomeClass(a.Property1, a.Property2)`.

- **`const` in a library assembly is a deployment hazard.** If any external code is compiled against your library, it embeds your `const` values. Changing the constant later requires recompiling everything downstream — something build systems don't always enforce. Prefer `static readonly` in any public API.

- **Nullable reference types (`string?`) are warnings, not errors, by default.** Enabling `<Nullable>enable</Nullable>` gives you compiler warnings on potential null dereferences — but warnings don't stop compilation. You can suppress them all with `!` (the null-forgiving operator) and still ship code that crashes. The feature is only as useful as your discipline in fixing the warnings.

---

## Interview Angle

**What they're really testing:** Whether you understand the value vs reference type memory model and can predict the behaviour of assignment — not just whether you know the syntax.

**Common question forms:**
- "What's the difference between `const` and `readonly`?"
- "What happens when you do `var b = a` for a class vs a struct?"
- "Is `string` a value type or reference type, and why does it behave like one?"

**The depth signal:** A junior says "`const` is for constants and `readonly` is for fields." A senior explains that `const` is resolved at compile time and embedded in the caller's IL — meaning changing it in a library without recompiling consumers silently breaks things — while `readonly` is resolved at runtime. On value vs reference, a senior brings up the closure capture gotcha: a loop variable captured in a lambda isn't copied, so all closures see the final loop value — and knows that the compiler-generated display class is what makes this happen.

**Follow-up questions to expect:**
- "What's a closure? How does variable capture work under the hood?"
- "How would you make a reference-type field truly immutable?"

---

## Related Topics

- [[dotnet/csharp/csharp-value-vs-reference-types.md]] — Deep dive into stack vs heap, boxing/unboxing, and why assignment behaves differently for each
- [[dotnet/csharp/csharp-nullable-types.md]] — `Nullable<T>`, null-coalescing operators, and C# 8 nullable reference types in full
- [[dotnet/csharp/csharp-lambda.md]] — Closure capture semantics — the exact mechanism that makes the loop-variable gotcha happen
- [[dotnet/csharp/csharp-generics.md]] — Generic type parameters are variables at the type level; constraints restrict what T can be

---

## Source

[C# Variables — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/variables)

---

*Last updated: 2026-04-06*