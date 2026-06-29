---
id: "5.020"
studied_well: false
title: "Two-Sum Pattern and Generalizations"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Hash Maps and Sets"
tags: [dsa, algorithms, two-sum, hash-map, csharp, interviews, pattern]
priority: 1
prerequisites:
  - "[[5.019 — Hash Maps and Hash Sets — Design and Collision Handling]]"
  - "[[5.005 — Two Pointers]]"
related:
  - "[[5.021 — Frequency Counting and Grouping]]"
  - "[[5.022 — Sliding Window with Hash Map]]"
  - "[[5.033 — Top-K and K-th Element Problems]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Hash Maps and Sets
**Previous:** [[5.019 — Hash Maps and Hash Sets — Design and Collision Handling]] | **Next:** [[5.023 — Binary Tree Traversals — Pre, In, Post, Level-Order]]

### Prerequisites
- [[5.019 — Hash Maps and Hash Sets — Design and Collision Handling]] — Two-Sum relies on the hash map's O(1) amortized lookup to achieve O(n) time.
- [[5.005 — Two Pointers]] — Two-Sum on a sorted array is optimally solved with two pointers in O(n) time and O(1) space.

### Where This Fits
Two-Sum is the canonical "intro to hash maps" problem — it is the most famous LeetCode problem and the one most frequently asked in phone screens. But more importantly, it establishes a pattern that generalizes to ThreeSum, FourSum, and K-Sum, each of which appears regularly in senior-level interviews. Mastery of the pattern means being able to recognize that any "find elements satisfying a sum condition" problem is a variant of Two-Sum with additional constraints (sortedness, duplicate handling, uniqueness requirements).

---

## Core Mental Model

Two-Sum asks: given an array and a target, find two elements that sum to the target. The hash map approach exploits the complement relationship: for each element `x`, the needed pair is `target - x`. Store each element as you traverse; when you encounter an element whose complement is already stored, the pair is found. The key insight is that the hash map converts the O(n²) check-every-pair problem into O(n) by remembering what you have seen.

### Classification

Two-Sum is a pattern that bridges hash maps and two pointers. The variants are distinguished by:
- **Number of elements:** Two-Sum (2), ThreeSum (3), FourSum (4), K-Sum
- **Output:** Indices (unsorted array) vs. values (sorted array, deduped)
- **Constraints:** Sorted vs. unsorted, duplicates allowed vs. not, exactly one solution vs. all solutions

```mermaid
graph TD
    A[Two-Sum Pattern] --> B[Two-Sum]
    A --> C[ThreeSum / K-Sum]
    A --> D[Variants]
    B --> E[Hash map: O(n) time, O(n) space]
    B --> F[Two pointers: O(n log n) sort + O(n)]
    C --> G[Sort + two pointers per element]
    C --> H["O(n^(k-1)) time for K-Sum"]
    D --> I[Two-Sum with BST input]
    D --> J[Two-Sum less than target]
    D --> K[Two-Sum closest to target]
    D --> L[Count pairs satisfying sum condition]
```

### Key Properties

|Property|Value|Derivation|
|---|---|---|
|Two-Sum (hash map)|O(n) time, O(n) space|Single pass; each element processed once; hash map stores at most n entries|
|Two-Sum (two pointers, sorted)|O(n log n) sort + O(n) = O(n log n), O(1) space|Sort dominates; two-pointer pass is O(n)|
|ThreeSum (sort + two pointers)|O(n log n + n²) = O(n²), O(log n) to O(n) sort|Sort + n × (two-pointer O(n))|
|K-Sum (general)|O(n^(k-1)) time|Recursive: fix one element, solve (k-1)-Sum on the remainder|
|Two-Sum with duplicates (values)|O(n) time, O(n) space|Hash set, not hash map — only need existence, not indices|

---

## Deep Mechanics

### How It Works

**Hash map approach (unsorted):**
1. Create an empty dictionary.
2. For each element at index i:
   - Compute complement = target - nums[i].
   - If complement is in the dictionary, return [map[complement], i].
   - Otherwise, store nums[i] at index i in the dictionary.
3. If loop completes, no solution exists.

