# Prefix Sum

> A precomputation technique that builds a cumulative sum array so that any subarray sum can be answered in O(1) — converting O(n) range queries into O(1) after O(n) preprocessing.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Cumulative sum array enabling O(1) range sum queries |
| **Use when** | Multiple range sum queries on an immutable array; subarray sum = k |
| **Avoid when** | Array is mutable (use Fenwick tree / segment tree instead) |
| **C# version** | C# 1.0+ (pure array arithmetic) |
| **Namespace** | None — pure algorithmic pattern on `int[]` or `long[]` |
| **Key types** | `int[] prefix` where `prefix[i]` = sum of `nums[0..i-1]` |

---

## When To Use It

Use prefix sum when you need to answer multiple range sum queries on an immutable array, or when you need to find subarrays whose sum equals a target value. The signal is: "given n queries of the form 'sum of nums[l..r]'" — building a prefix array turns each query from O(n) to O(1) after an O(n) build step. Also the right tool for "subarray sum equals k" (hash map + prefix sum), which sliding window can't handle because elements can be negative.

Don't use it for mutable arrays — each update would require rebuilding the prefix array in O(n). Use a Fenwick tree (O(log n) update and query) or segment tree instead.

---

## Core Concept

Define `prefix[i]` as the sum of `nums[0]` through `nums[i-1]` (using 1-based indexing to simplify boundary conditions). Then `prefix[0] = 0` and `prefix[i] = prefix[i-1] + nums[i-1]`. The sum of any subarray `nums[l..r]` (inclusive, 0-indexed) is `prefix[r+1] - prefix[l]`.

This works because `prefix[r+1] - prefix[l]` = (sum of nums[0..r]) - (sum of nums[0..l-1]) = sum of nums[l..r]. The subtraction cancels the prefix that both ranges share.

For "subarray sum equals k": transform the problem — we need indices i, j where `prefix[j] - prefix[i] = k`, i.e., `prefix[i] = prefix[j] - k`. Use a hash map to store how many times each prefix sum value has appeared so far. As you walk right, each new `prefix[j]` checks if `prefix[j] - k` was seen before.

---

## Algorithm History

| Era | Development |
|---|---|
| 1960s | Prefix sums used in numerical methods and signal processing |
| 1970s | Formalized in algorithm textbooks as "partial sums" |
| 1994 | Peter Fenwick publishes Fenwick tree — efficient prefix sum with updates |
| 2000s | "Subarray sum equals k" with hash map becomes a standard interview problem |
| 2010s | 2D prefix sum popularised for matrix range sum queries |

---

## Performance

| Operation | Time | Space | Notes |
|---|---|---|---|
| Build prefix array | O(n) | O(n) | One pass through nums |
| Range sum query [l, r] | O(1) | O(1) | prefix[r+1] - prefix[l] |
| Subarray sum = k (count) | O(n) | O(n) | Hash map of prefix sum → count |
| 2D prefix sum build | O(m × n) | O(m × n) | |
| 2D range sum query | O(1) | O(1) | Inclusion-exclusion on 4 corners |
| Update + query (mutable) | O(log n) | O(n) | Use Fenwick tree instead |

**Allocation behaviour:** One `int[]` or `long[]` of length n+1 for the prefix array. For the subarray-sum-equals-k problem, a `Dictionary<int, int>` of up to n entries. No per-query allocation.

**Benchmark notes:** For a single query, prefix sum's O(n) build dominates — just iterate. For 2+ queries, prefix sum wins. For k queries: naive is O(nk), prefix sum is O(n + k). The break-even is around k = 2.

---

## The Code

**Scenario 1 — range sum queries on an immutable array**
```csharp
public class RangeSumQuery
{
    private readonly int[] _prefix;

    public RangeSumQuery(int[] nums)
    {
        _prefix = new int[nums.Length + 1]; // 1-indexed: prefix[0] = 0
        for (int i = 0; i < nums.Length; i++)
            _prefix[i + 1] = _prefix[i] + nums[i];
    }

    // Returns sum of nums[left..right] inclusive, 0-indexed
    public int Query(int left, int right) => _prefix[right + 1] - _prefix[left];
}
```

**Scenario 2 — subarray sum equals k (count all subarrays)**
```csharp
public static int SubarraySum(int[] nums, int k)
{
    // prefix[j] - prefix[i] = k  ↔  prefix[i] = prefix[j] - k
    // Hash map: how many times has each prefix sum value been seen so far?
    var freq = new Dictionary<int, int> { [0] = 1 }; // prefix[0] = 0 seen once
    int prefixSum = 0, count = 0;

    foreach (int num in nums)
    {
        prefixSum += num;
        int complement = prefixSum - k;
        if (freq.TryGetValue(complement, out int times))
            count += times; // each prior occurrence of (prefixSum - k) is a valid left bound
        freq[prefixSum] = freq.GetValueOrDefault(prefixSum) + 1;
    }
    return count;
}
```

