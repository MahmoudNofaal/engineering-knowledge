# Space Complexity
> A measure of how much memory an algorithm requires relative to its input size — analyzed using the same Big-O notation as time complexity.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Memory usage growth rate as input scales |
| **Use when** | Memory is constrained or allocations impact GC pressure |
| **Avoid when** | Memory is abundant and time is the binding constraint |
| **Key distinction** | Auxiliary space (extra) vs total space (input + extra) |
| **Biggest trap** | Forgetting recursive call stack contributes O(depth) space |
| **C# relevance** | Heap allocations affect GC; stack space can overflow |

---

## When To Use It

Analyze space complexity any time you're choosing between algorithms or reviewing code that allocates memory proportional to input size. It's critical in three scenarios: memory-constrained environments (embedded, serverless with small limits), high-throughput services where GC pressure degrades latency, and deep recursive algorithms where stack overflow is a real risk. In interviews, always give both time and space — omitting space is a common gap that interviewers notice.

Don't over-optimize space when memory is abundant and the time trade-off is severe. Many O(n) space algorithms (hash tables, memoization tables) buy enormous time improvements — that's usually the right trade.

---

## Core Concept

Space complexity uses the same Big-O notation as time complexity, but counts memory units instead of operations. Two types matter: *auxiliary space* is the extra memory your algorithm uses beyond the input itself (the number most people care about); *total space* includes the input. In most interview and production contexts, "space complexity" means auxiliary space.

Memory comes from two places: the heap (explicit `new` allocations, collections, closures) and the stack (call frames, local variables, parameters). Iterative algorithms typically use O(1) auxiliary space — a few fixed variables. Recursive algorithms accumulate call frames proportional to recursion depth — a recursive DFS on a balanced binary tree with n nodes uses O(log n) stack space; on a degenerate tree (linked list), O(n). This distinction is why deep recursion can stack-overflow before hitting a time limit.

---

## Version History

| Concept | Context | Notes |
|---|---|---|
| Space complexity | Concurrent with time analysis | Formalized alongside Big-O in algorithm theory |
| In-place algorithms | Knuth, TAOCP | Sorting "in place" = O(1) auxiliary space |
| Tail call optimization | Functional languages | Converts O(n) stack to O(1) — C# does NOT do this |
| Span<T> / Memory<T> | .NET Core 2.1 / C# 7.2 | Stack-allocated slices without heap allocation |
| stackalloc | Early C# | Fixed-size stack arrays — O(1) space, no GC |

*C# does not perform tail call optimization in the general case (the JIT applies it sometimes, but it's not guaranteed). This means deeply recursive C# code always risks stack overflow — it's not optimized away like in F# or Haskell.*

---

## Performance

| Pattern | Time | Auxiliary Space | Notes |
|---|---|---|---|
| Iterative with counters | O(n) | O(1) | Best space efficiency |
| Hash map for lookup | O(n) | O(n) | Classic time-space trade-off |
| Recursive DFS (balanced) | O(n) | O(log n) | Stack depth = tree height |
| Recursive DFS (degenerate) | O(n) | O(n) | Linked-list-shaped tree |
| Merge sort | O(n log n) | O(n) | Auxiliary array for merging |
| Heapsort | O(n log n) | O(1) | In-place — no aux array |
| Memoization (DP) | O(n) → O(n²) | O(n) → O(n²) | Cache trades space for time |
| BFS with queue | O(n) | O(w) | w = max queue width (tree width) |

**Allocation behaviour:** In .NET, heap allocations trigger garbage collection. Repeated O(n) allocations in hot paths (e.g., creating a `new List<T>` per request) create GC pressure that shows up as unpredictable latency spikes. Use `ArrayPool<T>`, `Span<T>`, or pre-allocated collections to reduce allocations in latency-sensitive code.

**Benchmark notes:** Space complexity affects real performance through GC pause time, not just raw memory use. A service that allocates 100MB per second will trigger Gen2 GC collections every few seconds — visible as latency spikes in P99 metrics. This is why allocation tracking (`dotMemory`, `PerfView`) is as important as CPU profiling in production .NET services.

---

## The Code

**O(1) auxiliary space — iterative, fixed variables**
```csharp
// No matter how large items is, we use the same fixed memory: sum, item
public static long Sum(List<int> items)
{
    long sum = 0;
    foreach (var item in items)
        sum += item;
    return sum;  // O(1) aux space — just a long and an iterator
}
```

**O(n) auxiliary space — building a new collection**
```csharp
// Output list grows with input — O(n) auxiliary space
public static List<int> FilterPositive(List<int> items)
{
    var result = new List<int>();          // up to n elements allocated
    foreach (var item in items)
        if (item > 0) result.Add(item);
    return result;
}

// Same O(n) space but with a hash table — common for dedup
public static List<int> Deduplicate(List<int> items)
{
    var seen = new HashSet<int>();         // up to n entries
    var result = new List<int>();          // up to n entries
    // Total: O(n) + O(n) = O(2n) → O(n) auxiliary space
    foreach (var item in items)
        if (seen.Add(item)) result.Add(item);
    return result;
}
```

