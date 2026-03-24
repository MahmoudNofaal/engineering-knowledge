# API Gateway

> A single entry point that sits in front of your backend services and handles cross-cutting concerns like routing, authentication, rate limiting, and protocol translation.

---

## When To Use It

Use an API Gateway when you have multiple backend services and don't want clients to know about or call them directly. It's essential when you need consistent auth enforcement, rate limiting, or SSL termination across services without duplicating that logic everywhere. Don't use one for a monolith or a simple two-service system — it's an extra network hop and failure point that adds no value at small scale. Avoid building a gateway that contains business logic; the moment it does, you've created a distributed monolith bottleneck.

---

## Core Concept

Without a gateway, a mobile app might call `/users` on Service A, `/orders` on Service B, and `/inventory` on Service C — each with its own auth, its own SSL cert, its own rate limiter. The gateway collapses that into one address for the client. Internally, it routes each request to the right backend. It also handles things that every service would otherwise have to implement: verifying JWTs, blocking abusive IPs, logging every request, translating protocols (REST in, gRPC out). The backend services become simpler because they can trust that the gateway already handled the cross-cutting concerns.

---

## The Code

**YARP reverse proxy setup (ASP.NET Core)**
```csharp
// Program.cs
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

app.MapReverseProxy();
```

**appsettings.json — routing configuration**
```json
{
  "ReverseProxy": {
    "Routes": {
      "orders-route": {
        "ClusterId": "orders-cluster",
        "Match": { "Path": "/api/orders/{**catch-all}" }
      },
      "users-route": {
        "ClusterId": "users-cluster",
        "Match": { "Path": "/api/users/{**catch-all}" }
      }
    },
    "Clusters": {
      "orders-cluster": {
        "Destinations": {
          "primary": { "Address": "https://orders-service:5001/" }
        }
      },
      "users-cluster": {
        "Destinations": {
          "primary": { "Address": "https://users-service:5002/" }
        }
      }
    }
  }
}
```

**Adding JWT validation middleware**
```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://your-identity-provider.com";
        options.Audience = "api";
    });

// In pipeline — runs before proxy forwards the request
app.UseAuthentication();
app.UseAuthorization();
app.MapReverseProxy();
```

**Rate limiting middleware**
```csharp
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("default", o =>
    {
        o.PermitLimit = 100;
        o.Window = TimeSpan.FromMinutes(1);
    });
});

app.UseRateLimiter();
```

---

## Gotchas

- **The gateway becomes a single point of failure.** If it goes down, everything goes down. Run multiple instances behind a load balancer and invest in health checks and circuit breakers before you go to production.
- **Business logic in the gateway is a trap.** Routing, auth, rate limiting, and logging belong in the gateway. If-this-customer-gets-a-discount logic does not. Once business logic creeps in, you lose the ability to deploy or scale backend services independently.
- **Protocol translation adds latency and complexity.** Translating REST to gRPC or aggregating responses from multiple backends in the gateway is possible but makes the gateway harder to test and debug. Evaluate whether a Backend for Frontend (BFF) pattern is more appropriate.
- **Authentication vs authorization is a common mistake.** The gateway can verify that a JWT is valid (authentication). It usually cannot check that this specific user is allowed to access this specific resource (authorization) — that check requires business context the gateway doesn't have. Push authorization to the service.
- **Cascading timeouts must be configured explicitly.** The gateway has its own timeout, and each backend service has its own. If the gateway timeout is 30s and the service timeout is 60s, a slow backend holds a gateway connection open until the gateway cuts it. Set gateway timeouts shorter than backend timeouts.

---

## Interview Angle

**What they're really testing:** Whether you understand the boundary between infrastructure concerns and business logic, and the reliability implications of a centralized entry point.

**Common question form:** "How would you design an API for a microservices system?" or "Where do you enforce authentication in a microservices architecture?"

**The depth signal:** A junior says the API gateway handles routing and authentication. A senior distinguishes authentication (gateway) from authorization (service), explains the single-point-of-failure risk and how to mitigate it (multiple instances, circuit breakers), warns against business logic creep, and can describe when a BFF is preferable to a general-purpose gateway — specifically when different client types (mobile vs web) need significantly different response shapes.

---

## Related Topics

- [[system-design/rest-vs-grpc.md]] — gateways often bridge REST clients to gRPC backends; understanding both protocols is necessary
- [[system-design/websockets.md]] — not all gateways support WebSocket protocol upgrades; this needs explicit verification and configuration
- [[system-design/event-driven-architecture.md]] — gateways handle synchronous entry points; async workflows typically bypass them entirely

---

## Source

https://learn.microsoft.com/en-us/azure/architecture/microservices/design/gateway

---

*Last updated: 2026-03-24*