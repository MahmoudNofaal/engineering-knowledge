# Binary Search

> A search algorithm that finds a target in a sorted array by repeatedly halving the search space — O(log n).

---

## Quick Reference

| | |
|---|---|
| **What it is** | Halve search space each step using sorted order |
| **Use when** | Sorted array lookup; "find minimum X where condition(X) is true" |
| **Avoid when** | Unsorted data; linked lists (no O(1) index access) |
| **C# version** | `Array.BinarySearch` since C# 1.0; manual implementation common in interviews |
| **Namespace** | `System` for `Array.BinarySearch`; `System.Collections.Generic` for `List<T>.BinarySearch` |
| **Key types** | `int lo`, `int hi`, `int mid`; `Array.BinarySearch<T>()` |

---

## When To Use It

Use binary search any time your input is sorted and you need to find a value, a boundary, or a condition. The pattern generalises far beyond exact lookup — "find the leftmost position where condition X becomes true" is binary search on an answer space. If you catch yourself scanning a sorted structure linearly, binary search probably applies. Don't use it on unsorted data — the result is simply wrong, not just slow.

---

## Core Concept

Binary search maintains a window `[lo, hi]` that contains the answer. Each iteration, check the midpoint. If it's too small, discard the left half. If it's too big, discard the right half. Each step halves the window — after log n steps the window is empty or contains exactly the answer.

The hard part isn't the idea — it's the boundary conditions. Off-by-one errors are the most common bug. Three variants:
- **Exact match**: `while (lo <= hi)`, return mid when found.
- **Lower bound** (leftmost position ≥ target): `while (lo < hi)`, `hi = len` not `len-1`.
- **Condition search**: find smallest x where `condition(x)` is true — binary search on an answer space, not an array.

---

## Algorithm History

| Year | Development |
|---|---|
| 1946 | John Mauchly describes binary search informally |
| 1960 | First published correct binary search implementation (D.H. Lehmer) |
| 1962 | First implementation without bugs in a textbook (after 14 years of buggy versions) |
| 1986 | Jon Bentley's "Programming Pearls" popularises binary search as an interview benchmark |
| 2006 | Joshua Bloch publishes famous blog post showing Java's `Arrays.binarySearch` had an overflow bug for 9 years (`lo + hi` overflows; fix is `lo + (hi - lo) / 2`) |

---

## Performance

| Variant | Time | Space | Notes |
|---|---|---|---|
| Exact match | O(log n) | O(1) | Returns -1 if not found |
| Lower bound | O(log n) | O(1) | Returns insertion point |
| Upper bound | O(log n) | O(1) | Returns first index > target |
| Answer-space search | O(log(range) × f(n)) | O(1) | f(n) = cost of condition check |

**Allocation behaviour:** Zero. Binary search operates on existing indices with a fixed set of local variables.

**Benchmark notes:** At n = 10^9, binary search takes at most 30 iterations. At n = 10^18, at most 60. For any n that fits in memory, binary search completes in under 100 iterations. The log growth is so slow it's practically free.

---

## The Code

**Scenario 1 — exact match**
```csharp
public static int BinarySearch(int[] nums, int target)
{
    int lo = 0, hi = nums.Length - 1;
    while (lo <= hi)                        // = because single element [lo==hi] is valid
    {
        int mid = lo + (hi - lo) / 2;       // avoids int overflow vs (lo + hi) / 2
        if (nums[mid] == target)  return mid;
        if (nums[mid] < target)   lo = mid + 1;
        else                      hi = mid - 1;
    }
    return -1;
}
```

**Scenario 2 — lower bound (leftmost position ≥ target)**
```csharp
public static int LowerBound(int[] nums, int target)
{
    int lo = 0, hi = nums.Length;          // hi = len (exclusive upper bound)
    while (lo < hi)                         // strict < because hi is exclusive
    {
        int mid = lo + (hi - lo) / 2;
        if (nums[mid] < target) lo = mid + 1;
        else                    hi = mid;   // mid might be the answer — don't exclude it
    }
    return lo;                              // lo == hi: the leftmost valid position
}

// Upper bound: leftmost position > target
public static int UpperBound(int[] nums, int target)
{
    int lo = 0, hi = nums.Length;
    while (lo < hi)
    {
        int mid = lo + (hi - lo) / 2;
        if (nums[mid] <= target) lo = mid + 1; // only difference: <= instead of <
        else                     hi = mid;
    }
    return lo;
}
```

**Scenario 3 — binary search on answer space**
```csharp
// "Find minimum capacity such that all weights can be shipped in D days"
public static int ShipWithinDays(int[] weights, int days)
{
    bool CanShip(int capacity)
    {
        int currentLoad = 0, daysNeeded = 1;
        foreach (int w in weights)
        {
            if (currentLoad + w > capacity) { daysNeeded++; currentLoad = 0; }
            currentLoad += w;
        }
        return daysNeeded <= days;
    }

    int lo = weights.Max();     // minimum capacity: must hold the heaviest item
    int hi = weights.Sum();     // maximum capacity: ship everything in one day
    while (lo < hi)
    {
        int mid = lo + (hi - lo) / 2;
        if (CanShip(mid)) hi = mid;   // mid works — try smaller
        else              lo = mid + 1; // mid too small — try larger
    }
    return lo;
}
```

