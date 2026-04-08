# EF Core Fluent API

> The method-chaining configuration system in `OnModelCreating` that tells EF Core exactly how to map your C# entity classes to database tables, columns, constraints, and relationships — without touching the entity classes themselves.

---

## When To Use It

Use Fluent API whenever data annotations aren't expressive enough — composite keys, table splitting, owned types, delete behaviour, column types, unique indexes, value converters, and any relationship with non-obvious foreign keys all require it. Prefer Fluent API over data annotations for anything beyond basic `[Required]` and `[MaxLength]` — it keeps entity classes free of infrastructure concerns and centralises all schema decisions in one place. Don't mix both heavily for the same property; when Fluent API and a data annotation conflict, Fluent API wins, which creates confusing double-configuration.

---

## Core Concept

Fluent API lives entirely in `DbContext.OnModelCreating(ModelBuilder modelBuilder)`. You call `modelBuilder.Entity<T>()` to get a builder for an entity, then chain methods to describe its table name, primary key, column types, required/optional constraints, indexes, and relationships. Nothing here runs at runtime — it's all read once at startup to build EF Core's internal model, which then drives both query generation and migration output. Whatever you configure here overrides conventions and annotations — this makes it the right place for production-critical decisions like delete behaviour, decimal precision, value converters, and JSON column mapping.

---

## The Code

**1. Table and column configuration**
```csharp
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<Product>(entity =>
    {
        entity.ToTable("Products", schema: "catalogue");
        entity.HasKey(p => p.Id);

        entity.Property(p => p.Name)
              .IsRequired()
              .HasMaxLength(200)
              .HasColumnName("ProductName");

        // decimal precision must always be set — default varies by provider
        entity.Property(p => p.Price)
              .HasColumnType("decimal(18,2)")
              .HasDefaultValue(0m);

        entity.Property(p => p.CreatedAt)
              .HasDefaultValueSql("GETUTCDATE()")
              .ValueGeneratedOnAdd();

        entity.Property(p => p.RowVersion)
              .IsRowVersion(); // optimistic concurrency token
    });
}
```

**2. Composite primary key**
```csharp
modelBuilder.Entity<OrderItem>(entity =>
{
    entity.HasKey(oi => new { oi.OrderId, oi.ProductId });
    entity.Property(oi => oi.Quantity).IsRequired();
    entity.Property(oi => oi.UnitPrice).HasColumnType("decimal(18,2)");
});
```

**3. Relationships**
```csharp
// One-to-many
modelBuilder.Entity<OrderItem>(entity =>
{
    entity.HasOne(oi => oi.Order)
          .WithMany(o => o.Items)
          .HasForeignKey(oi => oi.OrderId)
          .OnDelete(DeleteBehavior.Cascade);

    entity.HasOne(oi => oi.Product)
          .WithMany()
          .HasForeignKey(oi => oi.ProductId)
          .OnDelete(DeleteBehavior.Restrict);
});

// Many-to-many (EF Core 5+)
modelBuilder.Entity<Student>()
    .HasMany(s => s.Courses)
    .WithMany(c => c.Students)
    .UsingEntity(j => j.ToTable("StudentCourses"));

// One-to-one
modelBuilder.Entity<User>()
    .HasOne(u => u.Profile)
    .WithOne(p => p.User)
    .HasForeignKey<UserProfile>(p => p.UserId)
    .OnDelete(DeleteBehavior.Cascade);
```

**4. Indexes and unique constraints**
```csharp
modelBuilder.Entity<Product>(entity =>
{
    entity.HasIndex(p => p.CategoryId);                  // simple index

    entity.HasIndex(p => p.Sku)
          .IsUnique()
          .HasDatabaseName("IX_Products_Sku");          // unique index

    entity.HasIndex(p => new { p.Name, p.CategoryId })
          .IsUnique();                                   // composite unique

    entity.HasIndex(p => p.Name)
          .HasFilter("[IsActive] = 1");                  // filtered index (SQL Server)
});
```

**5. Value converters — transform how a property is stored**
```csharp
// Enum stored as string in the database — readable in DB tools, survives reordering
modelBuilder.Entity<Order>()
    .Property(o => o.Status)
    .HasConversion<string>()            // stores "Pending", "Confirmed", "Shipped"
    .HasMaxLength(50);

// Custom converter — store a strongly-typed value object as a primitive
public record ProductCode(string Value);

modelBuilder.Entity<Product>()
    .Property(p => p.Code)
    .HasConversion(
        code => code.Value,             // C# → DB: extract the string
        value => new ProductCode(value) // DB → C#: reconstruct the value object
    )
    .HasMaxLength(20);

// Encrypted column — store sensitive data encrypted, decrypt on read
modelBuilder.Entity<Customer>()
    .Property(c => c.TaxId)
    .HasConversion(
        plain  => EncryptionService.Encrypt(plain),
        cipher => EncryptionService.Decrypt(cipher)
    );

// Global value converter — apply to every property of a type across all entities
// Useful for applying value object pattern uniformly
modelBuilder.Properties<ProductCode>()
    .HaveConversion<ProductCodeConverter>(); // custom IValueConverter<ProductCode, string>
```

**6. JSON columns — EF Core 7+**
```csharp
// Stores owned type as a single JSON column — great for complex value objects
public class Customer
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public ContactInfo ContactInfo { get; set; } = new();
}

public class ContactInfo
{
    public string         Email   { get; set; } = string.Empty;
    public string?        Phone   { get; set; }
    public List<string>   Tags    { get; set; } = [];
}

modelBuilder.Entity<Customer>().OwnsOne(c => c.ContactInfo, ci =>
{
    ci.ToJson(); // stored as: {"Email":"...","Phone":"...","Tags":["vip","retail"]}
});

// EF Core 8+ — query into JSON properties
var customers = await context.Customers
    .Where(c => c.ContactInfo.Email.Contains("@example.com"))
    .ToListAsync();
// Generates: WHERE JSON_VALUE(ContactInfo, '$.Email') LIKE '%@example.com%'
```

