# Binary Search
> A search algorithm that finds a target in a sorted array by repeatedly halving the search space — O(log n).

---

## When To Use It
Use binary search any time your input is sorted and you need to find a value, a boundary, or a condition. It's not just for exact lookups — the pattern generalizes to "find the leftmost position where condition X becomes true." If you catch yourself scanning a sorted structure linearly, binary search probably applies. Don't use it on unsorted data — the result is simply wrong, not just slow.

---

## Core Concept
Binary search works by maintaining a window [lo, hi] that contains the answer. Each iteration, check the midpoint. If it's too small, discard the left half. If it's too big, discard the right half. Each step halves the window, so after log n steps the window is empty or contains exactly the answer.

The hard part isn't the idea — it's the boundary conditions. Off-by-one errors are the most common bug in binary search implementations. The three variants to know: exact match, leftmost insertion point (lower bound), and rightmost insertion point (upper bound). Each has slightly different loop conditions and return values.

---

## The Code

**Exact match**
```csharp
public static int BinarySearch(int[] items, int target)
{
    int lo = 0, hi = items.Length - 1;
    while (lo <= hi)                        // = because single element is valid
    {
        int mid = lo + (hi - lo) / 2;       // avoids integer overflow vs (lo+hi)/2
        if (items[mid] == target)
            return mid;
        else if (items[mid] < target)
            lo = mid + 1;
        else
            hi = mid - 1;
    }
    return -1;                              // not found
}
```

**Lower bound — leftmost index where items[i] >= target**
```csharp
public static int LowerBound(int[] items, int target)
{
    int lo = 0, hi = items.Length;        // hi = len, not len-1
    while (lo < hi)                        // strict < because hi is exclusive
    {
        int mid = (lo + hi) / 2;
        if (items[mid] < target)
            lo = mid + 1;
        else
            hi = mid;                      // don't exclude mid — it could be the answer
    }
    return lo;                             // lo == hi, the insertion point
}
```

**Upper bound — leftmost index where items[i] > target**
```csharp
public static int UpperBound(int[] items, int target)
{
    int lo = 0, hi = items.Length;
    while (lo < hi)
    {
        int mid = (lo + hi) / 2;
        if (items[mid] <= target)          // only difference from lower_bound
            lo = mid + 1;
        else
            hi = mid;
    }
    return lo;
}
```

**Binary search on a condition — generalized template**
```csharp
// Find the smallest x in [lo, hi] where condition(x) is True.
// Assumes: condition is False for some prefix, True for the rest (monotonic).
public static int BinarySearchCondition(int lo, int hi, Func<int, bool> condition)
{
    while (lo < hi)
    {
        int mid = (lo + hi) / 2;
        if (condition(mid))
            hi = mid;          // mid could be the answer, don't exclude it
        else
            lo = mid + 1;      // mid is definitely not the answer
    }
    return lo;                 // first index where condition is True
}
```

**Real usage: find minimum speed to ship packages within D days**
```csharp
public static int ShipWithinDays(int[] weights, int days)
{
    bool CanShip(int capacity)
    {
        int current = 0, dayCount = 1;
        foreach (int w in weights)
        {
            if (current + w > capacity)
            {
                dayCount++;
                current = 0;
            }
            current += w;
        }
        return dayCount <= days;
    }

    int lo = weights.Max(), hi = weights.Sum();
    return BinarySearchCondition(lo, hi, CanShip);
}
```

**Search in rotated sorted array**
```csharp
public static int SearchRotated(int[] items, int target)
{
    int lo = 0, hi = items.Length - 1;
    while (lo <= hi)
    {
        int mid = (lo + hi) / 2;
        if (items[mid] == target)
            return mid;
        if (items[lo] <= items[mid])  // left half is sorted
        {
            if (items[lo] <= target && target < items[mid])
                hi = mid - 1;
            else
                lo = mid + 1;
        }
        else  // right half is sorted
        {
            if (items[mid] < target && target <= items[hi])
                lo = mid + 1;
            else
                hi = mid - 1;
        }
    }
    return -1;
}
```

---

## Gotchas

- **`mid = (lo + hi) // 2` overflows in languages with fixed-width integers.** Use `lo + (hi - lo) // 2` instead. Python integers don't overflow, but write it correctly anyway — interviewers notice.
- **The loop condition determines the invariant.** `while lo <= hi` with `hi = len - 1` is for exact match. `while lo < hi` with `hi = len` is for boundary search. Mixing them produces subtle off-by-one bugs that are hard to debug under pressure.
- **Binary search applies to answer spaces, not just arrays.** Any monotonic condition over an integer range is binary-searchable. "Find the minimum capacity/speed/size such that X is possible" is binary search on the answer, not on an array.
- **Always verify the loop terminates.** In boundary-search variants, if `lo == mid` is possible and you set `hi = mid`, the loop can run forever. Ensure mid always moves: `mid = (lo + hi) // 2` moves toward lo, so always update at least one bound strictly.
- **Python has `bisect.bisect_left` and `bisect.bisect_right`.** These are the standard lower/upper bound implementations. Use them in production and in interviews unless you're explicitly asked to implement binary search from scratch.

---

## Interview Angle

**What they're really testing:** Whether you can identify a monotonic condition and apply binary search to an answer space — not just find a value in a sorted array.

**Common question form:** Search in rotated array, find peak element, minimum in rotated sorted array, koko eating bananas, capacity to ship packages, find first and last position of element.

**The depth signal:** A junior does exact match binary search. A senior recognizes that "find the minimum X such that condition(X) is true" is a binary search on the answer space — decoupling the search from an array entirely. They implement lower bound and upper bound correctly from memory, know the loop invariant for each variant, and reach for `bisect` in Python without needing to re-derive it.

---

## Related Topics

- [[algorithms/sorting-in-practice.md]] — Binary search requires sorted input; knowing sort complexity matters.
- [[algorithms/array.md]] — Binary search is an array algorithm; index arithmetic is central.
- [[algorithms/complexity-analysis.md]] — The recurrence T(n) = T(n/2) + O(1) solves to O(log n) — binary search's complexity proof.

---

## Source

https://docs.python.org/3/library/bisect.html

---

*Last updated: 2026-03-24*