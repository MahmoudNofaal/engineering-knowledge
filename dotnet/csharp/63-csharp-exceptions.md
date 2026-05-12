# C# Exceptions

> An exception is a runtime signal that something went wrong that the normal return path can't express — caught with `try/catch/finally`, filtered with `when`, and propagated up the call stack until handled or fatal.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Runtime error propagation via stack unwinding |
| **Use when** | Unexpected, unrecoverable conditions the caller can't reasonably predict |
| **Avoid when** | Expected outcomes — use `TryParse`, `TryGetValue`, `Result<T>` instead |
| **C# version** | C# 1.0 (exception filters `when`: C# 6.0, `ExceptionDispatchInfo`: .NET 4.5) |
| **Namespace** | `System` |
| **Base class** | `System.Exception` → `System.ApplicationException` or direct |

---

## When To Use It

Throw exceptions for conditions that represent a genuine failure of a contract — a method received arguments that violate its preconditions, a network call failed, a file wasn't found when it was expected to exist. Exceptions are for the *unexpected*.

Don't use exceptions for expected, frequent outcomes. `int.TryParse` returns `false` for invalid input without allocating an exception. `Dictionary.TryGetValue` returns `false` for missing keys. These are expected outcomes, not failures. Using exceptions for control flow is a correctness and performance problem — allocating an exception with a full stack trace is orders of magnitude slower than a boolean return.

**The caller decides what to handle.** A method should throw when it cannot fulfil its contract. The decision of whether that failure is recoverable belongs to the caller, not the method.

---

## Core Concept

When an exception is thrown, the runtime starts unwinding the call stack — leaving each stack frame and running any `finally` blocks along the way. It searches each frame for a matching `catch`. If none is found, the exception becomes unhandled and typically crashes the process.

`finally` always runs — whether execution leaves normally, via `return`, or via an exception. It's the guaranteed cleanup path. The `using` statement is syntactic sugar over `try/finally` calling `Dispose()`.

**Exception filters** (`when`) let you attach a condition to a `catch` without catching the exception if the condition is false. The key distinction: a failed `when` does not unwind the stack — the filter is evaluated while the original stack is still intact, which preserves the stack trace for debugging tools.

**`ExceptionDispatchInfo`** captures an exception with its original stack trace and lets you rethrow it from a different context without overwriting the trace. This is how `await` preserves async exception context.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | `try/catch/finally`, `throw`, exception hierarchy |
| C# 2.0 | .NET 2.0 | Generic exception types; `yield` in try/finally |
| .NET 4.5 | — | `ExceptionDispatchInfo` for stack-preserving rethrow |
| C# 6.0 | .NET 4.6 | Exception filters: `catch (Exception ex) when (condition)` |
| C# 6.0 | .NET 4.6 | `await` in `catch` and `finally` blocks |
| C# 7.0 | .NET Core 1.0 | Pattern matching in `catch`: `catch (Exception ex) when (ex is ...)` |
| .NET 6 | — | `UnreachableException` for impossible code paths |
| .NET 8 | — | `Debug.Assert` throw in release builds via `[DoesNotReturn]` |

*Before C# 6, you could not `await` inside a `catch` or `finally` block. This forced awkward patterns where you'd catch the exception, store it in a variable, and rethrow after the finally's awaitable completed.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Normal path (no exception) | Near zero | `try` blocks themselves have negligible cost |
| Throwing an exception | ~1–10 µs | Stack trace capture is expensive |
| Catching an exception | ~1 µs | Cheaper than throwing |
| `when` filter evaluation | ~1 ns | Evaluated before stack unwind |
| `ExceptionDispatchInfo.Capture` | ~100 ns | Saves the full exception state |

**Allocation behaviour:** Throwing allocates the exception object and captures a full stack trace (string allocation, walking the call stack). At high frequency this is a significant allocation source. Never use `throw new Exception()` in a path that runs millions of times per second — use a `bool` return or `Result<T>` instead.

**Benchmark notes:** The `try` block itself has no measurable overhead — the cost is in *throwing*, not in *guarding*. Wrapping a hot path in `try` is fine. Throwing in a hot path is not.

