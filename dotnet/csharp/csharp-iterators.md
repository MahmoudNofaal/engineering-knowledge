# C# Iterators

> An iterator is a method using `yield return` to produce a sequence one element at a time, pausing execution between yields — lazy, memory-efficient, and composable with LINQ.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Compiler-generated state machine that produces lazy sequences |
| **Return type** | `IEnumerable<T>`, `IEnumerator<T>`, `IAsyncEnumerable<T>` |
| **Use when** | Large/infinite sequences, early termination possible, tree flattening |
| **Avoid when** | Random access needed, thread safety required, sequence must be reused cheaply |
| **C# version** | C# 2.0 (`yield`), `IAsyncEnumerable<T>`: C# 8.0 |

---

## When To Use It

Use iterators when you want to produce a potentially large or infinite sequence without materialising it all in memory at once — reading file lines, paginating through an API, generating a Fibonacci series, flattening a tree.

They're also right when the caller may stop consuming early, since elements that are never requested are never computed.

Don't use iterators when random access is required, when the sequence must be thread-safe, or when generation logic has meaningful side effects that must run to completion regardless of consumption.

---

## Core Concept

When the compiler sees `yield return` in a method, it rewrites the entire method into a state machine class. Calling the method returns an instance of that class — **no code in the method body runs yet**. Each time the caller calls `MoveNext()` (which `foreach` does for you), the state machine runs until the next `yield return`, delivers that value, and pauses. `yield break` signals completion.

This lazy evaluation is the key property: `Take(3)` on an infinite sequence only produces three elements. The cost is that re-enumerating requires calling the method again to get a fresh state machine.

---

## The Code

**Basic iterator — infinite sequence**
```csharp
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
```

**File reading — no List<string> in memory**
```csharp
static IEnumerable<string> ReadLines(string path)
{
    using var reader = new StreamReader(path);
    string? line;
    while ((line = reader.ReadLine()) != null)
        yield return line;
    // StreamReader disposed when caller breaks out OR iteration completes
}

foreach (string line in ReadLines("data.txt").Where(l => l.StartsWith("ERROR")))
    Console.WriteLine(line);
```

**Tree flattening — recursive iterator**
```csharp
class Node { public int Value; public List<Node> Children = new(); }

static IEnumerable<int> Flatten(Node root)
{
    yield return root.Value;
    foreach (var child in root.Children)
        foreach (int v in Flatten(child)) // each recursive call is its own enumerator
            yield return v;
}
// NOTE: O(depth) MoveNext cost — use an explicit Stack<Node> for deep trees
```

**Eager argument validation wrapper**
```csharp
// Problem: iterator methods execute NO code until first MoveNext
// So validation at the top isn't triggered when the method is called
static IEnumerable<int> GetRange(int start, int count)
{
    if (count < 0) throw new ArgumentOutOfRangeException(nameof(count)); // NOT thrown yet!
    for (int i = 0; i < count; i++) yield return start + i;
}

// Fix: wrap in a non-iterator method for eager validation
static IEnumerable<int> GetRangeSafe(int start, int count)
{
    if (count < 0) throw new ArgumentOutOfRangeException(nameof(count)); // thrown immediately
    return GetRangeCore(start, count);
}
private static IEnumerable<int> GetRangeCore(int start, int count)
{
    for (int i = 0; i < count; i++) yield return start + i;
}
```

**Async iterator (C# 8+)**
```csharp
static async IAsyncEnumerable<string> FetchPagesAsync(
    string baseUrl,
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

- **Iterator methods execute no code until first `MoveNext`.** Argument validation at the top of the method body doesn't run when the method is called. Wrap in a non-iterator method for eager validation.
- **`using` inside an iterator is disposed when the enumerator is disposed.** A `foreach` always disposes the enumerator. A raw `GetEnumerator()` call without `using` does not.
- **Re-enumerating calls the method again.** If the body has side effects (printing, writing), those run again. Materialise with `ToList()` when you need stable, reusable results.
- **Recursive iterators are O(depth) in `MoveNext` time.** A 1000-level-deep tree produces a chain of 1000 `MoveNext` calls per leaf. Use an explicit `Stack<Node>` for deep trees.
- **`[EnumeratorCancellation]` is required on the `CancellationToken` parameter of async iterators.** Without it, passing a token via `WithCancellation(ct)` does nothing.

---

## Interview Angle

**What they're really testing:** Whether you understand lazy evaluation, the state machine the compiler generates, and the execution timing implications.

**Common question forms:**
- "What does `yield return` do?"
- "Why doesn't my argument validation throw when I call the method?"
- "What's the difference between returning `IEnumerable<T>` with a list vs `yield return`?"

**The depth signal:** A senior explains the state machine — no code runs until `MoveNext` is first called, which is why eager validation must be separated into a wrapper method. They know `finally` and `using` blocks run on enumerator disposal, and that recursive iterators have O(depth) per-element overhead.

---

## Related Topics

- [[dotnet/csharp/csharp-ienumerable.md]] — `IEnumerable<T>` is the interface iterator methods return
- [[dotnet/csharp/csharp-linq-basics.md]] — LINQ operators like `Where` and `Select` are iterator methods internally

---

## Source

[Iterators — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/iterators)

---
*Last updated: 2026-04-06*