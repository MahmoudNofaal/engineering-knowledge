# WebAPI CORS

> A browser security mechanism that controls which frontend origins are allowed to make HTTP requests to your API — configured on the server, enforced by the browser.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Server-side HTTP headers that tell browsers which cross-origin requests are allowed |
| **Use when** | Browser frontend on a different origin needs to call your API |
| **Avoid when** | Server-to-server calls — CORS is a browser-only constraint |
| **Introduced** | ASP.NET Core 1.0 |
| **Namespace** | `Microsoft.AspNetCore.Cors` |
| **Key types** | `CorsPolicy`, `CorsPolicyBuilder`, `CorsOptions`, `ICorsPolicyProvider` |

---

## When To Use It

Use it any time a browser-based frontend on one origin (e.g. `https://app.example.com`) needs to call an API on a different origin (different domain, port, or scheme). Without CORS headers on the API response, the browser blocks the response before your JavaScript ever sees it. You don't need CORS for server-to-server calls — it's purely a browser constraint. Don't set `AllowAnyOrigin` in production; that defeats the entire purpose of the mechanism and exposes your API to cross-site request forgery from any website.

---

## Core Concept

The browser enforces a "same-origin policy" by default — a page at `https://app.example.com` can't read responses from `https://api.example.com` unless the API explicitly says it's okay. The way the API does that is by returning `Access-Control-Allow-Origin` (and related headers) in its responses. For simple requests the browser just checks the response header after the fact. For non-simple requests (anything with a custom header, or methods like PUT/DELETE/PATCH), the browser sends a preflight `OPTIONS` request first to ask "are you going to allow this?" — and the API has to respond correctly before the browser sends the real request. ASP.NET Core's CORS middleware handles all of this: you define a named policy with the origins, methods, and headers you allow, then apply it globally or per-endpoint.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | `AddCors`, `UseCors`, `[EnableCors]`, `[DisableCors]` introduced |
| ASP.NET Core 2.0 | `CorsPolicyBuilder` improvements; `AllowAnyOriginWithPreflightMaxAge` added |
| ASP.NET Core 3.0 | Endpoint routing: `UseCors` ordering relative to `UseRouting` became strict |
| .NET 6 | `.RequireCors()` and `.DisableCors()` on minimal API endpoints |
| .NET 8 | CORS policy can be applied to route groups |

*The ASP.NET Core 3.0 change that made `UseCors` order-sensitive relative to `UseRouting` broke many existing apps on upgrade — `UseCors` must come after `UseRouting` but before `UseAuthentication` for endpoint-specific CORS policies to work.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| CORS header write (no preflight) | ~1 µs | Header string append; negligible |
| Preflight `OPTIONS` response | ~5–50 µs | Policy lookup + header write; no action execution |
| Policy evaluation | O(n) | n = number of allowed origins; linear scan |

**Allocation behaviour:** CORS middleware allocates `CorsResult` and origin string comparisons per request. For APIs with many origins in `WithOrigins(...)`, the linear scan allocates string comparison objects. Prefer a hash-based `ICorsPolicyProvider` for APIs with hundreds of dynamic allowed origins.

**Benchmark notes:** CORS overhead is unmeasurable compared to any real workload. The only scenario where it matters is extremely high-frequency preflight OPTIONS requests — which is usually a client-side bug (incorrect caching of preflight, missing `Access-Control-Max-Age`).

---

## The Code

**Define and apply a CORS policy in Program.cs**
```csharp
var MyPolicy = "MyFrontendPolicy";

builder.Services.AddCors(options =>
{
    options.AddPolicy(MyPolicy, policy =>
    {
        policy
            .WithOrigins(
                "https://app.example.com",
                "https://staging.example.com")
            .WithMethods("GET", "POST", "PUT", "DELETE")
            .WithHeaders("Authorization", "Content-Type")
            .AllowCredentials()         // required if frontend sends cookies or Auth headers
            .SetPreflightMaxAge(TimeSpan.FromHours(1)); // cache preflight for 1 hour
    });
});

var app = builder.Build();
app.UseRouting();
app.UseCors(MyPolicy);              // after UseRouting, before UseAuthentication
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
```

**Development-only permissive policy**
```csharp
if (app.Environment.IsDevelopment())
{
    builder.Services.AddCors(options =>
    {
        options.AddPolicy("DevOnly", policy =>
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader());
            // AllowAnyOrigin() and AllowCredentials() cannot be combined — spec violation
    });
}
```

