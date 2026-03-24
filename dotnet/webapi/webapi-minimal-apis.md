# ASP.NET Core Minimal APIs

> Minimal APIs let you define HTTP endpoints directly in `Program.cs` with a single line per route, without controllers, action methods, or the MVC infrastructure.

---

## When To Use It

Use minimal APIs for microservices, small focused APIs, Azure Functions replacements, or any project where MVC's convention overhead outweighs its benefits. They're also excellent for prototyping — you can stand up a working API in under 20 lines. Avoid them when your API has dozens of endpoints that share complex filters, action-level authorization policies, or model binding customisations that MVC handles cleanly via attributes — at that scale, the lack of built-in grouping and the manual wiring become friction. In practice many large codebases use both: minimal APIs for lightweight endpoints, controllers for feature-heavy areas.

---

## Core Concept

Minimal APIs skip the controller layer entirely. You call `app.MapGet`, `app.MapPost`, etc., passing a route pattern and a handler — a lambda, a local function, or a static method. Parameter binding works the same way as MVC: simple types come from the route or query string, complex types from the body, and services are injected directly into the handler signature from DI (no constructor needed). Route groups let you apply shared prefixes, middleware, and authorization to a set of endpoints without a controller class. The result is the same Kestrel/middleware pipeline under the hood — you're just skipping the MVC layer that sits on top of it.

---

## The Code
```csharp
// --- Minimal complete API: Program.cs only ---
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
    return Results.CreatedAtRoute("get-order", new { id = created.Id }, created);
})
.WithName("create-order");

app.MapGet("/api/orders/{id:int}", async (int id, IOrderService svc) =>
    Results.Ok(await svc.GetByIdAsync(id)))
.WithName("get-order");

app.Run();
```
```csharp
// --- Route groups: shared prefix, auth, and filters ---
var api = app.MapGroup("/api")
             .RequireAuthorization()             // all routes in this group require auth
             .AddEndpointFilter<TimingFilter>(); // custom filter applied to all

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
```csharp
// --- Binding sources: explicit when inference isn't enough ---
app.MapGet("/search", (
    [FromQuery] string q,
    [FromQuery] int page = 1,
    [FromHeader(Name = "X-Tenant-Id")] string? tenantId = null) =>
{
    return Results.Ok(new { q, page, tenantId });
});

app.MapPost("/upload", async (
    [FromForm] string description,
    IFormFile file) =>
{
    await using var stream = file.OpenReadStream();
    return Results.Ok(new { file.FileName, description });
}).DisableAntiforgery();                         // required for multipart form endpoints
```
```csharp
// --- Typed Results: return type visible to OpenAPI ---
// Results<T1, T2> tells Swashbuckle which response types this endpoint can produce
app.MapGet("/api/orders/{id:int}", async Task<Results<Ok<OrderDto>, NotFound>> (
    int id, IOrderService svc) =>
{
    var order = await svc.GetByIdAsync(id);
    return order is null
        ? TypedResults.NotFound()
        : TypedResults.Ok(order);
});
```
```csharp
// --- Endpoint filter: equivalent of an action filter ---
public class TimingFilter : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext ctx, EndpointFilterDelegate next)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var result = await next(ctx);
        sw.Stop();
        Console.WriteLine($"{ctx.HttpContext.Request.Path} took {sw.ElapsedMilliseconds}ms");
        return result;
    }
}

// Applied per-endpoint:
app.MapGet("/api/slow", async (ISlowService svc) => Results.Ok(await svc.RunAsync()))
   .AddEndpointFilter<TimingFilter>();
```
```csharp
// --- Organising endpoints in separate files (extension methods pattern) ---
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

// Program.cs:
var orders = app.MapGroup("/api/orders").RequireAuthorization();
orders.MapOrderEndpoints();
```

---

## Gotchas

- **Services injected into handler lambdas are resolved per-request from the DI container — but if you capture them in a closure outside `Map*`, you get the wrong lifetime.** Writing `var svc = app.Services.GetRequiredService<IOrderService>()` before the `MapGet` call and using it in the lambda captures a singleton-scoped instance for a scoped service, bypassing the DI scope entirely. Always inject services as handler parameters, not captured closures.
- **`Results.Json` and `Results.Ok` both serialize to JSON, but `Results.Ok` uses the app's configured `JsonSerializerOptions` and `Results.Json` uses its own options parameter.** If you mix them in an endpoint and pass different options to `Results.Json`, you'll get inconsistent casing or property naming in the response. Stick to `Results.Ok` unless you have a specific reason to override serialization.
- **`TypedResults` (with the 'd') is different from `Results`.** `TypedResults.Ok(data)` returns a strongly-typed `Ok<T>` which OpenAPI/Swashbuckle can reflect on to generate response schemas automatically. `Results.Ok(data)` returns `IResult`, which is opaque to the schema generator — you lose automatic response type documentation. For any endpoint you want documented in Swagger, use `TypedResults` and declare the return type as `Results<Ok<T>, NotFound>`.
- **Minimal API validation is not automatic — there is no `[ApiController]` equivalent.** Model binding will still fail gracefully if a required body property is wrong type, but data annotation validation (`[Required]`, `[Range]`) on your request DTO does NOT automatically trigger a 400. You must call `Validator.TryValidateObject` manually, use an endpoint filter, or integrate FluentValidation. This is the most common production mistake when migrating from controllers to minimal APIs.
- **Route groups don't support attribute-based filters — only `AddEndpointFilter`.** If you're accustomed to putting `[Authorize("PolicyName")]` on a controller, the minimal API equivalent is `.RequireAuthorization("PolicyName")` on the group or endpoint. Forgetting this and not applying auth to a group exposes endpoints you intended to protect, with no compile-time warning.

---

## Interview Angle

**What they're really testing:** Whether you understand that minimal APIs share the same underlying runtime as MVC controllers — and whether you can reason about what you gain and lose by removing the MVC layer.

**Common question form:** "What's the difference between minimal APIs and controllers?" or "When would you choose one over the other?" or "How do you validate input in a minimal API?"

**The depth signal:** A junior knows minimal APIs are "less code" and use `MapGet`. A senior can explain that both approaches use the same Kestrel server, routing engine, DI container, and middleware pipeline — the difference is purely in how endpoints are declared and dispatched. They know that minimal APIs lack automatic model validation (no `ModelStateInvalidFilter` equivalent out of the box), that `TypedResults` is required for accurate OpenAPI schema generation, that the extension method pattern (`MapOrderEndpoints`) is the standard answer to "how do you organise a large minimal API codebase," and that endpoint filters are the direct analogue of action filters — same pipeline position, different registration syntax.

---

## Related Topics

- [[dotnet/webapi-controllers.md]] — the controller-based alternative; comparing the two reveals exactly what MVC adds on top of the shared routing and middleware infrastructure
- [[dotnet/webapi-routing.md]] — minimal APIs use the same routing engine; route patterns, constraints, and `MapGroup` work identically to attribute routing
- [[dotnet/webapi-filters.md]] — `IEndpointFilter` is the minimal API equivalent of `IActionFilter`; understanding both shows how cross-cutting concerns are handled at each layer
- [[dotnet/webapi-model-validation.md]] — validation is not automatic in minimal APIs; knowing the gap is essential before deploying to production

---

## Source

[https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/overview](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/overview)

---
*Last updated: 2026-03-24*