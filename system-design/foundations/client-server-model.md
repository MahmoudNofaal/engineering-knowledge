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
```csharp
// ── Minimal HTTP server (ASP.NET Core) ──────────────────────────────────────────
using Microsoft.AspNetCore.Http;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/ping", () =>
{
    var response = new { status = "ok" };
    return Results.Json(response);
});

app.MapFallback(context =>
{
    context.Response.StatusCode = 404;
    return context.Response.CompleteAsync();
});

app.Run("http://0.0.0.0:8080");
```
```csharp
// ── Minimal HTTP client ──────────────────────────────────────────────
using System.Net.Http;
using System.Text.Json;

public async Task<Dictionary<string, string>> PingServerAsync(string baseUrl)
{
    using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
    try
    {
        var response = await client.GetAsync($"{baseUrl}/ping");
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<Dictionary<string, string>>(json);
    }
    catch (HttpRequestException ex)
    {
        throw new Exception($"Request failed: {ex.Message}");
    }
}

var result = await PingServerAsync("http://localhost:8080");
Console.WriteLine(JsonSerializer.Serialize(result));  // {"status": "ok"}
```
```csharp
// ── Server-as-client: service-to-service communication ───────────────────────
// The "server" in one interaction becomes a "client" in the next.
// This is the basis of microservice architectures.

using System.Net.Http;
using System.Text.Json;

public class OrderService
{
    private readonly HttpClient _client;

    public OrderService(HttpClient client) => _client = client;

    public async Task<Dictionary<string, object>> CreateOrderAsync(string itemId, int quantity)
    {
        // This service is a client here — calling another server
        var inventoryResponse = await _client.GetAsync(
            $"http://inventory-service/items/{itemId}"
        );
        
        if (!inventoryResponse.IsSuccessStatusCode)
            throw new Exception($"Inventory service failed: {inventoryResponse.StatusCode}");

        var inventoryJson = await inventoryResponse.Content.ReadAsStringAsync();
        var inventory = JsonSerializer.Deserialize<Dictionary<string, object>>(inventoryJson);

        if ((int)inventory["stock"] < quantity)
            throw new InvalidOperationException("Insufficient stock");

        return new Dictionary<string, object>
        {
            { "order_id", "ord_123" },
            { "item_id", itemId },
            { "quantity", quantity }
        };
    }
}
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