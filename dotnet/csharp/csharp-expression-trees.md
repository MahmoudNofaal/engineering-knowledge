# C# Expression Trees

> An expression tree is a data structure that represents code as inspectable, traversable objects at runtime — the lambda is stored as a syntax tree, not compiled to executable IL.

---

## When To Use It

Use expression trees when you need to translate code into something other than execution — SQL queries, MongoDB filters, dynamic property access, AutoMapper projections, or any framework that needs to know *what* the code says, not just *what it does*. EF Core, LINQ to SQL, and most ORMs depend entirely on expression trees to convert `.Where(x => x.Age > 18)` into `WHERE Age > 18`. Do not use them for logic you simply want to execute — compile the expression and call `Invoke`, but at that point a plain delegate is cleaner. Expression trees have significant compile overhead and are not appropriate for hot-path runtime code generation without caching.

---

## Core Concept

When you write `Func<int, bool> f = x => x > 5`, the compiler turns the lambda into IL bytecode — real executable code. When you write `Expression<Func<int, bool>> e = x => x > 5`, the compiler does something different: it emits code that *builds a tree of objects* describing the lambda. The tree has nodes: a `ParameterExpression` for `x`, a `ConstantExpression` for `5`, and a `BinaryExpression` of type `GreaterThan` connecting them. Nothing executes — the tree just sits there as data. You can walk it, inspect it, transform it, or send it to a library that translates it into SQL or some other query language. EF Core's `.Where()` accepts `Expression<Func<T, bool>>` precisely for this reason — it reads the tree and generates a SQL `WHERE` clause. If you pass it a plain `Func<T, bool>`, EF Core has no tree to read, silently loads the whole table, and filters in memory.

---

## The Code
```csharp
// --- Compiler-built tree: inspect what the lambda says ---
using System.Linq.Expressions;

Expression<Func<int, bool>> expr = x => x > 5;

var binary  = (BinaryExpression)expr.Body;
var param   = (ParameterExpression)binary.Left;
var constant = (ConstantExpression)binary.Right;

Console.WriteLine(binary.NodeType);   // GreaterThan
Console.WriteLine(param.Name);        // x
Console.WriteLine(constant.Value);    // 5

// Compile and execute the tree as a real delegate
Func<int, bool> compiled = expr.Compile();
Console.WriteLine(compiled(7));  // True
Console.WriteLine(compiled(3));  // False

// --- Build a tree manually at runtime ---
// Equivalent to: x => x * 2 + 1
ParameterExpression p    = Expression.Parameter(typeof(int), "x");
BinaryExpression    mult = Expression.Multiply(p, Expression.Constant(2));
BinaryExpression    add  = Expression.Add(mult, Expression.Constant(1));
Expression<Func<int, int>> built = Expression.Lambda<Func<int, int>>(add, p);

Func<int, int> run = built.Compile();
Console.WriteLine(run(5));  // 11

// --- Dynamic property accessor: build a getter at runtime and cache it ---
// Useful when the property name is only known at runtime (e.g. from config or reflection)
public static Func<T, object> BuildGetter<T>(string propertyName)
{
    ParameterExpression param    = Expression.Parameter(typeof(T), "obj");
    MemberExpression    property = Expression.Property(param, propertyName);
    UnaryExpression     boxed    = Expression.Convert(property, typeof(object)); // box value types
    return Expression.Lambda<Func<T, object>>(boxed, param).Compile();
}

var getAge = BuildGetter<Person>("Age");
Console.WriteLine(getAge(new Person { Age = 30 })); // 30

// Cache the compiled delegate — Compile() is expensive, never call it in a loop
static readonly ConcurrentDictionary<string, Func<Person, object>> _cache = new();
Func<Person, object> getter = _cache.GetOrAdd("Age", BuildGetter<Person>);

// --- ExpressionVisitor: rewrite a tree ---
// Classic use: replace one parameter expression with another (query composition)
public class ParameterReplacer : ExpressionVisitor
{
    private readonly ParameterExpression _target;
    private readonly Expression          _replacement;

    public ParameterReplacer(ParameterExpression target, Expression replacement)
        => (_target, _replacement) = (target, replacement);

    protected override Expression VisitParameter(ParameterExpression node)
        => node == _target ? _replacement : base.VisitParameter(node);
}

// Combine two predicates: (x => x > 3) AND (x => x < 10) → one expression
Expression<Func<int, bool>> left  = x => x > 3;
Expression<Func<int, bool>> right = x => x < 10;

// Replace 'x' in 'right' with 'x' from 'left' so they share one parameter
var replacer  = new ParameterReplacer(right.Parameters[0], left.Parameters[0]);
Expression    merged = Expression.AndAlso(left.Body, replacer.Visit(right.Body));
var combined  = Expression.Lambda<Func<int, bool>>(merged, left.Parameters[0]);

Console.WriteLine(combined.Compile()(5));  // True  (5 > 3 && 5 < 10)
Console.WriteLine(combined.Compile()(11)); // False (11 > 3 but not < 10)

// --- EF Core: the right and wrong delegate type ---
// RIGHT: EF Core reads the tree and generates SQL WHERE clause
IQueryable<Order> query = db.Orders.Where(o => o.Total > 100);

// WRONG: EF Core gets a Func, cannot translate, loads entire table into memory
IEnumerable<Order> bad = db.Orders.AsEnumerable().Where(o => o.Total > 100);
```

