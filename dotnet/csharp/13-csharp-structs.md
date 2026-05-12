# C# Structs

> A struct is a value type that stores its data directly, is copied on assignment, and is suited for small, immutable data with no identity — typically allocated on the stack.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Value type — copied on assignment, no GC per instance |
| **Use when** | Small (≤16 bytes), immutable, no inheritance, high-frequency allocation |
| **Avoid when** | >16 bytes, needs inheritance, will be boxed frequently, holds reference types |
| **C# version** | C# 1.0 (`readonly struct`: C# 7.2, `ref struct`: C# 7.2, `record struct`: C# 10) |
| **Namespace** | N/A — language primitive |
| **Key keywords** | `struct`, `readonly`, `ref struct`, `in`, `stackalloc` |

---

## When To Use It

Use a struct when the type represents a *value* rather than an *entity* — coordinates, colour, a temperature reading, a date range, a money amount. The guideline Microsoft publishes: prefer struct when the type is smaller than ~16 bytes, logically represents a single value (like primitives do), is immutable, and won't be frequently boxed.

Avoid structs when:
- **Size > 16 bytes**: copying 64 bytes on every method call is slower than copying an 8-byte pointer.
- **Frequent boxing**: storing in `object`, non-generic collections, or interface variables negates all benefit.
- **Mutable**: mutable structs produce silent bugs where modifications to copies look like modifications to originals.
- **Inheritance needed**: structs can implement interfaces but cannot inherit from other structs or classes.

---

## Core Concept

When you assign a struct to another variable, C# copies every byte — the two variables are fully independent. When you pass a struct to a method, the method gets its own copy. Changes to the copy don't affect the original. This is value semantics: the variable *is* the data, not a pointer to it.

Structs typically live on the stack when declared as local variables. Stack allocation means no GC involvement — the memory is freed automatically when the function returns. But this "structs on the stack" rule only applies to local variables. A struct field on a class lives on the heap with the class. A struct captured in a lambda moves to the heap. A struct in an array lives on the heap.

