# C# Encapsulation

> Encapsulation is hiding internal state and implementation details behind a controlled public surface so outside code can only interact with an object in ways you explicitly permit.

---

## Quick Reference

| Access modifier | Visible to | Use for |
|---|---|---|
| `private` | Same class only | Fields, implementation details |
| `protected` | Same class + subclasses | Extensibility hooks for inheritance |
| `internal` | Same assembly | Types used only within the project |
| `protected internal` | Same assembly OR subclasses | Library hooks |
| `private protected` | Same class + subclasses in same assembly | Narrow extensibility |
| `public` | Everywhere | The intentional public API |

---

## When To Use It

Encapsulation applies to every class you write — it's not an optional technique, it's the default posture. The principle: **make everything as private as possible by default, and make things more public only when a specific, justified need arises.**

It matters most when your object has **invariants** to protect: rules that must always be true about its state. A `BankAccount` where balance can never go negative. A `Customer` where name can never be null or empty. An `Order` where items can't be modified after it ships. Without encapsulation, any caller can corrupt these invariants with a direct field assignment. With encapsulation, the class itself controls every state transition.

---

## Core Concept

Keep fields private. Expose state through properties that can enforce rules at write time and compute derived values at read time. Expose behaviour through methods that validate inputs and maintain invariants. The outside world sees a clean API; the implementation details are yours to change without breaking callers.

Access modifiers are the tool, but the goal is correctness: a class with proper encapsulation is impossible to put into an invalid state from outside code. You don't have to trust callers — the type system enforces correctness at compile time.

C# provides multiple encapsulation mechanisms that work together: access modifiers restrict who can access a member, properties control how state is read and written, `readonly` and `init` restrict when state can change, and immutable types (via `readonly struct` or `record`) enforce that state never changes after construction.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Access modifiers, properties with get/set |
| C# 2.0 | .NET 2.0 | `private set` on auto-properties |
| C# 3.0 | .NET 3.5 | Auto-properties (`{ get; set; }` without backing field) |
| C# 6.0 | .NET 4.6 | Getter-only auto-properties (`{ get; }` with initializer) |
| C# 7.2 | .NET Core 2.0 | `private protected` access modifier |
| C# 8.0 | .NET Core 3.0 | `init` accessor — settable only in object initializer |
| C# 9.0 | .NET 5 | `init` in records — immutability-by-default pattern |
| C# 11.0 | .NET 7 | `required` modifier — must be set in initializer |

*Before C# 2.0, `private set` didn't exist — properties were either fully read-only or fully writable. `private set` was added specifically to support the "publicly read, privately written" pattern.*

---

## Performance

Encapsulation has no runtime performance cost when properties use auto-implementation or simple backing fields. The JIT inlines trivial getters and setters — `_balance` and `Balance => _balance` compile to the same IL at the call site. The only overhead is validation logic inside setters, which you'd need anyway.

**Allocation behaviour:** No additional allocations from encapsulation itself. Defensive copying (returning `new List<T>(internalList)` to protect internal state) does allocate — design around `IReadOnlyList<T>` instead.

---

## The Code

**Private fields with property access control**
```csharp
public class BankAccount
{
    // Private field — state hidden from outside
    private decimal _balance;
    private readonly List<string> _transactions = new();

    // Read-only property — callers see balance, can't set it
    public decimal Balance => _balance;

    // Owner set once in constructor — immutable afterward
    public string Owner { get; }

    public BankAccount(string owner, decimal initialBalance)
    {
        if (string.IsNullOrWhiteSpace(owner))
            throw new ArgumentException("Owner required.", nameof(owner));
        if (initialBalance < 0)
            throw new ArgumentOutOfRangeException(nameof(initialBalance), "Cannot be negative.");

        Owner    = owner;
        _balance = initialBalance;
    }

    public void Deposit(decimal amount)
    {
        if (amount <= 0) throw new ArgumentException("Deposit must be positive.", nameof(amount));
        _balance += amount;
        _transactions.Add($"+{amount:C}");
    }

    public void Withdraw(decimal amount)
    {
        if (amount <= 0) throw new ArgumentException("Amount must be positive.", nameof(amount));
        if (amount > _balance) throw new InvalidOperationException("Insufficient funds.");
        _balance -= amount;
        _transactions.Add($"-{amount:C}");
    }

    // Expose transaction history as read-only — callers can iterate but not modify
    public IReadOnlyList<string> Transactions => _transactions.AsReadOnly();
}

var account = new BankAccount("Alice", 100m);
account.Deposit(50m);
// account._balance = 9999;   // compile error — private
// account.Balance = 9999;    // compile error — no setter
// account.Transactions.Add("hack"); // compile error — IReadOnlyList
```

