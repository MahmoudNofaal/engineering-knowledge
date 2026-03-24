# ASP.NET Core Web API Filters

> Filters are hooks that run code at specific points in the request pipeline around your action methods — before, after, or instead of them.

---

## When To Use It

Use filters for cross-cutting concerns that apply to multiple endpoints: logging, exception handling, caching response headers, enforcing custom authorization rules, or auditing. They're the correct alternative to duplicating that logic in every action. Don't use filters when middleware is a better fit — if the concern applies to every request regardless of whether it reaches a controller (rate limiting, HTTPS redirection, CORS), it belongs in middleware. Filters only run when the routing system has selected an endpoint; middleware runs unconditionally.

---

## Core Concept

Filters slot into the MVC pipeline at fixed points, forming their own mini-pipeline inside the main middleware chain. There are five kinds, each with a specific job: authorization filters run first and can short-circuit the request; resource filters wrap the entire action including model binding; action filters run immediately before and after the action method; exception filters catch unhandled exceptions thrown by the action; result filters run around the `IActionResult` execution. Each filter type has a synchronous interface (`IActionFilter`) and an async one (`IAsyncActionFilter`) — use async when your filter does I/O. Filters can be applied as attributes on an action or controller, registered globally for all controllers, or injected via DI using `ServiceFilter` or `TypeFilter`.

---

## The Code
```csharp
// --- Action filter: log execution time for any action ---
public class TimingFilter : IAsyncActionFilter
{
    private readonly ILogger<TimingFilter> _logger;

    public TimingFilter(ILogger<TimingFilter> logger) => _logger = logger;

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();

        var executed = await next();        // runs the action (and any inner filters)

        sw.Stop();

        if (executed.Exception is not null)
            _logger.LogWarning("Action {Action} threw after {Ms}ms",
                context.ActionDescriptor.DisplayName, sw.ElapsedMilliseconds);
        else
            _logger.LogInformation("Action {Action} completed in {Ms}ms",
                context.ActionDescriptor.DisplayName, sw.ElapsedMilliseconds);
    }
}

// Registration — globally in Program.cs:
builder.Services.AddControllers(options =>
{
    options.Filters.Add<TimingFilter>();    // needs DI, so register in services too
});
builder.Services.AddScoped<TimingFilter>();
```
```csharp
// --- Attribute-based action filter (no DI dependencies) ---
[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class)]
public class RequireHttpsHeaderAttribute : ActionFilterAttribute  // inherits from Attribute + IActionFilter
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

// Usage:
[RequireHttpsHeader]
[HttpPost("secure")]
public IActionResult SecureEndpoint() => Ok();
```
```csharp
// --- Exception filter: centralise unhandled exception handling ---
public class GlobalExceptionFilter : IAsyncExceptionFilter
{
    private readonly ILogger<GlobalExceptionFilter> _logger;

    public GlobalExceptionFilter(ILogger<GlobalExceptionFilter> logger) => _logger = logger;

    public Task OnExceptionAsync(ExceptionContext context)
    {
        _logger.LogError(context.Exception, "Unhandled exception in action");

        context.Result = new ObjectResult(new ProblemDetails
        {
            Status = StatusCodes.Status500InternalServerError,
            Title  = "An unexpected error occurred.",
            Detail = context.Exception.Message         // omit in production
        })
        {
            StatusCode = StatusCodes.Status500InternalServerError
        };

        context.ExceptionHandled = true;               // prevents further propagation
        return Task.CompletedTask;
    }
}
```
```csharp
// --- Result filter: add a response header after every action ---
public class AddCorrelationHeaderFilter : IResultFilter
{
    public void OnResultExecuting(ResultExecutingContext context)
    {
        var correlationId = context.HttpContext.TraceIdentifier;
        context.HttpContext.Response.Headers["X-Correlation-Id"] = correlationId;
    }

    public void OnResultExecuted(ResultExecutedContext context) { }  // nothing needed after
}
```
```csharp
// --- ServiceFilter: apply a filter that needs DI, scoped to one controller ---
// Register the filter in DI first:
builder.Services.AddScoped<TimingFilter>();

// Then apply per-controller or per-action:
[ServiceFilter(typeof(TimingFilter))]
[ApiController]
[Route("api/orders")]
public class OrdersController : ControllerBase { }

// TypeFilter is similar but instantiates the filter itself (useful for passing constructor args):
[TypeFilter(typeof(TimingFilter))]
public IActionResult Create() => Ok();
```
```csharp
// --- Filter order: global → controller → action (innermost wins on short-circuit) ---
// You can set Order explicitly on IOrderedFilter to override the default:
public class EarlyRunningFilter : IAsyncActionFilter, IOrderedFilter
{
    public int Order => -1000;   // lower number = runs earlier in the before-phase

    public async Task OnActionExecutionAsync(ActionExecutingContext ctx, ActionExecutionDelegate next)
    {
        // runs before any Order=0 filters
        await next();
    }
}
```