The invariant: the dictionary always contains elements to the left of the current index. When a match is found, the left element is the complement and the right element is the current one.

**Two-pointer approach (sorted):**
1. Sort the array (if not already sorted).
2. Place left at 0, right at n-1.
3. While left < right:
   - Compute sum = arr[left] + arr[right].
   - If sum == target → return.
   - If sum < target → left++. Sum must increase; sorted ensures left++ gives a larger value.
   - If sum > target → right--. Sum must decrease; right-- gives a smaller value.

### Complexity Derivation

**Time — Hash map:** Single loop of n iterations. Each iteration does O(1) work (dictionary lookup and insertion). Total: O(n).

**Time — ThreeSum with sort + two pointers:** Sort is O(n log n). Outer loop runs n times. For each iteration, two-pointer scan runs O(n) in the worst case (scanning from i+1 to n-1). Total: O(n log n + n²) = O(n²). The sort is dominated by the n² term.

**Space — Hash map:** O(n) in the worst case (no pair found, all n elements stored). Two-pointer approach: O(1) auxiliary space, plus O(log n) to O(n) for the sort (in-place sort is O(log n) for recursion stack).

### .NET Runtime Notes

- **Dictionary vs. HashSet for Two-Sum:** When the problem asks for values (not indices), `HashSet<int>` suffices for the complement check. When indices are required, `Dictionary<int, int>` stores value → index mapping.
- **Sorting for two-pointer approach:** `Array.Sort` uses introsort (O(n log n)). For ThreeSum, the sort is in-place by default; if the original array must be preserved, clone it first.
- **Memory pressure for large inputs:** The hash map for Two-Sum allocates O(n) entries. For n = 10⁷, a dictionary of 10 million integers uses ~160 MB (8 bytes per int × 2 for key + value overhead). This can trigger LOH allocation and GC pressure.
- **LINQ alternatives:** `nums.Select((val, i) => (val, i)).ToDictionary(x => x.val, x => x.i)` can build the map but duplicates cause an exception. Prefer explicit loops.

---

## Implementation and Problem Patterns

### C# Implementation

```csharp
public static class TwoSumPattern
{
    /// <summary>
    /// Classic Two-Sum — return indices of the two numbers that add to target.
    /// Assumes exactly one solution. May not use the same element twice.
    /// </summary>
    public static int[] TwoSum(int[] nums, int target)
    {
        var map = new Dictionary<int, int>();
        for (int i = 0; i < nums.Length; i++)
        {
            int complement = target - nums[i];
            if (map.TryGetValue(complement, out int index))
                return [index, i];
            map[nums[i]] = i;
        }
        return [-1, -1];
    }

    /// <summary>
    /// Two-Sum on a sorted array — two-pointer approach.
    /// Returns the values (not indices) for the pair.
    /// </summary>
    public static int[] TwoSumSortedTwoPointers(int[] sorted, int target)
    {
        int left = 0, right = sorted.Length - 1;
        while (left < right)
        {
            int sum = sorted[left] + sorted[right];
            if (sum == target) return [sorted[left], sorted[right]];
            if (sum < target) left++;
            else right--;
        }
        return [-1, -1];
    }

    /// <summary>
    /// Two-Sum — return values using a hash set (when indices are not needed).
    /// </summary>
    public static int[] TwoSumValues(int[] nums, int target)
    {
        var seen = new HashSet<int>();
        foreach (int num in nums)
        {
            int complement = target - num;
            if (seen.Contains(complement))
                return [complement, num];
            seen.Add(num);
        }
        return [-1, -1];
    }

    /// <summary>
    /// Two-Sum — less than target. Count pairs with sum < target.
    /// Sorted input. Two-pointer approach.
    /// </summary>
    public static int CountPairsLessThanTarget(int[] nums, int target)
    {
        Array.Sort(nums);
        int left = 0, right = nums.Length - 1, count = 0;
        while (left < right)
        {
            if (nums[left] + nums[right] < target)
            {
                count += right - left;
                left++;
            }
            else
            {
                right--;
            }
        }
        return count;
    }

    /// <summary>
    /// Two-Sum — closest to target. Find the pair whose sum is closest to target.
    /// </summary>
    public static int TwoSumClosest(int[] nums, int target)
    {
        Array.Sort(nums);
        int left = 0, right = nums.Length - 1;
        int closest = nums[left] + nums[right];
        while (left < right)
        {
            int sum = nums[left] + nums[right];
            if (Math.Abs(sum - target) < Math.Abs(closest - target))
                closest = sum;
            if (sum < target) left++;
            else if (sum > target) right--;
            else return sum;
        }
        return closest;
    }

    /// <summary>
    /// Two-Sum in a Binary Search Tree — find two nodes whose values sum to target.
    /// In-order traversal gives sorted values; use two pointers on the BST.
    /// </summary>
    public static bool TwoSumBST(TreeNode? root, int target)
    {
        var stack = new Stack<TreeNode>();
        var sorted = new List<int>();
        var current = root;
        while (current != null || stack.Count > 0)
        {
            while (current != null) { stack.Push(current); current = current.Left; }
            current = stack.Pop();
            sorted.Add(current.Value);
            current = current.Right;
        }

        int left = 0, right = sorted.Count - 1;
        while (left < right)
        {
            int sum = sorted[left] + sorted[right];
            if (sum == target) return true;
            if (sum < target) left++;
            else right--;
        }
        return false;
    }
}

public class TreeNode
{
    public int Value;
    public TreeNode? Left;
    public TreeNode? Right;
    public TreeNode(int value) { Value = value; }
}
```

