# ASP.NET Core Web API Problem Details

> A standardised JSON error response format defined by RFC 7807 that gives API consumers consistent, machine-readable error information instead of ad-hoc error shapes.

---

## Quick Reference

| | |
|---|---|
| **What it is** | RFC 7807 standard error response format for HTTP APIs |
| **Use when** | Any API endpoint that returns error responses — always |
| **Avoid when** | Never avoid — but extend it rather than replacing it with a custom shape |
| **Introduced** | `ProblemDetails` class in ASP.NET Core 2.1; `IProblemDetailsService` in .NET 7 |
| **Namespace** | `Microsoft.AspNetCore.Mvc`, `Microsoft.AspNetCore.Http` |
| **Key types** | `ProblemDetails`, `ValidationProblemDetails`, `IProblemDetailsService`, `IProblemDetailsFactory` |

---

## When To Use It

Use it for every error response in your API — validation failures, not-found, forbidden, server errors, and domain-specific errors. The value of `ProblemDetails` is consistency: every client — mobile app, JavaScript frontend, third-party integration — can handle errors the same way regardless of which endpoint failed. Ad-hoc error shapes (`{ "error": "something went wrong" }`, `{ "message": "...", "code": 42 }`) force every client to handle each endpoint's errors differently, which is the problem RFC 7807 was designed to solve.

---

## Core Concept

RFC 7807 defines a JSON object with five standard fields: `type` (a URI identifying the error kind), `title` (short human-readable summary), `status` (HTTP status code), `detail` (longer human-readable explanation), and `instance` (a URI identifying this specific occurrence). Extensions are allowed — you can add custom fields alongside the standard ones. ASP.NET Core's `ProblemDetails` class implements this structure. `ValidationProblemDetails` extends it with an `errors` dictionary mapping field names to error arrays. `[ApiController]` produces `ValidationProblemDetails` automatically for model validation failures. Since .NET 7, `IProblemDetailsService` unifies how the framework produces problem details across all error paths.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 2.1 | `ProblemDetails` and `ValidationProblemDetails` classes introduced |
| ASP.NET Core 2.1 | `[ApiController]` produces `ValidationProblemDetails` for 400 automatically |
| .NET 5 | `IProblemDetailsFactory` — customise the factory that produces all `ProblemDetails` instances |
| .NET 7 | `IProblemDetailsService` — unified service; `AddProblemDetails()` maps status codes to ProblemDetails |
| .NET 7 | `UseStatusCodePages()` integration — non-exception 404/405 etc. automatically get ProblemDetails bodies |
| .NET 8 | `ProblemDetails` middleware can intercept exceptions and status codes in a single registration |

*Before .NET 7, there was no unified way to ensure all error responses (not just 400 validation errors) returned `ProblemDetails`. A 404 from routing would return an empty body; a 500 from middleware would return the developer exception page. `.AddProblemDetails()` in .NET 7 closed this gap.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `ProblemDetails` serialisation | ~5–20 µs | JSON write via `System.Text.Json` |
| `ValidationProblemDetails` with errors | O(n) | n = number of validation errors |
| `IProblemDetailsService.WriteAsync` | ~10 µs | Service dispatch + JSON write |

**Allocation behaviour:** `ProblemDetails` allocates a dictionary for `Extensions` even when empty. `ValidationProblemDetails` allocates an `Errors` dictionary proportional to the number of invalid fields. For extremely high-volume error paths (e.g., a public endpoint that gets hammered with invalid input), consider caching the JSON for common error shapes.

**Benchmark notes:** Error response performance is never the bottleneck — you should be more concerned with the client receiving a useful error and recovering gracefully than with the microseconds spent serialising the error object.

---

## The Code

