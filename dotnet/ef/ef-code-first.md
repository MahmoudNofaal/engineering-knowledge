# EF Core Code First

> The workflow where you define your database schema entirely in C# classes and let EF Core generate and evolve the actual database tables from those classes via migrations.

---

## When To Use It

Use Code First when you own the database and want the schema to live in source control alongside the application code. It's the standard approach for greenfield projects — you write entities, configure relationships in `OnModelCreating`, and run `dotnet ef migrations add` to produce versioned SQL scripts the team applies consistently. Don't use it when you're connecting to a database that already exists and is maintained independently of your application — use Database First (scaffold) instead. Don't use it if your DBA team manages schema changes manually in production and doesn't want migrations running automatically on deploy.

---

## Core Concept

Code First means your C# classes are the source of truth, not the database. You write an entity class (`Product`, `Order`, `Customer`), register it on `DbContext` as a `DbSet<T>`, and optionally configure its columns, constraints, and relationships using either data annotations or the Fluent API in `OnModelCreating`. When you run `dotnet ef migrations add`, EF Core compares your current model to the last migration snapshot and generates a C# migration class containing `Up()` (what to apply) and `Down()` (how to reverse it). Running `dotnet ef database update` executes those pending migrations against the database. The schema in the database is always the result of running all migrations in order — making schema history auditable, reversible, and repeatable across environments.

---

## The Code

**1. Entity classes — two configuration styles**
```csharp
// Entities/Product.cs — data annotations (simple, inline)
public class Product
{
    public int Id { get; set; }

    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    [Column(TypeName = "decimal(18,2)")]
    public decimal Price { get; set; }

    public bool IsActive { get; set; } = true;

    public int CategoryId { get; set; }
    public Category Category { get; set; } = null!; // navigation property
}

// Entities/Category.cs
public class Category
{
    public int Id { get; set; }

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    public ICollection<Product> Products { get; set; } = [];
}
```

**2. DbContext with Fluent API configuration (preferred for non-trivial mappings)**
```csharp
// Data/AppDbContext.cs
public class AppDbContext(DbContextOptions<AppDbContext> options)
    : DbContext(options)
{
    public DbSet<Product>  Products   { get; set; }
    public DbSet<Category> Categories { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Product>(entity =>
        {
            entity.HasKey(p => p.Id);

            entity.Property(p => p.Name)
                  .IsRequired()
                  .HasMaxLength(200);

            entity.Property(p => p.Price)
                  .HasColumnType("decimal(18,2)");

            entity.Property(p => p.IsActive)
                  .HasDefaultValue(true);

            // Relationship: many products → one category
            entity.HasOne(p => p.Category)
                  .WithMany(c => c.Products)
                  .HasForeignKey(p => p.CategoryId)
                  .OnDelete(DeleteBehavior.Restrict); // prevents cascade delete
        });

        modelBuilder.Entity<Category>(entity =>
        {
            entity.HasKey(c => c.Id);
            entity.Property(c => c.Name).IsRequired().HasMaxLength(100);

            // Unique constraint — no two categories with the same name
            entity.HasIndex(c => c.Name).IsUnique();
        });
    }
}
```

**3. Migration workflow — the full CLI cycle**
```bash
# Create a migration after changing entities or OnModelCreating
dotnet ef migrations add InitialCreate

# Review the generated migration before applying it
# Migrations/20260324_InitialCreate.cs

# Apply pending migrations to the database
dotnet ef database update

# Roll back the last migration (reverts DB and removes migration file)
dotnet ef migrations remove

# Generate a SQL script instead of applying directly — for DBA review
dotnet ef migrations script --output schema.sql

# Apply migrations programmatically at app startup (common in dev/Docker)
# In Program.cs:
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync(); // applies all pending migrations
}
```

**4. A subsequent migration — adding a column**
```csharp
// After adding: public string? Description { get; set; } to Product

// dotnet ef migrations add AddProductDescription generates:
public partial class AddProductDescription : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "Description",
            table: "Products",
            type: "nvarchar(max)",
            nullable: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(
            name: "Description",
            table: "Products");
    }
}
```

