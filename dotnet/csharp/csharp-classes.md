# C# Classes

> A class is a blueprint that defines the data (fields/properties) and behaviour (methods) that its instances will have — and the primary reference type in C#.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Reference type blueprint for objects |
| **Use when** | Entities with identity, mutable state, or non-trivial lifetime |
| **Avoid when** | Small, immutable value containers — use `struct` or `record` |
| **C# version** | C# 1.0 |
| **Namespace** | N/A — language primitive |
| **Key keywords** | `class`, `new`, `this`, `base`, `virtual`, `override`, `sealed`, `abstract`, `static` |

---

## When To Use It

Use a class for anything that has identity (two instances with the same data are different things), mutable state that changes over its lifetime, or behaviour beyond simple data storage. `OrderService`, `HttpClient`, `DbContext` — these are all classes because they have state, dependencies, and a meaningful lifecycle.

Don't use a class when a `record` fits better (immutable data, value-based equality) or when a `struct` fits better (small, short-lived value with no identity). The guideline: if you can describe the type as "a thing that does X", it's a class. If you can describe it as "a value that represents X", it might be a record or struct.

---

## Core Concept

A class is a reference type — its instances live on the managed heap and are accessed through pointers. When you assign a class instance to another variable or pass it to a method, you're copying the pointer (8 bytes), not the data. Both variables now point at the same object, and mutations through either variable affect both.

The class provides the three pillars of OOP in C#: **encapsulation** (access modifiers hide internal state), **inheritance** (a class can extend one base class), and **polymorphism** (virtual methods dispatch to the most-derived override at runtime). Every class implicitly inherits from `System.Object`, giving every instance `ToString()`, `Equals()`, `GetHashCode()`, and `GetType()` for free.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Classes, constructors, access modifiers, virtual/override |
| C# 3.0 | .NET 3.5 | Auto-properties, object initializers, `var` |
| C# 6.0 | .NET 4.6 | Expression-bodied members, `nameof`, null-conditional |
| C# 7.0 | .NET Core 1.0 | Pattern matching on types, `out` variable inline |
| C# 8.0 | .NET Core 3.0 | Nullable reference types, `init` accessor |
| C# 9.0 | .NET 5 | `init`-only setters, `required` on properties (preview) |
| C# 11.0 | .NET 7 | `required` modifier on members |
| C# 12.0 | .NET 8 | Primary constructors on classes |

