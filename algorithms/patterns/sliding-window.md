# Sliding Window

> A technique that maintains a contiguous subarray of variable or fixed size using two pointers moving in the same direction — turning O(n²) subarray problems into O(n).

---

## Quick Reference

| | |
|---|---|
| **What it is** | Two same-direction pointers bounding a live window |
| **Use when** | Longest/shortest contiguous subarray or substring with a constraint |
| **Avoid when** | Subarray need not be contiguous; negative numbers with shrink logic |
| **C# version** | C# 1.0+ (pure index logic, no language feature) |
| **Namespace** | None — works on `int[]`, `char[]`, `string`, `List<T>` |
| **Key types** | `int left`, `int right`, `Dictionary<T, int>` for frequency maps |

---

## When To Use It

Use sliding window when the problem asks for something about a contiguous subarray or substring: maximum/minimum sum, longest/shortest subarray satisfying a condition, number of subarrays matching a constraint. The signal is a brute-force solution that iterates all O(n²) pairs (i, j). If extending or shrinking the window by one element is O(1) to evaluate, sliding window brings it to O(n).

Don't use it when the subarray doesn't need to be contiguous (use DP instead), or when elements can be negative and you need a minimum-length subarray (the shrink-when-violated logic breaks — prefix sums work better).

---

## Core Concept

A window is defined by two pointers, `left` and `right`, both starting at 0 and moving only rightward. Expand the window by advancing `right`. If the window violates a constraint, shrink it by advancing `left`. Because both pointers only move forward, the total movement is O(n). The insight is that you never re-examine elements — when `right` adds a new element, update the window state incrementally; when `left` removes one, downdate it. No recomputation from scratch.

Two variants: **fixed-size window** (both pointers move in lockstep, window is always k) and **variable-size window** (right expands freely, left catches up when the constraint is violated). The variable-size variant has a further sub-pattern: the **"at most k" decomposition** — when "exactly k" is hard to express directly, `exactly(k) = atMost(k) - atMost(k-1)`.

---

## Algorithm History

| Era | Development |
|---|---|
| 1970s | Network congestion control uses sliding window for TCP flow control — same principle, different domain |
| 1980s | Pattern matching algorithms (Boyer-Moore, KMP) introduce window-based string scanning |
| 1990s | Formalized as an interview pattern in algorithm textbooks |
| 2000s | Variable-size window popularized; "at most k" decomposition becomes standard trick |

*The name comes from TCP's sliding window protocol — a fixed-size buffer that slides along a data stream. The algorithm borrowed the metaphor.*

---

## Performance

| Variant | Time | Space | Notes |
|---|---|---|---|
| Fixed window (sum, max) | O(n) | O(1) | Add right, drop left — O(1) per step |
| Variable window (substring) | O(n) | O(k) | k = distinct characters/values in window |
| Sliding window maximum | O(n) | O(k) | Requires monotonic deque; without it O(nk) |
| "At most k" counting | O(n) | O(k) | Two passes of the same O(n) function |

**Allocation behaviour:** Fixed-window problems allocate O(1). Variable-window problems tracking character/value frequency allocate a `Dictionary` or array of size proportional to the alphabet (26 for lowercase letters, 128 for ASCII). No heap allocation in the inner loop.

**Benchmark notes:** The naive O(n²) approach is faster for window sizes k < 10 due to loop overhead. Sliding window becomes measurably better at k > 50 and is essential for k in the thousands. Sliding window maximum with a deque beats a sorted set when you only need the maximum — the deque's O(1) amortized operations beat O(log k) tree operations at any scale.

---

## The Code

**Scenario 1 — fixed window: maximum sum of k consecutive elements**
```csharp
public static int MaxSumFixed(int[] nums, int k)
{
    int windowSum = 0;
    for (int i = 0; i < k; i++)
        windowSum += nums[i];   // build the first window

    int best = windowSum;
    for (int i = k; i < nums.Length; i++)
    {
        windowSum += nums[i] - nums[i - k]; // add right, drop left
        best = Math.Max(best, windowSum);
    }
    return best;
}
```

