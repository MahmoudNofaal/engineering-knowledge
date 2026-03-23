# C# Structs

> A struct is a value type that lives on the stack (usually), copied on assignment, and suited for small, self-contained data with no identity.

---

## When To Use It
Use a struct when you have a small, immutable-ish data container where copying is cheap and identity doesn't matter — think `Vector2`, `Point`, `Color`, `Money`. The real win is avoiding heap allocations in hot paths. Don't use a struct for anything over ~16 bytes, anything that needs inheritance, or anything you'll be boxing frequently — that erases the performance benefit entirely.

---

## Core Concept
When you assign a class, both variables point at the same object. When you assign a struct, you get a full independent copy. That's the whole thing. It means structs have no shared mutable state between variables, but it also means passing them around copies data, not a pointer. They usually live on the stack when declared as local variables, which means no GC pressure — the memory is reclaimed the moment the scope exits. The moment you box one (store it in an `object` or interface variable), it escapes to the heap and you've lost the benefit.

---

## The Code

**Basic struct and copy semantics**
```csharp
public struct Point
{
    public int X { get; }
    public int Y { get; }

    public Point(int x, int y) => (X, Y) = (x, y);

    public Point Translate(int dx, int dy) => new Point(X + dx, Y + dy);

    public override string ToString() => $"({X}, {Y})";
}

var a = new Point(1, 2);
var b = a;           // full copy — b is independent
Console.WriteLine(a); // (1, 2)
Console.WriteLine(b); // (1, 2) — same so far

// Can't mutate because X/Y have no setter — immutability enforced
```

**Mutable struct — what goes wrong**
```csharp
public struct MutablePoint
{
    public int X;
    public int Y;
}

var points = new List<MutablePoint> { new MutablePoint { X = 1, Y = 2 } };

// This does NOT modify the item in the list
// Indexer returns a copy; you're mutating the copy, then discarding it
MutablePoint p = points[0];
p.X = 99;
Console.WriteLine(points[0].X); // still 1
```

**readonly struct — performance hint to the compiler**
```csharp
// readonly struct = compiler guarantees no mutation
// Lets the JIT pass by reference internally instead of copying defensively
public readonly struct Temperature
{
    public double Celsius { get; }
    public double Fahrenheit => Celsius * 9 / 5 + 32;

    public Temperature(double celsius) => Celsius = celsius;
}
```

**Boxing — the silent heap allocation**
```csharp
Point p = new Point(3, 4);

object boxed = p;          // BOXING — allocates on heap, copies value into wrapper
Point unboxed = (Point)boxed; // UNBOXING — copies back out

// Happens silently when passing struct to interface parameter or object param
IComparable c = 42;        // int is a struct — this boxes it
```

---

## Gotchas

- **Mutable structs in collections are a trap.** `list[0].X = 5` silently modifies a copy. The list item is untouched. This compiles fine and causes bugs that are hard to trace.
- **Default constructor always exists and zeroes memory.** You can't define a parameterless constructor in older C# (<10) and you can't prevent `default(MyStruct)` — all fields will be zero/null. Design structs to be valid in their zeroed state.
- **Boxing kills your perf win.** Storing a struct in `object`, `dynamic`, or a non-generic interface boxes it onto the heap. If you're passing structs through an interface in a hot loop, you've paid allocation cost on every call.
- **Large structs are slower to copy than a class reference.** A class is always 8 bytes (pointer). A 64-byte struct copies 64 bytes on every assignment and method call. The break-even is roughly 16 bytes.
- **`readonly` on the struct vs `readonly` on a field are different things.** `readonly struct` means the whole type is immutable. A `readonly` field inside a non-readonly struct just protects that one field — the rest can still mutate.

---

## Interview Angle
**What they're really testing:** Understanding of value vs reference semantics, stack vs heap allocation, and where GC pressure comes from.

**Common question form:** "What's the difference between a struct and a class in C#?" or "When would you use a struct over a class?"

**The depth signal:** A junior says "structs are on the stack and classes are on the heap." A senior qualifies that: structs are only on the stack when they're local variables — a struct field inside a class lives on the heap with the class. They'll mention `readonly struct` as a JIT hint to avoid defensive copies, explain that boxing moves a struct to the heap and negates the allocation benefit, and know that `Span<T>` and `ref struct` exist specifically to enforce stack-only lifetimes.

---

## Related Topics
- [[dotnet/csharp-classes.md]] — The reference-type counterpart; the core comparison for value vs reference semantics.
- [[dotnet/csharp-records.md]] — `record struct` (C# 10+) gives you value equality plus immutability with less boilerplate.
- [[dotnet/memory-and-span.md]] — `Span<T>` and `ref struct` take stack-only allocation further; natural follow-on to understanding structs.
- [[dotnet/boxing-and-unboxing.md]] — The exact mechanism that makes structs expensive when used carelessly with interfaces or `object`.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/struct](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/struct)

---
*Last updated: 2026-03-23*