# xUnit in .NET

> xUnit is the standard .NET test framework — the runner that discovers, organises, and executes your tests, and provides the attributes and fixtures that structure a test suite.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Test discovery and execution framework |
| **Use when** | Writing any automated tests in .NET — unit, integration, component |
| **Avoid when** | Never avoid it — it's the runtime everything else sits on |
| **Key packages** | `xunit`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk` |
| **Key types** | `[Fact]`, `[Theory]`, `[InlineData]`, `IClassFixture<T>`, `ICollectionFixture<T>`, `IAsyncLifetime` |
| **CLI** | `dotnet test`, `dotnet watch test` |

---

## When To Use It
Use xUnit for every automated test project in .NET. It is the de facto standard, the framework used by Microsoft's own ASP.NET Core and EF Core test suites, and the one FluentAssertions, Moq, and Testcontainers are all designed to integrate with. NUnit and MSTest are legacy alternatives — still functional, but xUnit is what you'll encounter in nearly every modern .NET codebase and what interviewers assume when they say "unit tests in .NET."

---

## Core Concept
xUnit discovers test methods via attributes. `[Fact]` marks a single test. `[Theory]` marks a parameterised test that runs once per data row. xUnit creates a **new instance of the test class for every test method** — this is the key design decision that separates xUnit from NUnit/MSTest. There are no `[SetUp]`/`[TearDown]` attributes. Setup goes in the constructor; teardown goes in `IDisposable.Dispose()` or `IAsyncLifetime.DisposeAsync()`. This prevents shared mutable state between tests by design.

Fixtures are the mechanism for sharing expensive resources across tests. `IClassFixture<T>` shares one `T` instance across all tests in one class. `ICollectionFixture<T>` shares one `T` instance across all tests in a named collection (multiple classes). The fixture is constructed once, injected into test class constructors, and disposed after all tests in the scope finish.

xUnit runs test classes in parallel by default — different test classes run simultaneously. Tests within the same class run sequentially. This matters for integration tests that share a database: two test classes each modifying the same table will produce non-deterministic failures unless they're in the same `[Collection]` (which disables cross-class parallelism for those classes).

---

## Version History

| Version | What changed |
|---|---|
| xUnit 1.x | Original xUnit — custom attributes, no async support |
| xUnit 2.0 | Parallel test execution introduced; constructor replaces `[SetUp]`; `IDisposable` replaces `[TearDown]` |
| xUnit 2.4 | `IAsyncLifetime` for async setup/teardown |
| xUnit 2.7 | `TheoryData<T>` strongly-typed alternative to `[MemberData]` |
| xUnit 3.x (preview) | Source-generated test discovery; `[Fact]` becomes sealed; breaking changes — check release notes before upgrading |

*xUnit's decision to create a new test class instance per test is intentional and philosophically significant — it forces tests to be independent by design. NUnit and MSTest reuse the class instance, which makes accidental shared state much easier to introduce.*

---

## Performance

| Scenario | Notes |
|---|---|
| Test discovery | < 1s for 1,000 tests |
| New class instance per test | Negligible allocation — constructor runs per test |
| Parallel execution (default) | Multiple test classes run simultaneously — overall suite time ≈ slowest class |
| `[Collection]` serialisation | Disables cross-class parallelism for grouped classes — adds time |

**Benchmark notes:** A well-structured xUnit suite of 500 unit tests completes in under 5 seconds. If it takes longer, the culprit is hidden I/O (real database or HTTP calls disguised as unit tests), not xUnit itself. Use `dotnet test --logger "console;verbosity=normal"` to surface slow tests by name.

---

## The Code

```csharp
// Setup
// dotnet new xunit -n MyProject.Tests
// Or manually:
// dotnet add package xunit
// dotnet add package xunit.runner.visualstudio
// dotnet add package Microsoft.NET.Test.Sdk
```

```csharp
// 1. [Fact] — single test, no parameters
public class CalculatorTests
{
    [Fact]
    public void Add_TwoPositiveNumbers_ReturnsSum()
    {
        var calc = new Calculator();
        var result = calc.Add(2, 3);
        result.Should().Be(5);
    }
}
```

```csharp
// 2. [Theory] with [InlineData] — parameterised test, runs N times
public class CalculatorTests
{
    [Theory]
    [InlineData(2,  3,  5)]
    [InlineData(0,  0,  0)]
    [InlineData(-1, 1,  0)]
    [InlineData(-5, -3, -8)]
    public void Add_VariousInputs_ReturnsCorrectSum(int a, int b, int expected)
    {
        new Calculator().Add(a, b).Should().Be(expected);
    }
}
```

```csharp
// 3. [MemberData] — data from a static property (when InlineData is too limited)
public class OrderValidatorTests
{
    public static TheoryData<CreateOrderDto, string> InvalidOrders => new()
    {
        { new CreateOrderDto { Total = 0 },     "Total must be positive" },
        { new CreateOrderDto { Total = -1 },    "Total must be positive" },
        { new CreateOrderDto { CustomerId = 0 }, "CustomerId is required" },
    };

