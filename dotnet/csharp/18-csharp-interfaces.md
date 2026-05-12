# C# Interfaces

> An interface is a contract — a named set of member signatures that any implementing type must provide — enabling polymorphism across unrelated class hierarchies.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Named contract with zero or more member signatures |
| **Use when** | Decoupling implementations from callers; testability; multiple polymorphic types |
| **Avoid when** | Single implementation that never changes; shared code needed — use abstract class |
| **C# version** | C# 1.0 (default interface methods: C# 8.0) |
| **Namespace** | N/A — language primitive |
| **Key keywords** | `interface`, `implements` (via `:`), `explicit interface implementation` |

---

## When To Use It

Use an interface when you want to **decouple what something does from how it does it**. The canonical cases:

- **Dependency injection**: `OrderService` depends on `IEmailSender`, not `SmtpEmailSender`. Swap implementations or mock in tests without changing `OrderService`.
- **Multiple polymorphic types**: `Dog`, `Printer`, and `Car` can all implement `IPrintable` without sharing any ancestry.
- **Testability**: any dependency that touches I/O, external services, or the clock should be behind an interface so tests can control it.
- **Open/Closed Principle**: callers program to `IExporter`, and new export formats are added without modifying existing code.

Don't use an interface when:
- There's only one concrete implementation that will never be mocked or swapped — the indirection adds no value.
- You need shared implementation or shared state — use an abstract class.
- You're creating interfaces speculatively ("I might need this later") — YAGNI.

---

## Core Concept

