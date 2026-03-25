# Graph
> A collection of nodes (vertices) connected by edges, used to model relationships, paths, and networks.

---

## When To Use It
Use a graph when entities have relationships that aren't strictly hierarchical. Social networks, maps, dependency resolution, web crawling, circuit design — all graphs. If your data has cycles or many-to-many connections, it's a graph, not a tree. Choose the representation (adjacency list vs matrix) based on whether the graph is sparse or dense.

---

## Core Concept
A graph is defined by vertices V and edges E. Edges are directed (one-way) or undirected (two-way), and weighted or unweighted. Most interview graphs are sparse — few edges relative to nodes — so the standard representation is an adjacency list: a dict mapping each node to its list of neighbors. An adjacency matrix uses O(V²) space and is only worth it for dense graphs or when you need O(1) edge existence checks.

The two fundamental traversals — BFS and DFS — solve completely different problems. BFS finds shortest paths on unweighted graphs. DFS detects cycles, finds connected components, and does topological sort. Know which one to reach for and why.

---

## The Code

**Graph representations**
```csharp
// Adjacency list — standard for sparse graphs
var graph = new Dictionary<int, List<int>>
{
    { 0, new List<int> { 1, 2 } },
    { 1, new List<int> { 0, 3 } },
    { 2, new List<int> { 0 } },
    { 3, new List<int> { 1 } }
};

// Adjacency matrix — O(V²) space, O(1) edge check
int n = 4;
int[][] matrix = new int[n][];
for (int i = 0; i < n; i++)
    matrix[i] = new int[n];
    
matrix[0][1] = 1;   // edge from 0 to 1
matrix[1][0] = 1;   // undirected
```

**DFS — recursive and iterative**
```csharp
public static void DfsRecursive(Dictionary<int, List<int>> graph, int node, HashSet<int> visited)
{
    visited.Add(node);
    if (graph.ContainsKey(node))
    {
        foreach (var neighbor in graph[node])
        {
            if (!visited.Contains(neighbor))
                DfsRecursive(graph, neighbor, visited);
        }
    }
}

public static List<int> DfsIterative(Dictionary<int, List<int>> graph, int start)
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
            if (graph.ContainsKey(node))
            {
                foreach (var neighbor in graph[node])
                    stack.Push(neighbor);
            }
        }
    }
    return order;
}
```

**BFS — shortest path on unweighted graph**
```csharp
public static int Bfs(Dictionary<int, List<int>> graph, int start, int end)
{
    var queue = new Queue<(int node, int dist)>();
    var visited = new HashSet<int> { start };
    queue.Enqueue((start, 0));
    
    while (queue.Count > 0)
    {
        var (node, dist) = queue.Dequeue();
        if (node == end)
            return dist;
        
        if (graph.ContainsKey(node))
        {
            foreach (var neighbor in graph[node])
            {
                if (!visited.Contains(neighbor))
                {
                    visited.Add(neighbor);
                    queue.Enqueue((neighbor, dist + 1));
                }
            }
        }
    }
    return -1;
}
```

**Cycle detection — directed graph**
```csharp
public static bool HasCycle(Dictionary<int, List<int>> graph)
{
    const int WHITE = 0, GRAY = 1, BLACK = 2;
    var color = new Dictionary<int, int>();
    foreach (var node in graph.Keys)
        color[node] = WHITE;

    bool Dfs(int node)
    {
        color[node] = GRAY;          // in current DFS path
        if (graph.ContainsKey(node))
        {
            foreach (var neighbor in graph[node])
            {
                if (color[neighbor] == GRAY)
                    return true;         // back edge = cycle
                if (color[neighbor] == WHITE && Dfs(neighbor))
                    return true;
            }
        }
        color[node] = BLACK;         // fully explored
        return false;
    }

    foreach (var node in graph.Keys)
        if (color[node] == WHITE && Dfs(node))
            return true;
    return false;
}
```

**Topological sort — Kahn's algorithm (BFS-based)**
```csharp
public static List<int> TopoSort(int n, List<(int u, int v)> edges)
{
    var graph = new Dictionary<int, List<int>>();
    var inDegree = new int[n];
    
    for (int i = 0; i < n; i++)
        graph[i] = new List<int>();
    
    foreach (var (u, v) in edges)
    {
        graph[u].Add(v);
        inDegree[v]++;
    }
    
    var queue = new Queue<int>();
    for (int i = 0; i < n; i++)
        if (inDegree[i] == 0)
            queue.Enqueue(i);
    
    var order = new List<int>();
    while (queue.Count > 0)
    {
        int node = queue.Dequeue();
        order.Add(node);
        foreach (var neighbor in graph[node])
        {
            inDegree[neighbor]--;
            if (inDegree[neighbor] == 0)
                queue.Enqueue(neighbor);
        }
    }
    return order.Count == n ? order : new List<int>();  // empty = cycle exists
}
```

---

## Gotchas

- **Always track visited nodes.** Without it, DFS/BFS on a cyclic graph runs forever. Use a set, not a list — membership check is O(1) vs O(n).
- **Mark visited on enqueue for BFS, not on dequeue.** Marking on dequeue lets the same node be enqueued multiple times, bloating the queue and causing duplicate processing.
- **Topological sort is only defined for DAGs.** If a cycle exists, Kahn's algorithm returns a partial order (fewer than n nodes). Check the length of the result to detect cycles.
- **Disconnected graphs need an outer loop.** A single DFS/BFS from one start node won't visit all components. Wrap in `for node in graph: if node not in visited: dfs(node)`.
- **Grid problems are implicit graphs.** A 2D grid is a graph where each cell is a node and neighbors are up/down/left/right. You don't need to build the adjacency list — just compute neighbors on the fly.

---

## Interview Angle

**What they're really testing:** Whether you can model an abstract problem as a graph and apply the right traversal.

**Common question form:** Number of islands, course schedule (cycle detection + topo sort), word ladder (BFS), clone a graph, shortest path in a grid.

**The depth signal:** A junior applies BFS or DFS correctly. A senior chooses *which* traversal based on the problem property — BFS for shortest path, DFS for cycle detection or topo sort — and explains why. They also know Dijkstra for weighted shortest paths, recognize grid problems as implicit graphs without needing an explicit adjacency list, and know that Kahn's algorithm doubles as cycle detection for directed graphs.

---

## Related Topics

- [[algorithms/queue.md]] — BFS is implemented with a queue; understanding deque is essential.
- [[algorithms/stack.md]] — DFS is naturally stack-based, either via recursion or an explicit stack.
- [[algorithms/heap.md]] — Dijkstra's algorithm replaces the BFS queue with a min-heap.
- [[algorithms/tree.md]] — A tree is a connected, acyclic, undirected graph — a special case.

---

## Source

https://en.wikipedia.org/wiki/Graph_(abstract_data_type)

---

*Last updated: 2026-03-24*