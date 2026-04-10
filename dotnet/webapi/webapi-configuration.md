# WebAPI Configuration

> The .NET system for loading, layering, and injecting app settings from multiple sources — env vars, JSON files, secrets, and more — into a strongly-typed object graph at startup.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Layered key-value configuration pipeline bound to strongly-typed classes via DI |
| **Use when** | Any setting that differs between environments or that is sensitive |
| **Avoid when** | Never hardcode values that differ per environment — always use configuration |
| **Introduced** | ASP.NET Core 1.0; `ValidateOnStart` added .NET 6 |
| **Namespace** | `Microsoft.Extensions.Configuration`, `Microsoft.Extensions.Options` |
| **Key types** | `IConfiguration`, `IOptions<T>`, `IOptionsMonitor<T>`, `IOptionsSnapshot<T>`, `OptionsBuilder<T>` |

---

## When To Use It

Any time your ASP.NET Core app needs settings that change between environments (dev, staging, prod), you need configuration. Use it for connection strings, feature flags, API keys, timeouts, and service URLs. Don't hardcode values that differ per environment or that are sensitive — that's what this system exists to prevent. If you find yourself using `Environment.GetEnvironmentVariable()` directly in your business logic, you're bypassing the configuration pipeline and losing testability.

---

## Core Concept

ASP.NET Core builds a single `IConfiguration` object at startup by layering multiple sources on top of each other — later sources win. `appsettings.json` sets the defaults, `appsettings.Production.json` overrides some of them, and environment variables override those. The result gets bound to a strongly-typed class (the Options pattern) so the rest of your code never touches raw strings — it just receives a `MySettings` object via DI. You configure the pipeline once in `Program.cs` and the rest of the app is completely decoupled from where the values actually came from.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | `IConfiguration`, `IOptions<T>`, JSON + environment variable providers |
| ASP.NET Core 2.0 | `IOptionsSnapshot<T>` — per-request reload for scoped services |
| ASP.NET Core 2.2 | `IOptionsMonitor<T>` — live reload + change notification |
| .NET 5 | `OptionsBuilder<T>.ValidateDataAnnotations()` |
| .NET 6 | `OptionsBuilder<T>.ValidateOnStart()` — fail immediately at startup, not on first use |
| .NET 8 | `IOptionsFactory<T>` improvements; named options pattern improvements |

*`ValidateOnStart()` (.NET 6) is the single most impactful addition to the Options API — it causes misconfigured deployments to fail at startup rather than silently serving bad data until the first request hits the bad code path.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `IOptions<T>.Value` access | O(1) | Singleton snapshot; computed once at startup |
| `IOptionsSnapshot<T>.Value` access | O(1) per scope | Recomputed per HTTP request |
| `IOptionsMonitor<T>.CurrentValue` | O(1) | Returns latest cached value; updated on file change |
| Configuration reload (file watcher) | ~1–5 ms | File read + rebind; happens asynchronously |

**Allocation behaviour:** `IOptions<T>` allocates the bound object once. `IOptionsSnapshot<T>` allocates a new bound object per request scope — don't use it in singletons. `IOptionsMonitor<T>` maintains one instance and replaces it atomically on reload; change callbacks allocate delegates.

**Benchmark notes:** Configuration access is never a bottleneck. The concern is correctness: using `IOptions<T>` in a long-running singleton that needs live-reload capability, or using `IOptionsSnapshot<T>` in a singleton (causes a captive dependency error).

---

## The Code

**Define your settings class**
```csharp
public class EmailSettings
{
    public string SmtpHost { get; set; } = string.Empty;
    public int    SmtpPort { get; set; }
    public bool   UseSsl   { get; set; }
    public string From     { get; set; } = string.Empty;
}
```

**Register with the Options pattern in Program.cs**
```csharp
builder.Services
    .AddOptions<EmailSettings>()
    .Bind(builder.Configuration.GetSection("Email"))
    .ValidateDataAnnotations()  // honours [Required], [Range], etc. on the settings class
    .ValidateOnStart();         // throw at startup, not on first use
```

**appsettings.json — base defaults**
```json
{
  "Email": {
    "SmtpHost": "smtp.example.com",
    "SmtpPort": 587,
    "UseSsl":   true,
    "From":     "noreply@example.com"
  }
}
```

