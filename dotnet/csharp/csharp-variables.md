# C# Variables

> A named storage location in memory that holds a value of a specific type, declared at compile time or inferred by the compiler.

---

## When To Use It
Variables are the foundation of any C# program — you're always using them. The real decisions are *which kind*: `var` vs explicit type, `const` vs `readonly`, value type vs reference type. Use `const` for values that are truly fixed at compile time (magic numbers, string literals). Use `readonly` for values set once at runtime (config, injected dependencies). Avoid `var` when the type isn't obvious from the right-hand side — it hurts readability.

---

## Core Concept
C# is statically typed, which means every variable has a type that's locked in at compile time — not at runtime like Python or JavaScript. When you write `int x = 5`, the compiler knows `x` is always an `int`. When you write `var x = 5`, the compiler still infers it as `int` — `var` is just syntactic sugar, not dynamic typing. The big gotcha is the difference between value types (like `int`, `bool`, `struct`) which live on the stack and are copied when assigned, versus reference types (like `string`, `object`, classes) which live on the heap and share a reference. Misunderstanding this causes the "why did my object change?" bug.

---

## The Code

**Basic declaration and inference**
```csharp
int age = 30;           // explicit type
var name = "Alice";     // compiler infers string
var score = 98.6;       // inferred as double, not float
float temp = 98.6f;     // 'f' suffix required for float literal
```

**const vs readonly**
```csharp
public class Config
{
    public const int MaxRetries = 3;           // compile-time constant, baked into IL
    public readonly string ConnectionString;   // set once, in constructor only

    public Config(string connStr)
    {
        ConnectionString = connStr;            // only valid here
    }
}
```

**Value type vs reference type behaviour**
```csharp
// Value type: copied
int a = 10;
int b = a;
b = 99;
Console.WriteLine(a); // still 10

// Reference type: shared reference
var list1 = new List<int> { 1, 2, 3 };
var list2 = list1;     // both point to same object
list2.Add(4);
Console.WriteLine(list1.Count); // 4 — list1 was modified too

// String is a reference type but is immutable, so it behaves like a value type
string s1 = "hello";
string s2 = s1;
s2 = "world";
Console.WriteLine(s1); // still "hello"
```

**Nullable value types**
```csharp
int? maybeAge = null;         // int? is Nullable<int>
int definiteAge = maybeAge ?? 0;  // null-coalescing fallback

// Nullable reference types (C# 8+, enable in .csproj)
string? maybeNull = null;
int length = maybeNull?.Length ?? 0;  // safe navigation
```

**out, ref, and in parameters**
```csharp
// out: caller doesn't need to initialise, method must assign
bool success = int.TryParse("42", out int parsed);

// ref: passes reference to value type, method can modify it
void Double(ref int x) => x *= 2;
int n = 5;
Double(ref n); // n is now 10

// in: readonly ref — passed by reference but can't be modified
void Print(in int x) => Console.WriteLine(x); // can't assign to x
```

---

## Gotchas

- **`var` with numeric literals defaults to `double`, not `float`** — `var x = 1.5` is a `double`. Writing `float x = 1.5` is a compile error; you need `1.5f`. This bites people coming from languages where float is the default.
- **`const` is baked into the caller's IL at compile time** — if you change a `const` in a library and don't recompile all dependent assemblies, they still use the old value. `readonly static` avoids this.
- **Assigning a reference type doesn't clone it** — `var b = a` when `a` is a class just copies the pointer. Both variables now mutate the same object. Use `new`, `.Clone()`, or a copy constructor if you need independence.
- **`string` looks like a value type but isn't** — it's a reference type that's immutable, so reassigning `s = s + "!"` creates a new string object. In tight loops this causes significant heap pressure; use `StringBuilder`.
- **Nullable reference types (`string?`) in C# 8+ are warnings, not errors by default** — you can still dereference a null without a compiler error if you ignore the warning. They're opt-in via `<Nullable>enable</Nullable>` in the `.csproj`.

---

## Interview Angle
**What they're really testing:** Whether you understand memory model, type safety, and the implications of value vs reference semantics — not just syntax.

**Common question form:** "What's the difference between `const` and `readonly`?" / "What happens when you do `var b = a` for a class vs a struct?" / "Is `string` a value type or reference type, and why does it behave like one?"

**The depth signal:** A junior says "`const` is for constants and `readonly` is for fields." A senior explains that `const` is resolved at compile time and embedded in the caller's IL — which means changing it in a library without recompiling consumers silently breaks things — while `readonly` is resolved at runtime. On value vs reference types, a senior brings up `struct` mutability traps: passing a `struct` to a method doesn't let the method mutate the original, which surprises people used to working with classes.

---

## Related Topics
- [[dotnet/csharp-value-types-vs-reference-types.md]] — Deeper dive into stack vs heap, boxing/unboxing, and struct design
- [[dotnet/csharp-nullable-types.md]] — Nullable<T>, null-coalescing operators, and C# 8 nullable reference types
- [[dotnet/csharp-string-manipulation.md]] — Why string concatenation in loops is slow and when to use StringBuilder
- [[algorithms/memory-management.md]] — Stack vs heap at the OS/runtime level, relevant to understanding value type behaviour

---

## Source
[C# Variables — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/variables)

---
*Last updated: 2026-03-23*