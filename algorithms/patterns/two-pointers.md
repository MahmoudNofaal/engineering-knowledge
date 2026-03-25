# Two Pointers
> A technique that uses two indices moving through a data structure — often toward each other or at different speeds — to solve problems in O(n) that would otherwise require O(n²).

---

## When To Use It
Use two pointers on sorted arrays or when processing pairs, triplets, or subarrays. The signal is a brute-force solution with nested loops that you need to reduce to a single pass. Also applies to linked lists (detect cycles, find midpoint, merge). Don't use it on unsorted data where the pointer movement logic would be undefined.

---

## Core Concept
Two pointers eliminates the inner loop by using the sorted order (or structure) to make informed decisions about which pointer to advance. When the current pair gives too small a sum, move the left pointer right to increase it. Too large, move the right pointer left to decrease it. Each step either finds the answer or eliminates a candidate that can't possibly work — so you never need to revisit. The total movement across both pointers is O(n), giving a single-pass O(n) solution.

---

## The Code

**Two sum on sorted array — O(n)**
```csharp
public static (int, int) TwoSumSorted(List<int> items, int target)
{
    int lo = 0, hi = items.Count - 1;
    while (lo < hi)
    {
        int s = items[lo] + items[hi];
        if (s == target)
            return (lo, hi);
        else if (s < target)
            lo++;    // sum too small — advance left to increase it
        else
            hi--;    // sum too large — retreat right to decrease it
    }
    return (-1, -1);
}
```

**Three sum — reduce to two sum with an outer loop**
```csharp
public static List<List<int>> ThreeSum(int[] nums)
{
    Array.Sort(nums);
    var result = new List<List<int>>();
    
    for (int i = 0; i < nums.Length - 2; i++)
    {
        if (i > 0 && nums[i] == nums[i - 1])
            continue;                          // skip duplicates at outer level
        
        int lo = i + 1, hi = nums.Length - 1;
        while (lo < hi)
        {
            long s = (long)nums[i] + nums[lo] + nums[hi];
            if (s == 0)
            {
                result.Add(new List<int> { nums[i], nums[lo], nums[hi] });
                while (lo < hi && nums[lo] == nums[lo + 1]) lo++;  // skip dupes
                while (lo < hi && nums[hi] == nums[hi - 1]) hi--;
                lo++; hi--;
            }
            else if (s < 0)
                lo++;
            else
                hi--;
        }
    }
    return result;
}
```

**Container with most water — maximize area**
```csharp
public static int MaxArea(int[] heights)
{
    int lo = 0, hi = heights.Length - 1;
    int best = 0;
    while (lo < hi)
    {
        int area = Math.Min(heights[lo], heights[hi]) * (hi - lo);
        best = Math.Max(best, area);
        if (heights[lo] < heights[hi])
            lo++;    // shorter side limits us — move it inward to possibly improve
        else
            hi--;
    }
    return best;
}
```

**Remove duplicates from sorted array in-place**
```csharp
public static int RemoveDuplicates(int[] nums)
{
    if (nums.Length == 0)
        return 0;
    int slow = 0;
    for (int fast = 1; fast < nums.Length; fast++)
    {
        if (nums[fast] != nums[slow])
        {
            slow++;
            nums[slow] = nums[fast];    // write pointer lags behind read pointer
        }
    }
    return slow + 1;
}
```
    return slow + 1
```

**Merge two sorted arrays into one**
```csharp
public List<int> MergeSorted(List<int> a, List<int> b)
{
    var result = new List<int>();
    int i = 0, j = 0;
    while (i < a.Count && j < b.Count)
    {
        if (a[i] <= b[j])
        {
            result.Add(a[i]);
            i++;
        }
        else
        {
            result.Add(b[j]);
            j++;
        }
    }
    result.AddRange(a.Skip(i));
    result.AddRange(b.Skip(j));
    return result;
}
```

---

## Gotchas

- **Two pointers only works correctly on sorted input for sum/pair problems.** If the array isn't sorted, sort it first — O(n log n) — which is still better than O(n²) brute force.
- **Duplicate handling in three-sum is where most implementations break.** You must skip duplicates at both the outer loop level and the inner two-pointer level, or the result list contains duplicate triplets.
- **The slow/fast read-write variant is a different pattern.** When slow is a write pointer and fast is a read pointer moving through the array, you're partitioning or deduplicating in-place — not searching for pairs. Don't confuse the two.
- **`lo < hi` not `lo <= hi`.** When `lo == hi`, both pointers are on the same element. A pair requires two distinct indices. This off-by-one causes false positives on exact-match problems.
- **Pointer movement logic must be provably correct.** For each step, you must be able to argue: "this candidate is impossible, so discarding it is safe." If you can't articulate that argument, the pointer movement may skip valid answers.

---

## Interview Angle

**What they're really testing:** Whether you see a nested loop and immediately ask "can I sort first and use two pointers?" — reducing O(n²) to O(n log n) or O(n).

**Common question form:** Two sum on sorted array, three sum, container with most water, trapping rain water, remove duplicates, valid palindrome.

**The depth signal:** A junior brute-forces pairs. A senior sorts and applies two pointers, articulates why each pointer move is safe, and extends the pattern from 2-sum to 3-sum without prompting by reducing it: fix one element, run two-sum on the rest. They also handle the duplicate-skipping logic cleanly — which is where most candidates fail on three-sum.

---

## Related Topics

- [[algorithms/sliding-window.md]] — Related single-pass pattern; two pointers for subarrays where both ends move right.
- [[algorithms/fast-slow-pointers.md]] — Two pointers at different speeds; for cycle detection and midpoint finding on linked lists.
- [[algorithms/binary-search.md]] — Another way to eliminate candidates; often combined with two pointers on sorted data.
- [[algorithms/sorting-in-practice.md]] — Two-pointer problems almost always require sorting first.

---

## Source

https://leetcode.com/articles/two-pointer-technique

---

*Last updated: 2026-03-24*