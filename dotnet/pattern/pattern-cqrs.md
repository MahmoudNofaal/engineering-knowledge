# CQRS Pattern

> CQRS (Command Query Responsibility Segregation) means using separate models and code paths for reads and writes instead of one shared service that does both.

---

## When To Use It

Use it when your read and write workloads have meaningfully different shapes — e.g., writes go through validation and domain logic, reads need flat DTOs optimized for display. It pays off in complex domains where a single service class accumulates too many responsibilities, or where read performance needs to be optimized independently of writes (separate read replicas, projections, caching). Don't use it in simple CRUD applications — you'll end up with twice the classes and half the clarity.

---

## Core Concept

**One sentence for the interview:** Commands change state and go through domain logic; queries just fetch data and go straight to the database as a flat DTO.

The core observation is that reads and writes are fundamentally different operations. A write (command) changes state and needs validation, business rules, and atomicity. A read (query) just fetches data and needs to be fast and shaped for the UI. When you put both through the same service and the same entity model, the model gets pulled in two directions — bloated with properties for queries, constrained by invariants for writes. CQRS splits them: commands go through domain logic and return nothing (or just an ID), queries bypass the domain model entirely and go straight to the database returning a DTO. In .NET, MediatR is the common implementation vehicle — commands and queries are message objects dispatched to handlers, which keeps controllers thin and logic organized by operation rather than by entity.

---

## The Code

```csharp
// 1. MediatR setup with marker interfaces — scope behaviors to command OR query side
builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly()));

public interface ICommand<TResponse> : IRequest<TResponse> { }
public interface IQuery<TResponse> : IRequest<TResponse> { }
```

```csharp
// 2. Command — changes state, returns minimal result, .NET 8 primary constructor
public record CreateOrderCommand(int CustomerId, decimal Total) : ICommand<int>;

public class CreateOrderHandler(AppDbContext context)
    : IRequestHandler<CreateOrderCommand, int>
{
    public async Task<int> Handle(CreateOrderCommand cmd, CancellationToken ct)
    {
        var order = new Order { CustomerId = cmd.CustomerId, Total = cmd.Total };
        context.Orders.Add(order);
        await context.SaveChangesAsync(ct);
        return order.Id;                             // return only the new ID, not the entity
    }
}
```

```csharp
// 3. Query — reads only, returns a flat DTO, no domain model involved
public record GetOrderSummaryQuery(int OrderId) : IQuery<OrderSummaryDto?>;

public class GetOrderSummaryHandler(AppDbContext context)
    : IRequestHandler<GetOrderSummaryQuery, OrderSummaryDto?>
{
    public Task<OrderSummaryDto?> Handle(GetOrderSummaryQuery qry, CancellationToken ct) =>
        context.Orders
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
// 4. Read replica separation — two DbContext registrations for read vs write
// Write context — full tracking, read-write connection string
builder.Services.AddDbContext<WriteDbContext>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("Primary")));

// Read context — no tracking by default, read-only replica connection string
builder.Services.AddDbContext<ReadDbContext>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("ReadReplica"))
     .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking));

// Command handlers inject WriteDbContext; query handlers inject ReadDbContext
public class CreateOrderHandler(WriteDbContext context) : IRequestHandler<CreateOrderCommand, int>
{
    // writes go to primary
}

public class GetOrderSummaryHandler(ReadDbContext context) : IRequestHandler<GetOrderSummaryQuery, OrderSummaryDto?>
{
    // reads go to replica — may lag by milliseconds, acceptable for reads
}
```

