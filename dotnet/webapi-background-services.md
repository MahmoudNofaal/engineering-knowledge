# ASP.NET Core Background Services

> Background services are long-running tasks that run inside your ASP.NET Core process alongside the web server, managed by the host's lifetime so they start and stop cleanly with the application.

---

## When To Use It

Use them for work that needs to run continuously or on a schedule without an incoming HTTP request triggering it: processing a message queue, polling an external API, sending scheduled emails, cleaning up expired records, or aggregating metrics. They're appropriate when the work is tightly coupled to your application and you don't want to deploy a separate worker process. Don't use them for CPU-intensive work that would starve the thread pool serving HTTP requests, or for distributed scheduled jobs across multiple instances — for those, reach for a proper job scheduler like Hangfire or Quartz with distributed locking.

---

## Core Concept

The host runs all registered `IHostedService` implementations concurrently when the application starts and stops them when it shuts down. `BackgroundService` is the abstract base class that implements `IHostedService` for you — you override a single `ExecuteAsync(CancellationToken)` method and put your work there. The `CancellationToken` is cancelled when the host wants to shut down, so your work loop should check it and exit cleanly. The host calls `StopAsync` after cancelling the token and waits up to 5 seconds (configurable) for the service to finish — after that it kills it. If your `ExecuteAsync` throws an unhandled exception, the host logs it and the service stops, but the rest of the application keeps running. This is a common source of silently dead background services in production.

---

## The Code
```csharp
// --- Basic background service: polling loop ---
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
            catch (OperationCanceledException)
            {
                break;                          // expected during shutdown — exit cleanly
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error syncing orders. Retrying in 30s.");
            }

            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
        }

        _logger.LogInformation("OrderSyncService stopped.");
    }
}

// Registration:
builder.Services.AddHostedService<OrderSyncService>();
```
```csharp
// --- Queue-based background service: producer/consumer pattern ---
// The queue is a singleton channel shared between controllers and the background service
public class BackgroundTaskQueue
{
    private readonly Channel<Func<CancellationToken, ValueTask>> _queue
        = Channel.CreateBounded<Func<CancellationToken, ValueTask>>(capacity: 100);

    public ValueTask EnqueueAsync(Func<CancellationToken, ValueTask> workItem) =>
        _queue.Writer.WriteAsync(workItem);

    public ValueTask<Func<CancellationToken, ValueTask>> DequeueAsync(CancellationToken ct) =>
        _queue.Reader.ReadAsync(ct);
}

public class QueueProcessorService : BackgroundService
{
    private readonly BackgroundTaskQueue _queue;
    private readonly ILogger<QueueProcessorService> _logger;

    public QueueProcessorService(BackgroundTaskQueue queue, ILogger<QueueProcessorService> logger)
    {
        _queue  = queue;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var workItem in _queue._queue.Reader.ReadAllAsync(stoppingToken))
        {
            try   { await workItem(stoppingToken); }
            catch (Exception ex) { _logger.LogError(ex, "Work item failed."); }
        }
    }
}

// Registration:
builder.Services.AddSingleton<BackgroundTaskQueue>();
builder.Services.AddHostedService<QueueProcessorService>();

// Enqueueing from a controller:
[HttpPost("reports")]
public async Task<IActionResult> RequestReport(
    [FromBody] ReportRequest req, BackgroundTaskQueue queue)
{
    await queue.EnqueueAsync(async ct =>
    {
        // heavy work runs off the request thread
        await _reportService.GenerateAsync(req, ct);
    });
    return Accepted();
}
```
```csharp
// --- Periodic timer service (.NET 8+): cleaner than Task.Delay loops ---
public class MetricsAggregatorService : BackgroundService
{
    private readonly ILogger<MetricsAggregatorService> _logger;

    public MetricsAggregatorService(ILogger<MetricsAggregatorService> logger)
        => _logger = logger;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));

        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try   { await AggregateAsync(stoppingToken); }
            catch (Exception ex) { _logger.LogError(ex, "Aggregation failed."); }
        }
    }

    private Task AggregateAsync(CancellationToken ct) => Task.CompletedTask; // real impl here
}
```
```csharp
// --- Configuring shutdown timeout ---
// In Program.cs: give background services more time to finish in-flight work
builder.Services.Configure<HostOptions>(options =>
{
    options.ShutdownTimeout = TimeSpan.FromSeconds(30);   // default is 5s
});
```

