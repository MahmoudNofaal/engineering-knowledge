# EF Core Seeding

> The strategies for populating a database with initial or reference data — from hardcoded lookup tables that belong in migrations, to environment-specific records injected at startup.

---

## When To Use It

Use seeding for data that must exist for the application to function: lookup tables (statuses, categories, roles, countries), default admin accounts, or reference data that rarely changes. `HasData()` is for immutable reference data that belongs in migrations and source control. Custom seeders (services running at startup) are for data that varies by environment, depends on application logic, or needs to be idempotent without being tied to a migration. Don't seed operational data (orders, users, transactions) through either mechanism — that belongs in test fixtures or staging scripts.

---

## Core Concept

EF Core has two seeding paths. `HasData()` in `OnModelCreating` embeds seed data directly into migrations — when the migration runs, it inserts the rows as part of `Up()`. EF tracks these rows by primary key: on subsequent `migrations add` runs, it diffs the current `HasData()` calls against the snapshot, generating `INSERT`, `UPDATE`, or `DELETE` statements for changes. The catch is that PKs must be hardcoded — EF can't track rows by database-generated identity values. The second path is a custom seeder — a service (typically `IHostedService` or called from `Program.cs`) that runs after the app starts, checks whether data already exists, and inserts it if not. This is more flexible but not tied to migrations, so it's your responsibility to make it idempotent.

---

## The Code

**1. HasData() — migration-embedded reference data**
```csharp
// In OnModelCreating — data ships with the migration
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<Category>().HasData(
        new Category { Id = 1, Name = "Electronics",  Slug = "electronics"  },
        new Category { Id = 2, Name = "Furniture",    Slug = "furniture"    },
        new Category { Id = 3, Name = "Sports",       Slug = "sports"       }
    );

    modelBuilder.Entity<OrderStatus>().HasData(
        new OrderStatus { Id = 1, Name = "Pending"   },
        new OrderStatus { Id = 2, Name = "Confirmed" },
        new OrderStatus { Id = 3, Name = "Shipped"   },
        new OrderStatus { Id = 4, Name = "Cancelled" }
    );
}

// EF generates in the migration's Up():
// migrationBuilder.InsertData(table: "Categories", columns: [...], values: [...]);
// On subsequent runs it generates UpdateData/DeleteData for any changes
```

**2. HasData() with owned types — requires explicit FK**
```csharp
// Owned types in HasData require the owner's FK as part of the seed
modelBuilder.Entity<Product>().OwnsOne(p => p.Dimensions).HasData(
    new
    {
        ProductId  = 1,   // owner FK — required for owned type seeding
        Width      = 10.5,
        Height     = 5.0,
        Depth      = 2.0
    }
);
```

**3. Custom startup seeder — for environment-specific data**
```csharp
// Services/DatabaseSeeder.cs
public class DatabaseSeeder
{
    private readonly AppDbContext _context;
    private readonly ILogger<DatabaseSeeder> _logger;

    public DatabaseSeeder(AppDbContext context, ILogger<DatabaseSeeder> logger)
    {
        _context = context;
        _logger  = logger;
    }

    public async Task SeedAsync()
    {
        // Always idempotent — check before inserting
        await SeedRolesAsync();
        await SeedDefaultAdminAsync();
    }

    private async Task SeedRolesAsync()
    {
        // Guard: don't re-seed if data already exists
        if (await _context.Roles.AnyAsync()) return;

        _context.Roles.AddRange(
            new Role { Name = "Admin",    NormalizedName = "ADMIN"    },
            new Role { Name = "Manager",  NormalizedName = "MANAGER"  },
            new Role { Name = "Viewer",   NormalizedName = "VIEWER"   }
        );

        await _context.SaveChangesAsync();
        _logger.LogInformation("Seeded {Count} roles", 3);
    }

    private async Task SeedDefaultAdminAsync()
    {
        const string adminEmail = "admin@example.com";
        if (await _context.Users.AnyAsync(u => u.Email == adminEmail)) return;

        var adminRole = await _context.Roles.FirstAsync(r => r.Name == "Admin");

        _context.Users.Add(new User
        {
            Email    = adminEmail,
            Name     = "System Admin",
            RoleId   = adminRole.Id,
            IsActive = true
        });

        await _context.SaveChangesAsync();
    }
}
```

**4. Calling the seeder from Program.cs**
```csharp
// Program.cs — run after migrations, before serving requests
var app = builder.Build();

// Seed in dev and staging only — not production (production data comes from ops)
if (app.Environment.IsDevelopment() || app.Environment.IsStaging())
{
    using var scope = app.Services.CreateScope();
    var seeder = scope.ServiceProvider.GetRequiredService<DatabaseSeeder>();
    await seeder.SeedAsync();
}

app.Run();

// Register the seeder in DI
builder.Services.AddScoped<DatabaseSeeder>();
```

