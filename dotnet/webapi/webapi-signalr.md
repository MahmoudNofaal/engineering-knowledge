# ASP.NET Core SignalR

> SignalR is a library that adds real-time, bidirectional communication to ASP.NET Core applications — the server can push messages to connected clients instantly without clients having to poll.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Real-time hub-based messaging over WebSockets (with fallbacks) |
| **Use when** | Live dashboards, chat, notifications, collaborative editing, game state |
| **Avoid when** | One-off request/response patterns — use regular HTTP endpoints instead |
| **Introduced** | ASP.NET Core 1.0 (rewrite of classic SignalR); Azure SignalR Service for scale-out |
| **Namespace** | `Microsoft.AspNetCore.SignalR` |
| **Key types** | `Hub`, `Hub<T>`, `IHubContext<T>`, `HubCallerClients`, `IClientProxy` |

---

## When To Use It

Use SignalR when clients need to receive data the moment it becomes available on the server, without polling. Live order tracking, real-time analytics dashboards, collaborative document editing, multiplayer game state, instant notifications, and live chat all benefit from push semantics. Don't use it for standard CRUD operations — a regular HTTP endpoint is simpler and scales better for request/response patterns. The rule of thumb: if the user would need to refresh the page to see new data, SignalR is worth evaluating.

---

## Core Concept

SignalR establishes a persistent connection between client and server — preferably WebSocket, falling back to Server-Sent Events, then long polling. Once connected, both sides can send messages freely. On the server, a `Hub` is the central class — clients call methods on it (client → server), and the server calls methods on clients via `Clients.All`, `Clients.Caller`, or `Clients.Group(...)` (server → client). Hubs are transient — a new instance is created for each method call. Persistent state lives in `IHubContext<T>` (injectable into services and background workers), not in the `Hub` class itself. Groups allow broadcasting to subsets of connected clients without tracking connection IDs manually.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | SignalR completely rewritten; WebSocket-first with fallback |
| ASP.NET Core 2.1 | Strongly-typed hubs (`Hub<T>`) — compile-time client method name checking |
| ASP.NET Core 3.0 | MessagePack protocol support; streaming improvements |
| .NET 5 | `IAsyncEnumerable<T>` server-to-client streaming |
| .NET 6 | Client-to-server streaming improvements; `HubConnectionBuilder` improvements |
| .NET 8 | Stateful reconnect — clients can resume without losing messages after reconnection |

*Stateful reconnect (.NET 8) is the most significant reliability improvement since launch. Before it, any network blip caused clients to miss messages during reconnection. With it, the server buffers messages during the disconnection window and replays them on reconnect.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| WebSocket frame send | ~10 µs | Near-native WebSocket; very low overhead |
| `Clients.All.SendAsync(...)` | O(n) | n = number of connected clients |
| `Clients.Group(...).SendAsync(...)` | O(m) | m = number of clients in the group |
| Hub method invocation | ~50–100 µs | Hub instantiation + method dispatch |
| JSON serialisation per message | O(size) | Use MessagePack for 2-3× throughput improvement |

**Allocation behaviour:** Each `SendAsync` call allocates a serialised message buffer per send. For broadcast to 10,000 clients, this means 10,000 send operations — SignalR pipelines them but the allocation is real. Use MessagePack (`AddMessagePackProtocol()`) for high-throughput scenarios — it serialises 2–3× faster and produces smaller payloads than JSON.

**Benchmark notes:** A single SignalR server on modern hardware handles 10,000–50,000 concurrent connections with JSON. MessagePack raises this to 100,000+. For larger scale, use Azure SignalR Service which handles connection management externally and lets your API server focus on business logic.

---

## The Code

**Hub definition and registration**
```csharp
// Define the hub
public class OrderHub : Hub
{
    // Client calls this method on the server
    public async Task SubscribeToOrder(string orderId)
    {
        // Add this connection to a group named after the order ID
        await Groups.AddToGroupAsync(Context.ConnectionId, $"order:{orderId}");
        await Clients.Caller.SendAsync("Subscribed", orderId);
    }

    public async Task UnsubscribeFromOrder(string orderId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"order:{orderId}");
    }

    // Called automatically when a client connects
    public override async Task OnConnectedAsync()
    {
        var userId = Context.User?.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId is not null)
            await Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");
        await base.OnConnectedAsync();
    }

    // Called automatically when a client disconnects
    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        // Groups are cleaned up automatically on disconnect
        await base.OnDisconnectedAsync(exception);
    }
}

// Program.cs
builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = builder.Environment.IsDevelopment();
    options.KeepAliveInterval   = TimeSpan.FromSeconds(15);
    options.ClientTimeoutInterval = TimeSpan.FromSeconds(30);
});

app.MapHub<OrderHub>("/hubs/orders");
```

