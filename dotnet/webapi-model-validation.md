# ASP.NET Core Web API Model Validation

> Model validation is the framework's mechanism for checking that incoming request data meets your rules before your action code runs.

---

## When To Use It

Use it on every public API endpoint that accepts input. It's the first line of defence against malformed data reaching your business logic or database. Data annotations handle the common cases (required fields, string length, numeric ranges) with no code in the action. Reach for `IValidatableObject` or FluentValidation when rules depend on multiple fields together, or when validation logic is complex enough to need unit testing on its own. Don't validate inside the action method with manual `if` checks when data annotations or a validation library will do the job — that logic belongs in the model, not the controller.

---

## Core Concept

After model binding populates your action parameters, the framework runs validation against them and writes the results into `ModelState` — a dictionary keyed by field name, with a list of errors for each. With `[ApiController]` on the controller, if `ModelState.IsValid` is false the framework short-circuits and returns a 400 `ValidationProblemDetails` response before your action is called at all. Without `[ApiController]`, you check `ModelState.IsValid` yourself and decide what to return. Data annotations are attributes on your DTO properties that express constraints declaratively. `IValidatableObject` gives you a `Validate` method for cross-field rules. Both feed into the same `ModelState` dictionary and produce the same error response shape.

---

## The Code
```csharp
// --- Data annotations on a request DTO ---
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
        // With [ApiController]: this line is only reached if ModelState.IsValid == true.
        // Invalid input returns 400 automatically before we get here.
        return CreatedAtAction(nameof(GetById), new { id = 1 }, req);
    }
}
```
```csharp
// --- Cross-field validation with IValidatableObject ---
public class DateRangeRequest : IValidatableObject
{
    [Required] public DateTime From { get; set; }
    [Required] public DateTime To { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (To <= From)
            yield return new ValidationResult(
                "To must be after From.",
                new[] { nameof(To) });          // field name appears in the error response

        if ((To - From).TotalDays > 365)
            yield return new ValidationResult(
                "Range cannot exceed 365 days.",
                new[] { nameof(From), nameof(To) });
    }
}
```
```csharp
// --- Custom validation attribute ---
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

// Usage:
public class ScheduleRequest
{
    [Required]
    [FutureDate]
    public DateTime ScheduledAt { get; set; }
}
```
```csharp
// --- Customising the 400 response shape ---
// In Program.cs — runs after [ApiController]'s default filter but lets you reshape the body
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
```csharp
// --- Manual ModelState check (when [ApiController] auto-behaviour is disabled) ---
[HttpPost]
public IActionResult Create([FromBody] CreateUserRequest req)
{
    if (!ModelState.IsValid)
        return ValidationProblem(ModelState);   // same ProblemDetails shape as auto-400

    // business logic here
    return Ok();
}
```
```csharp
// --- Validating nested objects: [ValidateNever] to skip a property ---
public class OrderRequest
{
    [Required] public string CustomerId { get; set; } = "";

    public List<OrderLineRequest> Lines { get; set; } = new();  // nested — validated automatically

    [ValidateNever]                              // explicitly opt this property out of validation
    public string? InternalNote { get; set; }
}

public class OrderLineRequest
{
    [Required] public string Sku { get; set; } = "";
    [Range(1, 9999)] public int Quantity { get; set; }
}
```

---

## Gotchas

- **`IValidatableObject.Validate` only runs if all data annotation checks pass first.** The framework runs attribute-based validation before calling `Validate`. If `[Required]` fails on a property, `Validate` is never called. This means cross-field rules that assume properties are non-null can't rely on `Validate` to guard them — you must null-check inside `Validate` defensively.
- **Nested object properties are validated recursively, but only one level deep by default with collections.** A `List<OrderLineRequest>` on a parent DTO will have each element's annotations validated. However, if you have a collection inside a collection, validation may not recurse into the inner level. Test nested validation explicitly rather than assuming it works at arbitrary depth.
- **`[Required]` on a non-nullable value type is redundant but not harmful.** `[Required] public int Quantity` — `int` can never be null, so the required check always passes. The real purpose of `[Required]` is for `string?` and nullable types. Putting it on `int` doesn't hurt, but it misleads readers into thinking it's doing something. Use `[Range(1, int.MaxValue)]` if you want to reject zero.
- **The automatic 400 fires before `OnActionExecuting` filters but after `IResourceFilter`.** If you have an `IActionFilter` that expects to log or intercept invalid requests, it won't see them — `ModelStateInvalidFilter` runs first and the pipeline short-circuits. To intercept these, use `IAlwaysRunResultFilter` or customise `InvalidModelStateResponseFactory` instead.
- **`[StringLength]` and `[MaxLength]` look similar but serve different purposes.** `[StringLength(100)]` is a validation attribute — it checks at request time and returns a 400 if violated. `[MaxLength(100)]` is an EF Core mapping hint — it sets the column size in the database schema. Using `[MaxLength]` alone won't validate incoming API requests. Always use `[StringLength]` (or FluentValidation) for API input, and optionally `[MaxLength]` on the same property for the DB constraint.

---

## Interview Angle

**What they're really testing:** Whether you know the validation pipeline well enough to reason about where errors are caught, what the response shape looks like, and how to extend it for real business rules.

**Common question form:** "How do you validate request data in ASP.NET Core?" or "How would you enforce a rule that depends on two fields at once?" or "How do you change the shape of the 400 validation error response?"

**The depth signal:** A junior knows data annotations and `ModelState.IsValid`. A senior knows that `[ApiController]` wires in `ModelStateInvalidFilter` as an action filter with order `-2000` (runs before all user-defined filters), that `IValidatableObject` only runs after all attribute checks pass (so it can't rescue a null `[Required]` field), and can articulate the trade-off between data annotations (fast, declarative, but hard to unit test) and FluentValidation (testable validators, fluent syntax, registered via `AddFluentValidation()` as `IValidator<T>` in DI, runs as a custom action filter). They also know how to reshape the error response via `InvalidModelStateResponseFactory` without breaking the standard `ProblemDetails` contract that clients expect.

---

## Related Topics

- [[dotnet/webapi-model-binding.md]] — binding runs before validation; `ModelState` is populated during binding and then checked during validation — they're two steps in the same pipeline
- [[dotnet/webapi-controllers.md]] — `[ApiController]` on the controller is what activates automatic 400 responses; without it, validation errors are silent unless you check `ModelState` manually
- [[dotnet/webapi-filters.md]] — `ModelStateInvalidFilter` is an action filter; understanding filter order explains why your `OnActionExecuting` doesn't see invalid requests
- [[dotnet/webapi-problem-details.md]] — the 400 response body is a `ValidationProblemDetails` object, which is an extension of the RFC 7807 `ProblemDetails` format; knowing the shape helps you design consistent error contracts

---

## Source

[https://learn.microsoft.com/en-us/aspnet/core/mvc/models/validation](https://learn.microsoft.com/en-us/aspnet/core/mvc/models/validation)

---
*Last updated: 2026-03-24*