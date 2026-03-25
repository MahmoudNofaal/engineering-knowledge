# Dijkstra's Algorithm
> A shortest-path algorithm for weighted graphs with non-negative edge weights — O((V + E) log V) with a min-heap.

---

## When To Use It
Use Dijkstra when you need the shortest path in a weighted graph and all edge weights are non-negative. It's the standard solution for network routing, maps, and any problem asking for "minimum cost path." Don't use it with negative edge weights — it gives wrong answers. Use Bellman-Ford instead for negative weights, and BFS for unweighted graphs (same correctness, lower overhead).

---

## Core Concept
Dijkstra is BFS with a priority queue instead of a plain queue. The key insight: always process the unvisited node with the smallest known distance first. When you settle a node (pop it from the heap), its distance is final — no future path through an unvisited node can be shorter because all weights are non-negative. For each settled node, relax its edges: if going through this node gives a neighbor a shorter path, update the neighbor's distance and push it to the heap.

The "visited" check on pop is essential: because Python's `heapq` doesn't support efficient decrease-key, you push duplicate entries and skip stale ones when they surface.

---

## The Code

**Dijkstra — standard implementation with min-heap**
```csharp
using System;
using System.Collections.Generic;
using System.Linq;

public Dictionary<int, int> Dijkstra(Dictionary<int, List<(int, int)>> graph, int start)
{
    // graph[u] = [(weight, v), ...] — adjacency list with weights
    var dist = new Dictionary<int, int>();
    foreach (var node in graph.Keys)
        dist[node] = int.MaxValue;
    dist[start] = 0;

    var heap = new PriorityQueue<int, int>();
    heap.Enqueue(start, 0);  // (node, distance)

    while (heap.Count > 0)
    {
        int node = heap.Dequeue();
        int d = dist[node];

        if (graph.ContainsKey(node))
        {
            foreach (var (weight, neighbor) in graph[node])
            {
                int newDist = d + weight;
                if (newDist < dist[neighbor])
                {
                    dist[neighbor] = newDist;
                    heap.Enqueue(neighbor, newDist);
                }
            }
        }
    }
    return dist;
}
```

**Dijkstra with path reconstruction**
```csharp
using System;
using System.Collections.Generic;
using System.Linq;

public (int, List<int>) DijkstraPath(Dictionary<int, List<(int, int)>> graph, int start, int end)
{
    var dist = new Dictionary<int, int>();
    var prev = new Dictionary<int, int>();
    foreach (var node in graph.Keys)
        dist[node] = int.MaxValue;
    dist[start] = 0;

    var heap = new PriorityQueue<int, int>();
    heap.Enqueue(start, 0);

    while (heap.Count > 0)
    {
        int node = heap.Dequeue();
        int d = dist[node];
        if (node == end)
            break;  // early exit once destination settled

        if (graph.ContainsKey(node))
        {
            foreach (var (weight, neighbor) in graph[node])
            {
                int newDist = d + weight;
                if (newDist < dist[neighbor])
                {
                    dist[neighbor] = newDist;
                    prev[neighbor] = node;  // track predecessor
                    heap.Enqueue(neighbor, newDist);
                }
            }
        }
    }

    // Reconstruct path
    var path = new List<int>();
    int current = end;
    while (prev.ContainsKey(current))
    {
        path.Add(current);
        current = prev[current];
    }
    path.Add(start);
    path.Reverse();
    return (dist[end], path);
}
```

**Dijkstra on a weighted grid**
```csharp
using System;
using System.Collections.Generic;

public int DijkstraGrid(int[][] grid)
{
    int rows = grid.Length, cols = grid[0].Length;
    var dist = new Dictionary<(int, int), int>();
    for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++)
            dist[(r, c)] = int.MaxValue;
    dist[(0, 0)] = grid[0][0];

    var heap = new PriorityQueue<(int, int, int), int>();  // (cost, r, c), priority
    heap.Enqueue((grid[0][0], 0, 0), grid[0][0]);

    while (heap.Count > 0)
    {
        var (cost, r, c) = heap.Dequeue();
        if (cost > dist[(r, c)])
            continue;
        if (r == rows - 1 && c == cols - 1)
            return cost;

        int[][] directions = new int[][] { new int[] { -1, 0 }, new int[] { 1, 0 },
                                            new int[] { 0, -1 }, new int[] { 0, 1 } };
        foreach (var dir in directions)
        {
            int nr = r + dir[0], nc = c + dir[1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols)
            {
                int newCost = cost + grid[nr][nc];
                if (newCost < dist[(nr, nc)])
                {
                    dist[(nr, nc)] = newCost;
                    heap.Enqueue((newCost, nr, nc), newCost);
                }
            }
        }
    }
    return dist[(rows - 1, cols - 1)];
}
```

---

## Gotchas

- **Dijkstra fails with negative edge weights.** The settled-node-is-final guarantee breaks when a negative edge can later improve an already-settled node's distance. Use Bellman-Ford for negative weights (O(VE)) or Johnson's algorithm for all-pairs with negatives.
- **The `if d > dist[node]: continue` guard is mandatory.** Without it, you process stale heap entries with outdated distances, potentially relaxing edges incorrectly and wasting O(E) extra work per stale entry.
- **Python's `heapq` has no decrease-key operation.** The standard workaround is lazy deletion: push a new `(new_dist, node)` entry and skip the old one when it surfaces. This means the heap can hold O(E) entries instead of O(V), making space complexity O(E).
- **Edge cases on disconnected graphs.** Unreachable nodes keep `dist = inf`. Always check for `inf` before using a distance result. Dijkstra doesn't tell you a path is impossible — the distance simply stays infinite.
- **All edge weights must be non-negative — zero is fine.** Zero-weight edges are processed correctly. This comes up in problems where moving in one direction is free and another costs 1 (0-1 BFS is a deque-based alternative that's faster for binary weights).

---

## Interview Angle

**What they're really testing:** Whether you can adapt BFS to weighted graphs and implement relaxation correctly — and whether you know the algorithm's limitations.

**Common question form:** Network delay time, cheapest flights within k stops, path with minimum effort, minimum cost to reach destination.

**The depth signal:** A junior knows Dijkstra uses a heap and can code the basics. A senior explains *why* it's correct — the greedy invariant: settling nodes in distance order guarantees finality because no non-negative path can improve an already-minimal distance. They also know the negative-weight failure case, implement the stale-entry guard correctly, and can distinguish when to use Dijkstra vs BFS (unweighted) vs Bellman-Ford (negative weights) vs Floyd-Warshall (all-pairs).

---

## Related Topics

- [[algorithms/breadth-first-search.md]] — Dijkstra is BFS with a priority queue; understanding BFS first is essential.
- [[algorithms/heap.md]] — The min-heap is what makes Dijkstra O((V + E) log V) instead of O(V²).
- [[algorithms/graph.md]] — Graph representations and the broader shortest-path algorithm landscape.
- [[algorithms/a-star.md]] — Dijkstra extended with a heuristic to guide search toward the destination faster.

---

## Source

https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm

---

*Last updated: 2026-03-24*