**Scenario 3 — 2D prefix sum (range sum on a matrix)**
```csharp
public class MatrixRangeSumQuery
{
    private readonly int[,] _prefix;

    public MatrixRangeSumQuery(int[][] matrix)
    {
        int m = matrix.Length, n = matrix[0].Length;
        _prefix = new int[m + 1, n + 1];

        for (int r = 1; r <= m; r++)
            for (int c = 1; c <= n; c++)
                _prefix[r, c] = matrix[r-1][c-1]
                    + _prefix[r-1, c]
                    + _prefix[r, c-1]
                    - _prefix[r-1, c-1]; // inclusion-exclusion to avoid double-counting
    }

    // Sum of matrix[r1..r2][c1..c2] inclusive, 0-indexed
    public int Query(int r1, int c1, int r2, int c2)
    {
        return _prefix[r2+1, c2+1]
             - _prefix[r1,   c2+1]
             - _prefix[r2+1, c1  ]
             + _prefix[r1,   c1  ]; // add back the doubly-subtracted corner
    }
}
```

**Scenario 4 — what NOT to do: iterating on every query**
```csharp
// BAD: O(n) per query — O(nk) for k queries
public static int RangeSumBad(int[] nums, int left, int right)
{
    int sum = 0;
    for (int i = left; i <= right; i++) // scans the range on every call
        sum += nums[i];
    return sum;
}

// GOOD: O(1) per query after O(n) build — O(n + k) for k queries
public static int[] BuildPrefix(int[] nums)
{
    var prefix = new int[nums.Length + 1];
    for (int i = 0; i < nums.Length; i++)
        prefix[i + 1] = prefix[i] + nums[i];
    return prefix;
}

public static int RangeSumGood(int[] prefix, int left, int right)
    => prefix[right + 1] - prefix[left]; // O(1)
```

---

## Real World Example

The `SalesAnalyticsService` in a business intelligence platform answers hundreds of daily queries of the form "total revenue between date A and date B." Revenue data is historical (immutable) and loaded once per day. Without prefix sums, each query iterates up to 365 days of daily revenue — 500 queries × 365 days = 182,500 iterations. With prefix sums, all 500 queries run in microseconds after a 365-step build.

```csharp
public class SalesAnalyticsService
{
    private readonly long[] _dailyRevenue;  // indexed by day-of-year (0-based)
    private readonly long[] _prefixRevenue; // prefix[i] = total revenue for days 0..i-1
    private readonly DateOnly _startDate;

    public SalesAnalyticsService(DateOnly startDate, long[] dailyRevenueSeries)
    {
        _startDate   = startDate;
        _dailyRevenue = dailyRevenueSeries;

        _prefixRevenue = new long[dailyRevenueSeries.Length + 1];
        for (int i = 0; i < dailyRevenueSeries.Length; i++)
            _prefixRevenue[i + 1] = _prefixRevenue[i] + dailyRevenueSeries[i];
    }

    // O(1) — total revenue between fromDate and toDate inclusive
    public long TotalRevenue(DateOnly fromDate, DateOnly toDate)
    {
        int left  = fromDate.DayNumber - _startDate.DayNumber;
        int right = toDate.DayNumber   - _startDate.DayNumber;

        if (left < 0 || right >= _dailyRevenue.Length || left > right)
            throw new ArgumentOutOfRangeException("Date range out of data bounds.");

        return _prefixRevenue[right + 1] - _prefixRevenue[left];
    }

    // O(n) — find the longest streak of days where cumulative revenue ≥ target
    // Uses prefix sum + binary search on the prefix array
    public int LongestRevenueStreak(long targetRevenue)
    {
        int best = 0;
        for (int right = 0; right < _dailyRevenue.Length; right++)
        {
            // Binary search for the smallest left such that prefix[right+1] - prefix[left] >= target
            int lo = 0, hi = right;
            while (lo <= hi)
            {
                int mid = (lo + hi) / 2;
                long rangeSum = _prefixRevenue[right + 1] - _prefixRevenue[mid];
                if (rangeSum >= targetRevenue) { best = Math.Max(best, right - mid + 1); lo = mid + 1; }
                else                           hi = mid - 1;
            }
        }
        return best;
    }
}
```

