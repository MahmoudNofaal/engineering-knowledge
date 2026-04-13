# Tree

> A hierarchical data structure of nodes where each node has a value and zero or more children, with no cycles.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Hierarchical node structure, acyclic |
| **Use when** | Data is naturally nested or hierarchical |
| **Avoid when** | Data is flat, relational, or has cycles (use graph) |
| **C# version** | C# 1.0 (custom nodes) / C# 2.0 (generic node wrappers) |
| **Namespace** | Custom implementation — no BCL tree type |
| **Key types** | Custom `TreeNode`, `SortedSet<T>` (BST), `PriorityQueue<T,P>` (heap) |

---

## When To Use It

Use a tree when your data is naturally hierarchical — file systems, org charts, HTML DOM, decision trees, expression parsing, JSON structure. Binary trees specifically appear in BSTs (sorted lookup), heaps (priority), and tries (prefix search). The recursive structure of trees makes divide-and-conquer natural: most tree problems decompose cleanly into the same problem on left and right subtrees plus work at the current node.

Avoid trees when your data is flat (use an array or hash table), when relationships are many-to-many (use a graph — a tree is a special case of a graph with exactly one path between any two nodes), or when you need O(1) access by key (use a hash table). The .NET BCL has no general-purpose tree type — you'll always implement `TreeNode` yourself in an interview context, or use `SortedSet<T>` for BST behaviour.

---

## Core Concept

A tree is a connected, acyclic structure with a designated root. Every non-root node has exactly one parent; a node with no children is a leaf. In a binary tree, each node has at most two children — left and right.

The recursive structure enables elegant solutions. A problem on a tree almost always decomposes into: solve it on the left subtree, solve it on the right subtree, combine at the current node. This is the **return-value pattern**: decide what your recursive function should return, trust that the recursive call gives you the correct answer for the subtree, and focus only on what you do at the current level.

The three traversal orders are the foundation of everything else:
- **Inorder (left → node → right):** visits BST nodes in sorted order — the only traversal that gives you sorted output from a BST.
- **Preorder (node → left → right):** serialises a tree; visiting the root first lets you reconstruct the shape.
- **Postorder (left → right → node):** evaluates bottom-up — used for expression trees, deletion, aggregating subtree information.

BFS (level-order) uses a queue instead of the implicit recursion stack and processes nodes layer by layer — essential for "minimum depth," "level averages," and "zigzag traversal" problems.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Custom node classes — no BCL tree |
| C# 2.0 | .NET 2.0 | `SortedDictionary<K,V>` and `SortedSet<T>` added — Red-Black tree backed |
| C# 6.0 | .NET 4.6 | Expression-bodied members make recursive node methods more concise |
| C# 9.0 | .NET 5 | `record` types simplify immutable tree node definitions |
| C# 12.0 | .NET 8 | Primary constructors reduce `TreeNode` boilerplate significantly |

*The BCL has never shipped a general-purpose binary tree you can walk with arbitrary traversal. Interview `TreeNode` classes are always hand-written.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| DFS traversal | O(n) | Visits every node exactly once |
| BFS traversal | O(n) | Same — different order |
| Height / depth | O(n) | Must visit all nodes in worst case (skewed tree) |
| Insert (BST) | O(h) | h = height; O(log n) balanced, O(n) skewed |
| Search (BST) | O(h) | Same as insert |
| LCA | O(n) | Worst case visits all nodes |

**Allocation behaviour:** Each `TreeNode` is a heap-allocated object with two reference pointers (`Left`, `Right`). A tree of n nodes costs n heap allocations plus the reference overhead. Recursive DFS uses O(h) call stack frames — O(log n) for balanced, O(n) for skewed trees (stack overflow risk for large skewed inputs).

**Benchmark notes:** Recursive tree algorithms become a practical concern only at depths above ~10,000 frames (the CLR default stack is ~1 MB). For interview inputs this never matters. For production trees of unbounded depth, convert to iterative with an explicit stack.

---

## The Code

**Node definition**
```csharp
public class TreeNode
{
    public int Val;
    public TreeNode Left, Right;
    public TreeNode(int val) { Val = val; }
}
```

**Three DFS traversals — recursive**
```csharp
// Inorder: left → node → right (BST sorted order)
public static List<int> Inorder(TreeNode node)
{
    if (node == null) return new List<int>();
    var result = Inorder(node.Left);
    result.Add(node.Val);
    result.AddRange(Inorder(node.Right));
    return result;
}

// Preorder: node → left → right (serialisation)
public static List<int> Preorder(TreeNode node)
{
    if (node == null) return new List<int>();
    var result = new List<int> { node.Val };
    result.AddRange(Preorder(node.Left));
    result.AddRange(Preorder(node.Right));
    return result;
}

// Postorder: left → right → node (bottom-up aggregation)
public static List<int> Postorder(TreeNode node)
{
    if (node == null) return new List<int>();
    var result = Postorder(node.Left);
    result.AddRange(Postorder(node.Right));
    result.Add(node.Val);
    return result;
}
```

