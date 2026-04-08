# EF Core Inheritance

> The three strategies EF Core offers for mapping a C# class hierarchy to database tables — each with different schema shapes, query costs, and migration implications.

---

## When To Use It

Use inheritance mapping when you have a genuine "is-a" relationship in your domain that you want modelled as C# inheritance — `Dog` is an `Animal`, `CreditCard` is a `Payment`, `AdminUser` is a `User`. The choice of strategy (TPH, TPT, or TPC) depends on how you query the hierarchy. Don't reach for inheritance just because classes share some properties — consider owned types or composition instead. Avoid inheritance mapping for large, high-traffic tables where you need maximum query performance — the join or union overhead of TPT and TPC compounds at scale.

---

## Core Concept

EF Core supports three inheritance mapping strategies. **TPH (Table-Per-Hierarchy)** stores all types in one table with a discriminator column — it's EF's default, has no JOINs, but produces nullable columns for every subtype-specific property. **TPT (Table-Per-Type)** gives each type its own table; queries join the base and derived tables. **TPC (Table-Per-Concrete, EF Core 7+)** gives each concrete type its own table with all inherited columns repeated — no JOINs, no shared table, no discriminator, but polymorphic queries use `UNION ALL`. The right choice is driven by your query patterns: if you mostly query the base type polymorphically, TPH is fastest. If your subtypes are large and distinct, TPC avoids nullable columns. If your schema must be normalized, TPT fits — but pay the JOIN cost.

---

## The Code

**1. Entity hierarchy — shared across all three strategies**
```csharp
// Base class — abstract means no direct Animal instances
public abstract class Animal
{
    public int    Id   { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Species { get; set; } = string.Empty;
}

public class Dog : Animal
{
    public string Breed        { get; set; } = string.Empty;
    public bool   IsVaccinated { get; set; }
}

public class Cat : Animal
{
    public bool   IsIndoor  { get; set; }
    public string? CoatColor { get; set; }
}

public class Bird : Animal
{
    public double WingspanCm { get; set; }
    public bool   CanFly     { get; set; }
}
```

**2. TPH — Table-Per-Hierarchy (EF Core default)**
```csharp
// Single table — all types, all columns, one discriminator column
// No configuration needed — EF uses TPH by default when you register the base type

public class AppDbContext : DbContext
{
    public DbSet<Animal> Animals { get; set; } // query all types polymorphically
    public DbSet<Dog>    Dogs    { get; set; } // query only Dogs
}

// Schema generated:
// Animals table: Id, Name, Species, Discriminator (varchar), Breed (nullable),
//                IsVaccinated (nullable), IsIndoor (nullable), CoatColor (nullable),
//                WingspanCm (nullable), CanFly (nullable)

// Custom discriminator — use string values instead of type names
modelBuilder.Entity<Animal>()
    .HasDiscriminator<string>("AnimalType")
    .HasValue<Dog>("DOG")
    .HasValue<Cat>("CAT")
    .HasValue<Bird>("BIRD");

// Or use an enum discriminator
modelBuilder.Entity<Animal>()
    .HasDiscriminator<AnimalKind>(nameof(AnimalKind))
    .HasValue<Dog>(AnimalKind.Dog)
    .HasValue<Cat>(AnimalKind.Cat)
    .HasValue<Bird>(AnimalKind.Bird);
```

**3. TPH — querying the hierarchy**
```csharp
// Polymorphic query — all animals (no JOIN, uses discriminator in WHERE)
var allAnimals = await context.Animals.ToListAsync();
// Generated: SELECT Id, Name, Species, Discriminator, Breed, ... FROM Animals

// Query a specific type — WHERE Discriminator = 'DOG'
var dogs = await context.Dogs.ToListAsync();
// Generated: SELECT ... FROM Animals WHERE Discriminator IN ('DOG')

// Pattern matching after loading
foreach (var animal in allAnimals)
{
    if (animal is Dog dog)
        Console.WriteLine($"{dog.Name} is a {dog.Breed}");
    else if (animal is Cat cat)
        Console.WriteLine($"{cat.Name} is {(cat.IsIndoor ? "indoor" : "outdoor")}");
}

// Type filter in LINQ
var vaccinatedDogs = await context.Animals
    .OfType<Dog>()
    .Where(d => d.IsVaccinated)
    .ToListAsync();
// Generated: SELECT ... FROM Animals WHERE Discriminator = 'DOG' AND IsVaccinated = 1
```

