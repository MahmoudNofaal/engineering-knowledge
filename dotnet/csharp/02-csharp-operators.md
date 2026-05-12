# C# Operators

> Symbols that perform operations on values — arithmetic, comparison, logical, bitwise, and null-handling — with defined precedence rules that control evaluation order.

---

## Quick Reference

| Category | Operators | Watch out for |
|---|---|---|
| Arithmetic | `+` `-` `*` `/` `%` | Integer division truncates silently |
| Comparison | `==` `!=` `<` `>` `<=` `>=` | `==` on classes checks identity, not value |
| Logical | `&&` `\|\|` `!` `&` `\|` | `&&`/`\|\|` short-circuit; `&`/`\|` don't |
| Bitwise | `&` `\|` `^` `~` `<<` `>>` | `>>` is arithmetic (sign-extends) for signed types |
| Null-handling | `?.` `??` `??=` `!` | `!` suppresses warnings but doesn't prevent NRE |
| Assignment | `=` `+=` `-=` `*=` `/=` `??=` | Compound operators read then write |
| Increment | `++` `--` (prefix/postfix) | Postfix returns original value, then increments |
| Ternary | `? :` | Don't nest more than two levels |
| Type | `is` `as` `typeof` `sizeof` | `as` returns null on failure; cast throws |

---

## When To Use It

Operators are in every non-trivial expression. The decisions that matter:

- Prefer `?.` and `??` over manual null checks — `user?.Address?.City ?? "Unknown"` beats four lines of if-statements.
- Use `&&`/`||` (not `&`/`|`) for boolean logic — short-circuiting prevents null dereferences and avoids unnecessary calls.
- Use bitwise operators (`&`, `|`, `^`) specifically for flag enums and bit manipulation, not as alternatives to `&&`/`||`.
- Avoid nesting ternary operators more than two levels — use a `switch` expression instead.
- Override `==` and `!=` together, always. If you override one, the compiler warns about the other.

---

## Core Concept

Operators are syntactic sugar for method calls. `a + b` on a custom type calls `operator +(a, b)`. `a == b` calls `operator ==`. This means you can define what every operator means for your own types — which is powerful for domain types like `Money` or `Vector`, and dangerous if overused to make operators mean non-obvious things.

The two most important properties of operators are **precedence** (which evaluates first when there are no parentheses — `*` before `+`) and **short-circuit evaluation** (`&&` stops at the first `false`, `||` stops at the first `true`). Both are sources of bugs when misunderstood. When in doubt, add parentheses.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | All arithmetic, comparison, logical, bitwise operators |
| C# 2.0 | .NET 2.0 | `??` null-coalescing operator |
| C# 6.0 | .NET 4.6 | `?.` null-conditional operator |
| C# 7.0 | .NET Core 1.0 | `is` pattern matching (`if (x is int n)`) |
| C# 8.0 | .NET Core 3.0 | `??=` null-coalescing assignment, `switch` expression |
| C# 9.0 | .NET 5 | `and`, `or`, `not` logical patterns in switch/is |
| C# 11.0 | .NET 7 | `>>>` unsigned right shift |

*Before C# 6.0, null checks required `if (x != null) x.Something()`. The null-conditional operator made these chains dramatically shorter and more readable.*

---

## Performance

| Operator | Cost | Notes |
|---|---|---|
| Arithmetic (`+`, `-`, `*`) | ~1 CPU cycle | JIT-optimised |
| Integer division (`/`) | ~3–5 cycles | Division is slow; modulo is similar |
| `&&` / `\|\|` short-circuit | Varies | Right side skipped if result known |
| `?.` null-conditional | ~1–2 cycles | Compiled to a null check + conditional |
| `==` on string | O(n) | Compares character by character |
| `==` on custom class | O(1) | Reference check only (unless overridden) |
| Operator overload call | Same as method | No overhead vs a named method |

**Allocation behaviour:** No standard operators allocate. The exception is string `+` — each concatenation creates a new string object. In a loop, use `StringBuilder` instead.

**Benchmark notes:** The integer division silent truncation is a correctness concern more than a performance one. The real performance concern is `string` concatenation in loops and `==` on strings in tight search loops — use `StringComparison.Ordinal` and `StringBuilder` in those cases.

---

## The Code

**Arithmetic operators and integer division trap**
```csharp
int a = 10, b = 3;

Console.WriteLine(a + b);   // 13
Console.WriteLine(a - b);   // 7
Console.WriteLine(a * b);   // 30
Console.WriteLine(a / b);   // 3  — truncates toward zero, no rounding
Console.WriteLine(a % b);   // 1  — remainder (modulo)

// The trap: cast placement matters for decimal division
double wrong  = (double)(a / b); // 3.0 — cast after integer division
double correct = (double)a / b;  // 3.333... — cast before division

// Checked arithmetic: throws OverflowException instead of wrapping
int max = int.MaxValue;
int overflow = checked(max + 1); // throws OverflowException
int silent   = max + 1;          // -2147483648 — silently wraps (two's complement)
```

