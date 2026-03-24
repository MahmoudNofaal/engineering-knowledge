# Middleware Pipeline

> A chain of components in ASP.NET Core where each component can process an HTTP request, decide to pass it to the next component, and then process the response on the way back out.

---

## When To Use It

Any time you need logic that applies to every request — or a defined subset of requests — without putting that logic inside individual controllers. Authentication, logging, exception handling, CORS, response compression, request timing — all of these belong in the pipeline, not in your business logic. If you find yourself writing the same cross-cutting code in multiple controllers, that is the signal to move it into middleware.

---

## Core Concept

Think of the pipeline as a series of nested functions, each wrapping the next. A request enters the first middleware, which does something, then calls `next()` to pass it forward. Eventually the request reaches your controller, gets handled, and then the response travels *back* through each middleware in reverse order. This two-way flow is the key insight — each middleware has a chance to act both before and after the rest of the pipeline runs. The order you register middleware in `Program.cs` is the exact order it executes — this is not a detail, it is everything. Registering authentication after routing means routing runs on unauthenticated requests. Order is your responsibility.

---

## The Code

### 1. The pipeline execution order

```csharp
// Program.cs — order here = execution order. Not negotiable.
var app = builder.Build();

app.UseExceptionHandler("/error");  // must be first — wraps everything else
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();            // must come before Authorization
app.UseAuthorization();             // depends on Authentication running first
app.MapControllers();               // terminal — handles the request, no 'next'

app.Run();
```

### 2. Writing your own middleware (class-based, preferred)

```csharp
// A middleware that logs request duration
public class RequestTimingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestTimingMiddleware> _logger;

    public RequestTimingMiddleware(RequestDelegate next, ILogger<RequestTimingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var sw = Stopwatch.StartNew();

        await _next(context);           // everything BEFORE this = request phase
                                        // everything AFTER this = response phase

        sw.Stop();
        _logger.LogInformation(
            "{Method} {Path} completed in {Ms}ms",
            context.Request.Method,
            context.Request.Path,
            sw.ElapsedMilliseconds);
    }
}

// Register it as an extension method — clean, discoverable
public static class RequestTimingMiddlewareExtensions
{
    public static IApplicationBuilder UseRequestTiming(this IApplicationBuilder app)
        => app.UseMiddleware<RequestTimingMiddleware>();
}

// Use it in Program.cs like any built-in middleware
app.UseRequestTiming();
```

### 3. Inline middleware with Use() — for quick, simple cases

```csharp
// Use() passes to the next middleware
app.Use(async (context, next) =>
{
    // request phase
    context.Items["RequestId"] = Guid.NewGuid();

    await next.Invoke();    // call the rest of the pipeline

    // response phase — runs after controller has responded
    context.Response.Headers.Append("X-Request-Id",
        context.Items["RequestId"]?.ToString());
});

// Run() is terminal — it does NOT call next. Pipeline stops here.
app.Run(async context =>
{
    await context.Response.WriteAsync("No further middleware runs after this.");
});
```

### 4. Short-circuiting — stopping the pipeline deliberately

```csharp
// Useful for things like maintenance mode, IP blocking, health checks
app.Use(async (context, next) =>
{
    if (context.Request.Path == "/health")
    {
        // respond immediately — controller never runs
        context.Response.StatusCode = 200;
        await context.Response.WriteAsync("healthy");
        return;     // no call to next() — pipeline short-circuits here
    }

    await next.Invoke();
});
```

---

## Gotchas

- **Order is everything.** `UseAuthentication()` must come before `UseAuthorization()`. `UseRouting()` must come before any middleware that uses endpoint metadata. `UseExceptionHandler()` must be first so it can catch exceptions from everything else. Getting this wrong produces bugs that are maddening to diagnose because the code looks correct.

- **`Use()` vs `Run()` vs `Map()`:** `Use()` can call next or short-circuit. `Run()` is always terminal — never calls next. `Map()` branches the pipeline based on path. Mixing these up is a common mistake, especially using `Run()` when you meant `Use()` and then wondering why the rest of your pipeline never executes.

- **Response has already started:** once you start writing to the response body (`context.Response.WriteAsync` or the controller has returned), you cannot change headers or status code. Trying to do so throws an exception. If your middleware needs to modify the response, it must do so before calling `next()` or by buffering the response — which has its own complexity.

- **Middleware is a singleton in behavior.** Middleware classes are instantiated once and reused across all requests. Do not store request-scoped state in middleware fields. Use `HttpContext.Items` for per-request state, or inject scoped services through `InvokeAsync` parameters, not the constructor.

- **Exception middleware scope:** `UseExceptionHandler` only catches exceptions that bubble up through the pipeline. If you swallow an exception inside a background task or a fire-and-forget call, it will not be caught.

---

## Interview Angle

**What they're really testing:** Whether you understand the pipeline as a first-class architectural concept — not just middleware as something the framework handles invisibly. They want to know you can reason about order, short-circuiting, and where cross-cutting concerns belong.

**Common question form:** *"How does the ASP.NET Core request pipeline work?"* / *"Where would you put authentication logic and why?"* / *"What is the difference between Use, Run, and Map?"* / *"How would you build a middleware that measures request duration?"*

**The depth signal:** A junior answer describes middleware as "code that runs before the controller." A senior answer explains the two-way pipeline flow (request phase → controller → response phase), explains why order in `Program.cs` is critical with a concrete example (auth before authz), explains the difference between `Use`, `Run`, and `Map` with their behavioral implications, explains short-circuiting and when to use it deliberately, and can discuss the singleton-behavior gotcha around request-scoped state in middleware fields. Bonus depth: mentioning that built-in middleware like `UseRouting` and `UseEndpoints` split what used to be a single operation in earlier ASP.NET versions — shows you know the history.

---

## Related Topics

- [[dotnet/dependency-injection]] — middleware constructors use DI; scoped services injected via `InvokeAsync` not the constructor
- [[dotnet/filters]] — filters (action, result, exception) run inside the MVC layer, after routing; not the same as middleware even though they look similar
- [[dotnet/exception-handling]] — `UseExceptionHandler` and `UseDeveloperExceptionPage` are both middleware; understanding the pipeline explains why they must be first
- [[system-design/cross-cutting-concerns]] — middleware is the implementation pattern for logging, auth, tracing, rate limiting at the infrastructure level

---

## Source

[ASP.NET Core Middleware — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware)

---

*Last updated: 2025-03-23*