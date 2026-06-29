---
id: "5.056"
studied_well: false
title: "Permutations and Combinations"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Backtracking"
tags: [dsa, algorithms, backtracking, permutations, combinations, csharp, interviews]
priority: 2
prerequisites:
  - "[[5.055 — Backtracking Template — Choose, Explore, Unchoose]]"
related:
  - "[[5.057 — Subsets and Power Set]]"
  - "[[5.058 — Grid and Board Problems — N-Queens, Sudoku, Word Search]]"
  - "[[5.002 — Recursion and the Call Stack]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Backtracking
**Previous:** [[5.055 — Backtracking Template — Choose, Explore, Unchoose]] | **Next:** [[5.059 — DP Fundamentals — Recognizing Problems, Memoization vs Tabulation]]

### Prerequisites
- [[5.055 — Backtracking Template — Choose, Explore, Unchoose]] — permutations and combinations are direct applications of the backtracking skeleton; the `for`-loop-with-pruning pattern is the same.

### Where This Fits
Permutations and combinations are the two fundamental combinatorial enumeration problems. Every permutation is an ordering of all elements; every combination is a selection of k elements without regard to order. The algorithms for generating them are the foundation for N-Queens (permutation with constraints), subsets (combinations of all sizes), and the "next permutation" problem. They appear in ~10% of interviews as standalone problems and in another ~15% as subproblems of more complex backtracking. A senior candidate must generate both recursively and iteratively, and must understand how to prune or constrain the search space with duplicate handling.

---

## Core Mental Model

A **permutation** of n elements is an arrangement of all n in some order. There are n! of them. The recursive insight: fix the first element (n choices), then recursively permute the remaining n-1.

A **combination** of k elements from n is a selection where order does not matter. There are C(n, k) = n! / (k! × (n-k)!) of them. The recursive insight: each element is either chosen or not, and once chosen, the remaining k-1 come from the remaining n-1.

The key distinction: permutations track **which elements have been used** (a `used` boolean array), while combinations track **which index to start from** (a `start` parameter) to enforce order-agnostic selection.

### Classification

Both are **backtracking** algorithms in the **combinatorial enumeration** paradigm. They are the two canonical applications of the "choose-explore-unchoose" skeleton.

```mermaid
graph TD
    subgraph "Combinatorial Enumeration"
        BT[Backtracking Template<br>Choose → Explore → Unchoose]
        P[Permutations<br>n choices at level 0<br>n-1 at level 1<br>... total: n!]
        C[Combinations<br>choose or skip each element<br>total: C(n,k)]
        S[Subsets<br>choose or skip each element<br>total: 2ⁿ]
    end

    BT --> P
    BT --> C
    BT --> S
```

### Key Properties

|Property|Permutations|Combinations|Derivation|
|---|---|---|---|
|Count|n!|C(n, k)|n! = n × (n-1) × ... × 1; C(n,k) = n! / (k! × (n-k)!)|
|Time|O(n × n!)|O(k × C(n, k))|Each leaf costs O(n) or O(k) to copy the current path|
|Space|O(n)|O(k)|Recursion depth equals selection size (n or k)|
|Algorithm|Swap-based or used[]|Start-index-based|Permutations need order tracking; combinations use start index|
|Duplicates|Sort + skip same value after used[i-1] reset|Sort + skip same value at same start level|Both require sorted input and neighbor-skip pruning|

---

## Deep Mechanics

### How It Works

**Permutations — swap-based (no extra space):**
At each level i, swap element i with each element j ≥ i, then recurse on i+1. The swap generates a new ordering without extra allocation. The used[] array approach tracks which elements are already placed in path.

Trace on `[1, 2, 3]` via used[]:
```
path=[], used=[F,F,F]
Level 0: try i=0 (1), i=1 (2), i=2 (3)
  pick 1 → path=[1], used=[T,F,F]
    Level 1: try i=0 (used), i=1 (2), i=2 (3)
      pick 2 → path=[1,2], used=[T,T,F]
        Level 2: try i=0 (used), i=1 (used), i=2 (3) → pick 3 → [1,2,3] ✓
        unchoose 3
      pick 3 → path=[1,3], used=[T,F,T]
        Level 2: try i=1 (2) → pick 2 → [1,3,2] ✓
      unchoose 2, unchoose 3
    unchoose 1
  pick 2 → path=[2], used=[F,T,F]
    Level 1: try i=0 (1), i=1 (used), i=2 (3)
      ...
```

**Combinations — start-index-based:**
At each level, try elements from `start` to `n`, placing each in `path[start]`. The start parameter enforces order: once element i is chosen, only elements > i can be chosen after it.

