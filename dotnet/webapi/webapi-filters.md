# ASP.NET Core Web API Filters

> Filters are hooks that run code at specific points in the request pipeline around your action methods — before, after, or instead of them.

---

## Quick Reference

| | |
|---|---|
| **What it is** | MVC-layer hooks that run around action method execution |
| **Use when** | Cross-cutting concerns scoped to controller actions: logging, auditing, caching headers, custom auth |
| **Avoid when** | Concerns that apply outside MVC (static files, WebSockets) — use middleware instead |
| **Introduced** | ASP.NET Core 1.0 |
| **Namespace** | `Microsoft.AspNetCore.Mvc.Filters` |
| **Key types** | `IActionFilter`, `IAsyncActionFilter`, `IExceptionFilter`, `IResultFilter`, `IResourceFilter`, `IAuthorizationFilter` |

---

## When To Use It

Use filters for cross-cutting concerns that apply to multiple endpoints: logging, exception handling, caching response headers, enforcing custom authorization rules, or auditing. They're the correct alternative to duplicating that logic in every action. Don't use filters when middleware is a better fit — if the concern applies to every request regardless of whether it reaches a controller (rate limiting, HTTPS redirection, CORS), it belongs in middleware. Filters only run when the routing system has selected an endpoint; middleware runs unconditionally.

---

## Core Concept

Filters slot into the MVC pipeline at fixed points, forming their own mini-pipeline inside the main middleware chain. There are five kinds: authorization filters run first and can short-circuit the request; resource filters wrap the entire action including model binding; action filters run immediately before and after the action method; exception filters catch unhandled exceptions thrown by the action; result filters run around the `IActionResult` execution. Each has a sync interface and an async one — use async when your filter does I/O. Filters can be applied as attributes on an action or controller, registered globally for all controllers, or injected via DI using `ServiceFilter` or `TypeFilter`.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | All five filter types introduced |
| ASP.NET Core 1.0 | `ServiceFilter`, `TypeFilter` for DI-resolved filters |
| ASP.NET Core 2.1 | `ModelStateInvalidFilter` added — the `[ApiController]` automatic 400 filter (order -2000) |
| .NET 6 | `IEndpointFilter` introduced for minimal APIs — equivalent of action filter outside MVC |
| .NET 7 | `IAlwaysRunResultFilter` improvements |

*`IEndpointFilter` in .NET 6 brought filter-like behaviour to minimal APIs without the full MVC filter pipeline. The two systems are separate — `IActionFilter` does not apply to minimal API endpoints and vice versa.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Filter pipeline dispatch | ~1–5 µs per filter | Virtual call overhead; negligible |
| Global filter evaluation | O(n) | n = number of global filters |
| `ServiceFilter` resolution | ~1 µs | DI scope lookup per request |
| Short-circuit via `context.Result` | O(1) | Stops further pipeline execution |

**Allocation behaviour:** Class-based filters registered as scoped allocate one instance per request. Attribute-based filters (inheriting `ActionFilterAttribute`) are allocated once and reused — they must be stateless. `ServiceFilter` and `TypeFilter` allocate per resolve depending on the registered lifetime.

**Benchmark notes:** Filter overhead is unmeasurable compared to any I/O. The only scenario where filter count matters is hundreds of global filters — which is a design problem, not a performance tuning problem.

---

## The Code

**Action filter — log execution time for any action**
```csharp
public class TimingFilter : IAsyncActionFilter
{
    private readonly ILogger<TimingFilter> _logger;

    public TimingFilter(ILogger<TimingFilter> logger) => _logger = logger;

    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        var sw = Stopwatch.StartNew();

        var executed = await next();    // runs the action (and any inner filters)

        sw.Stop();

        if (executed.Exception is not null)
            _logger.LogWarning("Action {Action} threw after {Ms}ms",
                context.ActionDescriptor.DisplayName, sw.ElapsedMilliseconds);
        else
            _logger.LogInformation("Action {Action} completed in {Ms}ms",
                context.ActionDescriptor.DisplayName, sw.ElapsedMilliseconds);
    }
}

// Global registration (needs DI):
builder.Services.AddControllers(options => options.Filters.Add<TimingFilter>());
builder.Services.AddScoped<TimingFilter>();
```

**Attribute-based action filter — no DI dependencies**
```csharp
[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class)]
public class RequireHttpsHeaderAttribute : ActionFilterAttribute
{
    public override void OnActionExecuting(ActionExecutingContext context)
    {
        if (!context.HttpContext.Request.IsHttps)
        {
            context.Result = new StatusCodeResult(StatusCodes.Status400BadRequest);
            // Setting context.Result short-circuits — the action does not run
        }
    }
}

[RequireHttpsHeader]
[HttpPost("secure")]
public IActionResult SecureEndpoint() => Ok();
```