**Basic `ProblemDetails` usage in a controller**
```csharp
[HttpGet("{id:int}")]
public async Task<ActionResult<ProductDto>> GetById(int id)
{
    if (id <= 0)
        return Problem(                          // ControllerBase helper method
            title: "Invalid product ID.",
            detail: "Product ID must be a positive integer.",
            statusCode: StatusCodes.Status400BadRequest);

    var product = await _products.GetByIdAsync(id);
    return product is null
        ? NotFound(new ProblemDetails           // explicit NotFound with detail
          {
              Title  = "Product not found.",
              Detail = $"No product exists with ID {id}.",
              Status = 404
          })
        : Ok(product);
}
```

**`ValidationProblemDetails` — the automatic 400 shape from `[ApiController]`**
```csharp
// This is what [ApiController] returns automatically when ModelState.IsValid == false:
// HTTP 400
// Content-Type: application/problem+json
// {
//   "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
//   "title": "One or more validation errors occurred.",
//   "status": 400,
//   "errors": {
//     "Email": ["The Email field is required."],
//     "Age": ["Age must be between 13 and 120."]
//   }
// }

// You can produce the same shape manually:
return ValidationProblem(ModelState);
```

**Adding custom extensions to ProblemDetails**
```csharp
return Problem(
    title: "Payment declined.",
    detail: "The card was declined by the issuing bank.",
    statusCode: 402,
    extensions: new Dictionary<string, object?>
    {
        ["errorCode"]   = "CARD_DECLINED",
        ["traceId"]     = HttpContext.TraceIdentifier,
        ["retryAfter"]  = 0                 // not retriable
    });
```

**`IProblemDetailsService` and `AddProblemDetails()` — .NET 7+**
```csharp
// Program.cs — ensures ALL error responses (not just validation) return ProblemDetails
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = ctx =>
    {
        ctx.ProblemDetails.Extensions["traceId"]   = ctx.HttpContext.TraceIdentifier;
        ctx.ProblemDetails.Extensions["requestId"] =
            Activity.Current?.Id ?? ctx.HttpContext.TraceIdentifier;

        // Suppress internal detail in production
        if (ctx.HttpContext.RequestServices
            .GetRequiredService<IHostEnvironment>().IsProduction())
        {
            ctx.ProblemDetails.Detail = null;
        }
    };
});

app.UseExceptionHandler();      // handles exceptions → ProblemDetails
app.UseStatusCodePages();       // handles 404/405/etc. → ProblemDetails
```

**Custom `IProblemDetailsFactory` — control the factory globally**
```csharp
public class CustomProblemDetailsFactory : ProblemDetailsFactory
{
    private readonly IOptions<ApiBehaviorOptions> _options;

    public CustomProblemDetailsFactory(IOptions<ApiBehaviorOptions> options)
        => _options = options;

    public override ProblemDetails CreateProblemDetails(
        HttpContext httpContext,
        int? statusCode = null,
        string? title = null,
        string? type = null,
        string? detail = null,
        string? instance = null)
    {
        var problemDetails = new ProblemDetails
        {
            Status   = statusCode ?? 500,
            Title    = title,
            Type     = type,
            Detail   = detail,
            Instance = instance ?? httpContext.Request.Path
        };

        // Add trace ID to every problem details instance produced by the factory
        problemDetails.Extensions["traceId"] = httpContext.TraceIdentifier;

        return problemDetails;
    }

    public override ValidationProblemDetails CreateValidationProblemDetails(
        HttpContext httpContext,
        ModelStateDictionary modelStateDictionary,
        int? statusCode = null,
        string? title = null,
        string? type = null,
        string? detail = null,
        string? instance = null)
    {
        var validationProblem = new ValidationProblemDetails(modelStateDictionary)
        {
            Status   = statusCode ?? 400,
            Instance = instance ?? httpContext.Request.Path
        };

        validationProblem.Extensions["traceId"] = httpContext.TraceIdentifier;
        return validationProblem;
    }
}

// Register in Program.cs:
builder.Services.AddSingleton<ProblemDetailsFactory, CustomProblemDetailsFactory>();
```

