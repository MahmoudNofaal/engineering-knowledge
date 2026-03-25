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
```csharp
// T(n) = aT(n/b) + f(n)
//
// Case 1: f(n) = O(n^(log_b(a) - ε)) → T(n) = O(n^log_b(a))
//   Work is dominated by subproblems.
//   Example: Binary search — T(n) = T(n/2) + O(1) → O(log n)
//
// Case 2: f(n) = O(n^log_b(a)) → T(n) = O(n^log_b(a) * log n)
//   Work is balanced between subproblems and combining.
//   Example: Merge sort — T(n) = 2T(n/2) + O(n) → O(n log n)
//
// Case 3: f(n) = O(n^(log_b(a) + ε)) → T(n) = O(f(n))
//   Work is dominated by combining.
//   Example: T(n) = T(n/2) + O(n) → O(n)
```

**Merge sort — canonical divide and conquer**
```csharp
public List<int> MergeSort(List<int> items)
{
    if (items.Count <= 1)
        return items;
    int mid = items.Count / 2;
    var left = MergeSort(new List<int>(items.GetRange(0, mid)));  // conquer left — T(n/2)
    var right = MergeSort(new List<int>(items.GetRange(mid, items.Count - mid)));  // conquer right — T(n/2)
    return Merge(left, right);  // combine — O(n)
}

private List<int> Merge(List<int> left, List<int> right)
{
    var result = new List<int>();
    int i = 0, j = 0;
    while (i < left.Count && j < right.Count)
    {
        if (left[i] <= right[j])
            result.Add(left[i++]);
        else
            result.Add(right[j++]);
    }
    result.AddRange(left.GetRange(i, left.Count - i));
    result.AddRange(right.GetRange(j, right.Count - j));
    return result;
}
```

**Maximum subarray — divide and conquer approach**
```csharp
public int MaxSubarray(int[] nums, int lo, int hi)
{
    if (lo == hi)
        return nums[lo];
    int mid = (lo + hi) / 2;
    int leftMax = MaxSubarray(nums, lo, mid);         // best in left half
    int rightMax = MaxSubarray(nums, mid + 1, hi);    // best in right half
    int crossMax = MaxCrossing(nums, lo, mid, hi);    // best spanning the midpoint
    return Math.Max(Math.Max(leftMax, rightMax), crossMax);
}

private int MaxCrossing(int[] nums, int lo, int mid, int hi)
{
    int leftSum = 0, rightSum = 0;
    int bestLeft = int.MinValue, bestRight = int.MinValue;
    int s = 0;
    for (int i = mid; i >= lo; i--)
    {
        s += nums[i];
        bestLeft = Math.Max(bestLeft, s);
    }
    s = 0;
    for (int i = mid + 1; i <= hi; i++)
    {
        s += nums[i];
        bestRight = Math.Max(bestRight, s);
    }
    return bestLeft + bestRight;
}
```

**Count inversions — divide and conquer piggyback on merge sort**
```csharp
public int CountInversions(int[] nums)
{
    return CountInversionsHelper(nums, 0, nums.Length - 1);
}

private int CountInversionsHelper(int[] nums, int left, int right)
{
    if (left >= right)
        return 0;
    int mid = (left + right) / 2;
    int count = CountInversionsHelper(nums, left, mid) + CountInversionsHelper(nums, mid + 1, right);
    var tempLeft = new int[mid - left + 1];
    var tempRight = new int[right - mid];
    Array.Copy(nums, left, tempLeft, 0, mid - left + 1);
    Array.Copy(nums, mid + 1, tempRight, 0, right - mid);
    int i = 0, j = 0, k = left;
    while (i < tempLeft.Length && j < tempRight.Length)
    {
        if (tempLeft[i] <= tempRight[j])
            nums[k++] = tempLeft[i++];
        else
        {
            nums[k++] = tempRight[j++];
            count += tempLeft.Length - i;  // all remaining left elements are inversions
        }
    }
    while (i < tempLeft.Length)
        nums[k++] = tempLeft[i++];
    while (j < tempRight.Length)
        nums[k++] = tempRight[j++];
    return count;
}
```

**Fast power — O(log n) exponentiation**
```csharp
public double FastPow(double baseNum, int exp)
{
    if (exp == 0)
        return 1;
    if (exp % 2 == 0)
    {
        double half = FastPow(baseNum, exp / 2);
        return half * half;  // reuse — don't compute twice
    }
    return baseNum * FastPow(baseNum, exp - 1);
}
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