# MVC Models

> The data-carrying layer in ASP.NET Core MVC — the classes that represent what your application works with, including domain entities, DTOs for API boundaries, and ViewModels shaped specifically for views.

---

## When To Use It

You're always working with models in MVC — every request that brings in data and every response that sends data out goes through them. The question isn't whether to use models, it's which kind fits where. Use domain entities inside your service layer, DTOs at the API boundary to control what enters and leaves, and ViewModels to shape data exactly for a specific view. Don't pass domain entities directly to views or bind them directly from HTTP requests — you lose control over what gets exposed or overwritten.

---

## Core Concept

"Model" in MVC is an overloaded word that means three different things depending on context, and conflating them causes real bugs. A domain entity is the in-memory representation of a business object — often mapped to a database table by EF Core. A DTO (Data Transfer Object) is what crosses the HTTP boundary — it's what the client sends in a POST body or what the API returns in a response. A ViewModel is shaped for one specific view — it might combine data from multiple domain objects and include display-only fields like `FormattedPrice` that the entity doesn't have. The rule is: entities live inside the service layer, DTOs live at the controller boundary, ViewModels live at the view boundary. Data annotations (`[Required]`, `[MaxLength]`, `[Range]`) on DTOs and ViewModels drive both server-side `ModelState` validation and client-side validation attribute generation.

---

## The Code

**1. Domain entity — lives in the service/data layer only**
```csharp
// Domain/Product.cs
public class Product
{
    public int    Id          { get; set; }
    public string Name        { get; set; } = string.Empty;
    public decimal Price      { get; set; }
    public int    Stock       { get; set; }
    public DateTime CreatedAt { get; set; }

    // EF Core navigation property — never expose this to views or API consumers
    public ICollection<OrderItem> OrderItems { get; set; } = [];
}
```

**2. DTOs — what crosses the HTTP boundary**
```csharp
// DTOs/CreateProductDto.cs — what the client POSTs
public class CreateProductDto
{
    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    [Range(0.01, 100_000)]
    public decimal Price { get; set; }

    [Range(0, int.MaxValue)]
    public int Stock { get; set; }
}

// DTOs/ProductDto.cs — what the API returns
public class ProductDto
{
    public int     Id    { get; set; }
    public string  Name  { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public bool    IsInStock { get; set; } // derived, not stored
}
```

**3. ViewModel — shaped for a specific view**
```csharp
// ViewModels/ProductIndexViewModel.cs
public class ProductIndexViewModel
{
    public IEnumerable<ProductSummary> Products { get; set; } = [];
    public int    TotalCount    { get; set; }
    public int    CurrentPage   { get; set; }
    public int    TotalPages    { get; set; }
    public string? SearchTerm   { get; set; }

    // Computed display property — belongs in the ViewModel, not the entity
    public bool HasNextPage => CurrentPage < TotalPages;
}

public class ProductSummary
{
    public int    Id             { get; set; }
    public string Name           { get; set; } = string.Empty;
    public string FormattedPrice { get; set; } = string.Empty; // "$19.99" — view-ready
    public bool   IsInStock      { get; set; }
}
```

**4. Manual mapping — explicit and safe**
```csharp
// Services/ProductService.cs
public async Task<ProductDto> GetByIdAsync(int id)
{
    var product = await _repo.FindAsync(id)
        ?? throw new NotFoundException($"Product {id} not found");

    // Explicit projection — you control exactly what leaves the service
    return new ProductDto
    {
        Id        = product.Id,
        Name      = product.Name,
        Price     = product.Price,
        IsInStock = product.Stock > 0
    };
}
```

**5. EF Core projection directly to DTO (avoids loading the full entity)**
```csharp
// Queries only the columns needed — no navigation properties loaded
var products = await _context.Products
    .Where(p => p.Stock > 0)
    .Select(p => new ProductDto
    {
        Id        = p.Id,
        Name      = p.Name,
        Price     = p.Price,
        IsInStock = true // we know it's true from the Where clause
    })
    .ToListAsync();
```

