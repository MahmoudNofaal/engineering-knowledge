# C# Nullable Types

> Two separate features sharing `?` syntax: `Nullable<T>` for value types that can represent "no value", and nullable reference types (C# 8) where the compiler tracks which references can be null.

---

## Quick Reference

| | |
|---|---|
| **`int?`** | `Nullable<int>` — runtime struct with `HasValue`/`Value` |
| **`string?`** | Compile-time annotation only — no runtime change |
| **Key operators** | `??` (coalesce), `?.` (null-conditional), `??=` (assign-if-null), `!` (suppress) |
| **Enable NRT** | `<Nullable>enable</Nullable>` in `.csproj` |
| **C# version** | `Nullable<T>`: C# 2.0 — Nullable reference types: C# 8.0 |
| **Namespace** | `System.Nullable<T>` (value types only) |

---

## When To Use It

**`int?` / `DateTime?` (nullable value types):** Use when the value is genuinely optional — a database column that allows NULL, a form field the user didn't fill in, an operation that may produce no result. Never use sentinel values (`-1`, `DateTime.MinValue`, `""`) to represent "no value" — they're ambiguous.

**`string?` / `MyClass?` (nullable reference types):** Enable `<Nullable>enable</Nullable>` for new projects. Annotate parameters and properties as `T?` when null is a legitimate value. Leave them as `T` when null should never occur. The compiler points out every potential null dereference.

**When NOT to use `!` (null-forgiving):** Use it only when you've genuinely verified the value is non-null through logic the compiler can't see. Never use `!` to silence a warning you haven't reasoned about — it has zero runtime effect.

---

## Core Concept

These are two completely different features sharing `?` syntax.

**`Nullable<T>` (value types):** A struct wrapper with two fields: `bool hasValue` and `T value`. When `hasValue` is false, accessing `.Value` throws `InvalidOperationException`. Boxing a null `Nullable<T>` produces a null reference — not a box containing null. This is special CLR handling.

**Nullable reference types (NRT):** Purely compile-time static analysis. `string?` and `string` are identical types at runtime — the `?` is erased by the compiler. The compiler uses flow analysis to track where null might exist and warns before you ship a `NullReferenceException`. No runtime overhead, no runtime protection.

The `?.` null-conditional operator safely chains member access: `user?.Address?.City` evaluates to null if any step is null, rather than throwing.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 2.0 | .NET 2.0 | `Nullable<T>` and `T?` shorthand, `??` operator |
| C# 6.0 | .NET 4.6 | `?.` null-conditional operator, `?[]` indexer |
| C# 8.0 | .NET Core 3.0 | Nullable reference types (`string?`), `??=` operator |
| C# 9.0 | .NET 5 | `is not null` pattern — idiomatic null check |
| C# 10.0 | .NET 6 | Improved NRT flow analysis for patterns |
| C# 11.0 | .NET 7 | `required` members — must be set, can't be left null |

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `int?` null check (`HasValue`) | O(1) | Single bool field read |
| `int?.Value` | O(1) + throw if null | `InvalidOperationException` if no value |
| `??` operator | O(1) | Branch on null |
| `?.` operator | O(1) | Null check + conditional access |
| NRT annotations | Zero | Compile-time only — completely erased |

**Allocation behaviour:** `Nullable<T>` is a struct — no heap allocation. Boxing a null `Nullable<T>` produces a null reference. Boxing a non-null `Nullable<T>` boxes the inner value directly (not the wrapper). NRT has zero runtime allocation or overhead.

---

## The Code

**Nullable value types: basics**
```csharp
int? age   = null;
int? score = 42;

Console.WriteLine(age.HasValue);               // false
Console.WriteLine(score.Value);                // 42
// Console.WriteLine(age.Value);              // throws InvalidOperationException!

// Safe access patterns
int safe1     = score.GetValueOrDefault();     // 42
int safe2     = score.GetValueOrDefault(-1);   // 42
int coalesced = age ?? -1;                     // -1
```

**Null-handling operators**
```csharp
string? name = GetUserName();

// ?. null-conditional: returns null instead of throwing
int? length = name?.Length;
string? city = user?.Address?.City;  // chain — null if any step is null

// ?? null-coalescing: fallback when null
string display = name ?? "Anonymous";
int safeLen    = name?.Length ?? 0;

// ??= assign-if-null (C# 8)
name ??= "Guest";   // only assigns if name is currently null

// is not null: idiomatic null check (C# 9)
if (name is not null)
    Console.WriteLine(name.Length); // compiler knows non-null here
```

**Nullable reference types — enabled per project**
```csharp
// In .csproj: <Nullable>enable</Nullable>

string nonNullable = "hello";   // null assignment = compiler warning
string? nullable   = null;      // explicitly allows null

void Greet(string name)          // non-null parameter — caller must provide value
    => Console.WriteLine(name.Length); // safe — no warning

void MaybeGreet(string? name)    // null is valid
{
    // name.Length — warning: dereference of possibly null reference
    Console.WriteLine(name?.Length ?? 0); // correct
}

// Flow analysis: compiler tracks nullability through branches
void Process(string? input)
{
    if (input is null) return;
    Console.WriteLine(input.Length); // safe — compiler knows input is not null
}
```

**The `!` null-forgiving — use sparingly**
```csharp
string? rawConfig = Configuration["key"]; // returns string?

// You know from the config contract this key always exists
string definite = rawConfig!; // suppresses warning — but no runtime protection

// Better: be explicit about the assumption
string definite2 = rawConfig
    ?? throw new InvalidOperationException("Required config key 'key' is missing.");
```

**`Nullable<T>` boxing special cases**
```csharp
int? nullableNull  = null;
int? nullableValue = 42;

object boxedNull  = nullableNull;    // boxes to NULL reference — not a box of null
object boxedValue = nullableValue;   // boxes to box containing 42 (int, not Nullable<int>)

Console.WriteLine(boxedNull  is null); // True
Console.WriteLine(boxedValue is int);  // True — unboxes to int directly

int? unboxedNull = (int?)boxedNull;    // null — no throw (special CLR handling)
// int bad = (int)boxedNull;          // NullReferenceException
```

**Switch expression on nullable value type**
```csharp
static string Categorise(int? score) => score switch
{
    null            => "No score recorded",
    < 50            => "Fail",
    >= 50 and < 80  => "Pass",
    _               => "Distinction"
};
```

---

## Real World Example

An API search endpoint with multiple optional filters. Every parameter is genuinely optional — absence means "no filter", not "error". Nullable types express this intent clearly.

```csharp
public record OrderSearchQuery(
    string?      CustomerName = null,
    DateTime?    FromDate     = null,
    DateTime?    ToDate       = null,
    decimal?     MinTotal     = null,
    decimal?     MaxTotal     = null,
    OrderStatus? Status       = null,
    int          Page         = 1,
    int          PageSize     = 20);

public async Task<PagedResult<OrderDto>> SearchAsync(OrderSearchQuery q, CancellationToken ct)
{
    var query = _db.Orders.AsQueryable();

    // Each filter applied only when the parameter has a value
    if (q.CustomerName is not null)
        query = query.Where(o => o.CustomerName.Contains(q.CustomerName));

    if (q.FromDate.HasValue)
        query = query.Where(o => o.CreatedAt >= q.FromDate.Value);

    if (q.ToDate.HasValue)
        query = query.Where(o => o.CreatedAt <= q.ToDate.Value);

    if (q.MinTotal.HasValue)
        query = query.Where(o => o.Total >= q.MinTotal.Value);

    if (q.MaxTotal.HasValue)
        query = query.Where(o => o.Total <= q.MaxTotal.Value);

    if (q.Status.HasValue)
        query = query.Where(o => o.Status == q.Status.Value);

    int total = await query.CountAsync(ct);
    var items = await query
        .OrderByDescending(o => o.CreatedAt)
        .Skip((q.Page - 1) * q.PageSize)
        .Take(q.PageSize)
        .Select(o => new OrderDto(o.Id, o.CustomerName, o.Total, o.Status))
        .ToListAsync(ct);

    return new PagedResult<OrderDto>(items, total, q.Page, q.PageSize);
}
```

*The key insight: every `DateTime?`, `decimal?`, and `OrderStatus?` in `OrderSearchQuery` semantically means "absent = not filtered." Using `HasValue` to gate each filter is clearer and more explicit than sentinel values like `0` or `DateTime.MinValue`. The type itself communicates the intent, and the compiler ensures you never accidentally use a value that might be absent without checking first.*

---

## Common Misconceptions

**"`int?` and `string?` are the same kind of nullable"**
Completely different. `int?` is `Nullable<int>` — a runtime struct with `HasValue`/`Value` fields and special boxing rules. `string?` with NRT enabled is a compile-time annotation only — `string` and `string?` are identical at runtime. `.Value` can throw on `int?`; there's no equivalent on `string?` because it's just `string` at runtime.

**"Nullable reference types prevent NullReferenceException"**
They don't prevent anything at runtime. NRT emits compiler warnings — not errors. You can suppress every warning with `!` and still ship code that crashes at runtime. NRT is a development-time analysis tool, not a runtime guard.

**"`!` makes null access safe"**
`!` tells the compiler "trust me, this isn't null." It has zero runtime effect. If the value is actually null, you still get `NullReferenceException` at the point of access — `!` just moves the crash without adding any protection.

---

## Gotchas

- **`Nullable<T>.Value` throws `InvalidOperationException` — not `NullReferenceException`.** Calling `.Value` on a null `int?` throws `InvalidOperationException: Nullable object must have a value`. Use `GetValueOrDefault()` or `??` for safe access.

- **`??` on a non-nullable value type is a compile error.** `int x = someInt ?? 0` fails if `someInt` is `int` — there's nothing to coalesce. The left side must actually be nullable.

- **EF Core navigation properties and NRT produce warnings.** EF assigns navigation properties outside normal constructors. Use `= null!` or the `required` modifier to satisfy the compiler: `public required Customer Customer { get; set; }`.

- **`string.IsNullOrWhiteSpace` vs `string.IsNullOrEmpty`:** For user input, use `IsNullOrWhiteSpace` — a string with only spaces is semantically empty. `IsNullOrEmpty` misses that case.

- **`#nullable enable` can be added file-by-file for incremental adoption.** You don't have to enable NRT for the entire project at once. Enable it in new files and gradually migrate old ones.

---

## Interview Angle

**What they're really testing:** Whether you understand that the two nullable systems are fundamentally different, and whether you've actually worked with NRT in a real codebase.

**Common question forms:**
- "What's the difference between `int?` and `string?`?"
- "What do nullable reference types actually prevent?"
- "When would you use `!` and what are the risks?"
- "What happens when you box a null `int?`?"

**The depth signal:** A junior explains `int?` correctly and knows `??` as a fallback. A senior distinguishes the two systems: `int?` is `Nullable<int>` with runtime semantics (special boxing rules, `.Value` throws `InvalidOperationException`); `string?` is a compile-time hint with zero runtime impact. They know `!` is a promise with no safety net, and that NRT emits warnings not errors.

**Follow-up questions to expect:**
- "How do you adopt NRT incrementally in a large existing codebase?"
- "Why does `(int)nullObject` throw `NullReferenceException` but `(int?)nullObject` gives you null?"

---

## Related Topics

- [[dotnet/csharp/csharp-variables.md]] — Covers the basics of variable declaration that interact with nullable annotations
- [[dotnet/csharp/csharp-value-vs-reference-types.md]] — `int?` is a value type wrapper; `string?` is a reference type annotation — both categories matter
- [[dotnet/csharp/csharp-pattern-matching.md]] — `is not null`, `is { }`, and switch expressions compose naturally with nullable types
- [[dotnet/csharp/csharp-operators.md]] — `??`, `?.`, `??=`, and `!` are all operators; full semantics there

---

## Source

[Nullable value types — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/nullable-value-types)

---

*Last updated: 2026-04-06*