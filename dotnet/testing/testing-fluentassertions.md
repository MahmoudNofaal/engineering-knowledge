# FluentAssertions

> FluentAssertions is a .NET library that replaces bare `Assert.Equal()` calls with readable, English-like assertion chains that produce clear failure messages.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Fluent assertion library for readable, informative test failures |
| **Use when** | Every test project — the failure messages alone justify the dependency |
| **Avoid when** | Production code — test-only dependency |
| **Key package** | `FluentAssertions` |
| **Entry point** | `.Should()` extension method on any type |
| **Key assertions** | `BeEquivalentTo`, `Contain`, `Throw`, `BeCloseTo`, `AssertionScope` |

---

## When To Use It
Use it in every test project — the failure messages alone justify the dependency. When `Assert.Equal(expected, actual)` fails, xUnit tells you the values didn't match. When a FluentAssertions chain fails, it tells you exactly what was wrong, on which property, and what it expected. Don't use it for production code — it's a test-only dependency and should be referenced only from test projects.

---

## Core Concept
The library extends every .NET type with `.Should()` — an entry point that returns a strongly-typed assertion object specific to the type you're asserting on. Strings get string-specific assertions (`Contain`, `StartWith`, `MatchRegex`). Collections get collection-specific assertions (`HaveCount`, `ContainSingle`, `BeInAscendingOrder`). Objects get structural equality assertions (`BeEquivalentTo`).

The key insight is `BeEquivalentTo`: it does deep structural comparison by recursively matching property names and values — no `Equals()` override required. It works across different types as long as the property names match. This replaces dozens of individual property assertions with one call. Failure messages name the exact property that diverged and show both values side by side.

`AssertionScope` is the second thing worth knowing. Without it, a test stops at the first failed assertion — if three properties are wrong you fix them one by one across three runs. Wrapping multi-property assertions in `using (new AssertionScope())` collects all failures and reports them together.

---

## Version History

| Version | What changed |
|---|---|
| 5.x | `BeEquivalentTo` options API stabilised; `Using<T>().WhenTypeIs<T>()` introduced |
| 6.0 | `AndWhich` chaining improved; `ThrowAsync` made more intuitive |
| 6.x | `HaveCount`, `AllSatisfy`, `OnlyContain` added to collection assertions |
| 7.0 | Breaking: some chaining methods renamed (`AndWhich` → `Which` in some paths); `AssertionChain` API changed; license changed to require commercial license for companies >10 developers |

*The FluentAssertions 7.0 commercial license change is significant — as of 2025, companies with more than 10 developers need a paid license for v7+. Many teams have pinned to v6.x or migrated to `Shouldly` (MIT license) as a result. Check your company's policy before upgrading.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `.Should().Be(x)` | < 0.01ms | Trivial value comparison |
| `.Should().BeEquivalentTo(x)` | 0.1–2ms | Recursive reflection-based comparison; scales with object depth |
| `.Should().BeEquivalentTo(x)` on large collections | 2–20ms | Each element compared recursively |
| `new AssertionScope()` | < 0.01ms | Stack-allocated scope; negligible overhead |

**Allocation behaviour:** `BeEquivalentTo` uses reflection to walk the object graph — it allocates for each property visited. For flat DTOs this is negligible. For deeply nested graphs with large collections it's measurable but still well within acceptable test overhead. If a test itself is the hot path, the assertion is not the bottleneck.

**Benchmark notes:** FluentAssertions does not meaningfully affect test suite runtime. If tests are slow, the cause is always I/O (hidden database or HTTP calls), not assertion overhead.

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
// 2. Object equality — BeEquivalentTo for deep structural comparison
var result = await _sut.GetOrderAsync(1);

