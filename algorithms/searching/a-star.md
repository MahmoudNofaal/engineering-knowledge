# A* Search
> A shortest-path algorithm that uses a heuristic to guide search toward the destination, finding optimal paths faster than Dijkstra in practice.

---

## When To Use It
Use A* when you need the shortest path in a weighted graph and you have a heuristic — an estimate of remaining distance to the goal. It's the standard algorithm for pathfinding in games, robotics, and maps. Use Dijkstra when you have no heuristic or need shortest paths to all nodes. Don't use A* when the heuristic is inadmissible (overestimates cost) — it will return suboptimal paths.

---

## Core Concept
A* extends Dijkstra by adding a heuristic function h(n) that estimates the cost from node n to the goal. Instead of prioritizing nodes by their distance from the start (g(n)), A* prioritizes by f(n) = g(n) + h(n) — actual cost so far plus estimated remaining cost. This steers the search toward the goal rather than expanding in all directions equally.

The heuristic must be **admissible**: it must never overestimate the true remaining cost. An admissible heuristic guarantees A* finds the optimal path. The tighter the heuristic (closer to true remaining cost without exceeding it), the fewer nodes A* expands compared to Dijkstra. With h(n) = 0 everywhere, A* degrades to exactly Dijkstra.

For grids: Manhattan distance (|dx| + |dy|) is admissible for 4-directional movement. Euclidean distance is admissible for any movement. Chebyshev distance is admissible for 8-directional movement.

---

## The Code

**A* on a weighted grid — 4-directional movement**
```csharp
using System;
using System.Collections.Generic;

public int AStar(int[][] grid, (int, int) start, (int, int) end)
{
    int rows = grid.Length, cols = grid[0].Length;

    int Heuristic(int r, int c) => Math.Abs(r - end.Item1) + Math.Abs(c - end.Item2);

    var dist = new Dictionary<(int, int), int>();
    for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++)
            dist[(r, c)] = int.MaxValue;
    dist[start] = 0;

    // PriorityQueue<(r, c), f> — min-heap on f-score
    var heap = new PriorityQueue<(int r, int c, int g), int>();
    heap.Enqueue((start.Item1, start.Item2, 0), Heuristic(start.Item1, start.Item2));

    while (heap.Count > 0)
    {
        var (r, c, g) = heap.Dequeue();
        if ((r, c) == end)
            return g;  // g is the true cost to end
        if (g > dist[(r, c)])
            continue;  // stale entry

        int[][] directions = new int[][] { new int[] { -1, 0 }, new int[] { 1, 0 },
                                            new int[] { 0, -1 }, new int[] { 0, 1 } };
        foreach (var dir in directions)
        {
            int nr = r + dir[0], nc = c + dir[1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] != -1)
            {
                int newG = g + grid[nr][nc];
                if (newG < dist[(nr, nc)])
                {
                    dist[(nr, nc)] = newG;
                    int newF = newG + Heuristic(nr, nc);
                    heap.Enqueue((nr, nc, newG), newF);
                }
            }
        }
    }
    return -1;  // no path
}
```

**A* with path reconstruction**
```csharp
using System;
using System.Collections.Generic;
using System.Linq;

public List<(int, int)> AStarPath(int[][] grid, (int, int) start, (int, int) end)
{
    int rows = grid.Length, cols = grid[0].Length;

    int Heuristic(int r, int c) => Math.Abs(r - end.Item1) + Math.Abs(c - end.Item2);

    var dist = new Dictionary<(int, int), int>();
    var prev = new Dictionary<(int, int), (int, int)>();
    for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++)
            dist[(r, c)] = int.MaxValue;
    dist[start] = 0;

    var heap = new PriorityQueue<(int r, int c, int g), int>();
    heap.Enqueue((start.Item1, start.Item2, 0), Heuristic(start.Item1, start.Item2));

    while (heap.Count > 0)
    {
        var (r, c, g) = heap.Dequeue();
        if ((r, c) == end)
            break;
        if (g > dist[(r, c)])
            continue;

        int[][] directions = new int[][] { new int[] { -1, 0 }, new int[] { 1, 0 },
                                            new int[] { 0, -1 }, new int[] { 0, 1 } };
        foreach (var dir in directions)
        {
            int nr = r + dir[0], nc = c + dir[1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] != -1)
            {
                int newG = g + grid[nr][nc];
                if (newG < dist[(nr, nc)])
                {
                    dist[(nr, nc)] = newG;
                    prev[(nr, nc)] = (r, c);
                    int newF = newG + Heuristic(nr, nc);
                    heap.Enqueue((nr, nc, newG), newF);
                }
            }
        }
    }

    var path = new List<(int, int)>();
    var node = end;
    while (prev.ContainsKey(node))
    {
        path.Add(node);
        node = prev[node];
    }
    path.Add(start);
    path.Reverse();
    return path;
}
```

