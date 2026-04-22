# Big-O Notation

> A mathematical notation that describes the upper bound of an algorithm's growth rate — how time or space scales as input size n approaches infinity.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Upper bound on growth rate, ignoring constants |
| **Use when** | Comparing algorithms, communicating scalability |
| **Avoid when** | Constant factors dominate (small n) — benchmark instead |
| **C# version** | N/A — mathematical notation, not a language feature |
| **Namespace** | N/A |
| **Key types** | O(1), O(log n), O(n), O(n log n), O(n²), O(2^n), O(n!) |

---

## When To Use It

Use Big-O to compare algorithms at scale — when n is large enough that the growth rate dominates constant factors. It's the language of algorithm analysis: in an interview, every solution you give should be accompanied by its time and space complexity. Don't over-rely on it for small n (< 1,000) where constant factors matter more — benchmark instead.

---

## Core Concept

Big-O describes how the number of operations grows relative to input size n, discarding constant multipliers and lower-order terms. O(2n) and O(5n) are both O(n) — the coefficient is irrelevant at scale. O(n² + n) is O(n²) — the dominant term wins.

Three notations exist: **O** (upper bound — worst case), **Ω** (lower bound — best case), **Θ** (tight bound — both). In interviews, "Big-O" almost always means worst-case upper bound.

Key rules:
- **Drop constants:** O(3n) → O(n)
- **Drop lower-order terms:** O(n² + n) → O(n²)
- **Loops multiply:** a loop of n inside a loop of n → O(n²)
- **Sequential blocks add:** O(n) + O(n log n) → O(n log n)
- **Recursion:** solve the recurrence T(n) = aT(n/b) + f(n) using the Master Theorem

---

## Algorithm History

| Year | Development |
|---|---|
| 1894 | Paul Bachmann introduces O notation in number theory |
| 1909 | Edmund Landau popularises it — hence "Landau notation" |
| 1960s | Donald Knuth adopts and standardises it for algorithm analysis |
| 1990s | Becomes the universal language of CS curricula and interviews |

---

## Performance

| Notation | Name | Example | n=10 | n=100 | n=1000 |
|---|---|---|---|---|---|
| O(1) | Constant | Array index, hash lookup | 1 | 1 | 1 |
| O(log n) | Logarithmic | Binary search | 3 | 7 | 10 |
| O(n) | Linear | Linear scan | 10 | 100 | 1,000 |
| O(n log n) | Linearithmic | Merge sort | 33 | 664 | 9,966 |
| O(n²) | Quadratic | Nested loops | 100 | 10,000 | 1,000,000 |
| O(2^n) | Exponential | Subsets | 1,024 | 10^30 | ∞ |
| O(n!) | Factorial | Permutations | 3.6M | 10^157 | ∞ |

**Space complexity** follows the same notation — it counts memory consumed relative to n, not time. O(1) space means the algorithm uses a fixed number of variables regardless of n. O(n) space means it allocates something proportional to n (an output array, a call stack, a hash map).

---

## The Code

**Scenario 1 — identifying complexity from code structure**
```csharp
// O(1) — fixed operations regardless of input size
public int GetFirst(int[] arr) => arr[0];

// O(log n) — halves the problem each step
public int BinarySearch(int[] arr, int target)
{
    int lo = 0, hi = arr.Length - 1;
    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2;
        if (arr[mid] == target) return mid;
        if (arr[mid] < target) lo = mid + 1; else hi = mid - 1;
    }
    return -1;
}

// O(n) — one pass through input
public int Sum(int[] arr) { int s = 0; foreach (int x in arr) s += x; return s; }

// O(n²) — nested loops both iterating to n
public bool HasDuplicates(int[] arr)
{
    for (int i = 0; i < arr.Length; i++)
        for (int j = i + 1; j < arr.Length; j++)
            if (arr[i] == arr[j]) return true;
    return false;
}

// O(n log n) — sort dominates
public int[] SortAndReturn(int[] arr) { Array.Sort(arr); return arr; }
```

