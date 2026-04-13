# Fenwick Tree (Binary Indexed Tree)

> An array-based structure that answers prefix sum queries and supports point updates in O(log n) with half the code of a segment tree.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Implicit tree via bit tricks — prefix sums in O(log n) |
| **Use when** | Range sum queries + point updates, nothing more complex |
| **Avoid when** | Range updates, range min/max, or non-invertible operations |
| **C# version** | C# 2.0+ (custom implementation — no BCL type) |
| **Namespace** | Custom implementation |
| **Key types** | `int[]` or `long[]` tree array, 1-indexed |

---

## When To Use It

Use a Fenwick tree when you need range sum queries and point updates on a mutable array and the simplicity of implementation matters. It does the same job as a segment tree for this specific use case, in the same O(log n) time, with half the code and half the memory.

Use a segment tree instead when you need range min/max (Fenwick can't do this), range updates (Fenwick can be extended but it becomes complex), arbitrary aggregate functions, or lazy propagation. The decision rule is simple: if "range sum + point update" describes your entire need, use a Fenwick tree. If you need anything beyond that, use a segment tree.

---

## Core Concept

A Fenwick tree is a flat array where index `i` stores the sum of a specific range of the original array — not the element at position `i`. The range stored at index `i` is determined by the lowest set bit of `i` (written `i & -i` in two's complement). Index `i` stores the sum of elements from `i - (i & -i) + 1` to `i`.

This bit trick encodes a tree structure implicitly — no pointers, no left/right children, just arithmetic on indices.

**Prefix sum query (sum from 1 to i):** Start at `i`, add `tree[i]`, then move to `i - (i & -i)` (strip the lowest set bit). Repeat until `i = 0`. Each step moves to the "parent" in the implicit tree. At most O(log n) steps.

**Point update (add delta to position i):** Start at `i`, add delta to `tree[i]`, then move to `i + (i & -i)` (add the lowest set bit). Repeat until `i > n`. Each step moves to the next node that covers position i's range. At most O(log n) steps.

The key insight is that query and update travel in opposite directions through the same implicit tree structure — query goes from `i` toward 0, update goes from `i` toward n.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Custom via `int[]` — the algorithm is array-based, no generics needed |
| C# 2.0 | .NET 2.0 | Generic wrappers possible, but the core int[] implementation is idiomatic |
| C# 9.0 | .NET 5 | No structural change — Fenwick trees don't benefit from new language features |

*The Fenwick tree algorithm is remarkably stable — the implementation from Peter Fenwick's 1994 paper is essentially unchanged.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Point update | O(log n) | At most log n bit-trick steps toward n |
| Prefix sum query [1..i] | O(log n) | At most log n bit-trick steps toward 0 |
| Range sum [l..r] | O(log n) | `Query(r) - Query(l-1)` |
| Build from array | O(n log n) | n point updates, or O(n) with a specialised build |
| Space | O(n) | Single array — half the memory of a segment tree |

**Allocation behaviour:** One `int[]` (or `long[]`) of length `n + 1` (1-indexed; index 0 is unused). No additional structure. Extremely cache-friendly — update and query both access O(log n) positions that tend to be near each other in the array.

**Benchmark notes:** Fenwick trees typically outperform segment trees in practice for range-sum queries due to smaller constant factors and better cache behaviour (smaller array, simpler index arithmetic). For n = 100,000 and 1,000,000 mixed operations, expect Fenwick to be 2–3× faster than a segment tree for the same task.

---

## The Code

**Standard Fenwick tree — point update, prefix sum**
```csharp
public class FenwickTree
{
    private readonly long[] _tree;
    private readonly int _n;

    public FenwickTree(int n)
    {
        _n    = n;
        _tree = new long[n + 1];   // 1-indexed; tree[0] is unused
    }

    // Add delta to position i (1-indexed)
    public void Update(int i, long delta)
    {
        for (; i <= _n; i += i & -i)   // move toward n by adding lowest set bit
            _tree[i] += delta;
    }

    // Prefix sum: sum of elements from 1 to i (inclusive, 1-indexed)
    public long Query(int i)
    {
        long sum = 0;
        for (; i > 0; i -= i & -i)    // move toward 0 by stripping lowest set bit
            sum += _tree[i];
        return sum;
    }

    // Range sum: sum of elements from l to r (inclusive, 1-indexed)
    public long RangeQuery(int l, int r) => Query(r) - Query(l - 1);
}

// Usage
var bt = new FenwickTree(6);
int[] nums = { 3, 2, -1, 6, 5, 4 };
for (int i = 0; i < nums.Length; i++)
    bt.Update(i + 1, nums[i]);         // convert to 1-indexed

Console.WriteLine(bt.RangeQuery(2, 5));   // 2 + (-1) + 6 + 5 = 12
bt.Update(3, 4);                          // nums[2] += 4 → nums[2] = 3
Console.WriteLine(bt.RangeQuery(2, 5));   // 2 + 3 + 6 + 5 = 16
```

**Build in O(n) instead of O(n log n)**
```csharp
public FenwickTree(int[] nums)
{
    _n    = nums.Length;
    _tree = new long[_n + 1];

    // O(n) build: copy then propagate
    for (int i = 1; i <= _n; i++)
    {
        _tree[i] += nums[i - 1];
        int parent = i + (i & -i);
        if (parent <= _n) _tree[parent] += _tree[i];
    }
}
```

**Order statistics — find kth smallest element**
```csharp
// BIT tracking frequency of values — supports "how many elements ≤ x?" queries
public class OrderStatisticBIT
{
    private readonly FenwickTree _bit;
    private readonly int _maxVal;

    public OrderStatisticBIT(int maxVal)
    {
        _maxVal = maxVal;
        _bit    = new FenwickTree(maxVal);
    }

    public void Insert(int val)   => _bit.Update(val, 1);
    public void Remove(int val)   => _bit.Update(val, -1);
    public long CountLeq(int val) => _bit.Query(Math.Min(val, _maxVal));

    // Kth smallest: binary search on the BIT — O(log²n) naive, O(log n) with descent
    public int KthSmallest(int k)
    {
        int lo = 1, hi = _maxVal;
        while (lo < hi)
        {
            int mid = (lo + hi) / 2;
            if (_bit.Query(mid) >= k) hi = mid;
            else lo = mid + 1;
        }
        return lo;
    }
}
```

**What NOT to do — and the fix**
```csharp
// BAD: 0-indexed Fenwick tree — i & -i on 0 is 0 → infinite loop
public void UpdateBad(int i, long delta)
{
    for (; i < _n; i += i & -i)    // when i=0: 0 & -0 = 0, infinite loop
        _tree[i] += delta;
}

// GOOD: always 1-indexed — convert at the call site
public void Insert(int[] nums, FenwickTree bt)
{
    for (int i = 0; i < nums.Length; i++)
        bt.Update(i + 1, nums[i]);   // i+1 converts to 1-indexed
}
```

---

## Real World Example

A competitive programming judge tracks submission scores for a contest with 100,000 participants. At any moment it must answer: "how many participants have scored more than X?" (prefix count query) and update a participant's score instantly when they make a submission. With submissions arriving thousands of times per second, a Fenwick tree over the score range answers both in O(log(maxScore)).

```csharp
public class ContestLeaderboard
{
    private readonly FenwickTree _scoreCount;
    private readonly Dictionary<string, int> _currentScore = new();
    private readonly int _maxScore;

    public ContestLeaderboard(int maxScore)
    {
        _maxScore   = maxScore;
        _scoreCount = new FenwickTree(maxScore);
    }

    // Called when a participant improves their score
    public void UpdateScore(string participantId, int newScore)
    {
        if (_currentScore.TryGetValue(participantId, out int old))
            _scoreCount.Update(old, -1);    // remove old score from frequency

        _currentScore[participantId] = newScore;
        _scoreCount.Update(newScore, 1);    // add new score
    }

    // How many participants have score strictly greater than threshold?
    public long CountAbove(int threshold)
    {
        if (threshold >= _maxScore) return 0;
        long total = _scoreCount.Query(_maxScore);
        long lte   = _scoreCount.Query(threshold);
        return total - lte;
    }

    // Rank of a participant (1 = highest score)
    public long GetRank(string participantId)
    {
        if (!_currentScore.TryGetValue(participantId, out int score))
            return -1;
        return CountAbove(score) + 1;
    }
}
```

*The key insight is treating the score range as an implicit array: position `v` tracks how many participants currently have score `v`. A point update (`Update(score, ±1)`) changes a participant's score; a prefix query (`Query(x)`) counts all participants with score ≤ x. Rank is then total − countAbove.*

---

## Common Misconceptions

**"A Fenwick tree can do everything a segment tree can"**
It can't. A Fenwick tree supports: range sum queries, point updates, and (with two BITs) range updates + range sum queries. It cannot do range min/max, range GCD, or any aggregate where the inverse operation doesn't exist. If you need those, use a segment tree.

**"The `i & -i` trick is magic — I don't need to understand it"**
It's not magic — it's two's complement arithmetic. In two's complement, `-i` flips all bits and adds 1. The result of `i & -i` isolates the lowest set bit of `i`. This determines which range of elements index `i` in the Fenwick tree is responsible for. Understanding this makes the algorithm predictable rather than magical.

**"Fenwick trees must be 1-indexed — you can adapt them to 0-indexed"**
Technically possible but error-prone. The `i & -i` operation returns 0 when `i = 0`, causing an infinite loop. The standard solution is always to use 1-indexed arrays and convert at the call site (`original_index + 1`). Don't fight the convention.

---

## Gotchas

- **Always 1-indexed — never call `Update(0, ...)` or `Query(0)`.** `i & -i` = 0 when `i = 0`, causing an infinite loop. Convert all 0-indexed inputs to 1-indexed at the call site.

- **Point update modifies a delta, not an absolute value.** `Update(i, delta)` adds `delta` to position `i`. To set position `i` to a new value, you must first subtract the old value: `Update(i, newVal - oldVal)`. This is a common source of bugs when updating an array that's already been loaded.

- **Range sum uses `Query(r) - Query(l-1)`, not `Query(r) - Query(l)`.** The query is for prefix sums [1..i] inclusive. The range [l..r] is `Query(r) - Query(l-1)`. Using `Query(l)` instead of `Query(l-1)` excludes the element at position l.

- **Overflow: use `long` for large datasets.** If elements can be large or there are many of them, `int` sums overflow silently. Always use `long` for the tree array in competitive programming contexts.

- **A Fenwick tree cannot answer range min/max queries.** The subtraction trick `Query(r) - Query(l-1)` only works for invertible operations (sum). Min and max are not invertible — you can't recover the minimum of a subrange from prefix minimums. Use a sparse table (static) or segment tree (dynamic) for range min/max.

---

## Interview Angle

**What they're really testing:** Whether you know this structure exists and when it's a simpler alternative to a segment tree — and whether you can explain the bit trick without hand-waving it away.

**Common question forms:**
- "Range Sum Query — Mutable" (same as the segment tree problem — Fenwick is the simpler solution)
- "Count of Smaller Numbers After Self" (requires coordinate compression + BIT)
- "Reverse pairs" (merge sort or BIT with coordinate compression)

**The depth signal:** A junior implements a segment tree for range sum + point update (correct but over-engineered). A senior reaches for the Fenwick tree — less code, faster in practice, same complexity. The elite signal is being able to explain *why* `i & -i` moves you up or down the implicit tree, and knowing the difference between segment tree and Fenwick tree capabilities without needing to look it up.

**Follow-up questions to expect:**
- "When would you use a segment tree instead?" (Range min/max, range updates, lazy propagation)
- "Explain what `i & -i` does." (Isolates the lowest set bit — two's complement arithmetic)
- "Can you support range updates?" (Yes — use two BITs: one for delta, one for delta × index; requires a specific derivation)

---

## Related Topics

- [[algorithms/datastructures/segment-tree.md]] — The more powerful alternative; use when Fenwick's constraints are too limiting.
- [[algorithms/datastructures/array.md]] — Prefix sums for the static case (no updates); O(1) query after O(n) build.

---

## Source

https://en.wikipedia.org/wiki/Fenwick_tree

---

*Last updated: 2026-04-12*