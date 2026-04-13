# Segment Tree

> A binary tree built over an array that answers range queries and supports point or range updates in O(log n).

---

## Quick Reference

| | |
|---|---|
| **What it is** | Array-backed binary tree for range queries |
| **Use when** | Frequent range queries on a mutable array |
| **Avoid when** | Array is static (use prefix sums) or updates are rare |
| **C# version** | C# 2.0+ (custom implementation — no BCL type) |
| **Namespace** | Custom implementation |
| **Key types** | `int[]` tree array, recursive build/query/update |

---

## When To Use It

Use a segment tree when you need both **frequent updates** and **frequent range queries** on the same mutable array. If the array never changes, a prefix-sum array handles range-sum queries in O(1) after O(n) build. If updates are rare, a brute-force O(n) scan per query is often simpler. The segment tree earns its complexity when both operations happen continuously — trading the O(1) prefix-sum query for O(log n) in exchange for O(log n) updates instead of O(n) rebuilds.

Avoid it when your range operation is only range sum with point updates and you don't need range updates — a Fenwick tree (Binary Indexed Tree) is simpler to implement and has comparable performance. Use a segment tree when you need range min, range max, range GCD, range updates with lazy propagation, or any aggregate that a Fenwick tree can't express.

---

## Core Concept

Build a binary tree where each leaf represents one array element, and each internal node stores the aggregate (sum, min, max) of its range. The root covers `[0, n-1]`. The left child of a node covering `[l, r]` covers `[l, mid]`; the right child covers `[mid+1, r]`.

The tree is stored in an array with index arithmetic identical to a heap: node `i` has children at `2i` and `2i+1` (1-indexed). You need `4n` elements in the tree array as a safe upper bound for any n.

**Querying a range:** Recursively split the query range. If the current node's range is fully inside the query range, return its stored value. If fully outside, return the identity value (0 for sum, `int.MaxValue` for min). Otherwise split and combine children.

**Point update:** Walk to the target leaf, update it, propagate the change back up through all ancestors.

**Range update with lazy propagation:** Instead of immediately updating all elements in a range (O(n) work), mark the covering node with a "pending" tag and defer the update to children until they're actually accessed. Each query or update flushes pending tags on the way down. This reduces range updates from O(n) to O(log n).

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Custom segment trees via `int[]` — no generic support |
| C# 2.0 | .NET 2.0 | Generic arrays enable `T[]` segment trees for any comparable type |
| C# 6.0 | .NET 4.6 | Expression-bodied members make merge functions more concise |
| C# 9.0 | .NET 5 | `record struct` enables zero-allocation node types in some segment tree variants |

*No version of .NET has ever shipped a segment tree in the BCL. It's always a hand-rolled data structure.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Build | O(n) | Bottom-up construction |
| Point update | O(log n) | Walk to leaf + propagate up |
| Range query | O(log n) | At most 4 nodes visited per level |
| Range update (no lazy) | O(n) | Update every leaf in range |
| Range update (lazy) | O(log n) | Defer with lazy tag |
| Space | O(4n) | Tree array — use 4n to be safe for any n |

**Allocation behaviour:** The segment tree is a single `int[]` (or `long[]`) of size `4n`. No per-node heap allocation — everything is inline in the array. This gives excellent cache behaviour for small-to-medium n.

**Benchmark notes:** For n under ~1,000 and infrequent queries, prefix sums or brute force are faster in practice due to lower constant factors. Segment trees become the right tool above ~10,000 elements with mixed update/query workloads. Lazy propagation adds constant overhead per operation — only enable it when you actually need range updates.

---

## The Code

