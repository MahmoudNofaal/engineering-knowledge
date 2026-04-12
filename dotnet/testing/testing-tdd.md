# Test-Driven Development (TDD)

> TDD is a development practice where you write a failing test first, then write the minimum code to make it pass, then refactor — in that order, every time.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Design discipline: Red → Green → Refactor loop |
| **Use when** | Logic with clear inputs/outputs; requirements stable enough to test before building |
| **Avoid when** | Exploratory code, infrastructure wiring, configuration, prototypes |
| **Loop** | Write failing test → minimum code to pass → refactor without breaking |
| **Primary benefit** | Design pressure — forces interface definition before implementation |
| **Secondary benefit** | Test coverage as a byproduct |

---

## When To Use It
Use it when building logic with clear inputs and outputs — domain rules, validation, calculations, state machines. The discipline pays off most when requirements are well-defined enough to write a test before you know the implementation. Don't force it on exploratory code where you're still figuring out the right abstraction — spike without tests first, then delete the spike and TDD the real implementation. Don't apply it mechanically to every line of code; configuration wiring, infrastructure setup, and trivial property mappings don't benefit from TDD.

---

## Core Concept
The loop is Red → Green → Refactor. Red: write a test that fails because the behavior doesn't exist yet — it should fail for the right reason (your new logic is missing), not because of a syntax error. Green: write the *simplest possible code* that makes the test pass — no more. Hardcoding a return value to pass the first test is correct technique, not cheating. Refactor: clean up the implementation without breaking the test. Then repeat.

The discipline of writing the test first forces you to think about the interface before the implementation — what should this method be called, what does it take, what does it return, what are the edge cases. You end up with code that is testable by construction because you designed it from the caller's perspective. The test suite is a side effect of the process, not the goal — the goal is better-designed, more maintainable code with fast feedback at every step.

The refactor step is where most practitioners slip. Under time pressure, teams do Red → Green and ship. The refactor step is what prevents TDD codebases from becoming tangled — it's where you extract methods, rename things to match your understanding, and introduce abstractions. Skipping it consistently defeats the long-term value of the practice.

---

## Version History

TDD is a practice, not a library — it has no version history of its own. The tooling that supports it does:

| Tool | Notes |
|---|---|
| xUnit 2.x | Parallel test execution makes Red feedback instant even in large suites |
| xUnit `IAsyncLifetime` | Async test setup without blocking; essential for TDD on async services |
| NCrunch / Live Unit Testing | Continuous test runners that show Red/Green in real time as you type |
| `dotnet watch test` | Built-in watch mode — re-runs tests on save; free alternative to NCrunch |

*`dotnet watch test` is the zero-cost way to get continuous Red/Green feedback. Run it in a terminal alongside your editor and the loop becomes nearly instantaneous.*

---

## Performance

TDD's performance impact is on *developer velocity*, not test execution time. The relevant metrics:

| Metric | With TDD | Without TDD |
|---|---|---|
| Time to first working feature | Slightly slower | Faster initially |
| Time to debug a regression | Much faster | Slower (tests catch regressions immediately) |
| Time to refactor safely | Much faster | Requires manual re-validation |
| Defect rate in maintained code | Lower | Higher |

**The tradeoff:** TDD is slower up front and faster over the lifetime of a feature. For throwaway code the investment never pays off. For production code that will be maintained and extended, the payoff usually comes within the first sprint after the feature ships.

---

## The Code

```csharp
// Worked example: building a discount calculator using TDD
// Each block shows one Red → Green → Refactor cycle

// ── Cycle 1: Red ──────────────────────────────────────────────────────────────
// Write the test first — DiscountCalculator doesn't exist yet, this won't compile
public class DiscountCalculatorTests
{
    [Fact]
    public void Calculate_NoDiscount_ReturnsSamePrice()
    {
        var sut = new DiscountCalculator();
        var result = sut.Calculate(100m, discountPercent: 0);
        result.Should().Be(100m);
    }
}
```

