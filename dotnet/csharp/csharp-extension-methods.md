# C# Extension Methods

> An extension method is a static method that you can call as if it were an instance method on a type you don't own or can't modify.

---

## When To Use It

Use extension methods to add behaviour to types you cannot modify — sealed classes, interfaces, third-party types, or primitives — and to write fluent, chainable APIs where method chaining reads naturally left to right. LINQ is entirely built on extension methods over `IEnumerable<T>`. Do not use them to work around poor object design in your own codebase — if you own the type, add the method to it directly. Do not use them to add state to a type; extension methods can only work with what is publicly accessible.

---

## Core Concept

An extension method is a static method in a static class whose first parameter has the `this` keyword. That keyword tells the compiler to make the method callable as if it belonged to the type of that first parameter. At the call site, `list.Shuffle()` looks like an instance method, but the compiler rewrites it to `CollectionExtensions.Shuffle(list)` — there is no difference in the generated IL. The method has no special access; it can only see the type's public members. Extension methods are resolved at compile time by scanning `using` namespaces, so adding a `using` directive can silently change which overload the compiler picks — a resolution rule that surprises people when two libraries define conflicting extensions on the same type.

---

## The Code
```csharp
// --- Basic extension method ---
public static class StringExtensions
{
    public static bool IsNullOrEmpty(this string? s) => string.IsNullOrEmpty(s);

    public static string Truncate(this string s, int maxLength)
    {
        if (s.Length <= maxLength) return s;
        return s[..maxLength] + "…";
    }

    public static string ToSlug(this string s) =>
        s.ToLowerInvariant()
         .Replace(' ', '-')
         .Where(c => char.IsLetterOrDigit(c) || c == '-')
         .Aggregate(new StringBuilder(), (sb, c) => sb.Append(c))
         .ToString();
}

// Call site — reads like instance methods
string title = "Hello World! This is a Test";
Console.WriteLine(title.Truncate(10));   // Hello Wor…
Console.WriteLine(title.ToSlug());       // hello-world-this-is-a-test
Console.WriteLine(((string?)null).IsNullOrEmpty()); // True — safe on null

// --- Extending an interface: add behaviour to every implementation ---
public static class EnumerableExtensions
{
    public static IEnumerable<T> WhereNotNull<T>(this IEnumerable<T?> source)
        where T : class
        => source.Where(x => x != null)!;

    // Fluent batching
    public static IEnumerable<IEnumerable<T>> Batch<T>(
        this IEnumerable<T> source, int size)
    {
        var batch = new List<T>(size);
        foreach (T item in source)
        {
            batch.Add(item);
            if (batch.Count == size)
            {
                yield return batch;
                batch = new List<T>(size);
            }
        }
        if (batch.Count > 0) yield return batch;
    }
}

string?[] names = { "Alice", null, "Bob", null, "Carol" };
foreach (string name in names.WhereNotNull())
    Console.WriteLine(name);

int[] nums = Enumerable.Range(1, 10).ToArray();
foreach (IEnumerable<int> chunk in nums.Batch(3))
    Console.WriteLine(string.Join(", ", chunk));

// --- Fluent builder pattern via extensions ---
public class QueryOptions
{
    public int Page     { get; set; } = 1;
    public int PageSize { get; set; } = 20;
    public string? OrderBy { get; set; }
}

public static class QueryOptionsExtensions
{
    public static QueryOptions WithPage(this QueryOptions o, int page)
        { o.Page = page; return o; }              // returns 'this' for chaining

    public static QueryOptions WithPageSize(this QueryOptions o, int size)
        { o.PageSize = size; return o; }

    public static QueryOptions OrderedBy(this QueryOptions o, string field)
        { o.OrderBy = field; return o; }
}

var options = new QueryOptions()
    .WithPage(2)
    .WithPageSize(50)
    .OrderedBy("CreatedAt");

// --- Extending a sealed third-party type ---
// HttpClient is sealed — we can't subclass it
public static class HttpClientExtensions
{
    public static async Task<T?> GetJsonAsync<T>(
        this HttpClient client, string url, CancellationToken ct = default)
    {
        using HttpResponseMessage response = await client.GetAsync(url, ct);
        response.EnsureSuccessStatusCode();
        string json = await response.Content.ReadAsStringAsync(ct);
        return System.Text.Json.JsonSerializer.Deserialize<T>(json);
    }
}

using var http = new HttpClient();
var user = await http.GetJsonAsync<User>("https://api.example.com/users/1");
```

