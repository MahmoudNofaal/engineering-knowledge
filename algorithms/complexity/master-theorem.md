# Master Theorem
> A formula for solving divide-and-conquer recurrence relations of the form T(n) = aT(n/b) + f(n) without manual expansion.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Three-case formula for divide-and-conquer recurrences |
| **Use when** | Recursive algorithm with equal-sized subproblems |
| **Avoid when** | Subproblems are unequal size, or recurrence doesn't fit the form |
| **Form** | T(n) = aT(n/b) + f(n), where a ≥ 1, b > 1 |
| **Key quantity** | log_b(a) — the "critical exponent" |
| **Alternative** | Akra-Bazzi method for irregular recurrences |

---

## When To Use It

Apply the Master Theorem whenever you have a recursive algorithm that: (1) divides the input into `a` equal subproblems, (2) each of size `n/b`, and (3) does `f(n)` extra work outside the recursive calls. This covers the vast majority of divide-and-conquer algorithms: merge sort, binary search, Strassen's matrix multiplication, fast Fourier transform variants. It's the fastest path from recurrence to Big-O in interviews and code reviews.

Don't apply it when subproblems are unequal-sized (e.g., quicksort worst case: T(n) = T(n-1) + O(n)), when the recurrence form is additive rather than multiplicative (e.g., Fibonacci: T(n) = T(n-1) + T(n-2)), or when the extra work involves another function of n in a non-polynomial way.

---

## Core Concept

The Master Theorem resolves T(n) = aT(n/b) + f(n) by comparing f(n) to n^(log_b a), which represents the work done across all recursive calls (the "recursive work"). The comparison has three outcomes:

- **Case 1** — Recursive work dominates: f(n) grows *slower* than n^(log_b a). The recursion tree base level does the most work. Result: T(n) = Θ(n^(log_b a)).
- **Case 2** — Work is balanced: f(n) grows at the *same rate* as n^(log_b a). Every level of the recursion tree does equal work. Result: T(n) = Θ(n^(log_b a) · log n).
- **Case 3** — Combination work dominates: f(n) grows *faster* than n^(log_b a). The top level does the most work. Result: T(n) = Θ(f(n)).

The intuition: the theorem identifies whether work concentrates at the leaves (Case 1), is spread evenly (Case 2), or concentrates at the root (Case 3).

---

## Version History

| Source | Year | Notes |
|---|---|---|
| Bentley, Haken, Saxe | 1980 | Original paper: "A General Method for Solving Divide-and-Conquer Recurrences" |
| CLRS (Introduction to Algorithms) | 1990 | Standardized presentation; widely taught formulation |
| Akra & Bazzi | 1998 | Extended to unequal subproblem sizes |
| Drmota & Szpankowski | 2013 | Further generalizations for randomized algorithms |

*The version taught in most university courses is CLRS's formulation, which requires f(n) to be polynomially related to n^(log_b a). The original Bentley-Haken-Saxe paper is more general.*

---

## Performance

| Recurrence | a | b | f(n) | log_b(a) | Case | Result |
|---|---|---|---|---|---|---|
| T(n) = T(n/2) + O(1) | 1 | 2 | 1 | 0 | 2 | O(log n) |
| T(n) = 2T(n/2) + O(n) | 2 | 2 | n | 1 | 2 | O(n log n) |
| T(n) = 4T(n/2) + O(n) | 4 | 2 | n | 2 | 1 | O(n²) |
| T(n) = 2T(n/2) + O(n²) | 2 | 2 | n² | 1 | 3 | O(n²) |
| T(n) = 7T(n/2) + O(n²) | 7 | 2 | n² | ~2.81 | 1 | O(n^2.81) |
| T(n) = 2T(n/3) + O(1) | 2 | 3 | 1 | ~0.63 | 1 | O(n^0.63) |

**Allocation behaviour:** The Master Theorem is purely about operations, not allocations. But the recursion depth — O(log n) for balanced divide-and-conquer — determines auxiliary stack space: O(log n) for algorithms like merge sort and binary search.

