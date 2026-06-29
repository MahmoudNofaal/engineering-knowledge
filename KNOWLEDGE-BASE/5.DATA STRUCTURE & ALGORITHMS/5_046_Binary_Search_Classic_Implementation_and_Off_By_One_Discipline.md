---
id: "5.046"
studied_well: false
title: "Binary Search — Classic Implementation and Off-by-One Discipline"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Binary Search"
tags: [dsa, algorithms, binary-search, sorted-array, divide-and-conquer, csharp, interviews]
priority: 1
prerequisites:
  - "[[5.004 — Arrays — Fixed, Dynamic, and In-Place Operations]]"
  - "[[5.001 — Big-O Notation and Complexity Analysis]]"
related:
  - "[[5.047 — Binary Search on the Answer]]"
  - "[[5.048 — Binary Search Variants — Rotated Array, 2D Matrix, Peak Element]]"
  - "[[2.002 — Array and List Internals]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Binary Search
**Previous:** [[5.041 — Dijkstra's Algorithm]] | **Next:** [[5.047 — Binary Search on the Answer]]

### Prerequisites
- [[5.004 — Arrays — Fixed, Dynamic, and In-Place Operations]] — binary search operates on a sorted array; index arithmetic (mid, low, high) is the core mechanism.
- [[5.001 — Big-O Notation and Complexity Analysis]] — the O(log n) derivation from halving the search space must be understood.

### Where This Fits
Binary search is the most fundamental divide-and-conquer algorithm. Given a sorted array and a target value, it finds the target in O(log n) time by repeatedly halving the search range. It appears directly in about 10% of coding interviews and is the foundation for more advanced patterns: binary search on the answer (searching over a monotonic predicate space), searching in rotated arrays, and finding peaks in bitonic arrays. Despite its apparent simplicity, binary search is notoriously easy to get wrong — off-by-one errors, infinite loops, and incorrect boundary conditions are the norm. A senior candidate must be able to write a bug-free binary search from memory, handle all four variants (first occurrence, last occurrence, insertion point, exact match), and explain the loop invariant.

---

## Core Mental Model

Binary search exploits the sorted property of an array. The search space is the interval [low, high]. At each step, examine the middle element mid = low + (high - low) / 2. If the middle element equals the target, return its index. If the target is less than the middle, continue in the left half [low, mid - 1]. If greater, continue in the right half [mid + 1, high]. The key invariant is that the target, if it exists, is always in the current interval [low, high]. Each iteration halves the interval size, giving O(log n) iterations.

### Classification

Binary search is a **divide-and-conquer** algorithm that operates on **sorted data**. It is a **search algorithm** specifically for sorted sequences — it does not apply to unsorted data (except in the "binary search on answer" pattern, where the search space is a monotonic function).

```mermaid
graph TD
    A[Search Algorithms] --> B[Linear Search — O(n), unsorted data]
    A --> C[Binary Search — O(log n), sorted data]
    A --> D[Interpolation Search — O(log log n), uniformly distributed data]
    C --> E[Classic — exact match]
    C --> F[Lower bound — first ≥ target]
    C --> G[Upper bound — first > target]
    C --> H["Binary search on answer — monotonic predicate"]
    E --> I["Divide, compare, recurse"]
    F --> J["Always narrow to [low, high]"]
```

### Key Properties

|Property|Value|Derivation|
|---|---|---|
|Exact match|O(log n)|Each iteration halves the search space; after k iterations, n × (1/2)^k ≤ 1 → k = log₂ n|
|Lower bound (first ≥ target)|O(log n)|Same halving logic; the midpoint comparison determines which half to keep|
|Insertion point|O(log n)|Same as lower bound — the index where the target should be inserted to maintain order|
|Space (iterative)|O(1)|Two or three integer variables (low, high, mid)|
|Space (recursive)|O(log n)|Call stack depth = number of recursive calls = log₂ n|

---

## Deep Mechanics

### How It Works

**Standard binary search (iterative):**
1. Set low = 0, high = n - 1.
2. While low ≤ high:
   a. mid = low + (high - low) / 2.
   b. If arr[mid] == target → return mid.
   c. If arr[mid] < target → low = mid + 1 (search right half).
   d. If arr[mid] > target → high = mid - 1 (search left half).
3. Return -1 (target not found).

**Why `low + (high - low) / 2` instead of `(low + high) / 2`:**
The naive formula `(low + high) / 2` can overflow for large arrays (when low + high exceeds int.MaxValue). `low + (high - low) / 2` avoids this by computing the midpoint relative to low — the largest intermediate value is at most `high - low`, which fits in an int.

**Loop invariant:**
If the target exists in the array, its index is in the range [low, high]. Initially true because the whole array is the range. Each iteration either returns (target found) or narrows the range while preserving the invariant. When low > high, the range is empty — the target does not exist.

**Variants:**
- **Lower bound (first occurrence of target):** Returns the leftmost index where arr[index] == target. When arr[mid] == target, set high = mid (keep searching left) instead of returning early.
- **Upper bound (first index > target):** Returns the leftmost index where arr[index] > target. When arr[mid] ≤ target, set low = mid + 1; otherwise set high = mid.
- **Range query:** Compute lower bound of target and lower bound of (target + 1). The results give the start and end+1 indices of the target range.

**Example trace:**
Array: [1, 3, 5, 7, 9], target = 5
- low=0, high=4, mid=2 (value 5). arr[2] == 5 → return 2.

Array: [1, 3, 5, 7, 9], target = 6
- low=0, high=4, mid=2 (value 5). 5 < 6 → low=3.
- low=3, high=4, mid=3 (value 7). 7 > 6 → high=2.
- low=3, high=2 → loop exits. Return -1.

### Complexity Derivation

**Time:** The search space starts at size n. After each iteration, the remaining search space is at most half of the previous size. After k iterations, the size is at most n / 2^k. The loop terminates when the size is 0 (empty range) or the target is found. Solving n / 2^k ≤ 1 gives k ≥ log₂ n. Each iteration does O(1) work (comparison + arithmetic). Total: O(log n).

**Space (iterative):** O(1) — three local variables.
**Space (recursive):** O(log n) — the call stack depth equals the number of recursive calls.

### .NET Runtime Notes

- **`Array.BinarySearch<T>(T[], T)`:** .NET provides a built-in binary search for arrays. It returns the index of the element if found, or a negative number (bitwise complement of the insertion point) if not found. The insertion point is `~result` — the index where the element should be inserted to maintain sorted order.
- **`List<T>.BinarySearch(T)`:** Same API as `Array.BinarySearch` but on `List<T>`.
- **Custom comparer:** Both overloads accept `IComparer<T>` for custom ordering.
- **Range checks:** The built-in methods throw `ArgumentException` if the array is not sorted according to the comparer — but do not actually verify sorting (it is unchecked).
- **When to use built-in:** Always prefer `Array.BinarySearch` or `List<T>.BinarySearch` in production code. The scratch implementation is only for interviews where the question specifically asks you to implement binary search.
- **`Span<T>.BinarySearch`:** Available in .NET 5+ for stack-allocated or slice-based binary search.

---

## Implementation and Problem Patterns

### C# Implementation

```csharp
/// <summary>
/// Classic binary search — returns index of target, or -1 if not found.
/// </summary>
public static int BinarySearch(int[] arr, int target)
{
    int low = 0, high = arr.Length - 1;

    while (low <= high)
    {
        int mid = low + (high - low) / 2;

        if (arr[mid] == target)
            return mid;

        if (arr[mid] < target)
            low = mid + 1;
        else
            high = mid - 1;
    }

    return -1;
}

/// <summary>
/// Lower bound — first index where arr[index] >= target.
/// Returns arr.Length if no such index exists.
/// </summary>
public static int LowerBound(int[] arr, int target)
{
    int low = 0, high = arr.Length;

    while (low < high)
    {
        int mid = low + (high - low) / 2;

        if (arr[mid] < target)
            low = mid + 1;
        else
            high = mid;
    }

    return low;
}

/// <summary>
/// Upper bound — first index where arr[index] > target.
/// Returns arr.Length if no such index exists.
/// </summary>
public static int UpperBound(int[] arr, int target)
{
    int low = 0, high = arr.Length;

    while (low < high)
    {
        int mid = low + (high - low) / 2;

        if (arr[mid] <= target)
            low = mid + 1;
        else
            high = mid;
    }

    return low;
}

/// <summary>
/// First occurrence of target — returns -1 if not found.
/// </summary>
public static int FirstOccurrence(int[] arr, int target)
{
    int index = LowerBound(arr, target);
    return index < arr.Length && arr[index] == target ? index : -1;
}

/// <summary>
/// Last occurrence of target — returns -1 if not found.
/// </summary>
public static int LastOccurrence(int[] arr, int target)
{
    int index = UpperBound(arr, target) - 1;
    return index >= 0 && arr[index] == target ? index : -1;
}

/// <summary>
/// Count occurrences of target in a sorted array (with duplicates).
/// </summary>
public static int CountOccurrences(int[] arr, int target)
{
    int first = FirstOccurrence(arr, target);
    if (first == -1) return 0;
    int last = LastOccurrence(arr, target);
    return last - first + 1;
}

/// <summary>
/// Recursive binary search — mainly for illustration; iterative is preferred.
/// </summary>
public static int BinarySearchRecursive(int[] arr, int target)
{
    return BinarySearchRecursive(arr, target, 0, arr.Length - 1);
}

private static int BinarySearchRecursive(int[] arr, int target, int low, int high)
{
    if (low > high) return -1;

    int mid = low + (high - low) / 2;

    if (arr[mid] == target) return mid;
    if (arr[mid] < target)
        return BinarySearchRecursive(arr, target, mid + 1, high);
    else
        return BinarySearchRecursive(arr, target, low, mid - 1);
}
```

### The .NET Idiomatic Version

```csharp
public static class BinarySearchIdiomatic
{
    // Prefer built-in for production code:
    public static void BuiltInExamples()
    {
        int[] arr = { 1, 3, 5, 7, 9 };

        // Exact match:
        int index = Array.BinarySearch(arr, 5); // 2

        // Not found → negative complement of insertion point:
        int notFound = Array.BinarySearch(arr, 6); // -4 (~3)
        int insertionPoint = ~notFound; // 3

        // With custom comparer (descending order):
        int[] desc = { 9, 7, 5, 3, 1 };
        int descIndex = Array.BinarySearch(desc, 5,
            Comparer<int>.Create((a, b) => b.CompareTo(a))); // 2

        // On List<T>:
        var list = new List<int> { 1, 3, 5, 7, 9 };
        int listIndex = list.BinarySearch(5); // 2

        // On Span<T>:
        Span<int> span = arr.AsSpan();
        int spanIndex = span.BinarySearch(5); // 2
    }

    // Use LowerBound/UpperBound for range queries in sorted arrays.
    // The built-in SearchFocused does not provide these directly,
    // so the scratch implementation in the previous section is
    // required when the built-in API is insufficient.
}
```

### Classic Problem Patterns

1. **Exact match in sorted array** — The classic: find whether a target exists in a sorted array. Key insight: halving the search space eliminates O(n) comparison, giving O(log n).
2. **First and last occurrence of target** — In a sorted array with duplicates, find the range [first, last] of a target value. Key insight: use lower bound for first, upper bound - 1 for last. Count = last - first + 1.
3. **Insertion point** — Find the index where a target should be inserted to maintain sorted order. Key insight: lower bound gives the insertion point; if the target exists, it is the first occurrence; if not, it is where it would be placed.
4. **Closest element to target** — Find the element in a sorted array closest to a given target. Key insight: find the insertion point (lower bound); the closest is either the element at that index or the one before it.
5. **Find index of a minimum in rotated sorted array** — A sorted array rotated at an unknown pivot, find the index of the minimum element. Key insight: compare mid with high — if mid > high, the minimum is in the right half; otherwise in the left half.

### Template / Skeleton

```csharp
// Binary Search Template (lower bound / first ≥ target)
// When to use: sorted array, need exact match, first/last occurrence,
//              insertion point, or range query
// Time: O(log n) | Space: O(1)

public static int BinarySearchTemplate(int[] arr, int target)
{
    int low = 0, high = arr.Length; // high = n for lower bound, n-1 for exact match

    while (low < high) // use <= for exact match (early return)
    {
        int mid = low + (high - low) / 2;

        // TODO: choose comparison based on variant:
        // Exact match: if (arr[mid] == target) return mid;
        // Lower bound: if (arr[mid] < target) low = mid + 1; else high = mid;
        // Upper bound: if (arr[mid] <= target) low = mid + 1; else high = mid;
        if (arr[mid] < target)
            low = mid + 1;
        else
            high = mid;
    }

    // low is the insertion point
    // TODO: for exact match, check: low < arr.Length && arr[low] == target
    return low;
}
```

---

## Gotchas and Edge Cases

### Integer Overflow When Computing Mid

**Mistake:** Using `(low + high) / 2` which overflows for large arrays.

```csharp
// ❌ Wrong — overflow when low + high > int.MaxValue
int mid = (low + high) / 2;
```

**Fix:** Use `low + (high - low) / 2` which avoids overflow.

```csharp
// ✅ Correct — no overflow; equivalent to (low + high) / 2
int mid = low + (high - low) / 2;
```

**Consequence:** mid becomes negative when low + high overflows int.MaxValue (~2.1 billion). For arrays with 1B+ elements, this produces an index out of bounds.

### Off-by-One in Loop Condition — Infinite Loop

**Mistake:** Using `while (low < high)` without adjusting `high = mid` correctly in exact-match binary search.

```csharp
// ❌ Wrong — infinite loop when target is at the last checked position
int low = 0, high = arr.Length - 1;
while (low < high) // should be <=
{
    int mid = low + (high - low) / 2;
    if (arr[mid] == target) return mid;
    if (arr[mid] < target) low = mid + 1;
    else high = mid - 1;
}
// When low == high == 0 and arr[0] == target, the loop exits without checking
```

**Fix:** Use `while (low <= high)` for exact-match binary search.

```csharp
// ✅ Correct — checks all elements including when low == high
while (low <= high)
```

**Consequence:** Target at the final index (when low == high) is never checked — function returns -1 incorrectly.

### Off-by-One in Lower Bound High Initialization

**Mistake:** Setting `high = arr.Length - 1` in lower-bound search, which fails when the target is greater than all elements.

```csharp
// ❌ Wrong — cannot return arr.Length if target > all elements
int low = 0, high = arr.Length - 1;
while (low < high)
{
    int mid = low + (high - low) / 2;
    if (arr[mid] < target) low = mid + 1;
    else high = mid;
}
// When target > all elements, low converges to arr.Length - 1, not arr.Length
```

**Fix:** Set `high = arr.Length` to allow the result to be one past the last index.

```csharp
// ✅ Correct — high = arr.Length allows returning n if not found
int low = 0, high = arr.Length;
```

**Consequence:** The insertion point for a target larger than all elements is incorrectly returned as n-1 instead of n — causing out-of-bounds access when used as an insertion position.

### Infinite Loop with Mid Computation in Lower Bound

**Mistake:** Using `mid = (low + high) / 2` (floor) with `low = mid` instead of `low = mid + 1`.

```csharp
// ❌ Wrong — infinite loop when low and high are 1 apart
int low = 0, high = n;
while (low < high)
{
    int mid = low + (high - low) / 2; // floor
    if (arr[mid] <= target) low = mid; // never advances if low = mid and no progress
    else high = mid;
}
```

**Fix:** When using floor mid, always use `low = mid + 1` for the target-on-right case. Or use `mid = low + (high - low + 1) / 2` (ceiling) with `low = mid`.

```csharp
// ✅ Correct — low always advances
if (arr[mid] < target) low = mid + 1;
else high = mid;
```

**Consequence:** When low = 0, high = 1, mid = 0, and arr[0] == target, the lower-bound check sets low = 0 (no progress), causing an infinite loop.

---

## Complexity Analysis and Benchmarks

### Operation Complexity Table

|Operation|Time (Best)|Time (Average)|Time (Worst)|Space|Notes|
|---|---|---|---|---|---|
|Exact match|O(1)|O(log n)|O(log n)|O(1)|Best case: target is at the first midpoint checked|
|Lower bound|O(1)|O(log n)|O(log n)|O(1)|Best case: target ≤ arr[0]|
|Upper bound|O(1)|O(log n)|O(log n)|O(1)|Best case: target < arr[0]|
|Range query (first + last)|O(log n)|O(log n)|O(log n)|O(1)|Two binary searches — 2 × O(log n) = O(log n)|
|Recursive binary search|O(1)|O(log n)|O(log n)|O(log n)|Call stack adds O(log n) space|

**Derivation for the non-obvious entries:** Each iteration divides the remaining search space in half. The number of iterations is the number of times n can be halved before reaching 1: ⌈log₂ (n + 1)⌉. For exact match, the best case is 1 comparison (target at mid). For lower/upper bound, the best case is also 1 comparison (target at the boundary).

### Comparison with Alternatives

|Algorithm|Time|Space|Data Requirement|Best When|
|---|---|---|---|---|
|Binary search|O(log n)|O(1)|Sorted array|Sorted data, many queries|
|Linear search|O(n)|O(1)|Unsorted data|Small n, single query, unsorted data|
|Hash set lookup|O(1) avg|O(n)|Hashable, existence only|Existence queries on unsorted data, no ordering needed|
|Interpolation search|O(log log n) avg, O(n) worst|O(1)|Sorted + uniformly distributed|Large sorted arrays with uniform distribution|

### BenchmarkDotNet

```csharp
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net90)]
public class BinarySearchBenchmark
{
    [Params(1_000, 100_000)]
    public int N { get; set; }

    private int[] _sorted = null!;
    private int _searchTarget;

    [GlobalSetup]
    public void Setup()
    {
        _sorted = Enumerable.Range(0, N).ToArray();
        _searchTarget = N / 3;
    }

    [Benchmark(Baseline = true)]
    public int BuiltInBinarySearch() => Array.BinarySearch(_sorted, _searchTarget);

    [Benchmark]
    public int ScratchBinarySearch() => BinarySearch(_sorted, _searchTarget);

    [Benchmark]
    public int LowerBoundSearch() => LowerBound(_sorted, _searchTarget);

    [Benchmark]
    public int LinearSearch()
    {
        for (int i = 0; i < _sorted.Length; i++)
            if (_sorted[i] == _searchTarget) return i;
        return -1;
    }
}
```

**Expected results (approximate, .NET 9, x64):**

|Method|N|Mean|Allocated|
|---|---|---|---|
|BuiltInBinarySearch|1,000|~5 ns|0 B|
|BuiltInBinarySearch|100,000|~15 ns|0 B|
|ScratchBinarySearch|1,000|~4 ns|0 B|
|ScratchBinarySearch|100,000|~12 ns|0 B|
|LowerBoundSearch|1,000|~5 ns|0 B|
|LowerBoundSearch|100,000|~14 ns|0 B|
|LinearSearch|1,000|~200 ns|0 B|
|LinearSearch|100,000|~25,000 ns|0 B|

**Interpretation:** Binary search is allocation-free and extremely fast. The difference between built-in and scratch implementations is negligible (the JIT optimizes both to similar code). Linear search starts to lose at N ≈ 100 — binary search is always better for large sorted arrays.

---

## Interview Arsenal

### Question Bank

1. [Definition] What is binary search and what assumption does it make about the input?
2. [Complexity] Derive the O(log n) time complexity of binary search.
3. [Implementation] Implement binary search for an exact match in a sorted array.
4. [Recognition] Given a problem about "first bad version" or "peak element," what algorithm?
5. [Comparison] Compare lower bound vs. upper bound — when would you use each?
6. [Trick] Why is `low + (high - low) / 2` preferred over `(low + high) / 2`?
7. [System Design] How would you design an autocomplete feature using binary search?
8. [Optimization] How would you search in a sorted array that is too large to fit in memory?

### Spoken Answers

**Q: Derive the O(log n) time complexity of binary search.**

> **Average answer:** Each step halves the search space, so it takes log₂ n steps.

> **Great answer:** The search space starts at size n. After the first comparison, the remaining search space is at most n/2 (we discard the half that cannot contain the target). After the second comparison, at most n/4. After k comparisons, at most n/2^k. The loop terminates when the search space is empty (size ≤ 0), which requires n/2^k < 1, so 2^k > n, so k > log₂ n. Each iteration does O(1) work — a comparison and an arithmetic operation. So total time is O(log n). A subtle point: this is log₂ n, not just "log n" — but in big-O notation, the base doesn't matter because log₂ n = log₂ e × ln n, and constant factors are dropped. For an array of 1 billion elements, log₂ n ≈ 30 comparisons — versus up to 1 billion for linear search. The space is O(1) for the iterative version since we only store three integers.

**Q: Implement binary search for an exact match.**

> **Average answer:** Uses a while loop with low and high indices, checks the middle, adjusts bounds.

> **Great answer:** I will implement the iterative version. I initialize low = 0 and high = arr.Length - 1. The loop condition is `low <= high` — this ensures we check the case when the range narrows to a single element. Inside the loop, I compute `mid = low + (high - low) / 2` — note the use of `low + (high - low) / 2` instead of `(low + high) / 2` to avoid integer overflow. If arr[mid] equals the target, return mid. If arr[mid] < target, the target is in the right half, so set low = mid + 1. If arr[mid] > target, it is in the left half, set high = mid - 1. If the loop exits without finding the target, return -1. I would also mention the recursive implementation for completeness, but note that the iterative version is preferred in production because it uses O(1) space vs. O(log n) for the call stack.

**Q: [Trick] Why is `low + (high - low) / 2` preferred over `(low + high) / 2`?**

> **Average answer:** It avoids overflow when low + high is large.

> **Great answer:** In C#, `int` is a 32-bit signed integer with a maximum value of 2,147,483,647. For an array of size 1 billion or larger, `low + high` can exceed this limit and overflow to a negative number. The expression `low + (high - low) / 2` computes the same midpoint but the subtraction `high - low` is at most n (the array size), which fits in a 32-bit int for any practical array size. The division by 2 is performed on a value ≤ n, and then we add low. The largest intermediate value is `low + (high - low) / 2`, which is at most `high`. This expression is also correct when low and high are unsigned integers or long integers. In C#, `Array.MaxLength` is 2,147,483,591 (int.MaxValue - 56) for a single-dimension array — so low + high can indeed overflow if the array is near maximum size.

### Trick Question

**"You have a sorted array with one element missing. How do you find the missing element in O(log n)?"**

Why it is a trap: The candidate tries to use binary search directly but does not know when to move left or right. The trick is that a sorted array of length n-1 containing numbers 1..n with one missing can be found by comparing `arr[mid]` to `mid + 1` (expected value at that index). If they match, the missing element is in the right half; if they differ, it is in the left half (or at mid).

Correct answer: Use binary search on the index, not the value. If `arr[mid] == mid + 1` (the expected value), the missing element is to the right (low = mid + 1). If `arr[mid] > mid + 1` (or differs), the missing element is to the left (high = mid). The missing element is `low + 1` when the loop exits. Time: O(log n), Space: O(1).

### Pattern Recognition Table

|If the problem has...|Then consider...|Because...|
|---|---|---|
|Sorted array + target value|Binary search|Exploits sorted order to eliminate half the search space each step|
|"First occurrence" or "last occurrence"|Lower bound / upper bound|Binary search with modified comparison — do not return early on match|
|"Insertion point" in a sorted array|Lower bound|The first index where arr[index] ≥ target gives the correct insertion point|
|"Find the k-th smallest" in two sorted arrays|Binary search on k|Select the k-th element by comparing mid elements of both arrays|
|"Find the minimum in a rotated sorted array"|Binary search comparing mid with high|Compare arr[mid] with arr[high] — if mid > high, minimum is right; else left|
|"Find the peak element"|Binary search on slope direction|Compare arr[mid] with arr[mid + 1] — if mid < mid+1, peak is right; else left|

---

## Decision Framework

### When to Apply

```mermaid
flowchart TD
    A[Need to find an element or boundary in sorted data] --> B{Input is sorted?}
    B -->|Yes| C{Multiple queries on the same data?}
    B -->|No| D["Consider hash set (existence) or linear scan (position)"]
    C -->|Yes| E[Binary search is optimal — O(log n) per query]
    C -->|No| F{Single query, small n?}
    F -->|Yes| G[Linear search may be simpler and fast enough]
    F -->|No| H["Binary search — O(log n) < O(n)"]
    E --> I{Need first/last occurrence?}
    I -->|Yes| J[Use lower bound / upper bound variant]
    I -->|No| K[Use classic exact-match binary search]
```

### Recognition Checklist

Indicators that binary search is the right choice:

- [ ] Input is sorted (or can be sorted without loss of information)
- [ ] Need to find an exact value, first occurrence, or insertion point
- [ ] Input size is large enough that O(log n) matters over O(n)
- [ ] Problem involves a monotonic predicate (for binary search on answer)
- [ ] Need to search in a rotated sorted array or find a peak

Counter-indicators — do NOT apply here:

- [ ] Input is unsorted and cannot be sorted (use hash set or linear scan)
- [ ] Data is in a linked list (binary search on a linked list is still O(n))
- [ ] Need to find all occurrences (binary search gives first/last; range query is fine)
- [ ] Single query on a small array (< 20 elements) — linear search is simpler

### Tradeoff Summary

|What You Gain|What You Give Up|
|---|---|
|O(log n) search time — exponentially faster than O(n)|Requires sorted input — O(n log n) sorting cost upfront if data is not already sorted|
|O(1) space (iterative) — minimal memory|Only works on random-access sequences (arrays, not linked lists)|
|Simple, deterministic, easy to reason about|Need to get the boundary conditions exactly right — high bug rate|
|Easily generalizes to lower bound / upper bound / range queries|Cannot handle non-comparable data (must have a total order)|

---

## Self-Check

### Conceptual Questions

1. What is the loop invariant of classic binary search?
2. Derive the O(log n) time complexity from the number of comparisons.
3. Recognizing from a problem: "Given a sorted array of distinct integers and a target value, return the index if found, otherwise the index where it would be inserted."
4. When would you use lower bound vs. upper bound vs. exact match binary search?
5. What specific integer overflow does `low + (high - low) / 2` prevent?
6. In .NET, which built-in types provide binary search methods, and what does the return value mean when the target is not found?
7. What invariant does the lower bound variant maintain about the interval [low, high)?
8. How does the answer change if the array contains duplicates?
9. How would you modify binary search to work on a linked list?
10. What is the trap question about finding a missing element in a sorted array of 1..n?

<details>
<summary>Answers</summary>

1. If the target exists in the array, its index is in the range [low, high]. The invariant is maintained by narrowing the range after each comparison — discarding the half that cannot contain the target.
2. After each iteration, the remaining search space is at most half the previous size. After k iterations, the size is at most n / 2^k. The loop terminates when n / 2^k < 1, so k > log₂ n. Each iteration is O(1). Total: O(log n).
3. Use lower bound (first ≥ target). The lower bound returns the insertion point directly — if the element at that index equals the target, return it; otherwise return the index.
4. Exact match → arr[mid] == target returns immediately. Lower bound → arr[mid] < target advances low, else high = mid — used for first occurrence. Upper bound → arr[mid] <= target advances low, else high = mid — used for last occurrence (upper bound - 1).
5. `(low + high) / 2` overflows to a negative number when low + high > int.MaxValue (~2.1B). `low + (high - low) / 2` computes the same midpoint safely because the largest intermediate value is high - low, which is at most the array size.
6. `Array.BinarySearch<T>`, `List<T>.BinarySearch`, and `Span<T>.BinarySearch`. If not found, they return a negative number whose bitwise complement (~returnValue) gives the insertion point.
7. The interval [low, high) always contains the leftmost index where arr[index] ≥ target. The left bound is inclusive; the right bound is exclusive. The size of the interval decreases until it is empty (low == high), at which point low is the answer.
8. With duplicates, exact match returns any occurrence (not guaranteed to be the first). Use lower bound for the first occurrence and upper bound - 1 for the last occurrence. Count = upperBound - lowerBound.
9. Binary search requires random access — linked lists do not support O(1) index access. You cannot do true binary search on a linked list without converting to an array first (O(n) time and space).
10. For a sorted array of length n-1 containing numbers 1..n with one missing: compare arr[mid] with mid + 1. If they match, the missing element is in the right half; if arr[mid] > mid + 1, it is in the left half. The missing element is low + 1 after the loop.

</details>

---

### Coding Challenges

**Challenge 1 — Implement from scratch**

Implement `FirstBadVersion(int n)` where given an API `bool IsBadVersion(int version)`, find the first bad version in 1..n. All versions after the first bad version are also bad.

```csharp
public static int FirstBadVersion(int n)
{
    // Your implementation here (call IsBadVersion API)
}
```

<details> <summary>Solution</summary>

```csharp
public static int FirstBadVersion(int n)
{
    int low = 1, high = n;

    while (low < high)
    {
        int mid = low + (high - low) / 2;

        if (IsBadVersion(mid))
            high = mid; // mid could be the first bad version — keep it in range
        else
            low = mid + 1; // mid is good — first bad must be after mid
    }

    return low;
}
```

**Complexity:** Time O(log n) | Space O(1) **Key insight:** This is a lower-bound search on a boolean predicate that transitions from false to true exactly once. The predicate `IsBadVersion(mid)` is the comparison; when true, we set high = mid (keep mid), when false, low = mid + 1 (exclude mid).

</details>

---

**Challenge 2 — Trace the execution**

Trace binary search for target = 7 on the array [1, 2, 3, 4, 5, 6, 8, 9, 10]. Show low, high, and mid at each step.

<details> <summary>Solution</summary>

Array: [1, 2, 3, 4, 5, 6, 8, 9, 10], n = 9, target = 7

Step 1: low=0, high=8, mid=4 (value 5). 5 < 7 → low = 5.
Step 2: low=5, high=8, mid=6 (value 8). 8 > 7 → high = 5.
Step 3: low=5, high=5, mid=5 (value 6). 6 < 7 → low = 6.
Step 4: low=6, high=5 → loop exits (low > high).
Return -1 (target not found).

**Why:** Binary search correctly determines that 7 is not present. The search narrows to the range around where 7 would be (between 6 and 8), confirms it is not there, and returns -1.

</details>

---

**Challenge 3 — Fix the bug**

```csharp
// This implementation of lower bound has a bug. What input causes it to fail?
public static int LowerBound(int[] arr, int target)
{
    int low = 0, high = arr.Length - 1;

    while (low < high)
    {
        int mid = low + (high - low) / 2;

        if (arr[mid] < target)
            low = mid + 1;
        else
            high = mid;
    }

    return low;
}
```

<details> <summary>Solution</summary>

**Bug:** When `target > arr[^1]` (the last element), the search converges to `low = arr.Length - 1` instead of `arr.Length`. The lower bound for a target greater than all elements should be `arr.Length` (one past the end) — but with `high` initialized to `arr.Length - 1`, it can never equal `arr.Length`.

**Fix:**

```csharp
public static int LowerBound(int[] arr, int target)
{
    int low = 0, high = arr.Length; // FIXED: high = length, not length - 1

    while (low < high)
    {
        int mid = low + (high - low) / 2;

        if (arr[mid] < target)
            low = mid + 1;
        else
            high = mid;
    }

    return low;
}
```

**Test case that exposes it:** `LowerBound([1, 3, 5], 6)` → buggy returns 2, correct is 3. The insertion point for 6 is index 3 (after the last element); the buggy version returns index 2 (the last element).

</details>

---

**Challenge 4 — Recognize and apply**

**Problem:** Given an array of integers sorted in ascending order and a target value, find the starting and ending position of the target value. If the target is not found, return [-1, -1]. For example, nums = [5, 7, 7, 8, 8, 10], target = 8 → return [3, 4].

<details> <summary>Solution</summary>

**Pattern:** Lower bound for the first occurrence, upper bound - 1 for the last occurrence. If the lower bound is out of range or does not contain the target, return [-1, -1].

```csharp
public static int[] SearchRange(int[] nums, int target)
{
    int first = LowerBound(nums, target);

    if (first >= nums.Length || nums[first] != target)
        return [-1, -1];

    int last = UpperBound(nums, target) - 1;
    return [first, last];
}

private static int LowerBound(int[] arr, int target)
{
    int low = 0, high = arr.Length;
    while (low < high)
    {
        int mid = low + (high - low) / 2;
        if (arr[mid] < target) low = mid + 1;
        else high = mid;
    }
    return low;
}

private static int UpperBound(int[] arr, int target)
{
    int low = 0, high = arr.Length;
    while (low < high)
    {
        int mid = low + (high - low) / 2;
        if (arr[mid] <= target) low = mid + 1;
        else high = mid;
    }
    return low;
}
```

**Complexity:** Time O(log n) — two binary searches | Space O(1)

</details>

---

**Challenge 5 — Optimize**

```csharp
// This solution finds a target in a sorted array using linear search.
// Optimize it to O(log n) using binary search.
public static int Search(int[] nums, int target)
{
    for (int i = 0; i < nums.Length; i++)
        if (nums[i] == target) return i;
    return -1;
}
```

<details> <summary>Solution</summary>

**Insight:** The array is sorted. Use binary search to eliminate half the search space each iteration.

```csharp
public static int Search(int[] nums, int target)
{
    int low = 0, high = nums.Length - 1;

    while (low <= high)
    {
        int mid = low + (high - low) / 2;

        if (nums[mid] == target) return mid;
        if (nums[mid] < target) low = mid + 1;
        else high = mid - 1;
    }

    return -1;
}
```

**Complexity:** Time O(log n) | Space O(1)

</details>