An interface is a list of promises. It says: "any class or struct that implements me must provide these members." The interface itself holds no state and (before C# 8) no code. The power is that a variable typed as `IEmailSender` can hold any object that implements it — your code doesn't know or care which one it gets at runtime.

A class can implement **any number of interfaces**, compensating for C#'s single-class inheritance limit. A struct can also implement interfaces, but doing so boxes the struct on assignment to the interface variable.

Since C# 8, interfaces can have **default method implementations** — letting library authors add new members without breaking all existing implementors. This is the main feature that now distinguishes interfaces from abstract classes (interfaces have no constructors and no fields).

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Interfaces, explicit implementation |
| C# 2.0 | .NET 2.0 | Generic interfaces (`IEnumerable<T>`, `IComparable<T>`) |
| C# 4.0 | .NET 4.0 | Covariance (`IEnumerable<out T>`) and contravariance (`IComparer<in T>`) |
| C# 8.0 | .NET Core 3.0 | Default interface methods — add members without breaking implementors |
| C# 8.0 | .NET Core 3.0 | Access modifiers on interface members |
| C# 11.0 | .NET 7 | `abstract static` members — static polymorphism via interfaces |

*C# 4.0's variance annotations (`out T`, `in T`) allow `IEnumerable<Dog>` to be assigned to `IEnumerable<Animal>` (covariance) and `IComparer<Animal>` to be assigned to `IComparer<Dog>` (contravariance). This is why LINQ works across typed sequences.*

---

## Performance

| Scenario | Cost |
|---|---|
| Interface method call | Interface method table lookup (~1–2 ns) |
| Generic constraint call (`where T : IFoo`) | Direct call — zero dispatch overhead |
| Struct implementing interface (stored as interface) | Boxing — heap allocation |
| `is` / pattern match on interface | Single type check |

**Allocation behaviour:** Interface dispatch itself allocates nothing. The object being called was already allocated. The exception is value types (structs) — assigning a struct to an interface variable boxes it.

**Benchmark notes:** Interface dispatch is ~1–2 ns per call on modern hardware, identical to virtual method dispatch. The only scenario where this matters is millions of calls per second in a tight loop. Use generic constraints (`where T : IAnimal`) to eliminate the dispatch cost entirely — the JIT specialises for each concrete `T`.

---

## The Code

**Defining and implementing an interface**
```csharp
public interface IEmailSender
{
    Task SendAsync(string to, string subject, string body, CancellationToken ct = default);
    bool IsConfigured { get; }
}

public sealed class SmtpEmailSender : IEmailSender
{
    private readonly SmtpClient _client;

    public SmtpEmailSender(SmtpClient client) => _client = client;

    public bool IsConfigured => _client.Host is not null;

    public async Task SendAsync(string to, string subject, string body, CancellationToken ct)
        => await _client.SendMailAsync(to, subject, body);
}

// Variable typed as the interface — implementation is invisible to caller
IEmailSender sender = new SmtpEmailSender(client);
await sender.SendAsync("user@example.com", "Hello", "Hi there");
```

**Dependency injection pattern — the primary reason interfaces exist**
```csharp
public class OrderService
{
    // Depends on the CONTRACT — not the concrete class
    private readonly IEmailSender _emailSender;
    private readonly IOrderRepository _repository;

    public OrderService(IEmailSender emailSender, IOrderRepository repository)
    {
        _emailSender = emailSender;
        _repository  = repository;
    }

    public async Task PlaceOrderAsync(Order order, CancellationToken ct)
    {
        await _repository.SaveAsync(order, ct);
        await _emailSender.SendAsync(order.CustomerEmail, "Order Confirmed", $"Order #{order.Id}", ct);
    }
}

// In tests: inject a fake that doesn't hit SMTP
public class FakeEmailSender : IEmailSender
{
    public bool IsConfigured => true;
    public List<(string To, string Subject)> Sent { get; } = new();

    public Task SendAsync(string to, string subject, string body, CancellationToken ct)
    {
        Sent.Add((to, subject));
        return Task.CompletedTask;
    }
}
// Test: var service = new OrderService(new FakeEmailSender(), repo);
```

**Implementing multiple interfaces**
```csharp
public interface IReadable  { Task<string> ReadAsync(CancellationToken ct); }
public interface IWritable  { Task WriteAsync(string data, CancellationToken ct); }
public interface IDisposable { void Dispose(); } // already in BCL

// A class can implement as many interfaces as needed
public sealed class FileBuffer : IReadable, IWritable, IDisposable
{
    private readonly FileStream _stream;

    public FileBuffer(string path) => _stream = File.Open(path, FileMode.OpenOrCreate);

    public async Task<string> ReadAsync(CancellationToken ct)
    {
        _stream.Seek(0, SeekOrigin.Begin);
        using var reader = new StreamReader(_stream, leaveOpen: true);
        return await reader.ReadToEndAsync(ct);
    }

    public async Task WriteAsync(string data, CancellationToken ct)
    {
        await using var writer = new StreamWriter(_stream, leaveOpen: true);
        await writer.WriteAsync(data, ct);
    }

    public void Dispose() => _stream.Dispose();
}
```

**Explicit interface implementation — resolve naming conflicts**
```csharp
public interface IShape    { double Area(); }
public interface IFigure   { double Area(); } // different meaning

public class Circle : IShape, IFigure
{
    private double _radius;

    // Explicit: only accessible through the specific interface
    double IShape.Area()  => Math.PI * _radius * _radius;
    double IFigure.Area() => 4 * Math.PI * _radius * _radius; // surface area

    // Implicit: accessible through the concrete type
    public double Circumference() => 2 * Math.PI * _radius;
}

var c = new Circle();
((IShape)c).Area();  // Math.PI version
((IFigure)c).Area(); // 4 * Math.PI version
// c.Area();         // compile error — ambiguous
```

**Default interface methods (C# 8) — add members without breaking implementors**
```csharp
public interface ILogger
{
    void Log(string message);

    // Default implementation — types don't have to override this
    void LogError(string message) => Log($"[ERROR] {message}");
    void LogWarning(string message) => Log($"[WARN] {message}");
}

public class ConsoleLogger : ILogger
{
    public void Log(string message) => Console.WriteLine(message);
    // LogError and LogWarning are inherited from the interface — no override needed
}

// IMPORTANT: default methods only visible through the interface type
ILogger logger = new ConsoleLogger();
logger.LogError("Something broke");    // works — accessed via ILogger
// new ConsoleLogger().LogError(".."); // compile error — not visible on the concrete type
```

**Generic interface with variance**
```csharp
// IEnumerable<out T>: covariant — IEnumerable<Dog> is assignable to IEnumerable<Animal>
IEnumerable<Dog> dogs = new List<Dog> { new Dog("Rex") };
IEnumerable<Animal> animals = dogs; // works because of 'out T'

// IComparer<in T>: contravariant — IComparer<Animal> is assignable to IComparer<Dog>
IComparer<Animal> animalComparer = Comparer<Animal>.Default;
IComparer<Dog> dogComparer = animalComparer; // works because of 'in T'
```

---

## Real World Example

An ASP.NET Core application uses interfaces to build a pluggable notification system. Different notification channels (email, SMS, push) all implement `INotificationChannel`. The `NotificationDispatcher` doesn't know which channels are registered — it just calls the contract and the DI container handles the rest.

```csharp
public interface INotificationChannel
{
    string ChannelName { get; }
    bool Supports(NotificationPreference preference);
    Task<NotificationResult> SendAsync(Notification notification, CancellationToken ct);
}

public record Notification(string RecipientId, string Subject, string Body, NotificationPreference Preference);
public record NotificationResult(bool Success, string? ErrorMessage = null);

// Each channel is self-contained — completely independent of the others
public sealed class EmailChannel : INotificationChannel
{
    private readonly IEmailService _email;
    private readonly IUserRepository _users;

    public EmailChannel(IEmailService email, IUserRepository users) { _email = email; _users = users; }

    public string ChannelName => "Email";
    public bool Supports(NotificationPreference p) => p.HasFlag(NotificationPreference.Email);

    public async Task<NotificationResult> SendAsync(Notification n, CancellationToken ct)
    {
        var user = await _users.FindAsync(n.RecipientId, ct);
        if (user?.Email is null) return new NotificationResult(false, "No email on file");
        await _email.SendAsync(user.Email, n.Subject, n.Body, ct);
        return new NotificationResult(true);
    }
}

public sealed class SmsChannel : INotificationChannel
{
    private readonly ISmsGateway _sms;
    private readonly IUserRepository _users;

    public SmsChannel(ISmsGateway sms, IUserRepository users) { _sms = sms; _users = users; }

    public string ChannelName => "SMS";
    public bool Supports(NotificationPreference p) => p.HasFlag(NotificationPreference.Sms);

    public async Task<NotificationResult> SendAsync(Notification n, CancellationToken ct)
    {
        var user = await _users.FindAsync(n.RecipientId, ct);
        if (user?.Phone is null) return new NotificationResult(false, "No phone on file");
        await _sms.SendAsync(user.Phone, $"{n.Subject}: {n.Body}", ct);
        return new NotificationResult(true);
    }
}

// Dispatcher: knows nothing about Email or SMS — only INotificationChannel
public class NotificationDispatcher
{
    private readonly IEnumerable<INotificationChannel> _channels;
    private readonly ILogger<NotificationDispatcher> _logger;

    public NotificationDispatcher(IEnumerable<INotificationChannel> channels, ILogger<NotificationDispatcher> logger)
    {
        _channels = channels;
        _logger   = logger;
    }

    public async Task DispatchAsync(Notification notification, CancellationToken ct)
    {
        var applicable = _channels.Where(c => c.Supports(notification.Preference));
        var tasks      = applicable.Select(c => SendWithLoggingAsync(c, notification, ct));
        await Task.WhenAll(tasks);
    }

    private async Task SendWithLoggingAsync(INotificationChannel channel, Notification n, CancellationToken ct)
    {
        var result = await channel.SendAsync(n, ct);
        if (!result.Success)
            _logger.LogWarning("{Channel} failed: {Error}", channel.ChannelName, result.ErrorMessage);
    }
}

// Registration in Program.cs — adding a new channel = one line
services.AddScoped<INotificationChannel, EmailChannel>();
services.AddScoped<INotificationChannel, SmsChannel>();
services.AddScoped<INotificationChannel, PushChannel>(); // new channel — nothing else changes
```

*The key insight: `NotificationDispatcher` is genuinely closed to modification — it has zero `if` statements checking the channel type, no registration of specific implementations, and no knowledge of email or SMS. Adding `PushChannel` requires adding one class and one registration line. Removing email requires deleting the registration. No existing code changes. This is the Open/Closed Principle made real through interface polymorphism.*

---

## Common Misconceptions

**"Every class should have an interface"**
An interface adds value when the implementation needs to be swapped, mocked in tests, or when multiple unrelated types need to be treated uniformly. A `UserRepository` that will only ever talk to SQL Server and is trivially testable without mocking doesn't need an `IUserRepository` — the abstraction adds ceremony without benefit. Create interfaces for things that genuinely need to vary.

**"Default interface methods (C# 8) make abstract classes obsolete"**
Default interface methods let you add methods without breaking implementors. But interfaces still can't have constructors, instance fields, or `private` members (beyond private helpers in default methods). If you need a constructor to inject dependencies, shared private state, or non-trivial shared logic, you still need an abstract class.

**"Explicit interface implementation hides the member from the implementing class"**
Explicit implementation (`void IShape.Area()`) makes the member accessible only through the interface type — not through the concrete type or `this` inside the class. This is useful for resolving naming conflicts or hiding interface members that don't make sense in the concrete type's API, but it can be surprising.

---

## Gotchas

- **Default interface methods are only visible through the interface type.** `new ConsoleLogger().LogError("x")` doesn't compile if `LogError` is a default interface method. The default implementation is only reachable through a variable typed as `ILogger`. This surprises almost everyone the first time.

- **Explicit interface implementations can't be called on `this` without a cast.** Inside a class that explicitly implements `IShape.Area()`, writing `Area()` in another method doesn't call the explicit implementation. You have to cast: `((IShape)this).Area()`. This makes explicit implementations awkward to chain internally.

- **Adding a member to a published interface is a breaking change** — even in C# 8. While you can add a *default* interface method without breaking implementors, adding a new method forces a recompile of all consumers regardless. In a library with external consumers, every interface change is a minor-version bump at minimum.

- **Interface covariance/contravariance only works on generic interfaces, and only with `out`/`in` annotations.** `IList<Dog>` is NOT assignable to `IList<Animal>`, even though `Dog` inherits from `Animal`. Only `IEnumerable<T>` (covariant) works this way because it marks `T` as `out`. `IList<T>` has both reads and writes, so variance is unsafe and disallowed.

- **Structs implementing interfaces box when stored in interface variables.** `IShape shape = new Point(1, 2)` boxes the `Point`. Every call through the `shape` variable goes through the boxed copy. Use generic constraints (`where T : IShape`) to avoid boxing when the concrete type is known at compile time.

---

## Interview Angle

**What they're really testing:** Whether you understand abstraction, loose coupling, and the mechanics that make dependency injection and testability possible.

**Common question forms:**
- "What's the difference between an interface and an abstract class?"
- "When would you use an interface?"
- "How does `IEmailSender` make `OrderService` testable?"
- "What is covariance in a generic interface?"

**The depth signal:** A junior says "interfaces have no implementation, abstract classes can." A senior gives the design-level reason: interfaces model capability contracts across unrelated types — `Dog` and `Printer` can both be `IPrintable` without any shared ancestry, which is impossible with class inheritance. They explain that DI containers depend entirely on interface abstraction, that default interface methods let library authors extend contracts without breaking consumers (but only for adding members, not removing), and can explain generic covariance: `IEnumerable<out T>` marks `T` as output-only, so substituting a more specific type is always safe.

**Follow-up questions to expect:**
- "What does `out T` mean on a generic interface? What about `in T`?"
- "Why does assigning a struct to an interface variable cause boxing?"
- "Can a static class implement an interface?"

---

## Related Topics

- [[dotnet/csharp/csharp-abstract-classes.md]] — The primary comparison; use abstract when shared implementation or state is needed
- [[dotnet/csharp/csharp-polymorphism.md]] — Interface dispatch is one of three forms of polymorphism in C#
- [[dotnet/csharp/csharp-generics.md]] — Generic interface constraints (`where T : IComparable<T>`) eliminate dispatch overhead and boxing
- [[dotnet/csharp/csharp-delegates.md]] — Delegates are single-method interfaces; the two concepts overlap for callback patterns

---

## Source

[Interfaces — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/interfaces)

---

*Last updated: 2026-04-06*