result.Should().BeEquivalentTo(new
{
    Id     = 1,
    Total  = 99m,
    Status = "Pending"
});
// Compares by property name — no Equals() override needed
// Failure message: "Expected result.Total to be 150, but found 99"
```

```csharp
// 3. BeEquivalentTo options — control comparison behaviour
result.Should().BeEquivalentTo(expected, options => options
    .Excluding(o => o.CreatedAt)          // ignore timestamps
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
orders.Should().OnlyContain(o => o.Total > 0);

// BeEquivalentTo on collections — order-insensitive by default
orders.Should().BeEquivalentTo(expected,
    options => options.WithStrictOrdering()); // opt into order-sensitive
```

```csharp
// 5. Exception assertions
// Sync
var act = () => _sut.Divide(10, 0);
act.Should().Throw<DivideByZeroException>()
   .WithMessage("*divide*");

// Async — must await the assertion
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
found!.Total.Should().Be(99m);    // ! safe after NotBeNull assertion
```

```csharp
// 7. Multiple assertions in one block — all failures reported together
using (new AssertionScope())
{
    result.Id.Should().Be(1);
    result.Total.Should().Be(99m);
    result.Status.Should().Be(OrderStatus.Pending);
    result.CustomerEmail.Should().Contain("@");
}
// Without AssertionScope, first failure stops the test and hides the rest
// With it: "Expected result.Total to be 99 ... AND Expected result.Status to be Pending ..."
```

```csharp
// 8. DateTime assertions — essential in integration tests
var order = await _sut.PlaceOrderAsync(dto);

order.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));
order.CreatedAt.Should().BeAfter(DateTime.UtcNow.AddMinutes(-1));
order.ExpiresAt.Should().BeBefore(DateTime.UtcNow.AddDays(30));
```

```csharp
// 9. What NOT to do

// BAD: asserting each property one by one — first failure hides the rest
result.Id.Should().Be(1);
result.Total.Should().Be(99m);           // if Id assertion fails, you never see this
result.Status.Should().Be("Pending");

// GOOD: BeEquivalentTo or AssertionScope reports everything at once
using (new AssertionScope())
{
    result.Should().BeEquivalentTo(new { Id = 1, Total = 99m, Status = "Pending" },
        options => options.Excluding(o => o.CreatedAt));
}

// BAD: forgetting await on ThrowAsync — test silently passes regardless of exception
act.Should().ThrowAsync<ArgumentException>();    // ← missing await, always passes

// GOOD: always await async exception assertions
await act.Should().ThrowAsync<ArgumentException>().WithMessage("*id*");
```

---

## Real World Example

An order API integration test asserts on the full response body after a `POST /api/orders` call. The response includes a generated ID, a server-assigned timestamp, a status field, a total, and a nested shipping address object. Without FluentAssertions the test would need 12+ individual `Assert.Equal` calls. With `BeEquivalentTo` it's one call, with two field exclusions and a timestamp tolerance check.

```csharp
[Fact]
public async Task PlaceOrder_ValidRequest_ReturnsCorrectOrderShape()
{
    var payload = new CreateOrderRequest
    {
        CustomerId      = "cust-001",
        Items           = new[] { new OrderItem { ProductId = "prod-1", Quantity = 2 } },
        ShippingAddress = new Address
        {
            Line1    = "10 High Street",
            City     = "London",
            Postcode = "SW1A 1AA"
        }
    };

    var response = await _client.PostAsJsonAsync("/api/orders", payload);
    response.StatusCode.Should().Be(HttpStatusCode.Created);

    var body = await response.Content.ReadFromJsonAsync<OrderResponse>();

    using (new AssertionScope())
    {
        body.Should().NotBeNull();

        body!.Should().BeEquivalentTo(new
        {
            CustomerId = "cust-001",
            Status     = "Pending",
            Items      = new[]
            {
                new { ProductId = "prod-1", Quantity = 2 }
            },
            ShippingAddress = new
            {
                Line1    = "10 High Street",
                City     = "London",
                Postcode = "SW1A 1AA"
            }
        }, options => options
            .Excluding(o => o.Id)             // server-generated
            .Excluding(o => o.CreatedAt)      // handled separately below
            .Excluding(o => o.Items[0].Id));  // server-generated per item

        body.Id.Should().NotBeNullOrEmpty();
        body.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(10));
    }
}
```

*The `AssertionScope` wrapping everything is the production habit worth building — without it, the first assertion failure in a 10-property check means you have to run the test 10 times to find all the problems. With it, one run shows every divergence.*

---

## Common Misconceptions

**"`BeEquivalentTo` requires the two objects to be the same type."**
It compares by property name and value, not by type. You can assert that a `CreateOrderCommand` record matches an `OrderDto` response object as long as the property names align. This is especially useful in integration tests where you're comparing a request payload against a response body — they are different types but share field names.

**"`ContainSingle()` means 'contains at least one'."**
It means exactly one. `orders.Should().ContainSingle()` fails if there are two elements. For "at least one", use `Contain(predicate)`. For "exactly one matching a condition", use `ContainSingle(o => o.Id == 1)`. The asymmetry trips people up consistently.

**"Forgetting `await` on `ThrowAsync` is a compile error."**
It isn't — it compiles and runs. `ThrowAsync` returns a `Task`, and without `await` the assertion task is created but not awaited — the test method continues and exits, reporting success. The async exception assertion never executes. This is one of the most common silent false-positives in .NET test code.

```csharp
// This compiles, runs, and PASSES even if CancelOrderAsync never throws
var act = async () => await _sut.CancelOrderAsync(-1);
act.Should().ThrowAsync<ArgumentException>();   // ← missing await

