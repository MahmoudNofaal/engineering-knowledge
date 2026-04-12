# Complexity Analysis
> The systematic process of quantifying how an algorithm's time and space requirements scale as input size grows.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Framework for measuring algorithmic scaling |
| **Use when** | Choosing between approaches or reviewing code for scale |
| **Avoid when** | Input is bounded small; constant factors matter more than growth |
| **Key tools** | Loop counting, recurrence relations, Master Theorem |
| **Cases** | Best (Ω), Average (Θ), Worst (O) |
| **Key insight** | Drop constants, keep dominant term |

---

## When To Use It

Apply complexity analysis whenever you're choosing between two approaches or reviewing code that will run on non-trivial input sizes. It's how you justify technical decisions beyond "it feels faster." It's also the minimum expected skill in any backend engineering interview — being unable to analyze your own code's complexity is a red flag at the senior level.

Skip deep analysis for throwaway scripts, config parsing, or one-time migrations where input is bounded and small. For those cases, readability and maintainability outweigh asymptotic performance.

---

## Core Concept

Complexity analysis is the discipline behind Big-O notation. You're asking: as n grows, what happens to the cost of this algorithm? You analyze it by counting the operations that scale with input — loops, recursive calls, comparisons — and ignoring the ones that don't. You do this separately for time (how many operations) and space (how much memory). The goal isn't a precise number; it's a growth class that lets you compare algorithms without benchmarking them.

There are three cases: best-case (Ω), average-case (Θ), and worst-case (O). In production, worst-case is what you design against — a service that degrades O(n²) on adversarial input is a vulnerability. Average-case matters for expected throughput estimation. Best-case is rarely useful except as a sanity check. State which case you're giving when answering interview questions — conflating them is a common mistake.

---

## Version History

| Notation | Introduced By | Year | Purpose |
|---|---|---|---|
| Big-O | Paul Bachmann | 1894 | Upper bound (worst case) |
| Big-Ω (Omega) | Edmund Landau | 1909 | Lower bound (best case) |
| Big-Θ (Theta) | Donald Knuth | 1976 | Tight bound (exact growth) |
| Little-o / Little-ω | Knuth formalized | 1976 | Strict bounds (rarely used in practice) |
| Master Theorem | Bentley, Haken, Saxe | 1980 | Systematic recurrence solving |

*The notation predates computers by decades. Knuth adapted it for algorithm analysis in TAOCP Vol. 1, which remains the canonical reference for formal complexity analysis.*

---

## Performance

| Analysis Technique | When to Use | Complexity to Apply |
|---|---|---|
| Loop counting | Iterative code | Multiply nested, add sequential |
| Recurrence relation | Recursive code | Expand or use Master Theorem |
| Amortized analysis | Variable-cost operations | Total cost ÷ operations |
| Probabilistic analysis | Randomized algorithms | Expected value over input distribution |

**Allocation behaviour:** Space complexity analysis must include both explicit allocations (new arrays, lists) and implicit ones (call stack depth for recursive algorithms). Forgetting call stack space is the most common analysis error in recursive code.

**Benchmark notes:** Complexity analysis tells you scaling behaviour, not actual speed. Two O(n log n) algorithms can differ by 10× in practice due to constant factors, memory access patterns, and hardware-specific optimizations. Always validate with benchmarks before optimizing — BenchmarkDotNet is the standard tool in .NET.

---

## The Code

**Rule 1: Identify the dominant term — drop everything else**
```csharp
public static void Example(List<int> items)
{
    Console.WriteLine(items[0]);        // O(1) — constant, dropped

    foreach (var item in items)         // O(n) — linear
        Console.WriteLine(item);

    foreach (var i in items)            // O(n²) — quadratic, dominates
        foreach (var j in items)
            Console.WriteLine($"{i} {j}");

    // Total: O(1) + O(n) + O(n²) → simplified to O(n²)
    // The quadratic term renders all smaller terms negligible at scale.
}
```

**Rule 2: Sequential loops add, nested loops multiply**
```csharp
public static void LoopRules(List<int> items, List<int> other)
{
    foreach (var x in items) Process(x);       // O(n)
    foreach (var x in other) Process(x);       // O(m)
    // Total: O(n + m) — not O(n × m), they're sequential

    foreach (var x in items)                   // O(n)
        foreach (var y in other)               // O(m) per outer iteration
            Console.WriteLine(x + y);
    // Total: O(n × m) — nested, they multiply
}
```

