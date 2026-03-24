# C# Iterators

> An iterator is a method that uses `yield return` to produce a sequence one element at a time, pausing execution between each element instead of building the entire collection up front.

---

## When To Use It

Use iterators when you want to produce a potentially large or infinite sequence without materialising it all in memory at once — reading lines from a file, paginating through an API, generating a Fibonacci series, or flattening a tree. They are also the right tool when the caller may stop consuming early, since elements that are never requested are never computed. Do not use iterators when random access or a known count is required — `yield` produces `IEnumerable<T>`, which is forward-only. Do not use them when the sequence must be thread-safe or when the generation logic has meaningful side effects that must run to completion regardless of how many items the caller consumes.

---

## Core Concept

When the compiler sees `yield return` in a method, it rewrites the entire method into a state machine class. Calling the method returns an object of that class — no code in the method body runs yet. Each time the caller calls `MoveNext()` (which `foreach` does for you), the state machine resumes from where it last paused, runs until the next `yield return`, delivers that value, and pauses again. `yield break` tells the state machine to signal completion. This lazy evaluation is the key property: if you call `Take(3)` on an infinite sequence, only three elements are ever produced. The cost is that the compiler-generated state machine is a heap-allocated object, and re-enumerating requires calling the method again to get a fresh one.

---

## The Code
```csharp
// --- Basic iterator: infinite sequence ---
static IEnumerable<int> Fibonacci()
{
    int a = 0, b = 1;
    while (true)
    {
        yield return a;
        (a, b) = (b, a + b); // state is preserved between yields
    }
}

foreach (int n in Fibonacci().Take(8))
    Console.Write(n + " "); // 0 1 1 2 3 5 8 13

// --- File reading: no List<string> in memory ---
static IEnumerable<string> ReadLines(string path)
{
    using var reader = new StreamReader(path);
    string? line;
    while ((line = reader.ReadLine()) != null)
        yield return line;
    // StreamReader disposed when iteration ends OR caller breaks out early
}

foreach (string line in ReadLines("data.txt").Where(l => l.StartsWith("ERROR")))
    Console.WriteLine(line);

// --- yield break: conditional early termination ---
static IEnumerable<int> TakeWhilePositive(IEnumerable<int> source)
{
    foreach (int n in source)
    {
        if (n < 0) yield break;  // stops the sequence
        yield return n;
    }
}

// --- Tree flattening: recursive iterator ---
class Node
{
    public int Value;
    public List<Node> Children = new();
}

static IEnumerable<int> Flatten(Node root)
{
    yield return root.Value;
    foreach (var child in root.Children)
        foreach (int v in Flatten(child)) // each recursive call is its own enumerator
            yield return v;
}

// --- IEnumerator<T> with Reset: implement IEnumerable<T> on a class ---
class Range : IEnumerable<int>
{
    private readonly int _start, _end;
    public Range(int start, int end) => (_start, _end) = (start, end);

    public IEnumerator<int> GetEnumerator()
    {
        for (int i = _start; i <= _end; i++)
            yield return i;
    }

    System.Collections.IEnumerator System.Collections.IEnumerable.GetEnumerator()
        => GetEnumerator(); // non-generic interface bridge
}

foreach (int n in new Range(1, 5))
    Console.Write(n + " "); // 1 2 3 4 5

// --- Async iterator (C# 8+): IAsyncEnumerable<T> ---
static async IAsyncEnumerable<string> FetchPagesAsync(string baseUrl,
    [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken ct = default)
{
    int page = 1;
    while (true)
    {
        string json = await FetchJsonAsync($"{baseUrl}?page={page}", ct);
        if (string.IsNullOrEmpty(json)) yield break;
        yield return json;
        page++;
    }
}

await foreach (string page in FetchPagesAsync("https://api.example.com/items"))
    Console.WriteLine(page);
```

---

## Gotchas

- **Iterator methods execute no code until first `MoveNext`.** If your method has argument validation at the top (`if (path == null) throw ...`), that exception is not thrown when the caller invokes the method — it is thrown when the caller first iterates. Wrap the iterator in a non-iterator method that validates eagerly, then delegates to the `yield` method.
- **`using` inside an iterator is disposed when the enumerator is disposed, not when the method returns.** If the caller abandons the `foreach` early (via `break` or an exception), the enumerator is disposed by the runtime and `finally` blocks run correctly — but only if the caller properly disposes the enumerator. A `foreach` loop always disposes; a raw `GetEnumerator()` call without `using` does not.
- **Re-enumerating calls the method again, creating a fresh state machine.** Assigning an iterator to a variable and enumerating it twice runs the body twice. If the body has side effects (printing, writing, network calls), those run again. Materialise with `.ToList()` or `.ToArray()` when you need stable, reusable results.
- **Recursive iterators are O(depth) in `MoveNext` time.** Each level of recursion nests one enumerator inside another. A 1000-level-deep tree produces a chain of 1000 `MoveNext` calls per leaf element. For deep trees, an explicit `Stack<Node>` loop is far more efficient than recursive `yield`.
- **`[EnumeratorCancellation]` is required on the `CancellationToken` parameter of async iterators.** Without it, passing a token via `WithCancellation(ct)` on `await foreach` does nothing — the token is never threaded into the iterator. The attribute tells the compiler to merge the externally supplied token with the parameter.

---

## Interview Angle

**What they're really testing:** Whether you understand lazy evaluation, the state machine the compiler generates, and the execution timing implications — not just "yield return produces a sequence."

**Common question form:** "What does `yield return` do?" or "Why doesn't my argument validation throw when I call the method?" or "What's the difference between returning `IEnumerable<T>` with a list and with `yield`?"

**The depth signal:** A junior says "`yield return` lets you return items one at a time without a list." A senior explains that the compiler rewrites the method into a heap-allocated state machine, that no code runs until `MoveNext` is first called — which is why eager argument validation must be separated into a wrapper method; that `finally` and `using` blocks run on enumerator disposal so early `break` is safe inside `foreach` but unsafe with a raw unenumerated `GetEnumerator()` call; and that recursive iterators have O(depth) per-element overhead due to chained `MoveNext` calls, making an explicit stack necessary for deep trees.

---

## Related Topics

- [[dotnet/csharp-linq.md]] — LINQ operators like `Where`, `Select`, and `Take` are iterator methods internally; understanding `yield` explains why LINQ is lazy and why `.ToList()` forces evaluation.
- [[dotnet/csharp-async-streams.md]] — `IAsyncEnumerable<T>` and `await foreach` are the async counterpart to `IEnumerable<T>` and `foreach`; the state machine model is the same with an added async layer.
- [[dotnet/csharp-span-and-memory.md]] — `Span<T>` cannot be used inside iterator methods because state machines are heap objects and `Span` is a stack-only type; knowing both explains why high-performance streaming sometimes requires a different pattern.
- [[algorithms/tree-traversal.md]] — Recursive iterators are the natural fit for tree traversal but have the O(depth) MoveNext cost; comparing iterator-based and stack-based traversal makes both patterns concrete.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/iterators](https://learn.microsoft.com/en-us/dotnet/csharp/iterators)

---
*Last updated: 2026-03-23*