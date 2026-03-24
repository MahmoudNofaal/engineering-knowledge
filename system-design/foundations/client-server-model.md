# Client-Server Model

> An architectural pattern where clients request resources or services, and servers respond to those requests — with a clear separation between the two roles.

---

## When To Use It
This model underpins almost every networked application built today — web apps, mobile apps, APIs, databases. You're implicitly using it any time a user's device talks to a backend. Understanding it deeply matters when you're debugging network issues, designing APIs, reasoning about latency, or deciding where to put logic (client-side vs. server-side). The edge cases — what happens when the connection drops, who retries, who owns state — are where real design decisions live.

---

## Core Concept
A client initiates requests; a server listens for them and sends back responses. That's the whole model. The client doesn't need to know how the server works internally — it just needs to know the interface (the API). The server doesn't need to know anything about the client beyond what's in the request. This separation is what makes it possible to change either side independently. In practice, the model gets complicated fast: servers become clients of other servers (microservices), clients cache responses locally, and the line between "who owns what" blurs. But the core contract — request, response, stateless by default — stays the same.

---

## The Code
```python
# ── Minimal HTTP server (Python stdlib, no frameworks) ────────────────────
from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/ping":
            body = json.dumps({"status": "ok"}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # suppress default request logging

if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
```
```python
# ── Minimal HTTP client ───────────────────────────────────────────────────
import httpx

def ping_server(base_url: str) -> dict:
    response = httpx.get(f"{base_url}/ping", timeout=5.0)
    response.raise_for_status()   # raises on 4xx/5xx
    return response.json()

result = ping_server("http://localhost:8080")
print(result)  # {"status": "ok"}
```
```python
# ── Server-as-client: service-to-service communication ───────────────────
# The "server" in one interaction becomes a "client" in the next.
# This is the basis of microservice architectures.

import httpx

# Order Service (acts as server to the browser, client to Inventory Service)
def create_order(item_id: str, quantity: int) -> dict:
    # This service is a client here — calling another server
    inventory = httpx.get(
        f"http://inventory-service/items/{item_id}",
        timeout=3.0
    ).json()

    if inventory["stock"] < quantity:
        raise ValueError("Insufficient stock")

    return {"order_id": "ord_123", "item_id": item_id, "quantity": quantity}
```

---

## Gotchas
- **HTTP is stateless by design — the server remembers nothing between requests.** Any "session" is an illusion maintained by tokens, cookies, or server-side session stores. Forgetting this leads to authentication bugs and broken state management.
- **The client decides what to do with errors, not the server.** A 500 response from the server doesn't retry itself. Retry logic, backoff, and circuit breaking all live on the client side — and most implementations skip them until something breaks in production.
- **Latency is a two-way cost.** Every client-server round trip pays the network cost twice (request + response). In a chain of three services, you've paid it six times. This is why chatty APIs are a performance problem, not just a design smell.
- **DNS resolution is a hidden client responsibility.** The client resolves the server's hostname before every new connection (unless cached). In service meshes or Kubernetes environments, stale DNS caches cause mysterious connection failures to recently redeployed services.
- **TCP connection setup is not free.** Each new TCP connection requires a handshake before any data flows. TLS adds another round trip on top. Connection pooling on the client side (reusing existing connections) is mandatory, not optional, at scale.

---

## Interview Angle
**What they're really testing:** Whether you understand the actual mechanics of how two machines communicate — not just that "clients talk to servers."

**Common question form:** "Walk me through what happens when a user types a URL into a browser and hits Enter."

**The depth signal:** A junior answer covers the surface: DNS, HTTP request, server responds with HTML. A senior answer layers in the mechanics: DNS resolution with caching TTLs, TCP handshake, TLS negotiation, HTTP/1.1 vs HTTP/2 multiplexing, keep-alive connection reuse, CDN edge caching before the origin server is even hit, and how a server-side render differs from a client-side React app. They also distinguish between the theoretical model and real-world complications: load balancers, reverse proxies, and why the "server" the client thinks it's talking to is often not the machine that actually runs the code.

---

## Related Topics
- [[system-design/load-balancing.md]] — What sits between clients and servers at scale, and why the model needs it.
- [[system-design/latency-numbers.md]] — The real costs of each round trip in this model.
- [[system-design/what-is-system-design.md]] — The client-server model is the base layer every system design builds on.

---

## Source
https://developer.mozilla.org/en-US/docs/Learn/Server-side/First_steps/Client-Server_overview

---
*Last updated: 2026-03-24*