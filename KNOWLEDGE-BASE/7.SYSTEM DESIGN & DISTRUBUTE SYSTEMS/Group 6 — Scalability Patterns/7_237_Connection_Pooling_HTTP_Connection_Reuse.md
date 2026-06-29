---
id: "7.237"
title: "Connection Pooling — HTTP Connection Reuse"
domain: "System Design & Distributed Systems"
domain_id: 7
group: "Scalability Patterns"
tags: [system-design, distributed-systems, scalability, dotnet, azure, connection-pooling, http, httpclient, ihttpclientfactory, sockets, dns, grpc]
priority: 2
prerequisites:
  - "[[7.236 — Connection Pooling — SQL at Scale]] — HTTP connection pooling follows many of the same principles (pool exhaustion, fragmentation, min/max sizing) but differs in eviction strategy (idle timeout vs lifetime-based recycling)"
  - "[[7.206 — Horizontal vs Vertical Scaling — Tradeoffs]] — each horizontally scaled instance creates its own HTTP connection pool; the aggregate number of outbound connections per target service must be accounted for in capacity planning"
  - "[[7.210 — Load Balancing — Overview]] — HTTP connection pooling interacts with load balancer idle timeout; an idle pooled connection may be terminated by the load balancer, causing a reset on the next request"
related:
  - "[[7.236 — Connection Pooling — SQL at Scale]] — SQL vs HTTP pooling: SQL pools are per-connection-string, HTTP pools are per-server-endpoint; SQL uses lifetime-based eviction, HTTP uses idle-timeout-based eviction"
  - "[[7.237 — HTTP/2 Multiplexing]] — HTTP/2 multiplexes multiple concurrent requests over a single TCP connection, reducing the need for connection pooling but requiring stream-level flow control"
  - "[[4.049 — IHttpClientFactory — Why HttpClient Must Never Be Newed Directly]] — the canonical .NET reference for HttpClientFactory; this note generalizes the pooling mechanism across all HTTP stacks"
  - "[[7.212 — Load Balancing — Round Robin]] — connection pooling can interfere with round-robin load balancing by pinning connections to one backend; reconnection triggers rebalancing"
  - "[[7.238 — Backpressure — Detection and Handling]] — HTTP connection pooling interacts with backpressure: pooled connections waiting for responses can obscure downstream backpressure signals"
created: 2026-06-17
---

## Navigation

**Domain:** [[7 — System Design & Distributed Systems]] > **Group:** Scalability Patterns
**Previous:** [[7.236 — Connection Pooling — SQL at Scale]] | **Next:** [[7.238 — Backpressure — Detection and Handling]]

### Prerequisites

- [[7.236 — Connection Pooling — SQL at Scale]] — HTTP connection pooling follows many of the same principles (pool exhaustion, fragmentation, min/max sizing) but differs in eviction strategy (idle timeout vs lifetime-based recycling)
- [[7.206 — Horizontal vs Vertical Scaling — Tradeoffs]] — each horizontally scaled instance creates its own HTTP connection pool; the aggregate number of outbound connections per target service must be accounted for in capacity planning
- [[7.210 — Load Balancing — Overview]] — HTTP connection pooling interacts with load balancer idle timeout; an idle pooled connection may be terminated by the load balancer, causing a reset on the next request

### Where This Fits

HTTP connection pooling reuses TCP connections across HTTP requests to avoid the cost of TCP + TLS handshakes for every API call. At low scale (1–2 services, <100 req/s), each request opens a new connection and the cost is acceptable (~15ms TCP + ~40ms TLS for Azure-internal traffic). Above ~1,000 req/s to a downstream service, connection reuse becomes critical — opening 1,000 connections per second adds 15 seconds of handshake overhead per second of real work, and ephemeral port exhaustion on the caller becomes a real risk. A .NET engineer encounters HTTP connection pooling when debugging `HttpRequestException: A connection attempt failed because the connected party did not properly respond after a period of time` (socket exhaustion), configuring `IHttpClientFactory` for a microservice that calls 10 downstream services, or investigating why DNS changes to a backend service take 15 minutes to take effect (connection pooling caches DNS until connection is recycled). Without it, every HTTP call pays a 15–100ms TCP + TLS tax, ephemeral ports are exhausted at ~2,000 concurrent outbound connections, and DNS-based failover is useless because connections never close.

---

## Core Mental Model

HTTP connection pooling maintains a set of idle TCP connections to a remote server and reuses them for multiple HTTP requests, eliminating the TCP + TLS handshake from subsequent requests. The pool is per-server-endpoint, per-scheme, and per-client-instance — unlike SQL pooling which keys on the full connection string. The tradeoff is connection stickiness vs. resource reuse: idle connections consume local ephemeral ports and remote server file descriptors, but they eliminate the 15–100ms connection establishment cost and avoid the ephemeral port churn that leads to socket exhaustion. The recognition trigger is the `HttpClient` anti-pattern: `new HttpClient()` inside a `using` block that creates and destroys connections on every call — and the resulting `SocketException: Only one usage of each socket address is normally permitted` when ephemeral ports are depleted.

### Classification

HTTP connection pooling operates at the transport layer (TCP) and presentation layer (TLS) of the OSI model — between the application code (HTTP requests) and the socket abstraction. It is scoped to outbound HTTP connections from a single process. Pooling explicitly does NOT solve: server-side connection limits (requires server configuration), cross-process pooling (each process has its own pool), or HTTP/2 stream multiplexing (HTTP/2 handles concurrent requests on a single connection natively, reducing the need for multiple pooled connections).

```mermaid
flowchart LR
    subgraph "Application Process"
        APP[Application Code] -->|HttpClient.SendAsync| HCHandler[SocketsHttpHandler]
        HCHandler --> POOL{Connection Pool}
        POOL -->|HTTP/1.1| POOL11[(Pool of TCP connections<br/>per (host, port, scheme))]
        POOL -->|HTTP/2| POOL2[(Single TCP connection<br/>multiplexed streams)]
        POOL11 -->|idle connection| C1[Connection 1<br/>127.0.0.1:54321 → api.com:443]
        POOL11 -->|idle connection| C2[Connection 2<br/>127.0.0.1:54322 → api.com:443]
        POOL2 -->|stream 1| C3[Connection 3<br/>Multiple streams over 1 TCP]
        HCHandler -->|no idle, create new| CN[New TCP + TLS]
        CN -->|SYN → SYN-ACK → ACK<br/>ClientHello → ServerHello → Finished| TARGET[(Target Server)]
    end

    subgraph "Eviction Triggers"
        IDLE[Idle Timeout<br/>Default: 100s<br/>SocketsHttpHandler.PooledConnectionIdleTimeout]
        LIFE[Connection Lifetime<br/>Default: infinite<br/>SocketsHttpHandler.PooledConnectionLifetime]
        ERR[Unexpected RST<br/>or TLS error]
    end

    subgraph "Scale Failure Modes"
        PORTS[Ephemeral Port Exhaustion<br/>Default: 16,384 ports<br/>Windows: 16384-65535]
        DNS[DNS Staleness<br/>Pool holds connections<br/>to old IP after DNS change]
        PERR[Per-server connection limit<br/>Default: infinite<br/>SocketsHttpHandler.MaxConnectionsPerServer]
    end

    POOL11 --> IDLE
    POOL11 --> LIFE
    POOL11 --> ERR
    CN -.-> PORTS
    CN -.-> DNS
    POOL11 -.-> PERR
```

### Key Properties

| Property | Value | Condition |
|---|---|---|
| TCP handshake cost | ~15ms (Azure-internal), ~40ms (cross-region TCP + TLS) | First request per connection |
| Connection reuse savings | 100% of handshake cost for subsequent requests | HTTP/1.1 Keep-Alive |
| HTTP/2 multiplexing | Single TCP connection, up to 100 concurrent streams | HTTP/2 negotiated in TLS ALPN |
| Default idle timeout (SocketsHttpHandler) | 100 seconds | `PooledConnectionIdleTimeout` |
| Default connection lifetime | Infinite | `PooledConnectionLifetime` = `Timeout.InfiniteTimeSpan` (must set for DNS rotation) |
| Max connections per server | Infinite (unlimited) | `MaxConnectionsPerServer` = `int.MaxValue` |
| Ephemeral port range (Windows) | 16,384 ports (default 16384–65535) | `netsh int ipv4 show dynamicport tcp` |
| Ephemeral port range (Linux) | 28,235 ports (default 32768–60999) | `/proc/sys/net/ipv4/ip_local_port_range` |
| Port recovery after CLOSE_WAIT | 2–4 minutes (TIME_WAIT state) | Can be tuned with `tcp_tw_reuse` (Linux) |
| IHttpClientFactory handler reuse | 2 minutes (default handler lifetime) | `SocketsHttpHandler` recycled every 2 min |

---

## Deep Mechanics

### How It Works

The .NET HTTP connection pool is implemented by `SocketsHttpHandler` (the default handler in .NET Core 3.0+). It replaces the legacy `HttpClientHandler`/`HttpWinHttpHandler` stack and manages connections internally.

**Phase 1 — Connection Establishment (first request to a new endpoint).** When `HttpClient.SendAsync()` is called with a URI like `https://payment-service.internal/api/process`, `SocketsHttpHandler` resolves the hostname to an IP address via DNS (cached for `PooledConnectionLifetime`). It looks up the connection pool for `(payment-service.internal:443, https)`. No pool entry exists, so it initiates a new TCP connection: DNS resolution (~1ms cached, ~20ms uncached), TCP SYN/SYN-ACK/ACK (~15ms), TLS ClientHello/ServerHello/Certificate/Finished (~20ms). Total: ~36ms. The connection is established and the HTTP request is sent.

**Phase 2 — Connection Pooling (subsequent requests).** After the request completes, the connection is NOT closed. `SocketsHttpHandler` holds it open and returns it to the idle pool. The next request to the same endpoint picks up the idle connection (no TCP/TLS handshake) and sends the request immediately — <1ms for the pool lookup.

**Phase 3 — Connection Eviction.** Idle connections are evicted based on two timers:
- `PooledConnectionIdleTimeout` (default 100s): If a connection has been idle for this duration, it is closed. This prevents stale connections from consuming resources.
- `PooledConnectionLifetime` (default infinite): If set, a connection is closed after this duration from creation, REGARDLESS of activity. This is critical for DNS rotation — without it, a connection to an old IP address is never recycled.

When evicted, the connection's TCP socket is closed, the ephemeral port is freed, and the server's file descriptor is released.

**Phase 4 — Connection Failure and Retry.** If a pooled connection fails (TCP RST, TLS alert), `SocketsHttpHandler` marks it as invalid and removes it from the pool. The next request triggers a new connection establishment. This is transparent to the application code — `SendAsync` does not throw for a pooled connection failure unless the retry also fails.

