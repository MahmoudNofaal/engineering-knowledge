# C# Inheritance

> Inheritance lets one class acquire the fields, properties, and methods of another, so you can build specialized types on top of a shared base.

---

## When To Use It
Use inheritance when a genuine is-a relationship exists — `Dog` is an `Animal`, `SavingsAccount` is a `BankAccount`. It's the right tool when subclasses share real implementation and you want polymorphic behavior through a common base type. Don't use it just to reuse code — if there's no is-a relationship, composition (holding another object as a field) is almost always the better choice. Inheritance chains deeper than two or three levels are usually a design smell.

---

## Core Concept
When class B inherits from class A, B gets everything A has — its fields, properties, and non-private methods. B can add new members or override virtual ones. The key runtime behavior is that a variable typed as `A` can hold a `B` instance, and if you call a virtual method on it, you get `B`'s version — not `A`'s. C# only allows single inheritance (one base class), which is the main reason interfaces exist. The `base` keyword is how a subclass reaches back into its parent to call the original constructor or method.

---

## The Code

**Basic inheritance and constructor chaining**
```csharp
public class Animal
{
    public string Name { get; }

    public Animal(string name)
    {
        Name = name;
    }

    public virtual string Describe() => $"I am {Name}";
}

public class Dog : Animal
{
    public string Breed { get; }

    // base(...) calls the parent constructor first
    public Dog(string name, string breed) : base(name)
    {
        Breed = breed;
    }

    public override string Describe() => $"I am {Name}, a {Breed}";
}

Animal a = new Dog("Rex", "Labrador");
Console.WriteLine(a.Describe()); // "I am Rex, a Labrador" — Dog's version
```

**`base` keyword — calling the parent method**
```csharp
public class Logger
{
    public virtual void Log(string message)
        => Console.WriteLine($"[LOG] {message}");
}

public class TimestampLogger : Logger
{
    public override void Log(string message)
    {
        // Extend parent behavior rather than replace it entirely
        base.Log($"{DateTime.UtcNow:O} | {message}");
    }
}
```

**`sealed` — stopping the chain**
```csharp
public class PaymentProcessor
{
    public virtual void Process() => Console.WriteLine("Processing...");
}

// sealed class — nothing can inherit from this
public sealed class StripeProcessor : PaymentProcessor
{
    public override void Process() => Console.WriteLine("Stripe processing");
}

// sealed override — stops just this method from being overridden further
public class AnotherProcessor : PaymentProcessor
{
    public sealed override void Process() => Console.WriteLine("Another");
}
```

**`abstract` — forcing subclasses to implement**
```csharp
public abstract class Shape
{
    // No body — every subclass MUST provide this
    public abstract double Area();

    // Concrete method shared by all shapes
    public void Print() => Console.WriteLine($"Area: {Area()}");
}

public class Circle : Shape
{
    private double _radius;
    public Circle(double radius) => _radius = radius;

    public override double Area() => Math.PI * _radius * _radius;
}

Shape s = new Circle(5);
s.Print(); // "Area: 78.539..."
// Shape s = new Shape(); — compile error, can't instantiate abstract class
```

---

## Gotchas

- **Forgetting `virtual` means no polymorphism.** A method that isn't `virtual` can't be overridden — only hidden with `new`. If you call that method through a base-typed reference, you always get the base version, silently. `new` on a derived method hides the base, it does not override it.
- **Constructors are not inherited.** A subclass must define its own constructors and explicitly chain to the base with `: base(...)`. If the base class has no parameterless constructor and you forget `: base(...)`, it won't compile.
- **`protected` is wider than you think in a library.** Any class in any assembly that inherits yours can see `protected` members. Don't put sensitive internal state there just because you want subclasses to access it.
- **Calling virtual methods in a constructor is a real bug source.** When the base constructor runs, the derived class's fields are zeroed but its constructor hasn't run yet. A virtual method called from the base constructor dispatches to the override, which may read uninitialized derived state.
- **Deep hierarchies become fragile fast.** A change to a grandparent class can break behavior two levels down in ways that are hard to trace. Prefer composition over inheritance beyond one level of specialization.

---

## Interview Angle
**What they're really testing:** Whether you understand the mechanics of virtual dispatch, where inheritance breaks down, and why composition is often preferred.

**Common question form:** "What is the difference between `override` and `new`?" or "When would you choose composition over inheritance?"

**The depth signal:** A junior says "`override` replaces a method and `new` also replaces it." A senior explains the exact difference: `override` participates in virtual dispatch — a base-typed reference calls the derived version. `new` only hides the method — a base-typed reference still calls the base version, making `new` nearly useless for polymorphism. They'll also articulate the Liskov Substitution Principle: a subclass should be substitutable for its base without breaking the program — which is the real test of whether inheritance is being used correctly, not just whether the code compiles.

---

## Related Topics
- [[dotnet/csharp-classes.md]] — Inheritance is built on top of classes; `virtual`, `override`, and constructors are all class concepts first.
- [[dotnet/csharp-interfaces.md]] — The alternative to inheritance for polymorphism; C#'s answer to multiple inheritance.
- [[dotnet/interfaces-abstract-classes.md]] — Direct comparison: abstract class gives you inheritance + contract; interface gives you contract only.
- [[dotnet/csharp-polymorphism.md]] — Virtual dispatch and runtime type behavior is the payoff for setting up inheritance correctly.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/inheritance](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/inheritance)

---
*Last updated: 2026-03-23*