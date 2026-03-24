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
```python
from collections import deque

def bfs(graph: dict, start: int, end: int) -> int:
    visited = {start}
    queue = deque([(start, 0)])           # (node, distance)
    while queue:
        node, dist = queue.popleft()
        if node == end:
            return dist
        for neighbor in graph[node]:
            if neighbor not in visited:
                visited.add(neighbor)     # mark on enqueue, not dequeue
                queue.append((neighbor, dist + 1))
    return -1                             # unreachable
```

**BFS level order — process nodes layer by layer**
```python
from collections import deque

def level_order(graph: dict, start: int) -> list[list]:
    visited = {start}
    queue = deque([start])
    levels = []
    while queue:
        level_size = len(queue)           # snapshot: how many nodes are in this level
        level = []
        for _ in range(level_size):
            node = queue.popleft()
            level.append(node)
            for neighbor in graph[node]:
                if neighbor not in visited:
                    visited.add(neighbor)
                    queue.append(neighbor)
        levels.append(level)
    return levels
```

**BFS on a 2D grid — shortest path**
```python
from collections import deque

def shortest_path_grid(grid: list, start: tuple, end: tuple) -> int:
    rows, cols = len(grid), len(grid[0])
    visited = {start}
    queue = deque([(start[0], start[1], 0)])
    while queue:
        r, c, dist = queue.popleft()
        if (r, c) == end:
            return dist
        for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < rows and 0 <= nc < cols \
               and grid[nr][nc] != '#' \
               and (nr, nc) not in visited:
                visited.add((nr, nc))
                queue.append((nr, nc, dist + 1))
    return -1
```

**Multi-source BFS — start from multiple sources simultaneously**
```python
from collections import deque

def walls_and_gates(rooms: list) -> None:
    # Fill each empty room with distance to nearest gate (0).
    # Gates are 0, walls are -1, empty rooms are INF.
    INF = float('inf')
    rows, cols = len(rooms), len(rooms[0])
    queue = deque()
    for r in range(rows):
        for c in range(cols):
            if rooms[r][c] == 0:
                queue.append((r, c))          # seed all gates at once

    while queue:
        r, c = queue.popleft()
        for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < rows and 0 <= nc < cols and rooms[nr][nc] == INF:
                rooms[nr][nc] = rooms[r][c] + 1
                queue.append((nr, nc))
```

**Word ladder — BFS on an implicit graph**
```python
from collections import deque

def word_ladder(begin: str, end: str, word_list: set) -> int:
    if end not in word_list:
        return 0
    queue = deque([(begin, 1)])
    visited = {begin}
    while queue:
        word, steps = queue.popleft()
        for i in range(len(word)):
            for c in 'abcdefghijklmnopqrstuvwxyz':
                candidate = word[:i] + c + word[i+1:]
                if candidate == end:
                    return steps + 1
                if candidate in word_list and candidate not in visited:
                    visited.add(candidate)
                    queue.append((candidate, steps + 1))
    return 0
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