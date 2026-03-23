# C# Encapsulation

> Encapsulation is the practice of hiding internal state and implementation details behind a controlled public surface, so outside code can only interact with an object in ways you explicitly allow.

---

## When To Use It
Encapsulation applies to every class you write — it's not an optional technique, it's the default posture. It matters most when your object has invariants to protect: rules that must always be true about its state, like "balance can never go negative" or "name can never be null or empty." Without encapsulation, any caller can corrupt that state directly. The risk of skipping it is low in throwaway scripts and high in any codebase with more than one developer or more than one callsite.

---

## Core Concept
The idea is simple: keep fields private, expose only what needs to be exposed, and control access through properties and methods that can enforce rules. A property with only a getter means the value is read-only from outside. A setter with a validation check means you decide what values are legal. The outside world sees a clean surface; the messy internals are your business. In C#, `private` is the default access for fields, and properties are the idiomatic way to expose state with controlled read/write access.

---

## The Code

**Private fields with property access control**
```csharp
public class BankAccount
{
    private decimal _balance;
    private readonly string _owner;  // set once in constructor, never again

    public BankAccount(string owner, decimal initialBalance)
    {
        if (string.IsNullOrWhiteSpace(owner))
            throw new ArgumentException("Owner required.");
        if (initialBalance < 0)
            throw new ArgumentException("Initial balance can't be negative.");

        _owner = owner;
        _balance = initialBalance;
    }

    public string Owner => _owner;           // read-only — no setter at all
    public decimal Balance => _balance;      // read-only — callers can see, not set

    public void Deposit(decimal amount)
    {
        if (amount <= 0) throw new ArgumentException("Deposit must be positive.");
        _balance += amount;
    }

    public void Withdraw(decimal amount)
    {
        if (amount <= 0) throw new ArgumentException("Amount must be positive.");
        if (amount > _balance) throw new InvalidOperationException("Insufficient funds.");
        _balance -= amount;
    }
}

var account = new BankAccount("Alice", 100m);
account.Deposit(50m);
// account._balance = 9999; — compile error, field is private
// account.Balance = 9999;  — compile error, no setter
Console.WriteLine(account.Balance); // 150
```

**Access modifier spectrum**
```csharp
public class Order
{
    public int Id { get; }                      // anyone can read
    internal string InternalRef { get; set; }   // only within same assembly
    protected decimal BasePrice { get; set; }   // only this class and subclasses
    private List<string> _auditLog = new();     // only this class

    // private set — public read, but only this class can write
    public string Status { get; private set; } = "Pending";

    public void Approve()
    {
        Status = "Approved";          // valid — same class
        _auditLog.Add("Approved");
    }
}

var order = new Order();
// order.Status = "Approved"; — compile error, setter is private
```

**`init` — settable only during construction**
```csharp
public class Product
{
    public int Id { get; init; }         // set in initializer, then immutable
    public string Name { get; init; }

    // Valid: object initializer syntax runs at construction time
    // Invalid: any assignment after the object is created
}

var p = new Product { Id = 1, Name = "Widget" };
// p.Name = "Other"; — compile error after construction
```

**Property with validation in setter**
```csharp
public class Employee
{
    private int _age;

    public int Age
    {
        get => _age;
        set
        {
            if (value < 16 || value > 100)
                throw new ArgumentOutOfRangeException(nameof(Age), "Age must be 16–100.");
            _age = value;
        }
    }
}
```

---

## Gotchas

- **Auto-properties with public setters are not encapsulation.** `public string Name { get; set; }` is a public field with extra syntax. Any caller can set any value. If you have invariants to protect, you need a private backing field or at minimum a `private set` / `init`.
- **`readonly` on a field only prevents reassignment of the reference, not mutation of the object.** `private readonly List<string> _items = new()` means `_items` can't be pointed at a different list — but `_items.Add("x")` works fine. If you want to prevent that, expose `IReadOnlyList<string>` instead of the list itself.
- **Returning a mutable collection from a property leaks internal state.** `public List<Order> Orders => _orders;` hands callers a reference to your private list. They can `Add`, `Remove`, or `Clear` it without going through any of your methods. Return `_orders.AsReadOnly()` or `IReadOnlyList<Order>` instead.
- **`protected` is a wider surface than most people realize.** Marking a field `protected` means any subclass in any assembly (including third-party code if your library is public) can read and write it. For internal implementation details, prefer `private` and expose via a `protected` property with a getter only.
- **Structs don't enforce encapsulation the same way.** A `public` field on a struct is copied on assignment, so the caller mutates their copy — which feels safe but leads to the silent mutation bugs described in the structs topic. The pattern still applies, but the failure mode is different.

---

## Interview Angle
**What they're really testing:** Whether you understand why encapsulation exists beyond "it's one of the four OOP pillars" — specifically, invariant protection and controlled mutation.

**Common question form:** "What is encapsulation and why does it matter?" or "Why would you use a property instead of a public field?"

**The depth signal:** A junior says "encapsulation means making fields private." A senior explains the actual goal: protecting object invariants — the rules that must always be true about an object's state. They'll give a concrete example like a bank account where `_balance` must never go negative, and explain that a public field lets any caller violate that rule with a direct assignment, while a private field with controlled methods makes it structurally impossible to corrupt the invariant. A senior will also distinguish between hiding state (access modifiers) and hiding behavior (not exposing internal methods), and note that returning mutable collections or exposing `protected` fields are common ways encapsulation is unintentionally broken even when fields are technically private.

---

## Related Topics
- [[dotnet/csharp-classes.md]] — Access modifiers and properties are class-level features; encapsulation is applied at the class level.
- [[dotnet/csharp-structs.md]] — Encapsulation on structs has different failure modes due to copy semantics; worth understanding the contrast.
- [[dotnet/csharp-records.md]] — Records enforce immutability by default, which is the strongest form of encapsulation for data types.
- [[dotnet/csharp-properties.md]] — Properties are the primary C# mechanism for controlled state exposure; the full property syntax lives here.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/)

---
*Last updated: 2026-03-23*