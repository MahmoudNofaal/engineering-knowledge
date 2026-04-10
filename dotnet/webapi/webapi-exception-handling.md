# ASP.NET Core Web API Exception Handling

> A centralised mechanism for catching unhandled exceptions anywhere in the request pipeline and converting them into consistent, safe HTTP error responses without leaking internal details.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Centralised unhandled exception → HTTP response conversion |
| **Use when** | Every production API — always |
| **Avoid when** | Never avoid — but don't replace middleware with try/catch in every action |
| **Introduced** | ASP.NET Core 1.0 (`UseExceptionHandler`); `IProblemDetailsService` .NET 7 |
| **Namespace** | `Microsoft.AspNetCore.Diagnostics`, `Microsoft.AspNetCore.Mvc` |
| **Key types** | `IExceptionHandler`, `IProblemDetailsService`, `ProblemDetails`, `UseExceptionHandler` |

---

## When To Use It

Use centralised exception handling on every API — the alternative is writing try/catch in every action method and hoping you don't miss one. The goal is a single place where any unhandled exception gets logged, mapped to an appropriate HTTP status code, and serialised into a safe response that doesn't expose stack traces or internal details to the caller. In development you want full detail; in production you want a clean `ProblemDetails` body with a correlation ID and nothing else.

Don't use exception filters (`IExceptionFilter`) as your primary strategy — they only catch exceptions thrown by MVC actions, not exceptions from middleware, result execution, or background work. The middleware approach (`UseExceptionHandler`) catches everything that bubbles up through the pipeline.

---

## Core Concept

When an exception escapes an action method, it travels back up through the middleware pipeline. If nothing catches it, ASP.NET Core returns a 500 with an empty body (or, in development, the developer exception page). `UseExceptionHandler` installs a middleware that wraps the entire inner pipeline in a try/catch — any uncaught exception is re-executed through a designated error-handling route or handler lambda where you control the response shape.

.NET 7 added `IProblemDetailsService` and the `IExceptionHandler` interface, which give you a cleaner, DI-friendly way to map exception types to specific `ProblemDetails` responses without branching inside a single monolithic handler. The pattern is: register one or more `IExceptionHandler` implementations in order; each gets a chance to handle the exception and return `true` to stop the chain or `false` to pass it on. Unhandled exceptions fall through to the built-in fallback which returns a generic 500.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | `UseExceptionHandler(path)` and `UseDeveloperExceptionPage()` introduced |
| ASP.NET Core 2.1 | `UseExceptionHandler(options =>)` lambda overload added |
| .NET 6 | `UseExceptionHandler` can write directly without a re-execute route |
| .NET 7 | `IProblemDetailsService`, `IExceptionHandler` interface, and `AddProblemDetails()` introduced |
| .NET 8 | `IExceptionHandler` chain improved; `ProblemDetails` middleware auto-maps common status codes |

*Before .NET 7, the only structured option was a catch-all handler or an exception filter. `IExceptionHandler` finally makes exception-type routing first-class.*

---

## Performance

| Scenario | Cost | Notes |
|---|---|---|
| Happy path (no exception) | Zero | Exception handling middleware has no overhead when no exception occurs |
| Exception caught by middleware | High (exceptions are expensive) | Stack unwinding, re-execution through error route — but this is exceptional by definition |
| `IExceptionHandler` chain | Negligible | Simple interface dispatch; only runs on exception |

**Allocation behaviour:** Exception handling itself allocates heavily (stack trace capture, re-execution). This is expected and unavoidable — optimise for clarity and correctness, not allocation, in the exception path.

**Benchmark notes:** The performance of your error handler doesn't matter in practice. Exceptions should be rare. If you're seeing enough exceptions to worry about handler overhead, the exception rate itself is the problem.

---

## The Code

**Basic setup — development vs production split**
```csharp
// Program.cs
var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    // Full stack trace, exception type, request details in the browser
    app.UseDeveloperExceptionPage();
}
else
{
    // Safe fallback: logs the exception, returns a generic error response
    app.UseExceptionHandler("/error");
}

// The error endpoint — reached via internal re-execute, not a real HTTP request
app.Map("/error", (HttpContext ctx) =>
{
    var feature = ctx.Features.Get<IExceptionHandlerFeature>();
    var exception = feature?.Error;
    // exception is available here for logging — but don't return it to the client
    return Results.Problem(title: "An error occurred.", statusCode: 500);
});
```

