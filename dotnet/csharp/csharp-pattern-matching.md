# C# Pattern Matching

> Pattern matching lets you test a value's shape, type, or content and extract parts of it in a single expression — replacing cascading if/else casts and multi-field null checks.

---

## Quick Reference

| Pattern | Syntax | Use for |
|---|---|---|
| Type | `is string s` | Check type and bind variable |
| Constant | `is 42` / `is "hello"` | Check exact value |
| Null / Not null | `is null` / `is not null` | Idiomatic null checks |
| Property | `is { Name: "Alice" }` | Check property values |
| Positional | `is (1, 2)` | Deconstruct and check |
| Relational | `is > 0 and < 100` | Compare values |
| Logical | `and`, `or`, `not` | Combine patterns |
| List | `is [var first, ..]` | Match sequence shape |
| Var | `is var x` | Always matches, binds value |
| Discard | `_` | Match-all default arm |

---

## When To Use It

Use pattern matching when you need to branch on an object's type, structure, or value — replacing long `if`/`else if` chains, `is`/`as` casts, and multi-field null checks with concise, readable expressions.

It excels for:
- **Type hierarchies**: processing a sealed hierarchy of records without `if (x is Dog d)` chains
- **State machines**: tuple switch on `(currentState, event)` pairs
- **Null-safe property access**: `is { Address.City: "London" }` as a single readable expression
- **Data validation**: relational and logical patterns for range checks

Don't use it when a simple `if` is clearer, or when each arm contains significant logic that belongs in a method — the switch becomes unreadable past ~6 arms.

---

## Core Concept

Before C# 7, checking a type meant `is` followed by a separate cast, or `as` followed by a null check — three lines for what should be one. Pattern matching collapses test and extraction into one step: `if (shape is Circle c)` tests the type and binds `c` in the same expression.

