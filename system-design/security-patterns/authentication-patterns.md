# Authentication Patterns

> The set of approaches for verifying that a user or service is who they claim to be — from session cookies to tokens to federated identity.

---

## When To Use It

Every system that has users or service-to-service communication needs an authentication pattern. The right pattern depends on who is authenticating (humans vs machines), where sessions need to be valid (single server vs distributed), and what trust model you're operating in. Don't build your own authentication from scratch — use established patterns and battle-tested libraries. The most expensive auth bugs are the ones you don't find until a breach.

---

## Core Concept

Authentication answers "who are you?" — authorization answers "what are you allowed to do?" They're separate concerns that get conflated constantly. The three dominant patterns are: (1) session-based auth, where the server stores session state and gives the client a cookie that references it; (2) token-based auth (JWT), where the server signs a self-contained token that the client presents on every request and the server validates without any stored state; (3) federated identity (OAuth2/OIDC), where you delegate the authentication to a trusted third party (Google, Azure AD) and receive a token confirming the user authenticated there. Each pattern shifts where trust, state, and complexity live.

---

## The Code

### Session-based auth (ASP.NET Core)
```csharp
// Server stores session; client holds only a session cookie
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.HttpOnly = true;   // not accessible via JS
    options.Cookie.IsEssential = true;
});

app.UseSession();

// Login endpoint — sets session on successful auth
app.MapPost("/login", (HttpContext ctx, LoginRequest req) =>
{
    if (ValidateCredentials(req.Username, req.Password))
    {
        ctx.Session.SetString("userId", GetUserId(req.Username));
        return Results.Ok();
    }
    return Results.Unauthorized();
});
```

### Token-based auth — issuing a JWT
```csharp
using System.IdentityModel.Tokens.Jwt;
using Microsoft.IdentityModel.Tokens;

public string IssueToken(string userId, string secret)
{
    var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
    var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

    var token = new JwtSecurityToken(
        issuer: "my-api",
        audience: "my-client",
        claims: new[] { new Claim("sub", userId) },
        expires: DateTime.UtcNow.AddHours(1),
        signingCredentials: creds
    );

    return new JwtSecurityTokenHandler().WriteToken(token);
}
```

### Validating a JWT in middleware
```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = "my-api",
            ValidateAudience = true,
            ValidAudience = "my-client",
            ValidateLifetime = true,           // rejects expired tokens
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(config["Jwt:Secret"]))
        };
    });
```

---

## Gotchas

- **JWTs can't be invalidated before expiry** — once issued, a JWT is valid until it expires. If a user logs out or is banned, the token still works. Mitigate with short expiry + refresh tokens, or maintain a token denylist (which reintroduces state).
- **Storing JWTs in localStorage exposes them to XSS** — any injected script can read `localStorage`. HttpOnly cookies prevent this. The choice is between CSRF risk (cookies) and XSS risk (localStorage).
- **Session auth requires sticky sessions or shared state in distributed systems** — if a user's session is on server A and their next request hits server B, they're logged out. Fix with Redis-backed session stores.
- **"Remember me" functionality needs a separate secure token** — don't extend session lifetime indefinitely. Issue a long-lived, rotatable refresh token stored securely and exchange it for short-lived access tokens.
- **Comparing passwords without constant-time comparison leaks timing information** — use `CryptographicOperations.FixedTimeEquals()` or your library's built-in compare, never `==` on raw strings.

---

## Interview Angle

**What they're really testing:** Whether you understand stateless vs stateful auth, the security trade-offs between storage locations, and distributed system implications.

**Common question form:** "How would you implement authentication for a distributed microservices system?" or "What's the difference between session auth and JWT?"

**The depth signal:** A junior explains that JWTs are tokens you store and send. A senior discusses the revocation problem, compares HttpOnly cookie vs Authorization header storage security, explains why short-lived access tokens + refresh token rotation is the production pattern, and knows that OAuth2 is an authorization protocol — not an authentication protocol (that's what OIDC adds).

---

## Related Topics

- [[system-design/oauth2-openid.md]] — The federated identity layer built on top of these patterns.
- [[system-design/jwt-deep-dive.md]] — The internals of JWT structure, signing, and validation.
- [[system-design/api-security.md]] — Authentication is one layer; API security covers the broader threat surface.

---

## Source

https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html

---

*Last updated: 2026-03-24*