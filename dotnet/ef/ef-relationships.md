# EF Core Relationships

> The configuration that tells EF Core how entities relate to each other — one-to-many, many-to-many, one-to-one — so it can generate correct foreign keys, JOIN queries, and cascade behaviour.

---

## When To Use It

Use relationship configuration any time two entities are connected — an `Order` has many `OrderItems`, a `Product` belongs to a `Category`, a `User` has one `UserProfile`. Without it, EF Core tries to infer the relationship from navigation properties and naming conventions, which works for simple cases but silently produces wrong foreign keys or missing constraints for anything non-obvious. Always configure delete behaviour explicitly — EF's cascade default will surprise you in production. Many-to-many with a join entity (that carries its own payload columns) always requires explicit configuration; EF can't infer it.

---

## Core Concept

A relationship in EF Core has three parts: two entity types, a foreign key column on one of them, and optional navigation properties that let you traverse from one entity to the other in code. EF Core needs to know which side owns the foreign key, which side is the "one" and which is the "many", and what should happen to dependent rows when the principal is deleted. You express this with `HasOne`/`WithMany`, `HasMany`/`WithMany`, or `HasOne`/`WithOne` in Fluent API. The principal is the entity being referenced (the `Category`); the dependent is the entity holding the foreign key (the `Product`). Navigation properties are not required on both sides — you can have a navigation on just one side — but the foreign key column always exists on the dependent table regardless.

---

## The Code

**1. One-to-many — the most common relationship**
```csharp
public class Category
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public ICollection<Product> Products { get; set; } = [];
}

public class Product
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int CategoryId { get; set; }
    public Category Category { get; set; } = null!;
}

modelBuilder.Entity<Product>()
    .HasOne(p => p.Category)
    .WithMany(c => c.Products)
    .HasForeignKey(p => p.CategoryId)
    .OnDelete(DeleteBehavior.Restrict); // never rely on cascade default
```

**2. Many-to-many — without a payload (EF Core 5+)**
```csharp
public class Student
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public ICollection<Course> Courses { get; set; } = [];
}

public class Course
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public ICollection<Student> Students { get; set; } = [];
}

modelBuilder.Entity<Student>()
    .HasMany(s => s.Courses)
    .WithMany(c => c.Students)
    .UsingEntity(j => j.ToTable("StudentCourses"));
```

**3. Many-to-many — with a join entity carrying payload columns**
```csharp
public class Enrollment
{
    public int StudentId { get; set; }
    public Student Student { get; set; } = null!;
    public int CourseId { get; set; }
    public Course Course { get; set; } = null!;
    public DateTime EnrolledAt { get; set; }
    public string? Grade { get; set; }
}

modelBuilder.Entity<Enrollment>(entity =>
{
    entity.HasKey(e => new { e.StudentId, e.CourseId });

    entity.HasOne(e => e.Student)
          .WithMany(s => s.Enrollments)
          .HasForeignKey(e => e.StudentId)
          .OnDelete(DeleteBehavior.Cascade);

    entity.HasOne(e => e.Course)
          .WithMany(c => c.Enrollments)
          .HasForeignKey(e => e.CourseId)
          .OnDelete(DeleteBehavior.Cascade);
});
```

**4. One-to-one**
```csharp
public class User
{
    public int Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public UserProfile? Profile { get; set; }
}

public class UserProfile
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User User { get; set; } = null!;
    public string? Bio { get; set; }
}

modelBuilder.Entity<User>()
    .HasOne(u => u.Profile)
    .WithOne(p => p.User)
    .HasForeignKey<UserProfile>(p => p.UserId) // must specify which side holds the FK
    .OnDelete(DeleteBehavior.Cascade);
```

**5. Self-referencing relationship**
```csharp
public class Category
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int? ParentId { get; set; }
    public Category? Parent { get; set; }
    public ICollection<Category> Children { get; set; } = [];
}

modelBuilder.Entity<Category>()
    .HasOne(c => c.Parent)
    .WithMany(c => c.Children)
    .HasForeignKey(c => c.ParentId)
    .OnDelete(DeleteBehavior.Restrict); // cascade on self-ref causes SQL Server cycle errors
```

**6. Shadow properties — FK without a C# property**
```csharp
// The FK column exists in the database but has no corresponding C# property
// Useful when you want the FK on the dependent table without polluting the entity class
public class Post
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    // No BlogId property — FK is a shadow property
    public Blog Blog { get; set; } = null!;
}

modelBuilder.Entity<Post>()
    .HasOne(p => p.Blog)
    .WithMany(b => b.Posts)
    .HasForeignKey("BlogId")  // shadow property name — exists in DB, not in C#
    .OnDelete(DeleteBehavior.Cascade);

// Querying with shadow properties
var posts = await context.Posts
    .Where(p => EF.Property<int>(p, "BlogId") == blogId)
    .ToListAsync();
```

**7. Alternate keys — unique constraints that act as FK targets**
```csharp
// A product has a unique SKU — other entities can FK to the SKU, not just the PK
public class Product
{
    public int Id { get; set; }
    public string Sku { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}

public class InventoryItem
{
    public int Id { get; set; }
    public string ProductSku { get; set; } = string.Empty; // FK to alternate key
    public Product Product { get; set; } = null!;
    public int Stock { get; set; }
}

modelBuilder.Entity<Product>()
    .HasAlternateKey(p => p.Sku); // creates UNIQUE constraint on Sku

modelBuilder.Entity<InventoryItem>()
    .HasOne(i => i.Product)
    .WithMany()
    .HasForeignKey(i => i.ProductSku)
    .HasPrincipalKey(p => p.Sku); // FK points to the alternate key, not the PK
```

