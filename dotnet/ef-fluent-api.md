# EF Core Fluent API

> The method-chaining configuration system in `OnModelCreating` that tells EF Core exactly how to map your C# entity classes to database tables, columns, constraints, and relationships — without touching the entity classes themselves.

---

## When To Use It

Use Fluent API whenever data annotations aren't expressive enough — composite keys, table splitting, owned types, delete behaviour, column types, unique indexes, and any relationship with non-obvious foreign keys all require it. Prefer Fluent API over data annotations for anything beyond basic `[Required]` and `[MaxLength]` — it keeps entity classes free of infrastructure concerns and centralises all schema decisions in one place. Don't mix both heavily for the same property; when Fluent API and a data annotation conflict, Fluent API wins, which creates confusing double-configuration that's hard to audit.

---

## Core Concept

Fluent API lives entirely in `DbContext.OnModelCreating(ModelBuilder modelBuilder)`. You call `modelBuilder.Entity<T>()` to get a builder for an entity, then chain methods to describe its table name, primary key, column types, required/optional constraints, indexes, and relationships. Nothing here runs at runtime — it's all read once at startup to build EF Core's internal model, which then drives both query generation and migration output. The key insight is that Fluent API is the authoritative layer: whatever you configure here overrides conventions and annotations. This makes it the right place for anything production-critical like delete behaviour, precision of `decimal` columns, and unique constraints — things where EF's defaults would silently produce the wrong schema.

---

## The Code

**1. Table and column configuration**
```csharp
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<Product>(entity =>
    {
        entity.ToTable("Products", schema: "catalogue"); // custom schema

        entity.HasKey(p => p.Id);

        entity.Property(p => p.Name)
              .IsRequired()
              .HasMaxLength(200)
              .HasColumnName("ProductName"); // column name differs from property name

        // decimal precision must always be set explicitly — default is (18,2) on SQL Server
        // but varies by provider; never rely on convention for money columns
        entity.Property(p => p.Price)
              .HasColumnType("decimal(18,2)")
              .HasDefaultValue(0m);

        entity.Property(p => p.CreatedAt)
              .HasDefaultValueSql("GETUTCDATE()") // DB-generated default
              .ValueGeneratedOnAdd();             // EF won't try to insert this

        entity.Property(p => p.RowVersion)
              .IsRowVersion(); // optimistic concurrency token
    });
}
```

**2. Composite primary key**
```csharp
// EF convention can't infer composite keys — Fluent API is required
modelBuilder.Entity<OrderItem>(entity =>
{
    entity.HasKey(oi => new { oi.OrderId, oi.ProductId }); // composite PK

    entity.Property(oi => oi.Quantity).IsRequired();
    entity.Property(oi => oi.UnitPrice).HasColumnType("decimal(18,2)");
});
```

**3. Relationships — one-to-many, many-to-many, one-to-one**
```csharp
// One-to-many: Order has many OrderItems
modelBuilder.Entity<OrderItem>(entity =>
{
    entity.HasOne(oi => oi.Order)
          .WithMany(o => o.Items)
          .HasForeignKey(oi => oi.OrderId)
          .OnDelete(DeleteBehavior.Cascade); // deleting an order deletes its items

    entity.HasOne(oi => oi.Product)
          .WithMany()                        // Product has no navigation back to OrderItems
          .HasForeignKey(oi => oi.ProductId)
          .OnDelete(DeleteBehavior.Restrict); // prevent accidental product deletion
});

// Many-to-many: Student ↔ Course (EF Core 5+ — no join entity class required)
modelBuilder.Entity<Student>()
    .HasMany(s => s.Courses)
    .WithMany(c => c.Students)
    .UsingEntity(j => j.ToTable("StudentCourses")); // explicit join table name

// One-to-one: User has one UserProfile
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
    // Simple index — speeds up queries filtering by CategoryId
    entity.HasIndex(p => p.CategoryId);

    // Unique index — database-enforced uniqueness
    entity.HasIndex(p => p.Sku)
          .IsUnique()
          .HasDatabaseName("IX_Products_Sku");

    // Composite unique index — combination must be unique
    entity.HasIndex(p => new { p.Name, p.CategoryId })
          .IsUnique();

    // Filtered index — only index active products (SQL Server syntax)
    entity.HasIndex(p => p.Name)
          .HasFilter("[IsActive] = 1");
});
```