**Height and Level-order (BFS)**
```csharp
public static int Height(TreeNode node)
{
    if (node == null) return 0;
    return 1 + Math.Max(Height(node.Left), Height(node.Right));
}

public static List<List<int>> LevelOrder(TreeNode root)
{
    var result = new List<List<int>>();
    if (root == null) return result;

    var queue = new Queue<TreeNode>();
    queue.Enqueue(root);

    while (queue.Count > 0)
    {
        int levelSize = queue.Count;      // snapshot before adding children
        var level = new List<int>();
        for (int i = 0; i < levelSize; i++)
        {
            var node = queue.Dequeue();
            level.Add(node.Val);
            if (node.Left  != null) queue.Enqueue(node.Left);
            if (node.Right != null) queue.Enqueue(node.Right);
        }
        result.Add(level);
    }
    return result;
}
```

**Lowest Common Ancestor — the return-value pattern at its clearest**
```csharp
public static TreeNode LCA(TreeNode root, TreeNode p, TreeNode q)
{
    if (root == null || root == p || root == q)
        return root;   // base: found one of the targets (or ran off the tree)

    TreeNode left  = LCA(root.Left,  p, q);
    TreeNode right = LCA(root.Right, p, q);

    // If both sides returned non-null, p and q are in different subtrees
    if (left != null && right != null) return root;

    // Otherwise, one side has both — propagate that result up
    return left ?? right;
}
```

**Validate a BST — pass min/max bounds down**
```csharp
public static bool IsValidBST(TreeNode node, long min = long.MinValue, long max = long.MaxValue)
{
    if (node == null) return true;
    if (node.Val <= min || node.Val >= max) return false;
    return IsValidBST(node.Left,  min, node.Val)
        && IsValidBST(node.Right, node.Val, max);
}
```

**What NOT to do — and the fix**
```csharp
// BAD: checking BST validity by comparing only with the immediate parent
// This misses violations like:
//     5
//    / \
//   1   4       ← 4 < 5 but 4 is in the right subtree — invalid BST
//      / \
//     3   6
public static bool IsValidBSTBad(TreeNode node)
{
    if (node == null) return true;
    if (node.Left  != null && node.Left.Val  >= node.Val) return false;
    if (node.Right != null && node.Right.Val <= node.Val) return false;
    return IsValidBSTBad(node.Left) && IsValidBSTBad(node.Right);
}

// GOOD: thread min/max bounds through the entire recursion (see IsValidBST above)
// Every node must satisfy the bounds of ALL its ancestors, not just its parent.
```

---

## Real World Example

A permissions system for a content management platform stores resource hierarchies (Workspace → Project → Folder → Document). Checking whether a user has access to a given resource requires walking the tree upward to find the nearest permission override — a path-from-node-to-root traversal. Rendering the full permission tree for a UI requires a preorder DFS so parents always appear before children in the output.

```csharp
public class PermissionNode
{
    public string ResourceId  { get; init; }
    public string? Permission { get; init; }   // null = inherit from parent
    public List<PermissionNode> Children { get; init; } = new();
}

public class PermissionTree
{
    private readonly PermissionNode _root;
    // Index for O(1) node lookup by resourceId
    private readonly Dictionary<string, PermissionNode> _index = new();

    public PermissionTree(PermissionNode root)
    {
        _root = root;
        IndexAll(root);
    }

    private void IndexAll(PermissionNode node)
    {
        _index[node.ResourceId] = node;
        foreach (var child in node.Children)
            IndexAll(child);
    }

    // Preorder: yields parent before its children — safe for UI rendering
    public IEnumerable<PermissionNode> Preorder(PermissionNode? node = null)
    {
        node ??= _root;
        yield return node;
        foreach (var child in node.Children)
            foreach (var descendant in Preorder(child))
                yield return descendant;
    }

    // Resolve effective permission by walking toward the root
    public string? ResolvePermission(string resourceId)
    {
        if (!_index.TryGetValue(resourceId, out var node))
            return null;

        // Walk up until we find an explicit permission
        // (In a real system, parent references would be stored on each node)
        return FindEffectivePermission(_root, resourceId);
    }

    private string? FindEffectivePermission(PermissionNode current, string targetId)
    {
        if (current.ResourceId == targetId)
            return current.Permission;   // found target — use its own permission (may be null)

        foreach (var child in current.Children)
        {
            string? result = FindEffectivePermission(child, targetId);
            if (result != null) return result;
            // If child is an ancestor of target, return its permission as fallback
            if (IsAncestorOf(child, targetId))
                return child.Permission ?? FindEffectivePermission(child, targetId);
        }
        return current.Permission;       // propagate parent's permission upward
    }

    private bool IsAncestorOf(PermissionNode node, string targetId)
        => node.ResourceId == targetId
        || node.Children.Any(c => IsAncestorOf(c, targetId));
}
```

