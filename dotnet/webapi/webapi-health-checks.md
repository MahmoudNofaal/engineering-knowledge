# ASP.NET Core Web API Health Checks

> Health checks are endpoints that report whether your application and its dependencies are ready to serve traffic, used by load balancers, orchestrators, and monitoring systems to make routing and restart decisions.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Registered endpoints that report application and dependency health status |
| **Use when** | Any deployed service — mandatory in Kubernetes, Docker Swarm, or behind a load balancer |
| **Avoid when** | Local development only — but still wire them up so they work in staging |
| **Introduced** | ASP.NET Core 2.2 |
| **Namespace** | `Microsoft.Extensions.Diagnostics.HealthChecks` |
| **Key types** | `IHealthCheck`, `HealthCheckResult`, `HealthCheckOptions`, `IHealthCheckPublisher` |

---

## When To Use It

Use them in any deployed service — the moment you run in Kubernetes, behind a load balancer, or in any environment where something external decides whether to send traffic to your instance. They're the difference between an orchestrator restarting a broken pod automatically and leaving it receiving traffic silently. Implement at minimum a liveness check (is the process alive?) and a readiness check (can it serve requests right now?). Don't put business logic or slow queries in health checks — they're called frequently, often every few seconds, and a slow check degrades the very thing you're trying to monitor.

---

## Core Concept

ASP.NET Core's health check system has two parts: checks and endpoints. A health check is a class implementing `IHealthCheck` that returns `Healthy`, `Degraded`, or `Unhealthy` with optional data. You register checks in DI, giving each a name and optional tags. Then you map one or more health endpoints that run a subset of registered checks and expose the result as HTTP — typically `/health/live` (liveness) and `/health/ready` (readiness). The response is 200 OK or 503 Service Unavailable depending on the aggregate result. Tags are the mechanism for splitting checks into groups — a liveness endpoint runs only process-level checks, while readiness runs database and external dependency checks too.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 2.2 | `IHealthCheck`, `AddHealthChecks`, `MapHealthChecks` introduced |
| ASP.NET Core 3.0 | Health checks integrated into endpoint routing; `MapHealthChecks` on `IEndpointRouteBuilder` |
| .NET 6 | `HealthCheckOptions.ResultStatusCodes` — map `Degraded` to custom HTTP status code |
| .NET 7 | Health checks integrate with `AddProblemDetails` for JSON responses |
| .NET 8 | `IHealthCheckPublisher` improvements; parallel check execution by default |

*Before ASP.NET Core 3.0, health checks used `UseHealthChecks` middleware. From 3.0 onward, `MapHealthChecks` is the standard — it uses endpoint routing so you can apply `.RequireAuthorization()` and `.RequireHost()` directly.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Simple `HealthCheckResult.Healthy()` | ~1 µs | Struct return; no allocation |
| SQL Server check (ping query) | ~5–50 ms | Network round-trip to DB |
| Redis check (PING command) | ~1–5 ms | Network round-trip |
| Custom check with DB query | ~10–500 ms | Depends on query complexity |

**Allocation behaviour:** `HealthCheckResult` with no data is a near-zero allocation struct. Adding `data` dictionaries allocates. `HealthReport` construction allocates `IReadOnlyDictionary` per check entry. For high-frequency probes, keep checks lightweight — return cached status rather than re-querying on every probe hit.

**Benchmark notes:** Kubernetes probes every 5–10 seconds per instance. A SQL Server check at 50 ms means 50 ms of DB overhead every 5 seconds from every pod. For 10 pods that's 10 checks × 50 ms every 5 seconds. Cache the result with a short TTL or use a lightweight `SELECT 1` query rather than a full schema query.

---

## The Code

**Basic setup in Program.cs**
```csharp
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy(), tags: new[] { "live" })
    .AddSqlServer(
        connectionString: builder.Configuration.GetConnectionString("Default")!,
        name: "sql",
        tags: new[] { "ready", "db" })
    .AddRedis(
        redisConnectionString: builder.Configuration["Redis:ConnectionString"]!,
        name: "redis",
        tags: new[] { "ready", "cache" })
    .AddUrlGroup(
        new Uri("https://api.stripe.com"),
        name: "stripe",
        tags: new[] { "ready", "external" });

var app = builder.Build();

// Liveness: only the self-check — no dependencies
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("live"),
    ResultStatusCodes = new Dictionary<HealthStatus, int>
    {
        [HealthStatus.Healthy]   = 200,
        [HealthStatus.Degraded]  = 200,   // degraded still routes traffic
        [HealthStatus.Unhealthy] = 503
    }
});

// Readiness: everything tagged "ready"
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),
    ResultStatusCodes = new Dictionary<HealthStatus, int>
    {
        [HealthStatus.Healthy]   = 200,
        [HealthStatus.Degraded]  = 200,
        [HealthStatus.Unhealthy] = 503
    }
});
```