**Per-endpoint override**
```csharp
app.MapGet("/api/public", () => "open")
   .RequireCors("PublicPolicy");

app.MapGet("/api/admin", () => "restricted")
   .RequireCors("AdminPolicy");
```

**Controller-level and action-level attributes**
```csharp
[ApiController]
[Route("api/[controller]")]
[EnableCors("MyFrontendPolicy")]
public class ProductsController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll() => Ok();

    [HttpPost]
    [DisableCors]                   // opt-out this specific action
    public IActionResult Create() => Ok();
}
```

**Environment-driven origins from configuration**
```csharp
var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? [];

builder.Services.AddCors(options =>
{
    options.AddPolicy("Configured", policy =>
        policy.WithOrigins(allowedOrigins)
              .WithMethods("GET", "POST", "PUT", "DELETE")
              .WithHeaders("Authorization", "Content-Type"));
});
```
```json
{
  "Cors": {
    "AllowedOrigins": ["https://app.example.com"]
  }
}
```

---

## Real World Example

A SaaS product has three environments (dev, staging, prod), each with a different frontend origin. A fourth "admin panel" frontend is served from a completely different domain and uses a separate stricter CORS policy with `AllowCredentials`. Origins are driven by configuration, not hardcoded.

```csharp
// Program.cs
var appOrigins   = builder.Configuration.GetSection("Cors:AppOrigins").Get<string[]>() ?? [];
var adminOrigins = builder.Configuration.GetSection("Cors:AdminOrigins").Get<string[]>() ?? [];

builder.Services.AddCors(options =>
{
    // Standard app policy — no credentials (uses Bearer tokens in Authorization header)
    options.AddPolicy("AppPolicy", policy =>
        policy.WithOrigins(appOrigins)
              .WithMethods("GET", "POST", "PUT", "DELETE", "PATCH")
              .WithHeaders("Authorization", "Content-Type", "X-Correlation-Id")
              .SetPreflightMaxAge(TimeSpan.FromHours(2)));

    // Admin panel — uses HttpOnly cookies for session, requires AllowCredentials
    options.AddPolicy("AdminPolicy", policy =>
        policy.WithOrigins(adminOrigins)        // must enumerate origins — no wildcard with credentials
              .WithMethods("GET", "POST", "PUT", "DELETE")
              .WithHeaders("Authorization", "Content-Type")
              .AllowCredentials()
              .SetPreflightMaxAge(TimeSpan.FromMinutes(10)));
});

var app = builder.Build();
app.UseRouting();
app.UseCors("AppPolicy");           // default policy for all endpoints

// Admin endpoints override with stricter policy
app.MapGroup("/api/admin")
   .RequireCors("AdminPolicy")
   .RequireAuthorization("AdminOnly");
```
```json
// appsettings.Production.json
{
  "Cors": {
    "AppOrigins": ["https://app.example.com", "https://app-eu.example.com"],
    "AdminOrigins": ["https://admin.example.com"]
  }
}
```

*The key insight: CORS policy names and allowed origins are configuration, not code. Deploying to a new region or adding a new frontend domain is a config change, not a code change. The separation of "AppPolicy" (no credentials) and "AdminPolicy" (with credentials and shorter preflight cache) reflects the real different security requirements of the two frontends.*

---

## Common Misconceptions

**"CORS is a server security mechanism that prevents attackers from calling my API."**
CORS is a browser restriction. A determined attacker using curl, Postman, a Python script, or any non-browser tool bypasses CORS entirely — the server still processes the request, it just doesn't send the `Access-Control-Allow-Origin` header. CORS protects legitimate users from being tricked by malicious websites into making unintended cross-origin requests from their browser. It is not a substitute for authentication and authorization.

**"Setting `AllowAnyOrigin` is fine if I also require authentication."**
Even with authentication, `AllowAnyOrigin` removes the protection against cross-site request forgery from the browser. A malicious website can make authenticated requests on behalf of a logged-in user if CORS allows any origin. The combination of `AllowAnyOrigin` with cookie authentication or `AllowCredentials` is actually forbidden by the spec — the framework throws at startup if you combine them.

