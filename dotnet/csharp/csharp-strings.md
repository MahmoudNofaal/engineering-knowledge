# C# Strings

> An immutable sequence of Unicode characters, represented as the `string` type (alias for `System.String`), with built-in language support for literals, interpolation, and manipulation.

---

## When To Use It
Strings are everywhere — any time you handle text, names, messages, paths, or serialised data. The key decisions are around *how* you build and manipulate them: use interpolation (`$""`) or `string.Format` for composing readable strings; use `StringBuilder` when you're concatenating in a loop; use `Span<char>` or `AsSpan()` in hot paths to avoid allocations. The main thing to avoid is string concatenation with `+` inside any loop — it looks innocent and causes serious GC pressure at scale.

---

## Core Concept
A `string` in C# is an immutable reference type. Immutable means that once created, it can't be changed — every operation that looks like it modifies a string (`.ToUpper()`, `.Replace()`, `+`) actually creates a new string object and returns it. The original is untouched. This is why `s = s + "!"` in a loop allocates a new string on the heap every single iteration. The flip side of immutability is that strings are safe to share across threads without locking, and the runtime can intern them (reuse identical literals from a pool). Interning is why two separate `"hello"` literals in your code can end up being the exact same object in memory, which makes `==` on string literals return true even though strings are reference types — but that's string value equality overriding the default reference equality, not pointer comparison.

---

## The Code

**Literals, verbatim strings, and raw string literals**
```csharp
string path = "C:\\Users\\alice\\docs";          // escaped backslash
string verbatim = @"C:\Users\alice\docs";        // verbatim: no escape needed
string multiLine = @"line one
line two";                                        // verbatim preserves newlines

// Raw string literals (C# 11+): no escaping at all
string json = """
    {
        "name": "Alice",
        "age": 30
    }
    """;
```

**String interpolation and formatting**
```csharp
string name = "Alice";
int age = 30;
decimal price = 9.99m;

string msg = $"Name: {name}, Age: {age}";
string formatted = $"Price: {price:C2}";          // currency format: $9.99
string padded = $"{name,10}";                      // right-align in 10 chars
string expr = $"Next year: {age + 1}";            // expressions work inside {}

// Multiline interpolation (C# 11+)
string block = $"""
    Hello, {name}.
    You are {age} years old.
    """;
```

**Common string methods**
```csharp
string s = "  Hello, World!  ";

s.Trim()                        // "Hello, World!"
s.ToUpper()                     // "  HELLO, WORLD!  "
s.Contains("World")             // true
s.Replace("World", "C#")        // "  Hello, C#!  "
s.StartsWith("Hello")           // false — leading spaces
s.Trim().StartsWith("Hello")    // true
s.Split(',')                    // ["  Hello", " World!  "]
s.Substring(2, 5)               // "Hello" (start index, length)
s[2..7]                         // "Hello" — range syntax (C# 8+)

// Null-safe check: prefer IsNullOrWhiteSpace over IsNullOrEmpty for user input
string.IsNullOrEmpty(s)         // false
string.IsNullOrWhiteSpace("  ") // true
```

**String equality: case-sensitive vs case-insensitive**
```csharp
string a = "Hello";
string b = "hello";

bool exact = a == b;                                           // false
bool ignoreCase = string.Equals(a, b, StringComparison.OrdinalIgnoreCase); // true

// Always specify StringComparison for non-trivial equality
// Ordinal = byte-by-byte, fastest, culture-independent
// OrdinalIgnoreCase = same but case-insensitive
// CurrentCulture = locale-aware, needed for user-visible text sorting
```

**StringBuilder: for concatenation in loops**
```csharp
// Bad: creates a new string object on every iteration
string result = "";
for (int i = 0; i < 10_000; i++)
    result += i.ToString();   // 10,000 allocations

// Good: one buffer, one final allocation
var sb = new StringBuilder();
for (int i = 0; i < 10_000; i++)
    sb.Append(i);
string result2 = sb.ToString();   // single string at the end

// StringBuilder also supports chaining
string csv = new StringBuilder()
    .Append("Alice").Append(',')
    .Append("30").Append(',')
    .AppendLine("Engineer")
    .ToString();
```

**Span<char>: zero-allocation slicing (hot paths)**
```csharp
string input = "user:alice:admin";

// Old way: allocates a new string
string[] parts = input.Split(':');

// Span way: no allocation — works on the original memory
ReadOnlySpan<char> span = input.AsSpan();
int first = span.IndexOf(':');
ReadOnlySpan<char> role = span[(first + 1)..];  // "alice:admin" — no new string
```

---

## Gotchas

- **`+` concatenation in a loop is a performance trap with no compile-time warning.** Each `result += someString` allocates a brand-new string of increasing length. Ten iterations is fine; ten thousand creates hundreds of megabytes of short-lived heap garbage. The compiler won't tell you — use `StringBuilder` or `string.Join` instead.
- **`==` on strings compares value, but `.Equals()` without `StringComparison` uses culture-sensitive rules by default.** `"café".Equals("cafe")` can return `true` on some locales. For any non-display comparison (IDs, keys, config values), always pass `StringComparison.Ordinal` or `StringComparison.OrdinalIgnoreCase` explicitly.
- **`string.Empty` and `""` are the same object due to interning, but `null` is not.** `null == string.Empty` is `false`. Using `s.Length == 0` on a potentially null string throws; use `string.IsNullOrEmpty(s)` instead.
- **`Substring` takes (startIndex, length), not (startIndex, endIndex).** `"Hello".Substring(1, 3)` is `"ell"`, not `"ello"`. The C# 8 range syntax `s[1..4]` is endIndex-exclusive and often clearer — but they're not drop-in identical because range syntax maps to `Slice`, not `Substring`, on spans.
- **Interpolated strings (`$""`) are not free when logging.** Writing `logger.Debug($"Processing {expensiveCall()}")` evaluates `expensiveCall()` and allocates the string *even when debug logging is disabled*. Use structured logging with message templates (`logger.Debug("Processing {Value}", value)`) so the string is never built unless it will actually be logged.

---

## Interview Angle
**What they're really testing:** Whether you understand immutability and its performance implications, and whether you make correct decisions about when plain strings vs `StringBuilder` vs `Span<char>` are appropriate.

**Common question form:** "Why is string concatenation in a loop bad?" / "What's the difference between `string` and `StringBuilder`?" / "How do you compare strings case-insensitively in C#?"

**The depth signal:** A junior knows to use `StringBuilder` in loops and that `==` does value comparison on strings. A senior explains *why* — immutability means every `+` allocates a new object; they know that `string.Equals` without `StringComparison` is a latent bug in any internationalised app; they know `Span<char>` and `AsSpan()` for parsing hot paths to avoid allocations entirely; and they flag the structured logging anti-pattern as a real production issue rather than a theoretical one.

---

## Related Topics
- [[dotnet/csharp-value-vs-reference-types.md]] — String is a reference type with value-type equality semantics; understanding why requires knowing how reference equality works
- [[dotnet/csharp-nullable-types.md]] — `string?` and `string.IsNullOrEmpty` vs `IsNullOrWhiteSpace` decisions come up constantly together
- [[dotnet/csharp-span-and-memory.md]] — `Span<char>` and `ReadOnlySpan<char>` are the zero-allocation alternative to string slicing in performance-sensitive code
- [[dotnet/csharp-type-conversion.md]] — `int.Parse`, `ToString`, and `Convert` are the bridge between strings and typed values; they connect directly to string handling patterns

---

## Source
[String class — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.string)

---
*Last updated: 2026-03-23*