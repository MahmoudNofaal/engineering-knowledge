# Fault Tolerance

> The ability of a system to continue operating correctly when one or more of its components fail.

---

## When To Use It

Every production system needs some level of fault tolerance — the question is how much, for which components, at what cost. Apply it aggressively to components whose failure would cause cascading outages or data loss. Apply it selectively to non-critical paths where degraded operation is acceptable. Don't spend engineering effort making a cron job fault-tolerant when a page-on-failure is sufficient. The goal is graceful degradation, not perfect operation under all conditions.

---

## Core Concept

Fault tolerance is the combination of strategies that keep a system useful when things break. It starts with accepting that failures are not exceptional — they are normal, scheduled events in any distributed system. Hardware fails, networks partition, third-party services go down. Fault tolerance means designing for the failure path, not just the happy path. The key techniques are redundancy (have more than one of everything critical), isolation (stop failures from spreading), and degraded-mode operation (do less rather than fail completely). A fault-tolerant system doesn't pretend failures don't happen — it makes failure survivable.

---

## The Code

**Redundant service calls with fallback**
```csharp
public async Task<ProductInfo> GetProductAsync(int id)
{
    try
    {
        // Try primary service first
        return await _primaryCatalogService.GetProductAsync(id);
    }
    catch (Exception ex) when (ex is HttpRequestException or TimeoutException)
    {
        _logger.LogWarning("Primary catalog failed, falling back to cache");

        // Degrade gracefully — return stale data rather than an error
        return await _cacheService.GetProductAsync(id)
            ?? throw new ServiceUnavailableException("Catalog unavailable");
    }
}
```

**Timeout enforcement — never wait forever**
```csharp
public async Task<string> CallDownstreamAsync(string url)
{
    using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(3));

    try
    {
        return await _httpClient.GetStringAsync(url, cts.Token);
    }
    catch (OperationCanceledException)
    {
        throw new TimeoutException($"Call to {url} exceeded 3s timeout");
    }
}
```

**Retry with exponential backoff (Polly)**
```csharp
var policy = Policy
    .Handle<HttpRequestException>()
    .WaitAndRetryAsync(
        retryCount: 3,
        sleepDurationProvider: attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt)),
        onRetry: (ex, delay, attempt, _) =>
            _logger.LogWarning("Attempt {Attempt} failed, retrying in {Delay}s", attempt, delay)
    );

var result = await policy.ExecuteAsync(() => CallDownstreamAsync(url));
```

**Health-gated operation — skip work when degraded**
```csharp
public async Task ProcessOrderAsync(Order order)
{
    await _orderRepository.SaveAsync(order);

    // Non-critical — skip if analytics is degraded, don't fail the order
    if (_healthMonitor.IsHealthy("analytics-service"))
    {
        await _analyticsService.TrackOrderAsync(order);
    }
}
```

---

## Gotchas

- **Retries amplify load during outages.** If 1000 clients all retry on failure with no jitter, they hit the recovering service simultaneously — the thundering herd. Always add random jitter to retry delays. A recovering service that immediately gets hammered again never recovers.
- **Timeouts must be set at every layer.** A timeout at the HTTP client layer doesn't help if the database query inside the service has no timeout. Unbound waits propagate up the call chain, exhausting thread pools and connection pools silently.
- **Fallback data must be clearly marked.** Returning stale cache data without indicating it's stale is a correctness bug. Either surface staleness to the caller or ensure the downstream effect of stale data is acceptable.
- **Fault tolerance adds test surface.** A fallback path that's never triggered in production is a path that's probably broken. Use chaos engineering or fault injection in staging to verify that your fault tolerance actually works before you need it.
- **Idempotency is required for retries.** If your retry sends the same payment request twice and the server processed the first one before failing to respond, you've charged the customer twice. Every operation that can be retried must be idempotent — producing the same result regardless of how many times it's called.

---

## Interview Angle

**What they're really testing:** Whether you design for the failure path with the same rigor as the happy path, and whether you understand the second-order effects of fault tolerance mechanisms.

**Common question form:** "How do you make a microservice resilient?" or "What happens to your system when the payment service goes down?"

**The depth signal:** A junior says "add retries and a fallback." A senior specifies that retries require idempotency and jitter, explains that fallbacks must be explicitly tested or they rot, distinguishes between failing fast (circuit breaker) and retrying (transient faults), and can describe how fault tolerance at the service level connects to system-level availability targets — showing that fault tolerance is not just about individual components but about the failure propagation model of the whole system.

---

## Related Topics

- [[system-design/circuit-breaker.md]] — the most important single pattern for stopping failure propagation between services
- [[system-design/retry-patterns.md]] — retries are a fault tolerance primitive with serious failure modes if implemented naively
- [[system-design/bulkhead-pattern.md]] — bulkheads isolate failure domains so one bad dependency can't exhaust shared resources
- [[system-design/availability-nines.md]] — fault tolerance is the set of techniques; availability is the measurable outcome

---

## Source

https://learn.microsoft.com/en-us/azure/architecture/guide/design-principles/design-for-failure

---

*Last updated: 2026-03-24*