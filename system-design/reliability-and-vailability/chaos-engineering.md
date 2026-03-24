# Chaos Engineering

> The practice of deliberately injecting failures into a system in controlled conditions to verify that it handles them correctly before a real incident does it for you.

---

## When To Use It

Use chaos engineering once you have resilience patterns in place and need to verify they actually work — circuit breakers, retries, fallbacks, health checks. It's most valuable for systems with high availability requirements where an untested failure path could mean serious production impact. Don't start with chaos engineering before you have monitoring and observability in place; injecting failures you can't observe proves nothing. Don't run it in production until you've run it in staging and understood what breaks.

---

## Core Concept

The core premise is that complex systems fail in ways that are impossible to anticipate through review alone. You think your circuit breaker will open when the payment service is slow — but does it? You think your retry logic handles 503s correctly — but has it ever actually been tested against a real 503? Chaos engineering forces these questions to be answered with evidence, not assumptions. You define a steady state (normal system behavior, measured), inject a fault, observe whether the system maintains acceptable behavior, and fix what breaks. Done on a schedule, it builds continuous confidence instead of hoping the next incident reveals no surprises.

---

## The Code

**Fault injection middleware (ASP.NET Core)**
```csharp
public class ChaosMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ChaosSettings _settings;

    public async Task InvokeAsync(HttpContext context)
    {
        if (_settings.Enabled && Random.Shared.NextDouble() < _settings.FailureRate)
        {
            // Simulate latency spike
            if (_settings.InjectLatency)
                await Task.Delay(_settings.LatencyMs);

            // Simulate service failure
            if (_settings.InjectFailure)
            {
                context.Response.StatusCode = 503;
                await context.Response.WriteAsync("Chaos: injected failure");
                return;
            }
        }

        await _next(context);
    }
}

// Register only when chaos is explicitly enabled
if (app.Environment.IsStaging() && chaosSettings.Enabled)
    app.UseMiddleware<ChaosMiddleware>();
```

**Polly chaos policy (Simmy library)**
```csharp
// Inject a 503 response 20% of the time
var chaosPolicy = MonkeyPolicy.InjectResultAsync<HttpResponseMessage>(
    with => with
        .Result(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable))
        .InjectionRate(0.2)           // 20% of calls affected
        .EnabledWhen((ctx, ct) =>
            Task.FromResult(Environment.GetEnvironmentVariable("CHAOS_ENABLED") == "true"))
);

// Inject latency 15% of the time
var latencyPolicy = MonkeyPolicy.InjectLatencyAsync(
    with => with
        .Latency(TimeSpan.FromSeconds(5))
        .InjectionRate(0.15)
        .Enabled()
);

// Wrap your real policy with chaos — chaos fires first
var fullPolicy = Policy.WrapAsync(retryPolicy, circuitBreakerPolicy, chaosPolicy);
```

**Structured chaos experiment**
```csharp
// 1. Measure steady state
var baselineP99 = await MeasureLatencyAsync(duration: TimeSpan.FromMinutes(5));
var baselineErrorRate = await MeasureErrorRateAsync(duration: TimeSpan.FromMinutes(5));

// 2. Enable fault injection
await _chaosController.EnableAsync(faultType: "dependency-latency", targetService: "catalog");

// 3. Observe during chaos
var chaosLatency = await MeasureLatencyAsync(duration: TimeSpan.FromMinutes(5));
var chaosErrorRate = await MeasureErrorRateAsync(duration: TimeSpan.FromMinutes(5));

// 4. Disable and verify recovery
await _chaosController.DisableAsync();
var recoveryLatency = await MeasureLatencyAsync(duration: TimeSpan.FromMinutes(5));

// 5. Assert hypothesis
Assert.That(chaosErrorRate, Is.LessThan(0.01), "Error rate should stay below 1% during catalog latency");
Assert.That(recoveryLatency, Is.EqualTo(baselineP99).Within(5).Percent, "Should recover to baseline within 5%");
```

---

## Gotchas

- **Chaos without observability is just breaking things.** If you inject a fault and can't see the effect in metrics, traces, and logs, you learn nothing. Observability must come before chaos, not alongside it.
- **Blast radius must be controlled before running in production.** Start with a single instance, a single dependency, a low injection rate. "We ran chaos and took down production" is not a successful experiment — it's an incident with extra steps.
- **Untested recovery logic is the most common failure.** Teams write circuit breakers and fallbacks and never verify they trigger correctly. Chaos testing almost always reveals that fallback logic has bugs, incorrect thresholds, or never actually fires because the policy is misconfigured.
- **Chaos in CI/CD requires idempotent cleanup.** If a chaos test fails midway and leaves fault injection enabled, subsequent tests run against an already-degraded system. Always wrap chaos experiments in try/finally to ensure cleanup regardless of outcome.
- **GameDay ≠ chaos engineering.** A GameDay is a one-time manual fire drill. Chaos engineering is continuous, automated, and part of the delivery pipeline. The goal is ongoing confidence, not a quarterly event.

---

## Interview Angle

**What they're really testing:** Whether you treat resilience as something that must be verified empirically rather than assumed from code review, and whether you understand the discipline around running experiments safely.

**Common question form:** "How do you validate that your system is resilient?" or "Have you worked with chaos engineering?"

**The depth signal:** A junior says "we test our error handling in unit tests." A senior describes chaos engineering as the practice of verifying resilience claims against a running system, explains the steady-state hypothesis model (measure before, inject, measure during, compare), specifies the blast radius controls required before running in production, and can describe what chaos testing typically reveals — fallback logic bugs, incorrect circuit breaker thresholds, missing health check logic — making the case that code review alone cannot catch these because they're emergent behaviors of the running system, not of individual components.

---

## Related Topics

- [[system-design/fault-tolerance.md]] — chaos engineering validates fault tolerance claims; you can't chaos test what you haven't designed for failure
- [[system-design/circuit-breaker.md]] — circuit breakers are the most common thing chaos testing finds broken; injection of dependency latency is the standard test
- [[system-design/health-checks.md]] — chaos experiments should verify that health checks correctly detect injected failures and trigger the right automated response
- [[system-design/availability-nines.md]] — chaos engineering is the empirical method for building confidence in availability targets before an incident tests them for you

---

## Source

https://principlesofchaos.org/

---

*Last updated: 2026-03-24*