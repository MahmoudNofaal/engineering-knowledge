# C# Object Class

> `object` is the root of every type in C# — every class, struct, interface, and built-in type ultimately inherits from `System.Object`, giving every value a guaranteed minimum set of methods.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Universal base type; alias for `System.Object` |
| **C# version** | C# 1.0 |
| **Namespace** | `System` |
| **Key methods** | `ToString()`, `Equals()`, `GetHashCode()`, `GetType()`, `ReferenceEquals()` |
| **Critical contract** | If `a.Equals(b)` is true, `a.GetHashCode() == b.GetHashCode()` must also be true |

---

## When To Use It

You don't choose to use `object` — it's always there. What matters is:

- **When to override its methods**: override `ToString()` to give your types meaningful debug output; override `Equals` and `GetHashCode` together when you need value-based equality on a class.
- **When NOT to override**: don't override `Equals` and `GetHashCode` on types that have identity (entities with a database ID). Two `Customer` instances with the same data might still be different customers.
- **When to use `object` as a parameter type**: almost never in modern C#. Use generics (`T`) instead — they preserve type safety and avoid boxing for value types.
- **When `object` is unavoidable**: reflection, logging interpolation, old pre-generics APIs, and some COM interop scenarios.

---

## Core Concept

Every type in C# — `int`, `string`, your custom `Order` class, a struct, a record, an enum — derives from `System.Object` (aliased as `object`). This means you can assign anything to an `object` variable, and every instance has four core methods.

**`ToString()`** — The default returns the full type name (`"MyApp.Models.Order"`). Override it to return something useful for debugging, logging, and `string.Format`.

**`Equals(object?)`** — The default compares by reference identity (same heap address). Override it to compare by value. The contract: `Equals` must be reflexive, symmetric, transitive, and consistent.

**`GetHashCode()`** — Returns an integer used by hash-based collections. The contract: objects that are `Equals` must have the same hash code. Override whenever you override `Equals`.

**`GetType()`** — Returns the runtime type as a `Type` object. Cannot be overridden. Used in reflection and type checks.

The `Equals`/`GetHashCode` contract is the most important thing to understand about `object`. Breaking it produces silent, hard-to-debug failures in `Dictionary<K,V>`, `HashSet<T>`, LINQ's `.Distinct()`, and everywhere that hashing is used.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | `System.Object` as the root type |
| C# 2.0 | .NET 2.0 | `IEquatable<T>` — typed equality without boxing |
| C# 6.0 | .NET 4.6 | `nameof` operator for property names in `GetHashCode` |
| C# 7.0 | .NET Core 1.0 | Tuple `HashCode.Combine` (via `ValueTuple`) |
| C# 8.0 | .NET Core 3.0 | `HashCode.Combine` in BCL (clean hash combining) |
| C# 9.0 | .NET 5 | Records automate all of this — `Equals`, `GetHashCode`, `==`, `!=` |

