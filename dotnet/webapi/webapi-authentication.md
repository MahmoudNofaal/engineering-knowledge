# WebAPI Authentication

> The ASP.NET Core mechanism for verifying who is making a request — most commonly by validating a JWT bearer token attached to the `Authorization` header.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Middleware that validates identity tokens and populates `HttpContext.User` |
| **Use when** | Any endpoint that should only be accessible to identified users or services |
| **Avoid when** | Truly public APIs with no per-user behaviour — but still use for auditing |
| **Introduced** | ASP.NET Core 1.0; JWT Bearer added ASP.NET Core 1.0 via NuGet |
| **Namespace** | `Microsoft.AspNetCore.Authentication`, `Microsoft.AspNetCore.Authentication.JwtBearer` |
| **Key types** | `JwtBearerOptions`, `TokenValidationParameters`, `ClaimsPrincipal`, `IAuthenticationService` |

---

## When To Use It

Use it any time your API has endpoints that should only be accessible to identified users or services. JWT bearer authentication is the standard choice for stateless APIs — the token carries the identity claims, so the server doesn't need a session store. Don't use cookie authentication for APIs consumed by mobile clients or third-party services; that's designed for browser-based flows. If your API is purely internal and runs inside a private network with mTLS, you may not need application-level auth at all — but that's an infrastructure decision, not a default.

---

## Core Concept

Authentication in ASP.NET Core is middleware that runs before your controllers. It inspects the incoming request, finds the token (from the `Authorization: Bearer <token>` header), validates it — signature, issuer, audience, expiry — and if valid, builds a `ClaimsPrincipal` and attaches it to `HttpContext.User`. From that point on, every piece of code in that request can read `User.Identity.Name` or `User.FindFirst("email")` without knowing anything about JWT. If the token is missing or invalid, the middleware sets the principal to anonymous and moves on — it's `[Authorize]` on the endpoint that actually rejects the request with a 401. Authentication proves identity; authorization decides access.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | Cookie authentication, JWT Bearer via `Microsoft.AspNetCore.Authentication.JwtBearer` |
| ASP.NET Core 2.0 | Authentication middleware refactored; `AddAuthentication()` / `AddJwtBearer()` pattern |
| ASP.NET Core 3.0 | `UseAuthentication()` must be explicitly registered (was implicit in 2.x templates) |
| .NET 6 | `JwtBearerOptions.TokenValidationParameters` improved; `MapControllers` + auth simplified |
| .NET 7 | `[Authorize]` on minimal API endpoints via `.RequireAuthorization()` |
| .NET 8 | `JwtBearerEvents` improved; `IAuthenticationHandlerProvider` refinements |

*In ASP.NET Core 2.x, authentication was partially implicit. From 3.0 onward, you must explicitly call `app.UseAuthentication()` — forgetting it is a common upgrade bug where all endpoints suddenly return 401 even with valid tokens.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| JWT signature validation | ~5–20 µs | RSA-256 is slower than HS256; both are negligible vs I/O |
| Claims principal construction | ~1–5 µs | Claim objects are small allocations |
| Token parsing | ~2–10 µs | String operations on the header value |
| Validation result caching | N/A | No built-in caching; every request validates the full token |

**Allocation behaviour:** Each JWT validation allocates a `ClaimsPrincipal` with `ClaimsIdentity` containing the token's claims. For tokens with many claims this can be non-trivial. Avoid putting large data payloads (full user records, permission lists) in JWT claims — use a reference ID and look up permissions from a cache on the server side.

**Benchmark notes:** Authentication middleware overhead is negligible compared to I/O. The scenario to watch is very large JWT payloads (>4 KB) where base64 decoding and claim parsing become measurable. Keep JWTs lean — sub, email, role, exp, iat, and a few custom claims is typical.

---

## The Code

**Install the NuGet package**
```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

**Register JWT bearer in Program.cs**
```csharp
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer           = true,
            ValidateAudience         = true,
            ValidateLifetime         = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer              = builder.Configuration["Jwt:Issuer"],
            ValidAudience            = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey         = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!))
        };

        // Customise challenge/forbidden responses
        options.Events = new JwtBearerEvents
        {
            OnChallenge = ctx =>
            {
                ctx.HandleResponse();
                ctx.Response.StatusCode  = 401;
                ctx.Response.ContentType = "application/problem+json";
                return ctx.Response.WriteAsJsonAsync(new ProblemDetails
                {
                    Status = 401,
                    Title  = "Authentication required."
                });
            }
        };
    });