    [Theory]
    [MemberData(nameof(InvalidOrders))]
    public void Validate_InvalidOrder_ReturnsExpectedError(
        CreateOrderDto dto, string expectedError)
    {
        var result = new OrderValidator().Validate(dto);
        result.Errors.Should().ContainSingle(e => e.ErrorMessage == expectedError);
    }
}
```

```csharp
// 4. Constructor setup + IDisposable teardown — xUnit's replacement for [SetUp]/[TearDown]
public class OrderServiceTests : IDisposable
{
    private readonly Mock<IOrderRepository> _repo = new();
    private readonly Mock<IEmailService>    _email = new();
    private readonly OrderService           _sut;

    // Runs before each test — constructor is [SetUp]
    public OrderServiceTests()
    {
        _sut = new OrderService(_repo.Object, _email.Object);
    }

    [Fact]
    public async Task CancelOrder_ValidOrder_ReturnsTrue()
    {
        _repo.Setup(r => r.GetByIdAsync(1))
             .ReturnsAsync(new Order { Id = 1, Status = OrderStatus.Pending });

        var result = await _sut.CancelOrderAsync(1);

        result.Should().BeTrue();
    }

    // Runs after each test — IDisposable.Dispose is [TearDown]
    public void Dispose()
    {
        // Clean up unmanaged resources, close connections, etc.
        // For most unit tests this is empty — xUnit's new-instance-per-test
        // handles cleanup automatically by creating a fresh instance next time.
    }
}
```

```csharp
// 5. IAsyncLifetime — async setup and teardown
public class IntegrationTests : IAsyncLifetime
{
    private AppDbContext _db = null!;

    // Runs before each test — async equivalent of constructor setup
    public async Task InitializeAsync()
    {
        _db = CreateDbContext();
        await _db.Database.EnsureCreatedAsync();
        await SeedAsync(_db);
    }

    [Fact]
    public async Task GetOrder_ExistingId_ReturnsOrder()
    {
        var result = await _db.Orders.FindAsync(1);
        result.Should().NotBeNull();
    }

    // Runs after each test — async equivalent of Dispose
    public async Task DisposeAsync()
    {
        await _db.Database.EnsureDeletedAsync();
        await _db.DisposeAsync();
    }
}
```

```csharp
// 6. IClassFixture<T> — share one expensive resource across all tests in a class
// The fixture is created once and disposed after all tests in the class complete.
public class DatabaseFixture : IDisposable
{
    public AppDbContext Db { get; }

    public DatabaseFixture()
    {
        // Expensive setup — done once for the whole class
        Db = CreateAndSeedDatabase();
    }

    public void Dispose() => Db.Dispose();
}

public class OrderQueryTests : IClassFixture<DatabaseFixture>
{
    private readonly AppDbContext _db;

    // Fixture injected via constructor — xUnit wires it automatically
    public OrderQueryTests(DatabaseFixture fixture)
    {
        _db = fixture.Db;
    }

    [Fact]
    public void GetOrders_ReturnsSeededOrders()
    {
        _db.Orders.Should().NotBeEmpty();
    }
}
```

```csharp
// 7. ICollectionFixture<T> — share one resource across multiple test classes
[CollectionDefinition("database")]
public class DatabaseCollection : ICollectionFixture<DatabaseFixture>
{
    // Marker class — no code needed
}

[Collection("database")]    // opts this class into the shared fixture
public class OrderCommandTests
{
    private readonly AppDbContext _db;

    public OrderCommandTests(DatabaseFixture fixture) => _db = fixture.Db;

    [Fact]
    public async Task PlaceOrder_PersistsToDatabase()
    {
        // test using shared _db
    }
}

[Collection("database")]    // shares the same DatabaseFixture instance as OrderCommandTests
public class CustomerQueryTests
{
    private readonly AppDbContext _db;

    public CustomerQueryTests(DatabaseFixture fixture) => _db = fixture.Db;