**Rule 3: Analyze recursive complexity with a recurrence relation**
```csharp
public static List<int> MergeSort(List<int> items)
{
    if (items.Count <= 1) return items;

    int mid = items.Count / 2;
    var left = MergeSort(items.Take(mid).ToList());     // T(n/2)
    var right = MergeSort(items.Skip(mid).ToList());    // T(n/2)

    return Merge(left, right);                           // O(n) to merge
}
// Recurrence: T(n) = 2T(n/2) + O(n)
// Apply Master Theorem case 2: a=2, b=2, f(n)=n → O(n log n)
```

**Rule 4: Space complexity includes the call stack**
```csharp
// O(1) space — no heap allocation, no call stack growth
public static int SumIterative(int n)
{
    int total = 0;
    for (int i = 1; i <= n; i++) total += i;
    return total;
}

// O(n) space — n stack frames pending simultaneously
public static int SumRecursive(int n)
{
    if (n == 0) return 0;
    return n + SumRecursive(n - 1);
    // At depth n, you have n frames on the stack before any return
}
```

**Rule 5: Amortized analysis averages over a sequence**
```csharp
var items = new List<int>();
for (int i = 0; i < n; i++)
{
    items.Add(i);
    // Most adds: O(1) — copy value into pre-allocated slot
    // Occasional add: O(n) — backing array doubles in size, all elements copied
    // Total cost across n adds: O(n) (each element is copied at most O(log n) times)
    // Amortized per add: O(n) / n = O(1)
}
// List<T>.Add is O(1) amortized — the expensive resizes are rare and diluted
```

**Rule 6: Watch for hidden complexity in library calls**
```csharp
// BAD: looks like O(n) but is actually O(n²)
public static bool HasAllUnique(List<int> items)
{
    for (int i = 0; i < items.Count; i++)
    {
        if (items.IndexOf(items[i]) != i)  // IndexOf is O(n) — hidden inner loop
            return false;
    }
    return true;
}

// GOOD: genuinely O(n)
public static bool HasAllUniqueFast(List<int> items)
{
    return new HashSet<int>(items).Count == items.Count;
}
```

---

## Real World Example

A reporting service built a query to load all orders for a dashboard summary. The initial query returned all orders as `List<Order>`, then used nested LINQ to group and aggregate in memory. On a database with 500,000 orders, the grouping loop called `.Where()` on the same list repeatedly — each `.Where()` on `IEnumerable` is a full O(n) scan, making the whole operation O(n × groups), which was O(n²) in practice.

```csharp
// BAD: O(n²) — Where() on List<T> scans the full list each call
public DashboardSummary GetSummaryNaive(List<Order> orders)
{
    var statuses = new[] { "Pending", "Shipped", "Delivered", "Cancelled" };
    var summary = new DashboardSummary();

    foreach (var status in statuses)
    {
        // orders.Where() is O(n) — called once per status → O(n × statuses)
        summary.Counts[status] = orders.Where(o => o.Status == status).Count();
        summary.Totals[status] = orders.Where(o => o.Status == status).Sum(o => o.Amount);
    }

    return summary;
}

// GOOD: O(n) — single pass, group into dictionary
public DashboardSummary GetSummaryFast(List<Order> orders)
{
    var groups = orders.GroupBy(o => o.Status)
                       .ToDictionary(
                           g => g.Key,
                           g => new { Count = g.Count(), Total = g.Sum(o => o.Amount) }
                       );

    var summary = new DashboardSummary();
    foreach (var (status, data) in groups)
    {
        summary.Counts[status] = data.Count;
        summary.Totals[status] = data.Total;
    }

    return summary;
}
```

*The key insight: grouping operations should always be O(n) — build a dictionary once, look up everything from it. Calling `.Where()` repeatedly on the same source is the in-memory version of N+1 queries.*

---

## Common Misconceptions

**"Complexity analysis is only relevant for algorithms, not for everyday code"**
Every database query, every API endpoint, every LINQ expression has complexity. A `.Where().Count()` chain on a `List<T>` is O(n) — called in a loop, it becomes O(n²). Complexity analysis applies everywhere code touches data, not just in LeetCode-style problems.

