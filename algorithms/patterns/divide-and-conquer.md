# Divide and Conquer

> A problem-solving strategy that breaks a problem into independent subproblems of the same type, solves them recursively, and combines the results.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Recursively split → solve independently → combine |
| **Use when** | Problem splits into independent same-shaped subproblems |
| **Avoid when** | Subproblems overlap — use DP instead |
| **C# version** | C# 1.0+ (Task.WhenAll in C# 5+ for parallel D&C) |
| **Namespace** | `System.Threading.Tasks` for parallel variants |
| **Key types** | Recursive methods; `int lo`, `int hi` for index-based splitting |

---

## When To Use It

Use divide and conquer when a problem can be split into independent subproblems of the same form, the base case is trivial, and the combination step is efficient. Merge sort, quicksort, binary search, and fast matrix multiplication are all divide and conquer. Avoid it when subproblems overlap — that's dynamic programming. The test: draw the recursion tree and check whether the same subproblem appears more than once. If yes, it's DP.

---

## Core Concept

Every divide-and-conquer algorithm has three steps: **divide** the input into subproblems, **conquer** each subproblem recursively, and **combine** the results. The complexity follows a recurrence: `T(n) = aT(n/b) + f(n)`, where `a` is the number of subproblems, `n/b` is the subproblem size, and `f(n)` is the divide + combine cost. The Master Theorem solves this recurrence into one of three cases depending on where the work is concentrated.

The key difference from DP: divide-and-conquer subproblems are **independent** — they don't share sub-subproblems. If you notice the same subproblem being solved multiple times, switch to DP.

---

## Algorithm History

