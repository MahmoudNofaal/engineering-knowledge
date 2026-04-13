# Balanced BST

> A binary search tree that automatically maintains O(log n) height by rebalancing after insertions and deletions.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Self-balancing sorted tree — O(log n) on all ops |
| **Use when** | Sorted order + fast lookup + range queries |
| **Avoid when** | Only need O(1) point lookup — use a hash table |
| **C# version** | C# 2.0 (`SortedSet<T>`, `SortedDictionary<K,V>`) |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `SortedSet<T>`, `SortedDictionary<TKey,TValue>` |

---

## When To Use It

Use a balanced BST when you need sorted order with fast lookup, insertion, and deletion — all O(log n). It's the right choice over a hash table when you need range queries ("all elements between X and Y"), predecessor/successor ("next smaller/larger than X"), or sorted iteration. It's right over a plain BST when input could be sorted or adversarial — inserting already-sorted data into a plain BST produces a linked list with O(n) everything.

In C#, you almost never implement a balanced BST from scratch in production. `SortedSet<T>` (Red-Black tree, no duplicate keys) and `SortedDictionary<TKey, TValue>` (Red-Black tree, key-value pairs) cover the practical use cases. Implement AVL or Red-Black manually only when an interview explicitly asks for it.

Avoid it when you don't need ordering — a `Dictionary<TKey, TValue>` is O(1) average and requires less code. Avoid it when you need frequent arbitrary-position insertions with O(1) — no tree structure achieves that.

---

## Core Concept

A plain BST gives O(log n) operations only if the tree stays balanced. Insert keys in sorted order and you get a linked list — O(n) everything. A balanced BST fixes this by restructuring after every mutation using **rotations** — local pointer rewirings that reduce height without violating the BST property.

Two main variants:

**AVL tree:** Strictly balanced — height difference between any node's left and right subtrees is at most 1. Faster for read-heavy workloads (height is very close to log₂ n) but requires more rotations on insert/delete.

**Red-Black tree:** Relaxed balance — no path from root to leaf is more than twice as long as any other. Fewer rotations on insert/delete, making writes faster. This is what most standard libraries use, including .NET's `SortedSet<T>` and `SortedDictionary<TKey, TValue>`, Java's `TreeMap`, and C++'s `std::map`.

The practical takeaway: Red-Black trees are the default because they balance write performance with read performance at reasonable constant factors. AVL trees appear in read-dominant, write-rare scenarios (e.g. in-memory indexes that are built once then queried heavily).

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 2.0 | .NET 2.0 | `SortedDictionary<K,V>` and `SortedList<K,V>` introduced |
| C# 3.0 | .NET 3.5 | `SortedSet<T>` added — Red-Black tree, no duplicate keys |
| C# 6.0 | .NET 4.6 | `SortedSet<T>` gains `GetViewBetween` for O(log n + k) range views |
| C# 9.0 | .NET 5 | `ImmutableSortedSet<T>` and `ImmutableSortedDictionary<K,V>` available via NuGet |
| C# 12.0 | .NET 8 | `FrozenDictionary<K,V>` available for read-only optimal lookup (not sorted) |

*`SortedList<K,V>` is array-backed (not a tree) — it's O(log n) for lookup but O(n) for insert/delete due to shifting. Don't confuse it with `SortedDictionary<K,V>` which is the actual tree.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Insert | O(log n) | Sift into position + rebalance rotations |
| Delete | O(log n) | Remove + rebalance |
| Lookup (exact) | O(log n) | Binary search down the tree |
| Min / Max | O(log n) | Walk leftmost / rightmost path |
| Predecessor / Successor | O(log n) | Inorder neighbour |
| Range query | O(log n + k) | k = number of elements in range |
| Sorted iteration | O(n) | Inorder traversal — fully sorted |

**Allocation behaviour:** Each node in `SortedSet<T>` is a heap-allocated object with value, left, right, parent references, and a color bit (Red-Black). Memory per node is higher than an array slot — roughly 32–40 bytes per node on 64-bit. For n elements, this is n × ~40 bytes vs n × element_size for an array.

**Benchmark notes:** `SortedSet<T>` insert/lookup is consistently slower than `HashSet<T>` because O(log n) with pointer chasing vs O(1) with a hash. The tree wins when you need sorted access or range queries. For sets of under ~1,000 elements where ordering matters occasionally, consider sorting a `List<T>` on demand — cheaper than maintaining a BST for infrequent ordered access.

---

## The Code