**Exception filter — catch unhandled action exceptions**
```csharp
public class GlobalExceptionFilter : IAsyncExceptionFilter
{
    private readonly ILogger<GlobalExceptionFilter> _logger;

    public GlobalExceptionFilter(ILogger<GlobalExceptionFilter> logger)
        => _logger = logger;

    public Task OnExceptionAsync(ExceptionContext context)
    {
        _logger.LogError(context.Exception, "Unhandled exception in action");

        context.Result = new ObjectResult(new ProblemDetails
        {
            Status = 500,
            Title  = "An unexpected error occurred."
        })
        { StatusCode = 500 };

        context.ExceptionHandled = true;    // prevents further propagation
        return Task.CompletedTask;
    }
}
```

**Result filter — add a response header after every action**
```csharp
public class AddCorrelationHeaderFilter : IResultFilter
{
    public void OnResultExecuting(ResultExecutingContext context)
    {
        context.HttpContext.Response.Headers["X-Correlation-Id"] =
            context.HttpContext.TraceIdentifier;
    }

    public void OnResultExecuted(ResultExecutedContext context) { }
}
```

**Resource filter — wraps the entire action including model binding**
```csharp
// Resource filters run before model binding — useful for short-circuiting expensive pipelines
public class CacheResourceFilter : IAsyncResourceFilter
{
    private readonly IMemoryCache _cache;

    public CacheResourceFilter(IMemoryCache cache) => _cache = cache;

    public async Task OnResourceExecutionAsync(
        ResourceExecutingContext context,
        ResourceExecutionDelegate next)
    {
        var key = context.HttpContext.Request.Path + context.HttpContext.Request.QueryString;

        if (_cache.TryGetValue(key, out IActionResult? cached))
        {
            context.Result = cached;    // short-circuit before model binding
            return;
        }

        var executed = await next();    // model binding + action runs

        if (executed.Result is OkObjectResult ok)
            _cache.Set(key, ok, TimeSpan.FromMinutes(5));
    }
}
```

**ServiceFilter vs TypeFilter**
```csharp
// ServiceFilter — resolves the filter from DI (filter must be registered)
builder.Services.AddScoped<TimingFilter>();

[ServiceFilter(typeof(TimingFilter))]
[ApiController]
public class OrdersController : ControllerBase { }

// TypeFilter — creates the filter itself (useful for passing constructor args)
[TypeFilter(typeof(CustomFilter), Arguments = new object[] { "arg1" })]
public IActionResult Create() => Ok();
```

**`IEndpointFilter` for minimal APIs (.NET 6+)**
```csharp
public class TimingEndpointFilter : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext ctx,
        EndpointFilterDelegate next)
    {
        var sw     = Stopwatch.StartNew();
        var result = await next(ctx);
        sw.Stop();
        Console.WriteLine($"{ctx.HttpContext.Request.Path} took {sw.ElapsedMilliseconds}ms");
        return result;
    }
}

app.MapGet("/api/slow", async (ISlowService svc) => Results.Ok(await svc.RunAsync()))
   .AddEndpointFilter<TimingEndpointFilter>();
```

---

## Real World Example

A financial API must audit every state-changing action: who called it, what parameters were passed, whether it succeeded or failed, and how long it took. An `AuditFilter` runs around every POST/PUT/DELETE action, logging to an `IAuditLog` service regardless of success or failure.

```csharp
[AttributeUsage(AttributeTargets.Method)]
public class AuditAttribute : Attribute { }  // marker — no logic here

public class AuditActionFilter : IAsyncActionFilter
{
    private readonly IAuditLog _audit;
    private readonly ILogger<AuditActionFilter> _logger;

    public AuditActionFilter(IAuditLog audit, ILogger<AuditActionFilter> logger)
    {
        _audit  = audit;
        _logger = logger;
    }

    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        // Only audit actions decorated with [Audit]
        var hasAudit = context.ActionDescriptor.EndpointMetadata
            .OfType<AuditAttribute>().Any();
        if (!hasAudit) { await next(); return; }

        var userId    = context.HttpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);
        var action    = context.ActionDescriptor.DisplayName;
        var sw        = Stopwatch.StartNew();

        var executed  = await next();

        sw.Stop();

        var entry = new AuditEntry
        {
            UserId      = userId,
            Action      = action,
            Parameters  = JsonSerializer.Serialize(context.ActionArguments),
            Success     = executed.Exception is null,
            DurationMs  = sw.ElapsedMilliseconds,
            StatusCode  = (executed.Result as ObjectResult)?.StatusCode ?? 200,
            Timestamp   = DateTimeOffset.UtcNow
        };

        await _audit.RecordAsync(entry);

        if (executed.Exception is not null)
            _logger.LogWarning("Audited action {Action} failed for user {UserId}",
                action, userId);
    }
}

// Register globally
builder.Services.AddControllers(opts => opts.Filters.Add<AuditActionFilter>());
builder.Services.AddScoped<AuditActionFilter>();
builder.Services.AddScoped<IAuditLog, DatabaseAuditLog>();

// Usage on a controller action
[HttpDelete("{id:guid}")]
[Authorize(Roles = "Admin")]
[Audit]                             // opt-in auditing for this action
public async Task<IActionResult> Delete(Guid id) { ... }
```

