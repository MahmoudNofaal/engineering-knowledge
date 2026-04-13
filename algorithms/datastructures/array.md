# Array

> A fixed-size, ordered collection of elements stored in contiguous memory, accessible by index in O(1).

---

## Quick Reference

| | |
|---|---|
| **What it is** | Contiguous memory block, index access |
| **Use when** | Ordered data, frequent index reads |
| **Avoid when** | Frequent mid-sequence inserts/deletes |
| **C# version** | C# 1.0 (arrays) / C# 2.0 (`List<T>`) |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `T[]`, `List<T>`, `Span<T>`, `ArraySegment<T>` |

---

## When To Use It

Use an array when you need fast index-based access and your data size is known or bounded. It's the default structure for ordered data and the foundation almost every other data structure is built on top of. Avoid it when you need frequent insertions or deletions in the middle — shifting elements is O(n) and compounds badly in loops. When size is unpredictable but you still need indexing, use `List<T>` (a dynamic array) rather than a raw array — you get amortised O(1) appends without sacrificing O(1) reads.

---

## Core Concept

An array maps directly to a block of memory. Element 0 starts at the base address; element k is at `base + (k × element_size)`. That's why index access is O(1) — it's a single arithmetic operation, not a search. The CPU can compute any address instantly because all elements are the same size and live next to each other.

The trade-off is rigidity around mutation. Inserting anywhere except the end requires shifting every subsequent element right by one slot — O(n) work. Dynamic arrays (`List<T>`) hide this by over-allocating capacity and copying into a larger buffer when full. The amortised cost of append stays O(1) because doublings are rare, but you pay for them silently. The other major advantage arrays have over linked structures is cache locality: because elements are contiguous, the CPU prefetcher loads them in bulk. Iterating an array is measurably faster than iterating a linked list of the same length, even if Big-O is identical.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Raw arrays (`T[]`), fixed-size, zero-based indexing |
| C# 2.0 | .NET 2.0 | `List<T>` introduced — generic dynamic array replaces `ArrayList` |
| C# 7.2 | .NET Core 2.1 | `Span<T>` and `Memory<T>` — zero-copy slicing over array memory |
| C# 8.0 | .NET Core 3.0 | Index (`^`) and Range (`..`) operators — `arr[^1]`, `arr[1..4]` |
| C# 9.0 | .NET 5 | `ImmutableArray<T>` promoted; init-only setters on array wrappers |
| C# 12.0 | .NET 8 | Collection expressions `[1, 2, 3]` unify array and list literals |

*Before C# 7.2, slicing an array always allocated a new copy. `Span<T>` changed this — a slice is now a view into the original buffer with no allocation.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Index read/write | O(1) | Direct address arithmetic — always constant |
| Append (List<T>) | O(1) amortised | Occasional O(n) resize doubling |
| Insert at position | O(n) | All elements after index shift right |
| Delete at position | O(n) | All elements after index shift left |
| Search (unsorted) | O(n) | Linear scan — no index to help |
| Search (sorted) | O(log n) | Binary search via `Array.BinarySearch` |
| Copy / slice | O(k) | k = number of elements copied |

**Allocation behaviour:** `T[]` allocates on the managed heap. Small arrays (< 85 KB) go on the regular heap; large arrays go on the Large Object Heap (LOH) and are never compacted, which can cause fragmentation. `Span<T>` and `stackalloc` can keep small arrays on the stack entirely — zero GC pressure.

**Benchmark notes:** Under ~1,000 elements the performance difference between an array and a `List<T>` is negligible in real code. Cache effects only become measurable above ~10,000 elements where linked structures start missing the L1/L2 cache. For hot inner loops over large datasets, prefer `T[]` or `Span<T>` over `List<T>` — the internal bounds-check on `List<T>` indexing adds a small but non-zero overhead the JIT can't always eliminate.

---

## The Code

**Basic operations — raw array and List<T>**
```csharp
// Raw fixed-size array
int[] arr = new int[] { 10, 20, 30, 40, 50 };
Console.WriteLine(arr[2]);         // 30 — O(1)
Console.WriteLine(arr.Length);     // 5

// Index and Range operators (C# 8+)
Console.WriteLine(arr[^1]);        // 50 — last element
int[] slice = arr[1..4];           // [20, 30, 40] — new array (copy)

// Dynamic array — List<T>
var list = new List<int> { 10, 20, 30 };
list.Add(40);                      // O(1) amortised
list.Insert(1, 99);                // O(n) — shifts everything after index 1
list.RemoveAt(1);                  // O(n) — shifts everything after index 1
bool found = list.Contains(30);    // O(n) linear scan
list.Sort();                       // O(n log n) in-place
```

