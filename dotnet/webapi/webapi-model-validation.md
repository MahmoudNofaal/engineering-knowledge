# ASP.NET Core Web API Model Validation

> Model validation is the framework's mechanism for checking that incoming request data meets your rules before your action code runs.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Declarative and programmatic validation of request DTOs before action execution |
| **Use when** | Every public endpoint that accepts input — always |
| **Avoid when** | Never avoid — but prefer FluentValidation over data annotations for complex cross-field rules |
| **Introduced** | ASP.NET Core 1.0; auto-400 via `[ApiController]` added ASP.NET Core 2.1 |
| **Namespace** | `System.ComponentModel.DataAnnotations`, `Microsoft.AspNetCore.Mvc` |
| **Key types** | `ValidationAttribute`, `IValidatableObject`, `ModelStateDictionary`, `ValidationProblemDetails` |

---

## When To Use It

Use it on every public API endpoint that accepts input. It's the first line of defence against malformed data reaching your business logic or database. Data annotations handle the common cases (required fields, string length, numeric ranges) with no code in the action. Reach for `IValidatableObject` or FluentValidation when rules depend on multiple fields together, or when validation logic is complex enough to need unit testing on its own. Don't validate inside the action method with manual `if` checks when data annotations or a validation library will do the job — that logic belongs in the model, not the controller.

---

## Core Concept

After model binding populates your action parameters, the framework runs validation against them and writes the results into `ModelState` — a dictionary keyed by field name, with a list of errors for each. With `[ApiController]` on the controller, if `ModelState.IsValid` is false the framework short-circuits and returns a 400 `ValidationProblemDetails` response before your action is called at all. Without `[ApiController]`, you check `ModelState.IsValid` yourself and decide what to return. Data annotations are attributes on your DTO properties that express constraints declaratively. `IValidatableObject` gives you a `Validate` method for cross-field rules. Both feed into the same `ModelState` dictionary and produce the same error response shape.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | `ModelState`, `[Required]`, `[Range]`, `[StringLength]` etc. available |
| ASP.NET Core 2.1 | `[ApiController]` — automatic 400 `ValidationProblemDetails` on invalid model state |
| ASP.NET Core 2.2 | `ApiBehaviorOptions.InvalidModelStateResponseFactory` — customise 400 shape |
| .NET 5 | `ProblemDetails` factory and `IProblemDetailsFactory` introduced |
| .NET 7 | `IProblemDetailsService` added; `ValidationProblemDetails` integrates with `AddProblemDetails()` |

*Before `[ApiController]`, every action that accepted input had to check `ModelState.IsValid` explicitly and return `BadRequest(ModelState)`. `[ApiController]` automated this but also made it invisible — causing confusion when the action never runs for invalid input.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Data annotation validation | O(k) | k = number of attributes; attribute execution is lightweight |
| `IValidatableObject.Validate` | O(1) to O(n) | Depends on implementation; runs only if attribute validation passes |
| `ModelState` dictionary construction | O(k) | Built once per request; pooled in most .NET versions |
| Custom `ValidationAttribute` | Varies | Async not supported; avoid I/O in validation attributes |

**Allocation behaviour:** `ModelState` entries allocate only when errors are present (happy path is near-zero). `ValidationProblemDetails` serialisation allocates proportionally to the number of errors. For high-volume APIs, consider suppressing the automatic 400 and returning a leaner custom error structure.

**Benchmark notes:** Validation overhead is negligible for typical DTOs (<20 properties). FluentValidation has similar performance to data annotations for simple rules but adds DI overhead per validation run. Both are dominated by JSON deserialization cost on any realistic payload.

---

## The Code

**Data annotations on a request DTO**
```csharp
public record CreateUserRequest
{
    [Required(ErrorMessage = "Email is required.")]
    [EmailAddress]
    public string Email { get; init; } = "";

    [Required]
    [StringLength(100, MinimumLength = 8, ErrorMessage = "Password must be 8–100 characters.")]
    public string Password { get; init; } = "";

    [Range(13, 120, ErrorMessage = "Age must be between 13 and 120.")]
    public int Age { get; init; }

    [Url]
    public string? ProfileUrl { get; init; }
}

[ApiController]
[Route("api/users")]
public class UsersController : ControllerBase
{
    [HttpPost]
    public IActionResult Create(CreateUserRequest req)
    {
        // With [ApiController]: only reached if ModelState.IsValid == true
        return CreatedAtAction(nameof(GetById), new { id = 1 }, req);
    }
}
```

