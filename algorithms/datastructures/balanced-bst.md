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

**Using Python's sortedcontainers (backed by a sorted list with O(log n) ops)**
```python
from sortedcontainers import SortedList

sl = SortedList()
sl.add(5)
sl.add(2)
sl.add(8)
sl.add(1)

print(sl)            # SortedList([1, 2, 5, 8])
print(sl[0])         # 1  — O(log n) index access
sl.remove(2)         # O(log n) removal
print(2 in sl)       # O(log n) membership
print(sl.bisect_left(5))  # 1 — index where 5 would be inserted
```

**Range query — find all values between lo and hi**
```python
from sortedcontainers import SortedList

sl = SortedList([1, 3, 5, 7, 9, 11])
lo, hi = 4, 10
# irange returns an iterator over keys in [lo, hi]
result = list(sl.irange(lo, hi))  # [5, 7, 9]
```

**AVL rotation — the core rebalancing primitive**
```python
class AVLNode:
    def __init__(self, val):
        self.val = val
        self.left = self.right = None
        self.height = 1

def get_height(node) -> int:
    return node.height if node else 0

def get_balance(node) -> int:
    return get_height(node.left) - get_height(node.right) if node else 0

def rotate_right(y: AVLNode) -> AVLNode:
    x = y.left
    T2 = x.right
    x.right = y          # perform rotation
    y.left = T2
    y.height = 1 + max(get_height(y.left), get_height(y.right))
    x.height = 1 + max(get_height(x.left), get_height(x.right))
    return x             # new root

def rotate_left(x: AVLNode) -> AVLNode:
    y = x.right
    T2 = y.left
    y.left = x
    x.right = T2
    x.height = 1 + max(get_height(x.left), get_height(x.right))
    y.height = 1 + max(get_height(y.left), get_height(y.right))
    return y
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