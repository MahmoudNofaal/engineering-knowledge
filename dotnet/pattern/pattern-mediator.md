# Mediator Pattern

> A mediator is an object that sits between senders and receivers so they never reference each other directly — each side only talks to the mediator.

---

## When To Use It

Use it when you have many components that need to communicate and direct references between them create a tightly coupled web that's hard to test and change. In .NET, it's most commonly used to decouple controllers from application logic — a controller sends a message, a handler processes it, and neither knows the other exists. Don't use it for simple applications where the indirection adds ceremony without removing real coupling; calling a service method directly is not a problem that needs solving.

---

## Core Concept

**One sentence for the interview:** The controller sends a message object into the pipeline and stops there — the mediator routes it to whoever handles it.

Without a mediator, `OrdersController` depends on `OrderService`, which depends on `InventoryService`, `EmailService`, and so on. Add a feature and you're editing a chain of classes. With a mediator, the controller just sends a message object (`CreateOrderCommand`) into a pipeline and stops there. Something else — the handler — picks it up and does the work. The controller has no idea what handler exists or what it does. In .NET, MediatR is the library that implements this: you register handlers, call `_mediator.Send()`, and MediatR routes the message to the right handler at runtime. The pattern's real power isn't just decoupling — it's that the pipeline (behaviors) lets you attach cross-cutting concerns like validation, logging, and caching to every request without touching the handlers themselves.

---

## The Code

```csharp
// 1. Setup
// dotnet add package MediatR.Extensions.Microsoft.DependencyInjection
builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly()));
```

```csharp
// 2. Request and handler — the core mediator unit, .NET 8 primary constructor
public record SendWelcomeEmailCommand(string Email, string Name) : IRequest;

public class SendWelcomeEmailHandler(IEmailService email)
    : IRequestHandler<SendWelcomeEmailCommand>
{
    public async Task Handle(SendWelcomeEmailCommand cmd, CancellationToken ct) =>
        await email.SendAsync(cmd.Email, $"Welcome, {cmd.Name}!");
}
```

```csharp
// 3. Notification — one message, many handlers (fan-out)
public record OrderPlacedNotification(int OrderId) : INotification;

public class SendConfirmationEmailHandler : INotificationHandler<OrderPlacedNotification>
{
    public Task Handle(OrderPlacedNotification n, CancellationToken ct)
    {
        Console.WriteLine($"Sending confirmation for order {n.OrderId}");
        return Task.CompletedTask;
    }
}

public class UpdateInventoryHandler : INotificationHandler<OrderPlacedNotification>
{
    public Task Handle(OrderPlacedNotification n, CancellationToken ct)
    {
        Console.WriteLine($"Updating inventory for order {n.OrderId}");
        return Task.CompletedTask;
    }
}

// Dispatching a notification — both handlers run
await mediator.Publish(new OrderPlacedNotification(orderId));
```

```csharp
// 4. Marker interfaces — scope pipeline behaviors to commands OR queries only
public interface ICommand : IRequest { }
public interface ICommand<TResponse> : IRequest<TResponse> { }
public interface IQuery<TResponse> : IRequest<TResponse> { }

// Commands and queries now have distinct types
public record CreateOrderCommand(int CustomerId, decimal Total) : ICommand<int>;
public record GetOrderSummaryQuery(int OrderId) : IQuery<OrderSummaryDto?>;

// Behavior restricted to commands only — never runs on queries
public class ValidationBehavior<TRequest, TResponse>
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : ICommand                              // ← only ICommand, not IQuery
{
    private readonly IEnumerable<IValidator<TRequest>> _validators;

    public ValidationBehavior(IEnumerable<IValidator<TRequest>> validators)
        => _validators = validators;

    public async Task<TResponse> Handle(
        TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var failures = _validators
            .Select(v => v.Validate(request))
            .SelectMany(r => r.Errors)
            .Where(e => e is not null)
            .ToList();

        if (failures.Count > 0) throw new ValidationException(failures);

        return await next();
    }
}
```

```csharp
// 5. Pipeline behavior — behaviors run in registration order, outermost first
// Registration order:
builder.Services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));   // 1st registered = outermost
builder.Services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>)); // 2nd
builder.Services.AddTransient(typeof(IPipelineBehavior<,>), typeof(CachingBehavior<,>));   // innermost

// Call order for a query: LoggingBehavior → ValidationBehavior → CachingBehavior → Handler
// Each behavior calls `next()` to pass control to the next one in the chain.

public class LoggingBehavior<TRequest, TResponse>(
    ILogger<LoggingBehavior<TRequest, TResponse>> logger)
    : IPipelineBehavior<TRequest, TResponse> where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        logger.LogInformation("Handling {Request}", typeof(TRequest).Name);
        var response = await next();
        logger.LogInformation("Handled {Request}", typeof(TRequest).Name);
        return response;
    }
}
```