*The key insight is that tree traversal naturally maps to hierarchical permission inheritance — preorder DFS gives parent-before-child ordering for rendering, and the index dictionary makes individual node lookup O(1) without sacrificing the tree structure needed for permission propagation.*

---

## Common Misconceptions

**"Inorder traversal always gives sorted output"**
Only for a valid **binary search tree**. Inorder traversal of an arbitrary binary tree gives elements in left-subtree-first order, which has no guaranteed sort relationship unless the BST property holds. Always check whether the tree is a BST before assuming inorder output is sorted.

**"The height of a tree with n nodes is always O(log n)"**
Only for balanced trees. A completely skewed tree (every node has only a right child — effectively a linked list) has height O(n). This distinction matters for understanding why BST operations degrade to O(n) without balancing, and why recursive algorithms on unbalanced trees can stack overflow.

**"You always need recursion for tree problems"**
Recursion is the natural fit, but every recursive tree algorithm has an equivalent iterative form using an explicit stack. For BFS you use a queue explicitly anyway. Converting DFS to iterative is a common follow-up question and a signal of production awareness — deep unbalanced trees can overflow the call stack in recursive form.

```csharp
// Iterative inorder — equivalent to recursive, no call stack risk
public static List<int> InorderIterative(TreeNode root)
{
    var result = new List<int>();
    var stack  = new Stack<TreeNode>();
    TreeNode curr = root;

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

---

## Gotchas

- **Always handle the null base case as the first line.** Every recursive tree function needs `if (node == null) return ...` before any other logic. Missing it causes `NullReferenceException` on leaf children.

- **Depth and height are commonly confused.** Depth = distance from root to a node (root has depth 0). Height = distance from a node to its deepest leaf. The root's height equals the tree's height.

- **Level-order: snapshot `queue.Count` before the inner loop.** If you don't capture the level size before adding children, you'll process children in the same iteration as their parents — mixing levels and producing wrong output.

- **BST validation requires passing bounds, not just comparing with the immediate parent.** A node's value must satisfy the constraints of *all* its ancestors, not just its direct parent. The classic mistake is checking only `left.Val < node.Val` without verifying that the left subtree's maximum is below the current node's range.

- **Serialisation uniqueness requires two traversal types.** Inorder traversal alone cannot uniquely reconstruct a binary tree — multiple different trees can produce the same inorder sequence. You need preorder + inorder, or preorder with null markers, to uniquely reconstruct.

---

## Interview Angle

**What they're really testing:** Recursive thinking — can you trust the recursive call and focus only on what the current node must do? And can you formulate the return value correctly before writing a single line?

**Common question forms:**
- "Maximum depth / minimum depth of a binary tree"
- "Validate a BST"
- "Lowest Common Ancestor"
- "Path sum — does a root-to-leaf path sum to target?"
- "Serialize and deserialize a binary tree"
- "Diameter of a binary tree"

**The depth signal:** A junior writes recursion but can't cleanly separate what happens at the node from what's returned from children. A senior frames the problem as: "what does this function return, and what do I do with the left/right results?" — the return-value pattern. They can also switch fluidly between recursive and iterative implementations, know that BFS (queue) gives level-order while DFS (stack/recursion) gives the three traversal orders, and can explain that serialisation needs preorder with null markers to be unambiguous.

**Follow-up questions to expect:**
- "Can you do this iteratively?" (Explicit stack for DFS; always yes)
- "What's the space complexity?" (O(h) for recursive DFS — O(log n) balanced, O(n) skewed)
- "How would you handle a very deep tree in production?" (Iterative to avoid stack overflow; tail-call elimination isn't guaranteed in C#)

---

## Related Topics

- [[algorithms/datastructures/balanced-bst.md]] — A self-balancing BST that maintains O(log n) height automatically.
- [[algorithms/datastructures/heap.md]] — A complete binary tree with an ordering constraint — a specialised tree.
- [[algorithms/datastructures/trie.md]] — A tree where each edge represents a character — built for prefix search.
- [[algorithms/datastructures/graph.md]] — A tree is a special case: connected, acyclic, one path between any two nodes.
- [[algorithms/searching/depth-first-search.md]] — DFS on a graph generalises tree DFS to cycles and multiple components.

---

## Source

https://en.wikipedia.org/wiki/Binary_tree

---

*Last updated: 2026-04-12*