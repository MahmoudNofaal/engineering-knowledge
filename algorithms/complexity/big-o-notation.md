# Big-O Notation
> A mathematical notation that describes the upper bound of an algorithm's growth rate as input size approaches infinity.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Worst-case growth rate descriptor |
| **Use when** | Comparing algorithm scalability |
| **Avoid when** | Input is small and constant factors dominate |
| **Origin** | Number theory (Bachmann–Landau notation) |
| **Namespace** | N/A — mathematical concept |
| **Key classes** | O(1), O(log n), O(n), O(n log n), O(n²), O(2ⁿ), O(n!) |

---

## When To Use It

Use Big-O when comparing algorithms or data structures to decide which fits your constraints. It matters most when input size can grow large — sorting a list of 10 items? Doesn't matter. Sorting 10 million? It matters enormously. Don't over-optimize for Big-O when data is small and constant factors dominate in practice. A hash map lookup is O(1) but if n never exceeds 20, a linear scan in a `List<T>` is often faster due to cache locality.

Also know when Big-O is *not* the right tool: comparing two O(n log n) algorithms requires benchmarking, not notation — the constant factor is invisible to Big-O.

---

## Core Concept

Big-O describes the worst-case growth rate of an algorithm — not the exact runtime, just how it scales. If you double the input and the time doubles, that's O(n). If the time quadruples, that's O(n²). Constants and lower-order terms get dropped because at large scale they become irrelevant. O(2n) and O(n + 500) are both just O(n). You care about the shape of the curve, not the exact values.

Three companions you'll hear alongside Big-O: Omega (Ω) describes the best case (lower bound), Theta (Θ) describes the exact case when upper and lower bounds match, and Big-O (O) strictly describes the upper bound — worst case. In interview and production contexts, "Big-O" almost always means worst-case analysis, which is the one you need to defend against.

---

## Version History

| Notation | Origin | Notes |
|---|---|---|
| Big-O | 1894 (Paul Bachmann) | Introduced in number theory for prime number analysis |
| Omega (Ω) | 1976 (Donald Knuth) | Knuth formalized asymptotic notation for CS |
| Theta (Θ) | 1976 (Donald Knuth) | Tight bound — upper and lower match |
| Little-o | Academic | Strict upper bound, rarely used in engineering interviews |

*Big-O predates computers. It was adapted from number theory into algorithm analysis by Knuth in the 1970s and has been the dominant notation in CS ever since.*

---

## Performance

| Complexity | n = 10 | n = 1,000 | n = 1,000,000 | Name |
|---|---|---|---|---|
| O(1) | 1 | 1 | 1 | Constant |
| O(log n) | 3 | 10 | 20 | Logarithmic |
| O(n) | 10 | 1,000 | 1,000,000 | Linear |
| O(n log n) | 33 | 9,966 | ~20,000,000 | Linearithmic |
| O(n²) | 100 | 1,000,000 | 10¹² | Quadratic |
| O(2ⁿ) | 1,024 | 10³⁰⁰ | 10³⁰⁰⁰⁰⁰ | Exponential |
| O(n!) | 3,628,800 | ≈ 10²⁵⁶⁷ | unsurvivable | Factorial |

**Allocation behaviour:** Big-O itself describes operations, not allocations. But the same notation applies to space — an O(n) space algorithm allocates memory proportional to input size, which can cause OOM failures well before time limits are hit.

