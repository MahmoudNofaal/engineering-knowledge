# C# Tuples

> A lightweight grouping of two or more values that can be returned, passed, or deconstructed without defining a named type — using `ValueTuple` under the hood.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Anonymous multi-value container — struct, not a class |
| **Use when** | Small local groupings, returning 2–3 values from a private method |
| **Avoid when** | Crossing public API boundaries, reused across >2 call sites |
| **C# version** | Modern `(T1, T2)` syntax: C# 7.0 (Old `Tuple<T1,T2>`: C# 4.0) |
| **Namespace** | `System.ValueTuple` (implicit) |
| **Key feature** | Element names are compile-time aliases — erased at runtime |

---

## When To Use It

Use tuples for small, local groupings where defining a named type would be ceremony overhead — returning two values from a private method, swapping variables, destructuring a `Dictionary` entry in a `foreach`, holding intermediate results inside a single method.

**Don't use tuples:**
- Across public API boundaries — callers see `Item1`/`Item2` in docs, IntelliSense shows no names, breaking changes are invisible.
- When the same shape appears at more than two call sites — define a `record`.
- For complex data — once you need behaviour or validation, it's a record or class.

The decision rule: if you'd name a local variable `result` and it holds two related values for 3 lines, use a tuple. If you'd name it `orderSummary` and it flows through your codebase, define a type.

---

## Core Concept

C# has two tuple mechanisms. The old `System.Tuple<T1,T2>` (C# 4.0) is a reference type — heap-allocated, immutable, accessed via `.Item1`/`.Item2`. Avoid it in new code.