**7. Inheritance — TPH, TPT, TPC**
```csharp
// TPH (default) — single table with discriminator column
modelBuilder.Entity<Animal>(entity =>
{
    entity.HasDiscriminator<string>("AnimalType")
          .HasValue<Dog>("Dog")
          .HasValue<Cat>("Cat");
});

// TPT — separate table per type
modelBuilder.Entity<Animal>().UseTptMappingStrategy();

// TPC — one table per concrete type (EF Core 7+)
modelBuilder.Entity<Animal>().UseTpcMappingStrategy();
```

**8. Owned types**
```csharp
modelBuilder.Entity<Order>()
    .OwnsOne(o => o.ShippingAddress, address =>
    {
        address.Property(a => a.Street).HasMaxLength(200).IsRequired();
        address.Property(a => a.City).HasMaxLength(100).IsRequired();
        address.Property(a => a.PostalCode).HasMaxLength(20);
        // Columns: ShippingAddress_Street, ShippingAddress_City, ShippingAddress_PostalCode
    });
```

**9. Pre-convention model configuration — apply rules across all entities**
```csharp
// EF Core 6+ — set defaults that apply to every entity unless overridden
protected override void ConfigureConventions(ModelConfigurationBuilder configBuilder)
{
    // All string properties default to nvarchar(200) — prevents accidental nvarchar(max)
    configBuilder.Properties<string>()
        .HaveMaxLength(200);

    // All DateTime properties stored as UTC
    configBuilder.Properties<DateTime>()
        .HaveConversion<UtcDateTimeConverter>();

    // All decimal properties default to decimal(18,4)
    configBuilder.Properties<decimal>()
        .HaveColumnType("decimal(18,4)");
}
```

**10. Split configuration into IEntityTypeConfiguration classes**
```csharp
// Configuration/ProductConfiguration.cs — keeps OnModelCreating clean
public class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> builder)
    {
        builder.ToTable("Products");
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Name).IsRequired().HasMaxLength(200);
        builder.Property(p => p.Price).HasColumnType("decimal(18,2)");
        builder.Property(p => p.Status).HasConversion<string>().HasMaxLength(50);
    }
}

// In DbContext — applies all IEntityTypeConfiguration<T> in the assembly at once
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
}
```

---

## Gotchas

- **`OnDelete(DeleteBehavior.Cascade)` is EF Core's default for required relationships.** Always set `OnDelete` explicitly — the cascade default is dangerous and on SQL Server causes schema errors with multiple cascade paths to the same table.
- **`HasDefaultValueSql()` requires `ValueGeneratedOnAdd()`.** Without it, EF sends the property's default C# value (null, 0) in the INSERT statement, overwriting the database default. The generated column value is never used.
- **Fluent API configuration is only read once at startup.** If your `IEntityTypeConfiguration<T>` class is in a different assembly than the one you pass to `ApplyConfigurationsFromAssembly`, it's silently skipped. No error — just missing configuration and EF falls back to conventions.
- **Value converters on composite primary keys break EF's key comparison.** EF compares keys in C# for the identity cache. If you apply a converter to a PK property, EF may fail to locate already-tracked entities. Stick to primitive PKs or test identity cache behaviour carefully with converted PKs.
- **`ToJson()` requires the provider to support JSON columns.** SQL Server maps JSON owned types to `nvarchar(max)`. Older SQL Server (pre-2016) has limited JSON support. PostgreSQL maps to `jsonb`. Always test JSON column queries on the target provider — LINQ translation into JSON path expressions varies.
- **Calling `modelBuilder.Entity<T>()` multiple times for the same type merges configuration.** Having both a data annotation and a conflicting Fluent API call for the same property is confusing — Fluent API silently wins. Pick one style per property.

---

## Interview Angle

**What they're really testing:** Whether you know when conventions and data annotations fall short, and whether you can configure non-trivial relationships and constraints — particularly delete behaviour, decimal precision, value converters, and JSON columns.

**Common question form:** *"What's the difference between data annotations and Fluent API?"* or *"How do you configure a many-to-many relationship in EF Core?"*

**The depth signal:** A junior answer says Fluent API goes in `OnModelCreating` and can do everything annotations can. A senior answer explains that composite keys, owned types, value converters, and JSON columns are Fluent API–only; why `OnDelete` must always be set explicitly (cascade default is dangerous); why `decimal` column types must be configured (convention precision varies by provider); how `IEntityTypeConfiguration<T>` classes scale `OnModelCreating` in large projects; how `ConfigureConventions` sets project-wide defaults (string max length, DateTime UTC, decimal precision); how value converters enable storing enums as strings, encrypting columns, and mapping value objects without changing entity classes; and why `HasDefaultValueSql` requires `ValueGeneratedOnAdd`.

---

## Related Topics

- [[dotnet/ef/ef-dbcontext.md]] — Fluent API lives inside `DbContext.OnModelCreating`; the context is the host for all configuration.
- [[dotnet/ef/ef-code-first.md]] — Fluent API configuration drives what Code First migrations generate.
- [[dotnet/ef/ef-owned-types.md]] — `OwnsOne`/`OwnsMany` and `ToJson()` are the key owned type configuration APIs covered briefly here and in depth there.
- [[dotnet/ef/ef-inheritance.md]] — TPH/TPT/TPC configuration introduced here is covered in depth (discriminator setup, migration implications, query performance) in the inheritance file.

---

## Source

https://learn.microsoft.com/en-us/ef/core/modeling

---
*Last updated: 2026-04-08*