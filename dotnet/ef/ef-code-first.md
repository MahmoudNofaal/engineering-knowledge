# EF Core Code First

> The workflow where you define your database schema entirely in C# classes and let EF Core generate and evolve the actual database tables from those classes via migrations.

---

## When To Use It

Use Code First when you own the database and want the schema to live in source control alongside the application code. It's the standard approach for greenfield projects — you write entities, configure relationships in `OnModelCreating`, and run `dotnet ef migrations add` to produce versioned SQL scripts the team applies consistently. Don't use it when you're connecting to a database that already exists and is maintained independently — use Database First (scaffold) instead. Don't use it if your DBA team manages schema changes manually in production and doesn't want migrations running automatically on deploy.

---

## Core Concept

Code First means your C# classes are the source of truth, not the database. You write an entity class, register it on `DbContext` as a `DbSet<T>`, and optionally configure its columns, constraints, and relationships using the Fluent API in `OnModelCreating`. When you run `dotnet ef migrations add`, EF Core compares your current model to the last migration snapshot and generates a C# migration class containing `Up()` (what to apply) and `Down()` (how to reverse it). Running `dotnet ef database update` executes those pending migrations. The snapshot — not the live database — is what EF diffs against, which is why editing applied migrations is dangerous and why the snapshot file must always be committed alongside the migration file.

---

## The Code

**1. Entity classes — two configuration styles**
```csharp
// Data annotations (simple, inline)
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
    public Category Category { get; set; } = null!;
}

public class Category
{
    public int Id { get; set; }

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    public ICollection<Product> Products { get; set; } = [];
}
```

**2. DbContext with Fluent API**
```csharp
public class AppDbContext(DbContextOptions<AppDbContext> options)
    : DbContext(options)
{
    public DbSet<Product>  Products   { get; set; }
    public DbSet<Category> Categories { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}

// Separate configuration class — keeps OnModelCreating clean
public class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> builder)
    {
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Name).IsRequired().HasMaxLength(200);
        builder.Property(p => p.Price).HasColumnType("decimal(18,2)");
        builder.Property(p => p.IsActive).HasDefaultValue(true);

        builder.HasOne(p => p.Category)
               .WithMany(c => c.Products)
               .HasForeignKey(p => p.CategoryId)
               .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(p => p.Name).IsUnique();
    }
}
```

**3. Migration workflow**
```bash
dotnet ef migrations add InitialCreate
# Review: Migrations/20260408_InitialCreate.cs — check for unexpected DROP columns

dotnet ef database update
dotnet ef migrations remove          # undo last migration (only if not applied)
dotnet ef database update InitialCreate  # roll back to a specific point
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
        migrationBuilder.DropColumn(name: "Description", table: "Products");
    }
}
```

**5. SQL script generation for production deployment**
```bash
# Standard script — from empty DB to latest
dotnet ef migrations script --output migrations.sql

# From a specific migration forward (useful for incremental deployments)
dotnet ef migrations script InitialCreate --output delta.sql

# Idempotent script — checks __EFMigrationsHistory before each migration
# Safe to run multiple times — the right format for CI/CD pipelines
dotnet ef migrations script --idempotent --output deploy.sql
```

**6. Apply migrations programmatically (dev / Docker)**
```csharp
// Program.cs — acceptable for local dev and Docker Compose
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();
}
// Never use this as your production deployment strategy — apply migrations as a
// discrete, gated CI/CD step with --idempotent SQL scripts instead
```

**7. Multiple DbContexts — separate migration histories**
```bash
dotnet ef migrations add InitialCreate --context AppDbContext   --output-dir Migrations/App
dotnet ef migrations add InitialCreate --context AuditDbContext --output-dir Migrations/Audit

dotnet ef database update --context AppDbContext
dotnet ef database update --context AuditDbContext
```

**8. Squashing migrations — consolidating a long history**
```bash
# When you have 200 migrations and want a clean baseline:
# Step 1: generate the current full schema as a SQL script
dotnet ef migrations script --output baseline.sql

# Step 2: delete all migration files (keep the snapshot)
# Step 3: create a fresh Baseline migration
dotnet ef migrations add Baseline

# Step 4: empty the Up() body — the schema already exists in prod
protected override void Up(MigrationBuilder migrationBuilder) { }

# Step 5: on existing databases, insert Baseline into __EFMigrationsHistory manually
# so EF doesn't try to apply it again
INSERT INTO __EFMigrationsHistory (MigrationId, ProductVersion)
VALUES ('20260408000000_Baseline', '8.0.0');

# New environments: run baseline.sql first, then dotnet ef database update
```

