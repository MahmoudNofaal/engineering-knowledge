# C# Generics

> Generics let you write a class, method, or interface once with a type placeholder, then use it with any concrete type at compile time — with full type safety and no boxing.

---

## When To Use It
Use generics any time you're writing logic that doesn't depend on a specific type — collections, repositories, result wrappers, caches, pipelines. They're the alternative to using `object` everywhere, which loses type safety and boxes value types. Don't introduce a generic type parameter when the method or class genuinely only makes sense for one type — unnecessary generics add complexity without benefit.

---

## Core Concept
Before generics, you'd write a list that held `object`, cast everything going in and out, and hope nothing blew up at runtime. Generics let the compiler do that work: you write `List<T>` once, and when someone writes `List<int>`, the compiler generates a version specifically for `int` — no cast needed, no boxing, a compile error if you try to add a `string`. The `T` is just a placeholder that gets filled in at the call site or construction site. Constraints (`where T : ...`) let you say "T must implement this interface" or "T must be a class" so you can actually call methods on T inside the generic code.

---

## The Code

**Generic class — typed repository pattern**
```csharp
public class Repository<T> where T : class
{
    private readonly List<T> _store = new();

    public void Add(T item) => _store.Add(item);

    public T? Find(Func<T, bool> predicate)
        => _store.FirstOrDefault(predicate);

    public IReadOnlyList<T> GetAll() => _store.AsReadOnly();
}

var orders = new Repository<Order>();
orders.Add(new Order(1, "Alice"));
orders.Add(new Order(2, "Bob"));

var found = orders.Find(o => o.Id == 2);
Console.WriteLine(found); // Order #2 for Bob
```

**Generic method — works on any type**
```csharp
// T is inferred from the argument — no need to specify it explicitly
public static T Clamp<T>(T value, T min, T max) where T : IComparable<T>
{
    if (value.CompareTo(min) < 0) return min;
    if (value.CompareTo(max) > 0) return max;
    return value;
}

Console.WriteLine(Clamp(15, 0, 10));      // 10
Console.WriteLine(Clamp(5, 0, 10));       // 5
Console.WriteLine(Clamp(3.7, 0.0, 3.5)); // 3.5
```

**Constraints — controlling what T can be**
```csharp
// new() — T must have a parameterless constructor
public static T CreateDefault<T>() where T : new() => new T();

// Multiple constraints
public static void Process<T>(T item)
    where T : class,          // must be a reference type
              IDisposable,    // must implement IDisposable
              new()           // must have parameterless constructor
{
    using var resource = item;
    Console.WriteLine($"Processing {resource.GetType().Name}");
}

// Constraint to a base class
public static void Render<T>(T shape) where T : Shape
{
    Console.WriteLine($"Rendering {shape.GetType().Name}, area={shape.Area()}");
}
```

**Generic result wrapper — common production pattern**
```csharp
public class Result<T>
{
    public T? Value { get; }
    public string? Error { get; }
    public bool IsSuccess => Error is null;

    private Result(T value) => Value = value;
    private Result(string error) => Error = error;

    public static Result<T> Ok(T value) => new(value);
    public static Result<T> Fail(string error) => new(error);
}

Result<Order> result = GetOrder(42);

if (result.IsSuccess)
    Console.WriteLine(result.Value);
else
    Console.WriteLine($"Failed: {result.Error}");
```

**Multiple type parameters**
```csharp
public class Pair<TFirst, TSecond>
{
    public TFirst First { get; }
    public TSecond Second { get; }

    public Pair(TFirst first, TSecond second)
        => (First, Second) = (first, second);

    public void Deconstruct(out TFirst first, out TSecond second)
        => (first, second) = (First, Second);
}

var pair = new Pair<string, int>("Alice", 42);
var (name, age) = pair;
Console.WriteLine($"{name} is {age}"); // "Alice is 42"
```

---

## Gotchas

- **Generic type parameters are erased at the IL level for reference types but specialized for value types.** `List<string>` and `List<Order>` share one IL implementation. `List<int>` gets its own native compiled version — no boxing. This is why generics outperform `object`-based collections for value types specifically.
- **You can't use `T` as if it has methods unless you constrain it.** Writing `item.Id` inside a generic method where `T` is unconstrained is a compile error. You need `where T : IHasId` or similar. A common mistake is writing overly broad generics and then hitting a wall when you need to do something type-specific inside them.
- **`default(T)` is `null` for reference types and zeroed memory for value types.** If you return `default` from a generic method, callers with a value type `T` get `0` or `false`, not `null`. Nullable annotations (`T?` with a nullable constraint) are required to be explicit about this in modern C#.
- **Static fields on generic classes are per closed type.** `Cache<T>.Items` is a separate static field for `Cache<Order>`, `Cache<User>`, `Cache<int>`, etc. This is usually desirable, but if you intended one shared static across all usages, you've accidentally created one per `T`.
- **Variance (`in`/`out`) only applies to interfaces and delegates, not classes.** You can't make `List<T>` covariant. `IEnumerable<T>` is covariant (`out T`), which is why `IEnumerable<Dog>` is assignable to `IEnumerable<Animal>`. `List<Dog>` is not assignable to `List<Animal>` — trying this is a common runtime confusion that starts as a compile error in C#.

---

## Interview Angle
**What they're really testing:** Whether you understand why generics exist (type safety + performance over `object`), how constraints work, and the covariance/contravariance rules for generic interfaces.

**Common question form:** "What are generics and why use them over `object`?" or "What is a generic constraint?" or "Why can't you assign `List<Dog>` to `List<Animal>`?"

**The depth signal:** A junior says "generics let you reuse code with different types." A senior explains the two concrete benefits: compile-time type safety (no casts, errors caught early) and zero-boxing for value types (the JIT generates specialized code per value type, so `List<int>` never boxes). On the `List<Dog>` question, a senior explains invariance: if `List<Dog>` were assignable to `List<Animal>`, you could call `.Add(new Cat())` through the `List<Animal>` reference and corrupt the `List<Dog>` — so the compiler disallows it. They'll contrast this with `IEnumerable<T>` being covariant because `out T` means you can only read, never write, so there's no way to corrupt the source.

---

## Related Topics
- [[dotnet/csharp-interfaces.md]] — Generic interfaces (`IEnumerable<T>`, `IRepository<T>`) are the most common place generics appear in real codebases.
- [[dotnet/csharp-collections.md]] — `List<T>`, `Dictionary<TKey, TValue>`, `HashSet<T>` are all generic types; understanding generics explains how they work.
- [[dotnet/boxing-and-unboxing.md]] — Generics exist partly to eliminate boxing; understanding boxing makes the performance case for generics concrete.
- [[dotnet/csharp-delegates-and-func.md]] — `Func<T>`, `Action<T>`, `Predicate<T>` are generic delegates; they appear constantly in generic method signatures.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/generics](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/generics)

---
*Last updated: 2026-03-23*