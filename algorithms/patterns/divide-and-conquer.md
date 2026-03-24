# Divide and Conquer
> A problem-solving strategy that breaks a problem into smaller subproblems of the same type, solves them recursively, and combines the results.

---

## When To Use It
Use divide and conquer when a problem can be split into independent subproblems of the same form, the base case is trivial, and the combination step is efficient. Merge sort, quick sort, binary search, and fast matrix multiplication are all divide and conquer. Avoid it when subproblems overlap — that's dynamic programming, not divide and conquer.

---

## Core Concept
Every divide-and-conquer algorithm has three steps: **divide** the input into subproblems, **conquer** each subproblem recursively, and **combine** the results. The complexity follows a recurrence: T(n) = aT(n/b) + f(n), where a is the number of subproblems, n/b is the subproblem size, and f(n) is the divide + combine cost. The Master Theorem solves this recurrence into one of three cases depending on where the work is concentrated.

The key difference from dynamic programming: divide-and-conquer subproblems are **independent** — they don't share sub-subproblems. If you notice the same subproblem being solved multiple times, it's overlapping subproblems and DP is the right tool.

---

## The Code

**Master Theorem reference**
```python
# T(n) = aT(n/b) + f(n)
#
# Case 1: f(n) = O(n^(log_b(a) - ε)) → T(n) = O(n^log_b(a))
#   Work is dominated by subproblems.
#   Example: Binary search — T(n) = T(n/2) + O(1) → O(log n)
#
# Case 2: f(n) = O(n^log_b(a)) → T(n) = O(n^log_b(a) * log n)
#   Work is balanced between subproblems and combining.
#   Example: Merge sort — T(n) = 2T(n/2) + O(n) → O(n log n)
#
# Case 3: f(n) = O(n^(log_b(a) + ε)) → T(n) = O(f(n))
#   Work is dominated by combining.
#   Example: T(n) = T(n/2) + O(n) → O(n)
```

**Merge sort — canonical divide and conquer**
```python
def merge_sort(items: list) -> list:
    if len(items) <= 1:
        return items
    mid = len(items) // 2
    left  = merge_sort(items[:mid])   # conquer left — T(n/2)
    right = merge_sort(items[mid:])   # conquer right — T(n/2)
    return merge(left, right)         # combine — O(n)

def merge(left, right):
    result, i, j = [], 0, 0
    while i < len(left) and j < len(right):
        if left[i] <= right[j]:
            result.append(left[i]); i += 1
        else:
            result.append(right[j]); j += 1
    return result + left[i:] + right[j:]
```

**Maximum subarray — divide and conquer approach**
```python
def max_subarray(nums: list, lo: int, hi: int) -> int:
    if lo == hi:
        return nums[lo]
    mid = (lo + hi) // 2
    left_max  = max_subarray(nums, lo, mid)       # best in left half
    right_max = max_subarray(nums, mid + 1, hi)   # best in right half
    cross_max = max_crossing(nums, lo, mid, hi)   # best spanning the midpoint
    return max(left_max, right_max, cross_max)

def max_crossing(nums, lo, mid, hi):
    left_sum = right_sum = 0
    best_left = best_right = float('-inf')
    s = 0
    for i in range(mid, lo - 1, -1):
        s += nums[i]
        best_left = max(best_left, s)
    s = 0
    for i in range(mid + 1, hi + 1):
        s += nums[i]
        best_right = max(best_right, s)
    return best_left + best_right
```

**Count inversions — divide and conquer piggyback on merge sort**
```python
def count_inversions(nums: list) -> int:
    if len(nums) <= 1:
        return 0
    mid = len(nums) // 2
    left, right = nums[:mid], nums[mid:]
    count = count_inversions(left) + count_inversions(right)
    i = j = k = 0
    while i < len(left) and j < len(right):
        if left[i] <= right[j]:
            nums[k] = left[i]; i += 1
        else:
            nums[k] = right[j]; j += 1
            count += len(left) - i    # all remaining left elements are inversions
        k += 1
    nums[k:] = left[i:] or right[j:]
    return count
```

**Fast power — O(log n) exponentiation**
```python
def fast_pow(base: float, exp: int) -> float:
    if exp == 0:
        return 1
    if exp % 2 == 0:
        half = fast_pow(base, exp // 2)
        return half * half             # reuse — don't compute twice
    return base * fast_pow(base, exp - 1)
```

---

## Gotchas

- **Divide and conquer ≠ dynamic programming.** The defining distinction: D&C subproblems are independent; DP subproblems overlap. Merge sort is D&C. Fibonacci is DP. If you're recomputing the same subproblem, switch to memoization.
- **The combine step determines everything.** An O(n²) combine makes the whole algorithm O(n²) regardless of how cleanly you divide. Always analyze the combine step first when designing a D&C algorithm.
- **Uneven splits degrade performance.** Quick sort on a sorted array with a naive pivot picks the smallest element every time — effectively splitting into sizes (0, n-1). This degrades T(n) = T(n-1) + O(n) to O(n²). Even splitting is what gives O(n log n).
- **Stack depth is O(log n) for balanced splits, O(n) for skewed.** A tree with depth d uses d stack frames. For merge sort that's O(log n). For a skewed quick sort that's O(n) — a stack overflow risk on large inputs.
- **`half * half` not `fast_pow(base, exp//2) * fast_pow(base, exp//2)`.** Computing it twice defeats the purpose. Store the result, then multiply — this is what makes it O(log n) instead of O(n).

---

## Interview Angle

**What they're really testing:** Whether you can identify when a problem decomposes into independent same-shaped subproblems and derive the complexity using the Master Theorem.

**Common question form:** Implement merge sort, find the kth largest element (quick select), maximum subarray, count inversions, pow(x, n).

**The depth signal:** A junior implements merge sort and says it's O(n log n). A senior derives it from T(n) = 2T(n/2) + O(n) via the Master Theorem — Case 2, f(n) = O(n^log_b(a)) = O(n) — and explains why fast power uses `half * half` instead of two recursive calls. They also know exactly where the D&C/DP boundary is and can articulate it with a concrete example.

---

## Related Topics

- [[algorithms/merge-sort.md]] — The canonical D&C sorting algorithm.
- [[algorithms/quick-sort.md]] — D&C with a partition step instead of a merge step.
- [[algorithms/dynamic-programming.md]] — The tool for when D&C subproblems overlap.
- [[algorithms/complexity-analysis.md]] — Master Theorem is the formal tool for D&C recurrences.

---

## Source

https://en.wikipedia.org/wiki/Divide-and-conquer_algorithm

---

*Last updated: 2026-03-24*