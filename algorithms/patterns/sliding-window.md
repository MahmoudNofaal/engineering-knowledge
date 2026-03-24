# Sliding Window
> A technique that maintains a contiguous subarray of variable or fixed size using two pointers moving in the same direction — turning O(n²) subarray problems into O(n).

---

## When To Use It
Use sliding window when the problem asks for something about a contiguous subarray or substring: maximum/minimum sum, longest/shortest subarray satisfying a condition, number of subarrays matching a constraint. The signal is: brute force iterates all pairs (i, j), which is O(n²). If extending or shrinking the window by one element is O(1) to evaluate, sliding window brings it to O(n). Don't use it when the subarray doesn't need to be contiguous.

---

## Core Concept
A window is defined by two pointers, left and right, both starting at 0 and moving only rightward. Expand the window by advancing right. If the window violates a constraint, shrink it by advancing left. Because both pointers only move forward, the total movement is O(n). The insight is that you never need to re-examine elements — when right adds a new element, you update the window state incrementally; when left removes an element, you downdate it incrementally. No recomputation from scratch.

Two variants: **fixed-size window** (both pointers move in lockstep, window size is always k) and **variable-size window** (right expands freely, left catches up when the constraint is violated).

---

## The Code

**Fixed window — maximum sum of k consecutive elements**
```python
def max_sum_k(items: list, k: int) -> int:
    window = sum(items[:k])
    best = window
    for i in range(k, len(items)):
        window += items[i] - items[i - k]    # add right, drop left
        best = max(best, window)
    return best
```

**Variable window — longest substring without repeating characters**
```python
def length_of_longest_substring(s: str) -> int:
    char_index = {}
    best = left = 0
    for right, ch in enumerate(s):
        if ch in char_index and char_index[ch] >= left:
            left = char_index[ch] + 1    # jump left past the duplicate
        char_index[ch] = right
        best = max(best, right - left + 1)
    return best
```

**Variable window — minimum window substring containing all target chars**
```python
from collections import Counter

def min_window(s: str, t: str) -> str:
    need = Counter(t)
    missing = len(t)       # total characters still needed in window
    best = ""
    left = 0
    for right, ch in enumerate(s):
        if need[ch] > 0:
            missing -= 1   # this character was needed and is now covered
        need[ch] -= 1
        if missing == 0:   # window satisfies the constraint
            # shrink from left while constraint still holds
            while need[s[left]] < 0:
                need[s[left]] += 1
                left += 1
            window = s[left:right + 1]
            if not best or len(window) < len(best):
                best = window
            # break the constraint to force expansion
            need[s[left]] += 1
            missing += 1
            left += 1
    return best
```

**Variable window — longest subarray with sum ≤ k (non-negative values)**
```python
def longest_subarray_sum(items: list, k: int) -> int:
    left = window_sum = best = 0
    for right, val in enumerate(items):
        window_sum += val
        while window_sum > k:
            window_sum -= items[left]
            left += 1
        best = max(best, right - left + 1)
    return best
```

**Counting subarrays with exactly k distinct values — sliding window on counts**
```python
def subarrays_with_k_distinct(nums: list, k: int) -> int:
    # exactly k = at most k - at most (k-1)
    def at_most(k: int) -> int:
        count = {}
        left = result = 0
        for right, val in enumerate(nums):
            count[val] = count.get(val, 0) + 1
            while len(count) > k:
                count[nums[left]] -= 1
                if count[nums[left]] == 0:
                    del count[nums[left]]
                left += 1
            result += right - left + 1    # all subarrays ending at right
        return result
    return at_most(k) - at_most(k - 1)
```

---

## Gotchas

- **Variable window left pointer must not skip past right.** If the constraint is already violated and left catches up to or passes right, the window is empty. Add a `left <= right` guard or ensure the logic prevents left from overshooting.
- **The "at most k" trick unlocks "exactly k" problems.** Counting subarrays with exactly k distinct elements is not directly amenable to a single sliding window. The decomposition `exactly(k) = atMost(k) - atMost(k-1)` is a clean and general solution.
- **Incrementally maintaining window state is the whole point.** If your window update requires scanning the entire window (e.g., recomputing max with a linear scan), the solution is O(n²) not O(n). Use a deque for sliding window maximum/minimum — O(1) update.
- **Fixed window: initialize on the first k elements, then loop from k to n.** Don't try to handle the initial window inside the main loop — it complicates the logic. Build the first window separately, then slide.
- **Negative numbers break the shrink-when-violated pattern.** If elements can be negative, shrinking the window doesn't necessarily reduce the sum. In that case, Kadane's algorithm (for max subarray sum) or prefix sums (for arbitrary range queries) are the right tools.

---

## Interview Angle

**What they're really testing:** Whether you can identify a subarray problem as sliding window and maintain window state incrementally — not recompute from scratch on each step.

**Common question form:** Longest substring without repeating characters, minimum window substring, max sum of k consecutive elements, longest subarray with sum ≤ k, fruit into baskets (longest subarray with at most 2 distinct values).

**The depth signal:** A junior uses two nested loops. A senior identifies the monotonic property (window can only shrink from the left when the right expands), maintains state with a hash map or counter, and knows the `exactly(k) = atMost(k) - atMost(k-1)` decomposition. The sliding window maximum problem — requiring a monotonic deque — is the senior-level extension that separates good candidates from strong ones.

---

## Related Topics

- [[algorithms/two-pointers.md]] — Sliding window is two pointers moving in the same direction; two pointers classically move toward each other.
- [[algorithms/array.md]] — Sliding window is fundamentally an array index technique.
- [[algorithms/hash-table.md]] — Variable windows almost always track state with a frequency map.

---

## Source

https://leetcode.com/articles/sliding-window-technique

---

*Last updated: 2026-03-24*