**Benchmark notes:** Case 2 (balanced work) is the most common in practice — it produces the n log n algorithms (merge sort, most efficient sorts, many tree operations). Case 1 means the work is dominated by leaf-level computation (often indicates poor divide-and-conquer design). Case 3 means the combining step is expensive — sometimes unavoidable (e.g., matrix multiplication).

---

## The Code

**Case 2 — Binary search: T(n) = T(n/2) + O(1)**
```csharp
public static int BinarySearch(int[] sorted, int target)
{
    int lo = 0, hi = sorted.Length - 1;
    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2;
        if (sorted[mid] == target) return mid;
        if (sorted[mid] < target) lo = mid + 1;
        else hi = mid - 1;
    }
    return -1;
}
// a=1 (one subproblem), b=2 (halved), f(n)=O(1) (constant comparison)
// log_b(a) = log_2(1) = 0
// f(n) = O(1) = O(n^0) — matches n^(log_b a) = n^0 = 1 → Case 2
// T(n) = O(n^0 · log n) = O(log n)
```

**Case 2 — Merge sort: T(n) = 2T(n/2) + O(n)**
```csharp
public static int[] MergeSort(int[] arr)
{
    if (arr.Length <= 1) return arr;
    int mid = arr.Length / 2;
    var left = MergeSort(arr[..mid]);   // T(n/2)
    var right = MergeSort(arr[mid..]);  // T(n/2)
    return Merge(left, right);           // O(n)
}
// a=2, b=2, f(n)=O(n)
// log_b(a) = log_2(2) = 1
// f(n) = O(n) = O(n^1) — matches n^(log_b a) = n^1 → Case 2
// T(n) = O(n^1 · log n) = O(n log n)
```

**Case 1 — Recursive work dominates: T(n) = 4T(n/2) + O(n)**
```csharp
// Hypothetical: 4 recursive calls, each on n/2, with O(n) combination
// Example structure: divide into 4 equal quadrants, linear merge
public static void HypotheticalAlgo(int[] arr)
{
    if (arr.Length <= 1) return;
    int q = arr.Length / 2;
    HypotheticalAlgo(arr[..q]);          // T(n/2) × 4
    HypotheticalAlgo(arr[q..]);
    HypotheticalAlgo(arr[..q]);
    HypotheticalAlgo(arr[q..]);
    MergeStep(arr);                       // O(n)
}
// a=4, b=2, f(n)=O(n)
// log_b(a) = log_2(4) = 2
// f(n) = O(n) = O(n^1)
// Is f(n) polynomially SMALLER than n^2? Yes — n^1 vs n^2, difference is n^1 → Case 1
// T(n) = O(n^(log_2 4)) = O(n²)
// The 4 subproblems dominate; the O(n) merge is irrelevant at scale
```

**Case 3 — Combination dominates: T(n) = 2T(n/2) + O(n²)**
```csharp
// Hypothetical: binary divide, but O(n²) combination step
// Example: comparing all pairs during merge
public static void ExpensiveMerge(int[] arr)
{
    if (arr.Length <= 1) return;
    int mid = arr.Length / 2;
    ExpensiveMerge(arr[..mid]);          // T(n/2)
    ExpensiveMerge(arr[mid..]);          // T(n/2)
    CompareAllPairs(arr);                // O(n²) — quadratic combination
}
// a=2, b=2, f(n)=O(n²)
// log_b(a) = log_2(2) = 1
// f(n) = O(n²) — polynomially LARGER than n^1 (by factor n^1) → Case 3
// Must verify regularity condition: a·f(n/b) ≤ c·f(n) for c < 1
// 2·(n/2)² = n²/2 ≤ c·n² ✓ for c = 0.5
// T(n) = O(f(n)) = O(n²)
// The top-level combination dominates all recursive work
```