Trace on `C(4, 2)`:
```
path=[], start=0, level=0
Level 0: try i=0→3
  pick 0 → path=[0]
    Level 1: start=1, try i=1→3
      pick 1 → path=[0,1] ✓
      pick 2 → path=[0,2] ✓
      pick 3 → path=[0,3] ✓
  pick 1 → path=[1]
    Level 1: start=2, try i=2→3
      pick 2 → path=[1,2] ✓
      pick 3 → path=[1,3] ✓
  pick 2 → path=[2]
    Level 1: start=3, pick 3 → path=[2,3] ✓
  pick 3 → path=[3] → start=4, no more elements
```

### Complexity Derivation

**Permutations:** At level 0, n choices. At level 1, n-1 choices. At level k, n-k choices. Total leaf nodes: n × (n-1) × ... × 1 = n!. Each leaf requires copying the path (O(n)). Total work: O(n × n!) comparisons and swaps, plus O(n × n!) for copying results.

**Combinations:** At level 0, choose from n elements. At level 1, choose from n-1 elements (those after the chosen one). Total leaf nodes: C(n, k). Each leaf requires O(k) to copy. Total work: O(k × C(n, k)).

**Space:** Each recursive call adds a stack frame. Depth is n for permutations (select all n elements), k for combinations (select k elements). Space: O(n) for permutations, O(k) for combinations.

### Why This Pattern Exists

The brute force for enumerating permutations is n nested loops — which is impossible when n is unknown at compile time. Recursive backtracking replaces the nested loops with a single loop that recurses, handling any n. The insight for combinations is that order does not matter, so "choosing {1, 2}" is the same as "choosing {2, 1}" — the start-index parameter eliminates the symmetric duplicates, reducing the search space from n! to C(n, k).

---

## Implementation and Problem Patterns

### C# Implementation

```csharp
/// <summary>
/// Generate all permutations of distinct integers.
/// </summary>
public IList<IList<int>> Permute(int[] nums)
{
    var result = new List<IList<int>>();
    var path = new List<int>();
    var used = new bool[nums.Length];
    BacktrackPermute(nums, used, path, result);
    return result;
}

private void BacktrackPermute(int[] nums, bool[] used, List<int> path, List<IList<int>> result)
{
    if (path.Count == nums.Length)
    {
        result.Add([.. path]);
        return;
    }

    for (int i = 0; i < nums.Length; i++)
    {
        if (used[i]) continue;

        used[i] = true;
        path.Add(nums[i]);
        BacktrackPermute(nums, used, path, result);
        path.RemoveAt(path.Count - 1);
        used[i] = false;
    }
}

/// <summary>
/// Generate all permutations of integers that may contain duplicates.
/// </summary>
public IList<IList<int>> PermuteUnique(int[] nums)
{
    Array.Sort(nums);
    var result = new List<IList<int>>();
    var path = new List<int>();
    var used = new bool[nums.Length];
    BacktrackPermuteUnique(nums, used, path, result);
    return result;
}

private void BacktrackPermuteUnique(int[] nums, bool[] used, List<int> path, List<IList<int>> result)
{
    if (path.Count == nums.Length)
    {
        result.Add([.. path]);
        return;
    }

    for (int i = 0; i < nums.Length; i++)
    {
        if (used[i]) continue;
        // Skip duplicate: same value as previous, and previous was NOT used (reset at this level)
        if (i > 0 && nums[i] == nums[i - 1] && !used[i - 1]) continue;

        used[i] = true;
        path.Add(nums[i]);
        BacktrackPermuteUnique(nums, used, path, result);
        path.RemoveAt(path.Count - 1);
        used[i] = false;
    }
}

/// <summary>
/// Generate all combinations of k elements from [1..n].
/// </summary>
public IList<IList<int>> Combine(int n, int k)
{
    var result = new List<IList<int>>();
    var path = new List<int>();
    BacktrackCombine(n, k, 1, path, result);  // 1-indexed
    return result;
}

private void BacktrackCombine(int n, int k, int start, List<int> path, List<IList<int>> result)
{
    if (path.Count == k)
    {
        result.Add([.. path]);
        return;
    }

    // Optimization: stop early if not enough elements remain
    int remaining = k - path.Count;
    for (int i = start; i <= n - remaining + 1; i++)
    {
        path.Add(i);
        BacktrackCombine(n, k, i + 1, path, result);
        path.RemoveAt(path.Count - 1);
    }
}

/// <summary>
/// Combination Sum — find all unique combinations that sum to target.
/// Elements may be reused.
/// </summary>
public IList<IList<int>> CombinationSum(int[] candidates, int target)
{
    Array.Sort(candidates);
    var result = new List<IList<int>>();
    var path = new List<int>();
    BacktrackCombinationSum(candidates, target, 0, 0, path, result);
    return result;
}

private void BacktrackCombinationSum(int[] candidates, int target, int start, int sum, List<int> path, List<IList<int>> result)
{
    if (sum == target)
    {
        result.Add([.. path]);
        return;
    }

    for (int i = start; i < candidates.Length; i++)
    {
        if (sum + candidates[i] > target) break;  // Since sorted

        path.Add(candidates[i]);
        BacktrackCombinationSum(candidates, target, i, sum + candidates[i], path, result);
        path.RemoveAt(path.Count - 1);
    }
}
```

