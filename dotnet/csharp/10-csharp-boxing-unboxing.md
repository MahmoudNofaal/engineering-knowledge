# C# Boxing & Unboxing

> Boxing is when a value type gets wrapped in a heap-allocated object so it can be treated as a reference type — unboxing is unwrapping it back. Both are automatic, silent, and expensive at scale.

---

## Quick Reference

| | |
|---|---|
| **Boxing** | Value type → object wrapper on heap |
| **Unboxing** | Object wrapper → value type (exact type match required) |
| **Cost** | Heap allocation + GC pressure per box |
| **Fix** | Generics — `List<int>` instead of `ArrayList` |
| **Silent sources** | Non-generic collections, `object` params, interface variables, `string.Format`, `params object[]` |
| **C# version** | C# 1.0 (eliminated for most use cases by generics in C# 2.0) |

---

## When To Use It

You rarely *choose* to box — it happens accidentally. Understanding it matters when:
- Diagnosing unexpected GC pressure or allocations in hot paths
- Choosing between generic and non-generic APIs
- Writing code that stores value types alongside reference types

**Recognise the sources:** Non-generic collections (`ArrayList`, `Hashtable`), `object`-typed parameters, interface variables holding value types, `string.Format` with value type arguments, `params object[]` methods, `lock` on a value type (which doesn't even work correctly).

**The fix is almost always generics.** `List<int>` stores `int` values with no boxing. `Dictionary<string, int>` stores `int` values with no boxing. `Func<int>` returns `int` with no boxing.

---

## Core Concept

Value types (`int`, `bool`, `DateTime`, structs) normally live on the stack or inline in another object — no heap allocation, no GC. The CLR has one unified type system where everything can be treated as `object`. When you assign a value type to an `object` variable (or an interface it implements), the runtime must heap-allocate a wrapper object, copy the value into it, and hand back a reference. That wrapper is the "box."

The box contains: an object header (8 bytes on 64-bit), a type handle (8 bytes), and then the value itself. An `int` takes 4 bytes on the stack but 20 bytes boxed. A `DateTime` takes 8 bytes but 24 bytes boxed.

Unboxing is the reverse: casting the `object` back to the value type copies the value out of the box. Unboxing must use the **exact type** — you cannot unbox an `int` box to `long` even though `int` implicitly converts to `long` in normal code.

Both operations are cheap individually. The problem is volume: boxing in a loop that runs millions of times creates millions of short-lived heap objects, triggering frequent Gen 0 garbage collections.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Boxing/unboxing as the mechanism for unified type system |
| C# 2.0 | .NET 2.0 | Generics — eliminated most boxing needs (`List<T>` etc.) |
| C# 7.2 | .NET Core 2.0 | `in` parameters — pass struct by ref to avoid boxing via interfaces |
| C# 8.0 | .NET Core 3.0 | Default interface methods — can still box structs if not careful |

*Generics in C# 2.0 were specifically designed to eliminate boxing for collections. Before that, every `int` in an `ArrayList` was boxed. After that, `List<int>` stores raw `int` values directly in its backing array with no wrapping.*

---

## Performance

| Scenario | Cost |
|---|---|
| Boxing one value | 1 heap allocation + copy |
| Unboxing one value | 1 type check + copy |
| Boxing in a loop (1M iterations) | ~1M heap allocations, GC pressure |
| `List<int>` vs `ArrayList` (1M elements) | Zero vs ~1M allocations |
| Interface dispatch on a struct | Boxing on assignment |
| `string.Format` with 3 ints | 3 box allocations per call |

**Allocation behaviour:** Each box creates a new heap object. The GC must track all boxes. Frequent boxing in hot loops creates short-lived Gen 0 objects that trigger more frequent collections. In latency-sensitive applications, this can cause GC pauses.

**Benchmark notes:** A single box is fast (nanoseconds). The problem is *volume*. Use `[MemoryDiagnoser]` in BenchmarkDotNet to see allocations per operation — that's how you confirm whether boxing is actually a bottleneck vs a theoretical concern.

---

## The Code

**What boxing looks like — explicit and implicit**
```csharp
int x = 42;
object boxed = x;              // boxing: heap allocation + copy
int unboxed = (int)boxed;      // unboxing: type check + copy back

// Implicit boxing in non-generic collection
var list = new System.Collections.ArrayList();
list.Add(42);                  // boxes the int — invisible in source code
int val = (int)list[0];        // unboxes it

// Fix: generic collection — no boxing at all
var typed = new List<int>();
typed.Add(42);                 // no allocation
int safe = typed[0];           // no unboxing
```

**Interface dispatch boxes value types**
```csharp
interface ILabel { string GetLabel(); }

struct Point : ILabel
{
    public int X, Y;
    public string GetLabel() => $"({X},{Y})";
}

// Assignment to interface type boxes the struct every time
ILabel label = new Point { X = 1, Y = 2 }; // box

// Fix: use generic constraint — no boxing, direct dispatch
static void Print<T>(T item) where T : ILabel
{
    Console.WriteLine(item.GetLabel());  // no box — JIT generates specialised code
}
```

**`string.Format` and logging box value type arguments**
```csharp
int count = 100;
double ratio = 0.75;

// Each value type argument is passed as object — boxes before the call
string s1 = string.Format("Count: {0}, Ratio: {1}", count, ratio); // 2 boxes

// String interpolation avoids boxing in .NET 6+ (DefaultInterpolatedStringHandler)
string s2 = $"Count: {count}, Ratio: {ratio}"; // no boxing in .NET 6+

// Structured logging DOES box in most ILogger implementations
_logger.LogInformation("Count: {Count}", count); // boxes count
// Fix: use the typed overloads or cast to avoid boxing
```

**Unboxing requires the EXACT type — not just a compatible type**
```csharp
int original = 42;
object boxed = original; // box contains an int

int unboxed1 = (int)boxed;    // OK — exact type match
// long bad  = (long)boxed;   // throws InvalidCastException at runtime!
long correct = (long)(int)boxed; // unbox to int first, then widen

// The trap: implicit conversions don't apply to unboxing
// int implicitly converts to long in normal code, but not from a box
```

**`Nullable<T>` boxing — special CLR rules**
```csharp
int? nullableNull  = null;
int? nullableValue = 42;

object boxedNull  = nullableNull;    // boxes to NULL reference — not a box of null
object boxedValue = nullableValue;   // boxes to a box containing 42 (int, not Nullable<int>)

Console.WriteLine(boxedNull  is null); // True — it IS null
Console.WriteLine(boxedValue is int);  // True — not Nullable<int>

// Unboxing back
int? back = (int?)boxedNull;    // null — special CLR handling, no throw
// int bad = (int)boxedNull;    // NullReferenceException
```

**Detecting boxing with BenchmarkDotNet**
```csharp
[MemoryDiagnoser]  // shows allocations per operation
public class BoxingBench
{
    private readonly ArrayList _arrayList = new();
    private readonly List<int> _typedList = new();

    [Benchmark(Baseline = true)]
    public void WithBoxing()
    {
        for (int i = 0; i < 1000; i++)
            _arrayList.Add(i);   // 1000 allocations
    }

    [Benchmark]
    public void WithoutBoxing()
    {
        for (int i = 0; i < 1000; i++)
            _typedList.Add(i);   // 0 allocations
    }
}
// WithBoxing:    Allocated: ~24,000 bytes (24 bytes per int box)
// WithoutBoxing: Allocated: 0 bytes
```

---

## Real World Example

A metrics aggregation service collects tagged counters. An early implementation used a dictionary with `object` values for flexibility. Profiling revealed millions of boxing allocations per second. The fix was a typed generic counter — zero allocations.

```csharp
// BEFORE: object-based — boxes every numeric value on write and read
public class MetricsRegistry
{
    private readonly Dictionary<string, object> _metrics = new();

    public void Increment(string name, long value = 1)
    {
        if (_metrics.TryGetValue(name, out object? current))
            _metrics[name] = (long)current + value;  // unbox, compute, rebox = 2 boxes per call
        else
            _metrics[name] = value;                  // 1 box per new counter
    }

    public long Get(string name)
        => _metrics.TryGetValue(name, out object? val) ? (long)val : 0L; // 1 unbox
}

// AFTER: generic — zero allocations
public class MetricsRegistry
{
    private readonly Dictionary<string, long> _metrics = new();

    public void Increment(string name, long value = 1)
    {
        _metrics[name] = _metrics.GetValueOrDefault(name) + value; // no boxing
    }

    public long Get(string name) => _metrics.GetValueOrDefault(name); // no unboxing
}

// At 100,000 counter increments/second:
// Before: ~300,000 heap allocations/second (3 per increment)
// After:  0 heap allocations from counter operations
```

*The key insight: `Dictionary<string, long>` stores `long` values directly in its backing arrays — no wrapping, no GC pressure. The original `Dictionary<string, object>` allocated a box for every `long` stored and every `long` read. At high throughput, that's hundreds of thousands of short-lived allocations per second, each triggering more frequent GC cycles.*

---

## Common Misconceptions

**"Boxing is rare and not worth worrying about"**
It's one of the most common unintentional allocations in C# code. Any non-generic collection, any `object`-typed parameter, any interface variable holding a value type, `string.Format` with value type arguments — all box. In profiler traces of real applications, unexpected boxing frequently shows up as a top allocation source. The word "rare" doesn't apply to code that runs in loops.

**"Unboxing to a compatible type works the same as implicit conversion"**
Unboxing requires the exact type. A box containing an `int` cannot be unboxed to `long` — even though `int` implicitly converts to `long` in regular assignment. You must unbox to `int` first, then widen: `(long)(int)boxed`. This runtime difference from compile-time type rules surprises developers.

**"Mutating a boxed struct affects the original variable"**
After `object boxed = myStruct`, the box holds a *copy*. Calling a method on the box that mutates fields does nothing to `myStruct`. The original and the box are completely independent. This is why mutable structs stored through interface variables behave so confusingly.

---

## Gotchas

- **`lock` on a value type creates a new box each time.** `lock(42)` boxes the `int` to get a reference, but the box is a new object every time — so multiple threads lock on different objects and you get no mutual exclusion. The compiler warns in C# 9+, but older code can have this silent bug.

- **`IEnumerator<T>` on a struct enumerator boxes when accessed through the interface.** `foreach` over `List<T>` uses `List<T>.Enumerator` (struct) through `IEnumerator<T>` (interface), which could box — but the compiler generates specialised code that avoids this for the `foreach` pattern. Manual iteration through the interface does box.

- **`string.Format` and most pre-.NET 6 interpolation box value types.** `$"Value: {myInt}"` boxed the `int` before .NET 6. Since .NET 6, string interpolation uses `DefaultInterpolatedStringHandler` which avoids boxing for common value types. But `string.Format`, `Console.Write`, and most `ILogger` overloads still box.

- **Boxing in tight loops is invisible in source code.** There's no visual indication that `list.Add(42)` on an `ArrayList` allocates. You need a profiler (BenchmarkDotNet's `[MemoryDiagnoser]`, dotMemory, or the .NET diagnostic tools) to see the allocations.

