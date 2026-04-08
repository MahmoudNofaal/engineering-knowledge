# EF Core Interceptors

> Hooks that let you intercept and optionally modify EF Core operations — query execution, command creation, SaveChanges, and connection events — without modifying entity classes or service code.

---

## When To Use It

Use interceptors for cross-cutting concerns that need to run around every EF operation: audit logging, soft-delete enforcement, query tagging for profiling, slow query detection, and connection retry telemetry. Interceptors are the right tool when the behaviour belongs to the infrastructure layer — not the domain or service layer — and needs to apply transparently to all operations. Don't use interceptors for business logic that should be visible to service code; interceptors are invisible to callers and can make behaviour surprising to debug.

---

## Core Concept

EF Core defines several interception points, each with its own interface. `ISaveChangesInterceptor` fires before and after `SaveChanges` — the right place for audit stamps, soft delete conversion, and domain event dispatch. `IDbCommandInterceptor` fires before and after every SQL command — the right place for query tagging, slow query logging, and command text modification. `IDbConnectionInterceptor` fires on connection open/close — useful for connection-level telemetry. Interceptors are registered on `DbContextOptionsBuilder` and can be scoped services (injected from DI) — meaning they have access to the current HTTP request's user identity, tenant, and other ambient context.

---

## The Code

**1. SaveChangesInterceptor — audit stamps without touching entity code**
```csharp
// Infrastructure/Interceptors/AuditInterceptor.cs
public class AuditInterceptor : SaveChangesInterceptor
{
    private readonly ICurrentUserService _currentUser;

    public AuditInterceptor(ICurrentUserService currentUser)
        => _currentUser = currentUser;

    // Fires synchronously before SaveChanges
    public override InterceptionResult<int> SavingChanges(
        DbContextEventData eventData, InterceptionResult<int> result)
    {
        ApplyAuditStamps(eventData.Context!);
        return result;
    }

    // Fires asynchronously before SaveChangesAsync
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData,
        InterceptionResult<int> result,
        CancellationToken ct = default)
    {
        ApplyAuditStamps(eventData.Context!);
        return new ValueTask<InterceptionResult<int>>(result);
    }

    private void ApplyAuditStamps(DbContext context)
    {
        var userId = _currentUser.UserId;
        var now    = DateTime.UtcNow;

        foreach (var entry in context.ChangeTracker.Entries<IAuditableEntity>())
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedAt = now;
                    entry.Entity.CreatedBy = userId;
                    entry.Entity.UpdatedAt = now;
                    entry.Entity.UpdatedBy = userId;
                    break;

                case EntityState.Modified:
                    entry.Entity.UpdatedAt = now;
                    entry.Entity.UpdatedBy = userId;
                    // Prevent accidental overwrite of CreatedAt on update
                    entry.Property(e => e.CreatedAt).IsModified = false;
                    entry.Property(e => e.CreatedBy).IsModified = false;
                    break;
            }
        }
    }
}
```

**2. Soft-delete interceptor — convert Remove() to a flag update**
```csharp
public class SoftDeleteInterceptor : SaveChangesInterceptor
{
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData,
        InterceptionResult<int> result,
        CancellationToken ct = default)
    {
        if (eventData.Context is null) return base.SavingChangesAsync(eventData, result, ct);

        foreach (var entry in eventData.Context.ChangeTracker.Entries<ISoftDeletable>())
        {
            if (entry.State == EntityState.Deleted)
            {
                entry.State            = EntityState.Modified; // prevent actual DELETE
                entry.Entity.IsDeleted = true;
                entry.Entity.DeletedAt = DateTime.UtcNow;
            }
        }

        return base.SavingChangesAsync(eventData, result, ct);
    }
}

// Entity interface
public interface ISoftDeletable
{
    bool      IsDeleted { get; set; }
    DateTime? DeletedAt { get; set; }
}
```

**3. DbCommandInterceptor — slow query detection**
```csharp
public class SlowQueryInterceptor : DbCommandInterceptor
{
    private readonly ILogger<SlowQueryInterceptor> _logger;
    private static readonly TimeSpan SlowThreshold = TimeSpan.FromMilliseconds(500);

    public SlowQueryInterceptor(ILogger<SlowQueryInterceptor> logger)
        => _logger = logger;

    public override DbDataReader ReaderExecuted(
        DbCommand command,
        CommandExecutedEventData eventData,
        DbDataReader result)
    {
        if (eventData.Duration > SlowThreshold)
        {
            _logger.LogWarning(
                "Slow EF query detected ({Duration}ms):\n{Sql}",
                eventData.Duration.TotalMilliseconds,
                command.CommandText);
        }

        return result;
    }

    public override ValueTask<DbDataReader> ReaderExecutedAsync(
        DbCommand command,
        CommandExecutedEventData eventData,
        DbDataReader result,
        CancellationToken ct = default)
    {
        if (eventData.Duration > SlowThreshold)
        {
            _logger.LogWarning(
                "Slow EF query detected ({Duration}ms):\n{Sql}",
                eventData.Duration.TotalMilliseconds,
                command.CommandText);
        }

        return new ValueTask<DbDataReader>(result);
    }
}
```

**4. DbCommandInterceptor — query tagging for profiling**
```csharp
// Adds a SQL comment to every query — visible in SQL Profiler and Azure Query Insights
public class QueryTagInterceptor : DbCommandInterceptor
{
    private readonly IHttpContextAccessor _httpContext;

    public QueryTagInterceptor(IHttpContextAccessor httpContext)
        => _httpContext = httpContext;

    public override InterceptionResult<DbDataReader> ReaderExecuting(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<DbDataReader> result)
    {
        var requestPath = _httpContext.HttpContext?.Request.Path.ToString() ?? "background";
        command.CommandText = $"/* {requestPath} */\n{command.CommandText}";
        return result;
    }
}

// Alternative: use EF Core's built-in TagWith() per query
var products = await context.Products
    .TagWith("ProductsController.GetAll")  // adds a comment to the generated SQL
    .Where(p => p.IsActive)
    .ToListAsync();
```

