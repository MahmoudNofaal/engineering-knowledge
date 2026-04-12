# Testcontainers in .NET

> Testcontainers spins up real Docker containers — SQL Server, Redis, RabbitMQ — inside your test run, so integration tests hit actual infrastructure instead of fakes.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Library that starts/stops Docker containers programmatically during tests |
| **Use when** | Integration tests need production-fidelity — same engine, same behavior |
| **Avoid when** | CI has no Docker daemon; or SQLite is acceptable for your query profile |
| **Key packages** | `Testcontainers.MsSql`, `Testcontainers.Redis`, `Testcontainers.RabbitMq` |
| **Key types** | `MsSqlContainer`, `RedisContainer`, `IAsyncLifetime`, `WebApplicationFactory<T>` |
| **Requires** | Docker Desktop (local) or Docker daemon on CI agent |

---

## When To Use It
Use it when your integration tests need to behave exactly like production — same SQL Server engine, same Redis eviction behavior, same message broker semantics. SQLite and in-memory fakes are faster but silently hide bugs that only surface against the real engine (JSON column support, specific index behavior, transaction isolation differences). Don't use it if your CI pipeline has no Docker daemon, or if your test suite is already slow and you need faster feedback — SQLite is an acceptable tradeoff for many scenarios.

---

## Core Concept
Testcontainers is a library that talks to the Docker socket on your machine (or CI agent) and starts a container when your test run begins. It hands you back a connection string pointing at that container. You wire that connection string into your `WebApplicationFactory` DI override, run your tests against real infrastructure, then Testcontainers tears the container down when the test run finishes.

The key design decision is lifecycle. If you use `IClassFixture`, the container is shared across all tests in a class — fast, but state bleeds between tests. If you use `IAsyncLifetime` per test, you get a fresh container per test — perfectly isolated, but a 10–15 second startup penalty per test is unacceptable. The right answer for most teams is **one container per test class** with explicit data cleanup between tests in `DisposeAsync`, not per-container teardown.

For developer machines, set `Reuse = true` in the container builder — Testcontainers skips teardown between runs and reuses the container across sessions, reducing the startup hit to near zero after the first run.

---

## Version History

| Package / Feature | Version | What changed |
|---|---|---|
| Testcontainers for .NET | 1.x | Initial .NET port of the Java library |
| Testcontainers for .NET | 2.0 | Full async API; `IAsyncLifetime` support |
| Testcontainers for .NET | 3.0 | Module packages split: `Testcontainers.MsSql`, `.Redis`, `.RabbitMq` etc. |
| Testcontainers for .NET | 3.x | `WithReuse(true)` for container session reuse |
| `MsSqlBuilder` | 3.x | Fluent builder replaces direct `ContainerBuilder<MsSqlTestcontainer>` |
| Docker Desktop | — | Requires license for commercial use on teams > 250 people or revenue > $10M |

*The Docker Desktop licensing change (2022) is worth knowing — large organisations need a paid Docker Desktop license. Alternatives like Rancher Desktop or Podman work as the container runtime for Testcontainers as long as the socket path is configured correctly.*

---

## Performance

| Scenario | Startup time | Per-test overhead | Notes |
|---|---|---|---|
| First run (image pull) | 60–120s | — | One-time per image; cached after |
| Container start (image cached) | 8–15s | — | SQL Server health check takes ~5s |
| Container start with `WithReuse(true)` | < 1s | — | Skips teardown; reuses running container |
| Per-test cleanup (data delete) | 50–200ms | — | Much faster than restarting container |
| Multiple containers in parallel | +2–5s | — | `Task.WhenAll` for parallel startup |

**Allocation behaviour:** Each container is a Docker process — no .NET heap cost beyond the connection. The container itself consumes 500MB–1GB RAM for SQL Server; Redis and RabbitMQ are lighter (~50–200MB each). On developer machines with multiple test projects running containers, memory can become a constraint.

**Parallelisation:** xUnit runs test collections in parallel by default. Two test classes each starting their own `MsSqlContainer` get different Docker-assigned host ports automatically — they don't conflict. But two test classes *sharing* a container fixture via `ICollectionFixture` run sequentially for that shared resource. Deliberate serialisation via `[Collection("db-tests")]` is safer than relying on automatic port assignment not to race.