**Inline handler (no separate route needed — .NET 6+)**
```csharp
app.UseExceptionHandler(errApp =>
{
    errApp.Run(async context =>
    {
        var feature   = context.Features.Get<IExceptionHandlerFeature>();
        var exception = feature?.Error;

        var (statusCode, title) = exception switch
        {
            KeyNotFoundException    => (404, "Resource not found."),
            UnauthorizedAccessException => (403, "Access denied."),
            ArgumentException       => (400, "Invalid argument."),
            _                       => (500, "An unexpected error occurred.")
        };

        context.Response.StatusCode  = statusCode;
        context.Response.ContentType = "application/problem+json";

        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = statusCode,
            Title  = title,
            // Never expose exception.Message or StackTrace in production
        });
    });
});
```

**`IExceptionHandler` — .NET 7+ preferred pattern**
```csharp
// Handlers are tried in registration order.
// Return true = handled, stop chain. Return false = pass to next handler.

public class NotFoundExceptionHandler : IExceptionHandler
{
    private readonly ILogger<NotFoundExceptionHandler> _logger;

    public NotFoundExceptionHandler(ILogger<NotFoundExceptionHandler> logger)
        => _logger = logger;

    public async ValueTask<bool> TryHandleAsync(
        HttpContext context,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not KeyNotFoundException) return false;   // not mine — pass on

        _logger.LogWarning(exception, "Resource not found.");

        context.Response.StatusCode = StatusCodes.Status404NotFound;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = 404,
            Title  = "Resource not found.",
            Detail = exception.Message  // safe — KeyNotFoundException messages are controlled
        }, cancellationToken);

        return true;
    }
}

public class ValidationExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext context,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not ValidationException vex) return false;

        context.Response.StatusCode = StatusCodes.Status400BadRequest;
        await context.Response.WriteAsJsonAsync(new ValidationProblemDetails(vex.Errors)
        {
            Status = 400,
            Title  = "Validation failed."
        }, cancellationToken);

        return true;
    }
}

// Registration in Program.cs:
builder.Services.AddExceptionHandler<NotFoundExceptionHandler>();
builder.Services.AddExceptionHandler<ValidationExceptionHandler>();
builder.Services.AddProblemDetails();   // registers the fallback 500 handler

app.UseExceptionHandler();   // no path needed — IExceptionHandler chain runs automatically
```

**Adding a correlation ID for traceability**
```csharp
public class GlobalExceptionHandler : IExceptionHandler
{
    private readonly ILogger<GlobalExceptionHandler> _logger;

    public GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger)
        => _logger = logger;

    public async ValueTask<bool> TryHandleAsync(
        HttpContext context,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var traceId = Activity.Current?.Id ?? context.TraceIdentifier;

        _logger.LogError(exception,
            "Unhandled exception. TraceId: {TraceId}", traceId);

        context.Response.StatusCode = StatusCodes.Status500InternalServerError;

        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status   = 500,
            Title    = "An unexpected error occurred.",
            Extensions = { ["traceId"] = traceId }
            // traceId lets the caller cross-reference your logs without exposing exception details
        }, cancellationToken);

        return true;  // always handle — this is the catch-all
    }
}
```

**Exception filter — use for MVC-specific concerns only**
```csharp
// IExceptionFilter only catches exceptions from MVC actions.
// Use for concerns that genuinely belong in the MVC layer (e.g. auditing action failures).
// Do NOT use as your primary exception handling strategy.

public class AuditExceptionFilter : IAsyncExceptionFilter
{
    private readonly IAuditLog _audit;

    public AuditExceptionFilter(IAuditLog audit) => _audit = audit;

    public async Task OnExceptionAsync(ExceptionContext context)
    {
        await _audit.RecordFailureAsync(
            context.ActionDescriptor.DisplayName,
            context.Exception);

        // Do NOT set context.ExceptionHandled = true here
        // unless you also set context.Result — let the middleware handle the response
    }
}

// Register globally:
builder.Services.AddControllers(opts => opts.Filters.Add<AuditExceptionFilter>());
builder.Services.AddScoped<AuditExceptionFilter>();
```

