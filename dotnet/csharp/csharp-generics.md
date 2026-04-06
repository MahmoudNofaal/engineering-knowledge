# C# Generics

> Generics let you write a class, method, or interface once with a type placeholder `T`, then use it with any concrete type at compile time — with full type safety and no boxing.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Parameterised types and methods — write once, use with any type |
| **Use when** | Logic that works the same regardless of the concrete type |
| **Avoid when** | Method/class only makes sense for one specific type |
| **C# version** | C# 2.0 (.NET 2.0) |
| **Namespace** | N/A — language feature |
| **Key keywords** | `<T>`, `where T :`, `default(T)`, `typeof(T)` |

---

## When To Use It

Use generics any time you're writing logic that doesn't depend on a specific type — collections, repositories, result wrappers, caches, pipelines, validators. They replace `object` everywhere, which loses type safety and boxes value types.

Don't introduce a type parameter when the method or class genuinely only makes sense for one type — unnecessary generics add complexity without benefit. The signal you need generics: you're copy-pasting a class or method and changing only the type name.

---

## Core Concept

Before generics, C# collections stored `object` — every insert cast to `object` (boxing for value types), every read cast back (unboxing, potential `InvalidCastException`). Generics solve both problems: the compiler substitutes the actual type at the use site, generating type-safe IL with no runtime casts.

For **reference types** (`List<string>`, `List<Order>`), the JIT generates one shared implementation. For **value types** (`List<int>`, `List<double>`), the JIT generates a **separate native code version per type** — `List<int>` is entirely different compiled code from `List<double>`. This is why value type generics have zero boxing — there's no `object` wrapper anywhere in the generated code.

**Constraints** (`where T : ...`) let you call methods on `T` inside the generic body. Without a constraint, `T` is treated as `object` — you can only call `object` methods on it. With `where T : IComparable<T>`, you can call `t.CompareTo(other)`.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 2.0 | .NET 2.0 | Generics introduced — `List<T>`, `Dictionary<K,V>`, generic methods |
| C# 2.0 | .NET 2.0 | Constraints: `where T : class/struct/new()/BaseClass/Interface` |
| C# 4.0 | .NET 4.0 | Covariance (`out T`) and contravariance (`in T`) on interfaces/delegates |
| C# 7.3 | .NET Core 2.1 | `unmanaged` constraint for unsafe pointer arithmetic |
| C# 8.0 | .NET Core 3.0 | `notnull` constraint |
| C# 11.0 | .NET 7 | Generic math: `where T : INumber<T>`, `IAdditionOperators<T,T,T>` |
| C# 11.0 | .NET 7 | `abstract static` members on generic interfaces |

*C# 11's generic math interfaces (`INumber<T>`) allow writing arithmetic operations over any numeric type. Before this, writing `T Add(T a, T b)` required separate overloads for `int`, `double`, `decimal`, etc.*

---

## Performance

| Scenario | Generic | Non-generic (`object`) |
|---|---|---|
| Value type storage | Zero boxing — native layout | One heap alloc per stored value |
| Method call on constraint | Direct call | Virtual dispatch or reflection |
| Type check | Compile time | `InvalidCastException` at runtime |
| `List<int>` vs `ArrayList` | Zero alloc per element | One heap alloc per `int` |
| `Func<int>` vs `Func<object>` | No boxing | Boxes the `int` return value |

**Allocation behaviour:** Generic collections for value types (`List<int>`, `HashSet<Guid>`) allocate only the backing array — no per-element boxing. Non-generic collections allocate a separate heap wrapper for every value type stored.

**Benchmark notes:** The performance argument for generics is strongest for high-frequency value type operations. For reference types, the primary benefit is type safety — catching type errors at compile time rather than at runtime.

---

## The Code

