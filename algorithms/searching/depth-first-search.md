# Depth-First Search

> A graph and tree traversal that explores as far as possible along each branch before backtracking — the foundation of cycle detection, topological sort, and backtracking.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Commit fully to one branch; backtrack when stuck |
| **Use when** | All paths, cycle detection, topological sort, connected components, backtracking |
| **Avoid when** | Shortest path on unweighted graphs (use BFS) |
| **C# version** | C# 1.0+ (recursive) or explicit `Stack<T>` for iterative |
| **Namespace** | `System.Collections.Generic` for `Stack<T>`, `HashSet<T>` |
| **Key types** | `HashSet<int>` visited, `Stack<int>` for iterative, `int[] color` for cycle detection |

---

## When To Use It

Use DFS when you need to explore all paths, detect cycles, perform topological sort, find connected components, or solve constraint problems (backtracking). It's the right traversal when you care about the full structure of the graph, not just the shortest path to a destination. For shortest path on unweighted graphs, use BFS instead.

---

## Core Concept

DFS commits fully to one direction before trying another. Start at a node, visit it, then recurse into each unvisited neighbour. When all neighbours are visited, backtrack. Each node is visited exactly once: O(V + E).

The recursive form uses the call stack implicitly. The iterative form uses an explicit `Stack<T>` — needed when recursion depth could overflow the call stack (trees with n=10,000+ nodes, large graphs).

For **cycle detection in directed graphs**, use three-colour DFS: white (unvisited), grey (currently in the call stack), black (fully explored). A back edge — grey to grey — indicates a cycle. Two-colour DFS (visited/unvisited) incorrectly flags cross-edges as cycles.

---

## Algorithm History

| Year | Development |
|---|---|
| 1879 | Trémaux's algorithm for maze solving — first DFS |
| 1970s | Formalized in algorithm textbooks (Tarjan, Hopcroft) |
| 1972 | Tarjan's SCC algorithm — DFS with a stack for strongly connected components |
| 1976 | Three-colour DFS for directed cycle detection formalized |

---

## Performance

| Operation | Time | Space | Notes |
|---|---|---|---|
| DFS traversal | O(V + E) | O(V) | Stack depth = O(V) worst case |
| Cycle detection (directed) | O(V + E) | O(V) | Three-colour array |
| Topological sort (DFS) | O(V + E) | O(V) | Reverse postorder |
| Connected components | O(V + E) | O(V) | One DFS per component |
| Tree traversal | O(n) | O(h) | h = height (O(log n) balanced, O(n) skewed) |

**Allocation behaviour:** Recursive DFS uses O(V) call stack frames (worst case: path graph). Iterative DFS uses O(V) explicit stack. Three-colour uses an O(V) integer array.

---

## The Code

**Scenario 1 — recursive DFS on a graph**
```csharp
public void Dfs(Dictionary<int, List<int>> graph, int node, HashSet<int> visited)
{
    visited.Add(node);
    Console.WriteLine(node);
    foreach (int neighbour in graph[node])
        if (!visited.Contains(neighbour))
            Dfs(graph, neighbour, visited);
}
```

**Scenario 2 — iterative DFS (explicit stack)**
```csharp
public List<int> DfsIterative(Dictionary<int, List<int>> graph, int start)
{
    var visited = new HashSet<int>();
    var stack   = new Stack<int>();
    var order   = new List<int>();
    stack.Push(start);

    while (stack.Count > 0)
    {
        int node = stack.Pop();
        if (!visited.Add(node)) continue;
        order.Add(node);
        // Push in reverse to match recursive DFS traversal order
        var neighbours = graph[node];
        for (int i = neighbours.Count - 1; i >= 0; i--)
            if (!visited.Contains(neighbours[i]))
                stack.Push(neighbours[i]);
    }
    return order;
}
```

**Scenario 3 — three-colour cycle detection (directed graph)**
```csharp
public bool HasCycleDirected(Dictionary<int, List<int>> graph)
{
    const int White = 0, Gray = 1, Black = 2;
    var color = graph.Keys.ToDictionary(k => k, _ => White);

    bool Dfs(int node)
    {
        color[node] = Gray; // entering: currently in call stack
        foreach (int nb in graph[node])
        {
            if (color[nb] == Gray)  return true;  // back edge = cycle
            if (color[nb] == White && Dfs(nb)) return true;
        }
        color[node] = Black; // leaving: fully explored
        return false;
    }

    return graph.Keys.Any(n => color[n] == White && Dfs(n));
}
```