---

## Real World Example

An e-commerce API uses a custom domain exception hierarchy (`DomainException`, `NotFoundException`, `ConflictException`) thrown from the service layer. The exception handlers map these to correct HTTP status codes and `ProblemDetails` bodies, with a correlation ID on every response for support tracing. The catch-all handler suppresses all internal detail in production but logs the full exception with the trace ID.

```csharp
// Domain exceptions — thrown from service layer
public abstract class DomainException(string message) : Exception(message);
public class NotFoundException(string resource, object id)
    : DomainException($"{resource} with id '{id}' was not found.");
public class ConflictException(string message) : DomainException(message);
public class BusinessRuleException(string rule, string message) : DomainException(message)
{
    public string Rule { get; } = rule;
}

// Handler for domain exceptions — maps each type to the correct status code
public class DomainExceptionHandler(ILogger<DomainExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext context,
        Exception exception,
        CancellationToken ct)
    {
        if (exception is not DomainException domain) return false;

        var (status, title) = domain switch
        {
            NotFoundException     => (404, "Resource not found."),
            ConflictException     => (409, "Conflict."),
            BusinessRuleException => (422, "Business rule violation."),
            _                     => (400, "Domain error.")
        };

        logger.LogWarning(exception, "Domain exception: {Type}", exception.GetType().Name);

        context.Response.StatusCode = status;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status  = status,
            Title   = title,
            Detail  = domain.Message,           // safe — controlled by our own code
            Extensions =
            {
                ["traceId"] = Activity.Current?.Id ?? context.TraceIdentifier
            }
        }, ct);

        return true;
    }
}

// Catch-all for anything that isn't a domain exception
public class FallbackExceptionHandler(ILogger<FallbackExceptionHandler> logger) : IExceptionHandler
{
    private readonly bool _isDev =
        Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") == "Development";

    public async ValueTask<bool> TryHandleAsync(
        HttpContext context,
        Exception exception,
        CancellationToken ct)
    {
        var traceId = Activity.Current?.Id ?? context.TraceIdentifier;

        logger.LogError(exception, "Unhandled exception. TraceId: {TraceId}", traceId);

        context.Response.StatusCode = 500;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status  = 500,
            Title   = "An unexpected error occurred.",
            Detail  = _isDev ? exception.ToString() : null,  // detail only in dev
            Extensions = { ["traceId"] = traceId }
        }, ct);

        return true;
    }
}

// Program.cs
builder.Services.AddExceptionHandler<DomainExceptionHandler>();
builder.Services.AddExceptionHandler<FallbackExceptionHandler>();
builder.Services.AddProblemDetails();
app.UseExceptionHandler();
```

*The key insight: the service layer throws semantically meaningful exceptions (`NotFoundException`, `ConflictException`) without knowing anything about HTTP. The exception handlers are the single translation layer between domain language and HTTP status codes — and they live in one file, not scattered across 40 controllers.*

---

## Common Misconceptions

**"I should wrap every action in try/catch to handle errors."**
This is the most common mistake. Per-action try/catch duplicates logic, is easy to forget on new actions, and produces inconsistent error shapes. Centralise exception handling in middleware and let exceptions propagate naturally. The only try/catch inside an action should be for genuinely local recovery (retry a transient operation, fall back to a default) — not for shaping error responses.

**"UseExceptionHandler catches everything — I don't need exception filters."**
`UseExceptionHandler` catches exceptions that reach the middleware layer. But exception filters (`IExceptionFilter`) run inside the MVC pipeline, before the response is committed, and have access to action metadata like the controller name and action descriptor. They're the right tool for concerns like auditing which specific action failed — not for shaping the HTTP response, which belongs in middleware.

**"I should return the exception message in the response so clients know what went wrong."**
`exception.Message` from system exceptions (SQL errors, null references, file not found) often contains internal details: table names, file paths, server names. Return it only for exceptions your own code throws with messages specifically designed for client consumption. For everything else, return a generic title and log the detail server-side with a trace ID the client can reference.