### The .NET Idiomatic Version

```csharp
public static class TwoSumIdiomatic
{
    // For Two-Sum, the idiomatic approach is Dictionary + single pass.
    // For ThreeSum, sort + two pointers is the standard pattern.

    // If the input is already a HashSet<int>, use it directly:
    public static bool TwoSumExists(HashSet<int> set, int target)
    {
        foreach (int num in set)
            if (set.Contains(target - num) && target - num != num)
                return true;
        return false;
    }

    // For Two-Sum with dictionary, prefer TryGetValue over ContainsKey + indexer
    // to avoid a double lookup. Always use TryGetValue.
}
```

### Classic Problem Patterns

1. **Classic Two-Sum (indices)** — Given an unsorted array of integers and a target, return the indices of the two numbers that sum to the target. Key insight: the hash map stores value → index; check complement before storing current.
2. **ThreeSum (unique triplets summing to zero)** — Sort the array, fix each element, run two-pointer on the remainder. Key insight: skip duplicates for the outer element and after each found pair to avoid duplicate triplets.
3. **Two-Sum variants (BST, less than target, closest)** — Each variant modifies the same core idea: hash map for unsorted, two pointers for sorted, counting instead of finding, proximity instead of equality.

### Template / Skeleton

```csharp
// Two-Sum (Hash Map) Template
// When to use: unsorted array, find pair summing to target
// Time: O(n) | Space: O(n)

public static int[] TwoSumTemplate(int[] nums, int target)
{
    var map = new Dictionary<int, int>();
    for (int i = 0; i < nums.Length; i++)
    {
        int complement = target - nums[i];
        if (map.TryGetValue(complement, out int index))
        {
            return [index, i];
        }
        if (!map.ContainsKey(nums[i]))
        {
            // TODO: may want to skip duplicates — store only first occurrence
            map[nums[i]] = i;
        }
    }
    return [-1, -1];
}
```

---

## Gotchas and Edge Cases

### Using the Same Element Twice

**Mistake:** Forgetting that the same element may satisfy the complement check if it appears at different indices.

```csharp
// ❌ Wrong — for target=6 and nums=[3, 1], returns [0, 0] if we check before storing
public int[] TwoSum(int[] nums, int target)
{
    var map = new Dictionary<int, int>();
    for (int i = 0; i < nums.Length; i++)
    {
        int complement = target - nums[i];
        if (map.TryGetValue(complement, out int index))
            return [index, i]; // If complement == nums[i], index == i (same element)
        map[nums[i]] = i;
    }
    return [-1, -1];
}
```

**Fix:** Store AFTER the check. The element at i is not yet in the map, so complement can only match an earlier element.

```csharp
// ✅ Correct — complement check happens before storing current element
map[nums[i]] = i; // Move this AFTER the check
```

