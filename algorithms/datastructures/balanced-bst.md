# Balanced BST
> A binary search tree that automatically maintains O(log n) height by rebalancing after insertions and deletions.

---

## When To Use It
Use a balanced BST when you need sorted order with fast lookup, insertion, and deletion — all O(log n). It's the right choice over a hash table when you need range queries, predecessor/successor, or sorted iteration. Use it over a plain BST when input might be sorted or adversarial, which would degrade a plain BST to O(n).

---

## Core Concept
A plain BST gives O(log n) operations only if the tree stays balanced. Insert keys in sorted order and you get a linked list — O(n) everything. A balanced BST fixes this by restructuring after every mutation. The two most common variants are AVL trees (strict: height difference between siblings ≤ 1) and Red-Black trees (relaxed: longer path is at most 2× shorter path). AVL trees are faster for lookups; Red-Black trees are faster for insertions and deletions. Most language standard libraries use Red-Black trees — Java's `TreeMap`, C++'s `std::map`, and Python's `sortedcontainers.SortedList`.

The key operation is **rotation** — rewiring parent-child pointers to reduce height without violating the BST property.

---

## The Code

**Using C# SortedSet (backed by a Red-Black tree with O(log n) ops)**
```csharp
using System.Collections.Generic;

var ss = new SortedSet<int>();
ss.Add(5);
ss.Add(2);
ss.Add(8);
ss.Add(1);

Console.WriteLine(string.Join(", ", ss));       // 1, 2, 5, 8
Console.WriteLine(ss.Min);         // 1  — O(log n) min access
ss.Remove(2);         // O(log n) removal
Console.WriteLine(ss.Contains(2));       // O(log n) membership
```

**Range query — find all values between lo and hi**
```csharp
using System.Linq;

var ss = new SortedSet<int> { 1, 3, 5, 7, 9, 11 };
int lo = 4, hi = 10;
// GetViewBetween returns a view/subset of elements in [lo, hi]
var result = ss.GetViewBetween(lo, hi).ToList();  // [5, 7, 9]
```

**AVL rotation — the core rebalancing primitive**
```csharp
public class AVLNode
{
    public int Val { get; set; }
    public AVLNode Left { get; set; }
    public AVLNode Right { get; set; }
    public int Height { get; set; } = 1;
}

private int GetHeight(AVLNode node) => node?.Height ?? 0;

private int GetBalance(AVLNode node) => node == null ? 0 : GetHeight(node.Left) - GetHeight(node.Right);

private AVLNode RotateRight(AVLNode y)
{
    var x = y.Left;
    var t2 = x.Right;
    x.Right = y;          // perform rotation
    y.Left = t2;
    y.Height = 1 + Math.Max(GetHeight(y.Left), GetHeight(y.Right));
    x.Height = 1 + Math.Max(GetHeight(x.Left), GetHeight(x.Right));
    return x;             // new root
}

private AVLNode RotateLeft(AVLNode x)
{
    var y = x.Right;
    var t2 = y.Left;
    y.Left = x;
    x.Right = t2;
    x.Height = 1 + Math.Max(GetHeight(x.Left), GetHeight(x.Right));
    y.Height = 1 + Math.Max(GetHeight(y.Left), GetHeight(y.Right));
    return y;
}
```

---

## Gotchas

- **Python has no built-in balanced BST.** The `sortedcontainers` library is the standard substitute. In interviews, state this upfront: "Python doesn't have a native BST, I'd use `SortedList` or simulate it with a heap + lazy deletion."
- **Inorder traversal of a BST gives sorted output.** This is the property that makes BSTs useful for ordered iteration — and it's tested directly in interviews.
- **Rotations preserve the BST property.** After a rotation, every node in the left subtree is still smaller than the root, and every node in the right subtree is still larger. This is non-obvious and worth verifying when implementing manually.
- **Red-Black trees are not strictly balanced.** The longest path can be up to 2× the shortest. Operations are O(log n) but with a larger constant than AVL. This is the trade-off for fewer rotations on insert/delete.
- **Range queries are O(log n + k) where k is the number of results.** You pay O(log n) to find the start of the range, then O(k) to iterate. If k ≈ n, the range query is O(n) — don't confuse this with O(log n).

---

## Interview Angle

**What they're really testing:** Whether you know when to reach for an ordered structure instead of a hash map, and whether you understand what "balanced" actually means.

**Common question form:** "Find all elements between X and Y," "find the kth smallest element," "design a data structure that supports insert, delete, and get-min in O(log n)."

**The depth signal:** A junior knows BSTs give sorted order. A senior knows the difference between AVL and Red-Black trees, can articulate when O(log n) degrades to O(n) on a plain BST, and knows that most standard library ordered maps are Red-Black trees for better insert/delete performance. They also recognize that a heap gives O(1) min but no range queries, while a BST gives O(log n) min with full range support.

---

## Related Topics

- [[algorithms/tree.md]] — Fundamentals of binary trees that balanced BSTs build on.
- [[algorithms/heap.md]] — Also gives O(log n) insert/delete but optimized for min/max, not range queries.
- [[algorithms/hash-table.md]] — O(1) average for point lookups, but no ordering. The alternative when sorted order isn't needed.

---

## Source

https://en.wikipedia.org/wiki/AVL_tree

---

*Last updated: 2026-03-24*