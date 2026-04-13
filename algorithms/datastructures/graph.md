# Graph

> A collection of nodes (vertices) connected by edges, used to model relationships, paths, and networks.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Vertices + edges — nodes with arbitrary relationships |
| **Use when** | Many-to-many relationships, paths, networks, dependencies |
| **Avoid when** | Data is strictly hierarchical (use tree) or flat (use array) |
| **C# version** | C# 2.0+ (custom adjacency list via `Dictionary<int, List<int>>`) |
| **Namespace** | Custom implementation — no BCL graph type |
| **Key types** | `Dictionary<int, List<int>>` (adjacency list), `int[,]` (matrix) |

---

## When To Use It

Use a graph when entities have relationships that aren't strictly hierarchical and can form cycles or have multiple connections between the same pair of nodes. Social networks, maps, dependency resolution, web crawling, circuit design — all graphs. If your data has cycles or many-to-many connections, it's a graph, not a tree.

Choose the representation based on density. An **adjacency list** (`Dictionary<int, List<int>>`) is standard for sparse graphs — O(V + E) space, efficient for iteration of neighbours. An **adjacency matrix** (`int[,]`) is better for dense graphs and when you need O(1) edge existence checks, but costs O(V²) space regardless of edge count.

Avoid graphs when the data is genuinely hierarchical (use a tree — it's cleaner and simpler). Don't reach for a graph just because you can model anything as one; the added complexity of cycle handling and visited sets is only worth it when cycles or multi-connectivity are actually present.

---

## Core Concept

A graph is defined by vertices V and edges E. Edges are **directed** (one-way, a digraph) or **undirected** (bidirectional). Edges can carry **weights** (distances, costs) or be unweighted.

The two fundamental traversals solve completely different problems and should be chosen deliberately:

**BFS (breadth-first search):** Uses a queue. Processes nodes in non-decreasing distance order from the start. Guarantees shortest path on unweighted graphs. Correct for: shortest path, minimum moves, level-by-level processing.

**DFS (depth-first search):** Uses a stack (or recursion). Explores as deep as possible before backtracking. Correct for: cycle detection, connected components, topological sort, path existence.

Choosing the wrong traversal gives a wrong algorithm, not just a slow one — BFS cannot detect cycles reliably without augmentation; DFS cannot guarantee shortest paths.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Custom graphs via `ArrayList` — non-generic, casting required |
| C# 2.0 | .NET 2.0 | `Dictionary<int, List<int>>` becomes idiomatic — generic, type-safe |
| C# 8.0 | .NET Core 3.0 | Nullable reference types improve node reference safety |
| C# 9.0 | .NET 5 | Record types simplify weighted edge definitions |
| C# 12.0 | .NET 8 | Primary constructors reduce edge/node class boilerplate |

*No version of .NET has shipped a general-purpose graph data structure. Graphs are always implemented using combinations of dictionaries, lists, and arrays.*

---

## Performance

| Operation | Adjacency List | Adjacency Matrix |
|---|---|---|
| Space | O(V + E) | O(V²) |
| Add vertex | O(1) | O(V²) — rebuild |
| Add edge | O(1) | O(1) |
| Check edge u→v | O(degree(u)) | O(1) |
| Iterate neighbours of u | O(degree(u)) | O(V) |
| BFS / DFS | O(V + E) | O(V²) |

**Allocation behaviour:** An adjacency list is a `Dictionary<int, List<int>>` — one dictionary entry per vertex, one list per vertex containing its neighbours. For sparse graphs (E ≪ V²) this is far more memory-efficient than a matrix. For dense graphs (E ≈ V²), a matrix has better cache locality for edge existence checks.

**Benchmark notes:** BFS and DFS on an adjacency list are O(V + E) — you visit each vertex once and scan each edge once. On a matrix, iterating neighbours of a node is O(V) even if it has one edge, making total BFS/DFS O(V²). For sparse graphs (most real-world graphs), use adjacency lists.

---

## The Code

**Graph representations**
```csharp
// Adjacency list — standard for sparse graphs
var graph = new Dictionary<int, List<int>>
{
    [0] = new List<int> { 1, 2 },
    [1] = new List<int> { 0, 3 },
    [2] = new List<int> { 0 },
    [3] = new List<int> { 1 }
};

// Weighted adjacency list
var weighted = new Dictionary<int, List<(int neighbour, int weight)>>
{
    [0] = new List<(int, int)> { (1, 4), (2, 1) },
    [1] = new List<(int, int)> { (3, 1) },
    [2] = new List<(int, int)> { (1, 2), (3, 5) }
};

// Adjacency matrix — O(V²) space, O(1) edge check
int n = 4;
int[,] matrix = new int[n, n];
matrix[0, 1] = 1;   // edge 0 → 1
matrix[1, 0] = 1;   // undirected: add both directions
```

**BFS — shortest path on unweighted graph**
```csharp
public static int ShortestPath(
    Dictionary<int, List<int>> graph, int start, int end)
{
    var visited = new HashSet<int> { start };
    var queue   = new Queue<(int node, int dist)>();
    queue.Enqueue((start, 0));

    while (queue.Count > 0)
    {
        var (node, dist) = queue.Dequeue();
        if (node == end) return dist;
        if (!graph.ContainsKey(node)) continue;
        foreach (int neighbour in graph[node])
        {
            if (!visited.Contains(neighbour))
            {
                visited.Add(neighbour);   // mark on enqueue
                queue.Enqueue((neighbour, dist + 1));
            }
        }
    }
    return -1;   // unreachable
}
```

**DFS — cycle detection in a directed graph (three-colour)**
```csharp
public static bool HasCycle(Dictionary<int, List<int>> graph)
{
    // 0 = unvisited, 1 = in current DFS path (gray), 2 = fully explored (black)
    var state = new Dictionary<int, int>();
    foreach (int v in graph.Keys) state[v] = 0;

    bool Dfs(int node)
    {
        state[node] = 1;   // entering — mark gray
        if (graph.TryGetValue(node, out var neighbours))
        {
            foreach (int nb in neighbours)
            {
                if (state.GetValueOrDefault(nb) == 1) return true;  // back edge = cycle
                if (state.GetValueOrDefault(nb) == 0 && Dfs(nb))   return true;
            }
        }
        state[node] = 2;   // done — mark black
        return false;
    }

    foreach (int v in graph.Keys)
        if (state[v] == 0 && Dfs(v))
            return true;
    return false;
}
```

**Topological sort — Kahn's BFS-based algorithm**
```csharp
// Returns topological order, or empty list if a cycle exists.
public static List<int> TopoSort(int numNodes, List<(int from, int to)> edges)
{
    var adj      = new Dictionary<int, List<int>>();
    var inDegree = new int[numNodes];

    for (int i = 0; i < numNodes; i++) adj[i] = new List<int>();
    foreach (var (from, to) in edges)
    {
        adj[from].Add(to);
        inDegree[to]++;
    }

    var queue = new Queue<int>();
    for (int i = 0; i < numNodes; i++)
        if (inDegree[i] == 0) queue.Enqueue(i);

    var order = new List<int>();
    while (queue.Count > 0)
    {
        int node = queue.Dequeue();
        order.Add(node);
        foreach (int nb in adj[node])
        {
            inDegree[nb]--;
            if (inDegree[nb] == 0) queue.Enqueue(nb);
        }
    }
    return order.Count == numNodes ? order : new List<int>();  // empty = cycle
}
```

**Dijkstra's shortest path — weighted graph**
```csharp
public static int[] Dijkstra(
    Dictionary<int, List<(int neighbour, int weight)>> graph, int start, int n)
{
    var dist = new int[n];
    Array.Fill(dist, int.MaxValue);
    dist[start] = 0;

    // Min-heap: (distance, node)
    var heap = new PriorityQueue<int, int>();
    heap.Enqueue(start, 0);

    while (heap.Count > 0)
    {
        int node = heap.Dequeue();
        if (!graph.ContainsKey(node)) continue;
        foreach (var (nb, w) in graph[node])
        {
            int newDist = dist[node] + w;
            if (newDist < dist[nb])
            {
                dist[nb] = newDist;
                heap.Enqueue(nb, newDist);   // lazy re-enqueue
            }
        }
    }
    return dist;
}
```

**What NOT to do — and the fix**
```csharp
// BAD: marking nodes visited on dequeue — allows duplicate enqueues
while (queue.Count > 0)
{
    int node = queue.Dequeue();
    if (visited.Contains(node)) continue;
    visited.Add(node);   // too late — node may already be in queue multiple times
    // ...
}

// GOOD: mark on enqueue — prevents duplicates entering the queue
queue.Enqueue(start);
visited.Add(start);
while (queue.Count > 0)
{
    int node = queue.Dequeue();
    foreach (int nb in graph[node])
    {
        if (!visited.Contains(nb))
        {
            visited.Add(nb);    // mark here, before enqueuing
            queue.Enqueue(nb);
        }
    }
}
```

---

## Real World Example

A CI/CD pipeline system models build steps as a directed acyclic graph (DAG). Each step has dependencies (edges pointing from prerequisite to dependent). Before running, the system must detect circular dependencies (a cycle = deadlock) and produce a valid execution order (topological sort). Steps with no unmet dependencies are dispatched to workers in parallel.

```csharp
public record BuildStep(string Name, List<string> DependsOn);

public class PipelinePlanner
{
    public static (bool hasCircle, List<string> order) Plan(List<BuildStep> steps)
    {
        var nameToIdx = steps.Select((s, i) => (s.Name, i))
                             .ToDictionary(x => x.Name, x => x.i);
        int n         = steps.Count;
        var adj       = new int[n][];
        var inDegree  = new int[n];

        for (int i = 0; i < n; i++)
        {
            var deps = steps[i].DependsOn
                .Where(nameToIdx.ContainsKey)
                .Select(dep => nameToIdx[dep])
                .ToArray();

            // Edge: dep → i (dep must run before i)
            foreach (int dep in deps) inDegree[i]++;
            // Build reverse: adj[dep] = steps that depend on dep
            adj[i] = Array.Empty<int>();
        }

        // Rebuild adjacency: for each step, list what it unlocks
        var graph = new Dictionary<int, List<int>>();
        for (int i = 0; i < n; i++) graph[i] = new List<int>();
        for (int i = 0; i < n; i++)
            foreach (string dep in steps[i].DependsOn)
                if (nameToIdx.TryGetValue(dep, out int depIdx))
                    graph[depIdx].Add(i);

        // Kahn's topological sort
        var queue = new Queue<int>();
        for (int i = 0; i < n; i++)
            if (inDegree[i] == 0) queue.Enqueue(i);

        var order = new List<string>();
        while (queue.Count > 0)
        {
            int node = queue.Dequeue();
            order.Add(steps[node].Name);
            foreach (int nb in graph[node])
            {
                inDegree[nb]--;
                if (inDegree[nb] == 0) queue.Enqueue(nb);
            }
        }

        bool hasCircle = order.Count != n;
        return (hasCircle, order);
    }
}

// Usage
var steps = new List<BuildStep>
{
    new("test",    new List<string> { "build" }),
    new("build",   new List<string> { "lint" }),
    new("lint",    new List<string>()),
    new("deploy",  new List<string> { "test", "build" })
};
var (cycle, runOrder) = PipelinePlanner.Plan(steps);
// runOrder: ["lint", "build", "test", "deploy"]
```

*The key insight is that Kahn's algorithm does two things simultaneously: it produces the execution order and detects cycles — if the output list is shorter than the number of nodes, a cycle exists and the pipeline is invalid.*

---

## Common Misconceptions

**"BFS finds the shortest path on any graph"**
BFS finds the shortest path only on **unweighted** graphs (or graphs where all edge weights are equal). With weights, use Dijkstra (positive weights) or Bellman-Ford (negative weights). BFS on a weighted graph gives the path with the fewest edges, not the path with the lowest total weight — these are often different.

**"Topological sort only applies to very specific problems"**
Topo sort applies to any problem involving dependency ordering — build systems, course prerequisites, spreadsheet formula evaluation, database migration ordering. Any time you have "A must happen before B," you have a DAG and topological sort applies.

**"For disconnected graphs, one BFS from one node is enough"**
It only visits the connected component containing the start node. For a disconnected graph, you need an outer loop over all vertices: `foreach (int v in graph.Keys) if (!visited.Contains(v)) BFS(v)`.

---

## Gotchas

- **Always track visited nodes — never skip this.** Without a visited set, DFS/BFS on a cyclic graph runs forever. Use a `HashSet<int>`, not a `List<int>` — membership check is O(1) vs O(n).

- **Mark visited on enqueue (BFS), not on dequeue.** Marking on dequeue allows the same node to be enqueued multiple times, causing exponential redundant work in dense graphs.

- **Topological sort is undefined for graphs with cycles.** Kahn's algorithm handles this gracefully — if the output list is shorter than V, a cycle exists. DFS-based topo sort needs explicit cycle detection alongside it.

- **Grid problems are implicit graphs.** A 2D grid where you move up/down/left/right is a graph where each cell is a vertex and edges connect adjacent non-blocked cells. You don't need to build an adjacency list — compute neighbours on the fly. This is the "number of islands," "shortest path in a maze," and "rotting oranges" pattern.

- **Dijkstra fails with negative edge weights.** If any edge weight is negative, use Bellman-Ford (O(VE)) or, for graphs with no negative cycles and you need all-pairs, Floyd-Warshall (O(V³)).

---

## Interview Angle

**What they're really testing:** Whether you can model an abstract problem as a graph and choose the right traversal — and whether you know the difference between BFS (shortest path, unweighted) and DFS (cycle detection, topo sort, components).

**Common question forms:**
- "Number of islands" (DFS/BFS on an implicit grid graph)
- "Course schedule" (cycle detection in a directed graph)
- "Word ladder" (BFS on an implicit character-transformation graph)
- "Clone a graph" (DFS with a copy-map for visited nodes)
- "Cheapest flights within k stops" (modified Dijkstra / BFS with state)

**The depth signal:** A junior applies BFS or DFS without knowing which or why. A senior chooses deliberately — BFS for shortest path, DFS for cycle/topo/components — and explains why. They also recognise grid problems as implicit graphs without needing an explicit adjacency list, know that Kahn's algorithm doubles as cycle detection, and understand Dijkstra's lazy-deletion workaround for when `PriorityQueue` lacks `DecreaseKey`.

**Follow-up questions to expect:**
- "What if the graph has negative edge weights?" (Bellman-Ford)
- "How would you detect if a graph is bipartite?" (BFS/DFS with two-colouring — a graph is bipartite iff it has no odd-length cycles)
- "What's the difference between a DAG and a general directed graph for topological sort?" (DAG is required — a cycle makes topo sort impossible)

---

## Related Topics

- [[algorithms/datastructures/queue.md]] — BFS is implemented with a queue; understanding circular buffers explains why queue dequeue is O(1).
- [[algorithms/datastructures/stack.md]] — DFS is naturally stack-based — recursive or iterative with an explicit stack.
- [[algorithms/datastructures/heap.md]] — Dijkstra replaces the BFS queue with a min-heap priority queue.
- [[algorithms/datastructures/union-find.md]] — Disjoint Set Union — an alternative to BFS/DFS for graph connectivity and cycle detection in undirected graphs.
- [[algorithms/datastructures/tree.md]] — A tree is a connected, acyclic, undirected graph — a special case of a graph.

---

## Source

https://en.wikipedia.org/wiki/Graph_(abstract_data_type)

---

*Last updated: 2026-04-12*