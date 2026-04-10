# Result Pattern

> A Result type wraps either a success value or an error description, forcing the caller to handle both cases explicitly instead of relying on exceptions for expected failures.

---

## When To Use It

Use it when a failure is an expected, recoverable business outcome — not a bug. Validation failures, not-found lookups, insufficient funds, duplicate registrations: these aren't exceptional; they're part of the domain. Using exceptions for them forces callers to guess which exceptions might be thrown, pollutes stack traces with non-exceptional events, and makes control flow harder to follow. Use exceptions for unexpected failures — infrastructure errors, null references, unrecoverable states — where the caller genuinely can't do anything useful. The dividing line: if a QA engineer would write a test case for the failure, it's a domain result, not an exception.

---

## Core Concept

**One sentence for the interview:** Result makes failure a value you return, not an exception you throw — the compiler forces the caller to handle both the success and failure paths.

A `Result<T>` holds either a `T` (success) or an `Error` (failure). You return it from a method instead of throwing. The caller must inspect the result — they can't accidentally ignore an error the way they can ignore a swallowed exception. The pattern is called railway-oriented programming: the happy path is one rail, the failure path is another, and once you're on the failure rail you stay there unless you explicitly handle it. In C# this is commonly implemented via a discriminated union using `record` types, or via a library (`FluentResults`, `ErrorOr`, `OneOf`). The library question comes up in interviews — the honest answer is that hand-rolling a simple `Result<T>` is fine for small codebases, but a library adds features (multiple errors, error metadata, LINQ-style chaining) that are tedious to maintain yourself.

---

## The Code

```csharp
// 1. Simple hand-rolled Result type
public class Result<T>
{
    public T? Value { get; }
    public string? Error { get; }
    public bool IsSuccess { get; }
    public bool IsFailure => !IsSuccess;

    private Result(T value)
    {
        Value = value;
        IsSuccess = true;
    }

    private Result(string error)
    {
        Error = error;
        IsSuccess = false;
    }

    public static Result<T> Success(T value) => new(value);
    public static Result<T> Failure(string error) => new(error);

    // Implicit conversions for ergonomic call sites
    public static implicit operator Result<T>(T value) => Success(value);
}

// Non-generic Result for operations that return no value on success
public class Result
{
    public string? Error { get; }
    public bool IsSuccess { get; }
    public bool IsFailure => !IsSuccess;

    private Result(bool success, string? error) { IsSuccess = success; Error = error; }

    public static Result Success() => new(true, null);
    public static Result Failure(string error) => new(false, error);
}
```

```csharp
// 2. Richer Error type — structured errors instead of plain strings
public record Error(string Code, string Message, ErrorType Type = ErrorType.Failure)
{
    public static readonly Error None = new(string.Empty, string.Empty, ErrorType.None);
    public static readonly Error NullValue = new("Error.NullValue", "A null value was provided.", ErrorType.Failure);

    public static Error NotFound(string resource, object id) =>
        new($"{resource}.NotFound", $"{resource} with id '{id}' was not found.", ErrorType.NotFound);

    public static Error Validation(string field, string message) =>
        new($"Validation.{field}", message, ErrorType.Validation);

    public static Error Conflict(string message) =>
        new("Error.Conflict", message, ErrorType.Conflict);
}

public enum ErrorType { None, Failure, NotFound, Validation, Conflict }

public class Result<T>
{
    public T? Value { get; }
    public Error Error { get; }
    public bool IsSuccess { get; }
    public bool IsFailure => !IsSuccess;

    private Result(T value) { Value = value; IsSuccess = true; Error = Error.None; }
    private Result(Error error) { Error = error; IsSuccess = false; }

    public static Result<T> Success(T value) => new(value);
    public static Result<T> Failure(Error error) => new(error);
    public static implicit operator Result<T>(T value) => Success(value);
    public static implicit operator Result<T>(Error error) => Failure(error);
}
```