**Typed `ProblemDetails` subclass for domain errors**
```csharp
// Extend ProblemDetails for domain-specific error types
public class OutOfStockProblemDetails : ProblemDetails
{
    public OutOfStockProblemDetails(string productId, int requested, int available)
    {
        Type     = "https://api.example.com/errors/out-of-stock";
        Title    = "Product out of stock.";
        Status   = StatusCodes.Status422UnprocessableEntity;
        Detail   = $"Requested {requested} units but only {available} available.";
        Extensions["productId"] = productId;
        Extensions["requested"] = requested;
        Extensions["available"] = available;
    }
}

// Usage in controller
return UnprocessableEntity(new OutOfStockProblemDetails(productId, requested, stock));
```

---

## Real World Example

A payment API must return consistent errors across all failure modes: validation failures, business rule violations, and unexpected server errors. A unified `CustomProblemDetailsFactory` ensures trace IDs appear on every error, and typed `ProblemDetails` subclasses document each domain error type.

```csharp
// Typed errors as self-documenting classes
public class PaymentDeclinedProblemDetails : ProblemDetails
{
    public PaymentDeclinedProblemDetails(string declineCode, string traceId)
    {
        Type     = "https://api.example.com/errors/payment-declined";
        Title    = "Payment declined.";
        Status   = 402;
        Detail   = "The payment was declined. Check the decline code and retry with different payment details.";
        Extensions["declineCode"] = declineCode;
        Extensions["traceId"]     = traceId;
        Extensions["retryable"]   = declineCode is "insufficient_funds" or "expired_card";
    }
}

public class DuplicateOrderProblemDetails : ProblemDetails
{
    public DuplicateOrderProblemDetails(string idempotencyKey, string existingOrderId)
    {
        Type     = "https://api.example.com/errors/duplicate-order";
        Title    = "Duplicate order detected.";
        Status   = 409;
        Detail   = "An order with this idempotency key already exists.";
        Extensions["idempotencyKey"]  = idempotencyKey;
        Extensions["existingOrderId"] = existingOrderId;
    }
}

// Controller — clean, typed error returns
[HttpPost]
public async Task<IActionResult> CreateOrder(
    [FromBody] CreateOrderRequest req,
    [FromHeader(Name = "Idempotency-Key")] string? idempotencyKey)
{
    if (idempotencyKey is not null)
    {
        var existing = await _orders.FindByIdempotencyKeyAsync(idempotencyKey);
        if (existing is not null)
            return Conflict(new DuplicateOrderProblemDetails(idempotencyKey, existing.Id.ToString()));
    }

    var result = await _payments.ChargeAsync(req.PaymentToken, req.Total);
    if (!result.Success)
        return StatusCode(402, new PaymentDeclinedProblemDetails(result.DeclineCode, HttpContext.TraceIdentifier));

    var order = await _orders.CreateAsync(req);
    return CreatedAtAction(nameof(GetById), new { id = order.Id }, order);
}
```

*The key insight: each domain error is self-documenting through its `type` URI (which can link to actual documentation) and its custom `Extensions` fields (which give clients enough information to handle the error programmatically). The client can check `declineCode == "expired_card"` and show a specific UI message — without parsing a human-readable `detail` string.*

---

## Common Misconceptions

**"Any JSON object with an `error` field is fine for API errors."**
Ad-hoc error shapes force every consumer to know each endpoint's specific error format. The value of RFC 7807 is the contract: any client that understands `ProblemDetails` can extract `status`, `title`, `detail`, and `extensions` from any compliant API — even one they've never seen before. This matters most for third-party integrations and SDKs.

**"The `type` field should be a human-readable description."**
`type` is a URI — typically a URL that points to documentation for that error type. It should be stable and unique, not a human-readable sentence. `"https://api.example.com/errors/payment-declined"` is a correct `type`. `"Payment was declined by the bank"` is not — that's what `title` is for. The `type` is for machine consumers; `title` and `detail` are for humans.

