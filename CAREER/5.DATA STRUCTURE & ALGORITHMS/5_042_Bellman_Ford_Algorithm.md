---
id: "5.042"
studied_well: false
title: "Bellman-Ford Algorithm"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Graphs"
tags: [dsa, algorithms, graphs, shortest-path, bellman-ford, negative-weights, csharp, interviews]
priority: 3
prerequisites:
  - "[[5.041 — Dijkstra's Algorithm]]"
related:
  - "[[5.043 — Floyd-Warshall — All-Pairs Shortest Path]]"
  - "[[5.046 — Binary Search — Classic Implementation and Off-by-One Discipline]]"
  - "[[5.037 — BFS — Shortest Path, Level-Order, Multi-Source]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Graphs
**Previous:** [[5.041 — Dijkstra's Algorithm]] | **Next:** [[5.046 — Binary Search — Classic Implementation and Off-by-One Discipline]]

### Prerequisites
- [[5.041 — Dijkstra's Algorithm]] — Bellman-Ford solves the same single-source shortest path problem but handles negative edges; understanding Dijkstra's limitation is the motivation.

### Where This Fits
Bellman-Ford finds the shortest paths from a single source to all vertices in a weighted graph, handling negative edge weights (unlike Dijkstra). It also detects negative-weight cycles reachable from the source. Its O(V·E) time is slower than Dijkstra's O((V+E) log V), but its ability to handle negative edges and detect cycles makes it essential for currency arbitrage (detect negative cycles in currency exchange graphs), constraint satisfaction (difference constraints reduced to shortest paths), and network routing protocols (RIP — Routing Information Protocol uses Bellman-Ford). In interviews, Bellman-Ford appears in ~3% of hard graph problems — typically involving negative weights or cycle detection.

### Core Mental Model

Bellman-Ford relaxes every edge V-1 times. After k iterations, the algorithm has found the shortest path using at most k edges. Since the shortest path in a graph with V vertices has at most V-1 edges (no cycles in a shortest path), V-1 iterations guarantee correctness. A V-th iteration that still improves any distance reveals a negative-weight cycle.

### Properties

|Property|Value|
|---|---|
|Time|O(V·E)|
|Space|O(V) for distances|
|Negative edges|Yes|
|Negative cycle detection|Yes — V-th iteration detects|
|Works on directed graphs|Yes|

### Implementation

```csharp
public (int[] dist, bool hasNegativeCycle) BellmanFord(
    int n, List<(int to, int weight)>[] graph, int source)
{
    int[] dist = new int[n];
    Array.Fill(dist, int.MaxValue);
    dist[source] = 0;

    // Relax all edges V-1 times
    for (int i = 0; i < n - 1; i++)
    {
        bool relaxed = false;
        for (int u = 0; u < n; u++)
        {
            if (dist[u] == int.MaxValue) continue;
            foreach (var (v, w) in graph[u])
            {
                if (dist[u] + w < dist[v])
                {
                    dist[v] = dist[u] + w;
                    relaxed = true;
                }
            }
        }
        if (!relaxed) break;  // Early exit — no more improvements
    }

    // V-th iteration — check for negative cycles
    for (int u = 0; u < n; u++)
    {
        if (dist[u] == int.MaxValue) continue;
        foreach (var (v, w) in graph[u])
        {
            if (dist[u] + w < dist[v])
                return (dist, true);  // Negative cycle detected
        }
    }

    return (dist, false);
}
```

### Gotchas

- **Early exit optimization** — If no edge relaxes in an iteration, the algorithm terminates early (all shortest paths found). Maintains correctness.
- **No negative cycles** — If the graph has no negative cycles, the V-1 guarantee holds. If it does, detect via V-th iteration.
- **Overflow** — Use `int.MaxValue` as infinity. Adding a negative weight to `int.MaxValue` overflows. Guard with `if (dist[u] == int.MaxValue) continue`.
- **Undirected graphs** — An undirected negative edge is a negative cycle of length 2. Bellman-Ford detects this: it can alternate across the edge indefinitely.
- **Difference constraints** — System of constraints xⱼ - xᵢ ≤ w. Create edge i→j with weight w. Add a super-source connected to all vertices with weight 0. Run Bellman-Ford. If no negative cycle, the shortest path distances give a feasible assignment.