```csharp
// 3. Usage in a service / command handler
public class RegisterUserHandler(IUserRepository users) : IRequestHandler<RegisterUserCommand, Result<int>>
{
    public async Task<Result<int>> Handle(RegisterUserCommand cmd, CancellationToken ct)
    {
        // Each failure returns a Result, not throws an exception
        if (string.IsNullOrWhiteSpace(cmd.Email))
            return Error.Validation("Email", "Email address is required.");

        var existing = await users.FindByEmailAsync(cmd.Email, ct);
        if (existing is not null)
            return Error.Conflict($"A user with email '{cmd.Email}' already exists.");

        EmailAddress email;
        try { email = new EmailAddress(cmd.Email); }
        catch (ArgumentException ex)
        { return Error.Validation("Email", ex.Message); }

        var user = User.Create(email, cmd.Name);
        await users.AddAsync(user, ct);
        await users.SaveChangesAsync(ct);

        return user.Id;                              // implicit conversion to Result<int>.Success
    }
}
```

```csharp
// 4. Handling Result in a controller — mapping Result to HTTP responses
[ApiController]
[Route("api/users")]
public class UsersController(IMediator mediator) : ControllerBase
{
    [HttpPost("register")]
    public async Task<IActionResult> Register(RegisterUserCommand cmd)
    {
        var result = await mediator.Send(cmd);

        return result.IsSuccess
            ? CreatedAtAction(nameof(GetById), new { id = result.Value }, null)
            : result.Error.Type switch
            {
                ErrorType.Validation => BadRequest(result.Error.Message),
                ErrorType.Conflict   => Conflict(result.Error.Message),
                ErrorType.NotFound   => NotFound(result.Error.Message),
                _                    => Problem(result.Error.Message)
            };
    }
}

// Or with a shared extension to avoid repeating the switch everywhere
public static class ResultExtensions
{
    public static IActionResult ToActionResult<T>(
        this Result<T> result, ControllerBase controller) =>
        result.IsSuccess
            ? controller.Ok(result.Value)
            : result.Error.Type switch
            {
                ErrorType.Validation => controller.BadRequest(result.Error.Message),
                ErrorType.Conflict   => controller.Conflict(result.Error.Message),
                ErrorType.NotFound   => controller.NotFound(result.Error.Message),
                _                    => controller.Problem(result.Error.Message)
            };
}
```

```csharp
// 5. Chaining results — railway-oriented programming
public class OrderService(IOrderRepository orders, IPaymentService payments)
{
    public async Task<Result<Order>> PlaceOrderAsync(PlaceOrderDto dto, CancellationToken ct)
    {
        // Each step returns Result — if any fails, short-circuit and return the error
        var validationResult = ValidateDto(dto);
        if (validationResult.IsFailure) return validationResult.Error;

        var paymentResult = await payments.AuthorizeAsync(dto.PaymentToken, dto.Total, ct);
        if (paymentResult.IsFailure) return paymentResult.Error;

        var order = Order.Place(dto.CustomerId, dto.Total);
        await orders.AddAsync(order, ct);
        await orders.SaveChangesAsync(ct);

        return order;                                // implicit Result<Order>.Success
    }

    private static Result<PlaceOrderDto> ValidateDto(PlaceOrderDto dto)
    {
        if (dto.Total <= 0) return Error.Validation("Total", "Total must be positive.");
        if (dto.CustomerId <= 0) return Error.Validation("CustomerId", "CustomerId is required.");
        return dto;                                  // success
    }
}
```

```csharp
// 6. ErrorOr — popular library alternative
// dotnet add package ErrorOr
using ErrorOr;

public class RegisterUserHandler : IRequestHandler<RegisterUserCommand, ErrorOr<int>>
{
    public async Task<ErrorOr<int>> Handle(RegisterUserCommand cmd, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(cmd.Email))
            return Errors.Validation(description: "Email is required.");

        var existing = await _users.FindByEmailAsync(cmd.Email, ct);
        if (existing is not null)
            return Errors.Conflict(description: "Email already registered.");

        // ... create user ...
        return user.Id;                              // implicit success
    }
}

// ErrorOr provides Then/Else chaining, multiple errors, and IActionResult integration
// FluentResults is the other popular option — more verbose but more powerful error metadata
```

---

## Gotchas

