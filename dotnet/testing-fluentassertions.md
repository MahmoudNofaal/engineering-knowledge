# FluentAssertions

> FluentAssertions is a .NET library that replaces bare `Assert.Equal()` calls with readable, English-like assertion chains that produce clear failure messages.

---

## When To Use It
Use it in every test project — the failure messages alone justify the dependency. When `Assert.Equal(expected, actual)` fails, xUnit tells you the values didn't match. When a FluentAssertions chain fails, it tells you exactly what was wrong, on which property, and what it expected. Don't use it for production code — it's a test-only dependency and should be referenced only from test projects.

---

## Core Concept
The library extends every .NET type with `.Should()` — an entry point that returns a strongly-typed assertion object specific to the type you're asserting on. Strings get string-specific assertions (`Contain`, `StartWith`, `MatchRegex`). Collections get collection-specific assertions (`HaveCount`, `ContainSingle`, `BeInAscendingOrder`). Objects get structural equality assertions (`BeEquivalentTo`). The key insight is `BeEquivalentTo`: it does deep structural comparison by recursively matching property names and values — no `Equals()` override required. This replaces dozens of individual property assertions with one call. Failure messages name the exact property that diverged and show both values side by side.

---

## The Code
```csharp
// Setup
// dotnet add package FluentAssertions
```
```csharp
// 1. Basic value assertions
result.Should().Be(42);
result.Should().NotBe(0);
result.Should().BeGreaterThan(10);
result.Should().BeInRange(1, 100);

name.Should().Be("Alice");
name.Should().NotBeNullOrWhiteSpace();
name.Should().StartWith("Al").And.EndWith("ce").And.HaveLength(5);
name.Should().Contain("lic");
name.Should().MatchRegex(@"^[A-Z][a-z]+$");
```
```csharp
// 2. Object equality — BeEquivalentTo does deep structural comparison
var result = await _sut.GetOrderAsync(1);

result.Should().BeEquivalentTo(new
{
    Id     = 1,
    Total  = 99m,
    Status = "Pending"
});
// Compares by property name — no Equals() override needed
// Failure message names the exact property that didn't match
```
```csharp
// 3. BeEquivalentTo options — control comparison behavior
result.Should().BeEquivalentTo(expected, options => options
    .Excluding(o => o.CreatedAt)          // ignore timestamp fields
    .Excluding(o => o.Id)                 // ignore generated IDs
    .Using<decimal>(ctx =>                // custom comparison for a type
        ctx.Subject.Should().BeApproximately(ctx.Expectation, 0.01m))
    .WhenTypeIs<decimal>());
```
```csharp
// 4. Collection assertions
var orders = await _sut.GetPendingOrdersAsync();

orders.Should().NotBeEmpty();
orders.Should().HaveCount(3);
orders.Should().ContainSingle(o => o.CustomerId == 5);  // exactly one match
orders.Should().Contain(o => o.Total > 100m);
orders.Should().NotContain(o => o.Status == OrderStatus.Shipped);
orders.Should().BeInAscendingOrder(o => o.CreatedAt);
orders.Should().AllSatisfy(o => o.Status.Should().Be(OrderStatus.Pending));
orders.Should().OnlyContain(o => o.Total > 0);          // every element passes predicate

// Structural collection equivalence — order-insensitive by default
orders.Should().BeEquivalentTo(expected,
    options => options.WithStrictOrdering());            // opt into order-sensitive
```
```csharp
// 5. Exception assertions
// Sync
var act = () => _sut.Divide(10, 0);
act.Should().Throw<DivideByZeroException>()
   .WithMessage("*divide*")                             // wildcard match on message
   .And.StackTrace.Should().NotBeNullOrEmpty();

// Async
var act = async () => await _sut.CancelOrderAsync(-1);
await act.Should().ThrowAsync<ArgumentException>()
         .WithMessage("*id*");

// Assert no exception thrown
var act = () => _sut.ProcessOrder(validOrder);
act.Should().NotThrow();
```
```csharp
// 6. Nullable and null assertions
Order? result = await _repo.GetByIdAsync(999);
result.Should().BeNull();

Order? found = await _repo.GetByIdAsync(1);
found.Should().NotBeNull();
found!.Total.Should().Be(99m);          // after NotBeNull, safe to use !
```
```csharp
// 7. Multiple assertions in one block — all failures reported together
using (new AssertionScope())            // collect all failures instead of stopping at first
{
    result.Id.Should().Be(1);
    result.Total.Should().Be(99m);
    result.Status.Should().Be(OrderStatus.Pending);
    result.CustomerEmail.Should().Contain("@");
}
// Without AssertionScope, first failure stops the test and hides the rest
```
```csharp
// 8. DateTime assertions
var order = await _sut.PlaceOrderAsync(dto);

order.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));
order.CreatedAt.Should().BeAfter(DateTime.UtcNow.AddMinutes(-1));
order.ExpiresAt.Should().BeBefore(DateTime.UtcNow.AddDays(30));
```