**Recursive space — call stack depth is auxiliary space**
```csharp
// O(n) time, O(n) stack space — n frames accumulate before any return
public static int SumRecursive(int n)
{
    if (n == 0) return 0;
    return n + SumRecursive(n - 1);
    // For n=10,000: 10,000 frames on the stack simultaneously
    // Default .NET stack: ~1MB — blows at roughly n=50,000
}

// Same O(n) time, O(1) space — convert to iterative
public static int SumIterative(int n)
{
    int total = 0;
    for (int i = 1; i <= n; i++) total += i;
    return total;
}
```

**Tree traversal — stack depth depends on tree shape**
```csharp
// Recursive DFS — O(h) stack space where h = tree height
public static int MaxDepth(TreeNode? node)
{
    if (node == null) return 0;
    return 1 + Math.Max(MaxDepth(node.Left), MaxDepth(node.Right));
    // Balanced tree: h = O(log n) → O(log n) stack space
    // Degenerate tree (all left): h = O(n) → O(n) stack space
}

// Iterative DFS with explicit stack — same O(h) space but controlled
public static int MaxDepthIterative(TreeNode? root)
{
    if (root == null) return 0;
    var stack = new Stack<(TreeNode node, int depth)>();
    stack.Push((root, 1));
    int maxDepth = 0;
    while (stack.Count > 0)
    {
        var (node, depth) = stack.Pop();
        maxDepth = Math.Max(maxDepth, depth);
        if (node.Left != null) stack.Push((node.Left, depth + 1));
        if (node.Right != null) stack.Push((node.Right, depth + 1));
    }
    return maxDepth;
    // Same O(h) space, but on the heap — won't stack overflow
}
```

**Span<T> and stackalloc — O(1) heap allocation**
```csharp
// stackalloc: fixed-size array on the stack — no heap allocation, no GC
public static int SumSmallArray(ReadOnlySpan<int> items)
{
    Span<int> buffer = stackalloc int[16];  // 16-element int array on the stack
    // Safe: size known at compile time, scope-limited
    int total = 0;
    foreach (var item in items) total += item;
    return total;
}

// ArrayPool<T>: rent from pool → process → return, avoids allocation
public static byte[] ProcessData(byte[] input)
{
    byte[] buffer = ArrayPool<byte>.Shared.Rent(input.Length);
    try
    {
        // process using buffer...
        return buffer[..input.Length];
    }
    finally
    {
        ArrayPool<byte>.Shared.Return(buffer);  // returned to pool, not GC'd
    }
}
```

**Memoization — trading O(2ⁿ) time for O(n) space**
```csharp
// Fibonacci: O(2ⁿ) time → O(n) time, O(n) space with memo
private static Dictionary<int, long> _memo = new();

public static long Fib(int n)
{
    if (n <= 1) return n;
    if (_memo.TryGetValue(n, out long cached)) return cached;
    _memo[n] = Fib(n - 1) + Fib(n - 2);
    return _memo[n];
}

// Space optimization: if you only need the final value, O(n) space → O(1)
public static long FibOptimal(int n)
{
    if (n <= 1) return n;
    long prev2 = 0, prev1 = 1;
    for (int i = 2; i <= n; i++)
    {
        long curr = prev1 + prev2;
        prev2 = prev1;
        prev1 = curr;
    }
    return prev1;  // O(1) space — only two variables
}
```

---

## Real World Example

A bulk CSV export service initially loaded all rows into a `List<OrderDto>` before serializing to CSV. For exports with 500,000 rows, this allocated ~200MB per request. Under concurrent load, it triggered frequent Gen2 GC collections and caused P99 latency to spike to 10+ seconds. The fix was streaming — yield-returning rows and writing each to the response stream as it was fetched.

```csharp
// BAD: O(n) space — entire dataset in memory before writing
public async Task<byte[]> ExportOrdersNaive(DateRange range)
{
    // Loads all orders into memory — 500k rows ≈ 200MB
    var orders = await _db.Orders
        .Where(o => o.CreatedAt >= range.Start && o.CreatedAt <= range.End)
        .Select(o => new OrderDto(o))
        .ToListAsync();                         // O(n) allocation

    using var ms = new MemoryStream();          // Second O(n) allocation
    using var writer = new StreamWriter(ms);
    foreach (var order in orders)
        await writer.WriteLineAsync(order.ToCsv());
    return ms.ToArray();
}

// GOOD: O(1) auxiliary space — stream rows directly without holding all in memory
public async IAsyncEnumerable<string> ExportOrdersStreaming(
    DateRange range,
    [EnumeratorCancellation] CancellationToken ct = default)
{
    yield return "Id,Customer,Amount,Status,CreatedAt";  // header

    await foreach (var order in _db.Orders
        .Where(o => o.CreatedAt >= range.Start && o.CreatedAt <= range.End)
        .Select(o => new OrderDto(o))
        .AsAsyncEnumerable()
        .WithCancellation(ct))
    {
        yield return order.ToCsv();  // serialize and yield one row at a time
    }
    // Memory footprint: O(1) — only one row in memory at a time
}
```

