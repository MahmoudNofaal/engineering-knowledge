# WebAPI Logging

> The built-in .NET logging abstraction that lets you write structured log messages through a consistent interface, with the actual output destination (console, file, cloud) wired up separately at startup.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Abstraction over structured logging with pluggable sinks |
| **Use when** | Any time you need runtime visibility — always |
| **Avoid when** | Never avoid — but don't log on every iteration of a tight loop |
| **Introduced** | ASP.NET Core 1.0; `[LoggerMessage]` source generators added .NET 6 |
| **Namespace** | `Microsoft.Extensions.Logging` |
| **Key types** | `ILogger<T>`, `ILoggerFactory`, `LogLevel`, `LoggerMessage`, `ILoggingBuilder` |

---

## When To Use It

Use it any time you need visibility into what your application is doing at runtime — request tracing, errors, slow queries, business events. The abstraction matters because your service code shouldn't care whether logs go to the console, Application Insights, or Seq. Don't use `Console.WriteLine` in production code — it bypasses log levels, filtering, and structured data. Avoid over-logging hot paths; writing a structured log object on every iteration of a tight loop has real allocations.

---

## Core Concept

.NET logging has two layers: the `ILogger<T>` interface your code writes to, and one or more "providers" (sinks) that decide where those messages go. The framework routes messages based on category (the `T` in `ILogger<T>`, which is the class name) and minimum level. You inject `ILogger<T>` into your class and call `.LogInformation(...)` or `.LogError(...)`. The important shift from classic logging is *structured logging* — instead of formatting a string, you pass a message template with named holes (`"User {UserId} logged in"`) and the raw values separately, so downstream tools can query on `UserId` as a field rather than parsing a string.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | `ILogger<T>`, `ILoggerFactory`, `ILoggingBuilder`; Console and Debug providers |
| ASP.NET Core 3.0 | `LoggerMessage.Define` for high-performance pre-compiled log actions |
| .NET 6 | `[LoggerMessage]` source generators — compile-time log methods with zero boxing |
| .NET 7 | `ILogger.IsEnabled` improvements; structured logging enhancements |
| .NET 8 | Primary constructor logging pattern; `AddJsonConsole` improvements |

*`[LoggerMessage]` source generators (.NET 6) produce the same compiled delegates as `LoggerMessage.Define` but with far less boilerplate. For any hot-path logging, they're the modern standard.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `LogInformation` (level disabled) | ~1–5 ns | Level check short-circuits; no message construction |
| `LogInformation` (level enabled) | ~50–200 ns | Template formatting + provider dispatch |
| String interpolation log (always bad) | ~200–500 ns | Evaluates arguments even when level is disabled |
| `[LoggerMessage]` source-generated | ~10–50 ns | No boxing, no allocation for value types |
| `BeginScope` | ~50–100 ns | Dictionary allocation for scope state |

**Allocation behaviour:** Every call to `LogInformation(template, args)` with value type arguments boxes them into `object[]`. At high QPS this is measurable. `[LoggerMessage]` source generators avoid boxing by generating typed overloads. `BeginScope` allocates a dictionary for scope state — use sparingly in hot paths.

**Benchmark notes:** Logging overhead only matters in extremely tight loops (>1M calls/sec). For typical API request logging (one `LogInformation` per request), the overhead is unmeasurable. Measure with BenchmarkDotNet before optimising.

---

## The Code

**Basic injection and usage**
```csharp
public class OrderService
{
    private readonly ILogger<OrderService> _logger;

    public OrderService(ILogger<OrderService> logger) => _logger = logger;

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

**Minimum level config in appsettings.json**
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

**`[LoggerMessage]` source generators — zero boxing on hot paths (.NET 6+)**
```csharp
public partial class OrderService
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Order {OrderId} dispatched to {Carrier}")]
    private partial void LogOrderDispatched(int orderId, string carrier);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Payment retry {Attempt} for order {OrderId}")]
    private partial void LogPaymentRetry(int attempt, int orderId);
}
```

**Wiring up Serilog as a provider (common in production)**
```csharp
using Serilog;

