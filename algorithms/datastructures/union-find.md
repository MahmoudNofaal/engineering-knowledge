# Union-Find (Disjoint Set Union)

> A data structure that tracks which elements belong to the same group, supporting merge and membership-check in near-O(1).

---

## Quick Reference

| | |
|---|---|
| **What it is** | Partition tracker — group merging and membership |
| **Use when** | Dynamic connectivity, cycle detection, Kruskal's MST |
| **Avoid when** | You need to split groups or list group members efficiently |
| **C# version** | C# 2.0+ (custom implementation — no BCL type) |
| **Namespace** | Custom implementation |
| **Key types** | `int[] parent`, `int[] rank` or `int[] size` |

---

## When To Use It

Use Union-Find when you need to repeatedly answer "are these two elements connected?" and "connect these two elements" on a dynamic set. It's the best tool for: detecting cycles in an undirected graph (add edges one by one — a cycle exists when you try to union two nodes already in the same set), building a minimum spanning tree with Kruskal's algorithm, determining connected components as edges are added in real time, and network connectivity problems.

Avoid it when you need to split groups apart (Union-Find only merges, never splits), when you need to enumerate all members of a group efficiently (Union-Find doesn't store group membership lists), or when the graph is directed (directed connectivity requires BFS/DFS or Tarjan's SCC — not Union-Find).

---

## Core Concept

Union-Find represents a partition of n elements into disjoint sets. Each set has a representative (root). Every element points to its parent; the root points to itself.

Two operations:

**Find(x):** Walk up the parent chain until you reach the root. With **path compression**, every node on the walk is rewired to point directly to the root — future Find calls on any of those nodes are O(1).

**Union(x, y):** Find the roots of x and y. If they're the same, they're already connected. Otherwise, merge the two trees. With **union by rank** (attach the shorter tree under the taller), the tree height stays at most O(log n). With **union by size** (attach the smaller-count tree under the larger), you get the same guarantee.

Combined, path compression + union by rank gives an amortised time of O(α(n)) per operation, where α is the inverse Ackermann function — effectively O(1) for any realistic input (α(n) ≤ 4 for n < 10^80).

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Custom via `int[]` — no generics, but the algorithm is array-based anyway |
| C# 2.0 | .NET 2.0 | Generic wrappers possible; still no BCL support |
| C# 9.0 | .NET 5 | `record struct` enables lightweight node types for typed Union-Find |
| C# 12.0 | .NET 8 | Primary constructors simplify UnionFind class definitions |

*Union-Find has never been in the .NET BCL. It's always hand-implemented — but it's one of the shortest correct implementations in competitive programming, typically under 20 lines.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Find | O(α(n)) amortised | Effectively O(1) in practice |
| Union | O(α(n)) amortised | Find both roots + one pointer assignment |
| Connected | O(α(n)) amortised | Find(x) == Find(y) |
| Build n elements | O(n) | Initialise parent[i] = i for all i |
| Space | O(n) | Two arrays: parent and rank/size |

**Allocation behaviour:** Two `int[]` arrays of length n. No per-element heap allocation beyond the initial arrays. Extremely cache-friendly — both arrays are accessed sequentially during build and with near-sequential access during path-compressed Find.

**Benchmark notes:** For n under ~100, the constant factors mean Union-Find has no meaningful advantage over BFS/DFS for connectivity. Above ~10,000 elements with many interleaved union and find operations, the O(α(n)) amortised bound is practically unbeatable. Path compression is what makes it fast in practice — without it, Find degrades to O(log n) with union by rank, or O(n) with naive union.

---

## The Code

**Standard implementation — path compression + union by rank**
```csharp
public class UnionFind
{
    private readonly int[] _parent;
    private readonly int[] _rank;
    public int ComponentCount { get; private set; }

    public UnionFind(int n)
    {
        _parent = new int[n];
        _rank   = new int[n];
        ComponentCount = n;
        for (int i = 0; i < n; i++)
            _parent[i] = i;   // each element is its own root
    }

    // Find with path compression — O(α(n))
    public int Find(int x)
    {
        if (_parent[x] != x)
            _parent[x] = Find(_parent[x]);   // compress: point directly to root
        return _parent[x];
    }

    // Union by rank — attach shorter tree under taller
    public bool Union(int x, int y)
    {
        int rx = Find(x), ry = Find(y);
        if (rx == ry) return false;    // already in same set — would form a cycle

        if (_rank[rx] < _rank[ry]) (rx, ry) = (ry, rx);   // ensure rx is taller
        _parent[ry] = rx;
        if (_rank[rx] == _rank[ry]) _rank[rx]++;
        ComponentCount--;
        return true;    // true = merge happened (no cycle)
    }

    public bool Connected(int x, int y) => Find(x) == Find(y);
}
```

