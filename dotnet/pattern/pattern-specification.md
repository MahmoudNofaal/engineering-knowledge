# Specification Pattern

> A specification is a reusable, composable object that encapsulates a single business rule as a boolean test — true if an object satisfies the rule, false if it doesn't.

---

## When To Use It
Use it when the same filtering or validation rule appears in multiple places — a repository query, a domain validation, and a UI eligibility check — and you're duplicating the condition each time. It pays off when rules need to be combined (`IsActive AND IsEligibleForDiscount`), named (`PremiumCustomerSpec`), and tested in isolation. Don't use it for one-off queries that live in a single repository method — the abstraction adds indirection without benefit when a condition is only ever used once.

---

## Core Concept
The problem it solves is scattered business logic. Without it, the rule "a customer is premium if they've spent over $1000 and have been active for 90 days" lives partly in a LINQ `Where()` clause, partly in a service method, and partly in a view model. Each copy drifts independently. A specification wraps that rule in a named class with a single `IsSatisfiedBy(T entity)` method and, optionally, an `Expression<Func<T, bool>>` property that EF Core can translate to SQL. You compose specifications with AND, OR, and NOT operators by combining their expressions. The result is that the rule has one home, one name, and one test — and it works both in-memory and in database queries.

---

## The Code
```csharp
// 1. Base specification class — supports both in-memory and EF Core translation
public abstract class Specification<T>
{
    public abstract Expression<Func<T, bool>> ToExpression();

    public bool IsSatisfiedBy(T entity) =>
        ToExpression().Compile()(entity);              // compile once per check — cache in prod

    public Specification<T> And(Specification<T> other) =>
        new AndSpecification<T>(this, other);

    public Specification<T> Or(Specification<T> other) =>
        new OrSpecification<T>(this, other);

    public Specification<T> Not() =>
        new NotSpecification<T>(this);
}
```
```csharp
// 2. Composition operators — AND / OR / NOT via expression tree merging
public class AndSpecification<T> : Specification<T>
{
    private readonly Specification<T> _left;
    private readonly Specification<T> _right;

    public AndSpecification(Specification<T> left, Specification<T> right)
    {
        _left = left;
        _right = right;
    }

    public override Expression<Func<T, bool>> ToExpression()
    {
        var left  = _left.ToExpression();
        var right = _right.ToExpression();
        var param = left.Parameters[0];

        // Rewrite right-hand expression to use the same parameter as left
        var body = Expression.AndAlso(left.Body,
            ReplaceParameter(right.Body, right.Parameters[0], param));

        return Expression.Lambda<Func<T, bool>>(body, param);
    }

    private static Expression ReplaceParameter(
        Expression expr, ParameterExpression from, ParameterExpression to) =>
        new ParameterReplacer(from, to).Visit(expr);
}

// Helper — rewrites parameter references in an expression tree
internal class ParameterReplacer : ExpressionVisitor
{
    private readonly ParameterExpression _from, _to;
    public ParameterReplacer(ParameterExpression from, ParameterExpression to)
    {
        _from = from; _to = to;
    }
    protected override Expression VisitParameter(ParameterExpression node) =>
        node == _from ? _to : base.VisitParameter(node);
}

// OrSpecification and NotSpecification follow the same pattern
// (Expression.OrElse / Expression.Not)
```
```csharp
// 3. Concrete specifications — one rule per class, named after the business concept
public class ActiveCustomerSpecification : Specification<Customer>
{
    public override Expression<Func<Customer, bool>> ToExpression() =>
        c => c.IsActive && c.LastLoginAt >= DateTime.UtcNow.AddDays(-90);
}

public class PremiumCustomerSpecification : Specification<Customer>
{
    public override Expression<Func<Customer, bool>> ToExpression() =>
        c => c.TotalSpend >= 1000m;
}
```
```csharp
// 4. Composing specifications — business rules read like sentences
var activeAndPremium = new ActiveCustomerSpecification()
    .And(new PremiumCustomerSpecification());

// In-memory check
var isEligible = activeAndPremium.IsSatisfiedBy(customer);

// EF Core query — expression translates to SQL WHERE clause
var eligible = await _context.Customers
    .Where(activeAndPremium.ToExpression())
    .AsNoTracking()
    .ToListAsync();
```
```csharp
// 5. Using in a repository — specification passed as a parameter
public interface ICustomerRepository
{
    Task<List<Customer>> FindAsync(Specification<Customer> spec);
}

public class CustomerRepository : ICustomerRepository
{
    private readonly AppDbContext _context;
    public CustomerRepository(AppDbContext context) => _context = context;

    public Task<List<Customer>> FindAsync(Specification<Customer> spec) =>
        _context.Customers
            .Where(spec.ToExpression())
            .AsNoTracking()
            .ToListAsync();
}

// Call site — the repository stays generic, the rule travels with the caller
var premiumCustomers = await _repo.FindAsync(new PremiumCustomerSpecification());
```

