# Monotonic Queue

> A double-ended queue that maintains a monotonic (increasing or decreasing) ordering of elements, enabling O(1) sliding window min/max queries.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Deque with ordering invariant — O(1) window min/max |
| **Use when** | Sliding window min or max over a fixed-size window |
| **Avoid when** | Window size varies arbitrarily or you need both min and max |
| **C# version** | C# 2.0+ (`LinkedList<T>` as deque) |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `LinkedList<int>` (stores indices), acts as double-ended queue |

---

## When To Use It

Use a monotonic queue when you need the minimum or maximum of a sliding window of fixed size k as it moves across an array. The naive approach recomputes the min/max for each window position — O(k) per step, O(nk) total. The monotonic queue amortises this to O(1) per step by maintaining a deque of candidate indices whose values form a monotonic sequence.

Use it specifically when: the window slides one position at a time, k is fixed (or at least bounded), and you need either min or max (not both). For variable-size windows where you contract from the left based on a condition, a monotonic queue still applies but the eviction logic changes — you remove from the front when the index falls out of the window.

Avoid it when you need both min and max simultaneously (would require two separate deques), when the window contracts from the right (different problem structure), or when k = 1 (trivially the element itself) or k = n (just find the global min/max).

---

## Core Concept

A monotonic decreasing queue for window maximum works as follows:

**Invariant:** The deque stores indices in order, and the corresponding values are in strictly decreasing order from front to back. The front always holds the index of the current window's maximum.

**Add a new element (index i):** Before pushing i onto the back, pop all indices from the back whose values are ≤ the new element's value. Those elements can never be the maximum for any future window — they're smaller than the current element and will leave the window before it does.

**Evict expired elements:** Before reading the maximum, check if the front index is still within the current window (`front >= i - k + 1`). If not, pop it from the front.

**Read the maximum:** `nums[deque.Front]` — always O(1).

The O(n) overall time bound comes from the same invariant as the monotonic stack: each index is added to the deque once and removed at most once — O(2n) total operations.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 2.0 | .NET 2.0 | `LinkedList<T>` — double-ended, O(1) add/remove from both ends |
| C# 5.0 | .NET 4.5 | No change — `LinkedList<T>` is still the standard deque substitute |
| C# 10.0 | .NET 6 | No dedicated `Deque<T>` in BCL; `LinkedList<T>` remains the idiom |

*C# has no `Deque<T>` in the BCL. `LinkedList<T>` is the standard substitute — `AddLast` / `RemoveLast` for the back, `AddFirst` / `RemoveFirst` for the front, both O(1).*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Full algorithm (n elements, window k) | O(n) | Each index enqueued once, dequeued at most once |
| Per-step window maximum/minimum | O(1) amortised | Read from front of deque |
| Space | O(k) | Deque holds at most k indices |

**Allocation behaviour:** `LinkedList<int>` allocates one `LinkedListNode<int>` per enqueued index. Nodes are garbage-collected on removal. For very high-throughput scenarios (millions of windows per second), consider a circular buffer array-based deque to avoid GC pressure.

**Benchmark notes:** The O(n) total complexity is tight — on a sorted-descending input, every element is pushed once and never popped (they maintain the decreasing invariant perfectly). On sorted-ascending input, every push evicts the previous element — O(2n) total operations. Both degenerate cases are still O(n).

---

## The Code

**Sliding window maximum — O(n)**
```csharp
public static int[] SlidingWindowMax(int[] nums, int k)
{
    int n      = nums.Length;
    int[] res  = new int[n - k + 1];
    // Deque stores indices; values are in decreasing order front-to-back
    var dq     = new LinkedList<int>();

    for (int i = 0; i < n; i++)
    {
        // 1. Evict front if it's outside the current window
        if (dq.Count > 0 && dq.First!.Value < i - k + 1)
            dq.RemoveFirst();

        // 2. Pop from back all indices whose values are ≤ nums[i]
        //    They can never be the window max — nums[i] is larger and newer
        while (dq.Count > 0 && nums[dq.Last!.Value] <= nums[i])
            dq.RemoveLast();

        dq.AddLast(i);

        // 3. Window is fully formed — record max
        if (i >= k - 1)
            res[i - k + 1] = nums[dq.First!.Value];
    }
    return res;
}
// SlidingWindowMax([1,3,-1,-3,5,3,6,7], 3) → [3,3,5,5,6,7]
```

