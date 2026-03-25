# Breadth-First Search
> A graph traversal that explores all neighbors at the current depth before moving to the next level — guarantees shortest path on unweighted graphs.

---

## When To Use It
Use BFS when you need the shortest path on an unweighted graph, when you need to process nodes level by level, or when the answer is likely close to the start (DFS might waste time going deep before finding it). Don't use BFS when you need to explore all paths or detect cycles in directed graphs — DFS handles those better. For weighted graphs, use Dijkstra's algorithm instead.

---

## Core Concept
BFS processes nodes in order of their distance from the source. It uses a queue: start by enqueuing the source, then repeatedly dequeue a node, enqueue its unvisited neighbors, and record their distance as current + 1. Because a node is first reached via the fewest hops possible, the first time BFS reaches the destination is guaranteed to be via the shortest route.

The key implementation detail that trips people up: mark nodes visited when you enqueue them, not when you dequeue them. If you mark on dequeue, the same node can be enqueued multiple times before being processed, causing duplicate work or, in the worst case, infinite loops.

---

## The Code

**BFS — shortest path on unweighted graph**
```csharp
using System;
using System.Collections.Generic;

public int BFS(Dictionary<int, List<int>> graph, int start, int end)
{
    var visited = new HashSet<int> { start };
    var queue = new Queue<(int node, int dist)>();
    queue.Enqueue((start, 0));
    while (queue.Count > 0)
    {
        var (node, dist) = queue.Dequeue();
        if (node == end)
            return dist;
        foreach (int neighbor in graph[node])
        {
            if (!visited.Contains(neighbor))
            {
                visited.Add(neighbor);  // mark on enqueue, not dequeue
                queue.Enqueue((neighbor, dist + 1));
            }
        }
    }
    return -1;  // unreachable
}
```

**BFS level order — process nodes layer by layer**
```csharp
public List<List<int>> LevelOrder(Dictionary<int, List<int>> graph, int start)
{
    var visited = new HashSet<int> { start };
    var queue = new Queue<int>();
    queue.Enqueue(start);
    var levels = new List<List<int>>();
    while (queue.Count > 0)
    {
        int levelSize = queue.Count;  // snapshot: how many nodes are in this level
        var level = new List<int>();
        for (int i = 0; i < levelSize; i++)
        {
            int node = queue.Dequeue();
            level.Add(node);
            foreach (int neighbor in graph[node])
            {
                if (!visited.Contains(neighbor))
                {
                    visited.Add(neighbor);
                    queue.Enqueue(neighbor);
                }
            }
        }
        levels.Add(level);
    }
    return levels;
}
```

**BFS on a 2D grid — shortest path**
```csharp
public int ShortestPathGrid(char[][] grid, (int, int) start, (int, int) end)
{
    int rows = grid.Length, cols = grid[0].Length;
    var visited = new HashSet<(int, int)> { start };
    var queue = new Queue<(int r, int c, int dist)>();
    queue.Enqueue((start.Item1, start.Item2, 0));
    int[][] directions = new int[][] { new[] { -1, 0 }, new[] { 1, 0 }, new[] { 0, -1 }, new[] { 0, 1 } };
    while (queue.Count > 0)
    {
        var (r, c, dist) = queue.Dequeue();
        if ((r, c) == end)
            return dist;
        foreach (int[] dir in directions)
        {
            int nr = r + dir[0], nc = c + dir[1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols &&
                grid[nr][nc] != '#' && !visited.Contains((nr, nc)))
            {
                visited.Add((nr, nc));
                queue.Enqueue((nr, nc, dist + 1));
            }
        }
    }
    return -1;
}
```