**Comparing heuristics — effect on nodes expanded**
```csharp
public int DijkstraCount(int[][] grid, (int, int) start, (int, int) end)
{
    // Count nodes expanded — baseline with h=0 (heuristic always 0)
    // Identical to A* but treated as uniform cost search
    // Returns node expansion count
    return 0;  // implementation similar to A* with Heuristic() = 0
}

public int AStarManhattanCount(int[][] grid, (int, int) start, (int, int) end)
{
    // Count nodes expanded — Manhattan heuristic
    // Typically expands far fewer nodes on open grids
    return 0;  // implementation calls A* and counts Dequeue() calls
}

// On a 100x100 open grid, A* with Manhattan typically expands
// ~10x fewer nodes than Dijkstra for a corner-to-corner query.
```

---

## Gotchas

- **An inadmissible heuristic (overestimates) produces suboptimal paths.** A* guarantees optimality only when h(n) ≤ true remaining cost for all n. If your heuristic can exceed the true cost, A* may settle a node before finding its true shortest path.
- **Ties in f-values matter.** When two nodes have equal f, breaking ties toward lower h (closer to goal) reduces nodes expanded. In Python, add the h value as a tiebreaker: push `(f, h, g, r, c)` and heapq will break ties on h.
- **The stale-entry guard is identical to Dijkstra's.** Python's heapq has no decrease-key, so you push duplicates and skip stale ones with `if g > dist[r][c]: continue`. Many A* implementations forget this and process stale entries.
- **A* is not always faster than Dijkstra.** On graphs with no spatial structure (random edge weights, non-grid graphs), no admissible heuristic meaningfully outperforms h=0. A* shines on geometric graphs where Euclidean/Manhattan distance is a tight lower bound.
- **Consistency (monotonicity) is stronger than admissibility.** A heuristic is consistent if h(n) ≤ cost(n, n') + h(n') for every edge (n, n'). Consistent heuristics are admissible and guarantee that once a node is settled its distance is final — same as Dijkstra's guarantee. Manhattan distance on a grid is consistent.

---

## Interview Angle

**What they're really testing:** Whether you understand the role of the heuristic, the admissibility requirement, and how A* relates to Dijkstra — not just that you've heard the name.

**Common question form:** A* rarely appears in standard LeetCode-style interviews. It comes up in system design for mapping/routing, game development interviews, and robotics/ML engineering roles. The more common interview form is: "How would you optimize Dijkstra if you know the approximate location of the destination?"

**The depth signal:** A junior knows A* uses a heuristic. A senior can define admissibility and consistency, explain why h=0 degrades to Dijkstra, choose the right heuristic for a movement model (Manhattan vs Euclidean vs Chebyshev), and articulate the trade-off: a tighter (closer-to-true) heuristic expands fewer nodes but may be more expensive to compute. The real depth signal is knowing that consistency eliminates the need for a closed set — once settled, a node is never re-expanded, exactly like Dijkstra.

---

## Related Topics

- [[algorithms/dijkstra.md]] — A* with h=0 is exactly Dijkstra; understanding Dijkstra is a prerequisite.
- [[algorithms/breadth-first-search.md]] — A* with h=0 and uniform weights is exactly BFS.
- [[algorithms/heap.md]] — The min-heap is what makes A*'s priority ordering efficient.
- [[algorithms/graph.md]] — Graph traversal fundamentals that A* builds on.

---

## Source

https://en.wikipedia.org/wiki/A*_search_algorithm

---

*Last updated: 2026-03-24*