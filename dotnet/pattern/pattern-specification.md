# Specification Pattern

> A specification is a reusable, composable object that encapsulates a single business rule as a boolean test — true if an object satisfies the rule, false if it doesn't.

---

## When To Use It

Use it when the same filtering or validation rule appears in multiple places — a repository query, a domain validation, and a UI eligibility check — and you're duplicating the condition each time. It pays off when rules need to be combined (`IsActive AND IsEligibleForDiscount`), named (`PremiumCustomerSpec`), and tested in isolation. Don't use it for one-off queries that live in a single repository method — the abstraction adds indirection without benefit when a condition is only ever used once.

---

## Core Concept

**One sentence for the interview:** A specification gives a business rule a name and a single home so it can be reused in queries, domain validation, and tests without duplication.

The problem it solves is scattered business logic. Without it, the rule "a customer is premium if they've spent over $1000 and have been active for 90 days" lives partly in a LINQ `Where()` clause, partly in a service method, and partly in a view model. Each copy drifts independently. A specification wraps that rule in a named class with a single `IsSatisfiedBy(T entity)` method and, optionally, an `Expression<Func<T, bool>>` property that EF Core can translate to SQL. You compose specifications with AND, OR, and NOT operators by combining their expressions. The result is that the rule has one home, one name, and one test — and it works both in-memory and in database queries.

---

## The Code

```csharp
// 1. Base specification class — supports both in-memory and EF Core translation
public abstract class Specification<T>
{
    public abstract Expression<Func<T, bool>> ToExpression();

    // Compiled delegate cached as Lazy<T> — avoids recompiling on every IsSatisfiedBy call
    private Lazy<Func<T, bool>>? _compiledExpression;
    private Func<T, bool> CompiledExpression =>
        (_compiledExpression ??= new Lazy<Func<T, bool>>(() => ToExpression().Compile())).Value;

    public bool IsSatisfiedBy(T entity) =>
        CompiledExpression(entity);                  // cached compile — safe in hot paths

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
public class AndSpecification<T>(Specification<T> left, Specification<T> right)
    : Specification<T>
{
    public override Expression<Func<T, bool>> ToExpression()
    {
        var leftExpr  = left.ToExpression();
        var rightExpr = right.ToExpression();
        var param     = leftExpr.Parameters[0];

        // Rewrite right-hand expression to use the same parameter as left
        // Without this, EF throws: "variable 'x' of type referenced from scope"
        var body = Expression.AndAlso(
            leftExpr.Body,
            ReplaceParameter(rightExpr.Body, rightExpr.Parameters[0], param));

        return Expression.Lambda<Func<T, bool>>(body, param);
    }

    private static Expression ReplaceParameter(
        Expression expr, ParameterExpression from, ParameterExpression to) =>
        new ParameterReplacer(from, to).Visit(expr);
}

public class OrSpecification<T>(Specification<T> left, Specification<T> right)
    : Specification<T>
{
    public override Expression<Func<T, bool>> ToExpression()
    {
        var leftExpr  = left.ToExpression();
        var rightExpr = right.ToExpression();
        var param     = leftExpr.Parameters[0];

        var body = Expression.OrElse(
            leftExpr.Body,
            ReplaceParameter(rightExpr.Body, rightExpr.Parameters[0], param));

        return Expression.Lambda<Func<T, bool>>(body, param);
    }

    private static Expression ReplaceParameter(
        Expression expr, ParameterExpression from, ParameterExpression to) =>
        new ParameterReplacer(from, to).Visit(expr);
}

public class NotSpecification<T>(Specification<T> inner) : Specification<T>
{
    public override Expression<Func<T, bool>> ToExpression()
    {
        var innerExpr = inner.ToExpression();
        var body = Expression.Not(innerExpr.Body);
        return Expression.Lambda<Func<T, bool>>(body, innerExpr.Parameters[0]);
    }
}

// Helper — rewrites parameter references in an expression tree
internal class ParameterReplacer(ParameterExpression from, ParameterExpression to)
    : ExpressionVisitor
{
    protected override Expression VisitParameter(ParameterExpression node) =>
        node == from ? to : base.VisitParameter(node);
}
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

var activeButNotPremium = new ActiveCustomerSpecification()
    .And(new PremiumCustomerSpecification().Not());

// In-memory check
var isEligible = activeAndPremium.IsSatisfiedBy(customer);

// EF Core query — expression translates to SQL WHERE clause
var eligible = await context.Customers
    .Where(activeAndPremium.ToExpression())
    .AsNoTracking()
    .ToListAsync();
```

