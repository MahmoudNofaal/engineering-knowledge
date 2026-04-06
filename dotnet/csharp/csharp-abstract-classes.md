# C# Abstract Classes

> An abstract class is a base class that cannot be instantiated directly — it exists to be inherited from, and can enforce that subclasses implement specific members while also providing shared implementation.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Base class with mandatory override points and optional shared implementation |
| **Use when** | Family of types shares implementation AND has required variation points |
| **Avoid when** | No shared implementation — use an interface instead |
| **C# version** | C# 1.0 |
| **Namespace** | N/A — language primitive |
| **Key keywords** | `abstract class`, `abstract` (member), `override`, `base` |

---

## When To Use It

Use an abstract class when you have a family of related types that share real, non-trivial implementation code AND have behaviour that each subclass must define for itself. The defining characteristic: there's something meaningful to put in the base class body.

The sweet spot is the **Template Method pattern**: the algorithm's skeleton lives in the abstract class, and specific steps are delegated to abstract methods that subclasses must fill in. `Generate()` is defined in the base, `GenerateContent()` is abstract.

**Don't use an abstract class when:**
- There's no shared implementation to offer — that's an `interface`.
- The types aren't genuinely related in an is-a sense — two unrelated classes sharing a method don't need a common ancestor.
- You're publishing a library and the hierarchy might need to grow — adding abstract members is a breaking change for all implementors.
- You want multiple inheritance — a class can inherit from only one abstract class but implement many interfaces.

---

## Core Concept

An abstract class sits between a fully concrete class and an interface. It can have fields, constructors, real method implementations, and properties — just like a normal class. But it can also declare `abstract` members that have no body, forcing every concrete subclass to provide their own implementation.

Because an abstract class can't be instantiated, it can only exist as the base of something else. It's a template with some blanks that subclasses must fill in.