**Scenario 4 — what NOT to do: two-colour cycle detection on directed graph**
```csharp
// BAD: two-colour DFS incorrectly flags CROSS-edges as cycles in directed graphs
// A cross-edge (from current DFS branch to a previously-BLACK node) is NOT a cycle.
// Two-colour can't distinguish a cross-edge from a back-edge.
public bool HasCycleBad(Dictionary<int, List<int>> graph)
{
    var visited = new HashSet<int>();
    bool Dfs(int node)
    {
        visited.Add(node);
        foreach (int nb in graph[node])
        {
            if (visited.Contains(nb)) return true; // BUG: cross-edge → false positive
            if (Dfs(nb)) return true;
        }
        return false;
    }
    return graph.Keys.Any(n => !visited.Contains(n) && Dfs(n));
}

// GOOD: three-colour — Gray means "in current path" (real cycle); Black means "done" (safe)
// See HasCycleDirected above.
// For UNDIRECTED graphs, two-colour is fine — cross-edges don't exist.
```

---

## Real World Example

The `ModuleDependencyChecker` in a build system uses DFS to detect circular dependencies across modules. It also produces a dependency load order (topological sort via reverse postorder DFS). Both operations are a single DFS pass.

```csharp
public class ModuleDependencyChecker
{
    private readonly Dictionary<string, List<string>> _deps; // module → its dependencies

    public ModuleDependencyChecker(Dictionary<string, List<string>> deps) => _deps = deps;

    // Returns load order (dependencies before dependents), or throws on circular dependency.
    public List<string> GetLoadOrder()
    {
        const int White = 0, Gray = 1, Black = 2;
        var color  = _deps.Keys.ToDictionary(k => k, _ => White);
        var result = new List<string>(); // filled in postorder = reverse dependency order

        void Dfs(string module)
        {
            color[module] = Gray;
            foreach (string dep in _deps.GetValueOrDefault(module, new()))
            {
                if (color.GetValueOrDefault(dep) == Gray)
                    throw new InvalidOperationException(
                        $"Circular dependency detected: {module} → {dep}");
                if (color.GetValueOrDefault(dep, White) == White)
                    Dfs(dep);
            }
            color[module] = Black;
            result.Add(module); // postorder: dependencies are added before dependents
        }

        foreach (string module in _deps.Keys)
            if (color[module] == White) Dfs(module);

        result.Reverse(); // reverse postorder = valid load order
        return result;
    }
}
```

*The key insight: DFS postorder naturally produces a reverse topological order — a module is added to the result only after all its dependencies are fully explored. Reversing this gives the correct load sequence.*

---

## Common Misconceptions

**"Iterative DFS produces the same traversal order as recursive DFS"**
Not unless you push neighbours in reverse order. Recursive DFS visits the first neighbour immediately. Iterative DFS pushes all neighbours and pops the last (LIFO) — visiting the last neighbour first unless you reverse the push order.

**"DFS can find shortest paths"**
DFS finds a path, not necessarily the shortest one. On an unweighted graph with multiple paths from A to B, DFS returns whichever it explores first — which may be the longest. Use BFS for shortest path.

**"Two-colour visited set is enough for cycle detection in all graphs"**
Only for undirected graphs. In directed graphs, a "visited" node might have been explored from a completely different path (cross-edge) — reaching it again is not a cycle. Three-colour (tracking "currently in call stack" as grey) is required for directed graphs.

---

## Gotchas

- **Iterative DFS traversal order may differ from recursive.** Push neighbours in reverse order to match. This matters for topological sort where consistent ordering is expected.
- **Three-colour DFS is required for directed cycle detection.** Two-colour produces false positives on cross-edges.
- **In backtracking DFS, undo state after the recursive call.** Missing the undo corrupts the shared state for sibling branches.
- **Recursive DFS can stack-overflow on large graphs.** Default .NET stack is ~1MB (~10,000–20,000 recursive calls). Convert to iterative for production traversals on large inputs.
- **Start DFS from every unvisited node** to handle disconnected graphs. A single DFS from one node only visits its connected component.

---

## Interview Angle

**What they're really testing:** Whether you apply DFS to tree, graph, and grid problems — and whether you understand backtracking as DFS with undo.

**Common question forms:** Number of islands. Path sum in tree. Clone a graph. Course schedule (cycle / topological). Generate all subsets/permutations (backtracking). Word search.

**The depth signal:** A junior does recursive DFS. A senior converts to iterative, uses three-colour for directed cycle detection, and recognises backtracking as DFS with state mutation and undo. The postorder-reversal trick for topological sort is the senior-level signal.

---

## Related Topics

- [[algorithms/searching/breadth-first-search.md]] — BFS for shortest path; DFS for full exploration.
- [[algorithms/patterns/backtracking.md]] — DFS with state mutation and undo.
- [[algorithms/datastructures/stack.md]] — Iterative DFS uses explicit Stack<T>.
- [[algorithms/datastructures/graph.md]] — Graph representations DFS operates on.

---

## Source

https://en.wikipedia.org/wiki/Depth-first_search

---

*Last updated: 2026-04-21*