**Cross-field validation with `IValidatableObject`**
```csharp
public class DateRangeRequest : IValidatableObject
{
    [Required] public DateTime From { get; set; }
    [Required] public DateTime To { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (To <= From)
            yield return new ValidationResult(
                "To must be after From.",
                new[] { nameof(To) });

        if ((To - From).TotalDays > 365)
            yield return new ValidationResult(
                "Range cannot exceed 365 days.",
                new[] { nameof(From), nameof(To) });
    }
}
```

**Custom validation attribute**
```csharp
[AttributeUsage(AttributeTargets.Property)]
public class FutureDateAttribute : ValidationAttribute
{
    protected override ValidationResult? IsValid(object? value, ValidationContext ctx)
    {
        if (value is DateTime date && date <= DateTime.UtcNow)
            return new ValidationResult("Date must be in the future.", new[] { ctx.MemberName! });
        return ValidationResult.Success;
    }
}

public class ScheduleRequest
{
    [Required]
    [FutureDate]
    public DateTime ScheduledAt { get; set; }
}
```

**Customising the 400 response shape**
```csharp
builder.Services.Configure<ApiBehaviorOptions>(options =>
{
    options.InvalidModelStateResponseFactory = context =>
    {
        var errors = context.ModelState
            .Where(e => e.Value?.Errors.Count > 0)
            .ToDictionary(
                kvp => kvp.Key,
                kvp => kvp.Value!.Errors.Select(e => e.ErrorMessage).ToArray());

        return new BadRequestObjectResult(new
        {
            Message = "Validation failed.",
            Errors  = errors
        });
    };
});
```

**Manual ModelState check (when auto-400 is disabled)**
```csharp
[HttpPost]
public IActionResult Create([FromBody] CreateUserRequest req)
{
    if (!ModelState.IsValid)
        return ValidationProblem(ModelState);  // same ProblemDetails shape as auto-400
    return Ok();
}
```

**Validating nested objects and opting out**
```csharp
public class OrderRequest
{
    [Required] public string CustomerId { get; set; } = "";
    public List<OrderLineRequest> Lines { get; set; } = new();  // validated recursively
    [ValidateNever] public string? InternalNote { get; set; }   // excluded from validation
}

public class OrderLineRequest
{
    [Required] public string Sku { get; set; } = "";
    [Range(1, 9999)] public int Quantity { get; set; }
}
```

---

## Real World Example

A booking API has complex validation: a room reservation requires `CheckIn` before `CheckOut`, the stay cannot exceed 30 nights, and the requested room category must be one of the valid values. The date rules use `IValidatableObject`; the category uses a custom attribute that reads from a static lookup.

```csharp
public class AllowedValuesAttribute(params string[] allowed) : ValidationAttribute
{
    protected override ValidationResult? IsValid(object? value, ValidationContext ctx)
    {
        if (value is string s && !allowed.Contains(s, StringComparer.OrdinalIgnoreCase))
            return new ValidationResult(
                $"'{s}' is not a valid value. Allowed: {string.Join(", ", allowed)}",
                new[] { ctx.MemberName! });
        return ValidationResult.Success;
    }
}

public class RoomReservationRequest : IValidatableObject
{
    [Required]
    public DateOnly CheckIn { get; set; }

    [Required]
    public DateOnly CheckOut { get; set; }

    [Required]
    [AllowedValues("standard", "deluxe", "suite")]
    public string RoomCategory { get; set; } = "";

    [Range(1, 6)]
    public int Guests { get; set; }

    [StringLength(500)]
    public string? SpecialRequests { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (CheckOut <= CheckIn)
            yield return new ValidationResult(
                "Check-out must be after check-in.",
                new[] { nameof(CheckOut) });

        var nights = CheckOut.DayNumber - CheckIn.DayNumber;
        if (nights > 30)
            yield return new ValidationResult(
                $"Maximum stay is 30 nights. Requested: {nights}.",
                new[] { nameof(CheckIn), nameof(CheckOut) });

        if (CheckIn < DateOnly.FromDateTime(DateTime.UtcNow))
            yield return new ValidationResult(
                "Check-in cannot be in the past.",
                new[] { nameof(CheckIn) });
    }
}

[ApiController]
[Route("api/reservations")]
public class ReservationsController : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] RoomReservationRequest req)
    {
        // Reaches here only if all annotations AND IValidatableObject.Validate passed
        var reservation = await _reservations.CreateAsync(req);
        return CreatedAtAction(nameof(GetById), new { id = reservation.Id }, reservation);
    }
}
```

*The key insight: attribute validation (`[AllowedValues]`, `[Range]`) runs first and guards individual fields. `IValidatableObject.Validate` runs only if all attributes pass — it can safely assume `CheckIn` and `CheckOut` are non-null and valid dates when it applies its cross-field logic. The action body is clean.*

---

## Common Misconceptions

