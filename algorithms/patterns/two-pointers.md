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
```python
def two_sum_sorted(items: list, target: int) -> tuple:
    lo, hi = 0, len(items) - 1
    while lo < hi:
        s = items[lo] + items[hi]
        if s == target:
            return (lo, hi)
        elif s < target:
            lo += 1    # sum too small — advance left to increase it
        else:
            hi -= 1    # sum too large — retreat right to decrease it
    return (-1, -1)
```

**Three sum — reduce to two sum with an outer loop**
```python
def three_sum(nums: list) -> list:
    nums.sort()
    result = []
    for i in range(len(nums) - 2):
        if i > 0 and nums[i] == nums[i - 1]:
            continue                          # skip duplicates at outer level
        lo, hi = i + 1, len(nums) - 1
        while lo < hi:
            s = nums[i] + nums[lo] + nums[hi]
            if s == 0:
                result.append([nums[i], nums[lo], nums[hi]])
                while lo < hi and nums[lo] == nums[lo + 1]: lo += 1  # skip dupes
                while lo < hi and nums[hi] == nums[hi - 1]: hi -= 1
                lo += 1; hi -= 1
            elif s < 0:
                lo += 1
            else:
                hi -= 1
    return result
```

**Container with most water — maximize area**
```python
def max_area(heights: list) -> int:
    lo, hi = 0, len(heights) - 1
    best = 0
    while lo < hi:
        area = min(heights[lo], heights[hi]) * (hi - lo)
        best = max(best, area)
        if heights[lo] < heights[hi]:
            lo += 1    # shorter side limits us — move it inward to possibly improve
        else:
            hi -= 1
    return best
```

**Remove duplicates from sorted array in-place**
```python
def remove_duplicates(nums: list) -> int:
    if not nums:
        return 0
    slow = 0
    for fast in range(1, len(nums)):
        if nums[fast] != nums[slow]:
            slow += 1
            nums[slow] = nums[fast]    # write pointer lags behind read pointer
    return slow + 1
```

**Merge two sorted arrays into one**
```python
def merge_sorted(a: list, b: list) -> list:
    result = []
    i = j = 0
    while i < len(a) and j < len(b):
        if a[i] <= b[j]:
            result.append(a[i]); i += 1
        else:
            result.append(b[j]); j += 1
    result.extend(a[i:])
    result.extend(b[j:])
    return result
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