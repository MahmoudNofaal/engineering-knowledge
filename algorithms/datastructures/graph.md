# Graph

> A set of nodes (vertices) connected by edges — the general structure that models networks, dependencies, maps, and social connections.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Vertices + edges; directed or undirected; weighted or unweighted |
| **Use when** | Networks, dependencies, shortest paths, cycles, connected components |
| **Avoid when** | Data is strictly hierarchical with no cycles (use Tree) |
| **C# version** | No built-in; represented as `Dictionary<int, List<int>>` or adjacency matrix |
| **Namespace** | `System.Collections.Generic` for representation |
| **Key types** | `Dictionary<int, List<int>>`, `Dictionary<int, List<(int w, int v)>>`, `int[,]` |

---

## When To Use It

Use a graph when the problem involves arbitrary connections between entities — social networks, road maps, dependency graphs, web crawling, circuit design. When edges are directional (A→B doesn't imply B→A), it's a **directed graph** (digraph). When edges have costs, it's **weighted**. Graphs subsume trees — a tree is a connected acyclic undirected graph.

The representation choice matters: **adjacency list** for sparse graphs (most real-world graphs), **adjacency matrix** for dense graphs or when O(1) edge existence checks are required.

---

## Core Concept

**Adjacency list:** `Dictionary<int, List<int>>` maps each vertex to its neighbours. Space: O(V + E). Edge check: O(degree). Iteration over neighbours: O(degree). Best for sparse graphs (E << V²).

**Adjacency matrix:** `bool[V, V]` or `int[V, V]`. Space: O(V²). Edge check: O(1). Iteration over all neighbours: O(V). Best for dense graphs (E ≈ V²) or when edge existence queries dominate.

Core algorithms by graph type:
- Unweighted shortest path → BFS
- Weighted non-negative shortest path → Dijkstra
- Negative weights → Bellman-Ford
- All-pairs shortest path → Floyd-Warshall
- Cycle detection (directed) → DFS three-colour
- Cycle detection (undirected) → Union-Find or DFS
- Topological sort → Kahn's BFS or DFS postorder
- Connected components → BFS/DFS or Union-Find
- Minimum spanning tree → Kruskal (Union-Find) or Prim (min-heap)

---

## Algorithm History

| Year | Development |
|---|---|
| 1736 | Euler solves the Königsberg bridge problem — first graph theory result |
| 1959 | Dijkstra's shortest path algorithm |
| 1965 | Floyd-Warshall all-pairs shortest path |
| 1972 | Tarjan's strongly connected components algorithm |
| 1983 | Union-Find with path compression and union by rank (near-O(1) per operation) |

---

## Performance

| Representation | Space | Edge exists? | Neighbours | Add vertex | Add edge |
|---|---|---|---|---|---|
| Adjacency list | O(V + E) | O(degree) | O(degree) | O(1) | O(1) |
| Adjacency matrix | O(V²) | O(1) | O(V) | O(V²) | O(1) |

| Algorithm | Time | Space | Use case |
|---|---|---|---|
| BFS | O(V + E) | O(V) | Unweighted shortest path |
| DFS | O(V + E) | O(V) | Cycle detection, topological sort |
| Dijkstra | O((V+E) log V) | O(V) | Weighted, non-negative |
| Bellman-Ford | O(VE) | O(V) | Negative weights |
| Floyd-Warshall | O(V³) | O(V²) | All-pairs |
| Union-Find | O(E × α(V)) | O(V) | Connected components, MST |

**Allocation behaviour:** Adjacency list allocates O(V + E) total across V lists. Adjacency matrix allocates one O(V²) array.

---

## The Code

**Scenario 1 — graph representations**
```csharp
// Undirected unweighted adjacency list
var graph = new Dictionary<int, List<int>>
{
    [0] = new() { 1, 2 },
    [1] = new() { 0, 3 },
    [2] = new() { 0 },
    [3] = new() { 1 }
};

// Directed weighted adjacency list
var weighted = new Dictionary<int, List<(int Weight, int Dest)>>
{
    [0] = new() { (4, 1), (2, 2) },
    [1] = new() { (3, 3) },
    [2] = new() { (1, 1), (5, 3) },
    [3] = new()
};

// Build from edge list
var edges = new[] { (0, 1), (0, 2), (1, 3) };
var fromEdges = new Dictionary<int, List<int>>();
foreach (var (u, v) in edges)
{
    if (!fromEdges.ContainsKey(u)) fromEdges[u] = new();
    if (!fromEdges.ContainsKey(v)) fromEdges[v] = new();
    fromEdges[u].Add(v);
    fromEdges[v].Add(u); // omit for directed graph
}
```

**Scenario 2 — cycle detection in directed graph (three-colour DFS)**
```csharp
public bool HasCycle(Dictionary<int, List<int>> graph)
{
    var state = new Dictionary<int, int>(); // 0=white, 1=gray, 2=black
    foreach (int node in graph.Keys) state[node] = 0;

    bool Dfs(int node)
    {
        state[node] = 1; // gray: currently being visited
        foreach (int neighbour in graph[node])
        {
            if (state[neighbour] == 1) return true;  // back edge = cycle
            if (state[neighbour] == 0 && Dfs(neighbour)) return true;
        }
        state[node] = 2; // black: fully explored
        return false;
    }

    return graph.Keys.Any(n => state[n] == 0 && Dfs(n));
}
```

**Scenario 3 — topological sort (Kahn's BFS)**
```csharp
public int[]? TopologicalSort(int n, int[][] edges)
{
    var adj     = new List<int>[n].Select(_ => new List<int>()).ToArray();
    var inDegree = new int[n];
    foreach (var e in edges) { adj[e[0]].Add(e[1]); inDegree[e[1]]++; }

    var queue = new Queue<int>();
    for (int i = 0; i < n; i++) if (inDegree[i] == 0) queue.Enqueue(i);

    var result = new List<int>();
    while (queue.Count > 0)
    {
        int node = queue.Dequeue();
        result.Add(node);
        foreach (int next in adj[node])
            if (--inDegree[next] == 0) queue.Enqueue(next);
    }
    return result.Count == n ? result.ToArray() : null; // null = cycle detected
}
```

**Scenario 4 — what NOT to do: adjacency matrix for sparse graphs**
```csharp
// BAD: O(V²) space for a social network with 1M users and 10M edges
// V = 1,000,000 → matrix = 10^12 booleans = 1 TB. Unusable.
bool[,] matrixBad = new bool[1_000_000, 1_000_000]; // OutOfMemoryException

// GOOD: adjacency list — O(V + E) = O(1M + 10M) = O(11M). Feasible.
var graphGood = new Dictionary<int, HashSet<int>>();
// HashSet<int> instead of List<int> for O(1) edge-existence checks
// Total space: ~11M entries
```

---

## Real World Example

The `DependencyResolver` in a CI/CD build system determines the order in which services must be built. Each service declares dependencies — if Service A depends on Service B, B must build first. This is a directed dependency graph; topological sort gives the build order. A cycle means a circular dependency — invalid, and the resolver must report it.

```csharp
public class DependencyResolver
{
    // Returns build order, or throws if circular dependency detected.
    public List<string> ResolveBuildOrder(Dictionary<string, List<string>> dependencies)
    {
        // Build adjacency list and in-degree map
        var allServices = dependencies.Keys
            .Concat(dependencies.Values.SelectMany(v => v))
            .Distinct().ToList();

        var inDegree = allServices.ToDictionary(s => s, _ => 0);
        foreach (var (service, deps) in dependencies)
            foreach (var dep in deps)
                inDegree[service]++; // service depends on dep → service's in-degree increases

        // Seeds: services with no dependencies
        var queue = new Queue<string>(allServices.Where(s => inDegree[s] == 0));
        var buildOrder = new List<string>();

        while (queue.Count > 0)
        {
            string service = queue.Dequeue();
            buildOrder.Add(service);

            // For all services that depend on this one, reduce their in-degree
            foreach (var (dependent, deps) in dependencies)
            {
                if (deps.Contains(service))
                {
                    inDegree[dependent]--;
                    if (inDegree[dependent] == 0) queue.Enqueue(dependent);
                }
            }
        }

        if (buildOrder.Count != allServices.Count)
            throw new InvalidOperationException(
                "Circular dependency detected — build order cannot be determined.");

        return buildOrder;
    }
}
```

*The key insight: topological sort on a directed dependency graph solves the build ordering problem. If Kahn's algorithm completes with fewer nodes than the total — a node never reached in-degree 0 — a cycle exists. The count check is the cycle detection.*

---

## Common Misconceptions

**"Graphs and trees are completely different structures"**
A tree is a connected acyclic undirected graph. All trees are graphs; not all graphs are trees. Most tree algorithms (DFS, BFS) apply directly to graphs with a visited set added to handle cycles.

**"Adjacency matrix is always faster because edge-check is O(1)"**
Only if you frequently check specific edges. For most graph algorithms (BFS, DFS, Dijkstra), you iterate over all neighbours of a node — O(V) for a matrix vs O(degree) for a list. For sparse graphs, the list is dramatically faster. Matrix wins only for dense graphs or dense edge-existence queries.

**"DFS always finds the shortest path"**
BFS finds shortest paths on unweighted graphs. DFS finds A path but not necessarily the shortest. This is one of the most common algorithm selection mistakes in interviews.

---

## Gotchas

- **Add all vertices to the adjacency list, even if they have no edges.** A vertex with no outgoing edges must still exist in the map (with an empty list) — otherwise `graph[node]` throws `KeyNotFoundException` during traversal.
- **Directed vs undirected: add edges in both directions for undirected.** Forgetting to add the reverse edge `v → u` when building from an undirected edge list produces a directed graph silently.
- **Mark visited on enqueue (BFS) / entry (DFS), not on exit.** For BFS, marking on dequeue allows the same node to be enqueued multiple times. For DFS cycle detection, the three-colour scheme is required — two-colour (visited/unvisited) incorrectly flags cross-edges as cycles in directed graphs.
- **`int[][]` edge list needs bidirectional addition for undirected graphs.** A common source of partial-graph bugs in interview code.

---

## Interview Angle

**What they're really testing:** Whether you can represent a graph correctly, choose the right algorithm (BFS vs DFS vs Dijkstra), and handle directed vs undirected, weighted vs unweighted.

**Common question forms:** Number of islands (implicit grid graph). Clone a graph. Course schedule (cycle detection / topological sort). Network delay time (Dijkstra). Number of connected components.

**The depth signal:** A junior does BFS/DFS correctly. A senior chooses the representation deliberately (list for sparse, matrix for dense), adds all vertices upfront, marks visited on enqueue for BFS, uses three-colour DFS for directed cycle detection, and reaches for Union-Find for undirected connected components.

**Follow-up questions to expect:**
- "When would you use an adjacency matrix?" → Dense graphs or when O(1) edge existence is critical.
- "How does topological sort detect cycles?" → If Kahn's BFS doesn't process all nodes (some never reach in-degree 0), a cycle exists.

---

## Related Topics

- [[algorithms/searching/breadth-first-search.md]] — BFS on graphs for unweighted shortest paths.
- [[algorithms/searching/depth-first-search.md]] — DFS for cycle detection, topological sort, connected components.
- [[algorithms/searching/dijkstra.md]] — Weighted graph shortest path.
- [[algorithms/patterns/topological-sort.md]] — Full treatment of Kahn's BFS and DFS postorder topological sort.

---

## Source

https://en.wikipedia.org/wiki/Graph_(abstract_data_type)

---

*Last updated: 2026-04-21*