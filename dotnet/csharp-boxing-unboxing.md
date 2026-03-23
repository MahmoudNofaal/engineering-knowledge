# C# Boxing & Unboxing

> Boxing is when a value type gets wrapped in a heap-allocated object so it can be treated as a reference type — unboxing is unwrapping it back.

---

## When To Use It

You rarely *choose* to box — it mostly happens accidentally. It matters when you're debugging unexpected GC pressure or allocations in hot paths: loops that add structs to non-generic collections, passing value types to methods that accept `object`, or using `string.Format` / non-interpolated logging with value type arguments. Knowing when boxing occurs lets you avoid it. Don't use non-generic collections (`ArrayList`, `Hashtable`) or `object`-typed APIs in performance-sensitive code where value types are involved.

---

## Core Concept

Value types (`int`, `bool`, `DateTime`, structs) normally live on the stack or inline inside another object — no heap allocation, no GC. But the CLR has one unified type system where everything can be treated as `object`. When you assign a value type to an `object` variable (or an interface it implements), the runtime has to heap-allocate a wrapper, copy the value into it, and hand back a reference. That wrapper is the "box." Unboxing is the reverse: casting that `object` back to the value type copies the value back out of the box. Both operations are cheap individually, but they generate garbage and in a tight loop they add up fast.

---

## The Code
```csharp
// --- What boxing looks like (and when it's implicit) ---
int x = 42;
object boxed = x;               // boxing: heap allocation + copy
int unboxed = (int)boxed;       // unboxing: type check + copy back

// Implicit boxing in a non-generic collection
var list = new System.Collections.ArrayList();
list.Add(42);                   // boxes the int
int val = (int)list[0];         // unboxes it

// Fix: use the generic equivalent — no boxing at all
var typed = new List<int>();
typed.Add(42);                  // no allocation
```
```csharp
// --- Interface dispatch boxes value types ---
interface ILabel { string GetLabel(); }

struct Point : ILabel
{
    public int X, Y;
    public string GetLabel() => $"({X},{Y})";
}

// This boxes every time — Point is a struct, ILabel is a reference type
ILabel label = new Point { X = 1, Y = 2 };   // box
Console.WriteLine(label.GetLabel());

// Fix: use generics with a constraint — no boxing
static void Print<T>(T item) where T : ILabel
{
    Console.WriteLine(item.GetLabel());       // no box, direct dispatch
}
```
```csharp
// --- string.Format boxes value type arguments ---
int count = 100;
double ratio = 0.75;

// Each argument is passed as object — both box
string s1 = string.Format("Count: {0}, Ratio: {1}", count, ratio);

// String interpolation via DefaultInterpolatedStringHandler avoids boxing
// in .NET 6+ when not used through an object overload
string s2 = $"Count: {count}, Ratio: {ratio}";   // no boxing in .NET 6+

// Structured logging — same trap
_logger.LogInformation("Count: {Count}", count);  // boxes count in most ILogger impls
```
```csharp
// --- Confirming allocations with BenchmarkDotNet ---
// Add [MemoryDiagnoser] to a benchmark class to see allocation per op
[MemoryDiagnoser]
public class BoxingBench
{
    [Benchmark]
    public object WithBoxing() => (object)42;        // allocates

    [Benchmark]
    public int WithoutBoxing() => 42;                // zero allocation
}
```
```csharp
// --- Detecting boxing at IL level (quick check) ---
// In a terminal: dotnet-ildasm MyAssembly.dll | grep box
// Any 'box' opcode in a hot method is worth investigating
```

---

## Gotchas

- **Mutating a boxed struct doesn't affect the original.** After `object boxed = myStruct`, the box holds a *copy*. Calling a method that mutates fields on the box does nothing to `myStruct`. This is one of the most confusing bugs with mutable structs and `IEnumerator` implementations.
- **Unboxing to the wrong type throws `InvalidCastException`, not a compile error.** `(long)(object)42` compiles fine but throws at runtime because the box wraps an `int`, not a `long` — even though `int` is implicitly convertible to `long` in normal code. You must unbox to the exact type, then widen: `(long)(int)boxed`.
- **`Nullable<T>` has special boxing rules.** Boxing a `null` `int?` produces a null reference — not a box containing a null. And unboxing a null `object` to `int?` gives you `null` back, not an exception. But unboxing a null `object` to `int` (non-nullable) throws `NullReferenceException`. The asymmetry trips people up.
- **`foreach` on a non-generic collection boxes on every iteration.** `foreach (var item in ArrayList)` casts each element to `object` and back on every loop. In a loop over thousands of structs this is measurable. The fix is always to switch to `List<T>`.
- **Using `==` on two boxed value types compares references, not values.** `(object)42 == (object)42` is `false` — two separate heap allocations. You need `.Equals()` or unbox first. This shows up in unit tests and dictionary key comparisons.

---

## Interview Angle

**What they're really testing:** Whether you understand the value type / reference type distinction at the memory level, and whether you can reason about allocation sources that aren't `new`.

**Common question form:** "What is boxing and when does it happen?" or "Why should you use `List<T>` instead of `ArrayList`?" or "Why is this code allocating more than expected?" (followed by a snippet with a struct and a non-generic collection).

**The depth signal:** A junior knows boxing converts a value type to `object` and that generics avoid it. A senior can point to the *specific IL opcode* (`box`) that the JIT emits, explain that the allocation goes to Gen 0 and adds GC pressure proportional to call frequency, and identify the non-obvious boxing sites: interface dispatch on structs without generic constraints, `string.Format` with value type arguments, `params object[]` methods, and `lock(valueType)` (which compiles but boxes silently). They also know how to verify allocations with BenchmarkDotNet's `[MemoryDiagnoser]` rather than guessing.

---

## Related Topics

- [[dotnet/csharp-garbage-collector.md]] — boxing allocates on the managed heap; frequent boxing drives Gen 0 collections, which is where the real performance cost shows up
- [[dotnet/value-types-vs-reference-types.md]] — boxing is the boundary between the two halves of the type system; you can't understand one without the other
- [[dotnet/memory-and-span.md]] — `Span<T>` and generics are the primary tools for writing allocation-free code that works with value types
- [[dotnet/csharp-generics.md]] — generic type constraints (`where T : struct`, `where T : IFoo`) are the main way to write polymorphic code over value types without triggering boxing

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/types/boxing-and-unboxing](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/types/boxing-and-unboxing)

---
*Last updated: 2026-03-24*