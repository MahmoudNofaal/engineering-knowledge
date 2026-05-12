# C# Lambda Expressions

> An inline anonymous function written with `=>` that can be passed as a delegate argument, stored in a variable, or compiled into an expression tree — replacing the need to declare a named method for single-use logic.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Inline anonymous function; compiled to a delegate or expression tree |
| **Use when** | Short, single-use logic passed to LINQ, callbacks, or method arguments |
| **Avoid when** | Logic is complex enough to deserve a name; or the same logic appears multiple times |
| **C# version** | C# 3.0 (static lambdas: C# 9.0, natural type: C# 10.0) |
| **Namespace** | N/A — language feature |
| **Compile target** | `Func<T>`/`Action<T>` (delegate) or `Expression<Func<T>>` (expression tree) |

---

## When To Use It

Use lambdas wherever you need a short, inline piece of behaviour — LINQ queries, event handlers, `Task.Run` bodies, callback arguments, and test assertions. They eliminate the need to declare a named method for logic used only in one place.

**Prefer a named method when:**
- The body is more than 2–3 lines — it deserves a name for readability
- The same logic appears at multiple call sites — avoid duplicating
- The lambda captures variables in ways that are non-obvious to readers
- You need recursion — a lambda cannot reference itself by name

**The critical distinction:** When you assign a lambda to `Func<T>`, it compiles to IL that executes. When you assign it to `Expression<Func<T>>`, the compiler builds a data structure describing the code. EF Core's `.Where(x => x.Age > 18)` uses `Expression<Func<T>>` — the lambda is *never executed as C# code* but is translated to SQL.

---

## Core Concept

A lambda is a method without a name. `x => x * 2` defines a function that takes `x` and returns `x * 2`. The compiler infers parameter types from the delegate type the lambda is assigned to. No type declaration, no method name, no `return` keyword for expression lambdas.

A **closure** happens when the lambda body references a variable from the surrounding scope. The compiler generates a hidden class (a "display class") to hold captured variables. The lambda and the surrounding code share the same variable storage — not a copy of the value. This means the lambda sees future changes to the variable.

