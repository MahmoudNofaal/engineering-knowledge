# ASP.NET Core Background Services

> Background services are long-running tasks that run inside your ASP.NET Core process alongside the web server, managed by the host's lifetime so they start and stop cleanly with the application.

---

## Quick Reference

| | |
|---|---|
| **What it is** | In-process long-running tasks managed by the host lifetime |
| **Use when** | Scheduled work, queue processing, or polling that doesn't need a separate process |
| **Avoid when** | CPU-intensive work that would starve HTTP request threads; distributed scheduled jobs across multiple instances |
| **Introduced** | ASP.NET Core 2.1 (`BackgroundService` abstract class) |
| **Namespace** | `Microsoft.Extensions.Hosting` |
| **Key types** | `IHostedService`, `BackgroundService`, `PeriodicTimer`, `IServiceScopeFactory` |

---

## When To Use It

Use them for work that needs to run continuously or on a schedule without an incoming HTTP request triggering it: processing a message queue, polling an external API, sending scheduled emails, cleaning up expired records, or aggregating metrics. They're appropriate when the work is tightly coupled to your application and you don't want to deploy a separate worker process. Don't use them for CPU-intensive work that would starve the thread pool serving HTTP requests, or for distributed scheduled jobs across multiple instances — for those, reach for a proper job scheduler like Hangfire or Quartz with distributed locking.

---

## Core Concept

The host runs all registered `IHostedService` implementations concurrently when the application starts and stops them when it shuts down. `BackgroundService` is the abstract base class that implements `IHostedService` for you — you override a single `ExecuteAsync(CancellationToken)` method and put your work there. The `CancellationToken` is cancelled when the host wants to shut down, so your work loop should check it and exit cleanly. The host calls `StopAsync` after cancelling the token and waits up to 5 seconds (configurable) for the service to finish. If your `ExecuteAsync` throws an unhandled exception, the host logs it and the service stops, but the rest of the application keeps running — a common source of silently dead background services in production.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 2.1 | `IHostedService`, `BackgroundService` introduced |
| .NET 6 | `PeriodicTimer` introduced — cleaner alternative to `Task.Delay` loops |
| .NET 7 | `BackgroundServiceExceptionBehavior.StopHost` — crash on unhandled exception |
| .NET 8 | `HostOptions.ServicesStartConcurrently` — parallel startup of hosted services |

*Before .NET 6, `Task.Delay(interval, stoppingToken)` in a while loop was the standard pattern. `PeriodicTimer` is more accurate — it fires on a fixed schedule regardless of how long processing takes, preventing drift accumulation.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `PeriodicTimer.WaitForNextTickAsync` | Near-zero | Timer-based wake; no thread consumed while waiting |
| `Task.Delay` loop | Near-zero | Similar; but accumulates drift from processing time |
| `Channel.Reader.ReadAllAsync` | Near-zero | Async enumeration; thread released while waiting |
| `IServiceScopeFactory.CreateAsyncScope` | ~1–5 µs | Scope creation and DI resolution |

**Allocation behaviour:** `PeriodicTimer` allocates minimally — the timer handle is pooled in .NET 6+. `Task.Delay` allocates a `Task` and a `Timer` per delay call — slightly more overhead than `PeriodicTimer` for tight loops. Scopes created via `IServiceScopeFactory` allocate a scope container per creation; reuse the scope for a logical unit of work rather than creating one per loop iteration.

**Benchmark notes:** Background service scheduling overhead is negligible. The bottleneck is always the work being done (DB queries, HTTP calls, queue operations). Measure the work, not the scheduling mechanism.

---

## The Code

**Basic polling loop**
```csharp
public class OrderSyncService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<OrderSyncService> _logger;

    public OrderSyncService(IServiceScopeFactory scopeFactory, ILogger<OrderSyncService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger       = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("OrderSyncService starting.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                // Background services are singletons — always create a scope for scoped services
                await using var scope   = _scopeFactory.CreateAsyncScope();
                var orderService        = scope.ServiceProvider.GetRequiredService<IOrderService>();
                await orderService.SyncPendingOrdersAsync(stoppingToken);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error syncing orders. Retrying in 30s.");
            }

            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
        }

        _logger.LogInformation("OrderSyncService stopped.");
    }
}

builder.Services.AddHostedService<OrderSyncService>();
```

