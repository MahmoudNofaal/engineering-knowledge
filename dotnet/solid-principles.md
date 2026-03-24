# SOLID Principles

> Five design principles that, applied together, keep object-oriented code easy to change, test, and extend without breaking what already works.

---

## When To Use It
SOLID isn't a feature you turn on — it's a lens you apply when writing or reviewing code. It matters most when a codebase needs to grow: new requirements, new developers, new integrations. Violations are cheap to ignore early and expensive to fix later. Don't treat it as a checklist to satisfy mechanically — over-applying SOLID to a 50-line script or a simple CRUD endpoint creates unnecessary abstraction layers with no payoff.

---

## Core Concept
Each letter targets a specific way code rots over time. SRP stops classes from accumulating unrelated responsibilities until they're impossible to test. OCP stops you from editing working code every time a new case is added. LSP stops subtypes from silently breaking the contract the base type promised. ISP stops classes from depending on methods they'll never call. DIP stops high-level logic from being locked to low-level implementations. In practice, violations of one principle usually drag in violations of others — a class that does too much (SRP) also tends to be hard to extend without editing (OCP) and impossible to test without its concrete dependencies (DIP). Fixing one often cascades into fixing the others.

---

## The Code
```csharp
// ── S: Single Responsibility Principle ───────────────────────────────────────
// BAD: one class handles order logic AND persistence AND email
public class OrderService
{
    public void PlaceOrder(Order order)
    {
        // validate
        // save to DB directly
        // send confirmation email directly
    }
}

// GOOD: each class has one reason to change
public class OrderService
{
    private readonly IOrderRepository _repo;
    private readonly IEmailService _email;

    public OrderService(IOrderRepository repo, IEmailService email)
    {
        _repo = repo;
        _email = email;
    }

    public async Task PlaceOrderAsync(Order order)
    {
        await _repo.AddAsync(order);
        await _email.SendConfirmationAsync(order.CustomerEmail);
    }
}
```
```csharp
// ── O: Open/Closed Principle ─────────────────────────────────────────────────
// BAD: adding a new payment method means editing this method
public decimal CalculateFee(string paymentType, decimal amount) => paymentType switch
{
    "stripe" => amount * 0.029m + 0.30m,
    "paypal" => amount * 0.034m + 0.30m,
    _ => throw new ArgumentException("Unknown type")   // edit here every time
};

// GOOD: new payment type = new class, zero edits to existing code
public interface IFeeCalculator { decimal Calculate(decimal amount); }

public class StripeFeeCalculator : IFeeCalculator
    { public decimal Calculate(decimal amount) => amount * 0.029m + 0.30m; }

public class PayPalFeeCalculator : IFeeCalculator
    { public decimal Calculate(decimal amount) => amount * 0.034m + 0.30m; }
```
```csharp
// ── L: Liskov Substitution Principle ─────────────────────────────────────────
// BAD: Square breaks the Rectangle contract — callers expecting Rectangle behavior get surprises
public class Rectangle
{
    public virtual int Width  { get; set; }
    public virtual int Height { get; set; }
    public int Area() => Width * Height;
}

public class Square : Rectangle
{
    public override int Width  { set { base.Width = base.Height = value; } }  // breaks caller
    public override int Height { set { base.Width = base.Height = value; } }
}

// GOOD: separate types, no inheritance; share behaviour through an interface if needed
public interface IShape { int Area(); }
public record Rectangle(int Width, int Height) : IShape { public int Area() => Width * Height; }
public record Square(int Side) : IShape               { public int Area() => Side * Side; }
```
```csharp
// ── I: Interface Segregation Principle ───────────────────────────────────────
// BAD: implementors are forced to implement methods they don't use
public interface IWorker
{
    void Work();
    void TakeBreak();
    void ReceiveSalary();    // robots don't need this
}

// GOOD: split into focused interfaces — classes implement only what they need
public interface IWorkable  { void Work(); }
public interface IBreakable { void TakeBreak(); }
public interface IPayable   { void ReceiveSalary(); }

public class Robot : IWorkable
{
    public void Work() => Console.WriteLine("Working...");
    // no break, no salary
}

public class Employee : IWorkable, IBreakable, IPayable
{
    public void Work()          => Console.WriteLine("Working...");
    public void TakeBreak()     => Console.WriteLine("On break...");
    public void ReceiveSalary() => Console.WriteLine("Paid.");
}
```
```csharp
// ── D: Dependency Inversion Principle ────────────────────────────────────────
// BAD: high-level service depends on a concrete low-level class
public class ReportService
{
    private readonly SqlReportRepository _repo = new();  // locked to SQL forever

    public Report Generate(int id) => _repo.GetById(id);
}

// GOOD: both depend on the abstraction — implementation is injected
public interface IReportRepository { Report GetById(int id); }

public class ReportService
{
    private readonly IReportRepository _repo;
    public ReportService(IReportRepository repo) => _repo = repo;  // inject anything

    public Report Generate(int id) => _repo.GetById(id);
}

public class SqlReportRepository   : IReportRepository { public Report GetById(int id) => default!; }
public class CachedReportRepository : IReportRepository { public Report GetById(int id) => default!; }
```