**Basic SortedSet<T> operations**
```csharp
var set = new SortedSet<int>();
set.Add(5);
set.Add(2);
set.Add(8);
set.Add(1);
set.Add(5);   // duplicate — ignored, SortedSet doesn't allow duplicates

Console.WriteLine(string.Join(", ", set));   // 1, 2, 5, 8
Console.WriteLine(set.Min);    // 1 — O(log n)
Console.WriteLine(set.Max);    // 8 — O(log n)
set.Remove(2);                 // O(log n)
Console.WriteLine(set.Contains(5));   // true — O(log n)
```

**Range query — O(log n + k)**
```csharp
var set = new SortedSet<int> { 1, 3, 5, 7, 9, 11, 13 };

// GetViewBetween returns a live view — mutations to the view affect the original set
SortedSet<int> range = set.GetViewBetween(4, 10);
Console.WriteLine(string.Join(", ", range));   // 5, 7, 9

// Predecessor / successor pattern
int key = 6;
// Largest element ≤ key
var lte = set.GetViewBetween(set.Min, key);
int predecessor = lte.Count > 0 ? lte.Max : -1;   // 5

// Smallest element ≥ key
var gte = set.GetViewBetween(key, set.Max);
int successor = gte.Count > 0 ? gte.Min : -1;      // 7
```

**AVL rotation — the core rebalancing primitive (interview implementation)**
```csharp
public class AvlNode
{
    public int Val, Height;
    public AvlNode? Left, Right;
    public AvlNode(int val) { Val = val; Height = 1; }
}

private static int H(AvlNode? n) => n?.Height ?? 0;
private static int Balance(AvlNode? n) => n == null ? 0 : H(n.Left) - H(n.Right);
private static void Update(AvlNode n) => n.Height = 1 + Math.Max(H(n.Left), H(n.Right));

private static AvlNode RotateRight(AvlNode y)
{
    AvlNode x = y.Left!, t = x.Right!;
    x.Right = y; y.Left = t;
    Update(y); Update(x);
    return x;   // new subtree root
}

private static AvlNode RotateLeft(AvlNode x)
{
    AvlNode y = x.Right!, t = y.Left!;
    y.Left = x; x.Right = t;
    Update(x); Update(y);
    return y;
}

public static AvlNode? Insert(AvlNode? node, int val)
{
    if (node == null) return new AvlNode(val);
    if (val < node.Val) node.Left  = Insert(node.Left,  val);
    else if (val > node.Val) node.Right = Insert(node.Right, val);
    else return node;   // duplicate

    Update(node);
    int bf = Balance(node);

    if (bf > 1 && val < node.Left!.Val)   return RotateRight(node);              // LL
    if (bf < -1 && val > node.Right!.Val) return RotateLeft(node);               // RR
    if (bf > 1 && val > node.Left!.Val)   { node.Left = RotateLeft(node.Left!); return RotateRight(node); }  // LR
    if (bf < -1 && val < node.Right!.Val) { node.Right = RotateRight(node.Right!); return RotateLeft(node); } // RL
    return node;
}
```

**What NOT to do — and the fix**
```csharp
// BAD: using SortedList<K,V> expecting tree performance on insert/delete
var sortedList = new SortedList<int, string>();
for (int i = 0; i < 100_000; i++)
    sortedList.Add(i, $"v{i}");   // O(n) per insert due to array shifting — O(n²) total

// GOOD: SortedDictionary<K,V> is the actual tree — O(log n) insert
var sortedDict = new SortedDictionary<int, string>();
for (int i = 0; i < 100_000; i++)
    sortedDict.Add(i, $"v{i}");   // O(log n) per insert — O(n log n) total
```

---

## Real World Example

A leaderboard service for a multiplayer game must support three operations continuously: update a player's score, query the top-k players, and query a player's rank. A hash map handles score storage, but ranking requires sorted access. A `SortedSet<(int score, string playerId)>` maintains the leaderboard in score order — composite key ensures no two players collide even with identical scores.

```csharp
public class Leaderboard
{
    // Composite key: (negated score for descending order, playerId for uniqueness)
    private readonly SortedSet<(int negScore, string id)> _ranked = new();
    private readonly Dictionary<string, int> _scores = new();

    public void UpdateScore(string playerId, int newScore)
    {
        // Remove old entry if exists
        if (_scores.TryGetValue(playerId, out int oldScore))
            _ranked.Remove((-oldScore, playerId));

        _scores[playerId] = newScore;
        _ranked.Add((-newScore, playerId));   // negate for descending order
    }

    // Top k players in O(k log n)
    public List<(string id, int score)> TopK(int k)
        => _ranked.Take(k)
                  .Select(entry => (entry.id, -entry.negScore))
                  .ToList();

    // Rank of a specific player in O(log n + rank) — SortedSet has no O(1) rank
    public int GetRank(string playerId)
    {
        if (!_scores.TryGetValue(playerId, out int score)) return -1;
        // Count how many players have a higher score
        var above = _ranked.GetViewBetween(
            _ranked.Min,
            (-score - 1, string.Empty));   // all entries with negScore < -score (i.e. score > score)
        return above.Count + 1;
    }
}
```

