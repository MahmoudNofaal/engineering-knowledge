# Recursion to Iteration
> The technique of converting a recursive algorithm into an iterative one using an explicit stack or loop — eliminating call-stack overhead and stack overflow risk.

---

## When To Use It
Convert recursion to iteration when: input size could exceed Python's recursion limit (~1000), stack overflow is a risk in production, or the interviewer asks for an iterative solution. Also use it when you need fine-grained control over traversal order that the call stack doesn't provide. Not every recursive algorithm needs to be converted — tail-recursive functions and small-depth recursion are fine as-is.

---

## Core Concept
Every recursive function implicitly uses the call stack. Each call pushes a frame containing the function arguments and local state. When the call returns, the frame is popped and execution continues from where it left off. Converting to iteration means making this stack management explicit: you push and pop your own stack instead of relying on the call stack.

The mechanical transformation: identify what state each recursive call needs (which is what the function parameters carry), push that state onto your explicit stack, and process it in a loop. The key insight is that the order you push neighbors onto the stack determines traversal order — and you have full control over that.

---

## The Code

**Factorial — tail recursion to loop**
```csharp
// Recursive — O(n) stack depth
public int FactorialRec(int n)
{
    if (n <= 1)
        return 1;
    return n * FactorialRec(n - 1);
}

// Iterative — O(1) stack space
public int FactorialIter(int n)
{
    int result = 1;
    for (int i = 2; i <= n; i++)
        result *= i;
    return result;
}
```

**Binary tree inorder traversal**
```csharp
// Recursive
public List<int> InorderRec(TreeNode root)
{
    var result = new List<int>();
    if (root == null)
        return result;
    result.AddRange(InorderRec(root.Left));
    result.Add(root.Val);
    result.AddRange(InorderRec(root.Right));
    return result;
}

// Iterative — explicit stack simulates the call stack
public List<int> InorderIter(TreeNode root)
{
    var result = new List<int>();
    var stack = new Stack<TreeNode>();
    TreeNode curr = root;
    
    while (curr != null || stack.Count > 0)
    {
        while (curr != null)
        {
            stack.Push(curr);  // Push: go as far left as possible
            curr = curr.Left;
        }
        curr = stack.Pop();    // Pop: process node
        result.Add(curr.Val);
        curr = curr.Right;     // Then explore right subtree
    }
    return result;
}
```

**Binary tree preorder traversal**
```csharp
public List<int> PreorderIter(TreeNode root)
{
    if (root == null)
        return new List<int>();
    
    var result = new List<int>();
    var stack = new Stack<TreeNode>();
    stack.Push(root);
    
    while (stack.Count > 0)
    {
        var node = stack.Pop();
        result.Add(node.Val);  // Process before children
        
        if (node.Right != null)
            stack.Push(node.Right);  // Push right first
        if (node.Left != null)
            stack.Push(node.Left);   // Push left second (processed first)
    }
    return result;
}
```

**Binary tree postorder traversal — reverse of modified preorder**
```csharp
public List<int> PostorderIter(TreeNode root)
{
    if (root == null)
        return new List<int>();
    
    var result = new List<int>();
    var stack = new Stack<TreeNode>();
    stack.Push(root);
    
    while (stack.Count > 0)
    {
        var node = stack.Pop();
        result.Add(node.Val);
        
        if (node.Left != null)
            stack.Push(node.Left);   // Opposite push order from preorder
        if (node.Right != null)
            stack.Push(node.Right);
    }
    
    result.Reverse();  // Reverse gives left-right-node order
    return result;
}
```