- **Result and exceptions solve different problems — don't replace exceptions with Result everywhere.** Infrastructure failures (database down, network timeout, null reference) should still throw — they're not expected business outcomes the caller can recover from meaningfully. Wrapping every method in `Result` including infrastructure calls creates noise that obscures the signal. The pattern earns its cost for domain operations with known failure modes.

- **Implicit conversions from `T` to `Result<T>` can cause surprising behavior.** `return user.Id` working via implicit conversion is ergonomic but requires the compiler to infer the return type correctly. If the return type is ambiguous or the method has overloads, the implicit conversion may not resolve as expected. Be explicit (`return Result<int>.Success(user.Id)`) when implicit conversion causes confusion.

- **Result types that carry multiple errors complicate chaining.** If `RegisterUserCommand` validation produces three errors (empty email, invalid name, missing phone), a single `Error` field loses two of them. Libraries like `FluentResults` and `ErrorOr` support lists of errors — necessary for form validation where you want to surface all failures at once. Hand-rolled `Result<T>` with a single error is fine for command handlers; use a library if you need multi-error collection.

- **Not handling the failure case is still possible — the compiler doesn't prevent `result.Value` on a failure.** Unlike a true discriminated union in F# or Rust, C# `Result<T>` doesn't force you to pattern-match both branches at compile time. You can call `result.Value` on a failure result and get `null` or the default. Add a guard in `Value` that throws if accessed on failure — fail loudly rather than silently returning null.

- **Result types in MediatR handlers change the controller contract.** Every controller action handling a `Result<T>` needs the same `switch` on `ErrorType` to map to HTTP status codes. This gets repetitive. Create a shared extension method or a base controller method once and reuse it — don't write the mapping in every action.

- **Don't use Result for async streams or IEnumerable returns.** A method returning `IAsyncEnumerable<T>` can't meaningfully return a `Result<IAsyncEnumerable<T>>` — the errors may occur mid-stream, not before the first element. Use exceptions for errors in streaming scenarios.

---

## Interview Angle

**What they're really testing:** Whether you understand when exceptions are appropriate vs when errors are domain values, and can articulate the tradeoff between Result types and exception-based error handling.

**Common question form:** *"How do you handle expected failures in your application — do you use exceptions or return types?"* or *"What is railway-oriented programming?"*

**The depth signal:** A junior says "I throw exceptions for errors." A senior distinguishes expected domain failures (validation, not found, conflict — use Result) from unexpected infrastructure failures (database down, null reference — use exceptions), describes the caller ergonomics of Result (can't accidentally ignore the failure path), and knows the library landscape (ErrorOr, FluentResults) and when hand-rolling is sufficient vs when a library adds real value.

**Follow-up the interviewer asks next:** *"How does the Result pattern interact with ASP.NET Core's problem details middleware?"*

ASP.NET Core's `IProblemDetailsService` and `UseExceptionHandler` middleware handle unhandled exceptions and return RFC 9457 problem details responses. The Result pattern operates at a different layer — it handles expected domain failures before they become exceptions. The two compose naturally: your handler returns `Result<T>` for expected failures (mapped to 400/404/409 in the controller), while unhandled exceptions propagate to the middleware which converts them to 500 problem details. Some teams use `IExceptionHandler` (introduced in .NET 8) to catch domain exceptions globally and convert them to problem details responses — a middle ground between the two approaches that avoids the Result type overhead at the cost of losing compile-time visibility of failure paths.

---

## Related Topics

- [[dotnet/pattern/pattern-value-object.md]] — `Result<T>` is itself a value object — immutable, no identity, structurally defined by its success/failure state and value.
- [[dotnet/pattern/pattern-cqrs.md]] — CQRS command handlers are the natural place to return `Result<T>` — the handler runs a domain operation with known failure modes and the controller maps the result to HTTP.
- [[dotnet/pattern/pattern-domain-events.md]] — Domain methods that raise events often return `Result` — the event is only raised on the success path, keeping the domain model clean.
- [[dotnet/webapi/webapi-exception-handling.md]] — Result handles expected failures; exception handling middleware handles unexpected failures — understanding both defines a complete error handling strategy.

---

## Source

https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model

---

*Last updated: 2026-04-09*