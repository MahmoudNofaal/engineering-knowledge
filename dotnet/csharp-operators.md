# C# Operators

> Symbols that perform operations on values — arithmetic, comparison, logical, bitwise, null-handling, and more — with defined precedence rules that control evaluation order.

---

## When To Use It
Operators are in every line of real code, so the question isn't whether to use them but which ones to reach for. The decisions that actually matter in practice: prefer `??` and `?.` over manual null checks for cleaner null-handling; know when bitwise operators (`&`, `|`, `^`, `<<`) are appropriate for flags and masks rather than using collections; understand short-circuit evaluation (`&&`, `||`) because it affects both performance and correctness. The operators that cause the most bugs are the ones people use without thinking — `==` on reference types, integer division, and `++`/`--` placement.

---

## Core Concept
An operator takes one or two values (operands), does something to them, and produces a result. Most are straightforward. The parts that trip people up are: operator precedence (does `2 + 3 * 4` evaluate left-to-right or multiply first?), the difference between `==` on value types vs reference types, integer vs floating-point division, and the null-related operators (`?.`, `??`, `??=`) which are C#-specific and do a lot of heavy lifting in modern code. Operators can also be overloaded on custom types, which is powerful for domain types like `Money` or `Vector` but dangerous if overused — overloading `+` to mean something non-additive is a maintenance trap.

---

## The Code

**Arithmetic operators and integer division trap**
```csharp
int a = 10, b = 3;

Console.WriteLine(a + b);   // 13
Console.WriteLine(a - b);   // 7
Console.WriteLine(a * b);   // 30
Console.WriteLine(a / b);   // 3  — integer division truncates, not rounds
Console.WriteLine(a % b);   // 1  — modulo (remainder)

// To get decimal division, cast first
double result = (double)a / b;   // 3.333...
double wrong  = (double)(a / b); // 3.0 — cast happens after integer division
```

**Comparison and equality operators**
```csharp
int x = 5;
Console.WriteLine(x == 5);   // true
Console.WriteLine(x != 3);   // true
Console.WriteLine(x > 3);    // true
Console.WriteLine(x >= 5);   // true
Console.WriteLine(x < 10);   // true

// Reference type equality: == checks value for string (overloaded),
// but checks reference identity for custom classes by default
var list1 = new List<int> { 1, 2 };
var list2 = new List<int> { 1, 2 };
Console.WriteLine(list1 == list2);  // false — different objects
```

**Logical operators: short-circuit evaluation matters**
```csharp
bool IsValid(string? s) => s != null && s.Length > 0;
// If s is null, s.Length is never evaluated — && short-circuits on first false

bool HasAccess(User? u) => u?.IsAdmin == true || u?.HasPermission("read") == true;
// || short-circuits: if first is true, second is never evaluated

// Non-short-circuit versions (evaluate both sides always):
bool both = true & false;    // evaluates right side even though left is false
bool either = false | true;  // same — both sides always evaluated
// Use & and | only when the right side has a necessary side effect (rare)
```

**Null-handling operators**
```csharp
string? name = null;

// Null-coalescing: return right side if left is null
string display = name ?? "anonymous";       // "anonymous"

// Null-coalescing assignment: assign only if currently null
name ??= "default";                          // name is now "default"

// Null-conditional: return null instead of throwing NullReferenceException
int? length = name?.Length;                  // null if name is null
string? upper = name?.ToUpper();

// Chaining null-conditional operators
string? city = user?.Address?.City;         // null if user or Address is null
int? zip = user?.Address?.PostalCode?.Length;

// Combining with ??
string city = user?.Address?.City ?? "Unknown";
```

**Bitwise operators: flags and masks**
```csharp
[Flags]
public enum Permissions
{
    None    = 0,
    Read    = 1,      // 0001
    Write   = 2,      // 0010
    Delete  = 4,      // 0100
    Admin   = 8       // 1000
}

Permissions p = Permissions.Read | Permissions.Write;   // 0011 = 3

bool canRead  = (p & Permissions.Read)  != 0;  // true
bool canDelete= (p & Permissions.Delete)!= 0;  // false

p |= Permissions.Delete;   // add Delete flag
p &= ~Permissions.Write;   // remove Write flag
p ^= Permissions.Read;     // toggle Read flag

// Bit shifts
int flags = 1;
int shifted = flags << 3;   // 8  — shift left 3 positions (multiply by 2^3)
int back    = shifted >> 2; // 2  — shift right 2 positions (divide by 2^2)
```

