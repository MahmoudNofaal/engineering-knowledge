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
```csharp
public void DfsRecursive(Dictionary<int, List<int>> graph, int node, HashSet<int> visited)
{
    visited.Add(node);
    Console.WriteLine(node);
    foreach (int neighbor in graph[node])
    {
        if (!visited.Contains(neighbor))
            DfsRecursive(graph, neighbor, visited);
    }
}

var graph = new Dictionary<int, List<int>>
{
    {0, new List<int> {1, 2}},
    {1, new List<int> {0, 3}},
    {2, new List<int> {0}},
    {3, new List<int> {1}}
};
var visited = new HashSet<int>();
DfsRecursive(graph, 0, visited);
```

**DFS on a graph — iterative**
```csharp
public List<int> DfsIterative(Dictionary<int, List<int>> graph, int start)
{
    var visited = new HashSet<int>();
    var stack = new Stack<int>();
    var order = new List<int>();
    stack.Push(start);
    
    while (stack.Count > 0)
    {
        int node = stack.Pop();
        if (!visited.Contains(node))
        {
            visited.Add(node);
            order.Add(node);
            foreach (int neighbor in graph[node])
                stack.Push(neighbor);   // neighbors pushed; last is explored first
        }
    }
    return order;
}
```

**DFS on a binary tree — all three orders**
```csharp
public class TreeNode
{
    public int Val;
    public TreeNode Left, Right;
    public TreeNode(int val, TreeNode left = null, TreeNode right = null)
    {
        Val = val;
        Left = left;
        Right = right;
    }
}

public List<int> Inorder(TreeNode node)    // left → node → right
{
    var result = new List<int>();
    if (node != null)
    {
        result.AddRange(Inorder(node.Left));
        result.Add(node.Val);
        result.AddRange(Inorder(node.Right));
    }
    return result;
}

public List<int> Preorder(TreeNode node)   // node → left → right
{
    var result = new List<int>();
    if (node != null)
    {
        result.Add(node.Val);
        result.AddRange(Preorder(node.Left));
        result.AddRange(Preorder(node.Right));
    }
    return result;
}

public List<int> Postorder(TreeNode node)  // left → right → node
{
    var result = new List<int>();
    if (node != null)
    {
        result.AddRange(Postorder(node.Left));
        result.AddRange(Postorder(node.Right));
        result.Add(node.Val);
    }
    return result;
}
```

**Cycle detection in a directed graph — three-color DFS**
```csharp
const int WHITE = 0, GRAY = 1, BLACK = 2;

public bool HasCycle(Dictionary<int, List<int>> graph)
{
    var color = new Dictionary<int, int>();
    foreach (int node in graph.Keys)
        color[node] = WHITE;

    bool Dfs(int node)
    {
        color[node] = GRAY;                    // currently being explored
        foreach (int neighbor in graph[node])
        {
            if (color[neighbor] == GRAY)
                return true;                   // back edge = cycle
            if (color[neighbor] == WHITE && Dfs(neighbor))
                return true;
        }
        color[node] = BLACK;                   // fully explored
        return false;
    }

    foreach (int node in graph.Keys)
    {
        if (color[node] == WHITE && Dfs(node))
            return true;
    }
    return false;
}
```

**Backtracking DFS — all subsets**
```csharp
public List<List<int>> Subsets(int[] nums)
{
    var result = new List<List<int>>();
    var path = new List<int>();

    void Dfs(int start)
    {
        result.Add(new List<int>(path));     // snapshot current path
        for (int i = start; i < nums.Length; i++)
        {
            path.Add(nums[i]);
            Dfs(i + 1);                      // explore with nums[i] included
            path.RemoveAt(path.Count - 1);  // backtrack — undo the choice
        }
    }

    Dfs(0);
    return result;
}
```

**DFS on a 2D grid — number of islands**
```csharp
public int NumIslands(char[][] grid)
{
    int rows = grid.Length, cols = grid[0].Length;
    int count = 0;

    void Dfs(int r, int c)
    {
        if (r < 0 || r >= rows || c < 0 || c >= cols || grid[r][c] != '1')
            return;
        grid[r][c] = '0';                    // mark visited by mutating grid
        int[][] directions = new int[][] { new int[] {-1,0}, new int[] {1,0}, new int[] {0,-1}, new int[] {0,1} };
        foreach (int[] dir in directions)
            Dfs(r + dir[0], c + dir[1]);
    }

    for (int r = 0; r < rows; r++)
    {
        for (int c = 0; c < cols; c++)
        {
            if (grid[r][c] == '1')
            {
                Dfs(r, c);
                count++;
            }
        }
    }
    return count;
}
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