**5. Environment-specific seed data**
```csharp
public async Task SeedAsync(IWebHostEnvironment env)
{
    await SeedReferenceDataAsync();  // always — lookup tables, statuses

    if (env.IsDevelopment())
    {
        await SeedDevelopmentDataAsync(); // fake customers, orders, products
    }

    if (env.IsStaging())
    {
        await SeedStagingDataAsync(); // anonymised prod-like volume
    }
}

private async Task SeedDevelopmentDataAsync()
{
    if (await _context.Products.AnyAsync()) return; // guard

    var faker = new Bogus.Faker<Product>()
        .RuleFor(p => p.Name,  f => f.Commerce.ProductName())
        .RuleFor(p => p.Price, f => f.Random.Decimal(1, 500));

    _context.Products.AddRange(faker.Generate(100));
    await _context.SaveChangesAsync();
}
```

**6. Seeder as IHostedService — runs automatically on startup**
```csharp
// Alternative pattern — no need to wire in Program.cs manually
public class SeedHostedService : IHostedService
{
    private readonly IServiceProvider _services;

    public SeedHostedService(IServiceProvider services)
        => _services = services;

    public async Task StartAsync(CancellationToken ct)
    {
        using var scope = _services.CreateScope();
        var seeder = scope.ServiceProvider.GetRequiredService<DatabaseSeeder>();
        await seeder.SeedAsync();
    }

    public Task StopAsync(CancellationToken ct) => Task.CompletedTask;
}

// Registration
builder.Services.AddHostedService<SeedHostedService>();
builder.Services.AddScoped<DatabaseSeeder>();
```

---

## Gotchas

- **`HasData()` PKs must be hardcoded — never use `0` or omit them.** EF tracks seeded rows by their primary key value between migrations. If you use `Id = 0`, EF can't distinguish it from an unset key, and subsequent migrations generate duplicate inserts. Use explicit integers (1, 2, 3) or stable GUIDs (`Guid.Parse("...fixed-string...")`). Never change a seeded PK after the migration ships — EF will try to delete the old row and insert a new one.
- **`HasData()` changes require a new migration.** Adding, updating, or removing a `HasData()` entry doesn't take effect until you run `dotnet ef migrations add`. The change is baked into the migration's `InsertData`/`UpdateData`/`DeleteData` calls — not applied at runtime.
- **Custom seeders must be idempotent.** If your seeder runs on every startup (e.g., via `IHostedService`) and isn't guarded with an existence check, it inserts duplicate rows or throws unique constraint violations. Always gate each seed block with `if (await context.X.AnyAsync()) return;` or use `InsertOrIgnore`-style upsert logic.
- **`HasData()` doesn't support navigation properties.** You can't do `new Product { Category = new Category { ... } }` inside `HasData()`. You must supply raw FK values: `new Product { CategoryId = 1 }`. Foreign-keyed seed data must be inserted in the correct dependency order across multiple `HasData()` calls.
- **Seeding before applying migrations causes foreign key errors.** If your seeder runs before `MigrateAsync()`, the tables may not exist or may be missing columns, causing runtime failures. Always apply migrations before seeding — in `Program.cs`, call `MigrateAsync()` first, then `SeedAsync()`.
- **`HasData()` and custom seeders can conflict.** If `HasData()` inserts a row with `Id = 1` and your custom seeder also tries to insert `Id = 1`, you get a primary key conflict. Keep reference data in one place — either `HasData()` or the seeder, not both.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between migration-embedded data and runtime seeding, and why idempotency matters for anything running in CI or on repeated deployments.

**Common question form:** *"How do you seed initial data in EF Core?"* or *"What's the difference between `HasData()` and a custom seeder?"*

**The depth signal:** A junior answer describes `HasData()` and calling `SaveChangesAsync()`. A senior answer explains that `HasData()` is migration-bound (changes need a new migration), why PKs must be hardcoded (EF tracks by key, not by content), why custom seeders must be idempotent (repeated runs on the same database), why the seeder must run after `MigrateAsync()` (tables must exist), how to scope seed data by environment (dev fake data, staging anonymised data, production never seeds), and the `IHostedService` pattern for automatic seeding that doesn't require manual wiring in `Program.cs`.

---

## Related Topics

- [[dotnet/ef/ef-migrations.md]] — `HasData()` seed entries are baked into migrations; understanding migrations explains how seed data reaches the database and why PK stability matters.
- [[dotnet/ef/ef-code-first.md]] — The Code First workflow generates the migrations that seed data ships in; entity and seed setup are part of the same model configuration step.
- [[dotnet/ef/ef-dbcontext.md]] — Custom seeders depend on `DbContext` lifetime (scoped); seeder services must create their own scope when running from `IHostedService` (which is singleton).

---

## Source

https://learn.microsoft.com/en-us/ef/core/modeling/data-seeding

---
*Last updated: 2026-04-08*