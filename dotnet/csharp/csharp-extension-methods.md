# C# Extension Methods

> A static method that you can call as if it were an instance method on a type you don't own or can't modify — enabling fluent APIs and adding behaviour to sealed, third-party, or interface types.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Static method callable as instance method via `this` keyword on first param |
| **Use when** | Adding methods to types you can't modify; fluent chaining; interface extensions |
| **Avoid when** | You own the type — add the method directly; or you need access to private state |
| **C# version** | C# 3.0 (.NET 3.5) |
| **Namespace** | The static class must be `using`-imported to be visible |
| **Key rule** | Instance methods always win over extension methods with the same signature |

---

## When To Use It

Use extension methods to:
- **Add methods to types you can't modify** — sealed BCL types, third-party libraries, primitive types
- **Write fluent, chainable APIs** — LINQ is entirely built on extension methods
- **Add default behaviour to interfaces** — all `IEnumerable<T>` implementations get `Where`, `Select`, etc. for free
- **Add utility methods to external types** — `HttpClient.GetJsonAsync<T>()`, `string.ToSlug()`

**Don't use extension methods when:**
- You own the type — adding an instance method is cleaner and has no namespace dependency
- You need access to private or protected state — extension methods only see the public API
- The method is actually a feature of the type's contract — it belongs as an instance method
- You're adding state — extension methods can only work with existing public members

---

## Core Concept

An extension method is a static method in a static class whose first parameter has the `this` keyword. The compiler rewrites `list.Shuffle()` to `CollectionExtensions.Shuffle(list)` — there is no difference in the generated IL. The method has no special access to private members; it only sees the public API.

Extension methods are resolved at compile time by scanning `using`-imported namespaces. Adding a `using` directive can silently change which overload the compiler picks — a resolution rule that surprises developers when two libraries define conflicting extensions on the same type.

**Instance methods always win.** If the type later adds a method with the same name and signature, your extension is silently shadowed. There's no warning — the call just goes to the instance method.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 3.0 | .NET 3.5 | Extension methods introduced |
| C# 3.0 | .NET 3.5 | LINQ built on top of extension methods |
| C# 8.0 | .NET Core 3.0 | Default interface methods (alternative for interface extension) |
| C# 10.0 | .NET 6 | Extended property patterns (unrelated but useful alongside extension methods) |

*LINQ's entire operator set (`Where`, `Select`, `GroupBy`, `OrderBy`, etc.) is implemented as extension methods on `IEnumerable<T>` and `IQueryable<T>`. Without extension methods, LINQ would require either inheriting from a base class or wrapping every collection in a query object.*

---

## Performance

| Scenario | Cost | Notes |
|---|---|---|
| Extension method call | Same as static method | Compiler rewrites to static call |
| Extension method vs instance method | Identical | Same IL emitted |
| `this` parameter | Zero | First parameter only — no boxing for value types |
| Closure in extension lambda | 1 display class allocation | Same as any lambda closure |