### The .NET Idiomatic Version

There is no built-in permutation or combination generator in .NET. For production code that needs combinatorial enumeration, use the iterative `NextPermutation` algorithm (lexicographic order) or a third-party library like `MoreLinq`. The recursive backtracking above is the interview-grade implementation.

The iterative "next permutation" (std::next_permutation equivalent):

```csharp
public static bool NextPermutation(int[] nums)
{
    // Find first decreasing element from the right
    int i = nums.Length - 2;
    while (i >= 0 && nums[i] >= nums[i + 1]) i--;

    if (i < 0) return false;  // Already the last permutation

    // Find the element just larger than nums[i]
    int j = nums.Length - 1;
    while (nums[j] <= nums[i]) j--;

    Swap(nums, i, j);
    Array.Reverse(nums, i + 1, nums.Length - i - 1);
    return true;
}

private static void Swap(int[] nums, int i, int j)
{
    (nums[i], nums[j]) = (nums[j], nums[i]);
}
```

### Classic Problem Patterns

- **Permutations (distinct)** — Generate all orderings of distinct elements. Use used[] array or swap-based recursion. O(n × n!).
- **Permutations (with duplicates)** — Sort input, skip duplicate elements at the same recursion level when the previous identical element was not used (was reset at that level). The condition: `if (i > 0 && nums[i] == nums[i-1] && !used[i-1]) continue`.
- **Combinations (C(n,k))** — Select k elements from [1..n] without order. Use start-index parameter; the early break `i <= n - remaining + 1` prunes when insufficient elements remain.
- **Combination Sum** — Find all combinations that sum to a target, elements reusable. Sort and prune when sum exceeds target; pass `i` (not `i+1`) as next start to allow reuse.
- **Combination Sum II (no reuse)** — Like Combination Sum but each element used at most once. Pass `i+1` as next start; skip duplicates at the same level.
- **Letter Combinations of a Phone Number** — Generate all strings from digit-to-letter mapping. The combinatorial product of digit options: recursive for-loop over each digit's letters.

### Template / Skeleton

```csharp
// Permutations Template (used[] approach)
// When to use: generate all orderings of elements
// Time: O(n × n!) | Space: O(n)

public IList<IList<int>> PermuteTemplate(int[] nums)
{
    var result = new List<IList<int>>();
    var path = new List<int>();
    var used = new bool[nums.Length];
    Backtrack(nums, used, path, result);
    return result;
}

private void Backtrack(int[] nums, bool[] used, List<int> path, List<IList<int>> result)
{
    if (/* TODO: base case — path is complete */)
    {
        result.Add([.. path]);
        return;
    }

    for (int i = 0; i < nums.Length; i++)
    {
        // TODO: Pruning — skip used elements or duplicates
        if (/* not a valid choice */) continue;

        // Choose
        used[i] = true;
        path.Add(nums[i]);

        // Explore
        Backtrack(nums, used, path, result);

        // Unchoose
        path.RemoveAt(path.Count - 1);
        used[i] = false;
    }
}

// Combinations Template (start-index approach)
// When to use: select k elements from n without order
// Time: O(k × C(n,k)) | Space: O(k)

public IList<IList<int>> CombineTemplate(int n, int k)
{
    var result = new List<IList<int>>();
    var path = new List<int>();
    BacktrackCombine(n, k, /* start */ 1, path, result);
    return result;
}

private void BacktrackCombine(int n, int k, int start, List<int> path, List<IList<int>> result)
{
    if (/* TODO: path.Count == k */)
    {
        result.Add([.. path]);
        return;
    }

    int remaining = k - path.Count;
    for (int i = start; i <= /* TODO: n - remaining + 1 */; i++)
    {
        path.Add(i);
        // TODO: Recurse with start = i + 1
        BacktrackCombine(n, k, i + 1, path, result);
        path.RemoveAt(path.Count - 1);
    }
}
```

---

## Gotchas and Edge Cases

### Duplicate Handling in Permutations — Wrong Skip Condition