---

## The Code

```csharp
// Setup
// dotnet add package Testcontainers.MsSql
// dotnet add package Testcontainers.Redis
// dotnet add package Testcontainers.RabbitMq
// dotnet add package Microsoft.AspNetCore.Mvc.Testing
// dotnet add package FluentAssertions
```

```csharp
// 1. SQL Server container fixture — one container per test class
public class SqlServerFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .WithPassword("Strong!Passw0rd")
        .Build();

    public string ConnectionString => _container.GetConnectionString();

    public Task InitializeAsync() => _container.StartAsync();
    public Task DisposeAsync()    => _container.DisposeAsync().AsTask();
}
```

```csharp
// 2. WebApplicationFactory that owns the container — clean single fixture
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

        // Run migrations once after container is ready
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
```

```csharp
// 3. Test class — shared container, explicit state cleanup between tests
public class OrdersApiTests : IClassFixture<ApiFactory>, IAsyncLifetime
{
    private readonly HttpClient _client;
    private readonly AppDbContext _db;
    private readonly IServiceScope _scope;

    public OrdersApiTests(ApiFactory factory)
    {
        _client = factory.CreateClient();
        _scope  = factory.Services.CreateScope();
        _db     = _scope.ServiceProvider.GetRequiredService<AppDbContext>();
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public async Task DisposeAsync()
    {
        // Wipe data without restarting the container
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

    [Fact]
    public async Task GetOrder_NonExistentId_Returns404()
    {
        var response = await _client.GetAsync("/api/orders/9999");
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }
}
```

```csharp
// 4. Redis container — for testing caching behaviour
public class RedisFixture : IAsyncLifetime
{
    private readonly RedisContainer _container = new RedisBuilder().Build();

    public string ConnectionString => _container.GetConnectionString();

    public Task InitializeAsync() => _container.StartAsync();
    public Task DisposeAsync()    => _container.DisposeAsync().AsTask();
}

// Wire into factory DI override
services.AddStackExchangeRedisCache(options =>
    options.Configuration = redisFixture.ConnectionString);
```

```csharp
// 5. Multiple containers — start in parallel to save startup time
public class IntegrationApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly MsSqlContainer   _db     = new MsSqlBuilder().Build();
    private readonly RabbitMqContainer _rabbit = new RabbitMqBuilder().Build();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            ReplaceDbContext(services, _db.GetConnectionString());
            ReplaceRabbitMq(services, _rabbit.GetConnectionString());
        });
    }

    public async Task InitializeAsync()
    {
        // Start containers in parallel — saves 10–15 seconds vs sequential
        await Task.WhenAll(_db.StartAsync(), _rabbit.StartAsync());

        using var scope = Services.CreateScope();
        await scope.ServiceProvider
            .GetRequiredService<AppDbContext>()
            .Database.MigrateAsync();
    }

    public new async Task DisposeAsync()
    {
        await Task.WhenAll(_db.DisposeAsync().AsTask(), _rabbit.DisposeAsync().AsTask());
        await base.DisposeAsync();
    }

    private static void ReplaceDbContext(IServiceCollection services, string connStr)
    {
        var d = services.SingleOrDefault(
            x => x.ServiceType == typeof(DbContextOptions<AppDbContext>));
        if (d is not null) services.Remove(d);
        services.AddDbContext<AppDbContext>(o => o.UseSqlServer(connStr));
    }

    private static void ReplaceRabbitMq(IServiceCollection services, string connStr)
    {
        // Replace IBus or IConnection depending on your messaging library
        var d = services.SingleOrDefault(x => x.ServiceType == typeof(IConnection));
        if (d is not null) services.Remove(d);
        services.AddSingleton<IConnection>(_ =>
            ConnectionFactory.CreateConnection(connStr));
    }
}
```

```csharp
// 6. Container reuse for developer machines — skip teardown between runs
private readonly MsSqlContainer _container = new MsSqlBuilder()
    .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
    .WithPassword("Strong!Passw0rd")
    .WithReuse(true)     // container survives test session; reused on next run
    .Build();
```

---

## Real World Example

