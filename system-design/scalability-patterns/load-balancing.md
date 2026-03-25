# Load Balancing

> Distributing incoming network traffic across multiple backend servers so no single server becomes a bottleneck or single point of failure.

---

## When To Use It
The moment you have more than one instance of a service. Without a load balancer, all traffic hits one server and you've gained nothing from horizontal scaling. Load balancers also provide health checking — removing unhealthy instances from rotation automatically — and are the entry point for TLS termination, rate limiting, and routing logic. If you have one server, you don't need one. If you have two, you do.

---

## Core Concept
A load balancer sits between the client and your fleet of servers. Every incoming request hits the load balancer first; it decides which backend server gets that request. The decision algorithm (the balancing strategy) matters because picking the wrong one causes uneven load even with multiple servers. Beyond distribution, load balancers continuously health-check backends — if a server stops responding, the balancer stops sending it traffic without the client ever knowing. This is what makes horizontal scaling invisible to callers.

---

## The Code
```csharp
// ── Load balancing algorithms — implemented from scratch ──────────────────
using System;
using System.Collections.Generic;
using System.Linq;

public class Backend
{
    public string Host { get; set; }
    public int Weight { get; set; } = 1;
    public int ActiveConns { get; set; } = 0;
    public bool Healthy { get; set; } = true;
}

public class RoundRobinBalancer
{
    // Equal distribution. Best when all backends are identical.
    private readonly List<Backend> _pool;
    private int _currentIndex = 0;

    public RoundRobinBalancer(List<Backend> backends)
    {
        _pool = backends.Where(b => b.Healthy).ToList();
    }

    public Backend Next()
    {
        var healthy = _pool.Where(b => b.Healthy).ToList();
        if (healthy.Count == 0)
            return null;
        var selected = healthy[_currentIndex % healthy.Count];
        _currentIndex++;
        return selected;
    }
}

public class LeastConnectionsBalancer
{
    // Routes to the server with fewest active connections.
    // Best when requests have variable processing time.
    private readonly List<Backend> _pool;

    public LeastConnectionsBalancer(List<Backend> backends)
    {
        _pool = backends;
    }

    public Backend Next()
    {
        var healthy = _pool.Where(b => b.Healthy).ToList();
        if (healthy.Count == 0)
            return null;
        return healthy.OrderBy(b => b.ActiveConns).First();
    }
}

public class WeightedRoundRobinBalancer
{
    // Backend with weight=3 gets 3x the traffic of weight=1.
    // Use when backends have different capacities.
    private readonly List<Backend> _pool;
    private int _currentIndex = 0;

    public WeightedRoundRobinBalancer(List<Backend> backends)
    {
        _pool = new List<Backend>();
        foreach (var b in backends.Where(b => b.Healthy))
        {
            for (int i = 0; i < b.Weight; i++)
                _pool.Add(b);
        }
    }

    public Backend Next()
    {
        if (_pool.Count == 0)
            return null;
        var selected = _pool[_currentIndex % _pool.Count];
        _currentIndex++;
        return selected;
    }
}

// ── Usage ─────────────────────────────────────────────────────────────────
var backends = new List<Backend>
{
    new Backend { Host = "web-1:8080", Weight = 3 },  // bigger instance
    new Backend { Host = "web-2:8080", Weight = 1 },
    new Backend { Host = "web-3:8080", Weight = 1, Healthy = false },  // down for maintenance
};

var lb = new LeastConnectionsBalancer(backends);
for (int i = 0; i < 5; i++)
{
    var chosen = lb.Next();
    Console.WriteLine($"Route to: {chosen.Host}");
}
```
```csharp
// ── Health checking loop ──
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

public class HealthCheckService
{
    private readonly List<Backend> _backends;
    private readonly HttpClient _httpClient = new();

    public HealthCheckService(List<Backend> backends)
    {
        _backends = backends;
    }

    public async Task HealthCheckLoopAsync(int intervalSeconds = 5)
    {
        // Runs as background task; marks backends healthy/unhealthy based on /health
        while (true)
        {
            foreach (var backend in _backends)
            {
                try
                {
                    var response = await _httpClient.GetAsync(
                        $"http://{backend.Host}/health",
                        HttpCompletionOption.ResponseContentRead
                    );
                    backend.Healthy = response.StatusCode == System.Net.HttpStatusCode.OK;
                }
                catch (Exception)
                {
                    backend.Healthy = false;  // timeout or connection refused
                }
                Console.WriteLine($"{backend.Host}: {(backend.Healthy ? "✓" : "✗")}");
            }
            await Task.Delay(intervalSeconds * 1000);
        }
    }
}
// In production this is handled by the load balancer itself (nginx, HAProxy, ALB).
// Shown here to make the concept explicit.
```
```csharp
// ── nginx: real load balancer config ──────────────────────────────────────
// /etc/nginx/nginx.conf reference — nginx configuration shown as comments

// C# YARP (Yet Another Reverse Proxy) equivalent in appsettings.json:
/*
{
  "ReverseProxy": {
    "Clusters": [
      {
        "ClusterId": "appCluster",
        "LoadBalancingPolicy": "LeastRequests",
        "Destinations": {
          "app1": { "Address": "http://web-1:8080" },
          "app2": { "Address": "http://web-2:8080" },
          "app3": { "Address": "http://web-3:8080" }
        }
      }
    ],
    "Routes": [
      {
        "RouteId": "api",
        "ClusterId": "appCluster",
        "Match": { "Path": "/{**catch-all}" }
      }
    ]
  }
}
*/
```