**"`ValidationProblemDetails` and `ProblemDetails` are the same."**
`ValidationProblemDetails` extends `ProblemDetails` with an `errors` dictionary mapping field names to arrays of error messages. It's the correct type for model validation failures (400). Use plain `ProblemDetails` for all other errors (404, 409, 500). Don't use `ValidationProblemDetails` for non-validation errors just because it has a convenient `errors` field — it conflates validation semantics with other error types.

---

## Gotchas

- **`UseStatusCodePages()` is required to get ProblemDetails on routing-level 404s.** Without it, a request to a route that doesn't exist returns a 404 with an empty body — not a `ProblemDetails` JSON body. `AddProblemDetails()` + `UseStatusCodePages()` together close this gap.

- **The `Content-Type` header must be `application/problem+json`, not `application/json`.** This is part of the RFC 7807 spec. `ControllerBase.Problem()` and the automatic `[ApiController]` validation response set this correctly. If you're returning `ProblemDetails` manually with `return new ObjectResult(...)`, set `ContentTypes = { "application/problem+json" }`.

- **`detail` should not contain internal error information in production.** Exception messages from the framework, database error messages, or stack frames leak infrastructure details to callers. Use `detail` for information specifically crafted for client consumption. Log the internal detail server-side with the trace ID as the correlation key.

- **Extensions dictionary keys shadow standard fields if they collide.** If you add `Extensions["status"] = 999`, the JSON serialiser may produce duplicate `status` fields or silently overwrite the standard one depending on the serialiser version. Use non-colliding keys for extensions.

- **`IProblemDetailsFactory` is not called for all error paths.** It's called by `[ApiController]` and by `IExceptionHandler` integrations — but not by every possible 4xx response. Some middleware (authentication, rate limiting) produce their own responses. Override those via `JwtBearerEvents.OnChallenge`, `RateLimiterOptions.OnRejected`, etc., to ensure consistent ProblemDetails across all error paths.

---

## Interview Angle

**What they're really testing:** Whether you know about RFC 7807, understand why consistent error responses matter for API consumers, and can describe how the framework produces them automatically vs how to customise them.

**Common question forms:**
- "What format do you use for API error responses?"
- "What is RFC 7807 and why does it matter?"
- "How do you add custom fields to error responses in ASP.NET Core?"
- "How do you ensure all error responses (not just validation) return ProblemDetails?"

**The depth signal:** A junior says "I return a JSON object with `message` and `statusCode`." A senior explains RFC 7807 by name, distinguishes `ProblemDetails` from `ValidationProblemDetails`, knows that `[ApiController]` produces the 400 automatically, and can explain how `IProblemDetailsService` (`.AddProblemDetails()`) + `UseStatusCodePages()` ensures even routing-level 404s return a proper ProblemDetails body. They also know the `type` field is a URI (not a human string), and can explain why `Content-Type: application/problem+json` matters for clients that do content negotiation.

**Follow-up questions to expect:**
- "How do you add a trace ID to every error response?"
- "How do you produce ProblemDetails from exception handlers?"
- "How do you ensure authentication failures return ProblemDetails?"

---

## Related Topics

- [[dotnet/webapi/webapi-exception-handling.md]] — exception handlers produce `ProblemDetails`; the two topics are tightly coupled
- [[dotnet/webapi/webapi-model-validation.md]] — `ValidationProblemDetails` is the 400 response shape for validation failures; `[ApiController]` produces it automatically
- [[dotnet/webapi/webapi-controllers.md]] — `ControllerBase.Problem()` and `ValidationProblem()` are the helper methods that produce ProblemDetails from controller actions
- [[dotnet/webapi/webapi-authentication.md]] — 401 and 403 from auth middleware bypass the normal ProblemDetails pipeline; customise via `JwtBearerEvents` to ensure consistent error shapes

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/web-api/handle-errors

---
*Last updated: 2026-04-10*