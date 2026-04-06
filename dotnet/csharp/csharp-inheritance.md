# C# Inheritance

> Inheritance lets one class acquire the fields, properties, and methods of another, enabling code reuse and polymorphic behaviour through a shared base type.

---

## Quick Reference

| | |
|---|---|
| **What it is** | One class extending another to inherit its members |
| **Use when** | Genuine is-a relationship exists with shared implementation |
| **Avoid when** | Only code reuse is needed without is-a — use composition instead |
| **C# version** | C# 1.0 |
| **Namespace** | N/A — language primitive |
| **Key keywords** | `: BaseClass`, `base`, `virtual`, `override`, `abstract`, `sealed`, `new` |

---

## When To Use It

Use inheritance when a genuine **is-a** relationship exists — `Dog` is an `Animal`, `SavingsAccount` is a `BankAccount`, `SqlOrderRepository` is an `OrderRepository`. It's the right tool when subclasses share real implementation and you want polymorphic dispatch through a common base type.

Prefer **composition** (holding another object as a field) over inheritance when:
- The relationship is has-a, not is-a (`Car` has an `Engine`, not `Car` is an `Engine`).
- You only want code reuse without polymorphism.
- The hierarchy would be more than 2–3 levels deep.
- You're designing a library and the hierarchy might need to change.

The Liskov Substitution Principle is the test: every subclass must be fully substitutable for its base class without breaking any caller. If you find yourself overriding base methods to throw `NotSupportedException`, the hierarchy is wrong.

---

## Core Concept

When class `B` inherits from class `A` (`class B : A`), `B` gets everything `A` has — its fields, properties, and non-private methods. `B` can add new members or override virtual ones. A variable typed as `A` can hold a `B` instance, and a call to a virtual method dispatches to `B`'s version at runtime — this is polymorphism.

C# only allows **single inheritance** for classes (a class can extend only one other class). Multiple inheritance is achieved via interfaces — a class can implement as many interfaces as needed.

The `base` keyword lets a subclass call its parent's constructor or method. The `override` keyword replaces a parent's virtual method in the vtable. The `new` keyword *hides* a parent method without replacing the vtable entry — a base-typed reference still calls the base version, making `new` almost always wrong.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Class inheritance, `virtual`, `override`, `abstract`, `sealed` |
| C# 2.0 | .NET 2.0 | Generics — `List<T>` extends `IEnumerable<T>` |
| C# 7.0 | .NET Core 1.0 | Pattern matching on types in switch |
| C# 8.0 | .NET Core 3.0 | Default interface methods (interface inheritance) |
| C# 9.0 | .NET 5 | Records support inheritance (`record B : A`) |
| C# 11.0 | .NET 7 | `abstract static` members on interfaces |

*C# 8's default interface methods blurred the line between interfaces and abstract classes slightly — interfaces can now carry default method implementations. The design distinction still applies: interfaces model contracts, abstract classes model shared implementation.*

---

## Performance

| Method type | Dispatch cost | JIT optimisation |
|---|---|---|
| Non-virtual method | Direct call | Fully inlinable |
| `virtual` method | Vtable lookup + indirect call | Cannot inline unless devirtualised |
| `override` on `sealed` class | Vtable lookup (but JIT devirtualises) | Can inline after devirtualisation |
| `abstract` method | Same as virtual | Cannot inline |
| Interface method | Interface table lookup | Same as virtual |

**Allocation behaviour:** Inheritance adds no allocation overhead. The cost is entirely in dispatch — one extra memory read for vtable lookup on virtual calls. This is negligible for code that doesn't call virtual methods millions of times per second.

**Benchmark notes:** Virtual dispatch costs roughly 1–2 ns per call on modern CPUs. It only becomes a bottleneck in extremely tight loops (game engines, numeric processing). For typical business logic, the cost is immeasurable. `sealed` on a class or override enables devirtualisation — the JIT can prove which method will be called and inline it.

---

## The Code

**Basic inheritance and constructor chaining**
```csharp
public class Animal
{
    public string Name { get; }
    public int Age { get; }

    // base class constructor — must be called by subclasses
    protected Animal(string name, int age)
    {
        if (string.IsNullOrWhiteSpace(name)) throw new ArgumentException("Name required.");
        Name = name;
        Age  = age;
    }

    // virtual: subclasses CAN override this
    public virtual string Speak() => "...";

    public override string ToString() => $"{GetType().Name}({Name}, age {Age})";
}

public class Dog : Animal
{
    public string Breed { get; }

    // base(...) must be called first
    public Dog(string name, int age, string breed) : base(name, age)
    {
        Breed = breed;
    }

    // override: replaces the vtable slot — works through Animal reference
    public override string Speak() => $"{Name} says: Woof!";
}

Animal a = new Dog("Rex", 3, "Labrador");
Console.WriteLine(a.Speak());    // "Rex says: Woof!" — Dog's version via vtable
Console.WriteLine(a);            // "Dog(Rex, age 3)" — ToString resolves to Dog
```