`readonly struct` (C# 7.2) tells the compiler the struct is immutable. This lets the JIT avoid defensive copies — when passing a `readonly struct` as `in`, the runtime can pass by reference directly without worrying that the method might mutate it.

`ref struct` (C# 7.2) enforces stack-only lifetime. A `ref struct` can never be boxed, stored in a field, captured in a lambda, or used across an `async` boundary. `Span<T>` and `ReadOnlySpan<T>` are `ref struct` types.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Basic structs |
| C# 7.2 | .NET Core 2.0 | `readonly struct` — enforces immutability, eliminates defensive copies |
| C# 7.2 | .NET Core 2.0 | `ref struct` — stack-only, enables `Span<T>` |
| C# 7.2 | .NET Core 2.0 | `in` parameter modifier — pass struct by reference, read-only |
| C# 8.0 | .NET Core 3.0 | `readonly` members on non-readonly structs |
| C# 10.0 | .NET 6 | `record struct` — value type with record semantics |
| C# 10.0 | .NET 6 | Parameterless constructor in structs (previously forbidden) |
| C# 11.0 | .NET 7 | `ref` fields in `ref struct` types |

*Before C# 10, structs could not have a custom parameterless constructor — `new MyStruct()` always zero-initialised without calling any code. C# 10 lifted this restriction.*

---

## Performance

| Operation | Struct (small) | Class equivalent |
|---|---|---|
| Allocation | Stack (free) | Heap allocation (GC pressure) |
| Assignment | Copy N bytes | Copy 8-byte pointer |
| Method pass | Copy N bytes | Copy 8-byte pointer |
| GC involvement | None (stack) | Yes (heap tracking) |
| Equality check | Field-by-field (reflection, slow!) | Reference check (O(1)) |
| Interface call | **Boxes** — heap allocation | No boxing |

**Allocation behaviour:** A local `Point` struct costs zero heap allocations. A `Point` field on a class lives on the heap with the class. Boxing (assigning to `object` or an interface) allocates a new heap wrapper each time.

**Benchmark notes:** The crossover point is roughly 16 bytes. Below that, the stack allocation savings outweigh the copy cost. Above that, copying becomes slower than the alternative heap allocation with a pointer copy. Profile before optimising — the compiler and JIT are often smarter than manual tuning.

---

## The Code

**Basic immutable struct**
```csharp
// readonly struct: compiler enforces immutability
// JIT can pass by reference internally (no defensive copies)
public readonly struct Point
{
    public double X { get; }
    public double Y { get; }

    public Point(double x, double y) => (X, Y) = (x, y);

    // Struct methods return new instances — no mutation
    public Point Translate(double dx, double dy) => new Point(X + dx, Y + dy);

    public double DistanceTo(Point other)
    {
        double dx = X - other.X, dy = Y - other.Y;
        return Math.Sqrt(dx * dx + dy * dy);
    }

    public override string ToString() => $"({X}, {Y})";
}

var p1 = new Point(1, 2);
var p2 = p1;           // full copy — p2 is independent
p2 = p2.Translate(5, 0);
Console.WriteLine(p1); // (1, 2) — p1 unchanged
Console.WriteLine(p2); // (6, 2)
```

**The mutable struct trap — what goes wrong**
```csharp
public struct MutablePoint
{
    public int X;
    public int Y;
}

var list = new List<MutablePoint> { new MutablePoint { X = 1, Y = 2 } };

// This silently does NOT modify the item in the list!
// The indexer returns a COPY; you mutate the copy, then discard it.
var temp = list[0];
temp.X = 99;
Console.WriteLine(list[0].X); // still 1 — the list item is untouched

// The compiler actually catches this for some cases:
// list[0].X = 99; // CS1612: Cannot modify the return value of 'List<>.this[int]'
// But not all cases produce an error — some silently do nothing.
```

**`readonly` member on a non-readonly struct (C# 8)**
```csharp
// When the whole struct can't be readonly, mark individual members
public struct Rectangle
{
    public double Width;
    public double Height;

    // readonly: guarantees this method doesn't modify any fields
    // Prevents the JIT from making a defensive copy when called via 'in'
    public readonly double Area => Width * Height;
    public readonly override string ToString() => $"{Width}x{Height}";
}
```

**`in` parameter: pass by reference, read-only**
```csharp
// Without 'in': copies the entire Matrix4x4 (64 bytes) on every call
static float TraceNoCopy(Matrix4x4 m) => m.M11 + m.M22 + m.M33 + m.M44;

// With 'in': passes an 8-byte pointer — no copy, no mutation allowed
static float Trace(in Matrix4x4 m) => m.M11 + m.M22 + m.M33 + m.M44;

// Caller syntax
var matrix = new Matrix4x4 { M11 = 1, M22 = 2, M33 = 3, M44 = 4 };
float result = Trace(in matrix); // explicit 'in' at call site
```

**`record struct` (C# 10): value type with record semantics**
```csharp
// All the convenience of a record (equality, ToString, Deconstruct)
// with value-type performance
public record struct Coordinate(double Lat, double Lng);

var loc1 = new Coordinate(40.7128, -74.0060);  // New York
var loc2 = loc1 with { Lng = -73.9857 };       // Slightly different

Console.WriteLine(loc1 == loc2); // False — value comparison
Console.WriteLine(loc1);         // Coordinate { Lat = 40.7128, Lng = -74.006 }

// Unlike record class, record struct is MUTABLE by default
// Use 'readonly record struct' for full immutability
public readonly record struct Money(decimal Amount, string Currency);
```

**Boxing — the silent performance killer**
```csharp
Point p = new Point(1, 2);

// Each of these boxes the struct — allocates a new heap object
object boxed       = p;           // explicit box
IComparable<Point> iface = p;     // interface box — happens at assignment

// Boxing in a non-generic collection — every element boxes
var list = new System.Collections.ArrayList();
list.Add(p); // boxes p — creates a heap wrapper

// Fix: use generic collections
var typedList = new List<Point>();
typedList.Add(p); // no boxing
```

---

## Real World Example

A high-throughput financial processing system uses a `Money` struct for currency values. Trades pass money amounts through dozens of calculation methods per second — using a struct instead of a class eliminates millions of heap allocations per minute.

```csharp
public readonly record struct Money : IComparable<Money>
{
    public decimal Amount { get; }
    public string Currency { get; }

    public Money(decimal amount, string currency)
    {
        if (amount < 0)
            throw new ArgumentOutOfRangeException(nameof(amount), "Cannot be negative.");
        if (string.IsNullOrWhiteSpace(currency))
            throw new ArgumentException("Currency code required.", nameof(currency));

        Amount   = amount;
        Currency = currency.ToUpperInvariant();
    }

    public static Money operator +(Money a, Money b)
    {
        EnsureSameCurrency(a, b);
        return new Money(a.Amount + b.Amount, a.Currency);
    }

    public static Money operator -(Money a, Money b)
    {
        EnsureSameCurrency(a, b);
        if (b.Amount > a.Amount) throw new InvalidOperationException("Result would be negative.");
        return new Money(a.Amount - b.Amount, a.Currency);
    }

    public static Money operator *(Money m, decimal multiplier)
        => new Money(m.Amount * multiplier, m.Currency);

    public int CompareTo(Money other)
    {
        EnsureSameCurrency(this, other);
        return Amount.CompareTo(other.Amount);
    }

    private static void EnsureSameCurrency(Money a, Money b)
    {
        if (a.Currency != b.Currency)
            throw new InvalidOperationException($"Currency mismatch: {a.Currency} vs {b.Currency}");
    }

    public override string ToString() => $"{Amount:F2} {Currency}";
}

// Usage: zero allocations, full operator support
var price    = new Money(9.99m,  "USD");
var tax      = new Money(0.80m,  "USD");
var total    = price + tax;            // new Money — no heap allocation
var doubled  = total * 2;             // new Money — no heap allocation
Console.WriteLine(doubled);           // 21.58 USD
```

*The key insight: `readonly record struct` gives value equality, `with` expressions, and `ToString()` for free — all the ergonomics of a record — but as a value type. Every arithmetic operation creates a new `Money` on the stack, not the heap. At 100,000 trades/second, the difference between `class Money` and `readonly record struct Money` can be millions of GC allocations eliminated per second.*

---

## Common Misconceptions

**"Structs always go on the stack"**
Only when declared as local variables. A struct *field* on a class lives on the heap with the class. A struct captured in a closure or lambda moves to the compiler-generated display class on the heap. A struct inside an array lives on the heap. The rule is: the struct goes where its container goes.

**"Structs are faster than classes because they avoid GC"**
For small, frequently-created-and-discarded types, yes. For large structs, or structs passed by value to many methods, copying cost can exceed the GC savings. A 64-byte struct copied 10 times across a call chain moves 640 bytes — more than the GC cost for a single pointer. Profile, don't assume.

**"You can use `default(MyStruct)` safely — it's like `null` for structs"**
`default(MyStruct)` zero-initialises all fields. Whether the result is a valid state depends entirely on your design. For `Money`, `default(Money)` gives `Amount = 0, Currency = null` — which the constructor would have rejected. A struct must be designed to be valid in its zero-initialised state, or callers must be prevented from using the default constructor.

---

## Gotchas

- **Mutable struct collections silently discard modifications.** `list[0].X = 99` on a `List<MutablePoint>` compiles but does nothing (the compiler sometimes catches it with CS1612, sometimes doesn't). The indexer returns a copy. You'd have to `var temp = list[0]; temp.X = 99; list[0] = temp;` — which is exactly the kind of boilerplate that makes mutable structs painful. Make structs immutable.

- **Interface dispatch on a struct boxes it.** `IMyInterface x = myStruct` allocates a heap object. Every call through the interface variable goes through the boxed copy, not the original. Use generic constraints (`where T : IMyInterface`) to get interface dispatch without boxing.

- **`in` parameters with non-readonly structs cause defensive copies.** If you pass a non-`readonly` struct as `in`, the JIT may make a copy before calling methods on it — because it can't prove those methods don't mutate it. The `in` optimisation only fully delivers with `readonly struct`.

- **The default equality implementation on structs is slow.** If you don't override `Equals` and `GetHashCode`, structs use reflection-based field comparison. This is correct but ~10-100× slower than a custom implementation. Always override both on any struct used as a dictionary key or in collections.

- **`ref struct` cannot be used in async methods or lambdas.** A `Span<T>` local variable cannot survive an `await` — the async state machine is a heap-allocated class that stores locals as fields, and `ref struct` cannot live on the heap. If you need to process a buffer across `await` points, use `Memory<T>` instead of `Span<T>`.

---

## Interview Angle

**What they're really testing:** Understanding of value semantics, memory model, and the practical trade-offs of value types — not just "structs are on the stack."

**Common question forms:**
- "What's the difference between a struct and a class in C#?"
- "When would you use a struct over a class?"
- "What happens when you modify a struct inside a collection?"
- "What is boxing and when does it happen with structs?"

**The depth signal:** A junior says "structs are on the stack and avoid GC." A senior immediately qualifies: only when they're local variables. They explain that mutable structs in collections silently discard modifications because the indexer returns a copy. They know `readonly struct` eliminates defensive copies, that interface dispatch boxes, and that the 16-byte rule of thumb is a starting point — not a law — and profile before deciding. They also know `ref struct` and why `Span<T>` can't cross `await` boundaries.

**Follow-up questions to expect:**
- "What is `readonly struct` and how does it help the JIT?"
- "Can a struct implement an interface? What's the catch?"
- "What is `ref struct` and when would you use one?"

---

## Related Topics

- [[dotnet/csharp/csharp-value-vs-reference-types.md]] — The full value/reference type memory model; structs are the primary value type
- [[dotnet/csharp/csharp-records.md]] — `record struct` combines struct performance with record ergonomics
- [[dotnet/csharp/csharp-boxing-unboxing.md]] — Boxing happens every time a struct is assigned to `object` or an interface
- [[dotnet/csharp/csharp-span-memory.md]] — `Span<T>` and `Memory<T>` are `ref struct` types; understanding structs explains their stack-only constraint
- [[dotnet/csharp/csharp-ref-out-in.md]] — `in` parameters pass structs by reference without allowing mutation

---

## Source

[Structure types — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/struct)

---

*Last updated: 2026-04-06*