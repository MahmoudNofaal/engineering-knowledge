# WebAPI Configuration

> The .NET system for loading, layering, and injecting app settings from multiple sources — env vars, JSON files, secrets, and more — into a strongly-typed object graph at startup.

---

## When To Use It

Any time your ASP.NET Core app needs settings that change between environments (dev, staging, prod), you need configuration. Use it for connection strings, feature flags, API keys, timeouts, and service URLs. Don't hardcode values that differ per environment or that are sensitive — that's what this system exists to prevent. If you find yourself using `Environment.GetEnvironmentVariable()` directly in your business logic, you're bypassing the configuration pipeline and losing testability.

---

## Core Concept

ASP.NET Core builds a single `IConfiguration` object at startup by layering multiple sources on top of each other. Later sources win. So `appsettings.json` sets the defaults, `appsettings.Production.json` overrides some of them, and environment variables override those. The result gets bound to a strongly-typed class (the Options pattern) so the rest of your code never touches raw strings — it just receives a `MySettings` object via dependency injection. The magic is that you configure the pipeline once in `Program.cs` and the rest of the app is completely decoupled from where the values actually came from.

---

## The Code

**1. Define your settings class**
```csharp
// Models/EmailSettings.cs
public class EmailSettings
{
    public string SmtpHost { get; set; } = string.Empty;
    public int SmtpPort { get; set; }
    public bool UseSsl { get; set; }
    public string FromAddress { get; set; } = string.Empty;
}
```

**2. Register with Options pattern in Program.cs**
```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// Binds the "Email" section of configuration to EmailSettings
builder.Services.Configure<EmailSettings>(
    builder.Configuration.GetSection("Email"));

builder.Services.AddScoped<IEmailService, EmailService>();
```

**3. appsettings.json (base defaults)**
```json
{
  "Email": {
    "SmtpHost": "smtp.example.com",
    "SmtpPort": 587,
    "UseSsl": true,
    "FromAddress": "noreply@example.com"
  }
}
```

**4. appsettings.Production.json (environment override)**
```json
{
  "Email": {
    "SmtpHost": "smtp.sendgrid.net"
  }
}
```

**5. Inject and consume via IOptions<T>**
```csharp
// Services/EmailService.cs
public class EmailService : IEmailService
{
    private readonly EmailSettings _settings;

    // IOptions<T> is a snapshot — value is fixed at startup
    public EmailService(IOptions<EmailSettings> options)
    {
        _settings = options.Value;
    }

    public Task SendAsync(string to, string subject, string body)
    {
        // _settings.SmtpHost, _settings.SmtpPort, etc. are all typed
        Console.WriteLine($"Sending via {_settings.SmtpHost}:{_settings.SmtpPort}");
        return Task.CompletedTask;
    }
}
```

**6. Validation at startup (fail fast)**
```csharp
// Program.cs — validate required fields before the app starts serving traffic
builder.Services
    .AddOptions<EmailSettings>()
    .Bind(builder.Configuration.GetSection("Email"))
    .ValidateDataAnnotations()  // honours [Required], [Range], etc.
    .ValidateOnStart();         // throws at startup, not on first request
```

**7. Layering order (for reference — last wins)**
```csharp
// WebApplication.CreateBuilder already adds these in this order:
// 1. appsettings.json
// 2. appsettings.{Environment}.json
// 3. User Secrets (Development only)
// 4. Environment variables
// 5. Command-line arguments

// To add a custom source (e.g. Azure Key Vault):
builder.Configuration.AddAzureKeyVault(vaultUri, credential);
// Key Vault is added last so it wins over everything else
```

---

## Gotchas

- **`IOptions<T>` is a startup snapshot — it doesn't reload.** If you need live config updates without restarting, inject `IOptionsMonitor<T>` instead. `IOptionsSnapshot<T>` reloads per-request (scoped) but still doesn't suit singletons.
- **Environment variable key separator is `__`, not `:`**. To override `Email:SmtpHost` via an env var, set `Email__SmtpHost=value`. The colon doesn't work on Linux; the double-underscore does.
- **User Secrets only load in the `Development` environment.** They are silently ignored in Production — which is correct behaviour, but confuses people who test with secrets locally and then wonder why values are missing in staging.
- **Missing sections don't throw — they silently bind defaults.** If `GetSection("Email")` finds nothing, all properties get their default values (`null`, `0`, `false`). Add `.ValidateOnStart()` with data annotations or a custom `IValidateOptions<T>` to catch this before your app starts taking traffic.
- **`Configuration["Key"]` returns `null` for missing keys, not an exception.** Direct string access via the indexer is convenient for debugging but terrible in production code — it bypasses all type safety and validation.

---

## Interview Angle

**What they're really testing:** Whether you understand the Options pattern, how the layered configuration pipeline works, and how to handle secrets safely — not just that you know `appsettings.json` exists.

**Common question form:** *"How do you manage configuration across multiple environments in ASP.NET Core?"* or *"What's the difference between `IOptions`, `IOptionsSnapshot`, and `IOptionsMonitor`?"*

**The depth signal:** A junior answer describes `appsettings.json` and `appsettings.Production.json`. A senior answer explains the full pipeline layering order, the `__` vs `:` separator difference for env vars, why `IOptions<T>` is a singleton-safe snapshot while `IOptionsMonitor<T>` is for live-reload scenarios, and how to wire up `.ValidateOnStart()` so misconfigured deployments fail immediately instead of silently serving bad data. A senior also mentions that secrets never belong in source control — User Secrets locally, Key Vault or secret manager in production.

---

## Related Topics

- [[dotnet/dependency-injection.md]] — Configuration values reach your services through DI; understanding the container lifetime (singleton vs scoped) determines which `IOptions` variant to use.
- [[dotnet/minimal-api-setup.md]] — `Program.cs` is where the configuration pipeline is assembled; the two topics share the same startup entry point.
- [[devops/environment-variables.md]] — Environment variables are the primary override mechanism in containerised deployments; how you set them in Docker/K8s directly shapes your config strategy.
- [[dotnet/user-secrets.md]] — The recommended local-dev alternative to putting real credentials in `appsettings.json`.

---

## Source

[https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration)

---
*Last updated: 2026-03-24*