**`new` vs `override` — the critical difference**
```csharp
public class Base
{
    public virtual void VirtualMethod()  => Console.WriteLine("Base.Virtual");
    public void         ConcreteMethod() => Console.WriteLine("Base.Concrete");
}

public class Derived : Base
{
    // override = participates in virtual dispatch — called through Base reference
    public override void VirtualMethod()  => Console.WriteLine("Derived.Virtual");

    // new = HIDES the base method — NOT called through a Base reference
    public new void ConcreteMethod() => Console.WriteLine("Derived.Concrete");
}

Base b = new Derived();
b.VirtualMethod();   // "Derived.Virtual"  — runtime dispatch to Derived
b.ConcreteMethod();  // "Base.Concrete"    — no vtable, declared type wins

Derived d = new Derived();
d.ConcreteMethod();  // "Derived.Concrete" — only reachable through Derived-typed ref
```

**`abstract` — force subclasses to provide implementation**
```csharp
public abstract class ReportGenerator
{
    // Abstract method — no body, every subclass MUST implement
    public abstract string GenerateContent();

    // Concrete method — shared by all subclasses
    public string Generate()
    {
        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"=== Report: {GetType().Name} ===");
        sb.AppendLine($"Generated: {DateTime.UtcNow:O}");
        sb.AppendLine(GenerateContent()); // calls subclass implementation
        return sb.ToString();
    }
}

public class SalesReport : ReportGenerator
{
    private readonly decimal _revenue;
    public SalesReport(decimal revenue) => _revenue = revenue;

    public override string GenerateContent() => $"Total Revenue: {_revenue:C}";
}

// new ReportGenerator(); // compile error — cannot instantiate abstract class
var report = new SalesReport(49_999.99m);
Console.WriteLine(report.Generate());
```

**`sealed` — stop the hierarchy and enable devirtualisation**
```csharp
// sealed class: nothing can inherit from this
public sealed class SqlOrderRepository : IOrderRepository { ... }

// sealed override: stops THIS method from being overridden further
public class AuditableService : BaseService
{
    public sealed override void Log(string message)
    {
        // This implementation cannot be overridden by further subclasses
        AuditLog.Write(message);
        base.Log(message);
    }
}
```

**`base` — calling the parent**
```csharp
public class TimestampLogger : ConsoleLogger
{
    public override void Log(string message)
    {
        // Extend parent behaviour rather than replace it
        base.Log($"[{DateTime.UtcNow:O}] {message}");
    }
}
```

---

## Real World Example

An e-commerce notification system uses an abstract base class to define the notification contract and shared infrastructure, while concrete subclasses implement the actual delivery mechanism. Adding a new channel requires adding one class with no changes to existing code — the Open/Closed Principle in practice.

```csharp
public abstract class NotificationChannel
{
    protected readonly ILogger Logger;
    protected readonly NotificationConfig Config;

    protected NotificationChannel(ILogger logger, NotificationConfig config)
    {
        Logger = logger;
        Config = config;
    }

    // Template Method pattern: skeleton defined here, steps implemented below
    public async Task<bool> NotifyAsync(
        string recipient,
        string subject,
        string body,
        CancellationToken ct = default)
    {
        if (!IsEnabled())
        {
            Logger.LogDebug("{Channel} is disabled — skipping", GetType().Name);
            return false;
        }

        try
        {
            await SendAsync(recipient, subject, body, ct);
            Logger.LogInformation("{Channel} sent to {Recipient}", GetType().Name, recipient);
            return true;
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "{Channel} failed for {Recipient}", GetType().Name, recipient);
            return false;
        }
    }

    // Each channel implements its own delivery logic
    protected abstract Task SendAsync(string recipient, string subject, string body, CancellationToken ct);

    // Subclasses can override this to add their own enabled check
    protected virtual bool IsEnabled() => Config.IsEnabled;
}

public sealed class EmailChannel : NotificationChannel
{
    private readonly IEmailClient _client;

    public EmailChannel(IEmailClient client, ILogger<EmailChannel> logger, NotificationConfig config)
        : base(logger, config) => _client = client;

    protected override async Task SendAsync(string recipient, string subject, string body, CancellationToken ct)
        => await _client.SendAsync(recipient, subject, body, ct);
}

public sealed class SmsChannel : NotificationChannel
{
    private readonly ISmsGateway _gateway;

    public SmsChannel(ISmsGateway gateway, ILogger<SmsChannel> logger, NotificationConfig config)
        : base(logger, config) => _gateway = gateway;

    protected override async Task SendAsync(string recipient, string subject, string body, CancellationToken ct)
        => await _gateway.SendSmsAsync(recipient, $"{subject}: {body}", ct);

    // SMS has an additional enabled check based on recipient format
    protected override bool IsEnabled()
        => base.IsEnabled() && Config.SmsEnabled;
}

// Caller works through the base type — doesn't know which channel it has
IEnumerable<NotificationChannel> channels = GetConfiguredChannels();
foreach (var channel in channels)
    await channel.NotifyAsync(user.Phone, "Order confirmed", $"Order #{orderId}", ct);
```

