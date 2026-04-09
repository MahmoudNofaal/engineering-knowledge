# Clean Architecture

> Clean architecture organizes code into concentric layers where dependencies only point inward — outer layers know about inner layers, inner layers know nothing about outer layers.

---

## When To Use It

Use it when your application has real domain logic that needs to be tested and changed independently of infrastructure — databases, HTTP clients, file systems. It earns its cost in medium-to-large applications where the business rules are the valuable part and you want them isolated from framework churn. Don't use it for simple CRUD APIs where the "domain logic" is saving a form to a database — you'll spend 80% of your time mapping between layers that don't need to exist. A feature-sliced structure or vertical slice architecture is often a better fit for those cases.

---

## Core Concept

**One sentence for the interview:** The domain layer is the center of the universe — everything else depends on it, and it depends on nothing.

The core rule is the dependency rule: source code dependencies can only point inward. The domain layer (entities, value objects, domain events) has zero external dependencies — no EF Core, no ASP.NET, no NuGet packages. The application layer (use cases, command/query handlers, service interfaces) depends on the domain but not on infrastructure. The infrastructure layer (EF Core DbContext, HTTP clients, email senders) implements the interfaces the application layer defined. The presentation layer (controllers, minimal API endpoints) calls into the application layer and knows nothing about the database.

This means when you swap PostgreSQL for SQL Server, or REST for gRPC, only the outer layer changes. The domain and application layers don't touch. That's the whole point.

```
Presentation  →  Application  →  Domain
Infrastructure  →  Application  →  Domain

(arrows = "depends on")
Domain depends on nothing.
```

---

## The Code

```csharp
// Project structure — each layer is a separate .csproj
// Domain          → no dependencies
// Application     → depends on Domain
// Infrastructure  → depends on Application + Domain
// WebApi          → depends on Application + Infrastructure (for DI wiring only)

// Domain layer — pure C#, no framework references
// Domain/Entities/Order.cs
public class Order
{
    public int Id { get; private set; }
    public int CustomerId { get; private set; }
    public decimal Total { get; private set; }
    public OrderStatus Status { get; private set; }

    private readonly List<DomainEvent> _events = new();
    public IReadOnlyList<DomainEvent> DomainEvents => _events;

    public static Order Create(int customerId, decimal total)
    {
        if (total <= 0) throw new DomainException("Order total must be positive.");
        var order = new Order { CustomerId = customerId, Total = total, Status = OrderStatus.Pending };
        order._events.Add(new OrderCreatedEvent(order.Id, customerId));
        return order;
    }

    public void Ship()
    {
        if (Status != OrderStatus.Pending) throw new DomainException("Only pending orders can be shipped.");
        Status = OrderStatus.Shipped;
    }
}
```

```csharp
// Application layer — interfaces defined here, implemented in Infrastructure
// Application/Interfaces/IOrderRepository.cs
public interface IOrderRepository                        // interface lives in Application
{
    Task<Order?> GetByIdAsync(int id, CancellationToken ct = default);
    Task AddAsync(Order order, CancellationToken ct = default);
    Task SaveChangesAsync(CancellationToken ct = default);
}

// Application/Interfaces/IEmailService.cs
public interface IEmailService
{
    Task SendAsync(string to, string subject, string body, CancellationToken ct = default);
}
```

```csharp
// Application layer — use case / command handler (MediatR)
// Application/Orders/Commands/CreateOrderCommand.cs
public record CreateOrderCommand(int CustomerId, decimal Total) : IRequest<int>;

public class CreateOrderHandler(IOrderRepository orders, IMediator mediator)
    : IRequestHandler<CreateOrderCommand, int>
{
    public async Task<int> Handle(CreateOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(cmd.CustomerId, cmd.Total);  // domain creates the entity
        await orders.AddAsync(order, ct);
        await orders.SaveChangesAsync(ct);

        foreach (var e in order.DomainEvents)
            await mediator.Publish(e, ct);                    // dispatch domain events after save

        return order.Id;
    }
}
```

```csharp
// Infrastructure layer — implements Application interfaces
// Infrastructure/Persistence/OrderRepository.cs
public class OrderRepository(AppDbContext context) : IOrderRepository
{
    public Task<Order?> GetByIdAsync(int id, CancellationToken ct) =>
        context.Orders.FirstOrDefaultAsync(o => o.Id == id, ct);

    public async Task AddAsync(Order order, CancellationToken ct) =>
        await context.Orders.AddAsync(order, ct);

    public Task SaveChangesAsync(CancellationToken ct) =>
        context.SaveChangesAsync(ct);
}

// Infrastructure/Persistence/AppDbContext.cs
public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
```

