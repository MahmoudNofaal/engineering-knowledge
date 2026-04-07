# C# Delegates

> A delegate is a type-safe function pointer — a variable that holds a reference to a method (or multiple methods) and can invoke it later, treating behaviour as data.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Type-safe method reference; can hold one or many methods (multicast) |
| **Use when** | Passing behaviour as an argument, callbacks, strategy injection |
| **Avoid when** | `Func<>` / `Action<>` already match — no need for a custom delegate type |
| **C# version** | C# 1.0 (multicast), `Func`/`Action`: C# 3.0 |
| **Namespace** | `System` |
| **Key built-ins** | `Func<T>`, `Action<T>`, `Predicate<T>` |

---

## When To Use It

Use delegates when you need to pass behaviour as an argument, store a callback for later invocation, or let callers inject logic into a method without knowing the implementation at compile time. They are the foundation of events, LINQ, and the `Func`/`Action` family.

**Don't define a custom delegate type** when `Func<>`, `Action<>`, or `Predicate<>` already match the signature — the built-in types communicate intent more clearly and require no extra declaration.

**Custom delegate types** are only justified when:
- The signature needs a name that carries domain meaning (`OrderProcessor`, `ValidationRule<T>`)
- You need `ref`/`out`/`in` parameters (built-in generics don't support them easily)
- You're implementing events and need the `EventHandler<T>` pattern specifically

---

## Core Concept

A delegate is a type that describes a method signature — its return type and parameters. Once you have a delegate type, you can create an instance of it pointing to any method matching that signature, then call it through the delegate without knowing which method is behind it.

**Multicast delegates** extend this: a single delegate instance can chain multiple methods, all called in order when you invoke it. `+=` adds a method to the chain; `-=` removes one. Events in C# are multicast delegates wrapped with `add`/`remove` access control.

**Closures** happen when a lambda captures a variable from the surrounding scope. The compiler generates a hidden class to hold the captured variables — the lambda and the captured variable share the same storage. This means the lambda sees mutations to the variable after it was captured.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Delegates, multicast, anonymous methods |
| C# 2.0 | .NET 2.0 | Anonymous methods (`delegate(int x) { return x * 2; }`) |
| C# 3.0 | .NET 3.5 | Lambda expressions, `Func<>` / `Action<>` / `Predicate<>` |
| C# 9.0 | .NET 5 | Static lambdas — `static x => x * 2` (no closure allowed) |
| C# 10.0 | .NET 6 | Natural type for lambdas — `var f = x => x * 2` works |
| C# 11.0 | .NET 7 | Method group improved inference |

*`Func<>` and `Action<>` in C# 3.0 eliminated the need to declare custom delegate types for most use cases. Before that, even a simple callback required a named `delegate` declaration.*

---

## Performance

| Scenario | Cost | Notes |
|---|---|---|
| Creating a delegate instance | 1 heap allocation | Small object — one per creation |
| Invoking a delegate | ~1–3 ns | Indirect call via function pointer |
| Multicast invocation | O(n) per subscriber | Iterates the invocation list |
| Closure allocation | 1 heap allocation per closure | Compiler-generated display class |
| Cached static lambda | 0 allocations after first use | Compiler caches non-capturing lambdas |
| `static` lambda | 0 allocations | Enforced: no capture allowed |

**Allocation behaviour:** Every new delegate instance is a heap allocation. A non-capturing lambda is cached by the compiler — it allocates once, ever. A capturing lambda creates a new display class instance each time the enclosing method runs. This matters in hot paths.

**Benchmark notes:** Delegate invocation overhead is ~1–3 ns — negligible for most code. The allocation concern is closures created in tight loops. Use `static` lambdas (C# 9+) in hot paths to guarantee no closure allocation. Cache delegate instances in `static readonly` fields for reuse.

---

## The Code

**Custom delegate type and Func/Action equivalents**
```csharp
// Custom delegate — only when the name adds semantic value
public delegate int Transform(int input);
public delegate bool OrderPredicate(Order order);

// For most cases, use built-in generic delegates
Func<int, int>       doubler   = x => x * 2;            // has return value
Action<string>       log       = msg => Console.WriteLine(msg); // void return
Predicate<string>    isEmpty   = s => s.Length == 0;    // bool return
Func<int, int, bool> compare   = (a, b) => a > b;       // multiple params

// Invoking
Console.WriteLine(doubler(5));   // 10
log("hello");
Console.WriteLine(isEmpty(""));  // true
```

**Passing a delegate as a parameter — strategy pattern**
```csharp
// Method accepts behaviour as argument — doesn't know the implementation
public int[] Filter(int[] data, Func<int, bool> predicate)
    => data.Where(predicate).ToArray();

public int[] Transform(int[] data, Func<int, int> selector)
    => data.Select(selector).ToArray();

int[] numbers = { 1, 2, 3, 4, 5, 6, 7, 8 };
int[] evens   = Filter(numbers, n => n % 2 == 0);       // [2,4,6,8]
int[] doubled = Transform(numbers, n => n * 2);          // [2,4,6,8,10,12,14,16]

// Same method, different strategy — no if/switch needed
int[] sorted     = Transform(evens, n => n);
int[] descending = evens.OrderByDescending(x => x).ToArray();
```

**Multicast delegates — chaining multiple methods**
```csharp
Action<string> pipeline = null!;
pipeline += s => Console.WriteLine(s.ToUpper());
pipeline += s => Console.WriteLine($"Length: {s.Length}");
pipeline += s => Console.WriteLine(new string('-', s.Length));

pipeline("hello");
// HELLO
// Length: 5
// -----

// Remove a method — must be the SAME delegate instance
Action<string> upper = s => Console.WriteLine(s.ToUpper());
pipeline += upper;
pipeline -= upper; // removes it — lambda must be stored to remove later
// pipeline -= s => Console.WriteLine(s.ToUpper()); // creates NEW instance — does nothing
```

**Multicast return values — only last value kept**
```csharp
Func<int> counter = null!;
counter += () => 1;
counter += () => 2;
counter += () => 3;

Console.WriteLine(counter()); // 3 — only the last return value is kept!

// To get ALL return values from multicast, use GetInvocationList
foreach (Func<int> fn in counter.GetInvocationList())
    Console.Write(fn() + " "); // 1 2 3
```

**Closures — variable capture by reference**
```csharp
// Closure captures the VARIABLE (by reference), not the value at capture time
int multiplier = 3;
Func<int, int> triple = x => x * multiplier;

Console.WriteLine(triple(4)); // 12
multiplier = 5;               // mutate the captured variable
Console.WriteLine(triple(4)); // 20 — sees the updated value

// Classic loop capture bug
var actions = new List<Action>();
for (int i = 0; i < 3; i++)
    actions.Add(() => Console.WriteLine(i)); // all capture the SAME variable i

foreach (var a in actions) a(); // prints 3, 3, 3 — not 0, 1, 2

// Fix: capture a copy inside the loop
for (int i = 0; i < 3; i++)
{
    int copy = i;               // new variable per iteration
    actions.Add(() => Console.WriteLine(copy));
}
foreach (var a in actions) a(); // prints 0, 1, 2
```

**Static lambda — prevent accidental captures (C# 9+)**
```csharp
// static: compiler enforces no capture — zero closure allocation
Func<int, int> pure = static x => x * 2;
// static x => x + multiplier; // compile error — cannot capture 'multiplier'

// In hot paths: cache the delegate to avoid repeated allocation
private static readonly Func<int, bool> IsPositive = static x => x > 0;

void ProcessItems(IEnumerable<int> items)
{
    var positives = items.Where(IsPositive); // reuses cached delegate, zero allocation
}
```

**`GetInvocationList` — resilient fan-out**
```csharp
// Default multicast: first exception stops all remaining subscribers
Action<string> pipeline = a + b + c;
pipeline("test"); // if a throws, b and c never run

// Resilient fan-out: wrap each subscriber
foreach (Action<string> subscriber in pipeline.GetInvocationList())
{
    try { subscriber("test"); }
    catch (Exception ex) { logger.LogError(ex, "Subscriber failed"); }
}
// All subscribers run even if some throw
```

---

## Real World Example

A data processing pipeline uses delegates to make each processing stage pluggable. New stages can be added without modifying the pipeline infrastructure — the pipeline is just a chain of `Func<T, T>` transforms.

```csharp
public class DataPipeline<T>
{
    private readonly List<Func<T, T>> _stages = new();
    private readonly List<Action<T, Exception>> _errorHandlers = new();

    public DataPipeline<T> AddStage(Func<T, T> stage)
    {
        _stages.Add(stage);
        return this;
    }

    public DataPipeline<T> OnError(Action<T, Exception> handler)
    {
        _errorHandlers.Add(handler);
        return this;
    }

    public T? Process(T input)
    {
        T current = input;

        foreach (var stage in _stages)
        {
            try
            {
                current = stage(current);
            }
            catch (Exception ex)
            {
                foreach (var handler in _errorHandlers)
                    handler(current, ex);
                return default;
            }
        }

        return current;
    }
}

// Build a pipeline by composing delegates
var orderPipeline = new DataPipeline<Order>()
    .AddStage(order => order with { Total = Math.Round(order.Total, 2) })
    .AddStage(order => ApplyTaxRules(order))
    .AddStage(order => ApplyDiscounts(order))
    .AddStage(order => ValidateAndEnrich(order))
    .OnError((order, ex) => logger.LogError(ex, "Failed processing order {Id}", order.Id));

Order? result = orderPipeline.Process(incomingOrder);
```

*The key insight: each pipeline stage is a `Func<Order, Order>` — a pure transform that takes an order and returns a modified order. Adding a new processing step requires no changes to `DataPipeline<T>`. Removing a step requires no changes to any other step. The stages are completely decoupled — each can be tested independently by calling it directly as a function.*

---

## Common Misconceptions

**"You can unsubscribe a lambda with `-=` without storing it"**
`pipeline -= s => Console.WriteLine(s)` creates a *new* delegate instance that does not match the one added. Nothing is unsubscribed. You must store the lambda in a variable, add that variable with `+=`, and remove the same variable with `-=`. This is the most common delegate/event subscription bug.

**"Multicast delegates call all subscribers even if one throws"**
Standard multicast invocation stops at the first unhandled exception. If the chain has three subscribers and the second throws, the third never runs. Use `GetInvocationList()` with individual try/catch blocks for resilient fan-out.

**"A non-capturing lambda creates no allocation"**
A non-capturing lambda is cached by the compiler as a static field — it allocates *once* when first used, then is reused. A capturing lambda (one that closes over a variable) creates a new display class instance every time the enclosing method runs. In hot paths, this distinction matters.

---

## Gotchas

- **Loop variable capture.** A lambda that captures a `for` loop variable captures the variable slot, not its value at the time of capture. By the time the lambdas execute, `i` has its final loop value. Fix: copy to a local variable inside the loop before capturing.

- **Multicast return values — only the last is kept.** Chaining two `Func<int>` delegates and invoking the result returns only the last return value. The others are silently discarded. Use `GetInvocationList()` to collect all return values.

- **`event` prevents direct assignment and invocation; a bare `Func` field does not.** If you expose a `public Func<string, string> Transform`, any caller can call it directly or set it to `null` (wiping all subscribers). Use `event` when external code should only subscribe and unsubscribe.

- **Delegate equality compares the target method AND the target instance.** Two delegates pointing to the same static method are equal. Two delegates pointing to the same instance method on different object instances are not equal. This affects `-=` subscription removal.

- **`delegate void MyDelegate()` and `Action` are NOT the same type.** They have the same signature, but they're different CLR types. You can't assign an `Action` to a `MyDelegate` variable directly — you need to create a new delegate instance.

---

## Interview Angle

**What they're really testing:** Whether you understand delegates as the mechanism behind events, LINQ, and callbacks — and the difference between exposing a raw delegate field versus an `event`-wrapped one.

**Common question forms:**
- "What is a delegate in C#?"
- "What's the difference between a delegate and an event?"
- "How do closures work with lambda expressions?"
- "What is a multicast delegate?"

**The depth signal:** A junior says "a delegate is a pointer to a method" and "events are special delegates." A senior explains that `event` is an access modifier on a multicast delegate that restricts external callers to `+=`/`-=` only — preventing them from invoking the delegate or replacing the entire subscription list with `=`. They know that multicast exception propagation stops at the first throw and how to work around it with `GetInvocationList`, and can explain the closure variable-capture gotcha: the lambda captures the variable binding, not the value — which is why loop-variable captures frequently surprise people.

**Follow-up questions to expect:**
- "How would you implement a pub/sub system using delegates?"
- "What is the `GetInvocationList` method and when would you use it?"
- "Why does removing a lambda with `-=` sometimes not work?"

---

## Related Topics

- [[dotnet/csharp/csharp-events.md]] — Events are multicast delegates with restricted access; delegates are the foundation
- [[dotnet/csharp/csharp-lambda.md]] — Lambda expressions are syntactic sugar for creating delegate instances; closures are the mechanism
- [[dotnet/csharp/csharp-linq-basics.md]] — LINQ is built entirely on delegates; every `Where`, `Select`, `OrderBy` takes a `Func<>` argument
- [[dotnet/csharp/csharp-expression-trees.md]] — Expression trees are the compile-time representation of a lambda as data rather than code

---

## Source

[Delegates — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/delegates/)

---

*Last updated: 2026-04-06*