**Mistake:** Using the subsets skip condition (`if (i > start && nums[i] == nums[i-1])`) for permutations.

```csharp
// ❌ Wrong — permutations don't have a meaningful `start` parameter
for (int i = 0; i < nums.Length; i++)
{
    if (i > 0 && nums[i] == nums[i - 1]) continue;  // Skips valid permutations
    ...
}
```

**Fix:** Use the `used[i-1]` condition: skip when the previous identical element was not used at this recursion level.

```csharp
// ✅ Correct
if (i > 0 && nums[i] == nums[i - 1] && !used[i - 1]) continue;
```

**Consequence:** With `!used[i-1]`, when the previous identical element is already in the current path (used[i-1] is true), the current duplicate IS allowed — it's a different position in the permutation. The skip only fires when both are at the same recursion level, preventing duplicate permutations.

### Combinations — Missing Early Break

**Mistake:** Not terminating the loop early when insufficient elements remain.

```csharp
// ❌ Wrong — wastes iterations on impossible choices
for (int i = start; i <= n; i++)
```

**Fix:** Stop when not enough elements are left to form a complete combination.

```csharp
// ✅ Correct
int remaining = k - path.Count;
for (int i = start; i <= n - remaining + 1; i++)
```

**Consequence:** Without the early break, the loop continues making recursive calls that immediately hit the base case (no elements left), adding unnecessary stack frames and wasting time.

### Path Copy — Capturing by Reference

**Mistake:** Adding the path reference directly instead of a copy.

```csharp
// ❌ Wrong — result ends up with multiple references to the same list
result.Add(path);
```

**Fix:** Add a copy of the current path.

```csharp
// ✅ Correct
result.Add([.. path]);
```

**Consequence:** All entries in result reference the same List<int> object. After backtracking completes, the list is empty, and result contains `[[], [], []]`.

### Combination Sum — Forgetting to Sort Before Pruning

**Mistake:** Breaking the loop early without sorting the input first.

```csharp
// ❌ Wrong — unsorted input: candidates = [3, 2, 1], target = 3
// Loop tries 3: sum=3 → found solution. Then breaks because 2 > 3? No, 2 < 3 but 2 is after 3.
// Without sorting, you cannot prune early with break.
```

**Fix:** Sort candidates before calling backtrack.

```csharp
// ✅ Correct
Array.Sort(candidates);
```

**Consequence:** Unsorted input prevents the `if (sum + candidates[i] > target) break` pruning from being correct — a larger element early in the iteration would block valid solutions with smaller elements later in the array.

---

## Complexity Analysis and Benchmarks

### Operation Complexity Table