**Logical operators: short-circuit matters for correctness**
```csharp
// && short-circuits: if s is null, s.Length is never evaluated
bool IsValid(string? s) => s != null && s.Length > 0;

// || short-circuits: if first is true, second is skipped
bool HasAccess(User? u) => u?.IsAdmin == true || HasPermission(u, "read");

// & and | do NOT short-circuit — both sides always evaluate
// Use only when the right side has a necessary side effect (rare)
bool logAndCheck = LogAction("check") & PerformCheck(); // both always run
```

**Null-handling operators**
```csharp
string? name = GetUserName();

// ?? null-coalescing: return right side if left is null
string display = name ?? "Anonymous";

// ??= null-coalescing assignment: assign only if currently null (C# 8+)
name ??= "Guest";

// ?. null-conditional: return null instead of throwing NullReferenceException
int? length = name?.Length;
string? city = user?.Address?.City;  // chains safely

// Combining ?? with ?.
string label = user?.Profile?.DisplayName ?? user?.Name ?? "Unknown";

// ! null-forgiving: suppresses compiler warning (does NOT prevent NRE at runtime)
string definite = maybeNull!; // "I know this isn't null" — compiler trusts you
```

**Increment/decrement: prefix vs postfix**
```csharp
int i = 5;

int a = i++;   // a = 5 (original), then i becomes 6  — postfix: use THEN increment
int b = ++i;   // i becomes 7 first, then b = 7       — prefix: increment THEN use

// The subtle bug:
int x = 0;
Console.WriteLine(x++);  // prints 0 — not 1
Console.WriteLine(x);    // prints 1

// In for loops: both i++ and ++i are equivalent because the result isn't used
for (int j = 0; j < 10; j++) { }   // same as ++j — no difference here
```

**Bitwise operators for flag enums**
```csharp
[Flags]
public enum Permissions
{
    None    = 0,
    Read    = 1 << 0,  // 0001
    Write   = 1 << 1,  // 0010
    Delete  = 1 << 2,  // 0100
    Admin   = 1 << 3   // 1000
}

Permissions p = Permissions.Read | Permissions.Write;  // combine: 0011

bool canRead  = (p & Permissions.Read)   != 0;  // true  — test a flag
bool canDelete= (p & Permissions.Delete) != 0;  // false

p |= Permissions.Delete;   // add a flag
p &= ~Permissions.Write;   // remove a flag (~ is bitwise NOT)
p ^= Permissions.Read;     // toggle a flag

// Bit shift: multiply/divide by powers of 2
int x = 1 << 4;  // 16 — faster than x * 16
int y = 128 >> 2; // 32 — faster than 128 / 4
```

**Equality: `==` vs `Equals` vs `ReferenceEquals`**
```csharp
// Value types: == compares value (always)
int a = 5, b = 5;
Console.WriteLine(a == b);         // true

// String: == compares content (operator is overloaded)
string s1 = "hello", s2 = "hello";
Console.WriteLine(s1 == s2);       // true — content comparison

// Reference types (class): == compares identity by default
var list1 = new List<int> { 1, 2 };
var list2 = new List<int> { 1, 2 };
Console.WriteLine(list1 == list2);  // false — different objects, same content

// ReferenceEquals: always identity, never overridable
Console.WriteLine(ReferenceEquals(s1, s2)); // may be true (string interning)
Console.WriteLine(string.Equals(s1, s2, StringComparison.OrdinalIgnoreCase)); // true
```

---

## Real World Example

In a permissions system for a multi-tenant SaaS application, bitwise operators manage combined permissions efficiently, and null-handling operators keep the access-checking code readable without defensive null checks scattered everywhere.

```csharp
[Flags]
public enum TenantPermissions
{
    None        = 0,
    ReadData    = 1 << 0,
    WriteData   = 1 << 1,
    DeleteData  = 1 << 2,
    ManageUsers = 1 << 3,
    BillingView = 1 << 4,
    BillingEdit = 1 << 5,
    Admin       = ~0  // all bits set — every permission
}

public class AccessChecker
{
    public bool HasPermission(User? user, TenantPermissions required)
    {
        // Null-conditional + null-coalescing: if user is null, no permissions
        TenantPermissions granted = user?.Permissions ?? TenantPermissions.None;

        // Bitwise AND: all required bits must be set in granted
        return (granted & required) == required;
    }

    public TenantPermissions GrantReadWrite(TenantPermissions current)
        => current | TenantPermissions.ReadData | TenantPermissions.WriteData;

    public TenantPermissions RevokeDelete(TenantPermissions current)
        => current & ~TenantPermissions.DeleteData;

    public bool CanEditBilling(User? user)
    {
        // Chained null-conditional — readable without four nested null checks
        return user?.IsActive == true
            && user.TenantId != null
            && HasPermission(user, TenantPermissions.BillingEdit);
    }
}
```

