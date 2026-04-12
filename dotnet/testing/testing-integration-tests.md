# Integration Testing in .NET

> An integration test verifies that real components work correctly together — real HTTP stack, real database, real DI container — not fakes.

---

## Quick Reference

| | |
|---|---|
| **What it is** | End-to-end test of real wired components via HTTP |
| **Use when** | Verifying routing, middleware, DI wiring, SQL queries, serialization |
| **Avoid when** | Testing isolated logic — unit tests are faster and more precise |
| **Framework** | xUnit + `Microsoft.AspNetCore.Mvc.Testing` |
| **Key packages** | `Microsoft.AspNetCore.Mvc.Testing`, `Testcontainers.MsSql`, `FluentAssertions` |
| **Key types** | `WebApplicationFactory<T>`, `IClassFixture<T>`, `IAsyncLifetime` |

---

## When To Use It
Use integration tests for the paths that matter most end-to-end: an HTTP request hits a controller, passes through middleware, executes a handler, writes to a database, and returns a response. They catch bugs that unit tests structurally can't — misconfigured DI, wrong SQL queries, middleware ordering errors, serialization mismatches. Don't replace unit tests with integration tests — they're slower, harder to parallelise, and less precise about *where* a failure is. Use both: unit tests for logic, integration tests for wiring.

---

## Core Concept
ASP.NET Core ships `WebApplicationFactory<T>` — a test helper that spins up your entire application in memory, with the real DI container, real middleware pipeline, and a real (but in-memory) HTTP client. You write tests that send HTTP requests through `HttpClient` and assert on the response — status code, body, headers. For the database you have two options: use a real SQL Server instance (via Testcontainers, which spins up Docker), or swap the real database for an in-memory SQLite instance registered in the test's DI override. Testcontainers is more accurate; SQLite is faster. The right choice depends on how much your queries rely on SQL Server-specific behavior. Either way, each test class gets a fresh database state by running migrations before tests and wrapping each test in a transaction that rolls back, or by clearing the database in `DisposeAsync`.

The most common bug with integration tests is **shared factory state causing test bleed**. `IClassFixture<WebApplicationFactory<T>>` shares one factory across all tests in a class — if test A inserts a row and test B queries all rows, B sees A's data. This is the reason test isolation requires explicit cleanup or transaction rollback between tests, not just between test *classes*.

The second common issue is the `Program` visibility problem. `WebApplicationFactory<Program>` needs to reference the app's entry point class, which in .NET 6+ minimal APIs is a compiler-generated internal class. Adding `public partial class Program { }` at the bottom of `Program.cs` exposes it to the test project.

---

## Version History

| Package / Feature | Version | What changed |
|---|---|---|
| `WebApplicationFactory<T>` | ASP.NET Core 2.1 | Introduced — replaced custom `TestServer` setup |
| `IAsyncLifetime` | xUnit 2.x | Enabled async `InitializeAsync`/`DisposeAsync` per test class |
| Minimal API `Program` | .NET 6 | `Program` became internal; requires `public partial class Program {}` workaround |
| `WebApplicationFactory` | .NET 6+ | Works with both controller-based and minimal API apps with no changes |
| Testcontainers for .NET | 3.x | Full async API, `MsSqlBuilder`, `RedisBuilder`, `RabbitMqBuilder` |
| `TimeProvider` | .NET 8 | Replaces `IClock` abstractions for time-dependent integration tests |

*The `public partial class Program {}` workaround has been needed since .NET 6 minimal APIs. It is still required in .NET 8+ unless the test project explicitly references the `InternalsVisibleTo` attribute.*

---

## Performance

| Test type | Typical startup | Per-test overhead | Notes |
|---|---|---|---|
| WebApplicationFactory + SQLite | 1–3s | < 50ms | Fast but SQLite masks SQL Server bugs |
| WebApplicationFactory + Testcontainers | 8–20s first run | < 100ms | Docker pull on first run; reuse across class |
| Testcontainers with container reuse | 1–2s | < 100ms | `Reuse = true` skips teardown between runs |
| Full suite (50 integration tests) | 30–90s | — | Normal range; integration tests are slow by design |

**Allocation behaviour:** Each `WebApplicationFactory` instance builds the full DI container and middleware pipeline — this is not cheap. Share one factory per test class via `IClassFixture`, not one per test. Testcontainers containers survive for the lifetime of the class fixture; the container itself isn't torn down between individual tests.

**Parallelisation:** Integration tests should run in a dedicated `[Collection]` to prevent two test classes from sharing the same database container and causing deadlocks. Add `[Collection("integration")]` to all integration test classes and a matching `[CollectionDefinition("integration")]` assembly-level class to disable cross-class parallelism.

---

## The Code