The key distinction from an interface is state and shared code: an abstract class can carry `private readonly` fields, inject dependencies through a constructor, implement methods that use those fields, and share that infrastructure across all subclasses. An interface is a pure contract — no storage, no implementation (before C# 8 default interface methods).

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | `abstract class`, `abstract` members |
| C# 8.0 | .NET Core 3.0 | Default interface methods (blur the line slightly) |
| C# 9.0 | .NET 5 | Abstract records — `abstract record Shape` |
| C# 11.0 | .NET 7 | `abstract static` interface members (static polymorphism) |

*C# 8's default interface methods allow interfaces to carry implementation, which reduces one of the historical reasons to prefer abstract classes. The choice is now more clearly about state: if you need shared fields or a constructor, use an abstract class. If you need a pure contract with optional defaults, use an interface.*

---

## Performance

| Scenario | Abstract class | Interface |
|---|---|---|
| Calling abstract method | Vtable dispatch | Interface table dispatch |
| Calling concrete base method | Direct call (or inlined) | N/A |
| Accessing base class field | Zero overhead | N/A — interfaces have no fields |
| Memory per instance | Same as a class | Same as a class |

**Allocation behaviour:** Abstract classes add no allocation overhead over concrete classes. The abstract constraint is purely compile-time. Instances of concrete subclasses are allocated exactly as any class instance is.

**Benchmark notes:** The cost of calling through an abstract base class is identical to calling any virtual method — one vtable lookup. The `sealed` keyword on concrete subclasses allows the JIT to devirtualise and inline calls at those call sites.

---

## The Code

**Basic abstract class with mixed members**
```csharp
public abstract class Report
{
    // Concrete state — every subclass gets this
    public string Title { get; }
    public DateTime GeneratedAt { get; } = DateTime.UtcNow;
    protected readonly ILogger Logger;

    protected Report(string title, ILogger logger)
    {
        if (string.IsNullOrWhiteSpace(title)) throw new ArgumentException("Title required.");
        Title  = title;
        Logger = logger;
    }

    // Abstract — subclass MUST implement; defines the variation point
    public abstract string GenerateContent();

    // Concrete — identical for every subclass; uses the abstract method above
    public string Generate()
    {
        Logger.LogInformation("Generating report: {Title}", Title);
        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"=== {Title} ===");
        sb.AppendLine($"Generated: {GeneratedAt:yyyy-MM-dd HH:mm}");
        sb.AppendLine(GenerateContent()); // calls subclass implementation
        return sb.ToString();
    }
}

public sealed class SalesReport : Report
{
    private readonly IEnumerable<Order> _orders;

    public SalesReport(IEnumerable<Order> orders, ILogger<SalesReport> logger)
        : base("Monthly Sales Report", logger)
        => _orders = orders;

    public override string GenerateContent()
    {
        decimal total = _orders.Sum(o => o.Total);
        int count     = _orders.Count();
        return $"Orders: {count} | Revenue: {total:C}";
    }
}

// new Report("x", logger); // compile error — cannot instantiate abstract class
var report = new SalesReport(orders, logger);
Console.WriteLine(report.Generate());
```

**Template Method pattern — the canonical abstract class use case**
```csharp
public abstract class DataImporter
{
    // Template method: defines the algorithm, delegates steps to subclasses
    public async Task ImportAsync(string source, CancellationToken ct = default)
    {
        var rawData = await ReadDataAsync(source, ct);  // subclass provides this
        var cleaned = Validate(rawData);                 // shared logic
        await SaveAsync(cleaned, ct);                    // subclass provides this
        LogSuccess(source, cleaned.Length);              // shared logic
    }

    // Subclass-specific steps
    protected abstract Task<string[]> ReadDataAsync(string source, CancellationToken ct);
    protected abstract Task SaveAsync(string[] data, CancellationToken ct);

    // Shared concrete steps — subclasses don't touch these
    private string[] Validate(string[] raw)
        => raw.Where(s => !string.IsNullOrWhiteSpace(s)).ToArray();

    private void LogSuccess(string source, int count)
        => Console.WriteLine($"Imported {count} records from {source}");
}

public sealed class CsvImporter : DataImporter
{
    private readonly IFileSystem _fs;
    private readonly IDatabase  _db;

    public CsvImporter(IFileSystem fs, IDatabase db) { _fs = fs; _db = db; }

    protected override async Task<string[]> ReadDataAsync(string path, CancellationToken ct)
        => await _fs.ReadAllLinesAsync(path, ct);

    protected override async Task SaveAsync(string[] rows, CancellationToken ct)
        => await _db.BulkInsertAsync(rows, ct);
}
```

**Abstract class implementing an interface — partial implementation pattern**
```csharp
public interface IShape
{
    double Area();
    double Perimeter();
    void Describe();         // common implementation for all shapes
}

// Abstract class implements the common part, leaves the specifics abstract
public abstract class Shape : IShape
{
    public abstract double Area();
    public abstract double Perimeter();

    // Concrete — every Shape gets this for free; no subclass needs to write it
    public void Describe()
        => Console.WriteLine($"{GetType().Name}: Area={Area():F2}, Perimeter={Perimeter():F2}");
}

public sealed class Circle : Shape
{
    private readonly double _radius;
    public Circle(double radius) => _radius = radius;
    public override double Area()      => Math.PI * _radius * _radius;
    public override double Perimeter() => 2 * Math.PI * _radius;
}
```

**`virtual` inside abstract class — optional override**
```csharp
public abstract class HttpHandler
{
    // abstract: subclass MUST override
    public abstract Task<HttpResponse> HandleAsync(HttpRequest request, CancellationToken ct);

    // virtual: subclass MAY override — has a sensible default
    protected virtual bool ShouldLog(HttpRequest request) => request.Method != "OPTIONS";

    // Non-virtual: same for everyone, no override possible
    public string HandlerName => GetType().Name;
}
```

---

## Real World Example

An ASP.NET Core background service uses an abstract base class to handle the common shutdown/cancellation infrastructure. Each concrete worker only implements the specific business logic — the lifecycle management is done once in the base.

```csharp
public abstract class ResilientBackgroundService : BackgroundService
{
    protected readonly ILogger Logger;
    private readonly TimeSpan _retryDelay;
    private readonly int _maxConsecutiveFailures;

    protected ResilientBackgroundService(
        ILogger logger,
        TimeSpan retryDelay,
        int maxConsecutiveFailures = 5)
    {
        Logger                  = logger;
        _retryDelay             = retryDelay;
        _maxConsecutiveFailures = maxConsecutiveFailures;
    }

    // Subclasses implement the actual work
    protected abstract Task ExecuteIterationAsync(CancellationToken ct);

    // Base handles retry logic, logging, and graceful shutdown
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        int consecutiveFailures = 0;

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ExecuteIterationAsync(stoppingToken);
                consecutiveFailures = 0; // reset on success
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break; // clean shutdown
            }
            catch (Exception ex)
            {
                consecutiveFailures++;
                Logger.LogError(ex, "{Service} iteration failed ({Count}/{Max})",
                    GetType().Name, consecutiveFailures, _maxConsecutiveFailures);

                if (consecutiveFailures >= _maxConsecutiveFailures)
                {
                    Logger.LogCritical("{Service} exceeded failure limit — stopping", GetType().Name);
                    break;
                }

                await Task.Delay(_retryDelay, stoppingToken);
            }
        }
    }
}

// Concrete worker: only the business logic, zero lifecycle code
public sealed class OrderSyncWorker : ResilientBackgroundService
{
    private readonly IOrderSyncService _syncService;

    public OrderSyncWorker(IOrderSyncService syncService, ILogger<OrderSyncWorker> logger)
        : base(logger, retryDelay: TimeSpan.FromSeconds(30)) => _syncService = syncService;

    protected override async Task ExecuteIterationAsync(CancellationToken ct)
    {
        int synced = await _syncService.SyncPendingOrdersAsync(ct);
        Logger.LogDebug("Synced {Count} orders", synced);
        await Task.Delay(TimeSpan.FromMinutes(1), ct);
    }
}
```

*The key insight: `ResilientBackgroundService` handles retry counting, consecutive failure limits, logging patterns, and clean shutdown in one place. Adding `InvoiceGenerationWorker`, `EmailSendingWorker`, or any other worker means writing exactly the business logic — 5–10 lines. The lifecycle infrastructure is written once and reused. This is the right use of abstract classes: shared infrastructure code that's identical across variants, with a single variation point (`ExecuteIterationAsync`).*

---

## Common Misconceptions

**"Abstract classes and interfaces are interchangeable"**
They solve different problems. An interface is a pure contract — it says "any type that implements me must provide these members." An abstract class is a partial implementation — it says "these types share code here, and must provide code there." If you have no shared code to offer, use an interface. If you need a constructor, fields, or substantial shared logic, use an abstract class. In practice, both is also common: an abstract class can implement an interface while leaving some of its members abstract.

**"You can add new abstract members to a published abstract class without breaking anything"**
Adding a new `abstract` member is a breaking change — every existing concrete subclass now fails to compile. Unlike default interface methods (C# 8+), abstract methods have no default implementation. If your type is in a public library and consumers subclass it, adding an abstract member breaks all their code. Plan the abstract interface carefully upfront, or use virtual methods with a throw-not-implemented default for extensibility points that might grow.

**"`protected virtual` and `abstract` methods serve the same purpose"**
A `virtual` method has a default implementation — calling it doesn't require any subclass to exist. An `abstract` method forces subclasses to provide an implementation. Use `virtual` when a sensible default exists and overriding is optional. Use `abstract` when there is no meaningful default and every concrete subclass must define its own behaviour.

---

## Gotchas

- **Abstract classes still have constructors — subclasses must call them.** If the abstract class constructor requires parameters (`protected Base(ILogger logger)`), every subclass must have a matching `: base(logger)` call. If you add a required parameter to the base constructor later, every subclass breaks.

- **You can't add a new abstract member without breaking all existing concrete subclasses.** Unlike interfaces with default methods, there's no "safe" way to extend an abstract class's contract post-publication. This makes abstract classes brittle to evolve in a library, where you may not control all subclasses.

- **`abstract override` is valid and often forgotten.** A class can inherit a virtual method and re-declare it as `abstract`, forcing its own subclasses to implement it fresh. This is rare but valid and sometimes exactly the right design for a three-level hierarchy.

- **`protected` constructors are the right default for abstract classes.** A `public` constructor on an abstract class is confusing — nothing outside can call it directly. Use `protected` to signal that it's only for subclasses, and use `internal` if you want to limit subclassing to the same assembly.

- **Don't call virtual methods in the abstract class constructor.** The concrete subclass hasn't been constructed yet when the abstract base constructor runs. Calling a virtual method that the subclass overrides will execute the override against an uninitialized object.

---

## Interview Angle

**What they're really testing:** Whether you can articulate the concrete trade-offs between abstract classes and interfaces, and whether you know which design problem each solves.

**Common question forms:**
- "What's the difference between an abstract class and an interface?"
- "When would you use one over the other?"
- "What is the Template Method pattern?"
- "Can an abstract class implement an interface?"

**The depth signal:** A junior recites "abstract classes can have implementation, interfaces can't." A senior gives the design-level answer: abstract classes model an is-a hierarchy with shared state and infrastructure — they're appropriate when subclasses are genuinely variants of the same thing with substantial shared code. Interfaces model a can-do capability contract across unrelated types. They name the Template Method pattern unprompted as the canonical use case. They also note that adding abstract members to a published abstract class is a breaking change — while adding default interface methods is not — which is a real design consideration when writing library code.

**Follow-up questions to expect:**
- "What is the Template Method pattern and why does it require an abstract class?"
- "Why is adding a new abstract member a breaking change but adding a default interface method isn't?"
- "Can you have an abstract class that implements an interface partially?"

---

## Related Topics

- [[dotnet/csharp/csharp-interfaces.md]] — The primary comparison point; interfaces are the alternative when you don't need shared state or implementation
- [[dotnet/csharp/csharp-inheritance.md]] — Abstract classes are a form of inheritance; virtual dispatch and `override` mechanics apply throughout
- [[dotnet/csharp/csharp-classes.md]] — Concrete class anatomy is the prerequisite; abstract classes extend it with abstract members and no instantiation
- [[dotnet/csharp/csharp-polymorphism.md]] — Abstract methods are the primary variation point in the Template Method pattern

---

## Source

[Abstract classes — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/abstract)

---

*Last updated: 2026-04-06*