**Allocation behaviour:** Extension methods themselves allocate nothing extra. Any closures in lambdas passed to them allocate the same as any other lambda. The `this` parameter is passed by value — structs are copied unless you use `ref this` (C# 7.2+).

**Benchmark notes:** There is no measurable performance difference between calling an extension method and calling the equivalent static method directly. The compiler rewrite is complete — no runtime dispatch, no virtual lookup, no overhead.

---

## The Code

**Basic extension methods on BCL types**
```csharp
public static class StringExtensions
{
    // Called as: "hello world".ToTitleCase()
    public static string ToTitleCase(this string s)
        => System.Globalization.CultureInfo.CurrentCulture.TextInfo.ToTitleCase(s.ToLower());

    // Safe on null — extension methods don't throw before entering the body
    public static bool IsNullOrEmpty(this string? s) => string.IsNullOrEmpty(s);

    // Returns truncated string with ellipsis
    public static string Truncate(this string s, int maxLength)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(maxLength);
        return s.Length <= maxLength ? s : s[..maxLength] + "…";
    }

    // URL-friendly slug
    public static string ToSlug(this string s)
        => string.Concat(
            s.ToLowerInvariant()
             .Replace(' ', '-')
             .Where(c => char.IsLetterOrDigit(c) || c == '-'))
         .Trim('-');
}

string title = "Hello, World! This is a Test";
Console.WriteLine(title.Truncate(10));  // "Hello, Wor…"
Console.WriteLine(title.ToSlug());      // "hello-world-this-is-a-test"
Console.WriteLine(((string?)null).IsNullOrEmpty()); // True — safe on null
```

**Extending an interface — adds behaviour to ALL implementations**
```csharp
public static class EnumerableExtensions
{
    // Works on any IEnumerable<T?> — not just List
    public static IEnumerable<T> WhereNotNull<T>(this IEnumerable<T?> source)
        where T : class
        => source.Where(x => x is not null)!;

    // Lazy batching — splits sequence into chunks without materialising
    public static IEnumerable<IEnumerable<T>> Batch<T>(
        this IEnumerable<T> source, int batchSize)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(batchSize, 1);
        var batch = new List<T>(batchSize);
        foreach (T item in source)
        {
            batch.Add(item);
            if (batch.Count == batchSize)
            {
                yield return batch;
                batch = new List<T>(batchSize);
            }
        }
        if (batch.Count > 0) yield return batch;
    }

    // Safe FirstOrDefault that throws on multiple matches
    public static T? SingleOrDefaultSafe<T>(this IEnumerable<T> source, Func<T, bool> predicate)
    {
        T? found = default;
        bool hasMatch = false;
        foreach (T item in source)
        {
            if (!predicate(item)) continue;
            if (hasMatch) throw new InvalidOperationException("Sequence contains more than one matching element.");
            found = item; hasMatch = true;
        }
        return found;
    }
}

string?[] names = { "Alice", null, "Bob", null, "Charlie" };
foreach (string name in names.WhereNotNull())
    Console.WriteLine(name); // Alice, Bob, Charlie

int[] nums = Enumerable.Range(1, 10).ToArray();
foreach (var chunk in nums.Batch(3))
    Console.WriteLine(string.Join(", ", chunk)); // 1,2,3 / 4,5,6 / 7,8,9 / 10
```

**Fluent builder pattern via extension methods**
```csharp
public class QueryOptions
{
    public int     Page     { get; set; } = 1;
    public int     PageSize { get; set; } = 20;
    public string? OrderBy  { get; set; }
    public bool    Descending { get; set; }
    public string? SearchTerm { get; set; }
}

public static class QueryOptionsExtensions
{
    public static QueryOptions WithPage(this QueryOptions o, int page)
        { o.Page = page; return o; }

    public static QueryOptions WithPageSize(this QueryOptions o, int size)
        { o.PageSize = Math.Clamp(size, 1, 100); return o; }

    public static QueryOptions OrderedBy(this QueryOptions o, string field, bool descending = false)
        { o.OrderBy = field; o.Descending = descending; return o; }

    public static QueryOptions WithSearch(this QueryOptions o, string? term)
        { o.SearchTerm = term; return o; }
}

// Reads naturally left-to-right
var options = new QueryOptions()
    .WithPage(2)
    .WithPageSize(50)
    .OrderedBy("CreatedAt", descending: true)
    .WithSearch("widget");
```

**Extending a sealed third-party type**
```csharp
// HttpClient is sealed — we can't subclass it
// But we can add typed JSON methods as extensions
public static class HttpClientExtensions
{
    public static async Task<T?> GetJsonAsync<T>(
        this HttpClient client,
        string url,
        JsonSerializerOptions? options = null,
        CancellationToken ct = default)
    {
        using HttpResponseMessage response = await client.GetAsync(url, ct);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<T>(options, ct);
    }

    public static async Task<HttpResponseMessage> PostJsonAsync<T>(
        this HttpClient client,
        string url,
        T payload,
        CancellationToken ct = default)
        => await client.PostAsJsonAsync(url, payload, ct);
}

using var http = new HttpClient { BaseAddress = new Uri("https://api.example.com") };
var users = await http.GetJsonAsync<List<UserDto>>("/users");
```

**`ref this` on structs (C# 7.2) — mutate the original**
```csharp
public struct Counter
{
    public int Value;
}

// Without 'ref this': extension gets a copy — mutations don't affect original
public static void IncrementCopy(this Counter c) => c.Value++; // useless

// With 'ref this': extension gets reference to original — mutation works
public static void Increment(ref this Counter c) => c.Value++;

var counter = new Counter { Value = 0 };
counter.Increment();  // ref extension — Value is now 1
counter.IncrementCopy(); // copy — Value is still 1
```

---

## Real World Example

An ASP.NET Core application registers services through fluent extension methods on `IServiceCollection`. This is the exact pattern Microsoft uses in the BCL — each feature area adds its own extension methods to the same interface.

```csharp
// Each service area encapsulates its own registration
public static class OrderingServiceExtensions
{
    public static IServiceCollection AddOrderingServices(
        this IServiceCollection services,
        Action<OrderingOptions>? configure = null)
    {
        var options = new OrderingOptions();
        configure?.Invoke(options);

        services.AddSingleton(options);
        services.AddScoped<IOrderRepository, SqlOrderRepository>();
        services.AddScoped<IOrderService, OrderService>();
        services.AddScoped<OrderValidationPipeline>();
        services.AddScoped<IValidator<Order>, OrderAmountValidator>();
        services.AddScoped<IValidator<Order>, OrderItemsValidator>();

        if (options.EnableEmailNotifications)
        {
            services.AddScoped<IOrderEventHandler, OrderEmailNotifier>();
        }

        return services; // return IServiceCollection for chaining
    }
}

public static class NotificationServiceExtensions
{
    public static IServiceCollection AddNotificationServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.Configure<SmtpOptions>(configuration.GetSection("Smtp"));
        services.AddSingleton<IEmailService, SmtpEmailService>();
        services.AddSingleton<ISmsGateway, TwilioSmsGateway>();
        services.AddScoped<INotificationChannel, EmailChannel>();
        services.AddScoped<INotificationChannel, SmsChannel>();
        services.AddScoped<NotificationDispatcher>();
        return services;
    }
}

// Program.cs — reads like a declarative composition
builder.Services
    .AddOrderingServices(opts => opts.EnableEmailNotifications = true)
    .AddNotificationServices(builder.Configuration)
    .AddDbContext<AppDbContext>(opts => opts.UseSqlServer(connectionString))
    .AddHttpClient();
```

*The key insight: each feature area owns its own registration code. `Program.cs` becomes a declarative list of what the application is composed of, without knowing any implementation details. `AddOrderingServices` can change its internal registrations — add a cache, swap a repository, add a new validator — without `Program.cs` changing at all. This is the composition root pattern enabled by extension methods on `IServiceCollection`.*

---

## Common Misconceptions

**"Extension methods can access private members of the extended type"**
Extension methods have no special access. They only see the public API — exactly what any external code would see. If you need to access private state, the method belongs inside the type itself, not as an extension.

**"An instance method always silently wins — I'll find out at runtime"**
Instance methods always win over extension methods with the same signature — but this is a compile-time resolution, not a runtime one. If the type adds a matching instance method after your extension was written, the compiler silently switches to calling the instance method. There's no warning. The code still compiles; it just calls a different method. This can be a subtle source of behaviour changes after a library upgrade.

**"Extension methods can be called on null"**
Extension methods can be called with a null `this` argument — the call enters the method body with the first parameter as null, rather than throwing before entry. This is intentional (it allows null-safe helper methods) but surprises people who expect a `NullReferenceException` at the call site. You must guard for null inside the method if null is invalid.

---

## Gotchas

- **Instance methods always shadow extension methods with the same signature.** There's no warning when this happens — the compiler silently switches. If you're writing extensions for types you don't own, a library update can silently change which method is called.

- **Resolution depends on `using` directives — conflicting extensions cause compile errors.** If two static classes in different namespaces both define `string.ToSlug()` and both namespaces are imported, the compiler reports an ambiguous call. The only fixes are removing one `using` or calling the static form directly: `MyNamespace.StringExtensions.ToSlug(title)`.

- **Extension methods on value types receive a copy, not a reference.** `this int n` in an extension method means `n` is a copy — modifying it does nothing to the caller's variable. Use `ref this` (C# 7.2+) to get a reference instead, but the caller must also use a `ref` variable.

- **Extension methods aren't visible across assemblies without a `using`.** An extension method in `MyLibrary.Extensions` is invisible to callers until they add `using MyLibrary.Extensions`. This is a discoverability problem — document which namespace to import.

- **You can't call extension methods through reflection without knowing the declaring class.** Reflection sees extension methods as static methods on the declaring class, not as members of the extended type. `typeof(string).GetMethod("ToSlug")` returns null; you need `typeof(StringExtensions).GetMethod("ToSlug")`.

---

## Interview Angle

**What they're really testing:** Whether you understand that extension methods are compile-time syntactic sugar with no runtime magic — and can explain LINQ's design as a consequence.

**Common question forms:**
- "How does LINQ work internally?"
- "What is an extension method and how does the compiler resolve it?"
- "Can you add methods to a type you don't own?"
- "What happens if a type adds an instance method that conflicts with your extension?"

**The depth signal:** A junior says "extension methods let you add methods to types you don't own" and knows the `this` keyword syntax. A senior explains that the compiler rewrites every extension call to a static call — no virtual dispatch, no runtime indirection — which is why LINQ operators chain without overhead. They know that instance methods always shadow extensions with matching signatures (compile-time, no warning), that null calls enter the method body rather than throwing, and that conflicting extensions across libraries cause ambiguous-call compile errors that can only be resolved by removing a `using` or calling the static form explicitly.

**Follow-up questions to expect:**
- "Can you extend a `static` class with extension methods?"
- "What is the difference between extending an interface and extending a class?"
- "Why does calling an extension method on null not always throw?"

---

## Related Topics

- [[dotnet/csharp/csharp-linq-basics.md]] — Every LINQ operator is an extension method on `IEnumerable<T>` or `IQueryable<T>`; extension methods are what make LINQ composable
- [[dotnet/csharp/csharp-interfaces.md]] — Extending an interface adds behaviour to every implementation; this is how LINQ extends every collection type
- [[dotnet/csharp/csharp-iterators.md]] — Custom LINQ-style extension methods like `Batch` and `WhereNotNull` use `yield return` internally
- [[dotnet/csharp/csharp-expression-trees.md]] — LINQ-to-SQL extension methods accept `Expression<Func<T>>` rather than `Func<T>`; the parameter type difference is what routes execution to the database

---

## Source

[Extension Methods — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/extension-methods)

---

*Last updated: 2026-04-06*