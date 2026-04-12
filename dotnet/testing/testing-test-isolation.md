# Test Isolation in .NET

> Test isolation means each test starts with a known state, runs independently of every other test, and leaves no trace that can affect what comes next.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Guarantee that tests don't affect each other's results |
| **Use when** | Always — non-isolated tests are non-deterministic tests |
| **Key strategies** | Transaction rollback, delete/re-seed, fresh container, in-memory state |
| **Key patterns** | Builder pattern for test data, Object Mother, `IAsyncLifetime` cleanup |
| **Common symptom** | Test passes alone, fails in the full suite — or vice versa |

---

## When To Use It
Every test needs isolation — this is not optional. A test suite without isolation produces non-deterministic results: tests pass in one order and fail in another, pass locally and fail on CI, pass for one developer and fail for another. The question is not *whether* to isolate but *which strategy* to use. Unit tests achieve isolation automatically through mocking and new-instance-per-test. Integration tests require deliberate effort because they share real infrastructure — a database, a Redis instance, a message queue.

---

## Core Concept
Test isolation has two components. **State isolation** means test A's writes don't affect test B's reads. **Fixture isolation** means shared expensive resources (containers, database connections, factory instances) are set up once but cleaned between each test.

For unit tests, xUnit's new-instance-per-test design handles both automatically — each test gets a fresh class instance and fresh mocks. For integration tests, the container or database is shared (for performance) but the *data* must be reset between tests.

The four common strategies for integration test data isolation:

1. **Delete and re-seed** — `DisposeAsync()` deletes all rows; `InitializeAsync()` seeds fresh data. Simple, reliable, works for most cases.
2. **Transaction rollback** — wrap each test in an EF transaction and roll it back in `DisposeAsync()`. Nothing is committed to the database. Fast but requires careful scope management.
3. **Fresh container per test class** — each test *class* gets its own container (not per test). Data doesn't bleed across classes; within a class, use delete/re-seed.
4. **Unique identifiers per test** — tests use GUIDs to scope their data and query by their own ID. Works but pollutes the database over time.

Test data construction is the second dimension. Hard-coded objects scattered across tests create maintenance burden — change one field in the domain model and fifty test data setups break. **Test data builders** and **Object Mothers** centralise construction so changes need only be made in one place.

---

## Version History

| Feature | Notes |
|---|---|
| `IAsyncLifetime` (xUnit 2.4+) | Async `InitializeAsync`/`DisposeAsync` — required for database cleanup patterns |
| EF Core `UseTransaction` | Wrapping tests in an EF-controlled transaction for rollback isolation |
| `TimeProvider` (.NET 8+) | Built-in clock abstraction; replaces hand-rolled `IClock` for time-dependent isolation |
| `Respawn` library | Alternative cleanup — resets database to empty state faster than DELETE; works at SQL level |

*The `Respawn` library (by Jimmy Bogard) is worth knowing — it resets a database faster than `DELETE` by examining foreign key constraints and deleting in the right order, then restoring identity seeds. It's particularly fast on large schemas where manual delete order management becomes complex.*

---

## Performance

| Strategy | Per-test overhead | Notes |
|---|---|---|
| Delete/re-seed in `DisposeAsync` | 10–200ms | Scales with row count |
| Transaction rollback | < 5ms | Near-zero overhead; fastest option |
| `Respawn` reset | 20–100ms | Faster than manual delete on complex schemas |
| Fresh container per test class | 10–15s once per class | Acceptable; unacceptable per test |
| Unique ID scoping | < 1ms | Fast but pollutes DB; needs separate cleanup job |

---

## The Code

