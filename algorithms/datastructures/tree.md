# Tree

> A hierarchical data structure of nodes connected by edges, with one root and no cycles — the foundation of file systems, DOM, compilers, and most search algorithms.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Acyclic connected graph with a designated root node |
| **Use when** | Hierarchical data, BST search/insert/delete, trie, heap, parse trees |
| **Avoid when** | Data is inherently flat (use array/list) or needs cycle support (use graph) |
| **C# version** | No built-in generic tree; `SortedSet<T>` uses a Red-Black tree internally |
| **Namespace** | Custom implementation; `System.Collections.Generic.SortedSet<T>` |
| **Key types** | Custom `TreeNode<T>`, `SortedSet<T>`, `SortedDictionary<K,V>` |

---

## When To Use It

Trees appear everywhere: file systems, XML/JSON DOM, expression evaluation, compiler ASTs, and database indexes (B-trees). In interviews, "tree" almost always means **binary tree** or **binary search tree (BST)**. A BST provides O(log n) average search, insert, and delete when balanced. An unbalanced BST degrades to O(n) — a sorted insert sequence produces a linked list. Use a balanced BST (`SortedSet<T>`, backed by Red-Black tree) when you need guaranteed O(log n).

---

## Core Concept

A tree is defined recursively: a root node with zero or more child subtrees. Key vocabulary:
- **Height**: longest path from root to a leaf.
- **Depth**: distance from root to a node.
- **Complete binary tree**: all levels full except possibly the last, filled left-to-right (heap property).
- **Perfect binary tree**: all levels completely full.
- **Balanced BST**: height is O(log n) — AVL or Red-Black tree.

BST property: for every node, all left descendants are smaller, all right descendants are larger. This enables binary search: at each node, eliminate half the tree.

Three DFS traversals define the visit order:
- **Inorder (left → node → right)**: gives BST elements in sorted order.
- **Preorder (node → left → right)**: used for serialisation/copying.
- **Postorder (left → right → node)**: used for deletion, expression evaluation.

---

## Algorithm History

| Year | Development |
|---|---|
| 1960 | Binary search tree formalised |
| 1962 | AVL tree — first self-balancing BST (Adelson-Velsky and Landis) |
| 1972 | Red-Black tree invented by Rudolf Bayer |
| 1970s | B-tree invented for disk-based indexes (Bayer and McCreight) |
| 1990s | C# `SortedSet<T>` and `SortedDictionary<K,V>` backed by Red-Black tree |

---

## Performance

| Operation | BST (average) | BST (worst) | Balanced BST |
|---|---|---|---|
| Search | O(log n) | O(n) | O(log n) |
| Insert | O(log n) | O(n) | O(log n) |
| Delete | O(log n) | O(n) | O(log n) |
| Min/Max | O(log n) | O(n) | O(log n) |
| Inorder traversal | O(n) | O(n) | O(n) |
| Height | O(log n) | O(n) | O(log n) |

**Allocation behaviour:** Each node is a separate heap allocation (reference type). For n nodes, n allocations. This gives worse cache performance than an array-backed heap but allows arbitrary tree shape.

---

## The Code

**Scenario 1 — binary tree node and traversals**
```csharp
public class TreeNode
{
    public int Val;
    public TreeNode? Left, Right;
    public TreeNode(int val = 0, TreeNode? left = null, TreeNode? right = null)
        => (Val, Left, Right) = (val, left, right);
}

public List<int> Inorder(TreeNode? root)   // sorted order for BST
{
    var result = new List<int>();
    void Dfs(TreeNode? node) {
        if (node == null) return;
        Dfs(node.Left); result.Add(node.Val); Dfs(node.Right);
    }
    Dfs(root); return result;
}

// Iterative inorder — avoids stack overflow for deep trees
public List<int> InorderIterative(TreeNode? root)
{
    var result = new List<int>();
    var stack  = new Stack<TreeNode>();
    var curr   = root;
    while (curr != null || stack.Count > 0)
    {
        while (curr != null) { stack.Push(curr); curr = curr.Left; }
        curr = stack.Pop();
        result.Add(curr.Val);
        curr = curr.Right;
    }
    return result;
}
```

**Scenario 2 — BST insert, search, validate**
```csharp
public TreeNode? Insert(TreeNode? root, int val)
{
    if (root == null) return new TreeNode(val);
    if (val < root.Val) root.Left  = Insert(root.Left,  val);
    else if (val > root.Val) root.Right = Insert(root.Right, val);
    return root; // duplicate: ignore
}

public bool Search(TreeNode? root, int val)
{
    while (root != null)
    {
        if (val == root.Val) return true;
        root = val < root.Val ? root.Left : root.Right;
    }
    return false;
}

// Validate BST: every node must be in (min, max) range
public bool IsValidBST(TreeNode? node, long min = long.MinValue, long max = long.MaxValue)
{
    if (node == null) return true;
    if (node.Val <= min || node.Val >= max) return false;
    return IsValidBST(node.Left, min, node.Val) &&
           IsValidBST(node.Right, node.Val, max);
}
```

**Scenario 3 — lowest common ancestor (LCA)**
```csharp
public TreeNode? LCA(TreeNode? root, TreeNode p, TreeNode q)
{
    if (root == null || root == p || root == q) return root;
    var left  = LCA(root.Left,  p, q);
    var right = LCA(root.Right, p, q);
    // If found in both subtrees, this node is the LCA
    if (left != null && right != null) return root;
    return left ?? right; // one side found both
}
```