**"Amortized O(1) and average-case O(1) mean the same thing"**
They're fundamentally different. Amortized is a guarantee over a *sequence* of operations — `List<T>.Add` is amortized O(1) because the expensive resizes are guaranteed to happen rarely enough. Average-case is a probabilistic statement over *input distributions* — QuickSort is average O(n log n) because most random inputs don't trigger worst-case behaviour. One is a deterministic accounting argument; the other depends on your input assumptions.

```csharp
// Amortized O(1) — guaranteed regardless of what values you add
var list = new List<int>();
for (int i = 0; i < 1_000_000; i++) list.Add(i);  // always O(n) total

// Average O(n log n) — NOT guaranteed, depends on input
var data = GetUserInputArray();  // if adversarial, QuickSort degrades to O(n²)
Array.Sort(data);
```

**"Recursive code is always more complex than iterative code"**
Tail-recursive functions compile to iterative code in many languages and runtimes. And a recursive binary search is O(log n) — identical to its iterative counterpart in time complexity, though O(log n) in space due to call stack. The structure of the recursion determines complexity, not the fact that it's recursive.

---

## Gotchas

- **Ignoring space complexity is a production bug waiting to happen.** A solution with O(1) time improvement but O(n) extra memory can OOM a service under load. In interviews, always give both. In code reviews, always ask "what's the allocation profile?"

- **Amortized ≠ average-case.** Amortized is a guarantee over a sequence of operations (e.g., dynamic array append). Average-case is a probabilistic statement over input distributions (e.g., QuickSort). They sound similar but mean fundamentally different things and are proven differently.

- **Recursive depth counts as stack space.** .NET's default stack size is 1MB per thread. A recursive DFS on a graph with 50,000 nodes can blow the stack before it blows the time limit. Know when to convert recursion to an explicit stack.

- **The Master Theorem only applies to specific recurrence forms.** `T(n) = aT(n/b) + f(n)` where subproblems are equal-sized and `a ≥ 1`, `b > 1`. If your recursion doesn't fit this shape — uneven splits, variable branching factor — you need expansion or the Akra-Bazzi method.

- **Input characteristics change which case applies.** An already-sorted array is QuickSort's worst case (O(n²)) but insertion sort's best case (O(n)). Never state complexity without specifying which case: "QuickSort is O(n log n)" is incomplete without saying "average case."

- **Hidden O(n) calls inside O(n) loops.** `.Contains()` on `List<T>`, `.IndexOf()`, `.Where().Count()` — these are all O(n) and make your "O(n) loop" into O(n²). Use `HashSet<T>` and `.GroupBy()` to avoid this pattern.

---

## Interview Angle

**What they're really testing:** Whether you can analyze unfamiliar code on the spot — not just recall the complexity of known algorithms. The ability to derive rather than recognize is the distinguishing skill.

**Common question forms:**
- "Walk me through the time and space complexity of your solution" (always asked after you write code)
- "Is there a way to improve the complexity here?"
- "What's the recurrence relation for this recursive function?"

**The depth signal:** A junior gives the answer ("it's O(n log n)"). A senior derives it — identifies the recurrence relation, applies the Master Theorem or expansion, states space complexity separately including the call stack, and flags when worst-case and average-case diverge. The deepest signal is volunteering: "this is O(n log n) average case but degrades to O(n²) worst case if the pivot selection is poor — here's how you'd guard against that."

**Follow-up questions to expect:**
- "What about space complexity?" (almost guaranteed if you only gave time)
- "How would the complexity change if the input were already sorted?"
- "Can you prove that's optimal?" (for sorting or search problems)

---

## Related Topics

- [[algorithms/complexity/big-o-notation.md]] — The notation itself: rules for simplification, the three cases, and what the classes mean.
- [[algorithms/complexity/common-complexities.md]] — Reference for each complexity class with concrete examples.
- [[algorithms/complexity/master-theorem.md]] — The systematic tool for solving divide-and-conquer recurrence relations.
- [[algorithms/complexity/recurrence-relations.md]] — How to set up and expand recurrences before applying the Master Theorem.
- [[algorithms/complexity/amortized-analysis.md]] — The accounting and potential methods for analyzing variable-cost operations.
- [[algorithms/complexity/space-complexity.md]] — Applying the same analysis to memory: heap allocations, call stack, auxiliary structures.

---

## Source

https://www.cs.cornell.edu/courses/cs3110/2012sp/lectures/lec19-master/lec19.html

---

*Last updated: 2026-04-12*