---

## Gotchas

- **`Expression.Compile()` is expensive and must be cached.** Compiling an expression tree involves JIT compilation and typically takes hundreds of microseconds. Calling it inside a loop or per-request is a significant performance regression. Always store compiled delegates in a `static readonly` field or a `ConcurrentDictionary` keyed on whatever varies at runtime.
- **Passing `Func<T, bool>` where `Expression<Func<T, bool>>` is expected silently switches EF Core to client-side evaluation.** The method signature looks the same at the call site. EF Core 3+ throws an exception for untranslatable expressions by default, but only for top-level projections — nested `Func` lambdas in `.Select()` can still silently load data. Always verify generated SQL with `.ToQueryString()` or SQL logging.
- **Not all C# constructs can appear in an expression tree.** You cannot use `await`, `throw`, multi-statement lambdas, `dynamic`, or most statement blocks. The compiler rejects them at compile time with `"An expression tree may not contain..."`. If your lambda needs any of these, you cannot use it as an `Expression<Func<T>>` — only as a compiled `Func<T>`.
- **Combining two expressions requires parameter replacement, not just `AndAlso`.** If you naively write `Expression.AndAlso(left.Body, right.Body)`, the two trees have different `ParameterExpression` instances even if both parameters are named `x`. EF Core and LINQ providers treat different instances as different variables and throw at translation time. You must use an `ExpressionVisitor` to replace one parameter with the other before combining.
- **`Expression<Func<T>>` cannot represent overloaded operators on custom types without explicit `Expression.Call`.** Writing `x => x.Money + x.Tax` works fine for primitive types, but for a custom `Money` struct with an overloaded `+`, the compiler may fail to build the expression or build it in a way the provider cannot translate. Use `Expression.Add` with the `MethodInfo` overload to specify the exact method explicitly.

---

## Interview Angle

**What they're really testing:** Whether you understand what ORMs are actually doing with LINQ, and can distinguish a delegate (code) from an expression tree (data representing code).

**Common question form:** "How does EF Core translate LINQ to SQL?" or "What's the difference between `Func<T, bool>` and `Expression<Func<T, bool>>`?" or "How would you build a dynamic query filter at runtime?"

**The depth signal:** A junior says "EF Core uses LINQ and expressions to generate SQL." A senior explains that `Expression<Func<T>>` is a data structure the compiler emits at compile time — not IL — that EF Core walks node-by-node to produce SQL; that accidentally using `Func<T>` instead silently causes a full table scan because the provider has no tree to translate; that `Compile()` must be cached because it invokes the JIT; and that combining predicates at runtime requires `ExpressionVisitor` to unify `ParameterExpression` instances — a concrete, non-obvious step that separates someone who has actually built dynamic query infrastructure from someone who has only read about it.

---

## Related Topics

- [[dotnet/csharp-lambda.md]] — Expression trees and lambdas share syntax but compile to entirely different things; the distinction is the root of the EF Core client-vs-server evaluation problem.
- [[dotnet/csharp-linq.md]] — `IQueryable<T>` relies on expression trees for translation; `IEnumerable<T>` uses compiled delegates — knowing which is which prevents silent full-table scans.
- [[dotnet/csharp-delegates.md]] — Delegates are the compiled executable form of a lambda; expression trees are the inspectable data form; understanding both shows you the full picture.
- [[databases/ef-core-query-pipeline.md]] — EF Core's query pipeline walks the expression tree, applies visitor rewrites, and maps nodes to SQL AST nodes; expression trees are the entry point to everything it does.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/expression-trees/](https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/expression-trees/)

---
*Last updated: 2026-03-23*