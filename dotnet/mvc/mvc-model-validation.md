# MVC Model Validation

> The ASP.NET Core system that checks whether bound model data satisfies declared constraints — using data annotations, `IValidatableObject`, or FluentValidation — before allowing the action to proceed.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Post-binding constraint checking on model data |
| **Use when** | Every action that receives input — validation gates bad data before it reaches business logic |
| **Avoid when** | Using validation as a substitute for business rules — annotations check shape, not domain intent |
| **Namespace** | `System.ComponentModel.DataAnnotations`, `FluentValidation` |
| **Key types** | `ModelStateDictionary`, `IValidatableObject`, `AbstractValidator<T>` |
| **Check** | `ModelState.IsValid` (manual) or `[ApiController]` auto-400 |

---

## When To Use It

Validation runs after model binding — once the framework has populated your action parameters from the request, it runs validation on them before calling your action method (with `[ApiController]`) or alongside your first check of `ModelState.IsValid` (without it). Use data annotations for simple, stateless constraints: required fields, length limits, numeric ranges, format checks. Use `IValidatableObject` for cross-property rules that annotations can't express. Use FluentValidation when rules are complex, async (e.g. uniqueness checks against the database), or when you want validation logic in a separate testable class. Don't use any of these for business rules — "a product name must be unique in this tenant" is a business rule that belongs in the service layer, not a validation attribute.

---

## Core Concept

Validation in ASP.NET Core MVC has three layers that run in sequence. First, model binding runs and populates parameters — if a value can't be converted to the target type at all (e.g. `"abc"` into `int`), a binding error is recorded in `ModelState` without ever reaching validation. Second, data annotation validation runs against the bound values — `[Required]`, `[MaxLength]`, `[Range]`, `[EmailAddress]`, and custom attributes. Third, if the model implements `IValidatableObject`, its `Validate()` method runs for cross-property rules. FluentValidation (when registered) runs as a third-party `IModelValidator` and integrates into this same pipeline.

`ModelState.IsValid` is false if any of these layers produced errors. With `[ApiController]`, the framework checks `ModelState.IsValid` before your action runs and returns a `ValidationProblemDetails` 400 automatically. Without `[ApiController]`, you check `ModelState.IsValid` manually at the top of your action and return `View(model)` (MVC) or `BadRequest(ModelState)` (API) yourself.

Client-side validation is a separate system entirely. `asp-for` on an `<input>` generates `data-val-*` HTML attributes; the `jquery.validate.unobtrusive` library reads those attributes at runtime in the browser. The two systems share the same annotations but run independently — server-side validation is always authoritative.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | `ModelState`, data annotations validation inherited from `System.ComponentModel.DataAnnotations` |
| ASP.NET Core 2.1 | .NET Core 2.1 | `[ApiController]` auto-validates before action runs; `ValidationProblemDetails` format introduced |
| ASP.NET Core 2.1 | .NET Core 2.1 | `ProblemDetails` (RFC 7807) standardised for API error responses |
| ASP.NET Core 3.0 | .NET Core 3.0 | `[ApiController]` problem details format improved; `ModelState` errors serialised consistently |
| ASP.NET Core 6.0 | .NET 6 | `[Required]` works correctly with C# nullable reference types; `[Length]` attribute added |
| ASP.NET Core 7.0 | .NET 7 | `ValidationProblemDetails` RFC 7807 fully compliant; `[AllowedValues]` and `[DeniedValues]` added |
| ASP.NET Core 8.0 | .NET 8 | `[Base64String]` attribute added; FluentValidation 11 async validators fully supported |

*Before ASP.NET Core 2.1, every API action had to manually check `ModelState.IsValid` and return a 400. `[ApiController]` automated this, but also standardised the error response format — if your client was parsing your custom error format, the switch to `ValidationProblemDetails` was a breaking change.*

---

## The Code

**1. Data annotations — the standard validation attributes**
```csharp
public class CreateProductDto
{
    [Required(ErrorMessage = "Name is required")]
    [MaxLength(200, ErrorMessage = "Name cannot exceed 200 characters")]
    [MinLength(2)]
    public string Name { get; set; } = string.Empty;

    [Range(0.01, 100_000, ErrorMessage = "Price must be between £0.01 and £100,000")]
    public decimal Price { get; set; }

    [Range(0, int.MaxValue)]
    public int Stock { get; set; }

    [Required]
    [EmailAddress]
    public string SupplierEmail { get; set; } = string.Empty;

    [Url]
    public string? ProductPageUrl { get; set; }

    // ASP.NET Core 7+
    [AllowedValues("physical", "digital", "subscription")]
    public string ProductType { get; set; } = "physical";
}
```