**Segment tree with point update and range sum query**
```csharp
public class SegmentTree
{
    private readonly int[] _tree;
    private readonly int _n;

    public SegmentTree(int[] nums)
    {
        _n    = nums.Length;
        _tree = new int[4 * _n];
        Build(nums, 1, 0, _n - 1);   // 1-indexed; root at index 1
    }

    private void Build(int[] nums, int node, int start, int end)
    {
        if (start == end)
        {
            _tree[node] = nums[start];
            return;
        }
        int mid = (start + end) / 2;
        Build(nums, 2 * node,     start, mid);
        Build(nums, 2 * node + 1, mid + 1, end);
        _tree[node] = _tree[2 * node] + _tree[2 * node + 1];
    }

    // Point update: set nums[idx] = val
    public void Update(int idx, int val) => DoUpdate(1, 0, _n - 1, idx, val);

    private void DoUpdate(int node, int start, int end, int idx, int val)
    {
        if (start == end) { _tree[node] = val; return; }
        int mid = (start + end) / 2;
        if (idx <= mid) DoUpdate(2 * node,     start, mid,     idx, val);
        else            DoUpdate(2 * node + 1, mid + 1, end,   idx, val);
        _tree[node] = _tree[2 * node] + _tree[2 * node + 1];   // propagate up
    }

    // Range sum query [l..r] inclusive
    public int Query(int l, int r) => DoQuery(1, 0, _n - 1, l, r);

    private int DoQuery(int node, int start, int end, int l, int r)
    {
        if (r < start || end < l) return 0;                    // fully outside — identity
        if (l <= start && end <= r) return _tree[node];        // fully inside
        int mid = (start + end) / 2;
        return DoQuery(2 * node, start, mid, l, r)
             + DoQuery(2 * node + 1, mid + 1, end, l, r);
    }
}

// Usage
int[] nums = { 1, 3, 5, 7, 9, 11 };
var st = new SegmentTree(nums);
Console.WriteLine(st.Query(1, 3));   // 3+5+7 = 15
st.Update(1, 10);                    // nums[1] = 10
Console.WriteLine(st.Query(1, 3));   // 10+5+7 = 22
```

**Range min query (swap the aggregate function)**
```csharp
// Only the merge and identity change — the structure is identical
private void BuildMin(int[] nums, int node, int start, int end)
{
    if (start == end) { _tree[node] = nums[start]; return; }
    int mid = (start + end) / 2;
    BuildMin(nums, 2 * node,     start, mid);
    BuildMin(nums, 2 * node + 1, mid + 1, end);
    _tree[node] = Math.Min(_tree[2 * node], _tree[2 * node + 1]);   // changed
}

private int DoQueryMin(int node, int start, int end, int l, int r)
{
    if (r < start || end < l) return int.MaxValue;  // identity for min
    if (l <= start && end <= r) return _tree[node];
    int mid = (start + end) / 2;
    return Math.Min(
        DoQueryMin(2 * node,     start, mid,     l, r),
        DoQueryMin(2 * node + 1, mid + 1, end, l, r));
}
```