**Strassen's matrix multiplication — Case 1 with non-integer exponent**
```csharp
// Standard matrix multiply: T(n) = 8T(n/2) + O(n²)
// a=8, b=2, log_2(8)=3 → O(n³) — obvious result

// Strassen's algorithm: T(n) = 7T(n/2) + O(n²)
// Reduces 8 multiplications to 7 — small change, big impact
// a=7, b=2, log_2(7) ≈ 2.807
// f(n) = O(n²) = O(n^2) — is n^2 smaller than n^2.807? Yes → Case 1
// T(n) = O(n^(log_2 7)) ≈ O(n^2.807)
//
// This beats naive O(n³) — Strassen's key insight was that one fewer
// multiplication per 2×2 block compounds into a meaningful improvement at scale
```

**When Master Theorem does NOT apply**
```csharp
// Case: T(n) = T(n-1) + O(n) — subproblem is T(n-1), not T(n/b)
// This is QuickSort worst case. NOT a Master Theorem form.
// Must use expansion: T(n) = n + (n-1) + (n-2) + ... + 1 = O(n²)

// Case: T(n) = T(n-1) + T(n-2) + O(1) — Fibonacci
// Two subproblems of DIFFERENT sizes, and neither is n/b.
// NOT a Master Theorem form. Expansion gives O(φⁿ) ≈ O(1.618ⁿ).

// Case: T(n) = 2T(n/2) + O(n log n)
// f(n) = n log n. Is this the same asymptotic rate as n^(log_2 2) = n?
// n log n grows faster than n but the gap is only log n, not polynomial.
// This is a gap case — the standard Master Theorem doesn't apply cleanly.
// Akra-Bazzi handles it: result is O(n log² n)

public static void CheckBeforeApplying(
    int a, int b, Func<int,double> f, int n)
{
    double criticalExp = Math.Log(a, b);
    double fValue = f(n);
    double criticalValue = Math.Pow(n, criticalExp);

    // Only apply Master Theorem if f(n) / n^(log_b a) behaves polynomially
    Console.WriteLine($"n^(log_{b} {a}) = n^{criticalExp:F2}");
    Console.WriteLine($"f(n) = {fValue}, n^critical = {criticalValue:F2}");
    // If ratio is n^ε for some ε > 0, it's Case 1 or 3; if Θ(1), it's Case 2
}
```

---

## Real World Example

When optimizing a search indexer that used a recursive segment-building algorithm, the team debated whether it was O(n log n) or O(n log² n). Writing the recurrence and applying the Master Theorem resolved the debate in 30 seconds, saved a needless rewrite, and identified where the actual bottleneck was.

```csharp
// Segment tree build: each node processes its range and recurses on two halves
public static void BuildSegmentTree(int[] arr, int node, int start, int end)
{
    if (start == end)
    {
        _tree[node] = arr[start];  // O(1) leaf work
        return;
    }

    int mid = (start + end) / 2;
    BuildSegmentTree(arr, 2 * node, start, mid);        // T(n/2)
    BuildSegmentTree(arr, 2 * node + 1, mid + 1, end);  // T(n/2)

    _tree[node] = _tree[2 * node] + _tree[2 * node + 1]; // O(1) combine
}

// Recurrence: T(n) = 2T(n/2) + O(1)
// a=2, b=2, f(n)=O(1)=O(n^0)
// log_b(a) = log_2(2) = 1
// Is f(n) = O(1) polynomially SMALLER than n^1? Yes — by factor n^1 → Case 1
// T(n) = O(n^(log_2 2)) = O(n^1) = O(n)
//
// The build is O(n), not O(n log n) as some assumed.
// Each of the n elements is processed by exactly one leaf, and internal nodes
// do O(1) work — total work is just O(n).
// The "tree structure" intuitively suggests log n levels but the work per
// level decreases geometrically → resolves to O(n) by Master Theorem Case 1
```

*The key insight: the Master Theorem reveals that seemingly complex recursive structures can reduce to simple linear or logarithmic results. It removes the need for intuition when formal analysis is needed — and it settles debates quickly.*

---

