# C# Enums

> A named set of integer constants that lets you replace magic numbers with readable labels, with optional bitwise flag support for representing combinations of values.

---

## When To Use It
Use enums any time you have a fixed, known set of related values — order status, directions, days of the week, permission levels. They make code self-documenting and give you compile-time safety against passing an arbitrary integer where a specific value is expected. Don't use enums for open-ended sets that grow over time (like country codes or product categories stored in a database) — those belong in a lookup table. Don't use a plain enum when you need behaviour attached to each value; use a class hierarchy or a discriminated union pattern instead.

---

## Core Concept
An enum is just a thin wrapper around an integer. When you write `Status.Active`, the compiler treats it as the integer `1` (or whatever you assigned) under the hood. This means enums cast freely to and from `int`, which is convenient but dangerous — you can cast any integer to any enum, even one with no defined member, and it won't throw. The `[Flags]` attribute turns a regular enum into a bitmask enum where each member represents a single bit, and you combine them with `|` and test them with `&`. Without `[Flags]`, combining values with `|` still works mechanically, but `.ToString()` and `Enum.HasFlag()` won't interpret the result correctly.

---

## The Code

**Basic enum declaration and usage**
```csharp
public enum OrderStatus
{
    Pending,      // 0 — starts at 0 by default
    Processing,   // 1
    Shipped,      // 2
    Delivered,    // 3
    Cancelled     // 4
}

OrderStatus status = OrderStatus.Processing;

Console.WriteLine(status);          // "Processing" — ToString() gives the name
Console.WriteLine((int)status);     // 1 — cast to underlying type
Console.WriteLine(status == OrderStatus.Processing);  // true

// Switch on enum — compiler warns if you miss a case
string label = status switch
{
    OrderStatus.Pending     => "Awaiting payment",
    OrderStatus.Processing  => "Being prepared",
    OrderStatus.Shipped     => "On the way",
    OrderStatus.Delivered   => "Complete",
    OrderStatus.Cancelled   => "Cancelled",
    _                       => "Unknown"
};
```

**Explicit values and non-default underlying type**
```csharp
public enum HttpStatusCode : int   // underlying type is int by default, but explicit is clearer
{
    Ok          = 200,
    NotFound    = 404,
    ServerError = 500
}

// Underlying type can be byte, short, int, long (not float, not string)
public enum Priority : byte
{
    Low    = 1,
    Medium = 2,
    High   = 3
}

HttpStatusCode code = HttpStatusCode.NotFound;
Console.WriteLine((int)code);    // 404
```

**Parsing and converting**
```csharp
// int to enum — always succeeds, even for undefined values
OrderStatus s1 = (OrderStatus)2;           // Shipped
OrderStatus s2 = (OrderStatus)99;          // 99 — no exception, no defined name

// string to enum
OrderStatus parsed = Enum.Parse<OrderStatus>("Shipped");       // throws on invalid
bool ok = Enum.TryParse<OrderStatus>("Shipped", out var s3);   // safe — use this

// Case-insensitive parse
Enum.TryParse<OrderStatus>("shipped", ignoreCase: true, out var s4);

// Check if value is defined before trusting a cast from external input
bool isDefined = Enum.IsDefined(typeof(OrderStatus), 99);   // false
bool isDefined2 = Enum.IsDefined<OrderStatus>(2);           // true (Shipped)

// Enum to string
string name = OrderStatus.Shipped.ToString();               // "Shipped"
string name2 = Enum.GetName(typeof(OrderStatus), 2);        // "Shipped"
```

**[Flags] enum: bitmask for combining values**
```csharp
[Flags]
public enum Permissions
{
    None    = 0,
    Read    = 1,    // 0001
    Write   = 2,    // 0010
    Delete  = 4,    // 0100
    Admin   = 8,    // 1000
    // Convenience composite
    ReadWrite = Read | Write   // 0011 = 3
}

Permissions p = Permissions.Read | Permissions.Write;

// Test for a flag
bool canRead   = p.HasFlag(Permissions.Read);    // true
bool canDelete = p.HasFlag(Permissions.Delete);  // false

// Manual bit test — equivalent, slightly faster in hot paths
bool canWrite = (p & Permissions.Write) != 0;   // true

// Add a flag
p |= Permissions.Delete;

// Remove a flag
p &= ~Permissions.Write;

// ToString on [Flags] combines names
Console.WriteLine(p);   // "Read, Delete" — comma-separated list of set flags
```

