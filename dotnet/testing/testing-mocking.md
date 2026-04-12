# Mocking in .NET Tests

> A mock is a fake object that stands in for a real dependency during testing, letting you control what it returns and verify how it was used.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Programmatically generated fake that replaces a real dependency |
| **Use when** | Dependency is slow, non-deterministic, or has side effects |
| **Avoid when** | The interface is simple and a hand-written fake would be cleaner |
| **Key packages** | `Moq` (most common), `NSubstitute` (alternative), `FakeItEasy` |
| **Key types** | `Mock<T>`, `It`, `Times`, `MockBehavior`, `Substitute.For<T>()` |
| **Cannot mock** | `sealed` classes, `static` methods, value types, non-virtual concrete methods |

---

## When To Use It
Use mocking when the class under test has dependencies that are slow, non-deterministic, or have side effects — database calls, HTTP requests, email sending, clock reads. Mocking isolates the logic you're actually testing from everything around it. Don't mock types you own when a hand-written fake is simpler and more readable. Never mock value types, static methods, or `sealed` classes — Moq can't intercept those without additional tooling (like `Microsoft.Fakes` or `Pose`).

---

## Core Concept
When you inject `IOrderRepository` into a service, the test can supply a fake implementation instead of the real one. The three concepts people conflate are worth separating carefully.

A **stub** provides canned return values so the code under test can run. You set it up to return specific data and you don't verify any calls on it afterward. The purpose is to feed inputs.

A **mock** is a stub where you also *verify* after the fact that specific methods were called with specific arguments. The setup says "when this is called, return this." The verify says "this must have been called, or the test fails." Use this for side effects with no observable return value — sending an email, publishing an event, writing to a log.

A **fake** is a lightweight working implementation you write by hand — an in-memory list that stands in for a database, a no-op logger, a fixed-clock that always returns the same time. Fakes are appropriate when the same mock setup would repeat across many tests, or when the fake needs real stateful logic (like maintaining a list between calls in the same test).

In practice, Moq objects do all three depending on how you use them. The rule is: assert on return values and observable state first; only call `Verify()` for side effects where there is nothing to return-value-assert on. Over-using `Verify()` creates tests that break on valid refactors.

---

## Version History

| Package | Version | What changed |
|---|---|---|
| Moq | 4.0 | Introduced lambda-based `Setup()` syntax |
| Moq | 4.8 | `ReturnsAsync()` and `ThrowsAsync()` for async interface methods |
| Moq | 4.10 | `SetupSequence` for different returns on successive calls |
| Moq | 4.16 | `Protected()` for virtual protected member mocking |
| Moq | 4.20 | `SponsorLink` controversy — many teams switched to NSubstitute; reverted in 4.20.2 |
| NSubstitute | 4.0+ | `Returns()` works correctly with async — no separate `ReturnsAsync` needed |
| NSubstitute | 5.x | Full NRT (nullable reference types) annotation support |

*Moq 4.20.0 briefly shipped telemetry code that caused significant community backlash. If your team uses Moq, pin to `>= 4.20.2` where it was removed. Many teams used this as the occasion to migrate to NSubstitute.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `new Mock<T>()` | ~0.2–1ms | Dynamic proxy generation per interface; one-time per mock instance |
| `.Setup(...)` | < 0.1ms | Expression tree parsing |
| `.Verify(...)` | < 0.1ms | Scans recorded invocations |
| Hand-written fake creation | < 0.01ms | Plain `new FakeRepo()` — no dynamic generation |

**Allocation behaviour:** Moq uses `Castle.DynamicProxy` to generate proxy types at runtime. The first call for a given interface type triggers IL code generation — expensive but cached. Subsequent `new Mock<ISameInterface>()` calls reuse the cached proxy type. For large test suites mocking the same interfaces repeatedly, the overhead is negligible. For 10,000+ unique interface mocks the first run is noticeably slower.

**Benchmark notes:** If your unit test suite is slow, the culprit is almost never Moq itself — it's tests that are secretly integration tests (touching a real database or HTTP endpoint). `dotnet test --logger "console;verbosity=normal"` sorted by duration will find them.

---

## The Code

```csharp
// Setup
// dotnet add package Moq
// dotnet add package NSubstitute   ← alternative
// dotnet add package FluentAssertions
```

```csharp
// 1. Basic stub — control what the dependency returns
public class OrderServiceTests
{
    private readonly Mock<IOrderRepository> _repo = new();
    private readonly Mock<IEmailService>    _email = new();
    private readonly OrderService           _sut;

    public OrderServiceTests() =>
        _sut = new OrderService(_repo.Object, _email.Object);

    [Fact]
    public async Task GetOrder_ExistingId_ReturnsOrder()
    {
        var expected = new Order { Id = 1, Total = 99m };

        _repo.Setup(r => r.GetByIdAsync(1))
             .ReturnsAsync(expected);

        var result = await _sut.GetOrderAsync(1);

        result.Should().BeEquivalentTo(expected);
    }
}
```

