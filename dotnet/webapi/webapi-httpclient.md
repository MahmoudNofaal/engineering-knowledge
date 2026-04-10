# ASP.NET Core HttpClient & IHttpClientFactory

> The correct way to make outbound HTTP requests from ASP.NET Core — using `IHttpClientFactory` to manage `HttpClient` instances, avoid socket exhaustion, and keep configuration per named client.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Factory-managed `HttpClient` pool that handles lifetime, DNS refresh, and configuration |
| **Use when** | Any outbound HTTP call to an external API or service |
| **Avoid when** | Never `new HttpClient()` in production — always use the factory |
| **Introduced** | `IHttpClientFactory` in ASP.NET Core 2.1 |
| **Namespace** | `System.Net.Http`, `Microsoft.Extensions.Http` |
| **Key types** | `IHttpClientFactory`, `HttpClient`, `HttpMessageHandler`, `DelegatingHandler` |

---

## When To Use It

Any time your application makes outbound HTTP requests — calling a payment gateway, querying a weather API, integrating with an internal microservice. Use `IHttpClientFactory` — never instantiate `HttpClient` with `new HttpClient()` in long-running code. The factory is the solution to two common `HttpClient` bugs: socket exhaustion (from creating too many instances) and stale DNS (from holding one instance too long).

---

## Core Concept

`HttpClient` has two problems when used naively. Creating a new instance per request exhausts the socket pool — `HttpClient` holds a `HttpMessageHandler` that keeps a TCP connection alive, and `Dispose` doesn't release the socket immediately. Reusing one static instance for the app's lifetime avoids socket exhaustion but holds DNS lookups indefinitely — if the target service's IP changes, your static instance never sees it. `IHttpClientFactory` solves both: it pools `HttpMessageHandler` instances, reuses them across `HttpClient` instances for a configured lifetime (2 minutes by default), and recreates them afterward to pick up DNS changes. You get a fresh `HttpClient` (cheap) that shares a pooled handler (efficient) with automatic renewal.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 2.1 | `IHttpClientFactory` introduced; named clients; typed clients |
| ASP.NET Core 2.1 | `AddHttpClient<T>` typed client registration |
| .NET 5 | `SocketsHttpHandler` became the default on all platforms |
| .NET 6 | `HttpClient` timeout improved; `IHttpClientFactory` integrates with `HttpClientHandler` lifetime config |
| .NET 8 | `KeyedService` support for named clients; resilience extensions via `Microsoft.Extensions.Http.Resilience` |

*`IHttpClientFactory` was added precisely because the correct use of raw `HttpClient` is non-obvious and the most intuitive pattern (create + use + dispose) is exactly wrong. The factory makes the correct pattern the easy path.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `IHttpClientFactory.CreateClient()` | ~1 µs | Returns a new `HttpClient` wrapping a pooled handler |
| `HttpMessageHandler` pool lookup | O(1) | Hash map lookup by client name |
| `HttpMessageHandler` recreation | O(connection setup) | Only on expiry (every 2 min by default) |
| DNS re-resolution | Every 2 min | On handler recreation; prevents stale DNS |

**Allocation behaviour:** `HttpClient` is a lightweight wrapper — allocates one object per call to `CreateClient()`. The expensive `HttpMessageHandler` (TCP connection pool) is shared and pooled. Don't pool `HttpClient` instances yourself — the factory does the right thing; your code should call `CreateClient()`, use it, and let it go out of scope.

**Benchmark notes:** The factory overhead is negligible. The bottleneck is always network I/O. For high-throughput services, configure `MaxConnectionsPerServer` on `SocketsHttpHandler` and tune the handler lifetime to match your target service's DNS TTL.

---

## The Code

