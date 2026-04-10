# WebAPI HTTPS & Certificates

> The mechanism that encrypts traffic between clients and your ASP.NET Core API using TLS — enforced via certificates that prove the server's identity and negotiate an encrypted channel.

---

## Quick Reference

| | |
|---|---|
| **What it is** | TLS encryption layer for HTTP traffic via certificate-backed identity verification |
| **Use when** | Every API in production — HTTP in production is unacceptable |
| **Avoid when** | Only skip TLS termination in the app when a reverse proxy handles it upstream |
| **Introduced** | ASP.NET Core 1.0; dev cert tooling added ASP.NET Core 2.1 |
| **Namespace** | `Microsoft.AspNetCore.HttpsPolicy`, `Microsoft.AspNetCore.Server.Kestrel` |
| **Key types** | `HttpsRedirectionOptions`, `HstsOptions`, `KestrelServerOptions`, `ForwardedHeadersOptions` |

---

## When To Use It

Use HTTPS for every API that carries any data worth protecting — which is all of them in production. HTTP in production is not acceptable for APIs that handle authentication headers, personal data, or anything sensitive, because the traffic is plaintext on the wire. In development, ASP.NET Core provides a self-signed dev certificate so you get the same TLS behaviour locally without buying a cert. The one place you might terminate TLS before it reaches your app is behind a reverse proxy (nginx, YARP, Azure App Gateway) — in that case the proxy holds the cert and forwards plain HTTP internally, and your app just needs to trust the forwarded headers.

---

## Core Concept

TLS works by having the server present a certificate — a cryptographically signed document that says "this public key belongs to api.example.com, and a trusted Certificate Authority (CA) vouches for that." The client checks the cert against its trust store. If it's valid and matches the hostname, they negotiate an encrypted session. In development, `dotnet dev-certs` generates a self-signed cert that only your machine trusts. In production, you get a cert from a CA (Let's Encrypt, DigiCert) and either load it directly into Kestrel or let your reverse proxy handle it. The app uses `UseHttpsRedirection()` to push any HTTP request up to HTTPS automatically.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | Kestrel supports HTTPS via certificate configuration |
| ASP.NET Core 2.1 | `dotnet dev-certs https --trust` introduced for local development |
| ASP.NET Core 2.1 | `UseHsts()` and `UseHttpsRedirection()` middleware |
| ASP.NET Core 3.0 | Kestrel certificate configuration via `appsettings.json` (`Kestrel:Endpoints`) |
| .NET 6 | `UseForwardedHeaders` improvements; `KnownNetworks` validation tightened |
| .NET 8 | Automatic certificate rotation support in Kestrel |

*Before the `Kestrel:Endpoints` JSON configuration in ASP.NET Core 3.0, certificate paths had to be configured in code. JSON configuration allows cert rotation without code changes — a significant operational improvement.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| TLS handshake (new connection) | ~1–5 ms | RSA key exchange; amortised over connection reuse |
| TLS data transfer overhead | ~1–5% CPU | AES-GCM on modern CPUs with hardware acceleration |
| HTTPS redirect (HTTP → HTTPS) | ~1 ms | Extra round-trip; clients should update bookmarks |
| HSTS header | ~1 µs | Simple header append; eliminates future redirect round-trips |

**Allocation behaviour:** TLS session state is managed by the OS TLS library (SChannel on Windows, OpenSSL on Linux) — minimal .NET heap allocation. Connection reuse (HTTP/2, keep-alive) amortises the handshake cost across many requests.

**Benchmark notes:** TLS overhead on modern hardware with AES-NI is 1–5% CPU. It is never a bottleneck. The round-trip cost of HTTP → HTTPS redirects is more significant for clients — HSTS eliminates it after the first visit.

---

## The Code

**Dev certificate setup (one-time per machine)**
```bash
dotnet dev-certs https --trust
dotnet dev-certs https --check       # verify it exists
dotnet dev-certs https --clean       # reset if broken or expired
dotnet dev-certs https --trust       # re-trust after reset
```

**HTTPS redirection and HSTS in Program.cs**
```csharp
var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    // HSTS: tell browsers to always use HTTPS for this domain for 1 year
    // Never enable in dev — it poisons the browser's HSTS cache for localhost
    app.UseHsts();
}

app.UseHttpsRedirection();  // redirects http:// requests to https://
```

**Kestrel with a certificate from a file**
```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    options.Listen(IPAddress.Any, 443, listenOptions =>
    {
        listenOptions.UseHttps("/certs/api.pfx",
            Environment.GetEnvironmentVariable("CERT_PASSWORD"));
    });
    options.Listen(IPAddress.Any, 80);
});
```

**Kestrel certificate via configuration (preferred — no code changes per env)**
```json
// appsettings.Production.json
{
  "Kestrel": {
    "Endpoints": {
      "Https": {
        "Url": "https://*:443",
        "Certificate": {
          "Path": "/certs/api.pfx",
          "Password": ""
        }
      }
    }
  }
}
```

**Behind a reverse proxy — trust forwarded headers**
```csharp
// TLS terminated at nginx/load balancer — app sees plain HTTP internally
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.1")); // restrict to known proxy IP
});

// Must be the very first middleware
app.UseForwardedHeaders();
app.UseHttpsRedirection();  // now sees https:// from the proxy header
```

