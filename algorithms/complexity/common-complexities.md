# Common Complexities

> A reference of the seven complexity classes that appear in practice — O(1) through O(n!) — with canonical algorithms and the practical scale limits of each.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Reference table of the growth classes that matter in practice |
| **Use when** | Identifying what complexity class an algorithm belongs to |
| **Avoid when** | N/A — this is reference material |
| **C# version** | N/A — mathematical classification |
| **Namespace** | N/A |
| **Key types** | O(1), O(log n), O(n), O(n log n), O(n²), O(2^n), O(n!) |

---

## When To Use It

Use this as a lookup when deriving an algorithm's complexity: once you know the structure (one pass? recursive halving? nested loops?), map it to the class here. Also use it to calibrate "is this fast enough?" — each class has a practical limit beyond which it becomes too slow for interactive (< 1 second) use.

---

## Core Concept

Every algorithm's complexity belongs to one of a small number of growth classes. The dominant term determines the class — lower-order terms and constants are dropped. The table below maps each class to its canonical algorithm, its practical n limit, and its "feel" so you can recognise it quickly.

**Practical scale guide (operations per second ≈ 10^8 for simple ops):**

| Class | Max tractable n | Feeling |
|---|---|---|
| O(1) | Any | Fixed cost — always instant |
| O(log n) | Any | Grows so slowly it's essentially free |
| O(n) | ~10^8 | Linear scan of everything once |
| O(n log n) | ~10^7 | Sorting — fast in practice |
| O(n²) | ~10^4 | Nested loops — fine for small n, pain for large |
| O(n³) | ~500 | Triple nested loops — limited to tiny inputs |
| O(2^n) | ~25 | Subset enumeration — only small n |
| O(n!) | ~12 | Permutation enumeration — tiny n only |

---

## Algorithm History

| Year | Development |
|---|---|
| 1894–1909 | Bachmann and Landau define the O, Ω, Θ notation families |
| 1962 | Karatsuba shows O(n^1.585) multiplication — first algorithm to beat O(n²) for arithmetic |
| 1971 | Cook-Levin theorem establishes NP-completeness — O(2^n) lower bounds for many problems |
| 1980s | CLRS textbook standardises the complexity class hierarchy for CS education |

---

## Performance

Detailed breakdown of each class:

| Class | Operations at n=1000 | Canonical algorithm | Real cost driver |
|---|---|---|---|
| O(1) | 1 | Array index, dictionary lookup | Register-level ops |
| O(log n) | ~10 | Binary search, heap insert | Halving the search space |
| O(√n) | ~32 | Trial division primality | Loop to √n |
| O(n) | 1,000 | Linear scan, prefix sum | One pass |
| O(n log n) | ~10,000 | Merge sort, heap sort | Sort or divide-and-conquer |
| O(n²) | 1,000,000 | Bubble sort, naive two-sum | Nested loops |
| O(n³) | 10^9 | Naive matrix multiply, Floyd-Warshall | Triple nested loops |
| O(2^n) | 10^301 | Subset enumeration, backtracking | Exponential branching |
| O(n!) | 4×10^2567 | Permutation enumeration, brute-force TSP | All orderings |

**Space equivalents:**

| Class | Example | What consumes the space |
|---|---|---|
| O(1) | In-place sort (selection sort) | Fixed variables |
| O(log n) | Recursive binary search | Call stack depth |
| O(n) | Merge sort buffer, hash map | Auxiliary array or map |
| O(n²) | Adjacency matrix, DP table | 2D grid |

---

## The Code

**Scenario 1 — O(1): hash map lookup**
```csharp
// O(1) — dictionary lookup is a hash computation + pointer follow, independent of size
var prices = new Dictionary<string, decimal>
{
    ["apple"] = 0.99m, ["banana"] = 0.59m, ["cherry"] = 2.49m
};
decimal price = prices["apple"]; // O(1) regardless of how many items are in the dictionary
```