The `switch` expression (C# 8) extends this into exhaustive, value-returning branching. For **sealed hierarchies**, the compiler tracks which subtypes exist and warns when a new subtype is added but the switch doesn't handle it — something `if/else` chains can never provide.

Patterns are composable: `is > 0 and < 100 and not 42` is a single expression that combines three checks. Property patterns (`is { Name: "Alice", Age: > 18 }`) let you match on nested structure without temporary variables.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 7.0 | .NET Core 1.0 | Type patterns with variable binding (`is T x`), `when` guards |
| C# 8.0 | .NET Core 3.0 | `switch` expression, property patterns, tuple patterns |
| C# 8.0 | .NET Core 3.0 | Positional patterns via `Deconstruct` |
| C# 9.0 | .NET 5 | Relational (`> 0`), logical (`and`, `or`, `not`) patterns |
| C# 10.0 | .NET 6 | Extended property patterns (`{ Address.City: "X" }`) |
| C# 11.0 | .NET 7 | List patterns (`[var first, .., var last]`) |

*Before C# 8's switch expression, multi-way type dispatch required a switch statement with `case` arms and separate variable declarations. The expression form returns a value directly and is exhaustiveness-checked.*

---

## Performance

| Pattern | Compile-to | Cost |
|---|---|---|
| Type pattern (`is Dog d`) | `isinst` + null check | O(1) — one type check |
| Property pattern | Null check + property reads | O(n properties) |
| Switch expression on int | Jump table (dense) | O(1) |
| Switch expression on string | Hash table (many arms) | O(1) average |
| Relational patterns | Comparisons | O(1) per comparison |

**Allocation behaviour:** Pattern matching allocates nothing. Variable binding (`is Dog d`) does not allocate — it just casts the reference. The matched value itself was already allocated.

**Benchmark notes:** Pattern matching compiles to the same IL as manual `if`/`else if` chains with `is`/`as`. The performance is identical — the benefit is correctness (exhaustiveness checking) and readability, not speed.

---

## The Code

**Type pattern — test and bind in one step**
```csharp
object obj = "hello";

// Old way: two steps
if (obj is string)
{
    string s = (string)obj;    // separate cast
    Console.WriteLine(s.ToUpper());
}

// Pattern matching: one step
if (obj is string s)
    Console.WriteLine(s.ToUpper()); // s is already string here
```

**Switch expression — sealed hierarchy with exhaustiveness checking**
```csharp
// Sealed hierarchy: compiler checks all subtypes are handled
public abstract record Shape;
public sealed record Circle(double Radius)          : Shape;
public sealed record Rectangle(double W, double H)  : Shape;
public sealed record Triangle(double Base, double H) : Shape;

static double Area(Shape shape) => shape switch
{
    Circle c    => Math.PI * c.Radius * c.Radius,
    Rectangle r => r.W * r.H,
    Triangle t  => 0.5 * t.Base * t.H,
    // Compiler warning if a new sealed subtype is added without a case here
};

// With when guard: additional condition after type match
static string Classify(Shape shape) => shape switch
{
    Circle c when c.Radius > 100 => "large circle",
    Circle c                     => "small circle",
    Rectangle { W: var w, H: var h } when w == h => "square",
    Rectangle r => $"rectangle {r.W}x{r.H}",
    _           => "other shape"
};
```

**Property patterns — match on field values**
```csharp
public record Order(string Status, decimal Total, string? Region);

static string Classify(Order o) => o switch
{
    { Status: "Cancelled" }                              => "cancelled",
    { Status: "Pending", Total: > 1000 }                 => "high-value pending",
    { Status: "Pending", Region: "EU" }                  => "EU pending",
    { Status: "Pending" }                                => "normal pending",
    { Status: "Shipped" or "Delivered" }                 => "in transit or done",
    _                                                    => "unknown"
};

// Extended property patterns (C# 10): nested without intermediate variables
public record Address(string City, string Country);
public record Customer(string Name, Address Address);

static bool IsLondon(Customer c)
    => c is { Address.Country: "UK", Address.City: "London" };
```

**Relational and logical patterns (C# 9)**
```csharp
static string GradeScore(int score) => score switch
{
    >= 90                  => "A",
    >= 80 and < 90         => "B",
    >= 70 and < 80         => "C",
    >= 60 and < 70         => "D",
    not (< 0 or > 100)     => "F",  // valid score, just low
    _                      => "Invalid score"
};

// is patterns with logical operators
bool IsValidAge(int? age)
    => age is >= 18 and <= 120;

bool IsSpecialCase(string? s)
    => s is not null and not "";
```

**Positional patterns — deconstruct and check**
```csharp
public record Point(int X, int Y);

static string Quadrant(Point p) => p switch
{
    (> 0, > 0)  => "Q1",
    (< 0, > 0)  => "Q2",
    (< 0, < 0)  => "Q3",
    (> 0, < 0)  => "Q4",
    _           => "on axis"
};

// Tuple switch — state machine
static string OrderTransition(OrderStatus status, OrderEvent evt) => (status, evt) switch
{
    (OrderStatus.Pending,    OrderEvent.PaymentReceived) => "Processing",
    (OrderStatus.Processing, OrderEvent.Shipped)         => "Shipped",
    (OrderStatus.Shipped,    OrderEvent.Delivered)       => "Complete",
    (_, OrderEvent.Cancelled)                            => "Cancelled",
    _ => throw new InvalidOperationException($"Invalid: {status} + {evt}")
};
```

**List patterns (C# 11) — match on sequence shape**
```csharp
static string DescribeList(int[] nums) => nums switch
{
    []                          => "empty",
    [var only]                  => $"one element: {only}",
    [var first, var second]     => $"two elements: {first}, {second}",
    [var first, .., var last]   => $"starts {first}, ends {last}",
};

// Validate command-line args structure
static string ParseArgs(string[] args) => args switch
{
    ["--help"]                     => ShowHelp(),
    ["--version"]                  => ShowVersion(),
    ["--output", var path]         => ProcessOutput(path),
    ["--input", var src, "--output", var dst] => ProcessFiles(src, dst),
    _                              => "Unknown command. Use --help"
};
```

---

## Real World Example

An event-sourcing system processes domain events and applies them to rebuild aggregate state. Pattern matching on the event type replaces a fragile switch on type names and makes adding new event types safe — the compiler warns at every unhandled switch site.

```csharp
public abstract record OrderEvent;
public sealed record OrderPlaced(Guid OrderId, string CustomerId, DateTime At)   : OrderEvent;
public sealed record ItemAdded(Guid OrderId, int ProductId, int Qty, decimal Price) : OrderEvent;
public sealed record ItemRemoved(Guid OrderId, int ProductId)                    : OrderEvent;
public sealed record OrderShipped(Guid OrderId, string TrackingNumber, DateTime At) : OrderEvent;
public sealed record OrderCancelled(Guid OrderId, string Reason, DateTime At)   : OrderEvent;

public record OrderState(
    Guid OrderId,
    string? CustomerId,
    IReadOnlyList<OrderLine> Items,
    OrderStatus Status,
    string? TrackingNumber)
{
    // Apply event: exhaustive switch — compiler warns if OrderEvent gains a new subtype
    public OrderState Apply(OrderEvent evt) => evt switch
    {
        OrderPlaced e => this with
        {
            OrderId    = e.OrderId,
            CustomerId = e.CustomerId,
            Status     = OrderStatus.Pending
        },

        ItemAdded e => this with
        {
            Items = Items.Append(new OrderLine(e.ProductId, e.Qty, e.Price)).ToList()
        },

        ItemRemoved e => this with
        {
            Items = Items.Where(l => l.ProductId != e.ProductId).ToList()
        },

        OrderShipped e => this with
        {
            Status         = OrderStatus.Shipped,
            TrackingNumber = e.TrackingNumber
        },

        OrderCancelled { Reason: var reason } when Status == OrderStatus.Shipped
            => throw new InvalidOperationException($"Cannot cancel shipped order: {reason}"),

        OrderCancelled => this with { Status = OrderStatus.Cancelled },

        // No _ arm — if OrderEvent gains a new subtype, this is a compiler warning
    };

    public static OrderState Empty => new(
        Guid.Empty, null, Array.Empty<OrderLine>(), OrderStatus.Unknown, null);
}
```

*The key insight: the absence of a `_` discard arm in the switch means the compiler warns whenever a new `OrderEvent` subtype is added to the hierarchy. Every event handler in the codebase gets a warning at the switch site. You can never silently miss handling a new event type — the type system enforces completeness.*

---

## Common Misconceptions

**"Pattern matching on non-sealed hierarchies is exhaustive"**
The compiler only guarantees exhaustiveness warnings for `sealed` hierarchies. If your base class is `public abstract` but not `sealed`, someone can add a subtype in another assembly and your switch silently falls through to `_`. Seal the hierarchy when the set of subtypes is meant to be closed.

**"`when` guards are evaluated before the pattern matches"**
`when` guards are evaluated *after* the pattern matches and binds variables. In `case Circle c when c.Radius > 10`, `c` is bound before `when` runs. A failed `when` guard does not prevent the next arm from matching — the switch continues to the next arm.

**"Property patterns match `null` for missing properties"**
`is { Total: > 0 }` does not match if `Total` is a nullable type and its value is null — the relational comparison fails silently and falls through to the next arm. Add `is { Total: not null and > 0 }` for nullable properties.

---

## Gotchas

- **Pattern matching on open hierarchies gives no exhaustiveness guarantee.** Forgetting `_` on a non-sealed type means if no arm matches at runtime, a `switch` expression throws `SwitchExpressionException`. This is a runtime crash, not a compile error. Always add `_` unless you're certain the hierarchy is sealed and all cases are handled.

- **`when` guards: failed guards pass to the next arm, not to `_`.** Multiple arms can match the same type — the `when` guard distinguishes them. If all matching arms fail their `when` guard, the switch falls to `_`. This is intentional but can be surprising.

- **Positional patterns require a `Deconstruct` method.** If you add a new parameter to a record's primary constructor, all positional patterns for that record break at compile time. The error appears at every pattern site — potentially scattered across the codebase.

- **Extended property patterns (`{ Address.City: "X" }`) only work for non-null intermediates.** `c is { Address.City: "London" }` is false if `c.Address` is null. You need to handle the null case explicitly or use `{ Address: { City: "London" } }` which also fails on null Address.

- **Switch expression arms must be exhaustive or the compiler warns and runtime throws.** A switch expression that falls through without matching any arm throws `SwitchExpressionException`. In production, this surfaces as an unhandled exception for the exact input combination you didn't anticipate.

---

## Interview Angle

**What they're really testing:** Whether you understand pattern matching as a structural and type-safe branching mechanism — not just syntactic sugar for `if/else` — and whether you know when the compiler's exhaustiveness checking actually kicks in.

**Common question forms:**
- "How would you refactor a chain of `if (x is TypeA)` checks?"
- "What is exhaustiveness checking and when does it work?"
- "What's the difference between `when` guards and property patterns?"
- "How do list patterns work in C# 11?"

**The depth signal:** A junior replaces `if/else if` with a `switch` expression and calls it done. A senior explains that exhaustiveness checking only works on sealed hierarchies — sealing the base type is a meaningful design decision, not just style. They know property patterns compose with `and`/`or`/`not`, that `when` guards are post-match predicates (failed guard → next arm, not `_`), and that positional patterns require `Deconstruct` — so adding a field to a record breaks all pattern sites at compile time, which is a real impact on refactoring strategy.

**Follow-up questions to expect:**
- "Why does adding a field to a positional record break all existing patterns?"
- "What's the difference between `_ =>` and leaving no default arm in a switch expression?"
- "Can you use pattern matching in a LINQ `Where` clause?"

---

## Related Topics

- [[dotnet/csharp/csharp-records.md]] — Records synthesise `Deconstruct`, making positional patterns work naturally over record hierarchies
- [[dotnet/csharp/csharp-tuples.md]] — Tuple switch expressions are one of the most concise uses of both features together
- [[dotnet/csharp/csharp-switch-expression.md]] — The `switch` expression syntax; pattern matching is what makes it powerful
- [[dotnet/csharp/csharp-nullable-types.md]] — `is not null` and `is { }` are the idiomatic null checks enabled by pattern matching

---

## Source

[Patterns — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns)

---

*Last updated: 2026-04-06*