## Common Misconceptions

**"Any divide-and-conquer algorithm is O(n log n)"**
Only if the subproblem count and size match Case 2. With 4 subproblems of size n/2, you get O(n²). With 1 subproblem of size n/2, you get O(log n) or O(n). The number of subproblems `a` and the division factor `b` together determine the result via log_b(a). There's no single answer for divide-and-conquer.

**"The Master Theorem gives exact constants"**
It gives Θ bounds — tight asymptotic bounds — but not constant factors. O(n log n) algorithms differ in practice by constant factors determined by cache behavior, branch prediction, and algorithmic specifics invisible to asymptotic analysis. The theorem classifies algorithms, it doesn't rank them within a class.

**"Case 3 is rare"**
Case 3 is common whenever the combining step is expensive. Matrix operations (O(n²) or O(n³) per level), string operations (O(n) per character), geometric algorithms (O(n log n) per level) — all can push into Case 3. It signals that the divide-and-conquer structure isn't buying much; the combination cost dominates.

---

## Gotchas

- **Verify the regularity condition for Case 3.** You also need `a·f(n/b) ≤ c·f(n)` for some c < 1 and large enough n. Most natural f(n) functions satisfy this, but it's technically required. Missing this condition is a formal error even if the result is correct.

- **Gap cases fall outside the theorem.** T(n) = 2T(n/2) + O(n log n): here f(n) = n log n is not polynomially larger *or* smaller than n^1 = n (the gap is logarithmic, not polynomial). The standard Master Theorem is silent on this case; the answer is O(n log² n) via Akra-Bazzi or careful expansion.

- **The theorem is about T, not about empirical runtime.** A Case 1 result of O(n²) is the worst outcome despite seeming simple — it means the recursion branches more than it should for the problem. Strassen's improvement was specifically about reducing `a` to reduce the Case 1 exponent.

- **Confusing a and b is a common arithmetic error.** For merge sort: a=2 (two subproblems), b=2 (each of size n/2). For binary search: a=1, b=2. The ratio `a/b` being 1:1 doesn't mean a=b — they're different parameters with different roles.

---

## Interview Angle

**What they're really testing:** Whether you can apply the Master Theorem mechanically *and* explain why each case produces the result it does. Mechanical application is junior-level; understanding the Case 1/2/3 intuition (where work concentrates in the recursion tree) is senior-level.

**Common question forms:**
- "What's the complexity of merge sort? Prove it."
- "Apply the Master Theorem to T(n) = 3T(n/4) + O(n)"
- "Why does binary search give O(log n)? Set up the recurrence."

**The depth signal:** A junior says "merge sort is O(n log n) because that's what the Master Theorem gives." A senior says "T(n) = 2T(n/2) + O(n) — log_b(a) = 1, f(n) = n matches n^1 → Case 2, so T(n) = O(n log n). Intuitively, this is Case 2 because work is perfectly balanced across all log n levels of the recursion tree — n work per level × log n levels."

**Follow-up questions to expect:**
- "What if the combination step were O(n²) instead? Which case applies?"
- "Does Master Theorem apply to QuickSort's recurrence? Why or why not?"
- "What's Strassen's matrix multiplication complexity and why is it an improvement?"

---

## Related Topics

- [[algorithms/complexity/recurrence-relations.md]] — How to set up the recurrence before applying the theorem.
- [[algorithms/complexity/complexity-analysis.md]] — The broader toolkit: when to use Master Theorem vs expansion vs tree method.
- [[algorithms/complexity/common-complexities.md]] — The complexity classes Master Theorem results fall into.
- [[algorithms/sorting-algorithms/merge-sort.md]] — The canonical Case 2 example: T(n) = 2T(n/2) + O(n).
- [[algorithms/searching/binary-search.md]] — The canonical Case 2 example: T(n) = T(n/2) + O(1).

---

## Source

https://en.wikipedia.org/wiki/Master_theorem_(analysis_of_algorithms)

---

*Last updated: 2026-04-12*