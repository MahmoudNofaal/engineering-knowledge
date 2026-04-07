# C# Strings

> An immutable, reference-type sequence of Unicode characters — every "modification" produces a new string, string literals are interned, and `StringBuilder` or interpolation handlers are the tools for efficient composition.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Immutable reference type; behaves like a value type due to operator overloads |
| **Equality** | `==` compares content (overloaded), `ReferenceEquals` compares identity |
| **Null-safe** | `string.IsNullOrEmpty`, `string.IsNullOrWhiteSpace` |
| **Performance tool** | `StringBuilder` for many concatenations, `$""` for simple |
| **C# version** | C# 1.0; interpolation: C# 6.0; `StringSyntaxAttribute`: C# 11 |
| **Namespace** | `System` |

---

## When To Use It

`string` is correct for almost all text. Switch to `StringBuilder` only when you're concatenating in a loop or building a string from many pieces — the threshold is roughly 5+ concatenations in a non-trivial loop. For parsing/processing without allocation, use `Span<char>` or `ReadOnlySpan<char>`.

---

## Core Concept

`string` is a reference type but acts like a value type because:
1. It's **immutable** — no method changes it in place
2. `==` and `!=` compare **content**, not reference (operator overloaded)
3. String **interning** means identical literal strings often share the same heap object

Because strings are immutable, `s = s + "x"` creates a new string on every call. In a loop of 10,000 concatenations, that's 10,000 allocations and O(n²) total copying. `StringBuilder` solves this by maintaining a mutable buffer and converting to a string once at the end.

**Interning:** The CLR keeps a pool of string literals. Two `"hello"` literals in different files resolve to the same heap object. `string.Intern(s)` can pool a runtime string; `string.IsInterned(s)` checks.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | `string`, `StringBuilder`, basic methods |
| C# 6.0 | .NET 4.6 | `$"interpolation"` string interpolation |
| .NET Core 2.1 | — | `Span<char>` slice APIs, `string.Create` |
| C# 8.0 | .NET Core 3.0 | Range/index: `s[1..4]`, `s[^1]` |
| .NET 6 | — | `DefaultInterpolatedStringHandler` — no boxing in `$""` |
| C# 11 | .NET 7 | Raw string literals `"""..."""`, UTF-8 literals `"text"u8` |

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `s1 + s2` | 1 allocation | Fine for 2–3 concatenations |
| `+` in a loop n times | O(n²) total copy | Use `StringBuilder` |
| `$"..."` (.NET 6+) | 0–1 allocation | `DefaultInterpolatedStringHandler` avoids boxing |
| `StringBuilder.Append` | Amortised O(1) | Buffer doubling like `List<T>` |
| `string.Concat(arr)` | O(n) + 1 alloc | Faster than `+` chain for many short strings |
| `ReadOnlySpan<char>` slice | 0 allocations | View into existing string, no copy |

---

## The Code

**Immutability and equality**
```csharp
string a = "hello";
string b = a;
a = a.ToUpper(); // a is now "HELLO" — b is still "hello"
// b was never modified — strings are immutable

// Content equality (operator overloaded)
string s1 = "hello", s2 = "hel" + "lo";
Console.WriteLine(s1 == s2);              // true  — content equal
Console.WriteLine(ReferenceEquals(s1, s2)); // maybe false — different objects

// Case-insensitive comparison
Console.WriteLine(string.Equals(s1, "HELLO", StringComparison.OrdinalIgnoreCase)); // true
Console.WriteLine(s1.Equals("HELLO", StringComparison.OrdinalIgnoreCase));          // true
```

**String interpolation and raw literals**
```csharp
string name = "Alice";
decimal price = 9.99m;
DateTime now = DateTime.UtcNow;

// Interpolation — format specifiers inline
string msg = $"Hello, {name}! Price: {price:C2}. Date: {now:yyyy-MM-dd}";

// Verbatim: @ prefix — no escape sequences (except "")
string path = @"C:\Users\Alice\Documents\file.txt";

// Raw string literal (C# 11) — any content, no escaping needed
string json = """
    {
        "name": "Alice",
        "path": "C:\\Users\\Alice"
    }
    """;

// UTF-8 literal (C# 11) — ReadOnlySpan<byte>, no allocation
ReadOnlySpan<byte> utf8 = "hello"u8;
```

**StringBuilder for loop concatenation**
```csharp
// BAD: O(n²) — allocates new string each iteration
string result = "";
for (int i = 0; i < 10_000; i++)
    result += i.ToString() + ", ";

// GOOD: StringBuilder — amortised O(1) per append
var sb = new StringBuilder(capacity: 64_000); // pre-size if known
for (int i = 0; i < 10_000; i++)
    sb.Append(i).Append(", ");
string result2 = sb.ToString(); // one final allocation
```

