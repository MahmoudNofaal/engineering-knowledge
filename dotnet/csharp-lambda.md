# C# Lambda Expressions

> A lambda is an inline anonymous function written with the `=>` syntax that can be passed as a delegate argument, stored in a variable, or compiled into an expression tree.

---

## When To Use It

Use lambdas wherever you need a short, inline piece of behaviour — LINQ queries, event handlers, `Task.Run` bodies, callback arguments, and test assertions. They eliminate the need to declare a named method for logic that is only used in one place. Do not use lambdas when the body is long enough that a named method would be clearer, or when you need recursion (a lambda cannot reference itself by name). Do not use lambdas that close over mutable shared state in concurrent code — the closure captures a reference, not a copy, which causes race conditions.

---

## Core Concept

A lambda is just a method without a name. `x => x * 2` is a function that takes `x` and returns `x * 2`. The compiler infers the parameter types from the delegate type the lambda is assigned to. If you assign it to `Func<int, int>`, `x` is an `int`. If you assign it to `Func<string, string>`, `x` is a `string`. A closure happens when the lambda body references a variable from the surrounding scope — the compiler captures that variable by reference inside a hidden compiler-generated class, which means the lambda sees future changes to the variable, not just its value at the time the lambda was created. When a lambda is assigned to an `Expression<Func<T>>` instead of a `Func<T>`, the compiler does not compile it to IL — it builds a data structure describing the expression, which is how EF Core translates `.Where(x => x.Age > 18)` into SQL.

---

## The Code
```csharp
// --- Statement lambda vs expression lambda ---
Func<int, int> expr      = x => x * 2;              // expression lambda: single expression, no braces
Func<int, int> statement = x => { return x * 2; };  // statement lambda: braces + return required

// --- Inferred types: compiler reads the delegate signature ---
Func<string, int>    length  = s => s.Length;
Func<int, int, int>  add     = (a, b) => a + b;
Action<string>       print   = msg => Console.WriteLine(msg);
Predicate<int>       isEven  = n => n % 2 == 0;

// --- Discard parameters (C# 9+) ---
Action<string, int> ignore = (_, _) => Console.WriteLine("called");

// --- Closures: lambda captures the variable reference, not the value ---
int multiplier = 3;
Func<int, int> triple = x => x * multiplier;

Console.WriteLine(triple(4)); // 12
multiplier = 5;
Console.WriteLine(triple(4)); // 20 — sees updated variable, not original 3

// --- Classic loop-capture bug ---
var actions = new List<Action>();
for (int i = 0; i < 3; i++)
{
    actions.Add(() => Console.WriteLine(i)); // all capture the SAME variable i
}
actions.ForEach(a => a()); // prints 3, 3, 3 — not 0, 1, 2

// Fix: capture a local copy
for (int i = 0; i < 3; i++)
{
    int copy = i;                              // new variable per iteration
    actions.Add(() => Console.WriteLine(copy));
}
actions.ForEach(a => a()); // 0, 1, 2

// --- Static lambda (C# 9+): prevents accidental closure over instance state ---
Func<int, int> pure = static x => x * 2; // compiler error if you reference 'this' or locals

// --- Lambda in LINQ ---
int[] nums = { 5, 3, 8, 1, 9, 2 };
int[] result = nums
    .Where(n => n > 3)
    .OrderBy(n => n)
    .Select(n => n * 10)
    .ToArray();

// --- Lambda stored as Expression<Func<T>>: data, not code ---
using System.Linq.Expressions;

Expression<Func<int, bool>> expr2 = x => x > 5;

// Compile it to a real delegate at runtime
Func<int, bool> compiled = expr2.Compile();
Console.WriteLine(compiled(7)); // true

// Inspect the tree
var binary = (BinaryExpression)expr2.Body;
Console.WriteLine(binary.NodeType);  // GreaterThan
Console.WriteLine(binary.Right);     // 5

// --- Recursive lambda: requires a local variable declaration ---
Func<int, int>? factorial = null;
factorial = n => n <= 1 ? 1 : n * factorial!(n - 1); // null-forgiving needed
Console.WriteLine(factorial(5)); // 120
```

---

## Gotchas

- **Loop variable capture is the most common lambda bug.** Closures capture the variable binding — a reference to the storage slot — not the value at the moment of creation. In a `for` loop, every lambda captures the same `i` variable, so they all print the final value of `i` when invoked. The fix is always to copy the loop variable to a new local inside the loop before capturing it.
- **`static` lambdas were added in C# 9 specifically to prevent accidental closures.** If you write `static x => x + _offset` and `_offset` is an instance field, the compiler refuses to compile. This is a useful tool in hot paths where allocating a closure object on every call is measurable overhead — but it only helps if you remember to use it.
- **Every closure that captures a variable causes a heap allocation.** The compiler generates a hidden class (a "display class") to hold the captured variables. In tight loops or high-throughput code, closures that look free are allocating on every iteration. Caching the delegate in a `static readonly` field eliminates the allocation when the lambda captures nothing.
- **`Expression<Func<T>>` and `Func<T>` look identical at the call site but are fundamentally different types.** A `Func<T>` is compiled IL that executes. An `Expression<Func<T>>` is an object tree describing the code. Passing a lambda to a method that takes `Expression<Func<T>>` (like EF Core's `Where`) means the lambda is never directly executed — it is translated. If you accidentally accept `Func<T>` in a repository method that should accept `Expression<Func<T>>`, EF Core will load the entire table into memory and filter client-side.
- **`null` delegate invocation throws `NullReferenceException`, not a meaningful error.** A `Func<int, int>` variable that was never assigned is `null`. Calling it throws `NullReferenceException` with no indication that the delegate was the problem. Always initialise delegate variables or null-check before invoking.

---

## Interview Angle

**What they're really testing:** Whether you understand closure semantics — specifically variable capture by reference — and can distinguish a compiled delegate from an expression tree.

**Common question form:** "What is a closure?" or "Why do all these lambdas in a loop print the same value?" or "What's the difference between `Func<T>` and `Expression<Func<T>>`?"

**The depth signal:** A junior says "a lambda is a shorthand for a method" and "a closure captures variables from the outer scope." A senior explains *how* capture works — the compiler generates a display class that holds the captured variable by reference, which is why mutating the variable after the lambda is created affects what the lambda sees; demonstrates the loop-capture bug and the local-copy fix; explains that `Expression<Func<T>>` is a parse tree the compiler emits instead of IL, which is how ORMs translate LINQ to SQL — and that accidentally using `Func<T>` where `Expression<Func<T>>` is needed causes a silent full-table scan.

---

## Related Topics

- [[dotnet/csharp-delegates.md]] — Lambdas are syntactic sugar for creating delegate instances; understanding delegate types, multicast, and `Func`/`Action` is the prerequisite.
- [[dotnet/csharp-linq.md]] — Every LINQ operator takes a lambda; the difference between `IQueryable` (uses `Expression`) and `IEnumerable` (uses `Func`) is the most important consequence of the `Func` vs `Expression` distinction.
- [[dotnet/csharp-expression-trees.md]] — `Expression<Func<T>>` builds a tree the compiler refuses to execute as IL; understanding expression trees explains how EF Core, AutoMapper, and dynamic proxies work.
- [[dotnet/csharp-task-parallel-library.md]] — `Task.Run`, `Parallel.For`, and PLINQ all accept lambdas; the closure-over-mutable-state gotcha is especially dangerous here because the race is non-deterministic.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/lambda-expressions](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/lambda-expressions)

---
*Last updated: 2026-03-23*