**PeriodicTimer (.NET 6+) — preferred over Task.Delay loops**
```csharp
public class MetricsAggregatorService : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));

        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try   { await AggregateAsync(stoppingToken); }
            catch (Exception ex) { _logger.LogError(ex, "Aggregation failed."); }
        }
    }
}
```

**Queue-based background service (producer/consumer)**
```csharp
public class BackgroundTaskQueue
{
    private readonly Channel<Func<CancellationToken, ValueTask>> _queue
        = Channel.CreateBounded<Func<CancellationToken, ValueTask>>(capacity: 100);

    public ValueTask EnqueueAsync(Func<CancellationToken, ValueTask> workItem)
        => _queue.Writer.WriteAsync(workItem);

    public ChannelReader<Func<CancellationToken, ValueTask>> Reader => _queue.Reader;
}

public class QueueProcessorService : BackgroundService
{
    private readonly BackgroundTaskQueue _queue;

    public QueueProcessorService(BackgroundTaskQueue queue) => _queue = queue;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var workItem in _queue.Reader.ReadAllAsync(stoppingToken))
        {
            try   { await workItem(stoppingToken); }
            catch (Exception ex) { _logger.LogError(ex, "Work item failed."); }
        }
    }
}

builder.Services.AddSingleton<BackgroundTaskQueue>();
builder.Services.AddHostedService<QueueProcessorService>();

// Enqueueing from a controller
[HttpPost("reports")]
public async Task<IActionResult> RequestReport(
    [FromBody] ReportRequest req, BackgroundTaskQueue queue)
{
    await queue.EnqueueAsync(async ct => await _reportService.GenerateAsync(req, ct));
    return Accepted();
}
```

**Configuring shutdown timeout and crash behaviour**
```csharp
builder.Services.Configure<HostOptions>(options =>
{
    options.ShutdownTimeout = TimeSpan.FromSeconds(30);

    // Crash the host if a background service throws — for critical workers
    options.BackgroundServiceExceptionBehavior =
        BackgroundServiceExceptionBehavior.StopHost;
});
```

---

## Real World Example

An e-commerce platform has an outbox pattern: orders placed while the payment service is down are stored in an `OutboxMessage` table. A background service polls the outbox every 10 seconds, attempts to publish each message, and marks it as processed on success.

```csharp
public class OutboxProcessorService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<OutboxProcessorService> _logger;

    public OutboxProcessorService(IServiceScopeFactory scopeFactory, ILogger<OutboxProcessorService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger       = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(10));

        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            await using var scope = _scopeFactory.CreateAsyncScope();
            var db        = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var publisher = scope.ServiceProvider.GetRequiredService<IMessagePublisher>();

            var pending = await db.OutboxMessages
                .Where(m => !m.ProcessedAt.HasValue)
                .OrderBy(m => m.CreatedAt)
                .Take(50)
                .ToListAsync(stoppingToken);

            foreach (var message in pending)
            {
                try
                {
                    await publisher.PublishAsync(message, stoppingToken);
                    message.ProcessedAt = DateTime.UtcNow;
                    _logger.LogInformation("Outbox message {Id} published", message.Id);
                }
                catch (Exception ex)
                {
                    message.RetryCount++;
                    _logger.LogWarning(ex, "Failed to publish outbox message {Id} (attempt {Retry})",
                        message.Id, message.RetryCount);
                }
            }

            await db.SaveChangesAsync(stoppingToken);
        }
    }
}
```

*The key insight: the scope is created once per timer tick and covers the entire batch — not once per message. This means one `DbContext` instance and one `SaveChangesAsync` call covers all 50 messages in the batch, making the outbox processor efficient without sacrificing the correct scoped lifetime for `DbContext`.*