**2. Without [ApiController] — manual ModelState check in MVC**
```csharp
// MVC controller returning a view — check manually
[HttpPost]
[ValidateAntiForgeryToken]
public async Task<IActionResult> Create(CreateProductDto dto)
{
    if (!ModelState.IsValid)
        return View(dto); // re-render form with validation error messages

    await productService.CreateAsync(dto);
    return RedirectToAction(nameof(Index));
}
```

**3. With [ApiController] — automatic 400 before the action runs**
```csharp
// [ApiController] intercepts before Create() is called if ModelState is invalid
// The 400 response body is a ValidationProblemDetails object (RFC 7807)
[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Create(CreateProductDto dto)
    {
        // If you reach here, ModelState.IsValid is guaranteed true
        var created = await productService.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }
}

/* Automatic 400 response body (ValidationProblemDetails):
{
    "type": "https://tools.ietf.org/html/rfc7807",
    "title": "One or more validation errors occurred.",
    "status": 400,
    "errors": {
        "Name":  ["Name is required"],
        "Price": ["Price must be between £0.01 and £100,000"]
    }
}
*/
```

**4. IValidatableObject — cross-property validation**
```csharp
// For rules that span multiple properties — can't be expressed with single-property annotations
public class DateRangeDto : IValidatableObject
{
    [Required]
    public DateOnly StartDate { get; set; }

    [Required]
    public DateOnly EndDate { get; set; }

    public string? Reason { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (EndDate <= StartDate)
            yield return new ValidationResult(
                "End date must be after start date",
                [nameof(EndDate), nameof(StartDate)]);  // associates error with both fields

        if ((EndDate.DayNumber - StartDate.DayNumber) > 365)
            yield return new ValidationResult(
                "Range cannot exceed one year",
                [nameof(EndDate)]);

        // Context gives access to the DI container for service lookups —
        // but prefer FluentValidation for async checks
        var service = context.GetService<IHolidayCalendar>();
        if (service is not null && service.IsBlockedPeriod(StartDate, EndDate))
            yield return new ValidationResult(
                "Selected period overlaps a company closure",
                [nameof(StartDate)]);
    }
}
```

**5. Custom validation attribute — reusable single-property rule**
```csharp
// For a rule that belongs on a type but isn't in the standard library
public class FutureDateAttribute : ValidationAttribute
{
    protected override ValidationResult? IsValid(object? value, ValidationContext context)
    {
        if (value is DateOnly date && date <= DateOnly.FromDateTime(DateTime.Today))
            return new ValidationResult(ErrorMessage ?? "Date must be in the future");

        return ValidationResult.Success;
    }
}

// Usage
public class BookingDto
{
    [Required]
    [FutureDate(ErrorMessage = "Booking date must be in the future")]
    public DateOnly BookingDate { get; set; }
}
```

**6. FluentValidation — complex and async rules in a separate class**
```csharp
// Install: dotnet add package FluentValidation.AspNetCore

// Validators/CreateProductDtoValidator.cs
public class CreateProductDtoValidator : AbstractValidator<CreateProductDto>
{
    public CreateProductDtoValidator(IProductRepository repo)
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required")
            .MaximumLength(200)
            .MustAsync(async (name, ct) => !await repo.ExistsAsync(name, ct))
            .WithMessage("A product with this name already exists");

        RuleFor(x => x.Price)
            .GreaterThan(0)
            .LessThanOrEqualTo(100_000);

        RuleFor(x => x.Stock)
            .GreaterThanOrEqualTo(0);

        // Conditional rule — only validates SupplierEmail if ProductType is physical
        When(x => x.ProductType == "physical", () =>
        {
            RuleFor(x => x.SupplierEmail).NotEmpty().EmailAddress();
        });
    }
}

// Program.cs — register FluentValidation
builder.Services.AddFluentValidationAutoValidation();
builder.Services.AddValidatorsFromAssemblyContaining<CreateProductDtoValidator>();
```

**7. Customising the [ApiController] 400 response format**
```csharp
// Program.cs — override the default ValidationProblemDetails factory
builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(options =>
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
                Message = "Validation failed",
                Errors  = errors
            });
        };
    });
```