**Common string methods**
```csharp
string s = "  Hello, World!  ";

s.Trim();                      // "Hello, World!"
s.ToUpper();                   // "  HELLO, WORLD!  "
s.Contains("World");           // true
s.StartsWith("  H");           // true
s.Replace("World", "C#");      // "  Hello, C#!  "
s.Split(',');                  // ["  Hello", " World!  "]
s.IndexOf("World");            // 8
s.Substring(2, 5);             // "Hello"
s[2..7];                       // "Hello" — range syntax (C# 8)
string.IsNullOrWhiteSpace(s);  // false — has non-whitespace
```

**Zero-allocation processing with `Span<char>`**
```csharp
string csv = "alice,bob,charlie";
ReadOnlySpan<char> span = csv.AsSpan();

while (span.Length > 0)
{
    int comma = span.IndexOf(',');
    ReadOnlySpan<char> field = comma >= 0 ? span[..comma] : span;
    Console.WriteLine(field.ToString()); // allocates only here — for display
    if (comma < 0) break;
    span = span[(comma + 1)..];
}
// Entire parsing loop: zero allocations
```

---

## Real World Example

A URL slug generator processes user-provided strings safely, using `Span<char>` for the hot inner loop to avoid per-character allocations.

```csharp
public static class SlugGenerator
{
    private static readonly char[] InvalidChars =
        Path.GetInvalidFileNameChars().Concat(new[] { ' ', '\t', '\r', '\n' }).ToArray();

    public static string ToSlug(string input)
    {
        if (string.IsNullOrWhiteSpace(input)) return string.Empty;

        // string.Create: allocate result buffer once, fill via delegate
        return string.Create(input.Length, input.ToLowerInvariant(), (span, src) =>
        {
            int writePos = 0;
            bool prevDash = false;

            foreach (char c in src)
            {
                if (char.IsLetterOrDigit(c))
                {
                    span[writePos++] = c;
                    prevDash = false;
                }
                else if (!prevDash && writePos > 0)
                {
                    span[writePos++] = '-';
                    prevDash = true;
                }
            }

            // Trim trailing dash
            if (writePos > 0 && span[writePos - 1] == '-') writePos--;

            // Slice to actual written length
            span = span[..writePos]; // note: in this delegate, span is already the right buffer
        }).TrimEnd('-');
    }
}

Console.WriteLine(SlugGenerator.ToSlug("Hello, World! 2026")); // "hello-world-2026"
```

---

## Common Misconceptions

**"`string` is a value type because `==` compares content"**
`string` is a reference type on the heap. `==` is an overloaded operator that compares content. The type itself is reference — `string` is `null`-able, stored as a pointer, passed by pointer. The operator overload just makes it *behave* like a value type for equality.

**"String interpolation always boxes value types"**
Before .NET 6, `$"Value: {myInt}"` boxed the `int`. Since .NET 6, the compiler uses `DefaultInterpolatedStringHandler` which avoids boxing for common value types. This is a free performance improvement for code targeting .NET 6+.

---

## Gotchas

- **`string.Concat(a, b, c)` is faster than `a + b + c` for 3+ strings.** `+` creates intermediate strings; `Concat` allocates once.
- **`string.IsNullOrWhiteSpace` vs `IsNullOrEmpty`:** for user input always use `IsNullOrWhiteSpace` — spaces-only is semantically empty.
- **`Split` with a string separator requires `StringSplitOptions`.** `"a,,b".Split(',')` returns `["a", "", "b"]` — the empty entry is included by default.
- **`StringBuilder` is not thread-safe.** Don't share one across threads.
- **Interned strings fail `ReferenceEquals` tests for runtime strings.** Don't rely on interning for equality — use `==` or `string.Equals`.
- **`string[^1]` is the last character, not an index.** The `^` index-from-end syntax works on strings since C# 8.

---

## Interview Angle

**What they're really testing:** Immutability consequences, allocation behaviour, and when to reach for `StringBuilder` vs `$""` vs `Span<char>`.

**Common question forms:**
- "Why is string concatenation in a loop slow?"
- "What's the difference between `==` on `string` vs on a custom class?"
- "When would you use `StringBuilder`?"

**The depth signal:** A senior explains `string` immutability leads to O(n²) copy behaviour for naive loop concatenation, knows `StringBuilder` pre-sizing avoids buffer resizing, and reaches for `Span<char>` or `string.Create` for zero-allocation parsing in hot paths.

---

## Related Topics

- [[dotnet/csharp/csharp-span-memory.md]] — `ReadOnlySpan<char>` for zero-allocation string slicing
- [[dotnet/csharp/csharp-value-vs-reference-types.md]] — `string` is a reference type that deliberately acts like a value type

---

## Source

[Strings — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/strings/)

---
*Last updated: 2026-04-06*