**appsettings.Production.json — environment override**
```json
{
  "Email": {
    "SmtpHost": "smtp.sendgrid.net"
  }
}
```

**`IOptions<T>` — startup snapshot (singleton-safe)**
```csharp
public class EmailService(IOptions<EmailSettings> options)
{
    private readonly EmailSettings _settings = options.Value;

    public Task SendAsync(string to, string subject) =>
        // _settings is a snapshot set at startup — never changes
        Task.CompletedTask;
}
```

**`IOptionsMonitor<T>` — live reload (for singletons that need updated config)**
```csharp
public class FeatureFlagService(IOptionsMonitor<FeatureFlagSettings> monitor)
{
    public bool IsEnabled(string flag) =>
        monitor.CurrentValue.EnabledFlags.Contains(flag);
        // CurrentValue always returns the latest value — reloads when appsettings.json changes
}
```

**`IOptionsSnapshot<T>` — per-request reload (for scoped services only)**
```csharp
public class TenantConfigService(IOptionsSnapshot<TenantSettings> snapshot)
{
    // snapshot.Value is recalculated once per HTTP request scope
    // Never inject IOptionsSnapshot into a singleton
    public TenantSettings Current => snapshot.Value;
}
```

**Layering order (last wins)**
```csharp
// WebApplication.CreateBuilder adds these in order:
// 1. appsettings.json
// 2. appsettings.{Environment}.json
// 3. User Secrets (Development only)
// 4. Environment variables
// 5. Command-line arguments

// Add Azure Key Vault last so it wins over everything:
builder.Configuration.AddAzureKeyVault(vaultUri, new DefaultAzureCredential());
```

---

## Real World Example

A multi-tenant SaaS needs different Stripe keys per environment, a feature flag system that reloads without restart, and startup validation that crashes the app if required secrets are missing — not silently serving requests with null API keys.

```csharp
// Settings classes with validation attributes
public class StripeSettings
{
    [Required, MinLength(20)]
    public string SecretKey { get; set; } = "";

    [Required, MinLength(20)]
    public string WebhookSecret { get; set; } = "";

    public string ApiVersion { get; set; } = "2024-01-01";
}

public class FeatureFlagSettings
{
    public HashSet<string> EnabledFlags { get; set; } = new();
}

// Program.cs — strict validation at startup
builder.Services
    .AddOptions<StripeSettings>()
    .Bind(builder.Configuration.GetSection("Stripe"))
    .ValidateDataAnnotations()
    .ValidateOnStart();     // crash immediately if SecretKey is empty

// Feature flags support live reload without restart
builder.Services
    .AddOptions<FeatureFlagSettings>()
    .Bind(builder.Configuration.GetSection("FeatureFlags"));

// Services that use the settings
builder.Services.AddScoped<IPaymentService, StripePaymentService>();
builder.Services.AddSingleton<IFeatureFlagService, FeatureFlagService>();

// appsettings.json — non-sensitive defaults only
{
  "FeatureFlags": { "EnabledFlags": ["new-checkout", "dark-mode"] }
}

// Environment variables (CI/CD injects these) — no secrets in appsettings
// Stripe__SecretKey=sk_live_xxx
// Stripe__WebhookSecret=whsec_xxx

// Services
public class StripePaymentService(IOptions<StripeSettings> opts) : IPaymentService
{
    // IOptions<T> — snapshot set at startup; Stripe keys don't change at runtime
    private readonly StripeSettings _stripe = opts.Value;

    public async Task<PaymentResult> ChargeAsync(decimal amount, string token)
    {
        // Use _stripe.SecretKey — guaranteed non-null by ValidateOnStart
        return await CallStripeApi(_stripe.SecretKey, amount, token);
    }
}

public class FeatureFlagService(IOptionsMonitor<FeatureFlagSettings> monitor) : IFeatureFlagService
{
    // IOptionsMonitor — live reload when appsettings.json changes
    public bool IsEnabled(string flag) =>
        monitor.CurrentValue.EnabledFlags.Contains(flag, StringComparer.OrdinalIgnoreCase);
}
```

