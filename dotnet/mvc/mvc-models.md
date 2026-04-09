# MVC Models

> The data-carrying layer in ASP.NET Core MVC — the classes that represent what your application works with, including domain entities, DTOs for API boundaries, and ViewModels shaped specifically for views.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Typed data contracts between layers |
| **Use when** | Always — every request and response flows through models |
| **Avoid when** | Passing domain entities directly to views or binding them from HTTP requests |
| **Namespace** | `System.ComponentModel.DataAnnotations` (annotations), your own project namespaces |
| **Key types** | Domain entity, DTO, ViewModel, `ModelStateDictionary`, `IValidatableObject` |
| **Validation libs** | Built-in data annotations, FluentValidation (`FluentValidation.AspNetCore`) |

---

## When To Use It

You're always working with models in MVC — every request that brings in data and every response that sends data out goes through them. The question isn't whether to use models, it's which kind fits where. Use domain entities inside your service layer, DTOs at the API boundary to control what enters and leaves, and ViewModels to shape data exactly for a specific view. Don't pass domain entities directly to views or bind them directly from HTTP requests — you lose control over what gets exposed or overwritten, and open yourself to mass assignment attacks.

---

## Core Concept

"Model" in MVC is an overloaded word that means three different things depending on context, and conflating them causes real bugs. A domain entity is the in-memory representation of a business object — often mapped to a database table by EF Core. A DTO (Data Transfer Object) is what crosses the HTTP boundary — it's what the client sends in a POST body or what the API returns in a response. A ViewModel is shaped for one specific view — it might combine data from multiple domain objects and include display-only fields like `FormattedPrice` that the entity doesn't have.

