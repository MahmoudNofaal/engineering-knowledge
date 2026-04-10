# MVC Action Filters

> Attributes or classes that run code before and after controller action methods execute — used to handle cross-cutting concerns like logging, authorisation, caching, and request validation without duplicating that logic inside every action.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Hooks that run around action method execution in the MVC pipeline |
| **Use when** | Logic must run on multiple actions without being duplicated in each one |
| **Avoid when** | Logic should run on every request — use middleware instead |
| **Namespace** | `Microsoft.AspNetCore.Mvc.Filters` |
| **Key interfaces** | `IActionFilter`, `IAsyncActionFilter`, `IResultFilter`, `IExceptionFilter`, `IAuthorizationFilter` |
| **Scope** | Global → Controller → Action (applied and executed in this order) |

---

## When To Use It

Use action filters when cross-cutting logic is specific to MVC actions — it needs access to action parameters, the selected controller, or the action result. Good candidates are logging that includes the action name, permission checks that depend on the controller's route, response transformation that needs the action's return value, or timing metrics per endpoint. Don't use filters for logic that should run on every request regardless of whether it's an MVC action — use middleware instead. Middleware runs before routing; filters run after an action has been selected. If your filter would apply to every single action in the entire app, it probably belongs in middleware.

---

## Core Concept

Filters form a pipeline around the action execution. For a single action call, the execution order is: Authorization filters → Resource filters → Model binding → Action filters → Action executes → Result filters → Result executes → Exception filters (on error). Each filter type has an "executing" hook (before) and an "executed" hook (after).

Filters can be applied at three scopes: globally (all actions in the app), at the controller level (all actions in that controller), or at the individual action level. When the same filter type is registered at multiple scopes, global filters run first, then controller-level, then action-level. This nested order applies to `OnActionExecuting`; for `OnActionExecuted`, it reverses — action-level first, then controller, then global.

There are two ways to apply a filter that needs services from the DI container: `[ServiceFilter(typeof(MyFilter))]` resolves the filter from the DI container (the filter must be registered as a service), and `[TypeFilter(typeof(MyFilter))]` instantiates the filter using DI-resolved constructor arguments without requiring the filter itself to be registered. `[TypeFilter]` is more convenient; `[ServiceFilter]` is the right choice when you want the filter to be a scoped or singleton service with controlled lifetime.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | Filter pipeline introduced; `IActionFilter`, `IResultFilter`, `IExceptionFilter`, `IAuthorizationFilter` |
| ASP.NET Core 1.0 | .NET Core 1.0 | `ServiceFilter` and `TypeFilter` attributes for DI-aware filter application |
| ASP.NET Core 1.1 | .NET Core 1.1 | `IAlwaysRunResultFilter` introduced for filters that must run even when an action is short-circuited |
| ASP.NET Core 2.0 | .NET Core 2.0 | `IAsyncActionFilter`, `IAsyncResultFilter`, `IAsyncExceptionFilter` async variants |
| ASP.NET Core 3.0 | .NET Core 3.0 | `IFilterFactory` interface for filters that create other filters at runtime |
| ASP.NET Core 6.0 | .NET 6 | Endpoint filters introduced for Minimal APIs (`IEndpointFilter`) — separate from MVC filters |
| ASP.NET Core 7.0 | .NET 7 | `IExceptionHandler` interface added as an alternative to exception filters for global error handling |

*Before ASP.NET Core, ASP.NET MVC 5 had a similar filter system but exception filters were unreliable — exceptions from result execution weren't always caught. ASP.NET Core's unified pipeline fixed this, and the addition of middleware (`UseExceptionHandler`) gave a cleaner global exception handling option that many apps prefer over exception filters.*

---

## The Code

**1. Synchronous action filter**
```csharp
// Filters/LogActionFilter.cs
public class LogActionFilter : IActionFilter
{
    private readonly ILogger<LogActionFilter> _logger;

    public LogActionFilter(ILogger<LogActionFilter> logger)
        => _logger = logger;

    // Runs before the action executes — action arguments are available
    public void OnActionExecuting(ActionExecutingContext context)
    {
        _logger.LogInformation(
            "Executing {Controller}.{Action} with arguments: {@Arguments}",
            context.RouteData.Values["controller"],
            context.RouteData.Values["action"],
            context.ActionArguments);
    }

    // Runs after the action executes — the result is available
    public void OnActionExecuted(ActionExecutedContext context)
    {
        if (context.Exception is not null)
            _logger.LogError(context.Exception, "Action threw an exception");
        else
            _logger.LogInformation("Action completed with result: {Result}",
                context.Result?.GetType().Name);
    }
}
```