**The full access modifier spectrum**
```csharp
public class Order
{
    // private: only this class — default for fields
    private readonly List<OrderItem> _items = new();

    // public: anyone
    public Guid Id { get; } = Guid.NewGuid();

    // public + private set: read anywhere, written only here
    public OrderStatus Status { get; private set; } = OrderStatus.Pending;

    // init: settable only in initializer — immutable after
    public string CustomerId { get; init; } = "";

    // internal: same assembly only
    internal string InternalReference { get; set; } = "";

    // protected: this class + subclasses (in any assembly)
    protected decimal BasePrice { get; set; }

    // private protected: this class + subclasses in THIS assembly only
    private protected void RecalculateDiscounts() { }

    // protected internal: same assembly OR any subclass
    protected internal void ApplyTax(decimal rate) { }
}
```

**Property with validation in setter**
```csharp
public class Employee
{
    private string _name = "";
    private int _age;

    public string Name
    {
        get => _name;
        set
        {
            if (string.IsNullOrWhiteSpace(value))
                throw new ArgumentException("Name cannot be empty.");
            _name = value.Trim();
        }
    }

    public int Age
    {
        get => _age;
        set
        {
            if (value is < 16 or > 100)
                throw new ArgumentOutOfRangeException(nameof(Age), "Must be 16–100.");
            _age = value;
        }
    }
}
```

**`init` and `required` — modern immutability**
```csharp
public class ProductDto
{
    // required: must be set in object initializer — compile error if missing
    public required int Id { get; init; }
    public required string Name { get; init; }

    // Optional with default
    public decimal Price { get; init; } = 0m;
    public bool IsActive { get; init; } = true;
}

var dto = new ProductDto { Id = 1, Name = "Widget" };
// dto.Name = "Other"; // compile error — init-only after construction
// new ProductDto { Id = 1 } // compile error — Name is required
```

**Protecting collection state**
```csharp
public class Playlist
{
    // Internal list — mutable, but callers never see it
    private readonly List<Song> _songs = new();

    // Expose as read-only view — no Add/Remove/Clear
    public IReadOnlyList<Song> Songs => _songs;

    // Controlled mutation through methods that maintain invariants
    public void AddSong(Song song)
    {
        ArgumentNullException.ThrowIfNull(song);
        if (_songs.Any(s => s.Id == song.Id))
            throw new InvalidOperationException($"Song {song.Id} is already in the playlist.");
        _songs.Add(song);
    }

    public bool RemoveSong(Guid songId)
    {
        var song = _songs.FirstOrDefault(s => s.Id == songId);
        return song is not null && _songs.Remove(song);
    }
}
```

---

## Real World Example

An `Auction` class encapsulates bidding rules that must hold at all times: the current bid can only increase, bids can't be placed after closing, and the auction has exactly one winner. Without encapsulation, any caller could corrupt these rules directly.

```csharp
public class Auction
{
    private decimal _currentBid;
    private string? _currentLeader;
    private readonly List<(string Bidder, decimal Amount, DateTime At)> _bidHistory = new();
    private bool _isClosed;

    public Guid Id { get; } = Guid.NewGuid();
    public string ItemName { get; }
    public decimal StartingPrice { get; }
    public DateTime ClosesAt { get; }

    // Read-only views — callers observe but can't tamper
    public decimal CurrentBid => _currentBid;
    public string? CurrentLeader => _currentLeader;
    public bool IsClosed => _isClosed || DateTime.UtcNow >= ClosesAt;
    public IReadOnlyList<(string, decimal, DateTime)> BidHistory => _bidHistory.AsReadOnly();

    public Auction(string itemName, decimal startingPrice, DateTime closesAt)
    {
        if (closesAt <= DateTime.UtcNow)
            throw new ArgumentException("Closing time must be in the future.");

        ItemName      = itemName;
        StartingPrice = startingPrice;
        ClosesAt      = closesAt;
        _currentBid   = startingPrice;
    }

    public void PlaceBid(string bidder, decimal amount)
    {
        // All business rules enforced here — callers can't bypass them
        if (IsClosed)
            throw new InvalidOperationException("Auction is closed.");
        if (string.IsNullOrWhiteSpace(bidder))
            throw new ArgumentException("Bidder name required.");
        if (amount <= _currentBid)
            throw new InvalidOperationException($"Bid must exceed current bid of {_currentBid:C}.");

        _currentBid    = amount;
        _currentLeader = bidder;
        _bidHistory.Add((bidder, amount, DateTime.UtcNow));
    }

    public AuctionResult Close()
    {
        if (_isClosed)
            throw new InvalidOperationException("Auction already closed.");

        _isClosed = true;
        return _currentLeader is null
            ? AuctionResult.NoBids(Id)
            : AuctionResult.Sold(Id, _currentLeader, _currentBid);
    }
}
```