- **Unboxing via `as` doesn't work for non-nullable value types.** `42 as int?` works, returning a `Nullable<int>`. But `42 as int` doesn't compile — `as` requires a nullable or reference type on the right side. Use a direct cast `(int)` for value type unboxing.

---

## Interview Angle

**What they're really testing:** Whether you understand the value type / reference type distinction at the memory level and can reason about allocation sources that aren't `new`.

**Common question forms:**
- "What is boxing and when does it happen?"
- "Why should you use `List<T>` instead of `ArrayList`?"
- "Why is this code allocating more than expected?" (followed by a snippet with a struct and a non-generic collection)
- "What is the problem with `string.Format` and value types?"

**The depth signal:** A junior knows boxing converts a value type to `object` and that generics avoid it. A senior can enumerate the *specific* non-obvious boxing sites: interface dispatch on structs (without generic constraints), `string.Format` with value type arguments, `params object[]` methods, `lock` on a value type. They know that unboxing requires the exact type (not just a compatible one), that mutating a boxed struct doesn't affect the original, and that the correct way to verify boxing in production is `[MemoryDiagnoser]` in BenchmarkDotNet rather than guessing.

**Follow-up questions to expect:**
- "What is the difference in memory layout between `int` and a boxed `int`?"
- "How do generic constraints eliminate boxing when calling interface methods?"
- "What's the special boxing behaviour of `Nullable<T>`?"

---

## Related Topics

- [[dotnet/csharp/csharp-garbage-collector.md]] — Boxing allocates on the managed heap; frequent boxing drives Gen 0 collections
- [[dotnet/csharp/csharp-value-vs-reference-types.md]] — Boxing is the boundary between the two halves of the type system
- [[dotnet/csharp/csharp-generics.md]] — Generic type constraints (`where T : struct`, `where T : IFoo`) are the main way to write polymorphic code over value types without boxing
- [[dotnet/csharp/csharp-span-memory.md]] — `Span<T>` and generics are the primary tools for writing allocation-free code with value types

---

## Source

[Boxing and Unboxing — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/types/boxing-and-unboxing)

---

*Last updated: 2026-04-06*