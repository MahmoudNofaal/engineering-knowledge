# Breadth-First Search

> A graph traversal that explores all neighbours at the current depth before moving to the next level — guarantees shortest path on unweighted graphs.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Level-by-level graph traversal using a queue |
| **Use when** | Shortest path (unweighted), level-order traversal, nearest X |
| **Avoid when** | Weighted edges (use Dijkstra); exploring all paths (use DFS) |
| **C# version** | C# 1.0+ (uses `Queue<T>`) |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `Queue<T>`, `HashSet<T>` for visited |

---

## When To Use It

Use BFS when you need the shortest path on an unweighted graph, level-by-level processing, or finding the nearest occurrence of a condition. The signal is "minimum steps," "shortest path," or "nearest X." For weighted graphs, use Dijkstra. For exploring all paths or detecting cycles in directed graphs, use DFS.

---

## Core Concept

BFS processes nodes in non-decreasing order of distance from the source. It uses a queue: enqueue the source, then repeatedly dequeue a node, enqueue its unvisited neighbours, and record their distance as current + 1. The first time BFS reaches the destination is via the shortest route — guaranteed because all edges have equal cost (1).

Critical implementation detail: mark nodes visited when you **enqueue** them, not when you dequeue them. Marking on dequeue allows the same node to be enqueued multiple times before being processed — causing duplicate work or infinite loops.

---

## Algorithm History

| Year | Development |
|---|---|
| 1945 | Konrad Zuse describes a similar traversal in his Plankalkül language notes |
| 1959 | Edward Moore publishes BFS for finding shortest paths in mazes |
| 1961 | C.Y. Lee independently develops BFS for circuit routing |
| 1970s | Formalized in graph algorithm textbooks |

---

## Performance

| Operation | Time | Space | Notes |
|---|---|---|---|
| BFS traversal | O(V + E) | O(V) | V vertices, E edges |
| Shortest path (unweighted) | O(V + E) | O(V) | First reach = shortest |
| Level-order traversal | O(V + E) | O(V) | Snapshot level size each level |
| Multi-source BFS | O(V + E) | O(V) | Seed all sources at distance 0 |

**Allocation behaviour:** One `Queue<T>` (up to O(V) entries at peak), one `HashSet<T>` for visited (O(V)). No per-step allocation in the inner loop.

---

## The Code

**Scenario 1 — shortest path on unweighted graph**
```csharp
public int BFS(Dictionary<int, List<int>> graph, int start, int end)
{
    var visited = new HashSet<int> { start };
    var queue   = new Queue<(int Node, int Dist)>();
    queue.Enqueue((start, 0));

    while (queue.Count > 0)
    {
        var (node, dist) = queue.Dequeue();
        if (node == end) return dist;
        foreach (int neighbour in graph[node])
            if (visited.Add(neighbour))          // Add returns false if already present
                queue.Enqueue((neighbour, dist + 1));
    }
    return -1;
}
```

**Scenario 2 — level-order traversal**
```csharp
public List<List<int>> LevelOrder(Dictionary<int, List<int>> graph, int start)
{
    var visited = new HashSet<int> { start };
    var queue   = new Queue<int>();
    queue.Enqueue(start);
    var levels = new List<List<int>>();

    while (queue.Count > 0)
    {
        int levelSize = queue.Count; // snapshot: how many nodes in this level
        var level = new List<int>(levelSize);
        for (int i = 0; i < levelSize; i++)
        {
            int node = queue.Dequeue();
            level.Add(node);
            foreach (int nb in graph[node])
                if (visited.Add(nb)) queue.Enqueue(nb);
        }
        levels.Add(level);
    }
    return levels;
}
```

**Scenario 3 — multi-source BFS (distance to nearest gate)**
```csharp
public void WallsAndGates(int[][] rooms)
{
    int rows = rooms.Length, cols = rooms[0].Length, INF = int.MaxValue;
    var queue = new Queue<(int R, int C)>();

    // Seed ALL gates simultaneously at distance 0
    for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++)
            if (rooms[r][c] == 0) queue.Enqueue((r, c));

    int[][] dirs = { new[]{-1,0}, new[]{1,0}, new[]{0,-1}, new[]{0,1} };
    while (queue.Count > 0)
    {
        var (r, c) = queue.Dequeue();
        foreach (var d in dirs)
        {
            int nr = r + d[0], nc = c + d[1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && rooms[nr][nc] == INF)
            {
                rooms[nr][nc] = rooms[r][c] + 1;
                queue.Enqueue((nr, nc));
            }
        }
    }
}
```

