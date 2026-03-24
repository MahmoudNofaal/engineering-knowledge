# C# — LINQ Performance

> Understanding where LINQ allocates, where it re-executes, and how to avoid the patterns that make it slow in hot paths — without abandoning it entirely.

---

## When To Use It

This topic matters any time LINQ appears in a code path that runs frequently, processes large sequences, or operates under tight latency requirements — API hot paths, batch jobs, game loops, real-time processing. LINQ's abstractions have real costs: iterator object allocations, delegate invocations, and deferred re-execution. None of these matter for code that runs once or processes dozens of elements. They matter a lot for code that runs thousands of times per second or processes millions of elements. The answer is rarely "remove LINQ" — it's "understand exactly what LINQ is doing and fix the specific problem."

---

## Core Concept

Every deferred LINQ operator (`Where`, `Select`, `OrderBy`, etc.) allocates a heap object — an iterator — that wraps the previous one. A five-operator chain allocates five iterator objects per enumeration. Each element pulled through the chain goes through five virtual `MoveNext()` calls. On top of that, materializing operators like `ToList()` allocate a new `List<T>` and copy all elements into it. None of this is free. The other dimension is re-execution: a LINQ query over `IEnumerable<T>` re-runs from scratch on every enumeration, so calling `Count()` followed by `foreach` on the same deferred query executes it twice. The performance fixes are usually one of three things: materialize once and reuse, use a more specific collection method instead of a LINQ operator, or switch to `Span<T>`-based processing for hot inner loops that LINQ can't reach.

---

## The Code

### Measure first — don't optimize by instinct
```csharp
using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;

// Always benchmark the actual pattern before and after changing it
// BenchmarkDotNet handles warmup, GC, and statistical noise correctly
[MemoryDiagnoser] // shows allocations per operation
public class LinqBenchmark
{
    private List<int> _data = Enumerable.Range(1, 10_000).ToList();

    [Benchmark(Baseline = true)]
    public int LinqCount() => _data.Where(n => n % 2 == 0).Count();

    [Benchmark]
    public int ManualCount()
    {
        int count = 0;
        foreach (var n in _data)
            if (n % 2 == 0) count++;
        return count;
    }
}
```

### Double enumeration — the most common unintentional cost
```csharp
IEnumerable<Order> GetPendingOrders() => 
    dbContext.Orders.Where(o => o.Status == "Pending"); // deferred

// BAD: three enumerations = three SQL queries
var pending = GetPendingOrders();
if (pending.Any())
{
    Log($"Processing {pending.Count()} orders"); // second query
    foreach (var o in pending)                   // third query
        Process(o);
}

// GOOD: one query, one allocation, three reads from the in-memory list
var pending2 = GetPendingOrders().ToList();      // one SQL query
if (pending2.Count > 0)                          // free — List.Count property
{
    Log($"Processing {pending2.Count} orders");  // free
    foreach (var o in pending2)                  // in-memory iteration
        Process(o);
}
```

### Use specific methods instead of LINQ where they exist
```csharp
var list = new List<int> { 3, 1, 4, 1, 5, 9, 2, 6 };

// SLOWER: LINQ operators allocate iterators and use delegates
int count1  = list.Count();         // allocates; use list.Count instead
bool any1   = list.Any();           // allocates; use list.Count > 0
bool has5   = list.Contains(5);     // OK for IEnumerable — but List has its own

// FASTER: direct collection members, no allocation, no delegate overhead
int count2  = list.Count;           // property — O(1), zero allocation
bool any2   = list.Count > 0;       // no LINQ involved
bool has5b  = list.Contains(5);     // List<T>.Contains — same as LINQ but no iterator

// For arrays specifically — Array.IndexOf, Array.Find, Array.Exists
int[] arr = { 1, 2, 3, 4, 5 };
bool found = Array.Exists(arr, n => n > 3);  // no iterator allocation
```

### Avoid LINQ in the innermost loop
```csharp
// BAD: allocates a new iterator and closure on every iteration of the outer loop
foreach (var order in orders)
{
    // Where + FirstOrDefault allocates per outer iteration
    var match = products.Where(p => p.Id == order.ProductId).FirstOrDefault();
    Process(order, match);
}

// GOOD: build a dictionary once, do O(1) lookups in the loop
var productById = products.ToDictionary(p => p.Id);

foreach (var order in orders)
{
    productById.TryGetValue(order.ProductId, out var match);
    Process(order, match);
}
```

### OrderBy allocation — sort allocates a new array
```csharp
var data = Enumerable.Range(1, 100_000).Reverse().ToList();

// OrderBy copies all elements into a buffer array to sort, then returns them
// For large sequences this is unavoidable, but don't do it in a loop
var sorted = data.OrderBy(n => n).ToList(); // two allocations: sort buffer + List

// If data is already sorted, avoid re-sorting by maintaining sorted order
// on insert rather than sorting on read
var sortedSet = new SortedSet<int>(data); // maintained in sorted order
```