```csharp
// 2. Verify — assert a side effect happened (use only for fire-and-forget)
[Fact]
public async Task CancelOrder_ValidOrder_SendsCancellationEmail()
{
    _repo.Setup(r => r.GetByIdAsync(1))
         .ReturnsAsync(new Order { Id = 1, Status = OrderStatus.Pending,
                                   CustomerEmail = "x@y.com" });

    await _sut.CancelOrderAsync(1);

    // Good use of Verify: email has no return value to assert on
    _email.Verify(
        e => e.SendCancellationAsync("x@y.com"),
        Times.Once);
}

[Fact]
public async Task CancelOrder_OrderNotFound_NeverSendsEmail()
{
    _repo.Setup(r => r.GetByIdAsync(99)).ReturnsAsync((Order?)null);

    await _sut.CancelOrderAsync(99);

    _email.Verify(
        e => e.SendCancellationAsync(It.IsAny<string>()),
        Times.Never);
}
```

```csharp
// 3. It matchers — flexible argument matching
_repo.Setup(r => r.GetByIdAsync(It.IsAny<int>()))
     .ReturnsAsync(new Order());

_repo.Setup(r => r.FindByEmailAsync(It.Is<string>(s => s.Contains("@"))))
     .ReturnsAsync(new Customer());

_repo.Verify(r => r.SaveChangesAsync(), Times.Exactly(1));
_repo.Verify(r => r.GetByIdAsync(It.IsInRange(1, 100, Range.Inclusive)), Times.Once);
```

```csharp
// 4. MockBehavior.Strict — catch unexpected calls at the call site
// Default Moq: unsetup calls return default(T) silently
// Strict: unsetup calls throw — surfaces hidden dependency usage
var repo = new Mock<IOrderRepository>(MockBehavior.Strict);

repo.Setup(r => r.GetByIdAsync(1)).ReturnsAsync(new Order { Id = 1 });
// Any call other than GetByIdAsync(1) now throws InvalidOperationException
```

```csharp
// 5. SetupSequence — different return values on successive calls
_repo.SetupSequence(r => r.GetByIdAsync(1))
     .ReturnsAsync(new Order { Status = OrderStatus.Pending })    // first call
     .ReturnsAsync(new Order { Status = OrderStatus.Cancelled }); // second call
```

```csharp
// 6. Callback — capture arguments passed in, or trigger side effects
Order? savedOrder = null;

_repo.Setup(r => r.AddAsync(It.IsAny<Order>()))
     .Callback<Order>(o => savedOrder = o)
     .Returns(Task.CompletedTask);

await _sut.PlaceOrderAsync(new CreateOrderDto { Total = 150m });

savedOrder.Should().NotBeNull();
savedOrder!.Total.Should().Be(150m);
```

```csharp
// 7. NSubstitute — alternative syntax, less ceremony
var repo  = Substitute.For<IOrderRepository>();
var email = Substitute.For<IEmailService>();
var sut   = new OrderService(repo, email);

repo.GetByIdAsync(1).Returns(new Order { Id = 1, Status = OrderStatus.Pending,
                                         CustomerEmail = "x@y.com" });

await sut.CancelOrderAsync(1);

await email.Received(1).SendCancellationAsync("x@y.com");
```

```csharp
// 8. Hand-written fake — prefer when logic is reused across many tests
public class FakeOrderRepository : IOrderRepository
{
    private readonly List<Order> _store = new();
    public int SaveCallCount { get; private set; }

    public Task<Order?> GetByIdAsync(int id) =>
        Task.FromResult(_store.FirstOrDefault(o => o.Id == id));

    public Task AddAsync(Order order)     { _store.Add(order); return Task.CompletedTask; }
    public Task<IReadOnlyList<Order>> GetAllAsync() =>
        Task.FromResult<IReadOnlyList<Order>>(_store.AsReadOnly());

    public Task SaveChangesAsync()
    {
        SaveCallCount++;
        return Task.CompletedTask;
    }

    public void Seed(params Order[] orders) => _store.AddRange(orders);
}
```

