# C# Value Types vs Reference Types

> The fundamental split in how C# stores and passes data — value types hold their data directly in the variable, reference types hold a pointer to data on the heap.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Two memory models for all C# types |
| **Use when** | Always — every type falls into one category |
| **Avoid when** | N/A — but understand which you're working with |
| **C# version** | C# 1.0 (ref structs: C# 7.2) |
| **Namespace** | N/A — language fundamental |
| **Value types** | `int`, `bool`, `double`, `decimal`, `struct`, `enum` |
| **Reference types** | `class`, `string`, `interface`, `delegate`, arrays |

---

## When To Use It

This distinction matters any time you assign variables, pass arguments to methods, or design a type. It explains the entire category of bugs where "I passed an object to a method and it changed on me" or "I copied a struct and it didn't update."

Choose `struct` (value type) for small, immutable, short-lived data — coordinates, money amounts, RGB colours, date ranges. The guideline is roughly 16 bytes or less, no inheritance needed, and the type represents a single value rather than an entity with identity.

Choose `class` (reference type) for anything with identity, mutable state, a non-trivial lifetime, or a size beyond a few fields. When in doubt, use a class — the performance difference only matters in hot paths.

---

## Core Concept

Every variable in C# is either holding the actual value (value type) or holding an address to where the value lives in memory (reference type).

**Value types** live on the stack when declared as local variables. When you assign one to another variable or pass it to a method, C# copies the entire data. Changes to the copy don't affect the original. The moment the variable goes out of scope, its memory is reclaimed — no GC involved.

**Reference types** live on the heap. The variable on the stack holds only a pointer (8 bytes on 64-bit). When you assign or pass one, you copy the pointer — both variables now point at the same object. Modifying the object through either variable affects both. The GC tracks heap objects and reclaims them when no pointers remain.

**Boxing** is what happens when a value type must be treated as a reference type — the runtime wraps it in a heap-allocated object. It's silent, automatic, and expensive if it happens in a hot loop. The opposite is unboxing.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Value/reference split established |
| C# 2.0 | .NET 2.0 | Generics eliminated most boxing needs |
| C# 7.2 | .NET Core 2.0 | `ref struct` — stack-only struct enforcement |
| C# 7.2 | .NET Core 2.0 | `readonly struct` — defensive-copy elimination |
| C# 8.0 | .NET Core 3.0 | `unmanaged` constraint for generic value types |
| C# 10.0 | .NET 6 | `record struct` — value type with record semantics |