**Scenario 4 — what NOT to do: marking visited on dequeue**
```csharp
// BAD: marking on dequeue allows duplicate enqueuing — O(E) wasted work, potential loops
public void BfsBad(Dictionary<int, List<int>> graph, int start)
{
    var visited = new HashSet<int>();
    var queue   = new Queue<int>();
    queue.Enqueue(start);
    while (queue.Count > 0)
    {
        int node = queue.Dequeue();
        if (visited.Contains(node)) continue; // check AFTER dequeue — too late
        visited.Add(node);
        foreach (int nb in graph[node]) queue.Enqueue(nb); // enqueues duplicates
    }
}

// GOOD: mark on enqueue — each node enters the queue exactly once
public void BfsGood(Dictionary<int, List<int>> graph, int start)
{
    var visited = new HashSet<int> { start }; // mark on enqueue
    var queue   = new Queue<int>();
    queue.Enqueue(start);
    while (queue.Count > 0)
    {
        int node = queue.Dequeue();
        foreach (int nb in graph[node])
            if (visited.Add(nb))   // Add returns false if already visited
                queue.Enqueue(nb); // only enqueue unvisited
    }
}
```

---

## Real World Example

The `FriendSuggestionService` in a social platform suggests "people you may know" — users within 2 degrees of separation. BFS from a user's node up to depth 2 collects all candidates. Multi-source BFS from all of the user's friends simultaneously avoids redundant re-traversal.

```csharp
public class FriendSuggestionService
{
    private readonly Dictionary<int, HashSet<int>> _friendGraph;

    public FriendSuggestionService(Dictionary<int, HashSet<int>> friendGraph)
        => _friendGraph = friendGraph;

    // Returns users within maxDegrees hops, excluding direct friends and self.
    public List<(int UserId, int Degree)> GetSuggestions(int userId, int maxDegrees = 2)
    {
        var visited  = new HashSet<int> { userId };
        var queue    = new Queue<(int UserId, int Degree)>();
        var result   = new List<(int, int)>();

        queue.Enqueue((userId, 0));
        visited.Add(userId);

        while (queue.Count > 0)
        {
            var (current, degree) = queue.Dequeue();
            if (degree >= maxDegrees) continue; // don't expand beyond max depth

            if (!_friendGraph.TryGetValue(current, out var friends)) continue;
            foreach (int friend in friends)
            {
                if (!visited.Add(friend)) continue; // already seen
                int friendDegree = degree + 1;
                // Direct friends (degree 1) are not suggestions — they're already connected
                if (friendDegree > 1) result.Add((friend, friendDegree));
                queue.Enqueue((friend, friendDegree));
            }
        }
        return result.OrderBy(r => r.Degree).ToList();
    }
}
```

*The key insight: BFS guarantees that each user is first discovered via the shortest path. When we first reach a user at degree d, that's the minimum degree of separation — we never need to re-process them at a higher degree.*

---

## Common Misconceptions

**"BFS and DFS produce the same result"**
They visit the same nodes but in completely different orders. BFS visits all nodes at depth d before any at depth d+1 — it finds the shortest path. DFS explores one branch as deep as possible before backtracking — it doesn't guarantee shortest paths. Use BFS for shortest path, DFS for complete exploration.

**"Multi-source BFS is just running BFS once from each source"**
No — that would be O(k × (V + E)) for k sources. Multi-source BFS seeds all sources into the queue at distance 0 simultaneously and runs one BFS pass — O(V + E) total. Each cell is correctly assigned the minimum distance to any source.

**"Level-size snapshot is optional"**
Without snapshotting `queue.Count` before the inner loop, children appended during the loop count toward the current level — mixing distances. The snapshot is mandatory for correct level-order traversal.

---

## Gotchas

- **Mark visited on enqueue, not dequeue.** Without this, the same node can be enqueued O(degree) times — turning O(V + E) BFS into O(V + E²) in the worst case.
- **Never use `List<T>` as the queue.** `list.RemoveAt(0)` is O(n). Use `Queue<T>`.
- **Snapshot `queue.Count` at the start of each level.** Required for level-order traversal.
- **Multi-source BFS seeds all sources at distance 0.** Not "run BFS from each source separately."

---

## Interview Angle

**What they're really testing:** Whether you reach for BFS for "minimum steps"/"nearest X" and implement it correctly — mark on enqueue, use Queue not List.

**Common question forms:** Shortest path in a grid. Word ladder. Rotting oranges. Binary tree level-order traversal. Minimum depth of binary tree.

**The depth signal:** A junior does BFS and marks on dequeue. A senior marks on enqueue, knows multi-source BFS as a first-class pattern, and explains why BFS guarantees shortest path — nodes are processed in non-decreasing distance order, so first-reach is always optimal.

---

## Related Topics

- [[algorithms/searching/depth-first-search.md]] — DFS for full exploration; BFS for shortest path.
- [[algorithms/searching/dijkstra.md]] — BFS generalised to weighted edges.
- [[algorithms/datastructures/queue.md]] — BFS is built on Queue semantics.
- [[algorithms/datastructures/graph.md]] — Graph representations BFS operates on.

---

## Source

https://en.wikipedia.org/wiki/Breadth-first_search

---

*Last updated: 2026-04-21*