```csharp
// ── Strategy 1: Delete and re-seed in IAsyncLifetime ─────────────────────────

public class OrderTests : IClassFixture<ApiFactory>, IAsyncLifetime
{
    private readonly HttpClient _client;
    private readonly AppDbContext _db;
    private readonly IServiceScope _scope;

    public OrderTests(ApiFactory factory)
    {
        _client = factory.CreateClient();
        _scope  = factory.Services.CreateScope();
        _db     = _scope.ServiceProvider.GetRequiredService<AppDbContext>();
    }

    public async Task InitializeAsync()
    {
        // Seed known state before each test
        _db.Orders.Add(new Order { Id = 1, Total = 99m, Status = OrderStatus.Pending,
                                   CustomerId = 1 });
        await _db.SaveChangesAsync();
    }

    public async Task DisposeAsync()
    {
        // Wipe all data after each test — next test starts clean
        _db.Orders.RemoveRange(_db.Orders);
        _db.Customers.RemoveRange(_db.Customers);
        await _db.SaveChangesAsync();
        _scope.Dispose();
    }

    [Fact]
    public async Task GetOrder_ExistingId_ReturnsOrder()
    {
        var response = await _client.GetAsync("/api/orders/1");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
```

```csharp
// ── Strategy 2: Transaction rollback ─────────────────────────────────────────
// Each test runs inside a transaction that rolls back in DisposeAsync.
// Nothing is ever committed — the database returns to its pre-test state.

public class TransactionIsolatedTests : IClassFixture<ApiFactory>, IAsyncLifetime
{
    private readonly AppDbContext _db;
    private readonly IServiceScope _scope;
    private IDbContextTransaction _transaction = null!;

    public TransactionIsolatedTests(ApiFactory factory)
    {
        _scope = factory.Services.CreateScope();
        _db    = _scope.ServiceProvider.GetRequiredService<AppDbContext>();
    }

    public async Task InitializeAsync()
    {
        // Begin transaction — nothing written in this test will be committed
        _transaction = await _db.Database.BeginTransactionAsync();

        _db.Orders.Add(new Order { Id = 1, Total = 150m, Status = OrderStatus.Pending });
        await _db.SaveChangesAsync();  // writes to transaction buffer, not committed
    }

    [Fact]
    public async Task GetOrder_SeededData_ReturnsCorrectTotal()
    {
        var order = await _db.Orders.FindAsync(1);
        order!.Total.Should().Be(150m);
    }

    public async Task DisposeAsync()
    {
        // Rollback — database returns to exact state before InitializeAsync
        await _transaction.RollbackAsync();
        await _transaction.DisposeAsync();
        _scope.Dispose();
    }
}
```

```csharp
// ── Strategy 3: Respawn library ───────────────────────────────────────────────
// dotnet add package Respawn

public class RespawnFixture : IAsyncLifetime
{
    private Respawner _respawner = null!;
    public string ConnectionString => "your-connection-string";

    public async Task InitializeAsync()
    {
        _respawner = await Respawner.CreateAsync(ConnectionString, new RespawnerOptions
        {
            TablesToIgnore = new Table[] { "__EFMigrationsHistory" }
        });
    }

    public async Task ResetAsync() => await _respawner.ResetAsync(ConnectionString);

    public Task DisposeAsync() => Task.CompletedTask;
}

public class OrderApiTests : IClassFixture<ApiFactory>, IClassFixture<RespawnFixture>,
    IAsyncLifetime
{
    private readonly RespawnFixture _respawn;

    public OrderApiTests(ApiFactory factory, RespawnFixture respawn)
    {
        _respawn = respawn;
        // setup ...
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public async Task DisposeAsync()
    {
        // Respawn deletes all rows in correct FK order, resets identity seeds
        await _respawn.ResetAsync();
    }
}
```