**4. TPT — Table-Per-Type**
```csharp
// Each type gets its own table; derived tables FK to the base table

modelBuilder.Entity<Animal>().UseTptMappingStrategy();
// Or per-entity:
// modelBuilder.Entity<Animal>().ToTable("Animals");
// modelBuilder.Entity<Dog>().ToTable("Dogs");
// modelBuilder.Entity<Cat>().ToTable("Cats");

// Schema generated:
// Animals: Id (PK), Name, Species
// Dogs:    Id (PK + FK → Animals.Id), Breed, IsVaccinated
// Cats:    Id (PK + FK → Animals.Id), IsIndoor, CoatColor
// Birds:   Id (PK + FK → Animals.Id), WingspanCm, CanFly

// Querying Dogs generates a JOIN:
// SELECT a.Id, a.Name, a.Species, d.Breed, d.IsVaccinated
// FROM Animals a INNER JOIN Dogs d ON a.Id = d.Id

// Polymorphic query (all animals) generates LEFT JOINs to all derived tables — expensive
var allAnimals = await context.Animals.ToListAsync();
// SELECT a.*, d.Breed, d.IsVaccinated, c.IsIndoor, c.CoatColor, b.WingspanCm, b.CanFly
// FROM Animals a
// LEFT JOIN Dogs d ON a.Id = d.Id
// LEFT JOIN Cats c ON a.Id = c.Id
// LEFT JOIN Birds b ON a.Id = b.Id
```

**5. TPC — Table-Per-Concrete (EF Core 7+)**
```csharp
// Each concrete type gets its own table with ALL columns (base + derived)
// No shared table, no discriminator, no JOINs for single-type queries

modelBuilder.Entity<Animal>().UseTpcMappingStrategy();

// Schema generated:
// Dogs:  Id, Name, Species, Breed, IsVaccinated  ← Name and Species repeated here
// Cats:  Id, Name, Species, IsIndoor, CoatColor   ← and here
// Birds: Id, Name, Species, WingspanCm, CanFly    ← and here

// Single-type query — no JOINs, uses Dogs table directly
var dogs = await context.Dogs.ToListAsync();
// Generated: SELECT Id, Name, Species, Breed, IsVaccinated FROM Dogs

// TPC requires a non-identity PK strategy — each concrete table needs unique IDs
// across all tables so polymorphic queries don't produce duplicate IDs
// Use HiLo or sequence-based IDs
modelBuilder.Entity<Animal>().Property(a => a.Id)
    .UseHiLo("animal_hilo"); // SQL Server HiLo sequence

// Polymorphic query uses UNION ALL — no JOINs but more result sets
var allAnimals = await context.Animals.ToListAsync();
// Generated:
// SELECT Id, Name, Species, Breed, IsVaccinated, NULL AS IsIndoor, ... FROM Dogs
// UNION ALL
// SELECT Id, Name, Species, NULL AS Breed, ..., IsIndoor, CoatColor, ... FROM Cats
// UNION ALL
// SELECT Id, Name, Species, ..., WingspanCm, CanFly FROM Birds
```

**6. Migration implications**

```csharp
// TPH migration — single table, nullable columns for all subtype properties
// dotnet ef migrations add InheritanceTPH generates:
migrationBuilder.CreateTable(
    name: "Animals",
    columns: table => new
    {
        Id           = table.Column<int>(nullable: false),
        Name         = table.Column<string>(nullable: false),
        Species      = table.Column<string>(nullable: false),
        AnimalType   = table.Column<string>(nullable: false),  // discriminator
        Breed        = table.Column<string>(nullable: true),   // Dog-specific
        IsVaccinated = table.Column<bool>(nullable: true),     // Dog-specific
        IsIndoor     = table.Column<bool>(nullable: true),     // Cat-specific
        CoatColor    = table.Column<string>(nullable: true),   // Cat-specific
        WingspanCm   = table.Column<double>(nullable: true),   // Bird-specific
        CanFly       = table.Column<bool>(nullable: true)      // Bird-specific
    });

// TPT migration — one table per type, FK constraints
// Generates: Animals + Dogs (with FK) + Cats (with FK) + Birds (with FK)

// TPC migration — one table per concrete type, repeated columns
// Generates: Dogs (all columns) + Cats (all columns) + Birds (all columns)
// Adding a column to the Animal base class = migration updates ALL concrete tables
```