```csharp
// 5. Using in a repository — specification passed as a parameter
public interface ICustomerRepository
{
    Task<List<Customer>> FindAsync(Specification<Customer> spec);
    Task<PagedResult<Customer>> FindPagedAsync(
        Specification<Customer> spec, int page, int pageSize);
}

public class CustomerRepository(AppDbContext context) : ICustomerRepository
{
    public Task<List<Customer>> FindAsync(Specification<Customer> spec) =>
        context.Customers
            .Where(spec.ToExpression())
            .AsNoTracking()
            .ToListAsync();

    public async Task<PagedResult<Customer>> FindPagedAsync(
        Specification<Customer> spec, int page, int pageSize)
    {
        var query = context.Customers
            .Where(spec.ToExpression())
            .AsNoTracking();

        var totalCount = await query.CountAsync();
        var items = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return new PagedResult<Customer>(items, totalCount, page, pageSize);
    }
}

// Call site — the repository stays generic, the rule travels with the caller
var premiumCustomers = await repo.FindAsync(new PremiumCustomerSpecification());

var pagedActive = await repo.FindPagedAsync(
    new ActiveCustomerSpecification(), page: 1, pageSize: 20);
```

```csharp
// 6. Ardalis.Specification — alternative to hand-rolling the base class
// dotnet add package Ardalis.Specification
// dotnet add package Ardalis.Specification.EntityFrameworkCore

public class PremiumCustomerSpec : Specification<Customer>
{
    public PremiumCustomerSpec()
    {
        Query
            .Where(c => c.TotalSpend >= 1000m)
            .AsNoTracking();
    }
}

// Repository with Ardalis — inherits RepositoryBase<T> which handles FindAsync, FirstOrDefaultAsync, etc.
public class CustomerRepository(AppDbContext context)
    : RepositoryBase<Customer>(context), ICustomerRepository { }

// Trade-off: Ardalis gives you pagination, ordering, includes, and split queries out of the box.
// Hand-rolling gives you full control over the expression tree and composition operators.
// Use Ardalis when you need the extras; hand-roll when you need NOT and complex composition.
```

```csharp
// 7. Unit testing a specification in isolation — no database required
[Fact]
public void PremiumCustomerSpecification_IsSatisfiedBy_ReturnsTrueForHighSpenders()
{
    var spec = new PremiumCustomerSpecification();

    var highSpender = new Customer { TotalSpend = 1500m };
    var lowSpender  = new Customer { TotalSpend = 500m };

    Assert.True(spec.IsSatisfiedBy(highSpender));
    Assert.False(spec.IsSatisfiedBy(lowSpender));
}

[Fact]
public void ComposedSpec_And_BothConditionsMustBeTrue()
{
    var spec = new ActiveCustomerSpecification().And(new PremiumCustomerSpecification());

    var activeAndRich  = new Customer { IsActive = true, LastLoginAt = DateTime.UtcNow, TotalSpend = 2000m };
    var activeButPoor  = new Customer { IsActive = true, LastLoginAt = DateTime.UtcNow, TotalSpend = 50m };

    Assert.True(spec.IsSatisfiedBy(activeAndRich));
    Assert.False(spec.IsSatisfiedBy(activeButPoor));
}
```

