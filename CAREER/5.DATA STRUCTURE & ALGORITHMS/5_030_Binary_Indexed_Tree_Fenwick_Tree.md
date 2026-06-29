---
id: "5.030"
studied_well: false
title: "Binary Indexed Tree (Fenwick Tree)"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Trees"
tags: [dsa, algorithms, trees, fenwick-tree, binary-indexed-tree, range-query, point-update, csharp, interviews]
priority: 4
prerequisites:
  - "[[5.029 — Segment Trees]]"
related:
  - "[[5.007 — Prefix Sums]]"
  - "[[5.033 — Top-K and K-th Element Problems]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Trees
**Previous:** [[5.029 — Segment Trees]] | **Next:** [[5.031 — Min-Heap and Max-Heap — Structure and Heapify]]

### Prerequisites
- [[5.029 — Segment Trees]] — the Fenwick tree is a space-optimized alternative to segment trees for prefix sum queries.

### Where This Fits
A Fenwick tree (Binary Indexed Tree) supports prefix sum queries and point updates in O(log n) using O(n) space with a simpler implementation than segment trees. It is the preferred structure for range sum when only prefix operations are needed.

### Key Insight

Each index i in the BIT stores the sum of a range of responsibility: the range `(i - lsb(i), i]` where lsb(i) = i & -i (lowest set bit). The query walks backwards subtracting lsb; the update walks forward adding lsb.

### Implementation

```csharp
public class FenwickTree
{
    private readonly int[] _bit;

    public FenwickTree(int n) => _bit = new int[n + 1];

    public void Add(int index, int delta)
    {
        for (int i = index + 1; i < _bit.Length; i += i & -i)
            _bit[i] += delta;
    }

    public int PrefixSum(int index)
    {
        int sum = 0;
        for (int i = index + 1; i > 0; i -= i & -i)
            sum += _bit[i];
        return sum;
    }

    public int RangeSum(int l, int r) =>
        PrefixSum(r) - PrefixSum(l - 1);
}
```

### Comparison

|Structure|Query|Update|Space|Code|
|---|---|---|---|---|
|Fenwick tree|O(log n) prefix|O(log n)|O(n)|~10 lines|
|Segment tree|O(log n) range|O(log n)|O(4n)|~30 lines|
|Prefix sums|O(1) range|O(n)|O(n)|~5 lines|

### Gotchas

- **1-indexed internally** — BIT uses 1-based indexing. Convert by adding 1 to the 0-based index.
- **Only prefix sums** — Range sum requires subtraction: `Sum(r) - Sum(l-1)`. The BIT does not natively support arbitrary range queries for non-invertible operations.
- **Can be extended** — For range update + point query, use a BIT storing differences. For range update + range query, use two BITs.
- **Not for min/max** — The BIT only supports invertible operations (sum, xor, product). For min/max, use a segment tree.

