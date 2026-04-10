# Middleware Pipeline

> A chain of components in ASP.NET Core where each component can process an HTTP request, decide to pass it to the next component, and then process the response on the way back out.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Ordered chain of request/response processing components |
| **Use when** | Any cross-cutting concern that applies across multiple or all requests |
| **Avoid when** | Logic that belongs only in a single controller — use filters instead |
| **Introduced** | ASP.NET Core 1.0; `MapGroup` added .NET 6; `IMiddlewareFactory` since 1.0 |
| **Namespace** | `Microsoft.AspNetCore.Builder`, `Microsoft.AspNetCore.Http` |
| **Key types** | `RequestDelegate`, `IMiddleware`, `IApplicationBuilder`, `WebApplication` |

---

## When To Use It

Any time you need logic that applies to every request — or a defined subset of requests — without putting that logic inside individual controllers. Authentication, logging, exception handling, CORS, response compression, request timing — all of these belong in the pipeline, not in your business logic. If you find yourself writing the same cross-cutting code in multiple controllers, that is the signal to move it into middleware.

Prefer filters over middleware when the concern is MVC-specific and needs access to action metadata (controller name, action descriptor, model state). Use middleware when the concern must run regardless of whether a controller is involved — static files, WebSockets, and health checks all short-circuit before routing reaches MVC.

---

## Core Concept

Think of the pipeline as a series of nested functions, each wrapping the next. A request enters the first middleware, which does something, then calls `next()` to pass it forward. Eventually the request reaches your controller, gets handled, and then the response travels *back* through each middleware in reverse order. This two-way flow is the key insight — each middleware has a chance to act both before and after the rest of the pipeline runs. The order you register middleware in `Program.cs` is the exact order it executes — this is not a detail, it is everything. Registering authentication after routing means routing runs on unauthenticated requests. Order is your responsibility.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | `Use`, `Run`, `Map`, `IMiddleware` introduced |
| ASP.NET Core 2.0 | `UseRouting` / `UseEndpoints` split introduced (replaces old `UseMvc`) |
| ASP.NET Core 3.0 | Endpoint routing made first-class; middleware can inspect endpoint metadata before it executes |
| .NET 6 | `WebApplication` / minimal hosting model; pipeline built directly on `app` instead of `IApplicationBuilder` |
| .NET 6 | `MapGroup` added for grouped endpoint routing |
| .NET 8 | `IMiddlewareFactory` improvements; `UseWhen` / `MapWhen` refinements |

*Before ASP.NET Core 3.0, `UseRouting` and `UseEndpoints` were a single `UseMvc` call — splitting them apart is what allows middleware like `UseAuthorization` to see endpoint metadata at the right time.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Middleware dispatch per component | ~5–20 ns | `RequestDelegate` invocation; essentially a virtual call |
| Class-based `IMiddleware` | Slightly higher than inline | Extra DI resolution on each request |
| Inline `Use` lambda | Lowest overhead | No class instantiation; suitable for trivial transforms |
| Short-circuit (no `next()`) | Near zero after the check | Response written directly; subsequent middleware never allocates |

**Allocation behaviour:** Each `Use` lambda that captures variables allocates a closure. Class-based middleware (`IMiddleware`) is instantiated once and reused — no per-request allocation for the middleware itself, though it may allocate inside `InvokeAsync`. Avoid allocating inside hot-path middleware (e.g., request logging for every request at high QPS).

**Benchmark notes:** The pipeline overhead is negligible compared to any I/O (DB, HTTP). Profiling rarely shows middleware dispatch as a bottleneck. Focus correctness and order first; micro-optimise only if profiling proves it necessary.

---

## The Code

**The canonical pipeline execution order**
```csharp
// Program.cs — order here = execution order. Not negotiable.
var app = builder.Build();

app.UseExceptionHandler("/error");  // must be first — wraps everything else
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseCors();                      // after UseRouting, before UseAuthentication
app.UseAuthentication();            // must come before Authorization
app.UseAuthorization();             // depends on Authentication running first
app.MapControllers();               // terminal — handles the request, no 'next'

app.Run();
```

**Writing your own middleware (class-based, preferred for production)**
```csharp
// A middleware that logs request duration
public class RequestTimingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestTimingMiddleware> _logger;

    // Constructor is called once at startup — inject singletons here
    public RequestTimingMiddleware(RequestDelegate next, ILogger<RequestTimingMiddleware> logger)
    {
        _next   = next;
        _logger = logger;
    }

    // InvokeAsync is called per request — inject scoped services here as parameters
    public async Task InvokeAsync(HttpContext context)
    {
        var sw = Stopwatch.StartNew();

        await _next(context);           // everything BEFORE this = request phase
                                        // everything AFTER this = response phase

        sw.Stop();
        _logger.LogInformation(
            "{Method} {Path} completed in {Ms}ms",
            context.Request.Method,
            context.Request.Path,
            sw.ElapsedMilliseconds);
    }
}

// Register it as an extension method — clean and discoverable
public static class RequestTimingMiddlewareExtensions
{
    public static IApplicationBuilder UseRequestTiming(this IApplicationBuilder app)
        => app.UseMiddleware<RequestTimingMiddleware>();
}

app.UseRequestTiming();
```