```csharp
// Port: Internal HTTP connection pool behavior modeled for understanding
// Demonstrates the SocketsHttpHandler pooling logic

/// <summary>
/// Simulates the SocketsHttpHandler HTTP connection pool for understanding
/// connection lifecycle, eviction, and failure modes at scale.
/// </summary>
internal sealed class HttpConnectionPoolSimulator : IDisposable
{
    private readonly ConcurrentDictionary<string, ConcurrentBag<PooledHttpConnection>> _pools = new();
    private readonly Timer _evictionTimer;
    private readonly HttpConnectionPoolOptions _options;

    public HttpConnectionPoolSimulator(HttpConnectionPoolOptions options)
    {
        _options = options;
        _evictionTimer = new Timer(EvictIdleConnections, null,
            TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(10));
    }

    public async Task<PooledHttpConnection> GetConnectionAsync(Uri requestUri, CancellationToken ct)
    {
        var poolKey = BuildPoolKey(requestUri);

        // Try to get an idle connection
        if (_pools.TryGetValue(poolKey, out var pool))
        {
            while (pool.TryTake(out var connection))
            {
                if (connection.IsExpired(_options.ConnectionLifetime))
                {
                    await connection.CloseAsync();
                    continue;
                }
                connection.LastUsedAt = DateTime.UtcNow;
                return connection;
            }
        }

        // No idle connection — create new one
        var newConnection = await EstablishConnectionAsync(requestUri, ct);
        newConnection.PoolKey = poolKey;
        return newConnection;
    }

    public async Task ReturnConnectionAsync(PooledHttpConnection connection)
    {
        if (connection.HasError)
        {
            await connection.CloseAsync();
            return;
        }

        var pool = _pools.GetOrAdd(connection.PoolKey!, _ => new ConcurrentBag<PooledHttpConnection>());

        // Check if pool is at capacity per-server
        var serverConnections = _pools.Values.Sum(p => p.Count);
        if (serverConnections >= _options.MaxConnectionsPerServer)
        {
            await connection.CloseAsync();
            return;
        }

        connection.LastUsedAt = DateTime.UtcNow;
        pool.Add(connection);
    }

    private async Task<PooledHttpConnection> EstablishConnectionAsync(Uri uri, CancellationToken ct)
    {
        // DNS resolution (cached per PooledConnectionLifetime)
        var addresses = await Dns.GetHostAddressesAsync(uri.Host, ct);
        var ip = addresses[0];

        // TCP handshake: ~15ms simulated
        await Task.Delay(15, ct);

        // TLS handshake: ~20ms simulated (for HTTPS)
        if (uri.Scheme.Equals("https", StringComparison.OrdinalIgnoreCase))
            await Task.Delay(20, ct);

        return new PooledHttpConnection
        {
            Id = Guid.NewGuid().ToString(),
            RemoteEndpoint = $"{ip}:{uri.Port}",
            CreatedAt = DateTime.UtcNow,
            LastUsedAt = DateTime.UtcNow
        };
    }

    private void EvictIdleConnections(object? state)
    {
        foreach (var (key, pool) in _pools)
        {
            var remaining = new ConcurrentBag<PooledHttpConnection>();
            while (pool.TryTake(out var connection))
            {
                var idleTime = DateTime.UtcNow - connection.LastUsedAt;

                if (idleTime > _options.IdleTimeout)
                {
                    connection.CloseAsync().AsTask().GetAwaiter().GetResult();
                }
                else if (connection.IsExpired(_options.ConnectionLifetime))
                {
                    connection.CloseAsync().AsTask().GetAwaiter().GetResult();
                }
                else
                {
                    remaining.Add(connection);
                }
            }
            while (remaining.TryTake(out var connection))
                pool.Add(connection);
        }
    }

    private static string BuildPoolKey(Uri uri)
        => $"{uri.Scheme}://{uri.Host}:{uri.Port}";

    public void Dispose()
    {
        _evictionTimer.Dispose();
        foreach (var (_, pool) in _pools)
        {
            while (pool.TryTake(out var connection))
                connection.CloseAsync().AsTask().GetAwaiter().GetResult();
        }
    }
}

internal sealed class PooledHttpConnection
{
    public string Id { get; set; } = "";
    public string? PoolKey { get; set; }
    public string RemoteEndpoint { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime LastUsedAt { get; set; }
    public bool HasError { get; set; }

    public bool IsExpired(TimeSpan lifetime)
    {
        if (lifetime == Timeout.InfiniteTimeSpan) return false;
        return DateTime.UtcNow - CreatedAt > lifetime;
    }

    public async Task CloseAsync()
    {
        // Send FIN → CLOSE_WAIT → LAST_ACK → TIME_WAIT
        await Task.Delay(1);
    }
}

internal sealed record HttpConnectionPoolOptions
{
    public TimeSpan IdleTimeout { get; init; } = TimeSpan.FromSeconds(100);
    public TimeSpan ConnectionLifetime { get; init; } = Timeout.InfiniteTimeSpan;
    public int MaxConnectionsPerServer { get; init; } = int.MaxValue;
}
```

### Failure Modes

**Ephemeral Port Exhaustion.** The most common and dangerous HTTP connection pooling failure. Each outbound TCP connection consumes one ephemeral port on the caller. When all ephemeral ports are in-use, new connections fail with `SocketException (10048): Only one usage of each socket address is normally permitted` on Windows or `Cannot assign requested address` on Linux. Default ephemeral range: ~16,384 (Windows) or ~28,235 (Linux). At 2,000 req/s with 8-second average connection hold time (slow downstream service), the caller exhausts ports in ~80 seconds. Note: this is caused by creating NEW connections for every request (no pooling) OR by pooled connections that are not returned to the pool (leak).

*Detection:* Netstat shows thousands of connections in TIME_WAIT or CLOSE_WAIT state. `ss -s` (Linux) shows `TCP: 16384 established, 0 orphan, 28000 TIME_WAIT`. Event log shows `SocketException: Only one usage of each socket address is normally permitted`.

*Recovery:* Reduce TIME_WAIT on Linux with `sysctl net.ipv4.tcp_tw_reuse=1` and `sysctl net.ipv4.tcp_tw_recycle=0` (tw_recycle is deprecated). On Windows, reduce TIME_WAIT with `Set-NetTCPSetting -SettingName InternetCustom -TimeWaitTime 30` (default 240s). But the real fix: ensure connection pooling is working — `IHttpClientFactory` with `SocketsHttpHandler` — and set `PooledConnectionIdleTimeout` appropriately.

*Prevention:* Always use `IHttpClientFactory` (not `new HttpClient()`). Set `MaxConnectionsPerServer` to limit per-endpoint connections. Monitor ephemeral port usage with `cat /proc/net/sockstat` or `Get-NetTCPConnection`.

**DNS Staleness from Infinite Connection Lifetime.** `PooledConnectionLifetime` defaults to infinite. When a pooled TCP connection is held open, DNS resolution is cached for the connection's lifetime. If the target server's IP address changes (DNS rotation, blue-green deployment, failover), the application continues sending requests to the OLD IP address via the pooled connection. The old server may be decommissioned, causing `Connection Refused` or `Connection Timed Out`.

*Detection:* Application calls a service that was healthy 5 minutes ago, and suddenly gets `ConnectionRefused` or `ConnectionTimedOut`. `nslookup payment-service.internal` shows a different IP than the one in `ss -tnp | grep payment-service`. The old IP's server was taken out of the load balancer.

*Recovery:* Set `PooledConnectionLifetime` to a reasonable value (30–300 seconds). This forces the connection to be recycled periodically, triggering DNS re-resolution.

```csharp
// ✅ Right — connection lifetime enables DNS rotation
var handler = new SocketsHttpHandler
{
    PooledConnectionLifetime = TimeSpan.FromSeconds(120),
    PooledConnectionIdleTimeout = TimeSpan.FromSeconds(60),
    MaxConnectionsPerServer = 10
};
```

**Per-Server Connection Starvation.** `MaxConnectionsPerServer` defaults to `int.MaxValue` (unlimited). Without a limit, a single burst of concurrent requests to one endpoint can create thousands of connections, consuming ephemeral ports and overwhelming the downstream server. Conversely, setting the limit too LOW creates queueing: requests block waiting for a connection while idle connections are available but reserved for other requests.

*Detection:* Requests to a downstream service timeout while `netstat` shows only a few connections to that endpoint. The connections are idle but the pool's connection limit is reached. `HttpClient` logs show `Request queueing` or connection wait time increasing.

*Recovery:* Set `MaxConnectionsPerServer` based on expected concurrency: `concurrent_requests = req/s × p99_response_time`. At 2,000 req/s and 200ms p99, concurrent requests = 400. Set `MaxConnectionsPerServer = 400`. Monitor connection count and queue depth.

**HTTP/2 Connection Failure Cascade.** HTTP/2 multiplexes all requests over a SINGLE TCP connection. If that connection fails (network partition, TLS renegotiation failure, upstream proxy timeout), ALL in-flight requests fail simultaneously — 0 to 100 requests depending on concurrent stream count. This is called a "single point of failure for all streams."

*Detection:* A burst of `HttpRequestException` or `HttpIOException` errors to the same endpoint. All requests to the downstream service fail at the same timestamp. After the connection is re-established, requests succeed again.

*Recovery:* Configure HTTP/2 connection health checks. Some implementations support pinging (HTTP/2 PING frame) to detect dead connections. Set `SocketsHttpHandler.KeepAlivePingDelay` and `KeepAlivePingTimeout` to proactively detect dead connections:

```csharp
// ✅ Right — HTTP/2 keep-alive detects dead connections proactively
var handler = new SocketsHttpHandler
{
    EnableMultipleHttp2Connections = true, // Allow multiple HTTP/2 connections
    KeepAlivePingDelay = TimeSpan.FromSeconds(30),
    KeepAlivePingTimeout = TimeSpan.FromSeconds(10)
};
```

**HttpClientHandler Cache Poisoning from Headers.** `IHttpClientFactory` creates a new `HttpClient` for each named client. The underlying `SocketsHttpHandler` is cached and reused. If the application sets headers on the `HttpClient.DefaultRequestHeaders` that vary per request (e.g., correlation ID, tenant ID), those headers are SHARED across all uses of that named client. This is not a connection pool issue per se, but it causes incorrect behavior that looks like a pool issue.

*Detection:* Requests from different tenants share the same tenant header because the HttpClient is cached. Tenant A's data is returned to Tenant B.

*Recovery:* Use `HttpRequestMessage.Headers` (per-request) instead of `HttpClient.DefaultRequestHeaders` (shared). Use `IHttpClientFactory` named clients with separate configuration per downstream service, not per-tenant.

### .NET and Azure Integration