**Multi-source BFS — start from multiple sources simultaneously**
```csharp
public void WallsAndGates(int[][] rooms)
{
    // Fill each empty room with distance to nearest gate (0).
    // Gates are 0, walls are -1, empty rooms are INF.
    int INF = int.MaxValue;
    int rows = rooms.Length, cols = rooms[0].Length;
    var queue = new Queue<(int, int)>();
    for (int r = 0; r < rows; r++)
    {
        for (int c = 0; c < cols; c++)
        {
            if (rooms[r][c] == 0)
                queue.Enqueue((r, c));  // seed all gates at once
        }
    }

    int[][] directions = new int[][] { new[] { -1, 0 }, new[] { 1, 0 }, new[] { 0, -1 }, new[] { 0, 1 } };
    while (queue.Count > 0)
    {
        var (r, c) = queue.Dequeue();
        foreach (int[] dir in directions)
        {
            int nr = r + dir[0], nc = c + dir[1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && rooms[nr][nc] == INF)
            {
                rooms[nr][nc] = rooms[r][c] + 1;
                queue.Enqueue((nr, nc));
            }
        }
    }
}
```

**Word ladder — BFS on an implicit graph**
```csharp
public int WordLadder(string begin, string end, HashSet<string> wordList)
{
    if (!wordList.Contains(end))
        return 0;
    var queue = new Queue<(string word, int steps)>();
    queue.Enqueue((begin, 1));
    var visited = new HashSet<string> { begin };
    while (queue.Count > 0)
    {
        var (word, steps) = queue.Dequeue();
        for (int i = 0; i < word.Length; i++)
        {
            for (char c = 'a'; c <= 'z'; c++)
            {
                var candidate = word.Substring(0, i) + c + word.Substring(i + 1);
                if (candidate == end)
                    return steps + 1;
                if (wordList.Contains(candidate) && !visited.Contains(candidate))
                {
                    visited.Add(candidate);
                    queue.Enqueue((candidate, steps + 1));
                }
            }
        }
    }
    return 0;
}
```

---

## Gotchas

- **Use `collections.deque`, never `list.pop(0)`.** `list.pop(0)` is O(n) — every element shifts. At scale this turns an O(V + E) BFS into O(V² + E). Always use `deque.popleft()`.
- **Mark visited on enqueue, not dequeue.** Marking on dequeue allows the same node to be enqueued multiple times. For a densely connected graph this multiplies work; for a graph with cycles it causes infinite looping.
- **BFS finds shortest path only on unweighted graphs.** Every edge is treated as cost 1. Add weights and BFS gives wrong answers. Use Dijkstra for weighted graphs.
- **Multi-source BFS seeds all sources into the queue at step 0.** This correctly computes distance to the nearest source in one pass. Running separate BFS from each source is O(k × (V + E)) — far slower and unnecessary.
- **Level size must be snapshotted before the inner loop.** If you use `while queue` without capturing `len(queue)` first, appending children mid-loop causes the inner loop to bleed into the next level, mixing distances.

---

## Interview Angle

**What they're really testing:** Whether you reach for BFS when the problem asks for "minimum steps," "shortest path," or "nearest X" — and whether you implement it correctly (deque, mark on enqueue, level-size snapshot).

**Common question form:** Shortest path in a grid, word ladder, rotting oranges, walls and gates, binary tree level order traversal, minimum depth of binary tree.

**The depth signal:** A junior uses BFS and gets the right answer on simple cases but marks visited on dequeue, causing TLE on dense graphs. A senior marks on enqueue, knows multi-source BFS as a first-class pattern (not "run BFS from each source"), and can explain *why* BFS guarantees shortest path — nodes are processed in non-decreasing distance order, so the first time you reach a destination is always optimal.

---

## Related Topics

- [[algorithms/depth-first-search.md]] — The alternative traversal; DFS for full exploration, BFS for shortest path.
- [[algorithms/dijkstra.md]] — BFS generalized to weighted edges using a priority queue instead of a plain queue.
- [[algorithms/queue.md]] — The data structure BFS is built on; deque correctness is critical.
- [[algorithms/graph.md]] — Graph representations and the full BFS/DFS decision framework.

---

## Source

https://en.wikipedia.org/wiki/Breadth-first_search

---

*Last updated: 2026-03-24*