**Increment/decrement: prefix vs postfix**
```csharp
int i = 5;

int a = i++;   // a = 5, then i becomes 6  (postfix: use then increment)
int b = ++i;   // i becomes 7, then b = 7  (prefix: increment then use)

// The bug version — people expect both to give the same result:
int x = 0;
Console.WriteLine(x++);  // prints 0 — not 1
Console.WriteLine(x);    // prints 1
```

**Conditional (ternary) operator**
```csharp
int score = 75;
string grade = score >= 90 ? "A" : score >= 70 ? "B" : "C";  // "B"

// Avoid chaining more than two levels — use switch expression instead
string label = score switch
{
    >= 90 => "A",
    >= 70 => "B",
    >= 50 => "C",
    _     => "F"
};
```

**Operator overloading on a custom type**
```csharp
public readonly struct Money
{
    public decimal Amount { get; }
    public string Currency { get; }

    public Money(decimal amount, string currency)
    {
        Amount = amount;
        Currency = currency;
    }

    public static Money operator +(Money a, Money b)
    {
        if (a.Currency != b.Currency)
            throw new InvalidOperationException("Currency mismatch");
        return new Money(a.Amount + b.Amount, a.Currency);
    }

    public static bool operator ==(Money a, Money b)
        => a.Amount == b.Amount && a.Currency == b.Currency;

    public static bool operator !=(Money a, Money b) => !(a == b);
}

var price = new Money(9.99m, "USD");
var tax   = new Money(0.80m, "USD");
var total = price + tax;   // Money(10.79, "USD")
```

---

## Gotchas

- **Integer division silently truncates — no warning, no exception.** `7 / 2` is `3`, not `3.5`. The cast must happen *before* the division: `(double)7 / 2` gives `3.5`, but `(double)(7 / 2)` gives `3.0`. This is the most common numeric bug in C# for people coming from Python where `/` always gives a float.
- **`&&` and `||` short-circuit; `&` and `|` do not.** This matters when the right operand has a side effect or an expensive call. `userList != null && userList.Count > 0` is correct; flipping to `&` evaluates `userList.Count` even when `userList` is null and throws. Most of the time you want `&&`/`||`.
- **`==` on custom classes checks reference identity by default, not content.** Two objects with identical field values are not `==` unless you override the operator (and `Equals` and `GetHashCode`). Forgetting this when comparing DTOs or entity objects is a common source of broken equality checks in unit tests and LINQ queries.
- **Postfix `i++` returns the original value, prefix `++i` returns the incremented value.** In simple `for` loops it makes no difference. It matters the moment you assign the result: `int a = i++` and `int a = ++i` produce different values for `a`. The confusion is that both increment `i` — the difference is only in what the expression *evaluates to*.
- **Overloading `==` without also overloading `!=` and `Equals` breaks the equality contract.** The compiler warns you, but it's easy to dismiss. If `a == b` returns true but `a.Equals(b)` returns false, you'll get bizarre behaviour in dictionaries and LINQ `.Distinct()` because they use `Equals`, not `==`.

---

## Interview Angle
**What they're really testing:** Precision about how basic operations actually evaluate — precedence, short-circuit behaviour, integer arithmetic semantics — and whether you've been bitten by these in real code.

**Common question form:** "What does `7 / 2` evaluate to in C#?" / "What's the difference between `&&` and `&`?" / "What does `i++` return vs `++i`?"

**The depth signal:** A junior knows `&&` is logical AND and `&` is bitwise AND. A senior explains short-circuit evaluation and *why it matters for correctness* — null guards, expensive calls, side effects — and can give a real example of a bug caused by accidentally using `&` instead of `&&`. On integer division, a junior knows you need to cast; a senior knows the cast placement matters (`(double)a / b` vs `(double)(a / b)`) and can explain why. On operator overloading, a senior brings up the contract: overloading `==` obligates you to override `Equals` and `GetHashCode`, and explains what breaks in collections if you don't.

---

## Related Topics
- [[dotnet/csharp-nullable-types.md]] — `??`, `?.`, and `??=` are nullable operators; their behaviour only makes sense in the context of nullable reference and value types
- [[dotnet/csharp-type-conversion.md]] — Integer division and cast placement are directly about type conversion semantics; the two topics overlap on numeric operations
- [[dotnet/csharp-value-vs-reference-types.md]] — `==` behaves differently on value types vs reference types; that distinction is the root cause of equality operator confusion
- [[dotnet/csharp-pattern-matching.md]] — Switch expressions and `is` patterns replace nested ternary operator chains in modern C#; knowing both lets you choose the cleaner option

---

## Source
[C# operators and expressions — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/)

---
*Last updated: 2026-03-23*