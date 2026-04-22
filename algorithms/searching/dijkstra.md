# Dijkstra's Algorithm

> A shortest-path algorithm for weighted graphs with non-negative edge weights — O((V + E) log V) with a min-heap.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Greedy BFS with a min-heap; settles nearest node each step |
| **Use when** | Weighted graph, all edge weights ≥ 0, single-source shortest path |
| **Avoid when** | Negative edge weights (use Bellman-Ford); unweighted (use BFS) |
| **C# version** | C# 1.0+ logic; `PriorityQueue<T,P>` since .NET 6 |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `PriorityQueue<int, int>`, `Dictionary<int, int>` for distances |

---

## When To Use It

Use Dijkstra when you need the shortest path in a weighted graph and all edge weights are non-negative. It's the standard solution for network routing, maps, and any problem asking for "minimum cost path." Don't use it with negative edge weights — it gives wrong answers silently. Use Bellman-Ford for negative weights, and plain BFS for unweighted graphs.

---

## Core Concept

Dijkstra is BFS with a priority queue instead of a plain queue. The key invariant: when a node is dequeued (settled), its distance is final. This holds because all weights are non-negative — no future edge can produce a shorter path to an already-settled node.

For each settled node, **relax** its edges: if the path through this node gives a neighbour a shorter distance, update the neighbour's distance and push it to the heap. Because C#'s `PriorityQueue` has no decrease-key operation, push duplicate `(node, newDist)` entries and skip stale ones when they surface with a `if (d > dist[node]) continue` guard.

---

## Algorithm History

| Year | Development |
|---|---|
| 1956 | Edsger Dijkstra develops the algorithm in ~20 minutes (published 1959) |
| 1984 | Fibonacci heap reduces Dijkstra to O(E + V log V) |
| 1990s | Becomes standard for road network routing |
| 2007 | Used in OpenStreetMap routing engines |
| 2021 | .NET 6 ships `PriorityQueue<T,P>` — clean Dijkstra implementation now possible in C# |

---

## Performance

| Heap type | Time | Space | Notes |
|---|---|---|---|
| Binary heap (PriorityQueue) | O((V + E) log V) | O(V + E) | Standard choice |
| Fibonacci heap | O(E + V log V) | O(V) | Better for dense graphs; complex to implement |
| No heap (array scan) | O(V²) | O(V) | Better when E ≈ V² (dense graph) |

**Allocation behaviour:** One `PriorityQueue` holding up to O(E) entries (lazy deletion, no decrease-key). One distance dictionary of O(V) entries.

---

## The Code

**Scenario 1 — standard Dijkstra**
```csharp
public Dictionary<int, int> Dijkstra(
    Dictionary<int, List<(int Weight, int Dest)>> graph, int start)
{
    var dist = graph.Keys.ToDictionary(k => k, _ => int.MaxValue);
    dist[start] = 0;
    var pq = new PriorityQueue<int, int>(); // (node, distance as priority)
    pq.Enqueue(start, 0);

    while (pq.Count > 0)
    {
        pq.TryDequeue(out int node, out int d);
        if (d > dist[node]) continue; // stale entry — skip

        foreach (var (weight, dest) in graph[node])
        {
            int newDist = d + weight;
            if (newDist < dist[dest])
            {
                dist[dest] = newDist;
                pq.Enqueue(dest, newDist); // push new entry; old entry becomes stale
            }
        }
    }
    return dist;
}
```

**Scenario 2 — with path reconstruction**
```csharp
public (int Dist, List<int> Path) DijkstraPath(
    Dictionary<int, List<(int Weight, int Dest)>> graph, int start, int end)
{
    var dist = graph.Keys.ToDictionary(k => k, _ => int.MaxValue);
    var prev = new Dictionary<int, int>();
    dist[start] = 0;
    var pq = new PriorityQueue<int, int>();
    pq.Enqueue(start, 0);

    while (pq.Count > 0)
    {
        pq.TryDequeue(out int node, out int d);
        if (node == end) break;
        if (d > dist[node]) continue;
        foreach (var (weight, dest) in graph[node])
        {
            int nd = d + weight;
            if (nd < dist[dest]) { dist[dest] = nd; prev[dest] = node; pq.Enqueue(dest, nd); }
        }
    }
    var path = new List<int>();
    for (int cur = end; prev.ContainsKey(cur); cur = prev[cur]) path.Add(cur);
    path.Add(start); path.Reverse();
    return (dist[end], path);
}
```

**Scenario 3 — Dijkstra on a weighted grid**
```csharp
public int DijkstraGrid(int[][] grid)
{
    int rows = grid.Length, cols = grid[0].Length;
    var dist = new int[rows, cols];
    for (int r = 0; r < rows; r++) for (int c = 0; c < cols; c++) dist[r, c] = int.MaxValue;
    dist[0, 0] = grid[0][0];
    var pq = new PriorityQueue<(int R, int C), int>();
    pq.Enqueue((0, 0), grid[0][0]);

    int[][] dirs = { new[]{-1,0}, new[]{1,0}, new[]{0,-1}, new[]{0,1} };
    while (pq.Count > 0)
    {
        pq.TryDequeue(out var pos, out int cost);
        if (cost > dist[pos.R, pos.C]) continue;
        if (pos.R == rows - 1 && pos.C == cols - 1) return cost;
        foreach (var d in dirs)
        {
            int nr = pos.R + d[0], nc = pos.C + d[1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols)
            {
                int nc2 = cost + grid[nr][nc];
                if (nc2 < dist[nr, nc]) { dist[nr, nc] = nc2; pq.Enqueue((nr, nc), nc2); }
            }
        }
    }
    return dist[rows - 1, cols - 1];
}
```

