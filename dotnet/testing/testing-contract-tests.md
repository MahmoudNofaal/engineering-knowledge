# Contract Testing in .NET

> Contract testing verifies that a service's API matches what its consumers expect — catching breaking changes between microservices without requiring both to run simultaneously.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Tests that verify API contracts between a consumer and a provider |
| **Use when** | Microservices where one service calls another's HTTP API |
| **Avoid when** | Monoliths; or when a full integration test environment is reliable and fast enough |
| **Key library** | `PactNet` — .NET implementation of the Pact specification |
| **Key package** | `PactNet`, `PactNet.Native` |
| **Pact Broker** | Central server that stores contracts; `pactflow.io` is the hosted option |

---

## When To Use It
Use contract testing when you have microservices that call each other's HTTP APIs and want confidence that a provider change won't break a consumer — without spinning up both services in a shared integration environment. Contract tests are faster and more targeted than end-to-end tests and catch the specific class of bug that integration tests in a shared environment miss: a provider team deploys a breaking change to a field name and the consumer team doesn't find out until their staging environment breaks.

Don't use contract testing in a monolith where both sides of the interface live in the same deployable. Don't use it as a replacement for integration tests — it tests the contract, not the behavior. Don't adopt it if you don't have a Pact Broker (or Pactflow) set up — the contracts need somewhere to live and be shared.

---

## Core Concept
Pact is consumer-driven contract testing. The **consumer** writes a test that defines what it expects from the provider — specific request/response pairs. Pact records this expectation as a **pact file** (JSON). The **provider** runs a verification test that replays the consumer's requests against a real running instance of the provider and checks that the responses match the contract. If the provider response doesn't match, the provider test fails — before any deployment happens.

The flow is:
1. Consumer writes Pact test → generates pact file
2. Consumer publishes pact file to Pact Broker
3. Provider pulls pact file from broker and runs verification tests
4. Both sides can gate deployments on "can I deploy?" — the broker knows which consumer/provider combinations are verified

This is fundamentally different from integration tests. Integration tests verify that two running services work together. Contract tests verify that each side honours the agreed interface independently — the consumer test runs without a real provider, and the provider test runs without a real consumer.

---

## Version History

| Package | Version | What changed |
|---|---|---|
| `PactNet` | 3.x | Synchronous verification API |
| `PactNet` | 4.0 | `PactNet.Native` replaces managed wrapper; async-first API |
| `PactNet` | 4.x | HTTP interactions, message interactions (async messaging) |
| `PactNet` | 4.5+ | V4 pact specification support; plugin architecture |
| Pact specification | V2 | Regex and type matchers |
| Pact specification | V3 | Message (async) contracts; provider state injection |
| Pact specification | V4 | Synchronous message interactions; combined interaction types |

*PactNet 4.0 was a significant breaking change from 3.x — the API is entirely different. Most documentation online is for 3.x. If starting fresh, use 4.x (`PactNet.Native`) which is the current version.*

---

## Performance

| Step | Time | Notes |
|---|---|---|
| Consumer pact generation | < 1s | Runs a mock server locally; no network |
| Provider verification (single pact) | 1–5s | Starts provider app; replays interactions |
| Pact Broker publish | < 1s | HTTP upload of pact JSON |
| Full consumer suite | Same as unit tests | Consumer tests are fast — no real provider |

---

## The Code

```csharp
// Setup
// In the CONSUMER test project:
// dotnet add package PactNet.Native

// In the PROVIDER test project:
// dotnet add package PactNet.Native
```

