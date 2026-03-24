# Integration Testing in .NET

> An integration test verifies that real components work correctly together — real HTTP stack, real database, real DI container — not fakes.

---

## When To Use It
Use integration tests for the paths that matter most end-to-end: an HTTP request hits a controller, passes through middleware, executes a handler, writes to a database, and returns a response. They catch bugs that unit tests structurally can't — misconfigured DI, wrong SQL queries, middleware ordering errors, serialization mismatches. Don't replace unit tests with integration tests — they're slower, harder to parallelize, and less precise about *where* a failure is. Use both: unit tests for logic, integration tests for wiring.

---

## Core Concept
ASP.NET Core ships `WebApplicationFactory<T>` — a test helper that spins up your entire application in memory, with the real DI container, real middleware pipeline, and a real (but in-memory) HTTP client. You write tests that send HTTP requests through `HttpClient` and assert on the response — status code, body, headers. For the database you have two options: use a real SQL Server instance (via Testcontainers, which spins up Docker), or swap the real database for an in-memory SQLite instance registered in the test's DI override. Testcontainers is more accurate; SQLite is faster. The right choice depends on how much your queries rely on SQL Server-specific behavior. Either way, each test class gets a fresh database state by running migrations before tests and wrapping each test in a transaction that rolls back.

---

## The Code
```csharp
// Setup
// dotnet add package Microsoft.AspNetCore.Mvc.Testing
// dotnet add package Testcontainers.MsSql          ← for real SQL Server in Docker
// dotnet add package Microsoft.EntityFrameworkCore.Sqlite  ← for SQLite alternative
// dotnet add package FluentAssertions
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
// 2. Custom factory — override DI registrations for tests
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

            // Register SQLite in-memory database instead
            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlite("DataSource=:memory:"));  // fresh DB per factory instance
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

    public OrdersApiTests(TestWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
        var scope = factory.Services.CreateScope();
        _db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    }

    public async Task InitializeAsync()
    {
        await _db.Database.EnsureCreatedAsync();             // run schema creation
        _db.Orders.Add(new Order { Id = 1, Total = 99m, Status = OrderStatus.Pending });
        await _db.SaveChangesAsync();
    }

    public async Task DisposeAsync() =>
        await _db.Database.EnsureDeletedAsync();             // clean up after all tests in class

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
public class SqlServerFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder().Build();

    public string ConnectionString => _container.GetConnectionString();

    public Task InitializeAsync() => _container.StartAsync();
    public Task DisposeAsync()    => _container.DisposeAsync().AsTask();
}

public class OrdersIntegrationTests
    : IClassFixture<SqlServerFixture>, IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public OrdersIntegrationTests(SqlServerFixture sql, WebApplicationFactory<Program> factory)
    {
        _client = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.Single(
                    d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
                services.Remove(descriptor);

                services.AddDbContext<AppDbContext>(options =>
                    options.UseSqlServer(sql.ConnectionString));  // real SQL Server
            });
        }).CreateClient();
    }

    [Fact]
    public async Task PlaceOrder_ValidPayload_Returns201()
    {
        var payload = new { CustomerId = 1, Total = 150m };
        var response = await _client.PostAsJsonAsync("/api/orders", payload);
        response.StatusCode.Should().Be(HttpStatusCode.Created);
    }
}
```
```csharp
// 5. Authenticating requests in tests — bypass or simulate auth
public class AuthenticatedFactory : TestWebApplicationFactory
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        base.ConfigureWebHost(builder);

        builder.ConfigureServices(services =>
        {
            // Replace auth with a test scheme that always authenticates
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
        var claims = new[] { new Claim(ClaimTypes.Name, "testuser"),
                             new Claim(ClaimTypes.Role, "Admin") };
        var identity = new ClaimsIdentity(claims, "Test");
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, "Test");
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

---

## Gotchas
- **`IClassFixture<WebApplicationFactory<T>>` shares one factory across all tests in a class — database state bleeds between tests.** If test A inserts a row and test B queries all rows, B sees A's data. Either delete and re-seed in `InitializeAsync`/`DisposeAsync`, or wrap each test in a transaction and roll back. Relying on test execution order to manage state is a trap.
- **SQLite in-memory databases are connection-scoped by default.** Each call to `UseSqlite("DataSource=:memory:")` opens a new connection and a new empty database. The `HttpClient` and your seeding code use different connections unless you configure SQLite to use a named shared in-memory database: `"DataSource=testdb;Mode=Memory;Cache=Shared"`.
- **`Program` must be accessible from the test project.** `WebApplicationFactory<Program>` needs a reference to your app's entry point. In .NET 6+ minimal APIs, `Program` is a compiler-generated internal class. Add `public partial class Program { }` to the bottom of `Program.cs` to expose it.
- **Testcontainers requires Docker running on the test machine and CI agent.** If your CI pipeline doesn't have Docker available, Testcontainer tests fail at startup with a cryptic socket error, not a clear test failure. Always check CI Docker availability before committing Testcontainer-based tests.
- **`CreateClient()` doesn't follow redirects by default — but `HttpClient` does.** `WebApplicationFactory.CreateClient()` returns a client configured with `AllowAutoRedirect = true`. If you're testing redirect behavior (301, 302), create the client with `factory.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false })`.

---

## Interview Angle
**What they're really testing:** Whether you understand what integration tests actually cover that unit tests can't, and what the tradeoffs are between test fidelity and speed.

**Common question form:** *"How do you test your API endpoints?"* or *"What's the difference between a unit test and an integration test in .NET?"* or *"How do you handle the database in integration tests?"*

**The depth signal:** A junior says "spin up the app and call the endpoint with HttpClient." A senior knows `WebApplicationFactory<T>` specifically, explains the two database strategies (SQLite for speed, Testcontainers for fidelity) and when each is appropriate, handles test isolation explicitly (shared factory state is the most common integration test bug), knows how to override auth so protected endpoints can be tested without a real identity provider, and understands that integration tests belong in their own project with their own CI stage — not mixed with unit tests — because they're an order of magnitude slower.

---

## Related Topics
- [[dotnet/testing-unit-tests.md]] — Integration tests verify wiring; unit tests verify logic — knowing the boundary determines which to write for a given scenario.
- [[dotnet/testing-mocking.md]] — Integration tests minimize mocking by design; where you draw the mock boundary determines whether a test is truly integration or a glorified unit test.
- [[dotnet/ef-transactions.md]] — Wrapping each integration test in a transaction and rolling back is the cleanest isolation strategy; understanding transactions is a prerequisite.
- [[devops/ci-pipeline.md]] — Integration tests with Testcontainers need Docker on the CI agent; pipeline configuration determines whether they run on every PR or only on main.

---

## Source
https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests

---
*Last updated: 2026-03-24*