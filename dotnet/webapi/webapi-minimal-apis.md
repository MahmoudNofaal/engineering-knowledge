# ASP.NET Core Minimal APIs

> Minimal APIs let you define HTTP endpoints directly in `Program.cs` with a single line per route, without controllers, action methods, or the MVC infrastructure.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Lightweight endpoint registration without MVC controllers |
| **Use when** | Microservices, small APIs, prototypes, or when MVC overhead outweighs its benefits |
| **Avoid when** | Large APIs with complex shared filters, custom model binders, or many endpoints needing action-level attributes |
| **Introduced** | .NET 6 |
| **Namespace** | `Microsoft.AspNetCore.Builder`, `Microsoft.AspNetCore.Http` |
| **Key types** | `RouteGroupBuilder`, `IEndpointFilter`, `IResult`, `TypedResults`, `Results<T1, T2>` |

---

## When To Use It

Use minimal APIs for microservices, small focused APIs, Azure Functions replacements, or any project where MVC's convention overhead outweighs its benefits. They're also excellent for prototyping — you can stand up a working API in under 20 lines. Avoid them when your API has dozens of endpoints that share complex filters, action-level authorization policies, or model binding customisations that MVC handles cleanly via attributes — at that scale, the manual wiring becomes friction. In practice many large codebases use both: minimal APIs for lightweight endpoints, controllers for feature-heavy areas.

---

## Core Concept

Minimal APIs skip the controller layer entirely. You call `app.MapGet`, `app.MapPost`, etc., passing a route pattern and a handler — a lambda, a local function, or a static method. Parameter binding works the same way as MVC: simple types come from the route or query string, complex types from the body, and services are injected directly into the handler signature from DI (no constructor needed). Route groups let you apply shared prefixes, middleware, and authorization to a set of endpoints without a controller class. The result is the same Kestrel/middleware pipeline under the hood — you're skipping the MVC layer that sits on top of it.

---

## Version History

| .NET Version | What changed |
|---|---|
| .NET 6 | Minimal APIs introduced — `MapGet`, `MapPost`, `MapGroup`, `IEndpointFilter` |
| .NET 7 | `TypedResults` for typed return types visible to OpenAPI; `[AsParameters]` attribute |
| .NET 7 | `Results<T1, T2>` union type for multiple possible return types |
| .NET 7 | `IEndpointFilter` improved; `RouteGroupBuilder` additions |
| .NET 8 | Form binding improvements; `[FromForm]` support; `DisableAntiforgery()` |

*`TypedResults` (.NET 7) is the key improvement that made minimal APIs viable for documented APIs — without it, Swashbuckle couldn't infer response types and every endpoint needed `[ProducesResponseType]` attributes.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Minimal API dispatch | ~10–30% faster than MVC | Skips the MVC action filter pipeline |
| `MapGet` lambda handler | Near-zero overhead | Compiled to a delegate at startup |
| Route group middleware | O(n) | n = number of group-level filters |
| `IEndpointFilter` chain | ~1–5 µs per filter | Same cost as MVC action filters |

**Allocation behaviour:** Minimal API handlers that capture variables in lambdas allocate closures — declare handlers as static local functions or static methods to avoid heap allocation in tight loops. `TypedResults.Ok(data)` allocates the result wrapper; for extremely high-frequency endpoints, consider `Results.Text` or direct response writing.

**Benchmark notes:** Minimal APIs are measurably faster than controllers in microbenchmarks — 10–30% fewer allocations and faster dispatch. In practice, for any API doing I/O (DB, HTTP, disk), the difference is unmeasurable against the I/O cost. Choose based on design preference, not performance.

---

## The Code

**Minimal complete API**
```csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddScoped<IOrderService, OrderService>();

var app = builder.Build();

app.MapGet("/api/orders/{id:int}", async (int id, IOrderService svc) =>
{
    var order = await svc.GetByIdAsync(id);
    return order is null ? Results.NotFound() : Results.Ok(order);
});

app.MapPost("/api/orders", async (CreateOrderRequest req, IOrderService svc) =>
{
    var created = await svc.CreateAsync(req);
    return Results.Created($"/api/orders/{created.Id}", created);
});

app.Run();
```