**Lazy propagation — range add update in O(log n)**
```csharp
public class LazySegmentTree
{
    private readonly long[] _tree;
    private readonly long[] _lazy;   // pending range-add for each node
    private readonly int _n;

    public LazySegmentTree(int[] nums)
    {
        _n    = nums.Length;
        _tree = new long[4 * _n];
        _lazy = new long[4 * _n];   // initialised to 0 — no pending updates
        Build(nums, 1, 0, _n - 1);
    }

    private void Build(int[] nums, int node, int start, int end)
    {
        if (start == end) { _tree[node] = nums[start]; return; }
        int mid = (start + end) / 2;
        Build(nums, 2 * node,     start, mid);
        Build(nums, 2 * node + 1, mid + 1, end);
        _tree[node] = _tree[2 * node] + _tree[2 * node + 1];
    }

    // Flush pending lazy tag to children before descending
    private void Propagate(int node, int start, int end)
    {
        if (_lazy[node] == 0) return;
        int mid = (start + end) / 2;
        Apply(2 * node,     start, mid,     _lazy[node]);
        Apply(2 * node + 1, mid + 1, end, _lazy[node]);
        _lazy[node] = 0;
    }

    private void Apply(int node, int start, int end, long delta)
    {
        _tree[node] += delta * (end - start + 1);   // sum of range increases by delta * length
        _lazy[node] += delta;
    }

    // Range update: add delta to every element in [l..r]
    public void RangeAdd(int l, int r, long delta) => DoRangeAdd(1, 0, _n - 1, l, r, delta);

    private void DoRangeAdd(int node, int start, int end, int l, int r, long delta)
    {
        if (r < start || end < l) return;
        if (l <= start && end <= r) { Apply(node, start, end, delta); return; }
        Propagate(node, start, end);
        int mid = (start + end) / 2;
        DoRangeAdd(2 * node,     start, mid,     l, r, delta);
        DoRangeAdd(2 * node + 1, mid + 1, end, l, r, delta);
        _tree[node] = _tree[2 * node] + _tree[2 * node + 1];
    }

    // Range sum query [l..r]
    public long Query(int l, int r) => DoQuery(1, 0, _n - 1, l, r);

    private long DoQuery(int node, int start, int end, int l, int r)
    {
        if (r < start || end < l) return 0;
        if (l <= start && end <= r) return _tree[node];
        Propagate(node, start, end);
        int mid = (start + end) / 2;
        return DoQuery(2 * node, start, mid, l, r)
             + DoQuery(2 * node + 1, mid + 1, end, l, r);
    }
}
```

**What NOT to do — and the fix**
```csharp
// BAD: allocating only 2n — causes ArrayIndexOutOfRangeException for many values of n
var treeBad = new int[2 * n];   // insufficient for arbitrary n

// GOOD: always allocate 4n
var treeGood = new int[4 * n];  // safe upper bound for any n
// Why: tree height is ⌈log₂ n⌉; last level may hold up to 2^⌈log₂ n⌉ nodes.
// For n=5, height=3, last level needs up to 8 slots → total ≤ 15 < 4×5=20 ✓
```

---

## Real World Example

A financial reporting system tracks daily revenue for thousands of product lines. Analysts run ad-hoc range queries ("total revenue for product X between day 50 and day 200"), and the operations team applies bulk adjustments ("all products in category Y had a pricing correction of +$500 for days 100–150"). Both operations need to complete in milliseconds on arrays of ~365 elements per product, with hundreds of concurrent queries. A `LazySegmentTree` per product handles both bulk range adds and range sum queries in O(log n).

```csharp
public class RevenueTracker
{
    private readonly Dictionary<string, LazySegmentTree> _trees = new();

    public void InitProduct(string productId, int[] dailyRevenue)
        => _trees[productId] = new LazySegmentTree(dailyRevenue);

    // Apply a pricing correction to a date range
    public void ApplyCorrection(string productId, int startDay, int endDay, long delta)
    {
        if (_trees.TryGetValue(productId, out var tree))
            tree.RangeAdd(startDay, endDay, delta);
    }

    // Query total revenue for a product over a date range
    public long TotalRevenue(string productId, int startDay, int endDay)
    {
        if (!_trees.TryGetValue(productId, out var tree))
            throw new KeyNotFoundException($"Product {productId} not found.");
        return tree.Query(startDay, endDay);
    }

    // Apply a category-wide correction — O(k log n) for k products in category
    public void ApplyCategoryCorrection(
        IEnumerable<string> productIds, int startDay, int endDay, long delta)
    {
        foreach (string id in productIds)
            ApplyCorrection(id, startDay, endDay, delta);
    }
}
```

*The critical insight is lazy propagation: without it, a range correction that touches 150 days would update 150 leaf nodes — O(n) per correction, O(n × corrections) total. With lazy propagation, each correction is O(log n) regardless of how wide the range is.*

---

## Common Misconceptions