**Inline middleware with `Use()` — for quick, simple cases**
```csharp
// Use() passes to the next middleware
app.Use(async (context, next) =>
{
    // request phase
    context.Items["RequestId"] = Guid.NewGuid();

    await next.Invoke();    // call the rest of the pipeline

    // response phase — runs after controller has responded
    context.Response.Headers.Append("X-Request-Id",
        context.Items["RequestId"]?.ToString());
});

// Run() is terminal — it does NOT call next. Pipeline stops here.
app.Run(async context =>
{
    await context.Response.WriteAsync("No further middleware runs after this.");
});
```

**Short-circuiting — stopping the pipeline deliberately**
```csharp
app.Use(async (context, next) =>
{
    if (context.Request.Path == "/health")
    {
        context.Response.StatusCode = 200;
        await context.Response.WriteAsync("healthy");
        return;     // no call to next() — pipeline short-circuits here
    }

    await next.Invoke();
});
```

**Conditional branching with `UseWhen` and `Map`**
```csharp
// UseWhen: branches the pipeline based on condition, then rejoins the main pipeline
app.UseWhen(
    ctx => ctx.Request.Path.StartsWithSegments("/api"),
    branch => branch.UseRequestTiming());   // only API requests are timed

// Map: branches permanently — requests that match never return to the main pipeline
app.Map("/admin", adminApp =>
{
    adminApp.UseAuthentication();
    adminApp.UseAuthorization();
    adminApp.MapControllers();
});
```

**Injecting scoped services into middleware**
```csharp
// Scoped services CANNOT go in the constructor (middleware is singleton-lifetime).
// Inject them as InvokeAsync parameters instead — the framework handles resolution.
public class TenantResolutionMiddleware
{
    private readonly RequestDelegate _next;

    public TenantResolutionMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context, ITenantService tenantService)
    {
        // tenantService is resolved from the request scope — correct lifetime
        var tenant = await tenantService.ResolveAsync(context);
        context.Items["Tenant"] = tenant;
        await _next(context);
    }
}
```

---

## Real World Example

A SaaS API needs per-request tenant resolution, correlation ID injection, and timing on every API route. These are wired as middleware so controllers never see the plumbing — they just read `HttpContext.Items["Tenant"]` and the logger automatically includes the correlation ID from the scope.

```csharp
// CorrelationIdMiddleware.cs
public class CorrelationIdMiddleware(RequestDelegate next)
{
    private const string HeaderName = "X-Correlation-Id";

    public async Task InvokeAsync(HttpContext context)
    {
        var correlationId = context.Request.Headers[HeaderName].FirstOrDefault()
                            ?? Guid.NewGuid().ToString();

        context.Items["CorrelationId"] = correlationId;
        context.Response.Headers[HeaderName] = correlationId;

        // Push into log scope so every log line in this request carries the ID
        using (Serilog.Context.LogContext.PushProperty("CorrelationId", correlationId))
        {
            await next(context);
        }
    }
}

// TenantMiddleware.cs
public class TenantMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context, ITenantRepository tenants)
    {
        var host   = context.Request.Host.Host;
        var tenant = await tenants.FindByHostAsync(host);

        if (tenant is null)
        {
            context.Response.StatusCode = 404;
            await context.Response.WriteAsync("Unknown tenant.");
            return;             // short-circuit — invalid tenant gets nothing
        }

        context.Items["Tenant"] = tenant;
        await next(context);
    }
}

// Program.cs
app.UseExceptionHandler();
app.UseMiddleware<CorrelationIdMiddleware>();    // runs first — ID available to everything
app.UseMiddleware<TenantMiddleware>();           // resolves tenant before auth
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// OrdersController.cs — no plumbing visible here
[HttpGet("{id}")]
public async Task<IActionResult> GetOrder(int id)
{
    var tenant = (Tenant)HttpContext.Items["Tenant"]!;
    var order  = await _orders.GetAsync(tenant.Id, id);
    return order is null ? NotFound() : Ok(order);
}
```

*The key insight: middleware runs before controller code is even selected by routing. Tenant resolution and correlation ID injection happen once, at the infrastructure layer, and the entire application benefits without any controller knowing it exists.*

---

## Common Misconceptions

**"Middleware and filters do the same thing."**
They run at different pipeline levels. Middleware wraps the entire HTTP pipeline — it runs for static files, WebSockets, and health checks, none of which involve MVC. Filters run inside the MVC layer, after routing has selected an action, and have access to action metadata. The wrong placement causes bugs: exception filters don't catch middleware exceptions; middleware can't access `ModelState`.