*The key insight: `(granted & required) == required` correctly handles the case where `required` is a combination of flags — it verifies that every required bit is present, not just that any bit overlaps. This is the correct multi-flag test pattern, and it's impossible to write clearly without understanding bitwise AND.*

---

## Common Misconceptions

**"Integer division rounds — it's like `Math.Round`"**
Integer division truncates toward zero. `7 / 2` is `3`, not `4`. `(-7) / 2` is `-3`, not `-4`. There is no rounding of any kind. If you want rounding, cast to `double` first, then use `Math.Round`. The compiler does not warn about this.

**"`&&` and `&` do the same thing for booleans"**
They produce the same result when both sides are pure expressions, but `&` always evaluates both sides. `&&` stops if the left side is `false`. This matters when the right side has a side effect or could throw — `user != null && user.IsActive` is safe; `user != null & user.IsActive` throws a `NullReferenceException` when `user` is null.

**"Overloading `==` also fixes dictionary and LINQ equality"**
Overloading `==` is a compile-time operator. `Dictionary` and `HashSet` use `Equals()` and `GetHashCode()` at runtime. If you override `==` but not `Equals`/`GetHashCode`, two "equal" objects can end up in different hash buckets. Always override all three together, or use a `record` which does it for you.

---

## Gotchas

- **Integer division silently truncates — no warning, no exception.** `7 / 2` is `3`. The cast must happen *before* the division: `(double)7 / 2` = `3.5`, but `(double)(7 / 2)` = `3.0`. This is the most common numeric bug for developers coming from Python where `/` always gives a float.

- **Postfix `i++` returns the original value, not the incremented one.** `int a = i++` and `int a = ++i` both increment `i`, but `a` gets different values. In a `for` loop body this doesn't matter because the result isn't used — but in any expression where the value is consumed, it changes the result.

- **`==` on custom classes checks identity by default — not content.** Two objects with identical field values are not `==` unless you override the operator (and `Equals` and `GetHashCode`). Forgetting this in unit tests produces false-negative equality checks that are hard to debug.

- **`!` (null-forgiving) suppresses the compiler warning but does nothing at runtime.** `string definite = maybeNull!` tells the compiler "trust me, this is not null." If it actually is null, you still get a `NullReferenceException` at runtime. Use `!` only when you've actually verified the value is non-null through logic the compiler can't see.

- **Operator overloading `==` without also overloading `!=` and `Equals` breaks the equality contract.** The compiler warns you, but it's easy to dismiss. Dictionary lookups, LINQ `.Distinct()`, and unit test assertions all use `Equals`, not `==`. An inconsistency between them produces bizarre, hard-to-reproduce bugs.

---

## Interview Angle

**What they're really testing:** Precision about how basic operations actually evaluate — precedence, short-circuit behaviour, and integer arithmetic semantics.

**Common question forms:**
- "What does `7 / 2` evaluate to in C#?"
- "What's the difference between `&&` and `&`?"
- "What does `i++` return vs `++i`?"
- "Why does `==` return false for two lists with the same content?"

**The depth signal:** A junior knows `&&` is logical AND and `&` is bitwise AND. A senior explains short-circuit evaluation and *why it matters for correctness* — specifically null guards and preventing unnecessary expensive calls. On `==`, a senior explains that it's a static operator resolved at compile time against the declared type, while `Equals` is a virtual method dispatched at runtime — making them behave differently if you haven't overloaded `==` to match `Equals`. They know the equality contract: override `==`, `!=`, `Equals`, and `GetHashCode` together.

**Follow-up questions to expect:**
- "How does `??=` differ from `?? =` with a space?"
- "Can you overload `&&` on a custom type?"

---

## Related Topics

- [[dotnet/csharp/csharp-nullable-types.md]] — `??`, `?.`, and `??=` are nullable operators; their behaviour only makes sense with nullable type fundamentals
- [[dotnet/csharp/csharp-type-conversion.md]] — Integer division and cast placement are directly about type conversion semantics
- [[dotnet/csharp/csharp-value-vs-reference-types.md]] — `==` behaves differently on value vs reference types; that distinction is the root of equality operator confusion
- [[dotnet/csharp/csharp-pattern-matching.md]] — `is` with pattern variables is the modern replacement for `as`-then-null-check
- [[dotnet/csharp/csharp-enums.md]] — `[Flags]` enums are the primary use case for bitwise operators in production code

---

## Source

[C# operators and expressions — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/)

---

*Last updated: 2026-04-06*