**Route groups — shared prefix, auth, and filters**
```csharp
var api = app.MapGroup("/api")
             .RequireAuthorization()
             .AddEndpointFilter<TimingFilter>();

var orders = api.MapGroup("/orders");
orders.MapGet("/",            async (IOrderService svc) => Results.Ok(await svc.GetAllAsync()));
orders.MapGet("/{id:int}",    async (int id, IOrderService svc) =>
    await svc.GetByIdAsync(id) is { } o ? Results.Ok(o) : Results.NotFound());
orders.MapPost("/",           async (CreateOrderRequest req, IOrderService svc) =>
    Results.Created($"/api/orders/{(await svc.CreateAsync(req)).Id}", null));
orders.MapDelete("/{id:int}", async (int id, IOrderService svc) =>
{
    await svc.DeleteAsync(id);
    return Results.NoContent();
});
```

**`TypedResults` — return type visible to OpenAPI (.NET 7+)**
```csharp
// TypedResults (with 'd') → OpenAPI knows the 200 returns OrderDto and 404 returns nothing
app.MapGet("/api/orders/{id:int}",
    async Task<Results<Ok<OrderDto>, NotFound>> (int id, IOrderService svc) =>
    {
        var order = await svc.GetByIdAsync(id);
        return order is null
            ? TypedResults.NotFound()
            : TypedResults.Ok(order);
    });
```

**`[AsParameters]` — bind multiple query params from a record (.NET 7+)**
```csharp
record OrderQuery(
    [property: FromQuery] int Page = 1,
    [property: FromQuery] int PageSize = 20,
    [property: FromQuery] string? Status = null);

app.MapGet("/api/orders", async ([AsParameters] OrderQuery q, IOrderService svc) =>
    Results.Ok(await svc.GetPagedAsync(q.Page, q.PageSize, q.Status)));
```

**`IEndpointFilter` — action filter equivalent**
```csharp
public class TimingFilter : IEndpointFilter
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
   .AddEndpointFilter<TimingFilter>();
```

**Organising endpoints in separate files**
```csharp
// OrderEndpoints.cs
public static class OrderEndpoints
{
    public static RouteGroupBuilder MapOrderEndpoints(this RouteGroupBuilder group)
    {
        group.MapGet("/",         async (IOrderService svc) => Results.Ok(await svc.GetAllAsync()));
        group.MapGet("/{id:int}", async (int id, IOrderService svc) =>
            await svc.GetByIdAsync(id) is { } o ? Results.Ok(o) : Results.NotFound());
        return group;
    }
}

// Program.cs
var orders = app.MapGroup("/api/orders").RequireAuthorization();
orders.MapOrderEndpoints();
```

---

## Real World Example

A notification microservice has five endpoints: send, schedule, cancel, get status, and list. It uses route groups for shared auth and `TypedResults` for OpenAPI accuracy. Endpoint logic is split into a separate static class to keep `Program.cs` clean.

```csharp
// NotificationEndpoints.cs
public static class NotificationEndpoints
{
    public static RouteGroupBuilder MapNotificationEndpoints(this RouteGroupBuilder group)
    {
        group.MapPost("/",
            async Task<Results<Created<NotificationDto>, BadRequest<ProblemDetails>>>
                (SendNotificationRequest req, INotificationService svc, CancellationToken ct) =>
            {
                if (req.Recipients.Count == 0)
                    return TypedResults.BadRequest(new ProblemDetails
                        { Title = "No recipients specified.", Status = 400 });

                var notification = await svc.SendAsync(req, ct);
                return TypedResults.Created($"/api/notifications/{notification.Id}", notification);
            });

        group.MapPost("/schedule",
            async Task<Results<Accepted<ScheduledNotificationDto>, BadRequest<ProblemDetails>>>
                (ScheduleNotificationRequest req, INotificationService svc, CancellationToken ct) =>
            {
                if (req.ScheduledAt <= DateTimeOffset.UtcNow)
                    return TypedResults.BadRequest(new ProblemDetails
                        { Title = "Scheduled time must be in the future.", Status = 400 });

                var scheduled = await svc.ScheduleAsync(req, ct);
                return TypedResults.Accepted($"/api/notifications/{scheduled.Id}", scheduled);
            });

        group.MapDelete("/{id:guid}",
            async Task<Results<NoContent, NotFound>>
                (Guid id, INotificationService svc, CancellationToken ct) =>
            {
                var cancelled = await svc.CancelAsync(id, ct);
                return cancelled ? TypedResults.NoContent() : TypedResults.NotFound();
            });

        group.MapGet("/{id:guid}",
            async Task<Results<Ok<NotificationDto>, NotFound>>
                (Guid id, INotificationService svc, CancellationToken ct) =>
            {
                var notification = await svc.GetAsync(id, ct);
                return notification is null
                    ? TypedResults.NotFound()
                    : TypedResults.Ok(notification);
            });

        return group;
    }
}

// Program.cs — clean, one line per resource group
var notifications = app.MapGroup("/api/notifications")
    .RequireAuthorization()
    .AddEndpointFilter<ValidationFilter>()
    .WithTags("Notifications");

notifications.MapNotificationEndpoints();
```