**Basic named client**
```csharp
// Program.cs — register a named client with base URL and headers
builder.Services.AddHttpClient("PaymentGateway", client =>
{
    client.BaseAddress = new Uri("https://api.stripe.com");
    client.DefaultRequestHeaders.Add("Accept", "application/json");
    client.Timeout = TimeSpan.FromSeconds(30);
});

// Inject and use via IHttpClientFactory
public class PaymentService(IHttpClientFactory factory)
{
    public async Task<PaymentResult> ChargeAsync(ChargeRequest req)
    {
        var client   = factory.CreateClient("PaymentGateway");
        var response = await client.PostAsJsonAsync("/v1/charges", req);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<PaymentResult>()
               ?? throw new InvalidOperationException("Empty response.");
    }
}
```

**Typed client — cleaner, fully injectable**
```csharp
// Define the typed client class
public class StripeClient(HttpClient client)
{
    public async Task<ChargeResponse> CreateChargeAsync(ChargeRequest req)
    {
        var response = await client.PostAsJsonAsync("/v1/charges", req);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<ChargeResponse>()
               ?? throw new InvalidOperationException("Empty response.");
    }

    public async Task<Customer?> GetCustomerAsync(string customerId)
    {
        var response = await client.GetAsync($"/v1/customers/{customerId}");
        if (response.StatusCode == System.Net.HttpStatusCode.NotFound) return null;
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<Customer>();
    }
}

// Register
builder.Services.AddHttpClient<StripeClient>(client =>
{
    client.BaseAddress = new Uri("https://api.stripe.com");
    client.DefaultRequestHeaders.Authorization =
        new AuthenticationHeaderValue("Bearer", builder.Configuration["Stripe:SecretKey"]);
});

// Inject directly — no factory needed
public class OrderService(StripeClient stripe) { ... }
```

**`DelegatingHandler` — cross-cutting concerns (retry, logging, auth)**
```csharp
// Logging handler — logs every outbound request and response
public class LoggingHandler(ILogger<LoggingHandler> logger) : DelegatingHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken ct)
    {
        logger.LogInformation("→ {Method} {Uri}", request.Method, request.RequestUri);
        var sw       = Stopwatch.StartNew();
        var response = await base.SendAsync(request, ct);
        sw.Stop();
        logger.LogInformation("← {Status} in {Ms}ms", (int)response.StatusCode, sw.ElapsedMilliseconds);
        return response;
    }
}

// Register the handler and attach to a client
builder.Services.AddTransient<LoggingHandler>();
builder.Services.AddHttpClient<StripeClient>(client =>
{
    client.BaseAddress = new Uri("https://api.stripe.com");
})
.AddHttpMessageHandler<LoggingHandler>();
```

**Resilience with `Microsoft.Extensions.Http.Resilience` (.NET 8)**
```csharp
// dotnet add package Microsoft.Extensions.Http.Resilience
builder.Services.AddHttpClient<WeatherClient>(client =>
{
    client.BaseAddress = new Uri("https://api.weather.example.com");
})
.AddStandardResilienceHandler();  // adds retry, circuit breaker, timeout, bulkhead

// Or custom resilience pipeline:
.AddResilienceHandler("custom", pipeline =>
{
    pipeline.AddRetry(new HttpRetryStrategyOptions
    {
        MaxRetryAttempts = 3,
        Delay = TimeSpan.FromSeconds(1),
        BackoffType = DelayBackoffType.Exponential,
        ShouldHandle = args => args.Outcome switch
        {
            { Exception: HttpRequestException } => PredicateResult.True(),
            { Result.StatusCode: >= HttpStatusCode.InternalServerError } => PredicateResult.True(),
            _ => PredicateResult.False()
        }
    });
    pipeline.AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
    {
        SamplingDuration       = TimeSpan.FromSeconds(30),
        FailureRatio           = 0.5,
        MinimumThroughput      = 10,
        BreakDuration          = TimeSpan.FromSeconds(15)
    });
});
```

