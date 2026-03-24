# WebAPI CORS

> A browser security mechanism that controls which frontend origins are allowed to make HTTP requests to your API — configured on the server, enforced by the browser.

---

## When To Use It

Use it any time a browser-based frontend on one origin (e.g. `https://app.example.com`) needs to call an API on a different origin (different domain, port, or scheme). Without CORS headers on the API response, the browser blocks the response before your JavaScript ever sees it. You don't need CORS for server-to-server calls — it's purely a browser constraint. Don't set `AllowAnyOrigin` in production; that defeats the entire purpose of the mechanism and exposes your API to cross-site request forgery from any website.

---

## Core Concept

The browser enforces a "same-origin policy" by default — a page at `https://app.example.com` can't read responses from `https://api.example.com` unless the API explicitly says it's okay. The way the API does that is by returning `Access-Control-Allow-Origin` (and related headers) in its responses. For simple requests the browser just checks the response header after the fact. For non-simple requests (anything with a custom header, or methods like PUT/DELETE/PATCH), the browser sends a preflight `OPTIONS` request first to ask "are you going to allow this?" — and the API has to respond correctly before the browser sends the real request. ASP.NET Core's CORS middleware handles all of this: you define a named policy with the origins, methods, and headers you allow, then apply it globally or per-endpoint.

---

## The Code

**1. Define and apply a CORS policy in Program.cs**
```csharp
// Program.cs
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
            .AllowCredentials(); // required if frontend sends cookies or Auth headers
    });
});

var app = builder.Build();

// Must come before UseRouting, UseAuthentication, UseAuthorization
app.UseCors(MyPolicy);
```

**2. Development-only permissive policy (never use in production)**
```csharp
if (app.Environment.IsDevelopment())
{
    builder.Services.AddCors(options =>
    {
        options.AddPolicy("DevOnly", policy =>
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader());
                  // Note: AllowAnyOrigin() and AllowCredentials() cannot be combined
    });
}
```

**3. Per-endpoint override (when most endpoints are public but some are restricted)**
```csharp
app.MapGet("/api/public", () => "open")
   .RequireCors("PublicPolicy");

app.MapGet("/api/admin", () => "restricted")
   .RequireCors("AdminPolicy");
```

**4. Controller-level and action-level attributes**
```csharp
[ApiController]
[Route("api/[controller]")]
[EnableCors("MyFrontendPolicy")] // applies to all actions
public class ProductsController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll() => Ok();

    [HttpPost]
    [DisableCors] // opt-out this specific action
    public IActionResult Create() => Ok();
}
```

**5. Environment-driven origins from configuration**
```csharp
// Keep allowed origins in config, not hardcoded
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
// appsettings.Production.json
{
  "Cors": {
    "AllowedOrigins": [
      "https://app.example.com"
    ]
  }
}
```

---

## Gotchas

- **`AllowAnyOrigin()` and `AllowCredentials()` cannot be used together — the framework throws at startup.** The `Access-Control-Allow-Origin: *` wildcard header is incompatible with `Access-Control-Allow-Credentials: true` per the CORS spec. If you need credentials, you must enumerate origins explicitly with `WithOrigins(...)`.
- **`app.UseCors()` must come before `app.UseRouting()`, `app.UseAuthentication()`, and `app.UseAuthorization()`.** Placing it after means the CORS headers aren't added to preflight `OPTIONS` responses, so browsers reject the preflight before auth even runs. The resulting error looks like an auth problem, not a CORS problem.
- **CORS errors in the browser are not visible in your API logs.** The API returned a valid response — the browser silently blocked it on the client side. When debugging, check the browser's Network tab for the preflight `OPTIONS` request and its response headers, not your server logs.
- **A trailing slash mismatch in `WithOrigins` causes silent CORS failures.** `WithOrigins("https://app.example.com")` and `WithOrigins("https://app.example.com/")` are treated as different origins. Always match the origin exactly as the browser sends it — no trailing slash, no path component.
- **Preflight responses are cached by the browser based on `Access-Control-Max-Age`.** If you change your CORS policy (add a new header, change an origin), browsers that cached the old preflight response will continue using the old rules until the cache expires. During debugging, force a fresh preflight by setting `Access-Control-Max-Age: 0` or testing in an incognito window.

---

## Interview Angle

**What they're really testing:** Whether you understand that CORS is a browser constraint (not a server security mechanism on its own), how preflights work, and why `AllowAnyOrigin` is dangerous in production.

**Common question form:** *"How do you configure CORS in ASP.NET Core?"* or *"Why is my frontend getting a CORS error even though the API returns 200?"*

**The depth signal:** A junior answer describes adding `AddCors` and `UseCors` with `AllowAnyOrigin`. A senior answer explains the preflight `OPTIONS` flow and when it triggers, why `AllowAnyOrigin` + `AllowCredentials` is spec-illegal and throws at runtime, why middleware ordering matters (`UseCors` before `UseRouting`), why CORS failures are invisible in server logs and where to actually find them, and that CORS is a browser guardrail — a determined attacker using curl or Postman ignores it entirely, so it's not a substitute for authentication and authorization.

---

## Related Topics

- [[dotnet/middleware-pipeline.md]] — CORS is middleware with strict ordering requirements; `UseCors` position relative to `UseRouting` and `UseAuthentication` directly determines whether preflight responses are handled correctly.
- [[dotnet/webapi-authentication.md]] — Credentialed CORS requests (cookies, Authorization headers) require `AllowCredentials()`, which forces you to enumerate origins explicitly rather than use wildcards.
- [[dotnet/webapi-configuration.md]] — Allowed origins should come from environment-specific configuration rather than being hardcoded; the config pipeline is the right place to manage per-environment origin lists.
- [[dotnet/webapi-authorization.md]] — CORS is commonly confused with authorization — CORS controls browser access by origin, authorization controls access by identity. They solve different problems and both are needed.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/security/cors

---
*Last updated: 2026-03-24*