# EF Core Owned Types

> Owned types are value objects in DDD terms — entity-like classes that don't have their own identity, always belong to a parent entity, and map to columns in the owner's table (or a separate table when explicitly configured).

---

## When To Use It

Use owned types for value objects that are logically part of an entity but are complex enough to warrant their own C# class: `Address`, `Money`, `DateRange`, `ContactInfo`, `GeoCoordinates`. They're the right model when the object has no meaning outside its owner — an `Address` on an `Order` isn't the same thing as an independent address with its own lifecycle. Don't use owned types when the object needs to be shared across multiple owners (e.g., a `Country` referenced by many entities), when it needs its own identity or FK relationships, or when it can exist without an owner. For those cases, use a regular entity with a proper FK relationship.

---

## Core Concept

An owned type is configured with `OwnsOne()` or `OwnsMany()` in Fluent API. EF Core treats the owned type as part of the owner's aggregate — it shares the owner's primary key and is loaded with the owner by default (no `Include()` needed). By default, owned type properties map to columns in the owner's table with a name prefix (`ShippingAddress_Street`, `ShippingAddress_City`). You can override this prefix, rename columns, or — from EF Core 7+ — map to a JSON column instead of individual columns. You can also push the owned type to its own table with `ToTable()`, which creates a one-to-one table relationship rather than embedding columns. EF Core 7+ adds `ToJson()`, which stores the entire owned object as a JSON column — the most compact and flexible option for complex value objects.

---

## The Code

**1. Basic OwnsOne — embedded in owner's table**
```csharp
// Value object — no Id, no DbSet, no own table by default
public class Address
{
    public string Street     { get; set; } = string.Empty;
    public string City       { get; set; } = string.Empty;
    public string PostalCode { get; set; } = string.Empty;
    public string Country    { get; set; } = string.Empty;
}

public class Order
{
    public int     Id              { get; set; }
    public decimal Total           { get; set; }
    public Address ShippingAddress { get; set; } = new();
    public Address BillingAddress  { get; set; } = new();
}

// Fluent API configuration
modelBuilder.Entity<Order>(entity =>
{
    entity.OwnsOne(o => o.ShippingAddress, addr =>
    {
        addr.Property(a => a.Street)    .HasMaxLength(200).IsRequired();
        addr.Property(a => a.City)      .HasMaxLength(100).IsRequired();
        addr.Property(a => a.PostalCode).HasMaxLength(20);
        addr.Property(a => a.Country)   .HasMaxLength(100).IsRequired();
        // Columns generated: ShippingAddress_Street, ShippingAddress_City, etc.
    });

    entity.OwnsOne(o => o.BillingAddress, addr =>
    {
        addr.Property(a => a.Street)    .HasMaxLength(200).IsRequired();
        addr.Property(a => a.City)      .HasMaxLength(100).IsRequired();
        addr.Property(a => a.PostalCode).HasMaxLength(20);
        addr.Property(a => a.Country)   .HasMaxLength(100).IsRequired();
        // Columns generated: BillingAddress_Street, BillingAddress_City, etc.
    });
});
```

**2. Overriding column names**
```csharp
entity.OwnsOne(o => o.ShippingAddress, addr =>
{
    addr.Property(a => a.Street)    .HasColumnName("Ship_Street");
    addr.Property(a => a.City)      .HasColumnName("Ship_City");
    addr.Property(a => a.PostalCode).HasColumnName("Ship_PostalCode");
    addr.Property(a => a.Country)   .HasColumnName("Ship_Country");
});
```

**3. OwnsOne in a separate table — table splitting**
```csharp
// Pushes owned type to its own table with a shared PK
entity.OwnsOne(o => o.ShippingAddress, addr =>
{
    addr.ToTable("OrderShippingAddresses"); // separate table, FK = Order.Id
    addr.Property(a => a.Street).HasMaxLength(200).IsRequired();
});

// OrderShippingAddresses table has OrderId (PK + FK) + Street, City, etc.
// Loaded via a JOIN — not embedded columns anymore
```

**4. OwnsMany — collection of owned value objects**
```csharp
public class Product
{
    public int               Id     { get; set; }
    public string            Name   { get; set; } = string.Empty;
    public List<ProductImage> Images { get; set; } = [];
}

public class ProductImage
{
    public string Url     { get; set; } = string.Empty;
    public string AltText { get; set; } = string.Empty;
    public int    SortOrder { get; set; }
}

modelBuilder.Entity<Product>().OwnsMany(p => p.Images, img =>
{
    img.ToTable("ProductImages");  // required for OwnsMany — can't be inline columns
    img.WithOwner().HasForeignKey("ProductId");
    img.Property<int>("Id").ValueGeneratedOnAdd(); // shadow PK for the owned table
    img.HasKey("Id");
    img.Property(i => i.Url).HasMaxLength(500).IsRequired();
    img.Property(i => i.AltText).HasMaxLength(200);
});
```

