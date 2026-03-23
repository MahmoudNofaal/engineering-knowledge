# C# Value Types vs Reference Types

> The fundamental split in how C# stores and passes data: value types hold their data directly, reference types hold a pointer to data on the heap.

---

## When To Use It
This distinction matters any time you assign variables, pass arguments to methods, or design a `struct` vs a `class`. It explains a whole category of bugs where "I passed an object to a method and it changed on me" or "I copied a struct and it didn't update". Use `struct` (value type) for small, immutable, short-lived data like coordinates or a money amount. Use `class` (reference type) for anything with identity, mutable state, or a non-trivial size.

---

## Core Concept
Every variable in C# is either holding the actual value (value type) or holding an address to where the value lives in memory (reference type). Value types live on the stack — when you assign one to another variable or pass it to a method, C# copies the whole thing. Changes to the copy don't affect the original. Reference types live on the heap — when you assign or pass one, you're only copying the address, so both variables point at the same object. This is why modifying a `List<T>` inside a method affects the caller's list, but modifying an `int` inside a method does nothing to the caller's `int`. Boxing is what happens when you shove a value type into a reference-type slot (like `object`) — C# wraps it in a heap allocation, which is silent, automatic, and expensive if it happens in a loop.

---

## The Code

**Assignment behaviour: value type is copied, reference type is shared**
```csharp
// Value type (struct)
int x = 10;
int y = x;   // full copy
y = 99;
Console.WriteLine(x); // 10 — x is unaffected

// Reference type (class)
var listA = new List<int> { 1, 2, 3 };
var listB = listA;   // copies the reference, not the list
listB.Add(4);
Console.WriteLine(listA.Count); // 4 — same object
```

**Passing to methods: value type vs reference type**
```csharp
void TryDoubleValue(int n) => n *= 2;
void AddToList(List<int> list) => list.Add(99);

int num = 5;
TryDoubleValue(num);
Console.WriteLine(num); // still 5 — method got a copy

var nums = new List<int> { 1, 2 };
AddToList(nums);
Console.WriteLine(nums.Count); // 3 — method mutated the original
```

**Struct vs class: the practical version**
```csharp
public struct Point          // value type
{
    public int X;
    public int Y;
}

public class Player          // reference type
{
    public string Name;
    public Point Position;   // struct embedded in class — lives on heap with the class
}

var p1 = new Point { X = 1, Y = 2 };
var p2 = p1;   // full copy
p2.X = 99;
Console.WriteLine(p1.X); // 1 — p1 unchanged

var player1 = new Player { Name = "Alice" };
var player2 = player1;   // same object
player2.Name = "Bob";
Console.WriteLine(player1.Name); // "Bob" — shared reference
```

**Boxing and unboxing**
```csharp
int val = 42;
object boxed = val;    // boxing: int copied onto heap, wrapped in object
int unboxed = (int)boxed;  // unboxing: copied back off the heap

// The danger: boxing in a hot loop
var items = new List<object>();
for (int i = 0; i < 1_000_000; i++)
    items.Add(i);   // 1 million heap allocations — use List<int> instead
```

**`ref` keyword: force pass-by-reference for a value type**
```csharp
void Double(ref int n) => n *= 2;

int count = 5;
Double(ref count);
Console.WriteLine(count); // 10 — ref gives method access to original
```

---

## Gotchas

- **Mutable structs are a trap.** If you modify a property on a struct that was returned from a method or accessed through an interface, you're modifying a copy. The original is unchanged and you get no error or warning. Make structs either immutable or tiny.
- **A struct inside a class lives on the heap, not the stack.** The "structs go on the stack" rule only applies when the struct is a local variable. A `Point` field on a class object is allocated on the heap with the rest of the object.
- **Boxing is silent and allocation-heavy.** Passing a value type to a parameter typed as `object`, `IComparable`, or any interface causes boxing. It's invisible in the source code but shows up in profilers as GC pressure. The classic case: storing `int` in a non-generic `ArrayList` boxes every element.
- **`string` is a reference type that behaves like a value type** because it's immutable. `s1 = s1 + "!"` doesn't mutate the original string — it creates a new one and rebinds `s1`. Two variables pointing to the same string can't interfere with each other the way two `List` variables can.
- **Equality semantics differ by default.** Value types use structural equality by default (`==` compares content). Reference types use reference equality by default (`==` checks if they're the same object). A class with `Name = "Alice"` and another class with `Name = "Alice"` are not `==` unless you override `Equals`.

---

## Interview Angle
**What they're really testing:** Whether you understand memory layout and can predict the side effects of assignment and method calls — not just whether you've memorised "stack vs heap."

**Common question form:** "What's the difference between a struct and a class in C#?" / "Why did modifying this parameter inside a method not change the value in the caller?" / "What is boxing and why is it a problem?"

**The depth signal:** A junior says "value types go on the stack and reference types go on the heap." A senior qualifies that immediately: a struct field on a class lives on the heap; a reference type local variable's *reference* lives on the stack but the object itself doesn't. They also talk about *when* boxing actually matters (interfaces, non-generic collections, `object` parameters in tight loops) rather than just defining it, and they know that mutable structs are actively dangerous — not just "a bit unusual."

---

## Related Topics
- [[dotnet/csharp-variables.md]] — Covers `const`, `readonly`, `var`, and the basics of variable declaration that underpin type behaviour
- [[dotnet/csharp-memory-management.md]] — GC, heap allocation, and why reference type pressure triggers collection cycles
- [[dotnet/csharp-structs.md]] — When to use `struct`, immutability patterns, and `readonly struct` in C# 7.2+
- [[algorithms/memory-management.md]] — Stack vs heap at the runtime level — the "why" behind C#'s model

---

## Source
[Value types — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/value-types)

---
*Last updated: 2026-03-23*