Log.Logger = new LoggerConfiguration()
    .WriteTo.Console(new JsonFormatter())
    .WriteTo.Seq("http://localhost:5341")
    .Enrich.FromLogContext()
    .MinimumLevel.Override("Microsoft",     LogEventLevel.Warning)
    .MinimumLevel.Override("System.Net.Http", LogEventLevel.Warning)
    .CreateLogger();

builder.Host.UseSerilog();
```

**Adding context to all logs within a scope**
```csharp
using (_logger.BeginScope(new Dictionary<string, object>
{
    ["RequestId"] = requestId,
    ["UserId"]    = userId
}))
{
    // All log messages in this block carry RequestId and UserId automatically
    await ProcessAsync();
}
```

**Request logging middleware (Serilog)**
```csharp
// Logs every HTTP request with duration, status code, and all scope properties
app.UseSerilogRequestLogging(options =>
{
    options.EnrichDiagnosticContext = (diag, ctx) =>
    {
        diag.Set("UserId",    ctx.User.FindFirstValue(ClaimTypes.NameIdentifier));
        diag.Set("UserAgent", ctx.Request.Headers.UserAgent.ToString());
    };
});
```

---

## Real World Example

A high-throughput order processing service logs every state transition of an order using source-generated log methods to avoid boxing. Slow operations log a warning with duration. All logs carry a correlation ID from the request scope.

```csharp
public partial class OrderProcessingService
{
    private readonly ILogger<OrderProcessingService> _logger;

    public OrderProcessingService(ILogger<OrderProcessingService> logger)
        => _logger = logger;

    [LoggerMessage(Level = LogLevel.Information,
        Message = "Order {OrderId} transitioned from {FromStatus} to {ToStatus}")]
    private partial void LogStatusTransition(Guid orderId, string fromStatus, string toStatus);

    [LoggerMessage(Level = LogLevel.Warning,
        Message = "Order {OrderId} payment step took {DurationMs}ms — threshold is {ThresholdMs}ms")]
    private partial void LogSlowPayment(Guid orderId, long durationMs, int thresholdMs);

    [LoggerMessage(Level = LogLevel.Error,
        Message = "Order {OrderId} failed at step {Step}")]
    private partial void LogOrderFailure(Guid orderId, string step);