**"I can inject a scoped service into the middleware constructor."**
Middleware classes are instantiated once at startup, making them effectively singletons. Injecting a scoped service (like `DbContext`) into the constructor captures it for the entire app lifetime — a captive dependency that will reuse a stale context across all requests. Inject scoped services as parameters on `InvokeAsync`, not in the constructor.

```csharp
// WRONG — DbContext captured as singleton
public class BadMiddleware(RequestDelegate next, AppDbContext db) { ... }

// RIGHT — DbContext resolved per request
public class GoodMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext ctx, AppDbContext db) { ... }
}
```

**"`UseRouting` is optional now that minimal APIs exist."**
`WebApplication` implicitly adds routing and endpoint middleware, but the *order* still matters. If you call `app.UseAuthentication()` before `app.MapControllers()`, the routing is implicit — but if you add explicit `UseRouting()`, everything after it can see endpoint metadata. Skipping `UseRouting()` in complex pipelines can cause auth middleware to run without knowing which endpoint was matched.

---

## Gotchas

- **Order is everything.** `UseAuthentication()` must come before `UseAuthorization()`. `UseRouting()` must come before any middleware that uses endpoint metadata. `UseExceptionHandler()` must be first so it can catch exceptions from everything else. Getting this wrong produces bugs that are maddening to diagnose because the code looks correct.

- **`Use()` vs `Run()` vs `Map()`:** `Use()` can call next or short-circuit. `Run()` is always terminal — never calls next. `Map()` branches the pipeline based on path permanently. Mixing these up is a common mistake, especially using `Run()` when you meant `Use()` and then wondering why the rest of your pipeline never executes.

- **Response has already started:** once you start writing to the response body, you cannot change headers or status code. Trying to do so after `context.Response.HasStarted` is `true` throws an exception. If your middleware needs to modify the response, it must do so before calling `next()` or by buffering — which has its own complexity.

- **Middleware is singleton in behaviour.** Middleware classes are instantiated once and reused across all requests. Do not store request-scoped state in middleware fields. Use `HttpContext.Items` for per-request state, or inject scoped services through `InvokeAsync` parameters, not the constructor.

- **Exception middleware scope:** `UseExceptionHandler` only catches exceptions that bubble up through the pipeline. If you swallow an exception inside a background task or a fire-and-forget call, it will not be caught and the response is already committed.

- **`UseWhen` rejoins the main pipeline; `MapWhen` does not.** A common mistake is using `MapWhen` when you intend `UseWhen` — with `MapWhen`, requests that enter the branch never continue to the main pipeline's `MapControllers()`. Use `UseWhen` when you want the branch middleware to apply only to certain requests but still have them reach the endpoint layer.

---

## Interview Angle

**What they're really testing:** Whether you understand the pipeline as a first-class architectural concept — not just middleware as something the framework handles invisibly. They want to know you can reason about order, short-circuiting, and where cross-cutting concerns belong.

**Common question forms:**
- "How does the ASP.NET Core request pipeline work?"
- "Where would you put authentication logic and why?"
- "What is the difference between `Use`, `Run`, and `Map`?"
- "How would you build a middleware that measures request duration?"

**The depth signal:** A junior says middleware is "code that runs before the controller." A senior explains the two-way pipeline flow (request phase → controller → response phase back through each middleware in reverse), explains why order in `Program.cs` is critical with a concrete example (auth before authz, exception handler first), explains the difference between `Use`, `Run`, and `Map` with their behavioural implications, explains short-circuiting and when to use it deliberately, and can discuss the singleton-behaviour gotcha around scoped services in middleware constructors. Bonus depth: knowing that `UseRouting` / `UseEndpoints` splitting in ASP.NET Core 3.0 is what enables middleware between those two calls to inspect endpoint metadata — which is how `UseAuthorization` knows which `[Authorize]` policy applies before the action runs.

**Follow-up questions to expect:**
- "How does middleware differ from a filter?"
- "How would you share data between middleware components within a single request?"
- "What happens if middleware doesn't call `next()`?"

---

## Related Topics

- [[dotnet/webapi/webapi-filters.md]] — filters run inside the MVC layer, after routing; not the same as middleware even though they look similar — knowing the distinction determines where cross-cutting logic belongs
- [[dotnet/webapi/webapi-exception-handling.md]] — `UseExceptionHandler` is middleware; its position first in the pipeline is what allows it to catch exceptions from all downstream components
- [[dotnet/webapi/dependency-injection.md]] — middleware constructors use DI for singletons; scoped services must be injected via `InvokeAsync` parameters to get the correct lifetime
- [[dotnet/webapi/webapi-cors.md]] — `UseCors` has strict ordering requirements relative to `UseRouting` and `UseAuthentication`; understanding the pipeline makes those requirements obvious

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware

---
*Last updated: 2026-04-10*