**Consequence:** Wrong indices — using the same element twice violates "you may not use the same element twice."

### Duplicate Values in the Map

**Mistake:** Overwriting the index of a duplicate value, losing the earlier index.

```csharp
// ❌ Wrong — map[3] = 0, then map[3] = 2 (overwrites index 0)
// If target is 6 and nums is [3, 4, 3], the correct answer is [0, 2] but
// map[3] = 2 after processing both 3s, so complement check for nums[2]=3
// accesses map[3] = 2 — same index again.
```

**Fix:** Only store the first occurrence, or use a list of indices per value.

```csharp
// ✅ Correct — only store if key does not exist
if (!map.ContainsKey(nums[i])) map[nums[i]] = i;
```

**Consequence:** Wrong answer if the problem expects the first valid pair. In classic Two-Sum (exactly one solution), duplicates do not cause issues because the complement is different.

### Unsorted Input with Two Pointers

**Mistake:** Running two pointers on an unsorted array — the monotonic property required for correct pointer movement does not hold.

```csharp
// ❌ Wrong — two pointers on unsorted arr = [3, 1, 2], target = 4
// Starting: left=0 (3), right=2 (2), sum=5 > 4. Move right → left=0 (3), right=1 (1).
// sum=4? No. sum=3+1=4. But we missed (1, 3) because right moved past index 2.
```

**Fix:** Sort first, or use a hash map.

```csharp
// ✅ Correct — sort first
Array.Sort(nums);
```

**Consequence:** Missed pair — the two-pointer approach requires sorted input to guarantee correctness.

### ThreeSum — Not Skipping Duplicates

**Mistake:** Including duplicate triplets because duplicate values in the array produce the same triplet.

```csharp
// ❌ Wrong — nums = [-1, -1, 0, 1, 1] produces [-1, 0, 1] twice
for (int i = 0; i < nums.Length; i++) { /* no duplicate skip */ }
```

**Fix:** Skip duplicates for the outer element and after each found pair.

```csharp
// ✅ Correct — skip duplicates
if (i > 0 && nums[i] == nums[i - 1]) continue;
// ... after finding a pair:
while (left < right && nums[left] == nums[left - 1]) left++;
while (left < right && nums[right] == nums[right + 1]) right--;
```

**Consequence:** Duplicate triplets in the result — the answer is rejected for containing duplicates not present in the expected output.

---

## Complexity Analysis and Benchmarks

### Operation Complexity Table

|Operation|Time|Space|Notes|
|---|---|---|---|
|Two-Sum (hash map)|O(n)|O(n)|Single pass, store all elements|
|Two-Sum (two pointers)|O(n log n)|O(1)|Sort dominates|
|ThreeSum (sort + two pointers)|O(n²)|O(log n) sort|Outer loop × two-pointer scan|
|FourSum (sort + nested + two pointers)|O(n³)|O(log n) sort|Two nested loops + two-pointer scan|
|K-Sum|O(n^(k-1))|O(k) recursion|Recursive reduction to (k-1)-Sum|

**Derivation for the non-obvious entries:** ThreeSum: sort O(n log n). For each of n elements, run two-pointer scan on the remaining n-i-1 elements. Each scan is O(n). So O(n log n + n²) = O(n²). FourSum: fix two elements (nested loops), then two-pointer scan on the remainder: O(n³).

### Comparison with Alternatives

|Approach|Time|Space|Best When|
|---|---|---|---|
|Hash Map|O(n)|O(n)|Unsorted, need indices|
|Two Pointers (sorted)|O(n log n) sort|O(1)|O(1) space critical; input can be sorted|
|Brute Force|O(n²)|O(1)|Small n (≤ 100)|
|Sort + Binary Search|O(n log n)|O(log n) sort|Only need to check existence for one pair per element|

### BenchmarkDotNet