builder.Services.AddAuthorization();
app.UseAuthentication(); // must come before UseAuthorization
app.UseAuthorization();
```

**Generate a JWT token (login endpoint)**
```csharp
public string GenerateToken(User user)
{
    var claims = new[]
    {
        new Claim(JwtRegisteredClaimNames.Sub,   user.Id.ToString()),
        new Claim(JwtRegisteredClaimNames.Email, user.Email),
        new Claim(JwtRegisteredClaimNames.Jti,   Guid.NewGuid().ToString()),
        new Claim(ClaimTypes.Role,               user.Role)
    };

    var key   = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Key"]!));
    var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

    var token = new JwtSecurityToken(
        issuer:             _config["Jwt:Issuer"],
        audience:           _config["Jwt:Audience"],
        claims:             claims,
        expires:            DateTime.UtcNow.AddHours(1),
        signingCredentials: creds
    );

    return new JwtSecurityTokenHandler().WriteToken(token);
}
```

**Protect endpoints with `[Authorize]`**
```csharp
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class OrdersController : ControllerBase
{
    [HttpGet("{id}")]
    public IActionResult GetOrder(int id)
    {
        var userId = User.FindFirstValue(JwtRegisteredClaimNames.Sub);
        return Ok(userId);
    }

    [AllowAnonymous]
    [HttpGet("public")]
    public IActionResult PublicEndpoint() => Ok();

    [Authorize(Roles = "Admin")]
    [HttpDelete("{id}")]
    public IActionResult Delete(int id) => NoContent();
}
```

**Asymmetric key (RS256) — preferred for production with an external IdP**
```csharp
// RS256: the IdP signs with its private key; your API validates with the public key
// You never need the private key in your API — it stays in the IdP
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        // For Auth0, Azure AD, Keycloak etc — they expose a JWKS endpoint
        options.Authority = "https://your-idp.example.com";
        options.Audience  = "https://your-api.example.com";
        // Framework fetches and caches the public keys from the JWKS endpoint automatically
    });
```

---

## Real World Example

A B2B SaaS API supports both end-user JWT tokens (from the app's own IdP) and machine-to-machine API keys (from a custom scheme). Two authentication schemes are registered; the first that succeeds wins.

```csharp
// Custom API key scheme
public class ApiKeyAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    IApiKeyRepository keys)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue("X-Api-Key", out var apiKeyHeader))
            return AuthenticateResult.NoResult();

        var apiKey = await keys.FindAsync(apiKeyHeader!);
        if (apiKey is null)
            return AuthenticateResult.Fail("Invalid API key.");

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, apiKey.ClientId),
            new Claim(ClaimTypes.Name,           apiKey.ClientName),
            new Claim(ClaimTypes.Role,           "ServiceAccount")
        };

        var identity  = new ClaimsIdentity(claims, Scheme.Name);
        var principal = new ClaimsPrincipal(identity);
        return AuthenticateResult.Success(new AuthenticationTicket(principal, Scheme.Name));
    }
}

// Program.cs — register both schemes
builder.Services
    .AddAuthentication(options =>
    {
        options.DefaultScheme          = "Multi";
        options.DefaultChallengeScheme = "Multi";
    })
    .AddPolicyScheme("Multi", "JWT or API Key", options =>
    {
        options.ForwardDefaultSelector = ctx =>
            ctx.Request.Headers.ContainsKey("X-Api-Key")
                ? "ApiKey"
                : JwtBearerDefaults.AuthenticationScheme;
    })
    .AddJwtBearer(options => { /* standard JWT config */ })
    .AddScheme<AuthenticationSchemeOptions, ApiKeyAuthenticationHandler>("ApiKey", null);
