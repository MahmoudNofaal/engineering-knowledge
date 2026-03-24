# Test-Driven Development (TDD)

> TDD is a development practice where you write a failing test first, then write the minimum code to make it pass, then refactor — in that order, every time.

---

## When To Use It
Use it when building logic with clear inputs and outputs — domain rules, validation, calculations, state machines. The discipline pays off most when requirements are well-defined enough to write a test before you know the implementation. Don't force it on exploratory code where you're still figuring out the right abstraction — spike without tests first, then delete the spike and TDD the real implementation. Don't apply it mechanically to every line of code; configuration wiring, infrastructure setup, and trivial property mappings don't benefit from TDD.

---

## Core Concept
The loop is Red → Green → Refactor. Red: write a test that fails because the behavior doesn't exist yet. Green: write the simplest possible code that makes the test pass — no more. Refactor: clean up the implementation without breaking the test. Then repeat. The discipline of writing the test first forces you to think about the interface before the implementation — what should this method be called, what does it take, what does it return. You end up with code that is testable by construction, because you designed it from the caller's perspective. The test suite is a side effect of the process, not the goal — the goal is better-designed code with fast feedback.

---

## The Code
```csharp
// Worked example: building a discount calculator using TDD
// Each block represents one Red→Green→Refactor cycle

// ── Cycle 1: Red ─────────────────────────────────────────────────────────────
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
// ── Cycle 1: Green ────────────────────────────────────────────────────────────
// Write the minimum code to make it pass — nothing more
public class DiscountCalculator
{
    public decimal Calculate(decimal price, int discountPercent) => price;
    // Returning price with no discount is enough to pass the first test
}
```
```csharp
// ── Cycle 2: Red ─────────────────────────────────────────────────────────────
// Add the next failing test — forces implementation of actual discount logic
[Fact]
public void Calculate_10PercentDiscount_ReturnsReducedPrice()
{
    var sut = new DiscountCalculator();
    var result = sut.Calculate(100m, discountPercent: 10);
    result.Should().Be(90m);                             // fails — current impl returns 100
}
```
```csharp
// ── Cycle 2: Green ────────────────────────────────────────────────────────────
public class DiscountCalculator
{
    public decimal Calculate(decimal price, int discountPercent) =>
        price - (price * discountPercent / 100m);
}
```
```csharp
// ── Cycle 3: Red — edge case ─────────────────────────────────────────────────
[Fact]
public void Calculate_DiscountOver100_ThrowsArgumentException()
{
    var sut = new DiscountCalculator();
    var act = () => sut.Calculate(100m, discountPercent: 101);
    act.Should().Throw<ArgumentException>()
       .WithMessage("*discount*");
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
// ── Cycle 3: Green ────────────────────────────────────────────────────────────
public class DiscountCalculator
{
    public decimal Calculate(decimal price, int discountPercent)
    {
        if (discountPercent < 0 || discountPercent > 100)
            throw new ArgumentException("Discount must be between 0 and 100.", nameof(discountPercent));

        return price - (price * discountPercent / 100m);
    }
}
```
```csharp
// ── Cycle 3: Refactor ─────────────────────────────────────────────────────────
// Tests pass — now clean up without changing behavior
public class DiscountCalculator
{
    public decimal Calculate(decimal price, int discountPercent)
    {
        ValidateDiscount(discountPercent);
        return price * (1 - discountPercent / 100m);
    }

    private static void ValidateDiscount(int discountPercent)
    {
        if (discountPercent is < 0 or > 100)
            throw new ArgumentException(
                "Discount must be between 0 and 100.", nameof(discountPercent));
    }
}
// All three tests still pass — refactor is safe
```
```csharp
// ── Full test class at the end of three cycles ───────────────────────────────
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

## Gotchas
- **"Write the minimum code to pass" doesn't mean write bad code.** It means don't implement behavior you haven't written a test for yet. Returning a hardcoded value to pass the first test is correct — the next test forces you to generalize. People misread this as permission to write deliberately terrible code, which defeats the refactor step.
- **Writing multiple tests before any implementation breaks the loop.** The value of Red→Green→Refactor is the tight feedback cycle — one failing test, one small implementation, immediate confirmation. Writing ten tests first and then implementing everything is just test-first development, not TDD. You lose the design pressure that comes from one test at a time.
- **TDD doesn't eliminate the need to think about design upfront.** If you start TDD on the wrong abstraction, you'll have a well-tested wrong abstraction. You still need to think about what class, interface, and method name makes sense before writing the first test — TDD refines the design, it doesn't replace it.
- **Refactoring without a passing test suite first is risky.** The refactor step is only safe when all tests are green. If you refactor during the Red phase, you're changing code with no safety net. The discipline of waiting until Green before refactoring is harder than it sounds under time pressure.
- **TDD is slower up front and faster overall — the tradeoff isn't always worth it.** For prototypes, one-off scripts, or genuinely exploratory work, TDD adds friction with limited payoff. The discipline pays off most on code that will be maintained, extended, or handed to someone else. Knowing when *not* to TDD is part of the skill.

---

## Interview Angle
**What they're really testing:** Whether you've actually practiced TDD or just read about it — and whether you understand the design benefits, not just the test coverage benefits.

**Common question form:** *"Do you practice TDD? Walk me through how you'd TDD a feature."* or *"What are the benefits of writing tests first?"*

**The depth signal:** A junior says "you write the test first so you have test coverage." A senior explains that test coverage is a byproduct — the real benefit is design pressure. Writing the test first forces you to define the interface from the caller's perspective before you're invested in an implementation. They describe the Red→Green→Refactor loop concretely, know that "minimum code to pass" is about scope discipline not code quality, can articulate when TDD is the wrong tool (exploratory spikes, infrastructure wiring, prototypes), and understand that the refactor step is where the design actually improves — most people skip it under time pressure, which is why codebases written with TDD but without disciplined refactoring don't look any better than ones without.

---

## Related Topics
- [[dotnet/testing-unit-tests.md]] — TDD produces unit tests as its artifact; understanding what makes a good unit test is a prerequisite for practicing TDD effectively.
- [[dotnet/testing-fluentassertions.md]] — Readable assertions are especially important in TDD because the failing test is the first thing you read — a clear failure message accelerates the Red→Green cycle.
- [[dotnet/testing-mocking.md]] — TDD on classes with dependencies requires mocking from the first test; knowing when to inject a fake vs reach for Moq is part of the TDD workflow.
- [[dotnet/solid-principles.md]] — TDD naturally pushes code toward SRP and DIP — classes designed test-first tend to be smaller and more focused because large classes are painful to test.

---

## Source
https://martinfowler.com/bliki/TestDrivenDevelopment.html

---
*Last updated: 2026-03-24*