A payments platform runs a test suite that exercises the full payment processing pipeline: HTTP request comes in, idempotency is checked in Redis, the payment is persisted in SQL Server, and a message is published to RabbitMQ for downstream processing. All three external systems need to be real — SQLite can't test the Redis TTL behavior, an in-memory queue can't test RabbitMQ routing keys, and the SQL Server-specific `ROWVERSION` concurrency token on the `Payment` table doesn't exist in SQLite.

```csharp
[Collection("payments-infra")]
public class PaymentPipelineTests : IClassFixture<PaymentsInfraFactory>, IAsyncLifetime
{
    private readonly HttpClient _client;
    private readonly AppDbContext _db;
    private readonly IConnection _rabbit;
    private readonly IDatabase _redis;
    private readonly IServiceScope _scope;

    public PaymentPipelineTests(PaymentsInfraFactory factory)
    {
        _client = factory.CreateClient();
        _scope  = factory.Services.CreateScope();
        _db     = _scope.ServiceProvider.GetRequiredService<AppDbContext>();
        _rabbit = _scope.ServiceProvider.GetRequiredService<IConnection>();
        _redis  = _scope.ServiceProvider.GetRequiredService<IDatabase>();
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public async Task DisposeAsync()
    {
        _db.Payments.RemoveRange(_db.Payments);
        await _db.SaveChangesAsync();
        await _redis.ExecuteAsync("FLUSHDB");  // clear Redis between tests
        _scope.Dispose();
    }

    [Fact]
    public async Task ProcessPayment_FirstRequest_PersistsAndPublishesMessage()
    {
        var idempotencyKey = Guid.NewGuid().ToString();
        var payload = new
        {
            FromAccount    = "acc-001",
            ToAccount      = "acc-002",
            Amount         = 100m,
            IdempotencyKey = idempotencyKey
        };

        var response = await _client.PostAsJsonAsync("/api/payments", payload);

        response.StatusCode.Should().Be(HttpStatusCode.Created);

        // Assert SQL Server persistence (ROWVERSION concurrency token is SQL Server-only)
        var payment = await _db.Payments.SingleAsync(p => p.IdempotencyKey == idempotencyKey);
        payment.RowVersion.Should().NotBeNull();  // would not exist in SQLite

        // Assert Redis idempotency key was cached
        var cached = await _redis.StringGetAsync($"idem:{idempotencyKey}");
        cached.HasValue.Should().BeTrue();

        // Assert RabbitMQ message was published
        using var channel = _rabbit.CreateModel();
        var result = channel.BasicGet("payments.processed", autoAck: true);
        result.Should().NotBeNull();
    }

    [Fact]
    public async Task ProcessPayment_DuplicateKey_ReturnsCachedResponse()
    {
        var idempotencyKey = "fixed-key-001";
        var payload = new { FromAccount = "acc-001", ToAccount = "acc-002",
                            Amount = 50m, IdempotencyKey = idempotencyKey };

        var first  = await _client.PostAsJsonAsync("/api/payments", payload);
        var second = await _client.PostAsJsonAsync("/api/payments", payload);

        first.StatusCode.Should().Be(HttpStatusCode.Created);
        second.StatusCode.Should().Be(HttpStatusCode.OK);  // cached replay

        _db.Payments.Count(p => p.IdempotencyKey == idempotencyKey).Should().Be(1);
    }
}
```

*The `ROWVERSION` assertion is the concrete example of why SQLite wouldn't work here — it's a SQL Server-specific concurrency feature that doesn't translate to SQLite. Any test suite for a SQL Server–backed system with optimistic concurrency needs Testcontainers to validate it correctly.*

---

## Common Misconceptions

**"One Testcontainers container per test gives perfect isolation."**
True isolation, catastrophic performance. Starting a SQL Server container takes 8–15 seconds. With 50 tests, that's 7–12 minutes of pure container startup time. The correct pattern is one container per test *class* with fast data cleanup (delete rows) between tests. Row deletion takes 10–100ms vs 10,000ms for a container restart.

**"Testcontainers tests are too slow for CI — only run them locally."**
The startup cost is fixed per container, not per test. 50 integration tests against one shared container class fixture adds 10–15 seconds to the CI run total, not 10–15 seconds per test. That's acceptable. What's not acceptable is mixing them into the same `dotnet test` invocation as unit tests — they need their own project and their own CI step.

