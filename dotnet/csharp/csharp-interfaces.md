# C# Interfaces

> An interface is a contract that says "anything implementing me guarantees these methods and properties exist" — with no implementation of its own (mostly).

---

## When To Use It
Use an interface when you want to decouple what something does from how it does it. The classic case is dependency injection — your `OrderService` depends on `IEmailSender`, not `SmtpEmailSender`, so you can swap implementations or mock it in tests. Don't use an interface just to have one; a single implementation that never changes doesn't need an interface. Also don't use it as a substitute for a base class when you actually need shared implementation.

---

## Core Concept
An interface is a list of promises. It says: "any class that signs this contract must provide these members." The interface itself holds no state and (before C# 8) no code. The power is that a variable typed as `IEmailSender` can hold any object that implements `IEmailSender` — your code doesn't know or care which one it gets at runtime. That's the entire point: you write code against the contract, and something else decides which concrete thing fulfills it. This is what makes unit testing and dependency injection possible.

---

## The Code

**Defining and implementing an interface**
```csharp
public interface IEmailSender
{
    void Send(string to, string subject, string body);
    bool IsConfigured { get; }
}

public class SmtpEmailSender : IEmailSender
{
    public bool IsConfigured => true;

    public void Send(string to, string subject, string body)
    {
        Console.WriteLine($"SMTP → {to}: {subject}");
    }
}

// Variable typed as the interface — implementation is hidden
IEmailSender sender = new SmtpEmailSender();
sender.Send("user@example.com", "Hello", "Hi there");
```

**Dependency injection pattern — why interfaces matter**
```csharp
public class OrderService
{
    private readonly IEmailSender _emailSender;

    // Constructor takes the interface, not the concrete class
    public OrderService(IEmailSender emailSender)
    {
        _emailSender = emailSender;
    }

    public void PlaceOrder(string customerEmail)
    {
        // business logic here...
        _emailSender.Send(customerEmail, "Order confirmed", "Thanks!");
    }
}

// In tests — swap in a fake with no SMTP config needed
public class FakeEmailSender : IEmailSender
{
    public bool IsConfigured => true;
    public List<string> SentTo { get; } = new();

    public void Send(string to, string subject, string body)
        => SentTo.Add(to);
}

var fake = new FakeEmailSender();
var service = new OrderService(fake);
service.PlaceOrder("test@example.com");
Console.WriteLine(fake.SentTo[0]); // "test@example.com"
```

**Implementing multiple interfaces**
```csharp
public interface IReadable  { string Read(); }
public interface IWritable  { void Write(string data); }

// A class can implement as many interfaces as needed
// (unlike inheritance — only one base class allowed)
public class FileBuffer : IReadable, IWritable
{
    private string _buffer = "";

    public string Read() => _buffer;
    public void Write(string data) => _buffer += data;
}
```

**Default interface methods (C# 8+)**
```csharp
public interface ILogger
{
    void Log(string message);

    // Default implementation — classes don't have to override this
    void LogError(string message) => Log($"[ERROR] {message}");
}

public class ConsoleLogger : ILogger
{
    public void Log(string message) => Console.WriteLine(message);
    // LogError is inherited from the interface — no override needed
}

ILogger logger = new ConsoleLogger();
logger.LogError("Something broke"); // "[ERROR] Something broke"
```

---

## Gotchas

- **Default interface methods are only accessible through the interface type.** If your variable is typed as `ConsoleLogger` (the concrete class), `LogError` doesn't exist on it — you only see it when the variable is typed as `ILogger`. This surprises almost everyone the first time.
- **Interfaces can't hold state.** You can define a property in an interface, but there's no backing field. Every implementing class has to store its own state. If you find yourself wanting shared state, you probably want an abstract class.
- **Explicit interface implementation hides members.** If you implement a member explicitly (`void IEmailSender.Send(...)`), it's invisible on the class — only accessible through the interface type. Useful to resolve naming conflicts, but confusing if done without reason.
- **`is` and `as` work on interfaces.** `if (obj is IEmailSender sender)` is perfectly valid and common — you don't need to know the concrete type to check if an object fulfills a contract.
- **Adding a member to a published interface is a breaking change.** Every class implementing it must now add the new member or it won't compile. Default interface methods exist specifically to soften this, but they come with the gotcha above.

---

## Interview Angle
**What they're really testing:** Whether you understand abstraction, loose coupling, and the mechanics that make dependency injection and testability work.

**Common question form:** "What's the difference between an interface and an abstract class?" or "Why would you use an interface?"

**The depth signal:** A junior says "interfaces have no implementation, abstract classes can." A senior gives the real design reason: interfaces model capability contracts across unrelated types (a `Dog` and a `Printer` can both be `IPrintable`), while abstract classes model an is-a hierarchy with shared behavior. They'll also explain that C# only allows single inheritance, so interfaces are the mechanism for composing multiple contracts — and that the entire DI/IoC ecosystem is built on coding to interfaces so the container can swap implementations without the consumer knowing.

---

## Related Topics
- [[dotnet/csharp-classes.md]] — Classes implement interfaces; understanding class anatomy is the prerequisite.
- [[dotnet/interfaces-abstract-classes.md]] — Direct comparison of when to pick interface vs abstract class.
- [[dotnet/dependency-injection.md]] — The primary reason to care about interfaces in a .NET backend; interfaces are the seam DI exploits.
- [[dotnet/csharp-generics.md]] — Generic type constraints (`where T : IEmailSender`) let you write code that works with any type fulfilling a contract.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/interfaces](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/interfaces)

---
*Last updated: 2026-03-23*