**Iterating enum values**
```csharp
// Get all defined values
foreach (OrderStatus status in Enum.GetValues<OrderStatus>())
    Console.WriteLine(status);

// Get all names
foreach (string name in Enum.GetNames<OrderStatus>())
    Console.WriteLine(name);
```

**Attaching data to enum values via attributes**
```csharp
public enum OrderStatus
{
    [Description("Awaiting payment")]
    Pending,

    [Description("Being prepared for shipment")]
    Processing,

    [Description("On the way")]
    Shipped
}

// Helper to read the Description attribute
public static string GetDescription(this Enum value)
{
    return value.GetType()
        .GetField(value.ToString())
        ?.GetCustomAttribute<DescriptionAttribute>()
        ?.Description ?? value.ToString();
}

Console.WriteLine(OrderStatus.Pending.GetDescription());  // "Awaiting payment"
```

---

## Gotchas

- **Casting any integer to an enum never throws, even for undefined values.** `(OrderStatus)999` compiles, runs, and gives you a valid variable that has no name and isn't equal to any defined member. If you're receiving enum values from external sources (API payloads, database columns), always call `Enum.IsDefined` before trusting the cast — otherwise undefined integers flow silently through your system and produce bizarre switch fall-throughs.
- **`[Flags]` enums must use powers of 2 or they break bitwise operations.** If you define `Read = 1, Write = 2, Execute = 3`, then `Read | Write = 3 = Execute`, and `HasFlag(Execute)` on a `Read|Write` value returns true incorrectly. Every standalone flag must be a unique bit: 1, 2, 4, 8, 16. The compiler won't warn you if you get this wrong.
- **`Enum.HasFlag` boxes its argument and is slightly slow.** For flags checked in tight loops, `(p & Permissions.Read) != 0` is faster. `HasFlag` is readable and fine for most code, but in performance-sensitive paths, use the bitwise form.
- **`enum` without `[Flags]` still lets you combine values with `|`, but `.ToString()` won't give you named output.** `OrderStatus.Pending | OrderStatus.Shipped` compiles and gives you `(OrderStatus)2` — which happens to be `Shipped` — with no indication that a combination was intended. If combining values is the intent, always add `[Flags]` so the semantics are explicit.
- **Enums are not safe to use as API contracts without explicit values assigned.** If you add a new member to an enum and it shifts the integer values of existing members (because you inserted it in the middle without explicit numbers), any serialised data or database values using the old integers will now map to the wrong members. Always assign explicit integer values to any enum that leaves your process boundary — serialised to JSON, stored in a DB, sent over a queue.

---

## Interview Angle
**What they're really testing:** Whether you understand the underlying integer representation and the safety gaps that come from it — and whether you know the `[Flags]` pattern for bitmask operations.

**Common question form:** "What is an enum in C#?" / "How do you represent a combination of values, like multiple permissions?" / "What happens when you cast an integer to an enum?"

**The depth signal:** A junior defines enums as named constants and knows `[Flags]` exists. A senior explains that enums are bare integers under the hood — casting any int succeeds at runtime regardless of whether it maps to a defined member — and flags the serialisation trap: enums stored or transmitted without explicit values are a versioning time bomb the moment you insert a new member. They also know the `[Flags]` power-of-2 requirement is a correctness constraint, not a convention, and can explain why an enum without it produces silent bugs rather than exceptions.

---

## Related Topics
- [[dotnet/csharp-operators.md]] — Bitwise operators (`|`, `&`, `~`, `^`) are the mechanics behind `[Flags]` enum combination and testing; understanding them is a prerequisite
- [[dotnet/csharp-pattern-matching.md]] — Switch expressions on enums benefit from exhaustiveness checking; patterns and enums pair naturally for state machine logic
- [[dotnet/csharp-attributes.md]] — Attaching metadata like `[Description]` or `[EnumMember]` to enum values is the standard way to associate display strings or serialisation names without a separate lookup
- [[databases/sql-lookup-tables.md]] — The decision between an enum and a database lookup table is a common design question; they solve the same problem at different layers

---

## Source
[Enumeration types — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/enum)

---
*Last updated: 2026-03-23*