**2. Async action filter**
```csharp
// Filters/RequestTimingFilter.cs
public class RequestTimingFilter : IAsyncActionFilter
{
    private readonly ILogger<RequestTimingFilter> _logger;

    public RequestTimingFilter(ILogger<RequestTimingFilter> logger)
        => _logger = logger;

    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        var stopwatch = Stopwatch.StartNew();

        // Call next() to execute the action (and subsequent filters)
        var executed = await next();

        stopwatch.Stop();

        var controller = context.RouteData.Values["controller"];
        var action     = context.RouteData.Values["action"];

        _logger.LogInformation("{Controller}.{Action} completed in {Ms}ms",
            controller, action, stopwatch.ElapsedMilliseconds);

        // Short-circuit example: if action took too long, replace result with 503
        if (stopwatch.ElapsedMilliseconds > 5_000)
            context.Result = new StatusCodeResult(StatusCodes.Status503ServiceUnavailable);
    }
}
```

**3. Short-circuiting — stopping execution before the action runs**
```csharp
// Filters/FeatureFlagFilter.cs
public class FeatureFlagFilter(IFeatureManager featureManager, string featureName)
    : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        var isEnabled = await featureManager.IsEnabledAsync(featureName);

        if (!isEnabled)
        {
            // Short-circuit: set Result without calling next() — action never runs
            context.Result = new NotFoundResult();
            return;
        }

        await next(); // feature is enabled — proceed normally
    }
}
```

**4. Exception filter — handling errors from actions and result execution**
```csharp
// Filters/ApiExceptionFilter.cs
public class ApiExceptionFilter : IExceptionFilter
{
    private readonly ILogger<ApiExceptionFilter> _logger;

    public ApiExceptionFilter(ILogger<ApiExceptionFilter> logger)
        => _logger = logger;

    public void OnException(ExceptionContext context)
    {
        _logger.LogError(context.Exception, "Unhandled exception in action");

        var result = context.Exception switch
        {
            NotFoundException  ex => new NotFoundObjectResult(new { ex.Message }),
            ForbiddenException ex => new ForbidObjectResult(new { ex.Message }),
            ConflictException  ex => new ConflictObjectResult(new { ex.Message }),
            _                     => null  // unrecognised — let middleware handle it
        };

        if (result is not null)
        {
            context.Result         = result;
            context.ExceptionHandled = true; // marks exception as handled
        }
    }
}
```

**5. Result filter — transforming the action result**
```csharp
// Filters/AddPaginationHeaderFilter.cs
// Adds X-Pagination headers to any response that carries a PagedResult
public class AddPaginationHeaderFilter : IResultFilter
{
    public void OnResultExecuting(ResultExecutingContext context)
    {
        if (context.Result is ObjectResult { Value: IPagedResult paged })
        {
            context.HttpContext.Response.Headers.Append(
                "X-Pagination-Total",   paged.TotalCount.ToString());
            context.HttpContext.Response.Headers.Append(
                "X-Pagination-Page",    paged.CurrentPage.ToString());
            context.HttpContext.Response.Headers.Append(
                "X-Pagination-Pages",   paged.TotalPages.ToString());
        }
    }

    public void OnResultExecuted(ResultExecutedContext context) { }
}
```

**6. Applying filters at different scopes**
```csharp
// Global — all actions in the app
builder.Services.AddControllers(options =>
{
    options.Filters.Add<LogActionFilter>();         // by type
    options.Filters.Add(new RequestTimingFilter()); // by instance (no DI)
});

// Register filter as a service (required for ServiceFilter)
builder.Services.AddScoped<LogActionFilter>();

// Controller-level — all actions in this controller
[ServiceFilter(typeof(LogActionFilter))]  // resolved from DI
public class ProductsController : ControllerBase { }

// Action-level — only this action
public class OrdersController : ControllerBase
{
    [TypeFilter(typeof(FeatureFlagFilter),   // DI-injected args, no service registration needed
        Arguments = new object[] { "new-checkout" })]
    [HttpPost("checkout")]
    public IActionResult Checkout() => Ok();
}
```