```csharp
// WRONG — leaks internal detail
Detail = exception.Message   // "Invalid object name 'dbo.Orders'" — reveals DB schema

// RIGHT — safe for controlled exceptions only
Detail = exception is DomainException ? exception.Message : null
```

---

## Gotchas

- **`UseExceptionHandler` must be the first middleware registered.** It wraps everything that comes after it. If you register it after `UseRouting` or `UseAuthentication`, exceptions thrown by those middleware components are not caught. The developer exception page (`UseDeveloperExceptionPage`) has the same requirement.

- **401 and 403 responses from auth middleware bypass exception handlers entirely.** Authentication and authorization rejections are not exceptions — they're deliberate responses set by middleware. If you want to customise the shape of 401/403 responses, handle them in `JwtBearerOptions.Events.OnChallenge` / `OnForbidden`, not in your exception handler.

- **Once the response has started (headers sent), you cannot change the status code.** If an exception occurs after `context.Response.Body` has been written to, `UseExceptionHandler` logs the exception but cannot change the response — the client already received a 200 header. This happens most often with streaming responses. Guard against it by checking `context.Response.HasStarted` and logging a warning rather than trying to write a new response.

- **`IExceptionHandler` registrations are tried in registration order — put specific handlers before the catch-all.** If your `FallbackExceptionHandler` returns `true` for everything, any handlers registered after it are dead code. Register from most-specific to least-specific. This is the same principle as catch blocks.

- **Exception filters don't run for exceptions thrown outside MVC.** Middleware exceptions, result execution exceptions, and exceptions from `IActionResult.ExecuteResultAsync` all bypass `IExceptionFilter`. Teams that rely solely on exception filters for "global" error handling discover this in production when a middleware throws and returns a raw 500 with no response body.

- **`AddProblemDetails()` without `UseExceptionHandler()` does nothing for exceptions.** `AddProblemDetails` configures status code mapping and `IProblemDetailsService` but does not install exception handling middleware. You need both. The common mistake is calling `AddProblemDetails()` and expecting 404/500 responses to automatically become `ProblemDetails` — that requires `UseStatusCodePages()` and `UseExceptionHandler()` as well.

---

## Interview Angle

**What they're really testing:** Whether you know the difference between the middleware-level and MVC-level exception handling approaches, where each is appropriate, and how to produce consistent, safe error responses that don't leak internal information.

**Common question forms:**
- "How do you handle exceptions globally in ASP.NET Core?"
- "What's the difference between `UseExceptionHandler` and `IExceptionFilter`?"
- "How do you map domain exceptions to HTTP status codes?"
- "How would you ensure stack traces never reach the client in production?"

**The depth signal:** A junior says "I use try/catch in my actions and return `BadRequest()`." A senior explains the `UseExceptionHandler` middleware approach, knows that `IExceptionHandler` (.NET 7+) gives you a chain of handlers ordered by registration, understands that auth failures are not exceptions and need separate handling, knows that `ProblemDetails` (RFC 7807) is the correct response format for API errors, and can explain why you should never return `exception.Message` directly — and how a trace ID bridges the gap between a safe client response and a detailed server log.

**Follow-up questions to expect:**
- "How do you include a correlation ID in error responses without exposing the stack trace?"
- "What happens if an exception is thrown after the response has started?"
- "How would you handle a FluentValidation exception differently from a database exception?"

---

## Related Topics

- [[dotnet/webapi/middleware-pipeline.md]] — `UseExceptionHandler` is middleware; its position at the top of the pipeline is what allows it to catch everything below it
- [[dotnet/webapi/webapi-problem-details.md]] — `ProblemDetails` is the RFC 7807 response format that exception handlers should produce; understanding its shape is prerequisite to writing consistent error responses
- [[dotnet/webapi/webapi-logging.md]] — exception handlers are where you log the full exception with context; the logging and exception handling layers are tightly coupled
- [[dotnet/webapi/webapi-filters.md]] — `IExceptionFilter` is the MVC-layer alternative for action-scoped exception handling; knowing when to use filters vs middleware is the key distinction

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling

---
*Last updated: 2026-04-10*