```csharp
// ── Consumer side ─────────────────────────────────────────────────────────────

// 1. Consumer pact test — defines what the consumer expects from the provider
public class OrderServiceConsumerTests : IDisposable
{
    private readonly IPactBuilderV4 _pactBuilder;
    private readonly string _pactDir = Path.Combine(
        Directory.GetCurrentDirectory(), "pacts");

    public OrderServiceConsumerTests()
    {
        // Define the contract between this consumer and the orders provider
        var pact = Pact.V4("payments-service", "orders-service",
            new PactConfig { PactDir = _pactDir });

        _pactBuilder = pact.WithHttpInteractions();
    }

    [Fact]
    public async Task GetOrder_ExistingId_ReturnsOrderWithExpectedFields()
    {
        // Define what request the consumer will make and what response it expects
        _pactBuilder
            .UponReceiving("a request for order 1")
            .Given("order 1 exists")             // provider state
            .WithRequest(HttpMethod.Get, "/api/orders/1")
            .WillRespond()
            .WithStatus(HttpStatusCode.OK)
            .WithHeader("Content-Type", "application/json; charset=utf-8")
            .WithJsonBody(new
            {
                id     = Match.Integer(1),        // must be an integer, value flexible
                total  = Match.Decimal(99.0),     // must be a decimal
                status = Match.Type("Pending"),   // must be a string, value flexible
                customerId = Match.Type("cust-001")
            });

        await _pactBuilder.VerifyAsync(async ctx =>
        {
            // Run the actual consumer code against the mock provider
            var httpClient = new HttpClient { BaseAddress = ctx.MockServerUri };
            var orderClient = new OrderServiceClient(httpClient);

            var order = await orderClient.GetOrderAsync(1);

            // Assert on the consumer side — does the client parse the response correctly?
            order.Should().NotBeNull();
            order!.Id.Should().Be(1);
            order.Status.Should().Be("Pending");
        });
    }

    [Fact]
    public async Task GetOrder_NonExistentId_Returns404()
    {
        _pactBuilder
            .UponReceiving("a request for a non-existent order")
            .Given("order 999 does not exist")
            .WithRequest(HttpMethod.Get, "/api/orders/999")
            .WillRespond()
            .WithStatus(HttpStatusCode.NotFound);

        await _pactBuilder.VerifyAsync(async ctx =>
        {
            var httpClient = new HttpClient { BaseAddress = ctx.MockServerUri };
            var orderClient = new OrderServiceClient(httpClient);

            var act = async () => await orderClient.GetOrderAsync(999);

            await act.Should().ThrowAsync<OrderNotFoundException>();
        });
    }

    public void Dispose()
    {
        // Pact files are written on dispose — check _pactDir after tests run
    }
}
```

```csharp
// ── Pact matchers — flexible matching instead of exact values ────────────────

// Match.Integer(n)    — value must be an integer; use n as example in pact file
// Match.Decimal(n)    — value must be a decimal/float
// Match.Type("str")   — value must be the same type as the example (string here)
// Match.Regex("...", pattern) — value must match the regex
// Match.Include("x")  — string value must contain "x"
// Match.MinType(example, min) — array with at least min elements of same type

_pactBuilder
    .UponReceiving("a request for orders")
    .WithRequest(HttpMethod.Get, "/api/orders")
    .WillRespond()
    .WithStatus(HttpStatusCode.OK)
    .WithJsonBody(new[]
    {
        new
        {
            id     = Match.Integer(1),
            total  = Match.Decimal(99.0),
            status = Match.Regex("Pending", "^(Pending|Shipped|Cancelled)$")
        }
    });
```

```csharp
// ── Provider side ──────────────────────────────────────────────────────────────

// 2. Provider verification test — runs consumer's recorded interactions against real provider
public class OrdersProviderPactTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public OrdersProviderPactTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task VerifyPactsFromBroker()
    {
        // Provider verifier replays consumer interactions and checks responses
        var verifier = new PactVerifier(new PactVerifierConfig
        {
            LogLevel = PactLogLevel.Information
        });

        verifier
            .ServiceProvider("orders-service", BuildHttpClient())
            .WithPactBrokerSource(new Uri("https://your-pact-broker.com"), options =>
            {
                options.TokenAuthentication("your-broker-token");
                options.PublishResults("1.0.0");    // publish verification results back
            })
            .WithProviderStateUrl(new Uri("http://localhost/provider-states"))
            .Verify();
    }

    // Local pact file (no broker) — useful during development
    [Fact]
    public async Task VerifyPactsFromLocalFile()
    {
        var pactFile = Path.Combine(Directory.GetCurrentDirectory(),
            "pacts", "payments-service-orders-service.json");

        var verifier = new PactVerifier(new PactVerifierConfig());

        verifier
            .ServiceProvider("orders-service", BuildHttpClient())
            .WithFileSource(new FileInfo(pactFile))
            .WithProviderStateUrl(new Uri("http://localhost/provider-states"))
            .Verify();
    }

    private HttpClient BuildHttpClient()
    {
        // Use the real WebApplicationFactory to create the provider's HttpClient
        return _factory.CreateClient();
    }
}
```