**Custom health check**
```csharp
public class QueueDepthHealthCheck : IHealthCheck
{
    private readonly IMessageQueue _queue;

    public QueueDepthHealthCheck(IMessageQueue queue) => _queue = queue;

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var depth = await _queue.GetDepthAsync(cancellationToken);
        var data  = new Dictionary<string, object> { ["depth"] = depth };

        return depth switch
        {
            < 1_000 => HealthCheckResult.Healthy("Queue depth nominal.", data),
            < 5_000 => HealthCheckResult.Degraded("Queue depth elevated.", data: data),
            _       => HealthCheckResult.Unhealthy("Queue depth critical.", data: data)
        };
    }
}

builder.Services.AddHealthChecks()
    .AddCheck<QueueDepthHealthCheck>("queue-depth", tags: new[] { "ready" });
```

**Detailed JSON response for internal dashboards**
```csharp
app.MapHealthChecks("/health/detail", new HealthCheckOptions
{
    Predicate             = _ => true,
    AllowCachingResponses = false,
    ResponseWriter        = WriteJsonResponse
}).RequireAuthorization("InternalMonitoring");

static Task WriteJsonResponse(HttpContext ctx, HealthReport report)
{
    ctx.Response.ContentType = "application/json";
    return ctx.Response.WriteAsJsonAsync(new
    {
        status   = report.Status.ToString(),
        duration = report.TotalDuration.TotalMilliseconds,
        checks   = report.Entries.Select(e => new
        {
            name      = e.Key,
            status    = e.Value.Status.ToString(),
            duration  = e.Value.Duration.TotalMilliseconds,
            data      = e.Value.Data,
            exception = e.Value.Exception?.Message
        })
    });
}
```

**Kubernetes probe configuration (reference)**
```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 2
```

**Securing health endpoints**
```csharp
// Expose liveness on a separate internal-only port
app.MapHealthChecks("/health/ready")
   .RequireHost("*:8081");

// Restrict detail endpoint to authorised users only
app.MapHealthChecks("/health/detail")
   .RequireAuthorization("InternalMonitoring");
```

---

## Real World Example

A microservice has three checks: a self (liveness) check, a database readiness check, and a downstream dependency check that marks the service as degraded (not unhealthy) when the external API is slow but not down. Degraded still routes traffic; unhealthy pulls the pod.

```csharp
public class DownstreamApiHealthCheck(IHttpClientFactory factory) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var sw = Stopwatch.StartNew();
        try
        {
            var client   = factory.CreateClient("InventoryService");
            var response = await client.GetAsync("/health/live",
                HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            sw.Stop();

            var data = new Dictionary<string, object>
            {
                ["responseMs"] = sw.ElapsedMilliseconds,
                ["statusCode"] = (int)response.StatusCode
            };

            if (!response.IsSuccessStatusCode)
                return HealthCheckResult.Unhealthy("Downstream API returned failure.", data: data);

            if (sw.ElapsedMilliseconds > 2_000)
                return HealthCheckResult.Degraded("Downstream API is slow.", data: data);

            return HealthCheckResult.Healthy("Downstream API OK.", data);
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Downstream API unreachable.", ex,
                new Dictionary<string, object> { ["error"] = ex.Message });
        }
    }
}

// Registration
builder.Services.AddHealthChecks()
    .AddCheck("self",              () => HealthCheckResult.Healthy(), tags: new[] { "live" })
    .AddSqlServer(connStr,         name: "db",         tags: new[] { "ready" })
    .AddCheck<DownstreamApiHealthCheck>("inventory",   tags: new[] { "ready" });

// Liveness: only self — DB or downstream being down doesn't restart the pod
app.MapHealthChecks("/health/live",  new HealthCheckOptions
{
    Predicate = c => c.Tags.Contains("live")
});

// Readiness: DB + downstream — pod pulled from load balancer rotation when either fails
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = c => c.Tags.Contains("ready"),
    ResultStatusCodes = new Dictionary<HealthStatus, int>
    {
        [HealthStatus.Healthy]   = 200,
        [HealthStatus.Degraded]  = 200,   // slow downstream: still route, but log
        [HealthStatus.Unhealthy] = 503
    }
});
```