**Scenario 2 — space complexity examples**
```csharp
// O(1) space — in-place, only a few variables
public void ReverseInPlace(int[] arr)
{
    int lo = 0, hi = arr.Length - 1;
    while (lo < hi) { (arr[lo], arr[hi]) = (arr[hi], arr[lo]); lo++; hi--; }
}

// O(n) space — allocates output proportional to input
public int[] ReverseCopy(int[] arr)
{
    var result = new int[arr.Length]; // O(n) allocation
    for (int i = 0; i < arr.Length; i++)
        result[i] = arr[arr.Length - 1 - i];
    return result;
}

// O(log n) space — recursive binary search uses log n stack frames
public int BinarySearchRecursive(int[] arr, int target, int lo, int hi)
{
    if (lo > hi) return -1;
    int mid = lo + (hi - lo) / 2;
    if (arr[mid] == target) return mid;
    return arr[mid] < target
        ? BinarySearchRecursive(arr, target, mid + 1, hi)   // O(log n) stack depth
        : BinarySearchRecursive(arr, target, lo, mid - 1);
}
```

**Scenario 3 — amortised analysis (dynamic array resizing)**
```csharp
// List<T>.Add() is O(1) amortised, not O(1) worst case.
// Occasional resize doubles the array — O(n) for that one operation.
// Over n additions: total work = n + n/2 + n/4 + ... = 2n = O(n)
// Per operation: O(n) / n = O(1) amortised.
var list = new List<int>(); // initial capacity: 4
for (int i = 0; i < 1000; i++)
    list.Add(i); // O(1) amortised per Add

// Compare: inserting at index 0 is O(n) worst case, O(n) amortised — always shifts all elements
list.Insert(0, -1); // O(n) — no amortisation helps here
```

**Scenario 4 — what NOT to do: claiming O(n) for an O(n²) algorithm**
```csharp
// BAD: this looks like O(n) but is O(n²) — string concatenation in a loop
public string BuildStringBad(string[] parts)
{
    string result = "";
    foreach (string part in parts)
        result += part; // each += allocates a NEW string of growing length → O(n²) total
    return result;
}

// GOOD: O(n) — StringBuilder appends in amortised O(1)
public string BuildStringGood(string[] parts)
{
    var sb = new StringBuilder();
    foreach (string part in parts)
        sb.Append(part); // O(1) amortised
    return sb.ToString(); // one allocation at the end
}
```

---

## Real World Example

During a code review on the `ProductSearchService`, a PR replaced a LINQ `.Contains()` check on a `List<int>` with a `HashSet<int>`. The original code was O(n) per lookup (list scans linearly); the fix was O(1). With 10,000 products and 500 lookups per request, the original code did up to 5,000,000 comparisons per request. The fix did 500.

```csharp
public class ProductSearchService
{
    private readonly List<int> _discontinuedIdsList;      // O(n) per Contains
    private readonly HashSet<int> _discontinuedIdsSet;    // O(1) per Contains

    public ProductSearchService(IEnumerable<int> discontinuedIds)
    {
        var ids = discontinuedIds.ToList();
        _discontinuedIdsList = ids;
        _discontinuedIdsSet  = new HashSet<int>(ids);
    }

    // O(n) per call — scans the entire list each time
    public bool IsDiscontinuedSlow(int productId)
        => _discontinuedIdsList.Contains(productId);

    // O(1) per call — hash lookup
    public bool IsDiscontinuedFast(int productId)
        => _discontinuedIdsSet.Contains(productId);

    // The difference matters in a hot path:
    // FilterCatalogue calls IsDiscontinued for every product in the catalogue.
    // With 10,000 products and 10,000 discontinued IDs:
    //   Slow: O(n²) = 100,000,000 comparisons
    //   Fast: O(n)  =      10,000 hash lookups
    public List<int> FilterCatalogue(List<int> allProductIds)
        => allProductIds.Where(IsDiscontinuedFast).ToList();
}
```