---

## The Code

**Basic try/catch/finally**
```csharp
try
{
    var data = File.ReadAllText("config.json");
    var config = JsonSerializer.Deserialize<AppConfig>(data);
    return config!;
}
catch (FileNotFoundException ex)
{
    logger.LogWarning("Config file not found: {Path}", ex.FileName);
    return AppConfig.Default;
}
catch (JsonException ex)
{
    logger.LogError(ex, "Config file is malformed");
    throw; // rethrow — we can't recover from bad config, let it propagate
}
finally
{
    logger.LogDebug("Config load attempt complete"); // always runs
}
```

**Exception filters (`when`) — conditional catch without swallowing**
```csharp
// catch only if the HTTP status is a specific code
catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.ServiceUnavailable)
{
    return await RetryAfterDelayAsync(ct);
}

// log without catching — filter evaluates, condition is false, exception propagates
// stack trace stays intact for diagnostics because the stack isn't unwound
catch (Exception ex) when (LogAndRethrow(ex))
{
    // never reached — LogAndRethrow always returns false
}

static bool LogAndRethrow(Exception ex)
{
    logger.LogError(ex, "Unhandled exception");
    return false; // returning false means: don't catch, let it propagate
}
```

**Rethrowing correctly**
```csharp
// WRONG: rethrow with 'throw ex' — resets the stack trace to THIS line
catch (Exception ex)
{
    logger.LogError(ex, "Failed");
    throw ex; // stack trace now starts here — original call site lost
}

// CORRECT: bare 'throw' preserves the original stack trace
catch (Exception ex)
{
    logger.LogError(ex, "Failed");
    throw; // original stack trace preserved
}

// CORRECT: ExceptionDispatchInfo — rethrow from a different context
ExceptionDispatchInfo? captured = null;
try { DoWork(); }
catch (Exception ex) { captured = ExceptionDispatchInfo.Capture(ex); }

// ... some time later, possibly on a different thread ...
captured?.Throw(); // throws with ORIGINAL stack trace intact
```

**Custom exception types**
```csharp
// Base domain exception — all domain exceptions inherit from this
public class DomainException : Exception
{
    public string ErrorCode { get; }

    public DomainException(string errorCode, string message)
        : base(message)
    {
        ErrorCode = errorCode;
    }

    public DomainException(string errorCode, string message, Exception innerException)
        : base(message, innerException)
    {
        ErrorCode = errorCode;
    }
}

// Specific exception with domain context
public class OrderNotFoundException : DomainException
{
    public Guid OrderId { get; }

    public OrderNotFoundException(Guid orderId)
        : base("ORDER_NOT_FOUND", $"Order {orderId} does not exist.")
    {
        OrderId = orderId;
    }
}

public class InsufficientStockException : DomainException
{
    public int ProductId  { get; }
    public int Requested  { get; }
    public int Available  { get; }

    public InsufficientStockException(int productId, int requested, int available)
        : base("INSUFFICIENT_STOCK",
               $"Product {productId}: requested {requested}, available {available}.")
    {
        ProductId = productId;
        Requested = requested;
        Available = available;
    }
}

// Caller catches at the right level
try
{
    await orderService.PlaceOrderAsync(request, ct);
}
catch (OrderNotFoundException ex)
{
    return NotFound(new { ex.OrderId, ex.Message });
}
catch (InsufficientStockException ex)
{
    return Conflict(new { ex.ProductId, ex.Requested, ex.Available, ex.Message });
}
catch (DomainException ex)
{
    return BadRequest(new { ex.ErrorCode, ex.Message });
}
```