**Sliding window minimum — flip the comparison**
```csharp
public static int[] SlidingWindowMin(int[] nums, int k)
{
    int n     = nums.Length;
    int[] res = new int[n - k + 1];
    var dq    = new LinkedList<int>();   // increasing order front-to-back

    for (int i = 0; i < n; i++)
    {
        if (dq.Count > 0 && dq.First!.Value < i - k + 1)
            dq.RemoveFirst();

        // Pop from back all values >= nums[i] — they're larger and older (useless)
        while (dq.Count > 0 && nums[dq.Last!.Value] >= nums[i])
            dq.RemoveLast();

        dq.AddLast(i);

        if (i >= k - 1)
            res[i - k + 1] = nums[dq.First!.Value];
    }
    return res;
}
```

**Variable-size window — longest subarray where max - min ≤ limit**
```csharp
// Uses TWO monotonic queues: one for max, one for min
public static int LongestSubarrayWithLimit(int[] nums, int limit)
{
    var maxDq = new LinkedList<int>();   // decreasing — tracks max
    var minDq = new LinkedList<int>();   // increasing — tracks min
    int left  = 0, best = 0;

    for (int right = 0; right < nums.Length; right++)
    {
        // Maintain max deque
        while (maxDq.Count > 0 && nums[maxDq.Last!.Value] <= nums[right])
            maxDq.RemoveLast();
        maxDq.AddLast(right);

        // Maintain min deque
        while (minDq.Count > 0 && nums[minDq.Last!.Value] >= nums[right])
            minDq.RemoveLast();
        minDq.AddLast(right);

        // Shrink from left while window violates limit
        while (nums[maxDq.First!.Value] - nums[minDq.First!.Value] > limit)
        {
            left++;
            if (maxDq.First.Value < left) maxDq.RemoveFirst();
            if (minDq.First.Value < left) minDq.RemoveFirst();
        }
        best = Math.Max(best, right - left + 1);
    }
    return best;
}
```

**Jump game VI — DP with sliding window max**
```csharp
// dp[i] = max score to reach index i
// Transition: dp[i] = nums[i] + max(dp[i-k..i-1])
// A monotonic queue makes this O(n) instead of O(nk)
public static long MaxResult(int[] nums, int k)
{
    int n      = nums.Length;
    long[] dp  = new long[n];
    dp[0]      = nums[0];
    var dq     = new LinkedList<int>();
    dq.AddLast(0);

    for (int i = 1; i < n; i++)
    {
        // Evict indices outside the window
        if (dq.First!.Value < i - k)
            dq.RemoveFirst();

        dp[i] = nums[i] + dp[dq.First!.Value];   // best dp in window

        // Maintain decreasing order (we want the max dp value at the front)
        while (dq.Count > 0 && dp[dq.Last!.Value] <= dp[i])
            dq.RemoveLast();
        dq.AddLast(i);
    }
    return dp[n - 1];
}
```

**What NOT to do — and the fix**
```csharp
// BAD: recomputing max for each window — O(nk)
public static int[] SlidingWindowMaxBad(int[] nums, int k)
{
    int n     = nums.Length;
    int[] res = new int[n - k + 1];
    for (int i = 0; i <= n - k; i++)
    {
        int max = int.MinValue;
        for (int j = i; j < i + k; j++)   // O(k) inner loop
            max = Math.Max(max, nums[j]);
        res[i] = max;
    }
    return res;                            // O(nk) total
}

// GOOD: monotonic queue — O(n) total (see SlidingWindowMax above)
```

---

## Real World Example

A network monitoring system tracks packet latency measurements arriving every millisecond. An alert fires when the maximum latency in any 5-second (5,000-sample) window exceeds a threshold. Checking every window naively would require re-scanning 5,000 samples per millisecond — 5 billion comparisons per second. The monotonic queue reduces this to one comparison per new sample, regardless of window size.

```csharp
public class LatencyMonitor
{
    private readonly LinkedList<(long latencyMs, int index)> _maxDq = new();
    private readonly int _windowSize;
    private readonly long _alertThresholdMs;
    private int _sampleIndex;

    public LatencyMonitor(int windowSizeSamples, long alertThresholdMs)
    {
        _windowSize       = windowSizeSamples;
        _alertThresholdMs = alertThresholdMs;
    }

    // Returns true if an alert should fire — called once per incoming sample
    public bool RecordSample(long latencyMs)
    {
        int i = _sampleIndex++;

        // Evict expired samples from front
        while (_maxDq.Count > 0 && _maxDq.First!.Value.index < i - _windowSize + 1)
            _maxDq.RemoveFirst();

        // Evict smaller candidates from back
        while (_maxDq.Count > 0 && _maxDq.Last!.Value.latencyMs <= latencyMs)
            _maxDq.RemoveLast();

        _maxDq.AddLast((latencyMs, i));

        long windowMax = _maxDq.First!.Value.latencyMs;   // O(1)
        return windowMax > _alertThresholdMs;
    }
}
```