---

## Common Misconceptions

**"Background services run on a separate thread."**
They run as `Task` instances on the thread pool — the same pool that handles HTTP requests. A CPU-bound background service that runs continuously can starve the request handler threads. For CPU-intensive work, either throttle the service (use `Task.Delay` between iterations) or move it to a separate process (`Worker Service` project template).

**"The host waits as long as needed for background services to stop."**
The default shutdown timeout is 5 seconds. After that, the host forcibly kills the service. If your service needs more time (e.g., to finish processing a message in flight), increase `HostOptions.ShutdownTimeout`. Always design your service to complete its current unit of work quickly when `stoppingToken` is cancelled — do not start new work after the token fires.

**"An unhandled exception in `ExecuteAsync` crashes the application."**
By default it does not — it logs the exception and silently stops the service, while the rest of the app continues running. This is the most dangerous default behaviour because you can have a dead background service for hours without knowing. Set `BackgroundServiceExceptionBehavior.StopHost` for critical services, or implement health checks that monitor the service's status.

---

## Gotchas

- **Background services are singletons — scoped services like `DbContext` cannot be injected directly.** Inject `IServiceScopeFactory` instead and create a scope per unit of work inside `ExecuteAsync`. This is the most common background service bug.

- **An unhandled exception in `ExecuteAsync` silently kills the service without stopping the host.** The host logs and continues. Set `BackgroundServiceExceptionBehavior.StopHost` for critical workers, or health-check the service state.

- **`Task.Delay(interval, stoppingToken)` throws `OperationCanceledException` when shutdown is requested.** Catch `OperationCanceledException` (not `TaskCanceledException`) or check `stoppingToken.IsCancellationRequested` at the loop top and break.

- **`ExecuteAsync` must return promptly for the host to consider startup complete.** Blocking work at the top of `ExecuteAsync` (migrations, seeding) delays the app from accepting traffic. Move startup work to `IHostedService.StartAsync` or a separate startup step.

- **Multiple `AddHostedService<T>()` calls for the same type create independent instances.** Both run simultaneously against the same singleton dependencies. Use a semaphore or distributed lock if only one instance should process at a time.

---

## Interview Angle

**What they're really testing:** Whether you understand the host lifetime model and can reason about the operational risks — scoped service access, crash behaviour, and graceful shutdown.

**Common question forms:**
- "How would you process a queue in the background without a separate worker service?"
- "How do you run a scheduled task in ASP.NET Core?"
- "What happens if a background service throws an unhandled exception?"

**The depth signal:** A junior knows `BackgroundService` has `ExecuteAsync` and you register it with `AddHostedService`. A senior knows the default exception behaviour is log-and-continue (not crash), can configure `BackgroundServiceExceptionBehavior.StopHost` for critical workers, understands why `IServiceScopeFactory` is mandatory for scoped service access, and knows that `PeriodicTimer` is preferable to `Task.Delay` loops because it fires on a fixed schedule without accumulating drift from processing time.

**Follow-up questions to expect:**
- "How do you handle graceful shutdown in a background service?"
- "How would you schedule a job that should run at a specific time (e.g., 2 AM daily)?"
- "How do you expose the health status of a background service to Kubernetes?"

---

## Related Topics

- [[dotnet/webapi/dependency-injection.md]] — background services are singletons; resolving scoped services via `IServiceScopeFactory` follows directly from DI lifetime rules
- [[dotnet/csharp/csharp-channels.md]] — `System.Threading.Channels` is the standard mechanism for the producer/consumer pattern between controllers and background services
- [[dotnet/webapi/webapi-health-checks.md]] — a crashed background service doesn't affect the liveness probe by default; wiring health checks to service state requires a custom `IHealthCheck`
- [[dotnet/webapi/middleware-pipeline.md]] — background services start and stop with the host, not with individual requests; understanding the host lifetime distinguishes them from request-scoped middleware

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services

---
*Last updated: 2026-04-10*