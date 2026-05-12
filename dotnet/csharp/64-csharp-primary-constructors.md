# C# Primary Constructors

> A C# 12 feature that lets you declare constructor parameters directly on the class or struct declaration — the parameters are in scope throughout the entire class body, eliminating the boilerplate of storing them in private fields manually.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Constructor parameters declared on the type declaration itself |
| **Use when** | DI services, lightweight data classes, simple parameter capture |
| **Avoid when** | Parameters need validation, transformation, or guard logic on capture |
| **C# version** | C# 12 (.NET 8) |
| **Namespace** | N/A — language feature |
| **Key distinction** | Class primary constructors ≠ record primary constructors (different semantics) |

---

## When To Use It

Use primary constructors on classes when all you need is to capture injected dependencies or configuration values into the class body — the most common pattern in ASP.NET Core service classes. They eliminate the three-step ceremony of: declare a field, declare a constructor parameter, assign parameter to field.

Don't use primary constructors when:
- You need to **validate** the incoming parameters — there's no natural place to put `ArgumentNullException.ThrowIfNull` without writing an explicit constructor body anyway.
- You need to **transform** the parameter before storing it (`_name = name.Trim()`).
- You want explicit **private readonly fields** — primary constructor parameters don't generate fields by default on classes; you have to capture them explicitly if you want field semantics.
- The class is complex enough that a reader needs to see the field declarations to understand the type's state.

For records, primary constructors are a different mechanism that auto-generates properties — this file is about class/struct primary constructors only.

---

## Core Concept

On a **record**, `record Point(int X, int Y)` generates public `init`-only properties `X` and `Y` plus a constructor. That's been available since C# 9.

On a **class or struct**, `class OrderService(IRepository repo)` in C# 12 does something different: `repo` is a **parameter in scope throughout the class body**, but it doesn't become a field or property automatically. The compiler captures it into a synthesised (hidden) field only if the class body actually uses it outside the constructor.

This means:
- If you only use `repo` inside a method, it becomes a hidden captured field — no explicit field declaration needed.
- If you want an explicit name for the field (for debugging, reflection, or clarity), you must assign it yourself: `private readonly IRepository _repo = repo;`
- You can still have additional constructors — they must call the primary constructor via `this(...)`.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 9.0 | .NET 5 | Primary constructors on **records** only |
| C# 10.0 | .NET 6 | Primary constructors on **record struct** |
| C# 12.0 | .NET 8 | Primary constructors on **classes and structs** |

*The C# 12 expansion to classes was deliberately designed to be more minimal than records — no property generation, just parameter scope injection. This prevents the feature from becoming a hidden footgun where parameters look like fields but aren't.*

---

## Performance

Primary constructors on classes have zero runtime overhead compared to explicit constructors. The synthesised captured fields are identical to what you'd write manually. The difference is purely ergonomic — less code to write and read.

---

## The Code

**Basic DI service — the primary use case**
```csharp
// Before C# 12: three lines of boilerplate per dependency
public class OrderService
{
    private readonly IOrderRepository _repository;
    private readonly ILogger<OrderService> _logger;

    public OrderService(IOrderRepository repository, ILogger<OrderService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<Order?> GetAsync(int id, CancellationToken ct)
    {
        _logger.LogDebug("Fetching order {Id}", id);
        return await _repository.FindAsync(id, ct);
    }
}

// C# 12: parameters in scope throughout class — no field/assignment boilerplate
public class OrderService(IOrderRepository repository, ILogger<OrderService> logger)
{
    public async Task<Order?> GetAsync(int id, CancellationToken ct)
    {
        logger.LogDebug("Fetching order {Id}", id);           // primary param used directly
        return await repository.FindAsync(id, ct);            // primary param used directly
    }
}
```

**When you still need explicit fields**
```csharp
// If you need the field name to be visible (debugging, reflection):
public class ProductService(IProductRepository repository, ICache cache)
{
    // Explicit assignment creates a named private field
    private readonly IProductRepository _repository = repository;
    private readonly ICache _cache = cache;

    // repository and cache are still in scope here too, but _repository/_cache
    // are the explicit fields that appear in debugger / IL tools
}
```

