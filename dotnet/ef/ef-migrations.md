# EF Core Migrations

> The versioned record of every schema change your application has made — stored as C# classes that EF Core can apply forward or reverse against any database.

---

## When To Use It

Migrations are the operational side of Code First — you use them every time the schema needs to change. They're not optional: without migrations, you're manually writing SQL schema changes that aren't tracked, aren't reversible, and diverge across environments. Use migrations for every schema change, no matter how small — a single nullable column addition is still a migration. Don't run migrations automatically on app startup in production; apply them as a discrete, gated deployment step so failures can be caught before traffic hits the new code.

---

## Core Concept

When you run `dotnet ef migrations add`, EF Core compares your current model (built from entity classes and `OnModelCreating`) against a snapshot file (`Migrations/AppDbContextModelSnapshot.cs`) that was written by the previous migration. The diff produces a new migration class with two methods: `Up()` (what to apply) and `Down()` (how to reverse it). The snapshot — not the live database — is the source of truth EF diffs against. This is why editing applied migrations is dangerous: the snapshot already moved on, so EF's diff is now computing from a different baseline than the database. The `__EFMigrationsHistory` table in the database records which migrations have been applied, so `dotnet ef database update` knows which `Up()` methods still need to run.

---

## The Code

**1. The full CLI lifecycle**
```bash
# Create a migration after changing entities or OnModelCreating
dotnet ef migrations add AddProductDescription

# Review the generated file before applying
# Migrations/20260324120000_AddProductDescription.cs

# Apply all pending migrations to the connected database
dotnet ef database update

# Apply up to a specific migration (useful for partial rollbacks)
dotnet ef database update AddProductDescription

# Roll back to the previous migration state (removes last migration file if not applied)
dotnet ef migrations remove

# Roll back to a specific migration name (runs Down() methods in reverse)
dotnet ef database update InitialCreate

# Roll back ALL migrations (empties the database)
dotnet ef database update 0
```

**2. A migration file — what it actually looks like**
```csharp
// Migrations/20260324120000_AddProductDescription.cs
public partial class AddProductDescription : Migration
{
    // Applied by: dotnet ef database update
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "Description",
            table: "Products",
            type: "nvarchar(500)",
            maxLength: 500,
            nullable: true);

        // Non-nullable column on an existing table with data — needs a default
        migrationBuilder.AddColumn<bool>(
            name: "IsFeatured",
            table: "Products",
            type: "bit",
            nullable: false,
            defaultValue: false); // required when adding NOT NULL to a populated table
    }

    // Applied by: dotnet ef database update {PreviousMigration}
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(name: "Description", table: "Products");
        migrationBuilder.DropColumn(name: "IsFeatured",  table: "Products");
    }
}
```

**3. Manual migration edits — rename instead of drop-and-add**
```csharp
// EF generates DROP + ADD for renamed properties — always check before applying
// Generated (WRONG — loses data):
migrationBuilder.DropColumn(name: "ProductName", table: "Products");
migrationBuilder.AddColumn<string>(name: "Name", table: "Products", ...);

// Correct (rename preserves data):
migrationBuilder.RenameColumn(
    name: "ProductName",
    table: "Products",
    newName: "Name");
```

**4. SQL script generation — for DBA review or CI/CD pipelines**
```bash
# Generate a SQL script for all migrations (from empty database)
dotnet ef migrations script --output migrations.sql

# Generate a script from a specific migration forward
dotnet ef migrations script InitialCreate --output delta.sql

# Idempotent script — safe to run multiple times, checks __EFMigrationsHistory first
# This is the right format for production deployment pipelines
dotnet ef migrations script --idempotent --output deploy.sql
```

**5. Applying migrations programmatically (dev / Docker only)**
```csharp
// Program.cs — acceptable for local dev and Docker Compose startup
// Never use this as your production deployment strategy
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

    // Retry loop — handles Docker where DB container may not be ready
    var retries = 0;
    while (retries < 5)
    {
        try
        {
            await db.Database.MigrateAsync();
            break;
        }
        catch (Exception ex) when (retries < 4)
        {
            retries++;
            await Task.Delay(TimeSpan.FromSeconds(Math.Pow(2, retries)));
        }
    }
}
```

**6. Multiple DbContexts — separate migration histories**
```bash
# When you have AppDbContext and AuditDbContext in the same project
# Each gets its own migration folder and history table

dotnet ef migrations add InitialCreate --context AppDbContext   --output-dir Migrations/App
dotnet ef migrations add InitialCreate --context AuditDbContext --output-dir Migrations/Audit

dotnet ef database update --context AppDbContext
dotnet ef database update --context AuditDbContext
```