**`await` in catch and finally (C# 6+)**
```csharp
public async Task ProcessAsync(Order order, CancellationToken ct)
{
    try
    {
        await _gateway.ChargeAsync(order.Total, ct);
        await _repository.MarkPaidAsync(order.Id, ct);
    }
    catch (PaymentException ex)
    {
        // await is valid in catch since C# 6 — no workarounds needed
        await _repository.MarkFailedAsync(order.Id, ex.Message, ct);
        await _notifier.SendFailureEmailAsync(order.CustomerEmail, ct);
        throw; // still rethrow after cleanup if caller needs to know
    }
    finally
    {
        // await is valid in finally since C# 6
        await _auditLog.RecordAttemptAsync(order.Id, ct);
    }
}
```

**AggregateException — Task.WhenAll and Parallel**
```csharp
Task[] tasks = { TaskA(ct), TaskB(ct), TaskC(ct) };
try
{
    await Task.WhenAll(tasks);
}
catch (Exception)
{
    // await only rethrows the FIRST exception from WhenAll
    // All exceptions are available on faulted tasks
    var allErrors = tasks
        .Where(t => t.IsFaulted)
        .SelectMany(t => t.Exception!.InnerExceptions)
        .ToList();

    foreach (var error in allErrors)
        logger.LogError(error, "Task failed");

    throw; // rethrow the first one
}
```

**ArgumentException helpers — .NET 6+ throw helpers**
```csharp
public void Process(string? name, int count, IEnumerable<Order> orders)
{
    // ArgumentNullException.ThrowIfNull — .NET 6+
    ArgumentNullException.ThrowIfNull(name);
    ArgumentNullException.ThrowIfNull(orders);

    // ArgumentOutOfRangeException.ThrowIfNegative — .NET 8+
    ArgumentOutOfRangeException.ThrowIfNegative(count);
    ArgumentOutOfRangeException.ThrowIfZero(count);

    // ArgumentException.ThrowIfNullOrEmpty — .NET 7+
    ArgumentException.ThrowIfNullOrEmpty(name);
    ArgumentException.ThrowIfNullOrWhiteSpace(name);

    // ObjectDisposedException.ThrowIf — .NET 7+
    ObjectDisposedException.ThrowIf(_disposed, this);
}
```

---

## Real World Example

An API middleware catches all unhandled exceptions, logs them with correlation context, and converts them to appropriate HTTP responses — using exception filters to distinguish domain errors from infrastructure failures.

```csharp
public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
        => (_next, _logger) = (next, logger);

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            // Client disconnected — not an error, don't log as error
            _logger.LogDebug("Request cancelled by client: {Path}", context.Request.Path);
            context.Response.StatusCode = 499;
        }
        catch (DomainException ex)
        {
            _logger.LogWarning(ex, "Domain error {Code}: {Message}", ex.ErrorCode, ex.Message);
            context.Response.StatusCode = ex.ErrorCode switch
            {
                "ORDER_NOT_FOUND"     => 404,
                "INSUFFICIENT_STOCK"  => 409,
                "VALIDATION_FAILED"   => 422,
                _                     => 400
            };
            await context.Response.WriteAsJsonAsync(new
            {
                error   = ex.ErrorCode,
                message = ex.Message
            });
        }
        catch (Exception ex)
        {
            // Unexpected — log with full context, return generic error
            var correlationId = context.TraceIdentifier;
            _logger.LogError(ex, "Unhandled exception {CorrelationId}: {Path}",
                correlationId, context.Request.Path);

            context.Response.StatusCode = 500;
            await context.Response.WriteAsJsonAsync(new
            {
                error         = "INTERNAL_ERROR",
                correlationId = correlationId,
                message       = "An unexpected error occurred."
            });
        }
    }
}
```

*The key insight: `when (context.RequestAborted.IsCancellationRequested)` filters `OperationCanceledException` without catching all cancellations — a background task cancelling would fall through to the generic handler. The filter is evaluated before stack unwind, so the original context is preserved in diagnostics. This is exactly the value of exception filters over nested if-checks inside catch.*

---

## Common Misconceptions

**"catch (Exception ex) { throw ex; } rethrows the exception"**
It does rethrow, but it **resets the stack trace** to the current line. The original call site that caused the exception is lost, which makes debugging significantly harder. Always use bare `throw;` (no argument) to rethrow while preserving the original trace. The only time `throw ex;` makes sense is when you intentionally want to hide the original source — which is almost never.

**"finally doesn't run if an exception is unhandled"**
`finally` runs even for unhandled exceptions — the stack still unwinds. The only exceptions to this are `StackOverflowException`, `ExecutionEngineException`, and process-terminating conditions where the runtime itself can't safely continue.

**"Exception filters (when) are just syntactic sugar for if inside catch"**
They're fundamentally different. An `if` inside a `catch` block catches the exception first (unwinding the stack), then checks the condition. A `when` filter is evaluated **before** the stack unwinds. This preserves the original exception context for debuggers and diagnostics tools that attach on first-chance exceptions. Filtering with `when` is the correct pattern when you need conditional catching.

---

## Gotchas

- **`throw ex;` destroys the original stack trace.** Always use bare `throw;` inside a catch block when you want to rethrow. The compiler gives no warning about this.

- **Swallowing exceptions silently is the most common exception bug.** An empty `catch {}` or `catch (Exception) { return null; }` hides failures that should be investigated. At minimum, log before swallowing. Prefer `when` filters or rethrowing.

- **`AggregateException` from `Task.WhenAll` wraps only the surface exception on `await`.** All inner exceptions are on the faulted `Task.Exception.InnerExceptions`. If you only catch the first, you miss the rest. Inspect all tasks explicitly when total failure visibility matters.

- **Don't catch `Exception` at a low level unless you're middleware/infrastructure.** Catching `Exception` in a service method swallows every possible failure — NullReferenceException, StackOverflowException (almost), OutOfMemoryException — turning unknown bugs into silent corruption. Catch specific exception types.

- **`OperationCanceledException` is not an error.** Cancellation is a cooperative, expected outcome. Don't log it as an error. Do distinguish between external cancellation (`ct.IsCancellationRequested`) and internal timeout/cancellation using `when` filters.

- **Custom exception constructors must include the three standard overloads.** A well-designed custom exception provides: `(string message)`, `(string message, Exception inner)`, and for serialisable exceptions, `(SerializationInfo, StreamingContext)` (legacy, less critical in modern .NET). Missing the `inner` overload makes it impossible for callers to wrap your exception with context.

---

## Interview Angle

**What they're really testing:** Whether you understand the exception mechanism as a propagation and cleanup system — not just the syntax — and whether you know the anti-patterns that turn exceptions into debugging nightmares.

**Common question forms:**
- "What's the difference between `throw` and `throw ex`?"
- "What are exception filters and when would you use them?"
- "What does `finally` do and when does it not run?"
- "How do you handle exceptions in async code?"
- "When should you NOT use exceptions?"

**The depth signal:** A junior knows try/catch/finally and that you should "throw without ex." A senior explains *why* — `throw ex` resets the stack trace pointer to the current frame, while `throw` preserves the original location. They explain that exception filters are evaluated before stack unwind (unlike an `if` inside a `catch`), making them the correct tool for conditional handling and side-effect-only catch patterns. They know `AggregateException.InnerExceptions` for `Task.WhenAll`, can explain `ExceptionDispatchInfo` for cross-context rethrow, and will immediately flag empty catch blocks as a red flag in code review.

**Follow-up questions to expect:**
- "Why does `await` preserve the original exception stack trace rather than wrapping in AggregateException?"
- "How would you implement a global exception handler in ASP.NET Core?"
- "What's the difference between `DomainException` and `ApplicationException` in your design?"

---

## Related Topics

- [csharp-async-await.md](csharp-async-await.md) — Async exception propagation, `await` in catch/finally, `OperationCanceledException`
- [csharp-task-parallel-library.md](csharp-task-parallel-library.md) — `AggregateException` from `Task.WhenAll`, faulted task inspection
- [csharp-control-flow.md](csharp-control-flow.md) — Exception-as-control-flow anti-pattern vs TryParse/TryGetValue
- [csharp-idisposable.md](csharp-idisposable.md) — `finally` as the cleanup mechanism; `using` as try/finally sugar
- [csharp-cancellation-token.md](csharp-cancellation-token.md) — `OperationCanceledException` is cooperative cancellation, not an error

---

## Source

[Exceptions and Exception Handling — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/exceptions/)

---
*Last updated: 2026-05-13*