---

## Gotchas
- **Round robin breaks sticky state.** If a user's session is stored on web-1, their next request routing to web-2 loses that session. Either externalize session state or use IP hash / cookie-based stickiness — and know that sticky sessions reduce your ability to drain a node cleanly.
- **Health checks must test real readiness, not just liveness.** A server that responds 200 to `/health` but has a saturated database connection pool will still accept — and fail — real traffic. Health checks should verify the server can actually serve requests (warm connections, dependencies reachable).
- **The load balancer itself is a single point of failure.** A single nginx instance in front of your fleet doesn't solve the SPOF problem — it just moves it. Production setups use active-passive or active-active LB pairs with a floating IP (keepalived, AWS NLB, etc.).
- **SSL termination at the load balancer exposes internal traffic.** Traffic between the LB and backends is plain HTTP. In regulated environments (HIPAA, PCI-DSS) you need end-to-end TLS — terminate at the LB and re-encrypt to backends — which adds latency and certificate management complexity.
- **Connection draining is mandatory for zero-downtime deploys.** When removing a backend from rotation (for a deploy), the load balancer must finish in-flight requests before stopping traffic. Without draining, active users get connection reset errors mid-request.

---

## Interview Angle
**What they're really testing:** Whether you understand that load balancing is more than just "spreading traffic" — it includes failure detection, routing logic, and the operational implications of deployment and state.

**Common question form:** "How would you design a system to handle 100K concurrent users?" — load balancing is always a required component of the answer.

**The depth signal:** A junior candidate says "put a load balancer in front of the servers." A senior candidate specifies the algorithm and why ("least connections because our ML inference requests have highly variable latency"), mentions health check configuration, addresses the stickiness question ("we externalize sessions to Redis so we don't need sticky sessions"), and flags the LB itself as a SPOF ("we'd use an AWS ALB or a keepalived pair — never a single nginx"). They also mention connection draining for deploys without being prompted. The separation is: juniors treat the load balancer as a box, seniors treat it as a component with its own failure modes and configuration decisions.

---

## Related Topics
- [[system-design/horizontal-vs-vertical-scaling.md]] — Load balancing is what makes horizontal scaling actually work.
- [[system-design/rate-limiting.md]] — Often implemented at the load balancer layer.
- [[system-design/consistent-hashing.md]] — How stateful load balancing (cache routing, sharding) distributes load without rehashing everything on topology changes.

---

## Source
https://www.nginx.com/resources/glossary/load-balancing/

---
*Last updated: 2026-03-24*