*The key insight: the audit filter checks for the `[Audit]` marker at runtime, so it can be registered globally but only activates for actions that opt in. The filter captures parameters, duration, success, and user identity in one place — no auditing code in any controller.*

---

## Common Misconceptions

**"Filters and middleware do the same thing."**
They run at different pipeline levels. Middleware wraps the entire HTTP pipeline — it runs for static files, WebSockets, health checks, and anything else, before routing selects an action. Filters run inside the MVC layer, after routing has selected an action, and have access to action metadata (`ActionDescriptor`, `ModelState`, `ActionArguments`). The wrong placement causes bugs: exception filters don't catch middleware exceptions; middleware can't access `ModelState`.

**"Setting `context.Result` in an action filter short-circuits everything."**
Setting `context.Result` in `OnActionExecuting` skips the action method and model binding. But it does NOT skip result filters or the `OnActionExecuted` phase of outer action filters. If you need to skip result filters too, use a resource filter — it's the only filter type that wraps the entire inner pipeline including result execution.

**"Exception filters handle all unhandled exceptions."**
`IExceptionFilter` catches exceptions thrown by MVC action methods and result execution. It does NOT catch exceptions from middleware, from background tasks, or from `IActionResult.ExecuteResultAsync` in some cases. For truly global exception handling, use `UseExceptionHandler` middleware in addition to exception filters.

---

## Gotchas

- **Setting `context.Result` in `OnActionExecuting` short-circuits the action but still runs `OnResultExecuting` on result filters and `OnActionExecuted` on outer action filters.** It does not skip all remaining filters. Use a resource filter if you need to bypass result filters too.

- **Exception filters don't catch exceptions from result execution.** An exception thrown inside `IActionResult.ExecuteResultAsync` propagates to middleware. For complete exception coverage use both `IExceptionFilter` and `UseExceptionHandler` middleware.

- **`ActionFilterAttribute` requires calling `next` or setting `context.Result` on every code path.** In async filters, if you take a branch without setting `context.Result` and without calling `await next()`, the framework throws `InvalidOperationException`. Every code path must do one or the other.

- **Filters registered globally have singleton behaviour if registered incorrectly.** Registering a filter via `options.Filters.Add<MyFilter>()` and `MyFilter` depends on a scoped service injected into the constructor results in a captive dependency. Use `options.Filters.Add(new ServiceFilterAttribute(typeof(MyFilter)))` instead so DI resolves it per request.

- **Authorization filters run before model binding.** `context.ActionArguments` is empty in an authorization filter — binding hasn't run yet. Use a resource filter or an `IAuthorizationHandler` with `IAuthorizationService` if you need to authorize based on request body content.

- **`IEndpointFilter` (minimal APIs) is NOT interchangeable with `IActionFilter` (MVC).** They serve the same conceptual role but are completely separate interfaces in different parts of the pipeline. An `IActionFilter` registered globally does not apply to minimal API endpoints.

---

## Interview Angle

**What they're really testing:** Whether you understand the MVC filter pipeline and can distinguish it from middleware — and whether you know which filter type to reach for for a given cross-cutting concern.

**Common question forms:**
- "How would you log execution time for all API actions?"
- "Where would you put global exception handling — middleware or filters?"
- "What's the difference between a filter and middleware?"
- "What's the execution order of the five filter types?"

**The depth signal:** A junior knows `[ServiceFilter]` applies a filter and that there are action and exception filters. A senior can draw the full execution order (Authorization → Resource → Model Binding → Action → Exception → Result), explain that `IResourceFilter` is the only filter type that wraps model binding, knows that short-circuiting in `OnActionExecuting` still executes `OnResultExecuting`, and can explain that middleware is the better choice when the concern applies outside MVC. They also know `ModelStateInvalidFilter` is the built-in action filter (order `-2000`) that produces the automatic 400 from `[ApiController]`.

**Follow-up questions to expect:**
- "How do you apply a filter to only specific controllers without repeating the attribute?"
- "What's the difference between `ServiceFilter` and `TypeFilter`?"
- "How do you write a filter equivalent for minimal API endpoints?"

---

## Related Topics

- [[dotnet/webapi/middleware-pipeline.md]] — middleware and filters solve similar problems at different pipeline levels; knowing when each applies prevents misplacing logic
- [[dotnet/webapi/webapi-model-validation.md]] — `ModelStateInvalidFilter` is itself an action filter at order `-2000`; knowing filter order explains why it fires before user-defined action filters
- [[dotnet/webapi/webapi-exception-handling.md]] — exception filters catch MVC-level exceptions; `UseExceptionHandler` middleware catches everything else — both are needed for full coverage
- [[dotnet/webapi/webapi-minimal-apis.md]] — `IEndpointFilter` is the minimal API equivalent of `IActionFilter`; same conceptual position in the pipeline, different interface and registration

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/filters

---
*Last updated: 2026-04-10*