```csharp
// 6. IAsyncEnumerable streaming response — for queries that return large result sets
public record GetOrderStreamQuery(int CustomerId) : IStreamRequest<OrderSummaryDto>;

public class GetOrderStreamHandler(AppDbContext context)
    : IStreamRequestHandler<GetOrderStreamQuery, OrderSummaryDto>
{
    public async IAsyncEnumerable<OrderSummaryDto> Handle(
        GetOrderStreamQuery query,
        [EnumeratorCancellation] CancellationToken ct)
    {
        await foreach (var order in context.Orders
            .Where(o => o.CustomerId == query.CustomerId)
            .AsAsyncEnumerable()
            .WithCancellation(ct))
        {
            yield return new OrderSummaryDto { Id = order.Id, Total = order.Total };
        }
    }
}

// Controller — streams response without loading all records into memory
[HttpGet("{customerId}/stream")]
public async IAsyncEnumerable<OrderSummaryDto> StreamOrders(int customerId,
    [EnumeratorCancellation] CancellationToken ct)
{
    await foreach (var dto in mediator.CreateStream(new GetOrderStreamQuery(customerId), ct))
        yield return dto;
}
```

```csharp
// 7. Controller — thin, just dispatches
[ApiController]
[Route("api/users")]
public class UsersController(IMediator mediator) : ControllerBase
{
    [HttpPost("{id}/welcome")]
    public async Task<IActionResult> SendWelcome(int id)
    {
        await mediator.Send(new SendWelcomeEmailCommand("user@example.com", "Alice"));
        return NoContent();
    }
}
```

---

## Gotchas

- **`IRequest` vs `INotification` is not interchangeable.** `Send()` expects exactly one handler — if you register zero or two handlers for the same `IRequest`, MediatR throws at runtime. `Publish()` fans out to all registered `INotificationHandler<T>` implementations and is fine with zero handlers.

- **Pipeline behaviors are registered open-generic and apply globally.** `typeof(IPipelineBehavior<,>)` wraps every single `IRequest<T>` — commands and queries alike. Use `ICommand` / `IQuery` marker interfaces to restrict scope. If your validation behavior runs on read-only queries, it runs on every cache hit too.

- **Handler registration is assembly-scanned — missing handlers fail silently until runtime.** If you put a handler in a different assembly and forget to include it in `RegisterServicesFromAssembly()`, MediatR throws `InvalidOperationException` only when that request is first dispatched in production.

- **`Publish()` handlers run sequentially by default, not in parallel.** If you have three `INotificationHandler<T>` implementations, they execute one after another. A slow handler blocks the rest. If you need fan-out with parallel execution, implement a custom `INotificationPublisher`.

- **MediatR is in-process only.** Dispatching a command via MediatR does not cross a network boundary or survive a process crash. If you need durable, decoupled messaging (retry on failure, cross-service), you need a real message broker — MediatR is not a substitute.

- **Defining the handler class nested inside the request record is a popular style but hides layer boundaries.** Putting `CreateOrderCommand` and `CreateOrderHandler` in the same file is convenient, but it pulls Infrastructure concerns (DbContext) into the same namespace as the command definition. In clean architecture, the command belongs in Application; the handler belongs in Application too, but its dependencies must only be Application-layer interfaces. Nesting encourages shortcuts.

- **MediatR v12 changed the registration API.** `AddMediatR(Assembly)` is gone; it's now `AddMediatR(cfg => cfg.RegisterServicesFromAssembly(...))`. If you see older blog posts with the old API, they're pre-v12.

---

## Interview Angle

**What they're really testing:** Whether you understand the purpose of the pattern — decoupling senders from receivers — versus just knowing how to wire up MediatR.

**Common question form:** *"What is the mediator pattern and why do you use MediatR in your projects?"* or *"How do you handle cross-cutting concerns like logging and validation in your API?"*

**The depth signal:** A junior describes MediatR as "it routes commands to handlers" and lists it as part of the standard project setup. A senior explains what problem it actually solves (removing direct service dependencies from controllers), distinguishes `Send` vs `Publish` semantics, knows that pipeline behaviors are the real architectural value (not just the dispatch), and is honest about the limits — MediatR is in-process and not a message bus, and adding it to a simple CRUD API introduces overhead with no benefit.

**Follow-up the interviewer asks next:** *"How would you unit test a handler that sits behind a validation pipeline behavior?"*

Test the handler in isolation — don't go through MediatR at all. The handler is just a class; construct it directly with a fake repository, call `Handle()`, assert on the result. The validation behavior is tested separately with its own unit tests. Integration tests can go through the full MediatR pipeline to verify the behaviors compose correctly. If you're constructing `IMediator` in every unit test and wiring up the full pipeline, you've made testing harder than it needs to be — MediatR isn't the system under test, the handler logic is.

---

## Related Topics

- [[dotnet/pattern/pattern-cqrs.md]] — MediatR is the most common implementation vehicle for CQRS in .NET; the two are often conflated but are independent concepts.
- [[dotnet/pattern/pattern-repository.md]] — Handlers are the natural consumers of repositories; understanding both shows how application logic is organized end-to-end.
- [[dotnet/webapi/middleware-pipeline.md]] — ASP.NET's middleware pipeline and MediatR's behavior pipeline solve the same cross-cutting concern problem at different layers of the stack.
- [[dotnet/pattern/pattern-clean-architecture.md]] — MediatR commands and queries map directly to the application layer use-case boundary in clean architecture.

---

## Source

https://github.com/jbogard/MediatR/wiki

---

*Last updated: 2026-04-09*