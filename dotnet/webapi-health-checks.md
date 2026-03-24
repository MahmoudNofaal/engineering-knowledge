# ASP.NET Core Web API Health Checks

> Health checks are endpoints that report whether your application and its dependencies are ready to serve traffic, used by load balancers, orchestrators, and monitoring systems to make routing and restart decisions.

---

## When To Use It

Use them in any deployed service — the moment you run in Kubernetes, behind a load balancer, or in any environment where something external decides whether to send traffic to your instance. They're the difference between an orchestrator restarting a broken pod automatically and leaving it receiving traffic silently. Implement at minimum a liveness check (is the process alive?) and a readiness check (can it serve requests right now?). Don't put business logic or slow queries in health checks — they're called frequently, often every few seconds, and a slow check degrades the very thing you're trying to monitor.

---

## Core Concept

ASP.NET Core's health check system has two parts: checks and endpoints. A health check is a class implementing `IHealthCheck` that returns `Healthy`, `Degraded`, or `Unhealthy` with optional data. You register checks in DI, giving each a name and optional tags. Then you map one or more health endpoints that run a subset of registered checks and expose the result as HTTP — typically `/health/live` (liveness) and `/health/ready` (readiness). The response is either 200 OK or 503 Service Unavailable depending on the aggregate result. Tags are the mechanism for splitting checks into groups — a liveness endpoint might run only the process-level checks, while a readiness endpoint runs database and external dependency checks too.

---

## The Code
```csharp
// --- Basic setup in Program.cs ---
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy())            // always-healthy liveness check
    .AddSqlServer(                                                   // from AspNetCore.HealthChecks.SqlServer
        connectionString: builder.Configuration.GetConnectionString("Default")!,
        name: "sql",
        tags: new[] { "ready", "db" })
    .AddRedis(                                                       // from AspNetCore.HealthChecks.Redis
        redisConnectionString: builder.Configuration["Redis:ConnectionString"]!,
        name: "redis",
        tags: new[] { "ready", "cache" })
    .AddUrlGroup(                                                    // from AspNetCore.HealthChecks.Uris
        new Uri("https://api.stripe.com"),
        name: "stripe",
        tags: new[] { "ready", "external" });

var app = builder.Build();

// Liveness: only checks the process itself — no dependencies
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = check => check.Name == "self"
});

// Readiness: checks everything tagged "ready"
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});
```
```csharp
// --- Custom health check ---
public class QueueDepthHealthCheck : IHealthCheck
{
    private readonly IMessageQueue _queue;

    public QueueDepthHealthCheck(IMessageQueue queue) => _queue = queue;

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var depth = await _queue.GetDepthAsync(cancellationToken);

        return depth switch
        {
            < 1000  => HealthCheckResult.Healthy("Queue depth nominal.", new Dictionary<string, object> { ["depth"] = depth }),
            < 5000  => HealthCheckResult.Degraded("Queue depth elevated.", data: new Dictionary<string, object> { ["depth"] = depth }),
            _       => HealthCheckResult.Unhealthy("Queue depth critical.", data: new Dictionary<string, object> { ["depth"] = depth })
        };
    }
}

// Registration:
builder.Services.AddHealthChecks()
    .AddCheck<QueueDepthHealthCheck>("queue-depth", tags: new[] { "ready" });
```
```csharp
// --- Detailed JSON response for internal monitoring dashboards ---
// By default the response body is just "Healthy" / "Unhealthy" as plain text.
// This adds a JSON payload with per-check results.
app.MapHealthChecks("/health/detail", new HealthCheckOptions
{
    Predicate           = _ => true,                                // include all checks
    ResponseWriter      = WriteJsonResponse,
    AllowCachingResponses = false
}).RequireAuthorization("internal");                               // don't expose detail publicly

static Task WriteJsonResponse(HttpContext ctx, HealthReport report)
{
    ctx.Response.ContentType = "application/json";
    var result = JsonSerializer.Serialize(new
    {
        status = report.Status.ToString(),
        duration = report.TotalDuration.TotalMilliseconds,
        checks = report.Entries.Select(e => new
        {
            name     = e.Key,
            status   = e.Value.Status.ToString(),
            duration = e.Value.Duration.TotalMilliseconds,
            data     = e.Value.Data,
            error    = e.Value.Exception?.Message
        })
    });
    return ctx.Response.WriteAsync(result);
}
```
```csharp
// --- Kubernetes liveness and readiness probe configuration (reference) ---
// In your Kubernetes deployment manifest:
//
// livenessProbe:
//   httpGet:
//     path: /health/live
//     port: 8080
//   initialDelaySeconds: 10
//   periodSeconds: 10
//   failureThreshold: 3
//
// readinessProbe:
//   httpGet:
//     path: /health/ready
//     port: 8080
//   initialDelaySeconds: 5
//   periodSeconds: 5
//   failureThreshold: 2
```
```csharp
// --- Securing health endpoints ---
// Liveness is safe to expose publicly (no sensitive data).
// Readiness and detail endpoints should be restricted.

// Option 1: allow only internal network / cluster
app.MapHealthChecks("/health/ready")
   .RequireHost("*:8081");            // expose on a separate internal-only port

// Option 2: restrict by authorization policy
app.MapHealthChecks("/health/detail")
   .RequireAuthorization("InternalMonitoring");

// Option 3: no auth but filter sensitive data in the response writer
// (don't include connection strings or stack traces in the data dict)
```