---

## Gotchas

- **Background services are registered as singletons but often need scoped services like `DbContext`.** Injecting a scoped service directly into the constructor of a `BackgroundService` throws at startup. You must inject `IServiceScopeFactory` instead and create a scope inside `ExecuteAsync` for each unit of work. Forgetting this is the most common background service bug and the error message doesn't always make the cause obvious.
- **An unhandled exception in `ExecuteAsync` silently kills the service without stopping the host.** The host logs the exception and marks the `IHostedService` as failed, but the web server keeps accepting requests. You can end up with a process that looks healthy from the outside but has had a dead background worker for hours. Set `HostOptions.BackgroundServiceExceptionBehavior = BackgroundServiceExceptionBehavior.StopHost` to treat background service crashes as fatal — appropriate for services where the background work is critical to the application's purpose.
- **`Task.Delay(interval, stoppingToken)` throws `OperationCanceledException` when shutdown is requested, not `TaskCanceledException`.** Both derive from `OperationCanceledException`, but if you catch only `TaskCanceledException` in your loop, the delay's cancellation slips through. Catch `OperationCanceledException` (the base) or simply check `stoppingToken.IsCancellationRequested` at the top of the loop and break.
- **`ExecuteAsync` must return promptly for the host to consider startup complete.** If you do blocking work at the top of `ExecuteAsync` before your loop (database migrations, seeding, etc.), the host startup hangs until it completes. Long-running startup work belongs in an `IHostedService.StartAsync` implementation or a separate startup check, not blocking `ExecuteAsync`.
- **Multiple instances of the same `BackgroundService` type all share the same singleton scope.** If you register `AddHostedService<MyService>()` twice, you get two independent instances — both running simultaneously against the same singleton dependencies. This is intentional for parallel workers but is often accidental and causes duplicate processing. Use a semaphore or distributed lock if you need only one instance to process at a time.

---

## Interview Angle

**What they're really testing:** Whether you understand the host lifetime model and can reason about the operational risks of long-running in-process work — specifically scoped service access, crash behaviour, and graceful shutdown.

**Common question form:** "How would you process a queue in the background without a separate worker service?" or "How do you run a scheduled task in ASP.NET Core?" or "What happens if a background service throws an unhandled exception?"

**The depth signal:** A junior knows `BackgroundService` has an `ExecuteAsync` and you register it with `AddHostedService`. A senior knows that the default exception behaviour is to log-and-continue (not crash the host), can configure `BackgroundServiceExceptionBehavior.StopHost` for critical workers, understands why `IServiceScopeFactory` is mandatory for scoped service access rather than direct injection, and knows that `PeriodicTimer` (introduced in .NET 6) is preferable to `Task.Delay` loops because it fires on a fixed schedule rather than accumulating drift from processing time — and handles cancellation correctly without swallowing the token.

---

## Related Topics

- [[dotnet/dependency-injection.md]] — background services are singletons; resolving scoped services via `IServiceScopeFactory` is mandatory and directly follows from DI lifetime rules
- [[dotnet/csharp-channels.md]] — `System.Threading.Channels` is the standard mechanism for the producer/consumer queue pattern between controllers and background services
- [[dotnet/webapi-health-checks.md]] — a crashed background service doesn't affect the liveness probe by default; wiring health checks to background service state requires a custom `IHealthCheck` that monitors the service's status
- [[dotnet/webapi-middleware-pipeline.md]] — background services start and stop with the host, not with individual requests; understanding the host lifetime distinguishes them from request-scoped middleware

---

## Source

[https://learn.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services)

---
*Last updated: 2026-03-24*