*The critical insight is that the window max query costs O(1) regardless of window size — the monotonic deque has already discarded every value that can't possibly be the maximum. The monitoring system's CPU cost is constant per sample, not proportional to the window size.*

---

## Common Misconceptions

**"A monotonic queue is the same as a monotonic stack"**
They're related but distinct. A monotonic stack processes elements left-to-right and pops from the top only — it's suited for "next greater/smaller" problems with no window constraint. A monotonic queue uses a deque with eviction from both ends — it's suited for sliding window min/max where elements also expire from the left as the window advances.

**"You need a priority heap for sliding window max"**
A heap gives O(log k) per step and O(n log k) total for this problem. The monotonic queue does it in O(1) per step and O(n) total — strictly better. The heap approach is also more complex to implement correctly because lazy deletion of expired elements is subtle. Reach for the monotonic queue for fixed-window min/max.

**"The deque stores values"**
It stores **indices**. Values are retrieved as `nums[dq.First.Value]`. Storing values instead of indices loses the position information needed to evict expired window elements.

---

## Gotchas

- **C# has no built-in `Deque<T>`.** Use `LinkedList<int>` with `AddFirst`/`RemoveFirst` for the front and `AddLast`/`RemoveLast` for the back. Both are O(1). Alternatively, implement a circular buffer array deque for lower GC pressure in hot paths.

- **Evict from the front before reading the maximum.** If you read `dq.First` before checking whether it's expired, you'll return stale maxima for windows that no longer contain that index.

- **The eviction order matters: expire-front first, then pop-back, then push.** If you push before checking expiry, you might evict a newly added valid element. The sequence is always: (1) expire front, (2) pop stale back, (3) push new index, (4) read front.

- **Use `<=` or `<` in the back-eviction comparison consistently.** For "strictly greater" window max: pop when `nums[back] <= nums[i]` (evict elements that are ≤ current — current is better). For "greater or equal" semantics: use `<`. Getting this wrong produces incorrect results on inputs with duplicate values.

- **For DP + sliding window max, the deque stores DP indices, not input indices.** The eviction check (`dq.First < i - k`) uses the same index, but you compare `dp[dq.Last]` against `dp[i]`, not `nums`. Mixing up the arrays is a common bug.

---

## Interview Angle

**What they're really testing:** Whether you know the monotonic queue pattern and can apply it to convert an O(nk) sliding-window problem to O(n) — and whether you understand why a heap is inferior here.

**Common question forms:**
- "Sliding Window Maximum" (LeetCode 239 — the canonical problem)
- "Jump Game VI" (DP + sliding window max)
- "Longest Subarray with Absolute Diff ≤ Limit" (LeetCode 1438 — two deques)
- "Constrained Subsequence Sum"

**The depth signal:** A junior solves sliding window max with a heap — O(n log k), correct but suboptimal. A senior uses the monotonic deque — O(n) — and explains why: each element is pushed and popped at most once, so total operations are O(2n). The elite signal is recognising when DP transitions have a sliding window structure (Jump Game VI) and applying the deque to reduce DP from O(nk) to O(n).

**Follow-up questions to expect:**
- "Why not use a heap?" (O(log k) per step vs O(1) — and lazy deletion of expired elements makes heap more complex)
- "How do you handle duplicates?" (The `<=` vs `<` back-eviction choice — both are valid; `<=` gives slightly shorter deques)
- "What if you need both min and max?" (Two separate deques — as shown in LongestSubarrayWithLimit above)

---

## Related Topics

- [[algorithms/datastructures/monotonic-stack.md]] — The single-ended analogue for next greater/smaller problems without a window constraint.
- [[algorithms/datastructures/queue.md]] — The plain queue that monotonic queue builds on; BFS vs sliding window are distinct use cases.
- [[algorithms/patterns/sliding-window.md]] — The general sliding window pattern; monotonic queue is the tool when you need the window min/max.
- [[algorithms/datastructures/heap.md]] — The O(n log k) alternative — correct but slower for fixed sliding window max.

---

## Source

https://leetcode.com/problems/sliding-window-maximum/solutions/65884/java-o-n-solution-using-deque-with-explanation/

---

*Last updated: 2026-04-12*