**"FluentValidation replaces data annotations entirely."**
FluentValidation handles API input validation — it replaces `[Required]`, `[Range]`, `IValidatableObject`. But data annotations on your EF Core entities serve a different purpose: they inform the database schema (`[MaxLength]` sets column size). You often need both — FluentValidation on your DTOs for API validation, and data annotations on your entities for database constraints. They serve different layers.

**"`IValidatableObject.Validate` always runs."**
It only runs if all data annotation checks pass first. If `[Required]` fails on a property, `Validate` is never called. This means cross-field rules in `Validate` that assume properties are non-null can't rely on that assumption — you must null-check inside `Validate` defensively, or restructure so the attribute validation guarantees the precondition.

**"`[StringLength]` and `[MaxLength]` do the same thing."**
`[StringLength(100)]` is a validation attribute — it checks at request time and returns 400 if violated. `[MaxLength(100)]` is an EF Core mapping hint — it sets the column size in the database schema. Using `[MaxLength]` alone won't validate incoming API requests. Always use `[StringLength]` (or FluentValidation) for API input, and optionally `[MaxLength]` on the same property for the DB constraint.

---

## Gotchas

- **`IValidatableObject.Validate` only runs if all data annotation checks pass first.** The framework runs attribute-based validation before calling `Validate`. If `[Required]` fails on a property, `Validate` is never called. Cross-field rules that assume properties are non-null must null-check inside `Validate` defensively.

- **Nested object properties are validated recursively, but only one level deep by default with collections.** A `List<OrderLineRequest>` will have each element's annotations validated. However, collections nested inside collections may not recurse into the inner level. Test nested validation explicitly.

- **`[Required]` on a non-nullable value type is redundant.** `[Required] public int Quantity` — `int` can never be null, so the required check always passes. The real purpose of `[Required]` is for `string?` and nullable types. Use `[Range(1, int.MaxValue)]` if you want to reject zero.

- **The automatic 400 fires before `OnActionExecuting` action filters.** `ModelStateInvalidFilter` runs before user-defined action filters. If you have a filter that expects to log or intercept invalid requests, it won't see them — `ModelStateInvalidFilter` short-circuits first. Use `IAlwaysRunResultFilter` or customise `InvalidModelStateResponseFactory` instead.

- **Custom `ValidationAttribute` cannot be `async`.** `IsValid` is synchronous. If your validation needs a database check (e.g., "does this username already exist?"), you cannot do it inside a `ValidationAttribute`. Use FluentValidation with `MustAsync` instead, or move the check into the action body after other validation passes.

- **`[ApiController]` automatic 400 only triggers for `ModelState` errors, not for exceptions.** If your DTO constructor throws, or a type converter throws, you get an unhandled exception, not a clean 400. Validation attributes report errors via `ModelState`; they don't throw.

---

## Interview Angle

**What they're really testing:** Whether you know the validation pipeline well enough to reason about where errors are caught, what the response shape looks like, and how to extend it for real business rules.

**Common question forms:**
- "How do you validate request data in ASP.NET Core?"
- "How would you enforce a rule that depends on two fields at once?"
- "How do you change the shape of the 400 validation error response?"
- "When would you use FluentValidation instead of data annotations?"

**The depth signal:** A junior knows data annotations and `ModelState.IsValid`. A senior knows that `[ApiController]` wires in `ModelStateInvalidFilter` as an action filter with order `-2000` (runs before all user-defined filters), that `IValidatableObject` only runs after all attribute checks pass (so it can't rescue a null `[Required]` field), and can articulate the trade-off between data annotations (fast, declarative, but hard to unit test in isolation) and FluentValidation (testable validators, fluent syntax, registered via `AddFluentValidation()` as `IValidator<T>` in DI, runs as a custom action filter). They also know how to reshape the error response via `InvalidModelStateResponseFactory` without breaking the standard `ProblemDetails` contract.

**Follow-up questions to expect:**
- "How does FluentValidation integrate with ASP.NET Core's validation pipeline?"
- "What's the execution order of attribute validation vs `IValidatableObject`?"
- "Can validation attributes be async? What are the alternatives?"

---

## Related Topics

- [[dotnet/webapi/webapi-model-binding.md]] — binding runs before validation; `ModelState` is populated during binding and then checked during validation — two steps in the same pipeline
- [[dotnet/webapi/webapi-controllers.md]] — `[ApiController]` on the controller activates automatic 400 responses; without it, validation errors are silent
- [[dotnet/webapi/webapi-filters.md]] — `ModelStateInvalidFilter` is an action filter; understanding filter order explains why your `OnActionExecuting` doesn't see invalid requests
- [[dotnet/webapi/webapi-exception-handling.md]] — validation failures produce 400 responses through the filter pipeline, not through exception handling; the two mechanisms are separate

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/models/validation

---
*Last updated: 2026-04-10*