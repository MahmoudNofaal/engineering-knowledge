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
```python
# ── Load balancing algorithms — implemented from scratch ──────────────────
import itertools
import random
import time
from dataclasses import dataclass, field

@dataclass
class Backend:
    host:         str
    weight:       int  = 1
    active_conns: int  = 0
    healthy:      bool = True

class RoundRobinBalancer:
    """Equal distribution. Best when all backends are identical."""
    def __init__(self, backends: list[Backend]):
        self._pool  = [b for b in backends if b.healthy]
        self._cycle = itertools.cycle(self._pool)

    def next(self) -> Backend | None:
        healthy = [b for b in self._pool if b.healthy]
        if not healthy:
            return None
        return next(self._cycle)

class LeastConnectionsBalancer:
    """Routes to the server with fewest active connections.
       Best when requests have variable processing time."""
    def __init__(self, backends: list[Backend]):
        self._pool = backends

    def next(self) -> Backend | None:
        healthy = [b for b in self._pool if b.healthy]
        if not healthy:
            return None
        return min(healthy, key=lambda b: b.active_conns)

class WeightedRoundRobinBalancer:
    """Backend with weight=3 gets 3x the traffic of weight=1.
       Use when backends have different capacities."""
    def __init__(self, backends: list[Backend]):
        self._pool = [b for b in backends for _ in range(b.weight) if b.healthy]
        self._cycle = itertools.cycle(self._pool)

    def next(self) -> Backend | None:
        if not self._pool:
            return None
        return next(self._cycle)

# ── Usage ─────────────────────────────────────────────────────────────────
backends = [
    Backend("web-1:8080", weight=3),  # bigger instance
    Backend("web-2:8080", weight=1),
    Backend("web-3:8080", weight=1, healthy=False),  # down for maintenance
]

lb = LeastConnectionsBalancer(backends)
for _ in range(5):
    chosen = lb.next()
    print(f"Route to: {chosen.host}")
```
```python
# ── Health checking loop ───────────────────────────────────────────────────
import httpx
import threading

def health_check_loop(backends: list[Backend], interval_s: int = 5) -> None:
    """Runs in background; marks backends healthy/unhealthy based on /health."""
    while True:
        for backend in backends:
            try:
                r = httpx.get(f"http://{backend.host}/health", timeout=2.0)
                backend.healthy = r.status_code == 200
            except Exception:
                backend.healthy = False   # timeout or connection refused
            print(f"{backend.host}: {'✓' if backend.healthy else '✗'}")
        time.sleep(interval_s)

# In production this is handled by the load balancer itself (nginx, HAProxy, ALB).
# Shown here to make the concept explicit.
```
```nginx
# ── nginx: real load balancer config ──────────────────────────────────────
# /etc/nginx/nginx.conf

upstream app_servers {
    least_conn;                      # algorithm: least connections

    server web-1:8080 weight=3;
    server web-2:8080 weight=1;
    server web-3:8080 weight=1 backup;  # only used if primary servers are down

    keepalive 32;                    # reuse upstream connections — critical at scale
}

server {
    listen 443 ssl;

    ssl_certificate     /etc/ssl/cert.pem;
    ssl_certificate_key /etc/ssl/key.pem;
    # TLS terminates HERE — backends receive plain HTTP internally

    location / {
        proxy_pass         http://app_servers;
        proxy_set_header   X-Real-IP $remote_addr;  # preserve original client IP
        proxy_set_header   Host      $host;
    }
}
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