**Benchmark notes:** The "crossover point" where a better-Big-O algorithm actually wins varies by algorithm. A well-tuned O(n²) sort like insertion sort outperforms O(n log n) merge sort for n < ~20 due to cache locality and no allocation overhead. Many library sort implementations (including .NET's `Array.Sort`) use insertion sort for small partitions for exactly this reason.

---

## The Code

**O(1) — Constant: index access, hash lookup**
```csharp
public static int GetFirst(List<int> items)
{
    return items[0];  // always one operation, regardless of list size
}

public static bool ContainsKey(Dictionary<string, int> map, string key)
{
    return map.ContainsKey(key);  // O(1) amortized — hash computation is fixed cost
}
```

**O(log n) — Logarithmic: binary search**
```csharp
public static int BinarySearch(List<int> items, int target)
{
    int lo = 0, hi = items.Count - 1;
    while (lo <= hi)
    {
        int mid = (lo + hi) / 2;
        if (items[mid] == target) return mid;
        else if (items[mid] < target) lo = mid + 1;  // discard left half
        else hi = mid - 1;                            // discard right half
    }
    return -1;
    // Each iteration cuts the search space in half → log₂(n) iterations max
}
```

**O(n) — Linear: single scan**
```csharp
public static int FindMax(List<int> items)
{
    int maxVal = items[0];
    foreach (var item in items)   // touches each element exactly once
        if (item > maxVal) maxVal = item;
    return maxVal;
}
```

**O(n²) — Quadratic: nested loops**
```csharp
// BAD: checking duplicates with nested loops
public static bool HasDuplicateNaive(List<int> items)
{
    for (int i = 0; i < items.Count; i++)
        for (int j = 0; j < items.Count; j++)
            if (i != j && items[i] == items[j]) return true;
    return false;
}

// GOOD: hash set drops it to O(n)
public static bool HasDuplicateFast(List<int> items)
{
    var seen = new HashSet<int>();
    foreach (var item in items)
        if (!seen.Add(item)) return true;
    return false;
}
```

**Simplification rules in action**
```csharp
public static void MultipleLoops(List<int> items)
{
    // Loop 1 — O(n)
    foreach (var item in items)
        Console.WriteLine(item);

    // Loop 2 — O(n), runs AFTER loop 1, not nested
    foreach (var item in items)
        Console.WriteLine(item * 2);

    // Total: O(n) + O(n) = O(2n) → simplified to O(n)
    // Sequential loops ADD. Only nested loops MULTIPLY.
}
```

---

## Real World Example

In a product search API, the initial implementation used a nested loop to find matching tags: for each search term, scan all product tags. At 500 products × 10 tags × 5 search terms, that's 25,000 comparisons per request. At scale with 100,000 products, it collapsed under load. The fix was pre-building a `Dictionary<string, List<Product>>` indexed by tag at startup — turning the hot path from O(n × m × k) to O(k) per search.

```csharp
public class ProductSearchService
{
    // Pre-built once at startup — O(n × m) to build, O(1) per lookup
    private readonly Dictionary<string, List<Product>> _tagIndex;

    public ProductSearchService(IEnumerable<Product> products)
    {
        _tagIndex = new Dictionary<string, List<Product>>(StringComparer.OrdinalIgnoreCase);

        foreach (var product in products)
        {
            foreach (var tag in product.Tags)
            {
                if (!_tagIndex.TryGetValue(tag, out var list))
                {
                    list = new List<Product>();
                    _tagIndex[tag] = list;
                }
                list.Add(product);
            }
        }
    }

    // O(k) where k = number of search terms — independent of product count
    public IEnumerable<Product> Search(IEnumerable<string> searchTerms)
    {
        var result = new HashSet<Product>();
        foreach (var term in searchTerms)
        {
            if (_tagIndex.TryGetValue(term, out var matches))
                foreach (var match in matches)
                    result.Add(match);
        }
        return result;
    }
}
```

*The key insight: trading one-time O(n × m) build cost for O(1) per query is almost always the right trade-off in read-heavy systems. The startup cost amortizes to nothing at scale.*

---

## Common Misconceptions

**"O(1) means fast and O(n²) means slow"**
O(1) means *constant*, not fast. A SHA-256 hash is O(1) but takes microseconds. An array access is O(1) and takes nanoseconds. And O(n²) on n=10 is 100 operations — completely fine. Big-O describes scaling behaviour, not absolute performance. The constant factor is invisible to the notation.

**"Two loops means O(n²)"**
Only nested loops multiply. Two sequential loops give O(n) + O(n) = O(2n) = O(n). The classic mistake is visually counting loops rather than analyzing their relationship. Ask: does the inner loop run n times *for each iteration* of the outer loop? If yes, that's multiplication. If they run one after the other, it's addition.

```csharp
// This is O(n), not O(n²) — the loops are sequential, not nested
for (int i = 0; i < n; i++) DoA(i);
for (int i = 0; i < n; i++) DoB(i);
```

**"Big-O accounts for everything"**
Big-O drops constants and ignores real-world effects: cache locality, branch prediction, memory allocation overhead, and SIMD instructions all affect observed performance but are invisible to asymptotic notation. This is why profilers exist — they measure the constant factors Big-O ignores.

---

## Gotchas

- **Dropping constants can mislead you in practice.** O(n) with a massive constant can be slower than O(n²) for small n. Big-O is about scale, not a guarantee of real-world speed. Always benchmark before optimizing based on notation alone.

- **Big-O is worst-case by default — but not always.** QuickSort is O(n²) worst-case but O(n log n) average. When someone says QuickSort is fast, they mean average-case. Know which case you're discussing and state it explicitly.

- **Space complexity is just as real as time complexity.** Recursive solutions often look clean but carry O(n) call stack space. A recursive DFS on a tree with depth 10,000 can blow the stack before it hits a time limit. Always state both.

- **Two separate loops is O(n), not O(n²).** Only nested loops multiply. Sequential loops add: O(n) + O(n) = O(2n) = O(n). Train yourself to ask "are these nested or sequential?" before classifying.

- **Hash map lookups are O(1) amortized, not guaranteed.** Worst-case with pathological hash collisions is O(n). In interview answers, say "amortized O(1)" — it shows you understand the implementation, not just the lookup table.

- **The `.Contains()` call hiding inside your "O(n)" loop.** A single loop with a `list.Contains(x)` call inside is actually O(n²) because `Contains` is O(n) on a `List<T>`. Use a `HashSet<T>` when you need O(1) membership checks inside a loop.

---

## Interview Angle

**What they're really testing:** Whether you can reason about scalability trade-offs, not just recite a lookup table. They want to see you *derive* complexity, not recall it.

**Common question forms:**
- "What's the time complexity of your solution?"
- "Can you do better than O(n²)?"
- "Walk me through why that's O(n log n) and not O(n²)"

**The depth signal:** A junior says "it's O(n) because there's one loop." A senior derives it — "it's O(n) because each element is visited exactly once, and the hash map lookups inside are O(1) amortized, so the loop doesn't compound into O(n²)." Seniors also volunteer space complexity unprompted and know *when* an O(n log n) solution is provably optimal (e.g., comparison-based sorting has a proven lower bound of Ω(n log n) due to the decision tree argument).

**Follow-up questions to expect:**
- "What about the space complexity?" (always asked if you only gave time)
- "Is that average-case or worst-case?" (the trap when you say QuickSort is O(n log n))
- "Can you prove that's the best possible?" (the senior-level follow-up on sorting)

---

## Related Topics

- [[algorithms/complexity/common-complexities.md]] — Each class with concrete code examples and the practical thresholds where they break.
- [[algorithms/complexity/complexity-analysis.md]] — The process of deriving complexity from code you haven't seen before.
- [[algorithms/complexity/space-complexity.md]] — Applying the same notation to memory usage, including call stack analysis.
- [[algorithms/complexity/amortized-analysis.md]] — How to reason about operations whose cost varies but averages out.
- [[algorithms/datastructures/hash-table.md]] — Why hash lookups are O(1) amortized and when they degrade to O(n).

---

## Source

https://www.bigocheatsheet.com

---

*Last updated: 2026-04-12*