```

*The key insight: authentication is decoupled from what the token looks like. A custom `AuthenticationHandler<T>` gives you complete control over how identity is established — whether from a JWT, an API key, a client certificate, or anything else — without changing any controller code. Controllers just read `HttpContext.User`.*

---

## Common Misconceptions

**"Authentication and authorization are the same thing."**
Authentication answers "who are you?" — it validates the token and builds `HttpContext.User`. Authorization answers "are you allowed to do this?" — it checks that user's claims against policies and roles. They're separate middleware components registered in a specific order. Getting them confused leads to bugs like putting permission checks in authentication handlers or expecting `[Authorize]` alone to validate tokens.

**"A valid JWT means the user is authenticated."**
A structurally valid JWT (correctly signed, not expired) means the token was issued by a trusted issuer. It does not mean the user is still active, hasn't been banned, or that the token hasn't been revoked. JWTs are stateless — there's no built-in revocation. If you need immediate revocation (e.g., on logout or account suspension), you must maintain a token blacklist or use short expiry times with a revocation check.

**"The signing key can be any string."**
For HMAC-SHA256, the key must be at least 128 bits (16 bytes) — the framework throws at runtime for shorter keys. In practice, use at least 256 bits (32 bytes / 32 random characters). A human-readable string like `"mysecretkey"` is too short and too predictable. Generate keys with `RandomNumberGenerator.GetBytes(32)` and store them in a secrets manager.

---

## Gotchas

- **`UseAuthentication()` must come before `UseAuthorization()` in the pipeline.** Swapping them means the claims principal is never populated before the authorization check runs — every `[Authorize]` endpoint returns 401 even with a valid token, with no error explaining why.

- **A missing or invalid token returns 401; an authenticated user without the right role or policy returns 403.** These are different status codes. `[Authorize(Roles = "Admin")]` on an authenticated non-admin should return 403, not 401. Many implementations return 401 for both, which is incorrect and confuses clients. Customise `OnForbidden` in `JwtBearerEvents` to fix this.

- **`DateTime.UtcNow` vs `DateTime.Now` in token expiry.** JWTs use UTC timestamps (`exp` claim). Generating a token with `DateTime.Now` in a non-UTC server timezone causes tokens to expire early or late. Always use `DateTime.UtcNow`.

- **Short-lived tokens without a refresh strategy cause silent client failures.** A 1-hour token sounds safe, but if your frontend doesn't implement refresh logic, users get logged out mid-session with a 401. Plan the refresh flow before choosing the expiry window.

- **Symmetric keys (HS256) mean the API server can forge tokens.** With HS256, any service that has the signing key can create valid tokens — not just your IdP. For multi-service architectures, use RS256 or ES256 with an asymmetric key pair. The IdP holds the private key; APIs validate with the public key via the JWKS endpoint.

- **The JWKS cache has a default refresh interval that may not match your key rotation schedule.** When using an external IdP (Auth0, Azure AD) with automatic key rotation, the JWT middleware caches the public keys and refreshes them periodically. If a key rotates while the old key is still cached, validation fails until the cache refreshes. Configure `options.RefreshOnIssuerKeyNotFound = true` to trigger an immediate JWKS refresh on validation failure.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between authentication and authorization, how JWT validation actually works end-to-end, and where the middleware fits in the request pipeline.

**Common question forms:**
- "How do you secure an ASP.NET Core Web API?"
- "Walk me through how JWT authentication works end-to-end."
- "What's the difference between HS256 and RS256?"
- "How would you implement token revocation with JWTs?"

**The depth signal:** A junior describes adding `[Authorize]` and returning a token from a login endpoint. A senior explains the full validation chain (`ValidateIssuer`, `ValidateAudience`, `ValidateLifetime`, `ValidateIssuerSigningKey`), why `UseAuthentication` must precede `UseAuthorization`, the 401 vs 403 distinction and when each fires, the risks of symmetric vs asymmetric keys and when you'd use each, and why storing the signing key in `appsettings.json` in source control is a production security incident. Bonus signal: knowing that JWTs are stateless and have no built-in revocation — and the strategies to work around this (short expiry + refresh tokens, token blacklist in Redis, opaque tokens with introspection).

**Follow-up questions to expect:**
- "How would you support multiple authentication schemes in the same API?"
- "How do you handle token revocation when a user logs out?"
- "What's the difference between `[Authorize]` returning 401 and 403?"

---

## Related Topics

- [[dotnet/webapi/webapi-authorization.md]] — authentication proves who you are; authorization decides what you can do — policies, roles, and resource-based checks build on top of the claims populated by authentication
- [[dotnet/webapi/middleware-pipeline.md]] — `UseAuthentication` and `UseAuthorization` have strict ordering requirements; understanding the pipeline makes this ordering constraint obvious
- [[dotnet/webapi/webapi-exception-handling.md]] — 401 and 403 responses from auth middleware bypass the global exception handler; knowing both systems prevents gaps in the error response contract
- [[dotnet/webapi/webapi-configuration.md]] — JWT signing keys and issuer settings must come from secrets or environment variables, not committed JSON files

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/security/authentication/jwt-authn

---
*Last updated: 2026-04-10*