---
id: "5.045"
studied_well: false
title: "Strongly Connected Components — Tarjan's and Kosaraju's"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Graphs"
tags: [dsa, algorithms, graphs, scc, tarjan, kosaraju, dfs, csharp, interviews]
priority: 3
prerequisites:
  - "[[5.038 — DFS — Cycle Detection, Connected Components, Islands]]"
related:
  - "[[5.039 — Topological Sort — Kahn's and DFS-Based]]"
  - "[[5.044 — Minimum Spanning Tree — Kruskal's and Prim's]]"
  - "[[5.015 — Stack — LIFO Applications and Balanced Parentheses]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Graphs
**Previous:** [[5.044 — Minimum Spanning Tree — Kruskal's and Prim's]] | **Next:** [[5.046 — Binary Search — Classic Implementation and Off-by-One Discipline]]

### Prerequisites
- [[5.038 — DFS — Cycle Detection, Connected Components, Islands]] — both Tarjan's and Kosaraju's are DFS-based algorithms; understanding graph DFS with visited state is required.

### Where This Fits
A strongly connected component (SCC) is a maximal set of vertices where every pair is mutually reachable. Kosaraju's algorithm runs DFS on the original graph, then DFS on the reversed graph in decreasing finish time. Tarjan's algorithm uses a single DFS with a stack and low-link values to identify SCCs. SCCs appear in dependency analysis (finding cycles in package dependencies), social network analysis (communities with mutual following), and compiler optimization (identifying loops for optimization). In interviews, SCC questions typically involve finding cycles in directed graphs or reducing a graph to its SCC DAG.

### Key Insight

Both algorithms exploit the fact that if you start DFS from a vertex in an SCC, you will visit all vertices in that SCC before returning. Kosaraju's uses graph reversal to separate SCCs; Tarjan's uses a low-link value (the earliest vertex reachable via back edges in the DFS tree) to identify SCC roots.

### Kosaraju's Algorithm

```csharp
public List<List<int>> KosarajuSCC(int n, List<int>[] graph)
{
    // 1. First pass — order by finish time (post-order)
    var visited = new bool[n];
    var order = new Stack<int>();

    void Dfs1(int u)
    {
        visited[u] = true;
        foreach (var v in graph[u])
            if (!visited[v]) Dfs1(v);
        order.Push(u);
    }

    for (int i = 0; i < n; i++)
        if (!visited[i]) Dfs1(i);

    // 2. Reverse the graph
    var revGraph = new List<int>[n];
    for (int i = 0; i < n; i++) revGraph[i] = new List<int>();
    for (int u = 0; u < n; u++)
        foreach (var v in graph[u])
            revGraph[v].Add(u);

    // 3. Second pass on reversed graph in finish-time order
    var result = new List<List<int>>();
    visited = new bool[n];

    void Dfs2(int u, List<int> component)
    {
        visited[u] = true;
        component.Add(u);
        foreach (var v in revGraph[u])
            if (!visited[v]) Dfs2(v, component);
    }

    while (order.Count > 0)
    {
        int u = order.Pop();
        if (!visited[u])
        {
            var component = new List<int>();
            Dfs2(u, component);
            result.Add(component);
        }
    }

    return result;
}
```

### Tarjan's Algorithm

```csharp
public List<List<int>> TarjanSCC(int n, List<int>[] graph)
{
    var result = new List<List<int>>();
    int[] index = new int[n];
    int[] lowLink = new int[n];
    bool[] onStack = new bool[n];
    var stack = new Stack<int>();
    Array.Fill(index, -1);
    int nextIndex = 0;

    void StrongConnect(int u)
    {
        index[u] = lowLink[u] = nextIndex++;
        stack.Push(u);
        onStack[u] = true;

        foreach (var v in graph[u])
        {
            if (index[v] == -1)
            {
                StrongConnect(v);
                lowLink[u] = Math.Min(lowLink[u], lowLink[v]);
            }
            else if (onStack[v])
            {
                lowLink[u] = Math.Min(lowLink[u], index[v]);
            }
        }

        if (lowLink[u] == index[u])
        {
            var component = new List<int>();
            while (true)
            {
                var w = stack.Pop();
                onStack[w] = false;
                component.Add(w);
                if (w == u) break;
            }
            result.Add(component);
        }
    }

    for (int i = 0; i < n; i++)
        if (index[i] == -1) StrongConnect(i);

    return result;
}
```

### Gotchas

- **Graph reversal (Kosaraju)** — Reversing the graph doubles memory. For large graphs, Tarjan's is more efficient (single pass).
- **Low-link vs index (Tarjan)** — The conditional `if (onStack[v])` ensures we only consider back edges, not cross edges to already-resolved SCCs.
- **Disconnected graphs** — Both algorithms handle disconnected graphs naturally; each unvisited vertex starts a new DFS.
- **Self-loops** — A self-loop makes a single vertex an SCC (it can reach itself).
- **SCC DAG** — Contracting each SCC into a single vertex produces a DAG. The condensation graph's topological order is the reverse of Kosaraju's first-pass finish order.