**8. Accessing ModelState errors programmatically**
```csharp
[HttpPost]
public IActionResult Create(CreateProductDto dto)
{
    if (!ModelState.IsValid)
    {
        // Flatten all errors into a list of strings for logging or custom response
        var errors = ModelState
            .Where(x => x.Value?.Errors.Count > 0)
            .SelectMany(x => x.Value!.Errors.Select(e =>
                $"{x.Key}: {e.ErrorMessage}"))
            .ToList();

        return BadRequest(new { errors });
    }

    return Ok();
}
```

---

## Real World Example

An HR leave request system where validation has three levels: data annotations for shape (required fields, date format), `IValidatableObject` for business-adjacent rules that can be checked without a database (end after start, not more than 30 days), and FluentValidation for rules that require a service call (checking remaining leave balance). Each level is tested independently.

```csharp
// DTOs/LeaveRequestDto.cs
public class LeaveRequestDto : IValidatableObject
{
    [Required]
    public DateOnly StartDate { get; set; }

    [Required]
    public DateOnly EndDate { get; set; }

    [Required]
    [AllowedValues("annual", "sick", "parental", "unpaid")]
    public string LeaveType { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? Notes { get; set; }

    // Cross-property rules that need no services
    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (EndDate < StartDate)
            yield return new ValidationResult(
                "End date cannot be before start date",
                [nameof(EndDate)]);

        var days = EndDate.DayNumber - StartDate.DayNumber + 1;
        if (days > 30)
            yield return new ValidationResult(
                "A single leave request cannot exceed 30 days. Split into multiple requests.",
                [nameof(EndDate)]);
    }
}

// Validators/LeaveRequestDtoValidator.cs — async rules requiring services
public class LeaveRequestDtoValidator : AbstractValidator<LeaveRequestDto>
{
    public LeaveRequestDtoValidator(
        ILeaveBalanceService  balanceService,
        IHolidayCalendarService calendarService,
        IHttpContextAccessor  httpContextAccessor)
    {
        var employeeId = httpContextAccessor.HttpContext?
            .User.FindFirstValue(ClaimTypes.NameIdentifier);

        RuleFor(x => x)
            .MustAsync(async (dto, ct) =>
            {
                var workingDays = await calendarService.CountWorkingDaysAsync(
                    dto.StartDate, dto.EndDate, ct);
                var balance = await balanceService.GetRemainingAsync(employeeId, dto.LeaveType, ct);
                return balance >= workingDays;
            })
            .WithMessage("Insufficient leave balance for this request")
            .When(x => x.LeaveType == "annual");

        RuleFor(x => x.StartDate)
            .MustAsync(async (date, ct) =>
                !await calendarService.IsBlockedPeriodAsync(date, ct))
            .WithMessage("Leave cannot start during a company closure");
    }
}

// Controllers/LeaveRequestsController.cs
[ApiController]
[Route("api/leave-requests")]
[Authorize]
public class LeaveRequestsController(ILeaveService leaveService) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Submit(LeaveRequestDto dto)
    {
        // [ApiController] + FluentValidation auto-validation means this line
        // is only reached if ALL three validation levels passed
        var request = await leaveService.SubmitAsync(dto, User);
        return CreatedAtAction(nameof(GetById), new { id = request.Id }, request);
    }
}
```

*The key insight: the three validation layers are tested independently. The DTO's `IValidatableObject` tests need no services — just date math. The FluentValidation tests mock `ILeaveBalanceService` and `IHolidayCalendarService`. The controller test can pass a known-valid DTO and focus entirely on the service call and response. No test has to cover all three concerns at once.*

---

## Common Misconceptions

**"ModelState.IsValid false means the data is invalid — I should reject it"**
`ModelState.IsValid` being false means the data failed annotation validation or binding. It doesn't mean the data is necessarily unsafe to inspect — you may want to log it, return the specific errors to the user, or re-render the form. Rejecting without reading `ModelState` errors (i.e. just returning `BadRequest()` with no body) is technically correct but unhelpful to API clients and confusing to users.

**"[Required] ensures the field was sent in the request"**
`[Required]` checks that the value is not null after binding. For a `string` property, a missing query string key and an explicitly sent `null` JSON value both result in `null` — both fail `[Required]`. But an empty string `""` does not fail `[Required]` — if you want to reject empty strings too, add `[MinLength(1)]` or use `[Required(AllowEmptyStrings = false)]`. For nullable types (`int?`), `[Required]` rejects null; for non-nullable value types (`int`), `[Required]` does nothing — the value always has a default.