```csharp
// 5. Pipeline behavior — validation scoped to commands only via marker interface
public class ValidationBehavior<TRequest, TResponse>
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : ICommand<TResponse>             // ← only ICommand, not IQuery
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

```csharp
// 6. Controller — thin, just dispatches
[ApiController]
[Route("api/orders")]
public class OrdersController(IMediator mediator) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Create(CreateOrderCommand cmd)
    {
        var id = await mediator.Send(cmd);
        return CreatedAtAction(nameof(Get), new { id }, null);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(int id)
    {
        var result = await mediator.Send(new GetOrderSummaryQuery(id));
        return result is null ? NotFound() : Ok(result);
    }
}
```

---

## Gotchas

- **CQRS does not require Event Sourcing.** They're often mentioned together but are fully independent. You can implement CQRS with a single relational database and EF Core. Conflating them leads to over-engineered solutions for problems you don't have.

- **Commands returning void break REST conventions awkwardly.** Returning just an ID or nothing is correct for CQRS purity, but `201 Created` with a `Location` header needs the ID. Returning the full entity from a command is a common compromise — it's pragmatic but blurs the pattern.

- **MediatR is a tool, not the pattern.** CQRS is the separation of reads and writes. MediatR is a mediator / in-process message bus that makes the dispatch mechanism clean. You can do CQRS without MediatR; using MediatR without actually separating read/write models isn't CQRS.

- **Query handlers that reuse command-side domain entities defeat the point.** If your query handler loads a full `Order` aggregate with all its navigation properties just to map it to a DTO, you're paying the command-side cost on the query path. Project directly to the DTO in the query.

- **`ValidationBehavior` accidentally runs on queries without marker interfaces.** If you register a global `IPipelineBehavior<TRequest, TResponse>` without constraining `TRequest` to `ICommand`, validators run on every read-only query too — adding latency and noise for queries that never mutate state. Use `ICommand<TResponse>` as the constraint.

- **Eventual consistency in distributed CQRS.** If commands go to one service and queries read from a separate read-model updated by events, the read model may lag the write by milliseconds to seconds. Callers issuing a command and immediately querying may see stale data. Design the UI for eventual consistency — show the command's confirmed result optimistically, don't immediately re-query.

- **Command handlers doing too much.** Once handlers become the application layer, the temptation is to put orchestration logic directly in them — call three repositories, fire domain events, send emails. A handler that does five things is just a service method with more ceremony. Keep handlers focused on a single use case and delegate to domain objects and services.

---

## Interview Angle

**What they're really testing:** Whether you understand the *reason* for the separation — different consistency and performance requirements for reads vs writes — and not just the mechanical implementation with MediatR.

**Common question form:** *"What is CQRS and when would you use it?"* or *"How do you structure your application layer — do you use MediatR?"*

**The depth signal:** A junior describes CQRS as "commands change data, queries read data, MediatR dispatches them" and treats it as a standard template to apply everywhere. A senior explains the actual tradeoff: it adds indirection and class count, but earns it when read and write models genuinely diverge — e.g., denormalized read projections, separate read replicas, or event-driven write sides. They also know the failure modes: commands that return full entities, query handlers that load domain aggregates, and validation pipelines accidentally running on read paths.

**Follow-up the interviewer asks next:** *"How does CQRS differ from a simple service layer that has separate read and write methods?"*

A service layer with `GetOrder()` and `CreateOrder()` on the same class is technically also segregating reads from writes — but it's not CQRS. The distinction is the *model*. CQRS means the read side has a different data model (flat DTOs, denormalized projections, potentially a separate database) from the write side (domain entities, aggregates, change tracking). A service layer with separate methods but the same underlying `Order` entity and same `DbContext` for both is just good organization, not CQRS. The value of CQRS is optimizing the two sides independently — AsNoTracking + projection for reads, full aggregate loading + domain logic for writes — not just having separate method names.

---

## Related Topics

- [[dotnet/pattern/pattern-repository.md]] — CQRS query handlers often bypass the repository entirely and query EF directly; understanding why illuminates the limits of a uniform repository abstraction.
- [[dotnet/ef/ef-performance.md]] — The query side of CQRS is where `AsNoTracking()`, projection, and split queries matter most — the read path should be as lean as possible.
- [[dotnet/pattern/pattern-mediator.md]] — MediatR is the delivery mechanism for CQRS in .NET; understanding pipeline behaviors and Send vs Publish semantics is essential.
- [[dotnet/pattern/pattern-unit-of-work.md]] — Command handlers are the natural place to use a unit of work; query handlers should never touch it.
- [[dotnet/pattern/pattern-clean-architecture.md]] — Commands and queries map to application layer use cases; clean architecture defines what they're allowed to depend on.

---

## Source

https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs

---

*Last updated: 2026-04-09*