    public async Task ProcessAsync(Order order, CancellationToken ct)
    {
        using var scope = _logger.BeginScope(
            new Dictionary<string, object> { ["OrderId"] = order.Id });

        LogStatusTransition(order.Id, order.Status.ToString(), "Processing");
        order.Status = OrderStatus.Processing;

        var sw = Stopwatch.StartNew();
        try
        {
            await _payments.ChargeAsync(order, ct);
            sw.Stop();

            if (sw.ElapsedMilliseconds > 2_000)
                LogSlowPayment(order.Id, sw.ElapsedMilliseconds, thresholdMs: 2_000);

            LogStatusTransition(order.Id, "Processing", "Completed");
        }
        catch (Exception ex)
        {
            LogOrderFailure(order.Id, "payment");
            _logger.LogError(ex, "Unexpected error processing order {OrderId}", order.Id);
            throw;
        }
    }
}
```

*The key insight: `[LoggerMessage]` source generators produce partial methods that the compiler fills in with type-safe, non-boxing implementations. `LogSlowPayment(order.Id, sw.ElapsedMilliseconds, 2_000)` never boxes `Guid`, `long`, or `int` — unlike `_logger.LogWarning("... {DurationMs}ms", sw.ElapsedMilliseconds)` which boxes `long` into `object`. At 50,000 orders/second this difference is measurable.*

---

## Common Misconceptions

**"String interpolation and message templates are equivalent."**
Writing `_logger.LogInformation($"User {userId} logged in")` turns everything into a flat string — the `userId` value is baked into the message and cannot be queried as a field. The correct form `_logger.LogInformation("User {UserId} logged in", userId)` keeps `UserId` as a named property that structured sinks index and query. This is the most common mistake when teams switch to structured logging.

**"I can log exceptions anywhere in the message template."**
`LogError(ex, message, args...)` — the exception must be the FIRST argument, not part of the template. `_logger.LogError("Failed: {Ex}", ex)` serialises the exception as a string, losing the stack trace. `_logger.LogError(ex, "Failed for user {UserId}", userId)` captures the full exception object. Swapping the order is a silent mistake.

**"Logging level checks happen automatically before expensive work."**
`_logger.LogDebug(ExpensiveMethod())` evaluates `ExpensiveMethod()` regardless of whether Debug is enabled, because C# evaluates arguments before the call. Use `if (_logger.IsEnabled(LogLevel.Debug)) _logger.LogDebug(...)` or `[LoggerMessage]` source generators, which the compiler optimises to check the level before any argument evaluation.

---

## Gotchas

- **String interpolation kills structured logging.** `$"User {userId}"` produces a flat string. `"User {UserId}"` produces a structured field. Never interpolate into log templates.

- **`LogError(ex, message)` — exception goes first, message second.** Swapping is a silent mistake — the exception is serialised as a string value instead of as a structured exception with stack trace.

- **EF Core query logging floods logs at Information level.** Override `Microsoft.EntityFrameworkCore.Database.Command` to `Warning` in non-dev environments or every SQL query appears in production logs.

- **Log level filtering only avoids message construction if you use `[LoggerMessage]` or `IsEnabled`.** `_logger.LogDebug(ExpensiveToString())` evaluates `ExpensiveToString()` even when Debug is disabled because arguments are evaluated before the call.

- **`BeginScope` data only appears in output if the provider supports it.** The default Console provider shows scopes; many third-party sinks need `Enrich.FromLogContext()` or similar configuration.

- **High-cardinality log message templates cause index bloat in structured sinks.** `"Processing order {OrderId}"` where `OrderId` is a Guid creates a unique template instantiation per order in some sinks. Prefer consistent templates with values in named properties, not in the template string itself.

---

## Interview Angle

**What they're really testing:** Whether you understand the abstraction boundary between writing logs and routing them, and the difference between string-formatted and structured logging.

**Common question forms:**
- "How do you implement logging in ASP.NET Core?"
- "What's the difference between structured and unstructured logging?"
- "How do you avoid performance overhead in logging on hot paths?"

**The depth signal:** A junior describes injecting `ILogger<T>` and calling `.LogInformation(...)`. A senior explains why you never interpolate strings into templates, what named holes give you in tools like Seq or Application Insights, the boxing cost on value types and how `[LoggerMessage]` source generators solve it, and how to suppress framework noise with `MinimumLevel.Override`. Bonus: knowing `LogError(ex, message)` requires the exception as the first argument.

**Follow-up questions to expect:**
- "How would you add a correlation ID to every log message?"
- "What's the difference between `ILogger.BeginScope` and Serilog's `LogContext`?"
- "How do you configure different log levels for different environments?"

---

## Related Topics

- [[dotnet/webapi/webapi-configuration.md]] — log levels and provider config come from the same `IConfiguration` pipeline; environment-specific overrides control log verbosity per environment
- [[dotnet/webapi/dependency-injection.md]] — `ILogger<T>` is resolved via DI; the generic type parameter sets the log category automatically
- [[dotnet/webapi/middleware-pipeline.md]] — request logging middleware sits in the pipeline and enriches every log written during a request with HTTP context (path, method, status, duration)
- [[dotnet/webapi/webapi-exception-handling.md]] — exception handlers are where you log the full exception with trace ID; logging and exception handling are tightly coupled

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/fundamentals/logging

---
*Last updated: 2026-04-10*