### Avoid closure allocations in tight LINQ chains
```csharp
int threshold = 500; // captured variable

// This lambda captures 'threshold' — the compiler generates a closure class
// and allocates an instance of it every time this line executes in a non-cached context
var expensive = products.Where(p => p.Price > threshold).ToList();

// For hot paths where the predicate is fixed, use a static lambda (C# 9+)
// static lambdas can't capture variables — compiler enforces this, zero closure alloc
// (only works when the predicate doesn't need outer state)
var cheap = products.Where(static p => p.Price > 0).ToList();

// For parameterized hot paths, cache the compiled predicate
private static readonly Func<Product, bool> IsExpensive = p => p.Price > 500;
var result = products.Where(IsExpensive).ToList(); // reuses the same delegate
```

### Span<T> for allocation-free in-memory processing
```csharp
// For truly hot inner loops, LINQ can't reach — Span<T> avoids all iterator overhead
int[] numbers = Enumerable.Range(1, 1_000_000).ToArray();

// LINQ path: allocates WhereIterator, SelectIterator, and result list
List<int> linqResult = numbers
    .Where(n => n % 2 == 0)
    .Select(n => n * n)
    .ToList();

// Span path: no heap allocation, no iterator objects, direct memory access
Span<int> span = numbers;
int count = 0;
// Count first pass to size the output correctly
foreach (var n in span)
    if (n % 2 == 0) count++;

int[] result = new int[count];
int idx = 0;
foreach (var n in span)
    if (n % 2 == 0) result[idx++] = n * n;
```

---

## Gotchas

- **`list.Count()` (LINQ) vs `list.Count` (property) is a real difference on non-List sources** — LINQ's `Count()` extension checks if the source implements `ICollection<T>` and short-circuits to `.Count` if it does, so `list.Count()` is O(1) for `List<T>`. But once any operator wraps the list (like `Where`), the `ICollection<T>` check fails and `Count()` walks everything. `query.Where(x => x.Active).Count()` is always O(n).
- **`ToList()` inside a loop is an allocation-per-iteration bomb** — calling `someQuery.ToList()` inside a `foreach` over thousands of items allocates a new `List<T>` on every pass. Cache the result outside the loop or restructure the query to avoid it.
- **Delegate caching matters for hot paths** — every lambda that captures a variable creates a closure object. For methods called millions of times, caching the `Func<T, bool>` as a static field eliminates repeated closure allocations. The compiler caches non-capturing lambdas automatically, but any lambda that closes over a variable — even a constant — is re-allocated unless you cache it.
- **`OrderBy` always allocates a sort buffer the size of the input** — there's no in-place sort in LINQ. If you're sorting a sequence that's already sorted (or nearly sorted), consider maintaining sorted order on insertion with `SortedList<K,V>` or `SortedSet<T>` rather than sorting on every read.
- **Chaining `Where` and `Select` doesn't fuse into one pass** — `Where(pred).Select(proj)` creates two iterator objects and makes two passes in terms of `MoveNext()` calls per element: one through `WhereIterator` and one through `SelectIterator`. The actual element data is only loaded once (it's pull-based), but the call stack is deeper. In practice, this matters less than allocations and double-enumeration — profile before optimizing this.

---

## Interview Angle

**What they're really testing:** Whether you understand the concrete cost model of LINQ — allocations per operator, re-execution on re-enumeration, and where LINQ's abstractions are the wrong tool — rather than the vague claim that "LINQ is slow."

**Common question form:** "How would you optimize this LINQ query?" or "Why is this code allocating more than expected?" or "When would you not use LINQ?"

**The depth signal:** A junior says LINQ is slower than `foreach` and avoids it in performance-sensitive code. A senior gives a cost model: each deferred operator allocates one iterator object, lambdas over captured variables allocate a closure, materializing operators allocate the result collection, and re-enumerating a deferred query re-runs it entirely. The senior knows that `list.Count` (property) is O(1) but `query.Where(...).Count()` (LINQ) is O(n), that the fix for double-enumeration is a single `ToList()` before multiple passes, and that `Dictionary` lookup inside a loop beats `Where().FirstOrDefault()` inside a loop by turning O(n²) into O(n). The senior also knows that profiling with `MemoryDiagnoser` in BenchmarkDotNet is how you confirm whether the optimization actually helped — not instinct.

---

## Related Topics

- [[dotnet/csharp-linq-deferred-execution.md]] — Deferred execution is the root cause of most double-enumeration performance bugs; the re-execution model is explained there in detail.
- [[dotnet/csharp-span-memory.md]] — `Span<T>` is the tool for processing contiguous memory without iterator overhead in genuinely hot inner loops where LINQ can't compete.
- [[dotnet/csharp-collections-dictionary.md]] — Replacing LINQ lookups inside loops with pre-built dictionaries is the single highest-impact LINQ performance fix in most codebases.
- [[dotnet/csharp-arraypool.md]] — `ArrayPool<T>` pairs with Span-based processing to avoid large array allocations in hot paths when you need a temporary buffer.

---

## Source

https://learn.microsoft.com/en-us/dotnet/standard/linq/linq-and-performance

---
*Last updated: 2026-03-23*