```csharp
// Setup
// dotnet add package Microsoft.AspNetCore.Mvc.Testing
// dotnet add package Testcontainers.MsSql          ← for real SQL Server in Docker
// dotnet add package Microsoft.EntityFrameworkCore.Sqlite  ← for SQLite alternative
// dotnet add package FluentAssertions

// In Program.cs (bottom of file) — required for WebApplicationFactory<Program> to compile
public partial class Program { }
```

```csharp
// 1. Basic WebApplicationFactory — minimal in-memory integration test
public class OrdersApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public OrdersApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetOrders_ReturnsOk()
    {
        var response = await _client.GetAsync("/api/orders");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
```

```csharp
// 2. Custom factory — override DI registrations, swap real DB for SQLite
public class TestWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Remove the real DbContext registration
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor is not null)
                services.Remove(descriptor);

            // Named shared in-memory SQLite — same connection for app and seed code
            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlite("DataSource=testdb;Mode=Memory;Cache=Shared"));
        });
    }
}
```

```csharp
// 3. Database seeding and migration per test class
public class OrdersApiTests : IClassFixture<TestWebApplicationFactory>, IAsyncLifetime
{
    private readonly HttpClient _client;
    private readonly AppDbContext _db;
    private readonly IServiceScope _scope;

    public OrdersApiTests(TestWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
        _scope  = factory.Services.CreateScope();
        _db     = _scope.ServiceProvider.GetRequiredService<AppDbContext>();
    }

    public async Task InitializeAsync()
    {
        await _db.Database.EnsureCreatedAsync();
        _db.Orders.Add(new Order { Id = 1, Total = 99m, Status = OrderStatus.Pending });
        await _db.SaveChangesAsync();
    }

    public async Task DisposeAsync()
    {
        await _db.Database.EnsureDeletedAsync();
        _scope.Dispose();
    }

    [Fact]
    public async Task GetOrder_ExistingId_ReturnsOrder()
    {
        var response = await _client.GetAsync("/api/orders/1");
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var body = await response.Content.ReadFromJsonAsync<OrderDto>();
        body!.Total.Should().Be(99m);
    }
}
```

```csharp
// 4. Testcontainers — real SQL Server in Docker per test run
public class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly MsSqlContainer _db = new MsSqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .WithPassword("Strong!Passw0rd")
        .Build();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor is not null) services.Remove(descriptor);

            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlServer(_db.GetConnectionString()));
        });
    }

    public async Task InitializeAsync()
    {
        await _db.StartAsync();

        using var scope = Services.CreateScope();
        var ctx = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await ctx.Database.MigrateAsync();
    }

    public new async Task DisposeAsync()
    {
        await _db.DisposeAsync();
        await base.DisposeAsync();
    }
}

public class OrdersIntegrationTests : IClassFixture<ApiFactory>, IAsyncLifetime
{
    private readonly HttpClient _client;
    private readonly AppDbContext _db;
    private readonly IServiceScope _scope;

    public OrdersIntegrationTests(ApiFactory factory)
    {
        _client = factory.CreateClient();
        _scope  = factory.Services.CreateScope();
        _db     = _scope.ServiceProvider.GetRequiredService<AppDbContext>();
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public async Task DisposeAsync()
    {
        _db.Orders.RemoveRange(_db.Orders);
        await _db.SaveChangesAsync();
        _scope.Dispose();
    }

    [Fact]
    public async Task PlaceOrder_ValidPayload_Returns201AndPersists()
    {
        var payload = new { CustomerId = 1, Total = 150m };

        var response = await _client.PostAsJsonAsync("/api/orders", payload);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        _db.Orders.Should().ContainSingle(o => o.Total == 150m);
    }
}
```