*The key insight: `ValidateOnStart()` means a missing `Stripe__SecretKey` environment variable in production causes the deployment to fail immediately with a clear error message — not a `NullReferenceException` on the first payment request two hours into production. Fail fast, fail loud.*

---

## Common Misconceptions

**"`IOptions<T>` reloads when `appsettings.json` changes."**
`IOptions<T>` is a startup snapshot — it never reloads. Use `IOptionsMonitor<T>` for live reload in singletons or `IOptionsSnapshot<T>` for per-request reload in scoped services. Using `IOptions<T>` for settings that need live updates silently serves stale values.

**"Environment variable separator is `:`."**
The colon separator works in `appsettings.json` (`"Email:SmtpHost"`). For environment variables on Linux/Docker, the separator must be `__` (double underscore): `Email__SmtpHost=value`. Colons in environment variable names don't work on Linux. This trips up every team the first time they deploy to a container.

**"User Secrets are available in all environments."**
User Secrets only load in the `Development` environment. They are silently ignored in Production — which is correct, but confuses developers who test with secrets locally and then wonder why values are missing in staging.

---

## Gotchas

- **`IOptionsSnapshot<T>` in a singleton causes a captive dependency exception.** `IOptionsSnapshot<T>` is scoped (per-request). Injecting it into a singleton captures it at construction time — either the framework throws at startup (with scope validation) or you get stale values silently. Use `IOptionsMonitor<T>` in singletons.

- **Environment variable `__` separator must be used on Linux.** `Email:SmtpHost` works in JSON but `Email__SmtpHost` is required in environment variables on Linux/macOS. Docker and Kubernetes both use environment variables — always use the double-underscore format in deployment configs.

- **Missing sections don't throw — they silently bind defaults.** If `GetSection("Email")` finds nothing, all properties get their default values (empty string, 0, false). Add `.ValidateOnStart()` with `[Required]` attributes to catch this at startup.

- **`Configuration["Key"]` returns `null` for missing keys.** Direct string access via the indexer bypasses type safety and validation. Use the Options pattern — inject `IOptions<T>` — for any settings your code actually uses.

- **Secrets in `appsettings.Production.json` committed to source control is a security incident.** Connection strings, API keys, and certificates should come from environment variables, User Secrets (dev only), or a secrets manager (Azure Key Vault, AWS Secrets Manager, HashiCorp Vault). Never commit secrets to source control.

---

## Interview Angle

**What they're really testing:** Whether you understand the Options pattern, how the layered configuration pipeline works, and how to handle secrets safely.

**Common question forms:**
- "How do you manage configuration across multiple environments?"
- "What's the difference between `IOptions`, `IOptionsSnapshot`, and `IOptionsMonitor`?"
- "How do you ensure required configuration values exist before the app starts serving traffic?"

**The depth signal:** A junior describes `appsettings.json` and environment-specific overrides. A senior explains the full pipeline layering order, the `__` vs `:` separator difference for environment variables, why `IOptions<T>` is a singleton-safe snapshot while `IOptionsMonitor<T>` is for live-reload singletons and `IOptionsSnapshot<T>` is for per-request scoped services, and how `ValidateOnStart()` causes misconfigured deployments to fail immediately. A senior also mentions that secrets never belong in source control — User Secrets locally, Key Vault or secrets manager in production.

**Follow-up questions to expect:**
- "How would you integrate Azure Key Vault into the configuration pipeline?"
- "What happens if a required configuration value is missing without `ValidateOnStart`?"
- "How do you write a unit test for a class that depends on `IOptions<T>`?"

---

## Related Topics

- [[dotnet/webapi/dependency-injection.md]] — `IOptions<T>`, `IOptionsMonitor<T>`, and `IOptionsSnapshot<T>` are DI-registered services; choosing the right one depends on the consumer's lifetime
- [[dotnet/webapi/webapi-authentication.md]] — JWT signing keys and issuer settings must come from configuration secrets, not committed JSON
- [[dotnet/webapi/webapi-https-certificates.md]] — certificate paths and passwords are configuration values that must come from environment variables or secrets managers
- [[dotnet/webapi/middleware-pipeline.md]] — the configuration pipeline is assembled in `Program.cs` before the middleware pipeline is built; ordering matters

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration

---
*Last updated: 2026-04-10*