    [Fact]
    public void GetCustomer_ReturnsSeededCustomer() { }
}
```

```csharp
// 8. Controlling parallelism — disable parallel execution for integration tests
// In xunit.runner.json (in test project root):
{
  "parallelizeAssembly": false,
  "parallelizeTestCollections": false
}

// Or target specific collections with [Collection] to serialise them
// while letting other collections remain parallel

// 9. Output — writing diagnostic messages visible in test results
public class DiagnosticTests
{
    private readonly ITestOutputHelper _output;

    public DiagnosticTests(ITestOutputHelper output) => _output = output;

    [Fact]
    public void SomeTest()
    {
        _output.WriteLine("Debug: starting test at {0}", DateTime.UtcNow);
        // _output messages appear in `dotnet test --logger console` output
        // and in IDE test runners — useful for debugging flaky tests
    }
}
```

```csharp
// 10. Skipping tests — conditional skip for known issues
[Fact(Skip = "Pending fix for issue #123")]
public void SomeFlakeyTest() { }

[Fact]
[Trait("Category", "slow")]
public void SlowIntegrationTest() { }
// Run only slow tests: dotnet test --filter "Category=slow"
// Skip slow tests:    dotnet test --filter "Category!=slow"
```

---

## Real World Example

A payments service has three test classes: `PaymentValidatorTests` (pure unit tests — no shared setup needed), `PaymentServiceTests` (unit tests with Moq mocks — constructor setup per test), and `PaymentApiTests` (integration tests with a real database — shared container fixture). The xUnit fixture hierarchy handles all three cases cleanly.

```csharp
// Pure unit — no fixture needed, new instance per test is enough
public class PaymentValidatorTests
{
    private readonly PaymentValidator _sut = new();

    [Theory]
    [InlineData(0,      "Amount must be positive")]
    [InlineData(-50,    "Amount must be positive")]
    [InlineData(100001, "Amount exceeds maximum")]
    public void Validate_InvalidAmount_ReturnsError(decimal amount, string expectedError)
    {
        var request = new PaymentRequest { Amount = amount, Currency = "GBP" };
        var result  = _sut.Validate(request);
        result.Errors.Should().ContainSingle(e => e.ErrorMessage == expectedError);
    }
}

// Mock-based unit test — mocks re-created per test via constructor
public class PaymentServiceTests
{
    private readonly Mock<IPaymentRepository> _repo  = new();
    private readonly Mock<IFraudDetector>     _fraud = new();
    private readonly PaymentService           _sut;

    public PaymentServiceTests() =>
        _sut = new PaymentService(_repo.Object, _fraud.Object);

    [Fact]
    public async Task ProcessPayment_FraudDetected_ReturnsDenied()
    {
        _fraud.Setup(f => f.EvaluateAsync(It.IsAny<PaymentRequest>()))
              .ReturnsAsync(FraudScore.High);

        var result = await _sut.ProcessAsync(new PaymentRequest { Amount = 500m });

        result.Status.Should().Be(PaymentStatus.Denied);
        _repo.Verify(r => r.SaveAsync(It.IsAny<Payment>()), Times.Never);
    }
}

// Integration test — shared container via IClassFixture + IAsyncLifetime per-test cleanup
[Collection("payments-integration")]
public class PaymentApiTests : IClassFixture<PaymentsApiFactory>, IAsyncLifetime
{
    private readonly HttpClient _client;
    private readonly AppDbContext _db;
    private readonly IServiceScope _scope;
    private readonly ITestOutputHelper _output;