**Validation — primary constructors make this awkward**
```csharp
// AWKWARD: no constructor body, so validation needs a workaround
public class Config(string connectionString, int timeout)
{
    // Field initializers can validate inline, but it's not clean
    private readonly string _connectionString =
        string.IsNullOrWhiteSpace(connectionString)
            ? throw new ArgumentException("Connection string required.", nameof(connectionString))
            : connectionString;

    private readonly int _timeout =
        timeout > 0
            ? timeout
            : throw new ArgumentOutOfRangeException(nameof(timeout), "Must be positive.");
}

// CLEANER: explicit constructor with primary constructor syntax is not possible together
// — if you need real validation logic, just write an explicit constructor
public class Config
{
    private readonly string _connectionString;
    private readonly int _timeout;

    public Config(string connectionString, int timeout)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(connectionString);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(timeout);
        _connectionString = connectionString;
        _timeout = timeout;
    }
}
```

**Additional constructors must chain to primary**
```csharp
public class NotificationService(IEmailSender emailSender, ISmsGateway smsGateway)
{
    // Secondary constructor must call primary via this(...)
    public NotificationService(IEmailSender emailSender)
        : this(emailSender, NullSmsGateway.Instance)
    {
    }

    public async Task NotifyAsync(string recipient, string message, CancellationToken ct)
    {
        await emailSender.SendAsync(recipient, message, ct);  // primary param in scope
    }
}
```

**Primary constructor on struct**
```csharp
// Struct primary constructor — same mechanics, value-type semantics
public struct Range(int start, int end)
{
    public int Start { get; } = start;
    public int End   { get; } = end;
    public int Length => End - Start;

    public bool Contains(int value) => value >= start && value <= end; // primary param in scope
}

var r = new Range(1, 10);
Console.WriteLine(r.Contains(5));  // true
Console.WriteLine(r.Length);       // 9
```

**Class vs record primary constructor — the critical difference**
```csharp
// RECORD: primary constructor parameters become PUBLIC INIT-ONLY PROPERTIES
public record Point(double X, double Y);
// Generates: public double X { get; init; }  public double Y { get; init; }
// Also generates: Equals, GetHashCode, ToString, Deconstruct

var p = new Point(1.0, 2.0);
Console.WriteLine(p.X);   // 1.0 — X is a public property
Console.WriteLine(p);     // Point { X = 1, Y = 2 }

// CLASS: primary constructor parameters are JUST PARAMETERS in scope
public class Point2D(double x, double y)
{
    // x and y are NOT properties — no public surface area exposed
    public double DistanceTo(Point2D other)
    {
        double dx = x - other.x; // COMPILE ERROR: other.x is a captured field, not accessible
        // ...
    }
}
// Solution: expose as properties explicitly
public class Point2D(double x, double y)
{
    public double X { get; } = x;
    public double Y { get; } = y;

    public double DistanceTo(Point2D other)
    {
        double dx = X - other.X;
        double dy = Y - other.Y;
        return Math.Sqrt(dx * dx + dy * dy);
    }
}
```

---

## Real World Example

An ASP.NET Core application uses primary constructors throughout its service layer. The result is significantly less boilerplate with no change in behaviour or testability.

```csharp
// Controller — primary constructor for DI
[ApiController]
[Route("api/orders")]
public class OrdersController(
    IOrderService orderService,
    IValidator<CreateOrderRequest> validator,
    ILogger<OrdersController> logger) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> CreateAsync(
        CreateOrderRequest request,
        CancellationToken ct)
    {
        var validation = validator.Validate(request);
        if (!validation.IsValid)
            return ValidationProblem(validation.ToDictionary());

        try
        {
            var order = await orderService.CreateAsync(request, ct);
            logger.LogInformation("Order {Id} created", order.Id);
            return CreatedAtAction(nameof(GetAsync), new { id = order.Id }, order);
        }
        catch (InsufficientStockException ex)
        {
            return Conflict(new { ex.ErrorCode, ex.Message });
        }
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetAsync(int id, CancellationToken ct)
    {
        var order = await orderService.GetAsync(id, ct);
        return order is null ? NotFound() : Ok(order);
    }
}

// Service layer — primary constructor, no field declarations needed
public class OrderService(
    IOrderRepository repository,
    IInventoryService inventory,
    IEventBus eventBus,
    ILogger<OrderService> logger) : IOrderService
{
    public async Task<OrderDto> CreateAsync(CreateOrderRequest request, CancellationToken ct)
    {
        await inventory.ReserveAsync(request.Items, ct); // primary param — no this._inventory

        var order = Order.Create(request);
        await repository.SaveAsync(order, ct);

        await eventBus.PublishAsync(new OrderCreatedEvent(order.Id), ct);
        logger.LogDebug("Order {Id} saved and event published", order.Id);

        return OrderDto.From(order);
    }

    public async Task<OrderDto?> GetAsync(int id, CancellationToken ct)
    {
        var order = await repository.FindAsync(id, ct);
        return order is null ? null : OrderDto.From(order);
    }
}
```