**"The container is ready as soon as `StartAsync()` returns."**
Testcontainers waits for the container's health check before returning from `StartAsync()`. But SQL Server specifically takes a few extra seconds after the health check passes before it accepts connections reliably. `MigrateAsync()` called immediately after `StartAsync()` sometimes fails with a connection refused error on the first attempt. Build in a retry policy on the migration call, or add `.WithWaitStrategy(Wait.ForUnixContainer().UntilCommandIsCompleted("/opt/mssql-tools/bin/sqlcmd..."))` to the builder.

---

## Gotchas

- **Container startup takes 5–15 seconds per image pull.** On the first run, Docker pulls the image. Subsequent runs use the cached layer — much faster. Pin the image tag (`2022-latest` vs `2022-CU12`) to avoid unexpected pulls on CI.

- **`IClassFixture` shares one container but xUnit creates a new test class instance per test.** The container stays up; the `HttpClient` and `DbContext` are re-created per test. Any data written in test A is visible to test B unless you explicitly clean up. The `DisposeAsync()` cleanup pattern is mandatory, not optional.

- **`MigrateAsync()` inside `InitializeAsync()` must happen after the container is fully ready.** If it fails with connection refused, add a `WaitStrategy` or a retry policy to the container builder.

- **Parallel test collections sharing a container cause port conflicts or concurrency issues.** Use `[Collection("db-tests")]` to serialise collections that share a container fixture.

- **`Program` must be `public partial class Program { }` for `WebApplicationFactory<Program>` to compile.** Minimal API apps in .NET 6+ generate `Program` as an internal class. Without the partial declaration at the bottom of `Program.cs`, the test project gets a compile error.

- **Docker Desktop requires a commercial license for large organisations.** Rancher Desktop and Podman are free alternatives that work with Testcontainers as long as the socket path is configured: `builder.WithDockerEndpoint("unix:///var/run/docker.sock")`.

---

## Interview Angle

**What they're really testing:** Whether you understand the tradeoff between test fidelity and speed, and can articulate *why* a real container catches bugs that SQLite or in-memory fakes miss.

**Common question forms:**
- *"How do you handle the database in integration tests?"*
- *"What are the tradeoffs between SQLite in-memory and a real database for testing?"*
- *"How do you make integration tests fast enough to run in CI?"*

**The depth signal:** A junior says "use an in-memory database so tests are fast." A senior knows that SQLite silently masks SQL Server-specific behaviors — JSON column queries, collation rules, `ROWVERSION` concurrency tokens, certain index types — and can name a specific case where this burned them or their team. They structure the fixture with one container per class (not per test), clean state between tests without restarting the container, start multiple containers in parallel with `Task.WhenAll`, and know the `Program` partial class requirement by heart because they've hit the compile error before.

**Follow-up questions to expect:**
- *"How do you handle the 10-second SQL Server startup in CI?"* — One container per test class shared via `IClassFixture`; startup is paid once, not per test. Separate CI job for integration tests so unit tests aren't blocked.
- *"What's `WithReuse(true)`?"* — Skips teardown between test sessions; the container stays running on the developer machine and is reused on the next run, reducing startup to near zero.

---

## Related Topics

- [[dotnet/testing/testing-integration-tests.md]] — Testcontainers is the infrastructure layer under integration tests; understanding the full `WebApplicationFactory` setup is a prerequisite.
- [[dotnet/testing/testing-test-isolation.md]] — Data cleanup between tests without restarting the container is the critical isolation pattern; alternatives include transaction rollback.
- [[dotnet/ef/ef-transactions.md]] — An alternative isolation strategy to cleanup-in-DisposeAsync is wrapping each test in a transaction and rolling back; both approaches work with real containers.
- [[devops/docker-fundamentals.md]] — Testcontainers talks directly to the Docker socket; understanding Docker images, layers, and health checks explains why startup time varies and how to tune it.
- [[dotnet/testing/testing-unit-tests.md]] — Testcontainers tests are slow by design; knowing what belongs in unit tests vs integration tests keeps the suite fast where it can be.

---

## Source

https://dotnet.testcontainers.org

---
*Last updated: 2026-04-12*