# C# Tuples

> A tuple is a lightweight, unnamed (or named) grouping of two or more values that can be returned, passed, or deconstructed without defining a class or struct.

---

## When To Use It

Use tuples for small, local groupings where defining a named type would be ceremonial overhead — returning two values from a private method, swapping variables, destructuring a `Dictionary` entry in a `foreach`, or holding intermediate results inside a single method. Do not use them across public API boundaries or anywhere the meaning of each position isn't immediately obvious from context — a named record or class communicates intent far better than `(string, int, bool)`. Do not use them as a substitute for domain types; if you find yourself passing the same tuple shape around more than two call sites, define a proper type.

---

## Core Concept

C# has two tuple mechanisms. The old `System.Tuple<T1, T2>` is a reference type from .NET 4 — heap-allocated, immutable, accessed via `.Item1`/`.Item2`. Avoid it in new code. The modern `(T1, T2)` syntax introduced in C# 7 compiles to `System.ValueTuple<T1, T2>`, which is a value type — stack-allocated when possible, no heap overhead, and supports element naming purely as a compile-time alias. The names are erased at runtime: `(int X, int Y)` and `(int A, int B)` are the same type to the CLR. Tuples support deconstruction natively, which lets you unpack them directly into separate variables. They also integrate with pattern matching and `foreach` over key-value pairs.

---

## The Code
```csharp
// --- Basic value tuple ---
(string Name, int Age) person = ("Alice", 30);
Console.WriteLine(person.Name); // Alice
Console.WriteLine(person.Age);  // 30

// --- Inferred names (C# 7.1) ---
string name = "Bob";
int age = 25;
var inferred = (name, age);     // element names inferred from variable names
Console.WriteLine(inferred.name); // Bob

// --- Return multiple values from a method ---
static (double Min, double Max, double Average) Stats(IEnumerable<double> data)
{
    double[] arr = data.ToArray();
    return (arr.Min(), arr.Max(), arr.Average());
}

var (min, max, avg) = Stats(new[] { 1.0, 5.0, 3.0, 2.0, 4.0 });
Console.WriteLine($"min={min} max={max} avg={avg}");

// --- Deconstruction ---
(int x, int y) = (10, 20);
Console.WriteLine(x); // 10

// Swap without temp variable
(x, y) = (y, x);
Console.WriteLine($"x={x} y={y}"); // x=20 y=10

// Discard elements you don't need
(string first, _, string last) = ("John", "Middle", "Doe");
Console.WriteLine($"{first} {last}");

// --- foreach over Dictionary: deconstruct KeyValuePair ---
var scores = new Dictionary<string, int> { ["Alice"] = 95, ["Bob"] = 87 };
foreach ((string player, int score) in scores)
    Console.WriteLine($"{player}: {score}");

// --- Tuple equality (C# 7.3+): element-wise comparison ---
var a = (1, "hello");
var b = (1, "hello");
Console.WriteLine(a == b); // True — compares each element

// --- Pattern matching with tuples ---
static string Direction(int dx, int dy) => (dx, dy) switch
{
    (0, 0)       => "stationary",
    (0, var y)   => y > 0 ? "north" : "south",
    (var x, 0)   => x > 0 ? "east" : "west",
    _            => "diagonal"
};

// --- Tuple as dictionary key (ValueTuple is equatable) ---
var grid = new Dictionary<(int Row, int Col), string>();
grid[(0, 0)] = "origin";
grid[(1, 2)] = "cell";
Console.WriteLine(grid[(0, 0)]); // origin

// --- Deconstruct a custom type (add Deconstruct method) ---
public class Rectangle
{
    public double Width  { get; init; }
    public double Height { get; init; }

    public void Deconstruct(out double width, out double height)
        => (width, height) = (Width, Height);
}

var rect = new Rectangle { Width = 4.0, Height = 3.0 };
var (w, h) = rect;  // calls Deconstruct
Console.WriteLine(w * h); // 12
```

---

## Gotchas

- **Element names are compile-time only — they vanish at runtime.** `(int X, int Y)` and `(int Row, int Col)` are the same CLR type: `ValueTuple<int, int>`. Reflection, serialization, and dynamic code see `.Item1`/`.Item2`, not your names. If you serialize a tuple to JSON you get `{"Item1":1,"Item2":2}`, not `{"X":1,"Y":2}`. Use a record or class if names need to survive beyond the compiler.
- **Tuples in public APIs make refactoring painful.** Renaming an element does nothing visible to callers — they already use positional deconstruction or `Item1`. Adding a third element is a breaking change for every caller that deconstructs into exactly two variables. Public-facing return types should almost always be named types.
- **`ValueTuple` is mutable.** Unlike the old `System.Tuple<>`, you can write `point.X = 5`. This matters when a tuple is stored in a `readonly` field: the field is readonly but its elements are not — mutation is still possible, which surprises people coming from other languages where tuples are immutable by convention.
- **Large tuples as struct values are copied on assignment.** A `(double, double, double, double, double, double, double, double)` is 64 bytes. Passing it to a method, storing it in a list, or returning it from a lambda all copy the whole struct. For large groupings, the heap allocation of a record or class is a better trade than copying tens of bytes on every use.
- **`System.Tuple` (old) and `System.ValueTuple` (new) are not interchangeable.** Old code returning `Tuple<string, int>` cannot be deconstructed with `var (a, b) = ...` syntax. You have to access `.Item1`/`.Item2` manually. Mixing both in a codebase creates confusion; migrate old `Tuple<>` usage to `(T1, T2)` when you touch that code.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between `System.Tuple` and `ValueTuple`, and when a tuple is appropriate versus a named type.

**Common question form:** "How do you return multiple values from a method in C#?" or "What's the difference between `Tuple<T1,T2>` and `(T1, T2)`?"

**The depth signal:** A junior says "`ValueTuple` is newer and supports naming." A senior explains that `ValueTuple` is a struct — value-type semantics, no heap allocation, element names are compiler aliases only and disappear at runtime; that this makes tuples unsuitable for serialization or reflection by name; that mutability is a meaningful difference from `System.Tuple`; and draws the line clearly: private/internal return values and local groupings are where tuples shine, while anything crossing a public API boundary or shared more than two call sites earns a named record — both for readability and because tuple shapes are invisible to callers in documentation, IDE tooltips, and breaking-change analysis.

---

## Related Topics

- [[dotnet/csharp-records.md]] — Records are the named, immutable alternative to tuples for structured data that crosses method or API boundaries; understanding both shows when each is appropriate.
- [[dotnet/csharp-pattern-matching.md]] — Tuple switch expressions with positional patterns are one of the most concise uses of both features together.
- [[dotnet/csharp-deconstruction.md]] — Deconstruction syntax works with tuples, records, and any type with a `Deconstruct` method; the three are part of the same language feature family.
- [[dotnet/csharp-value-types-vs-reference-types.md]] — `ValueTuple` is a struct; understanding stack allocation, copy-on-assignment, and mutability semantics makes the gotchas predictable.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/value-tuples](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/value-tuples)

---
*Last updated: 2026-03-23*