# API Security

> The set of practices and controls that protect an API from unauthorized access, abuse, data exposure, and injection attacks.

---

## When To Use It

Every API that is publicly reachable or handles sensitive data needs an explicit security model. Even internal APIs behind a VPC need it — lateral movement after a breach is real. Security is not a feature you add later; retrofitting auth and rate limiting onto an existing API always leaves gaps. Model threats before you build, not after.

---

## Core Concept

API security is layered. Authentication establishes identity. Authorization enforces what that identity can do. Input validation prevents injection. Rate limiting prevents abuse and DDoS. Transport security (TLS) prevents interception. Each layer is necessary and none is sufficient alone. The OWASP API Security Top 10 is the canonical threat list — broken object level authorization (BOLA) is the most common real-world vulnerability: a user who can access `/orders/123` shouldn't be able to access `/orders/124` just by changing the ID. This sounds obvious and gets missed constantly.

---

## The Code

### Rate limiting middleware (ASP.NET Core)
```csharp
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("api", limiter =>
    {
        limiter.PermitLimit = 100;
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        limiter.QueueLimit = 0; // reject immediately when limit hit
    });
});

app.UseRateLimiter();

// Apply to specific endpoints
app.MapGet("/orders", GetOrders).RequireRateLimiting("api");
```

### Object-level authorization (prevent BOLA)
```csharp
app.MapGet("/orders/{id}", async (int id, HttpContext ctx, OrderService svc) =>
{
    var userId = int.Parse(ctx.User.FindFirst("sub")!.Value);
    var order = await svc.GetByIdAsync(id);

    if (order is null) return Results.NotFound();

    // CRITICAL: verify the resource belongs to the requesting user
    if (order.UserId != userId) return Results.Forbid();

    return Results.Ok(order);
});
```

### Input validation (prevent injection)
```csharp
public record CreateOrderRequest(
    [Required, Range(1, 10000)] decimal Total,
    [Required, MaxLength(200), RegularExpression(@"^[a-zA-Z0-9\s\-]+$")] string Description
);

app.MapPost("/orders", async (
    [FromBody] CreateOrderRequest req,  // model binding validates attributes
    OrderService svc) =>
{
    // Never interpolate req fields directly into SQL — use parameterized queries
    await svc.CreateAsync(req.Total, req.Description);
    return Results.Created();
});
```

### Security headers middleware
```csharp
app.Use(async (ctx, next) =>
{
    ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
    ctx.Response.Headers["X-Frame-Options"]        = "DENY";
    ctx.Response.Headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains";
    ctx.Response.Headers["Content-Security-Policy"] = "default-src 'self'";
    await next();
});
```

---

## Gotchas

- **BOLA is not the same as authentication failure** — the user is authenticated; they're just accessing a resource that isn't theirs. It's an authorization bug, and it's the most common API vulnerability in production because it requires per-object ownership checks, not just a middleware flag.
- **HTTP 401 vs 403 is not cosmetic** — 401 means "not authenticated" (include credentials); 403 means "authenticated but not authorized" (don't bother retrying with the same credentials). Getting these wrong confuses clients and leaks information about your auth model.
- **Verbose error messages are an information leak** — returning stack traces, SQL errors, or internal IDs in 500 responses tells attackers about your stack. Log the detail server-side; return a generic error message to clients.
- **CORS misconfiguration is a real vulnerability** — `Access-Control-Allow-Origin: *` on an authenticated API means any malicious website can make credentialed requests using a logged-in user's cookies. Whitelist origins explicitly.
- **API versioning + security means old versions stay vulnerable** — if you fix a BOLA bug in v2 but leave v1 running, attackers use v1. Deprecated API versions must be decommissioned, not just undocumented.

---

## Interview Angle

**What they're really testing:** Whether you think about security as a system-level concern, not just "add JWT validation."

**Common question form:** "How would you secure this API?" or "What vulnerabilities would you look for in a code review of an API endpoint?"

**The depth signal:** A junior says "add authentication and use HTTPS." A senior names BOLA specifically (not just "authorization"), discusses rate limiting strategies (fixed window vs token bucket), explains the difference between authentication and authorization at the object level, knows about the OWASP API Security Top 10, and can describe how they'd do a threat model on a new endpoint before writing code.

---

## Related Topics

- [[system-design/authentication-patterns.md]] — Authentication is the first layer of API security.
- [[system-design/jwt-deep-dive.md]] — JWT validation vulnerabilities are a subset of API security risks.
- [[system-design/secret-management.md]] — API keys and credentials used by the API must be managed securely.
- [[system-design/oauth2-openid.md]] — OAuth2 scopes are the mechanism for coarse-grained API authorization.

---

## Source

https://owasp.org/API-Security/editions/2023/en/0x00-header/

---

*Last updated: 2026-03-24*