**"Allocating 2n elements for the tree array is enough"**
It's not. The tree needs space for up to `2^(⌈log₂ n⌉ + 1) - 1` nodes. For n = 5, the height is 3 and the last level may have 8 slots — total up to 15 nodes, but `2n = 10`. Always allocate `4n`. For n a power of two, `2n` technically works, but `4n` is the safe universal bound.

**"Segment trees and Fenwick trees are interchangeable"**
A Fenwick tree (BIT) supports range sum queries and point updates in O(log n) with simpler code and half the memory. But it cannot do range min/max, and range updates require a trick that only works for sums. A segment tree is more general — it handles any associative aggregate and range updates with lazy propagation. If you only need range sum + point update, the Fenwick tree is the better tool. For everything else, use the segment tree.

**"Lazy propagation is just an optimisation — the results are the same without it"**
Without lazy propagation, range updates require touching every element in the range — O(n) per update. With lazy propagation they're O(log n). The results are the same but the performance profile is completely different: without lazy propagation, a segment tree offers no advantage over a prefix sum array for range-update-then-query workloads.

---

## Gotchas

- **Always allocate 4n, not 2n.** This is the most common segment tree bug — the array is too small and you get an `ArrayIndexOutOfRangeException` for specific values of n.

- **The identity value must match the operation.** For sum: 0. For min: `int.MaxValue`. For max: `int.MinValue`. For GCD: 0. Using the wrong identity produces silently incorrect query results for out-of-range nodes.

- **0-indexed vs 1-indexed — pick one and be consistent.** Most implementations root at index 1 with children at `2i` and `2i+1`. Starting at 0 requires children at `2i+1` and `2i+2` — easy to mix up. The examples above use 1-indexed.

- **Lazy propagation must flush before every descent.** Call `Propagate(node, start, end)` before accessing children in both query and update functions. Forgetting this in one of the two functions produces subtle correctness bugs that pass most test cases but fail on interleaved update-query sequences.

- **Range updates change the aggregate formula.** For a range-add update, the node's sum increases by `delta × (end - start + 1)` — not just `delta`. This is the most common lazy propagation implementation error.

---

## Interview Angle

**What they're really testing:** Whether you know this structure exists, when it applies, and whether you can implement build/query/update correctly from memory. The lazy propagation extension separates candidates who've truly internalised segment trees from those who've only memorised the basic version.

**Common question forms:**
- "Range Sum Query — Mutable" (LeetCode 307) — the canonical segment tree problem
- "Range Minimum Query" — swap sum for min
- "Count of Range Sum" — advanced; requires a modified segment tree or merge sort

**The depth signal:** A junior uses a prefix sum array and breaks when updates appear. A senior immediately identifies this as a segment tree problem, knows the 4n allocation rule, the identity value for the operation, and can implement build/query/update from memory. The elite signal is implementing lazy propagation correctly — including the `Propagate` call in both query and update paths, and the `delta × range_length` formula for the sum aggregate — and knowing when a Fenwick tree is a simpler substitute.

**Follow-up questions to expect:**
- "When would you use a Fenwick tree instead?" (Only range sum + point update — simpler, less memory)
- "How would you extend this to range min with range assignment updates?" (Lazy tag stores the assigned value; propagation overwrites children's tags)
- "What's the space complexity?" (O(4n) ≈ O(n) — the constant matters in memory-tight environments)

---

## Related Topics

- [[algorithms/datastructures/tree.md]] — The structural foundation; segment trees are binary trees with array-backed storage.
- [[algorithms/datastructures/array.md]] — Prefix sums are the simpler alternative when the array is static.
- [[algorithms/datastructures/heap.md]] — Also uses array-backed binary tree index arithmetic (2i+1, 2i+2) but for a different purpose.
- [[algorithms/datastructures/fenwick-tree.md]] — The simpler alternative for range sum + point update — less memory, simpler code.

---

## Source

https://cp-algorithms.com/data_structures/segment_tree.html

---

*Last updated: 2026-04-12*