**7. Squashing old migrations — consolidating history**
```csharp
// When you have 200 migrations and startup is slow, squash into one baseline
// Step 1: generate a script of the current full schema
dotnet ef migrations script --output baseline.sql

// Step 2: delete all migration files except the snapshot
// Step 3: create a fresh "baseline" migration
dotnet ef migrations add Baseline

// Step 4: empty the Up() method — the schema already exists in prod
protected override void Up(MigrationBuilder migrationBuilder) { }

// Step 5: insert the Baseline migration into __EFMigrationsHistory on existing databases
// so EF doesn't try to apply it
INSERT INTO __EFMigrationsHistory (MigrationId, ProductVersion)
VALUES ('20260324_Baseline', '8.0.0');

// New databases: run baseline.sql first, then dotnet ef database update
```

**8. Checking migration status**
```bash
# List all migrations and which are applied vs pending
dotnet ef migrations list

# Check if the database is up to date (exit code 0 = in sync, 1 = pending)
dotnet ef migrations has-pending-model-changes
```

---

## Gotchas

- **Never edit a migration that has already been applied to any shared environment.** EF tracks applied migrations by their class name. If you edit the file, the `Up()` logic changes but the migration is still marked as applied in `__EFMigrationsHistory` — the change never runs. You now have a mismatch between what the code says ran and what actually ran. Create a new migration instead.
- **Property renames generate `DROP COLUMN` + `ADD COLUMN`, not `RENAME COLUMN`.** EF has no way to detect intent from a C# rename. Always check generated migration files before applying — if you see a drop on a column that has data, manually replace it with `migrationBuilder.RenameColumn()`.
- **Adding a `NOT NULL` column to a table with existing rows requires a `defaultValue`.** The database must fill existing rows with something when you add a non-nullable column. EF won't infer this — you must set `defaultValue` in the migration or the `ALTER TABLE` fails. For production: use nullable first, back-fill, then make it non-nullable in a follow-up migration.
- **`dotnet ef migrations remove` only works if the last migration hasn't been applied to the database.** If it's been applied, you need to `dotnet ef database update {PreviousMigration}` first to run `Down()`, then `migrations remove` to delete the file.
- **The snapshot file must be committed with the migration.** The snapshot is what EF diffs against for the next migration. If `AppDbContextModelSnapshot.cs` is in `.gitignore` or out of sync, the next `migrations add` produces an empty or incorrect migration.
- **Idempotent scripts check the history table — but only if the table exists.** On a brand-new database, `--idempotent` scripts first check if `__EFMigrationsHistory` exists and create it if not. On databases with a broken or missing history table, the idempotent check fails. Include a guard in your pipeline.

---

## Interview Angle

**What they're really testing:** Whether you understand the snapshot model, the `__EFMigrationsHistory` table, and the real risks of schema changes on populated databases — especially the rename vs drop-and-add trap.

**Common question form:** *"How do you manage database schema changes across environments?"* or *"What happens when you run `dotnet ef migrations add`?"*

**The depth signal:** A junior answer describes the CLI commands and the `Up`/`Down` pattern. A senior answer explains that EF diffs against the snapshot file (not the live database), why editing an applied migration doesn't fix anything (the history table already recorded it as applied), the rename trap and why you always review generated migrations before applying, why `NOT NULL` columns on populated tables need a `defaultValue`, the difference between `dotnet ef database update` for dev and `--idempotent` SQL scripts for production CI/CD pipelines, and why `MigrateAsync()` at startup is a development convenience and a production risk.

---

## Related Topics

- [[dotnet/ef/ef-code-first.md]] — Migrations are the output of the Code First workflow; entity class and Fluent API changes drive what `migrations add` generates.
- [[dotnet/ef/ef-fluent-api.md]] — Every Fluent API change that affects schema (indexes, column types, constraints) must be captured in a migration before it reaches the database.
- [[dotnet/ef/ef-seeding.md]] — `HasData()` seed entries are included in migrations; seeding strategy and migration strategy are tightly coupled.
- [[devops/ci-cd-pipelines.md]] — Production migration strategy (idempotent scripts, deployment gates, rollback procedures) belongs in the CI/CD pipeline, not in application startup code.

---

## Source

https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations

---
*Last updated: 2026-04-08*