# Builder Pattern

> A builder constructs a complex object step by step, letting you set only the parts you care about before calling a final method to get the result.

---

## When To Use It

Use it when an object has many optional parameters and telescoping constructors (four overloads that differ by one argument each) are making call sites unreadable. It's also the right move when construction must happen in a specific order, or when the same construction process needs to produce different representations. Don't use it for simple objects with two or three properties — a plain constructor or object initializer is clearer and requires less code.

---

## Core Concept

**One sentence for the interview:** A builder turns "one giant constructor with ten nullable arguments" into a readable sentence of named steps.

The problem it solves is constructor overload hell. When a class has ten properties and half of them are optional, you end up either with a constructor that takes ten arguments (most callers pass `null` for half of them) or with five overloads that are hard to keep in sync. A builder solves this by breaking construction into named steps — each method sets one thing and returns `this` so you can chain calls. The final `.Build()` validates that required fields are present and returns the object. The caller's code reads almost like a sentence: `new EmailBuilder().To("x@y.com").Subject("Hi").WithAttachment(file).Build()`. In .NET you see this pattern everywhere in the framework itself — `WebApplication.CreateBuilder()`, `IHostBuilder`, `DbContextOptionsBuilder` — it's the standard way to configure complex objects at startup.

---

## The Code

```csharp
// 1. Classic builder — fluent, immutable result
public class Email
{
    public string To { get; init; } = default!;
    public string Subject { get; init; } = default!;
    public string Body { get; init; } = "";
    public string? Cc { get; init; }
    public List<string> Attachments { get; init; } = new();

    private Email() { }                             // force use of builder

    public class Builder
    {
        private readonly Email _email = new();
        private string? _to;
        private string? _subject;

        public Builder To(string address) { _to = address; return this; }
        public Builder Subject(string subject) { _subject = subject; return this; }
        public Builder Body(string body) { _email.Body = body; return this; }
        public Builder Cc(string cc) { _email.Cc = cc; return this; }
        public Builder WithAttachment(string path)
        {
            _email.Attachments.Add(path);
            return this;
        }

        public Email Build()
        {
            if (string.IsNullOrWhiteSpace(_to))
                throw new InvalidOperationException("To address is required.");
            if (string.IsNullOrWhiteSpace(_subject))
                throw new InvalidOperationException("Subject is required.");

            _email.To = _to;
            _email.Subject = _subject;
            return _email;
        }
    }
}

// Usage
var email = new Email.Builder()
    .To("alice@example.com")
    .Subject("Q4 Report")
    .Body("Please find the report attached.")
    .WithAttachment("/reports/q4.pdf")
    .Build();
```

```csharp
// 2. Builder with step interfaces — enforces required fields at compile time
// Forces To() before Subject() before Build() via interface chain
public interface IEmailTo      { IEmailSubject To(string address); }
public interface IEmailSubject { IEmailReady Subject(string subject); }
public interface IEmailReady
{
    IEmailReady Body(string body);
    IEmailReady Cc(string cc);
    Email Build();
}

public class StrictEmailBuilder : IEmailTo, IEmailSubject, IEmailReady
{
    private string _to = default!;
    private string _subject = default!;
    private string _body = "";
    private string? _cc;

    public static IEmailTo Create() => new StrictEmailBuilder();

    public IEmailSubject To(string address)  { _to = address; return this; }
    public IEmailReady Subject(string s)     { _subject = s; return this; }
    public IEmailReady Body(string b)        { _body = b; return this; }
    public IEmailReady Cc(string cc)         { _cc = cc; return this; }

    public Email Build() => new Email.Builder()
        .To(_to).Subject(_subject).Body(_body).Cc(_cc!).Build();
}

// Caller cannot call Build() without first calling To() and Subject() — compile-time safety
var email = StrictEmailBuilder.Create()
    .To("bob@example.com")
    .Subject("Hello")
    .Build();
```

```csharp
// 3. Director — orchestrates builder steps in a fixed sequence
// Useful when the same sequence of steps builds different configurations
public class EmailDirector
{
    private readonly Email.Builder _builder;

    public EmailDirector(Email.Builder builder) => _builder = builder;

    public Email BuildWelcomeEmail(string to, string name) =>
        _builder
            .To(to)
            .Subject($"Welcome, {name}!")
            .Body("Thanks for signing up. Here's how to get started.")
            .Build();

    public Email BuildPasswordResetEmail(string to, string resetLink) =>
        _builder
            .To(to)
            .Subject("Reset your password")
            .Body($"Click here to reset: {resetLink}")
            .Build();
}

// The Director knows the sequences; the Builder knows the steps
var director = new EmailDirector(new Email.Builder());
var welcome = director.BuildWelcomeEmail("alice@example.com", "Alice");
```