**Scenario 4 — what NOT to do: overflow in midpoint calculation**
```csharp
// BAD: (lo + hi) can overflow int.MaxValue when both are large
public static int BinarySearchBad(int[] nums, int target)
{
    int lo = 0, hi = nums.Length - 1;
    while (lo <= hi)
    {
        int mid = (lo + hi) / 2;   // BUG: lo=1_000_000_000, hi=1_500_000_000 → overflow
        if (nums[mid] == target) return mid;
        if (nums[mid] < target)  lo = mid + 1;
        else                     hi = mid - 1;
    }
    return -1;
}

// GOOD: lo + (hi - lo) / 2 never overflows because (hi - lo) ≤ INT_MAX
public static int BinarySearchGood(int[] nums, int target)
{
    int lo = 0, hi = nums.Length - 1;
    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2; // safe
        if (nums[mid] == target) return mid;
        if (nums[mid] < target)  lo = mid + 1;
        else                     hi = mid - 1;
    }
    return -1;
}
```

---

## Real World Example

The `CapacityPlannerService` at a cloud provider determines the minimum server count needed to handle a projected request load within an SLA. The search space is the number of servers (1 to MaxServers). The condition: can this many servers handle the load within the latency SLA? The condition check is a simulation (O(n)). Binary search reduces the trials from O(MaxServers) to O(log MaxServers).

```csharp
public class CapacityPlannerService
{
    private readonly int[] _requestsPerMinute; // historical load data
    private readonly int _maxLatencyMs;
    private readonly int _serverThroughputRpm; // requests per minute per server

    public CapacityPlannerService(int[] requestsPerMinute, int maxLatencyMs, int serverThroughputRpm)
    {
        _requestsPerMinute  = requestsPerMinute;
        _maxLatencyMs       = maxLatencyMs;
        _serverThroughputRpm = serverThroughputRpm;
    }

    // Returns the minimum server count to meet the SLA across all time windows.
    public int MinServersForSla(int maxServers)
    {
        int lo = 1, hi = maxServers;
        while (lo < hi)
        {
            int mid = lo + (hi - lo) / 2;
            if (MeetsSla(mid)) hi = mid;   // mid servers is enough — try fewer
            else               lo = mid + 1;
        }
        return lo;
    }

    private bool MeetsSla(int serverCount)
    {
        int capacity = serverCount * _serverThroughputRpm;
        foreach (int rpm in _requestsPerMinute)
        {
            if (rpm > capacity) return false; // over capacity — latency will exceed SLA
        }
        return true;
    }
}
```

*The key insight: the condition `MeetsSla(n)` is monotonic — if n servers meet the SLA, then n+1 also does. This monotonic property is the prerequisite for binary search on the answer space. Always verify monotonicity before applying this pattern.*

---

## Common Misconceptions

**"Binary search only works on arrays"**
Binary search works on any structure where you can compute a midpoint and determine "too high" or "too low." It works on answer spaces (integers, real numbers), implicit sorted sequences, and even on function call arguments. The array is just the most common substrate.

**"Binary search requires the exact element to be present"**
Exact match binary search returns -1 if absent. Lower/upper bound variants return the insertion point regardless of whether the target exists. The answer-space variant doesn't even operate on an array. Binary search is about eliminating half the search space per step — not about finding a specific value.

**"`Array.BinarySearch` returns the index when found"**
It returns a negative value (bitwise complement of the insertion point) when not found — not -1. `if (result < 0) insertionPoint = ~result;`. Many developers expect -1 and get subtle bugs.

---

## Gotchas

- **`mid = lo + (hi - lo) / 2` not `(lo + hi) / 2`.** The addition `lo + hi` can overflow when both are large positive integers. This was a bug in Java's standard library for 9 years.

- **Loop condition determines the invariant.** `while (lo <= hi)` with `hi = len - 1` is for exact match. `while (lo < hi)` with `hi = len` is for boundary search. Mixing them produces off-by-one bugs that are hard to debug under pressure.

- **Lower bound `hi` starts at `len`, not `len - 1`.** The answer might be "insert at the end" (all elements < target). If `hi = len - 1`, that position is excluded.

- **In the answer-space variant, verify the monotonic property.** If `condition(mid)` doesn't have a clear "false...false...true...true" shape, binary search will give the wrong answer.

- **`Array.BinarySearch` requires a sorted array and uses `CompareTo`.** If the array is not sorted, results are undefined. If the type doesn't implement `IComparable`, it throws at runtime.

---

## Interview Angle

**What they're really testing:** Whether you can identify a monotonic condition and apply binary search to an answer space — not just find a value in a sorted array.

**Common question forms:**
- "Search in rotated sorted array."
- "Find first and last position of element."
- "Minimum in rotated sorted array."
- "Koko eating bananas / capacity to ship packages."
- "Find peak element."

**The depth signal:** A junior does exact-match binary search on an array. A senior recognises "find the minimum X such that condition(X) is true" as binary search on the answer space — decoupled from any array. They implement lower bound and upper bound correctly from memory, know the overflow-safe midpoint, and understand why `hi = len` for boundary variants.

**Follow-up questions to expect:**
- "What's the loop invariant?" → `lo <= hi`: answer is in [lo, hi]. For boundary: answer is in [lo, hi) and lo converges to the insertion point.
- "Why is `hi = nums.Length` and not `nums.Length - 1` for lower bound?" → The answer could be "insert at position n" (all elements smaller than target). `hi = n - 1` would incorrectly exclude that.

---

## Related Topics

- [[algorithms/datastructures/array.md]] — Binary search requires O(1) index access — array-native.
- [[algorithms/patterns/two-pointers.md]] — Related pattern for sorted arrays; binary search finds a position in O(log n), two pointers finds pairs in O(n).
- [[algorithms/complexity/complexity-analysis.md]] — T(n) = T(n/2) + O(1) → O(log n) via Master Theorem Case 1.

---

## Source

https://docs.microsoft.com/en-us/dotnet/api/system.array.binarysearch

---

*Last updated: 2026-04-21*