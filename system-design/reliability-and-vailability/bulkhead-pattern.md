# Bulkhead Pattern

> An isolation pattern that partitions a system's resources so that failure in one area can't exhaust resources needed by everything else.

---

## When To Use It

Use bulkheads when one slow or failing dependency could starve your thread pool, connection pool, or semaphore and take down unrelated parts of the system. It's critical when you have a mix of critical-path and non-critical dependencies served by the same process. Apply it whenever a single dependency is responsible for more than one high-value workflow. Don't bother for genuinely independent services with their own processes — process isolation is already a bulkhead.

---

## Core Concept

Named after the watertight compartments in a ship's hull. If one compartment floods, the bulkheads keep the others dry — the ship stays afloat. In software, the shared resource is usually a thread pool or connection pool. If Service A makes calls to both a payment provider and a recommendation engine using the same pool, a slow recommendation engine fills the thread pool with waiting threads — and now payment calls are also queued behind them. A bulkhead assigns a fixed slice of resources to each dependency. The recommendation engine can only ever consume its allocation; the payment pool is untouched regardless of what happens to recommendations.

---

## The Code

**Semaphore-based bulkhead (manual)**
```csharp
// Each dependency gets its own semaphore — independent resource limits
private static readonly SemaphoreSlim _paymentBulkhead = new(maxConcurrentCalls: 10);
private static readonly SemaphoreSlim _recommendationBulkhead = new(maxConcurrentCalls: 5);

public async Task<PaymentResult> ChargeAsync(ChargeRequest request)
{
    // If 10 payment calls are already in flight, this queues or throws
    if (!await _paymentBulkhead.WaitAsync(TimeSpan.FromSeconds(2)))
        throw new BulkheadRejectedException("Payment bulkhead full");

    try
    {
        return await _paymentService.ChargeAsync(request);
    }
    finally
    {
        _paymentBulkhead.Release();
    }
}
```

**Polly bulkhead policy**
```csharp
// maxParallelization: concurrent calls allowed
// maxQueuingActions: how many can wait before being rejected
var paymentBulkhead = Policy.BulkheadAsync(
    maxParallelization: 10,
    maxQueuingActions: 5,
    onBulkheadRejectedAsync: _ =>
    {
        _logger.LogWarning("Payment bulkhead rejected — at capacity");
        return Task.CompletedTask;
    }
);

var recommendationBulkhead = Policy.BulkheadAsync(
    maxParallelization: 5,
    maxQueuingActions: 2
);
```

**Named HttpClient with bulkhead per dependency (ASP.NET Core)**
```csharp
builder.Services.AddHttpClient("payment-service")
    .AddPolicyHandler(paymentBulkhead)
    .AddPolicyHandler(circuitBreakerPolicy);

builder.Services.AddHttpClient("recommendation-service")
    .AddPolicyHandler(recommendationBulkhead)
    .AddPolicyHandler(circuitBreakerPolicy);
// Each client has its own isolated resource pool — total isolation
```

**Thread pool bulkhead via dedicated channels**
```csharp
// For CPU-bound work: dedicated channel per priority tier
var criticalChannel = Channel.CreateBounded<WorkItem>(
    new BoundedChannelOptions(capacity: 100) { FullMode = BoundedChannelFullMode.Wait }
);
var backgroundChannel = Channel.CreateBounded<WorkItem>(
    new BoundedChannelOptions(capacity: 500) { FullMode = BoundedChannelFullMode.DropOldest }
);
// Critical work is never blocked by background work backlog
```

---

## Gotchas

- **Setting limits too low creates artificial throttling.** A payment bulkhead of 2 concurrent calls on a service that handles 500 requests/second means 498 are rejected even when the payment provider is healthy. Size limits based on actual measured concurrency under normal load, not gut feel.
- **Bulkheads without rejection handling hide failures.** When a bulkhead rejects a call, you get a `BulkheadRejectedException`. If that's not caught and converted to a meaningful response (fallback, 503, queue), it surfaces as an unhandled exception that looks like a bug rather than capacity management.
- **Shared HttpClient instances share connection pools by default.** Two named HttpClients can still share underlying connection pool infrastructure depending on configuration. Verify that your "isolated" clients are genuinely isolated at the socket level, not just at the policy level.
- **Bulkheads protect the caller, not the callee.** Isolating your thread pool protects your service from being brought down by a slow dependency — it doesn't protect the dependency from being overloaded. Combine with rate limiting on the callee side for full protection.
- **Queue depth is as important as concurrency limit.** A bulkhead that allows 10 concurrent calls and 1000 queued calls provides almost no protection — threads are just waiting in a different place. Keep queue depth small (2–3x concurrency limit) and reject early.

---

## Interview Angle

**What they're really testing:** Whether you understand how shared resources create hidden coupling between seemingly independent features, and how isolation prevents that coupling from becoming a failure mode.

**Common question form:** "How do you prevent one slow dependency from taking down your entire service?" or "What is the bulkhead pattern and when would you use it?"

**The depth signal:** A junior says "bulkheads isolate failures." A senior describes the specific shared resource that creates the coupling (thread pool, connection pool, semaphore), gives a concrete scenario — slow recommendation engine starving the payment thread pool — explains the sizing tradeoff between too-small (artificial throttling) and too-large (no protection), and connects bulkheads to the broader resilience stack: bulkheads cap blast radius, circuit breakers stop calling failing services, and retries handle transient noise — three different problems requiring three different patterns.

---

## Related Topics

- [[system-design/circuit-breaker.md]] — circuit breakers stop calls to failing services; bulkheads limit how many calls can be in-flight at once — complementary, not interchangeable
- [[system-design/retry-patterns.md]] — retries without bulkheads can amplify load; bulkheads cap the maximum concurrent retry pressure on a dependency
- [[system-design/fault-tolerance.md]] — bulkhead is one pattern in the fault tolerance toolkit, specifically targeting resource exhaustion failures

---

## Source

https://learn.microsoft.com/en-us/azure/architecture/patterns/bulkhead

---

*Last updated: 2026-03-24*