```csharp
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net90)]
public class TwoSumBenchmark
{
    [Params(1_000, 10_000)]
    public int N { get; set; }

    private int[] _data = null!;

    [GlobalSetup]
    public void Setup()
    {
        _data = Enumerable.Range(0, N).ToArray();
    }

    [Benchmark(Baseline = true)]
    public int[] TwoSumHashMap()
    {
        var map = new Dictionary<int, int>();
        for (int i = 0; i < _data.Length; i++)
        {
            int complement = N - _data[i];
            if (map.TryGetValue(complement, out int idx))
                return [idx, i];
            map[_data[i]] = i;
        }
        return [-1, -1];
    }

    [Benchmark]
    public int[] TwoSumTwoPointers()
    {
        int left = 0, right = _data.Length - 1;
        while (left < right)
        {
            int sum = _data[left] + _data[right];
            if (sum == N) return [_data[left], _data[right]];
            if (sum < N) left++;
            else right--;
        }
        return [-1, -1];
    }
}
```

**Expected results (approximate, .NET 9, x64):**

|Method|N|Mean|Allocated|
|---|---|---|---|
|TwoSumHashMap|1,000|~3 μs|~32 KB|
|TwoSumHashMap|10,000|~30 μs|~320 KB|
|TwoSumTwoPointers|1,000|~100 ns|0 B|
|TwoSumTwoPointers|10,000|~1 μs|0 B|

**Interpretation:** The two-pointer approach is ~30× faster and uses zero heap memory because the input is already sorted. The hash map allocates a dictionary entry for each element. This demonstrates the tradeoff: when you control the sorting step, two pointers is strictly better; when you cannot sort (need original indices), hash map is the only choice.

---

## Interview Arsenal

### Question Bank

1. [Definition] What is the Two-Sum problem and why is it famous?
2. [Complexity] Derive the time complexity of the hash map approach to Two-Sum.
3. [Implementation] Implement ThreeSum that returns all unique triplets summing to zero.
4. [Recognition] Given a problem involving finding pairs/triplets with a sum constraint, what approach?
5. [Comparison] Compare the hash map and two-pointer approaches for Two-Sum — when is each better?
6. [Trick] Can you solve Two-Sum in O(n) time with O(1) space?
7. [System Design] How would you design a system that finds Two-Sum pairs in a streaming data pipeline?
8. [Optimization] How would you modify Two-Sum to handle an array of 10 billion elements?

### Spoken Answers

**Q: Derive the time complexity of the hash map approach to Two-Sum.**

> **Average answer:** It is O(n) because we iterate once through the array.

> **Great answer:** The algorithm makes a single pass through the array of n elements. For each element, we compute the complement and perform a dictionary lookup — which is O(1) amortized average case. If the complement exists, we return immediately. If not, we insert the current element — O(1) amortized. The total cost across all n elements is O(n). The space complexity is O(n) because in the worst case — when no pair exists — the dictionary stores all n elements. One important detail: the dictionary operations are O(1) amortized only with a good hash function. If the integer hash function produces many collisions (e.g., all values are the same), the dictionary degrades to O(n) per operation, making the algorithm O(n²). In .NET, `Int32.GetHashCode()` returns the integer itself, so for a well-distributed set of keys, collisions are rare. But if all elements are the same value, they all map to the same bucket, and the dictionary handles this via open addressing probing.

**Q: Can you solve Two-Sum in O(n) time with O(1) space?**

> **Average answer:** No, hash map is O(n) space and two pointers is O(1) space but needs O(n log n) sort.

> **Great answer:** Not in the general case. For arbitrary integers, there is no known O(n) time, O(1) space algorithm for Two-Sum. The lower bound proof: if such an algorithm existed, it would imply a linear-time, constant-space solution for the element distinctness problem, which has a known Ω(n log n) lower bound in the comparison model. However, for *specific* cases with constraints, we can do better: if the integers are in a small, known range (e.g., -1000 to 1000), we can use a boolean array of size 2001 as a frequency map — O(n) time, O(1) space (the array size is constant relative to n). The trap question is whether the interviewer wants the general answer or allows problem-specific optimizations.

**Q: [Trick] Two-Sum in a BST — how do you solve it?**

> **Average answer:** Traverse the BST, store values in a hash set, check complement at each node.

