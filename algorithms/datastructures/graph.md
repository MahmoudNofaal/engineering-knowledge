# Graph
> A collection of nodes (vertices) connected by edges, used to model relationships, paths, and networks.

---

## When To Use It
Use a graph when entities have relationships that aren't strictly hierarchical. Social networks, maps, dependency resolution, web crawling, circuit design — all graphs. If your data has cycles or many-to-many connections, it's a graph, not a tree. Choose the representation (adjacency list vs matrix) based on whether the graph is sparse or dense.

---

## Core Concept
A graph is defined by vertices V and edges E. Edges are directed (one-way) or undirected (two-way), and weighted or unweighted. Most interview graphs are sparse — few edges relative to nodes — so the standard representation is an adjacency list: a dict mapping each node to its list of neighbors. An adjacency matrix uses O(V²) space and is only worth it for dense graphs or when you need O(1) edge existence checks.

The two fundamental traversals — BFS and DFS — solve completely different problems. BFS finds shortest paths on unweighted graphs. DFS detects cycles, finds connected components, and does topological sort. Know which one to reach for and why.

---

## The Code

**Graph representations**
```python
# Adjacency list — standard for sparse graphs
graph = {
    0: [1, 2],
    1: [0, 3],
    2: [0],
    3: [1]
}

# Adjacency matrix — O(V²) space, O(1) edge check
n = 4
matrix = [[0] * n for _ in range(n)]
matrix[0][1] = 1   # edge from 0 to 1
matrix[1][0] = 1   # undirected
```

**DFS — recursive and iterative**
```python
def dfs_recursive(graph: dict, node: int, visited: set) -> None:
    visited.add(node)
    for neighbor in graph[node]:
        if neighbor not in visited:
            dfs_recursive(graph, neighbor, visited)

def dfs_iterative(graph: dict, start: int) -> list:
    visited, stack, order = set(), [start], []
    while stack:
        node = stack.pop()
        if node not in visited:
            visited.add(node)
            order.append(node)
            stack.extend(graph[node])
    return order
```

**BFS — shortest path on unweighted graph**
```python
from collections import deque

def bfs(graph: dict, start: int, end: int) -> int:
    queue = deque([(start, 0)])
    visited = set([start])
    while queue:
        node, dist = queue.popleft()
        if node == end:
            return dist
        for neighbor in graph[node]:
            if neighbor not in visited:
                visited.add(neighbor)
                queue.append((neighbor, dist + 1))
    return -1
```

**Cycle detection — directed graph**
```python
def has_cycle(graph: dict) -> bool:
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {node: WHITE for node in graph}

    def dfs(node: int) -> bool:
        color[node] = GRAY          # in current DFS path
        for neighbor in graph[node]:
            if color[neighbor] == GRAY:
                return True         # back edge = cycle
            if color[neighbor] == WHITE and dfs(neighbor):
                return True
        color[node] = BLACK         # fully explored
        return False

    return any(dfs(n) for n in graph if color[n] == WHITE)
```

**Topological sort — Kahn's algorithm (BFS-based)**
```python
from collections import deque, defaultdict

def topo_sort(n: int, edges: list) -> list:
    graph = defaultdict(list)
    in_degree = [0] * n
    for u, v in edges:
        graph[u].append(v)
        in_degree[v] += 1
    queue = deque(i for i in range(n) if in_degree[i] == 0)
    order = []
    while queue:
        node = queue.popleft()
        order.append(node)
        for neighbor in graph[node]:
            in_degree[neighbor] -= 1
            if in_degree[neighbor] == 0:
                queue.append(neighbor)
    return order if len(order) == n else []  # empty = cycle exists
```

---

## Gotchas

- **Always track visited nodes.** Without it, DFS/BFS on a cyclic graph runs forever. Use a set, not a list — membership check is O(1) vs O(n).
- **Mark visited on enqueue for BFS, not on dequeue.** Marking on dequeue lets the same node be enqueued multiple times, bloating the queue and causing duplicate processing.
- **Topological sort is only defined for DAGs.** If a cycle exists, Kahn's algorithm returns a partial order (fewer than n nodes). Check the length of the result to detect cycles.
- **Disconnected graphs need an outer loop.** A single DFS/BFS from one start node won't visit all components. Wrap in `for node in graph: if node not in visited: dfs(node)`.
- **Grid problems are implicit graphs.** A 2D grid is a graph where each cell is a node and neighbors are up/down/left/right. You don't need to build the adjacency list — just compute neighbors on the fly.

---

## Interview Angle

**What they're really testing:** Whether you can model an abstract problem as a graph and apply the right traversal.

**Common question form:** Number of islands, course schedule (cycle detection + topo sort), word ladder (BFS), clone a graph, shortest path in a grid.

**The depth signal:** A junior applies BFS or DFS correctly. A senior chooses *which* traversal based on the problem property — BFS for shortest path, DFS for cycle detection or topo sort — and explains why. They also know Dijkstra for weighted shortest paths, recognize grid problems as implicit graphs without needing an explicit adjacency list, and know that Kahn's algorithm doubles as cycle detection for directed graphs.

---

## Related Topics

- [[algorithms/queue.md]] — BFS is implemented with a queue; understanding deque is essential.
- [[algorithms/stack.md]] — DFS is naturally stack-based, either via recursion or an explicit stack.
- [[algorithms/heap.md]] — Dijkstra's algorithm replaces the BFS queue with a min-heap.
- [[algorithms/tree.md]] — A tree is a connected, acyclic, undirected graph — a special case.

---

## Source

https://en.wikipedia.org/wiki/Graph_(abstract_data_type)

---

*Last updated: 2026-03-24*