**5. Owned types — value objects embedded in the same table**
```csharp
// Address is not its own table — it's columns in the Orders table
modelBuilder.Entity<Order>()
    .OwnsOne(o => o.ShippingAddress, address =>
    {
        address.Property(a => a.Street).HasMaxLength(200).IsRequired();
        address.Property(a => a.City).HasMaxLength(100).IsRequired();
        address.Property(a => a.PostalCode).HasMaxLength(20);
        // Generates columns: ShippingAddress_Street, ShippingAddress_City, etc.
    });
```

**6. Split configuration into IEntityTypeConfiguration classes (keeps OnModelCreating clean)**
```csharp
// Configuration/ProductConfiguration.cs
public class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> builder)
    {
        builder.ToTable("Products");
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Name).IsRequired().HasMaxLength(200);
        builder.Property(p => p.Price).HasColumnType("decimal(18,2)");
    }
}

// In DbContext — applies all IEntityTypeConfiguration implementations in the assembly
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
}
```

---

## Gotchas

- **`OnDelete(DeleteBehavior.Cascade)` is EF Core's default for required relationships — it's not opt-in.** If you define a required foreign key without calling `OnDelete()`, EF generates a `CASCADE` constraint. On SQL Server, multiple cascade paths to the same table cause a schema error at migration time; on other databases it silently enables cascading deletes you didn't intend. Always set `OnDelete` explicitly for every relationship.
- **`HasDefaultValueSql()` and `ValueGeneratedOnAdd()` tell EF not to send that column in `INSERT` statements — but EF still reads it back after insert.** If your database default returns a value (like `GETUTCDATE()`), EF re-queries the row to populate the property. This is an extra round-trip. If you set `HasDefaultValueSql` without `ValueGeneratedOnAdd`, EF sends `null` in the INSERT and the default never fires.
- **Fluent API configuration in `OnModelCreating` is only read once at startup.** If you add `ApplyConfigurationsFromAssembly` but your configuration class is in a different assembly, it won't be found — no error, just silently missing configuration. The resulting migration will use EF conventions instead, which may produce wrong column types or missing constraints.
- **`OwnsOne` and `OwnsMany` make the owned type's table the owner's table by default.** If you later decide the owned type needs its own table (e.g. for performance), switching from `OwnsOne` to a regular `HasOne` relationship is a breaking migration — EF drops the embedded columns and creates a new table. Design ownership carefully upfront.
- **Calling `modelBuilder.Entity<T>()` multiple times for the same type in `OnModelCreating` is fine — EF merges the configuration.** But having both a data annotation (e.g. `[MaxLength(100)]`) and a conflicting Fluent API call (`.HasMaxLength(200)`) for the same property is confusing and Fluent API silently wins. Pick one style per property and stick to it — mixing creates ambiguity during code reviews and migration audits.

---

## Interview Angle

**What they're really testing:** Whether you know when conventions and data annotations fall short, and whether you can configure non-trivial relationships and constraints correctly — particularly delete behaviour and decimal precision, which are the most common production schema mistakes.

**Common question form:** *"What's the difference between data annotations and Fluent API in EF Core?"* or *"How do you configure a composite primary key or a many-to-many relationship?"*

**The depth signal:** A junior answer says Fluent API goes in `OnModelCreating` and can do everything data annotations can. A senior answer explains that composite keys and owned types are Fluent API-only (annotations can't express them), why `OnDelete` must be set explicitly because the cascade default is dangerous, why `decimal` column types must always be configured (convention-generated precision varies by provider), how `IEntityTypeConfiguration<T>` classes scale `OnModelCreating` in larger projects, and why `HasDefaultValueSql` requires `ValueGeneratedOnAdd` to prevent EF from overwriting the DB-generated value with null in the INSERT statement.

---

## Related Topics

- [[dotnet/ef-dbcontext.md]] — Fluent API lives inside `DbContext.OnModelCreating`; the context is the entry point and the host for all configuration.
- [[dotnet/ef-code-first.md]] — Fluent API configuration directly drives what Code First migrations generate; getting the configuration wrong produces the wrong schema.
- [[dotnet/ef-migrations.md]] — Every Fluent API change that affects the schema must be captured in a migration; understanding migrations explains why configuration must be finalised before running `migrations add`.
- [[dotnet/ef-querying.md]] — Relationship configuration (navigation properties, foreign keys, owned types) determines what EF Core can and can't include in queries; a misconfigured relationship produces wrong or missing JOIN clauses.

---

## Source

https://learn.microsoft.com/en-us/ef/core/modeling

---
*Last updated: 2026-03-24*