// Correct
await act.Should().ThrowAsync<ArgumentException>().WithMessage("*id*");
```

---

## Gotchas

- **`BeEquivalentTo` compares by property name — mismatches are silently skipped.** If your expected object has a property called `Amount` and the actual object has `Total`, neither property is compared — the assertion passes despite the field being different. Name anonymous object properties to match exactly.

- **`BeEquivalentTo` on collections is order-insensitive by default.** This is almost always what you want, but if you're asserting on ordered results (query with `ORDER BY`), add `.WithStrictOrdering()` to the options.

- **Without `AssertionScope`, a test stops at the first failed assertion.** Wrap multi-property assertions in `using (new AssertionScope())` to see all failures at once — especially valuable when asserting on complex response objects where several fields are wrong simultaneously.

- **`ThrowAsync` must be awaited.** `act.Should().ThrowAsync<T>()` returns a `Task` — if you forget `await`, the assertion never executes and the test passes regardless of whether the exception was thrown. This is the most common silent false-positive in async test code.

- **`ContainSingle()` without a predicate asserts exactly one element total.** `orders.Should().ContainSingle()` fails if there are two or more elements — it's not "contains at least one." Use `ContainSingle(o => o.Id == 1)` for "exactly one matching", and `Contain(o => o.Id == 1)` for "at least one matching."

- **FluentAssertions 7.0 introduced a commercial license for teams > 10 developers.** If your organisation has more than 10 developers, v7+ requires a paid license. Many teams have pinned to v6.x or moved to `Shouldly` (MIT). Know which version your project targets and whether a license is required.

---

## Interview Angle

**What they're really testing:** Whether you write assertions that give actionable failure messages — a proxy for whether you've actually maintained a test suite through real failures in production.

**Common question forms:**
- *"How do you write assertions in your tests?"*
- *"What libraries do you use for testing and why?"*
- *"How do you assert on a complex response object?"*

**The depth signal:** A junior says "I use `Assert.Equal` from xUnit" or "I use FluentAssertions because the syntax is nicer." A senior explains the concrete benefit: `BeEquivalentTo` eliminates twenty individual property assertions and its failure message names the exact mismatched property — which cuts debugging time on a failing CI build from minutes to seconds. They know `AssertionScope` for collecting multiple failures, `BeCloseTo` for timestamp assertions in integration tests where exact equality is unreliable, the `ThrowAsync` await trap because they've been burned by a silent pass, and the v7 licensing change because it affected their project.

**Follow-up questions to expect:**
- *"How would you compare two lists of objects?"* — `BeEquivalentTo(expected)` on the collection; add `.WithStrictOrdering()` if order matters, `.Excluding()` for generated IDs.
- *"What happens if you don't `await` a `ThrowAsync` assertion?"* — The assertion task is created but abandoned; the test passes silently regardless of whether the exception was thrown.

---

## Related Topics

- [[dotnet/testing/testing-unit-tests.md]] — FluentAssertions is the assertion layer that sits on top of xUnit; understanding both together shows the full picture of a well-written test.
- [[dotnet/testing/testing-mocking.md]] — Moq's `Verify()` and FluentAssertions are complementary — Verify for interaction assertions, FluentAssertions for output and state assertions.
- [[dotnet/testing/testing-integration-tests.md]] — `BeEquivalentTo` and `BeCloseTo` are especially valuable in integration tests where response bodies have generated IDs and timestamps needing careful exclusion.
- [[dotnet/testing/testing-testcontainers.md]] — Integration tests against real containers produce complex response objects; `BeEquivalentTo` with exclusions is the cleanest way to assert on them.

---

## Source

https://fluentassertions.com/introduction

---
*Last updated: 2026-04-12*