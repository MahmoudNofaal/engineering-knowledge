# WebSockets

> A protocol that keeps a single TCP connection open between client and server so either side can send data at any time, without the client polling.

---

## When To Use It

Use WebSockets when you need low-latency, bidirectional communication — chat apps, live dashboards, multiplayer games, collaborative editing. Don't use them for request-response interactions where the client only occasionally needs data; polling or Server-Sent Events are simpler and easier to scale. Avoid WebSockets when your infrastructure (load balancers, proxies) doesn't support persistent connections — you'll fight configuration issues the whole way.

---

## Core Concept

Normal HTTP is one-directional per request: client asks, server answers, connection closes. WebSockets start as an HTTP request that gets "upgraded" — the client sends an `Upgrade: websocket` header, the server agrees, and the connection switches protocols. From that point on, it's a persistent TCP pipe. Both sides can push frames to each other whenever they want, with very little overhead per message compared to HTTP headers. The connection stays open until one side closes it or the network drops.

---

## The Code

**Server — ASP.NET Core WebSocket handler**
```csharp
app.Use(async (context, next) =>
{
    if (context.Request.Path == "/ws" && context.WebSockets.IsWebSocketRequest)
    {
        using var ws = await context.WebSockets.AcceptWebSocketAsync();
        var buffer = new byte[1024 * 4];

        while (true)
        {
            var result = await ws.ReceiveAsync(buffer, CancellationToken.None);

            if (result.MessageType == WebSocketMessageType.Close) break;

            // Echo the message back
            await ws.SendAsync(
                new ArraySegment<byte>(buffer, 0, result.Count),
                WebSocketMessageType.Text,
                endOfMessage: true,
                CancellationToken.None
            );
        }
    }
    else
    {
        await next();
    }
});
```

**Client — browser JavaScript**
```javascript
const socket = new WebSocket("wss://myapp.com/ws");

socket.onopen = () => socket.send("hello");

socket.onmessage = (event) => console.log("Received:", event.data);

socket.onclose = () => console.log("Connection closed");
```

**Sending structured data**
```javascript
// Always serialize — WebSocket frames carry strings or binary, not objects
socket.send(JSON.stringify({ type: "chat", text: "hello" }));
```

---

## Gotchas

- **Load balancers need sticky sessions or WebSocket-aware routing.** If a connection gets routed to a different server mid-session, it breaks. Most cloud load balancers support WebSocket passthrough, but you must explicitly enable it.
- **Connections don't automatically recover.** If the network drops, the client gets a close event and that's it. You must implement reconnection logic with exponential backoff yourself — the protocol doesn't do it for you.
- **Horizontal scaling requires a shared message bus.** If you have 10 servers and users are connected to different ones, server A can't push to a user on server B. You need Redis Pub/Sub or a message broker to fan out messages across instances.
- **Idle connections get killed silently.** Proxies, NAT gateways, and firewalls close TCP connections that look idle. Implement a heartbeat (ping/pong frames) every 30–60 seconds to keep connections alive.
- **You lose HTTP semantics.** No standard auth headers per message, no built-in request IDs, no automatic retries. You have to design your own message envelope format to handle all of this.

---

## Interview Angle

**What they're really testing:** Whether you understand the stateful nature of WebSocket connections and the scaling problems that come from it.

**Common question form:** "How would you build a real-time chat system?" or "What are the challenges of scaling WebSockets?"

**The depth signal:** A junior says WebSockets are fast because they don't have HTTP overhead. A senior talks about sticky sessions at the load balancer, the need for a pub/sub layer (Redis) to fan out messages across server instances, heartbeat implementation to survive NAT timeouts, and reconnection strategy on the client. They also mention when *not* to use WebSockets — Server-Sent Events for server-to-client-only streams, which are simpler to scale and proxy.

---

## Related Topics

- [[system-design/event-driven-architecture.md]] — WebSockets are the delivery mechanism at the edge; event-driven architecture handles what happens on the backend
- [[system-design/message-queues.md]] — message queues often sit between backend services and the WebSocket layer, decoupling event production from delivery
- [[system-design/api-gateway.md]] — API gateways need explicit WebSocket support; not all of them handle protocol upgrades correctly

---

## Source

https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API

---

*Last updated: 2026-03-24*