*The key insight: `Results<Created<T>, BadRequest<ProblemDetails>>` union return types tell Swashbuckle exactly which status codes this endpoint can return and what schema each produces — without any `[ProducesResponseType]` attributes. The OpenAPI document is accurate with zero extra decoration.*

---

## Common Misconceptions

**"Minimal APIs don't support validation."**
They don't have automatic `[ApiController]`-style validation. But you can add validation via `IEndpointFilter`, FluentValidation's minimal API integration, or by calling `Validator.TryValidateObject` manually in the handler. The difference from controllers: validation is not automatic — you must opt in explicitly.

**"Minimal APIs are only for small projects."**
The extension method pattern (`MapOrderEndpoints`, `MapProductEndpoints`) scales to large APIs cleanly. Each resource group lives in its own static class and is registered in one line in `Program.cs`. The constraint is that complex filter hierarchies (action filters with order, result filters, resource filters) have no equivalent — you only have `IEndpointFilter`. If your design requires that, use controllers.

**"Services captured in handler lambdas are resolved correctly regardless of how you capture them."**
Writing `var svc = app.Services.GetRequiredService<IOrderService>()` before `MapGet` and using it in the lambda captures a singleton-scoped instance for a scoped service — bypassing DI scope entirely. Always inject services as handler parameters, not captured closures.

---

## Gotchas

- **Services captured in handler closures outside `Map*` get the wrong DI lifetime.** Capturing a scoped service before `MapGet` gives you a singleton-lifetime instance. Always inject as handler parameters.

- **`TypedResults` (with 'd') vs `Results` (no 'd').** `TypedResults.Ok(data)` returns a strongly-typed `Ok<T>` that OpenAPI reflects on. `Results.Ok(data)` returns `IResult` — opaque to schema generation. Use `TypedResults` for any documented endpoint.

- **Minimal API validation is not automatic.** Unlike `[ApiController]`, data annotation validation on request DTOs does NOT automatically return 400. Use an endpoint filter or FluentValidation. This is the most common production mistake when migrating from controllers.

- **Route groups don't support attribute-based filters — only `AddEndpointFilter`.** The minimal API equivalent of `[Authorize("PolicyName")]` is `.RequireAuthorization("PolicyName")` on the group or endpoint.

- **`[FromForm]` with file upload on minimal APIs requires `.DisableAntiforgery()`.** Without it, multipart form endpoints throw a 400. This is a known friction point in minimal APIs for file upload scenarios.

- **`IEndpointFilter` is NOT the same as `IActionFilter`.** They're separate interfaces in different parts of the pipeline. `IActionFilter` registered globally does not apply to minimal API endpoints.

---

## Interview Angle

**What they're really testing:** Whether you understand that minimal APIs share the same underlying runtime as MVC controllers — and can reason about what you gain and lose by removing the MVC layer.

**Common question forms:**
- "What's the difference between minimal APIs and controllers?"
- "When would you choose one over the other?"
- "How do you validate input in a minimal API?"
- "How do you organise a large minimal API codebase?"

**The depth signal:** A junior knows minimal APIs are "less code" and use `MapGet`. A senior explains that both approaches use the same Kestrel server, routing engine, DI container, and middleware pipeline — the difference is purely in how endpoints are declared and dispatched. They know minimal APIs lack automatic model validation, that `TypedResults` is required for accurate OpenAPI schema generation, that the extension method pattern is the standard for large codebase organisation, and that `IEndpointFilter` is the direct analogue of `IActionFilter` with different registration syntax.

**Follow-up questions to expect:**
- "How would you add request validation to a minimal API?"
- "How does `TypedResults` differ from `Results` for OpenAPI generation?"
- "How do you apply a filter to a group of minimal API endpoints?"

---

## Related Topics

- [[dotnet/webapi/webapi-controllers.md]] — the controller-based alternative; comparing the two reveals exactly what MVC adds on top of shared routing and middleware
- [[dotnet/webapi/webapi-routing.md]] — minimal APIs use the same routing engine; route patterns, constraints, and `MapGroup` work identically to attribute routing
- [[dotnet/webapi/webapi-filters.md]] — `IEndpointFilter` is the minimal API equivalent of `IActionFilter`; understanding both shows how cross-cutting concerns are handled at each layer
- [[dotnet/webapi/webapi-model-validation.md]] — validation is not automatic in minimal APIs; knowing the gap is essential before deploying to production

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/overview

---
*Last updated: 2026-04-10*