**Strongly-typed hub (`Hub<T>`) — compile-time safety**
```csharp
// Define the client interface — what methods the server can call on clients
public interface IOrderHubClient
{
    Task OrderStatusChanged(OrderStatusUpdate update);
    Task OrderItemAdded(OrderItemDto item);
    Task OrderCancelled(string orderId, string reason);
}

public class OrderHub : Hub<IOrderHubClient>
{
    public async Task SubscribeToOrder(string orderId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"order:{orderId}");

        // Strongly typed — no magic strings, compile-time checked
        await Clients.Caller.OrderStatusChanged(new OrderStatusUpdate
        {
            OrderId = orderId,
            Status  = "Subscribed"
        });
    }
}
```

**Pushing from a background service via `IHubContext`**
```csharp
// Inject IHubContext to push from anywhere — background services, controllers, event handlers
public class OrderStatusService(IHubContext<OrderHub, IOrderHubClient> hub)
{
    public async Task NotifyStatusChangeAsync(string orderId, string newStatus)
    {
        // Push to all clients subscribed to this order's group
        await hub.Clients.Group($"order:{orderId}").OrderStatusChanged(new OrderStatusUpdate
        {
            OrderId   = orderId,
            Status    = newStatus,
            Timestamp = DateTimeOffset.UtcNow
        });
    }
}

// Register and use in a background service
public class OrderEventProcessor(
    IOrderRepository orders,
    OrderStatusService statusService) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        await foreach (var @event in _queue.ReadAllAsync(ct))
        {
            await orders.UpdateStatusAsync(@event.OrderId, @event.NewStatus, ct);
            await statusService.NotifyStatusChangeAsync(@event.OrderId, @event.NewStatus);
        }
    }
}
```

**Authentication on SignalR connections**
```csharp
// SignalR uses cookies or query string token for WebSocket auth (headers don't work in browsers)
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                // SignalR clients send the token as a query string param
                var accessToken = context.Request.Query["access_token"];
                var path        = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) &&
                    path.StartsWithSegments("/hubs"))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

// Protect the hub endpoint
app.MapHub<OrderHub>("/hubs/orders").RequireAuthorization();
```

**Server-to-client streaming**
```csharp
public class ReportHub : Hub
{
    // Server streams multiple values to the client over time
    public async IAsyncEnumerable<ReportRow> StreamReport(
        string reportId,
        [EnumeratorCancellation] CancellationToken ct)
    {
        var rows = _reports.GetRowsAsync(reportId, ct);
        await foreach (var row in rows.WithCancellation(ct))
        {
            yield return row;
            await Task.Delay(10, ct); // throttle to avoid overwhelming the client
        }
    }
}
```

**Groups for multi-tenant broadcasting**
```csharp
public class DashboardHub : Hub
{
    // On connect, join the tenant's group so they only receive their data
    public override async Task OnConnectedAsync()
    {
        var tenantId = Context.User?.FindFirstValue("tenant_id");
        if (tenantId is not null)
            await Groups.AddToGroupAsync(Context.ConnectionId, $"tenant:{tenantId}");
        await base.OnConnectedAsync();
    }
}

// Push to a specific tenant from a controller or service
public class MetricsController(IHubContext<DashboardHub> hub) : ControllerBase
{
    [HttpPost("metrics/push")]
    public async Task<IActionResult> Push([FromBody] MetricsUpdate update)
    {
        await hub.Clients.Group($"tenant:{update.TenantId}")
            .SendAsync("MetricsUpdated", update);
        return Ok();
    }
}
```

---

## Real World Example

A logistics platform shows real-time delivery tracking on a map. The driver's mobile app sends location updates to an API endpoint; the API pushes them to all browser clients tracking that delivery via SignalR groups. The `IHubContext` is injected into the REST controller — no polling, no webhook, sub-second updates.

```csharp
// Hub — clients subscribe to deliveries they're tracking
public class DeliveryHub : Hub<IDeliveryHubClient>
{
    public async Task TrackDelivery(string deliveryId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"delivery:{deliveryId}");
    }

    public async Task StopTracking(string deliveryId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"delivery:{deliveryId}");
    }
}

public interface IDeliveryHubClient
{
    Task LocationUpdated(DeliveryLocationUpdate update);
    Task StatusChanged(DeliveryStatusUpdate update);
    Task EstimatedArrivalUpdated(DateTimeOffset eta);
}

// REST endpoint called by the driver app
[ApiController]
[Route("api/deliveries")]
public class DeliveryController(
    IHubContext<DeliveryHub, IDeliveryHubClient> hub,
    IDeliveryRepository deliveries) : ControllerBase
{
    // Driver's mobile app calls this with GPS coordinates
    [HttpPost("{id}/location")]
    [Authorize(Roles = "Driver")]
    public async Task<IActionResult> UpdateLocation(
        string id,
        [FromBody] LocationUpdate location)
    {
        await deliveries.SaveLocationAsync(id, location);

        // Push to all browser clients tracking this delivery
        await hub.Clients.Group($"delivery:{id}").LocationUpdated(new DeliveryLocationUpdate
        {
            DeliveryId = id,
            Latitude   = location.Latitude,
            Longitude  = location.Longitude,
            Timestamp  = DateTimeOffset.UtcNow,
            Speed      = location.SpeedKmh
        });

        // Recalculate ETA and push update if changed significantly
        var eta = await deliveries.RecalculateEtaAsync(id, location);
        if (eta.HasValue)
            await hub.Clients.Group($"delivery:{id}").EstimatedArrivalUpdated(eta.Value);

        return NoContent();
    }
}

// Program.cs
builder.Services.AddSignalR().AddMessagePackProtocol(); // MessagePack for lower latency
app.MapHub<DeliveryHub>("/hubs/deliveries").RequireAuthorization();
```