**"CORS errors mean my API is returning an error."**
CORS failures look like network errors in the browser (`Failed to fetch`, `CORS error`) even when the API returned a perfectly valid 200 response. The browser blocks your JavaScript from reading the response — the response itself arrived and was processed by the browser, just not made available to your code. Always check the browser's Network tab, not just the console, to see what the actual API response was.

---

## Gotchas

- **`AllowAnyOrigin()` and `AllowCredentials()` cannot be used together — the framework throws at startup.** `Access-Control-Allow-Origin: *` is incompatible with `Access-Control-Allow-Credentials: true` per the CORS spec. If you need credentials, you must enumerate origins explicitly with `WithOrigins(...)`.

- **`app.UseCors()` must come after `UseRouting()` but before `UseAuthentication()` and `UseAuthorization()`.** Placing it before `UseRouting` means endpoint-specific CORS policies (`.RequireCors()`) never apply. Placing it after `UseAuthentication` means preflight `OPTIONS` requests may fail authentication before CORS headers are added. The resulting error looks like an auth problem, not a CORS problem.

- **CORS errors in the browser are not visible in your API logs.** The API returned a valid response — the browser silently blocked it on the client side. When debugging, check the browser's Network tab for the preflight `OPTIONS` request and its response headers, not your server logs.

- **A trailing slash mismatch in `WithOrigins` causes silent CORS failures.** `WithOrigins("https://app.example.com")` and `WithOrigins("https://app.example.com/")` are treated as different origins. Always match the origin exactly as the browser sends it — no trailing slash, no path component.

- **Preflight responses are cached by the browser based on `Access-Control-Max-Age`.** If you change your CORS policy (add a new header, change an origin), browsers that cached the old preflight response continue using the old rules until the cache expires. During debugging, force a fresh preflight by testing in an incognito window or setting `SetPreflightMaxAge(TimeSpan.Zero)` temporarily.

- **`[DisableCors]` on an action disables CORS entirely for that action — including returning the `Access-Control-Allow-Origin` header.** If your action is accessed cross-origin without CORS headers, the browser blocks it. Use `[DisableCors]` only for actions that will never be called cross-origin (e.g., server-to-server endpoints reachable only from your backend network).

---

## Interview Angle

**What they're really testing:** Whether you understand that CORS is a browser constraint (not a server security mechanism on its own), how preflights work, and why `AllowAnyOrigin` is dangerous in production.

**Common question forms:**
- "How do you configure CORS in ASP.NET Core?"
- "Why is my frontend getting a CORS error even though the API returns 200?"
- "What's a preflight request and when does the browser send one?"
- "Why can't you use `AllowAnyOrigin` with `AllowCredentials`?"

**The depth signal:** A junior describes adding `AddCors` and `UseCors` with `AllowAnyOrigin`. A senior explains the preflight `OPTIONS` flow and when it triggers (non-simple requests: custom headers, non-GET/POST/HEAD methods), why `AllowAnyOrigin` + `AllowCredentials` is spec-illegal and throws at runtime, why middleware ordering matters (after `UseRouting`, before `UseAuthentication`), why CORS failures are invisible in server logs and where to find them (Network tab), and that CORS is a browser guardrail — a server-side attacker ignores it entirely, so it's not a substitute for authentication and authorization.

**Follow-up questions to expect:**
- "How would you handle CORS for a multi-tenant app where allowed origins come from the database?"
- "What's the difference between simple requests and non-simple requests in CORS?"
- "How does the browser cache preflight responses and how does that affect debugging?"

---

## Related Topics

- [[dotnet/webapi/middleware-pipeline.md]] — CORS is middleware with strict ordering requirements; `UseCors` position relative to `UseRouting` and `UseAuthentication` directly determines whether preflight responses are handled correctly
- [[dotnet/webapi/webapi-authentication.md]] — credentialed CORS requests (cookies, Authorization headers) require `AllowCredentials()`, which forces you to enumerate origins explicitly rather than use wildcards
- [[dotnet/webapi/webapi-configuration.md]] — allowed origins should come from environment-specific configuration rather than being hardcoded; the config pipeline is the right place to manage per-environment origin lists
- [[dotnet/webapi/webapi-authorization.md]] — CORS is commonly confused with authorization; CORS controls browser access by origin, authorization controls access by identity — they solve different problems and both are needed

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/security/cors

---
*Last updated: 2026-04-10*