*The key insight: the controller and service have the same testability as before — dependencies are injected through the constructor and can be mocked. What's gone is the three-line field/constructor/assignment ceremony per dependency. A service with four dependencies went from twelve lines of boilerplate to zero.*

---

## Common Misconceptions

**"Primary constructors on classes work the same as on records"**
Completely different semantics. Records generate public init-only properties from primary constructor parameters. Classes do not — the parameters are in scope in the body but generate no public surface area. If you want properties on a class, you must declare them explicitly and assign from the parameter.

**"Primary constructor parameters are fields"**
They're captured into hidden fields by the compiler *if used*, but they're not fields you declared. They have no access modifier, no XML docs, no visibility in most debuggers under a stable name, and no presence in reflection's `GetFields()`. If you need an actual field — explicit declaration, explicit assignment.

**"You can't add validation with primary constructors"**
You can, through field initializer expressions that throw, but it's awkward. The clean answer is: if you need meaningful validation logic, write an explicit constructor. Primary constructors are for the common case (capture and store); explicit constructors are for the complex case (validate and transform).

---

## Gotchas

- **Primary constructor parameters on classes are mutable by default.** Unlike record properties (which are `init`-only), primary constructor parameters on classes are just captured values. If a method inside the class reassigns the parameter name, it works — silently changing what the captured variable holds. This is rarely intended. Use explicit `private readonly` fields if immutability of the captured value matters.

- **The parameter name is part of the class's public API for source generators and diagnostics.** If you use `[FromServices]` or similar attributes, the primary constructor parameter names matter. Renaming them is a breaking change for anything that keys off the parameter name.

- **Accessing a primary constructor parameter through `other.param` on another instance doesn't work.** The parameter is a private captured field. `other.x` where `x` is a primary constructor parameter won't compile. Expose it as a property if you need cross-instance access.

- **Primary constructors don't mix with `record` — you can't declare a `record class` with class-style primary constructor semantics.** `record class` (or just `record`) always generates properties. If you want class-style behaviour, use a plain `class`.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between record and class primary constructors, and whether you know the tradeoffs around validation and field visibility.

**Common question forms:**
- "What are primary constructors in C# 12?"
- "What's the difference between a primary constructor on a class versus a record?"
- "When would you not use a primary constructor?"

**The depth signal:** A junior says "primary constructors remove the boilerplate of assigning constructor parameters to fields." A senior explains the semantic difference: records generate properties; classes just scope the parameters into the body — no properties, no explicit fields generated. They flag the validation gotcha (no constructor body means validation must go in field initializers, which is awkward) and know that for complex construction logic, explicit constructors remain cleaner.

---

## Related Topics

- [csharp-classes.md](csharp-classes.md) — Class fundamentals; primary constructors are a C# 12 addition to class syntax
- [csharp-records.md](csharp-records.md) — Record primary constructors have different semantics (generate properties); the comparison is the interview angle
- [csharp-encapsulation.md](csharp-encapsulation.md) — `private readonly` field patterns that primary constructors replace
- [csharp-exceptions.md](csharp-exceptions.md) — Constructor validation with `ArgumentNullException.ThrowIfNull`; relevant when choosing between primary and explicit

---

## Source

[Primary Constructors — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-12#primary-constructors)

---
*Last updated: 2026-05-13*