**6. Data annotations driving both server and client validation**
```csharp
// DTOs/RegisterDto.cs
public class RegisterDto
{
    [Required(ErrorMessage = "Email is required")]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    [MinLength(8, ErrorMessage = "Password must be at least 8 characters")]
    public string Password { get; set; } = string.Empty;

    [Compare(nameof(Password), ErrorMessage = "Passwords do not match")]
    public string ConfirmPassword { get; set; } = string.Empty;
}

// In the controller — [ApiController] auto-returns 400 if invalid
// In MVC with views — check ModelState manually
if (!ModelState.IsValid)
    return View(dto); // re-render form with validation errors shown
```

---

## Gotchas

- **Binding a POST body directly to a domain entity enables mass assignment.** If your `Product` entity has an `IsAdmin` or `CreatedAt` field and you bind directly from `[FromBody] Product product`, a crafted request can set any property — including ones you never intended to be user-controlled. Always use a DTO that declares only the fields the client is allowed to set.
- **EF Core navigation properties on entities cause serialization loops and N+1 queries when passed to views.** Passing a `Product` with `ICollection<OrderItem> OrderItems` to a Razor view or returning it from a JSON endpoint will either trigger lazy loading every item in the loop or cause `System.Text.Json` to throw a cycle exception. Project to a DTO or ViewModel before it leaves the service layer.
- **`[Required]` on a non-nullable value type (`int`, `decimal`, `bool`) is redundant and misleading.** Non-nullable value types can never be null, so `[Required]` has no effect on them — validation always passes. Apply `[Required]` only to `string`, nullable types (`int?`), or reference types. If you need a range constraint on an `int`, use `[Range]`.
- **`ModelState.IsValid` only covers data annotation validation — not business rules.** A DTO where `Name` passes `[Required]` and `[MaxLength(200)]` can still be a duplicate, a reserved word, or violate a uniqueness constraint in the database. Annotation validation checks shape; business validation belongs in the service layer and should throw a domain exception that the global handler maps to a 400 or 409.
- **AutoMapper's `ProjectTo<TDto>()` can generate surprising SQL if your mapping config references computed properties.** If you define a mapping that calls a C# method or property that EF Core can't translate to SQL, `ProjectTo` throws at runtime. Always verify projected queries with logging enabled in development, and prefer explicit `Select` projections for anything non-trivial.

---

## Interview Angle

**What they're really testing:** Whether you understand the distinction between entities, DTOs, and ViewModels — and specifically the mass assignment vulnerability that comes from binding request bodies directly to domain entities.

**Common question form:** *"What is a DTO and why would you use one instead of passing your entity directly?"* or *"What is over-posting / mass assignment and how do you prevent it?"*

**The depth signal:** A junior answer describes entities as "database models" and DTOs as "what you return from the API." A senior answer explains the mass assignment attack vector by name — a client sets `IsAdmin=true` in a POST body that binds to an entity — why separate input DTOs (for binding) and output DTOs (for responses) are both needed, why EF Core navigation properties cause serialization cycles and lazy-load N+1 problems when entities reach the view layer, and why `[Required]` on non-nullable value types is silently meaningless. Bonus: explaining why `Select` projections in EF Core queries are more reliable than AutoMapper's `ProjectTo` for complex mappings.

---

## Related Topics

- [[dotnet/mvc-controllers.md]] — Controllers receive DTOs via model binding and pass ViewModels to views; the model types used at each boundary are defined here.
- [[dotnet/mvc-views.md]] — Views are typed to a ViewModel via `@model`; the ViewModel is the contract between controller and view.
- [[dotnet/ef-core-basics.md]] — Domain entities are defined in the EF Core context; understanding how EF tracks changes and loads navigation properties explains why entities must not leak past the service layer.
- [[dotnet/webapi-exception-handling.md]] — Business validation failures in the service layer throw domain exceptions; the global handler maps them to 400/409 responses that the controller never has to handle manually.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/models/model-binding

---
*Last updated: 2026-03-24*