**Sliding window — O(n) instead of O(n²)**
```csharp
// Find maximum sum of any subarray of length k
public static int MaxSumSubarray(int[] nums, int k)
{
    if (nums.Length < k) return 0;

    int window = 0;
    for (int i = 0; i < k; i++)
        window += nums[i];

    int best = window;
    for (int i = k; i < nums.Length; i++)
    {
        window += nums[i] - nums[i - k];   // slide: add right, drop left
        best = Math.Max(best, window);
    }
    return best;
}
// MaxSumSubarray([2,1,5,1,3,2], 3) → 9  (5+1+3)
```

**Two-pointer — O(n) pair search on a sorted array**
```csharp
// Return indices of two numbers that sum to target
public static (int, int) TwoSumSorted(int[] nums, int target)
{
    int lo = 0, hi = nums.Length - 1;
    while (lo < hi)
    {
        int sum = nums[lo] + nums[hi];
        if (sum == target) return (lo, hi);
        if (sum < target) lo++;
        else              hi--;
    }
    return (-1, -1);
}
```

**What NOT to do — and the fix**
```csharp
// BAD: searching for a complement inside a loop — O(n²)
public static bool HasPairBad(int[] nums, int target)
{
    for (int i = 0; i < nums.Length; i++)
        for (int j = i + 1; j < nums.Length; j++)
            if (nums[i] + nums[j] == target)
                return true;
    return false;
}

// GOOD: use a hash set — O(n) time, O(n) space
public static bool HasPairGood(int[] nums, int target)
{
    var seen = new HashSet<int>();
    foreach (int n in nums)
    {
        if (seen.Contains(target - n)) return true;
        seen.Add(n);
    }
    return false;
}
```

---

## Real World Example

An e-commerce platform needs to display a dashboard showing each product's 7-day rolling average sales volume. The raw data comes in as a flat daily-sales array per product. Re-summing the window from scratch for every day would be O(n × k) per product — unacceptable at scale. A prefix-sum array built once in O(n) lets each range query answer in O(1), and a sliding window computes the rolling metric in a single pass.

```csharp
public class SalesDashboard
{
    // Build a prefix-sum array so any range sum is O(1)
    private static int[] BuildPrefixSums(int[] dailySales)
    {
        var prefix = new int[dailySales.Length + 1];   // prefix[0] = 0 sentinel
        for (int i = 0; i < dailySales.Length; i++)
            prefix[i + 1] = prefix[i] + dailySales[i];
        return prefix;
    }

    // Range sum [l..r] inclusive in O(1)
    private static int RangeSum(int[] prefix, int l, int r)
        => prefix[r + 1] - prefix[l];

    // Compute 7-day rolling averages for a product's sales history
    public static double[] SevenDayRollingAverage(int[] dailySales)
    {
        const int window = 7;
        if (dailySales.Length < window)
            throw new ArgumentException("Need at least 7 days of data.");

        int[] prefix  = BuildPrefixSums(dailySales);
        int resultLen = dailySales.Length - window + 1;
        var averages  = new double[resultLen];

        for (int i = 0; i < resultLen; i++)
        {
            int sum = RangeSum(prefix, i, i + window - 1);
            averages[i] = (double)sum / window;
        }

        return averages;
    }
}

// Usage
int[] sales = { 12, 8, 15, 20, 5, 18, 22, 9, 14, 30 };
double[] rolling = SalesDashboard.SevenDayRollingAverage(sales);
// rolling[0] = avg of days 0–6 = (12+8+15+20+5+18+22)/7 = 14.28
// rolling[1] = avg of days 1–7 = (8+15+20+5+18+22+9)/7  = 13.86
```

*The key insight here is the prefix-sum trick: store cumulative totals once, then answer any window query with two array reads and a subtraction — no re-summing, no inner loop.*

---

## Common Misconceptions

**"List<T> is slower than T[] for reads, so I should always use raw arrays"**
In practice the JIT optimises `List<T>` index access heavily and the difference is single-digit nanoseconds on modern hardware. Only reach for `T[]` directly when profiling proves it matters — in a hot loop over millions of elements, for example. For everyday application code the ergonomics of `List<T>` (Add, Remove, Count) outweigh the micro-optimisation.

