---
id: "5.063"
studied_well: false
title: "DP on Trees and Graphs"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Dynamic Programming"
tags: [dsa, algorithms, dynamic-programming, trees, graphs, tree-dp, post-order, csharp, interviews]
priority: 3
prerequisites:
  - "[[5.061 — 2D Dynamic Programming]]"
  - "[[5.023 — Binary Tree Traversals — Pre, In, Post, Level-Order]]"
  - "[[5.041 — Dijkstra's Algorithm]]"
related:
  - "[[5.060 — 1D Dynamic Programming]]"
  - "[[5.028 — Binary Tree — Diameter, Serialize/Deserialize, Path Problems]]"
  - "[[5.037 — BFS — Shortest Path, Level-Order, Multi-Source]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Dynamic Programming
**Previous:** [[5.062 — Interval DP — Burst Balloons, Palindromic Substrings, Matrix Chain]] | **Next:** 

### Prerequisites
- [[5.061 — 2D Dynamic Programming]] — DP on trees uses a 2D state per node (include/exclude, or counts by depth).
- [[5.023 — Binary Tree Traversals — Pre, In, Post, Level-Order]] — tree DP is computed via post-order (children before parent).
- [[5.041 — Dijkstra's Algorithm]] — shortest path DP on graphs is related to Dijkstra's relaxation.

### Where This Fits
DP on trees uses post-order traversal to compute state for each node from its children. The classic problems are House Robber III (tree with constraint that no two adjacent nodes are selected), diameter of a tree, maximum path sum, and tree-based knapsack. DP on graphs typically involves shortest paths with constraints (K stops, K edges). These appear in ~5% of hard-level interviews and test the ability to combine DFS backtracking with memoization.

### House Robber III

```csharp
public int Rob(TreeNode? root)
{
    var (withRoot, withoutRoot) = Dfs(root);
    return Math.Max(withRoot, withoutRoot);
}

private (int with, int without) Dfs(TreeNode? node)
{
    if (node == null) return (0, 0);

    var left = Dfs(node.Left);
    var right = Dfs(node.Right);

    int with = node.Val + left.without + right.without;
    int without = Math.Max(left.with, left.without)
                + Math.Max(right.with, right.without);

    return (with, without);
}
```

### Max Path Sum (LeetCode 124)

```csharp
public int MaxPathSum(TreeNode? root)
{
    int maxSum = int.MinValue;
    MaxGain(root);
    return maxSum;

    int MaxGain(TreeNode? node)
    {
        if (node == null) return 0;

        int left = Math.Max(0, MaxGain(node.Left));
        int right = Math.Max(0, MaxGain(node.Right));

        // Path through current node (left + node + right)
        maxSum = Math.Max(maxSum, left + node.Val + right);

        // Return max gain from this node to its parent
        return node.Val + Math.Max(left, right);
    }
}
```

### Shortest Path with K Stops (LeetCode 787)

```csharp
public int FindCheapestPrice(int n, int[][] flights, int src, int dst, int k)
{
    int[,] dp = new int[k + 2, n];
    for (int i = 0; i <= k + 1; i++)
        for (int j = 0; j < n; j++)
            dp[i, j] = int.MaxValue;

    dp[0, src] = 0;

    for (int stops = 1; stops <= k + 1; stops++)
    {
        dp[stops, src] = 0;
        foreach (var flight in flights)
        {
            int from = flight[0], to = flight[1], price = flight[2];
            if (dp[stops - 1, from] != int.MaxValue)
                dp[stops, to] = Math.Min(dp[stops, to],
                    dp[stops - 1, from] + price);
        }
    }

    int min = int.MaxValue;
    for (int s = 0; s <= k + 1; s++)
        min = Math.Min(min, dp[s, dst]);

    return min == int.MaxValue ? -1 : min;
}
```

### Gotchas

- **Post-order guarantee** — In tree DP, the parent's state depends on children's states. This requires post-order traversal (process children first).
- **Null children** — Return identity values (0 for sum, 0 for count) for null children.
- **Global state** — Max path sum uses a closure variable to track the global maximum; the return value of the DFS is the max gain to the parent, which is a different value.
- **K stop constraint** — In graph DP with K stops, the DP dimension is [stops][vertex], not [vertex] alone. Each row depends on the previous.
- **Negative values** — In max path sum, negative subtrees should be ignored (Math.Max(0, gain)).

