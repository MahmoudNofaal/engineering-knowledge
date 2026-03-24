# Circuit Breaker

> A pattern that stops making calls to a failing dependency and fails fast instead, giving the dependency time to recover while protecting your own service from cascading failure.

---

## When To Use It

Use circuit breakers on every external dependency call where a slow or failed downstream service could exhaust your thread pool, connection pool, or response time budget. This is non-negotiable in microservice architectures. Don't use it for calls to your own database in simple monoliths where a database failure should surface immediately — circuit breakers are most valuable when there's an alternative path (fallback, cache) or when failing fast is better than queuing requests that will never succeed.

---

## Core Concept

Named after the electrical component. When a circuit is closed, current flows — calls go through normally. When too many failures happen, the breaker opens and current stops — calls fail immediately without hitting the downstream service. After a timeout, the breaker moves to half-open: it lets a test call through. If it succeeds, the circuit closes again. If it fails, it stays open. This protects your service in two ways: you don't waste threads waiting for a service that's down, and you give the failing service breathing room to recover instead of hammering it with more traffic.

---

## The Code

**Circuit breaker with Polly (.NET)**
```csharp
var circuitBreaker = Policy
    .Handle<HttpRequestException>()
    .CircuitBreakerAsync(
        exceptionsAllowedBeforeBreaking: 5,   // open after 5 consecutive failures
        durationOfBreak: TimeSpan.FromSeconds(30), // stay open for 30s
        onBreak: (ex, duration) =>
            _logger.LogWarning("Circuit OPEN for {Duration}s: {Message}", duration, ex.Message),
        onReset: () =>
            _logger.LogInformation("Circuit CLOSED — service recovered"),
        onHalfOpen: () =>
            _logger.LogInformation("Circuit HALF-OPEN — testing service")
    );
```

**Combining circuit breaker with retry (order matters)**
```csharp
// Retry wraps circuit breaker — retry fires first, circuit breaker catches sustained failures
// WRONG order: circuit breaker wrapping retry means retries happen inside open circuit
var policy = Policy.WrapAsync(retryPolicy, circuitBreakerPolicy);

var result = await policy.ExecuteAsync(() => _httpClient.GetAsync(url));
```

**Circuit breaker with fallback**
```csharp
var policy = Policy
    .Handle<BrokenCircuitException>()   // caught when circuit is open
    .FallbackAsync(
        fallbackAction: async ct =>
        {
            _logger.LogWarning("Circuit open, returning cached response");
            return await _cache.GetAsync("product-list");
        }
    );

var fullPolicy = Policy.WrapAsync(policy, circuitBreakerPolicy);
```

**Registering as a named policy (ASP.NET Core)**
```csharp
// In Program.cs — shared policy reused across all requests
builder.Services.AddHttpClient("catalog-service")
    .AddPolicyHandler(circuitBreaker);
```

---

## Gotchas

- **The retry + circuit breaker ordering is easy to get backwards.** Retry should be the outer policy, circuit breaker the inner. If you reverse them, retries execute after the circuit is already open, meaning you retry against a known-open circuit and get immediate `BrokenCircuitException` on each retry — wasting nothing but making your logs misleading.
- **A single shared circuit breaker instance matters.** If you create a new circuit breaker per-request, each one has its own failure count and never opens. The breaker must be shared across all callers to the same downstream service — register it as a singleton or via named HttpClient policies.
- **Open circuit exceptions must be handled explicitly.** When the circuit is open, Polly throws `BrokenCircuitException`. If your catch block only handles `HttpRequestException`, the open-circuit exception propagates uncaught and looks like a bug rather than intentional fail-fast behavior.
- **Threshold tuning requires production data.** Five failures in 30 seconds might be normal traffic variation for a high-volume service. Open the circuit too eagerly and you're constantly degraded. Too conservatively and the protection comes too late. Start with generous thresholds and tighten based on observed failure rates.
- **Circuit breakers don't replace timeouts.** Without a timeout, a single slow call holds a thread for minutes — enough to trigger the breaker, but after the damage is done. The timeout fires first; the circuit breaker counts the timeout as a failure and opens after enough of them accumulate.

---

## Interview Angle

**What they're really testing:** Whether you understand failure propagation in distributed systems and the mechanics of how circuit breakers actually protect a caller.

**Common question form:** "How do you prevent cascading failures in microservices?" or "What happens when Service B is slow and Service A depends on it?"

**The depth signal:** A junior says "use a circuit breaker so if the service is down, we fail fast." A senior explains the three states and state transitions, the critical importance of the shared singleton instance (per-request breakers don't work), the correct nesting order with retries, and that a circuit breaker without a fallback strategy just moves the error — the real protection comes from having a meaningful response when the circuit is open, whether that's a cache, a default, or an explicit degraded mode.

---

## Related Topics

- [[system-design/retry-patterns.md]] — retries and circuit breakers are always used together; understanding how they interact is essential
- [[system-design/bulkhead-pattern.md]] — bulkheads prevent resource exhaustion; circuit breakers prevent cascading failure — different problems, often applied together
- [[system-design/fault-tolerance.md]] — circuit breaker is the most important single pattern within the broader fault tolerance toolkit
- [[system-design/health-checks.md]] — health checks inform load balancers; circuit breakers protect individual service-to-service calls — complementary mechanisms

---

## Source

https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker

---

*Last updated: 2026-03-24*