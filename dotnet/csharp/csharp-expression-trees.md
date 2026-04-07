# C# Expression Trees

> A data structure that represents code as a tree of objects rather than compiled IL — enabling code to be inspected, transformed, and translated (e.g. to SQL) at runtime rather than executed directly as C#.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Lambda as data structure, not compiled IL |
| **Type** | `Expression<Func<T, bool>>` etc. |
| **Use when** | ORM query translation, rule engines, dynamic predicates |
| **Not for** | Async lambdas, `out`/`ref` parameters, statement lambdas with loops |
| **C# version** | C# 3.0 (.NET 3.5) |
| **Namespace** | `System.Linq.Expressions` |

---

## When To Use It

Use expression trees when you need to **inspect or translate code** rather than execute it. EF Core uses them to translate LINQ predicates to SQL. Rule engines use them to build dynamic predicates at runtime from user configuration. Libraries use them for property selectors that emit type-safe member names.

Don't use them where a compiled `Func<T>` would work — expression trees are more complex and slower to invoke (must call `Compile()` first).

---

## Core Concept

When the compiler sees a lambda assigned to `Expression<Func<T, bool>>` instead of `Func<T, bool>`, it emits code that **builds an object tree** representing the lambda, rather than compiling the lambda to IL. This tree can be walked at runtime by a provider like EF Core, which traverses the tree and generates SQL.

The same `p => p.Price > 100` syntax produces:
- `Func<Product, bool>`: compiled IL — runs as C# in memory
- `Expression<Func<Product, bool>>`: an object tree — EF Core translates to `WHERE Price > 100`

You can also build expression trees programmatically using the static methods on `Expression` — this is how dynamic predicates and compiled mappers work.

---

## The Code

**Compiler-generated vs programmatic**
```csharp
// Compiler generates the expression tree from the lambda syntax
Expression<Func<Product, bool>> expr = p => p.Price > 100;

// Examine the tree
Console.WriteLine(expr.Body);        // (p.Price > 100)
Console.WriteLine(expr.Body.NodeType); // GreaterThan
var binary = (BinaryExpression)expr.Body;
Console.WriteLine(binary.Left);      // p.Price
Console.WriteLine(binary.Right);     // 100

// Compile to executable delegate — pay the compile cost once
Func<Product, bool> compiled = expr.Compile();
bool result = compiled(new Product { Price = 150 }); // true
```

**Building expressions programmatically — dynamic predicates**
```csharp
// Build p => p.Price > threshold at runtime
static Expression<Func<Product, bool>> BuildPriceFilter(decimal threshold)
{
    ParameterExpression param   = Expression.Parameter(typeof(Product), "p");
    MemberExpression    price   = Expression.Property(param, nameof(Product.Price));
    ConstantExpression  value   = Expression.Constant(threshold, typeof(decimal));
    BinaryExpression    greaterThan = Expression.GreaterThan(price, value);

    return Expression.Lambda<Func<Product, bool>>(greaterThan, param);
}

// Use with EF Core — translated to SQL
var expr = BuildPriceFilter(100m);
var products = await dbContext.Products.Where(expr).ToListAsync();
// SQL: SELECT * FROM Products WHERE Price > 100
```

**Combining predicates — AND / OR composition**
```csharp
public static class ExpressionExtensions
{
    public static Expression<Func<T, bool>> And<T>(
        this Expression<Func<T, bool>> left,
        Expression<Func<T, bool>> right)
    {
        // Rewrite right's parameter to match left's parameter
        var param      = left.Parameters[0];
        var rightBody  = new ReplaceParameter(right.Parameters[0], param).Visit(right.Body);
        return Expression.Lambda<Func<T, bool>>(Expression.AndAlso(left.Body, rightBody), param);
    }
}

class ReplaceParameter : ExpressionVisitor
{
    private readonly ParameterExpression _from, _to;
    public ReplaceParameter(ParameterExpression from, ParameterExpression to)
        => (_from, _to) = (from, to);
    protected override Expression VisitParameter(ParameterExpression p)
        => p == _from ? _to : base.VisitParameter(p);
}

Expression<Func<Product, bool>> filter =
    ((Expression<Func<Product, bool>>)(p => p.Category == "Electronics"))
    .And(p => p.Price > 100);

// Can be passed to EF Core — translates to full WHERE clause
var results = dbContext.Products.Where(filter).ToList();
```

**Type-safe property selector — no magic strings**
```csharp
static string GetPropertyName<T>(Expression<Func<T, object>> selector)
{
    if (selector.Body is MemberExpression m) return m.Member.Name;
    if (selector.Body is UnaryExpression u && u.Operand is MemberExpression m2) return m2.Member.Name;
    throw new ArgumentException("Expression must be a property access");
}

string name = GetPropertyName<Order>(o => o.Total); // "Total" — no magic string
```

---

## Gotchas

- **Expression trees can't contain `async`/`await`, `out`/`ref` parameters, or multi-statement bodies.** Only expression lambdas (single expression, no `{ }`) compile to expression trees.
- **`Compile()` is expensive and produces non-collectible code.** Cache compiled delegates in static fields or `ConcurrentDictionary`.
- **EF Core can't translate arbitrary C# inside expressions.** Calling a custom helper method inside an EF LINQ expression throws at runtime. Only property access, arithmetic, comparisons, and `EF.Functions.*` methods are translatable.
- **`ExpressionVisitor` is the correct way to traverse and rewrite trees.** Doing it manually with pattern matching on `NodeType` is fragile and verbose.

---

## Interview Angle

**What they're really testing:** Whether you understand why EF Core can translate `Where(p => p.Price > 100)` to SQL but can't translate `Where(p => MyHelper(p))`.

**Common question forms:**
- "How does EF Core translate LINQ to SQL?"
- "What's the difference between `Func<T, bool>` and `Expression<Func<T, bool>>`?"

**The depth signal:** A senior explains that the compiler emits an object tree instead of compiled IL when it sees `Expression<Func<T, bool>>`. EF Core's `IQueryable<T>` provider traverses that tree using the Visitor pattern to build a SQL string. They know expression trees can't contain async code or multi-statement lambdas, and that compiled delegates from `Compile()` must be cached.

---

## Related Topics

- [[dotnet/csharp/csharp-linq-to-sql.md]] — EF Core uses expression trees to translate every `IQueryable` LINQ operator
- [[dotnet/csharp/csharp-delegates.md]] — `Func<T>` is the compiled alternative to `Expression<Func<T>>`
- [[dotnet/csharp/csharp-reflection.md]] — Expression trees are the performant alternative to reflection for dynamic member access

---

## Source

[Expression Trees — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/expression-trees/)

---
*Last updated: 2026-04-06*