*The key insight is the composite key `(-score, playerId)`: negating the score makes the SortedSet's natural ascending order give us descending score order, and the playerId component ensures two players with the same score get distinct keys — no silent overwrites.*

---

## Common Misconceptions

**"`SortedList<K,V>` and `SortedDictionary<K,V>` are interchangeable"**
They're not. `SortedList<K,V>` is backed by two arrays (keys and values) — it uses less memory and has better cache performance for read-heavy workloads, but insert and delete are O(n) due to array shifting. `SortedDictionary<K,V>` is a Red-Black tree — O(log n) insert/delete, more memory per node. Use `SortedList` for small, mostly static datasets; `SortedDictionary` for any dataset that mutates frequently.

**"Red-Black trees are strictly balanced"**
They're not. The Red-Black property guarantees that no path from root to leaf is more than twice as long as any other — so height is O(log n), but not as tightly bounded as AVL. AVL guarantees height ≤ 1.44 log₂ n; Red-Black guarantees height ≤ 2 log₂ n. The relaxed constraint means fewer rotations on writes, which is the trade-off.

**"`SortedSet<T>` allows duplicates"**
It doesn't. `SortedSet<T>` is a set — adding a duplicate is silently ignored. If you need a sorted collection with duplicates (a sorted multiset), use `SortedDictionary<T, int>` with a frequency count as the value, or a sorted `List<T>`.

---

## Gotchas

- **`SortedSet<T>.GetViewBetween` is a live view, not a copy.** Mutations through the view affect the underlying set, and mutations to the set are reflected in the view. If you need a snapshot, call `.ToList()` on the view.

- **Range query complexity is O(log n + k), not O(log n).** You pay O(log n) to find the range start, then O(k) to iterate. If k ≈ n, the range query is effectively O(n). Don't confuse "O(log n) to find the boundary" with "O(log n) for the whole query."

- **Python has no built-in balanced BST.** In Python interviews, use `sortedcontainers.SortedList` (third-party) or state upfront that you'd use it. Never pretend a Python `dict` gives sorted access.

- **Rotations preserve the BST property.** After any rotation, every node in the left subtree is still less than the current root, and every node in the right subtree is still greater. This is non-obvious and worth verifying manually when implementing.

- **`SortedSet<T>` has no `GetRank` or index access.** There's no O(log n) "give me the kth element" or "what's the rank of this element" operation in .NET's `SortedSet<T>`. Counting elements up to a value requires `GetViewBetween(...).Count` which iterates. A true order-statistic tree would solve this but isn't in the BCL.

---

## Interview Angle

**What they're really testing:** Whether you know when to reach for an ordered structure instead of a hash map, and whether you understand what "balanced" means and why it matters.

**Common question forms:**
- "Find all elements between X and Y" (range query)
- "Find the kth smallest element" (rank query)
- "Design a data structure that supports insert, delete, and get-min in O(log n)"
- "Implement an AVL tree" (explicit implementation request)

**The depth signal:** A junior knows BSTs give sorted order. A senior knows the difference between AVL (stricter, faster reads) and Red-Black (fewer rotations, faster writes), knows that `SortedList` is array-backed while `SortedDictionary` is tree-backed, and can articulate when O(log n) degrades to O(n) without balancing. The elite signal is awareness that `SortedSet<T>` lacks O(log n) rank queries (an order-statistic tree would be needed) and knowing the `SortedList` vs `SortedDictionary` trap.

**Follow-up questions to expect:**
- "What's the difference between AVL and Red-Black?" (Strictness of balance, rotation frequency — AVL reads faster, RB writes faster)
- "How would you get the kth smallest in O(log n)?" (Augment each node with subtree size — an order-statistic tree)
- "Why does your BST degrade to O(n)?" (Sorted insertion creates a linked list — every new node becomes the rightmost leaf)

---

## Related Topics

- [[algorithms/datastructures/tree.md]] — Fundamentals of binary trees that balanced BSTs build on.
- [[algorithms/datastructures/heap.md]] — Also O(log n) insert/delete, but optimised for min/max only — no range queries or sorted iteration.
- [[algorithms/datastructures/hash-table.md]] — O(1) average for point lookups, no ordering. The alternative when sorted order isn't needed.
- [[algorithms/datastructures/segment-tree.md]] — For range aggregate queries (sum, min, max) on arrays — different from BST range membership queries.

---

## Source

https://en.wikipedia.org/wiki/AVL_tree

---

*Last updated: 2026-04-12*