```csharp
// 5. Authenticating requests — bypass or simulate auth
public class AuthenticatedFactory : TestWebApplicationFactory
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        base.ConfigureWebHost(builder);

        builder.ConfigureServices(services =>
        {
            services.AddAuthentication("Test")
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                    "Test", _ => { });
        });
    }
}

public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public TestAuthHandler(IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger, UrlEncoder encoder)
        : base(options, logger, encoder) { }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = new[]
        {
            new Claim(ClaimTypes.Name, "testuser"),
            new Claim(ClaimTypes.Role, "Admin"),
            new Claim("sub", "user-123")
        };
        var identity  = new ClaimsIdentity(claims, "Test");
        var principal = new ClaimsPrincipal(identity);
        var ticket    = new AuthenticationTicket(principal, "Test");
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

```csharp
// 6. Asserting on response bodies — BeEquivalentTo with exclusions
[Fact]
public async Task GetOrder_ExistingId_ReturnsCorrectShape()
{
    var response = await _client.GetAsync("/api/orders/1");
    response.StatusCode.Should().Be(HttpStatusCode.OK);

    var body = await response.Content.ReadFromJsonAsync<OrderDto>();

    body.Should().BeEquivalentTo(new
    {
        Total  = 99m,
        Status = "Pending"
    }, options => options
        .Excluding(o => o.Id)          // generated ID — unpredictable
        .Excluding(o => o.CreatedAt)); // timestamp — use BeCloseTo instead
    body!.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(30));
}
```

---

## Real World Example

A financial services API exposes a `POST /api/payments` endpoint that validates the payload, checks that the payer account has sufficient funds, persists the payment record, and returns `201 Created` with a `Location` header pointing to the new resource. Several middleware components are in the path: request logging, an idempotency key check, and a custom exception handler that maps domain exceptions to RFC 7807 problem details. Unit tests cover the individual domain rules; integration tests cover whether all of that actually works together over a real HTTP call.

```csharp
[Collection("payments-integration")]
public class PaymentsApiTests : IClassFixture<PaymentsApiFactory>, IAsyncLifetime
{
    private readonly HttpClient _client;
    private readonly AppDbContext _db;
    private readonly IServiceScope _scope;