**Cycle detection in an undirected graph**
```csharp
public static bool HasCycle(int numNodes, List<(int u, int v)> edges)
{
    var uf = new UnionFind(numNodes);
    foreach (var (u, v) in edges)
    {
        if (!uf.Union(u, v))
            return true;   // Union returned false = already connected = cycle
    }
    return false;
}
// HasCycle(4, [(0,1),(1,2),(2,0),(2,3)]) → true  (0→1→2→0 is a cycle)
```

**Number of connected components**
```csharp
public static int CountComponents(int n, int[][] edges)
{
    var uf = new UnionFind(n);
    foreach (int[] edge in edges)
        uf.Union(edge[0], edge[1]);
    return uf.ComponentCount;
}
```

**Kruskal's Minimum Spanning Tree — Union-Find's canonical application**
```csharp
public static int MinSpanningTreeCost(int n, List<(int u, int v, int weight)> edges)
{
    // Sort edges by weight — greedy: take cheapest edge that doesn't form a cycle
    var sorted = edges.OrderBy(e => e.weight).ToList();
    var uf     = new UnionFind(n);
    int totalCost  = 0;
    int edgesAdded = 0;

    foreach (var (u, v, w) in sorted)
    {
        if (uf.Union(u, v))           // true = no cycle — safe to add this edge
        {
            totalCost  += w;
            edgesAdded++;
            if (edgesAdded == n - 1) break;   // MST has exactly n-1 edges
        }
    }
    return edgesAdded == n - 1 ? totalCost : -1;   // -1 = disconnected graph
}
```

**What NOT to do — and the fix**
```csharp
// BAD: Find without path compression — O(log n) instead of O(α(n))
public int FindBad(int x)
{
    while (_parent[x] != x)
        x = _parent[x];    // no compression: next Find on the same path is equally slow
    return x;
}

// GOOD: recursive path compression — rewires every node on the path to the root
public int FindGood(int x)
{
    if (_parent[x] != x)
        _parent[x] = FindGood(_parent[x]);   // path compression
    return _parent[x];
}

// ALSO GOOD: iterative path compression (avoids stack overflow for large n)
public int FindIterative(int x)
{
    int root = x;
    while (_parent[root] != root) root = _parent[root];   // find root
    while (_parent[x] != root) { int next = _parent[x]; _parent[x] = root; x = next; }   // compress
    return root;
}
```

---

## Real World Example

A social platform needs to recommend "people you might know": users who are in the same connected component (friends-of-friends-of-friends). As new friendships are created, the service updates group membership in real time. With millions of users and thousands of new connections per second, BFS/DFS per update is too slow. Union-Find handles each new friendship in O(α(n)) ≈ O(1) and answers "are these users in the same group?" in the same time.

```csharp
public class FriendshipNetwork
{
    private readonly UnionFind _uf;
    private readonly Dictionary<string, int> _userIndex = new();
    private int _nextId;

    public FriendshipNetwork(IEnumerable<string> users)
    {
        var userList = users.ToList();
        _uf     = new UnionFind(userList.Count);
        _nextId = 0;
        foreach (string user in userList)
            _userIndex[user] = _nextId++;
    }

    // Add a friendship — O(α(n))
    public void AddFriendship(string userA, string userB)
    {
        if (!_userIndex.TryGetValue(userA, out int ia) ||
            !_userIndex.TryGetValue(userB, out int ib))
            throw new ArgumentException("Unknown user.");
        _uf.Union(ia, ib);
    }

    // Are they in the same friend network? — O(α(n))
    public bool InSameNetwork(string userA, string userB)
    {
        if (!_userIndex.TryGetValue(userA, out int ia) ||
            !_userIndex.TryGetValue(userB, out int ib))
            return false;
        return _uf.Connected(ia, ib);
    }

    // How many distinct friend networks exist? — O(1) after all unions
    public int NetworkCount() => _uf.ComponentCount;
}
```