**5. Registering interceptors in Program.cs**
```csharp
// Scoped interceptors need per-request DI access (e.g. current user, tenant)
builder.Services.AddScoped<AuditInterceptor>();
builder.Services.AddScoped<SoftDeleteInterceptor>();
builder.Services.AddSingleton<SlowQueryInterceptor>(); // stateless — singleton is fine

builder.Services.AddDbContext<AppDbContext>((serviceProvider, options) =>
{
    options.UseSqlServer(connectionString)
           .AddInterceptors(
               serviceProvider.GetRequiredService<AuditInterceptor>(),
               serviceProvider.GetRequiredService<SoftDeleteInterceptor>(),
               serviceProvider.GetRequiredService<SlowQueryInterceptor>());
});
```

**6. SaveChangesInterceptor — dispatching domain events after commit**
```csharp
// Fire domain events only after SaveChanges succeeds — not before (commit may fail)
public class DomainEventInterceptor : SaveChangesInterceptor
{
    private readonly IMediator _mediator;
    private List<IDomainEvent> _pendingEvents = [];

    public DomainEventInterceptor(IMediator mediator) => _mediator = mediator;

    public override async ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData,
        InterceptionResult<int> result,
        CancellationToken ct = default)
    {
        // Collect domain events before saving (entities may be cleared after save)
        _pendingEvents = eventData.Context!.ChangeTracker
            .Entries<IHasDomainEvents>()
            .SelectMany(e => e.Entity.DomainEvents)
            .ToList();

        foreach (var entry in eventData.Context.ChangeTracker.Entries<IHasDomainEvents>())
            entry.Entity.ClearDomainEvents();

        return await base.SavingChangesAsync(eventData, result, ct);
    }

    public override async ValueTask<int> SavedChangesAsync(
        SaveChangesCompletedEventData eventData,
        int result,
        CancellationToken ct = default)
    {
        // Dispatch AFTER commit — events are published only if the transaction succeeded
        foreach (var domainEvent in _pendingEvents)
            await _mediator.Publish(domainEvent, ct);

        _pendingEvents.Clear();
        return await base.SavedChangesAsync(eventData, result, ct);
    }
}
```

---

## Gotchas

- **Scoped interceptors registered on a pooled DbContext context can cause lifetime issues.** If you use `AddDbContextPool`, the pool reuses context instances. A scoped interceptor resolved per-request is correct for standard `AddDbContext` but may behave unexpectedly with pooling. Test interceptor behaviour with your registration strategy.
- **Interceptors registered on `AddDbContext` fire for every save — including `MigrateAsync()`.** Your audit interceptor will try to stamp migrations as if they were user operations. Guard against this by checking whether `_currentUser.UserId` is null or system-level before applying stamps.
- **`SavingChangesAsync` runs before commit — exceptions thrown here roll back the transaction.** If your interceptor throws (e.g. current user service is unavailable), `SaveChangesAsync` throws too and the entire unit of work rolls back. This is usually correct, but make sure your interceptors handle transient failures gracefully.
- **`SavedChangesAsync` (post-commit) is not in the same transaction.** Domain events dispatched in `SavedChangesAsync` run after the database commit. If event dispatch fails (e.g. message broker is down), the database change is already committed. Use the outbox pattern for guaranteed delivery.
- **Multiple interceptors of the same type are all called.** If you register two `ISaveChangesInterceptor` implementations, both fire. Order matters — they fire in registration order. Design interceptors to be composable and order-independent where possible.

---

## Interview Angle

**What they're really testing:** Whether you know how to separate cross-cutting infrastructure concerns from business logic in EF Core, and whether you understand the lifecycle differences between pre-save and post-save hooks.

**Common question form:** *"How do you automatically stamp CreatedAt/UpdatedAt on entities?"* or *"How do you implement soft delete in EF Core?"*

**The depth signal:** A junior overrides `SaveChangesAsync` in `DbContext` and stamps fields there. A senior reaches for a `SaveChangesInterceptor` — testable in isolation, no DbContext subclassing required, accepts DI — and explains the difference between `SavingChangesAsync` (pre-commit, can roll back) and `SavedChangesAsync` (post-commit, can't roll back), why domain events should be dispatched in `SavedChangesAsync` and why that still requires the outbox pattern for guaranteed delivery, and how `IDbCommandInterceptor` enables slow query logging and query tagging without polluting query call sites.

---

## Related Topics

- [[dotnet/ef/ef-dbcontext.md]] — Interceptors are registered on `DbContextOptionsBuilder`; the context is the host for all interceptor wiring.
- [[dotnet/ef/ef-tracking.md]] — Interceptors access `ChangeTracker.Entries()` to read entity states; understanding the change tracker is the prerequisite for writing correct interceptors.
- [[dotnet/ef/ef-global-query-filters.md]] — Global query filters complement interceptors: filters handle read-side soft delete (IsDeleted = 0 in WHERE), interceptors handle write-side soft delete (convert Remove() to flag update).
- [[system-design/communication-patterns/event-driven-architecture.md]] — Domain event dispatch in `SavedChangesAsync` and the outbox pattern for guaranteed post-commit delivery.

---

## Source

https://learn.microsoft.com/en-us/ef/core/logging-events-diagnostics/interceptors

---
*Last updated: 2026-04-08*