```csharp
// Presentation layer — thin controllers, just dispatch
// WebApi/Controllers/OrdersController.cs
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
    public async Task<IActionResult> Get(int id) =>
        await mediator.Send(new GetOrderSummaryQuery(id)) is { } result
            ? Ok(result)
            : NotFound();
}
```

```csharp
// WebApi/Program.cs — the only place Infrastructure is wired to Application
// This is the composition root — the one place that knows about all layers
builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddScoped<IOrderRepository, OrderRepository>();   // Infrastructure → Application interface
builder.Services.AddScoped<IEmailService, SmtpEmailService>();

builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssembly(typeof(CreateOrderCommand).Assembly)); // Application assembly
```

---

## Gotchas

- **The dependency rule is violated the moment Infrastructure is referenced from Domain or Application.** The most common slip: adding a NuGet package to the Domain project. If `Domain.csproj` has a `<PackageReference>` to `Microsoft.EntityFrameworkCore`, the dependency rule is already broken. EF attributes (`[Key]`, `[Column]`) belong in the infrastructure mapping, not on the entity.

- **Interfaces belong in the layer that consumes them, not the layer that implements them.** `IOrderRepository` lives in Application (the consumer), not Infrastructure (the implementor). This is the dependency inversion principle in action — Infrastructure depends on Application's interface, not the other way around.

- **Mapping between layers is a cost that compounds.** Domain entity → Application DTO → API response model means three representations of the same data. For simple apps this is pure overhead. If you find yourself writing identical mapping code for every property, consider whether the layers are earning their keep or whether a direct query (Dapper, raw EF projection) is the honest choice for that use case.

- **`Program.cs` knowing about Infrastructure is correct and intentional.** The composition root is the one place that's allowed to know everything — it's where the wiring happens. Developers sometimes try to hide `OrderRepository` from `Program.cs` behind a `Infrastructure.DependencyInjection` extension method. That's fine for organization, but understand it's still a reference to Infrastructure; it just moves where the reference appears.

- **Domain events dispatched in the handler are in-process only.** Calling `mediator.Publish(domainEvent)` inside the command handler is synchronous and in-memory. If the process crashes after `SaveChanges` but before `Publish`, the event is lost. For durable event publishing across services, you need the Outbox pattern — clean architecture doesn't solve that on its own.

- **Testing the application layer requires faking the infrastructure interfaces.** This is the whole point of the dependency inversion. `IOrderRepository` can be implemented as an in-memory fake for unit tests. If you're spinning up a real database to test a command handler, either the handler has leaked infrastructure concerns, or you're writing an integration test — both are valid, but they're different things.

---

## Interview Angle

**What they're really testing:** Whether you understand the dependency rule and can explain *why* it exists — not just draw a diagram of four circles.

**Common question form:** *"How do you structure a .NET application?"* or *"What is clean architecture and when would you use it?"* or *"Where does the repository interface live in your project structure?"*

**The depth signal:** A junior draws the four layers and says "domain in the middle, infrastructure on the outside." A senior explains the dependency rule directionally — Domain has no dependencies, Application depends only on Domain, Infrastructure implements Application interfaces — and knows the practical implication: you can test the entire application layer with fakes and never touch a database. They also know when *not* to use it: a CRUD API with no real domain logic doesn't need four projects; the abstraction cost isn't justified.

**Follow-up the interviewer asks next:** *"If the domain layer has no dependencies, how does EF Core know about your entities?"*

The answer: EF Core doesn't need to reference the domain — the domain entities are plain C# classes. The Infrastructure layer references both `Domain` and `EntityFrameworkCore`. The `DbContext` and `IEntityTypeConfiguration<Order>` live in Infrastructure. EF maps to the domain entity's properties (which can be private setters via `UsePropertyAccessMode`) without the domain entity needing any EF attributes.

---

## Related Topics

- [[dotnet/pattern/pattern-repository.md]] — The repository interface lives in the Application layer; the EF Core implementation lives in Infrastructure. Clean architecture explains why the split exists.
- [[dotnet/pattern/pattern-cqrs.md]] — MediatR command and query handlers are the application layer's use cases; clean architecture gives them a home and defines what they're allowed to depend on.
- [[dotnet/pattern/pattern-mediator.md]] — MediatR is the most common implementation vehicle for the application layer boundary; `IMediator` is the entry point from Presentation into Application.
- [[dotnet/pattern/dependency-injection.md]] — The composition root (`Program.cs`) is where Infrastructure binds to Application interfaces; understanding DI lifetimes is essential to wiring layers correctly.
- [[dotnet/pattern/pattern-domain-events.md]] — Domain events raised on entities and dispatched in command handlers are a core application layer pattern in clean architecture.

---

## Source

https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures

---

*Last updated: 2026-04-09*