**7. Filter as an attribute (combines attribute and filter in one class)**
```csharp
// Filter attributes are convenient but can't use constructor DI for services —
// use property injection via ServiceProvider instead, or use TypeFilter/ServiceFilter
public class RequireApiKeyAttribute : Attribute, IActionFilter
{
    public void OnActionExecuting(ActionExecutingContext context)
    {
        var apiKey = context.HttpContext.Request.Headers["X-Api-Key"].FirstOrDefault();

        // Get service from DI inside the filter (since we can't use constructor injection)
        var apiKeyService = context.HttpContext.RequestServices
            .GetRequiredService<IApiKeyService>();

        if (!apiKeyService.IsValid(apiKey))
        {
            context.Result = new UnauthorizedObjectResult(new { error = "Invalid API key" });
        }
    }

    public void OnActionExecuted(ActionExecutedContext context) { }
}

// Usage as a plain attribute
[RequireApiKey]
[HttpGet("export")]
public IActionResult Export() => Ok();
```

**8. Execution order visualised**
```
Request
  │
  ▼
[Global] OnActionExecuting
  │
  ▼
[Controller] OnActionExecuting
  │
  ▼
[Action] OnActionExecuting
  │
  ▼
Action method executes
  │
  ▼
[Action] OnActionExecuted
  │
  ▼
[Controller] OnActionExecuted
  │
  ▼
[Global] OnActionExecuted
  │
  ▼
Result executes
  │
  ▼
[Global] OnResultExecuted
```

---

## Real World Example

A multi-tenant API where every controller action must verify the tenant is active, record an audit log entry, and append tenant-specific rate limit headers to the response. Three filters handle these concerns, applied at different scopes.

```csharp
// Filters/TenantActiveFilter.cs — authorization filter (runs first)
public class TenantActiveFilter(ITenantService tenantService) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        var tenantId = context.HttpContext.User.FindFirstValue("tenant_id");

        if (tenantId is null || !await tenantService.IsActiveAsync(Guid.Parse(tenantId)))
        {
            context.Result = new ObjectResult(new { error = "Tenant account is inactive" })
            {
                StatusCode = StatusCodes.Status403Forbidden
            };
            return; // short-circuit — action never runs
        }

        await next();
    }
}

// Filters/AuditFilter.cs — records every action call
public class AuditFilter(IAuditService auditService) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        var executed = await next();

        var tenantId   = context.HttpContext.User.FindFirstValue("tenant_id");
        var action     = context.ActionDescriptor.DisplayName;
        var statusCode = (context.HttpContext.Response.StatusCode);

        // Fire and forget — don't let audit failure block the response
        _ = auditService.RecordAsync(tenantId, action, statusCode);
    }
}

// Filters/RateLimitHeaderFilter.cs — result filter adds headers
public class RateLimitHeaderFilter(IRateLimitService rateLimitService) : IAsyncResultFilter
{
    public async Task OnResultExecutionAsync(
        ResultExecutingContext context,
        ResultExecutionDelegate next)
    {
        var tenantId = context.HttpContext.User.FindFirstValue("tenant_id");
        var limits   = await rateLimitService.GetStatusAsync(tenantId);

        context.HttpContext.Response.Headers.Append("X-RateLimit-Limit",     limits.Limit.ToString());
        context.HttpContext.Response.Headers.Append("X-RateLimit-Remaining", limits.Remaining.ToString());
        context.HttpContext.Response.Headers.Append("X-RateLimit-Reset",     limits.ResetAt.ToUnixTimeSeconds().ToString());

        await next();
    }
}

// Program.cs — wire up globally
builder.Services.AddScoped<TenantActiveFilter>();
builder.Services.AddScoped<AuditFilter>();
builder.Services.AddScoped<RateLimitHeaderFilter>();

builder.Services.AddControllers(options =>
{
    // Applied in this order globally
    options.Filters.AddService<TenantActiveFilter>();
    options.Filters.AddService<AuditFilter>();
    options.Filters.AddService<RateLimitHeaderFilter>();
});
```

*The key insight: three concerns that would otherwise appear in every controller method are handled by three filters registered once globally. Adding a new controller automatically gets all three behaviours. The filters are injected with scoped services (`ITenantService`, `IAuditService`) and the DI container manages their lifetime correctly — something that couldn't be done with filter attributes using constructor injection.*

---

## Common Misconceptions

**"Filters and middleware are interchangeable — use whichever is easier"**
They run at different points in the pipeline and have different access to context. Middleware runs on every request before routing — it has no knowledge of controllers, actions, or parameters. Filters run after routing and action selection — they know the controller name, action name, action arguments, and the result type. Logic that needs action context belongs in filters; logic that doesn't (authentication, CORS, compression, request buffering) belongs in middleware.

**"Exception filters catch all exceptions in the application"**
Exception filters only catch exceptions that are thrown during action execution and result execution. They do not catch exceptions thrown in middleware, in the request pipeline before routing, or during view rendering in some cases. For truly global exception handling, use `app.UseExceptionHandler()` middleware or the `IExceptionHandler` interface (ASP.NET Core 7+). Exception filters are best for mapping specific domain exceptions to HTTP responses within the MVC layer.