---

## Gotchas

- **Setting `context.Result` in an action filter's `OnActionExecuting` short-circuits the action but still runs `OnResultExecuting` on result filters and `OnActionExecuted` on outer action filters.** It does NOT skip all remaining filters. If your short-circuit response needs to bypass result filters too, use a resource filter (`IResourceFilter`) instead — it wraps the entire inner pipeline including model binding and all other filters.
- **Exception filters don't catch exceptions from result execution.** An exception thrown inside `IActionResult.ExecuteResultAsync` (i.e., while writing the response) is not caught by `IExceptionFilter`. It propagates to middleware. For truly global exception handling, use `UseExceptionHandler` middleware or `IProblemDetailsService` in addition to exception filters.
- **`ActionFilterAttribute` short-circuits poorly when you forget to call `next`.** In async filters, if you call `await next()` conditionally and take a different branch without setting `context.Result`, the framework throws a `InvalidOperationException` because the pipeline expects either `next()` to be called or `context.Result` to be set. Always ensure one of those two things happens on every code path.
- **Filters registered globally have the same lifetime as their registration — watch out for scoped services in singletons.** If you register a filter globally via `options.Filters.Add<MyFilter>()` and `MyFilter` is scoped, but the options registration creates it as singleton, you'll get a captive dependency. Use `options.Filters.Add(new ServiceFilterAttribute(typeof(MyFilter)))` instead, which resolves the filter from DI per request.
- **Authorization filters run before model binding.** This means an authorization filter cannot inspect `context.ActionArguments` — they're empty at that point because binding hasn't run yet. If you need to authorize based on a route value or body content, use a resource filter or a policy handler with `IAuthorizationHandler` that receives the resource separately.

---

## Interview Angle

**What they're really testing:** Whether you understand the MVC filter pipeline and can distinguish it from middleware — and whether you know which filter type to reach for for a given cross-cutting concern.

**Common question form:** "How would you log execution time for all API actions?" or "Where would you put global exception handling?" or "What's the difference between a filter and middleware?"

**The depth signal:** A junior knows that `[ServiceFilter]` applies a filter and that there are action filters and exception filters. A senior can draw the full execution order (Authorization → Resource → Model Binding → Action → Exception → Result), explain that `IResourceFilter` is the only filter type that wraps model binding, and knows that short-circuiting in `OnActionExecuting` by setting `context.Result` still executes `OnResultExecuting` — which is why centralised error shaping belongs in a result filter or `InvalidModelStateResponseFactory`, not an action filter. They also know that middleware is the better choice when the concern applies outside MVC (static files, WebSockets, health checks) and that mixing both is normal in production apps.

---

## Related Topics

- [[dotnet/webapi-middleware-pipeline.md]] — middleware and filters solve similar problems at different pipeline levels; knowing when each applies prevents misplacing logic
- [[dotnet/webapi-model-validation.md]] — `ModelStateInvalidFilter` is itself an action filter; knowing filter order explains why it fires before user-defined action filters
- [[dotnet/webapi-controllers.md]] — filters are applied at the controller and action level via attributes or global registration; the controller is where their scope is defined
- [[dotnet/webapi-problem-details.md]] — exception filters and result filters are where you shape `ProblemDetails` error responses consistently across the API

---

## Source

[https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/filters](https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/filters)

---
*Last updated: 2026-03-24*