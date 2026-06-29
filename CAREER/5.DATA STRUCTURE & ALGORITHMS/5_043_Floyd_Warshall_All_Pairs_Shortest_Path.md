---
id: "5.043"
studied_well: false
title: "Floyd-Warshall — All-Pairs Shortest Path"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Graphs"
tags: [dsa, algorithms, graphs, shortest-path, floyd-warshall, all-pairs, dynamic-programming, csharp, interviews]
priority: 4
prerequisites:
  - "[[5.041 — Dijkstra's Algorithm]]"
  - "[[5.042 — Bellman-Ford Algorithm]]"
related:
  - "[[5.061 — 2D Dynamic Programming]]"
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
**Previous:** [[5.042 — Bellman-Ford Algorithm]] | **Next:** [[5.044 — Minimum Spanning Tree — Kruskal's and Prim's]]

### Prerequisites
- [[5.041 — Dijkstra's Algorithm]] — single-source shortest path; Floyd-Warshall solves the all-pairs version.
- [[5.042 — Bellman-Ford Algorithm]] — handles negative edges; Floyd-Warshall also handles negative edges but detects negative cycles differently.

### Where This Fits
Floyd-Warshall computes shortest paths between all pairs of vertices in O(V³) time using dynamic programming. It handles negative edges (but not negative cycles). It is simpler to implement than running Dijkstra V times (O(V·(V+E) log V) for sparse graphs) and works with dense graphs efficiently.

### Key Insight

DP[k][i][j] = shortest path from i to j using only vertices 0..k as intermediates. Optimized to 2D: dist[i][j] = min(dist[i][j], dist[i][k] + dist[k][j]).

### Implementation

```csharp
public int[,] FloydWarshall(int n, List<(int to, int weight)>[] graph)
{
    int[,] dist = new int[n, n];
    for (int i = 0; i < n; i++)
    {
        for (int j = 0; j < n; j++)
            dist[i, j] = i == j ? 0 : int.MaxValue / 2;

        foreach (var (to, w) in graph[i])
            dist[i, to] = w;
    }

    for (int k = 0; k < n; k++)
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                if (dist[i, k] + dist[k, j] < dist[i, j])
                    dist[i, j] = dist[i, k] + dist[k, j];

    // Negative cycle detection
    for (int i = 0; i < n; i++)
        if (dist[i, i] < 0)
            throw new InvalidOperationException("Negative cycle detected");

    return dist;
}
```

### Comparison

|Algorithm|Time|Space|Use Case|
|---|---|---|---|
|Floyd-Warshall|O(V³)|O(V²)|Dense graphs, all-pairs, simple code|
|Dijkstra × V|O(V·(V+E) log V)|O(V²)|Sparse graphs, all-pairs|
|Bellman-Ford × V|O(V²·E)|O(V²)|Negative edges, all-pairs|

### Gotchas

- **Infinity overflow** — Use `int.MaxValue / 2` as infinity so that adding two infinities does not overflow.
- **Graph size** — V³ for V = 500 is 125 million operations, feasible. For V = 2000, it is 8 billion — too slow.
- **Edge duplication** — If there are multiple edges between i and j, use the minimum weight.
- **Memory** — O(V²) is 3.8 MB for V = 1000 (int array). Acceptable for most interview constraints.
- **Path reconstruction** — Maintain a separate `next[i][j]` matrix to reconstruct the actual path.

