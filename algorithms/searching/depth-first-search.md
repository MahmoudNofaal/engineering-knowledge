# Depth-First Search
> A graph and tree traversal that explores as far as possible along each branch before backtracking.

---

## When To Use It
Use DFS when you need to explore all paths, detect cycles, find connected components, perform topological sort, or solve constraint problems (backtracking). It's the right traversal when you care about the existence of a path or the structure of the entire graph — not the shortest path. For shortest path on unweighted graphs, use BFS instead.

---

## Core Concept
DFS commits fully to one direction before trying another. From a starting node, go to the first unvisited neighbor, then that node's first unvisited neighbor, and so on until you hit a dead end — then backtrack and try the next option. The call stack (or an explicit stack) tracks where you are. Each node is visited exactly once. Time complexity is O(V + E): every vertex is entered once, and every edge is examined once.

The recursive form is natural because the call stack handles backtracking automatically. The iterative form uses an explicit stack and is necessary when recursion depth could hit Python's limit (~1000 by default).

---

## The Code

**DFS on a graph — recursive**
```python
def dfs_recursive(graph: dict, node: int, visited: set) -> None:
    visited.add(node)
    print(node)
    for neighbor in graph[node]:
        if neighbor not in visited:
            dfs_recursive(graph, neighbor, visited)

graph = {0: [1, 2], 1: [0, 3], 2: [0], 3: [1]}
visited = set()
dfs_recursive(graph, 0, visited)
```

**DFS on a graph — iterative**
```python
def dfs_iterative(graph: dict, start: int) -> list:
    visited, stack, order = set(), [start], []
    while stack:
        node = stack.pop()
        if node not in visited:
            visited.add(node)
            order.append(node)
            stack.extend(graph[node])   # neighbors pushed; last is explored first
    return order
```

**DFS on a binary tree — all three orders**
```python
class TreeNode:
    def __init__(self, val, left=None, right=None):
        self.val = val; self.left = left; self.right = right

def inorder(node: TreeNode) -> list:    # left → node → right
    return inorder(node.left) + [node.val] + inorder(node.right) if node else []

def preorder(node: TreeNode) -> list:   # node → left → right
    return [node.val] + preorder(node.left) + preorder(node.right) if node else []

def postorder(node: TreeNode) -> list:  # left → right → node
    return postorder(node.left) + postorder(node.right) + [node.val] if node else []
```

**Cycle detection in a directed graph — three-color DFS**
```python
def has_cycle(graph: dict) -> bool:
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {node: WHITE for node in graph}

    def dfs(node: int) -> bool:
        color[node] = GRAY                    # currently being explored
        for neighbor in graph[node]:
            if color[neighbor] == GRAY:
                return True                   # back edge = cycle
            if color[neighbor] == WHITE and dfs(neighbor):
                return True
        color[node] = BLACK                   # fully explored
        return False

    return any(dfs(n) for n in graph if color[n] == WHITE)
```

**Backtracking DFS — all subsets**
```python
def subsets(nums: list) -> list:
    result, path = [], []

    def dfs(start: int) -> None:
        result.append(path[:])               # snapshot current path
        for i in range(start, len(nums)):
            path.append(nums[i])
            dfs(i + 1)                       # explore with nums[i] included
            path.pop()                       # backtrack — undo the choice

    dfs(0)
    return result
```

**DFS on a 2D grid — number of islands**
```python
def num_islands(grid: list) -> int:
    rows, cols = len(grid), len(grid[0])
    count = 0

    def dfs(r: int, c: int) -> None:
        if r < 0 or r >= rows or c < 0 or c >= cols or grid[r][c] != '1':
            return
        grid[r][c] = '0'                     # mark visited by mutating grid
        for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
            dfs(r + dr, c + dc)

    for r in range(rows):
        for c in range(cols):
            if grid[r][c] == '1':
                dfs(r, c)
                count += 1
    return count
```

---

## Gotchas

- **Recursive DFS hits Python's recursion limit at ~1000 depth.** A grid of 1000×1000 can trigger this. Either increase the limit with `sys.setrecursionlimit()` or convert to iterative with an explicit stack.
- **Iterative DFS does not always produce the same order as recursive DFS.** Recursive DFS processes the first neighbor immediately. Iterative DFS pushes all neighbors and pops the last one first (LIFO), so the traversal order differs unless you reverse the neighbor list before pushing.
- **In backtracking, always undo the choice after the recursive call.** Forgetting `path.pop()` after `dfs(...)` means the path accumulates stale entries across branches and all results are wrong.
- **Three-color DFS is required for cycle detection in directed graphs.** Two-color (visited/unvisited) incorrectly flags cross-edges as cycles. A back edge (gray → gray) is a cycle; a cross-edge (gray → black) is not.
- **Marking visited on entry vs on discovery matters in some problems.** For simple traversal it doesn't matter. For problems where you need to track the path (cycle detection, backtracking), you need to mark and unmark around the recursive call — not permanently on entry.

---

## Interview Angle

**What they're really testing:** Whether you can apply DFS to tree, graph, and grid problems — and whether you understand backtracking as DFS with undo.

**Common question form:** Number of islands, path sum, word search, course schedule (cycle detection), generate permutations/subsets, clone a graph.

**The depth signal:** A junior writes DFS for a tree. A senior applies it to grids as implicit graphs, uses three-color cycle detection for directed graphs, and recognizes backtracking as DFS with state mutation and undo — not a separate algorithm. They also know when to switch to iterative DFS to avoid stack overflow and why iterative traversal order differs from recursive.

---

## Related Topics

- [[algorithms/breadth-first-search.md]] — The alternative traversal; use BFS for shortest path, DFS for full exploration.
- [[algorithms/graph.md]] — Graph representations and when DFS applies to topological sort.
- [[algorithms/stack.md]] — The data structure underlying iterative DFS.
- [[algorithms/tree.md]] — Tree traversals are specializations of DFS with no visited set needed.

---

## Source

https://en.wikipedia.org/wiki/Depth-first_search

---

*Last updated: 2026-03-24*