**Scenario 4 — what NOT to do: missing the stale-entry guard**
```csharp
// BAD: without the stale-entry guard, old entries re-process settled nodes
// causing incorrect relaxations and potential O(E × V) behaviour
public void DijkstraBad(Dictionary<int, List<(int, int)>> graph, int start)
{
    var dist = graph.Keys.ToDictionary(k => k, _ => int.MaxValue);
    dist[start] = 0;
    var pq = new PriorityQueue<int, int>();
    pq.Enqueue(start, 0);
    while (pq.Count > 0)
    {
        pq.TryDequeue(out int node, out int d);
        // MISSING: if (d > dist[node]) continue;
        foreach (var (w, dest) in graph[node])
        {
            int nd = d + w;
            if (nd < dist[dest]) { dist[dest] = nd; pq.Enqueue(dest, nd); }
        }
    }
}

// GOOD: always include the stale-entry guard
// if (d > dist[node]) continue; // skip outdated heap entries
```

---

## Real World Example

The `DeliveryRouteOptimiser` finds the minimum-cost route between a depot and delivery addresses across a road network. Roads have distances (weights). Dijkstra gives the shortest path from the depot to every address in one pass.

```csharp
public class DeliveryRouteOptimiser
{
    private readonly Dictionary<string, List<(int DistanceKm, string Destination)>> _roadNetwork;

    public DeliveryRouteOptimiser(
        Dictionary<string, List<(int, string)>> roadNetwork) => _roadNetwork = roadNetwork;

    public Dictionary<string, int> ShortestDistancesFrom(string depot)
    {
        var dist = _roadNetwork.Keys.ToDictionary(k => k, _ => int.MaxValue);
        dist[depot] = 0;
        var pq = new PriorityQueue<string, int>();
        pq.Enqueue(depot, 0);

        while (pq.Count > 0)
        {
            pq.TryDequeue(out string location, out int d);
            if (d > dist[location]) continue;

            foreach (var (km, dest) in _roadNetwork.GetValueOrDefault(location, new()))
            {
                int newDist = d + km;
                if (newDist < dist[dest])
                {
                    dist[dest] = newDist;
                    pq.Enqueue(dest, newDist);
                }
            }
        }
        return dist;
    }
}
```

*The key insight: Dijkstra computes shortest distances from the depot to ALL addresses in O((V+E) log V) — one run, not one run per address. If you need distances from every address to every other, run Dijkstra once per source (O(V × (V+E) log V)) or use Floyd-Warshall (O(V³)) for small V.*

---

## Common Misconceptions

**"Dijkstra works with negative edge weights"**
No. The settled-node-is-final invariant breaks: a future negative edge could reduce the distance to an already-settled node. Use Bellman-Ford for negative weights. With negative cycles, no shortest path is defined.

**"I need decrease-key for Dijkstra — PriorityQueue can't do it"**
Not required. Push a new `(node, newDist)` entry whenever you find a shorter path. When the old stale entry is eventually dequeued, the `if (d > dist[node]) continue` guard discards it. The heap contains O(E) entries in the worst case (one per relaxation) instead of O(V), but this is the standard trade-off and is perfectly efficient in practice.

**"Dijkstra is only for graphs — not grids"**
Grids are implicit graphs. Each cell is a vertex; adjacent cells are edges. Dijkstra runs on grids with weighted cells identically to how it runs on explicit graphs.

---

## Gotchas

- **Always include the stale-entry guard** `if (d > dist[node]) continue`. Without it, old entries re-process settled nodes causing wrong results and performance regression.
- **Dijkstra fails with negative weights — silently.** It won't throw; it just returns wrong distances. If input might have negative weights, detect them and fall back to Bellman-Ford.
- **Unreachable nodes keep `dist = int.MaxValue`.** Always check before using a distance result: `if (dist[node] == int.MaxValue) // unreachable`.
- **`int.MaxValue + weight` overflows silently.** Use `if (dist[node] == int.MaxValue) continue` before relaxing, or use a safe addition.

---

## Interview Angle

**What they're really testing:** Whether you can adapt BFS to weighted graphs and implement relaxation correctly — and whether you know the algorithm's limitations.

**Common question forms:** Network delay time. Cheapest flights within K stops. Path with minimum effort. Minimum cost to reach destination.

**The depth signal:** A junior knows Dijkstra uses a heap. A senior explains the greedy invariant (settling in distance order is final for non-negative weights), implements the stale-entry guard, and knows when to use Dijkstra vs BFS vs Bellman-Ford vs Floyd-Warshall.

---

## Related Topics

- [[algorithms/searching/breadth-first-search.md]] — Dijkstra is BFS with a priority queue.
- [[algorithms/searching/bellman-ford.md]] — The alternative for negative edge weights.
- [[algorithms/datastructures/heap.md]] — PriorityQueue makes Dijkstra O((V+E) log V).
- [[algorithms/datastructures/graph.md]] — Graph representations Dijkstra operates on.

---

## Source

https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm

---

*Last updated: 2026-04-21*