**Scenario 2 — variable window: longest substring without repeating characters**
```csharp
public static int LengthOfLongestSubstring(string s)
{
    var lastSeen = new Dictionary<char, int>(); // char → last index seen
    int best = 0, left = 0;

    for (int right = 0; right < s.Length; right++)
    {
        char c = s[right];
        if (lastSeen.TryGetValue(c, out int prev) && prev >= left)
            left = prev + 1; // jump left past the duplicate — not just left++

        lastSeen[c] = right;
        best = Math.Max(best, right - left + 1);
    }
    return best;
}
```

**Scenario 3 — "exactly k" decomposition: subarrays with exactly k distinct values**
```csharp
public static int SubarraysWithKDistinct(int[] nums, int k)
{
    // exactly(k) = atMost(k) - atMost(k-1)
    return AtMost(nums, k) - AtMost(nums, k - 1);
}

private static int AtMost(int[] nums, int k)
{
    var freq = new Dictionary<int, int>();
    int left = 0, result = 0;

    for (int right = 0; right < nums.Length; right++)
    {
        freq[nums[right]] = freq.GetValueOrDefault(nums[right]) + 1;

        while (freq.Count > k)
        {
            freq[nums[left]]--;
            if (freq[nums[left]] == 0) freq.Remove(nums[left]);
            left++;
        }
        result += right - left + 1; // all subarrays ending at right
    }
    return result;
}
```

**Scenario 4 — what NOT to do: recomputing the window from scratch**
```csharp
// BAD: O(n * k) — recalculates the sum of every window by iterating k elements
public static int MaxSumBad(int[] nums, int k)
{
    int best = int.MinValue;
    for (int i = 0; i <= nums.Length - k; i++)
    {
        int sum = 0;
        for (int j = i; j < i + k; j++) // inner loop is the problem
            sum += nums[j];
        best = Math.Max(best, sum);
    }
    return best;
}

// GOOD: O(n) — maintains a running sum, adds one, drops one
public static int MaxSumGood(int[] nums, int k)
{
    int windowSum = nums[..k].Sum();
    int best = windowSum;
    for (int i = k; i < nums.Length; i++)
    {
        windowSum += nums[i] - nums[i - k];
        best = Math.Max(best, windowSum);
    }
    return best;
}
```

---

## Real World Example

The `RateLimiterService` in an API gateway enforces a sliding window rate limit: no more than `maxRequests` requests from a single IP in the last `windowSeconds`. The naive approach stores every timestamp and scans the full list per request — O(n) per check. The sliding window approach keeps a sorted deque of timestamps and evicts stale ones in O(1) amortized.

```csharp
public class RateLimiterService
{
    private readonly int _maxRequests;
    private readonly TimeSpan _window;
    private readonly Dictionary<string, LinkedList<DateTimeOffset>> _ipTimestamps = new();

    public RateLimiterService(int maxRequests, TimeSpan window)
    {
        _maxRequests = maxRequests;
        _window      = window;
    }

    // Returns true if the request is allowed, false if rate-limited.
    public bool IsAllowed(string ipAddress)
    {
        var now = DateTimeOffset.UtcNow;
        var cutoff = now - _window;

        if (!_ipTimestamps.TryGetValue(ipAddress, out var timestamps))
        {
            timestamps = new LinkedList<DateTimeOffset>();
            _ipTimestamps[ipAddress] = timestamps;
        }

        // Shrink the window from the left: evict timestamps older than cutoff
        while (timestamps.Count > 0 && timestamps.First!.Value < cutoff)
            timestamps.RemoveFirst();

        if (timestamps.Count >= _maxRequests)
            return false; // window is full — rate limit exceeded

        // Expand the window from the right: record this request
        timestamps.AddLast(now);
        return true;
    }

    // For monitoring: how many requests remain in the current window for an IP
    public int RemainingCapacity(string ipAddress)
    {
        if (!_ipTimestamps.TryGetValue(ipAddress, out var timestamps))
            return _maxRequests;

        var cutoff = DateTimeOffset.UtcNow - _window;
        while (timestamps.Count > 0 && timestamps.First!.Value < cutoff)
            timestamps.RemoveFirst();

        return Math.Max(0, _maxRequests - timestamps.Count);
    }
}
```