**8. Inheritance — TPH, TPT, TPC**
```csharp
// Base class
public abstract class Animal
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
}

public class Dog : Animal
{
    public string Breed { get; set; } = string.Empty;
}

public class Cat : Animal
{
    public bool IsIndoor { get; set; }
}

// TPH (Table-Per-Hierarchy) — EF Core default
// Single table with a discriminator column — fastest queries, nullable columns for subtype props
modelBuilder.Entity<Animal>().ToTable("Animals");
// Generates: Animals table with Discriminator column ("Dog"/"Cat") + Breed (nullable) + IsIndoor (nullable)

// TPT (Table-Per-Type) — separate table per type, joined on query
modelBuilder.Entity<Animal>().UseTptMappingStrategy();
// Generates: Animals(Id, Name), Dogs(Id FK, Breed), Cats(Id FK, IsIndoor)
// Queries use JOINs — cleaner schema, slower reads

// TPC (Table-Per-Concrete, EF Core 7+) — one table per concrete type, no shared table
modelBuilder.Entity<Animal>().UseTpcMappingStrategy();
// Generates: Dogs(Id, Name, Breed), Cats(Id, Name, IsIndoor)
// No JOINs, no discriminator — fastest queries, but polymorphic queries need UNION ALL
```

**9. Lazy loading — opt-in, use with care**
```csharp
// Not enabled by default — requires installing Microsoft.EntityFrameworkCore.Proxies
// and making navigation properties virtual
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(connStr)
           .UseLazyLoadingProxies()); // installs proxy-based lazy loading

public class Order
{
    public int Id { get; set; }
    public virtual Customer Customer { get; set; } = null!; // must be virtual
    public virtual ICollection<OrderItem> Items { get; set; } = [];
}

// With lazy loading — navigation properties auto-load on first access
var order = await context.Orders.FindAsync(orderId);
var name = order.Customer.Name; // triggers SELECT FROM Customers WHERE Id = @p0

// The danger: N+1 is now invisible — no Include() warning, just silent database calls
foreach (var order in orders)
    Console.WriteLine(order.Customer.Name); // N queries — no warning, no exception
```

**10. Eager loading**
```csharp
var orders = await context.Orders
    .Include(o => o.Customer)
    .Include(o => o.Items)
        .ThenInclude(i => i.Product)
    .Where(o => o.Status == OrderStatus.Pending)
    .AsNoTracking()
    .ToListAsync();

// Filtered include — load only active items
var orders = await context.Orders
    .Include(o => o.Items.Where(i => i.IsActive))
    .ToListAsync();
```

---

## Gotchas

- **EF Core's default delete behaviour for required relationships is `Cascade`.** If you define a required FK without `OnDelete`, EF generates a `CASCADE` constraint. On SQL Server, multiple cascade paths to the same table throw a schema error; on other databases they silently delete data you didn't intend to remove. Always set `OnDelete` explicitly.
- **One-to-one requires `HasForeignKey<TDependent>()` to specify which side holds the FK.** EF Core can't infer this for one-to-one relationships. Omitting it causes EF to guess, sometimes putting the FK on the wrong table.
- **Self-referencing relationships with `DeleteBehavior.Cascade` fail on SQL Server.** SQL Server prohibits cycle cascade paths. The migration succeeds but `database update` throws. Use `DeleteBehavior.Restrict` and handle deletion logic manually.
- **Many-to-many without a join entity class can't have payload columns added later.** If you later need `EnrolledAt` on the join table, you can't add it to the implicit join entity — you must refactor to an explicit join entity class, which is a breaking migration.
- **Lazy loading hides N+1 queries.** Every access to an unloaded navigation property inside a loop silently fires a new SELECT. There's no exception, no warning — just unexpectedly high database load. Turn on EF query logging and check for repeated single-row SELECTs to detect it.
- **TPT inheritance uses JOINs on every query** — even loading `Dog` requires joining `Animals` and `Dogs`. For polymorphic queries over large tables, TPT can be significantly slower than TPH. Profile before choosing TPT for performance-sensitive paths.

---

## Interview Angle

**What they're really testing:** Whether you understand the principal/dependent distinction, the FK placement rules for one-to-one, cascade behaviour defaults, and the N+1 query problem.

**Common question form:** *"How do you configure a one-to-many relationship in EF Core?"* or *"What is the N+1 query problem and how does EF Core's Include solve it?"*

**The depth signal:** A junior answer describes `HasOne`/`WithMany` and `Include`. A senior answer explains EF's cascade default and why it's dangerous, why one-to-one requires `HasForeignKey<TDependent>`, why lazy loading is off by default (it hides N+1 rather than fixing it), the difference between TPH/TPT/TPC and when each is appropriate, shadow properties for clean entities without FK pollution, alternate keys for non-PK FK relationships, and why implicit many-to-many join entities can't be extended with payload columns.

---

## Related Topics

- [[dotnet/ef/ef-fluent-api.md]] — All relationship configuration is expressed through Fluent API; `HasOne`/`WithMany`/`HasForeignKey`/`OnDelete` is Fluent API syntax.
- [[dotnet/ef/ef-queries.md]] — `Include`, `ThenInclude`, and filtered includes are how you load related data; relationship configuration determines what EF can join and how.
- [[dotnet/ef/ef-inheritance.md]] — TPH, TPT, and TPC deserve their own deep-dive; this file introduces them, the inheritance file covers configuration and migration implications in depth.
- [[dotnet/ef/ef-dbcontext.md]] — Navigation properties are tracked by the change tracker; understanding how the context tracks entities explains why accessing an unloaded navigation returns null.

---

## Source

https://learn.microsoft.com/en-us/ef/core/modeling/relationships

---
*Last updated: 2026-04-08*