*Primary constructors (C# 12) let you declare constructor parameters directly on the class declaration: `class OrderService(IRepository repo)` — the parameters are in scope throughout the class body.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Instantiation (`new`) | Heap allocation | GC tracks it; cost is low per object, but volume adds up |
| Field access | O(1) | Pointer dereference, then field offset |
| Virtual method call | O(1) + vtable lookup | One extra indirection vs non-virtual |
| `sealed` virtual | O(1), no vtable | JIT can devirtualise and inline |
| Static member access | O(1) | No instance pointer needed |

**Allocation behaviour:** Every `new MyClass()` is a heap allocation. The GC reclaims it when no references remain. In hot paths (APIs processing thousands of requests/second), frequent allocation of short-lived class instances creates Gen 0 GC pressure. Use object pooling (`ObjectPool<T>`) or switch to structs/records for data-only types.

**Benchmark notes:** The cost of virtual dispatch (`virtual` + `override`) is negligible for most code — it's one extra memory dereference. It only matters in tight loops doing millions of iterations. `sealed` on a class or a specific override allows the JIT to devirtualise and inline the call, which can matter in hot-path code.

---

## The Code

**Basic class anatomy**
```csharp
public class BankAccount
{
    // Private backing field — state is hidden
    private decimal _balance;

    // Auto-property — compiler generates the backing field
    public string Owner { get; private set; }

    // Read-only property via expression body
    public decimal Balance => _balance;

    // Constructor — validates invariants on creation
    public BankAccount(string owner, decimal initialBalance)
    {
        if (string.IsNullOrWhiteSpace(owner))
            throw new ArgumentException("Owner is required.", nameof(owner));
        if (initialBalance < 0)
            throw new ArgumentOutOfRangeException(nameof(initialBalance), "Cannot be negative.");

        Owner = owner;
        _balance = initialBalance;
    }

    // Method — enforces business rules
    public void Deposit(decimal amount)
    {
        if (amount <= 0) throw new ArgumentException("Amount must be positive.");
        _balance += amount;
    }

    public void Withdraw(decimal amount)
    {
        if (amount <= 0) throw new ArgumentException("Amount must be positive.");
        if (amount > _balance) throw new InvalidOperationException("Insufficient funds.");
        _balance -= amount;
    }

    // Override ToString for readable output
    public override string ToString() => $"Account[{Owner}] Balance: {_balance:C}";
}
```

**Virtual dispatch and inheritance**
```csharp
public class Notification
{
    public string Message { get; init; } = "";

    // virtual: subclasses CAN override this slot
    public virtual void Send()
        => Console.WriteLine($"[Base] {Message}");
}

public class EmailNotification : Notification
{
    public string Recipient { get; init; } = "";

    // override: this subclass DOES replace the vtable slot
    public override void Send()
        => Console.WriteLine($"[Email → {Recipient}] {Message}");
}

// Polymorphic dispatch — caller doesn't know the concrete type
Notification n = new EmailNotification { Recipient = "alice@example.com", Message = "Hi" };
n.Send(); // "[Email → alice@example.com] Hi"
```

**Static members and primary constructors (C# 12)**
```csharp
// Static members are shared across ALL instances
public class Counter
{
    private static int _total;        // one value for the whole type
    private readonly int _id;         // unique per instance

    public Counter() => _id = Interlocked.Increment(ref _total);

    public static int Total => _total;
    public int Id => _id;
}

// Primary constructor (C# 12): parameters in scope throughout class
public class OrderService(IOrderRepository repo, ILogger<OrderService> logger)
{
    public async Task<Order?> GetAsync(int id, CancellationToken ct)
    {
        logger.LogInformation("Fetching order {Id}", id);
        return await repo.FindAsync(id, ct);
    }
}
```

**Object initializer vs constructor: when to use each**
```csharp
// Constructor: enforces required state — prefer for invariants
var account = new BankAccount("Alice", 1000m);

// Object initializer: optional properties after required ones
var notification = new EmailNotification
{
    Message    = "Hello",
    Recipient  = "alice@example.com"
};

// init-only: settable in initializer, immutable afterward
public class Config
{
    public required string ConnectionString { get; init; }  // required = must be set
    public int TimeoutSeconds { get; init; } = 30;           // has a default
}

var config = new Config { ConnectionString = "Server=..." };
// config.ConnectionString = "other"; // compile error — init-only
```

**Sealed: prevent further inheritance and enable devirtualisation**
```csharp
public class StripePaymentGateway : IPaymentGateway
{
    // sealed = no further subclassing allowed
    // JIT can inline calls made through this concrete type
}

public sealed class SqlOrderRepository : IOrderRepository
{
    public sealed override string ToString() => "SqlOrderRepository";
}
```

---

## Real World Example

A `ProductService` in an e-commerce API manages product lookup with caching. The class uses constructor injection (DI), `private readonly` for dependencies, and encapsulates all caching logic so callers only see a clean `GetAsync` method.

```csharp
public class ProductService
{
    private readonly IProductRepository _repository;
    private readonly IDistributedCache _cache;
    private readonly ILogger<ProductService> _logger;
    private const string CacheKeyPrefix = "product:";
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(15);

    public ProductService(
        IProductRepository repository,
        IDistributedCache cache,
        ILogger<ProductService> logger)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        _cache      = cache      ?? throw new ArgumentNullException(nameof(cache));
        _logger     = logger     ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task<ProductDto?> GetAsync(int productId, CancellationToken ct = default)
    {
        string cacheKey = $"{CacheKeyPrefix}{productId}";

        // Try cache first
        byte[]? cached = await _cache.GetAsync(cacheKey, ct);
        if (cached is not null)
        {
            _logger.LogDebug("Cache hit for product {Id}", productId);
            return JsonSerializer.Deserialize<ProductDto>(cached);
        }

        // Cache miss — fetch from DB
        _logger.LogDebug("Cache miss for product {Id}", productId);
        var product = await _repository.FindAsync(productId, ct);

        if (product is null)
            return null;

        var dto = new ProductDto(product.Id, product.Name, product.Price);

        // Store in cache for next call
        await _cache.SetAsync(
            cacheKey,
            JsonSerializer.SerializeToUtf8Bytes(dto),
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = CacheDuration },
            ct);

        return dto;
    }

    public async Task InvalidateCacheAsync(int productId, CancellationToken ct = default)
    {
        await _cache.RemoveAsync($"{CacheKeyPrefix}{productId}", ct);
        _logger.LogInformation("Cache invalidated for product {Id}", productId);
    }
}
```

*The key insight: the class hides the caching strategy completely. A caller using `IProductService` doesn't know or care whether the result came from cache or the database. That's encapsulation doing its job — the caching policy can change (different TTL, different storage) without any caller changing.*

---

## Common Misconceptions

**"Fields should be public so callers can access them directly"**
Public fields give any caller unrestricted read/write access with no opportunity to validate, notify, or add computed logic. Properties with private setters (or `init`) are the standard because they let you enforce invariants at write time and add computed logic at read time, without changing the public API. The single exception is `readonly` struct fields in performance-critical code where property overhead is measured.

**"You need `this.` to access instance members"**
`this.` is only required to disambiguate when a local variable or parameter has the same name as a field. `_balance += amount` is identical to `this._balance += amount`. The convention of prefixing private fields with `_` (as in `_balance`) makes `this.` unnecessary in the vast majority of cases.

**"`sealed` is only for preventing misuse by developers"**
`sealed` is also a performance optimisation. The JIT compiler cannot inline a virtual call unless it can prove at compile time which method will be called. When a class is `sealed`, or when a specific `override` is `sealed`, the JIT can devirtualise the call site and inline the method body — eliminating the vtable lookup entirely. For types called in tight loops, this can be measurable.

---

## Gotchas

- **Calling virtual methods in a constructor is dangerous.** When the base constructor runs, the derived class's fields are zero-initialised but its constructor hasn't run. A virtual method called from the base constructor dispatches to the override, which may read fields that are still at default values. This is a real bug source with no compile-time warning.

- **`static` fields are shared across the entire AppDomain — including all threads.** A `static int _counter` in a class is one variable shared by every request in an ASP.NET Core app. Concurrent increments without `Interlocked` or a `lock` are a data race. Use `ThreadLocal<T>` or `AsyncLocal<T>` for per-request state.

- **`public` setters on properties are the same as public fields for mutation purposes.** `public string Name { get; set; }` lets any caller assign any value. If `Name` has rules (non-null, non-empty, max length), those rules can't be enforced. Use `private set`, `init`, or a validated constructor.

- **Reference equality by default means `==` on two class instances is almost always wrong for value comparison.** Two `Product` instances with `Id = 1` are not `==` unless you override the operator. Forgetting this in unit tests and LINQ `.Distinct()` calls produces bugs that are hard to trace.

- **Partial classes span multiple files but are one type at compile time.** Auto-generated code (EF Core model scaffolding, WinForms designer) uses `partial` to separate generated from hand-written code. Don't use `partial` as an organisational tool in regular application code — it makes the type's full surface area hard to understand at a glance.

---

## Interview Angle

**What they're really testing:** Whether you understand the memory model (reference type, heap, pointer semantics), OOP fundamentals (encapsulation, inheritance, polymorphism), and the practical implications of virtual dispatch.

**Common question forms:**
- "What's the difference between a class and a struct in C#?"
- "What does `virtual` do, and what happens if you forget it?"
- "What's the difference between `abstract` and `sealed`?"
- "When would you use `static` members?"

**The depth signal:** A junior says "a class is a blueprint for objects" and "virtual lets you override methods." A senior explains that `virtual` sets up a vtable entry — without it, a base-typed reference always calls the base version regardless of the runtime type, silently bypassing any override. They explain that `sealed` enables devirtualisation, that calling virtual methods from constructors is a real bug pattern with no warning, and that static fields are shared across all threads requiring explicit synchronisation.

**Follow-up questions to expect:**
- "Explain what happens in memory when you do `var b = a` for a class."
- "What does `sealed` do to the vtable? Why does it matter for performance?"
- "What are primary constructors (C# 12) and when would you use them?"

---

## Related Topics

- [[dotnet/csharp/csharp-structs.md]] — The value-type counterpart; key for understanding when NOT to use a class
- [[dotnet/csharp/csharp-records.md]] — Classes with compiler-generated value equality and immutability; use instead of a class for data-only types
- [[dotnet/csharp/csharp-inheritance.md]] — How `base`, `virtual`, `override`, and `sealed` work together for polymorphic hierarchies
- [[dotnet/csharp/csharp-encapsulation.md]] — Access modifiers, properties, and invariant enforcement in depth
- [[dotnet/csharp/csharp-interfaces.md]] — The primary alternative to inheritance for expressing polymorphic contracts

---

## Source

[Classes — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/classes)

---

*Last updated: 2026-04-06*