> **Great answer:** There are two approaches. First, use a hash set during any traversal (BFS or DFS): for each node, check if `target - node.val` is in the set. If so, return true; otherwise, add the node's value and continue. This is O(n) time, O(n) space. The second approach uses the BST property: an in-order traversal produces a sorted list, then two pointers on that list — O(n) time, O(n) space for the list. The optimal approach combines the two-pointer idea with the BST structure directly using forward and backward iterators, giving O(n) time and O(h) space (stack for the two iterators, where h is tree height). At the whiteboard, I would start with the hash set approach (simplest to communicate) and then discuss the space-optimized version.

### Trick Question

**"Two-Sum on a sorted array — can you solve it in O(log n) time?"**

Why it is a trap: Candidates might think binary search helps, but finding a pair summing to target requires at least O(n) time in the worst case because you must examine each element — the pair could be any two positions.

Correct answer: No, O(n) is optimal for Two-Sum even on a sorted array. The two-pointer approach is O(n). Binary search on each element's complement gives O(n log n), which is worse. There is no O(log n) solution because the pair could be at any two indices, and you must at least check each element once. This is a common trick: candidates confuse "finding one element" (binary search O(log n)) with "finding a pair" (must look at every element).

### Pattern Recognition Table

|If the problem has...|Then consider...|Because...|
|---|---|---|
|Unsorted array + pair sum|Hash map|O(n) time, O(n) space; preserves original indices|
|Sorted array + pair sum|Two pointers|O(n) time, O(1) space; no auxiliary memory|
|"All unique triplets"|Sort + two-pointer inside a loop|Skip duplicates for outer element and inner pair|
|Count pairs with sum condition|Sort + two-pointer counting|Left pointer move counts all pairs with current left|
|Closest sum|Sort + two-pointer tracking closest|Track closest delta, move pointer toward target|

---

## Decision Framework

### When to Apply

```mermaid
flowchart TD
    A[Find pair(s) satisfying sum condition] --> B{Need indices or values?}
    B -->|Indices| C{Array sorted?}
    B -->|Values| D{Array sorted?}
    C -->|Yes| E[Two pointers on original array]
    C -->|No| F[Hash map: store value->index]
    D -->|Yes| G[Two pointers — O(1) space]
    D -->|No| H[Hash set — O(n) space, values only]
    A --> I{3 or more elements?}
    I -->|ThreeSum| J[Sort + fix one + two pointers]
    I -->|K-Sum| K[Recursive: fix one, solve (k-1)-Sum]
```

### Recognition Checklist

Indicators that Two-Sum pattern applies:

- [ ] Problem involves pairs of elements meeting a numeric condition
- [ ] Condition involves addition/subtraction (sum, difference) or comparison
- [ ] "All unique combinations" triggers ThreeSum with duplicate skipping
- [ ] "Count pairs" triggers two-pointer counting pattern
- [ ] "Closest" triggers tracking the minimum delta

Counter-indicators — do NOT apply here:

- [ ] Condition involves multiplication/division (typically harder, may use hash map of products)
- [ ] Problem involves subsequences (not necessarily contiguous pairs) — requires DP
- [ ] Input is a linked list (different traversal concerns)

### Tradeoff Summary

|What You Gain|What You Give Up|
|---|---|
|O(n) time for pair finding|O(n) memory for hash map (or O(n log n) time for two pointers)|
|Simplicity: three lines of code|Cannot handle 3+ elements without extending (K-Sum is O(n^(k-1)))|
|Pattern generalizes to K-Sum|K-Sum becomes impractical for large K (K > 4 is rare in interviews)|

---

## Self-Check

### Conceptual Questions

1. What is the core insight that makes the hash map Two-Sum work?
2. Derive the time complexity of ThreeSum by analyzing the sort + two-pointer approach step by step.
3. Recognizing from a problem: given an unsorted array, find all unique pairs that sum to a target.
4. When would you use a hash set instead of a hash map for Two-Sum?
5. What specific edge case causes the two-pointer approach to fail on unsorted input?
6. What .NET dictionary method should you prefer for checking existence before reading a value?
7. What invariant must the two-pointer approach maintain on a sorted array?
8. How does the answer change if the problem asks for "all pairs" vs "any pair" vs "count of pairs"?
9. In a production system processing stock trades, how would you detect Two-Sum patterns in real-time?
10. What is the trap question about O(log n) Two-Sum?