```csharp
// 9. What NOT to do — over-mocking couples tests to implementation

// BAD: verifying every internal call — breaks on valid refactors
[Fact]
public async Task BAD_OverMocked_CancelOrder()
{
    _repo.Setup(r => r.GetByIdAsync(1))
         .ReturnsAsync(new Order { Id = 1, Status = OrderStatus.Pending });

    await _sut.CancelOrderAsync(1);

    _repo.Verify(r => r.GetByIdAsync(1), Times.Once);      // ← brittle
    _repo.Verify(r => r.SaveChangesAsync(), Times.Once);   // ← brittle
    _email.Verify(e => e.SendCancellationAsync(It.IsAny<string>()), Times.Once);
}

// GOOD: assert on observable output; verify only the side effect
[Fact]
public async Task GOOD_CancelOrder_UpdatesStateAndNotifies()
{
    var order = new Order { Id = 1, Status = OrderStatus.Pending,
                            CustomerEmail = "x@y.com" };
    _repo.Setup(r => r.GetByIdAsync(1)).ReturnsAsync(order);

    var result = await _sut.CancelOrderAsync(1);

    result.Should().BeTrue();
    order.Status.Should().Be(OrderStatus.Cancelled);    // observable state
    _email.Verify(e => e.SendCancellationAsync("x@y.com"), Times.Once); // fire-and-forget
}
```

---

## Real World Example

A notification service decides which channel to use (email, SMS, push) based on user preferences and message priority. The `NotificationRouter` depends on three interfaces: `IUserPreferencesRepository`, `IEmailSender`, and `ISmsSender`. Unit tests for the routing logic mock all three — the preferences repo is a stub (controls what the router reads), the senders are mocks (verify the right one was called), and the whole test class is set up once in the constructor.

```csharp
public class NotificationRouterTests
{
    private readonly Mock<IUserPreferencesRepository> _prefs = new();
    private readonly Mock<IEmailSender>               _email = new();
    private readonly Mock<ISmsSender>                 _sms   = new();
    private readonly NotificationRouter               _sut;

    public NotificationRouterTests()
    {
        _sut = new NotificationRouter(_prefs.Object, _email.Object, _sms.Object);
    }

    [Fact]
    public async Task Route_UserPrefersEmail_SendsViaEmail()
    {
        _prefs.Setup(p => p.GetAsync("user-1"))
              .ReturnsAsync(new UserPreferences { Channel = Channel.Email });

        await _sut.SendAsync("user-1", new Notification { Body = "Hello", Priority = Priority.Normal });

        _email.Verify(e => e.SendAsync("user-1", "Hello"), Times.Once);
        _sms.Verify(s => s.SendAsync(It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task Route_HighPriorityNotification_UsesSmsRegardlessOfPreference()
    {
        _prefs.Setup(p => p.GetAsync("user-1"))
              .ReturnsAsync(new UserPreferences { Channel = Channel.Email });

        await _sut.SendAsync("user-1", new Notification { Body = "Urgent!", Priority = Priority.High });

        // High priority overrides user preference — always SMS
        _sms.Verify(s => s.SendAsync("user-1", "Urgent!"), Times.Once);
        _email.Verify(e => e.SendAsync(It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task Route_PreferencesServiceThrows_FallsBackToEmail()
    {
        _prefs.Setup(p => p.GetAsync(It.IsAny<string>()))
              .ThrowsAsync(new TimeoutException());

        // Should not throw — fallback to email on preferences service failure
        await _sut.SendAsync("user-1", new Notification { Body = "Hello", Priority = Priority.Normal });

        _email.Verify(e => e.SendAsync("user-1", "Hello"), Times.Once);
    }

    [Fact]
    public async Task Route_UserNotFound_SendsToDefaultChannel()
    {
        _prefs.Setup(p => p.GetAsync("unknown"))
              .ReturnsAsync((UserPreferences?)null);

        await _sut.SendAsync("unknown", new Notification { Body = "Hi", Priority = Priority.Normal });

        // Null preferences → default channel (email) per business rule
        _email.Verify(e => e.SendAsync("unknown", "Hi"), Times.Once);
    }
}
```

*The fallback test is the one that justifies mocking over a fake here — you need to simulate a service throwing at runtime, which a hand-written fake would need special configuration to do. That's the sweet spot for Moq: controlled failure scenarios that are hard to trigger with real implementations.*

---

## Common Misconceptions

**"The more things I verify, the more confident I can be in the test."**
Verification confidence is an illusion when applied to implementation details. `_repo.Verify(r => r.GetByIdAsync(1), Times.Once)` doesn't tell you the behavior is correct — it tells you the method was called once with that argument. If you later refactor the service to call it twice for valid reasons (a caching check and a fallback), this test fails even though the behavior is identical. Verify only what is observable from the *outside* of the unit under test.

**"I should always use `MockBehavior.Strict` to be safe."**
Strict mode is valuable for high-risk interfaces where silent fallthrough has already caused bugs. But applied everywhere it creates extreme test fragility — calling `ToString()` on a mocked object, or a logging extension method that internally touches your mock, throws with no useful error. Start with default behavior, switch to Strict only on interfaces where you've been burned by an unexpected call being swallowed silently.

