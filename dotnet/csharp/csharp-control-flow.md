# C# Control Flow

> The set of statements that decide which code runs, how many times, and under what conditions — if/else, switch, loops, and the jump statements that break out of them.

---

## When To Use It
Control flow is in every non-trivial method. The real decisions are about *which* construct fits: `if/else` for simple branching, `switch` expressions for multi-way dispatch on a value, `for`/`foreach` for iteration, `while`/`do-while` when the iteration count isn't known upfront. Avoid deeply nested `if` blocks — early returns (`guard clauses`) flatten the structure and make the happy path obvious. Don't use exceptions as control flow for expected conditions; they're expensive and semantically wrong.

---

## Core Concept
Control flow statements let you express "do this, but only if...", "repeat this until...", and "jump out of here when...". In C# the notable things are: `switch` has been significantly upgraded — the modern `switch` expression (C# 8+) is concise, exhaustive, and returns a value rather than executing statements. `foreach` works on anything that implements `IEnumerable<T>`, not just arrays. `break` exits the nearest enclosing loop or switch; `continue` skips the rest of the current iteration; `return` exits the entire method. The pattern that separates clean C# from messy C# is using guard clauses to handle edge cases at the top of a method and returning early, rather than wrapping the main logic in an `else` block.

---

## The Code

**if / else if / else**
```csharp
int score = 72;

if (score >= 90)
    Console.WriteLine("A");
else if (score >= 70)
    Console.WriteLine("B");
else if (score >= 50)
    Console.WriteLine("C");
else
    Console.WriteLine("F");

// Guard clause pattern: handle invalid cases first, keep main logic unindented
string ProcessOrder(Order? order)
{
    if (order == null)      return "No order";
    if (!order.IsValid())   return "Invalid order";
    if (order.IsCancelled)  return "Cancelled";

    // Happy path — no nesting
    return $"Processing order {order.Id}";
}
```

**switch statement (classic)**
```csharp
string day = "Monday";

switch (day)
{
    case "Saturday":
    case "Sunday":
        Console.WriteLine("Weekend");
        break;
    case "Monday":
        Console.WriteLine("Start of week");
        break;
    default:
        Console.WriteLine("Weekday");
        break;
}
```