**"Slicing an array with `arr[1..4]` gives me a view, not a copy"**
In C#, the range operator on a `T[]` produces a new array — a copy. Only `Span<T>` and `Memory<T>` give you true zero-allocation views. If you're slicing frequently inside a hot path, switch to `span.Slice(1, 3)` to avoid allocations.

```csharp
int[] arr  = { 1, 2, 3, 4, 5 };
int[] copy = arr[1..4];          // new allocation — modifying copy doesn't affect arr
Span<int> view = arr.AsSpan(1, 3); // zero allocation — view into the same memory
view[0] = 99;                    // arr[1] is now 99
```

**"Arrays are always faster than lists because they're simpler"**
Arrays have better cache locality during iteration and zero overhead on indexed reads, but inserting at the front of an array is O(n) while a `LinkedList<T>` can do it in O(1). "Faster" depends entirely on the access pattern. Arrays win on read-heavy sequential workloads; they lose on frequent mid-sequence mutation.

---

## Gotchas

- **Off-by-one errors are the most common bug.** Range operators in C# are exclusive at the end: `arr[1..4]` returns elements at indices 1, 2, 3 — not 4. Always verify boundary conditions on slices and loop limits. A classic: `for (int i = 0; i <= arr.Length; i++)` will throw on `arr[i]` at the last iteration.

- **`Array.BinarySearch` requires a sorted array — silently wrong otherwise.** If the array isn't sorted, `BinarySearch` returns a meaningless value with no exception. Sort first, or check the precondition explicitly.

- **Modifying a collection while iterating it throws.** Doing `list.RemoveAt(i)` inside a `foreach` over that list throws `InvalidOperationException`. Either iterate backwards with an index loop, collect indices to remove first, or use `list.RemoveAll(predicate)`.

- **The Large Object Heap affects arrays over ~85 KB.** Arrays of reference types or large value types that exceed this threshold land on the LOH, which is collected infrequently and never compacted. Frequent creation of large arrays in a tight loop causes fragmentation and GC pauses. Pre-allocate and reuse, or use `ArrayPool<T>.Shared.Rent()`.

- **2D arrays and jagged arrays behave differently.** `int[,]` is a true rectangular 2D block (one allocation, row-major layout). `int[][]` is an array of references to independent row arrays (multiple allocations). The rectangular form has better cache performance for full-row access but awkward syntax; jagged arrays have more flexible row lengths. Mixing them up causes `IndexOutOfRangeException` or incorrect indexing math.

- **Prefix sums are underused.** Any time you need repeated range sums on a static array, build a prefix-sum array once in O(n) and answer every query in O(1). Most candidates reach for the sliding window pattern without realising prefix sums generalise it to arbitrary (not fixed-width) ranges.

---

## Interview Angle

**What they're really testing:** Whether you recognise that most "search inside a loop" problems can be reduced from O(n²) to O(n) using a hash map, sorting, two pointers, or prefix sums — and whether you ask the right question first: "Is this array sorted? Can I sort it?"

**Common question forms:**
- "Find two numbers in this array that sum to target"
- "Find the maximum sum subarray of length k"
- "Find the longest subarray where [condition]"
- "Given a list of intervals, merge overlapping ones"

**The depth signal:** A junior loops and checks — O(n²). A senior asks: "Is it sorted? Can I use a hash map to trade space for time? Is this a sliding window?" and restructures to a single pass. The next level: a senior brings up prefix sums unprompted when the problem involves multiple range queries, and knows that `Span<T>` avoids allocation on slice-heavy paths — two signals that separate strong candidates from exceptional ones.

**Follow-up questions to expect:**
- "What if the array doesn't fit in memory?" (External sort, chunked processing)
- "What if elements can be negative?" (Kadane's algorithm for max subarray — the sliding window assumption breaks)
- "How would you make this thread-safe?" (`ImmutableArray<T>`, `Interlocked`, copy-on-write)

---

## Related Topics

- [[algorithms/patterns/sliding-window.md]] — Core pattern built on array index arithmetic; the main technique for fixed-width window problems.
- [[algorithms/patterns/two-pointers.md]] — Requires a sorted array as precondition; reduces O(n²) pair searches to O(n).
- [[algorithms/datastructures/hash-table.md]] — Almost always paired with arrays to convert O(n) scans into O(1) lookups.
- [[algorithms/datastructures/segment-tree.md]] — When the array is mutable and range queries are frequent, a segment tree replaces the prefix-sum approach.
- [[dotnet/csharp/csharp-span-memory.md]] — Zero-allocation slicing over arrays; essential for performance-sensitive paths.

---

## Source

https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/arrays

---

*Last updated: 2026-04-12*