*The key insight: `NotifyAsync` in the base class handles logging and error recovery the same way for every channel. Subclasses only implement the delivery-specific `SendAsync` — typically 3–5 lines. This is the Template Method pattern enabled by inheritance, and it's the right use of abstract classes: shared infrastructure code that's identical across variants, with a single variation point.*

---

## Common Misconceptions

**"`override` and `new` both replace the base method"**
`override` replaces the vtable slot — a base-typed reference calls the derived version. `new` hides the base method without touching the vtable — a base-typed reference still calls the base version. Only `override` produces polymorphism. `new` is almost never the right choice; when you think you want `new`, you usually want `override` or a completely separate method.

**"Inheritance is the primary way to reuse code"**
Inheritance is the primary way to model is-a relationships. Code reuse that doesn't come with is-a should use composition — hold a dependency as a field and call it. Inheritance creates tight coupling between base and derived classes: changes to the base can silently break all derived classes. Composition doesn't have this problem.

**"You can always add new abstract members to an existing abstract class"**
Adding a new `abstract` member to a base class is a breaking change — every existing concrete subclass now fails to compile until it implements the new member. This is the opposite of interfaces with default interface methods (C# 8+), where a default implementation prevents compile breakage. Plan abstract class hierarchies carefully in public APIs.

---

## Gotchas

- **Calling virtual methods in a constructor is dangerous.** The base constructor runs first. If it calls a virtual method, and the derived class overrides it, the override executes against an object whose derived constructor hasn't run yet — so derived fields are still at default values. The compiler gives no warning. This is a real bug pattern.

- **`protected` is wider than "internal to the class".** Any subclass in any assembly (including third parties) can access `protected` members. Don't use `protected` for state that should truly stay internal — use `private` and expose it via `protected` properties with controlled access.

- **Deep hierarchies are fragile.** A three-level hierarchy (`A → B → C`) means `C` knows about both `A`'s and `B`'s implementation details. Changes in `A` can break `C` in ways that are hard to trace. Prefer flat hierarchies (one level deep) and favour composition for the rest.

- **`new` on a method hides without overriding.** A derived class member declared with `new` is invisible to any caller holding a base-typed reference. This creates the confusing situation where `derived.Method()` and `((Base)derived).Method()` call different code. The only legitimate use of `new` is to resolve a naming conflict with a newly added base class method.

- **The Liskov Substitution Principle is the real correctness test.** If you find yourself throwing `NotImplementedException` or `NotSupportedException` in an override, or narrowing pre-conditions, the hierarchy is wrong. The derived class must honour all contracts of the base class, not just the ones it cares about.

---

## Interview Angle

**What they're really testing:** Whether you understand virtual dispatch mechanics, can distinguish `override` from `new`, and know when inheritance is the wrong tool.

**Common question forms:**
- "What's the difference between `override` and `new` on a method?"
- "What happens if you forget `virtual` on a base class method?"
- "When would you choose composition over inheritance?"
- "What is the Liskov Substitution Principle?"

**The depth signal:** A junior says "`override` changes a method and `new` also changes it." A senior explains the vtable: `virtual` creates a dispatchable slot; `override` replaces that slot in the subclass's table; a base-typed reference looks up the runtime type's slot, dispatching to the derived version. `new` doesn't touch the vtable — a base-typed reference always calls the base version. They name LSP as the correctness test and give a concrete example of a violation (`ReadOnlyList` that inherits `List` and throws on `Add`). They can also articulate when composition is right: when you want the behaviour of another class without the is-a relationship.

**Follow-up questions to expect:**
- "Can a derived class override a non-virtual method?"
- "What is the Template Method pattern and how does it relate to abstract classes?"
- "If a base class has a `virtual` method and the derived class has `override sealed`, what does that mean?"

---

## Related Topics

- [[dotnet/csharp/csharp-classes.md]] — Inheritance is built on top of classes; `virtual`, `override`, and constructors are all class concepts first
- [[dotnet/csharp/csharp-polymorphism.md]] — Virtual dispatch and runtime type behaviour is the payoff for setting up inheritance correctly
- [[dotnet/csharp/csharp-interfaces.md]] — The alternative to inheritance for polymorphism; C#'s answer to multiple inheritance
- [[dotnet/csharp/csharp-abstract-classes.md]] — Abstract classes are a form of inheritance; virtual dispatch and `override` mechanics apply throughout

---

## Source

[Inheritance — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/inheritance)

---

*Last updated: 2026-04-06*