```csharp
// ── Cycle 1: Green ─────────────────────────────────────────────────────────────
// Minimum code to pass — returning price unchanged is enough for this test
public class DiscountCalculator
{
    public decimal Calculate(decimal price, int discountPercent) => price;
}
```

```csharp
// ── Cycle 2: Red ───────────────────────────────────────────────────────────────
// New test forces implementation of actual discount logic
[Fact]
public void Calculate_10PercentDiscount_ReturnsReducedPrice()
{
    var sut = new DiscountCalculator();
    var result = sut.Calculate(100m, discountPercent: 10);
    result.Should().Be(90m);    // fails — current impl returns 100
}
```

```csharp
// ── Cycle 2: Green ─────────────────────────────────────────────────────────────
public class DiscountCalculator
{
    public decimal Calculate(decimal price, int discountPercent) =>
        price - (price * discountPercent / 100m);
}
```

```csharp
// ── Cycle 3: Red — edge case ───────────────────────────────────────────────────
[Fact]
public void Calculate_DiscountOver100_ThrowsArgumentException()
{
    var sut = new DiscountCalculator();
    var act = () => sut.Calculate(100m, discountPercent: 101);
    act.Should().Throw<ArgumentException>().WithMessage("*discount*");
}

[Fact]
public void Calculate_NegativeDiscount_ThrowsArgumentException()
{
    var sut = new DiscountCalculator();
    var act = () => sut.Calculate(100m, discountPercent: -1);
    act.Should().Throw<ArgumentException>();
}
```

```csharp
// ── Cycle 3: Green ─────────────────────────────────────────────────────────────
public class DiscountCalculator
{
    public decimal Calculate(decimal price, int discountPercent)
    {
        if (discountPercent < 0 || discountPercent > 100)
            throw new ArgumentException(
                "Discount must be between 0 and 100.", nameof(discountPercent));

        return price - (price * discountPercent / 100m);
    }
}
```

```csharp
// ── Cycle 3: Refactor ───────────────────────────────────────────────────────────
// Tests are green — now clean up without changing behavior
public class DiscountCalculator
{
    public decimal Calculate(decimal price, int discountPercent)
    {
        ValidateDiscount(discountPercent);
        return price * (1 - discountPercent / 100m);    // cleaner arithmetic
    }

    private static void ValidateDiscount(int discountPercent)
    {
        if (discountPercent is < 0 or > 100)
            throw new ArgumentException(
                "Discount must be between 0 and 100.", nameof(discountPercent));
    }
}
// All three previous tests still pass — refactor is safe
```

```csharp
// ── Consolidated test class after three cycles ─────────────────────────────────
public class DiscountCalculatorTests
{
    private readonly DiscountCalculator _sut = new();

    [Theory]
    [InlineData(100, 0,   100)]
    [InlineData(100, 10,  90)]
    [InlineData(200, 25,  150)]
    [InlineData(50,  100, 0)]
    public void Calculate_ValidInputs_ReturnsCorrectPrice(
        decimal price, int discount, decimal expected)
    {
        _sut.Calculate(price, discount).Should().Be(expected);
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(101)]
    public void Calculate_InvalidDiscount_ThrowsArgumentException(int discount)
    {
        var act = () => _sut.Calculate(100m, discount);
        act.Should().Throw<ArgumentException>();
    }
}
```

---

## Real World Example

An e-commerce platform introduces a returns policy engine: returned items older than 30 days are rejected, items within 30 days get a full refund, but items that have been opened within the first 7 days are ineligible for refund and can only be exchanged. The policy has four distinct branches — exactly the kind of decision logic where TDD shines. The team writes a failing test for each branch before writing the `ReturnsPolicy` class at all.