*The key insight is that Union-Find gives you connected-component membership without ever storing or traversing the full graph — just two flat integer arrays. Adding an edge is O(1); checking connectivity is O(1). No adjacency list, no BFS, no queue.*

---

## Common Misconceptions

**"Union-Find can detect cycles in directed graphs"**
It cannot. Union-Find is designed for **undirected** connectivity. For directed cycle detection, use DFS with three-colour marking (white/gray/black). The intuition: in an undirected graph, a cycle exists when you try to connect two nodes already connected. In a directed graph, you can have a path from A to B and from B to A without a cycle in the undirected sense.

**"You have to implement path compression recursively"**
You can implement it iteratively (two-pass: find root, then repoint all nodes on the path). The iterative version avoids stack overflow for degenerate inputs where the tree is tall before compression. For most competitive programming inputs, the recursive version is fine — use iterative in production code.

**"Union by rank and union by size are equivalent"**
They produce the same O(log n) height guarantee but via different strategies. Rank tracks an upper bound on height; size tracks the number of nodes. Both work correctly with path compression. Union by size is slightly more intuitive to implement and reason about. Rank is marginally tighter as a height bound. In practice the difference is negligible.

---

## Gotchas

- **Always find roots before comparing.** `_parent[x] == _parent[y]` does not tell you if x and y are connected — it only tells you if they have the same immediate parent. Always use `Find(x) == Find(y)`.

- **Path compression changes `_parent` in-place.** If you store a reference to `_parent[x]` before a `Find` call and use it after, it may be stale. Always call `Find` fresh.

- **`ComponentCount` is only accurate if you maintain it.** Decrement it by 1 in `Union` when a merge actually happens (when `Find(x) != Find(y)`). If you forget the guard, you'll undercount.

- **Union-Find does not support split operations.** Once two elements are merged, you cannot un-merge them. If you need "undo" (rollback merges), you must use a union-find with explicit undo support — store a stack of previous parent assignments and restore them on rollback.

- **For very large n (> ~100,000), use iterative Find.** Recursive path compression can stack-overflow on a tall tree before the first compression. The iterative two-pass version is safe at any n.

---

## Interview Angle

**What they're really testing:** Whether you know Union-Find exists and can apply it correctly to graph connectivity and cycle detection problems — and whether you know both optimisations (path compression + union by rank) without which Find degrades.

**Common question forms:**
- "Number of connected components in an undirected graph"
- "Detect cycle in an undirected graph"
- "Accounts merge — merge accounts with a shared email"
- "Number of islands II — dynamic islands added one by one"
- "Minimum cost to connect all points (Kruskal's MST)"

**The depth signal:** A junior solves connectivity with BFS/DFS — O(V + E) per query. A senior immediately reaches for Union-Find for dynamic connectivity problems — O(α(n)) per union and find. The elite signal is knowing both optimisations by name (path compression, union by rank), being able to explain why union by rank without path compression is O(log n) and why together they give O(α(n)), and recognising that Union-Find only works for undirected graphs.

**Follow-up questions to expect:**
- "What's the time complexity without the optimisations?" (Find is O(n) without compression; O(log n) with rank but no compression)
- "Can you undo a union?" (Not with standard Union-Find — need a stack-based rollback variant)
- "Why doesn't this work for directed graphs?" (Union-Find tracks symmetric reachability; directed connectivity is not symmetric)

---

## Related Topics

- [[algorithms/datastructures/graph.md]] — BFS/DFS for connectivity when the graph is static; Union-Find when edges arrive dynamically.
- [[algorithms/searching/breadth-first-search.md]] — The alternative for undirected connectivity when you need full component enumeration.
- [[algorithms/datastructures/heap.md]] — Kruskal's MST uses Union-Find for cycle detection and a min-heap for edge selection.

---

## Source

https://en.wikipedia.org/wiki/Disjoint-set_data_structure

---

*Last updated: 2026-04-12*