*Before records (C# 9), implementing correct value equality on a class required overriding `Equals`, `GetHashCode`, `==`, `!=`, and implementing `IEquatable<T>`. Records automate all five. For new value-carrying types, use `record` instead of doing this manually.*

---

## Performance

| Method | Cost | Notes |
|---|---|---|
| `GetType()` | ~1–2 ns | One memory read (type handle from object header) |
| `Equals(object)` | O(1) default | One pointer comparison — faster than you'd expect |
| `GetHashCode()` default | O(1) | Identity-based — often the object's memory address |
| Custom `GetHashCode()` | O(n properties) | Manual computation — use `HashCode.Combine` |
| `ReferenceEquals` | O(1) | Always — single pointer comparison, never overridable |
| `ToString()` default | O(1) + type reflection | Returns type name string |

**Allocation behaviour:** `GetType()` returns a shared `Type` object — no allocation. `ToString()` default returns a new string (type name) — allocates. Custom `ToString()` with string interpolation allocates. `Equals` and `GetHashCode` allocate nothing.

**Benchmark notes:** The overhead of calling `object` methods is negligible for all but the most extreme hot paths. The real concern is correctness of the `Equals`/`GetHashCode` contract, not performance.

---

## The Code

**The four core methods**
```csharp
var order = new Order(42, "Alice");

Console.WriteLine(order.ToString());    // "Order" — default: type name
Console.WriteLine(order.GetType());     // System.RuntimeType for Order
Console.WriteLine(order.GetHashCode()); // some int based on identity
Console.WriteLine(order.Equals(order)); // True — same reference
Console.WriteLine(order.Equals(new Order(42, "Alice"))); // False — different reference (default)

// GetType() returns the RUNTIME type — not the declared type
Animal a = new Dog("Rex");
Console.WriteLine(a.GetType().Name);     // "Dog" — runtime type
Console.WriteLine(a.GetType() == typeof(Dog));    // True
Console.WriteLine(a.GetType() == typeof(Animal)); // False
```

**Overriding `Equals`, `GetHashCode`, and `ToString` correctly**
```csharp
public class Product : IEquatable<Product>
{
    public int    Id       { get; }
    public string Name     { get; }
    public decimal Price   { get; }

    public Product(int id, string name, decimal price)
        => (Id, Name, Price) = (id, name, price);

    // Value equality based on Id only (the business key)
    public override bool Equals(object? obj)
        => obj is Product other && Equals(other);

    // Typed equality — avoids boxing, called by Dictionary/HashSet
    public bool Equals(Product? other)
        => other is not null && Id == other.Id;

    // MUST be consistent with Equals — equal objects must have equal hashes
    // HashCode.Combine handles null-safety and distribution
    public override int GetHashCode() => HashCode.Combine(Id);

    // Override == and != to match Equals
    public static bool operator ==(Product? left, Product? right)
        => left?.Equals(right) ?? right is null;

    public static bool operator !=(Product? left, Product? right)
        => !(left == right);

    // Useful for debugging and logging
    public override string ToString() => $"Product #{Id}: {Name} ({Price:C})";
}

var p1 = new Product(1, "Widget", 9.99m);
var p2 = new Product(1, "Widget", 9.99m); // same data
var p3 = new Product(2, "Gadget", 14.99m);

Console.WriteLine(p1.Equals(p2));       // True  — same Id
Console.WriteLine(p1 == p2);            // True  — operator overloaded
Console.WriteLine(ReferenceEquals(p1, p2)); // False — different objects

// Works correctly in collections because Equals and GetHashCode are consistent
var set = new HashSet<Product> { p1, p2, p3 };
Console.WriteLine(set.Count); // 2 — p1 and p2 are considered the same
```

**`ReferenceEquals` — identity that can never be overridden**
```csharp
var a = new Product(1, "Widget", 9.99m);
var b = a;   // same reference
var c = new Product(1, "Widget", 9.99m); // different object, same data

Console.WriteLine(ReferenceEquals(a, b)); // True  — same object
Console.WriteLine(ReferenceEquals(a, c)); // False — different objects
Console.WriteLine(a.Equals(c));           // True  — value equality (if we override)

// ReferenceEquals is useful inside Equals to handle the "same object" fast path
public override bool Equals(object? obj)
{
    if (ReferenceEquals(this, obj)) return true;  // fast path
    if (obj is not Product other) return false;    // type check
    return Id == other.Id;                          // value comparison
}
```

**Using `object` as a universal container — and why generics replaced it**
```csharp
// Pre-generics pattern — type-unsafe, boxes value types
public void PrintAll(object[] items)
{
    foreach (var item in items)
        Console.WriteLine(item?.ToString());
}

// Modern — type-safe, no boxing for value types
public void PrintAll<T>(IEnumerable<T> items)
{
    foreach (var item in items)
        Console.WriteLine(item?.ToString());
}

// object is still used in: reflection, dynamic code, COM interop
// and as a lock target: object _lock = new();
```

**`HashCode.Combine` for multi-field hashing (C# 8+)**
```csharp
// WRONG: XOR of hash codes — produces collisions for equal pairs
public override int GetHashCode() => Name.GetHashCode() ^ Age.GetHashCode();
// "Alice"^30 == "Bob"^29 might coincidentally collide

// CORRECT: use HashCode.Combine — proper distribution
public override int GetHashCode() => HashCode.Combine(Name, Age, Department);

// For nullable properties:
public override int GetHashCode()
    => HashCode.Combine(FirstName, LastName ?? string.Empty, DateOfBirth);
```

---

## Real World Example

An entity framework-style `DbContext` needs to track entity identity. Objects retrieved from the database are cached by their primary key. The identity tracking relies on correct `Equals` and `GetHashCode` so the change tracker can detect when the same entity is accessed twice.

```csharp
public abstract class Entity : IEquatable<Entity>
{
    public int Id { get; protected set; }

    // Entities with no Id (not yet saved) use reference equality
    // Entities with an Id use value equality by Id
    public override bool Equals(object? obj) => obj is Entity other && Equals(other);

    public bool Equals(Entity? other)
    {
        if (other is null) return false;
        if (ReferenceEquals(this, other)) return true;
        if (GetType() != other.GetType()) return false; // different entity types are never equal

        // Unsaved entities (Id == 0) can't be equal unless they're the same reference
        if (Id == 0 || other.Id == 0) return false;

        return Id == other.Id;
    }

    public override int GetHashCode()
    {
        // Unsaved entities hash by reference (identity)
        // Saved entities hash by Id and type
        if (Id == 0) return System.Runtime.CompilerServices.RuntimeHelpers.GetHashCode(this);
        return HashCode.Combine(GetType(), Id);
    }

    public static bool operator ==(Entity? left, Entity? right)
        => left?.Equals(right) ?? right is null;

    public static bool operator !=(Entity? left, Entity? right)
        => !(left == right);
}

public sealed class Order : Entity
{
    public string CustomerName { get; set; } = "";
    public decimal Total { get; set; }

    public override string ToString() => $"Order #{Id} for {CustomerName}: {Total:C}";
}

// The change tracker can now use HashSet<Entity> correctly
var tracker = new HashSet<Entity>();
var order1  = new Order { Id = 42, CustomerName = "Alice", Total = 99.99m };
var order2  = new Order { Id = 42, CustomerName = "Alice", Total = 99.99m }; // loaded again

tracker.Add(order1);
tracker.Add(order2); // not added — same Id, same Type = same entity

Console.WriteLine(tracker.Count); // 1 — correctly deduplicated
```

*The key insight: entity equality is more subtle than simple value equality. Two entity instances are equal if they represent the same database row (same type + same Id). An unsaved entity (Id == 0) can only be equal to itself — two different unsaved entities aren't the same row even if their data matches. This requires carefully controlled `Equals` and `GetHashCode` that use `GetType()` and handle the Id == 0 case.*

---

## Common Misconceptions

**"Overriding `Equals` also updates `==`"**
Overriding `Equals` does not change `==`. For classes, `==` stays reference equality unless you explicitly overload the operator. This asymmetry is a real trap: `p1.Equals(p2)` might return `true` while `p1 == p2` returns `false`. Always overload `==` and `!=` when you override `Equals` on a class. Records do all of this automatically.

**"Using XOR (`^`) to combine hash codes is fine"**
`hash1 ^ hash2` is symmetric — `(a, b)` produces the same hash as `(b, a)`. For dictionary keys like `(from, to)`, this means `("NYC", "LAX")` and `("LAX", "NYC")` hash to the same bucket, causing unnecessary collisions. Use `HashCode.Combine` which is order-dependent and has better distribution.

**"`GetHashCode` must return a unique value for each object"**
`GetHashCode` only needs to be *consistent* (same object always returns same value) and *equal objects must produce equal hashes*. Collisions (different objects with the same hash) are allowed and expected. Hash collections handle collisions by using `Equals` to distinguish within a bucket. A hash function that returns `1` for everything is technically valid (just extremely slow — O(n) for all operations).

---

## Gotchas

- **Overriding `Equals` without overriding `GetHashCode` silently breaks hash collections.** If `a.Equals(b)` is `true` but `a.GetHashCode() != b.GetHashCode()`, then `Dictionary<Product, V>` puts them in different buckets. Looking up `b` after inserting `a` returns nothing — a silent correctness bug. The compiler warns you, but the bug is runtime-silent.

- **`GetHashCode` must return the same value for the object's lifetime.** If the property used in `GetHashCode` changes after the object is stored in a `Dictionary` or `HashSet`, the object will be in the wrong bucket and unreachable. This is why mutable types should not be used as dictionary keys, and why `GetHashCode` should only use immutable fields.

- **`==` and `Equals` semantics differ by default.** For classes, `==` is reference equality; `Equals` is also reference equality by default — but `Equals` can be overridden while `==` is a static operator. Records override both. Forgetting to overload `==` after overriding `Equals` leads to confusing inconsistency.

- **`GetType()` returns the runtime type, not the declared type.** `Animal a = new Dog(); a.GetType()` is `typeof(Dog)`, not `typeof(Animal)`. `a.GetType() == typeof(Animal)` is `false`. Use `is Animal` for assignability checking — it handles the whole hierarchy.

- **`ToString()` is called implicitly by string interpolation and concatenation.** Any type used in `$"Value: {myObj}"` calls `myObj.ToString()`. If `ToString()` returns `null` (which it shouldn't, but can), the interpolation produces an empty string silently. Override `ToString()` to return something meaningful — at minimum, the type name and identifying properties.

---

## Interview Angle

**What they're really testing:** Whether you understand the `Equals`/`GetHashCode` contract and can explain what breaks when it's violated.

**Common question forms:**
- "What methods does every C# object have?"
- "What's the contract between `Equals` and `GetHashCode`?"
- "Why do you have to override both `Equals` and `GetHashCode` together?"
- "What does `ReferenceEquals` do that `Equals` doesn't?"

**The depth signal:** A junior says "you should override both at the same time." A senior explains exactly why: hash-based collections use `GetHashCode` to find the bucket, then `Equals` to confirm the match within the bucket. If two objects are `Equals` but hash differently, the lookup goes to the wrong bucket and returns nothing — a silent correctness bug, not an exception. They also explain that `==` is a static operator resolved at compile time against the declared type, while `Equals` is a virtual method dispatched at runtime against the actual type — making them behave differently on the same objects if you haven't overloaded `==` to match.

**Follow-up questions to expect:**
- "What happens to a `Dictionary<MyClass, V>` if you change the key's properties after inserting it?"
- "Why is XOR a poor way to combine hash codes?"
- "What does `HashCode.Combine` do differently?"

---

## Related Topics

- [[dotnet/csharp/csharp-classes.md]] — Every class implicitly inherits from `object`; understanding the base is part of understanding classes
- [[dotnet/csharp/csharp-records.md]] — Records automate the `Equals`/`GetHashCode`/`==`/`!=` override that you'd otherwise write manually
- [[dotnet/csharp/csharp-structs.md]] — Structs also inherit from `object` but have different default `Equals`/`GetHashCode` behaviour (reflection-based, slow)
- [[dotnet/csharp/csharp-boxing-unboxing.md]] — Assigning a value type to `object` is boxing; the `object` base type is what makes boxing necessary

---

## Source

[System.Object — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.object)

---

*Last updated: 2026-04-06*