**HttpClient with dev cert bypass (test environments only)**
```csharp
// NEVER in production — bypasses certificate validation entirely
var handler = new HttpClientHandler
{
    ServerCertificateCustomValidationCallback =
        HttpClientHandler.DangerousAcceptAnyServerCertificateValidator
};
var client = new HttpClient(handler);
```

---

## Real World Example

A containerised API runs in Kubernetes with TLS terminated at the ingress controller (nginx). The app sees plain HTTP internally but `UseForwardedHeaders` makes `UseHttpsRedirection` and `Request.Scheme` work correctly. The certificate PFX password comes from a Kubernetes secret, not from `appsettings.json`.

```csharp
// Program.cs — production config for behind-proxy deployment
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;

    // Only trust the ingress controller's IP range
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("10.96.0.0"), 12));
});

var app = builder.Build();

// MUST be first middleware
app.UseForwardedHeaders();

if (!app.Environment.IsDevelopment())
    app.UseHsts();

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
```

```yaml
# Kubernetes secret for cert password — not in any config file
apiVersion: v1
kind: Secret
metadata:
  name: api-cert-secret
data:
  CERT_PASSWORD: <base64-encoded-password>
```

*The key insight: in a containerised reverse-proxy deployment, the app never touches the TLS certificate directly. The ingress controller owns the cert; the app trusts `X-Forwarded-Proto` from the proxy to know whether the original request was HTTPS. `ForwardedHeaders` with restricted `KnownNetworks` is what prevents a malicious client from injecting a fake `X-Forwarded-Proto: https` header directly at the app.*

---

## Common Misconceptions

**"HTTPS in development is unnecessary — it's just local traffic."**
The dev cert exists for a reason: to catch bugs that only manifest with HTTPS (mixed-content warnings, secure cookie flags, HSTS interactions). Testing on HTTP locally and deploying to HTTPS production is a common source of hard-to-reproduce production bugs. Always use `https://localhost` during development.

**"`UseHsts()` everywhere is harmless."**
Calling `app.UseHsts()` unconditionally — without the `!IsDevelopment()` guard — permanently poisons the browser's HSTS cache for `localhost` for up to a year. Other local projects that run on plain HTTP break. The guard in the template exists for exactly this reason.

**"The PFX certificate password can go in `appsettings.json`."**
PFX certificate passwords are secrets — storing them in `appsettings.json` committed to source control exposes them. Pull passwords from environment variables, User Secrets (dev), or a secrets manager (prod).

---

## Gotchas

- **`UseHsts()` in Development permanently poisons the browser's HSTS cache for localhost.** Always guard with `if (!app.Environment.IsDevelopment())`.

- **`UseForwardedHeaders()` must be the first middleware.** Before `UseHttpsRedirection()`. If after, `UseHttpsRedirection` reads the raw scheme (HTTP from the proxy) and redirects in an infinite loop.

- **Without `KnownProxies` or `KnownNetworks`, `ForwardedHeadersMiddleware` ignores forwarded headers by default in production (.NET 6+).** Explicitly add the proxy's IP or clear and repopulate `KnownNetworks`.

- **The dev certificate is machine-local and doesn't work inside Docker containers.** Export it with `dotnet dev-certs https --export-path` and mount it into the container, or configure the container to run HTTP internally and let the host proxy handle TLS.

- **PFX passwords passed as plain strings in config are secrets.** Pull the password from environment variables or a secrets manager, never from committed JSON.

---

## Interview Angle

**What they're really testing:** Whether you understand where TLS is terminated in a real production architecture, the difference between Kestrel handling certs vs a reverse proxy doing it, and why HSTS and forwarded headers matter.

**Common question form:**
- "How do you configure HTTPS in ASP.NET Core?"
- "Your API is behind a load balancer — how do you make HTTPS redirection work correctly?"
- "Why shouldn't you enable HSTS in development?"

**The depth signal:** A junior describes `UseHttpsRedirection()` and the dev cert. A senior explains TLS termination at the proxy layer, why `UseForwardedHeaders()` must come first in the pipeline when behind a proxy, the HSTS risk in development, why `DangerousAcceptAnyServerCertificateValidator` is test-only, and that a PFX password in committed JSON is a security incident.

**Follow-up questions to expect:**
- "How does `UseForwardedHeaders` prevent a client from spoofing `X-Forwarded-Proto`?"
- "How do you rotate a TLS certificate without restarting the application?"
- "What's the difference between HSTS and HTTPS redirection?"

---

## Related Topics

- [[dotnet/webapi/middleware-pipeline.md]] — `UseForwardedHeaders`, `UseHttpsRedirection`, and `UseHsts` have strict ordering dependencies in the pipeline
- [[dotnet/webapi/webapi-configuration.md]] — Kestrel endpoint URLs and certificate paths are driven by configuration; secrets (passwords) must come from environment variables or a secrets manager
- [[dotnet/webapi/webapi-authentication.md]] — HTTPS is a prerequisite for secure JWT authentication; tokens sent over plain HTTP are readable by anyone on the network

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/security/enforcing-ssl

---
*Last updated: 2026-04-10*