**Generic class — typed repository pattern**
```csharp
public interface IRepository<T> where T : class
{
    Task<T?> FindAsync(int id, CancellationToken ct = default);
    Task<IReadOnlyList<T>> GetAllAsync(CancellationToken ct = default);
    Task SaveAsync(T entity, CancellationToken ct = default);
}

// One base implementation works for ALL entity types
public abstract class EfRepository<T> : IRepository<T> where T : class
{
    protected readonly DbContext Context;
    protected readonly DbSet<T> DbSet;

    protected EfRepository(DbContext context)
    {
        Context = context;
        DbSet   = context.Set<T>();
    }

    public async Task<T?> FindAsync(int id, CancellationToken ct)
        => await DbSet.FindAsync(new object[] { id }, ct);

    public async Task<IReadOnlyList<T>> GetAllAsync(CancellationToken ct)
        => await DbSet.AsNoTracking().ToListAsync(ct);

    public async Task SaveAsync(T entity, CancellationToken ct)
    {
        Context.Entry(entity).State = EntityState.Modified;
        await Context.SaveChangesAsync(ct);
    }
}

// Concrete implementation = just the DI registration hook
public sealed class OrderRepository : EfRepository<Order>
{
    public OrderRepository(AppDbContext ctx) : base(ctx) { }
}
```

**Generic method with constraints**
```csharp
// T must implement IComparable<T> — needed to call CompareTo inside
public static T Clamp<T>(T value, T min, T max) where T : IComparable<T>
{
    if (value.CompareTo(min) < 0) return min;
    if (value.CompareTo(max) > 0) return max;
    return value;
}

// Type is inferred from the argument — no need to specify <T> explicitly
Console.WriteLine(Clamp(15, 0, 10));        // 10
Console.WriteLine(Clamp(5.5, 0.0, 10.0));  // 5.5
Console.WriteLine(Clamp("m", "a", "z"));   // "m"
```

**The full constraints toolkit**
```csharp
// class: T must be a reference type
public T? CreateIfAbsent<T>(bool condition) where T : class, new()
    => condition ? new T() : null;

// struct: T must be a value type (non-nullable)
public T GetValueOrDefault<T>(T? nullable) where T : struct
    => nullable ?? default;

// new(): T must have a public parameterless constructor
public T CreateDefault<T>() where T : new() => new T();

// Multiple constraints combined
public void ProcessItem<T>(T item)
    where T : class,            // reference type
              IDisposable,      // has Dispose
              new()             // has parameterless constructor
{
    using var resource = item;  // safe because IDisposable is guaranteed
    Console.WriteLine(resource.GetType().Name);
}

// notnull (C# 8): T cannot be a nullable reference type
public void RequireValue<T>(T value) where T : notnull
    => Console.WriteLine(value);

// unmanaged (C# 7.3): T can be used in unsafe pointer arithmetic
public unsafe void WriteToBuffer<T>(T value, byte* buffer) where T : unmanaged
    => *(T*)buffer = value;
```

**Generic result wrapper — common production pattern**
```csharp
public sealed class Result<T>
{
    public T? Value { get; }
    public string? Error { get; }
    public bool IsSuccess => Error is null;

    private Result(T value)       => Value = value;
    private Result(string error)  => Error = error;

    public static Result<T> Ok(T value)      => new(value);
    public static Result<T> Fail(string err) => new(err);

    // Chain operations — each can fail without manual IsSuccess checks
    public Result<TNext> Then<TNext>(Func<T, Result<TNext>> next)
        => IsSuccess ? next(Value!) : Result<TNext>.Fail(Error!);

    public Result<TNext> Map<TNext>(Func<T, TNext> map)
        => IsSuccess ? Result<TNext>.Ok(map(Value!)) : Result<TNext>.Fail(Error!);

    public override string ToString()
        => IsSuccess ? $"Ok({Value})" : $"Fail({Error})";
}
```

