# C# Nullable Types

> A way to represent the absence of a value for types that normally can't be null — and, in C# 8+, a compiler-enforced system for making null safety explicit across all types.

---

## When To Use It
Use `int?` (or any `ValueType?`) whenever a value is genuinely optional — a database column that allows NULL, a form field the user didn't fill in, a result that might not exist. Use nullable reference types (`string?`, C# 8+) when you want the compiler to help you track which variables can be null so you stop writing defensive null checks on things that are never null. Don't enable nullable reference types mid-project without a plan — flipping `<Nullable>enable</Nullable>` on a large existing codebase generates hundreds of warnings at once.

---

## Core Concept
C# originally couldn't express "this `int` has no value" — `0` isn't the same as nothing, and value types can't hold `null`. So `Nullable<T>` (shorthand: `T?`) was added as a wrapper struct that holds either a value or a signal that there's no value. That's the old problem, and it's been solved since C# 2. The newer problem (C# 8+) is the opposite: reference types like `string` and `List<T>` have always *allowed* null, but nothing in the compiler told you which ones were *supposed* to be null. Nullable reference types flip the default — the compiler assumes every reference is non-null unless you explicitly say `string?`. It doesn't change runtime behaviour at all; it's a static analysis layer that catches potential null dereferences at compile time. The two systems — nullable value types and nullable reference types — look the same syntactically (`T?`) but are completely different under the hood.

---

## The Code

**Nullable value types: the basics**
```csharp
int? age = null;          // Nullable<int> — has a value or doesn't
int? score = 42;

Console.WriteLine(age.HasValue);    // false
Console.WriteLine(score.Value);     // 42
Console.WriteLine(age.GetValueOrDefault());   // 0
Console.WriteLine(age ?? -1);       // -1 — null-coalescing fallback
```

**Null-conditional and null-coalescing operators**
```csharp
string? name = null;

int? length = name?.Length;        // null if name is null, not a NullReferenceException
string display = name ?? "unknown"; // fallback value
string upper = name?.ToUpper() ?? "UNKNOWN"; // chain them

// Null-coalescing assignment (C# 8+)
name ??= "default";   // assigns only if name is currently null
```

**Nullable reference types (C# 8+): enable in .csproj**
```xml
<!-- .csproj -->
<PropertyGroup>
  <Nullable>enable</Nullable>
</PropertyGroup>
```
```csharp
// With Nullable enabled:
string nonNullable = "hello";   // compiler assumes never null
string? nullable = null;        // explicitly maybe-null

void Greet(string name)         // caller must pass non-null
{
    Console.WriteLine(name.ToUpper()); // safe — no null warning
}

void MaybeGreet(string? name)   // caller may pass null
{
    Console.WriteLine(name.ToUpper()); // warning: dereference of possibly null
    Console.WriteLine(name?.ToUpper() ?? "(nobody)"); // correct
}
```

**Null-forgiving operator: telling the compiler you know better**
```csharp
string? raw = GetFromConfig();   // returns string? 

// You've checked the config and know this key always exists,
// but the compiler doesn't. Use ! to suppress the warning.
string definite = raw!;          // runtime still crashes if raw is null
```

**Pattern matching with null**
```csharp
int? count = GetCount();

string result = count switch
{
    null    => "no data",
    0       => "empty",
    int n when n < 0 => "invalid",
    int n   => $"{n} items"
};
```

**Nullable in a real-world model (database row mapping)**
```csharp
public class UserRecord
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;  // non-null, default to empty
    public string? PhoneNumber { get; set; }           // nullable — column allows NULL
    public DateTime? LastLoginAt { get; set; }         // nullable — may never have logged in
}
```

---

## Gotchas

- **`int?` and `string?` look identical but are completely different.** `int?` is `Nullable<int>` — a value-type struct with a `HasValue` flag. `string?` under nullable reference types is just a compiler annotation; there's no runtime type difference between `string` and `string?`. Calling `.Value` on `Nullable<int>` when it's null throws `InvalidOperationException`, not `NullReferenceException`.
- **Nullable reference types are opt-in and warnings-only by default.** Enabling `<Nullable>enable</Nullable>` doesn't make null dereferences into compile errors — they're warnings. You can suppress them all with `!` and still ship code that crashes at runtime. The system is only as useful as your discipline in actually fixing the warnings.
- **The null-forgiving operator (`!`) is a runtime time bomb.** `raw!` just tells the compiler "trust me." It does nothing at runtime. If `raw` is actually null, you still get a `NullReferenceException`. Don't use it as a shortcut to silence warnings you haven't actually reasoned through.
- **`??` doesn't work on non-nullable value types.** `int x = someInt ?? 0` is a compile error if `someInt` is `int`, not `int?` — there's nothing to coalesce from. The compiler will tell you, but the error message is sometimes confusing if you expected `someInt` to be nullable.
- **EF Core and JSON deserializers generate warnings under Nullable.** When you enable nullable reference types, entity classes and DTOs start producing warnings because `string` properties aren't initialised in the constructor. The idiomatic fix is `= string.Empty;` or `= null!;` — not disabling Nullable for those files.

---

## Interview Angle
**What they're really testing:** Whether you understand the difference between a missing value (null semantics for value types) and null safety at the type system level — and whether you've actually used nullable reference types in production, not just read about them.

**Common question form:** "What's the difference between `int` and `int?`?" / "How do you handle nullable reference types in C# 8?" / "What does the `??` operator do?"

**The depth signal:** A junior explains `int?` correctly and knows `??` as a fallback. A senior distinguishes the two nullable systems (`Nullable<T>` vs nullable reference type annotations), explains that `string?` has zero runtime impact and is purely a static analysis hint, knows when `!` is legitimate vs lazy, and can talk about the practical friction of enabling Nullable on an existing codebase — particularly with EF Core models and deserialised DTOs that need explicit initialisation patterns to satisfy the compiler cleanly.

---

## Related Topics
- [[dotnet/csharp-variables.md]] — Covers `var`, `const`, and basic type declarations that set the context for nullable annotations
- [[dotnet/csharp-value-vs-reference-types.md]] — Explains why `int?` and `string?` are structurally different despite identical syntax
- [[dotnet/csharp-pattern-matching.md]] — `switch` expressions and `is` patterns work naturally with nullable types for exhaustive null handling
- [[databases/sql-null-handling.md]] — NULL in SQL is the source of most nullable value types in C# data models; understanding both together prevents mapping bugs

---

## Source
[Nullable value types — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/nullable-value-types)

---
*Last updated: 2026-03-23*