The rule is: entities live inside the service layer, DTOs live at the controller boundary, ViewModels live at the view boundary. Data annotations (`[Required]`, `[MaxLength]`, `[Range]`) on DTOs and ViewModels drive both server-side `ModelState` validation and client-side validation attribute generation via Tag Helpers. For complex validation rules that don't fit cleanly into attributes, `IValidatableObject` and FluentValidation are the two main alternatives.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | Data annotations validation inherited from `System.ComponentModel.DataAnnotations` |
| ASP.NET Core 2.1 | .NET Core 2.1 | `[ApiController]` auto-returns 400 on `ModelState` failure; `ValidationProblemDetails` introduced |
| ASP.NET Core 3.0 | .NET Core 3.0 | `System.Text.Json` replaces `Newtonsoft.Json` as default serializer; behaviour differences for nulls and cycles |
| ASP.NET Core 6.0 | .NET 6 | Required members (`required` keyword in C# 11) work with model binding |
| ASP.NET Core 7.0 | .NET 7 | `[JsonRequired]` attribute for `System.Text.Json`; improved `ProblemDetails` RFC 7807 |
| ASP.NET Core 8.0 | .NET 8 | Keyed services support; `IValidatableObject` works with async validators via FluentValidation integration |

*Before `System.Text.Json` in ASP.NET Core 3.0, `Newtonsoft.Json` handled serialization by default. The switch introduced subtle differences: `System.Text.Json` does not serialize reference cycles (throws instead), does not support `JObject`/`JArray`, and handles null differently. Many projects still opt back into `Newtonsoft.Json` via `AddNewtonsoftJson()`.*

---

## The Code

**1. Domain entity — lives in the service/data layer only**
```csharp
// Domain/Product.cs
public class Product
{
    public int      Id          { get; set; }
    public string   Name        { get; set; } = string.Empty;
    public decimal  Price       { get; set; }
    public int      Stock       { get; set; }
    public DateTime CreatedAt   { get; set; }

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
    public int     Id        { get; set; }
    public string  Name      { get; set; } = string.Empty;
    public decimal Price     { get; set; }
    public bool    IsInStock { get; set; } // derived, not stored
}
```

**3. ViewModel — shaped for a specific view**
```csharp
// ViewModels/ProductIndexViewModel.cs
public class ProductIndexViewModel
{
    public IEnumerable<ProductSummary> Products    { get; set; } = [];
    public int    TotalCount   { get; set; }
    public int    CurrentPage  { get; set; }
    public int    TotalPages   { get; set; }
    public string? SearchTerm  { get; set; }

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
```

**7. IValidatableObject — cross-property validation**
```csharp
// For validation rules that span multiple properties —
// data annotations can't express these
public class DateRangeDto : IValidatableObject
{
    [Required]
    public DateOnly StartDate { get; set; }

    [Required]
    public DateOnly EndDate { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (EndDate <= StartDate)
            yield return new ValidationResult(
                "End date must be after start date",
                [nameof(EndDate), nameof(StartDate)]);

        if ((EndDate - StartDate).Days > 365)
            yield return new ValidationResult(
                "Date range cannot exceed one year",
                [nameof(EndDate)]);
    }
}
```

**8. FluentValidation — complex validation rules outside the model**
```csharp
// Install: dotnet add package FluentValidation.AspNetCore
// Validators/CreateProductDtoValidator.cs
public class CreateProductDtoValidator : AbstractValidator<CreateProductDto>
{
    private readonly IProductRepository _repo;

    public CreateProductDtoValidator(IProductRepository repo)
    {
        _repo = repo;

        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(200)
            .MustAsync(BeUniqueName).WithMessage("A product with this name already exists");

        RuleFor(x => x.Price)
            .GreaterThan(0)
            .LessThanOrEqualTo(100_000);

        RuleFor(x => x.Stock)
            .GreaterThanOrEqualTo(0);
    }

    private async Task<bool> BeUniqueName(string name, CancellationToken ct)
        => !await _repo.ExistsAsync(name, ct);
}

// Program.cs — register FluentValidation
builder.Services.AddFluentValidationAutoValidation();
builder.Services.AddValidatorsFromAssemblyContaining<CreateProductDtoValidator>();
```

---

## Real World Example

A property management platform where tenants can submit maintenance requests. The request goes through three different model shapes: a `MaintenanceRequest` entity stored in EF Core, a `CreateMaintenanceRequestDto` bound from the form POST, and a `MaintenanceRequestViewModel` that combines the request details with the tenant's contact info and property address for display.

```csharp
// DTOs/CreateMaintenanceRequestDto.cs
public class CreateMaintenanceRequestDto : IValidatableObject
{
    [Required]
    [MaxLength(100)]
    public string Title { get; set; } = string.Empty;

    [Required]
    [MaxLength(2000)]
    public string Description { get; set; } = string.Empty;

    [Required]
    public MaintenancePriority Priority { get; set; }

    public DateTime? PreferredAccessDate { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        // Business rule: high-priority requests can't schedule access more than 48 hours out
        if (Priority == MaintenancePriority.High
            && PreferredAccessDate.HasValue
            && PreferredAccessDate.Value > DateTime.UtcNow.AddHours(48))
        {
            yield return new ValidationResult(
                "High-priority requests must be scheduled within 48 hours",
                [nameof(PreferredAccessDate)]);
        }
    }
}

// ViewModels/MaintenanceRequestDetailViewModel.cs
public class MaintenanceRequestDetailViewModel
{
    // From MaintenanceRequest entity
    public int    RequestId   { get; set; }
    public string Title       { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string StatusLabel { get; set; } = string.Empty; // "Open", "In Progress", "Resolved"
    public string PriorityBadgeClass { get; set; } = string.Empty; // CSS class for Bootstrap badge

    // From Tenant entity (joined by service layer)
    public string TenantName  { get; set; } = string.Empty;
    public string TenantPhone { get; set; } = string.Empty;

    // From Property entity
    public string PropertyAddress { get; set; } = string.Empty;
    public string UnitNumber      { get; set; } = string.Empty;

    // Computed for the view — no business logic in the view itself
    public bool CanBeEscalated     => StatusLabel == "Open";
    public bool ShowContactDetails => Priority == "High"; // view decision
}

// Services/MaintenanceService.cs
public async Task<MaintenanceRequestDetailViewModel> GetDetailAsync(int requestId, Guid tenantId)
{
    // Single query joining three tables — no navigation properties leaked to view
    return await _context.MaintenanceRequests
        .Where(r => r.Id == requestId && r.TenantId == tenantId)
        .Select(r => new MaintenanceRequestDetailViewModel
        {
            RequestId           = r.Id,
            Title               = r.Title,
            Description         = r.Description,
            StatusLabel         = r.Status.ToString(),
            PriorityBadgeClass  = r.Priority == MaintenancePriority.High ? "badge-danger" : "badge-secondary",
            TenantName          = r.Tenant.FullName,
            TenantPhone         = r.Tenant.PhoneNumber,
            PropertyAddress     = r.Unit.Property.Address,
            UnitNumber          = r.Unit.UnitNumber,
        })
        .FirstOrDefaultAsync()
        ?? throw new NotFoundException($"Request {requestId} not found");
}
```

*The key insight: `PriorityBadgeClass` and `StatusLabel` are view-specific concerns that belong in the ViewModel — not in the entity, and not computed in the Razor view. The service does the mapping and drives the EF Core projection in a single query. The controller gets a flat, fully-formed object and the view never touches a navigation property or makes formatting decisions.*

---

## Common Misconceptions

**"[Required] on an int or bool means the field is mandatory"**
`[Required]` only checks for null. Non-nullable value types (`int`, `bool`, `decimal`) can never be null — `[Required]` on them is silently meaningless and validation always passes. To enforce a range on an `int`, use `[Range]`. To ensure a `bool` is explicitly `true`, use a custom validation attribute. Apply `[Required]` only to `string`, nullable types (`int?`), or reference types.

```csharp
// [Required] has NO effect here — int can never be null
[Required]         // ← silently ignored
public int Stock { get; set; }

// Correct: use [Range] to enforce a minimum
[Range(1, int.MaxValue, ErrorMessage = "Stock must be at least 1")]
public int Stock { get; set; }
```

**"ModelState.IsValid covers all validation — if it passes, the data is valid"**
`ModelState.IsValid` only validates against data annotations (and FluentValidation if registered). It checks shape, not business rules. A DTO where `Name` passes `[Required]` and `[MaxLength(200)]` can still be a duplicate product name, a reserved keyword, or violate a database uniqueness constraint. Business validation belongs in the service layer and should throw a domain exception. Treating a `ModelState` pass as "fully valid" leads to database errors bubbling up as unhandled exceptions.

**"You should use one model class for everything — entity, DTO, and ViewModel"**
This works fine for trivial CRUD apps and breaks badly as complexity grows. An entity with EF Core navigation properties causes serialization cycles and lazy-load N+1 problems when passed directly to a view. A DTO that doubles as a ViewModel carries display-only fields (like `FormattedPrice` or `BadgeClass`) that make no sense at the API boundary. A ViewModel that doubles as a domain entity exposes persistence concerns to the view. The three types serve different masters — keeping them separate is the design, not the overhead.

---

## Gotchas

- **Binding a POST body directly to a domain entity enables mass assignment.** If your `Product` entity has an `IsAdmin` or `CreatedAt` field and you bind directly from `[FromBody] Product product`, a crafted request can set any property — including ones you never intended to be user-controlled. Always use a DTO that declares only the fields the client is allowed to set.

- **EF Core navigation properties on entities cause serialization loops and N+1 queries when passed to views.** Passing a `Product` with `ICollection<OrderItem> OrderItems` to a Razor view or returning it from a JSON endpoint will either trigger lazy loading every item in the loop or cause `System.Text.Json` to throw a cycle exception. Project to a DTO or ViewModel before it leaves the service layer.

- **`[Required]` on a non-nullable value type (`int`, `decimal`, `bool`) is redundant and misleading.** Non-nullable value types can never be null, so `[Required]` has no effect on them — validation always passes. Apply `[Required]` only to `string`, nullable types (`int?`), or reference types.

- **`ModelState.IsValid` only covers data annotation validation — not business rules.** Annotation validation checks shape; business validation belongs in the service layer and should throw a domain exception that the global handler maps to a 400 or 409.

- **Dropdown options and select lists in ViewModels must be rebuilt on POST failure.** `SelectList` or `IEnumerable<SelectListItem>` properties are not submitted in POST bodies — only the selected value is. If your ViewModel has a `CategoryOptions` property for a `<select>`, it will be null on the POST action. You must re-populate it before returning `View(vm)` when `ModelState.IsValid` is false.

- **AutoMapper's `ProjectTo<TDto>()` can generate surprising SQL if your mapping config references C# methods EF Core can't translate.** Always verify projected queries with logging enabled in development, and prefer explicit `Select` projections for anything non-trivial.

---

## Interview Angle

**What they're really testing:** Whether you understand the distinction between entities, DTOs, and ViewModels — and specifically the mass assignment vulnerability that comes from binding request bodies directly to domain entities.

**Common question forms:**
- *"What is a DTO and why would you use one instead of passing your entity directly?"*
- *"What is over-posting / mass assignment and how do you prevent it?"*
- *"What's the difference between a DTO and a ViewModel?"*

**The depth signal:** A junior answer describes entities as "database models" and DTOs as "what you return from the API." A senior answer explains the mass assignment attack vector by name — a client sets `IsAdmin=true` in a POST body that binds to an entity — why separate input DTOs (for binding) and output DTOs (for responses) are both needed, why EF Core navigation properties cause serialization cycles and lazy-load N+1 problems when entities reach the view layer, and why `[Required]` on non-nullable value types is silently meaningless. Bonus: explaining why `Select` projections in EF Core queries are more reliable than AutoMapper's `ProjectTo` for complex mappings, and when to reach for `IValidatableObject` vs FluentValidation.

**Follow-up questions to expect:**
- *"How would you validate that a product name is unique — where does that logic live?"* (service layer, not annotations)
- *"What's the difference between IValidatableObject and FluentValidation?"* (inline vs separate class; FluentValidation supports async and DI injection)

---

## Related Topics

- [[dotnet/mvc/mvc-controllers.md]] — Controllers receive DTOs via model binding and pass ViewModels to views; the model types used at each boundary are defined here.
- [[dotnet/mvc/mvc-views.md]] — Views are typed to a ViewModel via `@model`; the ViewModel is the contract between controller and view.
- [[dotnet/ef/ef-dbcontext.md]] — Domain entities are defined in the EF Core context; understanding how EF tracks changes and loads navigation properties explains why entities must not leak past the service layer.
- [[dotnet/webapi-exception-handling.md]] — Business validation failures in the service layer throw domain exceptions; the global handler maps them to 400/409 responses that the controller never has to handle manually.
- [[dotnet/mvc/mvc-model-validation.md]] — Deep dive into ModelState, data annotations, FluentValidation, and client-side validation wiring.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/models/model-binding

---
*Last updated: 2026-04-09*