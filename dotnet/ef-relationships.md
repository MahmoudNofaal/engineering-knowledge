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
// Entities
public class Category
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public ICollection<Product> Products { get; set; } = []; // navigation
}

public class Product
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int CategoryId { get; set; }           // foreign key property
    public Category Category { get; set; } = null!; // navigation
}

// Fluent API configuration
modelBuilder.Entity<Product>()
    .HasOne(p => p.Category)       // Product has one Category
    .WithMany(c => c.Products)     // Category has many Products
    .HasForeignKey(p => p.CategoryId)
    .OnDelete(DeleteBehavior.Restrict); // don't cascade-delete products
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

// EF generates a hidden join table automatically
modelBuilder.Entity<Student>()
    .HasMany(s => s.Courses)
    .WithMany(c => c.Students)
    .UsingEntity(j => j.ToTable("StudentCourses")); // name the join table explicitly
```

**3. Many-to-many — with a join entity carrying payload columns**
```csharp
// When the join table has its own columns, model it explicitly
public class Enrollment
{
    public int StudentId { get; set; }
    public Student Student { get; set; } = null!;

    public int CourseId { get; set; }
    public Course Course { get; set; } = null!;

    public DateTime EnrolledAt { get; set; }  // payload column
    public string? Grade { get; set; }
}

modelBuilder.Entity<Enrollment>(entity =>
{
    entity.HasKey(e => new { e.StudentId, e.CourseId }); // composite PK

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
    public UserProfile? Profile { get; set; } // optional navigation
}

public class UserProfile
{
    public int Id { get; set; }
    public int UserId { get; set; }         // FK lives on the dependent side
    public User User { get; set; } = null!;
    public string? Bio { get; set; }
}

modelBuilder.Entity<User>()
    .HasOne(u => u.Profile)
    .WithOne(p => p.User)
    .HasForeignKey<UserProfile>(p => p.UserId) // must specify which side holds the FK
    .OnDelete(DeleteBehavior.Cascade);
```

**5. Self-referencing relationship (e.g. category tree)**
```csharp
public class Category
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int? ParentId { get; set; }                      // nullable = root nodes have no parent
    public Category? Parent { get; set; }
    public ICollection<Category> Children { get; set; } = [];
}

modelBuilder.Entity<Category>()
    .HasOne(c => c.Parent)
    .WithMany(c => c.Children)
    .HasForeignKey(c => c.ParentId)
    .OnDelete(DeleteBehavior.Restrict); // cascade on self-ref causes SQL Server errors
```

**6. Querying with relationships**
```csharp
// Eager loading — include related data in the same query
var orders = await context.Orders
    .Include(o => o.Items)
        .ThenInclude(i => i.Product)  // chain for nested relationships
    .Where(o => o.CustomerId == customerId)
    .ToListAsync();

// Filtered include (EF Core 5+) — load only non-cancelled items
var orders = await context.Orders
    .Include(o => o.Items.Where(i => !i.IsCancelled))
    .ToListAsync();

// Explicit loading — load navigation after the fact
var order = await context.Orders.FindAsync(orderId);
await context.Entry(order).Collection(o => o.Items).LoadAsync();
```

---

## Gotchas

- **EF Core's default delete behaviour for required relationships is `Cascade` — not `Restrict`.** A required FK (non-nullable `CategoryId`) gets a `CASCADE` constraint in the migration unless you override it. On SQL Server, multiple cascade paths to the same table throw a schema error; on other databases they silently delete data you didn't intend to remove. Always set `OnDelete` explicitly for every relationship — never rely on the default.
- **One-to-one requires `HasForeignKey<TDependent>()` to specify which side holds the FK.** EF Core can't infer this for one-to-one relationships the way it can for one-to-many. Omitting `HasForeignKey<UserProfile>` causes EF to guess, which sometimes puts the FK on the wrong table and generates a migration with an extra column on the principal entity.
- **Self-referencing relationships with `DeleteBehavior.Cascade` fail on SQL Server.** SQL Server prohibits cascade paths that could loop (a category deleting its children which are also categories). The migration succeeds but `database update` throws `Introducing FOREIGN KEY constraint may cause cycles`. Always use `DeleteBehavior.Restrict` or `ClientCascade` for self-referencing entities and handle deletion logic manually.
- **Many-to-many without a join entity class uses a hidden shared entity that you can't query directly.** If you later need to add a payload column to the join table (like `EnrolledAt`), you can't add it to the implicit join entity — you have to refactor to an explicit join entity class, which is a breaking migration that drops and recreates the join table. Model explicit join entities upfront if there's any chance the relationship will carry data.
- **Navigation properties initialised to `null!` are not loaded automatically — they require `.Include()` or explicit loading.** Accessing `product.Category` without an `Include` on the query returns `null` for tracked entities (no lazy loading by default in EF Core) or triggers a `NullReferenceException`. Lazy loading is opt-in via `UseLazyLoadingProxies()` and requires virtual navigation properties — it's not enabled by default because it hides N+1 queries.

---

## Interview Angle

**What they're really testing:** Whether you understand the principal/dependent distinction, the FK placement rules for one-to-one, cascade behaviour defaults, and the N+1 query problem that comes from misusing navigation properties.

**Common question form:** *"How do you configure a one-to-many relationship in EF Core?"* or *"What is the N+1 query problem and how does EF Core's Include solve it?"*

**The depth signal:** A junior answer describes `HasOne`/`WithMany` and `Include`. A senior answer explains that EF Core's default cascade on required FKs is dangerous and must always be overridden explicitly, why one-to-one requires `HasForeignKey<TDependent>` (EF can't infer it), why lazy loading is off by default and why turning it on hides N+1 queries rather than fixing them, the difference between implicit and explicit many-to-many join entities and why you can't add payload columns to the implicit one, and why self-referencing cascades fail on SQL Server at migration time rather than at query time.

---

## Related Topics

- [[dotnet/ef-fluent-api.md]] — All relationship configuration is expressed through Fluent API; the `HasOne`/`WithMany`/`HasForeignKey`/`OnDelete` chain is Fluent API syntax.
- [[dotnet/ef-querying.md]] — `Include`, `ThenInclude`, and filtered includes are how you load related data; relationship configuration determines what EF can join and how.
- [[dotnet/ef-dbcontext.md]] — Navigation properties are tracked by the change tracker; understanding how the context tracks entities explains why accessing an unloaded navigation returns null rather than fetching it.
- [[databases/foreign-keys-constraints.md]] — EF relationship configuration maps to FK constraints in the database; understanding DB-level cascade and restrict behaviour explains why EF's defaults matter so much.

---

## Source

https://learn.microsoft.com/en-us/ef/core/modeling/relationships

---
*Last updated: 2026-03-24*