**Static lambdas** (C# 9) prevent closures entirely. `static x => x * 2` cannot capture any variable — the compiler enforces this. Zero allocation overhead, guaranteed.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 2.0 | .NET 2.0 | Anonymous methods — `delegate(int x) { return x * 2; }` |
| C# 3.0 | .NET 3.5 | Lambda expressions — `x => x * 2` |
| C# 3.0 | .NET 3.5 | Expression trees — `Expression<Func<int, bool>>` |
| C# 5.0 | .NET 4.5 | `async` lambdas — `async (x) => await DoAsync(x)` |
| C# 9.0 | .NET 5 | `static` lambdas — prevent captures, zero allocation |
| C# 10.0 | .NET 6 | Natural type for lambdas — `var f = x => x * 2` works |
| C# 10.0 | .NET 6 | Explicit return type — `var f = int (x) => x * 2` |

*Before C# 3.0, passing inline logic required full anonymous method syntax (`delegate(int x) { ... }`). Lambdas made the syntax concise enough that LINQ became practical — LINQ's readability depends entirely on lambda syntax.*

---

## Performance

| Lambda type | Allocation | Notes |
|---|---|---|
| Non-capturing lambda | 0 after first use | Compiler caches as static field |
| Static lambda (`static x => ...`) | 0 always | Compiler enforces no capture |
| Capturing lambda (each method call) | 1 display class allocation | New instance per enclosing method invocation |
| `async` lambda | 1 state machine allocation | Same as any `async` method |
| Cached delegate (`static readonly Func<...>`) | 0 always | Reused across all calls |

**Allocation behaviour:** Non-capturing lambdas are cached by the compiler — one allocation ever. Every time a method that contains a capturing lambda is called, a new display class instance is allocated on the heap. In tight loops or high-frequency methods, this matters.

**Benchmark notes:** The allocation cost is per-enclosing-method-call, not per delegate invocation. A capturing lambda allocated once and reused is fine. The problem is lambda expressions inside frequently-called methods that re-allocate the closure on every call.

---

## The Code

**Expression lambda vs statement lambda**
```csharp
// Expression lambda: single expression, implicit return, no braces
Func<int, int> square  = x => x * x;
Func<int, bool> isEven = n => n % 2 == 0;
Action<string>  print  = msg => Console.WriteLine(msg);

// Statement lambda: multiple statements, explicit return, braces required
Func<int, int> abs = x =>
{
    if (x < 0) return -x;
    return x;
};
```

**Type inference — the compiler reads the delegate type**
```csharp
Func<string, int>    length  = s => s.Length;          // s is inferred as string
Func<int, int, bool> compare = (a, b) => a > b;        // a and b inferred as int

// Natural type for lambdas (C# 10): var works when type is unambiguous
var doubler = (int x) => x * 2;    // explicit param type needed for var inference
var greet   = (string name) => $"Hello, {name}!";

// Explicit return type (C# 10)
var parse = int (string s) => int.Parse(s);
```

**Closures — capture by reference, not value**
```csharp
int multiplier = 3;
Func<int, int> triple = x => x * multiplier;

Console.WriteLine(triple(4)); // 12
multiplier = 10;              // mutate the captured variable
Console.WriteLine(triple(4)); // 40 — lambda sees the mutation

// The loop capture bug — all closures share ONE variable i
var actions = new List<Action>();
for (int i = 0; i < 5; i++)
    actions.Add(() => Console.WriteLine(i)); // captures 'i' by reference

foreach (var a in actions) a(); // 5 5 5 5 5 — all see the final value of i

// Fix: capture a copy inside the loop body
for (int i = 0; i < 5; i++)
{
    int captured = i;         // new variable per iteration
    actions.Add(() => Console.WriteLine(captured));
}
foreach (var a in actions) a(); // 0 1 2 3 4
```

**Static lambda — prevents accidental closures (C# 9+)**
```csharp
int threshold = 500;

// Non-static: captures 'threshold' — allocates a display class every method call
var expensive = products.Where(p => p.Price > threshold).ToList();

// Static: cannot capture anything — compiler enforces, zero allocation
var cheap = products.Where(static p => p.Price > 0).ToList();
// static x => x + threshold; // compile error — cannot capture 'threshold'

// Best practice for hot paths: cache the delegate
private static readonly Func<Product, bool> IsActive = static p => p.IsActive;

void ProcessProducts(IEnumerable<Product> products)
{
    var active = products.Where(IsActive); // zero allocation — reuses cached delegate
}
```

**`Func<T>` vs `Expression<Func<T>>` — the critical distinction**
```csharp
// Func<T>: compiled IL — executes as C# code
Func<Product, bool> funcPredicate = p => p.Price > 100;
// This runs in memory:
var result1 = products.Where(funcPredicate).ToList(); // C# loop

// Expression<Func<T>>: data structure — never directly executed
Expression<Func<Product, bool>> exprPredicate = p => p.Price > 100;
// EF Core reads this tree and generates SQL:
var result2 = dbContext.Products.Where(exprPredicate).ToListAsync(); // SQL: WHERE Price > 100

// The silent performance bug: passing Func to IQueryable
// This compiles but loads ALL rows then filters in memory:
IEnumerable<Product> enumerable = dbContext.Products; // AsEnumerable implicit
var bad = enumerable.Where(funcPredicate).ToList();   // SELECT * then filter in C#!
```

**`async` lambdas**
```csharp
// async lambda returns Task
Func<string, Task<string>> fetch = async url =>
{
    using var client = new HttpClient();
    return await client.GetStringAsync(url);
};

// async Action equivalent
Func<CancellationToken, Task> worker = async ct =>
{
    await Task.Delay(1000, ct);
    Console.WriteLine("Done");
};

// async void — only for event handlers
Button.Click += async (sender, e) =>
{
    await SaveAsync();
};
// async void elsewhere swallows exceptions — use Func<Task> instead
```

**Discards in lambda parameters (C# 9+)**
```csharp
// _ discards parameters you don't need
Action<string, int> logWithIndex = (_, i) => Console.WriteLine($"Item {i}");
EventHandler handler = (_, _) => Console.WriteLine("Event fired");

// Useful in LINQ when you need the index overload but don't use the element
var indexed = items.Select((_, i) => i); // just the indices
```

---

## Real World Example

A background job processor applies retry logic using lambdas for the work unit and error handler. The lambda captures the job context (what to retry) while the infrastructure stays generic.

```csharp
public class RetryExecutor
{
    private readonly ILogger _logger;
    private readonly int _maxAttempts;
    private readonly TimeSpan _delay;

    public RetryExecutor(ILogger logger, int maxAttempts = 3, TimeSpan? delay = null)
    {
        _logger      = logger;
        _maxAttempts = maxAttempts;
        _delay       = delay ?? TimeSpan.FromSeconds(1);
    }

    public async Task<T> ExecuteAsync<T>(
        Func<CancellationToken, Task<T>> operation,
        Func<Exception, int, bool>? shouldRetry = null,
        CancellationToken ct = default)
    {
        shouldRetry ??= static (_, attempt) => attempt < 3; // default: retry transient errors

        int attempt = 0;
        while (true)
        {
            try
            {
                return await operation(ct);
            }
            catch (Exception ex) when (!ct.IsCancellationRequested)
            {
                attempt++;

                if (attempt >= _maxAttempts || !shouldRetry(ex, attempt))
                    throw;

                _logger.LogWarning(ex, "Attempt {Attempt} failed, retrying in {Delay}ms",
                    attempt, _delay.TotalMilliseconds);

                await Task.Delay(_delay, ct);
            }
        }
    }
}

// Usage — lambdas capture the specific operation context
var executor = new RetryExecutor(logger, maxAttempts: 3);

// The lambda captures 'orderId' from the calling scope
Order result = await executor.ExecuteAsync(
    operation: async ct => await orderService.GetAsync(orderId, ct),
    shouldRetry: static (ex, _) => ex is HttpRequestException or TimeoutException,
    ct);

// The static lambda for shouldRetry allocates nothing — captures no variables
// The async lambda for operation captures 'orderId' — one allocation per ExecuteAsync call
```

*The key insight: the `shouldRetry` delegate uses `static` because it doesn't need any captured context — it's a pure policy decision based only on its parameters. Zero allocation. The `operation` lambda captures `orderId` from the calling scope — one display class allocation per retry call, which is fine at this frequency. The distinction between when to use `static` vs regular lambdas is exactly this: does the lambda need anything from the outer scope?*

---

## Common Misconceptions

**"Lambdas are always allocated on the heap"**
Non-capturing lambdas are cached by the compiler as a static field — they allocate once when first used, then are reused. `static` lambdas never allocate at all. Only capturing lambdas (those that close over variables) allocate a new display class instance each time the enclosing method runs.

**"`Expression<Func<T>>` and `Func<T>` look the same at the call site — they behave the same"**
They look identical syntactically but compile to completely different things. `Func<T>` is compiled IL. `Expression<Func<T>>` is an object tree describing the lambda — it's never executed directly. Accidentally passing a `Func<T>` where an `IQueryable<T>.Where()` expects `Expression<Func<T>>` can cause EF Core to load entire tables into memory.

**"Async lambdas with `async void` are fine for background work"**
`async void` lambdas (outside of event handlers) swallow exceptions — they can never be awaited, and unhandled exceptions may crash the process silently depending on the host. For background work, use `Func<Task>` and await the result.

---

## Gotchas

- **Loop variable capture produces the final loop value.** A lambda capturing a `for` or `foreach` variable captures the variable slot, not its value at capture time. By execution time, the loop has finished and the variable holds its final value. Fix: copy to a new local inside the loop.

- **Captured variables extend the lifetime of objects they reference.** A long-lived lambda that captures a `DbContext` keeps that context alive indefinitely. If the lambda is stored in a static field or a long-lived event, the captured object is rooted and won't be GC'd.

- **Recursive lambdas require a two-step declaration.** A lambda cannot call itself by name. The workaround is: `Func<int, int>? factorial = null; factorial = n => n <= 1 ? 1 : n * factorial!(n - 1);` — but the null-forgiving `!` is required and the logic is fragile.

- **`async` lambda with `Action` parameter becomes `async void`.** `Task.Run(async () => await DoAsync())` is fine — `Task.Run` has an overload for `Func<Task>`. But `someAction?.Invoke()` where `someAction` is an `Action` that was set to an async lambda creates `async void` with all its hazards.

- **The compiler caches non-capturing lambdas per *callsite*, not per *type*.** If the same non-capturing lambda appears in two different methods, the compiler may generate two different static fields. This is an implementation detail, not a contract, but it means "zero allocation" applies at each usage site independently.

---

## Interview Angle

**What they're really testing:** Whether you understand closure semantics — specifically variable capture by reference — and can distinguish a compiled delegate from an expression tree.

**Common question forms:**
- "What is a closure and how does variable capture work?"
- "Why do lambdas in a loop all print the same value?"
- "What's the difference between `Func<T, bool>` and `Expression<Func<T, bool>>`?"
- "When does a lambda allocate memory?"

**The depth signal:** A junior says "a lambda is a shorthand for a method" and "a closure captures variables from the outer scope." A senior explains *how* capture works: the compiler generates a display class that holds the captured variable by reference, which is why mutating the variable after the lambda is created affects what the lambda sees. They demonstrate the loop-capture bug and the local-copy fix. They know `Expression<Func<T>>` is a parse tree the compiler emits instead of IL — which is how ORMs translate LINQ to SQL — and that accidentally using `Func<T>` where `Expression<Func<T>>` is needed causes a silent full-table scan.

**Follow-up questions to expect:**
- "What does `static` on a lambda do and when would you use it?"
- "What happens to memory when a lambda captures a large object?"
- "How does the compiler cache non-capturing lambdas?"

---

## Related Topics

- [[dotnet/csharp/csharp-delegates.md]] — Lambdas are syntactic sugar for creating delegate instances; delegates are the underlying type
- [[dotnet/csharp/csharp-expression-trees.md]] — `Expression<Func<T>>` is the data-structure form of a lambda; understanding it explains how EF Core works
- [[dotnet/csharp/csharp-linq-basics.md]] — Every LINQ operator takes a lambda; the readability of LINQ depends entirely on lambda syntax
- [[dotnet/csharp/csharp-async-await.md]] — `async` lambdas have the same semantics as `async` methods — state machine generation, `await` suspension points

---

## Source

[Lambda expressions — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/lambda-expressions)

---

*Last updated: 2026-04-06*