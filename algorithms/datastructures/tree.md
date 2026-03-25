# Tree
> A hierarchical data structure of nodes where each node has a value and zero or more children, with no cycles.

---

## When To Use It
Use a tree when your data is naturally hierarchical — file systems, org charts, HTML DOM, decision trees, expression parsing. Binary trees specifically appear in BSTs (sorted lookup), heaps (priority), and tries (prefix search). Avoid trees when your data is flat or relational with cycles — that's a graph.

---

## Core Concept
A tree is a connected, acyclic graph with a designated root. Every non-root node has exactly one parent; a node with no children is a leaf. In a binary tree, each node has at most two children — left and right. The structure enables divide-and-conquer naturally: a problem on a tree usually decomposes into the same problem on left and right subtrees plus some work at the current node. That's recursion, and that's why tree problems almost always have elegant recursive solutions.

The three traversal orders are the foundation of everything else:
- **Inorder (left → node → right):** visits BST nodes in sorted order
- **Preorder (node → left → right):** serializes a tree, constructs copies
- **Postorder (left → right → node):** evaluates expressions, deletes trees

---

## The Code

**Node definition**
```csharp
public class TreeNode
{
    public int Val { get; set; }
    public TreeNode Left { get; set; }
    public TreeNode Right { get; set; }

    public TreeNode(int val)
    {
        Val = val;
        Left = null;
        Right = null;
    }
}
```

**Three traversals — recursive**
```csharp
public List<int> Inorder(TreeNode node)
{
    if (node == null)
        return new List<int>();
    var result = Inorder(node.Left);
    result.Add(node.Val);
    result.AddRange(Inorder(node.Right));
    return result;
}

public List<int> Preorder(TreeNode node)
{
    if (node == null)
        return new List<int>();
    var result = new List<int> { node.Val };
    result.AddRange(Preorder(node.Left));
    result.AddRange(Preorder(node.Right));
    return result;
}

public List<int> Postorder(TreeNode node)
{
    if (node == null)
        return new List<int>();
    var result = Postorder(node.Left);
    result.AddRange(Postorder(node.Right));
    result.Add(node.Val);
    return result;
}
```

**Height and depth**
```csharp
public int Height(TreeNode node)
{
    if (node == null)
        return 0;
    return 1 + Math.Max(Height(node.Left), Height(node.Right));
}
```

**Level-order traversal (BFS)**
```csharp
using System.Collections.Generic;

public List<List<int>> LevelOrder(TreeNode root)
{
    if (root == null)
        return new List<List<int>>();
    var result = new List<List<int>>();
    var queue = new Queue<TreeNode>();
    queue.Enqueue(root);
    while (queue.Count > 0)
    {
        var level = new List<int>();
        int levelSize = queue.Count;       // snapshot the current level size
        for (int i = 0; i < levelSize; i++)
        {
            var node = queue.Dequeue();
            level.Add(node.Val);
            if (node.Left != null) queue.Enqueue(node.Left);
            if (node.Right != null) queue.Enqueue(node.Right);
        }
        result.Add(level);
    }
    return result;
}
```

**Lowest Common Ancestor**
```csharp
public TreeNode LCA(TreeNode root, TreeNode p, TreeNode q)
{
    if (root == null || root == p || root == q)
        return root;
    var left = LCA(root.Left, p, q);
    var right = LCA(root.Right, p, q);
    if (left != null && right != null)
        return root;   // p and q are on opposite sides
    return left ?? right;
}
```

---

## Gotchas

- **Always handle the null/None base case first.** Every recursive tree function needs `if not node: return ...` as line one. Forgetting this causes NullPointerExceptions on leaf children.
- **Depth and height are easy to confuse.** Depth is distance from root to a node. Height is distance from a node to its deepest leaf. The root has depth 0 and height = tree height.
- **Level-order snapshot the queue size before iterating.** If you don't capture `len(queue)` at the start of each level, you'll mix nodes from different levels as you add children mid-loop.
- **Recursive tree solutions have O(n) space from the call stack.** For a balanced tree that's O(log n). For a skewed tree it's O(n). This matters for large inputs.
- **Serialization and deserialization are a common but underrated problem.** Preorder with null markers lets you reconstruct the exact tree. Inorder alone is insufficient — you need preorder or postorder to reconstruct uniquely.

---

## Interview Angle

**What they're really testing:** Recursive thinking — can you trust the recursive call and focus only on what the current node needs to do?

**Common question form:** Max depth, validate BST, path sum, lowest common ancestor, serialize/deserialize, symmetric tree.

**The depth signal:** A junior writes recursion but can't cleanly separate what happens at the node vs what's returned from children. A senior formulates the problem as "what does this function return, and what do I do with the left/right results?" — the return-value pattern. They can also switch between recursive and iterative implementations and know that BFS (queue) gives level order while DFS (stack/recursion) gives the three traversal orders.

---

## Related Topics

- [[algorithms/balanced-bst.md]] — A self-balancing binary search tree built on these same primitives.
- [[algorithms/heap.md]] — A complete binary tree with an ordering constraint — a specialized tree.
- [[algorithms/trie.md]] — A tree where each edge represents a character — built for prefix search.
- [[algorithms/graph.md]] — A tree is a special case of a graph: connected, acyclic, undirected.

---

## Source

https://en.wikipedia.org/wiki/Binary_tree

---

*Last updated: 2026-03-24*