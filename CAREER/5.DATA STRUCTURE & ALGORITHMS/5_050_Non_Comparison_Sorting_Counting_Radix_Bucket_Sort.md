---
id: "5.050"
studied_well: false
title: "Non-Comparison Sorting — Counting, Radix, Bucket Sort"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Sorting"
tags: [dsa, algorithms, sorting, counting-sort, radix-sort, bucket-sort, non-comparison, csharp, interviews]
priority: 3
prerequisites:
  - "[[5.049 — Comparison-Based Sorting — Merge Sort, Quick Sort, Heap Sort]]"
related:
  - "[[5.001 — Big-O Notation and Complexity Analysis]]"
  - "[[5.051 — Sorting in .NET — Array.Sort, List.Sort, Custom Comparers, Stability]]"
  - "[[5.033 — Top-K and K-th Element Problems]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Sorting
**Previous:** [[5.049 — Comparison-Based Sorting — Merge Sort, Quick Sort, Heap Sort]] | **Next:** [[5.052 — Greedy Choice Property and Optimal Substructure]]

### Prerequisites
- [[5.049 — Comparison-Based Sorting — Merge Sort, Quick Sort, Heap Sort]] — the O(n log n) lower bound for comparison-based sorting is why non-comparison sorts exist; understanding that bound is required.

### Where This Fits
Non-comparison sorts break the O(n log n) barrier by exploiting properties of the input data rather than comparing elements pairwise. Counting sort works when the key range is small. Radix sort extends counting sort by processing digits. Bucket sort distributes elements into buckets and sorts each bucket. They appear in specialized scenarios: sorting grades (counting sort), sorting phone numbers (radix sort), and sorting uniformly distributed data (bucket sort). In interviews, these are rarely standalone questions but appear as subroutines or optimizations.

### Key Insight

The O(n log n) lower bound applies only to comparison-based sorts. Non-comparison sorts use the **value itself** as an index or use the value's digit decomposition to determine position. Counting sort: key = index in a frequency array. Radix sort: sort by each digit from LSD to MSD using a stable counting sort. Bucket sort: divide range into buckets, sort each bucket individually.

### Properties

|Sort|Time|Space|Stable|Requires|
|---|---|---|---|---|
|Counting sort|O(n + k)|O(k)|Yes|Integer keys in range [0, k]|
|Radix sort (LSD)|O(d·(n + k))|O(n + k)|Yes|Fixed-length keys, d digits|
|Bucket sort|O(n + k)*|O(n)|Stable depends|Uniform distribution|
|Bucket sort worst|O(n²)|O(n)|Depends|All elements in one bucket|

### Counting Sort

```csharp
public int[] CountingSort(int[] nums, int maxValue)
{
    int[] count = new int[maxValue + 1];
    foreach (int num in nums) count[num]++;

    for (int i = 1; i < count.Length; i++)
        count[i] += count[i - 1];

    int[] result = new int[nums.Length];
    for (int i = nums.Length - 1; i >= 0; i--)
    {
        int num = nums[i];
        result[count[num] - 1] = num;
        count[num]--;
    }

    return result;
}
```

### Radix Sort (LSD)

```csharp
public void RadixSort(int[] nums)
{
    int max = nums.Max();
    for (int exp = 1; max / exp > 0; exp *= 10)
        CountingSortByDigit(nums, exp);
}

private void CountingSortByDigit(int[] nums, int exp)
{
    int n = nums.Length;
    int[] output = new int[n];
    int[] count = new int[10];

    for (int i = 0; i < n; i++)
        count[(nums[i] / exp) % 10]++;

    for (int i = 1; i < 10; i++)
        count[i] += count[i - 1];

    for (int i = n - 1; i >= 0; i--)
    {
        int digit = (nums[i] / exp) % 10;
        output[count[digit] - 1] = nums[i];
        count[digit]--;
    }

    Array.Copy(output, nums, n);
}
```

### Gotchas

- **Counting sort large range** — If k is large (e.g., sorting 10 integers in range [0, 10⁹]), counting sort uses O(k) space — impractical.
- **Radix sort digit order** — LSD radix sort processes digits right-to-left. MSD radix sort processes left-to-right and is more complex (must handle prefixes recursively).
- **Bucket sort distribution** — Worst case (all elements in one bucket) degenerates to O(n²) if the bucket sort uses insertion sort. Use a good hash function for the bucket assignment.
- **Negative numbers** — Counting sort requires non-negative keys. Shift the range: add -min to all values.
- **Stability** — Counting sort is stable only when iterating backward in the output construction. This is essential for radix sort correctness.

