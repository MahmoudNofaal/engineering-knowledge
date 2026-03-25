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
```csharp
public static int MaxSumK(List<int> items, int k)
{
    int window = items.Skip(0).Take(k).Sum();
    int best = window;
    for (int i = k; i < items.Count; i++)
    {
        window += items[i] - items[i - k];    // add right, drop left
        best = Math.Max(best, window);
    }
    return best;
}
```

**Variable window — longest substring without repeating characters**
```csharp
public static int LengthOfLongestSubstring(string s)
{
    var charIndex = new Dictionary<char, int>();
    int best = 0, left = 0;
    
    for (int right = 0; right < s.Length; right++)
    {
        char ch = s[right];
        if (charIndex.ContainsKey(ch) && charIndex[ch] >= left)
            left = charIndex[ch] + 1;    // jump left past the duplicate
        
        charIndex[ch] = right;
        best = Math.Max(best, right - left + 1);
    }
    return best;
}
```

**Variable window — minimum window substring containing all target chars**
```csharp
public static string MinWindow(string s, string t)
{
    var need = new Dictionary<char, int>();
    foreach (char ch in t)
    {
        if (need.ContainsKey(ch))
            need[ch]++;
        else
            need[ch] = 1;
    }
    
    int missing = t.Length;  // total characters still needed in window
    string best = "";
    int left = 0;
    
    for (int right = 0; right < s.Length; right++)
    {
        char ch = s[right];
        if (need.ContainsKey(ch) && need[ch] > 0)
            missing--;   // this character was needed and is now covered
        if (need.ContainsKey(ch))
            need[ch]--;
        
        if (missing == 0)   // window satisfies the constraint
        {
            // shrink from left while constraint still holds
            while (need[s[left]] < 0)
            {
                need[s[left]]++;
                left++;
            }
            string window = s.Substring(left, right - left + 1);
            if (best.Length == 0 || window.Length < best.Length)
                best = window;
            
            // break the constraint to force expansion
            need[s[left]]++;
            missing++;
            left++;
        }
    }
    return best;
}
```

**Variable window — longest subarray with sum ≤ k (non-negative values)**
```csharp
public static int LongestSubarraySum(List<int> items, int k)
{
    int left = 0, windowSum = 0, best = 0;
    
    for (int right = 0; right < items.Count; right++)
    {
        windowSum += items[right];
        while (windowSum > k)
        {
            windowSum -= items[left];
            left++;
        }
        best = Math.Max(best, right - left + 1);
    }
    return best;
}
```

**Counting subarrays with exactly k distinct values — sliding window on counts**
```csharp
public static int SubarraysWithKDistinct(int[] nums, int k)
{
    // exactly k = at most k - at most (k-1)
    int AtMost(int maxDistinct)
    {
        var count = new Dictionary<int, int>();
        int left = 0, result = 0;
        
        for (int right = 0; right < nums.Length; right++)
        {
            if (!count.ContainsKey(nums[right]))
                count[nums[right]] = 0;
            count[nums[right]]++;
            
            while (count.Count > maxDistinct)
            {
                count[nums[left]]--;
                if (count[nums[left]] == 0)
                    count.Remove(nums[left]);
                left++;
            }
            result += right - left + 1;    // all subarrays ending at right
        }
        return result;
    }
    
    return AtMost(k) - AtMost(k - 1);
}
```
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