*The key insight: Big-O analysis predicted the problem before profiling confirmed it. O(n) inside a loop of O(n) = O(n²) — the moment you see `.Contains()` on a `List` inside a loop, reach for a `HashSet`.*

---

## Common Misconceptions

**"O(2n) is faster than O(n²) for all n"**
For small n, constants dominate. O(2n) = 20 operations and O(n²) = 100 operations at n=10 — yes, O(n) wins. But at n=2, O(n²) = 4 and O(2n) = 4 — tied. At n=1, O(n²) wins. Big-O describes asymptotic behaviour. For n < ~50, always benchmark rather than relying on notation alone.

**"O(log n) means log base 10"**
In algorithm analysis, log means log base 2 (binary logarithm) unless stated otherwise. It doesn't matter for Big-O since log bases differ only by a constant factor (`log₂(n) = log₁₀(n) / log₁₀(2)`), and constants are dropped. When someone says "log n" in an algorithm context, they mean log₂.

**"Space complexity is just the size of the output"**
Space complexity counts all memory the algorithm uses — input (sometimes), auxiliary data structures, call stack frames, and output. A recursive algorithm with O(n) depth uses O(n) stack space even if it produces O(1) output. The stack is part of the space cost.

---

## Gotchas

- **String concatenation in a loop is O(n²), not O(n).** Each `+=` on a string allocates a new string of the combined length. Over n iterations: n + (n-1) + ... + 1 = O(n²). Always use `StringBuilder` for repeated string building.

- **`List<T>.Contains` is O(n), not O(1).** It scans linearly. `HashSet<T>.Contains` is O(1). `Dictionary<K,V>.ContainsKey` is O(1). This is one of the most common hidden O(n) operations in production C# code.

- **LINQ `.OrderBy().First()` is O(n log n), not O(n).** It sorts the whole sequence. Use `.MinBy()` (O(n)) if you only need the minimum element.

- **Recursive depth counts as space.** A recursive DFS on a tree of depth n uses O(n) stack space even if it never allocates any heap memory. Stack overflow is a space complexity problem.

- **Amortised O(1) is not the same as worst-case O(1).** `List<T>.Add` is O(1) amortised but O(n) worst case on resize. In real-time systems where worst-case latency matters, amortised guarantees are insufficient — use a fixed-capacity array or pre-size the list.

---

## Interview Angle

**What they're really testing:** Whether you automatically think in complexity when you write code — not whether you can recite definitions.

**Common question forms:**
- "What's the time and space complexity of your solution?"
- "Can you do better than O(n²)?"
- "What's the complexity of LINQ `.OrderBy().First()`?"

**The depth signal:** A junior recites Big-O for the obvious loop. A senior analyses every sub-operation — including hidden costs like string concatenation, `.Contains()` on a list, and recursive stack depth — and proactively states both time and space complexity without being asked. They also know the difference between worst-case, best-case, and amortised complexity, and can give an example of each.

**Follow-up questions to expect:**
- "What's the difference between O, Ω, and Θ?" → O is upper bound (worst case); Ω is lower bound (best case); Θ is tight bound (both). In interviews, O = worst case unless specified.
- "Why do we drop constants?" → At large n, the growth rate dominates. O(100n) and O(n) differ by a fixed multiplier; O(n) and O(n²) diverge without bound.

---

## Related Topics

- [[algorithms/complexity/common-complexities.md]] — One real example per complexity class.
- [[algorithms/complexity/complexity-analysis.md]] — How to derive Big-O step-by-step from code.
- [[algorithms/patterns/dynamic-programming.md]] — DP problems often involve trading O(2^n) exponential recursion for O(n²) or O(n) with memoization.

---

## Source

https://en.wikipedia.org/wiki/Big_O_notation

---

*Last updated: 2026-04-21*