---

## Gotchas
- **`Compile()` on every `IsSatisfiedBy()` call is expensive.** `Expression.Compile()` generates IL at runtime and should not be called in a tight loop. Cache the compiled delegate as a `Lazy<Func<T, bool>>` in the specification, or avoid `IsSatisfiedBy()` in hot paths and use `ToExpression()` directly with EF.
- **Expression trees can't call arbitrary C# methods.** EF Core translates `ToExpression()` to SQL, but only for constructs it recognizes. If your expression calls a custom C# method (e.g., `customer.IsVip()`), EF throws at runtime with a translation error. Keep expressions to simple comparisons, arithmetic, and string operations.
- **The `ParameterReplacer` is mandatory for AND/OR composition.** When you combine two `Expression<Func<T, bool>>` with `Expression.AndAlso`, both lambdas have their own `ParameterExpression` objects. If you don't rewrite one side to share the other's parameter, EF throws `InvalidOperationException: variable 'x' of type referenced from scope`. This trips up everyone who tries to merge expressions naively.
- **Specifications composed deeply produce complex expression trees that generate slow SQL.** Three levels of AND/OR nesting can produce a WHERE clause that confuses the query optimizer. Profile the generated SQL for composite specs — sometimes a hand-written query is clearer and faster.
- **Passing a specification to a generic repository leaks query concern back to the caller.** If the caller constructs the specification, they're effectively writing the query from outside the repository — the repository is no longer the single owner of query logic. Use specifications for shared, named business rules, not as a general-purpose query builder that replaces repository methods.

---

## Interview Angle
**What they're really testing:** Whether you understand how to encapsulate business rules so they're reusable across layers — in domain validation, repository queries, and service logic — without duplication.

**Common question form:** *"How do you avoid duplicating filtering logic across your service layer and your repository layer?"* or *"How would you implement a reusable eligibility check that works both in-memory and as a database query?"*

**The depth signal:** A junior says "put the condition in a helper method" or "use a predicate." A senior knows that a predicate works in-memory but can't be translated to SQL, while an `Expression<Func<T, bool>>` can — and that the specification pattern gives you both through `IsSatisfiedBy()` and `ToExpression()`. They also know the `ParameterReplacer` requirement for expression composition, the `Compile()` performance trap, and the architectural risk of specifications becoming a leaky query-builder that erodes the repository boundary.

---

## Related Topics
- [[dotnet/pattern-repository.md]] — Specifications are most commonly passed into repository `FindAsync()` methods; understanding the boundary between them prevents the pattern from becoming a leaky abstraction.
- [[dotnet/ef-performance.md]] — Translated expressions must use EF-compatible constructs; a specification that forces client-side evaluation silently loads entire tables.
- [[dotnet/pattern-strategy.md]] — Both patterns encapsulate a rule behind an interface; strategies encapsulate behavior (what to *do*), specifications encapsulate criteria (whether a condition is *met*).
- [[databases/indexes.md]] — Composite specifications generate composite WHERE clauses; the underlying index coverage determines whether the resulting query is fast or a full scan.

---

## Source
https://www.martinfowler.com/apsupp/spec.pdf

---
*Last updated: 2026-03-24*