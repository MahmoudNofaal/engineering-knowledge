# WebAPI HTTPS & Certificates

> The mechanism that encrypts traffic between clients and your ASP.NET Core API using TLS — enforced via certificates that prove the server's identity and negotiate an encrypted channel.

---

## When To Use It

Use HTTPS for every API that carries any data worth protecting — which is all of them in production. HTTP in production is not acceptable for APIs that handle authentication headers, personal data, or anything sensitive, because the traffic is plaintext on the wire. In development, ASP.NET Core provides a self-signed dev certificate so you get the same TLS behaviour locally without buying a cert. The one place you might terminate TLS before it reaches your app is behind a reverse proxy (nginx, YARP, Azure App Gateway) — in that case the proxy holds the cert and forwards plain HTTP internally, and your app just needs to trust the forwarded headers.

---

## Core Concept

TLS works by having the server present a certificate — a cryptographically signed document that says "this public key belongs to api.example.com, and a trusted Certificate Authority (CA) vouches for that." The client (browser, HttpClient) checks the cert against its trust store. If it's valid and matches the hostname, they negotiate an encrypted session using the public key. After that, everything is encrypted. In development, `dotnet dev-certs` generates a self-signed cert that only your machine trusts. In production, you get a cert from a CA (Let's Encrypt, DigiCert, etc.) and either load it directly into Kestrel or let your reverse proxy handle it. The app itself uses `UseHttpsRedirection()` to push any HTTP request up to HTTPS automatically.

---

## The Code

**1. Dev certificate setup (one-time per machine)**
```bash
# Generate and trust the dev cert
dotnet dev-certs https --trust

# Verify it exists
dotnet dev-certs https --check

# Reset if it's broken or expired
dotnet dev-certs https --clean
dotnet dev-certs https --trust
```

**2. HTTPS redirection and HSTS in Program.cs**
```csharp
// Program.cs
var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    // HSTS tells browsers to always use HTTPS for this domain for 1 year
    // Don't enable in dev — it makes it hard to test on plain HTTP locally
    app.UseHsts();
}

// Redirects http:// requests to https:// automatically
app.UseHttpsRedirection();
```

**3. Kestrel with a production certificate (loaded from file)**
```csharp
// Program.cs — loading cert from disk (e.g. in a container)
builder.WebHost.ConfigureKestrel(options =>
{
    options.Listen(IPAddress.Any, 443, listenOptions =>
    {
        listenOptions.UseHttps("/certs/api.pfx",
            Environment.GetEnvironmentVariable("CERT_PASSWORD"));
    });

    // Keep HTTP open only for health checks or internal redirect
    options.Listen(IPAddress.Any, 80);
});
```

**4. Kestrel certificate via configuration (preferred — no code changes per env)**
```json
// appsettings.Production.json
{
  "Kestrel": {
    "Endpoints": {
      "Https": {
        "Url": "https://*:443",
        "Certificate": {
          "Path": "/certs/api.pfx",
          "KeyPath": null
        }
      }
    }
  }
}
```

**5. Behind a reverse proxy — trust forwarded headers instead**
```csharp
// Program.cs — when TLS is terminated at nginx/load balancer
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;

    // Restrict to known proxy IPs in production
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));
});

// Must be the very first middleware
app.UseForwardedHeaders();
app.UseHttpsRedirection(); // now works correctly — sees https from the proxy header
```

**6. HttpClient with dev cert bypass (tests only — never production)**
```csharp
// Integration test setup only
var handler = new HttpClientHandler
{
    // Accepts the self-signed dev cert in test environments
    ServerCertificateCustomValidationCallback =
        HttpClientHandler.DangerousAcceptAnyServerCertificateValidator
};
var client = new HttpClient(handler);
```

---

## Gotchas

- **`UseHsts()` in Development permanently poisons the browser's HSTS cache for localhost.** If you call `app.UseHsts()` unconditionally (not guarded by `!IsDevelopment()`), your browser will refuse plain HTTP on localhost for up to a year. This breaks other local projects that run on HTTP. The template guard exists for exactly this reason — don't remove it.
- **`UseForwardedHeaders()` must be the first middleware registered**, before `UseHttpsRedirection()`. If you put it after, `UseHttpsRedirection()` reads the raw incoming scheme (HTTP from the proxy) and redirects in an infinite loop because it never sees HTTPS.
- **Without `KnownProxies` or `KnownNetworks`, `ForwardedHeadersMiddleware` ignores forwarded headers by default** in production (changed in .NET 6). A blank `ForwardedHeadersOptions` will silently not forward anything. You must explicitly add the proxy's IP or set `options.KnownNetworks.Clear()` + `options.KnownProxies.Clear()` only if you trust all proxies — which you should only do in a fully controlled network.
- **The dev certificate is machine-local and doesn't work in Docker containers by default.** When you run your app in a container locally, the container doesn't have your machine's trusted dev cert. You need to export it with `dotnet dev-certs https --export-path` and mount it into the container, or configure the container to run on HTTP internally and let the host proxy handle TLS.
- **PFX certificate passwords passed as plain strings in config are a secret.** Storing the `KeyPath` password in `appsettings.Production.json` committed to source control is the same mistake as storing a connection string password there. Pull it from environment variables or a secret manager, and reference it in Kestrel config via `builder.Configuration["CertPassword"]`.

---

## Interview Angle

**What they're really testing:** Whether you understand where TLS is terminated in a real production architecture, the difference between Kestrel handling certs directly vs a reverse proxy doing it, and whether you know why HSTS and forwarded headers matter.

**Common question form:** *"How do you configure HTTPS in ASP.NET Core?"* or *"Your API is behind a load balancer — how do you make sure HTTPS redirection works correctly?"*

**The depth signal:** A junior answer describes `UseHttpsRedirection()` and the dev cert. A senior answer explains TLS termination at the proxy layer, why `UseForwardedHeaders()` must come first in the pipeline when behind a proxy, the HSTS risk in development, why `DangerousAcceptAnyServerCertificateValidator` is test-only and what it actually bypasses (identity verification, not encryption), and that a PFX password in config is a secret that belongs in a secret manager — not in a committed JSON file.

---

## Related Topics

- [[dotnet/middleware-pipeline.md]] — `UseForwardedHeaders()`, `UseHttpsRedirection()`, and `UseHsts()` have strict ordering dependencies in the pipeline; getting them wrong causes redirect loops or ignored headers.
- [[dotnet/webapi-configuration.md]] — Kestrel endpoint URLs and certificate paths are driven by configuration; environment-specific overrides in `appsettings.Production.json` are the standard pattern for cert paths.
- [[devops/reverse-proxy-nginx.md]] — In production, nginx or a cloud load balancer typically owns the TLS cert; understanding that layer explains why ASP.NET Core apps behind a proxy often run on plain HTTP internally.
- [[devops/docker-networking.md]] — The dev cert doesn't travel into containers automatically; knowing how Docker networking works explains why HTTPS inside containers requires explicit cert mounting or a sidecar proxy.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/security/enforcing-ssl

---
*Last updated: 2026-03-24*