**switch expression (C# 8+): returns a value, exhaustive**
```csharp
int score = 72;

// Replaces if/else chains that assign a value
string grade = score switch
{
    >= 90           => "A",
    >= 70           => "B",
    >= 50           => "C",
    _               => "F"    // _ is the default/discard arm
};

// Pattern matching in switch expression
string Describe(object obj) => obj switch
{
    int n when n < 0    => "negative int",
    int n               => $"int: {n}",
    string s            => $"string: {s}",
    null                => "null",
    _                   => "unknown"
};

// Tuple switch: dispatch on multiple values at once
string GetTariff(string country, bool isPremium) => (country, isPremium) switch
{
    ("US", true)    => "US-Premium",
    ("US", false)   => "US-Standard",
    ("UK", _)       => "UK",
    _               => "International"
};
```

**for loop**
```csharp
// Classic indexed loop — use when you need the index
for (int i = 0; i < 10; i++)
    Console.WriteLine(i);

// Reverse iteration — common when removing items from a list by index
for (int i = list.Count - 1; i >= 0; i--)
{
    if (list[i].IsExpired)
        list.RemoveAt(i);   // safe: iterating backwards avoids index shift
}
```

**foreach loop**
```csharp
var names = new List<string> { "Alice", "Bob", "Charlie" };

foreach (string name in names)
    Console.WriteLine(name);

// Works on any IEnumerable<T>
foreach (var (key, value) in dictionary)   // deconstruct KeyValuePair
    Console.WriteLine($"{key}: {value}");

// With index — use a for loop or LINQ Select with index
foreach (var (item, index) in names.Select((n, i) => (n, i)))
    Console.WriteLine($"{index}: {item}");
```

**while and do-while**
```csharp
// while: condition checked before first iteration — may never run
int attempts = 0;
while (attempts < 3)
{
    bool success = TryConnect();
    if (success) break;
    attempts++;
}

// do-while: body always runs at least once — condition checked after
string input;
do
{
    input = Console.ReadLine() ?? "";
} while (string.IsNullOrWhiteSpace(input));  // keep asking until non-empty
```

**break, continue, return**
```csharp
// break: exit the nearest loop or switch immediately
foreach (var item in items)
{
    if (item.IsTarget)
    {
        Process(item);
        break;   // stop searching once found
    }
}

// continue: skip the rest of this iteration, move to next
foreach (var item in items)
{
    if (item.IsDisabled) continue;   // skip disabled items
    Process(item);
}

// return early: cleaner than else-wrapping the main logic
decimal CalculateDiscount(Customer c)
{
    if (c == null)       return 0;
    if (!c.IsActive)     return 0;
    if (c.OrderCount < 5) return 0.05m;
    return 0.10m;
}
```

**Exception-based flow — what NOT to do**
```csharp
// Bad: using exceptions for expected control flow
try
{
    int id = int.Parse(userInput);   // throws if invalid — exception for flow control
    Process(id);
}
catch (FormatException)
{
    ShowError("Invalid input");
}

// Good: use TryParse — exceptions for unexpected conditions only
if (int.TryParse(userInput, out int id))
    Process(id);
else
    ShowError("Invalid input");
```

---

## Gotchas

- **Fall-through in `switch` statements is a compile error in C# (unlike C/Java).** Each `case` must have a `break`, `return`, `throw`, or `goto case`. The only legal fall-through is stacking multiple `case` labels with no code between them (`case "a": case "b":` sharing one body). This prevents a whole category of bugs, but surprises people coming from other languages.
- **Modifying a collection inside `foreach` throws `InvalidOperationException` at runtime.** The enumerator detects the structural change and throws. If you need to remove items while iterating, use a `for` loop backwards, build a removal list and call `RemoveAll`, or use LINQ to build a new collection.
- **`switch` expressions must be exhaustive — the compiler enforces it.** If no arm matches and there's no `_` discard arm, you get an `InvalidOperationException` at runtime (not compile time for all cases). The compiler warns when it can detect non-exhaustiveness statically, but it can't always. Always add a `_` arm or a `default:` branch.
- **`break` only exits one level.** Inside a nested loop, `break` exits the inner loop, not the outer one. If you need to break out of multiple levels, the idiomatic C# approach is to extract the inner loop to a method and use `return`, or use a flag variable. `goto` technically works but is a maintenance problem.
- **`do-while` is the right tool for retry loops but is chronically underused.** People write `while (true) { ... if (done) break; }` when `do { ... } while (!done)` is cleaner and expresses the intent directly. The semantic difference — body always runs at least once — is exactly the retry/prompt pattern.

---

## Interview Angle
**What they're really testing:** Code structure judgment — do you write flat, readable control flow or deeply nested conditions? Do you know which construct is semantically correct for a given situation?

**Common question form:** "How would you refactor this nested if/else chain?" / "What's the difference between `while` and `do-while`?" / "When would you use a `switch` expression over `if/else`?"

**The depth signal:** A junior knows all the syntax and can use every construct correctly. A senior uses guard clauses reflexively to reduce nesting, reaches for `switch` expressions over long `if/else if` chains that return a value, knows the `foreach`-modification trap and how to work around it, and will immediately flag exception-as-control-flow as a design problem — explaining that exceptions are for *unexpected* conditions, not for branching on predictable outcomes like invalid user input.

---

## Related Topics
- [[dotnet/csharp-pattern-matching.md]] — Switch expressions are built on pattern matching; the two topics are inseparable in modern C#
- [[dotnet/csharp-operators.md]] — Logical operators (`&&`, `||`, `?:`) are the building blocks of conditions in if/switch/while; short-circuit behaviour directly affects control flow correctness
- [[dotnet/csharp-exceptions.md]] — Understanding when *not* to use exceptions for control flow requires knowing what exceptions are for; these two topics define the boundary
- [[dotnet/csharp-linq.md]] — LINQ replaces many `foreach`-with-if patterns with declarative `.Where()`, `.Select()`, `.FirstOrDefault()`; knowing both lets you choose the right level of abstraction

---

## Source
[Selection statements and iteration statements — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/statements/selection-statements)

---
*Last updated: 2026-03-23*