*Before generics (C# 2.0), every collection stored `object`, causing boxing of every value type inserted. `List<int>` is the fix — no boxing occurs.*

---

## Performance

| Operation | Value type | Reference type |
|---|---|---|
| Assignment | Copies all bytes | Copies 8-byte pointer |
| Method pass | Copies all bytes | Copies 8-byte pointer |
| GC involvement | None (stack) | Yes (heap) |
| Boxing | Yes — when cast to `object`/interface | N/A — already a ref |
| Null | Not possible (unless `T?`) | Always possible |

**Allocation behaviour:** A local `int` costs zero heap allocations. A local `new MyClass()` costs one heap allocation. A struct field inside a class lives on the heap with the class — the "structs go on the stack" rule only applies when the struct is a direct local variable, not when it's a field.

**Benchmark notes:** Value types win when structs are small (≤ 16 bytes) and frequently created/discarded in tight loops — you eliminate GC pressure. They lose when large (copying 64 bytes is slower than copying one 8-byte pointer), when they're boxed (negates all benefit), or when they're stored in non-generic collections.

---

## The Code

**Assignment behaviour: value type is copied, reference type is shared**
```csharp
// Value type — full copy on assignment
int x = 10;
int y = x;
y = 99;
Console.WriteLine(x); // 10 — x is untouched

// Reference type — pointer copy on assignment
var listA = new List<int> { 1, 2, 3 };
var listB = listA;   // both point at the same List object
listB.Add(4);
Console.WriteLine(listA.Count); // 4 — same object was mutated

// String: reference type, but immutable — behaves like value type
string s1 = "hello";
string s2 = s1;
s2 = "world";        // creates a new string, rebinds s2 only
Console.WriteLine(s1); // "hello" — unaffected
```

**Passing to methods: value type gets a copy, reference type shares the object**
```csharp
void TryDoubleValue(int n)
{
    n *= 2; // modifies the local copy only
}

void AddToList(List<int> list)
{
    list.Add(99); // modifies the original object
}

int num = 5;
TryDoubleValue(num);
Console.WriteLine(num); // still 5 — method got a copy

var nums = new List<int> { 1, 2 };
AddToList(nums);
Console.WriteLine(nums.Count); // 3 — original was mutated
```

**Boxing and unboxing — the hidden cost**
```csharp
int val = 42;
object boxed = val;        // boxing: value copied to heap, wrapped in object header
int unboxed = (int)boxed;  // unboxing: value copied back from heap

// The danger: boxing in a loop
var items = new List<object>();
for (int i = 0; i < 1_000_000; i++)
    items.Add(i);           // 1 million heap allocations — use List<int> instead

// Interface dispatch also boxes value types
IComparable boxedByInterface = 42; // int is IComparable — this boxes
```

**Struct inside a class — lives on the heap with the class**
```csharp
public struct Point { public int X; public int Y; }

public class Player
{
    public string Name;
    public Point Position; // struct embedded in class — on the heap with Player
}

// Point is only on the stack when declared as a local variable:
Point localPoint = new Point { X = 1, Y = 2 }; // stack
Player player = new Player();                   // player.Position is on the heap
```

**Using `ref` to pass value types by reference**
```csharp
// Without ref: method gets a copy — original unchanged
void Double(int n) => n *= 2;

// With ref: method gets a pointer to the original
void DoubleRef(ref int n) => n *= 2;

int count = 5;
DoubleRef(ref count);
Console.WriteLine(count); // 10
```

---

## Real World Example

In a 2D game engine, the coordinate system uses `struct` for positions and velocities (created/discarded thousands of times per frame), while game entities use `class` (they have identity and persistent state). Choosing wrong causes either GC pressure or unexpected mutation bugs.

```csharp
// GOOD: small, immutable struct — zero GC pressure per frame
public readonly struct Vector2
{
    public float X { get; }
    public float Y { get; }

    public Vector2(float x, float y) => (X, Y) = (x, y);

    public static Vector2 operator +(Vector2 a, Vector2 b)
        => new Vector2(a.X + b.X, a.Y + b.Y);

    public float Length => MathF.Sqrt(X * X + Y * Y);
}

// GOOD: class — entity has identity, mutable state, tracked over time
public class Enemy
{
    public int Id { get; }
    public Vector2 Position { get; private set; }
    public float Health { get; private set; }

    public Enemy(int id, Vector2 startPosition, float health)
    {
        Id = id;
        Position = startPosition;
        Health = health;
    }

    public void Move(Vector2 delta)
    {
        // Vector2 + creates a new struct — no allocation, just stack math
        Position = Position + delta;
    }

    public void TakeDamage(float amount)
    {
        Health = Math.Max(0, Health - amount);
    }
}

// Per-frame update — thousands of Vector2 operations, zero heap allocations
void UpdateEnemies(IEnumerable<Enemy> enemies, float deltaTime)
{
    var velocity = new Vector2(1.0f, 0.5f) * deltaTime; // stack, no GC
    foreach (var enemy in enemies)
        enemy.Move(velocity); // passes struct by copy — correct and efficient
}
```

*The key insight: `Vector2` as a `struct` means the physics math runs entirely on the stack — thousands of additions and subtractions per frame with zero GC impact. If `Vector2` were a class, every arithmetic operation would allocate.*

---

## Common Misconceptions

**"Structs always go on the stack"**
Only when declared as local variables. A `struct` field on a class lives on the heap with the class. A `struct` captured in a lambda moves to the heap. A `struct` in an array lives on the heap. The stack is the exception, not the rule.

**"Reference types are always slower because of the heap"**
It depends entirely on usage. Copying a large struct (say, 64 bytes) on every method call is slower than copying an 8-byte pointer. The GC overhead of heap allocation only matters when allocations are frequent — a single `new Customer()` is negligible. The real cost model is: heap allocations in tight loops (GC pressure) vs large struct copies (CPU cost).

**"Boxing is rare and not worth worrying about"**
It's one of the most common unintentional allocations in C# code. Any non-generic collection (`ArrayList`, `Hashtable`), any `object`-typed parameter, any interface variable holding a value type, any `string.Format` with a value type argument — all box. In profiler traces, unexpected boxing frequently shows up as a top allocation source.

```csharp
// Invisible boxing — happens on every call to Log
logger.Log(LogLevel.Info, "User {0} logged in at {1}", userId, DateTime.Now);
//                                                      ^^^^^    ^^^^^^^^^^^
//                          int boxes here         DateTime boxes here
// Fix: use structured logging with proper generic overloads
logger.LogInformation("User {UserId} logged in at {Time}", userId, DateTime.Now);
```

---

## Gotchas

- **Mutable structs are a trap.** If you modify a property on a struct returned from a method or accessed through an interface, you're modifying a copy. The original is unchanged and you get no error or warning. Either make structs immutable (`readonly struct`) or keep them tiny and obvious.

- **A struct inside a class lives on the heap.** The "structs go on the stack" rule only applies when the struct is a local variable. A `Point` field on a class object is on the heap. Don't design around this assumption.

- **Boxing is silent and allocation-heavy.** Passing a value type to a parameter typed as `object`, `IComparable`, or any interface causes boxing. It's invisible in source code but shows up in profilers as GC pressure. The fix is always generics: `where T : IComparable<T>` instead of accepting `IComparable`.

- **`string` equality works differently from other reference types.** `==` on `string` compares content (the operator is overloaded), but `==` on other reference types compares identity. Two `string` variables with value `"hello"` are `==`. Two `new List<int>()` with the same content are not `==` without overriding `Equals`.

- **Default value differs between categories.** `default(int)` is `0`. `default(bool)` is `false`. `default(MyClass)` is `null`. This matters in generic code where `default(T)` behaves differently depending on whether `T` is a value or reference type.

---

## Interview Angle

**What they're really testing:** Whether you understand memory layout well enough to predict the side effects of assignment and method calls — not just whether you've memorised the "stack vs heap" answer.

**Common question forms:**
- "What's the difference between a struct and a class in C#?"
- "Why did modifying this parameter inside a method not change the value in the caller?"
- "What is boxing and why is it a problem?"
- "Where does a struct field on a class live?"

**The depth signal:** A junior says "value types go on the stack and reference types go on the heap." A senior immediately qualifies: a struct field on a class lives on the heap with the class; a reference type local variable's *pointer* is on the stack but the object itself is on the heap. They talk about *when* boxing actually matters (interfaces, non-generic collections, `string.Format` in tight loops) rather than just defining it. They know that mutable structs are actively dangerous, not just "a bit unusual." They can explain why `string` behaves like a value type even though it's a reference type.

**Follow-up questions to expect:**
- "What is a `ref struct` and when would you use one?"
- "How do generics eliminate boxing?"
- "Why can't you use `Span<T>` in an `async` method?"

---

## Related Topics

- [[dotnet/csharp/csharp-variables.md]] — `const`, `readonly`, and the basics of variable declaration that underpin type behaviour
- [[dotnet/csharp/csharp-boxing-unboxing.md]] — The full boxing lifecycle, how to detect it with IL inspection, and all the non-obvious places it happens
- [[dotnet/csharp/csharp-structs.md]] — When to use `struct`, `readonly struct`, immutability patterns, and `ref struct`
- [[dotnet/csharp/csharp-garbage-collector.md]] — GC, heap allocation, and why reference type pressure triggers collection cycles
- [[dotnet/csharp/csharp-span-memory.md]] — `Span<T>` enforces stack-only lifetime via `ref struct` — the ultimate value type for memory slicing

---

## Source

[Value types — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/value-types)

---

*Last updated: 2026-04-06*