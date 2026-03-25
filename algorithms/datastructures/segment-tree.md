# Segment Tree
> A binary tree built over an array that answers range queries and supports point or range updates in O(log n).

---

## When To Use It
Use a segment tree when you need repeated range queries (sum, min, max) on a mutable array. If the array never changes, a prefix sum handles range sum queries in O(1). If the array changes but queries are rare, a simple loop is fine. A segment tree is the right tool when you need both frequent updates and frequent range queries — each O(log n).

---

## Core Concept
Build a binary tree where each leaf represents one array element, and each internal node stores the aggregate of its children's range (sum, min, or max). The root covers the entire array. Querying a range means combining the values of the O(log n) nodes that exactly cover that range. Updating a single element means walking down to the leaf and propagating the change back up — also O(log n). The tree is stored in an array with the same index arithmetic as a heap: node i has children at 2i and 2i+1. You allocate 4n space to be safe.

---

## The Code

**Segment tree for range sum queries with point updates**
```csharp
public class SegmentTree
{
    private readonly int[] _tree;
    private readonly int _n;

    public SegmentTree(int[] nums)
    {
        _n = nums.Length;
        _tree = new int[4 * _n];
        Build(nums, 0, 0, _n - 1);
    }

    private void Build(int[] nums, int node, int start, int end)
    {
        if (start == end)
        {
            _tree[node] = nums[start];
        }
        else
        {
            int mid = (start + end) / 2;
            Build(nums, 2 * node, start, mid);
            Build(nums, 2 * node + 1, mid + 1, end);
            _tree[node] = _tree[2 * node] + _tree[2 * node + 1];
        }
    }

    public void Update(int idx, int val)  // O(log n)
    {
        DoUpdate(0, 0, _n - 1, idx, val);
    }

    private void DoUpdate(int node, int start, int end, int idx, int val)
    {
        if (start == end)
        {
            _tree[node] = val;
        }
        else
        {
            int mid = (start + end) / 2;
            if (idx <= mid)
                DoUpdate(2 * node, start, mid, idx, val);
            else
                DoUpdate(2 * node + 1, mid + 1, end, idx, val);
            _tree[node] = _tree[2 * node] + _tree[2 * node + 1];
        }
    }

    public int Query(int l, int r)  // O(log n)
    {
        return DoQuery(0, 0, _n - 1, l, r);
    }

    private int DoQuery(int node, int start, int end, int l, int r)
    {
        if (r < start || end < l)
            return 0;          // out of range — identity for sum
        if (l <= start && end <= r)
            return _tree[node];  // fully inside range
        int mid = (start + end) / 2;
        int left = DoQuery(2 * node, start, mid, l, r);
        int right = DoQuery(2 * node + 1, mid + 1, end, l, r);
        return left + right;
    }
}
```

**Usage**
```csharp
int[] nums = { 1, 3, 5, 7, 9, 11 };
var st = new SegmentTree(nums);
Console.WriteLine(st.Query(1, 3));   // 3+5+7 = 15
st.Update(1, 10);        // nums[1] = 10
Console.WriteLine(st.Query(1, 3));   // 10+5+7 = 22
```

**Lazy propagation — range updates in O(log n)**
```csharp
// Without lazy propagation, updating a range of m elements costs O(m log n).
// Lazy propagation defers range updates: mark a node "pending"
// and only push the update down when a child is actually accessed.
// Full implementation is long; the concept: each node stores a lazy tag
// that represents a pending operation for its entire subtree.
// When querying or updating children, flush the lazy tag first.
```

---

## Gotchas

- **Allocate 4n space, not 2n.** The tree height is ⌈log₂ n⌉, and the array representation needs 2^(⌈log₂ n⌉+1) nodes. 4n is the safe upper bound for any n.
- **The identity value for out-of-range nodes depends on the operation.** For sum it's 0, for min it's `float('inf')`, for max it's `float('-inf')`. Using the wrong identity produces wrong query results.
- **Range updates without lazy propagation are O(n), not O(log n).** If you need to add a value to every element in a range, implement lazy propagation — otherwise you defeat the purpose of the structure.
- **0-indexed vs 1-indexed matters.** Many implementations root the tree at index 1 (children at 2i and 2i+1). Using index 0 as root puts children at 2i+1 and 2i+2 — easy to mix up. Pick one convention and stick to it.
- **A Fenwick tree (Binary Indexed Tree) is simpler for range sum + point update.** If that's your only use case, a Fenwick tree is fewer lines and less error-prone. Use a segment tree when you need range min/max, range updates, or lazy propagation.

---

## Interview Angle

**What they're really testing:** Whether you know this structure exists and when it applies — and whether you can implement it cleanly under pressure.

**Common question form:** Range sum query with updates (LeetCode 307), range minimum query, "design a data structure that supports update and range aggregate."

**The depth signal:** A junior uses a prefix sum array and breaks when updates appear. A senior immediately identifies this as a segment tree problem, knows the 4n allocation rule, the out-of-range identity, and can implement build/query/update from memory. The elite-level signal is knowing when a Fenwick tree is a simpler substitute and when lazy propagation is required — and being able to articulate the difference.

---

## Related Topics

- [[algorithms/tree.md]] — The structural foundation; segment trees are binary trees with array-backed storage.
- [[algorithms/array.md]] — A segment tree is built over an array and answers array range queries.
- [[algorithms/heap.md]] — Also uses array-backed binary tree index arithmetic (2i+1, 2i+2).

---

## Source

https://cp-algorithms.com/data_structures/segment_tree.html

---

*Last updated: 2026-03-24*