*The key insight: `IHubContext<DeliveryHub, IDeliveryHubClient>` is injected into a regular REST controller. The driver's app uses a plain HTTP POST (reliable, works on all networks); browser clients use WebSocket. The hub is the fan-out mechanism — one driver POST triggers pushes to potentially thousands of tracking browser sessions simultaneously.*

---

## Common Misconceptions

**"Hub instances persist across calls — I can store state in Hub fields."**
Hub instances are transient — a new instance is created for each method invocation and disposed after. State stored in Hub fields is lost immediately. Use `IHubContext<T>` for server-initiated pushes, and store persistent state in a cache, database, or `ConcurrentDictionary` in a singleton service.

**"SignalR replaces REST endpoints."**
SignalR is for push scenarios — data the server needs to send to clients without a client request. REST is for request/response. Use them together: REST for commands (place order, update profile), SignalR for events (order status changed, new message received). Trying to do everything through SignalR adds unnecessary complexity for patterns that work better as HTTP.

**"WebSockets work everywhere without configuration."**
WebSockets require specific infrastructure support: load balancers must be configured to pass WebSocket upgrade requests, sticky sessions are needed if you're not using a backplane (Redis, Azure SignalR Service), and firewalls/proxies sometimes block WebSocket traffic. SignalR's fallback transports (Server-Sent Events, long polling) handle the cases where WebSocket fails — but sticky sessions remain required for multi-server deployments without Azure SignalR Service.

---

## Gotchas

- **Hub instances are transient — state in Hub fields doesn't persist.** Use `IHubContext<T>` for inter-request communication and shared services for state.

- **JWT tokens can't be sent as `Authorization` headers with WebSocket from browsers.** The browser WebSocket API doesn't support custom headers. SignalR clients send the token as a `?access_token=` query string parameter. Configure `OnMessageReceived` in `JwtBearerEvents` to extract it from there.

- **Multi-server deployments without a backplane break group broadcasting.** Each server has its own in-memory connection registry. A group push from server A doesn't reach clients connected to server B. Add Redis backplane (`AddStackExchangeRedis`) or use Azure SignalR Service.

- **`Clients.All.SendAsync(...)` blocks until all sends complete.** For large connection counts this can be slow. For fire-and-forget notifications, don't `await` the send — or use a background queue to fan out.

- **`OnDisconnectedAsync` is not guaranteed to fire.** If the server restarts abruptly, connection cleanup may not run. Design group membership and connection tracking to be tolerant of missed disconnection events.

- **Stateful reconnect (.NET 8) requires opt-in on both server and client.** Without it, reconnecting clients miss messages sent during the disconnection window. Enable with `options.EnableDetailedErrors` and configure the server-side buffer size appropriately.

---

## Interview Angle

**What they're really testing:** Whether you understand the push model vs request/response, how Hub lifetime affects design, and what infrastructure requirements real-time at scale introduces.

**Common question forms:**
- "How would you implement real-time notifications in ASP.NET Core?"
- "What's the difference between SignalR and WebSockets?"
- "How do you push messages from a background service to connected clients?"
- "How does SignalR work in a multi-server deployment?"

**The depth signal:** A junior knows SignalR uses WebSockets and has a Hub class. A senior explains that hubs are transient (new instance per call), knows to use `IHubContext<T>` for server-initiated pushes outside the hub, understands that multi-server deployments need a Redis backplane or Azure SignalR Service, knows JWT auth requires the `OnMessageReceived` event because browsers can't send custom headers with WebSockets, and can explain the difference between `Clients.All`, `Clients.Group`, and `Clients.Caller` semantics.

**Follow-up questions to expect:**
- "How would you scale SignalR to 100,000 concurrent connections?"
- "How do you handle message delivery guarantees with SignalR?"
- "What's the difference between server-to-client streaming and regular hub method calls?"

---

## Related Topics

- [[dotnet/webapi/webapi-authentication.md]] — SignalR JWT auth requires the `OnMessageReceived` event because browser WebSockets don't support `Authorization` headers
- [[dotnet/webapi/webapi-background-services.md]] — background services push to clients via `IHubContext<T>`; this is the primary integration pattern for event-driven real-time updates
- [[dotnet/webapi/middleware-pipeline.md]] — SignalR endpoints are registered with `MapHub<T>()` in the endpoint routing middleware; `RequireAuthorization()` applies to the WebSocket upgrade request
- [[databases/nosql/redis-fundamentals.md]] — Redis is the backplane for multi-server SignalR deployments; it replicates group membership and message broadcast across server instances

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/signalr/introduction

---
*Last updated: 2026-04-10*