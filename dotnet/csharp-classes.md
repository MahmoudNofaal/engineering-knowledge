# C# Classes

> A class is a blueprint that defines the data (fields/properties) and behavior (methods) that its objects will have.

---

## When To Use It
Use a class when you need a reference type that models a real-world entity or a logical unit of behavior. Classes are appropriate when you need inheritance, identity semantics, or mutable shared state. Don't reach for a class when a `record` (for immutable data) or `struct` (for small, stack-allocated value types) fits better.

---

## Core Concept
A class is a reference type — when you pass it around, you're passing a pointer to the same object in memory, not a copy. This matters because two variables can point to the same instance. The class itself doesn't do anything; it's the mold. The `new` keyword creates an instance from that mold and puts it on the heap. Everything else — constructors, access modifiers, properties — is about controlling how that instance is built and exposed.

---

## The Code

**Basic class anatomy**
```csharp
public class BankAccount
{
    // Backing field — private by convention
    private decimal _balance;

    // Auto-property — compiler generates the backing field
    public string Owner { get; set; }

    // Constructor
    public BankAccount(string owner, decimal initialBalance)
    {
        Owner = owner;
        _balance = initialBalance;
    }

    // Method
    public void Deposit(decimal amount)
    {
        if (amount <= 0) throw new ArgumentException("Amount must be positive.");
        _balance += amount;
    }

    // Read-only property — no setter
    public decimal Balance => _balance;
}
```

**Inheritance and virtual dispatch**
```csharp
public class Animal
{
    public string Name { get; init; }

    public Animal(string name) => Name = name;

    // virtual = subclasses CAN override this
    public virtual string Speak() => "...";
}

public class Dog : Animal
{
    public Dog(string name) : base(name) { }

    // override = this subclass DOES override it
    public override string Speak() => "Woof";
}

Animal a = new Dog("Rex");
Console.WriteLine(a.Speak()); // "Woof" — runtime polymorphism
```

**Static members vs instance members**
```csharp
public class Counter
{
    private static int _total = 0;  // shared across ALL instances
    private int _id;                // unique per instance

    public Counter()
    {
        _total++;
        _id = _total;
    }

    public static int Total => _total;
    public int Id => _id;
}

var c1 = new Counter(); // _total = 1, c1.Id = 1
var c2 = new Counter(); // _total = 2, c2.Id = 2
Console.WriteLine(Counter.Total); // 2
```

---

## Gotchas

- **Reference equality by default.** `==` on two class instances checks if they point to the same object, not if they have the same values. Override `Equals` and `GetHashCode` (or use `record`) if you need value equality.
- **Forgetting `virtual`/`override` breaks polymorphism silently.** If the base method isn't `virtual`, calling `.Speak()` on an `Animal` reference always calls `Animal.Speak()` — even if the object is a `Dog`. No compiler error, wrong behavior at runtime.
- **`init` vs `set` isn't just style.** `init` only allows assignment during object initialization (constructor or initializer syntax). After that, it's immutable. Using `set` when you meant `init` opens mutation you didn't intend.
- **Static fields are shared across the entire AppDomain.** In web apps, one static counter shared by all threads and requests. Concurrency bugs live here if you're not careful.
- **Calling virtual methods from a constructor is dangerous.** The derived class constructor hasn't run yet, so overridden methods may read uninitialized state.

---

## Interview Angle
**What they're really testing:** Understanding of OOP fundamentals, memory model (reference vs value types), and how C#'s type system enforces encapsulation.

**Common question form:** "Explain the difference between a class and a struct" or "How does inheritance work in C#?" or "What does `virtual` do?"

**The depth signal:** A junior says "override lets you change a method in a subclass." A senior explains that without `virtual`, the vtable entry isn't set up — so even with `override` declared on the derived type, a base-typed reference won't dispatch to it. They'll also mention `sealed` to prevent further overrides for performance (devirtualization), and know that calling abstract/virtual members from a constructor is a design smell with real consequences.

---

## Related Topics
- [[dotnet/csharp-records.md]] — Records are classes with built-in value equality and immutability; know when to use one over the other.
- [[dotnet/interfaces-abstract-classes.md]] — The other half of the polymorphism story; classes implement interfaces or extend abstract classes.
- [[dotnet/csharp-structs.md]] — The value-type counterpart; key for understanding when NOT to use a class.
- [[dotnet/access-modifiers.md]] — Controls what outside code can touch on your class members.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/classes](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/classes)

---
*Last updated: 2026-03-23*