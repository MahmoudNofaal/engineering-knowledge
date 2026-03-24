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
```python
# Recursive — O(n) stack depth
def factorial_rec(n: int) -> int:
    if n <= 1:
        return 1
    return n * factorial_rec(n - 1)

# Iterative — O(1) stack space
def factorial_iter(n: int) -> int:
    result = 1
    for i in range(2, n + 1):
        result *= i
    return result
```

**Binary tree inorder traversal**
```python
# Recursive
def inorder_rec(root) -> list:
    if not root:
        return []
    return inorder_rec(root.left) + [root.val] + inorder_rec(root.right)

# Iterative — explicit stack simulates the call stack
def inorder_iter(root) -> list:
    result, stack = [], []
    curr = root
    while curr or stack:
        while curr:
            stack.append(curr)     # push: go as far left as possible
            curr = curr.left
        curr = stack.pop()         # pop: process node
        result.append(curr.val)
        curr = curr.right          # then explore right subtree
    return result
```

**Binary tree preorder traversal**
```python
def preorder_iter(root) -> list:
    if not root:
        return []
    result, stack = [], [root]
    while stack:
        node = stack.pop()
        result.append(node.val)    # process before children
        if node.right:
            stack.append(node.right)   # push right first
        if node.left:
            stack.append(node.left)    # push left second (processed first)
    return result
```

**Binary tree postorder traversal — reverse of modified preorder**
```python
def postorder_iter(root) -> list:
    if not root:
        return []
    result, stack = [], [root]
    while stack:
        node = stack.pop()
        result.append(node.val)
        if node.left:
            stack.append(node.left)    # opposite push order from preorder
        if node.right:
            stack.append(node.right)
    return result[::-1]                # reverse gives left-right-node order
```

**DFS on a graph with explicit state**
```python
# Recursive DFS
def dfs_rec(graph, node, visited):
    visited.add(node)
    for neighbor in graph[node]:
        if neighbor not in visited:
            dfs_rec(graph, neighbor, visited)

# Iterative DFS — push (node, iterator) to resume mid-neighbor-list
def dfs_iter(graph, start):
    visited = set()
    stack = [start]
    while stack:
        node = stack.pop()
        if node in visited:
            continue
        visited.add(node)
        for neighbor in graph[node]:
            if neighbor not in visited:
                stack.append(neighbor)
```

**Backtracking — iterative using explicit state tuples**
```python
# Recursive subsets backtracking
def subsets_rec(nums):
    result, path = [], []
    def bt(start):
        result.append(path[:])
        for i in range(start, len(nums)):
            path.append(nums[i])
            bt(i + 1)
            path.pop()
    bt(0)
    return result

# Iterative — push (start_index, current_path) as explicit state
def subsets_iter(nums):
    result = []
    stack = [(0, [])]          # (next index to consider, current subset)
    while stack:
        start, path = stack.pop()
        result.append(path)
        for i in range(len(nums) - 1, start - 1, -1):   # reverse for correct order
            stack.append((i + 1, path + [nums[i]]))
    return result
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