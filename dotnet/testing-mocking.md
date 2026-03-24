# Mocking in .NET Tests

> A mock is a fake object that stands in for a real dependency during testing, letting you control what it returns and verify how it was used.

---

## When To Use It
Use mocking when the class under test has dependencies that are slow, non-deterministic, or have side effects — database calls, HTTP requests, email sending, clock reads. Mocking isolates the logic you're actually testing from everything around it. Don't mock types you own when a hand-written fake is simpler and more readable. Never mock value types, static methods, or `sealed` classes — Moq can't intercept those without additional tooling.

---

## Core Concept
When you inject `IOrderRepository` into a service, the test can supply a fake implementation instead of the real one. A mock goes further than a simple fake — it lets you program exactly what each method returns per call, and then verify after the fact that specific methods were called with specific arguments. The three concepts people conflate are: a **stub** (returns canned data, you don't verify calls), a **mock** (you verify calls were made), and a **fake** (a working lightweight implementation, like an in-memory list). In practice, Moq objects do all three depending on how you use them. The rule of thumb: assert on outputs and state first; only use `Verify()` for side effects that have no return value to assert on — like sending an email or publishing an event.

---

## The Code
```csharp
// Setup
// dotnet add package Moq
// dotnet add package NSubstitute   ← alternative, shown in example 5
// dotnet add package FluentAssertions
```
```csharp
// 1. Basic stub — control return values
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
             .ReturnsAsync(expected);                  // stub: always return this for id=1

        var result = await _sut.GetOrderAsync(1);

        result.Should().BeEquivalentTo(expected);
    }
}
```
```csharp
// 2. Verify — assert a side effect happened
[Fact]
public async Task CancelOrder_ValidOrder_SendsCancellationEmail()
{
    _repo.Setup(r => r.GetByIdAsync(1))
         .ReturnsAsync(new Order { Id = 1, Status = OrderStatus.Pending,
                                   CustomerEmail = "x@y.com" });

    await _sut.CancelOrderAsync(1);

    // Only use Verify for side effects with no observable return value
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
     .ReturnsAsync(new Order());                       // matches any int argument

_repo.Setup(r => r.FindByEmailAsync(It.Is<string>(s => s.Contains("@"))))
     .ReturnsAsync(new Customer());                    // matches only valid-looking emails

_repo.Verify(r => r.SaveChangesAsync(), Times.Exactly(1));
_repo.Verify(r => r.GetByIdAsync(It.IsInRange(1, 100, Range.Inclusive)), Times.Once);
```
```csharp
// 4. MockBehavior.Strict — catch unexpected calls
// Default Moq behavior: unsetup calls return default(T) silently
// Strict: unsetup calls throw — safer for catching accidental dependency calls
var repo = new Mock<IOrderRepository>(MockBehavior.Strict);

repo.Setup(r => r.GetByIdAsync(1)).ReturnsAsync(new Order { Id = 1 });
// Any call to repo that isn't GetByIdAsync(1) will now throw InvalidOperationException
```
```csharp
// 5. SetupSequence — different returns on successive calls
_repo.SetupSequence(r => r.GetByIdAsync(1))
     .ReturnsAsync(new Order { Status = OrderStatus.Pending })   // first call
     .ReturnsAsync(new Order { Status = OrderStatus.Cancelled }); // second call
```
```csharp
// 6. Callback — capture arguments or trigger side effects
Order? savedOrder = null;

_repo.Setup(r => r.AddAsync(It.IsAny<Order>()))
     .Callback<Order>(o => savedOrder = o)            // capture what was passed in
     .Returns(Task.CompletedTask);

await _sut.PlaceOrderAsync(new CreateOrderDto { Total = 150m });

savedOrder.Should().NotBeNull();
savedOrder!.Total.Should().Be(150m);
```
```csharp
// 7. NSubstitute — alternative syntax, less ceremony
// dotnet add package NSubstitute

var repo  = Substitute.For<IOrderRepository>();
var email = Substitute.For<IEmailService>();
var sut   = new OrderService(repo, email);

repo.GetByIdAsync(1).Returns(new Order { Id = 1, Status = OrderStatus.Pending });

await sut.CancelOrderAsync(1);

await email.Received(1).SendCancellationAsync("x@y.com");  // NSubstitute verify syntax
```
```csharp
// 8. Hand-written fake — prefer over mocks when logic is reused across many tests
public class FakeOrderRepository : IOrderRepository
{
    private readonly List<Order> _store = new();
    public int SaveCallCount { get; private set; }

    public Task<Order?> GetByIdAsync(int id) =>
        Task.FromResult(_store.FirstOrDefault(o => o.Id == id));

    public Task AddAsync(Order order) { _store.Add(order); return Task.CompletedTask; }

    public Task SaveChangesAsync()
    {
        SaveCallCount++;
        return Task.CompletedTask;
    }

    public void Seed(params Order[] orders) => _store.AddRange(orders);
}
```

---

## Gotchas
- **Moq can only mock virtual methods, interfaces, and abstract members.** If you try to mock a concrete non-virtual method, Moq silently ignores the setup and the real method runs. This is the most common source of "my mock isn't working" — check that the interface method or the method on the concrete class is `virtual`.
- **Verifying call counts instead of outputs couples tests to implementation.** `_repo.Verify(r => r.GetByIdAsync(It.IsAny<int>()), Times.Once)` breaks if you refactor to call the repo twice internally for a valid reason. Assert on the observable result; reserve `Verify` for fire-and-forget side effects (emails, event publishing) where there's nothing to return-value assert on.
- **`It.IsAny<T>()` in Setup conflicts with specific-value setups.** If you set up `GetByIdAsync(It.IsAny<int>())` and also `GetByIdAsync(1)`, Moq uses the last registered setup. Registration order matters — put the more specific setup last.
- **Async methods must be set up with `ReturnsAsync()`, not `Returns()`.**  `.Returns(Task.FromResult(value))` works but `.Returns(value)` on an async interface method throws at runtime. Always use `ReturnsAsync(value)` or `Returns(Task.CompletedTask)` for `Task`-returning methods.
- **`MockBehavior.Strict` breaks if the code under test calls any infrastructure methods you forgot to set up** — including things like `ToString()` or logging extensions that call into your mocked interface indirectly. Start with default behavior and switch to Strict only on interfaces where silent fallthrough has already caused bugs.

---

## Interview Angle
**What they're really testing:** Whether you understand the difference between stubs, mocks, and fakes — and specifically, what's worth verifying vs what's just noise in a test.

**Common question form:** *"What's the difference between a mock and a stub?"* or *"When would you use Verify() in a test?"* or *"How do you test a method that sends an email?"*

**The depth signal:** A junior says "use Moq, set up the method, verify it was called" and verifies every single call in every test. A senior distinguishes stubs (control inputs), mocks (verify interactions), and fakes (working implementations) — and knows the rule: verify calls only for side effects with no observable return value. They reach for `MockBehavior.Strict` on high-risk interfaces, know when a hand-written fake beats twenty lines of `Setup()` repetition across tests, and can explain why over-mocking produces tests that pass when behavior is wrong and fail when behavior is correct.

---

## Related Topics
- [[dotnet/testing-unit-tests.md]] — Mocking is the isolation mechanism that makes unit tests possible; the two topics are inseparable.
- [[dotnet/dependency-injection.md]] — Constructor injection is what makes mocking work — a class that instantiates its own dependencies can't have them replaced with fakes.
- [[dotnet/pattern-repository.md]] — Repositories are the most commonly mocked dependency; understanding the interface contract clarifies what the mock should and shouldn't simulate.
- [[dotnet/testing-integration-tests.md]] — Knowing where mocking ends and integration testing begins determines whether a test suite actually catches real failures.

---

## Source
https://github.com/devlooped/moq/wiki/Quickstart

---
*Last updated: 2026-03-24*