```csharp
// ── Test Data Builders ────────────────────────────────────────────────────────
// Centralise test data construction — one place to update when the domain changes

public class OrderBuilder
{
    private int _id              = 1;
    private decimal _total       = 99m;
    private OrderStatus _status  = OrderStatus.Pending;
    private string _email        = "test@example.com";
    private DateTime _createdAt  = DateTime.UtcNow;

    public OrderBuilder WithId(int id)                  { _id = id; return this; }
    public OrderBuilder WithTotal(decimal total)        { _total = total; return this; }
    public OrderBuilder WithStatus(OrderStatus status)  { _status = status; return this; }
    public OrderBuilder WithEmail(string email)         { _email = email; return this; }
    public OrderBuilder Shipped()                       => WithStatus(OrderStatus.Shipped);
    public OrderBuilder Cancelled()                     => WithStatus(OrderStatus.Cancelled);

    public Order Build() => new Order
    {
        Id            = _id,
        Total         = _total,
        Status        = _status,
        CustomerEmail = _email,
        CreatedAt     = _createdAt
    };
}

// Usage — tests read like specifications, not data setup
[Fact]
public async Task CancelOrder_ShippedOrder_ReturnsFalse()
{
    var order = new OrderBuilder().WithId(5).Shipped().Build();
    _repo.Setup(r => r.GetByIdAsync(5)).ReturnsAsync(order);

    var result = await _sut.CancelOrderAsync(5);

    result.Should().BeFalse();
}
```

```csharp
// ── Object Mother ─────────────────────────────────────────────────────────────
// Simpler alternative to Builder — static factory methods for common test objects
// Use when objects don't need per-test customisation

public static class TestOrders
{
    public static Order PendingOrder(int id = 1, decimal total = 99m) =>
        new Order { Id = id, Total = total, Status = OrderStatus.Pending,
                    CustomerEmail = "test@example.com" };

    public static Order ShippedOrder(int id = 1) =>
        new Order { Id = id, Total = 200m, Status = OrderStatus.Shipped,
                    CustomerEmail = "shipped@example.com" };

    public static Order HighValueOrder(decimal total = 1000m) =>
        PendingOrder(total: total);
}

// Usage
[Fact]
public async Task GetOrder_HighValueOrder_ReturnsWithApprovalFlag()
{
    _repo.Setup(r => r.GetByIdAsync(1)).ReturnsAsync(TestOrders.HighValueOrder());
    // ...
}
```

```csharp
// ── Time isolation with IClock / TimeProvider ──────────────────────────────────

// Before .NET 8: hand-rolled IClock
public interface IClock { DateTime UtcNow { get; } }
public class SystemClock : IClock { public DateTime UtcNow => DateTime.UtcNow; }
public class FakeClock : IClock
{
    private DateTime _time;
    public FakeClock(DateTime fixedTime) => _time = fixedTime;
    public DateTime UtcNow => _time;
    public void Advance(TimeSpan by) => _time = _time.Add(by);
}

// .NET 8+: use built-in TimeProvider
public class FakeTimeProvider : TimeProvider
{
    private DateTimeOffset _now;
    public FakeTimeProvider(DateTimeOffset startTime) => _now = startTime;
    public override DateTimeOffset GetUtcNow() => _now;
    public void Advance(TimeSpan by) => _now = _now.Add(by);
}

// Test using FakeTimeProvider
[Fact]
public void Session_ExpiredToken_ReturnsUnauthorized()
{
    var fakeTime = new FakeTimeProvider(DateTimeOffset.UtcNow);
    var sut = new SessionService(fakeTime);

    var token = sut.CreateToken();           // created "now"
    fakeTime.Advance(TimeSpan.FromHours(2)); // advance clock 2 hours

    sut.Validate(token).Should().BeFalse();  // token expired after 1 hour
}
```

```csharp
// ── What NOT to do ────────────────────────────────────────────────────────────

// BAD: tests that depend on a specific execution order
public class OrderTests
{
    private static int _lastCreatedId;  // ← static shared state — death to parallelism

    [Fact]
    public async Task Step1_CreateOrder_SetsId()
    {
        var result = await _sut.CreateOrderAsync(new CreateOrderDto { Total = 100m });
        _lastCreatedId = result.Id;         // ← assumes this test runs before Step2
    }

    [Fact]
    public async Task Step2_GetOrder_ReturnsCreated()
    {
        var order = await _sut.GetOrderAsync(_lastCreatedId);  // ← fails if Step1 didn't run first
        order.Should().NotBeNull();
    }
}

// GOOD: each test is self-contained
[Fact]
public async Task CreateAndGetOrder_RoundTrip_ReturnsCreatedOrder()
{
    var created = await _sut.CreateOrderAsync(new CreateOrderDto { Total = 100m });
    var fetched = await _sut.GetOrderAsync(created.Id);
    fetched.Should().BeEquivalentTo(created);
}
```