---

## Gotchas
- **`BeEquivalentTo` compares by property name, not by type.** It works across different types as long as the property names and values match — which is intentional for DTO comparisons. But if your production class has a property called `Amount` and your expected object has `Total`, the assertion passes silently because neither property is matched against the other. Name your anonymous object properties to match exactly.
- **`BeEquivalentTo` on collections checks structural equality of elements, not reference equality.** This is almost always what you want, but if you're asserting that the *exact same object instance* is in a collection, use `Contain(x => ReferenceEquals(x, expected))` instead.
- **Without `AssertionScope`, a test stops at the first failed assertion.** If three properties are wrong, you see one failure, fix it, run again, see the second, and so on. Wrap multi-property assertions in `using (new AssertionScope())` to see all failures at once — especially useful when asserting on complex response objects.
- **`ThrowAsync` must be awaited.** `act.Should().ThrowAsync<T>()` returns a `Task` — if you forget the `await`, the assertion never executes and the test passes regardless of whether the exception was thrown. This is one of the most common silent false-positives in async test code.
- **`ContainSingle()` without a predicate asserts exactly one element total.** `orders.Should().ContainSingle()` fails if there are two or more elements — it's not "contains at least one." If you want to assert exactly one element matching a condition, use `ContainSingle(o => o.Id == 1)`. If you want at least one, use `Contain(o => o.Id == 1)`.

---

## Interview Angle
**What they're really testing:** Whether you write assertions that give actionable failure messages — a proxy for whether you've actually maintained a test suite through real failures in production.

**Common question form:** *"How do you write assertions in your tests?"* or *"What libraries do you use for testing and why?"*

**The depth signal:** A junior says "I use `Assert.Equal` from xUnit" or "I use FluentAssertions because the syntax is nicer." A senior explains the concrete benefit: `BeEquivalentTo` eliminates twenty individual property assertions and its failure message names the exact mismatched property — which cuts debugging time on a failing CI build from minutes to seconds. They know `AssertionScope` for collecting multiple failures, `BeCloseTo` for timestamp assertions in integration tests where exact equality is unreliable, and the `ThrowAsync` await trap because they've been burned by a test that silently passed when it shouldn't have.

---

## Related Topics
- [[dotnet/testing-unit-tests.md]] — FluentAssertions is the assertion layer that sits on top of xUnit; understanding both together shows the full picture of a well-written test.
- [[dotnet/testing-mocking.md]] — Moq's `Verify()` and FluentAssertions are complementary — Verify for interaction assertions, FluentAssertions for output and state assertions.
- [[dotnet/testing-integration-tests.md]] — `BeEquivalentTo` and `BeCloseTo` are especially valuable in integration tests where response bodies have generated IDs and timestamps that need careful handling.
- [[dotnet/testing-testcontainers.md]] — Integration tests against real containers produce complex response objects; `BeEquivalentTo` with exclusions is the cleanest way to assert on them.

---

## Source
https://fluentassertions.com/introduction

---
*Last updated: 2026-03-24*