**Covariance and contravariance**
```csharp
// IEnumerable<out T>: covariant — more-specific assigns to less-specific
IEnumerable<Dog> dogs = new List<Dog>();
IEnumerable<Animal> animals = dogs;  // works: you can only read from IEnumerable

// IComparer<in T>: contravariant — less-specific assigns to more-specific
IComparer<Animal> animalComparer = Comparer<Animal>.Default;
IComparer<Dog> dogComparer = animalComparer;  // works: Animal comparison works for Dogs

// IList<T> is invariant — neither direction allowed
// IList<Animal> list = new List<Dog>(); // error — would let you Add a Cat
```

**Static abstract members — generic math (C# 11)**
```csharp
// Interfaces can require static methods — enables compile-time polymorphism
public interface IParser<T>
{
    static abstract T Parse(string input);
    static abstract bool TryParse(string input, out T result);
}

public record Temperature(double Celsius) : IParser<Temperature>
{
    public static Temperature Parse(string s) => new(double.Parse(s));
    public static bool TryParse(string s, out Temperature t)
    {
        if (double.TryParse(s, out double d)) { t = new(d); return true; }
        t = default!; return false;
    }
}

// Generic method: works with ANY IParser<T> — zero runtime dispatch overhead
static T ParseOrDefault<T>(string input, T fallback) where T : IParser<T>
    => T.TryParse(input, out T result) ? result : fallback;
```

---

## Real World Example

A generic validation pipeline runs all registered validators for any entity type. One infrastructure implementation handles `Order`, `Customer`, `Invoice` — adding validation for a new type requires only new validator classes.

```csharp
public interface IValidator<T>
{
    IReadOnlyList<string> Validate(T value);
}

public sealed class ValidationPipeline<T>
{
    private readonly IEnumerable<IValidator<T>> _validators;

    public ValidationPipeline(IEnumerable<IValidator<T>> validators)
        => _validators = validators;

    public ValidationResult Validate(T value)
    {
        var errors = _validators
            .SelectMany(v => v.Validate(value))
            .ToList();

        return errors.Count == 0
            ? ValidationResult.Ok()
            : ValidationResult.Fail(errors);
    }
}

// Concrete validators for Order
public sealed class OrderAmountValidator : IValidator<Order>
{
    private const decimal MaxOrderValue = 10_000m;

    public IReadOnlyList<string> Validate(Order order)
    {
        var errors = new List<string>();
        if (order.Total <= 0)           errors.Add("Order total must be positive");
        if (order.Total > MaxOrderValue) errors.Add($"Order total cannot exceed {MaxOrderValue:C}");
        return errors;
    }
}

public sealed class OrderItemsValidator : IValidator<Order>
{
    public IReadOnlyList<string> Validate(Order order)
    {
        if (order.Items.Count == 0)
            return ["Order must have at least one item"];

        return order.Items
            .Where(i => i.Quantity <= 0)
            .Select(i => $"Item {i.ProductId} has invalid quantity")
            .ToList();
    }
}

// DI registration — same pattern for every entity type
services.AddScoped<IValidator<Order>, OrderAmountValidator>();
services.AddScoped<IValidator<Order>, OrderItemsValidator>();
services.AddScoped<ValidationPipeline<Order>>();

// Adding Customer validation = new validators + registration, zero other changes
services.AddScoped<IValidator<Customer>, CustomerEmailValidator>();
services.AddScoped<ValidationPipeline<Customer>>();
```

*The key insight: `ValidationPipeline<T>` is written once and handles all domain types. The type parameter `T` is the only variation point — the orchestration, error collection, and result building are shared infrastructure. A new entity type requires only new validator classes; the pipeline itself never changes.*

---

## Common Misconceptions

**"Generics are just syntactic sugar for `object`"**
This is true for reference types (one shared IL implementation), but completely wrong for value types. `List<int>` has its own JIT-generated native code with no boxing whatsoever. `ArrayList` storing `int` allocates a heap wrapper for every single element. At high volumes, this difference is enormous — millions of heap allocations vs zero.

**"You can use `T` as if it has any methods"**
Without a constraint, `T` is treated as `System.Object` inside the generic body — you can only call `Equals`, `GetHashCode`, `ToString`, and `GetType`. Writing `item.Name` inside an unconstrained generic is a compile error. You need `where T : IHasName` before you can call any methods not on `object`.

**"`default(T)` is always `null`"**
`default(T)` is `null` for reference types, `0` for numeric types, `false` for `bool`, and zero-initialised fields for structs. In generic code, you don't know what `default(T)` is without a constraint. With `where T : class`, you know it's null. Without a constraint, it could be anything.

---

## Gotchas

- **Static fields on generic classes are per closed type.** `Cache<T>.Instance` is a separate field for `Cache<Order>`, `Cache<User>`, and `Cache<int>`. Usually this is what you want (separate caches per type). If you intended one shared static, move it to a non-generic base class.

- **You can't use arithmetic operators on unconstrained `T`.** `T Add(T a, T b) => a + b;` doesn't compile — `+` isn't defined on `object`. Before C# 11, this required separate overloads per numeric type. With C# 11's `where T : INumber<T>`, arithmetic on generic types works.

- **Covariance only works on generic interfaces/delegates, not classes.** `IEnumerable<Dog>` → `IEnumerable<Animal>` works. `List<Dog>` → `List<Animal>` does not — `List<T>` is invariant. If that assignment worked, you could call `.Add(new Cat())` through the `List<Animal>` reference, corrupting the original `List<Dog>`.

- **`new()` constraint requires a public parameterless constructor.** If you add a required constructor to an entity type, anything with `where T : new()` for that type breaks. This is a compile-time error, but can appear surprising mid-refactor.

- **Reflection on generic types requires `MakeGenericType`.** `Type.GetType("List<int>")` doesn't work. You need `typeof(List<>).MakeGenericType(typeof(int))`. Open (`<>`) and closed (`<int>`) generic types are different objects in the reflection API.

---

## Interview Angle

**What they're really testing:** Whether you understand why generics exist (type safety + zero boxing for value types), how the JIT handles specialisation, and how constraints unlock type-specific behaviour.

**Common question forms:**
- "What are generics and why use them over `object`?"
- "What is a generic constraint and why would you use one?"
- "Why can't you assign `List<Dog>` to `List<Animal>`?"
- "What's the performance difference between `List<int>` and `ArrayList`?"

**The depth signal:** A junior says "generics let you reuse code with different types." A senior explains two concrete benefits: compile-time type safety and zero boxing for value types (the JIT generates specialised native code per value type). On `List<Dog>` → `List<Animal>`, a senior explains invariance: that assignment would allow `.Add(new Cat())` through the `List<Animal>` reference, corrupting the `List<Dog>`. They contrast this with `IEnumerable<T>` being covariant because `out T` means read-only — you can never write a `Cat` into it.

**Follow-up questions to expect:**
- "How does the JIT handle `List<int>` vs `List<string>` differently at runtime?"
- "What does `where T : notnull` do?"
- "What are the generic math interfaces in C# 11?"

---

## Related Topics

- [[dotnet/csharp/csharp-interfaces.md]] — Generic interfaces (`IEnumerable<T>`, `IRepository<T>`) are the most common place generics appear
- [[dotnet/csharp/csharp-collections-list.md]] — `List<T>`, `Dictionary<K,V>`, `HashSet<T>` are all generic types
- [[dotnet/csharp/csharp-boxing-unboxing.md]] — Generics exist partly to eliminate boxing; understanding boxing makes the performance case concrete
- [[dotnet/csharp/csharp-delegates.md]] — `Func<T>`, `Action<T>`, `Predicate<T>` are generic delegates used in every generic method signature

---

## Source

[Generics — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/generics)

---

*Last updated: 2026-04-06*