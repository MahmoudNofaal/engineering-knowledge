# Retry Patterns

> The strategy of automatically re-attempting a failed operation on the assumption that the failure is transient and will resolve itself.

---

## When To Use It

Use retries for transient failures — network blips, brief service restarts, temporary rate limiting (HTTP 429), or database deadlocks that resolve in milliseconds. Don't retry on permanent failures: a 400 Bad Request won't succeed on attempt two, and retrying a 404 wastes time. Never retry without thinking about idempotency — if the operation has side effects and the first call succeeded but the response was lost, retrying means doing the work twice. Retries are a tool for handling noise in distributed systems, not a substitute for fixing reliability problems.

---

## Core Concept

A naive retry — try again immediately — is often worse than no retry at all. If 1000 clients all hit a service that just went down and all retry immediately, the service gets 1000 simultaneous hammers the moment it tries to come back up. The solution is exponential backoff: wait 1s, then 2s, then 4s — giving the downstream system time to recover and reducing load during outage. Add jitter (random offset to the wait time) so clients don't all sync up on the same retry window. The result is a self-regulating retry mechanism that's kind to struggling dependencies.

---

## The Code

**Exponential backoff with jitter (manual)**
```csharp
public async Task<T> RetryAsync<T>(
    Func<Task<T>> operation,
    int maxAttempts = 3)
{
    var random = new Random();

    for (int attempt = 1; attempt <= maxAttempts; attempt++)
    {
        try
        {
            return await operation();
        }
        catch (TransientException ex)
        {
            if (attempt == maxAttempts) throw;

            // Exponential backoff: 1s, 2s, 4s + random jitter up to 500ms
            var delay = TimeSpan.FromSeconds(Math.Pow(2, attempt - 1))
                      + TimeSpan.FromMilliseconds(random.Next(0, 500));

            _logger.LogWarning("Attempt {Attempt} failed, retrying in {Delay}ms", attempt, delay.TotalMilliseconds);
            await Task.Delay(delay);
        }
    }

    throw new UnreachableException();
}
```

**Polly retry — production approach**
```csharp
var retryPolicy = Policy
    .Handle<HttpRequestException>()
    .Or<TimeoutException>()
    // Explicitly do NOT retry on: 400, 401, 403, 404
    .OrResult<HttpResponseMessage>(r =>
        r.StatusCode == HttpStatusCode.TooManyRequests ||    // 429 — rate limited
        r.StatusCode == HttpStatusCode.ServiceUnavailable)   // 503 — transient
    .WaitAndRetryAsync(
        retryCount: 3,
        sleepDurationProvider: (attempt, outcome, _) =>
        {
            // Respect Retry-After header if present (rate limiting)
            if (outcome.Result?.Headers.RetryAfter?.Delta is { } retryAfter)
                return retryAfter;

            return TimeSpan.FromSeconds(Math.Pow(2, attempt))
                 + TimeSpan.FromMilliseconds(Random.Shared.Next(0, 300));
        },
        onRetryAsync: (outcome, delay, attempt, _) =>
        {
            _logger.LogWarning("Retry {Attempt} after {Delay}ms", attempt, delay.TotalMilliseconds);
            return Task.CompletedTask;
        }
    );
```

**Idempotency key — safe retry for write operations**
```csharp
public async Task<PaymentResult> ChargeAsync(decimal amount, Guid idempotencyKey)
{
    var request = new HttpRequestMessage(HttpMethod.Post, "/payments");
    // Server uses this key to deduplicate — same key = same result, no double charge
    request.Headers.Add("Idempotency-Key", idempotencyKey.ToString());
    request.Content = JsonContent.Create(new { Amount = amount });

    return await _retryPolicy.ExecuteAsync(() => _httpClient.SendAsync(request));
}
```

---

## Gotchas

- **Retrying non-idempotent operations causes data corruption.** POST /orders that creates an order and charges a card is not safe to retry unless the server implements idempotency keys. Retrying a succeeded-but-lost-response creates a duplicate order and charge. Confirm idempotency before adding retries to write operations.
- **Immediate retry on connection failure is almost always wrong.** If a TCP connection fails, the service is either down or overloaded. Retrying in the same millisecond achieves nothing. The minimum useful first retry delay is around 100–500ms for transient network issues.
- **Retry amplifies load by a multiplier of your retry count.** Three retries mean up to 3x the traffic to the downstream service during degradation. Combined with multiple upstream callers, a single degraded service can receive orders-of-magnitude more traffic than normal. This is why circuit breakers pair with retries.
- **Status code filtering is mandatory.** A policy that retries on all exceptions will retry on 400, 401, 404, and 500 alike. 400s are client bugs — retrying them wastes time. 401s are auth failures — retrying them locks accounts. Only retry on genuinely transient status codes (429, 503) and network exceptions.
- **Retry budgets prevent retry storms in fan-out systems.** If Service A fans out to 10 downstream services and each has 3 retries, a single request can generate 30 downstream calls on failure. Set an absolute retry deadline (e.g., total retry time ≤ 5s) rather than a fixed retry count.

---

## Interview Angle

**What they're really testing:** Whether you understand the second-order effects of retries — load amplification, idempotency requirements, and interaction with other resilience patterns.

**Common question form:** "How do you handle transient failures?" or "Walk me through your retry strategy."

**The depth signal:** A junior says "retry three times with a delay." A senior specifies exponential backoff with jitter, explains idempotency as a prerequisite for retrying writes (with idempotency keys as the concrete mechanism), distinguishes which HTTP status codes are retryable and which are not, and describes how retries interact with circuit breakers — retries handle transient noise, circuit breakers handle sustained outages — and why you need both, layered correctly.

---

## Related Topics

- [[system-design/circuit-breaker.md]] — circuit breakers stop retries from hammering a service that's genuinely down, not just transiently failing
- [[system-design/fault-tolerance.md]] — retries are one building block in the broader fault tolerance toolkit
- [[system-design/bulkhead-pattern.md]] — bulkheads limit how much damage retry amplification can do by capping concurrent calls per dependency

---

## Source

https://learn.microsoft.com/en-us/azure/architecture/patterns/retry

---

*Last updated: 2026-03-24*