# C# Type Conversion

> The process of changing a value from one type to another — either automatically by the compiler (implicit), explicitly instructed by you (explicit cast), or via parsing methods for string-to-type conversions.

---

## Quick Reference

| Conversion kind | Syntax | Throws? | Use when |
|---|---|---|---|
| Implicit | `long l = myInt;` | Never | Compiler guarantees no data loss |
| Explicit cast | `(int)myLong` | `OverflowException` in `checked` | You accept potential truncation |
| `as` | `obj as string` | Never (returns null) | Reference type, failure is expected |
| `is` pattern | `if (obj is string s)` | Never | Test + bind in one step |
| `Parse` | `int.Parse("42")` | `FormatException` / `OverflowException` | Internal data you control |
| `TryParse` | `int.TryParse(s, out n)` | Never | External / user input |
| `Convert` | `Convert.ToInt32(x)` | `FormatException` on bad string | Null-safe, mixed-type conversion |

---

## When To Use It

Type conversion comes up any time you mix numeric types, work with inheritance hierarchies, or parse external input. The most important decision is which tool to use:

- **Implicit conversion**: use freely — the compiler only allows it when there's no data loss risk.
- **Explicit cast**: use when you *know* the conversion is safe and accept truncation, or when downcasting in a class hierarchy after checking the type.
- **`TryParse`**: always use for strings coming from outside your program — user input, API responses, config files, database columns. It never throws.
- **`as` operator**: use for reference types when failure (null result) is a normal expected outcome.
- **`is` with pattern variable**: the modern default for downcasting — checks and binds in one step, no separate null check needed.
- Never use `Parse` for untrusted external input — it throws on any invalid input, and `FormatException` is not a pleasant error to surface to users.

---

## Core Concept

There are four distinct mechanisms that people call "type conversion" in C#, and confusing them causes bugs:

1. **Implicit widening**: the compiler widens a type silently when there's zero data loss risk. `int` → `long` → `double`. This is always safe.

2. **Explicit casting**: you force a narrowing conversion with `(TargetType)value`. The compiler trusts you — no check is performed at runtime by default. If the value doesn't fit, you get silent truncation (integer) or a wrapped result. In a `checked` block, you get an `OverflowException` instead.

3. **Reference type casting** (`as`, `is`): unlike numeric casting, reference type casting doesn't move or transform data. It just changes the *static type* the compiler uses for the variable. The underlying object doesn't change. If the object isn't actually the target type, `as` returns null and a direct cast throws `InvalidCastException`.

4. **Parsing**: `int.Parse("42")` is not a cast at all — it's a method that interprets the string's characters and constructs an `int`. There's no relationship between the types involved. Always use `TryParse` for externally-sourced strings.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Implicit/explicit cast, `as`, `is` (basic) |
| C# 2.0 | .NET 2.0 | `TryParse` pattern standardised across BCL |
| C# 7.0 | .NET Core 1.0 | `is` pattern variable: `if (obj is int n)` |
| C# 7.0 | .NET Core 1.0 | `switch` with type patterns |
| C# 8.0 | .NET Core 3.0 | `switch` expression with full patterns |
| C# 9.0 | .NET 5 | `and`, `or`, `not` patterns; `is not null` |

*Before C# 7.0, downcasting required `as` followed by a null check, or a direct cast inside a `try/catch`. The pattern variable (`if (obj is Dog dog)`) eliminated both the separate null check and the double-cast.*

---

## Performance

| Conversion | Cost | Notes |
|---|---|---|
| Implicit numeric widening | 0–1 instruction | Often eliminated by JIT |
| Explicit cast (numeric) | 0–1 instruction | May require truncation instruction |
| `as` operator | 1 type check | `isinst` IL instruction |
| `is` with pattern | 1 type check | Same as `as` — no extra overhead |
| Direct cast `(T)obj` | 1 type check + throw on fail | `castclass` IL instruction |
| `int.Parse` | String scan O(n) | Allocates exception on failure |
| `int.TryParse` | String scan O(n) | No allocation on failure |
| `Convert.ToInt32` | Method call overhead | Calls `Parse` internally for strings |

**Allocation behaviour:** `TryParse` allocates nothing on failure — it returns `false`. `Parse` and `Convert` allocate a full exception object with stack trace on failure, making them expensive in code paths that regularly encounter invalid input.

**Benchmark notes:** In hot paths that parse many strings (log parsers, CSV readers, protocol buffers), the difference between `Parse` (throws on bad data) and `TryParse` (returns false) is significant — not because of the method call overhead, but because exception allocation and unwinding is orders of magnitude slower than a normal return.

---

## The Code

**Implicit widening: safe, automatic**
```csharp
int i = 100;
long l = i;       // int → long: always safe, no data loss
float f = i;      // int → float: safe (though precision may differ for large values)
double d = f;     // float → double: safe

// These don't compile — the compiler knows data loss could occur:
// int x = l;     // error: long can't implicitly become int
// float g = d;   // error: double can't implicitly become float
```