**Scenario 4 — what NOT to do: validate BST with only parent comparison**
```csharp
// BAD: only checks immediate parent — misses subtree range violations
public bool IsValidBSTBad(TreeNode? node)
{
    if (node == null) return true;
    if (node.Left  != null && node.Left.Val  >= node.Val) return false;
    if (node.Right != null && node.Right.Val <= node.Val) return false;
    return IsValidBSTBad(node.Left) && IsValidBSTBad(node.Right);
    // WRONG: a right-subtree node could be smaller than the root's ancestor
    // e.g.  root=5, right=6, right.left=1 → 1 < 5 but passes the local check
}

// GOOD: carry (min, max) bounds down the tree
public bool IsValidBSTGood(TreeNode? node, long min, long max)
{
    if (node == null) return true;
    if (node.Val <= min || node.Val >= max) return false;
    return IsValidBSTGood(node.Left,  min,      node.Val) &&
           IsValidBSTGood(node.Right, node.Val, max);
}
```

---

## Real World Example

The `CategoryTreeService` in a product catalogue system stores the product category hierarchy as a tree. Categories can be nested arbitrarily deep. The service supports finding all ancestors of a category (path to root) and all descendants (subtree traversal) for filtering and breadcrumb generation.

```csharp
public class CategoryTreeService
{
    public record Category(int Id, string Name, int? ParentId);

    private readonly Dictionary<int, Category> _byId;
    private readonly Dictionary<int, List<int>> _children; // parentId → childIds

    public CategoryTreeService(List<Category> categories)
    {
        _byId     = categories.ToDictionary(c => c.Id);
        _children = categories.GroupBy(c => c.ParentId ?? -1)
                              .ToDictionary(g => g.Key, g => g.Select(c => c.Id).ToList());
    }

    // DFS postorder: collect all descendant IDs — O(subtree size)
    public List<int> GetAllDescendants(int categoryId)
    {
        var result = new List<int>();
        var stack  = new Stack<int>();
        stack.Push(categoryId);
        while (stack.Count > 0)
        {
            int id = stack.Pop();
            if (id != categoryId) result.Add(id); // exclude the root itself
            if (_children.TryGetValue(id, out var children))
                foreach (int child in children) stack.Push(child);
        }
        return result;
    }

    // Walk up via ParentId — O(depth)
    public List<Category> GetBreadcrumb(int categoryId)
    {
        var path = new List<Category>();
        int? current = categoryId;
        while (current.HasValue && _byId.TryGetValue(current.Value, out var cat))
        {
            path.Add(cat);
            current = cat.ParentId;
        }
        path.Reverse(); // root first
        return path;
    }
}
```

*The key insight: storing both `_byId` (O(1) lookup) and `_children` (O(1) adjacency) makes both upward (breadcrumb) and downward (descendants) traversal efficient. Without `_children`, finding descendants requires a full O(n) scan per level.*

---

## Common Misconceptions

**"BST search is always O(log n)"**
Only if the tree is balanced. Inserting elements in sorted order (1, 2, 3, 4, ...) into a plain BST produces a right-skewed linked list — O(n) search. Use `SortedSet<T>` (Red-Black tree) for guaranteed O(log n).

**"Inorder traversal produces sorted output for any binary tree"**
Only for a binary search tree. Inorder on a random binary tree produces the left-subtree-inorder then root then right-subtree-inorder — meaningful only when the BST property holds.

**"Leaf nodes have depth 0"**
Depth is measured from the root. The root has depth 0. Leaves have the maximum depth. Height is the maximum depth of any leaf — the longest root-to-leaf path.

---

## Gotchas

- **BST validation requires propagating range bounds**, not just comparing with the immediate parent. The classic interview trap.
- **Deleting from a BST is more complex than insert.** Find the node; if it has two children, replace its value with the inorder successor (leftmost node of the right subtree), then delete the inorder successor.
- **Recursive tree traversal can stack-overflow on deep trees.** A perfectly unbalanced BST of n nodes is a chain of depth n. For n = 10,000, that's 10,000 stack frames. Convert to iterative for production code.
- **`SortedSet<T>` and `SortedDictionary<K,V>` don't expose the tree structure.** They are BSTs internally but expose a set/dict interface. You can't traverse the tree directly.

---

## Interview Angle

**What they're really testing:** Pointer manipulation on trees, recursive vs iterative traversal, and BST properties (search, validate, insert, delete, LCA).

**Common question forms:** Inorder/preorder/postorder traversal. Validate BST. Level-order traversal (BFS). Max depth. Lowest common ancestor. Serialize and deserialize.

**The depth signal:** A junior traverses recursively. A senior implements iterative inorder (stack + curr pointer), catches the BST validation trap (range bounds, not parent comparison), and derives LCA with the two-found-in-both-subtrees pattern.

---

## Related Topics

- [[algorithms/searching/depth-first-search.md]] — All tree traversals are DFS variants.
- [[algorithms/searching/breadth-first-search.md]] — Level-order traversal is BFS on a tree.
- [[algorithms/datastructures/heap.md]] — A heap is a complete binary tree stored as an array.
- [[algorithms/datastructures/balanced-bst.md]] — AVL and Red-Black trees for guaranteed O(log n).

---

## Source

https://en.wikipedia.org/wiki/Binary_search_tree

---

*Last updated: 2026-04-21*