|Operation|Generation Count|Time|Space|Notes|
|---|---|---|---|---|
|Permutations (distinct)|n!|O(n × n!)|O(n)|Each leaf: O(n) copy; each internal node: O(1)|
|Permutations (duplicates)|n! / (multiset)|O(n × n!')|O(n)|Duplicates reduce leaf count; same per-leaf cost|
|Combinations C(n,k)|C(n, k)|O(k × C(n, k))|O(k)|Early break prunes impossible branches|
|Combination Sum|Variable|O(2ⁿ) worst|O(target/min)|Dependent on target and candidates|
|Next Permutation (iterative)|1|O(n)|O(1)|Lexicographic next; reversing a suffix|

**Derivation for the non-obvious entries:** Combination Sum worst case is O(2ⁿ) when candidates = [1] and target = n — every subset of 1s of every size 1..n is a valid combination. The branching factor is 1 (always pick 1 again), but the depth is n, producing 2ⁿ subsets.

### Comparison with Alternatives

|Approach|Time|Space|Best When|
|---|---|---|---|
|Backtracking (recursive)|O(n × n!) or O(k × C(n,k))|O(n) or O(k)|Need all permutations or combinations explicitly|
|Next Permutation (iterative)|O(n) per call|O(1)|Need to process permutations one at a time in lexicographic order|
|Gray code (iterative)|O(2ⁿ)|O(1)|Binary representation of subsets; less intuitive|

### BenchmarkDotNet

```csharp
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net90)]
public class CombinatorialBenchmark
{
    [Params(6, 8, 10)]
    public int N { get; set; }

    [Benchmark]
    public int PermuteBacktrack()
    {
        int[] nums = new int[N];
        for (int i = 0; i < N; i++) nums[i] = i;
        var result = new List<IList<int>>();
        var path = new List<int>();
        var used = new bool[N];
        void Dfs()
        {
            if (path.Count == N) { result.Add([.. path]); return; }
            for (int i = 0; i < N; i++)
            {
                if (used[i]) continue;
                used[i] = true; path.Add(nums[i]);
                Dfs();
                path.RemoveAt(path.Count - 1); used[i] = false;
            }
        }
        Dfs();
        return result.Count;
    }

    [Benchmark]
    public int PermuteIterative()
    {
        int[] nums = new int[N];
        for (int i = 0; i < N; i++) nums[i] = i;
        int count = 1;
        while (NextPermutation(nums)) count++;
        return count;
    }

    private static bool NextPermutation(int[] nums)
    {
        int i = nums.Length - 2;
        while (i >= 0 && nums[i] >= nums[i + 1]) i--;
        if (i < 0) return false;
        int j = nums.Length - 1;
        while (nums[j] <= nums[i]) j--;
        (nums[i], nums[j]) = (nums[j], nums[i]);
        Array.Reverse(nums, i + 1, nums.Length - i - 1);
        return true;
    }
}
```

**Expected results (approximate, .NET 9, x64):**

|Method|N|Mean|Allocated|
|---|---|---|---|
|PermuteBacktrack|6|~5 μs|~50 KB|
|PermuteIterative|6|~2 μs|0 B|
|PermuteBacktrack|8|~400 μs|~5 MB|
|PermuteIterative|8|~100 μs|0 B|
|PermuteBacktrack|10|~40 ms|~500 MB|
|PermuteIterative|10|~8 ms|0 B|

**Interpretation:** Both algorithms generate n! permutations. The iterative (next_permutation) is faster and allocates zero memory because it modifies the array in place. The backtracking allocates a new list per permutation. For N = 10, the backtrack generates 3.6M permutations and allocates ~500 MB for the copies.

---

## Interview Arsenal

### Question Bank

1. What is the difference between generating permutations and generating combinations?
2. How does the duplicate-handling condition `!used[i-1]` work for permutations?
3. Implement the "next permutation" algorithm in lexicographic order.
4. Given a list with duplicates, how many unique permutations does it have, and how would you generate them?
5. Compare the swap-based permutation generation with the used[] array approach — which is better and when?
6. The `NextPermutation` algorithm returns false when the array is in descending order (last permutation). Why is this the correct behavior?
7. How would you generate combinations of size k without recursion (iterative)?
8. Optimize the combination generation to avoid the `[.. path]` copy on every leaf.
9. In a production system, when would you choose the iterative `NextPermutation` over the recursive backtracking?

### Spoken Answers

**Q: What is the difference between generating permutations and generating combinations?**

> **Average answer:** Permutations care about order. Combinations do not.

> **Great answer:** Permutations and combinations differ on whether order matters. A permutation of n elements is an arrangement — every element appears exactly once, and [1, 2, 3] is different from [2, 1, 3]. There are n! permutations for n distinct elements. The recursive structure is: pick any unused element as the first, then permute the remaining n-1. This requires a `used` boolean array to track which elements have been placed. A combination of k elements from n is a selection — [1, 2] is the same as [2, 1]. There are C(n, k) = n! / (k! × (n-k)!) combinations. The recursive structure uses a `start` index: pick element i (only from positions ≥ start), then choose k-1 from positions i+1 to n. The start index enforces a canonical order, eliminating the symmetric duplicates. The same template generates subsets by allowing k to vary from 0 to n.

**Q: How does the duplicate-handling condition work for permutations?**

> **Average answer:** Sort the input, then skip duplicate values when backtracking.

> **Great answer:** For permutations with duplicates, the standard `used[]` approach would generate identical permutations because swapping two identical elements at different positions produces the same ordering. The fix is: sort the input first, then during the for loop, if `nums[i] == nums[i-1]` AND `!used[i-1]`, skip nums[i]. The condition `!used[i-1]` is the key — it means "the previous identical element was available at this level of recursion but was not chosen." This fires when we have exhausted all permutations starting with the previous identical value and are now at the same recursion level trying the same value. If `used[i-1]` is true (the previous identical element is already in the path), then nums[i] can be chosen — it's a different position in the permutation. This condition is often described as "skip if the previous identical element was reset at this level."

**Q: Implement the NextPermutation algorithm.**

> **Average answer:** Find the first decreasing element from the right, swap it with the next larger element, then reverse the suffix.

> **Great answer:** The algorithm has three steps. First, find the largest index i such that nums[i] < nums[i+1] — scanning from right to left. If no such i exists, the array is in descending order, which is the last permutation; return false. Second, find the largest index j > i such that nums[j] > nums[i] — this is the smallest element in the suffix that is larger than nums[i]. Swap nums[i] and nums[j]. Third, reverse the suffix from i+1 to the end. After the swap, the suffix is in descending order (by construction — the suffix was descending before the swap, and swapping preserves the descending property). Reversing it gives the smallest possible suffix, which is the lexicographically next permutation. This algorithm is O(n) and modifies the array in place with no extra allocation. It is the C# equivalent of C++'s `std::next_permutation`.

### Trick Question

**"To generate all permutations of n elements, the backtracking algorithm takes O(n × n!) time, but the iterative `NextPermutation` takes O(n) per permutation — so they are the same complexity."**

Why it is a trap: The statement is technically true (both are O(n × n!)) but misleading. The constant factor differs significantly: the backtracking allocates O(n) memory per permutation (copying the path list), leading to massive GC pressure and memory bandwidth usage. The iterative version modifies the array in place and allocates nothing per permutation. For n = 12 (479M permutations), the backtracking would exhaust available memory, while the iterative version would run (slowly but without memory thrashing).

Correct answer: Both have the same asymptotic complexity, but the iterative NextPermutation is substantially faster in practice due to zero allocation and better cache locality. Use iterative when memory is constrained or n is large; use backtracking when you need to collect all permutations in a list or apply early pruning.

### Pattern Recognition Table

|If the problem has...|Then consider...|Because...|
|---|---|---|
|"All possible orderings" or "arrangements"|Permutations (used[] array)|Order matters; every element used exactly once|
|"All possible selections of k elements"|Combinations (start parameter)|Order does not matter; choose k from n|
|Input contains duplicates; outputs must be unique|Sort + neighbor-skip pruning|Without dedup, the same permutation/combination appears multiple times|
|"Next lexicographically larger arrangement"|NextPermutation (iterative)|Single-step increment in lexicographic order; no recursion needed|
|Elements can be reused (unlimited times)|Combination Sum (pass i not i+1)|Reuse means the next recursion can pick the same element again|

---

## Decision Framework

### When to Apply

```mermaid
flowchart TD
    A[Generate all arrangements/selections] --> B{Does order matter?}
    B -->|Yes — arrangements| C{All elements used?}
    B -->|No — selections| D{Fixed size k?}
    C -->|Yes| E[Permutations — used[]]
    C -->|No — reuse allowed| F[Combination Sum — start=i]
    D -->|Yes| G[Combinations — start index]
    D -->|No — all sizes| H[Subsets — include/exclude]
    E --> I{Duplicates?}
    I -->|Yes| J[Sort + !used[i-1] skip]
    I -->|No| K[Standard backtrack]
```

### Recognition Checklist

Indicators that the permutations pattern applies:

- [ ] "All possible orderings" or "arrangements" or "sequences" of input elements
- [ ] Every element appears exactly once in each output
- [ ] Output orderings are permutations of the input set

Indicators that the combinations pattern applies:

- [ ] "All possible selections of k elements"
- [ ] "Choose k" or "subsets of size k"
- [ ] Order does not matter — [1, 2] and [2, 1] are the same

### Tradeoff Summary

|What You Gain|What You Give Up|
|---|---|
|Simple recursive structure that mirrors the combinatorial definition|O(n × n!) time — factorial growth is unavoidable|
|Used[] vs start-index clearly separates permutations from combinations|Backtracking copies the path at each leaf — significant allocation overhead|
|Duplicate pruning is a single condition after sorting|Sorting changes the input; must copy or accept mutation|

---

## Self-Check

### Conceptual Questions

1. Why do permutations use a `used` array while combinations use a `start` parameter?
2. Derive the total number of permutations and combinations for n = 5, k = 3.
3. How does the duplicate skip condition `!used[i-1]` prevent duplicate permutations but still generate correct ones?
4. What is the time complexity of `NextPermutation` and why does it work?
5. How would you generate all permutations of a string with distinct characters?
6. In .NET, how would you implement a generic `Permutations<T>` method? What are the constraints?
7. Why does the combination loop break at `n - remaining + 1` instead of `n`?
8. How does combination sum (unlimited reuse) differ from standard combinations?
9. In a poker hand evaluator, how would you generate all 5-card combinations from a 52-card deck? Is C(52, 5) feasible to enumerate?

<details>
<summary>Answers</summary>

1. Permutations must track which elements are already placed because order matters — at each level, any unused element can be next. Combinations enforce a canonical order (picked elements are sorted by their original index), so only the start parameter is needed to avoid generating [1,2] and [2,1] separately.
2. Permutations: 5! = 120. Combinations: C(5,3) = 5! / (3! × 2!) = 10.
3. The condition fires when nums[i] == nums[i-1] and used[i-1] is false (was reset at this level). This means we have already generated all permutations starting with nums[i-1] and are now considering the same value at the same position — which would produce duplicates. If used[i-1] is true, nums[i-1] is already placed elsewhere in the permutation, so nums[i] is a distinct element value at a different position.
4. O(n): find the pivot (O(n)), find the swap target (O(n)), reverse the suffix (O(n)). It works because: (1) the suffix after the pivot is decreasing (otherwise the pivot would have been found later), (2) swapping the pivot with the smallest larger element preserves the decreasing suffix order, (3) reversing gives the smallest possible suffix.
5. Same algorithm as integers: convert string to char[], permute using used[] array, convert path back to string for each result. Or use swap-based recursion.
6. `IList<IList<T>> Permute<T>(T[] nums)` requires T to implement `IEquatable<T>` for used[] tracking. The List<T> path stores references, so copies must use `new List<T>(path)` or `path.ToList()`.
7. `n - remaining + 1` ensures there are at least `remaining` elements to pick from. If i exceeds this bound, even taking all remaining elements (i, i+1, ..., n) cannot fill the combination. This prunes unreachable branches.
8. Combination Sum allows reusing elements: `start = i` instead of `i + 1`. It also sorts and prunes when `sum + candidates[i] > target`. The base case is `sum == target` instead of `path.Count == k`.
9. C(52, 5) = 2,598,960 — feasible to enumerate. The recursion would use start-index combinations with n=52, k=5. At ~3 million leaves, each requiring a 5-element copy, total memory is ~60 MB for all combinations, or stream them one at a time.

</details>

---

### Coding Challenges

**Challenge 1 — Implement from scratch**

Implement a function that generates all permutations of a string with distinct characters using the swap-based approach (no used[] array, swap elements in place).

```csharp
public IList<string> PermuteString(string s)
{
    // Your implementation here
}
```

<details> <summary>Solution</summary>

```csharp
public IList<string> PermuteString(string s)
{
    var result = new List<string>();
    char[] arr = s.ToCharArray();
    PermuteSwap(arr, 0, result);
    return result;
}

private void PermuteSwap(char[] arr, int index, List<string> result)
{
    if (index == arr.Length - 1)
    {
        result.Add(new string(arr));
        return;
    }

    for (int i = index; i < arr.Length; i++)
    {
        Swap(arr, index, i);     // Choose: place arr[i] at position index
        PermuteSwap(arr, index + 1, result);  // Explore: permute remaining
        Swap(arr, index, i);     // Unchoose: restore original order
    }
}

private static void Swap(char[] arr, int i, int j)
{
    (arr[i], arr[j]) = (arr[j], arr[i]);
}
```

**Complexity:** Time O(n × n!) | Space O(n) recursion depth **Key insight:** Swaps generate the permutation in-place without a used[] array or path list. Each swap places an element at the current position, and the undo-swap restores it.

</details>

---

**Challenge 2 — Trace the execution**

Trace the combination generation for C(5, 3). Show the recursion tree for the first branch (starting from 1).

<details> <summary>Solution</summary>

```
Level 0 (k=3, start=1):
  i=1: path=[1], remaining=2
    Level 1 (start=2):
      i=2: path=[1,2], remaining=1
        Level 2 (start=3):
          i=3: path=[1,2,3] → output ✓ (remaining 0 after this, but:)
            remaining=2-2=0, n-remaining+1 = 5-0+1=6, loop i=3..5
          i=4: path=[1,2,4] → output ✓
          i=5: path=[1,2,5] → output ✓
      i=3: path=[1,3], remaining=1
        Level 2 (start=4):
          i=4: path=[1,3,4] → output ✓
          i=5: path=[1,3,5] → output ✓
      i=4: path=[1,4], remaining=1
        Level 2 (start=5):
          i=5: path=[1,4,5] → output ✓
      i=5: n-remaining+1=5-1+1=5, i=5 ≤ 5 → loop runs
        path=[1,5], remaining=1 → Level 2 start=6 → i loop from 6 to 5 → no iterations
```

Continue with Level 0 starting from 2, 3...

**Why:** The early break `n - remaining + 1` stops the loop at i=5 for the first sub-branch (remaining=1), and at i=3 for the root level (remaining=3, so n-3+1=3).

</details>

---

**Challenge 3 — Fix the bug**

```csharp
// This generates permutations of [1, 2, 3] but has a bug.
// The output contains duplicate permutations.
public IList<IList<int>> Permute(int[] nums)
{
    var result = new List<IList<int>>();
    var path = new List<int>();
    Dfs(nums, path, result);
    return result;
}

private void Dfs(int[] nums, List<int> path, List<IList<int>> result)
{
    if (path.Count == nums.Length)
    {
        result.Add(new List<int>(path));
        return;
    }

    for (int i = 0; i < nums.Length; i++)
    {
        path.Add(nums[i]);
        Dfs(nums, path, result);
        path.RemoveAt(path.Count - 1);
    }
}
```

<details> <summary>Solution</summary>

**Bug:** No `used[]` tracking — the algorithm picks the same element multiple times within a single permutation. At level 0, it picks 1, then at level 1 it can pick 1 again, producing [1, 1, 2] which is invalid.

**Fix:** Add a `used` boolean array to track which elements are already in the path.

```csharp
public IList<IList<int>> Permute(int[] nums)
{
    var result = new List<IList<int>>();
    var path = new List<int>();
    var used = new bool[nums.Length];
    Dfs(nums, used, path, result);
    return result;
}

private void Dfs(int[] nums, bool[] used, List<int> path, List<IList<int>> result)
{
    if (path.Count == nums.Length)
    {
        result.Add([.. path]);
        return;
    }

    for (int i = 0; i < nums.Length; i++)
    {
        if (used[i]) continue;
        used[i] = true;
        path.Add(nums[i]);
        Dfs(nums, used, path, result);
        path.RemoveAt(path.Count - 1);
        used[i] = false;
    }
}
```

**Test case that exposes it:** `Permute([1, 2])` → original returns `[[1,1],[1,2],[2,1],[2,2]]` — invalid entries. After fix: `[[1,2],[2,1]]`.

</details>

---

**Challenge 4 — Recognize and apply**

**Problem:** Given an array of distinct integers and a target sum, find all unique combinations where chosen numbers sum to target. You may reuse elements. The array is [2, 3, 6, 7] and target is 7. Return [[2,2,3],[7]].

<details> <summary>Solution</summary>

**Pattern:** Combination Sum — backtracking with start=i for unlimited reuse, sorted candidates for pruning.

```csharp
public IList<IList<int>> CombinationSum(int[] candidates, int target)
{
    Array.Sort(candidates);
    var result = new List<IList<int>>();
    var path = new List<int>();
    Dfs(candidates, target, 0, 0, path, result);
    return result;
}

private void Dfs(int[] candidates, int target, int start, int sum, List<int> path, List<IList<int>> result)
{
    if (sum == target)
    {
        result.Add([.. path]);
        return;
    }

    for (int i = start; i < candidates.Length; i++)
    {
        if (sum + candidates[i] > target) break;
        path.Add(candidates[i]);
        Dfs(candidates, target, i, sum + candidates[i], path, result);
        path.RemoveAt(path.Count - 1);
    }
}
```

**Complexity:** Time O(2^(target/minCandidate)) | Space O(target/min) **Key insight:** Passing `i` (not `i+1`) as the next start allows reusing the same element.

</details>

---

**Challenge 5 — Optimize**

```csharp
// This generates all subsets of size k from n. It creates a new list at every leaf.
// Optimize to reduce allocations while maintaining correctness.
public IList<IList<int>> Combine(int n, int k)
{
    var result = new List<IList<int>>();
    var path = new int[k];
    Dfs(n, k, 0, 1, path, result);
    return result;
}

private void Dfs(int n, int k, int depth, int start, int[] path, List<IList<int>> result)
{
    if (depth == k)
    {
        result.Add(path.ToList());  // Allocates new list per leaf
        return;
    }

    for (int i = start; i <= n; i++)
    {
        path[depth] = i;
        Dfs(n, k, depth + 1, i + 1, path, result);
    }
}
```

<details> <summary>Solution</summary>

**Insight:** The function already uses an `int[]` for the path, avoiding `List<T>` overhead. The allocation is in `path.ToList()` at each leaf. We can avoid this by using `result.Add((int[])path.Clone())` — but that still allocates. The only way to truly zero-allocate is to use callbacks instead of collecting results, or generate results in a memory-efficient way. For the interview, the `path.ToList()` allocation is acceptable. A micro-optimization is to use a `resultArray` of pre-allocated arrays:

```csharp
// ✅ Eliminates LINQ .ToList()
private void Dfs(int n, int k, int depth, int start, int[] path, List<IList<int>> result)
{
    if (depth == k)
    {
        result.Add([.. path]);  // Collection expression — still allocates, but faster than ToList()
        return;
    }

    int remaining = k - depth;
    for (int i = start; i <= n - remaining + 1; i++)
    {
        path[depth] = i;
        Dfs(n, k, depth + 1, i + 1, path, result);
    }
}
```

**Complexity:** Time O(k × C(n,k)) | Space O(k) + O(C(n,k) × k) for output — the allocation at each leaf is unavoidable if we need to return all combinations.

</details>