**Explicit cast: you accept the truncation**
```csharp
double price = 9.99;
int truncated = (int)price;     // 9 — decimal part silently dropped, no rounding

long big = 3_000_000_000L;
int overflowed = (int)big;      // wraps around — result is garbage, no exception

// Use checked to get an exception instead of silent wrapping
int safe = checked((int)big);   // throws OverflowException

// Or wrap a whole block
checked
{
    int a = int.MaxValue;
    int b = a + 1;              // throws OverflowException
}
```

**Reference type casting: `as`, `is`, and direct cast**
```csharp
object obj = "hello";

// Direct cast: throws InvalidCastException if wrong type
string s1 = (string)obj;          // fine — obj is actually a string

// as: returns null on failure — no exception
string? s2 = obj as string;       // "hello"
int? n1 = obj as int?;            // null — obj is not an int (as with value types needs T?)

// is with pattern variable (C# 7+): test and bind in one step — preferred
if (obj is string text)
    Console.WriteLine(text.Length); // text is already typed as string

// is not null: idiomatic null check in modern C#
if (obj is not null)
    Console.WriteLine(obj.GetType().Name);

// Pattern matching in switch — type dispatch without casting
string Classify(object value) => value switch
{
    int n when n > 100 => "large int",
    int n              => "small int",
    string { Length: > 10 } s => "long string",
    string s           => "short string",
    null               => "null",
    _                  => "other"
};
```

**String parsing: `Parse` vs `TryParse` vs `Convert`**
```csharp
// Parse: throws FormatException if invalid, OverflowException if too large
int fromString = int.Parse("42");       // fine
int bad = int.Parse("forty-two");       // throws FormatException

// TryParse: never throws — always use for external input
if (int.TryParse(userInput, out int parsed))
    Console.WriteLine($"Valid: {parsed}");
else
    Console.WriteLine("Invalid number");

// TryParse with culture for decimal separator differences
bool ok = decimal.TryParse("9.99", 
    System.Globalization.NumberStyles.Any,
    System.Globalization.CultureInfo.InvariantCulture,
    out decimal amount);

// Convert.ToXxx: null-safe but still throws on bad strings
int fromNull = Convert.ToInt32(null);   // returns 0, doesn't throw
int fromObj  = Convert.ToInt32(42.7);   // 43 — rounds, unlike explicit cast
```

**Custom implicit and explicit conversion operators**
```csharp
public readonly struct Celsius
{
    public double Value { get; }
    public Celsius(double v) => Value = v;

    // Implicit: caller doesn't need to write a cast
    public static implicit operator Fahrenheit(Celsius c)
        => new Fahrenheit(c.Value * 9.0 / 5.0 + 32);

    // Explicit: caller must write (Celsius)fahrenheit — signals possible loss
    public static explicit operator Celsius(double raw)
        => new Celsius(raw);
}

Celsius boiling = new Celsius(100);
Fahrenheit f = boiling;            // implicit — no cast syntax needed
Celsius back = (Celsius)37.0;      // explicit — cast syntax required
```

---

## Real World Example

An API endpoint receives JSON with an unknown schema. Field values come in as `JsonElement`, which requires explicit conversion to typed values. Using `TryParse` for every user-provided field prevents exceptions from propagating to the response layer.

```csharp
public class OrderRequestParser
{
    public ParseResult<OrderRequest> Parse(JsonElement root)
    {
        var errors = new List<string>();

        // String fields — may be missing or wrong type
        if (!root.TryGetProperty("referenceId", out var refIdElement)
            || refIdElement.ValueKind != JsonValueKind.String)
        {
            errors.Add("referenceId is required and must be a string");
        }
        string? referenceId = refIdElement.GetString();

        // Numeric fields — TryParse protects against bad string values
        decimal amount = 0;
        if (root.TryGetProperty("amount", out var amountElement))
        {
            if (!decimal.TryParse(
                amountElement.GetRawText(),
                System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture,
                out amount))
            {
                errors.Add("amount must be a valid decimal number");
            }
        }
        else
        {
            errors.Add("amount is required");
        }

        // Enum parsing — TryParse on enum
        OrderPriority priority = OrderPriority.Normal;
        if (root.TryGetProperty("priority", out var priorityElement))
        {
            string? priorityStr = priorityElement.GetString();
            if (!Enum.TryParse<OrderPriority>(priorityStr, ignoreCase: true, out priority))
            {
                errors.Add($"priority must be one of: {string.Join(", ", Enum.GetNames<OrderPriority>())}");
            }
        }

        if (errors.Count > 0)
            return ParseResult<OrderRequest>.Invalid(errors);

        return ParseResult<OrderRequest>.Valid(
            new OrderRequest(referenceId!, amount, priority));
    }
}
```