---

## Real World Example

A subscription platform has tests covering the renewal flow: when a subscription expires, a renewal job picks it up, charges the card, and either activates the next period or marks the subscription as lapsed. The tests need a real database (SQL Server-specific row locking behavior matters) and a controllable clock. The isolation strategy combines transaction rollback for database state and `FakeTimeProvider` for time.

```csharp
public class SubscriptionRenewalTests : IClassFixture<SubscriptionApiFactory>,
    IAsyncLifetime
{
    private readonly AppDbContext _db;
    private readonly FakeTimeProvider _clock;
    private readonly SubscriptionRenewalJob _job;
    private readonly IServiceScope _scope;
    private IDbContextTransaction _transaction = null!;

    // Fixed point in time — all tests see the same "now"
    private static readonly DateTimeOffset TestNow =
        new DateTimeOffset(2026, 1, 15, 12, 0, 0, TimeSpan.Zero);

    public SubscriptionRenewalTests(SubscriptionApiFactory factory)
    {
        _scope  = factory.Services.CreateScope();
        _db     = _scope.ServiceProvider.GetRequiredService<AppDbContext>();
        _clock  = factory.FakeTime;                  // injected fake from factory
        _job    = _scope.ServiceProvider.GetRequiredService<SubscriptionRenewalJob>();
    }

    public async Task InitializeAsync()
    {
        _clock.Reset(TestNow);                        // reset clock before each test
        _transaction = await _db.Database.BeginTransactionAsync();

        _db.Subscriptions.Add(new Subscription
        {
            Id         = 1,
            CustomerId = "cust-001",
            ExpiresAt  = TestNow.AddDays(-1),         // expired yesterday
            Status     = SubscriptionStatus.Active,
            Plan       = "pro-monthly"
        });
        await _db.SaveChangesAsync();
    }

    [Fact]
    public async Task ProcessRenewal_ExpiredSubscription_ChargesAndRenews()
    {
        await _job.RunAsync();

        var sub = await _db.Subscriptions.FindAsync(1);
        sub!.Status.Should().Be(SubscriptionStatus.Active);
        sub.ExpiresAt.Should().BeCloseTo(TestNow.AddMonths(1), TimeSpan.FromMinutes(1));
    }

    [Fact]
    public async Task ProcessRenewal_ChargeFailure_MarksAsLapsed()
    {
        // Arrange: configure fake payment service to fail for this test
        _scope.ServiceProvider
              .GetRequiredService<IFakePaymentService>()
              .SetNextResult(ChargeResult.Declined);

        await _job.RunAsync();

        var sub = await _db.Subscriptions.FindAsync(1);
        sub!.Status.Should().Be(SubscriptionStatus.Lapsed);
    }

    public async Task DisposeAsync()
    {
        await _transaction.RollbackAsync();
        await _transaction.DisposeAsync();
        _scope.Dispose();
    }
}
```

*The transaction rollback here is key — the renewal job writes to the database, and the rollback undoes those writes so the next test starts from the seeded state. Without it, the `ExpiresAt` check in the first test would be wrong for the second test because the subscription was already renewed.*

---

## Common Misconceptions

**"My tests pass individually — they're isolated."**
Passing in isolation doesn't prove isolation. Isolation means passing in *any execution order*, including the reverse of the natural order, and in parallel with other test classes. The real test is: `dotnet test` passes, then run it again with a different random seed (xUnit can randomise test order) and it still passes.