    public PaymentApiTests(PaymentsApiFactory factory, ITestOutputHelper output)
    {
        _client = factory.CreateClient();
        _scope  = factory.Services.CreateScope();
        _db     = _scope.ServiceProvider.GetRequiredService<AppDbContext>();
        _output = output;
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public async Task DisposeAsync()
    {
        _output.WriteLine("Cleaning up {0} payments", _db.Payments.Count());
        _db.Payments.RemoveRange(_db.Payments);
        await _db.SaveChangesAsync();
        _scope.Dispose();
    }

    [Fact]
    public async Task PostPayment_ValidRequest_Returns201()
    {
        var payload = new { Amount = 100m, Currency = "GBP", RecipientId = "rec-001" };
        var response = await _client.PostAsJsonAsync("/api/payments", payload);
        response.StatusCode.Should().Be(HttpStatusCode.Created);
    }
}
```

*The `ITestOutputHelper` injection in the integration test class is the right way to add diagnostic logging — those messages appear in CI test output when a test fails and are invaluable for debugging non-deterministic test failures.*

---

## Common Misconceptions

**"There's no `[SetUp]` or `[TearDown]` in xUnit — I have to repeat setup code in every test."**
Setup goes in the constructor (runs before each test) and teardown goes in `Dispose()`/`DisposeAsync()`. This is intentional — xUnit's authors believe the constructor/dispose pattern is more natural and less surprising than magic attributes. For expensive setup that should run once per class, use `IClassFixture<T>`. For async setup, use `IAsyncLifetime`.

**"`IClassFixture<T>` runs setup once per test, just like the constructor."**
The fixture is created once for the *entire class* and shared across all tests. The constructor runs once per test. This distinction matters: mutations to the fixture's state in test A are visible to test B. Fixture objects should be treated as read-only after `InitializeAsync()` completes, or tests become order-dependent.

**"Parallel test execution can't be disabled."**
It can — either globally via `xunit.runner.json`, or for specific groups via `[Collection]`. Tests within the same collection run sequentially; tests in different collections (that don't share a collection name) run in parallel. The `[Collection]` attribute is the surgical tool; `parallelizeAssembly: false` is the sledgehammer.

---

## Gotchas

- **`async void` test methods swallow exceptions.** Declare async tests as `async Task`, never `async void`. xUnit 2.x will silently pass an `async void` test even if it throws — the runner doesn't observe the exception.

- **`IClassFixture<T>` state shared between tests causes order-dependent failures.** If test A modifies the fixture and test B reads it, B's result depends on A running first. xUnit does not guarantee test execution order within a class. Treat fixture objects as immutable after construction.

- **`[Collection]` disables parallelism between the collected classes, not within them.** Tests within the same test class always run sequentially. `[Collection]` controls cross-class parallelism.

- **`ITestOutputHelper` messages only appear when the test fails** (in most runners). They don't appear for passing tests. This is by design — use `_output.WriteLine()` freely for diagnostic context that you want to see *if* a test fails.

- **`dotnet test` with no filter runs everything.** Add `--filter "Category!=integration"` to CI unit test steps so integration tests don't slow down every PR build. Pair with `[Trait("Category", "integration")]` on integration test classes.

- **`[Fact(Skip = "reason")]` shows as skipped in results, not as passing.** This is good — skipped tests are visible in CI. Don't comment out tests to suppress failures; always use `Skip` so the suppression is explicit and auditable.

---

## Interview Angle

**What they're really testing:** Whether you understand the xUnit design philosophy — specifically why there are no `[SetUp]`/`[TearDown]` attributes and how fixtures work — and whether you know when to use which fixture type.

**Common question forms:**
- *"How do you share setup code across multiple tests in xUnit?"*
- *"What's the difference between `IClassFixture` and `ICollectionFixture`?"*
- *"How do you run xUnit tests in parallel and when would you disable it?"*

**The depth signal:** A junior says "use the constructor for setup." A senior explains the fixture hierarchy: constructor for per-test setup, `IClassFixture<T>` for per-class shared resources, `ICollectionFixture<T>` for cross-class shared resources, and explains *why* xUnit creates a new instance per test (prevents accidental shared state). They know `IAsyncLifetime` for database setup, `ITestOutputHelper` for diagnostic output, and `[Collection]` for controlling parallelism in integration tests.

**Follow-up questions to expect:**
- *"Why does xUnit create a new instance per test instead of reusing it?"* — Prevents the most common cause of test flakiness: mutable state set in test A polluting test B's preconditions.
- *"When does `IClassFixture` get created and destroyed?"* — Created before the first test in the class, destroyed after the last test in the class. One instance total, regardless of how many tests are in the class.

---

## Related Topics

- [[dotnet/testing/testing-unit-tests.md]] — Unit test structure, `[Fact]` vs `[Theory]`, naming conventions — all built on xUnit mechanics.
- [[dotnet/testing/testing-integration-tests.md]] — `IClassFixture<WebApplicationFactory<T>>` is the standard integration test setup; understanding xUnit fixtures is a prerequisite.
- [[dotnet/testing/testing-testcontainers.md]] — Testcontainers fixtures implement `IAsyncLifetime` and are wired via `IClassFixture`; the two topics overlap significantly.
- [[dotnet/testing/testing-tdd.md]] — The TDD Red→Green loop depends on fast test feedback; `dotnet watch test` and understanding xUnit's runner are what make that loop tight.

---

## Source

https://xunit.net/docs/getting-started/netcore/cmdline

---
*Last updated: 2026-04-12*