*The key insight: every `TryParse` call here returns false on bad input instead of throwing. No exception allocation, no try/catch, no stack unwinding — just a list of validation errors built up and returned. This is the correct pattern for any code that handles external, untrusted data.*

---

## Common Misconceptions

**"`(int)` and `Convert.ToInt32` are interchangeable"**
They're not. `(int)9.99` truncates to `9`. `Convert.ToInt32(9.99)` rounds to `10`. `(int)null` throws `NullReferenceException`. `Convert.ToInt32(null)` returns `0`. `(int)longValue` silently wraps on overflow. `Convert.ToInt32(longValue)` throws `OverflowException` if it doesn't fit. They behave differently in almost every edge case.

**"`as` is always safer than a direct cast"**
`as` is safer in the sense that it doesn't throw — it returns null. But if you then use the result without a null check, you get a `NullReferenceException` on the next line instead of an `InvalidCastException` on the cast. The null check is required. The `is` pattern variable is the modern alternative: it combines the type check, the null check, and the binding into a single expression with no way to forget the null check.

**"`int.Parse` and `int.TryParse` have the same performance"**
On the happy path (valid input) they're similar. On the failure path, `Parse` throws an exception — which allocates the exception object, captures a stack trace (expensive), and unwinds the stack. `TryParse` simply returns `false` with zero allocation. If 10% of your input is invalid, `Parse` in a loop will show up in profiler traces. If 90% is invalid (adversarial input), `Parse` can be 100× slower than `TryParse`.

---

## Gotchas

- **Explicit cast between numeric types truncates silently — it does not round.** `(int)9.99` is `9`, not `10`. And `(int)` on an overflowing `long` produces wrapped garbage with no exception. You need a `checked` block or `checked()` expression to get an `OverflowException`.

- **`as` only works on reference types and nullable value types.** `42 as string` is a compile error. `someInt as int?` works because `int?` is `Nullable<int>`. For non-nullable value types, use `is` patterns instead.

- **`Convert.ToInt32` calls `int.Parse` for strings — it throws on invalid format.** Many developers think `Convert` is a safe parsing method. It's null-safe for null input, but it still throws `FormatException` on strings like `"abc"`. Use `TryParse` for truly safe parsing.

- **Implicit conversion operators on custom types can make code deceptive.** Defining `implicit operator` means the conversion happens invisibly at assignment — callers don't see a cast and may not realise a conversion is occurring. Use `explicit operator` unless the conversion is truly lossless and unsurprising. The classic mistake is defining implicit conversions between domain types (`UserId` → `OrderId`) that should never be silently interchangeable.

- **Downcasting with `as` still requires a null check — it doesn't go away.** `var dog = animal as Dog;` produces `null` if `animal` isn't a `Dog`. Using `dog.Fetch()` after that without checking is just a deferred `NullReferenceException`. The modern fix: `if (animal is Dog dog) dog.Fetch();` — the null check is structurally impossible to forget.

---

## Interview Angle

**What they're really testing:** Whether you understand which tool fits which situation and *why* they behave differently — not just that you know the syntax.

**Common question forms:**
- "What's the difference between implicit and explicit conversion?"
- "When would you use `as` instead of a direct cast?"
- "What's the difference between `Parse` and `TryParse`, and when do you choose each?"
- "What's the difference between `(int)` and `Convert.ToInt32`?"

**The depth signal:** A junior says "`TryParse` is safer." A senior explains *why*: exception allocation in `Parse` has real performance cost in loops, `TryParse` allocates nothing on failure, and the semantic intent is different — `Parse` says "I expect this to be valid", `TryParse` says "this might not be valid and that's fine." On `as` vs `is`, a senior reaches for the pattern variable form unprompted: `if (obj is Dog dog)` is one line that cannot have a forgotten null check, whereas `as` requires a separate null check that's easy to omit under time pressure.

**Follow-up questions to expect:**
- "Can you have implicit conversion between two unrelated types?"
- "What happens when you cast a boxed `int` to a `long`?"

---

## Related Topics

- [[dotnet/csharp/csharp-value-vs-reference-types.md]] — Implicit/explicit cast rules differ between value and reference types; the distinction is a prerequisite
- [[dotnet/csharp/csharp-nullable-types.md]] — `as` returns a nullable reference; `TryParse` uses `out` with nullable value types — they constantly intersect
- [[dotnet/csharp/csharp-pattern-matching.md]] — `is` with pattern variables is the modern replacement for `as`-then-null-check
- [[dotnet/csharp/csharp-boxing-unboxing.md]] — Casting a value type to `object` or an interface is boxing; unboxing requires an exact type match

---

## Source

[Casting and type conversions — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/types/casting-and-type-conversions)

---

*Last updated: 2026-04-06*