**9. Database First — reverse engineering an existing database**
```bash
# Scaffold entity classes and DbContext from an existing database
# Useful when you inherit a database you don't own
dotnet ef dbcontext scaffold \
    "Server=.;Database=LegacyDb;Trusted_Connection=True" \
    Microsoft.EntityFrameworkCore.SqlServer \
    --output-dir Models \
    --context LegacyDbContext \
    --data-annotations    # use data annotations instead of Fluent API
    --no-onconfiguring    # don't embed connection string in the context

# Limitation: generated code is a starting point, not ongoing workflow
# Re-running scaffold overwrites your edits — manage schema changes manually after initial scaffold
```

**10. Seed data**
```csharp
modelBuilder.Entity<Category>().HasData(
    new Category { Id = 1, Name = "Electronics" },
    new Category { Id = 2, Name = "Furniture"   }
);
// Seeded via migration — included in the generated Up() method
// IDs must be hardcoded (not auto-generated) for HasData to work correctly
```

---

## Gotchas

- **Never edit a migration that has already been applied to any shared environment.** Once applied, a migration is recorded in `__EFMigrationsHistory` — editing the file doesn't change what ran. Create a new migration to fix mistakes in applied ones.
- **`DeleteBehavior.Cascade` is EF Core's default for required relationships.** Always set `OnDelete` explicitly — cascade defaults silently delete data and cause SQL Server schema errors with multiple cascade paths.
- **`HasData()` seed entries require hardcoded primary keys.** EF tracks seeded rows by their PK. Using `Id = 0` or omitting the key generates duplicate inserts on subsequent migrations. Use stable integer or GUID PKs and never change them after the migration ships.
- **Property renames generate DROP + ADD, not RENAME.** Always review generated migration files before applying. Replace drop-and-add patterns with `migrationBuilder.RenameColumn()` to preserve data.
- **Adding a `NOT NULL` column to a populated table requires `defaultValue`.** EF won't infer what to fill existing rows with — you must set `defaultValue` in the migration or the `ALTER TABLE` fails. Better pattern: add as nullable, back-fill, make non-nullable in a follow-up migration.
- **The snapshot file must be committed with the migration.** `AppDbContextModelSnapshot.cs` is what EF diffs against for the next migration. If it's out of sync or in `.gitignore`, the next `migrations add` generates an empty or incorrect migration.
- **`MigrateAsync()` at app startup is a production risk.** A bad migration can take your production database down before you can intervene. Apply migrations as an explicit CI/CD step — use `--idempotent` scripts with a rollback plan.

---

## Interview Angle

**What they're really testing:** Whether you understand the migration lifecycle and the risks of automating schema changes, and whether you know the difference between convention, data annotation, and Fluent API configuration.

**Common question form:** *"What is Code First in EF Core and how do migrations work?"* or *"How do you handle database schema changes in a team environment?"*

**The depth signal:** A junior answer describes writing entity classes and running `dotnet ef migrations add`. A senior answer explains the snapshot model (EF diffs against the snapshot, not the live database), why editing applied migrations doesn't work (the history table already recorded it), the `DeleteBehavior.Cascade` default and its data-loss risk, why property renames generate drop-and-add and how to fix the generated migration manually, why `NOT NULL` columns on populated tables need a `defaultValue`, why `MigrateAsync()` at startup is acceptable for dev/Docker but a deployment risk in production, how to squash migration history for long-lived projects, and the `--idempotent` flag for CI/CD pipelines.

---

## Related Topics

- [[dotnet/ef/ef-dbcontext.md]] — The `DbContext` and `OnModelCreating` are where all Code First configuration lives; the context is what EF reads to generate migrations.
- [[dotnet/ef/ef-migrations.md]] — The operational side of Code First: the full migration lifecycle, the `__EFMigrationsHistory` table, rollback strategies, and deployment patterns.
- [[dotnet/ef/ef-fluent-api.md]] — Fluent API configuration in `OnModelCreating` drives what Code First migrations generate; getting configuration right is the prerequisite for correct migrations.
- [[dotnet/ef/ef-seeding.md]] — `HasData()` seed entries are baked into migrations; seeding strategy and migration strategy are tightly coupled.

---

## Source

https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations

---
*Last updated: 2026-04-08*