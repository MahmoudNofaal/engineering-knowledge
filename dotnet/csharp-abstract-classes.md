# C# Abstract Classes

> An abstract class is a base class that can't be instantiated directly — it exists to be inherited from, and it can enforce that subclasses implement specific members.

---

## When To Use It
Use an abstract class when you have a family of related types that share real implementation but also have behavior that each subclass must define for itself. The sweet spot is: common state + common code + enforced contract. Don't use it when you have no shared implementation to offer — that's what interfaces are for. Also don't use it when the types aren't genuinely related in an is-a sense; two classes forced into an abstract hierarchy just to share a method is a composition problem wearing inheritance clothes.

---

## Core Concept
An abstract class sits between a fully concrete class and an interface. It can have fields, constructors, real method implementations, and properties — just like a normal class. But it can also declare `abstract` members that have no body, forcing every subclass to provide their own version. Because it can't be instantiated, it can only ever exist as the base of something else. Think of it as a template with some blanks that subclasses must fill in. The distinction from an interface is that an abstract class can carry state and implemented behavior; an interface is a pure contract with no storage.

---

## The Code

**Abstract class with mixed concrete and abstract members**
```csharp
public abstract class Report
{
    // Concrete state — shared by all subclasses
    public string Title { get; }
    public DateTime GeneratedAt { get; } = DateTime.UtcNow;

    protected Report(string title)
    {
        Title = title;
    }

    // Abstract — each subclass must implement this
    public abstract string GenerateContent();

    // Concrete — shared implementation every subclass gets
    public void Print()
    {
        Console.WriteLine($"=== {Title} ===");
        Console.WriteLine(GeneratedAt);
        Console.WriteLine(GenerateContent());
    }
}

public class SalesReport : Report
{
    private readonly decimal _revenue;

    public SalesReport(decimal revenue) : base("Sales Report")
    {
        _revenue = revenue;
    }

    public override string GenerateContent() =>
        $"Total Revenue: {_revenue:C}";
}

public class InventoryReport : Report
{
    private readonly int _itemCount;

    public InventoryReport(int itemCount) : base("Inventory Report")
    {
        _itemCount = itemCount;
    }

    public override string GenerateContent() =>
        $"Items in stock: {_itemCount}";
}

// Report r = new Report("x"); — compile error, can't instantiate
Report r = new SalesReport(49_999.99m);
r.Print();
```

**Template Method pattern — the natural fit for abstract classes**
```csharp
public abstract class DataImporter
{
    // Template method — defines the algorithm skeleton
    public void Import(string source)
    {
        var raw = ReadData(source);    // step 1: subclass handles this
        var clean = Validate(raw);     // step 2: shared logic
        Save(clean);                   // step 3: subclass handles this
    }

    protected abstract string[] ReadData(string source);
    protected abstract void Save(string[] data);

    // Shared concrete step — subclasses don't need to touch this
    private string[] Validate(string[] raw) =>
        Array.FindAll(raw, s => !string.IsNullOrWhiteSpace(s));
}

public class CsvImporter : DataImporter
{
    protected override string[] ReadData(string source) =>
        File.ReadAllLines(source);

    protected override void Save(string[] data) =>
        Console.WriteLine($"Saving {data.Length} CSV rows");
}
```

**Abstract class implementing an interface — partial implementation pattern**
```csharp
public interface IShape
{
    double Area();
    double Perimeter();
    void Describe();
}

// Abstract class implements part of the interface
// Subclasses only need to fill in Area() and Perimeter()
public abstract class Shape : IShape
{
    public abstract double Area();
    public abstract double Perimeter();

    // Concrete — no subclass needs to rewrite this
    public void Describe() =>
        Console.WriteLine($"Area: {Area():F2}, Perimeter: {Perimeter():F2}");
}

public class Rectangle : Shape
{
    private double _w, _h;
    public Rectangle(double w, double h) => (_w, _h) = (w, h);

    public override double Area() => _w * _h;
    public override double Perimeter() => 2 * (_w + _h);
}
```

---

## Gotchas

- **Abstract classes still have constructors — and subclasses must call them.** The constructor runs when a subclass is instantiated via `: base(...)`. If you add a required parameter to the abstract constructor later, every subclass breaks. Design the constructor signature carefully upfront.
- **You can't add a new abstract member without breaking all existing subclasses.** Unlike a default interface method, a new `abstract` member in a base class is a compile error for every class that inherits it but doesn't implement it. This makes abstract classes brittle to extend in a published library.
- **`abstract override` is valid and often forgotten.** A class can inherit a virtual method and re-declare it as `abstract`, forcing its own subclasses to implement it fresh. Useful but rarely intuitive the first time you see it.
- **Protected constructors are the right default.** An abstract class constructor should almost always be `protected`, not `public`. A `public` constructor on an abstract class is misleading — nothing outside can call it directly anyway.
- **Abstract class + interface is a deliberate pattern, not redundancy.** Having an abstract class implement an interface lets you enforce the contract externally (via the interface) while providing a partial default implementation internally. Don't collapse one into the other just to reduce type count.

---

## Interview Angle
**What they're really testing:** Whether you can articulate the concrete trade-offs between abstract classes and interfaces, and whether you know which design problems each one solves.

**Common question form:** "What's the difference between an abstract class and an interface?" or "When would you use one over the other?"

**The depth signal:** A junior recites "abstract classes can have implementation, interfaces can't." A senior gives the design-level answer: abstract classes model an is-a hierarchy with shared state and behavior — they're appropriate when subclasses are genuinely variants of the same thing. Interfaces model a can-do capability contract across unrelated types. They'll note that C# 8 default interface methods blur the line technically, but the design intent remains distinct. A senior will also name the Template Method pattern unprompted, because it's the canonical use case that abstract classes are built for — and they'll mention that adding abstract members to a published abstract class is a breaking change, while adding default members to an interface is not.

---

## Related Topics
- [[dotnet/csharp-interfaces.md]] — The primary comparison point; interfaces are the alternative when you don't need shared state or implementation.
- [[dotnet/csharp-inheritance.md]] — Abstract classes are a form of inheritance; virtual dispatch and `override` mechanics apply here too.
- [[dotnet/csharp-classes.md]] — Concrete class anatomy is the prerequisite; abstract classes extend it with abstract members and no instantiation.
- [[dotnet/interfaces-abstract-classes.md]] — Direct side-by-side decision guide for picking the right abstraction tool.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/abstract](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/abstract)

---
*Last updated: 2026-03-23*