**Scenario 2 — O(log n): binary search**
```csharp
// O(log n) — halves the search space each step
// n=1000 → at most 10 iterations; n=1,000,000 → at most 20 iterations
public int BinarySearch(int[] sortedArr, int target)
{
    int lo = 0, hi = sortedArr.Length - 1;
    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2;
        if (sortedArr[mid] == target) return mid;
        if (sortedArr[mid] < target)  lo = mid + 1;
        else                          hi = mid - 1;
    }
    return -1;
}
```

**Scenario 3 — O(n log n): merge sort**
```csharp
// O(n log n) — log n levels of recursion, O(n) work per level
// The recurrence T(n) = 2T(n/2) + O(n) solves to O(n log n) by Master Theorem Case 2
public void MergeSort(int[] arr, int lo, int hi)
{
    if (lo >= hi) return;
    int mid = (lo + hi) / 2;
    MergeSort(arr, lo, mid);       // T(n/2)
    MergeSort(arr, mid + 1, hi);   // T(n/2)
    Merge(arr, lo, mid, hi);       // O(n)
}
```

**Scenario 4 — identifying hidden O(n²) vs apparent O(n)**
```csharp
// LOOKS like O(n) but is O(n²) — nested iteration hidden inside a method call
public bool HasCommonElement(List<int> a, List<int> b)
{
    foreach (int x in a)
        if (b.Contains(x)) return true; // b.Contains is O(|b|) — total: O(|a| × |b|)
    return false;
}

// O(n) with a HashSet — convert b once, then O(1) per lookup
public bool HasCommonElementFast(List<int> a, List<int> b)
{
    var setB = new HashSet<int>(b); // O(|b|) once
    foreach (int x in a)
        if (setB.Contains(x)) return true; // O(1) each
    return false;
}

// Also O(n log n) with sorting + two pointers:
public bool HasCommonElementSort(List<int> a, List<int> b)
{
    a.Sort(); b.Sort(); // O(n log n)
    int i = 0, j = 0;
    while (i < a.Count && j < b.Count)
    {
        if (a[i] == b[j]) return true;
        if (a[i] < b[j]) i++; else j++;
    }
    return false;
}
```

---

## Real World Example

The `RecommendationEngine` at an e-commerce platform generates personalised product recommendations. The initial implementation computed cosine similarity between every user-product pair — O(U × P) = O(n²) for U users and P products. At 100k users and 50k products, this was 5 billion operations per batch run, taking 4 hours. Replacing with an approximate nearest-neighbour index (O(n log n) build, O(log n) query) brought it to 8 minutes.

```csharp
public class RecommendationEngine
{
    // Complexity comparison for a batch recommendation job
    // U = users, P = products, K = embedding dimensions

    // O(U × P × K) — brute-force cosine similarity for all pairs
    // At U=100k, P=50k, K=128: ~640 billion multiplications per batch
    public Dictionary<int, List<int>> BruteForceRecommend(
        float[][] userEmbeddings,   // [U][K]
        float[][] productEmbeddings // [P][K]
    )
    {
        int u = userEmbeddings.Length, p = productEmbeddings.Length, k = userEmbeddings[0].Length;
        var result = new Dictionary<int, List<int>>();

        for (int i = 0; i < u; i++)
        {
            // For each user: score all P products — O(P × K) per user → O(U × P × K) total
            var scores = new (float Score, int ProductId)[p];
            for (int j = 0; j < p; j++)
                scores[j] = (CosineSimilarity(userEmbeddings[i], productEmbeddings[j], k), j);

            Array.Sort(scores, (a, b) => b.Score.CompareTo(a.Score));
            result[i] = scores.Take(10).Select(s => s.ProductId).ToList();
        }
        return result;
    }

    private static float CosineSimilarity(float[] a, float[] b, int k)
    {
        float dot = 0, magA = 0, magB = 0;
        for (int i = 0; i < k; i++) { dot += a[i]*b[i]; magA += a[i]*a[i]; magB += b[i]*b[i]; }
        return dot / (MathF.Sqrt(magA) * MathF.Sqrt(magB) + 1e-8f);
    }

    // O(P × K log P) build + O(log P × K) per user query — approximate but fast
    // Real implementation uses HNSW or FAISS; this is the conceptual shape
    public string ExplainComplexityImprovement()
        => "Brute force: O(U×P×K). ANN index: O(P×K log P) build + O(U × log P × K) queries. " +
           "For U=100k, P=50k, K=128: from 6.4×10^11 to ~1.3×10^9 ops — ~500× speedup.";
}
```