**7. Choosing the right strategy**
```csharp
// Decision guide (not code — just commentary on when each fits)

// TPH — choose when:
// - You query the base type polymorphically most of the time
// - Subtypes have few unique properties
// - You want the simplest schema and fastest single-type queries
// - You're OK with nullable columns

// TPT — choose when:
// - Your schema must be fully normalized (DBA requirement)
// - Subtypes have many unique properties and no nullable column policy
// - You rarely query polymorphically — mostly hit individual subtypes
// - You can accept JOIN overhead on polymorphic queries

// TPC — choose when:
// - You mostly query individual concrete types (no JOINs needed)
// - Polymorphic queries are rare and UNION ALL cost is acceptable
// - You don't want nullable columns (TPH's downside) or JOINs (TPT's downside)
// - You can use HiLo or sequence-based PKs (identity columns don't work with TPC)
```

---

## Gotchas

- **TPT polymorphic queries produce LEFT JOINs to every derived table.** Loading all `Animal` entities joins `Animals`, `Dogs`, `Cats`, and `Birds` in a single query. For a hierarchy with 10 subtypes and millions of rows, this is a performance disaster. Benchmark before choosing TPT for polymorphic-heavy workloads.
- **TPC requires non-identity primary keys.** SQL Server identity columns are per-table — each table generates its own sequence, so `Dog.Id = 1` and `Cat.Id = 1` are different rows but collide if returned in a UNION. Use `UseHiLo()` or `UseSequence()` to generate IDs from a shared sequence.
- **Adding a property to the base class generates schema changes across all concrete tables in TPC.** In TPT and TPC, a new column on the abstract base class produces a migration that adds the column to every concrete table. In a hierarchy with 10 concrete types, that's 10 `ALTER TABLE` statements.
- **TPH non-nullable subtype properties require workarounds.** If `Dog.Breed` is non-nullable in C# but stored in the TPH table as `nullable` (because Cats and Birds have no Breed), EF Core may emit a warning or require you to configure the column as nullable explicitly. Either make the property nullable, or use `IsRequired(false)` in Fluent API.
- **Discriminator value changes are a data migration.** Changing the discriminator string (e.g., from `"Dog"` to `"DOG"`) requires a data migration to update existing rows. A schema migration alone is not enough.
- **`DbSet<Animal>` and `DbSet<Dog>` can be registered simultaneously.** Both can coexist in the context — `DbSet<Animal>` queries all types, `DbSet<Dog>` queries only Dogs with an implicit type filter. You don't have to register both — `DbSet<Animal>` is sufficient, with `OfType<Dog>()` for typed queries.

---

## Interview Angle

**What they're really testing:** Whether you understand the schema trade-offs between the three strategies and can make the right choice for a given query pattern.

**Common question form:** *"How does EF Core handle inheritance?"* or *"What's the difference between TPH, TPT, and TPC in EF Core?"*

**The depth signal:** A junior says EF uses a discriminator column (TPH). A senior explains all three strategies with their schema shape (one table vs per-type vs per-concrete), their query cost (no joins vs inner joins vs UNION ALL), and their migration implications (nullable columns vs FK tables vs repeated columns); knows that TPC requires non-identity PKs (HiLo or sequence) because identity columns generate per-table IDs that collide in UNION queries; understands that TPT's polymorphic query generates LEFT JOINs to all derived tables and degrades at scale; and knows when inheritance is the wrong model entirely (composition or owned types may be better for shared properties without a true "is-a" relationship).

---

## Related Topics

- [[dotnet/ef/ef-relationships.md]] — Inheritance is introduced in the relationships file; this file covers configuration and migration implications in depth.
- [[dotnet/ef/ef-fluent-api.md]] — `UseTptMappingStrategy()`, `UseTpcMappingStrategy()`, `HasDiscriminator()`, and `HasValue<T>()` are all Fluent API configuration methods.
- [[dotnet/ef/ef-migrations.md]] — Adding a property to the base class in TPC/TPT produces migrations that touch multiple tables; understanding migration structure helps you plan and review these changes safely.
- [[dotnet/ef/ef-performance.md]] — TPT polymorphic queries and TPC UNION ALL queries have significant performance implications; profile before choosing a strategy for high-traffic tables.

---

## Source

https://learn.microsoft.com/en-us/ef/core/modeling/inheritance

---
*Last updated: 2026-04-08*