*The key insight: `long` instead of `int` for the prefix array — daily revenues can be large and the cumulative sum over a year can exceed `int.MaxValue` (~2.1 billion). Overflowing silently gives wrong query results. For financial data, always use `long` or `decimal` for prefix sums.*

---

## Common Misconceptions

**"Prefix sum only works for sum queries — not useful for other aggregations"**
The pattern generalizes to any associative operation with an inverse: prefix XOR for range XOR queries, prefix product (with modular inverse) for range product queries. The key requirement is that you can "undo" the prefix operation for a range.

**"I need prefix[0] = nums[0]"**
The standard is `prefix[0] = 0` and `prefix[i] = prefix[i-1] + nums[i-1]` (1-indexed). This avoids special-casing the left boundary — `prefix[r+1] - prefix[l]` works uniformly for all l including l=0. Setting `prefix[0] = nums[0]` forces you to special-case the case where l=0.

**"Prefix sum handles mutable arrays"**
No. Every update to `nums[i]` requires updating `prefix[i]` through `prefix[n]` — O(n) per update. For mutable arrays, use a Fenwick tree (O(log n) update, O(log n) prefix query) or a segment tree (O(log n) update, O(log n) range query).

---

## Gotchas

- **Off-by-one in the indexing convention.** The standard 1-indexed convention (`prefix[0] = 0`, `prefix[i] = prefix[i-1] + nums[i-1]`) lets you query `prefix[right + 1] - prefix[left]` without special cases. Mixing 0-indexed and 1-indexed conventions is the #1 prefix sum bug.

- **Integer overflow on large arrays.** Prefix sums accumulate — if `nums` contains values up to `10^9` and length up to `10^5`, the prefix sum can reach `10^14`, well beyond `int.MaxValue`. Use `long[]` for the prefix array when element values or array sizes are large.

- **Initialise `freq[0] = 1` for subarray sum = k.** The empty prefix (sum = 0) counts as a valid starting point. Without it, subarrays starting at index 0 are never counted — a silent bug that only manifests when the answer includes subarrays that start at the beginning of the array.

- **The 2D prefix sum inclusion-exclusion.** The formula `prefix[r,c] = matrix[r-1][c-1] + prefix[r-1,c] + prefix[r,c-1] - prefix[r-1,c-1]` subtracts the doubly-counted top-left rectangle. Getting the query formula wrong (`prefix[r2+1,c2+1] - prefix[r1,c2+1] - prefix[r2+1,c1] + prefix[r1,c1]`) is the most common 2D prefix sum bug.

- **Prefix sum requires the array to be fixed at query time.** If the problem has updates interleaved with queries, prefix sum gives stale results. Rebuild the array after each update (O(n)) — or switch to a Fenwick tree.

---

## Interview Angle

**What they're really testing:** Whether you recognise that multiple range queries on a static array are a preprocessing problem, and whether you know the hash-map + prefix-sum pattern for "subarray sum equals k."

**Common question forms:**
- "Range sum query — immutable."
- "Subarray sum equals k (count all)."
- "Number of subarrays with sum divisible by k."
- "Find pivot index (left sum equals right sum)."
- "Range sum query 2D — immutable."
- "Product of array except self (prefix + suffix product)."

**The depth signal:** A junior answers a single range query with a loop. A senior builds a prefix array for multiple queries, explains why `prefix[0] = 0` prevents special cases, and knows the hash-map + prefix-sum pattern for "subarray sum = k" — including the crucial `freq[0] = 1` initialisation and why sliding window doesn't work for this problem (negative numbers). The 2D prefix sum with correct inclusion-exclusion is the senior-level extension.

**Follow-up questions to expect:**
- "What if the array is mutable?" → Fenwick tree (O(log n) per update and query).
- "Why doesn't sliding window work for subarray sum = k with negatives?" → Sliding window's shrink logic assumes removing the left element reduces the sum — false for negatives. Prefix sum + hash map handles arbitrary elements.

---

## Related Topics

- [[algorithms/patterns/sliding-window.md]] — The alternative for subarray problems with non-negative elements; O(1) space but doesn't handle negatives or "exactly k" counting directly.
- [[algorithms/datastructures/segment-tree.md]] — For mutable arrays requiring range queries — O(log n) per update and query.
- [[algorithms/patterns/dynamic-programming.md]] — Prefix sum is sometimes the "state" in DP (e.g., maximum sum subarray via prefix min tracking).

---

## Source

https://en.wikipedia.org/wiki/Prefix_sum

---

*Last updated: 2026-04-21*