*The key insight: streaming (IAsyncEnumerable, yield return) converts O(n) space to O(1) for sequential processing. Any pipeline that reads data, transforms it, and writes it elsewhere should stream rather than buffer — unless random access to the full dataset is actually required.*

---

## Common Misconceptions

**"Space complexity only matters for large datasets"**
GC pressure matters at any scale in latency-sensitive systems. Allocating a `new List<T>()` per request in an API handling 10,000 RPS means millions of allocations per second. Each one is O(1) space but the aggregate rate overwhelms the GC. Space efficiency in hot paths is about GC pressure, not just total memory used.

**"In-place sorting means O(1) space"**
In-place means O(1) *auxiliary* space — no extra array for the elements. But quicksort (in-place) uses O(log n) to O(n) stack space for recursion. "In-place" and "O(1) space complexity" are not synonymous. Heapsort is genuinely O(1) auxiliary including the recursion (iterative implementation); quicksort is O(log n) average-case stack depth.

```csharp
// Both "in-place" — but different stack space
Array.Sort(data);          // .NET IntroSort: in-place, O(log n) stack
HeapSort(data);            // Iterative heapsort: in-place, O(1) stack
```

**"Tail recursion in C# is O(1) stack space"**
C# and .NET do not guarantee tail call optimization. The JIT *sometimes* applies it, but it's not in the language specification and you cannot rely on it. If you need O(1) stack space in C#, write the loop yourself — don't assume tail recursion will be optimized.

---

## Gotchas

- **Forgetting call stack as space.** Every recursive call adds a frame. A recursive DFS on an unbalanced tree of depth n uses O(n) stack space — independent of whether you're allocating on the heap. The stack overflows around depth 50,000–100,000 in .NET depending on frame size.

- **LINQ creates allocators you can't see.** `.ToList()`, `.ToArray()`, `.ToDictionary()`, `.GroupBy()` all allocate. In a hot path, chaining LINQ operations in a loop multiplies these allocations. Profile before assuming "just one LINQ query" is cheap.

- **Closures capture variables onto the heap.** A lambda that captures a local variable causes that variable to be heap-allocated inside a closure object. This is usually fine but can be a source of unexpected allocations in tight loops.

- **`StringBuilder` vs string concatenation in loops.** String concatenation in a loop (`s += item`) is O(n²) in time *and* allocates O(n) new strings. `StringBuilder` is O(n) time and O(n) space total. This is one of the few cases where the O notation of space affects correctness (GC blowup).

- **Dictionary initial capacity matters for GC.** `new Dictionary<K,V>()` with no capacity hint will resize (and reallocate) several times as it fills. If you know the size, `new Dictionary<K,V>(expectedCount)` avoids those intermediate allocations — meaningful in bulk processing.

---

## Interview Angle

**What they're really testing:** Whether you think about memory as a real constraint, not just an afterthought. Omitting space complexity is one of the top gaps interviewers notice in candidates who otherwise answer well.

**Common question forms:**
- "What's the space complexity of your solution?" (always asked if you only gave time)
- "Can you solve this in O(1) space?" (after an O(n) space solution)
- "How does the recursive version's space differ from the iterative one?"

**The depth signal:** A junior says "it's O(n) because of the list." A senior breaks it down — "O(n) auxiliary space for the hash map; the recursive call stack adds another O(h) where h is the tree height — O(log n) for a balanced tree, O(n) worst case. If memory is constrained, here's how I'd convert to iterative to eliminate the stack contribution."

**Follow-up questions to expect:**
- "What happens to space if the tree is unbalanced?" (the degenerate case)
- "How would you reduce this to O(1) space?" (expecting iterative conversion or space-optimized DP)
- "What are the GC implications of this in a high-throughput .NET service?" (senior-level)

---

## Related Topics

- [[algorithms/complexity/big-o-notation.md]] — The notation system — everything here uses it.
- [[algorithms/complexity/complexity-analysis.md]] — How to derive complexity from code structure, including space.
- [[algorithms/complexity/amortized-analysis.md]] — How amortized O(1) applies to List<T> and Dictionary growth.
- [[dotnet/csharp/csharp-span-memory.md]] — Span<T> and Memory<T> for stack-allocated and pool-allocated slices.
- [[dotnet/csharp/csharp-garbage-collector.md]] — How .NET GC works and why space complexity affects latency.
- [[dotnet/csharp/csharp-stackalloc.md]] — stackalloc for fixed-size stack arrays with O(1) heap allocation.

---

## Source

https://docs.microsoft.com/en-us/dotnet/standard/garbage-collection/performance

---

*Last updated: 2026-04-12*