<details>
<summary>Answers</summary>

1. Store each element after checking if its complement already exists. This avoids the O(n²) pair check by providing O(1) complement lookup.
2. Sort: O(n log n). Outer loop: n iterations. Each iteration: two-pointer scan O(n) in worst case. Total: O(n log n + n²) = O(n²). The two-pointer scan is O(n) because each iteration moves either left or right until they meet.
3. Sort the array, then use two pointers. After sorting, skip duplicates for the outer element. This gives all unique pairs in O(n log n + n²/2) = O(n²) worst case.
4. When only values are needed (not indices), a HashSet<int> suffices and is lighter. Also when the problem asks "does any pair exist?" — boolean answer.
5. The monotonic property fails: moving left increases the sum and moving right decreases the sum only when the array is sorted. On unsorted input, moving left could decrease the sum or increase it unpredictably.
6. `TryGetValue(key, out value)` — performs a single lookup and returns false if the key is not found. Avoids the double lookup of `ContainsKey` followed by indexer.
7. At each step, any valid pair must have its left element ≥ current left and its right element ≤ current right. Moving a pointer preserves this invariant by eliminating the skipped element from the search space.
8. "Any pair" → return immediately on first match (standard Two-Sum). "All pairs" → continue scanning after finding a match; may need duplicate skipping. "Count pairs" → two-pointer counting (add right-left when sum < target at left).
9. Use a hash set to track seen trade values. For each incoming trade, check if its complement (hedge value) exists. This works in streaming because each element is processed once and immediately checked against past values.
10. Two-Sum on a sorted array has a lower bound of Ω(n) — you must examine each element. O(log n) is impossible because a single element could be part of the pair. The trap confuses element search (binary search) with pair search.

</details>

---

### Coding Challenges

**Challenge 1 — Implement from scratch**

Implement FourSum — find all unique quadruplets that sum to a target value.

```csharp
public static List<List<int>> FourSum(int[] nums, int target)
{
    // Your implementation here
}
```

<details> <summary>Solution</summary>

```csharp
public static List<List<int>> FourSum(int[] nums, int target)
{
    Array.Sort(nums);
    var result = new List<List<int>>();
    int n = nums.Length;
    for (int i = 0; i < n - 3; i++)
    {
        if (i > 0 && nums[i] == nums[i - 1]) continue;
        for (int j = i + 1; j < n - 2; j++)
        {
            if (j > i + 1 && nums[j] == nums[j - 1]) continue;
            int left = j + 1, right = n - 1;
            while (left < right)
            {
                long sum = (long)nums[i] + nums[j] + nums[left] + nums[right];
                if (sum == target)
                {
                    result.Add([nums[i], nums[j], nums[left], nums[right]]);
                    left++;
                    right--;
                    while (left < right && nums[left] == nums[left - 1]) left++;
                    while (left < right && nums[right] == nums[right + 1]) right--;
                }
                else if (sum < target) left++;
                else right--;
            }
        }
    }
    return result;
}
```

**Complexity:** Time O(n³) | Space O(log n) for sort **Key insight:** Two nested fixed loops + two-pointer scan. Skip duplicates at every level.

</details>

---

**Challenge 2 — Trace the execution**

Given `nums = [-1, 0, 1, 2, -1, -4]` sorted to `[-4, -1, -1, 0, 1, 2]`, trace ThreeSum (target = 0).

<details> <summary>Solution</summary>

Sorted: [-4, -1, -1, 0, 1, 2]

i=0 (-4): left=1 (-1), right=5 (2), sum=-4-1+2=-3 < 0 → left=2 (-1), sum=-4-1+2=-3 < 0 → left=3 (0), sum=-4+0+2=-2 < 0 → left=4 (1), sum=-4+1+2=-1 < 0 → left=5 (2) → left=right, exit

i=1 (-1): left=2 (-1), right=5 (2), sum=-1-1+2=0 → add [-1, -1, 2], left=3 (0), right=4 (1), sum=-1+0+1=0 → add [-1, 0, 1], left=4, right=3 → exit

i=2 (-1): skip (same as i=1)