**Handling transient failures manually (without resilience package)**
```csharp
public async Task<T?> GetWithRetryAsync<T>(string url, int maxAttempts = 3)
{
    var client = _factory.CreateClient("ExternalApi");

    for (int attempt = 1; attempt <= maxAttempts; attempt++)
    {
        try
        {
            var response = await client.GetAsync(url);
            if (response.IsSuccessStatusCode)
                return await response.Content.ReadFromJsonAsync<T>();

            if ((int)response.StatusCode >= 500 && attempt < maxAttempts)
            {
                await Task.Delay(TimeSpan.FromSeconds(Math.Pow(2, attempt)));
                continue;
            }

            return default;
        }
        catch (HttpRequestException) when (attempt < maxAttempts)
        {
            await Task.Delay(TimeSpan.FromSeconds(Math.Pow(2, attempt)));
        }
    }
    return default;
}
```

---

## Real World Example

A shipping API integrates with three carrier APIs (FedEx, UPS, DHL). Each has different base URLs, auth headers, and timeout requirements. Typed clients encapsulate each carrier; a `LoggingHandler` applies to all of them.

```csharp
// Carrier clients
public class FedExClient(HttpClient client) : ICarrierClient
{
    public async Task<ShippingRate> GetRateAsync(ShipmentRequest req)
    {
        var response = await client.PostAsJsonAsync("/rate/v1/rates/quotes", req);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<ShippingRate>()
               ?? throw new InvalidOperationException();
    }
}

public class UpsClient(HttpClient client) : ICarrierClient
{
    public async Task<ShippingRate> GetRateAsync(ShipmentRequest req)
    {
        var response = await client.PostAsJsonAsync("/api/rating/v1/rate", req);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<ShippingRate>()
               ?? throw new InvalidOperationException();
    }
}

// Program.cs — each carrier gets its own config
builder.Services.AddTransient<LoggingHandler>();

builder.Services.AddHttpClient<FedExClient>(client =>
{
    client.BaseAddress = new Uri("https://apis.fedex.com");
    client.DefaultRequestHeaders.Authorization =
        new AuthenticationHeaderValue("Bearer", config["FedEx:Token"]);
    client.Timeout = TimeSpan.FromSeconds(15);
})
.AddHttpMessageHandler<LoggingHandler>()
.AddStandardResilienceHandler();

builder.Services.AddHttpClient<UpsClient>(client =>
{
    client.BaseAddress = new Uri("https://onlinetools.ups.com");
    client.DefaultRequestHeaders.Add("transId", Guid.NewGuid().ToString());
    client.Timeout = TimeSpan.FromSeconds(20);
})
.AddHttpMessageHandler<LoggingHandler>()
.AddStandardResilienceHandler();

// Rate comparison service
public class ShippingRateService(FedExClient fedEx, UpsClient ups, DhlClient dhl)
{
    public async Task<IReadOnlyList<ShippingRate>> GetAllRatesAsync(ShipmentRequest req)
    {
        var tasks = new[]
        {
            fedEx.GetRateAsync(req),
            ups.GetRateAsync(req),
            dhl.GetRateAsync(req)
        };

        var results = await Task.WhenAll(tasks.Select(async t =>
        {
            try { return await t; }
            catch { return null; }  // one carrier failing doesn't block the others
        }));

        return results.Where(r => r is not null).ToList()!;
    }
}
```

*The key insight: each carrier's typed client encapsulates the authentication, base URL, and serialisation details specific to that carrier. The `ShippingRateService` has no knowledge of HTTP — it just calls `GetRateAsync` on each client. Adding a fourth carrier is a new typed client class and a registration line, not changes to existing code.*

---

## Common Misconceptions

**"I should reuse one `HttpClient` instance as a singleton."**
This solves socket exhaustion but creates stale DNS. If the target service's IP changes (failover, scaling, DNS update), your static instance never sees it and requests silently go to the old IP. `IHttpClientFactory` rotates `HttpMessageHandler` instances every 2 minutes, solving both problems simultaneously.

**"Calling `Dispose()` on `HttpClient` releases the socket immediately."**
It does not. `HttpClient.Dispose()` disposes the `HttpMessageHandler`, but sockets enter `TIME_WAIT` state and aren't immediately released by the OS. Creating and disposing `HttpClient` frequently rapidly exhausts the socket pool. The factory's pooling model is the correct solution — it keeps handlers alive and shares them across `HttpClient` instances.