---

## Gotchas

- **`Compile()` on every `IsSatisfiedBy()` call is expensive.** `Expression.Compile()` generates IL at runtime and should not be called in a tight loop. Cache the compiled delegate as a `Lazy<Func<T, bool>>` in the specification — as shown in the base class above — so compilation happens once per spec instance, not once per call.

- **Expression trees can't call arbitrary C# methods.** EF Core translates `ToExpression()` to SQL, but only for constructs it recognizes. If your expression calls a custom C# method (e.g., `customer.IsVip()`), EF throws at runtime with a translation error. Keep expressions to simple comparisons, arithmetic, and string operations.

- **The `ParameterReplacer` is mandatory for AND/OR composition.** When you combine two `Expression<Func<T, bool>>` with `Expression.AndAlso`, both lambdas have their own `ParameterExpression` objects. If you don't rewrite one side to share the other's parameter, EF throws `InvalidOperationException: variable 'x' of type referenced from scope`. This trips up everyone who tries to merge expressions naively.

- **Specifications composed deeply produce complex expression trees that generate slow SQL.** Three levels of AND/OR nesting can produce a WHERE clause that confuses the query optimizer. Profile the generated SQL for composite specs — sometimes a hand-written query is clearer and faster.

- **Passing a specification to a generic repository leaks query concern back to the caller.** If the caller constructs the specification, they're effectively writing the query from outside the repository — the repository is no longer the single owner of query logic. Use specifications for shared, named business rules, not as a general-purpose query builder that replaces repository methods.

- **Specifications that include navigation properties may cause cartesian product queries.** A spec like `c => c.Orders.Any(o => o.Total > 100)` translates to a JOIN in SQL. If EF hasn't been configured to split the query or the include strategy is wrong, this can produce many rows being returned and filtered client-side. Check the generated SQL.

---

## Interview Angle

**What they're really testing:** Whether you understand how to encapsulate business rules so they're reusable across layers — in domain validation, repository queries, and service logic — without duplication.

**Common question form:** *"How do you avoid duplicating filtering logic across your service layer and your repository layer?"* or *"How would you implement a reusable eligibility check that works both in-memory and as a database query?"*

**The depth signal:** A junior says "put the condition in a helper method" or "use a predicate." A senior knows that a predicate works in-memory but can't be translated to SQL, while an `Expression<Func<T, bool>>` can — and that the specification pattern gives you both through `IsSatisfiedBy()` and `ToExpression()`. They also know the `ParameterReplacer` requirement for expression composition, the `Compile()` performance trap, and the architectural risk of specifications becoming a leaky query-builder that erodes the repository boundary.

**Follow-up the interviewer asks next:** *"How would you test a specification in isolation without a real database?"*

Call `IsSatisfiedBy()` directly with in-memory objects — no EF, no database, no connection string. The specification is a pure function on a domain object; unit testing it is as simple as constructing a `Customer` with the relevant properties set and asserting the boolean result. This is one of the pattern's hidden benefits: your business rules become directly unit-testable without any persistence infrastructure. Test `ToExpression()` integration behavior (SQL translation) in a separate integration test against a real or in-memory database if needed.

---

## Related Topics

- [[dotnet/pattern/pattern-repository.md]] — Specifications are most commonly passed into repository `FindAsync()` methods; understanding the boundary between them prevents the pattern from becoming a leaky abstraction.
- [[dotnet/ef/ef-performance.md]] — Translated expressions must use EF-compatible constructs; a specification that forces client-side evaluation silently loads entire tables.
- [[dotnet/pattern/pattern-strategy.md]] — Both patterns encapsulate a rule behind an interface; strategies encapsulate behavior (what to *do*), specifications encapsulate criteria (whether a condition is *met*).

---

## Source

https://www.martinfowler.com/apsupp/spec.pdf

---

*Last updated: 2026-04-09*