**5. Seed data in OnModelCreating**
```csharp
modelBuilder.Entity<Category>().HasData(
    new Category { Id = 1, Name = "Electronics" },
    new Category { Id = 2, Name = "Furniture" }
);
// Seeded via migration — included in the generated Up() method
// IDs must be hardcoded (not auto-generated) for HasData to work correctly
```

---

## Gotchas

- **Never edit a migration that has already been applied to any shared environment.** Once a migration has run against dev, staging, or production, it's immutable. If you need to fix something in it, create a new migration. Editing an applied migration corrupts the `__EFMigrationsHistory` table and makes future `database update` commands unpredictable or fail entirely.
- **`DeleteBehavior.Cascade` is EF Core's default for required relationships — this will silently delete child rows.** If you add a required foreign key without specifying `OnDelete`, EF generates a `CASCADE` delete constraint. Deleting a `Category` deletes all its `Products`. This is almost never what you want in a production schema. Always set `OnDelete(DeleteBehavior.Restrict)` or `ClientSetNull` explicitly for relationships involving business-critical data.
- **`HasData()` seed entries require hardcoded primary keys, never database-generated ones.** EF Core needs to detect whether a seed row already exists on subsequent migrations. If you use `Id = 0` or omit the key, EF can't track it and generates duplicate insert attempts. Seed data with identity keys like `1`, `2`, `3` and never change those IDs once the migration has shipped.
- **Renaming a property without configuration generates a `DROP COLUMN` + `ADD COLUMN`, not an `ALTER COLUMN`.** EF Core doesn't infer renames — it sees a deleted property and a new property. The generated migration drops the old column (and all its data) and adds a new one. If you need to rename a column without losing data, manually edit the generated migration to use `migrationBuilder.RenameColumn()` before applying it.
- **`db.Database.MigrateAsync()` in `Program.cs` should never run in production without a deployment gate.** Running migrations automatically on every app startup means a bad migration can take your production database down before you can intervene. In production, apply migrations as an explicit deployment step (`dotnet ef database update` in your CI/CD pipeline) so you can catch and roll back failures before traffic hits the new app.

---

## Interview Angle

**What they're really testing:** Whether you understand the migration lifecycle and the risks of automating schema changes, and whether you know the difference between convention, data annotation, and Fluent API configuration and when each applies.

**Common question form:** *"What is Code First in EF Core and how do migrations work?"* or *"How do you handle database schema changes in a team environment?"*

**The depth signal:** A junior answer describes writing entity classes and running `dotnet ef migrations add`. A senior answer explains the migration snapshot model (EF diffs against the last snapshot, not the live database), why editing applied migrations is dangerous and how the `__EFMigrationsHistory` table tracks state, the `DeleteBehavior.Cascade` default and the data-loss risk it carries for required relationships, why property renames generate drop-and-add rather than rename and how to fix the generated migration manually, and why `MigrateAsync()` at startup is acceptable for dev/Docker but a deployment risk in production where migrations should be a discrete, reversible step.

---

## Related Topics

- [[dotnet/ef-dbcontext.md]] — The `DbContext` and its `OnModelCreating` method are where all Code First configuration lives; the context is what EF reads to generate migrations.
- [[dotnet/ef-migrations.md]] — Migrations are the output of Code First; understanding the migration file structure, the snapshot, and the CLI commands is the operational side of this topic.
- [[dotnet/ef-querying.md]] — Once the schema exists, querying through EF Core's LINQ provider is the day-to-day use of the Code First model.
- [[devops/docker-networking.md]] — Running `MigrateAsync()` on startup is common in Docker Compose dev setups where the database container may not be ready when the app starts; understanding container startup order explains why retry logic or health checks are needed alongside it.

---

## Source

https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations

---
*Last updated: 2026-03-24*