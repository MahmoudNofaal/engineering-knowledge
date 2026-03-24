# C# Type Conversion

> The process of changing a value from one type to another — either automatically by the compiler (implicit) or explicitly instructed by you (explicit/cast).

---

## When To Use It
Type conversion comes up any time you mix numeric types, work with inheritance hierarchies, or parse external input (strings from APIs, user input, config files). Use implicit conversion freely — the compiler only allows it when there's no risk of data loss. Use explicit casting when you know the conversion is safe and accept the truncation or risk. Use `Convert`, `Parse`, or `TryParse` for string-to-type conversions from external data — never cast a string to a number. Avoid casting down an inheritance hierarchy (`as` or direct cast) without checking the actual runtime type first.

---

## Core Concept
There are really four different things people call "type conversion" in C#, and mixing them up causes bugs. First, implicit conversion: the compiler silently widens a type when there's no data loss risk — `int` to `long`, `float` to `double`. Second, explicit casting: you force a conversion with `(TargetType)value`, accepting that it might truncate or throw. Third, the `as` and `is` operators for reference type conversions — `as` returns null on failure instead of throwing, `is` checks the type before you commit. Fourth, parsing: `int.Parse("42")` and `int.TryParse("42", out int n)` for turning strings into typed values — these are method calls, not casts, and they're the right tool for any string coming from outside your program. Knowing which tool fits which situation is the whole skill.

---

## The Code

**Implicit conversion: compiler widens automatically**
```csharp
int i = 100;
long l = i;       // safe: int fits in long, no data loss
float f = i;      // safe: int to float
double d = f;     // safe: float to double

// Not implicit — would lose data:
// int x = l;     // compile error: long can't implicitly become int
```

**Explicit cast: you accept the truncation**
```csharp
double price = 9.99;
int truncated = (int)price;    // 9 — decimal part is silently dropped, no rounding

long bigNumber = 3_000_000_000L;
int overflow = (int)bigNumber; // compiles and runs — result is garbage (wraps around)
                                // no exception thrown by default

// Checked context: throws OverflowException instead of wrapping
int safe = checked((int)bigNumber); // throws
```

**`as` and `is` for reference type downcasting**
```csharp
object obj = "hello";

// Direct cast: throws InvalidCastException if wrong type
string s1 = (string)obj;   // fine here, but dangerous on unknown objects

// as: returns null on failure — no exception
string? s2 = obj as string;
if (s2 != null) Console.WriteLine(s2.ToUpper());

// is with pattern variable (C# 7+): check and bind in one step
if (obj is string text)
    Console.WriteLine(text.Length); // text is already string here

// Pattern matching in switch
object value = 42;
string description = value switch
{
    int n when n > 0 => $"positive int: {n}",
    string s         => $"string: {s}",
    null             => "null",
    _                => "something else"
};
```

**Parse vs TryParse: string to numeric type**
```csharp
// Parse: throws FormatException if input is invalid
int age = int.Parse("25");         // fine
int bad = int.Parse("twenty");     // throws FormatException

// TryParse: returns false on failure, never throws
if (int.TryParse("25", out int parsed))
    Console.WriteLine(parsed);     // 25
else
    Console.WriteLine("invalid input");

// Always use TryParse for external/user input
string userInput = Console.ReadLine() ?? "";
if (!decimal.TryParse(userInput, out decimal amount))
    Console.WriteLine("not a valid number");
```

**Convert class: null-safe conversions between base types**
```csharp
object? maybeNull = null;

int fromNull = Convert.ToInt32(maybeNull);   // returns 0 — doesn't throw on null
// contrast: (int)maybeNull throws NullReferenceException
// int.Parse(null) throws ArgumentNullException

string numStr = "42";
int result = Convert.ToInt32(numStr);   // works, but TryParse is safer for user input
```

**Implicit and explicit conversion operators on custom types**
```csharp
public readonly struct Celsius
{
    public double Value { get; }
    public Celsius(double v) => Value = v;

    public static implicit operator Fahrenheit(Celsius c)
        => new Fahrenheit(c.Value * 9 / 5 + 32);
}

public readonly struct Fahrenheit
{
    public double Value { get; }
    public Fahrenheit(double v) => Value = v;
}

Celsius boiling = new Celsius(100);
Fahrenheit f = boiling;   // implicit conversion — no cast syntax needed
Console.WriteLine(f.Value); // 212
```

---

## Gotchas

- **Explicit cast between numeric types truncates silently, it does not round.** `(int)9.99` is `9`, not `10`. And `(int)` on an overflowing `long` produces garbage data with no exception — you need a `checked` block to get an `OverflowException`.
- **`as` only works on reference types and nullable value types.** `42 as string` is a compile error. `someInt as int?` works because `int?` is `Nullable<int>`. If you try to use `as` on a non-nullable value type the compiler rejects it — don't reach for it thinking it's a safe version of any cast.
- **`Convert.ToInt32` and `(int)` are not the same thing.** `Convert.ToInt32(null)` returns `0`. `(int)null` throws. `Convert.ToInt32("42")` calls `int.Parse` internally and throws `FormatException` on bad input. They look interchangeable but behave differently at the edges.
- **`int.Parse` throws two different exceptions depending on what's wrong.** `FormatException` if the string isn't a valid number, `OverflowException` if it's a valid number but too large for `int`. If you catch one and not the other, you'll get uncaught exceptions in production. `TryParse` handles both — use it for any input you don't fully control.
- **Implicit conversion operators on custom types can make code deceptive.** Defining `implicit operator` means the conversion happens invisibly at assignment — callers don't see a cast, so they may not realise a conversion is occurring. Use `explicit operator` instead unless the conversion is truly loss-free and unsurprising. The classic mistake is defining implicit conversions between domain types (like `UserId` to `OrderId`) that should never be silently interchangeable.

---

## Interview Angle
**What they're really testing:** Whether you understand the difference between safe widening, potentially lossy casting, and string parsing — and whether you know which one to reach for in each context.

**Common question form:** "What's the difference between implicit and explicit conversion?" / "When would you use `as` instead of a direct cast?" / "What's the difference between `Parse` and `TryParse`?"

**The depth signal:** A junior knows that `(int)` casts and that `TryParse` is "safer." A senior explains *why* each tool exists: implicit conversion is compiler-guaranteed to be lossless; explicit cast is a runtime risk you're accepting; `as` avoids the `InvalidCastException` but shifts the null check onto you; `TryParse` never throws so it's correct for all external input, while `Parse` is fine inside your own system where you control the data. They also know about `checked` blocks for overflow detection, and can talk about when defining custom conversion operators on structs is legitimate vs a design smell.

---

## Related Topics
- [[dotnet/csharp-value-vs-reference-types.md]] — Implicit/explicit cast rules differ between value types and reference types; understanding that split is a prerequisite
- [[dotnet/csharp-nullable-types.md]] — `as` returns a nullable reference; `TryParse` uses `out` with nullable value types — the two topics intersect constantly
- [[dotnet/csharp-pattern-matching.md]] — `is` with pattern variables is the modern replacement for `as`-then-null-check; they cover the same ground with cleaner syntax
- [[dotnet/csharp-structs.md]] — Custom implicit/explicit conversion operators are most commonly defined on structs; the design rules for when to use them live there

---

## Source
[Casting and type conversions — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/types/casting-and-type-conversions)

---
*Last updated: 2026-03-23*