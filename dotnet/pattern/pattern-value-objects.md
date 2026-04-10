# Value Object

> A value object is an immutable type defined entirely by its data — two value objects with the same data are equal, regardless of identity.

---

## When To Use It

Use it when a concept in your domain is defined by its content rather than its identity — money, email addresses, phone numbers, coordinates, date ranges, measurement units. The signal is primitive obsession: when you're passing `decimal amount` and `string currency` as separate parameters everywhere, or validating the same email regex in five different places, you have a value object waiting to be born. Don't use it for things with identity that persist independently — entities like `Order` or `Customer` have an ID and a lifecycle; value objects don't.

---

## Core Concept

**One sentence for the interview:** A value object has no identity — it is its data, it's immutable, and two instances with the same values are equal.

Three rules define a value object. First: **no identity** — a `Money(100, "USD")` isn't tracked by ID; it just is what it is. Second: **immutability** — you don't change a value object, you create a new one. You don't set `money.Amount = 200`; you create `new Money(200, "USD")`. Third: **structural equality** — two `Money` objects with the same amount and currency are equal, even if they're different instances. In C#, `record` types give you structural equality and immutability for free — they're the natural implementation for value objects. The deeper benefit is replacing primitive obsession: instead of `void Charge(decimal amount, string currency)` accepting any decimal and any string, `void Charge(Money amount)` encapsulates the validation and invariants in one place.

---

## The Code

```csharp
// 1. Simple value object using C# record — structural equality for free
public record Money(decimal Amount, string Currency)
{
    // Validation in the constructor — the object is always valid or never created
    public Money(decimal amount, string currency) : this(amount, currency.ToUpperInvariant())
    {
        if (amount < 0) throw new ArgumentException("Amount cannot be negative.", nameof(amount));
        if (string.IsNullOrWhiteSpace(currency)) throw new ArgumentException("Currency is required.", nameof(currency));
        if (currency.Length != 3) throw new ArgumentException("Currency must be a 3-letter ISO code.", nameof(currency));
    }

    // Domain behavior lives on the value object — not in a service
    public Money Add(Money other)
    {
        if (Currency != other.Currency)
            throw new InvalidOperationException($"Cannot add {Currency} and {other.Currency}.");
        return new Money(Amount + other.Amount, Currency);
    }

    public Money Subtract(Money other)
    {
        if (Currency != other.Currency)
            throw new InvalidOperationException($"Cannot subtract different currencies.");
        return new Money(Amount - other.Amount, Currency);
    }

    public Money Multiply(decimal factor) => new(Amount * factor, Currency);

    public bool IsGreaterThan(Money other)
    {
        if (Currency != other.Currency)
            throw new InvalidOperationException("Cannot compare different currencies.");
        return Amount > other.Amount;
    }

    public static Money Zero(string currency) => new(0, currency);

    public override string ToString() => $"{Amount:F2} {Currency}";
}

// Usage — structural equality means this works correctly
var price = new Money(100, "USD");
var tax   = new Money(10, "USD");
var total = price.Add(tax);           // new Money(110, "USD")

var a = new Money(100, "USD");
var b = new Money(100, "USD");
Console.WriteLine(a == b);            // true — records use structural equality by default
```

```csharp
// 2. Email address — a classic value object that encapsulates validation
public record EmailAddress
{
    private static readonly Regex _pattern =
        new(@"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.Compiled);

    public string Value { get; }

    public EmailAddress(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new ArgumentException("Email address cannot be empty.");
        if (!_pattern.IsMatch(value))
            throw new ArgumentException($"'{value}' is not a valid email address.");

        Value = value.ToLowerInvariant().Trim();
    }

    public static implicit operator string(EmailAddress email) => email.Value;
    public static explicit operator EmailAddress(string value) => new(value);

    public override string ToString() => Value;
}

// Usage
var email = new EmailAddress("  Alice@Example.COM  ");
Console.WriteLine(email);             // "alice@example.com" — normalized on creation
```

```csharp
// 3. Date range — value object with meaningful behavior
public record DateRange
{
    public DateTime Start { get; }
    public DateTime End { get; }
    public int DurationDays => (End - Start).Days;

    public DateRange(DateTime start, DateTime end)
    {
        if (end <= start) throw new ArgumentException("End must be after start.");
        Start = start.Date;  // strip time component — this is a date range, not datetime range
        End = end.Date;
    }

    public bool Overlaps(DateRange other) =>
        Start < other.End && End > other.Start;

    public bool Contains(DateTime date) =>
        date.Date >= Start && date.Date <= End;

    public DateRange ExtendBy(int days) =>
        new(Start, End.AddDays(days));

    public static DateRange ThisMonth()
    {
        var now = DateTime.UtcNow;
        return new DateRange(
            new DateTime(now.Year, now.Month, 1),
            new DateTime(now.Year, now.Month, DateTime.DaysInMonth(now.Year, now.Month)));
    }
}
```

```csharp
// 4. EF Core — persisting value objects as owned entities
public class Order
{
    public int Id { get; private set; }
    public Money Price { get; private set; } = null!;     // value object, not an entity
    public EmailAddress CustomerEmail { get; private set; } = null!;
    public Address ShippingAddress { get; private set; } = null!;
}

public class Address
{
    public string Street { get; init; } = default!;
    public string City { get; init; } = default!;
    public string PostalCode { get; init; } = default!;
    public string Country { get; init; } = default!;
}

// EF Core configuration — owned entity maps value object properties to columns on the owner's table
protected override void OnModelCreating(ModelBuilder mb)
{
    mb.Entity<Order>(e =>
    {
        // Money maps to two columns: Price_Amount and Price_Currency
        e.OwnsOne(o => o.Price, price =>
        {
            price.Property(m => m.Amount).HasColumnName("Price_Amount").HasPrecision(18, 2);
            price.Property(m => m.Currency).HasColumnName("Price_Currency").HasMaxLength(3);
        });

        // EmailAddress maps to a single column
        e.Property(o => o.CustomerEmail)
            .HasConversion(
                email => email.Value,                           // to DB: string
                value => new EmailAddress(value))               // from DB: validate and wrap
            .HasMaxLength(256);

        // Address maps to columns on the Orders table — no separate table
        e.OwnsOne(o => o.ShippingAddress, addr =>
        {
            addr.Property(a => a.Street).HasMaxLength(200);
            addr.Property(a => a.City).HasMaxLength(100);
            addr.Property(a => a.PostalCode).HasMaxLength(20);
            addr.Property(a => a.Country).HasMaxLength(2);
        });
    });
}
```