**"FluentValidation replaces data annotations entirely"**
FluentValidation runs in the same `ModelState` pipeline but does not replace data annotations. You can use both together. The practical recommendation: use data annotations for simple, self-contained constraints that benefit from the generated `data-val-*` client-side attributes (`[Required]`, `[MaxLength]`, `[EmailAddress]`). Use FluentValidation for complex, async, or service-dependent rules. Mixing both on the same class is common and fine.

---

## Gotchas

- **`[Required]` on non-nullable value types (`int`, `bool`, `decimal`) is silently meaningless.** Non-nullable value types always have a value — they can never be null, so `[Required]` has nothing to check. Use `[Range(1, int.MaxValue)]` to enforce a minimum, or use a nullable type (`int?`) with `[Required]` if you need to detect a missing value.

- **`IValidatableObject.Validate()` only runs if all data annotation validation passes first.** The framework runs annotations first; if any annotation fails, `Validate()` is skipped. This means cross-property validation in `IValidatableObject` assumes the individual fields are already valid. Design accordingly — don't assume `StartDate` is non-null inside `Validate()` if it has a `[Required]` annotation that might have failed.

- **With `[ApiController]`, customising the 400 response requires `ConfigureApiBehaviorOptions`.** The auto-400 behaviour uses a default `ValidationProblemDetails` factory. If your API client expects a custom error format, override `InvalidModelStateResponseFactory` in `ConfigureApiBehaviorOptions`. Without this override you can't change the shape of the 400 response from `[ApiController]`.

- **Client-side validation (`data-val-*`) is not generated for FluentValidation rules.** Only data annotations on model properties generate client-side validation attributes via `asp-for`. FluentValidation rules are server-side only. If you want client-side enforcement of a FluentValidation rule, you must duplicate it as a data annotation or write custom JavaScript.

- **Returning `View(model)` after a failed POST doesn't automatically preserve dropdown options.** `ModelState` validation errors are preserved when you return `View(model)` — the error messages render correctly. But any `SelectList` or `IEnumerable<SelectListItem>` properties on the ViewModel are not submitted in POST bodies and will be null. You must re-populate them before returning the view.

- **FluentValidation async validators run in the validation pipeline synchronously in some hosting contexts.** If you use `.MustAsync()` inside a FluentValidation rule and the validator is invoked from a sync context, it can deadlock. Always ensure `AddFluentValidationAutoValidation()` is registered so the async pipeline is used, and never call validators synchronously outside of the MVC pipeline.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between binding errors, annotation validation errors, and business rule failures — and where each layer lives in the pipeline.

**Common question forms:**
- *"How does validation work in ASP.NET Core MVC?"*
- *"What's the difference between [Required] and checking if a value is null in the action?"*
- *"When would you use FluentValidation instead of data annotations?"*

**The depth signal:** A junior answer describes `[Required]`, `[MaxLength]`, and checking `ModelState.IsValid`. A senior answer explains the three-layer pipeline (binding errors → annotation validation → `IValidatableObject`), why `[Required]` on non-nullable value types does nothing, that `IValidatableObject.Validate()` only runs after all annotations pass, what `[ApiController]` does to the pipeline (auto-400 before the action runs), the difference between `ValidationProblemDetails` and a plain `BadRequest`, how `ConfigureApiBehaviorOptions` overrides the auto-400 format, and why FluentValidation rules don't generate client-side attributes. The senior also draws the clear line: annotations and FluentValidation validate shape; business rules belong in the service layer.

**Follow-up questions to expect:**
- *"How do you validate that a product name is unique — is that a validation annotation or a service call?"* (service layer — it's a business rule, not a shape constraint)
- *"What happens when IValidatableObject.Validate() throws an exception?"* (unhandled exception — always yield ValidationResult, never throw inside Validate())

---

## Related Topics

- [[dotnet/mvc/mvc-models.md]] — The DTOs and ViewModels that carry validation annotations; the three model types (entity, DTO, ViewModel) and where validation belongs on each.
- [[dotnet/mvc/mvc-model-binding.md]] — Binding runs before validation; binding errors (type conversion failures) are recorded in `ModelState` before annotations even run.
- [[dotnet/mvc/mvc-controllers.md]] — `[ApiController]` on the controller changes when validation runs and how failures are returned; without it validation is manual.
- [[dotnet/mvc/mvc-views.md]] — `asp-for` generates `data-val-*` attributes for client-side validation; `_ValidationScriptsPartial` loads the JavaScript that reads those attributes.
- [[dotnet/mvc/mvc-tag-helpers.md]] — `asp-validation-for` renders the `<span>` that displays validation error messages; it reads from `ModelState` during view rendering.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/models/validation

---
*Last updated: 2026-04-09*