*The key insight: timestamps arrive in order, so evicting stale entries from the front is always safe. The left pointer (oldest timestamp) only moves forward — exactly the sliding window invariant.*

---

## Common Misconceptions

**"Sliding window and two pointers are the same thing"**
They're related but distinct. Two pointers classically has `lo` and `hi` moving toward each other on sorted data for pair-sum problems. Sliding window has `left` and `right` both moving rightward on unsorted data for subarray problems. The pointer directions and the problems they solve are different. Sliding window is a specialised two-pointer pattern, not a synonym.

**"The window always shrinks one element at a time"**
In the longest-substring-without-repeating variant, `left` jumps directly to `prev + 1` — potentially skipping many positions. This is correct and safe because the skipped positions are guaranteed to also violate the constraint. Shrinking one-by-one would give the right answer but O(n²) time. The jump is the optimisation.

**"Sliding window works for minimum subarray with negative numbers"**
It doesn't. The variable-window shrink logic (`while windowSum > target: left++`) assumes that removing the leftmost element can only decrease the sum. With negative elements, removing an element can increase the sum — so you can't know when to stop shrinking. Use prefix sums + a deque for that problem instead.

---

## Gotchas

- **Fixed window: build the first window outside the loop.** Trying to handle the initial window inside the main loop adds edge-case conditionals. Build `windowSum = nums[0..k].Sum()` explicitly, then loop from `i = k`.

- **Variable window: left must never exceed right.** If the constraint is violated before `right` even moves, `left` could leap past `right`. Guard with `while (left <= right && ...)` or ensure the constraint can't be violated on a single-element window.

- **The "at most k" decomposition is the unlock for "exactly k" problems.** A single sliding window can't directly count subarrays with exactly k distinct values — the window doesn't know when to stop expanding. `exactly(k) = atMost(k) - atMost(k-1)` is the clean, general solution.

- **Sliding window maximum requires a monotonic deque, not a sorted set.** Maintaining the max naively inside the window is O(k) per step = O(nk) total. A deque that pops elements smaller than the incoming element keeps the front as the current max in O(1) amortized.

- **Negative numbers break the standard shrink heuristic.** The standard variable-window assumes that making the window smaller reduces the sum/count. This is false with negatives. Stick to sliding window for non-negative values only, unless you've explicitly verified the monotonic property holds.

---

## Interview Angle

**What they're really testing:** Whether you can identify a subarray problem as sliding window and maintain window state incrementally — not recompute from scratch each step.

**Common question forms:**
- "Longest substring without repeating characters."
- "Minimum window substring containing all characters of T."
- "Maximum sum of k consecutive elements."
- "Longest subarray with sum ≤ k."
- "Fruit into baskets (longest subarray with at most 2 distinct values)."

**The depth signal:** A junior uses two nested loops. A senior identifies the monotonic property (window can only shrink from the left when right expands), maintains state with a hash map or counter, and knows the `exactly(k) = atMost(k) - atMost(k-1)` decomposition without being prompted. The sliding window maximum problem — requiring a monotonic deque — is the senior-level extension that separates good candidates from strong ones.

**Follow-up questions to expect:**
- "What if elements can be negative?" → Prefix sums or Kadane's algorithm.
- "How does this differ from two pointers?" → Direction of pointer movement, type of problem it solves.

---

## Related Topics

- [[algorithms/patterns/two-pointers.md]] — Sliding window is two pointers moving in the same direction; classic two pointers move toward each other.
- [[algorithms/patterns/prefix-sum.md]] — The alternative for subarray problems when elements can be negative.
- [[algorithms/datastructures/hash-table.md]] — Variable windows almost always track state with a frequency map.
- [[algorithms/datastructures/queue.md]] — The monotonic deque is the data structure for sliding window maximum.

---

## Source

https://leetcode.com/articles/sliding-window-technique

---

*Last updated: 2026-04-21*