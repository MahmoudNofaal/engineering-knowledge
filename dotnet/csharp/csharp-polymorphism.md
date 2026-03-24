# C# Polymorphism

> Polymorphism is the ability to call a method on a base-typed reference and get the right subclass behavior at runtime, without the caller knowing which subclass it is.

---

## When To Use It
Polymorphism is the payoff for setting up inheritance or interfaces correctly. It matters any time you have a collection of related but varying types that all need to respond to the same operation — processing a list of `Shape` objects and calling `Area()` on each, for example. Without it, you write `if/switch` chains that check the concrete type at runtime, which breaks every time you add a new subtype. Don't force it — if you only ever have one concrete type, there's nothing for polymorphism to do.

---

## Core Concept
The runtime keeps a table of method pointers per type (the vtable). When you declare a method `virtual`, the compiler says "this slot in the table can be replaced by a subclass." When a subclass uses `override`, it replaces that slot. When you call the method on a base-typed reference, the runtime looks up the actual object's type, finds its vtable, and calls whatever's in that slot — which might be the subclass version. The caller never has to know. This is called virtual dispatch, and it's the mechanical reason why `virtual`/`override` is required for polymorphism to work in C#. Without `virtual`, the base slot is called every time, regardless of the actual runtime type.

---

## The Code

**Virtual dispatch in action**
```csharp
public class Notification
{
    public virtual void Send(string message)
        => Console.WriteLine($"[Base] {message}");
}

public class EmailNotification : Notification
{
    public override void Send(string message)
        => Console.WriteLine($"[Email] {message}");
}

public class SmsNotification : Notification
{
    public override void Send(string message)
        => Console.WriteLine($"[SMS] {message}");
}

// Caller works entirely against the base type
List<Notification> notifications = new()
{
    new EmailNotification(),
    new SmsNotification(),
    new EmailNotification()
};

foreach (var n in notifications)
    n.Send("Hello"); // Correct subclass version called each time
// [Email] Hello
// [SMS] Hello
// [Email] Hello
```

**`override` vs `new` — the critical difference**
```csharp
public class Base
{
    public virtual void VirtualMethod() => Console.WriteLine("Base.Virtual");
    public void ConcreteMethod()        => Console.WriteLine("Base.Concrete");
}

public class Derived : Base
{
    // override = participates in virtual dispatch
    public override void VirtualMethod() => Console.WriteLine("Derived.Virtual");

    // new = hides the base method — does NOT affect virtual dispatch
    public new void ConcreteMethod() => Console.WriteLine("Derived.Concrete");
}

Base b = new Derived();

b.VirtualMethod();   // "Derived.Virtual"  — runtime looks up Derived's vtable slot
b.ConcreteMethod();  // "Base.Concrete"    — no vtable, base-typed ref calls base version

Derived d = new Derived();
d.ConcreteMethod();  // "Derived.Concrete" — only reachable through Derived-typed ref
```

**Interface polymorphism — same dispatch, no inheritance required**
```csharp
public interface IExporter
{
    string Export(string[] data);
}

public class CsvExporter : IExporter
{
    public string Export(string[] data) => string.Join(",", data);
}

public class JsonExporter : IExporter
{
    public string Export(string[] data) =>
        "[" + string.Join(",", data.Select(d => $"\"{d}\"")) + "]";
}

// Polymorphism through interface — CsvExporter and JsonExporter are unrelated types
IExporter exporter = new JsonExporter();
Console.WriteLine(exporter.Export(new[] { "a", "b", "c" }));
// ["a","b","c"]
```

**Pattern matching — explicit type dispatch when polymorphism isn't available**
```csharp
// When you don't control the types and can't add virtual methods
public static double GetArea(object shape) => shape switch
{
    Circle c    => Math.PI * c.Radius * c.Radius,
    Rectangle r => r.Width * r.Height,
    _           => throw new ArgumentException("Unknown shape")
};

// This is the escape hatch — prefer true polymorphism when you own the types
```

---

## Gotchas

- **`new` looks like it overrides but it doesn't.** `public new void Method()` on a derived class compiles cleanly and appears to "replace" the base method — but through a base-typed reference, the base version always runs. This is hiding, not overriding, and is one of the most common sources of subtle runtime bugs in C# OOP code.
- **Casting to a derived type to call a non-virtual method defeats the purpose.** If you find yourself doing `if (obj is Dog d) d.Fetch()` everywhere, polymorphism hasn't been set up correctly. The virtual method should be on the base type.
- **Overloads are resolved at compile time, overrides at runtime.** If you have two overloads — `Process(Animal a)` and `Process(Dog d)` — calling `Process(animalRef)` where `animalRef` is actually a `Dog` will call `Process(Animal a)`. The compiler picks the overload based on the declared type, not the runtime type. This surprises people who confuse method overloading with polymorphism.
- **`sealed` on an override stops the chain unexpectedly.** If a mid-chain class seals an override, any further subclass can't override it again. If you're consuming a third-party library and wondering why your override isn't being called, check for `sealed` in the hierarchy.
- **Calling virtual methods in a constructor bypasses the intended initialization order.** The derived constructor hasn't run when the base constructor calls a virtual method. The override executes against a partially constructed object.

---

## Interview Angle
**What they're really testing:** Whether you understand how the runtime resolves method calls — the vtable mechanism — and whether you can distinguish compile-time from runtime dispatch.

**Common question form:** "What is polymorphism?" or "What's the difference between method overriding and method hiding?" or "What happens if you don't mark a method as virtual?"

**The depth signal:** A junior says "polymorphism means a subclass can override a method." A senior explains the vtable: `virtual` creates a dispatchable slot; `override` replaces that slot in the subclass's table; calling through a base reference looks up the runtime type's slot, not the declared type's. They'll contrast this with `new` (hiding, compile-time, breaks through a base reference) and with overloading (also compile-time, resolved by declared parameter type). A senior also knows that interface dispatch works the same way — each implementing type gets its own vtable entry for the interface method — and can explain why removing `virtual` from a base method silently breaks polymorphism without a compile error.

---

## Related Topics
- [[dotnet/csharp-inheritance.md]] — Polymorphism is inheritance's runtime payoff; `virtual` and `override` are set up there.
- [[dotnet/csharp-interfaces.md]] — Interface polymorphism works the same as class polymorphism but without an inheritance chain.
- [[dotnet/csharp-abstract-classes.md]] — Abstract methods are implicitly virtual; abstract classes exist specifically to enable polymorphic behavior.
- [[dotnet/csharp-pattern-matching.md]] — The explicit-type-dispatch escape hatch when true polymorphism isn't possible.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/polymorphism](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/polymorphism)

---
*Last updated: 2026-03-23*