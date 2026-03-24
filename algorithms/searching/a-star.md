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
```python
import heapq

def a_star(grid: list, start: tuple, end: tuple) -> int:
    rows, cols = len(grid), len(grid[0])

    def heuristic(r: int, c: int) -> int:
        # Manhattan distance — admissible for 4-directional movement
        return abs(r - end[0]) + abs(c - end[1])

    dist = [[float('inf')] * cols for _ in range(rows)]
    dist[start[0]][start[1]] = 0

    # heap stores (f = g + h, g, row, col)
    heap = [(heuristic(*start), 0, start[0], start[1])]

    while heap:
        f, g, r, c = heapq.heappop(heap)
        if (r, c) == end:
            return g                       # g is the true cost to end
        if g > dist[r][c]:
            continue                       # stale entry

        for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < rows and 0 <= nc < cols and grid[nr][nc] != -1:
                new_g = g + grid[nr][nc]   # actual cost to neighbor
                if new_g < dist[nr][nc]:
                    dist[nr][nc] = new_g
                    new_f = new_g + heuristic(nr, nc)
                    heapq.heappush(heap, (new_f, new_g, nr, nc))

    return -1                              # no path
```

**A* with path reconstruction**
```python
import heapq

def a_star_path(grid: list, start: tuple, end: tuple) -> list:
    rows, cols = len(grid), len(grid[0])

    def heuristic(r, c):
        return abs(r - end[0]) + abs(c - end[1])

    dist = [[float('inf')] * cols for _ in range(rows)]
    dist[start[0]][start[1]] = 0
    prev = {}
    heap = [(heuristic(*start), 0, start[0], start[1])]

    while heap:
        f, g, r, c = heapq.heappop(heap)
        if (r, c) == end:
            break
        if g > dist[r][c]:
            continue
        for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < rows and 0 <= nc < cols and grid[nr][nc] != -1:
                new_g = g + grid[nr][nc]
                if new_g < dist[nr][nc]:
                    dist[nr][nc] = new_g
                    prev[(nr, nc)] = (r, c)
                    heapq.heappush(heap, (new_g + heuristic(nr, nc), new_g, nr, nc))

    path, node = [], end
    while node in prev:
        path.append(node)
        node = prev[node]
    path.append(start)
    return path[::-1]
```

**Comparing heuristics — effect on nodes expanded**
```python
def dijkstra_count(grid, start, end):
    """Count nodes expanded — baseline with h=0."""
    # identical to a_star but heuristic always returns 0
    ...

def a_star_manhattan_count(grid, start, end):
    """Count nodes expanded — Manhattan heuristic."""
    # typically expands far fewer nodes on open grids
    ...

# On a 100x100 open grid, A* with Manhattan typically expands
# ~10x fewer nodes than Dijkstra for a corner-to-corner query.
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