*The key insight: liveness and readiness serve different purposes in Kubernetes. A liveness failure restarts the pod — only use it when the process itself is broken (deadlock, thread pool exhausted). A readiness failure pulls the pod from the load balancer rotation without restarting — correct for dependency failures (DB down, downstream service unreachable). Putting dependency checks in liveness causes unnecessary pod restarts that don't fix the underlying problem.*

---

## Common Misconceptions

**"Liveness and readiness checks can contain the same checks."**
They serve completely different purposes. Liveness tells Kubernetes whether to restart the pod. Readiness tells the load balancer whether to route traffic to it. Database and downstream API checks belong in readiness only. Putting them in liveness causes restarts when the database is down — which doesn't fix the database and adds startup overhead on top of the existing problem.

**"`HealthStatus.Degraded` means the service is unhealthy."**
Degraded is a third state — the service is functioning but with reduced capacity or elevated response times. By default, both Healthy and Degraded map to HTTP 200 (the pod stays in rotation). Only Unhealthy maps to 503 by default. This means degraded checks don't affect routing unless you explicitly override `ResultStatusCodes`. Decide per-check whether degraded should affect routing.

**"Health check endpoints are automatically protected by global auth middleware."**
`MapHealthChecks` registers endpoints outside the normal controller pipeline. A global `RequireAuthorization` policy applied via `app.UseAuthorization()` does NOT automatically apply to health endpoints. You must explicitly chain `.RequireAuthorization()` on each `MapHealthChecks` call for any endpoint that needs protection.

---

## Gotchas

- **`HealthStatus.Degraded` returns HTTP 200 by default — it doesn't affect load balancer routing.** Override `ResultStatusCodes` in `HealthCheckOptions` if you want degraded to affect routing decisions.

- **External dependency checks add real latency on every probe.** A SQL Server check at 300 ms means 300 ms of DB overhead every 5–10 seconds per pod. Use a lightweight check (`SELECT 1`) or cache the result with a short TTL using `IHealthCheckPublisher` instead of re-querying live on every probe.

- **Dependency checks in liveness probes cause unnecessary pod restarts.** Database unavailability causes a liveness failure which restarts the pod, which doesn't fix the database. Keep liveness to process-only checks; dependency checks belong in readiness.

- **Health check endpoints bypass global `[Authorize]` policies.** Explicitly call `.RequireAuthorization()` on detail endpoints. Detailed health responses with data dictionaries may leak connection strings, internal hostnames, or error messages.

- **`AddCheck<T>` resolves `T` from DI on every health check run.** If your custom `IHealthCheck` depends on a scoped service, the health check system creates a fresh DI scope per run — correct behaviour. If you register it incorrectly as a singleton capturing a scoped service, you'll get a captive dependency error or stale data.

- **`IHealthCheckPublisher` is the correct tool for push-based monitoring.** For monitoring systems that expect push (Datadog, Prometheus) rather than pull (Kubernetes probes), implement `IHealthCheckPublisher` to push health data on a schedule rather than serving it on demand.

---

## Interview Angle

**What they're really testing:** Whether you understand the operational contract between your application and its hosting environment — specifically Kubernetes — and whether you can reason about the consequences of a misconfigured probe.

**Common question forms:**
- "What's the difference between a liveness probe and a readiness probe?"
- "How would you set up health checks in a Kubernetes-deployed .NET service?"
- "What should and shouldn't be in a liveness check?"
- "How do you handle the case where a downstream service is slow but not down?"

**The depth signal:** A junior knows health checks return 200 or 503 and Kubernetes uses them. A senior can explain the specific consequences of putting database checks in the liveness probe (unnecessary restarts), knows `HealthStatus.Degraded` maps to HTTP 200 by default and must be explicitly remapped, understands that detailed health responses should never be public-facing, and can describe the `IHealthCheckPublisher` pattern for push-based monitoring systems.

**Follow-up questions to expect:**
- "How do you prevent health check probes from overwhelming a slow dependency?"
- "How would you expose health check results to Prometheus?"
- "What's the `ResultStatusCodes` option and when would you use it?"

---

## Related Topics

- [[dotnet/webapi/middleware-pipeline.md]] — health check endpoints are registered via endpoint routing; understanding the pipeline explains why global auth policies don't apply automatically
- [[dotnet/webapi/webapi-rate-limiting.md]] — health endpoints should be exempted from rate limiting with `.DisableRateLimiting()` to ensure probes always get through under load
- [[dotnet/webapi/webapi-authentication.md]] — health endpoints bypass JWT authentication by default; explicitly apply `.RequireAuthorization()` to detail endpoints
- [[dotnet/webapi/dependency-injection.md]] — custom health checks are DI-registered services; lifetime affects whether scoped dependencies are resolved correctly

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks

---
*Last updated: 2026-04-10*