```csharp
// 3. Provider state middleware — set up data required for each consumer interaction
// Provider state is declared by the consumer ("given order 1 exists")
// The provider must implement a middleware that sets up that state

// Add to the test WebApplicationFactory or Program.cs in test mode:
app.MapPost("/provider-states", async (ProviderState state, AppDbContext db) =>
{
    switch (state.State)
    {
        case "order 1 exists":
            db.Orders.Add(new Order { Id = 1, Total = 99m,
                                      Status = OrderStatus.Pending,
                                      CustomerId = "cust-001" });
            await db.SaveChangesAsync();
            break;

        case "order 999 does not exist":
            // Nothing to set up — just ensure 999 isn't seeded
            break;

        default:
            return Results.BadRequest($"Unknown provider state: {state.State}");
    }

    return Results.Ok();
});

public record ProviderState(string State, Dictionary<string, string>? Params);
```

```csharp
// 4. Publishing pact to broker in CI
// In the consumer's CI pipeline after tests run:
// dotnet pact-broker publish ./pacts \
//   --broker-base-url https://your-pact-broker.com \
//   --broker-token $PACT_BROKER_TOKEN \
//   --consumer-app-version $GIT_SHA \
//   --tag $BRANCH_NAME

// Can I deploy check before deploying:
// dotnet pact-broker can-i-deploy \
//   --pacticipant payments-service \
//   --version $GIT_SHA \
//   --to-environment production \
//   --broker-base-url https://your-pact-broker.com
```

---

## Real World Example

A payments service calls the orders service to validate that an order exists and is in a `Pending` state before charging a customer. The orders team is refactoring their API — they're adding pagination, renaming a field from `customerId` to `customerRef`, and changing the date format. Without contract tests, the payments team discovers the breaking change when their staging environment starts returning 500 errors. With contract tests, the orders team's provider verification fails before they can merge the rename.

```csharp
// payments-service consumer test (discovers the breaking change)
public class OrderValidationConsumerTests : IDisposable
{
    private readonly IPactBuilderV4 _pactBuilder;

    public OrderValidationConsumerTests()
    {
        var pact = Pact.V4("payments-service", "orders-service",
            new PactConfig { PactDir = "./pacts" });
        _pactBuilder = pact.WithHttpInteractions();
    }

    [Fact]
    public async Task ValidateOrder_PendingOrder_ReturnsValidatable()
    {
        _pactBuilder
            .UponReceiving("a validation request for order 42")
            .Given("order 42 is pending")
            .WithRequest(HttpMethod.Get, "/api/orders/42")
            .WillRespond()
            .WithStatus(HttpStatusCode.OK)
            .WithJsonBody(new
            {
                id         = Match.Integer(42),
                customerId = Match.Type("cust-001"),  // ← consumer expects "customerId"
                status     = Match.Type("Pending"),
                total      = Match.Decimal(150.0)
            });

        await _pactBuilder.VerifyAsync(async ctx =>
        {
            var client        = new HttpClient { BaseAddress = ctx.MockServerUri };
            var orderClient   = new OrderValidationClient(client);
            var validationResult = await orderClient.ValidateAsync(42);

            validationResult.IsValid.Should().BeTrue();
            validationResult.CustomerId.Should().NotBeNullOrEmpty();
        });
    }
}

// When the orders team renames "customerId" → "customerRef" in their provider:
// Their provider verification test fails with:
// "Expected body: { customerId: ... } Actual body: { customerRef: ... }"
// The breaking change is caught before deployment — the orders team must either
// maintain the old field name or coordinate the change with the payments team.
```