**"ServiceFilter and TypeFilter do the same thing"**
Both resolve filter dependencies from DI, but differently. `[ServiceFilter(typeof(MyFilter))]` requires the filter class to be registered as a service in the DI container — the container fully manages its lifetime. `[TypeFilter(typeof(MyFilter))]` instantiates the filter using the DI container for constructor parameters, but the filter class itself doesn't need to be registered. Use `[ServiceFilter]` when you want to control the filter's lifetime (singleton, scoped); use `[TypeFilter]` for convenience when no explicit registration is needed.

---

## Gotchas

- **Global filters registered via `options.Filters.Add<T>()` are instantiated per-request if transient, per-scope if scoped.** If you register a filter globally using `Add<T>()` directly (not `AddService<T>()`), the filter is created without DI — its constructor can't receive services. Use `options.Filters.AddService<T>()` to enable DI-resolved global filters, and ensure the filter is registered in the DI container.

- **`OnActionExecuted` still runs when the action throws an exception.** `context.Exception` will be non-null. If you check `context.Result` in `OnActionExecuted` without checking for exceptions first, you'll get a null reference on `context.Result` for failed actions.

- **Short-circuiting in `OnActionExecuting` skips all subsequent `OnActionExecuting` filters but still runs `OnActionExecuted` for filters that already ran.** If global → controller → action filter order applies, and you short-circuit in the global filter, the controller and action filters' `OnActionExecuting` never run. But the global filter's own `OnActionExecuted` still runs after the short-circuit result is set.

- **Exception filters don't catch exceptions thrown in `IResultFilter.OnResultExecuting` or result execution itself.** If your result filter throws, or if rendering the view throws, the exception filter doesn't see it. Use middleware-level exception handling for those cases.

- **Filter attributes can't use constructor injection for services.** Attribute constructors must have constant values. A `[RequireFeatureFlag("new-dashboard")]` attribute can't inject `IFeatureManager` via the constructor. Use `context.HttpContext.RequestServices.GetRequiredService<T>()` inside the filter method, or use `[ServiceFilter]` / `[TypeFilter]` instead of the inline attribute approach.

- **Async filters must call `await next()` or set `context.Result` — doing neither hangs the request.** If you write `OnActionExecutionAsync` and forget both `await next()` and `context.Result = ...`, the request never completes and the client times out.

---

## Interview Angle

**What they're really testing:** Whether you understand the filter pipeline execution order, the difference between filters and middleware, and the practical wiring of DI-aware filters.

**Common question forms:**
- *"What is an action filter and when would you use one?"*
- *"What's the difference between a filter and middleware?"*
- *"How do you apply a filter that needs a service from the DI container?"*

**The depth signal:** A junior answer says filters run before and after actions and can be used for logging. A senior answer explains the full filter type hierarchy (authorization → resource → action → result → exception), the three-scope model and execution order (global executes first for "executing", reverses for "executed"), why middleware is the wrong choice for logic that needs action context, the difference between `ServiceFilter` and `TypeFilter`, why filter attributes can't use constructor injection, and the short-circuit behaviour — setting `context.Result` in `OnActionExecuting` skips the action but still runs `OnActionExecuted` for already-started filters.

**Follow-up questions to expect:**
- *"What's the execution order when the same filter type is applied globally and at the controller level?"* (global OnActionExecuting → controller OnActionExecuting → action executes → controller OnActionExecuted → global OnActionExecuted)
- *"How do you handle a domain exception like NotFoundException across all controllers?"* (global exception filter mapping to 404, or middleware `UseExceptionHandler`)

---

## Related Topics

- [[dotnet/mvc/mvc-controllers.md]] — Filters are applied to controllers and actions via attributes or global registration; the controller is the scope at which most filters are first encountered.
- [[dotnet/mvc/mvc-pattern.md]] — Filters are part of the MVC pipeline; understanding the full request flow from routing to action to result clarifies where filters fit.
- [[dotnet/webapi/middleware-pipeline.md]] — Middleware and filters are complementary; understanding both makes it clear which tool fits which concern.
- [[dotnet/webapi/webapi-exception-handling.md]] — Exception filters handle MVC-layer exceptions; global middleware exception handling (`UseExceptionHandler`) handles the rest.
- [[dotnet/dependency-injection.md]] — `ServiceFilter` and `TypeFilter` resolve filter dependencies from DI; lifetime rules (scoped vs singleton) apply to filters just like any other service.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/filters

---
*Last updated: 2026-04-09*