*The key insight: recognising O(n²) in the structure (every user × every product) immediately signals "this won't scale." The complexity class predicts the problem before you run the benchmark.*

---

## Common Misconceptions

**"O(n log n) is close to O(n) — it barely matters"**
At n = 10,000,000: O(n) = 10M operations, O(n log n) = 230M operations — a 23× difference. At n = 10^9: O(n log n) = 30 billion — too slow for a 1-second budget. The log factor matters at scale. Sorting is the most common reason an otherwise-O(n) algorithm becomes O(n log n).

**"O(n²) is always too slow"**
For n ≤ 1,000, O(n²) is about 1 million operations — fast on any modern hardware. Insertion sort (O(n²)) is used inside Timsort for subarrays of ≤ 32 elements because the constant factor beats merge sort's O(n log n) at small n. Always consider the actual n before rejecting an O(n²) algorithm.

**"O(2^n) is unusable"**
For n ≤ 20, O(2^n) = ~1M operations — perfectly tractable. Bitmask DP (TSP with ≤ 20 cities), subset enumeration for small sets, and backtracking with heavy pruning all run in acceptable time. The constraint "n ≤ 20" or "n ≤ 25" in a problem is an explicit signal that exponential is expected and acceptable.

---

## Gotchas

- **O(n log n) is the barrier for comparison-based sorting.** The comparison model has a Ω(n log n) lower bound — no comparison-based sort can do better. Non-comparison sorts (counting, radix) beat this by using key structure, but only for specific data types.

- **Hidden costs change the class.** `.ToList()` on a LINQ query is O(n). `.OrderBy()` is O(n log n). `.First()` after `.OrderBy()` is still O(n log n) — the full sort runs before the first element is returned. Use `.MinBy()` (O(n)) instead.

- **O(n) space from recursion can cause stack overflow before it causes an out-of-memory exception.** The default stack size in .NET is 1MB. A recursive call at ~8 bytes per frame allows ~125,000 frames before overflow. For deep recursion (tree height, DFS depth), convert to iterative before hitting this limit.

- **Amortised complexity is not per-operation worst case.** `List<T>.Add` is O(1) amortised — the occasional O(n) resize is averaged across all n additions. In real-time systems, this occasional spike matters even if the average is fine.

- **`string + string` in a loop is O(n²), not O(n).** Every concatenation allocates a new string of growing length. The total allocation is 1 + 2 + 3 + ... + n = O(n²). `StringBuilder` is O(n) because it appends to an internal buffer.

---

## Interview Angle

**What they're really testing:** Whether you can look at code and immediately know its complexity class — without having to think hard about it.

**Common question forms:**
- "What's the complexity of this code?" (shown a nested loop)
- "Can you improve this from O(n²) to O(n log n) or O(n)?"
- "What's the maximum n for which this will run in time?"

**The depth signal:** A junior identifies the obvious loop complexity. A senior identifies hidden costs (string concatenation, `.Contains()` on a list, recursive stack depth), knows the comparison sort lower bound (Ω(n log n)), and gives a concrete "this is too slow at n = 10,000 because that's 100M operations and we have a 100ms budget" analysis.

**Follow-up questions to expect:**
- "Why is sorting O(n log n) and not O(n)?" → Ω(n log n) lower bound for comparison-based sorting from information theory: n! possible orderings require log₂(n!) ≈ n log n bits to distinguish.

---

## Related Topics

- [[algorithms/complexity/big-o-notation.md]] — The notation itself; this file is the reference for the classes.
- [[algorithms/complexity/complexity-analysis.md]] — How to derive which class an algorithm belongs to.
- [[algorithms/sorting-algorithms/sorting-in-practice.md]] — Why O(n log n) is the practical sorting standard.

---

## Source

https://en.wikipedia.org/wiki/Time_complexity

---

*Last updated: 2026-04-21*