*The key insight: the `Auction` class makes it structurally impossible to corrupt its invariants. You cannot set `_currentBid` to a lower value. You cannot add items to `_bidHistory` directly. You cannot close an already-closed auction. Every state transition goes through a method that validates preconditions. No amount of creative calling can put an `Auction` into an invalid state — the type system prevents it at compile time.*

---

## Common Misconceptions

**"Auto-properties with public setters are encapsulated"**
`public string Name { get; set; }` is a public field with extra syntax. Any caller can assign any value — including null, empty strings, or values that violate your business rules. If your type has invariants, you need either a private/init setter or a validated setter with a backing field. The property syntax isn't encapsulation — restricting access is.

**"`protected` means only my class can access it"**
`protected` is accessible to any subclass in any assembly. If you're writing a public library, `protected` members are part of your public API surface — they can be accessed by consumers who subclass your type. For truly internal implementation, use `private` and expose what you need to subclasses via `protected` properties with only a getter.

**"Returning a collection property is safe because callers can't see the private field"**
`public List<Order> Orders => _orders;` still lets callers call `.Add()`, `.Remove()`, and `.Clear()` on your internal list — through the reference you handed them. The fact that the field is private is irrelevant if you expose the mutable object through the public API. Return `IReadOnlyList<Order>` or `_orders.AsReadOnly()` to prevent external mutation.

---

## Gotchas

- **`readonly` on a field prevents reassignment, not mutation of the object it points to.** `private readonly List<string> _items = new()` means `_items` can't be pointed at a different list — but `_items.Add("x")` works fine. For true immutability of collection contents, expose `IReadOnlyList<T>` or use `ImmutableList<T>`.

- **`protected` is a wider surface than most people expect.** Marking a field `protected` means any third-party code that inherits your class can access it. Use `private` and `protected` properties with only a getter for state that subclasses need to read but not write.

- **Object initializer syntax bypasses constructor validation when using `init`.** `init` properties can be set in object initializers — which run after the constructor. Validation logic in the constructor won't catch invalid values assigned in the initializer. Put validation in the property setter or use a compact record constructor.

- **`private set` allows mutation from within any method of the class** — including methods that should only read. If you want a property that's set in the constructor and never changes afterward, use `{ get; }` (getter-only with initializer) or `{ get; init; }` (init-only). `private set` is "write anywhere in this class."

- **Partial classes spread state across files, making encapsulation harder to reason about.** A `partial class Customer` split across three files means understanding the full state and invariants requires reading three files. Avoid `partial` for application code — use it only for machine-generated code that you need to extend.

---

## Interview Angle

**What they're really testing:** Whether you understand why encapsulation exists beyond "it's one of the four OOP pillars" — specifically, invariant protection and preventing objects from entering invalid states.

**Common question forms:**
- "What is encapsulation and why does it matter?"
- "Why would you use a property instead of a public field?"
- "What's the difference between `private set` and `init`?"
- "How do you protect a collection from external mutation?"

**The depth signal:** A junior says "encapsulation means making fields private." A senior explains the goal: protecting invariants — rules that must always be true about an object's state. They give a concrete example (bank balance never goes negative), explain that a public field lets any caller violate that rule with a direct assignment, and describe how `private readonly` fields + controlled methods make it structurally impossible. They know `readonly` on a field doesn't prevent mutation of the object it points to, that `IReadOnlyList<T>` is how you protect collection state, and that `protected` is part of the public API surface for inheritable types.

**Follow-up questions to expect:**
- "What is the difference between `readonly` on a field and `IReadOnlyList<T>` on a property?"
- "How does `init` differ from `private set`?"
- "When would you use `internal` vs `private`?"

---

## Related Topics

- [[dotnet/csharp/csharp-classes.md]] — Access modifiers and properties are class-level features; encapsulation is applied at the class level
- [[dotnet/csharp/csharp-records.md]] — Records enforce immutability by default via `init`, which is the strongest form of encapsulation for data types
- [[dotnet/csharp/csharp-structs.md]] — `readonly struct` provides the strongest compile-time immutability guarantee
- [[dotnet/csharp/csharp-interfaces.md]] — Interfaces are a form of encapsulation at a higher level — hiding which implementation is used from the caller

---

## Source

[Object-Oriented Programming — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/)

---

*Last updated: 2026-04-06*