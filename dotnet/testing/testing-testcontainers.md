# Testcontainers in .NET

> Testcontainers spins up real Docker containers — SQL Server, Redis, RabbitMQ — inside your test run, so integration tests hit actual infrastructure instead of fakes.

---

## When To Use It
Use it when your integration tests need to behave exactly like production — same SQL Server engine, same Redis eviction behavior, same message broker semantics. SQLite and in-memory fakes are faster but silently hide bugs that only surface against the real engine (JSON column support, specific index behavior, transaction isolation differences). Don't use it if your CI pipeline has no Docker daemon, or if your test suite is already slow and you need faster feedback — SQLite is an acceptable tradeoff for many scenarios.

---

## Core Concept
Testcontainers is a library that talks to the Docker socket on your machine (or CI agent) and starts a container when your test run begins. It hands you back a connection string pointing at that container. You wire that connection string into your `WebApplicationFactory` DI override, run your tests against real infrastructure, then Testcontainers tears the container down when the test run finishes. The key design decision is lifecycle: if you use `IClassFixture`, the container is shared across all tests in a class — fast, but state bleeds between tests. If you use `IAsyncLifetime` per test, you get a fresh container per test — perfectly isolated, but slow. The right answer for most teams is one container per test *class*, with explicit cleanup between tests rather than per-container teardown.

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

    public Task DisposeAsync() => _container.DisposeAsync().AsTask();
}
```
```csharp
// 2. WebApplicationFactory wired to the container connection string
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
            // Remove existing DbContext registration
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor is not null) services.Remove(descriptor);

            // Inject real SQL Server pointing at the container
            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlServer(_db.GetConnectionString()));
        });
    }

    public async Task InitializeAsync()
    {
        await _db.StartAsync();

        // Run migrations once after container is up
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
// 3. Test class using the factory — shared container, isolated state per test
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
        // Clean up between tests without restarting the container
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
// 4. Redis container — for testing caching behavior
public class RedisFixture : IAsyncLifetime
{
    private readonly RedisContainer _container = new RedisBuilder().Build();

    public string ConnectionString => _container.GetConnectionString();

    public Task InitializeAsync() => _container.StartAsync();
    public Task DisposeAsync()    => _container.DisposeAsync().AsTask();
}

// Wire into factory
services.AddStackExchangeRedisCache(options =>
    options.Configuration = redisFixture.ConnectionString);
```
```csharp
// 5. Multiple containers — compose SQL Server + RabbitMQ together
public class IntegrationApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly MsSqlContainer _db = new MsSqlBuilder().Build();
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
        // Start containers in parallel — saves startup time
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
        // Replace IBus or IConnection registration depending on your messaging library
    }
}
```

---

## Gotchas
- **Container startup takes 5–15 seconds per image pull.** On the first run, Docker pulls the image. Subsequent runs use the cached layer — much faster. On CI, pin the image tag (`2022-latest` vs `2022-CU12`) to avoid unexpected pulls breaking build times. Use `Reuse = true` in Testcontainers config to share containers across test sessions on developer machines.
- **`IClassFixture` shares one container but xUnit creates a new test class instance per test.** The container stays up; the `HttpClient` and `DbContext` are re-created per test. Any data written in test A is visible to test B unless you explicitly clean up. The `DisposeAsync()` cleanup pattern in example 3 is mandatory — not optional.
- **`MigrateAsync()` inside `InitializeAsync()` must happen after the container is fully ready.** Testcontainers waits for the container's health check before returning from `StartAsync()`, but SQL Server specifically takes a few extra seconds to accept connections after the health check passes. If `MigrateAsync()` fails with a connection refused, add a short `WaitStrategy` or a retry policy to the container builder.
- **Parallel test collections sharing a container cause port conflicts.** xUnit runs test collections in parallel by default. If two test classes each spin up their own `MsSqlContainer` simultaneously, Docker assigns different host ports automatically — that's fine. But if they share a fixture instance, concurrent schema operations can deadlock. Use `[Collection("db-tests")]` to serialize collections that share a container.
- **`Program` must be `public partial class Program { }` for `WebApplicationFactory<Program>` to compile.** Minimal API apps in .NET 6+ generate `Program` as an internal class. Without the partial declaration at the bottom of `Program.cs`, the test project can't reference it and the factory fails to compile — not a runtime error, a build error that looks confusing the first time.

---

## Interview Angle
**What they're really testing:** Whether you understand the tradeoff between test fidelity and speed, and can articulate *why* a real container catches bugs that SQLite or in-memory fakes miss.

**Common question form:** *"How do you handle the database in integration tests?"* or *"What are the tradeoffs between SQLite in-memory and a real database for testing?"*

**The depth signal:** A junior says "use an in-memory database so tests are fast." A senior knows that SQLite silently masks SQL Server-specific behaviors — JSON column queries, specific collation rules, `ROWVERSION` concurrency tokens, certain index types — and can name a specific case where this burned them or their team. They structure the fixture with one container per class (not per test), clean state between tests without restarting the container, start multiple containers in parallel with `Task.WhenAll`, and know the `Program` partial class requirement by heart because they've hit the compile error before.

---

## Related Topics
- [[dotnet/testing-integration-tests.md]] — Testcontainers is the infrastructure layer under integration tests; understanding the full `WebApplicationFactory` setup is a prerequisite.
- [[dotnet/ef-transactions.md]] — An alternative isolation strategy to cleanup-in-DisposeAsync is wrapping each test in a transaction and rolling back; both approaches work with real containers.
- [[devops/docker-fundamentals.md]] — Testcontainers talks directly to the Docker socket; understanding Docker images, layers, and health checks explains why startup time varies and how to tune it.
- [[dotnet/testing-unit-tests.md]] — Testcontainers tests are slow by design; knowing what belongs in unit tests vs integration tests keeps the suite fast where it can be.

---

## Source
https://dotnet.testcontainers.org

---
*Last updated: 2026-03-24*