# C# — LINQ Performance

> Understanding where LINQ allocates, where it re-executes, and how to fix the patterns that make it slow in hot paths.

---

## Quick Reference

| Problem | Symptom | Fix |
|---|---|---|
| Double enumeration | Source executed multiple times | `ToList()` before multiple passes |
| `list.Count()` LINQ vs `.Count` | O(n) vs O(1) | Use property on known collections |
| LINQ in inner loop | Allocation per iteration | Build `Dictionary` outside loop |
| Closure in hot path | Allocation per call | `static` lambda or cached `Func` |
| `OrderBy` + re-enumerate | Re-sorts every time | Materialise with `ToList()` |

---

## Core Concept

Every deferred LINQ operator (`Where`, `Select`, `OrderBy`) allocates a heap object — an iterator — wrapping the previous one. A five-operator chain allocates five objects per enumeration. On top of that, materialising operators (`ToList()`) allocate a new `List<T>` and copy all elements.

None of this matters for code that runs once or processes dozens of elements. It matters for code that runs thousands of times per second or processes millions of elements.

The fixes are usually: materialise once and reuse, use a more specific collection method, or switch to `Span<T>`-based processing.

---

## The Code

**Measure first — don't optimise by instinct**
```csharp
[MemoryDiagnoser]
public class LinqBench
{
    private List<int> _data = Enumerable.Range(1, 10_000).ToList();

    [Benchmark(Baseline = true)]
    public int LinqCount() => _data.Where(n => n % 2 == 0).Count();

    [Benchmark]
    public int ManualCount()
    {
        int count = 0;
        foreach (var n in _data) if (n % 2 == 0) count++;
        return count;
    }
}
```

**Double enumeration — materialise once**
```csharp
IEnumerable<Order> pending = GetPendingOrders(); // deferred

// BAD: three executions
if (pending.Any()) Log($"{pending.Count()} orders"); // two hits
foreach (var o in pending) Process(o);              // third hit

// GOOD: one execution
var list = pending.ToList();
if (list.Count > 0) { Log($"{list.Count} orders"); foreach (var o in list) Process(o); }
```

**Use collection members instead of LINQ operators**
```csharp
var list = new List<int> { 3, 1, 4, 1, 5 };

// Slower: LINQ allocates iterator
int count = list.Count();    // use list.Count (property)
bool any  = list.Any();      // use list.Count > 0

// Faster: direct collection members
int count2 = list.Count;     // O(1) property
bool any2  = list.Count > 0;
```

**Replace LINQ lookup in loop with Dictionary**
```csharp
// BAD: O(n²) — LINQ search per order
foreach (var order in orders)
{
    var match = products.Where(p => p.Id == order.ProductId).FirstOrDefault();
    Process(order, match);
}

// GOOD: O(n) — build dict once, O(1) lookup per order
var productById = products.ToDictionary(p => p.Id);
foreach (var order in orders)
{
    productById.TryGetValue(order.ProductId, out var match);
    Process(order, match);
}
```

**Cache delegates — avoid closure allocation in hot paths**
```csharp
int threshold = 500;

// Allocates closure display class every method call:
var expensive = products.Where(p => p.Price > threshold).ToList();

// Cache non-capturing delegate — zero allocation after first use:
private static readonly Func<Product, bool> IsActive = static p => p.IsActive;
var result = products.Where(IsActive).ToList();
```

---

## Gotchas

- **`list.Count()` (LINQ) vs `list.Count` (property).** LINQ's `Count()` checks for `ICollection<T>` and short-circuits for `List<T>` — O(1). But once any operator wraps the list (like `Where`), `Count()` is always O(n).
- **`ToList()` inside a loop allocates per iteration.** Cache the result outside the loop.
- **Chaining `Where` and `Select` creates two iterator objects per enumeration.** In practice, this matters less than allocations and double-enumeration.
- **`OrderBy` re-sorts on every enumeration.** Materialise with `ToList()` if the sorted result is used more than once.

---

## Interview Angle

**The depth signal:** A senior gives a cost model: each deferred operator allocates one iterator object; lambdas over captured variables allocate a closure; materialising operators allocate the result collection; re-enumerating runs it again. They know that `Dictionary` lookup inside a loop beats `Where().FirstOrDefault()` inside a loop by turning O(n²) into O(n).

---

## Related Topics

- [[dotnet/csharp/csharp-linq-deferred-execution.md]] — Re-execution is the root cause of most double-enumeration bugs
- [[dotnet/csharp/csharp-collections-dictionary.md]] — Replacing LINQ lookups with dictionaries is the highest-impact optimisation

---

## Source

[LINQ Performance — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/linq/linq-and-performance)

---
*Last updated: 2026-04-06*