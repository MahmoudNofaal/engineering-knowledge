# WebAPI Authentication

> The ASP.NET Core mechanism for verifying who is making a request — most commonly by validating a JWT bearer token attached to the `Authorization` header.

---

## When To Use It

Use it any time your API has endpoints that should only be accessible to identified users or services. JWT bearer authentication is the standard choice for stateless APIs — the token carries the identity claims, so the server doesn't need a session store. Don't use cookie authentication for APIs consumed by mobile clients or third-party services; that's designed for browser-based flows. If your API is purely internal and runs inside a private network with mTLS, you may not need application-level auth at all — but that's an infrastructure decision, not a default.

---

## Core Concept

Authentication in ASP.NET Core is middleware that runs before your controllers. It inspects the incoming request, finds the token (from the `Authorization: Bearer <token>` header), validates it — signature, issuer, audience, expiry — and if valid, builds a `ClaimsPrincipal` and attaches it to `HttpContext.User`. From that point on, every piece of code in that request can read `User.Identity.Name` or `User.FindFirst("email")` without knowing anything about JWT. If the token is missing or invalid, the middleware sets the principal to anonymous and moves on — it's `[Authorize]` on the endpoint that actually rejects the request with a 401. Authentication proves identity; authorization decides access.

---

## The Code

**1. Install the NuGet package**
```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

**2. Register JWT bearer in Program.cs**
```csharp
// Program.cs
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

            ValidIssuer      = builder.Configuration["Jwt:Issuer"],
            ValidAudience    = builder.Configuration["Jwt:Audience"],

            // Key used to verify the token signature
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!))
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication(); // must come before UseAuthorization
app.UseAuthorization();
```

**3. appsettings.json (never put real keys here — use secrets/env vars)**
```json
{
  "Jwt": {
    "Issuer":   "https://yourapp.com",
    "Audience": "https://yourapp.com",
    "Key":      "replace-with-secret-via-env-var"
  }
}
```

**4. Generate a JWT token (login endpoint)**
```csharp
// Services/TokenService.cs
public string GenerateToken(User user)
{
    var claims = new[]
    {
        new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
        new Claim(ClaimTypes.Email,          user.Email),
        new Claim(ClaimTypes.Role,           user.Role)
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

**5. Protect endpoints with [Authorize]**
```csharp
// Controllers/OrdersController.cs
[ApiController]
[Route("api/[controller]")]
[Authorize] // applies to all actions in this controller
public class OrdersController : ControllerBase
{
    [HttpGet("{id}")]
    public IActionResult GetOrder(int id)
    {
        // User is guaranteed authenticated here
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Ok(userId);
    }

    [AllowAnonymous] // overrides the controller-level [Authorize]
    [HttpGet("health")]
    public IActionResult Health() => Ok();

    [Authorize(Roles = "Admin")] // requires role claim
    [HttpDelete("{id}")]
    public IActionResult DeleteOrder(int id) => NoContent();
}
```

**6. Read claims from HttpContext.User anywhere in the pipeline**
```csharp
// Works in controllers, minimal API handlers, or services with IHttpContextAccessor
var email  = User.FindFirstValue(ClaimTypes.Email);
var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
var isAdmin = User.IsInRole("Admin");
```

---

## Gotchas

- **`UseAuthentication()` must come before `UseAuthorization()` in the pipeline.** Swapping them means the claims principal is never populated before the authorization check runs — every `[Authorize]` endpoint returns 401 even with a valid token, with no error explaining why.
- **A missing or invalid token returns 401; an authenticated user without the right role or policy returns 403.** These are different status codes with different meanings. Many implementations return 401 for both, which is incorrect and confuses clients. `[Authorize(Roles = "Admin")]` on an authenticated non-admin should return 403, not 401.
- **`DateTime.UtcNow` vs `DateTime.Now` in token expiry.** JWTs use UTC timestamps (`exp` claim). If you generate a token with `DateTime.Now` in a non-UTC server timezone, the expiry will be wrong and tokens will appear to expire early or late. Always use `DateTime.UtcNow`.
- **Short-lived tokens without a refresh strategy cause silent client failures.** A 1-hour token sounds safe, but if your frontend doesn't implement refresh logic, users get logged out mid-session with a 401 they don't understand. Plan the refresh flow before choosing the expiry window.
- **Symmetric keys must be at least 128 bits (16 bytes) for HMAC-SHA256 — but 256 bits (32 bytes) is the minimum you should use in production.** A key shorter than 128 bits causes a `SecurityTokenInvalidSignatureException` at runtime. A key shorter than 256 bits is technically valid but weak. Pull the key from secrets management, never from a short hardcoded string.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between authentication and authorization, how JWT validation actually works, and where the middleware fits in the request pipeline.

**Common question form:** *"How do you secure an ASP.NET Core Web API?"* or *"Walk me through how JWT authentication works end-to-end."*

**The depth signal:** A junior answer describes adding `[Authorize]` and returning a token from a login endpoint. A senior answer explains the full validation chain (`ValidateIssuer`, `ValidateAudience`, `ValidateLifetime`, `ValidateIssuerSigningKey`), why `UseAuthentication` must precede `UseAuthorization` in the pipeline, the 401 vs 403 distinction and when each fires, the risks of symmetric vs asymmetric keys (HS256 vs RS256) and when you'd use each, and why storing the signing key in `appsettings.json` in source control is a production security incident.

---

## Related Topics

- [[dotnet/webapi-authorization.md]] — Authentication proves who you are; authorization decides what you can do. Policies, roles, and resource-based checks build on top of the claims populated here.
- [[dotnet/webapi-exception-handling.md]] — 401 and 403 responses from auth middleware bypass your global exception handler; understanding both systems prevents gaps in your error response contract.
- [[dotnet/webapi-configuration.md]] — JWT signing keys and issuer settings must come from the configuration pipeline — specifically from secrets or environment variables, not committed JSON.
- [[dotnet/middleware-pipeline.md]] — Authentication is middleware with strict ordering requirements; understanding the pipeline makes the `UseAuthentication` / `UseAuthorization` ordering constraint obvious rather than arbitrary.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/security/authentication/jwt-authn

---
*Last updated: 2026-03-24*