**"Moq can mock any class."**
Moq can only mock interfaces, abstract classes, and classes with `virtual` members. Concrete non-virtual methods run as real code — Moq ignores the `Setup()` silently and the real implementation runs. This is the most common "my mock isn't working" root cause. If you need to mock a concrete non-virtual method, extract an interface, mark the method `virtual`, or use a wrapper.

```csharp
// This Setup is silently ignored — HttpClient.GetAsync is not virtual
var client = new Mock<HttpClient>();
client.Setup(c => c.GetAsync(It.IsAny<string>())).ReturnsAsync(new HttpResponseMessage());
// ↑ real GetAsync runs, test likely fails or hits the network

// Correct approach: wrap HttpClient behind IHttpClientWrapper or use HttpMessageHandler mock
```

---

## Gotchas

- **Moq can only mock virtual methods, interfaces, and abstract members.** If you try to mock a concrete non-virtual method, Moq silently ignores the setup and the real method runs. This is the most common source of "my mock isn't working" — check that the interface method or the method on the concrete class is `virtual`.

- **Verifying call counts instead of outputs couples tests to implementation.** `_repo.Verify(r => r.GetByIdAsync(It.IsAny<int>()), Times.Once)` breaks if you refactor to call the repo twice internally for a valid reason. Assert on the observable result; reserve `Verify` for fire-and-forget side effects.

- **`It.IsAny<T>()` in Setup conflicts with specific-value setups based on registration order.** If you set up `GetByIdAsync(It.IsAny<int>())` and also `GetByIdAsync(1)`, Moq uses the last registered setup. Put specific setups last.

- **Async methods must be set up with `ReturnsAsync()`, not `Returns()`.** `.Returns(Task.FromResult(value))` works but `.Returns(value)` on an async interface method throws at runtime. Always use `ReturnsAsync(value)` or `Returns(Task.CompletedTask)` for `Task`-returning methods.

- **`MockBehavior.Strict` breaks if any infrastructure call hits your mock unexpectedly.** This includes logging extensions and `ToString()` calls that internally resolve through your mocked interface. Start with default behavior and narrow to Strict only when needed.

- **NSubstitute requires `await` on async `Received()` checks.** `email.Received(1).SendAsync(...)` without `await` compiles and passes silently even if the method was never called. Always `await email.Received(1).SendAsync(...)`.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between stubs, mocks, and fakes — and specifically, what's worth verifying vs what's just noise in a test.

**Common question forms:**
- *"What's the difference between a mock and a stub?"*
- *"When would you use `Verify()` in a test?"*
- *"How do you test a method that sends an email?"*
- *"What's the difference between Moq and NSubstitute?"*

**The depth signal:** A junior says "use Moq, set up the method, verify it was called" and verifies every single call in every test. A senior distinguishes stubs (control inputs), mocks (verify interactions), and fakes (working implementations) — and knows the rule: verify calls only for side effects with no observable return value. They reach for `MockBehavior.Strict` on high-risk interfaces, know when a hand-written fake beats twenty lines of `Setup()` repetition across tests, and can explain why over-mocking produces tests that pass when behavior is wrong and fail when behavior is correct.

**Follow-up questions to expect:**
- *"When would you use NSubstitute instead of Moq?"* — Personal/team preference; NSubstitute has less ceremonial syntax and avoids the `.Object` suffix everywhere. Moq is more widely documented. After the Moq 4.20 telemetry incident, NSubstitute gained adoption.
- *"Can you mock `HttpClient` with Moq?"* — No, not directly — `GetAsync` is not virtual. The correct approach is to mock `HttpMessageHandler` or use a typed `IHttpClientFactory` wrapper.

---

## Related Topics

- [[dotnet/testing/testing-unit-tests.md]] — Mocking is the isolation mechanism that makes unit tests possible; the two topics are inseparable.
- [[dotnet/testing/testing-test-isolation.md]] — Hand-written fakes and their seed patterns are covered in the isolation topic alongside test data builders.
- [[dotnet/webapi/dependency-injection.md]] — Constructor injection is what makes mocking work — a class that instantiates its own dependencies can't have them replaced with fakes.
- [[dotnet/pattern/pattern-repository.md]] — Repositories are the most commonly mocked dependency; understanding the interface contract clarifies what the mock should and shouldn't simulate.
- [[dotnet/testing/testing-integration-tests.md]] — Knowing where mocking ends and integration testing begins determines whether a test suite actually catches real failures.

---

## Source

https://github.com/devlooped/moq/wiki/Quickstart

---
*Last updated: 2026-04-12*