```csharp
// 5. Value object with collection equality — when the record default isn't enough
// record struct for stack-allocated small value objects
public readonly record struct Coordinate(double Latitude, double Longitude)
{
    public Coordinate(double latitude, double longitude)
        : this(Math.Round(latitude, 6), Math.Round(longitude, 6))
    {
        if (latitude is < -90 or > 90) throw new ArgumentOutOfRangeException(nameof(latitude));
        if (longitude is < -180 or > 180) throw new ArgumentOutOfRangeException(nameof(longitude));
    }

    public double DistanceTo(Coordinate other)
    {
        // Haversine formula — simplified
        const double R = 6371;
        var dLat = (other.Latitude - Latitude) * Math.PI / 180;
        var dLon = (other.Longitude - Longitude) * Math.PI / 180;
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(Latitude * Math.PI / 180) * Math.Cos(other.Latitude * Math.PI / 180) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        return R * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }
}
```

```csharp
// 6. The anti-pattern — primitive obsession — and the fix
// BAD: passing primitives that belong together everywhere
public void PlaceOrder(int customerId, decimal amount, string currency,
    string street, string city, string postalCode, string country,
    string email) { }

// GOOD: value objects make the intent clear and validation centralized
public void PlaceOrder(
    int customerId,
    Money price,
    Address shippingAddress,
    EmailAddress customerEmail) { }
```

---

## Gotchas

- **C# `record` gives structural equality for simple properties, but not for collections.** If a value object contains a `List<T>`, two records with identical list contents will not be equal by default — `record` uses reference equality for collections. Override `Equals` and `GetHashCode` explicitly, or use `ImmutableArray<T>` which has value semantics.

- **EF Core's `OwnsOne()` maps the value object as columns on the owning entity's table — no separate table.** This means the value object's properties can't be null in the database unless you configure them as optional owned entities. If the value object is optional (order may have no shipping address until confirmed), use `OwnsOne` with a null check in the mapping.

- **EF Core `HasConversion()` bypasses your constructor validation on reads.** When EF reads a row and converts the column value back to your value object (e.g., `new EmailAddress(value)`), the constructor runs — including your validation. If legacy data in the database doesn't meet the current validation rules, reads will throw. Either loosen the constructor or add a static `TryCreate()` factory.

- **Mutable "value objects" are just entities without an ID.** If you add setters to your value object, it's no longer immutable, and structural equality breaks: two instances can look the same initially but diverge. The `init`-only properties on records enforce immutability at the property level — use them.

- **Value objects in domain methods should return new instances, not mutate.** `money.Add(other)` returns `new Money(...)`. If you find yourself writing `money.Amount += 10`, you've made it mutable. All operations on a value object produce a new value object.

- **Don't map value objects as entities in EF.** If you give `Money` its own table with a primary key, it becomes an entity — you've introduced identity where there should be none. Value objects live as columns on their owning entity's table (via `OwnsOne`) or as JSON columns, not as rows in their own table.

---

## Interview Angle

**What they're really testing:** Whether you understand the DDD building blocks — specifically the entity vs value object distinction — and can connect it to concrete C# implementation.

**Common question form:** *"What is a value object?"* or *"What is primitive obsession and how do you fix it?"* or *"How do you persist a value object with EF Core?"*

**The depth signal:** A junior says "it's an object defined by its value, not its identity." A senior gives the three rules (no identity, immutable, structural equality), names `record` as the natural C# implementation, describes `OwnsOne` for EF persistence, and connects value objects to primitive obsession — replacing `(decimal, string)` pairs with `Money` so validation is centralized and domain behavior lives on the type itself.

**Follow-up the interviewer asks next:** *"What's the difference between an entity and a value object?"*

An entity has identity — two orders with different IDs are different orders, even if every other property is identical. An entity persists across time and can change state while remaining "the same thing." A value object has no identity — two `Money(100, "USD")` instances are identical; swapping one for the other changes nothing. A value object doesn't change; you replace it with a new instance. In EF: entities get their own table with a primary key and are tracked by identity. Value objects are mapped as owned properties (columns on the owner's table) or via value converters — no primary key, no independent lifecycle.

---

## Related Topics

- [[dotnet/pattern/pattern-domain-events.md]] — Domain events carry value object data (not entity references) to describe what changed; understanding value objects clarifies why events are designed this way.
- [[dotnet/pattern/pattern-specification.md]] — Specifications that filter on value object properties must use EF-compatible expression trees; the owned entity mapping determines what's queryable.
- [[dotnet/ef/ef-dbcontext.md]] — `OwnsOne()` and `HasConversion()` are the two EF Core mechanisms for mapping value objects; both have important limitations around nullability and querying.
- [[dotnet/pattern/pattern-result.md]] — `Result<T>` is itself a value object — it holds a success value or error description, has no identity, and is immutable.

---

## Source

https://martinfowler.com/bliki/ValueObject.html

---

*Last updated: 2026-04-09*