```csharp
// Red phase: all four tests written before any implementation
public class ReturnsPolicyTests
{
    private readonly Mock<IClock> _clock = new();
    private readonly ReturnsPolicy _sut;
    private readonly DateTime _now = new DateTime(2026, 1, 15);

    public ReturnsPolicyTests()
    {
        _clock.Setup(c => c.UtcNow).Returns(_now);
        _sut = new ReturnsPolicy(_clock.Object);
    }

    [Fact]
    public void Evaluate_ItemOver30DaysOld_ReturnsRejected()
    {
        var item = new ReturnRequest { PurchasedAt = _now.AddDays(-31), IsOpened = false };
        var result = _sut.Evaluate(item);
        result.Outcome.Should().Be(ReturnOutcome.Rejected);
    }

    [Fact]
    public void Evaluate_UnopenedWithin30Days_ReturnsFullRefund()
    {
        var item = new ReturnRequest { PurchasedAt = _now.AddDays(-15), IsOpened = false };
        var result = _sut.Evaluate(item);
        result.Outcome.Should().Be(ReturnOutcome.FullRefund);
    }

    [Fact]
    public void Evaluate_OpenedWithin7Days_ReturnsExchangeOnly()
    {
        var item = new ReturnRequest { PurchasedAt = _now.AddDays(-3), IsOpened = true };
        var result = _sut.Evaluate(item);
        result.Outcome.Should().Be(ReturnOutcome.ExchangeOnly);
    }

    [Fact]
    public void Evaluate_OpenedBetween7And30Days_ReturnsFullRefund()
    {
        var item = new ReturnRequest { PurchasedAt = _now.AddDays(-20), IsOpened = true };
        var result = _sut.Evaluate(item);
        result.Outcome.Should().Be(ReturnOutcome.FullRefund);
    }
}

// Green phase: minimum implementation to pass all four tests
public class ReturnsPolicy
{
    private readonly IClock _clock;

    public ReturnsPolicy(IClock clock) => _clock = clock;

    public ReturnResult Evaluate(ReturnRequest request)
    {
        var age = (_clock.UtcNow - request.PurchasedAt).TotalDays;

        if (age > 30)
            return new ReturnResult(ReturnOutcome.Rejected);

        if (request.IsOpened && age <= 7)
            return new ReturnResult(ReturnOutcome.ExchangeOnly);

        return new ReturnResult(ReturnOutcome.FullRefund);
    }
}

// Refactor phase: the policy logic is already clean — nothing to change.
// But after reviewing with the product team, a fifth rule emerges:
// high-value items (over £500) always require manager approval regardless of age.
// TDD workflow: write the new failing test first, then extend Evaluate().
[Fact]
public void Evaluate_HighValueItemWithin30Days_RequiresManagerApproval()
{
    var item = new ReturnRequest
    {
        PurchasedAt  = _now.AddDays(-5),
        IsOpened     = false,
        PurchaseValue = 600m
    };

    var result = _sut.Evaluate(item);

    result.Outcome.Should().Be(ReturnOutcome.FullRefund);
    result.RequiresApproval.Should().BeTrue();
}
```

*The IClock injection is non-negotiable in TDD for time-dependent logic — the test for "30 days old" must be deterministic. Without a seam for the clock, the 30-day boundary test becomes a time bomb that fails on its 30th birthday.*

---

## Common Misconceptions

**"TDD means writing all your tests before writing any code."**
That's test-first development, not TDD. The Red → Green → Refactor loop is one test at a time, cycling fast. Writing ten tests up front and then implementing everything removes the design pressure that comes from one small failing test at a time — you lose the tight feedback loop and the incremental interface design that makes TDD valuable.

**"The minimum code to make a test pass means writing terrible code."**
"Minimum" means don't implement behavior you haven't written a test for yet. It doesn't mean deliberately write bad code. Returning a hardcoded value to pass the first test is correct — the second test forces generalisation. The refactor step then cleans up whatever was needed to get to green. The goal at Green is correctness, not elegance; the goal at Refactor is elegance.

**"If I write tests after coding I get the same benefit."**
Test-after gives you coverage and regression protection. Test-first gives you all that *plus* a design tool. Writing a test for code you've already written rarely surfaces design problems — you tend to write tests that fit the implementation you already built rather than the interface you should have built. The design pressure only comes when the test exists before the code does.

---

## Gotchas