**DFS on a graph with explicit state**
```csharp
// Recursive DFS
public void DfsRec(Dictionary<int, List<int>> graph, int node, HashSet<int> visited)
{
    visited.Add(node);
    foreach (var neighbor in graph[node])
    {
        if (!visited.Contains(neighbor))
            DfsRec(graph, neighbor, visited);
    }
}

// Iterative DFS — push (node, iterator) to resume mid-neighbor-list
public void DfsIter(Dictionary<int, List<int>> graph, int start)
{
    var visited = new HashSet<int>();
    var stack = new Stack<int>();
    stack.Push(start);
    
    while (stack.Count > 0)
    {
        int node = stack.Pop();
        if (visited.Contains(node))
            continue;
        
        visited.Add(node);
        foreach (var neighbor in graph[node])
        {
            if (!visited.Contains(neighbor))
                stack.Push(neighbor);
        }
    }
}
```

**Backtracking — iterative using explicit state tuples**
```csharp
// Recursive subsets backtracking
public List<List<int>> SubsetsRec(int[] nums)
{
    var result = new List<List<int>>();
    var path = new List<int>();
    
    void Backtrack(int start)
    {
        result.Add(new List<int>(path));
        for (int i = start; i < nums.Length; i++)
        {
            path.Add(nums[i]);
            Backtrack(i + 1);
            path.RemoveAt(path.Count - 1);
        }
    }
    
    Backtrack(0);
    return result;
}

// Iterative — push (startIndex, currentPath) as explicit state
public List<List<int>> SubsetsIter(int[] nums)
{
    var result = new List<List<int>>();
    var stack = new Stack<(int, List<int>)>();  // (nextIndex, currentSubset)
    stack.Push((0, new List<int>()));
    
    while (stack.Count > 0)
    {
        var (start, path) = stack.Pop();
        result.Add(new List<int>(path));
        
        for (int i = nums.Length - 1; i >= start; i--)  // Reverse for correct order
        {
            var newPath = new List<int>(path) { nums[i] };
            stack.Push((i + 1, newPath));
        }
    }
    return result;
}
```

---

## Gotchas

- **Iterative DFS traversal order differs from recursive.** Recursive DFS explores the first neighbor immediately. Iterative DFS pushes all neighbors then pops the last (LIFO) — which is the last neighbor first. Reverse the neighbor list before pushing to match recursive order.
- **Postorder is the hardest traversal to convert.** A node must be processed after both subtrees. The trick: use a modified preorder (node, right, left) and reverse the result — it gives (left, right, node).
- **State must be fully captured in what you push.** If the recursive function has local variables that matter after the recursive call (like a loop index or partial result), they must go into the stack entry. Forgetting a piece of state produces wrong results that are hard to debug.
- **Iterative backtracking creates new path objects instead of mutating one.** The mutation-and-undo trick of recursive backtracking doesn't translate directly to iteration. You either push copies of the path (memory cost) or use index-based representations. Recursive backtracking is usually cleaner.
- **Increasing Python's recursion limit is a band-aid.** `sys.setrecursionlimit(10000)` helps for specific inputs but doesn't fix the root issue. For production code or large inputs, convert to iterative.

---

## Interview Angle

**What they're really testing:** Whether you understand that recursion is just implicit stack management — and whether you can make that explicit when required.

**Common question form:** "Can you do this iteratively?" asked after you write a recursive solution. Or: "Implement inorder traversal without recursion."

**The depth signal:** A junior converts factorial to a loop. A senior converts tree traversals correctly — especially inorder, which requires a curr pointer and a stack, not just pushing root. They know that postorder is the hardest and use the reverse-preorder trick. The highest signal: a senior explains *why* iterative DFS can have different traversal order than recursive DFS and how to fix it — because it demonstrates they understand the call stack as a data structure, not just a language feature.

---

## Related Topics

- [[algorithms/stack.md]] — The explicit stack used in iterative DFS and tree traversal.
- [[algorithms/depth-first-search.md]] — The primary algorithm converted from recursion to iteration here.
- [[algorithms/backtracking.md]] — Recursive backtracking and why converting it to iteration is non-trivial.
- [[algorithms/tree.md]] — Tree traversals are the canonical recursion-to-iteration exercise.

---

## Source

https://en.wikipedia.org/wiki/Recursion_(computer_science)#Conversion_to_iteration

---

*Last updated: 2026-03-24*