*This is the specific scenario contract testing was built for. The orders team wouldn't know the field name matters to the payments team without a contract — and the payments team wouldn't find out the field was renamed until runtime in a shared environment.*

---

## Common Misconceptions

**"Contract tests replace integration tests."**
Contract tests verify the *interface* — the shape of requests and responses. Integration tests verify the *behavior* — does the business logic execute correctly when the two services communicate. Both are necessary. A provider can pass all contract tests and still have a bug in what it does with the request.

**"The provider just needs to return the right JSON shape."**
Provider state matters as much as response shape. If the consumer says "given order 1 exists" and the provider's state setup doesn't create order 1, the verification passes trivially because the endpoint returns 200 with whatever happens to be seeded. Always verify that provider state setup is correct and that tests are not false-positives.

**"We need Pactflow to use PactNet."**
You can store pact files in source control and use local file verification during development. Pactflow (or a self-hosted Pact Broker) is needed for the full workflow: publishing results, "can I deploy?" gates, and automatic cross-team pact sharing. Local file-based pacts work fine for a single team managing both consumer and provider.

---

## Gotchas

- **Consumer pact tests run against a mock server, not the real provider.** The consumer test passes as long as the consumer code handles the *defined* response correctly. It does not test what the provider actually returns — that's the provider's job.

- **Provider state endpoints must clean up after themselves.** If "order 1 exists" seeds data and the next pact interaction is "order 1 does not exist," the state endpoint must delete the row. Shared state between provider state setups causes non-deterministic verification results.

- **Matchers in the pact file must be used deliberately.** `Match.Type("Pending")` means "this field must be a string" — the actual value is ignored during provider verification. Using `Match.Type()` everywhere defeats the purpose; use it only for fields that legitimately vary (IDs, timestamps, generated values). Use exact matching for enumerated values like status codes.

- **PactNet 4.x is a complete rewrite of 3.x.** Most online tutorials are for 3.x. The 4.x API uses `IPactBuilderV4`, `Match.*` methods, and `VerifyAsync` — not the old `PactBuilder`, `IMockProviderService`, or `IPactVerifier` classes.

- **"Can I deploy?" only works if both consumer and provider publish verification results to the broker.** If the provider team hasn't set up broker integration, the consumer gets no protection from the gate.

---

## Interview Angle

**What they're really testing:** Whether you understand the specific problem contract testing solves — catching API breaking changes between microservices before deployment — and whether you can articulate when it's worth the setup cost.

**Common question forms:**
- *"How do you prevent breaking changes in a microservices API?"*
- *"What's the difference between contract testing and integration testing?"*
- *"Have you used Pact? How does it work?"*

**The depth signal:** A junior says "we have integration tests in a shared staging environment." A senior explains the specific failure mode that contract tests address — provider team renames a field, consumer doesn't find out until staging — and can describe the consumer/provider split: consumer generates pact, provider verifies it independently, broker connects the two. They know provider state is as important as the request/response shape, understand that matchers should be deliberate (not `Match.Type()` everywhere), and can explain the "can I deploy?" gate and why it requires both sides to publish results.

**Follow-up questions to expect:**
- *"Who owns the pact file?"* — The consumer owns it; they define what they need. The provider verifies that they satisfy it. This is consumer-driven contract testing.
- *"What happens if the provider needs to make a breaking change?"* — The provider's verification fails. The provider team must either coordinate a versioned change with the consumer (consumer updates their pact first), or maintain backwards compatibility.

---

## Related Topics

- [[dotnet/testing/testing-integration-tests.md]] — Contract tests complement integration tests; they test the interface, not the behavior.
- [[dotnet/testing/testing-unit-tests.md]] — Consumer pact tests run at unit test speed against a mock server; they fit naturally alongside unit tests.
- [[devops/ci-pipeline.md]] — "Can I deploy?" gates in CI are the primary value driver for the Pact Broker; the pipeline integration is what makes contract testing operational.
- [[system-design/communication-patterns/rest-vs-grpc.md]] — Contract testing is most common with REST APIs; gRPC has built-in schema enforcement via proto files.

---

## Source

https://docs.pact.io

---
*Last updated: 2026-04-12*