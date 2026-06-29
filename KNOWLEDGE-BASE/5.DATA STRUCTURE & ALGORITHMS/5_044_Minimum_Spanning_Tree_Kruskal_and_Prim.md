---
id: "5.044"
studied_well: false
title: "Minimum Spanning Tree — Kruskal's and Prim's"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Graphs"
tags: [dsa, algorithms, graphs, mst, kruskal, prim, union-find, greedy, csharp, interviews]
priority: 3
prerequisites:
  - "[[5.040 — Union-Find (Disjoint Set Union)]]"
  - "[[5.031 — Min-Heap and Max-Heap — Structure and Heapify]]"
related:
  - "[[5.049 — Comparison-Based Sorting]]"
  - "[[5.041 — Dijkstra's Algorithm]]"
  - "[[5.042 — Bellman-Ford Algorithm]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Graphs
**Previous:** [[5.042 — Bellman-Ford Algorithm]] | **Next:** [[5.046 — Binary Search — Classic Implementation and Off-by-One Discipline]]

### Prerequisites
- [[5.040 — Union-Find (Disjoint Set Union)]] — Kruskal's algorithm uses Union-Find to detect cycles when adding edges.
- [[5.031 — Min-Heap and Max-Heap — Structure and Heapify]] — Prim's algorithm uses a min-heap (PriorityQueue) to select the cheapest frontier edge.

### Where This Fits
A Minimum Spanning Tree (MST) connects all vertices in an undirected weighted graph with the minimum total edge weight. Kruskal's algorithm sorts all edges by weight and adds them greedily if they connect two different components. Prim's algorithm grows a tree from a start vertex, always adding the cheapest edge from the tree to a vertex outside it. MST appears in network design (laying cables with minimal cost), clustering (Kruskal's is the basis for single-linkage clustering), and approximation algorithms (traveling salesman, Steiner tree). In interviews (~3% of hard graph problems), MST typically appears as a subproblem or as a validation of greedy algorithm understanding.

### Performance

|Algorithm|Time|Space|Best When|
|---|---|---|---|
|Kruskal's|O(E log E)|O(V + E)|Sparse graphs (E ≈ V)|
|Prim's (binary heap)|O((V+E) log V)|O(V + E)|Dense graphs (E ≈ V²)|
|Prim's (unsorted array)|O(V²)|O(V)|Dense graphs with small V|

### Key Insight

Kruskal's processes edges globally by weight; Prim's grows locally from a seed. Both are greedy and both rely on the **cut property**: the minimum-weight edge crossing any cut belongs to every MST. Kruskal's uses Union-Find to check if two vertices are already connected (forming a cycle). Prim's uses a visited set and a priority queue to select the cheapest frontier edge.

### Implementation

```csharp
// Kruskal's
public int KruskalMST(int n, List<(int u, int v, int w)> edges)
{
    edges.Sort((a, b) => a.w.CompareTo(b.w));
    var dsu = new DSU(n);
    int totalWeight = 0;

    foreach (var (u, v, w) in edges)
    {
        if (dsu.Union(u, v))
            totalWeight += w;  // Edge added to MST
    }

    return totalWeight;
}

// Prim's
public int PrimMST(int n, List<(int to, int weight)>[] graph)
{
    var visited = new bool[n];
    var pq = new PriorityQueue<int, int>();
    int totalWeight = 0;
    int verticesInMST = 0;

    visited[0] = true;
    verticesInMST = 1;
    foreach (var (to, w) in graph[0])
        pq.Enqueue(to, w);

    while (pq.Count > 0 && verticesInMST < n)
    {
        pq.TryDequeue(out int v, out int w);
        if (visited[v]) continue;  // Lazy deletion

        visited[v] = true;
        totalWeight += w;
        verticesInMST++;

        foreach (var (to, weight) in graph[v])
        {
            if (!visited[to])
                pq.Enqueue(to, weight);
        }
    }

    return totalWeight;
}
```

### Gotchas

- **Disconnected graph** — Both algorithms produce a spanning forest (minimum spanning forest) when the graph is disconnected. Check the number of edges in the MST: it should be V-1.
- **Negative weights** — Both algorithms handle negative edge weights correctly. The MST definition only requires minimum total weight, which negative edges satisfy.
- **Multiple edges** — When multiple edges have the same weight, there may be multiple valid MSTs. Any MST is acceptable.
- **Kruskal's edge sorting** — Sorting E edges is O(E log E). For dense graphs, this dominates. Use Prim's instead.
- **Prim's visited check** — The lazy Prim's implementation may have stale entries in the heap. The `visited[v]` check on dequeue is essential for correctness.

