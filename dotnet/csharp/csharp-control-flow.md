# C# Control Flow

> The set of statements that decide which code runs, how many times, and under what conditions — if/else, switch expressions, loops, and the jump statements that break out of them.

---

## Quick Reference

| Construct | Use when | Key gotcha |
|---|---|---|
| `if` / `else` | 1–2 conditions | Nest max 2 levels; prefer guard clauses |
| `switch` expression | 3+ conditions on one value | Must be exhaustive or add `_` arm |
| `switch` statement | Legacy; avoid for new code | Fall-through is a compile error |
| `for` | Index needed, known count | Off-by-one errors |
| `foreach` | Iterating any `IEnumerable<T>` | Cannot modify collection mid-iteration |
| `while` | Unknown count, condition first | Infinite loop if condition never changes |
| `do-while` | Body must run at least once | Underused; perfect for retry loops |
| `break` | Exit one loop/switch level | Only exits the *nearest* loop |
| `continue` | Skip current iteration | Jumps to loop condition, not loop start |
| `return` | Exit method early (guard clause) | The main tool for reducing nesting |

---

## When To Use It

Control flow is in every non-trivial method. The real decisions:

- Use **guard clauses** (early `return` for invalid cases) to keep the happy path flat and unindented. The deepest nesting level should contain the main logic, not edge cases.
- Use **`switch` expressions** (C# 8+) over long `if/else if` chains that compute a value. They're exhaustive, concise, and the compiler warns on missing cases.
- Use **`for` loops** when you need the index or want to iterate backwards. Use **`foreach`** for everything else.
- Never use **exceptions** for expected control flow (validating user input, checking if a key exists). Use `TryParse`, `TryGetValue`, and return values instead.

---

## Core Concept

Control flow statements let you express "do this, but only if...", "repeat this until...", and "jump out of here when...". The pattern that separates clean C# from messy C# is using **guard clauses** — handling edge cases at the top of a method with an early `return`, rather than wrapping the main logic in nested `else` blocks.

The modern C# `switch` expression (C# 8+) is fundamentally different from the old `switch` statement — it's an expression that *returns a value*, participates in exhaustiveness checking, supports pattern matching, and doesn't have fall-through. It's the right tool any time you're branching to assign a value. The old `switch` statement still exists but rarely adds value over an `if/else` chain.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | `if`, `switch`, `for`, `foreach`, `while`, `do`, `break`, `continue`, `return` |
| C# 7.0 | .NET Core 1.0 | `is` type patterns in `if` conditions |
| C# 8.0 | .NET Core 3.0 | `switch` expression (value-returning, exhaustive) |
| C# 8.0 | .NET Core 3.0 | Property patterns and tuple patterns in `switch` |
| C# 9.0 | .NET 5 | `and`, `or`, `not` logical patterns |
| C# 11.0 | .NET 7 | List patterns in `switch` |

*Before C# 8.0, multi-way branching that returned a value required either a series of `if/else if` blocks or a `switch` statement with a variable assigned in each `case`. The `switch` expression replaced both patterns cleanly.*

---

## Performance

| Construct | Cost | Notes |
|---|---|---|
| `if` / `else if` | Branch prediction dependent | JIT optimises simple chains |
| `switch` on int/enum | O(1) via jump table | Compiler emits jump table for dense integer cases |
| `switch` on string | O(n) scan or hash | Compiler uses hash table for many cases |
| `foreach` on array | O(n), no allocation | JIT special-cases `T[]` |
| `foreach` on `List<T>` | O(n), no allocation | Uses `List<T>.Enumerator` struct |
| `foreach` on `IEnumerable<T>` | O(n), 1 allocation | Interface dispatch; enumerator heap-allocated |

**Allocation behaviour:** `for` and `foreach` over arrays and `List<T>` allocate nothing. `foreach` over `IEnumerable<T>` (interface) allocates a heap-based enumerator via `GetEnumerator()`. Exception-based control flow allocates the exception object and captures a stack trace — expensive compared to a simple `return false`.

**Benchmark notes:** The switch-on-int jump table optimisation means a switch over an enum with 50 cases is the same cost as a switch with 3 cases. String switches above ~5 cases use a hash table. Neither matters unless inside a loop running millions of iterations.

---

## The Code

**Guard clauses: flatten the nesting**
```csharp
// BAD: main logic buried inside else blocks
string ProcessOrder(Order? order)
{
    if (order != null)
    {
        if (order.IsValid())
        {
            if (!order.IsCancelled)
            {
                return $"Processing {order.Id}"; // happy path at level 3
            }
            else return "Cancelled";
        }
        else return "Invalid";
    }
    else return "No order";
}

// GOOD: guard clauses first, happy path unindented
string ProcessOrder(Order? order)
{
    if (order == null)       return "No order";
    if (!order.IsValid())    return "Invalid";
    if (order.IsCancelled)   return "Cancelled";

    return $"Processing {order.Id}"; // happy path at level 0
}
```

**`switch` expression (C# 8+): concise, exhaustive, pattern-aware**
```csharp
// Replaces if/else chains that compute a value
int score = 72;
string grade = score switch
{
    >= 90           => "A",
    >= 70 and < 90  => "B",
    >= 50 and < 70  => "C",
    _               => "F"   // _ is the required catch-all
};

// Pattern matching on type
string Describe(object obj) => obj switch
{
    int n when n < 0    => $"negative int: {n}",
    int n               => $"positive int: {n}",
    string { Length: 0 } => "empty string",
    string s            => $"string: {s}",
    null                => "null",
    _                   => "unknown"
};

// Tuple switch: dispatch on multiple values at once
string GetShippingZone(string country, bool isPremium) => (country, isPremium) switch
{
    ("US", true)  => "US-Priority",
    ("US", false) => "US-Standard",
    ("UK", _)     => "UK",
    _             => "International"
};
```

**`for` loop: index-required scenarios**
```csharp
// Classic indexed loop
for (int i = 0; i < 10; i++)
    Console.Write(i + " ");

// Reverse iteration — safe when removing by index
for (int i = list.Count - 1; i >= 0; i--)
{
    if (list[i].IsExpired)
        list.RemoveAt(i); // safe: going backwards avoids index shift
}

// Iterate with step
for (int i = 0; i < array.Length; i += 2)
    Console.Write(array[i]); // every other element
```

**`foreach` loop: the default for iteration**
```csharp
var names = new List<string> { "Alice", "Bob", "Charlie" };

foreach (string name in names)
    Console.WriteLine(name);

// Deconstruct KeyValuePair in foreach — no .Key or .Value needed
foreach (var (key, value) in dictionary)
    Console.WriteLine($"{key}: {value}");

// With index — LINQ Select overload
foreach (var (name, index) in names.Select((n, i) => (n, i)))
    Console.WriteLine($"{index}: {name}");
```

**`while` vs `do-while`: condition timing**
```csharp
// while: condition checked BEFORE first iteration — may never run
int attempts = 0;
while (attempts < 3 && !IsConnected())
{
    attempts++;
    Thread.Sleep(1000);
}

// do-while: body runs at LEAST ONCE — condition checked after
// Perfect for user input retry loops
string input;
do
{
    Console.Write("Enter a non-empty value: ");
    input = Console.ReadLine() ?? "";
} while (string.IsNullOrWhiteSpace(input));

// Perfect for retry patterns
int retries = 0;
bool success;
do
{
    success = TryOperation();
    retries++;
} while (!success && retries < MaxRetries);
```

**Exception-as-control-flow: the anti-pattern**
```csharp
// BAD: using exceptions for expected outcomes
try
{
    int id = int.Parse(userInput);  // throws on invalid — expensive
    Process(id);
}
catch (FormatException)
{
    ShowError("Invalid input");
}

// GOOD: use TryParse — returns false, no exception allocation
if (int.TryParse(userInput, out int id))
    Process(id);
else
    ShowError("Invalid input");

// BAD: using exception to check dictionary
try
{
    var value = dict["key"]; // throws if missing
}
catch (KeyNotFoundException) { ... }

// GOOD: TryGetValue
if (dict.TryGetValue("key", out var value))
    Use(value);
```

---

## Real World Example

A payment processing service uses guard clauses and a `switch` expression to handle multiple payment outcomes cleanly, without deeply nested if/else blocks.

```csharp
public class PaymentProcessor
{
    private readonly IPaymentGateway _gateway;
    private readonly ILogger<PaymentProcessor> _logger;

    public async Task<PaymentResult> ProcessAsync(
        PaymentRequest request,
        CancellationToken ct)
    {
        // Guard clauses: handle invalid states upfront
        if (request == null)
            return PaymentResult.Failed("Request cannot be null");

        if (request.Amount <= 0)
            return PaymentResult.Failed("Amount must be positive");

        if (string.IsNullOrWhiteSpace(request.Currency))
            return PaymentResult.Failed("Currency is required");

        if (!SupportedCurrencies.Contains(request.Currency))
            return PaymentResult.Failed($"Currency {request.Currency} not supported");

        // Happy path starts here — no nesting
        GatewayResponse response;
        try
        {
            response = await _gateway.ChargeAsync(request, ct);
        }
        catch (GatewayTimeoutException ex)
        {
            _logger.LogWarning(ex, "Gateway timeout for {Amount} {Currency}",
                request.Amount, request.Currency);
            return PaymentResult.Failed("Payment gateway timed out");
        }

        // switch expression: map gateway status to domain result
        return response.Status switch
        {
            GatewayStatus.Success         => PaymentResult.Success(response.TransactionId),
            GatewayStatus.InsufficientFunds => PaymentResult.Failed("Insufficient funds"),
            GatewayStatus.CardDeclined    => PaymentResult.Failed("Card declined"),
            GatewayStatus.FraudSuspected  => PaymentResult.Failed("Transaction blocked"),
            GatewayStatus.Pending         => PaymentResult.Pending(response.TransactionId),
            _                             => PaymentResult.Failed($"Unknown status: {response.Status}")
        };
    }
}
```

*The key insight: the guard clauses at the top mean every line of the happy path is at the same indentation level. Adding a new validation rule means adding one line, not another nested block. The `switch` expression at the end makes every `GatewayStatus` case visible and forces a compiler warning if `GatewayStatus` gains a new value.*

---

## Common Misconceptions

**"Fall-through in `switch` statements works like C or Java"**
C# `switch` statements do not allow fall-through between non-empty cases. Each case must end with `break`, `return`, `throw`, or `goto case`. The only legal "fall-through" is stacking multiple `case` labels with no body between them (`case "a": case "b": DoThing(); break;`). This is a deliberate departure from C/Java that prevents a whole class of bugs.

**"`break` exits all nested loops"**
`break` exits only the *nearest* enclosing loop or switch. If you have a nested loop and want to break out of both, options are: extract the inner loop to a method and use `return`, use a bool flag, or use `goto` (which actually works here but is a maintenance problem). There's no `break 2` like in some other languages.

**"`switch` expressions and `switch` statements are interchangeable"**
They're different features. A `switch` statement executes code blocks and assigns values via side effects. A `switch` expression *is* a value — you can use it directly in an assignment, as a method argument, or in a `return`. The expression form also enforces exhaustiveness (the compiler warns if a case is missing) in ways the statement form doesn't.

---

## Gotchas

- **Fall-through in `switch` statements is a compile error in C# — not just a warning.** Unlike C/Java, forgetting `break` will not compile. The only exception is empty cases (`case "a": case "b":` sharing one body). This is a feature, not a limitation.

- **Modifying a collection inside `foreach` throws `InvalidOperationException` at runtime.** The enumerator checks a version counter on the collection. Any `Add`, `Remove`, or `Clear` during iteration increments the version and the enumerator throws. Fix: build a removal list, then remove after; or iterate a `for` loop backwards; or use `RemoveAll` with a predicate.

- **`switch` expressions must be exhaustive — the compiler warns, but the runtime throws.** If no arm matches at runtime, `SwitchExpressionException` is thrown. Forgetting `_` on a non-sealed type or a non-exhaustive enum is the common cause. Production code should always have a `_` arm or a clearly documented reason for omitting it.

- **`break` only exits one level.** Inside a nested loop, `break` exits the inner loop, not the outer one. If you need to break out of multiple levels, the idiomatic C# approach is to extract the inner loop to a method and use `return`.

- **`do-while` is chronically underused, leading to awkward `while (true)` loops.** People write `while (true) { ...; if (done) break; }` when `do { ...; } while (!done)` is cleaner and semantically accurate. The distinction — body always runs at least once — is exactly the retry/prompt pattern that `do-while` was designed for.

---

## Interview Angle

**What they're really testing:** Code structure judgment — do you write flat, readable control flow or deeply nested conditions? Do you use the right construct for each situation?

**Common question forms:**
- "How would you refactor this nested if/else chain?"
- "What's the difference between `while` and `do-while`?"
- "When would you use a `switch` expression over `if/else`?"
- "Why is using exceptions for control flow a bad practice?"

**The depth signal:** A junior knows all the syntax and uses every construct correctly. A senior uses guard clauses reflexively to reduce nesting, reaches for `switch` expressions over long `if/else if` chains that return a value, knows the `foreach`-modification trap and works around it without thinking, and will immediately flag exception-as-control-flow as a correctness and performance problem — explaining that exceptions capture a stack trace on allocation, making them 10–100× more expensive than a simple `return false`.

**Follow-up questions to expect:**
- "What does `RemoveAll` do and how does it differ from modifying during `foreach`?"
- "How does the `switch` expression exhaustiveness check work?"

---

## Related Topics

- [[dotnet/csharp/csharp-pattern-matching.md]] — `switch` expressions are built on pattern matching; the two topics are inseparable in modern C#
- [[dotnet/csharp/csharp-operators.md]] — Logical operators (`&&`, `||`, `?:`) are the building blocks of conditions in `if`/`switch`/`while`; short-circuit behaviour affects control flow correctness
- [[dotnet/csharp/csharp-linq-basics.md]] — LINQ's `Where`, `First`, `Any` replace many `foreach`-with-if patterns at a higher abstraction level
- [[dotnet/csharp/csharp-iterators.md]] — `yield return` is the mechanism behind lazy sequences that `foreach` consumes

---

## Source

[Selection and iteration statements — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/statements/selection-statements)

---

*Last updated: 2026-04-06*