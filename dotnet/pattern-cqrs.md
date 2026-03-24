# CQRS Pattern

> CQRS (Command Query Responsibility Segregation) means using separate models and code paths for reads and writes instead of one shared service that does both.

---

## When To Use It
Use it when your read and write workloads have meaningfully different shapes — e.g., writes go through validation and domain logic, reads need flat DTOs optimized for display. It pays off in complex domains where a single service class accumulates too many responsibilities, or where read performance needs to be optimized independently of writes (separate read replicas, projections, caching). Don't use it in simple CRUD applications — you'll end up with twice the classes and half the clarity.

---

## Core Concept
The core observation is that reads and writes are fundamentally different operations. A write (command) changes state and needs validation, business rules, and atomicity. A read (query) just fetches data and needs to be fast and shaped for the UI. When you put both through the same service and the same entity model, the model gets pulled in two directions — bloated with properties for queries, constrained by invariants for writes. CQRS splits them: commands go through domain logic and return nothing (or just an ID), queries bypass the domain model entirely and go straight to the database returning a DTO. In .NET, MediatR is the common implementation vehicle — commands and queries are message objects dispatched to handlers, which keeps controllers thin and logic organized by operation rather than by entity.

---

## The Code
```csharp
// 1. MediatR setup
// dotnet add package MediatR.Extensions.Microsoft.DependencyInjection
builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly()));
```
```csharp
// 2. Command — changes state, returns minimal result
public record CreateOrderCommand(int CustomerId, decimal Total) : IRequest<int>;

public class CreateOrderHandler : IRequestHandler<CreateOrderCommand, int>
{
    private readonly AppDbContext _context;

    public CreateOrderHandler(AppDbContext context) => _context = context;

    public async Task<int> Handle(CreateOrderCommand cmd, CancellationToken ct)
    {
        var order = new Order { CustomerId = cmd.CustomerId, Total = cmd.Total };
        _context.Orders.Add(order);
        await _context.SaveChangesAsync(ct);
        return order.Id;                             // return only the new ID, not the entity
    }
}
```
```csharp
// 3. Query — reads only, returns a flat DTO, no domain model involved
public record GetOrderSummaryQuery(int OrderId) : IRequest<OrderSummaryDto?>;

public class GetOrderSummaryHandler : IRequestHandler<GetOrderSummaryQuery, OrderSummaryDto?>
{
    private readonly AppDbContext _context;

    public GetOrderSummaryHandler(AppDbContext context) => _context = context;

    public Task<OrderSummaryDto?> Handle(GetOrderSummaryQuery qry, CancellationToken ct) =>
        _context.Orders
            .AsNoTracking()                          // never track on query side
            .Where(o => o.Id == qry.OrderId)
            .Select(o => new OrderSummaryDto
            {
                Id = o.Id,
                CustomerName = o.Customer.Name,
                Total = o.Total,
                Status = o.Status.ToString()
            })
            .FirstOrDefaultAsync(ct);
}
```
```csharp
// 4. Controller — thin, just dispatches
[ApiController]
[Route("api/orders")]
public class OrdersController : ControllerBase
{
    private readonly IMediator _mediator;

    public OrdersController(IMediator mediator) => _mediator = mediator;

    [HttpPost]
    public async Task<IActionResult> Create(CreateOrderCommand cmd)
    {
        var id = await _mediator.Send(cmd);
        return CreatedAtAction(nameof(Get), new { id }, null);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(int id)
    {
        var result = await _mediator.Send(new GetOrderSummaryQuery(id));
        return result is null ? NotFound() : Ok(result);
    }
}
```
```csharp
// 5. Pipeline behavior — cross-cutting concerns via MediatR (e.g., validation)
public class ValidationBehavior<TRequest, TResponse>
    : IPipelineBehavior<TRequest, TResponse> where TRequest : notnull
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
            .Where(e => e != null)
            .ToList();

        if (failures.Count != 0)
            throw new ValidationException(failures);

        return await next();                         // proceed to actual handler
    }
}
```

---

## Gotchas
- **CQRS does not require Event Sourcing.** They're often mentioned together but are fully independent. You can implement CQRS with a single relational database and EF Core. Conflating them leads to over-engineered solutions for problems you don't have.
- **Commands returning void break REST conventions awkwardly.** Returning just an ID or nothing is correct for CQRS purity, but `201 Created` with a `Location` header needs the ID. Returning the full entity from a command is a common compromise — it's pragmatic but blurs the pattern.
- **MediatR is a tool, not the pattern.** CQRS is the separation of reads and writes. MediatR is a mediator / in-process message bus that makes the dispatch mechanism clean. You can do CQRS without MediatR; using MediatR without actually separating read/write models isn't CQRS.
- **Query handlers that reuse command-side domain entities defeat the point.** If your query handler loads a full `Order` aggregate with all its navigation properties just to map it to a DTO, you're paying the command-side cost on the query path. Project directly to the DTO in the query.
- **Pipeline behaviors apply to both commands and queries by default.** If you register a logging or validation behavior globally, it runs on every `IRequest<T>` — including queries. Use marker interfaces (`ICommand`, `IQuery`) to restrict behaviors to the right side if you need them to diverge.

---

## Interview Angle
**What they're really testing:** Whether you understand the *reason* for the separation — different consistency and performance requirements for reads vs writes — and not just the mechanical implementation with MediatR.

**Common question form:** *"What is CQRS and when would you use it?"* or *"How do you structure your application layer — do you use MediatR?"*

**The depth signal:** A junior describes CQRS as "commands change data, queries read data, MediatR dispatches them" and treats it as a standard template to apply everywhere. A senior explains the actual tradeoff: it adds indirection and class count, but earns it when read and write models genuinely diverge — e.g., denormalized read projections, separate read replicas, or event-driven write sides. They also know the failure modes: commands that return full entities, query handlers that load domain aggregates, and validation pipelines accidentally running on read paths.

---

## Related Topics
- [[dotnet/pattern-repository.md]] — CQRS query handlers often bypass the repository entirely and query EF directly; understanding why illuminates the limits of a uniform repository abstraction.
- [[dotnet/ef-performance.md]] — The query side of CQRS is where `AsNoTracking()`, projection, and split queries matter most — the read path should be as lean as possible.
- [[system-design/event-sourcing.md]] — Frequently paired with CQRS in distributed systems; the write side emits events, the read side builds projections from them.
- [[dotnet/pattern-unit-of-work.md]] — Command handlers are the natural place to use a unit of work; query handlers should never touch it.

---

## Source
https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs

---
*Last updated: 2026-03-24*