**"Typed clients are singletons."**
Typed clients (`AddHttpClient<T>`) are registered as transient services. The underlying `HttpMessageHandler` is pooled, but the `HttpClient` wrapper and the typed client class are new per injection. This is correct behaviour — it lets the typed client class safely hold per-request state if needed.

---

## Gotchas

- **Never store `HttpClient` returned by `CreateClient()` as a field or property.** The factory gives you a client that wraps a pooled handler. Storing it defeats the pooling model and reintroduces the stale DNS problem. Inject `IHttpClientFactory` as a field and call `CreateClient()` per operation.

- **`EnsureSuccessStatusCode()` throws `HttpRequestException` with no response body details.** The exception message includes the status code but not the response body — which often contains the error detail you need for debugging. Read the body before throwing: `var body = await response.Content.ReadAsStringAsync(); response.EnsureSuccessStatusCode();` — but note `EnsureSuccessStatusCode` disposes the response, so read the body first if the request fails.

- **`client.Timeout` is a per-request total timeout, not a connection or read timeout.** It covers DNS resolution + TCP connection + headers + body read — all combined. For APIs with slow-starting but fast-streaming responses, this can cause timeouts. Use `CancellationToken` and `HttpCompletionOption.ResponseHeadersRead` for fine-grained control.

- **`BaseAddress` requires a trailing slash, and relative paths must NOT start with a slash.** `client.BaseAddress = new Uri("https://api.example.com/v1/")` + `client.GetAsync("orders")` → `https://api.example.com/v1/orders`. But `client.GetAsync("/orders")` → `https://api.example.com/orders` (the `/v1` path is dropped). This is URI combining behaviour from `System.Uri`, not an HttpClient bug.

- **`DelegatingHandler` instances registered as `Transient` are recreated per `HttpMessageHandler` expiry.** If your delegating handler holds state (counters, caches), be aware of this. Stateless handlers (logging, auth header injection) are always safe as transient.

---

## Interview Angle

**What they're really testing:** Whether you know the two classic `HttpClient` bugs (socket exhaustion, stale DNS) and can explain why `IHttpClientFactory` solves both — not just "use the factory."

**Common question forms:**
- "What's wrong with `new HttpClient()` in a controller?"
- "What is `IHttpClientFactory` and why does it exist?"
- "How do you add retry logic to outbound HTTP calls?"
- "What's the difference between named clients and typed clients?"

**The depth signal:** A junior says "use `IHttpClientFactory` instead of `new HttpClient()`." A senior explains socket exhaustion (sockets enter `TIME_WAIT`), stale DNS (static instances never re-resolve), how the factory rotates handlers on a 2-minute default lifecycle, why typed clients are transient while their handlers are pooled, and how `DelegatingHandler` gives you a composable pipeline for retry, auth, correlation ID, and logging without touching the typed client's business logic. Bonus: knowing `AddStandardResilienceHandler()` from `Microsoft.Extensions.Http.Resilience` is the modern way to add retry + circuit breaker in .NET 8.

**Follow-up questions to expect:**
- "How do you configure different timeouts for different external services?"
- "How do you inject authentication tokens into outbound requests?"
- "How would you implement a circuit breaker for an external service?"

---

## Related Topics

- [[dotnet/webapi/dependency-injection.md]] — typed clients are registered via `AddHttpClient<T>()` and resolved via DI; understanding lifetimes explains why typed clients are transient
- [[dotnet/webapi/webapi-configuration.md]] — base URLs, API keys, and timeouts for external services come from configuration; never hardcode them
- [[dotnet/webapi/webapi-background-services.md]] — background services frequently make outbound HTTP calls; `IHttpClientFactory` is injected into `BackgroundService` implementations the same way as controllers
- [[system-design/reliability-and-vailability/circuit-breaker.md]] — the circuit breaker pattern protects your API from cascading failures when downstream services are degraded

---

## Source

https://learn.microsoft.com/en-us/dotnet/core/extensions/httpclient-factory

---
*Last updated: 2026-04-10*