---

## Gotchas
- **SRP doesn't mean one method per class.** "One reason to change" means one stakeholder or concern drives changes to the class — not that the class is minimal. A class with ten cohesive methods that all serve the same concern is fine. A class with two methods from two different concerns is not.
- **OCP is not "never edit a class."** It means the common extension points shouldn't require editing existing working code. You still edit classes to fix bugs or make them extensible in the first place. The principle targets the *direction* of change, not change itself.
- **LSP violations are often silent.** A subclass that overrides a method and throws `NotImplementedException`, returns `null` where the base never did, or ignores a parameter the base honors — all violate LSP. The violation isn't a compile error; it's a broken assumption that surfaces as a production bug.
- **ISP violations multiply over time.** A fat interface that starts with four methods grows to twelve because each new feature adds to the one shared interface. Every implementor then inherits the burden of stub-implementing methods that don't apply to them. Catch this early by questioning whether every implementor genuinely needs every method.
- **DIP doesn't mean "always use an interface."** Abstractions should be driven by what the high-level module needs, not by reflexively wrapping every class. A `Logger` that's only ever `SerilogLogger` in production doesn't need `ILogger<T>` unless you're testing code that uses it — though in .NET, `ILogger<T>` is standard and should always be used.

---

## Interview Angle
**What they're really testing:** Whether you can apply the principles to real design decisions — not recite definitions — and whether you know when *not* to apply them.

**Common question form:** *"Can you explain SOLID?"* or *"Which SOLID principle does this code violate and how would you fix it?"* — often presented with a specific code snippet.

**The depth signal:** A junior recites acronym definitions and gives textbook examples. A senior connects each principle to a concrete failure mode they've seen (the service class that accumulates responsibilities until it can't be tested; the `switch` statement that grows a new case every sprint; the subclass that throws `NotSupportedException` on half the interface), knows which violations commonly co-occur, and can articulate when the cure is worse than the disease — e.g., ISP taken too far produces twenty single-method interfaces that are harder to navigate than one reasonable one.

---

## Related Topics
- [[dotnet/dependency-injection.md]] — DIP is only actionable when a DI container wires the abstractions to implementations; SOLID and DI are inseparable in .NET.
- [[dotnet/pattern-strategy.md]] — OCP violations are most commonly fixed with the strategy pattern; the two concepts directly reinforce each other.
- [[dotnet/pattern-decorator.md]] — Decorators add behavior while keeping SRP and OCP intact — a concrete example of two principles working together.
- [[dotnet/pattern-repository.md]] — The repository pattern exists partly to satisfy DIP — business logic depends on `IRepository`, not on EF Core directly.

---

## Source
https://learn.microsoft.com/en-us/archive/msdn-magazine/2014/may/csharp-best-practices-dangers-of-violating-solid-principles-in-csharp

---
*Last updated: 2026-03-24*