| Year | Development |
|---|---|
| 1945 | John von Neumann invents merge sort — first documented D&C algorithm |
| 1962 | Karatsuba multiplication — D&C beats O(n²) naïve multiplication |
| 1969 | Strassen matrix multiplication — D&C sub-cubic for matrices |
| 1971 | Master Theorem formalized by Akra-Bazzi (full form) |
| 1980s | Becomes standard in algorithm curricula (CLRS) |
| 2000s | Parallel D&C via fork/join frameworks (Java ForkJoin, C# Task) |

---

## Performance

| Recurrence | Example | Result | Case |
|---|---|---|---|
| T(n) = T(n/2) + O(1) | Binary search | O(log n) | Master Case 1 |
| T(n) = 2T(n/2) + O(n) | Merge sort | O(n log n) | Master Case 2 |
| T(n) = 4T(n/2) + O(n) | Naive matrix multiply | O(n²) | Master Case 1 |
| T(n) = 2T(n/2) + O(1) | Tree height | O(n) | Master Case 1 |
| T(n) = T(n-1) + O(n) | Naive quicksort worst | O(n²) | Not Master (uneven split) |

**Master Theorem cases:**
- Case 1: `f(n) = O(n^(log_b(a) - ε))` → T(n) = O(n^log_b(a)) — subproblem work dominates
- Case 2: `f(n) = Θ(n^log_b(a))` → T(n) = O(n^log_b(a) × log n) — balanced
- Case 3: `f(n) = Ω(n^(log_b(a) + ε))` → T(n) = O(f(n)) — combine step dominates

**Allocation behaviour:** Stack space is O(log n) for balanced splits (merge sort, binary search). O(n) for skewed splits (naive quicksort on sorted input). Each level of recursion contributes one stack frame.

---

## The Code

**Scenario 1 — merge sort (canonical D&C)**
```csharp
public static int[] MergeSort(int[] arr, int lo, int hi)
{
    if (lo >= hi) return new[] { arr[lo] }; // base case: single element

    int mid = (lo + hi) / 2;
    int[] left  = MergeSort(arr, lo, mid);    // conquer left — T(n/2)
    int[] right = MergeSort(arr, mid + 1, hi); // conquer right — T(n/2)
    return Merge(left, right);                 // combine — O(n)
}

private static int[] Merge(int[] left, int[] right)
{
    var result = new int[left.Length + right.Length];
    int i = 0, j = 0, k = 0;
    while (i < left.Length && j < right.Length)
        result[k++] = left[i] <= right[j] ? left[i++] : right[j++];
    while (i < left.Length)  result[k++] = left[i++];
    while (j < right.Length) result[k++] = right[j++];
    return result;
}
```

**Scenario 2 — count inversions (piggyback on merge step)**
```csharp
public static (int[] Sorted, long Inversions) CountInversions(int[] arr)
{
    if (arr.Length <= 1) return (arr, 0);

    int mid = arr.Length / 2;
    var (leftSorted, leftInv)  = CountInversions(arr[..mid]);
    var (rightSorted, rightInv) = CountInversions(arr[mid..]);

    long splitInv = 0;
    var merged = new int[arr.Length];
    int i = 0, j = 0, k = 0;
    while (i < leftSorted.Length && j < rightSorted.Length)
    {
        if (leftSorted[i] <= rightSorted[j])
            merged[k++] = leftSorted[i++];
        else
        {
            merged[k++] = rightSorted[j++];
            splitInv += leftSorted.Length - i; // all remaining left elements > rightSorted[j]
        }
    }
    while (i < leftSorted.Length)  merged[k++] = leftSorted[i++];
    while (j < rightSorted.Length) merged[k++] = rightSorted[j++];

    return (merged, leftInv + rightInv + splitInv);
}
```

**Scenario 3 — fast power: O(log n) exponentiation**
```csharp
public static double FastPow(double baseNum, long exp)
{
    if (exp == 0)  return 1;
    if (exp < 0)   return 1.0 / FastPow(baseNum, -exp);
    if (exp % 2 == 0)
    {
        double half = FastPow(baseNum, exp / 2);
        return half * half; // reuse — calling FastPow twice would be O(n)
    }
    return baseNum * FastPow(baseNum, exp - 1);
}
```

**Scenario 4 — what NOT to do: confusing D&C with DP (Fibonacci)**
```csharp
// BAD: naive D&C on Fibonacci — O(2^n) because subproblems OVERLAP
// Fib(5) calls Fib(4) and Fib(3). Fib(4) also calls Fib(3). Same subproblem — not D&C territory.
public static long FibDivideConquerBad(int n)
{
    if (n <= 1) return n;
    return FibDivideConquerBad(n - 1) + FibDivideConquerBad(n - 2); // Fib(n-2) is recomputed
}

// GOOD: use DP (memoization) because subproblems overlap
public static long FibDP(int n)
{
    if (n <= 1) return n;
    long a = 0, b = 1;
    for (int i = 2; i <= n; i++) (a, b) = (b, a + b);
    return b; // O(n) time, O(1) space
}
// Rule: if the same subproblem appears more than once in the recursion tree → DP, not D&C.
```

---

## Real World Example

The `ReportAggregatorService` in a business intelligence platform merges sorted report chunks from distributed nodes. Each node produces a sorted list of events. The central service merges N sorted lists into one sorted master report for downstream export. This is a D&C k-way merge — split the N lists into two halves, recursively merge each half, then merge the two results.

```csharp
public class ReportAggregatorService
{
    public record ReportEvent(DateTimeOffset Timestamp, string NodeId, string Message)
        : IComparable<ReportEvent>
    {
        public int CompareTo(ReportEvent? other) =>
            other == null ? 1 : Timestamp.CompareTo(other.Timestamp);
    }

    // Merges N sorted event lists into one sorted master list.
    // D&C approach: split the list of lists in half, recurse on each half, merge the results.
    // Time: O(n log k) where n = total events, k = number of source lists.
    public List<ReportEvent> MergeReports(List<List<ReportEvent>> reports)
    {
        if (reports.Count == 0) return new List<ReportEvent>();
        return MergeRange(reports, 0, reports.Count - 1);
    }

    private List<ReportEvent> MergeRange(List<List<ReportEvent>> reports, int lo, int hi)
    {
        if (lo == hi) return reports[lo]; // base case: single sorted list

        int mid = (lo + hi) / 2;
        var left  = MergeRange(reports, lo, mid);  // conquer
        var right = MergeRange(reports, mid + 1, hi); // conquer
        return MergeSorted(left, right);              // combine
    }

    private List<ReportEvent> MergeSorted(List<ReportEvent> left, List<ReportEvent> right)
    {
        var result = new List<ReportEvent>(left.Count + right.Count);
        int i = 0, j = 0;
        while (i < left.Count && j < right.Count)
        {
            if (left[i].Timestamp <= right[j].Timestamp)
                result.Add(left[i++]);
            else
                result.Add(right[j++]);
        }
        result.AddRange(left.Skip(i));
        result.AddRange(right.Skip(j));
        return result;
    }
}
```

*The key insight: a flat N-way merge comparing all N heads per event is O(n × k). The D&C binary-merge tree reduces it to O(n log k) — the same asymptotic gain merge sort achieves over insertion sort. For k = 32 distributed nodes and n = 1,000,000 events, that's 5 merges instead of 32 comparisons per event.*

---

## Common Misconceptions

**"Divide and conquer and dynamic programming are both recursive — they're the same"**
The defining distinction: D&C subproblems are independent; DP subproblems overlap. Merge sort is D&C — the two halves never share elements. Fibonacci is DP — `Fib(n-2)` is called by both `Fib(n)` and `Fib(n-1)`. Applying D&C to overlapping subproblems gives exponential time where DP gives polynomial.

**"The combine step doesn't matter as long as divide is even"**
The combine step determines everything. Merge sort's O(n log n) comes from an even split (good) and an O(n) merge (good). An O(n²) combine step makes the whole algorithm O(n² log n) regardless of how cleanly you divide. Analyse the combine step first.

**"half * half is the same as FastPow(base, exp/2) called twice"**
Calling `FastPow` twice with the same argument doubles the recursion depth — you get O(n) calls instead of O(log n). Store the result in a variable and square it. This is the entire point of the fast exponentiation algorithm: reuse the already-computed half.

---

## Gotchas

- **Uneven splits degrade performance.** Quicksort on a sorted array with a naive last-element pivot splits into (0, n-1) every time — the recurrence becomes T(n) = T(n-1) + O(n) = O(n²). Even splitting is what gives O(n log n). Always randomise the quicksort pivot.

- **Stack depth is O(log n) for balanced splits, O(n) for skewed.** A depth-n recursion on a skewed split risks `StackOverflowException` on large inputs. For merge sort this doesn't happen (always even splits). For divide-and-conquer on trees or linked lists, ensure you're not dividing unevenly.

- **`half * half` not `FastPow(base, exp/2) * FastPow(base, exp/2)`.** As above — calling the function twice defeats the entire purpose of the algorithm.

- **The Master Theorem doesn't apply to all recurrences.** It requires the form `T(n) = aT(n/b) + f(n)` with constant `a` and `b`. T(n) = T(n-1) + O(n) (uneven split) or T(n) = T(n/2) + T(n/3) + O(n) (unequal splits) require the Akra-Bazzi method, not the standard Master Theorem.

- **D&C on arrays creates subarrays — prefer index passing over slicing.** `arr[lo..mid]` creates a new array in C#. For performance-critical code, pass `(arr, lo, mid)` indices and operate in-place to avoid O(n log n) total allocation.

---

## Interview Angle

**What they're really testing:** Whether you can identify when a problem decomposes into independent same-shaped subproblems, derive the complexity using the Master Theorem, and distinguish D&C from DP.

**Common question forms:**
- "Implement merge sort from scratch."
- "Find the kth largest element (quick select)."
- "Maximum subarray (D&C approach)."
- "Count inversions in an array."
- "Pow(x, n) — implement fast exponentiation."

**The depth signal:** A junior implements merge sort and says O(n log n). A senior derives it from T(n) = 2T(n/2) + O(n) via Master Theorem Case 2, explains why `half * half` is critical in fast power, and articulates the D&C/DP boundary with a concrete example. They also know that D&C is parallelisable (independent subproblems → Task.WhenAll) while DP is not.

**Follow-up questions to expect:**
- "What's the recurrence for this algorithm?" → Walk through the Master Theorem.
- "When would you parallelise this?" → D&C subproblems are independent, so each recursive call can run on a separate thread/task up to the point where overhead exceeds gain.

---

## Related Topics

- [[algorithms/sorting-algorithms/merge-sort.md]] — The canonical D&C sorting algorithm.
- [[algorithms/sorting-algorithms/quick-sort.md]] — D&C with a partition step instead of a merge step.
- [[algorithms/patterns/dynamic-programming.md]] — The tool for when D&C subproblems overlap.
- [[algorithms/complexity/complexity-analysis.md]] — Master Theorem is the formal tool for D&C recurrences.

---

## Source

https://en.wikipedia.org/wiki/Divide-and-conquer_algorithm

---

*Last updated: 2026-04-21*