**5. JSON columns — EF Core 7+**
```csharp
// Stores the entire owned type as a JSON column — single column, any depth
public class Customer
{
    public int         Id           { get; set; }
    public string      Name         { get; set; } = string.Empty;
    public ContactInfo ContactInfo  { get; set; } = new(); // complex nested object
}

public class ContactInfo
{
    public string         Email   { get; set; } = string.Empty;
    public string?        Phone   { get; set; }
    public List<string>   Tags    { get; set; } = [];
    public Address        Address { get; set; } = new();
}

// Configure as JSON column — requires EF Core 7+ and a compatible provider
modelBuilder.Entity<Customer>().OwnsOne(c => c.ContactInfo, ci =>
{
    ci.ToJson(); // stored as: {"Email":"...","Phone":"...","Address":{...}}
    ci.OwnsOne(c => c.Address); // nested owned types work inside JSON
});

// EF Core 8+ — querying into JSON properties works in LINQ
var customers = await context.Customers
    .Where(c => c.ContactInfo.Address.City == "Cairo")
    .ToListAsync();
// Generates: WHERE JSON_VALUE(ContactInfo, '$.Address.City') = 'Cairo'
```

**6. Querying owned types — no Include() needed**
```csharp
// Owned types load with the owner automatically — no Include()
var orders = await context.Orders
    .AsNoTracking()
    .Where(o => o.ShippingAddress.City == "Cairo")
    .ToListAsync();

// Orders includes ShippingAddress columns in the SELECT — they're part of the owner row
// Access: orders[0].ShippingAddress.Street

// Filtering on owned type properties works in LINQ
var cairoOrders = await context.Orders
    .Where(o => o.ShippingAddress.City == "Cairo"
             && o.ShippingAddress.Country == "Egypt")
    .ToListAsync();
```

**7. Null handling — optional owned types**
```csharp
// If ShippingAddress might not exist (all columns nullable), configure it
entity.OwnsOne(o => o.ShippingAddress, addr =>
{
    addr.Property(a => a.Street).IsRequired(false);
    addr.Property(a => a.City).IsRequired(false);
});

// In code — EF Core creates an owned instance if all columns are null
// The navigation property will be null if all columns are null (EF Core 8+)
// In EF Core 7 and earlier, it was always a non-null instance even with all-null columns
if (order.ShippingAddress is not null)
{
    Console.WriteLine(order.ShippingAddress.City);
}
```

---

## Gotchas

- **Owned types are always loaded with the owner — there's no lazy loading option.** Every query that loads an `Order` will also select all `ShippingAddress` and `BillingAddress` columns, even if you never access them. For wide owned types with many columns, this is a meaningful over-fetch. Use `ToTable()` to push the owned type to a separate table if you want to control when it's loaded via `Include()`.
- **Switching from `OwnsOne` (embedded) to `HasOne` (separate FK relationship) is a breaking migration.** The embedded columns are dropped and a new table with a FK is created. You lose data unless you manually write a data migration. Plan your ownership boundary carefully before the first production migration ships.
- **`OwnsMany` requires `ToTable()` — it cannot be stored as embedded columns.** Unlike `OwnsOne`, a collection of owned types cannot be inlined as columns in the owner's table. EF requires a separate table with a FK back to the owner. The table needs a primary key, which is usually a shadow property.
- **JSON columns (`ToJson()`) require the database to support JSON column types.** SQL Server 2016+ supports this via `nvarchar(max)` with JSON functions. PostgreSQL uses `jsonb`. Older SQL Server versions or providers without JSON support will throw at migration time. JSON columns also can't be used in indexed filters on SQL Server (no computed column index on JSON paths in EF Core).
- **`HasData()` seeding with owned types requires explicit FK values.** You can't use the navigation property in `HasData()` for owned types — you must seed the owned properties as anonymous objects with the owner's FK. See the seeding file for the pattern.
- **Owned types don't have their own `DbSet<T>`.** You cannot query an owned type directly (`context.Addresses` doesn't exist). All access is through the owner. If you find yourself wanting to query the owned type independently, it's a signal it shouldn't be an owned type — it needs its own entity.

---

## Interview Angle

**What they're really testing:** Whether you understand the DDD value object concept and when embedding vs separate table vs JSON column is the right choice.

**Common question form:** *"How would you model an `Address` that belongs to an `Order`?"* or *"What's the difference between an owned type and a regular entity in EF Core?"*

**The depth signal:** A junior answer describes `OwnsOne()` and says the columns go in the owner's table. A senior answer explains that owned types are value objects (no identity, always part of an aggregate), the trade-off between inline columns (always loaded, no Include needed) vs `ToTable()` (separate JOIN, loadable on demand) vs `ToJson()` (single column, flexible schema, JSON query support in EF Core 8+), why you can't query owned types independently, why `OwnsMany` always needs a table, and the migration cost of changing the ownership strategy once it's shipped to production.

---

## Related Topics

- [[dotnet/ef/ef-fluent-api.md]] — `OwnsOne`/`OwnsMany` and `ToJson()` are Fluent API–only configurations; owned type setup lives entirely in `OnModelCreating`.
- [[dotnet/ef/ef-relationships.md]] — Understanding the difference between `OwnsOne` (value object, embedded) and `HasOne`/`WithOne` (entity with its own identity and FK) is the core distinction.
- [[dotnet/ef/ef-migrations.md]] — Owned type configuration changes produce migrations; switching from embedded to table-per-type generates a breaking migration that drops columns and creates a new table.
- [[dotnet/ef/ef-seeding.md]] — Seeding owned types with `HasData()` has specific syntax requirements (anonymous objects with explicit FK properties).

---

## Source

https://learn.microsoft.com/en-us/ef/core/modeling/owned-entities

---
*Last updated: 2026-04-08*