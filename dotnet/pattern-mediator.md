# Mediator Pattern

> A mediator is an object that sits between senders and receivers so they never reference each other directly — each side only talks to the mediator.

---

## When To Use It
Use it when you have many components that need to communicate and direct references between them create a tightly coupled web that's hard to test and change. In .NET, it's most commonly used to decouple controllers from application logic — a controller sends a message, a handler processes it, and neither knows the other exists. Don't use it for simple applications where the indirection adds ceremony without removing real coupling; calling a service method directly is not a problem that needs solving.

---

## Core Concept
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
// 2. Request and handler — the core mediator unit
public record SendWelcomeEmailCommand(string Email, string Name) : IRequest;

public class SendWelcomeEmailHandler : IRequestHandler<SendWelcomeEmailCommand>
{
    private readonly IEmailService _email;

    public SendWelcomeEmailHandler(IEmailService email) => _email = email;

    public async Task Handle(SendWelcomeEmailCommand cmd, CancellationToken ct)
    {
        await _email.SendAsync(cmd.Email, $"Welcome, {cmd.Name}!");
    }
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
await _mediator.Publish(new OrderPlacedNotification(orderId));
```
```csharp
// 4. Pipeline behavior — cross-cutting logic without touching handlers
public class LoggingBehavior<TRequest, TResponse>
    : IPipelineBehavior<TRequest, TResponse> where TRequest : notnull
{
    private readonly ILogger<LoggingBehavior<TRequest, TResponse>> _logger;

    public LoggingBehavior(ILogger<LoggingBehavior<TRequest, TResponse>> logger)
        => _logger = logger;

    public async Task<TResponse> Handle(
        TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        _logger.LogInformation("Handling {Request}", typeof(TRequest).Name);
        var response = await next();                 // call the actual handler
        _logger.LogInformation("Handled {Request}", typeof(TRequest).Name);
        return response;
    }
}

// Register the behavior — applies to every IRequest<T> in the pipeline
builder.Services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
```
```csharp
// 5. Controller — sends the message, owns nothing else
[ApiController]
[Route("api/users")]
public class UsersController : ControllerBase
{
    private readonly IMediator _mediator;

    public UsersController(IMediator mediator) => _mediator = mediator;

    [HttpPost("{id}/welcome")]
    public async Task<IActionResult> SendWelcome(int id)
    {
        await _mediator.Send(new SendWelcomeEmailCommand("user@example.com", "Alice"));
        return NoContent();
    }
}
```

---

## Gotchas
- **`IRequest` vs `INotification` is not interchangeable.** `Send()` expects exactly one handler — if you register zero or two handlers for the same `IRequest`, MediatR throws at runtime. `Publish()` fans out to all registered `INotificationHandler<T>` implementations and is fine with zero handlers.
- **Pipeline behaviors are registered open-generic and apply globally.** `typeof(IPipelineBehavior<,>)` wraps every single `IRequest<T>` — commands and queries alike. If your logging behavior runs expensive operations, it runs on every request. Use marker interfaces to restrict scope.
- **Handler registration is assembly-scanned — missing handlers fail silently until runtime.** If you put a handler in a different assembly and forget to include it in `RegisterServicesFromAssembly()`, MediatR throws `InvalidOperationException` only when that request is first dispatched in production.
- **`Publish()` handlers run sequentially by default, not in parallel.** If you have three `INotificationHandler<T>` implementations, they execute one after another. A slow handler blocks the rest. If you need fan-out with parallel execution, implement a custom `INotificationPublisher`.
- **MediatR is in-process only.** Dispatching a command via MediatR does not cross a network boundary or survive a process crash. If you need durable, decoupled messaging (retry on failure, cross-service), you need a real message broker — MediatR is not a substitute.

---

## Interview Angle
**What they're really testing:** Whether you understand the purpose of the pattern — decoupling senders from receivers — versus just knowing how to wire up MediatR.

**Common question form:** *"What is the mediator pattern and why do you use MediatR in your projects?"* or *"How do you handle cross-cutting concerns like logging and validation in your API?"*

**The depth signal:** A junior describes MediatR as "it routes commands to handlers" and lists it as part of the standard project setup. A senior explains what problem it actually solves (removing direct service dependencies from controllers), distinguishes `Send` vs `Publish` semantics, knows that pipeline behaviors are the real architectural value (not just the dispatch), and is honest about the limits — MediatR is in-process and not a message bus, and adding it to a simple CRUD API introduces overhead with no benefit.

---

## Related Topics
- [[dotnet/pattern-cqrs.md]] — MediatR is the most common implementation vehicle for CQRS in .NET; the two are often conflated but are independent concepts.
- [[dotnet/pattern-repository.md]] — Handlers are the natural consumers of repositories; understanding both shows how application logic is organized end-to-end.
- [[dotnet/middleware-pipeline.md]] — ASP.NET's middleware pipeline and MediatR's behavior pipeline solve the same cross-cutting concern problem at different layers of the stack.
- [[system-design/clean-architecture.md]] — MediatR commands and queries map directly to the application layer use-case boundary in clean architecture.

---

## Source
https://github.com/jbogard/MediatR/wiki

---
*Last updated: 2026-03-24*