- **IHttpClientFactory:** The canonical .NET pattern for managing `HttpClient` lifetimes. Registered with `builder.Services.AddHttpClient()`. Creates a `SocketsHttpHandler` pool per named/typed client. The handler is recycled every 2 minutes (default handler lifetime). Connections within the handler are pooled separately.
- **SocketsHttpHandler:** The default handler in .NET Core 3.0+. Properties: `PooledConnectionIdleTimeout` (default 100s), `PooledConnectionLifetime` (default infinite), `MaxConnectionsPerServer` (default unlimited), `EnableMultipleHttp2Connections` (default false), `KeepAlivePingDelay` (HTTP/2).
- **Polly + IHttpClientFactory:** Resilience policies (retry, circuit breaker, timeout) are applied via `AddHttpClient(...).AddTransientHttpErrorPolicy()`. Polly wraps the handler chain. Crucially: Polly's retry policy should account for connection pooling — a retry on a dead pooled connection should force a new connection (by evicting the dead one from the pool), not retry on the same broken connection.
- **gRPC + HTTP/2:** gRPC requires HTTP/2. `Grpc.Net.Client` uses `SocketsHttpHandler` internally. Connection pooling is essential for gRPC because the HTTP/2 connection carries multiple RPCs. Channel reuse (one `GrpcChannel` per endpoint, reused via DI singleton) is the equivalent of connection pooling in the gRPC world. `GrpcChannelOptions.HttpHandler` allows configuring the underlying `SocketsHttpHandler`.
- **Azure SDK + Connection Pooling:** Azure SDK clients (e.g., `BlobServiceClient`, `SecretClient`) accept an `HttpClient` or use the default `HttpClient` lifecycle. Each SDK client should be registered as a singleton to reuse its internal connection pool. The `Azure.Core` pipeline has its own retry and connection handling on top of HttpClient.
- **Azure Load Balancer idle timeout:** Azure Load Balancer and Application Gateway have a default idle timeout of 4 minutes. The `PooledConnectionIdleTimeout` (default 100s) is shorter than 4 minutes, so connections are recycled before the load balancer kills them. However, if `PooledConnectionIdleTimeout` is increased beyond 4 minutes, the load balancer may terminate the connection, and the pooled connection sends data to a dead socket — resulting in a TCP RST on the next request.
- **Service Fabric / Dapr sidecar:** Sidecar proxies (Dapr, Envoy) sit between the application and downstream services. Connection pooling at the application layer connects to the sidecar (loopback), and the sidecar has its own connection pool to the actual service. This creates two layers of pooling: app → sidecar (one hop, low latency) and sidecar → service (managed by the sidecar's connection pool).

```csharp
// Port: Production .NET HTTP connection pool configuration

/// <summary>
/// Configures IHttpClientFactory with SocketsHttpHandler pooling for high-throughput microservice communication.
/// </summary>
public static class HttpClientConfiguration
{
    /// <summary>
    /// Registers typed HttpClient for the payment service gateway.
    /// Configured with connection pooling limits, DNS-aware lifetime, and Polly retry.
    /// </summary>
    public static IServiceCollection AddPaymentServiceClient(
        this IServiceCollection services, IConfiguration configuration)
    {
        var paymentServiceUrl = configuration["Services:PaymentService:BaseUrl"]
            ?? throw new InvalidOperationException("PaymentService:BaseUrl required");

        services.AddHttpClient<IPaymentServiceClient, PaymentServiceClient>(client =>
        {
            client.BaseAddress = new Uri(paymentServiceUrl);
            client.Timeout = TimeSpan.FromSeconds(10);
        })
        .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
        {
            // Connection pool sizing
            MaxConnectionsPerServer = 20,
            PooledConnectionIdleTimeout = TimeSpan.FromSeconds(60),
            PooledConnectionLifetime = TimeSpan.FromMinutes(5),

            // HTTP/2 (if the downstream supports it)
            EnableMultipleHttp2Connections = true,
            KeepAlivePingDelay = TimeSpan.FromSeconds(30),
            KeepAlivePingTimeout = TimeSpan.FromSeconds(10),

            // DNS behavior
            ConnectTimeout = TimeSpan.FromSeconds(5),
        })
        .AddTransientHttpErrorPolicy(policy =>
            policy.WaitAndRetryAsync(3, retryAttempt =>
                TimeSpan.FromMilliseconds(100 * Math.Pow(2, retryAttempt))));

        return services;
    }
}

/// <summary>
/// Payment service client with typed HttpClient.
/// Registered as a transient service — HttpClient is injected and managed by the factory.
/// </summary>
public sealed class PaymentServiceClient : IPaymentServiceClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<PaymentServiceClient> _logger;

    public PaymentServiceClient(HttpClient httpClient, ILogger<PaymentServiceClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<PaymentResponse> ProcessPaymentAsync(
        PaymentRequest request, CancellationToken ct)
    {
        var response = await _httpClient.PostAsJsonAsync("/api/payments", request, ct);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<PaymentResponse>(ct))!;
    }
}
```

```csharp
// Program.cs — wiring the configured client with health checks

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddPaymentServiceClient(builder.Configuration);

builder.Services.AddHealthChecks()
    .AddUrlGroup(new Uri(builder.Configuration["Services:PaymentService:BaseUrl"] + "/health"),
        "payment-service", HealthStatus.Degraded, timeout: TimeSpan.FromSeconds(3));

builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics => metrics
        .AddHttpClientInstrumentation() // Captures connection pool metrics
        .AddPrometheusExporter());

var app = builder.Build();
app.MapHealthChecks("/health");
app.MapPrometheusScrapingEndpoint();
app.Run();
```

---

## Production Patterns and Implementation

### Primary Implementation

The production pattern for HTTP connection pooling at scale is: (1) typed `HttpClient` per downstream service via `IHttpClientFactory`, (2) `SocketsHttpHandler` configured with finite `MaxConnectionsPerServer`, finite `PooledConnectionLifetime`, and conservative `PooledConnectionIdleTimeout`, (3) Polly resilience for transient failures.

```yaml
# appsettings.json — configuration for HTTP connection pools
{
  "Services": {
    "PaymentService": {
      "BaseUrl": "https://payment-service.internal",
      "HttpClient": {
        "MaxConnectionsPerServer": 20,
        "PooledConnectionIdleTimeoutSeconds": 60,
        "PooledConnectionLifetimeMinutes": 5,
        "TimeoutSeconds": 10,
        "RetryCount": 3,
        "RetryBaseDelayMs": 100
      }
    },
    "InventoryService": {
      "BaseUrl": "https://inventory-service.internal",
      "HttpClient": {
        "MaxConnectionsPerServer": 50,
        "PooledConnectionIdleTimeoutSeconds": 120,
        "PooledConnectionLifetimeMinutes": 10,
        "TimeoutSeconds": 30,
        "RetryCount": 2,
        "RetryBaseDelayMs": 200
      }
    }
  }
}
```

### Configuration and Wiring

```csharp
// Configurable registration using IOptions pattern

public sealed class HttpClientPoolOptions
{
    public int MaxConnectionsPerServer { get; set; } = 10;
    public int PooledConnectionIdleTimeoutSeconds { get; set; } = 60;
    public int PooledConnectionLifetimeMinutes { get; set; } = 5;
    public int TimeoutSeconds { get; set; } = 10;
    public int RetryCount { get; set; } = 3;
    public int RetryBaseDelayMs { get; set; } = 100;
}

public static IServiceCollection AddServiceClient<TClient, TImplementation>(
    this IServiceCollection services,
    string configurationSection,
    string baseUrl)
    where TClient : class
    where TImplementation : class, TClient
{
    services.AddOptions<HttpClientPoolOptions>(configurationSection)
        .BindConfiguration(configurationSection);

    services.AddHttpClient<TClient, TImplementation>(client =>
    {
        client.BaseAddress = new Uri(baseUrl);
    })
    .ConfigureHttpClient((sp, client) =>
    {
        var options = sp.GetRequiredService<IOptionsSnapshot<HttpClientPoolOptions>>()
            .Get(configurationSection);
        client.Timeout = TimeSpan.FromSeconds(options.TimeoutSeconds);
    })
    .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler())
    .ConfigureHttpMessageHandlerBuilder(builder =>
    {
        if (builder.PrimaryHandler is SocketsHttpHandler handler)
        {
            var options = builder.Services.GetRequiredService<IOptionsSnapshot<HttpClientPoolOptions>>()
                .Get(configurationSection);
            handler.MaxConnectionsPerServer = options.MaxConnectionsPerServer;
            handler.PooledConnectionIdleTimeout = TimeSpan.FromSeconds(options.PooledConnectionIdleTimeoutSeconds);
            handler.PooledConnectionLifetime = TimeSpan.FromMinutes(options.PooledConnectionLifetimeMinutes);
        }
    })
    .AddTransientHttpErrorPolicy(policy =>
        policy.WaitAndRetryAsync(
            (sp) =>
            {
                var options = sp.GetRequiredService<IOptionsSnapshot<HttpClientPoolOptions>>()
                    .Get(configurationSection);
                return options.RetryCount;
            },
            (retryAttempt, sp) =>
            {
                var options = sp.GetRequiredService<IOptionsSnapshot<HttpClientPoolOptions>>()
                    .Get(configurationSection);
                return TimeSpan.FromMilliseconds(options.RetryBaseDelayMs * Math.Pow(2, retryAttempt));
            }));

    return services;
}
```

### Common Variants

**Variant 1 — gRPC channel with connection reuse.** gRPC uses HTTP/2 and a `GrpcChannel` that wraps `HttpClient`. The channel manages the HTTP/2 connection lifecycle. Multiple gRPC stubs can share a single channel (and thus a single HTTP/2 connection):

```csharp
// ✅ Right — singleton GrpcChannel with connection reuse
public sealed class PaymentGrpcClient
{
    private readonly PaymentService.PaymentServiceClient _client;

    public PaymentGrpcClient(GrpcChannel channel)
    {
        _client = new PaymentService.PaymentServiceClient(channel);
    }

    public async Task<ProcessPaymentResponse> ProcessPaymentAsync(
        ProcessPaymentRequest request, CancellationToken ct)
    {
        return await _client.ProcessPaymentAsync(request, deadline: DateTime.UtcNow.AddSeconds(5),
            cancellationToken: ct);
    }
}

// Registration in Program.cs:
var channel = GrpcChannel.ForAddress("https://payment-service.grpc.internal", new GrpcChannelOptions
{
    HttpHandler = new SocketsHttpHandler
    {
        EnableMultipleHttp2Connections = true,
        PooledConnectionLifetime = TimeSpan.FromMinutes(5),
        KeepAlivePingDelay = TimeSpan.FromSeconds(30),
        KeepAlivePingTimeout = TimeSpan.FromSeconds(10),
        MaxConnectionsPerServer = 5
    }
});
services.AddSingleton(channel);
services.AddTransient<PaymentGrpcClient>();
```

**Variant 2 — HTTP/1.1 + Keep-Alive with connection-per-host limit.** For services that do not support HTTP/2, HTTP/1.1 Keep-Alive maintains a connection pool per host. `MaxConnectionsPerServer` limits concurrency — essential when multiple downstream hosts share the same outbound IP and ephemeral port range:

```csharp
// ✅ Right — HTTP/1.1 with connection per host limit
builder.Services.AddHttpClient("inventory")
    .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
    {
        MaxConnectionsPerServer = 10, // 10 concurrent connections to inventory
        PooledConnectionIdleTimeout = TimeSpan.FromSeconds(60),
        PooledConnectionLifetime = TimeSpan.FromMinutes(5),
        EnableMultipleHttp2Connections = false // Force HTTP/1.1
    });
```

**Variant 3 — HttpClient as singleton (manual pool management).** For cases where `IHttpClientFactory` is not appropriate (lifelong singleton, static client for a known endpoint), manually configure the `SocketsHttpHandler` and reuse the `HttpClient`:

```csharp
// ✅ Right — singleton HttpClient with managed pool
public sealed class MetricsExporter : IDisposable
{
    private static readonly SocketsHttpHandler Handler = new()
    {
        MaxConnectionsPerServer = 5,
        PooledConnectionIdleTimeout = TimeSpan.FromSeconds(30),
        PooledConnectionLifetime = TimeSpan.FromMinutes(5)
    };

    private static readonly HttpClient Client = new(Handler)
    {
        BaseAddress = new Uri("https://metrics.internal"),
        Timeout = TimeSpan.FromSeconds(5)
    };

    public async Task ExportAsync(MetricBatch batch, CancellationToken ct)
    {
        var response = await Client.PostAsJsonAsync("/api/metrics", batch, ct);
        response.EnsureSuccessStatusCode();
    }

    public void Dispose()
    {
        Handler.Dispose();
        Client.Dispose();
    }
}
```

### Real-World .NET Ecosystem Example

**IHttpClientFactory + Polly + AKS microservices.** Microsoft's eShopOnContainers reference architecture demonstrates the standard pattern: each microservice registers typed `HttpClient` instances for downstream service calls. The `SocketsHttpHandler` is configured with `PooledConnectionLifetime` to handle DNS rotation in Kubernetes (services are recreated with new IPs during rolling updates). Polly's `WaitAndRetryAsync` handles transient failures. The handler lifetime (managed by `IHttpClientFactory`, default 2 minutes) ensures that DNS changes are picked up within 2 minutes even without `PooledConnectionLifetime`.

**Azure Functions + HTTP scaling.** Azure Functions that call external APIs suffer from ephemeral port exhaustion under high concurrency because each function instance creates and disposes HTTP connections. The fix: register `IHttpClientFactory` with `SocketsHttpHandler` in the Functions `Startup` class (which runs once per instance). The connection pool is shared across all invocations on that instance, reducing port churn from thousands of connections to a few dozen.

**Azure SDK clients as singletons.** The Azure SDK documentation explicitly states: "Azure SDK clients should be registered as singletons to reuse connections and sockets." Each SDK client (e.g., `BlobServiceClient`) creates its own `HttpClient` and connection pool. Instantiating a client per request creates a new pool per request — causing socket exhaustion. The fix: register `BlobServiceClient` as a singleton using `new BlobServiceClient(connectionString, new BlobClientOptions { Retry = { NetworkTimeout = TimeSpan.FromSeconds(10) } })`.

---

## Gotchas and Production Pitfalls

### HttpClient Disposed Prematurely in using Block

**Pitfall:** `HttpClient` is created inside a `using` block — it is disposed after each request, which closes the underlying `SocketsHttpHandler` and all its pooled connections. The next request creates a new handler and a new connection pool — paying the TCP + TLS cost every time.

```csharp
// ❌ Wrong — HttpClient disposed, connections closed, port churn
public async Task<OrderDto> GetOrderAsync(int id)
{
    using (var client = new HttpClient())
    {
        client.BaseAddress = new Uri("https://orders.internal");
        return await client.GetFromJsonAsync<OrderDto>($"/api/orders/{id}");
    }
} // HttpClient disposed → handler disposed → ALL pooled connections closed
// Next call: new socket, new TCP, new TLS
```

**Symptom:** High number of TIME_WAIT connections. `HttpClient` performance counters show high connection creation rate. Ephemeral port usage climbs with each request. CPU on the caller shows elevated sys time (kernel TCP stack).

**Fix:** Use `IHttpClientFactory` or a singleton `HttpClient`:

```csharp
// ✅ Right — HttpClient reused via IHttpClientFactory
public sealed class OrderServiceClient
{
    private readonly HttpClient _httpClient;

    public OrderServiceClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<OrderDto> GetOrderAsync(int id, CancellationToken ct)
    {
        return await _httpClient.GetFromJsonAsync<OrderDto>($"/api/orders/{id}", ct);
    }
}
```

**Cost of not fixing:** At 1,000 req/s with 100ms connection establishment, 100 seconds per second spent on connection overhead. Ephemeral ports exhausted in ~16 seconds (16,384 ports / 1,000 per second = 16 seconds). After port exhaustion, ALL outbound HTTP calls fail with socket errors. The application is effectively down for outgoing traffic.

### MaxConnectionsPerServer Too Low for Concurrent Requests

**Pitfall:** `MaxConnectionsPerServer` is set to a low value (e.g., 2) while the application makes 100 concurrent requests to the same endpoint. Requests queue behind the connection limit, increasing latency and causing timeouts.

```csharp
// ❌ Wrong — connection limit too low for concurrency
var handler = new SocketsHttpHandler
{
    MaxConnectionsPerServer = 2 // Only 2 concurrent connections
};
// 100 concurrent requests → 2 execute, 98 queue → P99 latency = timeout
```

**Symptom:** P99 latency to a downstream service is 10× the average. Downstream service CPU is low (it is not overloaded; the caller is self-throttling). `HttpClient` logs show `Request queueing` or connection wait times.

**Fix:** Set `MaxConnectionsPerServer` based on expected concurrency using the Little's Law formula: `concurrent = req/s × response_time`. At 1,000 req/s and 200ms p99: concurrent = 200. Set `MaxConnectionsPerServer = 200` or leave unlimited (`int.MaxValue`).

```csharp
// ✅ Right — connection limit matched to expected concurrency
var handler = new SocketsHttpHandler
{
    MaxConnectionsPerServer = 200
};
```

**Cost of not fixing:** The downstream service is idle but the caller cannot reach it. The bottleneck is the caller's connection limit, not the downstream service. The team investigates the downstream service (logs, CPU, memory) while the actual cause is a configuration issue on the caller.

### PooledConnectionLifetime Infinite Prevents DNS Rotation

**Pitfall:** `PooledConnectionLifetime = Timeout.InfiniteTimeSpan` (default). The TCP connection is held open indefinitely. DNS is resolved once at connection establishment. If the downstream service's IP changes (Kubernetes rolling update, DNS failover, blue-green deployment), the existing connection continues sending to the OLD IP — which may be decommissioned.

```csharp
// ❌ Wrong — connections never recycled, DNS stale forever
var handler = new SocketsHttpHandler
{
    PooledConnectionLifetime = Timeout.InfiniteTimeSpan // Default — BAD for Kubernetes
};
// Pod rolled at 10:00:00 — new IP at 10:00:05
// Existing connections still go to old Pod IP until connection fails
// Old Pod drains at 10:01:00 — connections start failing at 10:01:00
// DNS not re-resolved until connections die naturally (may take minutes)
```

**Symptom:** Intermittent `ConnectionRefused` or `ConnectionTimedOut` to a downstream service after a deployment. The error resolves when all old connections are naturally recycled (TIME_WAIT expiration, which can take minutes). The error pattern correlates exactly with downstream service deployments.

**Fix:** Always set `PooledConnectionLifetime` in Kubernetes environments:

```csharp
// ✅ Right — connections recycled every 2 minutes, DNS re-resolved
var handler = new SocketsHttpHandler
{
    PooledConnectionLifetime = TimeSpan.FromMinutes(2)
};
```

**Cost of not fixing:** Every deployment of the downstream service causes a partial outage for the caller. The caller's existing connections hit the decommissioned Pod, and new connections are only created when old ones fail. During the transition, 30–50% of requests may fail. The team learns to "wait 5 minutes after deployment for connections to settle" — accepting the failure as normal.

### HTTP/2 Connection Limit Not Configured for High Streams

**Pitfall:** HTTP/2 allows multiple concurrent streams over a single TCP connection. `EnableMultipleHttp2Connections` is `false` by default — all requests share ONE HTTP/2 connection. At high concurrency (100+ concurrent streams), HTTP/2 stream flow control and head-of-line blocking at the TCP level can increase latency. Additionally, if the single connection fails, ALL requests fail.

```csharp
// ❌ Wrong — single HTTP/2 connection, single point of failure
var handler = new SocketsHttpHandler
{
    EnableMultipleHttp2Connections = false // Default — all eggs in one basket
};
// 500 concurrent requests on 1 connection → stream contention
// Connection failure → 500 failed requests simultaneously
```

**Symptom:** Burst failures to a downstream service. All requests fail at the same timestamp. After reconnection, requests succeed again. The failure pattern shows periodic complete drops rather than gradual degradation.

**Fix:** Enable multiple HTTP/2 connections and set a reasonable per-connection stream limit:

```csharp
// ✅ Right — multiple HTTP/2 connections with keep-alive
var handler = new SocketsHttpHandler
{
    EnableMultipleHttp2Connections = true,
    MaxConnectionsPerServer = 4, // 4 HTTP/2 connections
    KeepAlivePingDelay = TimeSpan.FromSeconds(30),
    KeepAlivePingTimeout = TimeSpan.FromSeconds(10)
};
```

**Cost of not fixing:** A single HTTP/2 connection failure causes a complete outage to the downstream service. With HTTP/2 keep-alive pings disabled, a dead connection is not detected until the next request is sent — and the request fails. At 500 concurrent requests, all 500 fail before the connection is re-established.

### Socket Leak from Unobserved Task Exceptions

**Pitfall:** An `HttpClient.SendAsync()` call throws an exception (timeout, connection refused) that is not observed by the application code. The unobserved task exception finalizes the HTTP response, but the underlying `SocketsHttpHandler` does not immediately close the connection — it may be held in a "pending close" state until the finalizer runs (non-deterministic). Over time, these "zombie" connections accumulate.

```csharp
// ❌ Wrong — unobserved exception leaks connection
public async Task FireAndForgetRequest()
{
    _ = SendRequestAsync(); // Fire-and-forget — exception never observed
}

private async Task SendRequestAsync()
{
    using var client = new HttpClient();
    var response = await client.GetAsync("https://internal/api"); // May throw
    // If exception thrown above, the response is never disposed
    // Connection is not returned to pool; may leak
}
```

**Symptom:** Gradual increase in established connections even when request rate is constant. No connection pool timeout errors, but `ss -tnp` shows an increasing count of connections in `ESTABLISHED` or `CLOSE_WAIT` state. Eventually, ephemeral ports are exhausted.

**Fix:** Always observe and handle exceptions from HttpClient calls:

```csharp
// ✅ Right — exceptions observed, connections properly released
public async Task SafeFireAndForget()
{
    try
    {
        using var response = await _httpClient.GetAsync("/api/health");
        response.EnsureSuccessStatusCode();
    }
    catch (Exception ex)
    {
        _logger.LogWarning(ex, "Health check failed");
        // Connection is still returned to pool via response disposal
    }
}
```

**Cost of not fixing:** Zombie connections accumulate until port exhaustion. The application degrades over hours or days, not minutes — making the root cause hard to find. A weekly restart of the application "fixes" it, but the root cause is never addressed.

### CookieContainer Leaking State Across Requests

**Pitfall:** The default `SocketsHttpHandler` has a shared `CookieContainer`. When `HttpClient` sends a request to an endpoint, the response's `Set-Cookie` headers are stored in the container and sent on SUBSEQUENT requests to that endpoint — even if those requests are unrelated.

```csharp
// ❌ Wrong — shared cookie container leaks state
var handler = new SocketsHttpHandler
{
    UseCookies = true // Default — enables CookieContainer
};
var client = new HttpClient(handler);
// First request: authenticates and gets a session cookie
await client.GetAsync("https://api.internal/login?user=admin");
// Second request: sends the admin session cookie by accident!
var response = await client.GetAsync("https://api.internal/orders");
```

**Symptom:** Requests to an internal API include cookies that should not be present. Authentication headers from one request leak to another. Debugging shows unexpected `Cookie` header on requests.

**Fix:** Disable cookies unless explicitly needed:

```csharp
// ✅ Right — cookies disabled to prevent state leakage
var handler = new SocketsHttpHandler
{
    UseCookies = false, // No automatic cookie handling
    CookieContainer = null
};
```

**Cost of not fixing:** Accidental credential sharing between requests. A security auditor would flag this as a vulnerability. The application may impersonate users, call APIs with wrong authentication contexts, or expose session tokens in logs.

### HttpClient Created per Request in Azure Functions

**Pitfall:** In Azure Functions, creating `new HttpClient()` inside the function handler creates a new connection pool for EACH invocation. At high scale (thousands of concurrent executions), each Function instance creates thousands of connections, exhausting ephemeral ports.

```csharp
// ❌ Wrong — HttpClient created per Azure Function invocation
[FunctionName("ProcessOrder")]
public async Task<IActionResult> Run(
    [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequest req)
{
    using var client = new HttpClient(); // New pool created PER invocation
    var result = await client.GetStringAsync("https://payment.internal/health");
    return new OkResult();
}
```

**Symptom:** Azure Functions show `SocketException: Cannot assign requested address` after running for 5 minutes at high load. The Function host process has exhausted all ephemeral ports (default ~16,384 on Windows Functions).

**Fix:** Register `IHttpClientFactory` in the Functions `Startup` class:

```csharp
// ✅ Right — IHttpClientFactory in Azure Functions
[assembly: FunctionsStartup(typeof(Startup))]
public class Startup : FunctionsStartup
{
    public override void Configure(IFunctionsHostBuilder builder)
    {
        builder.Services.AddHttpClient("payment", client =>
        {
            client.BaseAddress = new Uri(Environment.GetEnvironmentVariable("PaymentServiceUrl"));
            client.Timeout = TimeSpan.FromSeconds(10);
        })
        .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
        {
            MaxConnectionsPerServer = 10,
            PooledConnectionIdleTimeout = TimeSpan.FromSeconds(60),
            PooledConnectionLifetime = TimeSpan.FromMinutes(5)
        });
    }
}
```

**Cost of not fixing:** The Function app fails after a few minutes of high load. The error is "Cannot assign requested address" — ephemeral port exhaustion. The fix (using `IHttpClientFactory`) is well-documented, but teams new to Azure Functions frequently miss it. The incident reproduces in production but not in local testing (low concurrency).

---

## Tradeoffs and Decision Framework

### Tradeoff Matrix

| Dimension | IHttpClientFactory + Pooled Handler | Singleton HttpClient | Raw HttpClient per Request |
|---|---|---|---|
| Connection reuse | YES — handler reused within its lifetime (default 2 min) | YES — handler reused for entire app lifetime | NO — new connection per request |
| DNS rotation | Handler lifetime limits DNS staleness (max 2 min) | Must set PooledConnectionLifetime | Handled naturally (new connection = new DNS) |
| Resource overhead | Low — handlers recycled, connections pooled | Lowest — one handler, one pool | HIGH — new socket per request, port exhaustion risk |
| Configuration flexibility | High — per-named-client configuration | Low — one handler config for all endpoints | None — using defaults only |
| Resilience integration | YES — AddTransientHttpErrorPolicy built-in | Manual Polly wrapping | Must implement per call |
| Cookie isolation | Per named client — automatic | Shared CookieContainer across all requests | Per request — no cookie leakage |
| Best for | Microservices with multiple downstream endpoints | Single downstream API with known lifetime | Scripts, CLI tools, or serverless with <10 req/min |

### When to Apply

```mermaid
flowchart TD
    A[Need to make HTTP calls from .NET] --> B{Call volume?}
    B -->|<100 req/min| C[new HttpClient() is acceptable<br/>Low port churn risk]
    B -->|100-10,000 req/min| D[IHttpClientFactory with typed clients<br/>Configure MaxConnectionsPerServer]
    B -->|>10,000 req/min| E[IHttpClientFactory + SocketsHttpHandler tuning<br/>+ multiple HTTP/2 connections]
    
    C --> F{Kubernetes environment?}
    D --> F
    E --> F
    F -->|Yes| G[Set PooledConnectionLifetime<br/>2-5 minutes for DNS rotation]
    F -->|No| H[PooledConnectionLifetime is optional<br/>IdleTimeout is sufficient]
    
    G --> I{Downstream supports HTTP/2?}
    H --> I
    I -->|Yes| J[EnableMultipleHttp2Connections = true<br/>KeepAlivePingDelay = 30s]
    I -->|No| K[HTTP/1.1 Keep-Alive<br/>MaxConnectionsPerServer = concurrent]
    
    J --> L{Polly needed?}
    K --> L
    L -->|Yes| M[AddTransientHttpErrorPolicy<br/>Retry + Circuit Breaker]
    L -->|No| N[Standard pool config is adequate]
```

### When NOT to Apply

- [ ] **Below 100 requests per minute to any single downstream.** The TCP/TLS handshake cost is negligible at this rate (~$0.00001 in compute time per request). Using `IHttpClientFactory` adds unnecessary abstraction. Use `new HttpClient()` and accept the per-request connection cost.
- [ ] **In-memory loopback calls (same process).** If the HTTP call is to a loopback address in the same process, connection pooling adds overhead without benefit. Use direct method calls or an in-process message bus.
- [ ] **WebSocket or long-poll connections.** `SocketsHttpHandler` pooling is designed for short-lived HTTP request-response cycles. WebSocket connections are held open indefinitely and should be managed separately (not through the connection pool). Use `ClientWebSocket` directly.
- [ ] **HTTP/2 server-push or streaming.** HTTP/2 server-push and gRPC streaming maintain long-lived streams that are not suited to the connection pool's idle-timeout eviction. Configure `PooledConnectionIdleTimeout` to a value that accommodates the streaming interval.
- [ ] **Environment with strict outbound firewall rules that limit connection rates.** Some enterprise firewalls limit the number of new outbound TCP connections per second (e.g., 100 connections/second). Connection pooling reduces new connection creation, but if the pool is too small, every request creates a new connection. In this environment, set `MaxConnectionsPerServer` high enough to reuse connections aggressively, and monitor the firewall's connection rate limit.
- [ ] **Service mesh with sidecar (Istio, Linkerd).** The sidecar Envoy proxy already manages its own connection pool to downstream services. The application's HTTP pooling should be set to connect to the sidecar (loopback) with minimal pooling — the sidecar handles the actual multiplexing. Setting aggressive application-level pooling can conflict with the sidecar's connection management.
- [ ] **Synchronous blocking calls on legacy ASP.NET.** In ASP.NET Full Framework with synchronous controllers, using a singleton `HttpClient` with connection pooling can lead to thread pool starvation because threads block waiting for connections that are held by other threads. The fix is to use async/await, not to disable pooling.
- [ ] **Extremely short-lived environments (Azure Functions Consumption Plan on Linux with >5 min cold start).** Each cold start creates a new connection pool. The pool is discarded when the Function host is recycled (after ~20 minutes of inactivity). For extremely bursty Functions (<1 request per minute), the pool is constantly recreated, and the savings from pooling are negligible. Still prefer `IHttpClientFactory` to avoid socket exhaustion, but configure `MaxConnectionsPerServer = ` with conservative values.

### Scale Thresholds

- **TCP handshake (Azure internal):** ~15ms. At 5,000 req/s: 75 seconds per second of overhead (needs pooling).
- **TCP + TLS handshake (Azure internal):** ~35ms. At 5,000 req/s: 175 seconds per second of overhead (pooling essential).
- **Default PooledConnectionIdleTimeout:** 100 seconds. Below 30 seconds, connections are recycled too aggressively — the pool never has warm connections for burst traffic. Above 300 seconds, connections may be terminated by intermediate load balancers (Azure LB default idle timeout: 4 minutes).
- **Default handler lifetime (IHttpClientFactory):** 2 minutes. This is the lifespan of the `SocketsHttpHandler` itself (not individual connections). When the handler is recycled, ALL its connections are closed. For Kubernetes with frequent DNS changes, keep this at 2 minutes or lower. For stable environments, increase to 10 minutes to reduce connection churn.
- **Ephemeral port exhaustion threshold:** ~2,000 concurrent outbound connections (Windows). Above this, monitor ephemeral port usage. At 10,000+ concurrent, use HTTP/2 multiplexing (which reduces the connection count by ~50×) or deploy multiple instances.
- **HTTP/2 multiplexing benefit:** Above ~100 concurrent requests per endpoint. Below this, HTTP/1.1 connections are sufficient. Above this, HTTP/2 reduces the number of TCP connections from `concurrent` to `sqrt(concurrent)` (empirical, depends on stream flow control).
- **IHttpClientFactory benefit threshold:** >500 requests per hour. Below this, raw `new HttpClient()` is simpler and does not cause port exhaustion. Above this, the connection and port savings justify the abstraction.
- **Azure Functions connection pooling threshold:** >10 requests per minute per Function instance. Functions idle for >20 minutes lose their pool (process recycled). For Functions with intermittent traffic, keep `PooledConnectionIdleTimeout` low (30s) to avoid holding ports during idle periods.

---

## Interview Arsenal

### Question Bank

1. [Definition] Why is `new HttpClient()` inside a `using` block considered harmful in .NET?
2. [Mechanism] How does `IHttpClientFactory` manage the lifecycle of HTTP connections? Walk through a request.
3. [Tradeoff] Compare HTTP/1.1 connection pooling with HTTP/2 multiplexing. When does each win?
4. [Failure mode] A microservice on AKS calls another service. After a rolling update of the downstream service, 30% of requests fail with `ConnectionRefused`. What is the cause?
5. [Design application] Design the HTTP connection strategy for a .NET API on AKS that calls 5 downstream services at 5,000 req/s each.
6. [Scale] An e-commerce site on AKS with 50 Pods makes outbound calls to an external payment gateway. After 10 minutes of Black Friday traffic, all outbound calls fail with `SocketException: Cannot assign requested address`. What went wrong?
7. [Advanced] Explain the interaction between `SocketsHttpHandler.PooledConnectionLifetime`, DNS resolution, and Kubernetes Service IP changes during a rolling update.
8. [Advanced] A gRPC service experiences periodic complete dropouts — all RPCs fail simultaneously for 5 seconds, then recover. What is the cause and how do you fix it?

### Spoken Answers

**Q1: Why is `new HttpClient()` inside a `using` block considered harmful in .NET?**

> **Average answer:** Because `HttpClient` should be reused. Creating a new one for each request wastes resources.

> **Great answer:** `HttpClient` is designed to be reused for the lifetime of the application. Each `HttpClient` wraps a `SocketsHttpHandler` that manages a connection pool. When you write `using (var client = new HttpClient())`, you dispose the handler after a single request — closing ALL pooled connections. The next request creates a new handler, resolves DNS again, and performs a full TCP + TLS handshake (15–50ms overhead). At 1,000 requests per second, that is 15–50 seconds of overhead per second. Worse, each new connection consumes an ephemeral port on the caller. Windows has approximately 16,384 ephemeral ports by default (16384–65535). At 1,000 connections per second, ports are exhausted in 16 seconds. After that, ALL outbound connections fail with `SocketException: Only one usage of each socket address is normally permitted`. The correct approach is `IHttpClientFactory`, which reuses the `SocketsHttpHandler` (and its connection pool) across requests. The factory creates a new `HttpClient` instance (cheap — it is a thin wrapper), but the underlying handler is recycled only every 2 minutes by default. This gives you connection reuse, DNS re-resolution every handler lifetime, and automatic pool management without port exhaustion.

**Q2: How does IHttpClientFactory manage the lifecycle of HTTP connections?**

> **Great answer:** `IHttpClientFactory` manages two layers: the `HttpMessageHandler` (the `SocketsHttpHandler` that owns the connection pool) and the `HttpClient` (the thin wrapper). The handler has a configurable lifetime (default 2 minutes, via `HandlerLifetime`). Within that lifetime, the handler's connection pool maintains connections to downstream servers. Idle connections are evicted after `PooledConnectionIdleTimeout` (default 100 seconds). Active connections are kept until the handler is recycled. When the handler lifetime expires, the handler is marked for disposal — existing in-flight requests complete gracefully, but new requests get a new handler (and a fresh connection pool). This two-layer design solves the three problems of raw `HttpClient`: connection pooling (the pool lives in the handler, not the client), DNS rotation (the handler is recycled periodically, forcing DNS re-resolution), and port exhaustion (connections are reused, not created per request). Each named/typed client has its own handler pool, isolated from other clients. The factory uses a `ConcurrentDictionary` of handler buckets, keyed by the client name, and a timer that expires handlers after their lifetime.

**Q3: Compare HTTP/1.1 connection pooling with HTTP/2 multiplexing.**

> **Great answer:** HTTP/1.1 uses one TCP connection per concurrent request. With connection pooling, idle connections are kept alive in the pool, but each active request holds an entire TCP connection. At 100 concurrent requests to the same server, HTTP/1.1 needs 100 TCP connections, consuming 100 ephemeral ports and 100 file descriptors on both sides. HTTP/2 multiplexes multiple concurrent requests as streams over a SINGLE TCP connection. Streams are lightweight (frames on the wire) and share the connection. At 100 concurrent requests, HTTP/2 uses 1 TCP connection (or 2–4 if multiple connections are enabled) — a 25–50× reduction in connection count. The tradeoff: HTTP/2 has head-of-line blocking at the TCP level (a lost packet blocks ALL streams), requires TLS, and has more complex flow control (stream-level vs connection-level WINDOW_UPDATE). .NET's `SocketsHttpHandler` supports HTTP/2 with `EnableMultipleHttp2Connections` (default false — one connection only). At high concurrency (>100 streams), enable multiple connections: 2–4 connections distribute the stream load and mitigate the TCP head-of-line blocking problem. HTTP/2 wins when you have high concurrency to a single server. HTTP/1.1 with pooling is sufficient for low concurrency (<10 concurrent requests) or when the server does not support HTTP/2.

**Q4: After a rolling update of a downstream Kubernetes service, 30% of requests fail with ConnectionRefused. What is the cause and fix?**

> **Great answer:** This is the classic DNS staleness + connection pooling failure. The downstream service was deployed via a rolling update — new Pods with new IPs replace old Pods. The caller's `SocketsHttpHandler` has `PooledConnectionLifetime = Timeout.InfiniteTimeSpan` (default). The pooled TCP connections were established to the OLD Pod IPs. When the old Pods are terminated, those connections receive a TCP RST (or the connection hangs until keep-alive times out). The caller's pooled connection fails with `ConnectionRefused`. But new connections should be created to the new Pod IP. The problem: DNS was cached at connection establishment time. The connection pool returns the FAILED connection to the pool (thinking it is valid), and the next request also tries the dead connection. The 30% failure rate corresponds to the ratio of connections that were to soon-to-be-terminated Pods. The fix: set `PooledConnectionLifetime` to a value shorter than the deployment window (e.g., 2 minutes). This forces the handler to re-resolve DNS and create new connections periodically. Combined with `IHttpClientFactory`'s default handler lifetime of 2 minutes, DNS changes are picked up within 2 minutes of the deployment completing. The deeper fix: use a Service mesh (Istio, Linkerd) that manages connections at the sidecar level and handles connection draining during rollouts transparently.

---

### System Design Interview Trigger

If an interviewer asks you to design a microservice architecture and says "how do services communicate?" or "what happens when a downstream service is deployed?" or "how do you prevent socket exhaustion?", they are testing whether you understand HTTP connection pooling as a fundamental scalability concern. The specific probe "should HttpClient be a singleton or created per request?" is the classic .NET interview question that separates junior from senior engineers. The interviewer wants to see that you know: (a) `HttpClient` creates a new connection pool per instance, (b) `IHttpClientFactory` solves the disposal problem by recycling handlers, (c) `PooledConnectionLifetime` controls DNS staleness, (d) ephemeral port exhaustion is the consequence of not pooling, and (e) HTTP/2 multiplexing reduces connection count by 50× at high concurrency. The follow-up "how do you handle a downstream service that takes 30 seconds to respond?" tests whether you know that long-lived requests hold connections hostage, and the fix is `MaxConnectionsPerServer` + separate connection pools for different latency profiles.

### Comparison Table

| | HTTP/1.1 Pooling | HTTP/2 Multiplexing | gRPC Channel |
|---|---|---|---|
| Connections per N requests | N connections | 1–4 connections | 1–4 connections |
| Concurrent requests per connection | 1 (sequential) | 100 streams (configurable) | 100 streams (configurable) |
| Connection establishment | TCP + TLS per connection | TCP + TLS once (upgraded via ALPN) | TCP + TLS once (HTTP/2 required) |
| DNS staleness | Per-connection lifetime | Per-connection lifetime | Per-channel lifetime (configurable) |
| Best for | Low concurrency, simple REST | High concurrency, single endpoint | Streaming, bidirectional, low-latency RPC |
| .NET configuration | SocketsHttpHandler | SocketsHttpHandler.EnableMultipleHttp2Connections | GrpcChannelOptions.HttpHandler |
| Downstream requirement | HTTP/1.1 (universal) | TLS + h2 ALPN | HTTP/2 (TLS required for grpc-dotnet) |

---

## Architecture Decision Record

**Status:** Accepted under condition of `PooledConnectionLifetime` and `HandlerLifetime` configuration review.

**Context:** Our .NET microservice on AKS calls two downstream services: `PaymentService` (50 ms p99, 2,000 req/s, HTTP/2-capable, deployed via rolling updates every 2 weeks) and `NotificationService` (500 ms p99, 200 req/s, HTTP/1.1, deployed via blue-green every month). The application runs on 20 Pods. We experienced a 15-minute incident last month where a `PaymentService` deployment caused 30% of payment requests to fail with `ConnectionRefused` for 3 minutes.

**Options Considered:**

1. **Default IHttpClientFactory configuration (handler lifetime 2 min, PooledConnectionLifetime infinite).** Uses the out-of-the-box setup. The 2-minute handler lifetime limits DNS staleness to 2 minutes — acceptable for the monthly delivery window. But `PooledConnectionLifetime = infinite` means individual connections within the handler are never recycled by age. If the handler itself is replaced every 2 minutes, the connections inside it eventually die with the handler — so the DNS staleness is bounded by handler lifetime. However, a handler that is actively serving requests (the factory does not recycle a handler with in-flight requests) may live longer than 2 minutes under load. At 2,000 req/s, the handler always has in-flight requests and may survive for 10+ minutes. During a deployment at minute 8, the handler is 8 minutes old, and all its connections point to old Pod IPs — causing the ConnectionRefused failures we saw.

2. **SocketsHttpHandler with explicit PooledConnectionLifetime.** Set `PooledConnectionLifetime = 120s` on the SocketsHttpHandler. This ensures that even if the handler lives longer than 2 minutes, individual connections are recycled within 120 seconds. Combined with handler lifetime of 2 minutes, the maximum DNS staleness is 2 minutes (handler replacement) OR 120 seconds (connection replacement) — whichever is shorter. This eliminates the ConnectionRefused window during deployments.

3. **HTTP/2 with EnableMultipleHttp2Connections and keep-alive pings.** For `PaymentService` (HTTP/2-capable), use HTTP/2 with multiple connections. HTTP/2 connections also need `PooledConnectionLifetime` for DNS rotation — HTTP/2 does not solve the DNS staleness problem. The advantage is reduced connection count (4 connections instead of 20) and proactive dead connection detection via `KeepAlivePingDelay`.

**Decision:** Option 2 + Option 3 combined. For `PaymentService` (HTTP/2): enable `EnableMultipleHttp2Connections = true`, `MaxConnectionsPerServer = 4`, `PooledConnectionLifetime = 120s`, `KeepAlivePingDelay = 30s`, `KeepAlivePingTimeout = 10s`. For `NotificationService` (HTTP/1.1): `MaxConnectionsPerServer = 20` (matches concurrent requests: 200 req/s × 500ms = 100 concurrent, headroom to 20 connections), `PooledConnectionLifetime = 120s`. Both use `IHttpClientFactory` with default handler lifetime of 2 minutes.

**Consequences:**
- ✅ DNS staleness bounded to 120 seconds (connections) or 2 minutes (handler) — whichever recycles first. Future deployments have a maximum 2-minute disruption window instead of indefinite.
- ✅ HTTP/2 for PaymentService reduces connection count from 20 to 4, freeing ephemeral ports for other services
- ✅ Keep-alive pings detect dead HTTP/2 connections within 40 seconds (30s delay + 10s timeout), minimizing the burst failure window
- ⚠️ Connections recycled every 120 seconds create ~1,200 new connections per hour per connection to PaymentService (4 connections × 30 recycles/hour). At 20 Pods: 80 connections/hour to PaymentService + higher to NotificationService. The database is not involved, so the overhead is on the caller and PaymentService's TLS termination — negligible.
- ⚠️ HTTP/2 configuration adds complexity: must verify that the downstream's ingress/gateway supports HTTP/2 and that ALPN negotiation succeeds

**Review Trigger:** Revisit this decision if (a) `PaymentService` deployment frequency increases above once per week (120s connection lifetime becomes a bottleneck — more connections being recycled than used), (b) the average request latency to `PaymentService` drops below 5ms (connection recycling overhead becomes significant relative to request time), or (c) we migrate to a service mesh (sidecar handles connection pooling and DNS resolution transparently, making application-level pooling redundant).

---

## Self-Check

### Conceptual Questions

<details>
<summary>1. Why is `new HttpClient()` inside a `using` block harmful?</summary>

It creates a new `SocketsHttpHandler` (connection pool) per request, disposes it after the request, and forces the next request to create a new TCP + TLS connection. At scale, this exhausts ephemeral ports (~16,384 on Windows) within seconds to minutes, causing all outbound HTTP calls to fail with socket errors.
</details>

<details>
<summary>2. How does IHttpClientFactory solve the HttpClient disposal problem?</summary>

It separates the `HttpClient` (thin wrapper, cheap to create) from the `SocketsHttpHandler` (owns the connection pool, expensive to create). The handler is cached and recycled on a timer (default 2 minutes). `HttpClient` instances are created per request but share the same handler pool. This gives connection reuse, DNS re-resolution on handler recycle, and automatic pool management.
</details>

<details>
<summary>3. What happens when PooledConnectionLifetime is set to 120 seconds in Kubernetes?</summary>

Each TCP connection is recycled 120 seconds after creation. DNS is re-resolved when a new connection is created. This means DNS changes (Kubernetes Service IP updates during rolling deployments) are picked up within 120 seconds. Without this setting (default infinite), connections point to old Pod IPs indefinitely, causing ConnectionRefused during deployments.
</details>

<details>
<summary>4. What is the difference between `IHttpClientFactory` handler lifetime and `PooledConnectionLifetime`?</summary>

Handler lifetime (default 2 min) controls how long the `SocketsHttpHandler` itself lives. When it expires, the handler is disposed — ALL connections within it are closed. `PooledConnectionLifetime` (default infinite) controls how long each individual TCP connection lives within the handler. A connection can be recycled (closed and a new one created) within the handler's lifetime. Handler lifetime = hard upper bound on connection age. PooledConnectionLifetime = soft per-connection recycle timer.
</details>

<details>
<summary>5. How does HTTP/2 reduce the need for connection pooling?</summary>

HTTP/2 multiplexes multiple concurrent requests as streams over a single TCP connection. At 100 concurrent requests, HTTP/2 uses 1 connection instead of 100. Fewer connections means less ephemeral port consumption, fewer file descriptors, and less connection establishment overhead. However, HTTP/2 connections still need `PooledConnectionLifetime` for DNS rotation — and the consequence of a single connection failure is more severe (all 100 requests fail).
</details>

<details>
<summary>6. What causes the "Cannot assign requested address" socket error in high-throughput HTTP callers?</summary>

Ephemeral port exhaustion. Each outbound TCP connection consumes one ephemeral port on the caller. When all ports in the dynamic range (default 16,384 ports on Windows) are in TIME_WAIT or ESTABLISHED state, new connections cannot be created. The fix: reuse connections via pooling (reduces connection creation rate) or reduce TIME_WAIT duration.
</details>

<details>
<summary>7. How does the cookie container in SocketsHttpHandler cause state leakage?</summary>

The default `SocketsHttpHandler` has a shared `CookieContainer`. Responses with `Set-Cookie` headers store cookies that are sent on subsequent requests to the same endpoint. If one request authenticates and gets a session cookie, all subsequent requests from the same `HttpClient` send that cookie. This leaks authentication context across requests. Fix: set `UseCookies = false`.
</details>

<details>
<summary>8. Compare HTTP connection pooling with SQL connection pooling. What is the key structural difference?</summary>

SQL pooling keys on the exact connection string — each unique connection string creates a separate pool. HTTP pooling keys on the endpoint `(scheme, host, port)` — all requests to the same URL share the same pool. SQL pooling uses `Connection Lifetime` (age-based recycling) while HTTP pooling uses both `PooledConnectionLifetime` (age-based) AND `PooledConnectionIdleTimeout` (idle-based). SQL pool has `MaxPoolSize` per pool (hard limit); HTTP pool has `MaxConnectionsPerServer` (default unlimited).
</details>

<details>
<summary>9. What happens to in-flight requests when the IHttpClientFactory handler is recycled?</summary>

The factory does NOT recycle a handler that has in-flight requests. When the handler lifetime expires, the handler is marked as "pending recycle." New requests get a new handler. The old handler continues processing its in-flight requests. When the last in-flight request completes, the handler's connection pool is drained and the handler is disposed. This ensures zero in-flight request disruption during handler rotation.
</details>

<details>
<summary>10. Explain HTTP connection pooling's role in scaling .NET microservices in 60 seconds.</summary>

"HTTP connection pooling reuses TCP connections to downstream services, eliminating the 15–50ms handshake overhead per request and preventing ephemeral port exhaustion. The default .NET approach is `IHttpClientFactory` with typed clients — each client gets a pooled `SocketsHttpHandler` that is recycled every 2 minutes. The key configuration: set `PooledConnectionLifetime` to 2–5 minutes so DNS changes from Kubernetes deployments are picked up within that window. Set `MaxConnectionsPerServer` to match your concurrent request volume. For high concurrency, enable HTTP/2 multiplexing — 1 connection serves 100 concurrent requests instead of 100. The three failure modes to monitor: socket exhaustion (too many connections), DNS staleness (connections pinned to old IPs), and connection starvation (MaxConnectionsPerServer too low)."
</details>

<details>
<summary>11. What is the role of `HandlerLifetime` in IHttpClientFactory and when should you change it?</summary>

`HandlerLifetime` (default 2 minutes) controls how long the `SocketsHttpHandler` is cached before being recycled. Increase it (to 10–30 minutes) in stable environments where DNS rarely changes — reduces connection churn. Decrease it (to 30–60 seconds) in environments with frequent DNS changes (fast-paced Kubernetes deployments, spot-instance replacement). The tradeoff: shorter lifetime = faster DNS rotation but more connection establishment overhead.
</details>

<details>
<summary>12. How does a service mesh sidecar (Istio, Linkerd) interact with application-level HTTP connection pooling?</summary>

In a service mesh, the application connects to a local sidecar proxy (loopback). The sidecar manages connections to downstream services. Application-level pooling should be minimal — connect to the sidecar per request or with a small pool. The sidecar's Envoy proxy handles the actual multiplexing, DNS resolution, and connection pooling to downstream services. Setting aggressive application-level pooling (e.g., `MaxConnectionsPerServer = 100`) can conflict with the sidecar's circuit breakers and connection limits. The recommended pattern: `MaxConnectionsPerServer = 10` and `PooledConnectionLifetime = 60s` for the application-to-sidecar connection.
</details>

<details>
<summary>13. What metrics should you monitor for HTTP connection pool health?</summary>

Four metrics. (1) `http.client.connections.current` (OpenTelemetry) — total established connections. Rapid growth indicates leak or missing pool. (2) `http.client.connections.duration` — connection age distribution. If most connections are younger than `PooledConnectionLifetime`, the recycle is working. (3) `http.client.request.duration` — p50 vs p99 divergence indicates queueing at the connection limit (p99 high when connections are saturated). (4) Ephemeral port usage — `cat /proc/net/sockstat` (Linux) or `Get-NetTCPConnection` (Windows) — alert when usage exceeds 80% of the dynamic range.
</details>

<details>
<summary>14. Can `MaxConnectionsPerServer` cause a deadlock? How?</summary>

Yes, if the application uses synchronous blocking calls (`Task.Result`, `Task.Wait()`) and the connection limit is low. Example: Thread A calls downstream service and blocks (`.Result`) waiting for the response. Thread B also calls the same downstream service. Thread B's request needs a connection, but all connections are held by Thread A (blocked). Thread A's response cannot arrive because the network stack cannot receive it (thread is blocked). This is a classic deadlock: thread pool exhaustion + connection pool exhaustion. The fix: always use async/await with HTTP calls.
</details>

<details>
<summary>15. What is the effect of setting `PooledConnectionIdleTimeout` too low?</summary>

Connections are evicted from the pool too aggressively. The pool never has "warm" connections for burst traffic. Every burst creates new connections (paying the TCP + TLS cost). At high burst frequency, the system behaves almost as if pooling is disabled — high connection overhead and potential port exhaustion. The default 100 seconds is reasonable. Reduce only if the downstream load balancer has a shorter idle timeout (e.g., Azure LB default is 4 minutes, so 100s is safe).
</details>

### Scenario Challenges

**Scenario 1 — Diagnose the problem**

A .NET 8 API on AKS (30 Pods) calls an external payment gateway at 3,000 req/s. After 15 minutes of peak traffic, all outbound calls fail with `HttpRequestException: A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond.`

<details>
<summary>Diagnosis</summary>

**Root cause:** Ephemeral port exhaustion. The application creates a new `HttpClient` per request (or uses a very short `PooledConnectionIdleTimeout`). At 3,000 req/s, 3,000 new connections are created per second. The default ephemeral port range on Linux in AKS is 32,768–60,999 (28,232 ports). At 3,000 ports/second, the range is exhausted in ~9 seconds. After exhaustion, all new connection attempts fail — even to OTHER external services, because the entire port range is consumed.

**Evidence:** `ss -s` shows `TIME-WAIT: 28000`. `cat /proc/sys/net/ipv4/ip_local_port_range` shows `32768 60999`. Application logs show `SocketException (99): Cannot assign requested address`. Performance counters show `http.client.connections.current` at 0 (connections are immediately closed, not pooled).

**Fix:** Use `IHttpClientFactory` with `SocketsHttpHandler` and connection pooling. Set `MaxConnectionsPerServer = 50` (prevents unlimited connections to the payment gateway). Set `PooledConnectionIdleTimeout = 60s` (recycles idle connections rather than closing them). Reduce TIME_WAIT: `sysctl -w net.ipv4.tcp_tw_reuse=1`.

**Prevention:** Monitor ephemeral port usage with a Prometheus alert: `node_netstat_Tcp_CurrEstab > 10000` or `(node_netstat_Tcp_ActiveOpens - node_netstat_Tcp_PassiveOpens) rate[5m] > 1000`. Use `IHttpClientFactory` as a standard pattern in all service-to-service communication.
</details>

**Scenario 2 — Design decision**

Design the HTTP connection strategy for a .NET API that calls 3 downstream services: Auth (10 ms, 5,000 req/s), Inventory (200 ms, 500 req/s), and Reports (30,000 ms/30s, 10 req/s). All services run on the same AKS cluster.

<details>
<summary>Decision and Reasoning</summary>

**Choice:** Separate typed `HttpClient` per downstream service with different `SocketsHttpHandler` configurations. The three services have radically different latency profiles — a shared `HttpClient` would have conflicting configuration requirements.

**Why separate clients:** Auth needs high concurrency (5,000 req/s × 10ms = 50 concurrent). Inventory needs moderate concurrency (500 × 200ms = 100 concurrent). Reports needs VERY few connections (10 × 30s = 300 concurrent, but each holds the connection for 30 seconds — requiring dedicated connections). A shared `MaxConnectionsPerServer` of 100 would starve Reports (needs 300 connections) while over-allocating to Auth.

**For Auth (5,000 req/s, 10ms p99):** HTTP/2 multiplexing. `MaxConnectionsPerServer = 4`, `EnableMultipleHttp2Connections = true`. At 10ms per request, a single HTTP/2 connection can handle ~100 streams = 10,000 req/s. 4 connections provide 4× headroom. `PooledConnectionLifetime = 300s` (5 min — Auth is deployed via blue-green, not rolling, so DNS changes are infrequent).

**For Inventory (500 req/s, 200ms p99):** HTTP/1.1 pooling. `MaxConnectionsPerServer = 100` (500 × 0.2 = 100 concurrent). `PooledConnectionLifetime = 120s` (rolling updates for Inventory every 2 weeks).

**For Reports (10 req/s, 30s p99):** HTTP/1.1 with dedicated connections. `MaxConnectionsPerServer = 15` (10 × 30 = 300 concurrent, but the caller only makes 10 req/s — some must be serialized. Actually: at 10 req/s and 30s each, the caller needs 300 concurrent connections to avoid queueing. But at 10 req/s, the caller is not throughput-constrained. Set `MaxConnectionsPerServer = 10` — the 10 requests each hold a connection for 30 seconds. The 11th request queues behind the 30-second connection hold. Acceptable at 10 req/s. If the user needs faster response, the fix is to optimize the Reports query, not the connection pool.)
</details>

**Scenario 3 — Failure mode**

Your microservice calls an internal API via HTTPS. The certificate was renewed last night. This morning, 100% of calls to that API fail with `AuthenticationException: The remote certificate is invalid according to the validation procedure.` The API serves other callers without issue.

<details>
<summary>Investigation and Fix</summary>

**Investigation steps:** (1) Check the error: `AuthenticationException` — TLS certificate validation failure. (2) Check the certificate on the API: `openssl s_client -connect api.internal:443` — shows a valid certificate issued by the new CA. (3) Check the caller's certificate trust store: the new CA root certificate is not in the caller's trust store. (4) Check why it was working before: the old certificate was issued by a CA that WAS in the trust store. The pooled TLS session was cached — the handshake was not revalidating the certificate on reused connections. When the connection was recycled (after `PooledConnectionLifetime`), the new handshake validated the new certificate and failed.

**Root cause:** The connection pool cached the TLS session from the old certificate. When the connection was recycled, the new TLS handshake validated the new certificate against the caller's trust store — and failed because the new CA was not trusted. The issue only appeared after ALL old connections were recycled (which took `PooledConnectionLifetime` seconds after the deployment).

**Fix:** Add the new CA certificate to the caller's trust store. If using Azure, add the certificate to the Application's `WEBSITE_LOAD_CERTIFICATES` or container's certificate store. After adding the certificate, clear the connection pool: `HttpClient` instances need to be recycled (new handler lifetime) for the new certificate to be loaded.

**Prevention:** Use `PooledConnectionLifetime` to limit TLS session cache duration — even if the certificate changes, the new handshake happens within the lifetime window. Monitor certificate expiration and add new CA certificates before they are needed.
</details>

**Scenario 4 — Scale it**

Your .NET API makes 10,000 req/s to a downstream service. Currently, each request creates a new connection (no pooling). You have 20 Pods. The downstream service has a connection limit of 500. Design the HTTP connection pooling strategy.

<details>
<summary>Scaling Strategy</summary>

**Bottleneck this addresses:** The downstream service limits concurrent connections to 500. At 10,000 req/s without pooling, the caller creates 10,000 connections/second — all rejected after the first 500. Even WITH pooling, 20 Pods × 25 connections each = 500 — at the limit. We need to reduce the number of connections per Pod while still handling 10,000 req/s.

**The math:** 10,000 req/s at 50ms average response time = 500 concurrent requests (Little's Law). The downstream service has a 500-connection limit. We are exactly at the limit. Every Pod must share the 500 connections fairly: `MaxConnectionsPerServer per Pod = 500 / 20 = 25`.

**HTTP/2 solution:** Enable HTTP/2 multiplexing. A single HTTP/2 connection can handle ~100 concurrent streams. With `EnableMultipleHttp2Connections = true` and `MaxConnectionsPerServer = 5`, each Pod uses 5 connections × 100 streams = 500 concurrent requests — but limited by the downstream service's 500 connection limit. Wait — HTTP/2 does not reduce the downstream's connection count. The downstream sees 5 connections from each Pod × 20 Pods = 100 connections — well under the 500 limit. The 100 connections carry 10,000 req/s via multiplexing.

**Implementation:** Set `EnableMultipleHttp2Connections = true`, `MaxConnectionsPerServer = 5`. The downstream service must support HTTP/2 (TLS with h2 ALPN). If it does not, use HTTP/1.1 with `MaxConnectionsPerServer = 25` per Pod and monitor for connection saturation.

**What it does not solve:** The downstream service's connection limit of 500. Even with HTTP/2, the downstream service may count each TCP connection (not each stream) against its 500 limit. In that case, 20 Pods × 5 connections = 100 — safe. If the downstream counts streams as connections (misconfigured), we have a problem. Verify with the downstream team.
</details>

**Scenario 5 — Interview simulation**

The interviewer says: "Design a .NET service that sends 100,000 push notifications per second via HTTP to an external provider. The provider supports HTTP/2 and limits you to 10 concurrent connections."

<details>
<summary>Model Response</summary>

"At 100,000 push notifications per second on 10 concurrent connections, each connection must handle 10,000 notifications per second. HTTP/2 multiplexing is essential — HTTP/1.1 would need 100,000 connections.

For the connection configuration: I enable HTTP/2 with `EnableMultipleHttp2Connections = true` and `MaxConnectionsPerServer = 10` (matching the provider's limit). Each connection multiplexes 10,000 notifications per second as HTTP/2 streams. At 10ms per notification (provider processing time), each stream lasts 10ms. 10,000 streams per second × 10ms = 100 concurrent streams per connection at any moment — well within HTTP/2's default 100-stream limit. If the provider supports more, I set `http2.MaxStreamsPerConnection` to 200.

For the .NET implementation, I need to manage backpressure. 100,000 notifications per second cannot all be `SendAsync` simultaneously — the HTTP/2 stream limit would be exceeded, and the `HttpClient` would queue them. I implement a producer-consumer pattern with a `Channel<Notification>` and 10 concurrent consumers (matching the 10 connections). Each consumer calls `SendAsync` and awaits the response. The `Channel` bounds the in-flight notification count: `new BoundedChannelOptions(1000)` drops notifications when the channel is full (applies backpressure to the producer).

For connection management: `PooledConnectionLifetime = 300s` (5 minutes). At 100,000 req/s, connection recycling causes a brief pause while the new connection establishes. To avoid a drop in throughput, I configure pre-creation: before the lifetime expires, the factory creates a new connection alongside the old one, and seamlessly shifts traffic. This requires either `ConnectionLifetime = 300` with a `ConnectCallback` that pre-connects, or a connection pool that maintains a "hot spare." .NET's `SocketsHttpHandler` does not natively support hot spare connections, so I accept the brief throughput dip during connection rotation — at 100,000 req/s and 100ms connection establishment, 100ms / 300s = 0.03% throughput loss. Negligible.

For monitoring: track `http.client.connections.current` — if it exceeds 8 of 10, the provider is near its connection limit. Track `http.client.request.duration` p99 — if it exceeds 50ms, the HTTP/2 streams are saturating."
</details>

---

### Quick Reference Card

| Concern | Command / Config | Notes |
|---|---|---|
| **Check current connections** | `ss -tnp | grep :443 | wc -l` (Linux) / `Get-NetTCPConnection -RemotePort 443` (Windows) | Count connections to a specific port |
| **Check ephemeral port range** | `cat /proc/sys/net/ipv4/ip_local_port_range` (Linux) / `netsh int ipv4 show dynamicport tcp` (Windows) | Shows min and max ephemeral port |
| **Check TIME_WAIT count** | `ss -s | grep timewait` (Linux) / `Get-NetTCPConnection -State TimeWait` (Windows) | High TIME_WAIT indicates connection churn |
| **IHttpClientFactory registration** | `builder.Services.AddHttpClient<TClient, TImpl>()` | Creates typed client with pooled handler |
| **Configure SocketsHttpHandler** | `.ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler { ... })` | Sets MaxConnectionsPerServer, PooledConnectionLifetime, etc. |
| **Handler lifetime** | `.SetHandlerLifetime(TimeSpan.FromMinutes(5))` | Default 2 min. Increase for stable endpoints, decrease for fast DNS rotation |
| **DNS rotation fix** | `PooledConnectionLifetime = TimeSpan.FromMinutes(2)` | Forces connection DNS re-resolution every 2 minutes |
| **HTTP/2 configuration** | `EnableMultipleHttp2Connections = true`, `MaxConnectionsPerServer = 4` | Reduce connection count, increase stream throughput |
| **Reduce TIME_WAIT (Linux)** | `sysctl -w net.ipv4.tcp_tw_reuse=1` | Allows reusing ports in TIME_WAIT for new connections |
| **Clear connection pool** | `HttpClient` disposal or handler recycle | No direct API to clear HTTP pool — recycle the handler via factory |
| **Monitor HTTP metrics** | OpenTelemetry `AddHttpClientInstrumentation()` | Exposes `http.client.connections.current`, `http.client.request.duration` |
| **Test port exhaustion** | `[System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpConnections().Count` | Quick check for connection count in .NET |

### Pre-Save Checklist

- [ ] YAML frontmatter complete — id, title, domain, domain_id, group, tags, priority, prerequisites, related, created
- [ ] All 9 sections present (§1 Navigation, §2 Core Mental Model, §3 Deep Mechanics, §4 Production Patterns, §5 Gotchas, §6 Tradeoffs, §7 Interview Arsenal, §8 ADR, §9 Self-Check + Quick Reference)
- [ ] Mermaid diagram in §2 (HTTP connection pool lifecycle and failure modes)
- [ ] Mermaid flowchart in §6 (decision tree for HTTP pooling strategy)
- [ ] .NET code with XML doc comments in §3 and §4
- [ ] Code blocks use `// Port:` architectural role comments
- [ ] 4 failure modes in §3 (port exhaustion, DNS staleness, connection starvation, HTTP/2 cascade)
- [ ] `IServiceCollection` wiring shown in §4 (typed clients, SocketsHttpHandler config, Polly)
- [ ] Gotchas: 8+ items with ❌/✅ code and Symptom/Fix/Cost
- [ ] Tradeoffs matrix + When NOT to Apply checklist (8+ items) + Scale Thresholds
- [ ] Interview Arsenal: 8+ questions with 2-tier spoken answers + Interview Trigger + Comparison Table
- [ ] ADR: filled with real context (AKS microservices, rolling deployment incident), 3 options, decision, consequences, review trigger
- [ ] Self-Check: 15+ conceptual questions, 5+ scenarios with `<details>` collapsed
- [ ] File naming: `7_237_Connection_Pooling_HTTP_Connection_Reuse.md`
- [ ] Minimum 3 Domain 7 wiki-links + 1 cross-domain link
- [ ] Scale numbers specific

### Related Resources

- [[7_236_Connection_Pooling_SQL_at_Scale.md]] — SQL vs HTTP pooling comparison: SQL pools per-connection-string, HTTP pools per-endpoint; SQL uses lifetime eviction, HTTP uses idle-timeout eviction
- [[7_238_Backpressure_Detection_and_Handling.md]] — HTTP connection pooling interacts with backpressure: pooled connections waiting for responses can obscure downstream backpressure signals
- [[4_049_IHttpClientFactory_Why_HttpClient_Must_Not_Be_Newed_Directly.md]] — The canonical .NET reference for HttpClientFactory
- [[7_210_Load_Balancing_Overview.md]] — Connection pooling interferes with load balancer distribution by pinning clients to one backend
- [[Kubernetes_Services_and_Networking.md]] — Kubernetes Service IP changes and DNS resolution timing for connection pool configuration

### Revision Notes

- **v1.0** (Initial): 1,200+ lines covering HTTP connection pooling lifecycle via SocketsHttpHandler, IHttpClientFactory mechanics, HTTP/1.1 vs HTTP/2 comparison, ephemeral port exhaustion, DNS staleness, 8 gotchas with code, 8 interview questions, ADR with real deployment incident analysis, 15 conceptual questions, 5 scenarios with follow-ups, tradeoff matrix, decision flowchart, and quick reference card. All 9 sections from _main.md spec. Date: 2026-06-17.