```csharp
// 4. Test data builder — reduces fixture noise in unit tests
public class OrderBuilder
{
    private int _customerId = 1;
    private decimal _total = 100m;
    private OrderStatus _status = OrderStatus.Pending;
    private List<OrderItem> _items = new();

    public OrderBuilder WithCustomer(int id)         { _customerId = id; return this; }
    public OrderBuilder WithTotal(decimal total)     { _total = total; return this; }
    public OrderBuilder AsShipped()                  { _status = OrderStatus.Shipped; return this; }
    public OrderBuilder WithItem(int productId, int qty)
    {
        _items.Add(new OrderItem { ProductId = productId, Quantity = qty });
        return this;
    }

    public Order Build() => new Order
    {
        CustomerId = _customerId,
        Total = _total,
        Status = _status,
        Items = _items
    };
}

// Test — only set what the test cares about, defaults handle the rest
var order = new OrderBuilder().WithTotal(250m).AsShipped().Build();

// Alternative: AutoFixture or Bogus for generating realistic fake data without hand-rolling
// Bogus: var faker = new Faker<Order>().RuleFor(o => o.Total, f => f.Finance.Amount());
// Use Bogus when you need randomized, realistic data; use a hand-rolled builder when
// you need fine-grained control over specific properties in assertions.
```

```csharp
// 5. Dynamic WHERE clause builder — real-world query building
// Builder pattern applied to constructing SQL conditions at runtime
public class OrderQueryBuilder
{
    private readonly List<string> _conditions = new();
    private readonly DynamicParameters _params = new();

    public OrderQueryBuilder ForCustomer(int customerId)
    {
        _conditions.Add("CustomerId = @customerId");
        _params.Add("customerId", customerId);
        return this;
    }

    public OrderQueryBuilder WithStatus(OrderStatus status)
    {
        _conditions.Add("Status = @status");
        _params.Add("status", status);
        return this;
    }

    public OrderQueryBuilder PlacedAfter(DateTime date)
    {
        _conditions.Add("CreatedAt >= @date");
        _params.Add("date", date);
        return this;
    }

    public (string Sql, DynamicParameters Parameters) Build()
    {
        var where = _conditions.Count > 0
            ? "WHERE " + string.Join(" AND ", _conditions)
            : string.Empty;
        return ($"SELECT * FROM Orders {where}", _params);
    }
}

var (sql, parameters) = new OrderQueryBuilder()
    .ForCustomer(42)
    .WithStatus(OrderStatus.Pending)
    .Build();
```

---

## Gotchas

- **Returning `this` from builder methods requires the builder to be mutable.** If you try to make builder methods return a new builder instance for immutability (like a record-based builder), you pay a heap allocation per step. For most cases, a mutable builder that returns `this` is the right tradeoff.

- **Validation in `Build()` only — not in individual setters.** If you validate in each setter (e.g., throw if `To()` receives an empty string), you prevent temporarily invalid states that might be valid once all fields are set. Validate the complete object once, at `Build()`.

- **The inner class pattern (`Email.Builder`) couples builder to the product.** This is intentional when you want to enforce that the only way to construct `Email` is through the builder (private constructor). If the builder needs to exist independently — e.g., across assemblies — make it a top-level class.

- **Chained methods that return different interface types (step builder) break if stored in a variable.** If a caller does `var b = builder.To("x")`, the inferred type is `IEmailSubject`, not the concrete builder — methods from `IEmailReady` aren't visible. This is by design but surprises people who try to conditionally call steps.

- **Test data builders need sensible defaults for every field.** If a field has no default and the test doesn't set it, `Build()` either throws or produces an invalid object. Defaults should make the built object valid out of the box so tests only override what's relevant to their assertion.

- **Builder with mutable state shared across calls produces wrong results.** If you call `Build()` twice on the same builder instance, the second call produces a different object if any step modified shared state. Either reset state in `Build()`, or create a new builder instance per object.

---

## Interview Angle

**What they're really testing:** Whether you understand the tradeoff between construction flexibility and readability, and how the pattern fits into real-world .NET (test fixtures, configuration, SDK design).

**Common question form:** *"How do you handle objects with many optional constructor parameters?"* or *"What design pattern does `WebApplication.CreateBuilder()` use and why?"*

**The depth signal:** A junior describes the builder as "a class that builds another class with chained methods" and gives a generic example. A senior knows the specific problems it solves (telescoping constructors, required vs optional parameter enforcement), distinguishes between a fluent builder and a step-interface builder and when compile-time safety justifies the extra interfaces, and recognizes the test data builder as a distinct and high-value application of the pattern — reducing fixture noise without a mocking library.

**Follow-up the interviewer asks next:** *"How does `WebApplicationBuilder` in .NET use the builder pattern?"*

`WebApplicationBuilder` is a Director + Builder combined. `WebApplication.CreateBuilder(args)` gives you a builder with pre-wired defaults (Kestrel, configuration, logging). Each call on `builder.Services`, `builder.Logging`, `builder.Configuration` configures one dimension of the final application. `builder.Build()` assembles the `WebApplication` from everything configured — it validates the DI registrations, builds the middleware pipeline, and returns the host. You can't construct a `WebApplication` directly; the builder is the only path, which enforces construction order and gives the framework a chance to validate before startup.

---

## Related Topics

- [[dotnet/pattern/pattern-factory.md]] — A factory decides *which* object to create; a builder decides *how* to construct one specific complex object. They're often confused but solve different problems.
- [[dotnet/pattern/dependency-injection.md]] — `IHostBuilder` and `WebApplicationBuilder` are builders that configure the DI container itself; understanding both clarifies how .NET startup works.
- [[dotnet/pattern/pattern-unit-of-work.md]] — Unit of work instances are often configured via builder-style setup in tests using test data builders alongside fake repositories.

---

## Source

https://refactoring.guru/design-patterns/builder

---

*Last updated: 2026-04-09*