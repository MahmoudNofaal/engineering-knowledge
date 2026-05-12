# C# Records

> A record is a reference type designed for immutable data where equality is based on values, not object identity — with most of the boilerplate written for you by the compiler.

---

## When To Use It
Use a record when your type's job is to carry data and two instances with the same values should be considered equal — DTOs, query results, domain value objects, API request/response models. Records are the right default for data that shouldn't change after construction. Don't use a record for objects with meaningful identity, mutable lifecycle state, or behavior heavier than a few convenience methods — that's a class.

---

## Core Concept
A class uses reference equality by default: two variables are equal only if they point to the same object in memory. A record flips that: two records are equal if all their properties have the same values, which the compiler generates automatically. The compiler also generates a constructor from the positional parameters, a `ToString()` that prints all properties, and a `with` expression for non-destructive mutation — creating a copy with one field changed. You get all of that with one line of code. Under the hood, a record is still a class (or struct for `record struct`) — it just has a different equality contract and a lot of compiler-generated members.

---

## The Code

**Positional record — the one-liner form**
```csharp
// Compiler generates: constructor, get-only properties,
// Equals, GetHashCode, ToString, and deconstruct
public record Point(double X, double Y);

var a = new Point(1.0, 2.0);
var b = new Point(1.0, 2.0);
var c = a;

Console.WriteLine(a == b);          // True  — value equality
Console.WriteLine(ReferenceEquals(a, b)); // False — different objects
Console.WriteLine(a == c);          // True
Console.WriteLine(a);               // Point { X = 1, Y = 2 }
```

**`with` expression — non-destructive mutation**
```csharp
public record Address(string Street, string City, string PostalCode);

var original = new Address("123 Main St", "Springfield", "12345");

// Creates a new record; original is unchanged
var updated = original with { PostalCode = "99999" };

Console.WriteLine(original.PostalCode); // "12345"
Console.WriteLine(updated.PostalCode);  // "99999"
Console.WriteLine(original == updated); // False — PostalCode differs
```

**Record with custom members and validation**
```csharp
public record Money(decimal Amount, string Currency)
{
    // Property validation in the compact constructor
    public decimal Amount { get; init; } = Amount >= 0
        ? Amount
        : throw new ArgumentException("Amount must be non-negative.");

    // Custom method — records can have behavior
    public Money Add(Money other)
    {
        if (Currency != other.Currency)
            throw new InvalidOperationException("Currency mismatch.");
        return this with { Amount = Amount + other.Amount };
    }

    public override string ToString() => $"{Amount:F2} {Currency}";
}

var price = new Money(9.99m, "USD");
var tax   = new Money(0.80m, "USD");
Console.WriteLine(price.Add(tax)); // "10.79 USD"
```

**`record struct` — value type with record semantics (C# 10+)**
```csharp
// Stack-allocated, no heap allocation, still gets value equality
public record struct Coordinate(double Lat, double Lng);

var loc1 = new Coordinate(40.7128, -74.0060);
var loc2 = loc1 with { Lng = -73.9857 };

Console.WriteLine(loc1 == loc2); // False
```

**Record inheritance**
```csharp
public record Shape(string Color);
public record Circle(string Color, double Radius) : Shape(Color);

Shape s = new Circle("Red", 5.0);
Console.WriteLine(s); // Circle { Color = Red, Radius = 5 }

// Equality checks the runtime type — a Shape and Circle are never equal
// even if their shared properties match
var s1 = new Shape("Red");
var c1 = new Circle("Red", 5.0);
Console.WriteLine(s1 == c1); // False — different runtime types
```

---

## Gotchas

- **Positional record properties are `init`-only, not truly immutable at the reference level.** The properties themselves can't be reassigned after construction, but if a property is a mutable object (like a `List<T>`), the contents of that list can still be modified. A record of a `List` is not a deeply immutable structure.
- **`with` is shallow copy.** When you do `record with { Prop = newVal }`, any reference-type properties that you don't replace are shared between the original and the copy. If `Address` has a `List<string> Tags`, both the original and the copy point at the same list.
- **Equality includes all properties — including ones you might not want compared.** If your record has a `CreatedAt` timestamp or an internal `_cacheKey`, those are included in equality checks unless you manually override `Equals` and `GetHashCode`. This can make records with audit fields unexpectedly unequal.
- **Record inheritance equality uses `EqualityContract`.** The compiler generates an `EqualityContract` property (returns `typeof(TheRecord)`) and includes it in equality checks. Two records with the same values but different runtime types (like `Shape` and `Circle`) are never equal — which is usually correct but can surprise you if you're relying on base-type equality in a polymorphic scenario.
- **Serialization libraries may not handle positional records without a parameterless constructor.** `System.Text.Json` requires either a parameterless constructor or a constructor annotated with `[JsonConstructor]`. A positional record has no parameterless constructor by default. Either add one or apply the attribute to the positional constructor.

---

## Interview Angle
**What they're really testing:** Whether you understand the difference between reference equality and value equality, when immutability is a design benefit, and what the compiler actually generates for you.

**Common question form:** "What is a record in C# and when would you use one instead of a class?" or "What's the difference between a record and a class?"

**The depth signal:** A junior says "records are immutable classes with value equality." A senior is more precise: records are classes (reference types, on the heap) where the compiler generates value-based `Equals`/`GetHashCode` using all properties, a `with` expression for copying, and positional deconstruction. They'll distinguish `record` (reference type) from `record struct` (value type), explain that immutability is `init`-only on the surface but not enforced deep into reference-type properties, and note the `EqualityContract` mechanism that prevents a base record from equaling a derived one. They'll also know when NOT to use a record — any type with an identity, mutable state, or a lifecycle that changes over time is still a class.

---

## Related Topics
- [[dotnet/csharp-classes.md]] — Records are built on top of classes; understanding reference types and constructors is the prerequisite.
- [[dotnet/csharp-structs.md]] — `record struct` combines record semantics with value-type memory allocation; the struct tradeoffs still apply.
- [[dotnet/csharp-encapsulation.md]] — Records enforce a strong form of encapsulation via `init`-only properties; useful contrast with mutable class patterns.
- [[dotnet/csharp-pattern-matching.md]] — Positional records support deconstruction in switch expressions, making pattern matching over record hierarchies clean and expressive.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record)

---
*Last updated: 2026-03-23*