The modern `(T1, T2)` syntax (C# 7.0) compiles to `System.ValueTuple<T1, T2>`, which is a **value type** — stack-allocated when possible, no heap overhead. Element names like `(int X, int Y)` are purely compile-time aliases — they're stored in assembly metadata for tooling but don't exist at runtime. `(int X, int Y)` and `(int Row, int Col)` are the same CLR type.

`ValueTuple` is mutable by default — you can assign to `point.X = 5`. This surprises developers who expect tuples to be immutable.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 4.0 | .NET 4.0 | `Tuple<T1,T2>` reference type introduced |
| C# 7.0 | .NET Core 1.0 | `(T1, T2)` syntax — `ValueTuple`, named elements |
| C# 7.1 | .NET Core 1.1 | Inferred tuple element names from variable names |
| C# 7.3 | .NET Core 2.1 | Tuple equality — `(1, "a") == (1, "a")` |

*Before C# 7.0's `ValueTuple`, returning multiple values required either an `out` parameter (awkward), a custom type (verbose), or `Tuple<T1,T2>` (heap-allocated, unnamed). The named `ValueTuple` syntax solved all three problems.*

---

## Performance

| Operation | `ValueTuple` | `Tuple<T1,T2>` (old) |
|---|---|---|
| Allocation | Stack (free) | Heap allocation |
| Assignment | Copies all bytes | Copies 8-byte pointer |
| Element access | Direct field access | Property access |
| Equality | Element-wise comparison | Reference equality by default |
| Mutable | Yes | No — fields are readonly |

**Allocation behaviour:** `ValueTuple` is a struct — no heap allocation for local variables. A `(string, int)` tuple containing a reference type copies the pointer, but the tuple itself doesn't allocate. Large tuples (8+ elements) use nested `ValueTuple` structs — still no allocation, but many bytes copied on assignment.

**Benchmark notes:** `ValueTuple` performance is identical to a plain struct of the same fields. The naming is compile-time only — no performance difference between `(int X, int Y)` and `(int, int)`.

---

## The Code

**Basic value tuple — declaration and access**
```csharp
// Named elements: names are compile-time aliases
(string Name, int Age) person = ("Alice", 30);
Console.WriteLine(person.Name); // Alice
Console.WriteLine(person.Age);  // 30

// Inferred names from variable names (C# 7.1)
string name = "Bob";
int age = 25;
var inferred = (name, age);      // element names inferred
Console.WriteLine(inferred.name); // Bob

// Anonymous (positional access)
(string, int) anon = ("Charlie", 35);
Console.WriteLine(anon.Item1); // Charlie
Console.WriteLine(anon.Item2); // 35
```

**Return multiple values from a method**
```csharp
// Private/internal method — tuple is appropriate here
static (double Min, double Max, double Average) Stats(IEnumerable<double> data)
{
    var arr = data.ToArray();
    return (arr.Min(), arr.Max(), arr.Average());
}

// Deconstruct directly into variables
var (min, max, avg) = Stats(new[] { 1.0, 5.0, 3.0, 2.0, 4.0 });
Console.WriteLine($"min={min} max={max} avg={avg}");

// Or access by name
var stats = Stats(new[] { 1.0, 5.0 });
Console.WriteLine(stats.Min);
```

**Deconstruction — swap, discard, patterns**
```csharp
(int x, int y) = (10, 20);

// Swap without temp variable
(x, y) = (y, x);
Console.WriteLine($"x={x} y={y}"); // x=20 y=10

// Discard elements you don't need
(string first, _, string last) = ("John", "Middle", "Doe");

// foreach over Dictionary — deconstruct KeyValuePair
var scores = new Dictionary<string, int> { ["Alice"] = 95, ["Bob"] = 87 };
foreach ((string player, int score) in scores)
    Console.WriteLine($"{player}: {score}");
```

**Tuple equality (C# 7.3)**
```csharp
var a = (1, "hello");
var b = (1, "hello");
Console.WriteLine(a == b); // True — element-wise comparison

// Note: names don't affect equality
(int X, int Y) p1 = (1, 2);
(int Row, int Col) p2 = (1, 2);
Console.WriteLine(p1 == p2); // True — same underlying ValueTuple<int,int>
```

**Tuple as dictionary key — ValueTuple is equatable**
```csharp
var grid = new Dictionary<(int Row, int Col), string>();
grid[(0, 0)] = "origin";
grid[(1, 2)] = "cell";

Console.WriteLine(grid[(0, 0)]); // "origin"
Console.WriteLine(grid.ContainsKey((1, 2))); // True
```

**Pattern matching with tuples**
```csharp
static string Direction(int dx, int dy) => (dx, dy) switch
{
    (0, 0)       => "stationary",
    (0, > 0)     => "north",
    (0, < 0)     => "south",
    (> 0, 0)     => "east",
    (< 0, 0)     => "west",
    _            => "diagonal"
};

// State machine using tuple of two values
static string GetTransition(OrderStatus from, OrderEvent evt) => (from, evt) switch
{
    (OrderStatus.Pending,    OrderEvent.Payment)    => "Processing",
    (OrderStatus.Processing, OrderEvent.Shipment)   => "Shipped",
    (OrderStatus.Shipped,    OrderEvent.Delivery)   => "Delivered",
    (OrderStatus.Pending,    OrderEvent.Cancellation) => "Cancelled",
    _ => throw new InvalidOperationException($"Invalid transition: {from} + {evt}")
};
```

**Custom `Deconstruct` — make any type work with tuple syntax**
```csharp
public class Rectangle
{
    public double Width  { get; init; }
    public double Height { get; init; }

    // Adding Deconstruct enables tuple-style destructuring
    public void Deconstruct(out double width, out double height)
        => (width, height) = (Width, Height);
}

var rect = new Rectangle { Width = 4.0, Height = 3.0 };
var (w, h) = rect;   // calls Deconstruct
Console.WriteLine(w * h); // 12
```

---

## Real World Example

A parser that reads CSV rows returns multiple parsed values per row. Using a tuple avoids defining a `ParsedRow` type that's only used inside the parser, while named elements keep the code readable.

```csharp
public class CsvOrderParser
{
    public IEnumerable<Order> Parse(IEnumerable<string> lines)
    {
        return lines
            .Skip(1) // skip header
            .Select(ParseLine)
            .Where(result => result.IsValid)
            .Select(result => new Order(result.Id, result.CustomerName, result.Total));
    }

    // Private method — tuple return is appropriate here (never crosses API boundary)
    private (bool IsValid, int Id, string CustomerName, decimal Total, string? Error)
        ParseLine(string line)
    {
        var parts = line.Split(',');

        if (parts.Length != 3)
            return (false, 0, "", 0, $"Expected 3 columns, got {parts.Length}");

        if (!int.TryParse(parts[0].Trim(), out int id))
            return (false, 0, "", 0, $"Invalid id: '{parts[0]}'");

        string customerName = parts[1].Trim();
        if (string.IsNullOrWhiteSpace(customerName))
            return (false, 0, "", 0, "Customer name is empty");

        if (!decimal.TryParse(parts[2].Trim(), out decimal total))
            return (false, 0, "", 0, $"Invalid total: '{parts[2]}'");

        return (true, id, customerName, total, null);
    }
}
```

*The key insight: `ParseLine` returns five values as a named tuple. Because it's a `private` method whose output is consumed immediately in the calling `Select`, defining a `ParsedLine` record would be pure ceremony. The named elements (`IsValid`, `Id`, `CustomerName`, `Total`, `Error`) make the calling code readable without adding a type to the public surface. This is exactly the use case tuples are designed for.*

---

## Common Misconceptions

**"Element names survive at runtime — I can use them in reflection"**
Element names are compile-time aliases stored in the assembly's attribute metadata for tooling. At runtime, `(int X, int Y)` and `(int A, int B)` are the same CLR type: `ValueTuple<int, int>`. Serializing a tuple to JSON gives `{"Item1":1,"Item2":2}`, not `{"X":1,"Y":2}`. Use a record or class if names need to survive to runtime.

**"`ValueTuple` and `Tuple<T>` are interchangeable"**
`Tuple<T1, T2>` (old) is a reference type — heap-allocated, immutable, accessed via `.Item1`. `ValueTuple<T1, T2>` (new syntax) is a struct — stack-allocated, mutable, supports element names. Old `Tuple` code can't be destructured with `var (a, b) = ...` syntax without a helper. Migrate old `Tuple<>` to `(T1, T2)` when you touch that code.

**"Tuples in public APIs are fine because callers can use positional access"**
Callers can access them via `Item1`/`Item2`, yes. But the API contract is opaque — IntelliSense shows no names, documentation generators show `ValueTuple`, and any change to the tuple shape (reordering, adding an element) is a silent breaking change. Public APIs deserve named types.

---

## Gotchas

- **`ValueTuple` is mutable — fields are not readonly.** `point.X = 99` works. Developers from functional backgrounds expect tuples to be immutable. If immutability matters, use a `readonly record struct`.

- **Large tuples copy many bytes on assignment.** A `(double, double, double, double, double, double, double, double)` is 64 bytes. Passing it to a method copies 64 bytes per call. For large groupings, the heap allocation of a `record` is a better trade than copying tens of bytes everywhere.

- **Tuple element names don't affect equality.** `(int X, int Y) == (int Row, int Col)` is `true` if the values match — the names are irrelevant. This means two tuples with different semantic meanings but the same types and values are equal, which can cause bugs if you're using tuples as dictionary keys.

- **No `out` parameters in async methods — use tuples instead.** `async` methods can't have `out` parameters. The idiomatic replacement is returning a named tuple: `async Task<(bool Success, Order? Value)> TryGetOrderAsync(...)`.

- **Chaining deconstruction into existing variables requires parentheses.** `var (a, b) = tuple;` declares new variables. `(a, b) = tuple;` assigns to existing ones. Forgetting the difference produces either a "variable already declared" or "use of unassigned variable" error.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between `ValueTuple` and the old `Tuple<T>`, and when a tuple is appropriate vs a named type.

**Common question forms:**
- "How do you return multiple values from a method in C#?"
- "What's the difference between `Tuple<T1,T2>` and `(T1, T2)`?"
- "When would you use a tuple vs a record?"

**The depth signal:** A junior says "`ValueTuple` is newer and supports naming." A senior explains that `ValueTuple` is a struct — value-type semantics, no heap allocation, element names are compiler aliases only and disappear at runtime. They know tuples are mutable (unlike `System.Tuple`), unsuitable for serialisation by name, and that the right boundary for using tuples is "private/internal return values and local groupings." Anything crossing a public API boundary or shared across more than two call sites earns a named `record` — for readability, for documentation, and because tuple shapes are invisible to callers in IDE tooltips and breaking-change analysis.

**Follow-up questions to expect:**
- "How do you make a class deconstructible like a tuple?"
- "Can you use a tuple as a dictionary key? What are the caveats?"
- "Why can't you use element names in JSON serialisation?"

---

## Related Topics

- [[dotnet/csharp/csharp-records.md]] — Records are the named, immutable alternative when the grouping crosses a method boundary or API surface
- [[dotnet/csharp/csharp-pattern-matching.md]] — Tuple switch expressions with positional patterns are one of the most concise uses of both features
- [[dotnet/csharp/csharp-value-vs-reference-types.md]] — `ValueTuple` is a struct; understanding copy semantics makes the gotchas predictable

---

## Source

[Value tuples — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/value-tuples)

---

*Last updated: 2026-04-06*