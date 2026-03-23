# C# Object Class

> `object` is the root of every type in C# — every class, struct, record, and built-in type ultimately inherits from it, which means every value in .NET has a guaranteed minimum set of methods.

---

## When To Use It
You don't choose to use `object` — it's always there. It matters when you need to understand what methods are available on any type (`ToString`, `Equals`, `GetHashCode`, `GetType`), when you're writing code that must accept literally any value, or when you're overriding the default equality or string representation on your own types. It matters most in interviews and debugging, and when you're implementing `Equals`/`GetHashCode` correctly as a pair.

---

## Core Concept
Every type in C# — `int`, `string`, your custom `Order` class, a struct, a record — inherits from `System.Object` (aliased as `object`). This means you can assign anything to an `object` variable, and every instance has four methods available: `ToString()` returns a string representation, `Equals()` checks equality, `GetHashCode()` returns a hash, and `GetType()` returns the runtime type. The defaults are: `ToString()` returns the type name, `Equals()` compares by reference, and `GetHashCode()` is based on identity. You override these when the defaults aren't meaningful for your type. The contract between `Equals` and `GetHashCode` — if two objects are equal, they must have the same hash code — is the most important rule that comes with inheriting from `object`.

---

## The Code

**The four inherited methods**
```csharp
var order = new Order(42, "Alice");

Console.WriteLine(order.ToString());    // "Order" (default — type name)
Console.WriteLine(order.GetType());     // "Order" (runtime type, not declared type)
Console.WriteLine(order.GetHashCode()); // some int based on identity
Console.WriteLine(order.Equals(order)); // True (same reference)

object box = order;  // any type is assignable to object
Console.WriteLine(box.GetType().Name); // "Order" — runtime type survives the cast
```

**Overriding `ToString` and `Equals`/`GetHashCode` together**
```csharp
public class Order
{
    public int Id { get; }
    public string Customer { get; }

    public Order(int id, string customer)
    {
        Id = id;
        Customer = customer;
    }

    // Useful ToString — default just prints "Order"
    public override string ToString() => $"Order #{Id} for {Customer}";

    // Value equality based on Id
    public override bool Equals(object? obj)
    {
        if (obj is not Order other) return false;
        return Id == other.Id;
    }

    // MUST override GetHashCode when overriding Equals
    // Objects that are equal must produce the same hash code
    public override int GetHashCode() => Id.GetHashCode();
}

var a = new Order(1, "Alice");
var b = new Order(1, "Bob");   // same Id, different customer

Console.WriteLine(a.Equals(b));   // True  — same Id
Console.WriteLine(a == b);        // False — == still uses reference equality
                                  //         unless you also overload the operator
Console.WriteLine(a);             // "Order #1 for Alice"
```

**`==` vs `Equals` after overriding**
```csharp
// Equals is overridden — value equality
// == is NOT overridden — still reference equality
// This asymmetry is a real trap:

var x = new Order(5, "Alice");
var y = new Order(5, "Alice");

Console.WriteLine(x.Equals(y)); // True  — overridden
Console.WriteLine(x == y);      // False — operator not overloaded

// To fix the asymmetry, also overload ==:
public static bool operator ==(Order? left, Order? right)
    => left?.Equals(right) ?? right is null;

public static bool operator !=(Order? left, Order? right)
    => !(left == right);
```

**`GetType` vs `is` — when they differ**
```csharp
public class Animal { }
public class Dog : Animal { }

Animal a = new Dog();

Console.WriteLine(a.GetType() == typeof(Dog));    // True  — runtime type
Console.WriteLine(a.GetType() == typeof(Animal)); // False — not the declared type
Console.WriteLine(a is Animal);                   // True  — is checks assignability
Console.WriteLine(a is Dog);                      // True  — is also checks runtime type
```

**`object` as a universal parameter — and why generics replaced it**
```csharp
// Pre-generics pattern — accepts anything, but loses type info and boxes value types
public void PrintAll(object[] items)
{
    foreach (var item in items)
        Console.WriteLine(item?.ToString());
}

// Modern equivalent — type-safe, no boxing for value types
public void PrintAll<T>(IEnumerable<T> items)
{
    foreach (var item in items)
        Console.WriteLine(item?.ToString());
}
```

---

## Gotchas

- **Overriding `Equals` without overriding `GetHashCode` breaks dictionaries and hash sets silently.** If two objects are `Equals` but have different hash codes, a `Dictionary<Order, V>` will put them in different buckets and you'll never find the second one with a lookup. The compiler warns you, but the bug is runtime-silent until you can't find a key you just inserted.
- **`==` and `Equals` are independent until you explicitly couple them.** Overriding `Equals` does not affect `==`. For classes, `==` stays reference equality unless you overload the operator. For `record` types, the compiler overloads both automatically — which is one of the main reasons records exist.
- **`GetType()` returns the runtime type, not the declared type.** `Animal a = new Dog(); a.GetType()` is `Dog`, not `Animal`. This matters when you're doing type comparisons — `a.GetType() == typeof(Animal)` is `false`. Use `is` if you want assignability checking.
- **`object.ReferenceEquals(a, b)` is the only equality check that can't be overridden.** If you need to know two variables point to the exact same instance regardless of any `Equals` override, use `ReferenceEquals`. This is also how you guard against self-comparison inside `Equals` implementations.
- **Structs inherit from `object` too, but their `GetHashCode` and `Equals` defaults are different.** The default struct `Equals` does field-by-field value comparison using reflection, which is slow. The default `GetHashCode` on a struct is based on the first non-null field. Always override both on structs you use as dictionary keys.

---

## Interview Angle
**What they're really testing:** Whether you understand the `Equals`/`GetHashCode` contract, the difference between `==` and `Equals`, and how the type system is unified through `object`.

**Common question form:** "What methods does every C# object have?" or "What's the contract between `Equals` and `GetHashCode`?" or "Why do you have to override both `Equals` and `GetHashCode` together?"

**The depth signal:** A junior says "you should override both at the same time." A senior explains exactly why: hash-based collections (`Dictionary`, `HashSet`) use `GetHashCode` to find the bucket, then `Equals` to confirm the match within the bucket. If two equal objects hash differently, the lookup goes to the wrong bucket and returns nothing — a silent correctness bug, not a crash. They'll also explain that `==` is a static operator resolved at compile time against the declared type, while `Equals` is a virtual method dispatched at runtime against the actual type — making them behave differently on the same objects if you haven't overloaded `==` to match.

---

## Related Topics
- [[dotnet/csharp-classes.md]] — Every class implicitly inherits from `object`; understanding the base is part of understanding classes.
- [[dotnet/csharp-structs.md]] — Structs also inherit from `object` but box when assigned to `object`; the default `Equals`/`GetHashCode` behavior differs meaningfully.
- [[dotnet/csharp-records.md]] — Records automate the `Equals`/`GetHashCode`/`==` override that you'd otherwise write manually on a class.
- [[dotnet/boxing-and-unboxing.md]] — Assigning a value type to `object` is boxing; understanding `object` as a universal base type leads directly here.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/reference-types#the-object-type](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/reference-types#the-object-type)

---
*Last updated: 2026-03-23*