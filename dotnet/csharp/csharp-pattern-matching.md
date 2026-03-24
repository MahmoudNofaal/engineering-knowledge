# C# Pattern Matching

> Pattern matching is a set of language features that let you test a value's shape, type, or content and extract parts of it in a single expression.

---

## When To Use It

Use pattern matching when you need to branch on an object's type, structure, or value — replacing long `if`/`else if` chains, `is`/`as` casts, and multi-field null checks with concise, readable expressions. It is especially powerful for processing discriminated union-like class hierarchies (sealed base class with known subtypes), deconstructing tuples and records, and writing switch expressions that must be exhaustive. Do not use it when a simple `if` or polymorphic dispatch is clearer — pattern matching can become unreadable if each arm contains significant logic that belongs in a method.

---

## Core Concept

Before C# 7, checking a type meant `is` followed by a separate cast, or `as` followed by a null check. Pattern matching collapses test and extraction into one step: `if (shape is Circle c)` tests the type and binds the variable `c` in the same expression. From C# 8 onwards, `switch` expressions extended this into exhaustive, value-returning branching. C# 9 added relational and logical patterns (`> 0`, `and`, `or`, `not`). C# 10 added extended property patterns. C# 11 added list patterns. The design goal throughout is that the compiler can check exhaustiveness — for a sealed hierarchy it warns you when a new subtype is added but your switch doesn't handle it — which is something `if`/`else` chains can never give you.

---

## The Code
```csharp
// --- Type pattern: test and bind in one step ---
object obj = "hello";

if (obj is string s)
    Console.WriteLine(s.ToUpper()); // s is string, already cast

// --- Declaration pattern in switch expression (C# 8+) ---
static string Describe(object obj) => obj switch
{
    int n when n < 0  => "negative int",
    int n             => $"positive int: {n}",
    string s          => $"string of length {s.Length}",
    null              => "null",
    _                 => "something else"   // discard = default arm
};

// --- Sealed hierarchy: compiler checks exhaustiveness ---
abstract record Shape;
record Circle(double Radius)          : Shape;
record Rectangle(double W, double H) : Shape;
record Triangle(double Base, double Height) : Shape;

static double Area(Shape shape) => shape switch
{
    Circle c       => Math.PI * c.Radius * c.Radius,
    Rectangle r    => r.W * r.H,
    Triangle t     => 0.5 * t.Base * t.Height,
    // Compiler warning if a new subtype is added and not handled here
};

// --- Property pattern: match on field/property values ---
record Order(string Status, decimal Total);

static string Classify(Order o) => o switch
{
    { Status: "Cancelled" }                     => "cancelled",
    { Status: "Pending", Total: > 1000 }        => "high-value pending",
    { Status: "Pending" }                       => "normal pending",
    { Status: "Shipped" or "Delivered" }        => "in transit or done",
    _                                           => "unknown"
};

// --- Positional pattern: uses Deconstruct ---
record Point(int X, int Y);

static string Quadrant(Point p) => p switch
{
    ( > 0,  > 0) => "Q1",
    ( < 0,  > 0) => "Q2",
    ( < 0,  < 0) => "Q3",
    ( > 0,  < 0) => "Q4",
    _            => "origin or axis"
};

// --- Relational and logical patterns (C# 9) ---
static string Grade(int score) => score switch
{
    >= 90           => "A",
    >= 80 and < 90  => "B",
    >= 70 and < 80  => "C",
    >= 60 and < 70  => "D",
    _               => "F"
};

// --- List pattern (C# 11): match on sequence structure ---
static string Summarise(int[] nums) => nums switch
{
    []          => "empty",
    [var only]  => $"one element: {only}",
    [var first, .., var last] => $"starts {first}, ends {last}",
};

// --- Nested property pattern (C# 10 extended) ---
record Address(string Country, string City);
record Customer(string Name, Address Address);

static bool IsLondonCustomer(Customer c) =>
    c is { Address.Country: "UK", Address.City: "London" };

// --- var pattern: always matches, binds the value ---
static bool IsHotAndFast(object reading) =>
    reading is { } r                          // non-null check
    && r is (double temp, double speed)       // positional deconstruct
    && temp > 100 && speed > 200;
```

---

## Gotchas

- **Pattern matching on non-sealed hierarchies is not exhaustive.** The compiler only guarantees it will warn about missing cases for `sealed` class hierarchies. If your base class is `public abstract` but not `sealed`, someone can add a subtype in another assembly and your switch silently falls through to `_`. Seal the base type when the set of subtypes is meant to be closed.
- **`when` guards are evaluated after the pattern matches, but the binding still occurs.** In `case Circle c when c.Radius > 10`, `c` is bound before `when` runs. If the guard throws, the bound variable is already in scope. More subtly, a failed `when` guard does not prevent the next arm from matching — the switch continues to the next arm, not the default.
- **Property patterns match `null` for a missing property only with a `null` pattern arm.** `{ Total: > 0 }` does not match if `Total` is a nullable and its value is `null` — the relational comparison fails silently and falls through to the next arm. Add an explicit `{ Total: not null and > 0 }` for nullable properties.
- **Positional patterns require a public `Deconstruct` method or a record's synthesised one.** If you add a new parameter to a record's primary constructor, all positional patterns on that record must be updated — the compiler will not warn you; it will just fail to compile at the pattern sites, which can be scattered across the codebase.
- **Switch expression arms must be exhaustive or the compiler emits a warning and runtime throws.** If no arm matches at runtime, the switch expression throws `SwitchExpressionException`. Forgetting `_` on a non-sealed type is the common cause. In production this surfaces as an unhandled exception for the exact input combination you didn't anticipate.

---

## Interview Angle

**What they're really testing:** Whether you understand pattern matching as a structural and type-safe branching mechanism — not just syntax sugar for `if`/`else` — and whether you know when the compiler's exhaustiveness checking actually kicks in.

**Common question form:** "How would you refactor a long chain of `if (x is TypeA) ... else if (x is TypeB)` checks?" or "How does C# pattern matching compare to a traditional switch statement?"

**The depth signal:** A junior replaces `if`/`else if` with a `switch` expression and calls it done. A senior explains that exhaustiveness checking only works on sealed hierarchies, so sealing the base type is a meaningful design decision — not just style; that property patterns compose with `and`/`or`/`not` to express complex conditions without nesting; that positional patterns require `Deconstruct` and coupling them tightly to a record's constructor means adding a field breaks all pattern sites at compile time; and that `when` guards are post-match predicates, meaning a failed guard hands control to the next arm rather than the default, which produces subtle bugs when multiple arms could match the same type.

---

## Related Topics

- [[dotnet/csharp-records.md]] — Records synthesise `Deconstruct`, equality, and `with` expressions that pair directly with positional and property patterns; they are the natural data type for pattern-matched hierarchies.
- [[dotnet/csharp-nullability.md]] — Pattern matching and nullable reference types intersect: `is not null` is the idiomatic null-check pattern, and property patterns on nullable types require explicit null guards.
- [[dotnet/csharp-linq.md]] — Complex LINQ projections and filters often benefit from `switch` expressions inside `Select` and `Where` instead of nested ternaries or method calls.
- [[dotnet/csharp-expression-trees.md]] — Pattern matching compiles to IL conditionals, not expression trees; understanding why pattern expressions cannot appear inside `Expression<Func<T>>` requires knowing the distinction.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns)

---
*Last updated: 2026-03-23*