---

## Gotchas

- **The default response is plain text, not JSON — and always 200 even when degraded.** `HealthStatus.Degraded` returns HTTP 200 by default, which means a load balancer using status code to decide routing sees no difference between healthy and degraded. Override `ResultStatusCodes` in `HealthCheckOptions` to map `Degraded` to 200 and `Unhealthy` to 503, or map both non-healthy states to 503 depending on your routing requirements.
- **External dependency checks (database, Redis, HTTP) add real latency on every probe.** Kubernetes probes call liveness every 5–10 seconds by default. A SQL Server check that takes 300 ms means 300 ms of DB overhead every 5 seconds from every instance. Use the `HealthCheckPublisherHostedService` pattern or cache check results with `Timeout` and a short `Period` instead of running a live query on every probe hit.
- **Putting dependency checks in the liveness probe will cause unnecessary pod restarts.** If your database is temporarily unavailable and your liveness probe fails because the DB check is included, Kubernetes restarts the pod — which doesn't fix the database and adds startup overhead. Liveness should only check whether the process itself is functional (thread pool not exhausted, no deadlock). Database and external checks belong in the readiness probe only.
- **Health check endpoints bypass `[Authorize]` and middleware that protects your other routes by default.** `MapHealthChecks` registers endpoints outside the normal MVC pipeline. A global `RequireAuthorization` policy applied via `app.UseAuthorization()` does not automatically apply to health endpoints unless you explicitly chain `.RequireAuthorization()` on the `MapHealthChecks` call. Internal monitoring endpoints with detailed data should always be explicitly secured.
- **`AddCheck<T>` resolves `T` from DI on every health check run — the lifetime matters.** If your custom `IHealthCheck` has a scoped dependency (e.g., a `DbContext`), register it with `AddCheck<T>` as-is and the health check system creates a fresh DI scope for each run. If you register the check incorrectly as a singleton with a scoped dependency captured in the constructor, you'll get a captive dependency exception or stale data on every check after the first.

---

## Interview Angle

**What they're really testing:** Whether you understand the operational contract between your application and its hosting environment — specifically Kubernetes or a load balancer — and whether you can reason about the consequences of a misconfigured probe.

**Common question form:** "What's the difference between a liveness probe and a readiness probe?" or "How would you set up health checks in a Kubernetes-deployed .NET service?" or "What should and shouldn't be in a liveness check?"

**The depth signal:** A junior knows health checks return 200 or 503 and that Kubernetes uses them. A senior can explain the specific consequences of putting database checks in the liveness probe (unnecessary pod restarts that don't fix the underlying problem), knows that `HealthStatus.Degraded` maps to HTTP 200 by default and must be explicitly remapped if it should affect routing, understands that detailed health responses should never be public-facing (connection strings, internal hostnames, and error messages leak through the `data` and `exception` fields), and can describe the `IHealthCheckPublisher` pattern for pushing health status to an external monitoring system like Datadog or Prometheus rather than polling.

---

## Related Topics

- [[dotnet/webapi-middleware-pipeline.md]] — health check endpoints are registered via `MapHealthChecks` which sits in the endpoint routing middleware; understanding the pipeline explains why global auth policies don't apply automatically
- [[dotnet/webapi-rate-limiting.md]] — health endpoints should be exempted from rate limiting with `.DisableRateLimiting()` to ensure probes always get through under load
- [[devops/kubernetes-deployments.md]] — liveness and readiness probes are Kubernetes concepts; the ASP.NET Core health check endpoints are the server-side contract that those probes hit
- [[dotnet/dependency-injection.md]] — custom health checks are registered in DI; understanding lifetimes prevents captive dependency bugs when checks depend on scoped services

---

## Source

[https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks)

---
*Last updated: 2026-03-24*