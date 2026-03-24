# Health Checks

> Endpoints or probes that report whether a service is ready to receive traffic, allowing load balancers and orchestrators to route around unhealthy instances automatically.

---

## When To Use It

Every service in a production environment needs health checks — this is not optional. They're the mechanism by which Kubernetes, load balancers, and service meshes know whether to send traffic to a given instance. Without them, traffic continues routing to crashed or deadlocked instances until a human notices. Use liveness checks to detect stuck processes and trigger restarts. Use readiness checks to hold traffic back until the service has finished warming up — loaded caches, migrated databases, established connection pools.

---

## Core Concept

There are two distinct concepts that are often conflated. A liveness check answers: "Is this process alive and not deadlocked?" If it fails, the orchestrator kills and restarts the instance. A readiness check answers: "Is this instance ready to serve traffic right now?" If it fails, the load balancer stops sending requests to this instance but doesn't kill it. They serve different purposes and should be different endpoints with different logic. A service can be alive (process running) but not ready (still warming up its cache or waiting for a database migration to finish).

---

## The Code

**ASP.NET Core — basic health check setup**
```csharp
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy())
    .AddSqlServer(connectionString, name: "database")
    .AddRedis(redisConnectionString, name: "cache")
    .AddUrlGroup(new Uri("https://dependency.com/health"), name: "external-api");

// Separate endpoints for liveness and readiness
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    // Liveness: only check the process itself, not dependencies
    Predicate = check => check.Tags.Contains("live"),
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    // Readiness: check all dependencies — don't serve traffic until they're available
    Predicate = _ => true,
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});
```

**Custom health check — database connection pool**
```csharp
public class DatabaseHealthCheck : IHealthCheck
{
    private readonly IDbConnectionFactory _connectionFactory;

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken ct)
    {
        try
        {
            using var conn = await _connectionFactory.OpenAsync(ct);
            // Lightweight query — don't run migrations or heavy reads here
            await conn.ExecuteScalarAsync("SELECT 1", ct);
            return HealthCheckResult.Healthy("Database reachable");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Database unreachable", ex);
        }
    }
}
```

**Kubernetes probe configuration**
```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 10   # give the process time to start
  periodSeconds: 15
  failureThreshold: 3       # restart after 3 consecutive failures

readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3       # remove from load balancer after 3 failures
```

**Tagging checks for selective endpoints**
```csharp
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy(), tags: new[] { "live" })
    .AddSqlServer(connectionString, name: "database", tags: new[] { "ready" })
    .AddRedis(redisConnectionString, name: "cache", tags: new[] { "ready" });
```

---

## Gotchas

- **Never make your liveness check depend on external services.** If your liveness probe calls your database and the database goes down, Kubernetes restarts all your instances simultaneously — a database blip causes a full service restart storm. Liveness checks should only verify the process itself is alive.
- **Health checks that are too expensive become a liability.** A check that runs a complex query every 5 seconds adds steady load to your database. Keep health check queries trivial (`SELECT 1`) and cache results if the check is called frequently.
- **Starting without an initial delay causes premature restarts.** If Kubernetes starts liveness checks immediately and your app takes 15 seconds to start, it fails liveness checks during startup and gets killed in a restart loop. Always set `initialDelaySeconds` to account for your actual startup time.
- **A healthy health check doesn't mean the service is correct.** A check that returns 200 OK proves the process is running and the database is reachable — it says nothing about whether your business logic is returning correct results. Health checks are an availability signal, not a correctness signal.
- **Missing authentication on health endpoints leaks infrastructure details.** A health check response that lists "database: unhealthy — connection string invalid" exposes internal topology. Either keep health responses minimal (just a status code) or put them behind internal network access only.

---

## Interview Angle

**What they're really testing:** Whether you understand the operational role health checks play in automated recovery and zero-downtime deployments, and the distinction between liveness and readiness.

**Common question form:** "How does Kubernetes know when to restart a pod?" or "How do you achieve zero-downtime deployments?"

**The depth signal:** A junior says "add a `/health` endpoint that returns 200." A senior distinguishes liveness from readiness with concrete examples of when each should fail, explains why liveness checks must never depend on external services (restart storm risk), describes readiness checks as the mechanism behind zero-downtime deployments (new pods only receive traffic when ready), and connects health checks to the broader observability picture — health checks detect binary up/down, but metrics and traces detect degraded-but-not-down states that health checks miss entirely.

---

## Related Topics

- [[system-design/circuit-breaker.md]] — health checks inform load balancers about instance-level health; circuit breakers protect individual service calls — different scopes
- [[system-design/availability-nines.md]] — health checks are the detection mechanism; availability targets define how quickly detection must trigger failover
- [[system-design/chaos-engineering.md]] — chaos engineering validates that health checks actually trigger the expected recovery behavior under real failure conditions

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks

---

*Last updated: 2026-03-24*