    public PaymentsApiTests(PaymentsApiFactory factory)
    {
        _client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false    // test redirects explicitly
        });
        _scope = factory.Services.CreateScope();
        _db    = _scope.ServiceProvider.GetRequiredService<AppDbContext>();
    }

    public async Task InitializeAsync()
    {
        _db.Accounts.Add(new Account { Id = "acc-001", Balance = 500m });
        await _db.SaveChangesAsync();
    }

    public async Task DisposeAsync()
    {
        _db.Payments.RemoveRange(_db.Payments);
        _db.Accounts.RemoveRange(_db.Accounts);
        await _db.SaveChangesAsync();
        _scope.Dispose();
    }

    [Fact]
    public async Task PostPayment_ValidRequest_Returns201WithLocation()
    {
        var payload = new
        {
            FromAccountId = "acc-001",
            ToAccountId   = "acc-002",
            Amount        = 100m,
            Currency      = "GBP",
            IdempotencyKey = Guid.NewGuid().ToString()
        };

        var response = await _client.PostAsJsonAsync("/api/payments", payload);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        response.Headers.Location.Should().NotBeNull();
        response.Headers.Location!.ToString().Should().StartWith("/api/payments/");
    }

    [Fact]
    public async Task PostPayment_InsufficientFunds_Returns422WithProblemDetails()
    {
        var payload = new
        {
            FromAccountId = "acc-001",
            ToAccountId   = "acc-002",
            Amount        = 1000m,     // more than the 500m balance
            Currency      = "GBP",
            IdempotencyKey = Guid.NewGuid().ToString()
        };

        var response = await _client.PostAsJsonAsync("/api/payments", payload);
        var problem  = await response.Content.ReadFromJsonAsync<ProblemDetails>();

        response.StatusCode.Should().Be(HttpStatusCode.UnprocessableEntity);
        problem!.Title.Should().Contain("Insufficient funds");
    }

    [Fact]
    public async Task PostPayment_DuplicateIdempotencyKey_Returns200NotDuplicate()
    {
        var payload = new
        {
            FromAccountId  = "acc-001",
            ToAccountId    = "acc-002",
            Amount         = 50m,
            Currency       = "GBP",
            IdempotencyKey = "idem-key-fixed"
        };

        var first  = await _client.PostAsJsonAsync("/api/payments", payload);
        var second = await _client.PostAsJsonAsync("/api/payments", payload);

        first.StatusCode.Should().Be(HttpStatusCode.Created);
        second.StatusCode.Should().Be(HttpStatusCode.OK);  // idempotent replay
        _db.Payments.Count(p => p.IdempotencyKey == "idem-key-fixed").Should().Be(1);
    }
}
```

*The idempotency key test is the kind of thing that only an integration test can catch — it verifies that the middleware check, the database query, and the response shaping all cooperate correctly. A unit test on the idempotency service alone would miss the HTTP response code difference between a first request and a replay.*

---

## Common Misconceptions

**"Integration tests are just slower unit tests — the same thing but heavier."**
They test structurally different things. A unit test cannot catch a misconfigured DI registration, a missing middleware, a SQL query that returns wrong data, or a serialization mismatch between your DTO and your JSON contract. Those categories of bug are invisible to unit tests and only surface when real components run together. The two test types are complements, not substitutes.

**"I can share one `WebApplicationFactory` across all my test classes to save startup time."**
The startup cost is a one-time penalty per fixture instance, and `IClassFixture<T>` already amortises it across all tests in a class. Sharing across classes via a collection fixture introduces state coupling — test class A's database writes are visible to test class B unless you're very careful. The tradeoff of faster startup vs harder-to-debug test bleed is usually not worth it. One factory per class is the right default.

**"SQLite is fine for all integration tests — it's nearly the same as SQL Server."**
SQLite silently swallows queries that SQL Server would reject: certain JSON column queries, `ROWVERSION` concurrency tokens, specific collations, computed columns, some index types, and implicit type conversions differ meaningfully. If your app uses any SQL Server-specific feature, SQLite tests will pass while production has a bug. Use SQLite for fast feedback in CI; add a Testcontainers-based suite that runs on SQL Server for the paths that matter.

---

## Gotchas

- **`IClassFixture<WebApplicationFactory<T>>` shares one factory — database state bleeds between tests.** If test A inserts a row and test B queries all rows, B sees A's data. Delete and re-seed in `InitializeAsync`/`DisposeAsync`, or wrap each test in a transaction and roll back. Relying on test execution order to manage state is a trap.

- **SQLite in-memory databases are connection-scoped by default.** Each call to `UseSqlite("DataSource=:memory:")` opens a new connection and a new empty database. The `HttpClient` and your seeding code use different connections unless you use a named shared in-memory database: `"DataSource=testdb;Mode=Memory;Cache=Shared"`.

- **`Program` must be accessible from the test project.** `WebApplicationFactory<Program>` needs a reference to your app's entry point. In .NET 6+ minimal APIs, `Program` is a compiler-generated internal class. Add `public partial class Program { }` to the bottom of `Program.cs` to expose it.

- **Testcontainers requires Docker running on the test machine and CI agent.** If your CI pipeline doesn't have Docker available, Testcontainer tests fail at startup with a cryptic socket error, not a clear test failure. Always check CI Docker availability before committing Testcontainer-based tests.

- **`CreateClient()` follows redirects by default.** `WebApplicationFactory.CreateClient()` returns a client with `AllowAutoRedirect = true`. If you're testing redirect behavior (301, 302), create the client with `factory.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false })`.

- **Integration tests must live in their own project and their own CI stage.** Mixed with unit tests, one slow integration test doubles the feedback loop for every developer on every `dotnet test` run. Separate projects, separate CI jobs — unit tests on every PR push, integration tests on merge to main or on a scheduled pipeline.

---

## Interview Angle

**What they're really testing:** Whether you understand what integration tests actually cover that unit tests can't, and what the tradeoffs are between test fidelity and speed.

**Common question forms:**
- *"How do you test your API endpoints?"*
- *"What's the difference between a unit test and an integration test in .NET?"*
- *"How do you handle the database in integration tests?"*
- *"What bugs do integration tests catch that unit tests miss?"*

**The depth signal:** A junior says "spin up the app and call the endpoint with HttpClient." A senior knows `WebApplicationFactory<T>` specifically, explains the two database strategies (SQLite for speed, Testcontainers for fidelity) and when each is appropriate, handles test isolation explicitly (shared factory state is the most common integration test bug), knows how to override auth so protected endpoints can be tested without a real identity provider, tests redirect behavior by disabling auto-redirect, and understands that integration tests belong in their own project with their own CI stage — not mixed with unit tests — because they're an order of magnitude slower.

**Follow-up questions to expect:**
- *"What does `public partial class Program {}` do and why is it needed?"* — Exposes the compiler-generated minimal API entry point class so the test project can reference it as the generic type argument.
- *"How do you prevent test A's data from affecting test B?"* — Either delete/re-seed in `IAsyncLifetime` or wrap each test in an EF transaction and roll back; the latter is cleaner but requires understanding how EF tracks transaction scope.

---

## Related Topics

- [[dotnet/testing/testing-unit-tests.md]] — Integration tests verify wiring; unit tests verify logic — knowing the boundary determines which to write for a given scenario.
- [[dotnet/testing/testing-testcontainers.md]] — The infrastructure layer for real SQL Server in tests; Testcontainers is the production-fidelity alternative to SQLite.
- [[dotnet/testing/testing-mocking.md]] — Integration tests minimise mocking by design; where you draw the mock boundary determines whether a test is truly integration or a glorified unit test.
- [[dotnet/testing/testing-test-isolation.md]] — State bleed is the #1 integration test problem; isolation strategies belong in their own file.
- [[dotnet/ef/ef-transactions.md]] — Wrapping each integration test in a transaction and rolling back is the cleanest isolation strategy; understanding transactions is a prerequisite.
- [[devops/ci-pipeline.md]] — Integration tests with Testcontainers need Docker on the CI agent; pipeline configuration determines whether they run on every PR or only on main.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests

---
*Last updated: 2026-04-12*