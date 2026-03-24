# WebAPI Logging

> The built-in .NET logging abstraction that lets you write structured log messages through a consistent interface, with the actual output destination (console, file, cloud) wired up separately at startup.

---

## When To Use It

Use it any time you need visibility into what your application is doing at runtime — request tracing, errors, slow queries, business events. The abstraction matters because your service code shouldn't care whether logs go to the console, Application Insights, or Seq. Don't use `Console.WriteLine` in production code — it bypasses log levels, filtering, and structured data. Avoid over-logging hot paths; writing a structured log object on every iteration of a tight loop has real allocations.

---

## Core Concept

.NET logging has two layers: the `ILogger<T>` interface your code writes to, and one or more "providers" (sinks) that decide where those messages actually go. The framework buffers and routes messages based on category (the `T` in `ILogger<T>`, which is just the class name) and minimum level. You inject `ILogger<T>` into your class, call `.LogInformation(...)` or `.LogError(...)`, and the host figures out the rest. The important shift from classic logging is *structured logging* — instead of formatting a string yourself, you pass a message template with named holes (`"User {UserId} logged in"`) and the raw values separately, so downstream tools can query on `UserId` as a field rather than parsing a string.

---

## The Code

**1. Basic injection and usage**
```csharp
public class OrderService
{
    private readonly ILogger<OrderService> _logger;

    public OrderService(ILogger<OrderService> logger)
    {
        _logger = logger;
    }

    public async Task<Order> PlaceOrderAsync(int userId, Cart cart)
    {
        // Named holes become queryable fields in structured sinks
        _logger.LogInformation("Placing order for user {UserId}, items {ItemCount}",
            userId, cart.Items.Count);

        try
        {
            var order = await ProcessAsync(cart);
            _logger.LogInformation("Order {OrderId} created for user {UserId}",
                order.Id, userId);
            return order;
        }
        catch (PaymentException ex)
        {
            // Pass exception as first arg so the sink captures the stack trace
            _logger.LogError(ex, "Payment failed for user {UserId}", userId);
            throw;
        }
    }
}
```

**2. Minimum level config in appsettings.json**
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore.Database.Command": "Warning"
    }
  }
}
```

**3. High-performance logging with LoggerMessage (avoids allocations)**
```csharp
public partial class OrderService
{
    // Compiled at build time — no string interpolation, no boxing on the hot path
    [LoggerMessage(Level = LogLevel.Information, Message = "Order {OrderId} dispatched")]
    private partial void LogOrderDispatched(int orderId);
}
```

**4. Wiring up Serilog as a provider (common in production)**
```csharp
// Program.cs
using Serilog;

Log.Logger = new LoggerConfiguration()
    .WriteTo.Console(new JsonFormatter()) // structured JSON to stdout
    .WriteTo.Seq("http://localhost:5341") // queryable log server
    .Enrich.FromLogContext()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .CreateLogger();

builder.Host.UseSerilog(); // replaces the default providers
```

**5. Adding context to all logs within a scope**
```csharp
// All log messages written inside this block carry RequestId automatically
using (_logger.BeginScope("RequestId: {RequestId}", requestId))
{
    await ProcessAsync();
}
```

---

## Gotchas

- **String interpolation kills structured logging.** Writing `_logger.LogInformation($"User {userId} logged in")` turns everything into a flat string. The correct form is `_logger.LogInformation("User {UserId} logged in", userId)` — the named hole is the queryable field. This is the most common mistake on teams switching to structured logging.
- **EF Core query logging is `Debug` level by default, but the SQL noise you see locally comes from `Microsoft.EntityFrameworkCore.Database.Command`.** Override it explicitly to `Warning` in non-dev environments or you'll flood your sink with every SELECT.
- **Log level filtering happens before the message is constructed only if you use `IsEnabled` or `LoggerMessage`.** A plain `_logger.LogDebug(ExpensiveToString())` evaluates `ExpensiveToString()` even if Debug is disabled, because the argument is evaluated before the call. Use `[LoggerMessage]` source generators or guard with `if (_logger.IsEnabled(LogLevel.Debug))` on truly expensive payloads.
- **`LogError(ex, message)` — exception goes first, message second.** Swapping them is a silent mistake; the overload that takes `string` first treats it as the message template without capturing the exception object, so your stack traces disappear.
- **Scopes from `BeginScope` only appear in output if the provider supports them.** The default Console provider shows them; many third-party sinks need explicit `Enrich.FromLogContext()` or similar configuration. Assuming scope data always flows through is a production debugging trap.

---

## Interview Angle

**What they're really testing:** Whether you understand the abstraction boundary between writing logs and routing them, and whether you know the difference between string-formatted and structured logging.

**Common question form:** *"How do you implement logging in ASP.NET Core?"* or *"What's the difference between structured and unstructured logging, and why does it matter?"*

**The depth signal:** A junior answer describes injecting `ILogger<T>` and calling `.LogInformation(...)`. A senior answer explains why you never interpolate strings into the template, what named holes give you in tools like Seq or Application Insights, the performance cost of boxing value types on hot paths and how `[LoggerMessage]` source generators solve it, and how to use `MinimumLevel.Override` to suppress framework noise without losing your own app's logs. Bonus signal: knowing that `LogError(ex, message)` requires the exception as the *first* argument.

---

## Related Topics

- [[dotnet/webapi-configuration.md]] — Log levels and provider config come from the same `IConfiguration` pipeline; understanding configuration layering explains how log levels differ between environments.
- [[dotnet/dependency-injection.md]] — `ILogger<T>` reaches your class through DI; the generic type parameter is how the framework sets the log category automatically.
- [[dotnet/middleware-pipeline.md]] — Request logging middleware (like `app.UseSerilogRequestLogging()`) sits in the pipeline and adds per-request context to every log written during that request.
- [[devops/structured-logging-sinks.md]] — Where logs actually go in production: stdout for containers, Seq for local dev, Application Insights or Datadog for cloud.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/fundamentals/logging

---
*Last updated: 2026-03-24*