- **Writing multiple tests before any implementation breaks the loop.** The value of Red→Green→Refactor is the tight feedback cycle — one failing test, one small implementation, immediate confirmation. Writing ten tests first and then implementing everything is just test-first development, not TDD.

- **"Write the minimum code to pass" doesn't mean write bad code.** It means don't implement behavior you haven't written a test for yet. Hardcoding a return value to pass the first test is fine — the next test forces you to generalise. People misread this as permission to write deliberately terrible code, which defeats the refactor step.

- **TDD doesn't eliminate the need to think about design upfront.** If you start TDD on the wrong abstraction, you'll have a well-tested wrong abstraction. You still need to think about what class, interface, and method name makes sense before writing the first test — TDD refines the design, it doesn't replace it.

- **Refactoring without a passing test suite first is risky.** The refactor step is only safe when all tests are green. If you refactor during the Red phase, you're changing code with no safety net. The discipline of waiting until Green before refactoring is harder than it sounds under time pressure.

- **TDD is slower up front and faster overall — the tradeoff isn't always worth it.** For prototypes, one-off scripts, or genuinely exploratory work, TDD adds friction with limited payoff. Knowing when *not* to TDD is part of the skill.

- **Forgetting the IClock abstraction makes time-dependent TDD tests into time bombs.** Any test that asserts on behavior relative to "now" — expiry, age, cooldown periods — must inject `IClock` or use .NET 8's `TimeProvider`. A test for "rejects items over 30 days old" that calls `DateTime.UtcNow` internally will silently break 30 days after it's written.

---

## Interview Angle

**What they're really testing:** Whether you've actually practised TDD or just read about it — and whether you understand the design benefits, not just the test coverage benefits.

**Common question forms:**
- *"Do you practise TDD? Walk me through how you'd TDD a feature."*
- *"What are the benefits of writing tests first?"*
- *"What's the difference between TDD and just having good test coverage?"*

**The depth signal:** A junior says "you write the test first so you have test coverage." A senior explains that test coverage is a byproduct — the real benefit is design pressure. Writing the test first forces you to define the interface from the caller's perspective before you're invested in an implementation. They describe the Red→Green→Refactor loop concretely, know that "minimum code to pass" is about scope discipline not code quality, can articulate when TDD is the wrong tool (exploratory spikes, infrastructure wiring, prototypes), and understand that the refactor step is where the design actually improves — most people skip it under time pressure, which is why codebases written with TDD but without disciplined refactoring don't look any better than ones without.

**Follow-up questions to expect:**
- *"What's the difference between TDD and BDD?"* — BDD (Behaviour-Driven Development) extends TDD by writing tests in a shared language (Given/When/Then) that non-technical stakeholders can read. `SpecFlow` is the .NET library. TDD is an internal development discipline; BDD is a collaboration format.
- *"How do you TDD code that has external dependencies?"* — Mock them from the first test. The act of writing the mock setup forces you to define the interface the production code needs — that's another layer of design pressure from TDD.

---

## Related Topics

- [[dotnet/testing/testing-unit-tests.md]] — TDD produces unit tests as its artifact; understanding what makes a good unit test is a prerequisite for practising TDD effectively.
- [[dotnet/testing/testing-fluentassertions.md]] — Readable assertions are especially important in TDD because the failing test is the first thing you read — a clear failure message accelerates the Red→Green cycle.
- [[dotnet/testing/testing-mocking.md]] — TDD on classes with dependencies requires mocking from the first test; knowing when to inject a fake vs reach for Moq is part of the TDD workflow.
- [[dotnet/testing/testing-xunit.md]] — The runner mechanics that the TDD loop depends on: watch mode, parallel execution, test naming conventions.
- [[dotnet/pattern/solid-principles.md]] — TDD naturally pushes code toward SRP and DIP — classes designed test-first tend to be smaller and more focused because large classes are painful to test.

---

## Source

https://martinfowler.com/bliki/TestDrivenDevelopment.html

---
*Last updated: 2026-04-12*