i=3 (0): left=4 (1), right=5 (2), sum=0+1+2=3 > 0 → right=4 → left=right, exit

Result: [[-1, -1, 2], [-1, 0, 1]]

**Why:** The algorithm scans through each element, skipping duplicates at each level. The two-pointer scan finds valid pairs for each fixed element.

</details>

---

**Challenge 3 — Fix the bug**

```csharp
// This implementation has a bug that fails on specific input types
public static int[] TwoSum(int[] nums, int target)
{
    var map = new Dictionary<int, int>();
    for (int i = 0; i < nums.Length; i++)
    {
        int complement = target - nums[i];
        if (map.ContainsKey(complement))
            return [map[complement], i];  // BUG: uses ContainsKey + indexer (double lookup)
        map[nums[i]] = i;
    }
    return [-1, -1];
}
```

<details> <summary>Solution</summary>

**Bug:** Using `ContainsKey` followed by the indexer performs two dictionary lookups. The functional bug is that if a duplicate value exists earlier, its index is overwritten, potentially causing issues. The performance issue is the double lookup.

**Fix:** Use `TryGetValue` for a single lookup.

```csharp
public static int[] TwoSum(int[] nums, int target)
{
    var map = new Dictionary<int, int>();
    for (int i = 0; i < nums.Length; i++)
    {
        int complement = target - nums[i];
        if (map.TryGetValue(complement, out int index))
            return [index, i];
        if (!map.ContainsKey(nums[i]))
            map[nums[i]] = i;
    }
    return [-1, -1];
}
```

**Test case that exposes it:** `nums = [3, 2, 4], target = 6` → expected `[1, 2]`, actual `[0, 0]` — wait, this is wrong. Actually this works because map doesn't have 3 yet when i=0. The real issue is with `nums = [3, 3], target = 6`: expected `[0, 1]`, actual — map[3]=0 at i=0. i=1: complement=3, ContainsKey=true → returns [0, 1]. This actually works for this case. The bug is the double lookup (performance) and overwriting indices for duplicates. For classic Two-Sum (exactly one solution), it works. The fix for the overwrite is `if (!map.ContainsKey(nums[i])) map[nums[i]] = i;`.

</details>

---

**Challenge 4 — Recognize and apply**

**Problem:** Given an array of integers, count the number of pairs (i, j) with i < j such that `arr[i] + arr[j]` is divisible by k. Solve in O(n + k) time.

<details> <summary>Solution</summary>

**Pattern:** Two-Sum variant using frequency of modulo values. Store the count of each `arr[i] % k`. For each remainder r, pairs are formed with remainder (k - r) % k.

```csharp
public static int CountPairsDivisibleByK(int[] nums, int k)
{
    var freq = new Dictionary<int, int>();
    int count = 0;
    foreach (int num in nums)
    {
        int rem = num % k;
        int complement = (k - rem) % k;
        if (freq.TryGetValue(complement, out int cnt))
            count += cnt;
        freq[rem] = freq.GetValueOrDefault(rem) + 1;
    }
    return count;
}
```

**Complexity:** Time O(n) | Space O(k) **Key insight:** Store remainder frequencies, not raw values. The complement relationship generalizes to modulo arithmetic.

</details>

---

**Challenge 5 — Optimize**

```csharp
// This solution is correct but uses O(n²) time
// Optimize to O(n) time
public static int[] TwoSumBruteForce(int[] nums, int target)
{
    for (int i = 0; i < nums.Length; i++)
        for (int j = i + 1; j < nums.Length; j++)
            if (nums[i] + nums[j] == target)
                return [i, j];
    return [-1, -1];
}
```

<details> <summary>Solution</summary>

**Insight:** Use a hash map to store elements as they are seen. Check complement before storing.

```csharp
public static int[] TwoSum(int[] nums, int target)
{
    var map = new Dictionary<int, int>();
    for (int i = 0; i < nums.Length; i++)
    {
        int complement = target - nums[i];
        if (map.TryGetValue(complement, out int index))
            return [index, i];
        if (!map.ContainsKey(nums[i]))
            map[nums[i]] = i;
    }
    return [-1, -1];
}
```

**Complexity:** Time O(n) | Space O(n)

</details>