---

## Gotchas

- **Extension methods cannot access private or protected members.** They only see what is public on the type. If you need access to internals, the extension is in the wrong place — the logic belongs inside the type itself or requires a different design.
- **An instance method always wins over an extension method with the same signature.** If the type later adds a method with the same name and compatible signature, your extension is silently shadowed everywhere. This is a breaking change risk for extension methods on types you don't own — a library update can invisibly replace your extension call with the type's own method, which may behave differently.
- **Calling an extension method on `null` does not throw automatically.** Unlike instance method calls, `null.Truncate(5)` does not produce a `NullReferenceException` before entering the method — control enters the static method with `s == null`. You must guard explicitly if null is invalid input. This is actually useful (as shown with `IsNullOrEmpty` above), but it surprises people who expect a null call to throw at the call site.
- **Resolution depends on `using` directives — ambiguous extensions cause compile errors.** If two static classes in different namespaces both define `string.ToSlug()` and both namespaces are imported, the compiler reports an ambiguous call. There is no runtime fallback; you must either remove one `using` or call the method as a static method directly: `MyNamespace.StringExtensions.ToSlug(title)`.
- **Extension methods on value types receive a copy, not a reference.** `this int n` in an extension method means `n` is a copy of the caller's value. Modifying `n` inside the method has no effect on the original. For mutation, the caller must use `ref` extensions (`this ref int n`), which are allowed but uncommon and require the call site to also write `ref`.

---

## Interview Angle

**What they're really testing:** Whether you understand that extension methods are compile-time syntactic sugar with no runtime magic — and can explain LINQ's design as a consequence of that.

**Common question form:** "How does LINQ work?" or "What is an extension method and how does the compiler resolve it?" or "Can you add methods to a type you don't own?"

**The depth signal:** A junior says "extension methods let you add methods to types you don't own" and knows the `this` keyword syntax. A senior explains that the compiler rewrites every extension call to a static call in generated IL — no virtual dispatch, no runtime indirection — which is why LINQ operators chain without overhead; that instance methods always shadow extensions with matching signatures, making library-owned type extensions a maintenance risk; that null calls enter the method body rather than throwing, which is both a safety gotcha and a deliberate design pattern (null-safe helpers); and that resolution is purely namespace-scoped at compile time, so conflicting extensions across libraries cause ambiguous-call errors that can only be resolved by removing a `using` or calling the static form explicitly.

---

## Related Topics

- [[dotnet/csharp-linq.md]] — Every LINQ operator (`Where`, `Select`, `OrderBy`, `GroupBy`) is an extension method on `IEnumerable<T>` or `IQueryable<T>`; extension methods are the mechanism that makes LINQ composable.
- [[dotnet/csharp-interfaces.md]] — Extending an interface with an extension method adds a default behaviour to every implementation without modifying any of them — a pattern used heavily in ASP.NET Core's `IServiceCollection` and `IApplicationBuilder` fluent APIs.
- [[dotnet/csharp-iterators.md]] — Custom LINQ-style extension methods like `Batch` and `WhereNotNull` use `yield return` internally; the two features compose naturally.
- [[dotnet/csharp-expression-trees.md]] — LINQ-to-SQL extension methods accept `Expression<Func<T>>` rather than `Func<T>`; understanding why requires knowing that the extension is just a method and the difference lies entirely in the parameter type.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/extension-methods](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/extension-methods)

---
*Last updated: 2026-03-23*