**"If I use `IClassFixture`, tests are automatically isolated."**
`IClassFixture` shares the fixture across tests — it does not isolate data. It's a resource-sharing mechanism, not an isolation mechanism. The data isolation must be built on top of it via delete/re-seed or transaction rollback.

**"Transaction rollback is always better than delete/re-seed."**
Transaction rollback is faster and cleaner — but it only works when the production code under test uses the *same database connection and transaction*. If the handler you're testing opens its own `DbContext` scope (common with `IMediator` + handlers), it runs in a different transaction than your test's rollback transaction. Delete/re-seed is slower but works regardless of how the code under test manages connections.

---

## Gotchas

- **Static fields in test classes destroy isolation.** xUnit creates a new instance per test, but `static` fields are shared across all instances. A `static int _lastId = 0` that gets incremented in tests will have different values depending on which other tests ran first.

- **Parallel test execution exposes isolation problems that sequential execution hides.** A test suite that passes with `parallelizeTestCollections: false` but fails with parallelism enabled has isolation bugs. The parallel failures are not a parallelism problem — they're an isolation problem that parallelism surfaces.

- **Transaction rollback doesn't work across multiple `DbContext` instances.** If the handler under test creates its own scope and `DbContext`, it runs in a separate transaction that isn't rolled back. Use delete/re-seed or Respawn for these scenarios.

- **Builders should have sensible defaults that satisfy all required fields and constraints.** A builder that produces an invalid object by default (missing a required FK, violating a non-null constraint) will generate cryptic database errors rather than useful test failures. Always ensure `Build()` returns a valid object that can be inserted without modification.

- **Time-dependent tests without clock injection become time bombs.** A test that says "order was placed 30 minutes ago" using `DateTime.UtcNow.AddMinutes(-30)` will pass today and might fail if the CI server is slow. Inject `IClock` or use `TimeProvider` and advance the clock explicitly in tests.

---

## Interview Angle

**What they're really testing:** Whether you've actually debugged non-deterministic integration test failures — the kind that only happen on CI, or when run in a different order.

**Common question forms:**
- *"How do you prevent integration tests from affecting each other?"*
- *"What's the difference between `IClassFixture` and test isolation?"*
- *"A test passes locally but fails on CI — how do you debug it?"*

**The depth signal:** A junior says "just use a fresh database for each test" (correct instinct, catastrophic performance). A senior knows the tradeoff between the four strategies — transaction rollback for speed with the caveat about multi-scope EF, delete/re-seed for simplicity and broad compatibility, Respawn for complex schemas, and unique-ID scoping as a last resort. They know what a test data builder is and why it's better than inline object construction, have used `IClock`/`TimeProvider` to make time-dependent tests deterministic, and can articulate the difference between a test passing in isolation and a test being genuinely isolated.

**Follow-up questions to expect:**
- *"When would you choose transaction rollback over delete/re-seed?"* — When tests run on the same `DbContext` instance as the code under test, rollback is faster and cleaner. When handlers run in their own scoped `DbContext`, rollback won't undo their writes.
- *"What's the Respawn library?"* — Resets a database faster than DELETE by building a deletion script that respects FK constraints and resets identity seeds. Useful for large schemas where ordering deletions manually is error-prone.

---

## Related Topics

- [[dotnet/testing/testing-integration-tests.md]] — State bleed is the #1 integration test bug; isolation is the fix.
- [[dotnet/testing/testing-testcontainers.md]] — One container per class with per-test cleanup is the Testcontainers isolation pattern.
- [[dotnet/testing/testing-xunit.md]] — `IClassFixture`, `IAsyncLifetime`, and the new-instance-per-test design are the xUnit mechanics that isolation patterns are built on.
- [[dotnet/ef/ef-transactions.md]] — Transaction rollback as an isolation strategy requires understanding how EF manages transaction scope.
- [[dotnet/testing/testing-unit-tests.md]] — Unit test isolation is automatic via mocking and new-instance-per-test; understanding the contrast clarifies why integration tests need explicit isolation.

---

## Source

https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices

---
*Last updated: 2026-04-12*