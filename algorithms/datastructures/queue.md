# Queue
> A first-in, first-out (FIFO) data structure where elements are added at the back and removed from the front.

---

## When To Use It
Use a queue when processing order must match arrival order — BFS traversal, task scheduling, rate limiting, event streams. It's the right structure any time fairness or sequencing matters. Avoid it when you need to jump to arbitrary elements or process by priority — use a heap instead.

---

## Core Concept
A queue enforces strict ordering: the first element in is the first element out. Enqueue adds to the back; dequeue removes from the front. Both must be O(1) — which is why you should never use a plain Python list as a queue. `list.pop(0)` is O(n) because every element shifts left. The correct structure is `collections.deque`, which is a doubly-linked list under the hood and gives true O(1) on both ends. BFS is the canonical use case — you process nodes layer by layer, and a queue naturally enforces that ordering.

---

## The Code

**Correct queue usage with deque**
```python
from collections import deque

queue = deque()
queue.append(1)      # enqueue — O(1)
queue.append(2)
queue.append(3)

front = queue[0]     # peek — O(1)
val = queue.popleft() # dequeue — O(1), NOT queue.pop(0)
```

**BFS — the definitive queue application**
```python
from collections import deque

def bfs(graph: dict, start: int) -> list:
    visited = set([start])
    queue = deque([start])
    order = []
    while queue:
        node = queue.popleft()
        order.append(node)
        for neighbor in graph[node]:
            if neighbor not in visited:
                visited.add(neighbor)
                queue.append(neighbor)
    return order
```

**BFS shortest path — track distance per layer**
```python
from collections import deque

def shortest_path(graph: dict, start: int, end: int) -> int:
    visited = set([start])
    queue = deque([(start, 0)])  # (node, distance)
    while queue:
        node, dist = queue.popleft()
        if node == end:
            return dist
        for neighbor in graph[node]:
            if neighbor not in visited:
                visited.add(neighbor)
                queue.append((neighbor, dist + 1))
    return -1  # unreachable
```

**Sliding window maximum using a monotonic deque**
```python
from collections import deque

def max_sliding_window(items: list, k: int) -> list:
    dq = deque()  # stores indices, front is always the max
    result = []
    for i, val in enumerate(items):
        # remove indices outside the window
        while dq and dq[0] < i - k + 1:
            dq.popleft()
        # remove indices whose values are smaller than current
        while dq and items[dq[-1]] < val:
            dq.pop()
        dq.append(i)
        if i >= k - 1:
            result.append(items[dq[0]])
    return result
```

---

## Gotchas

- **Never use `list.pop(0)` as dequeue.** It's O(n). At scale this turns an O(n) BFS into O(n²). Always use `collections.deque` and `popleft()`.
- **BFS finds the shortest path only on unweighted graphs.** Add weights and BFS gives wrong answers. Use Dijkstra's algorithm instead.
- **Mark nodes visited when enqueuing, not when dequeuing.** If you mark on dequeue, the same node can be enqueued multiple times before it's processed, causing redundant work or infinite loops.
- **A deque can be used as both a stack and a queue.** Don't mix the two in the same algorithm — it defeats the purpose of both data structures and makes the code unreadable.
- **Priority queues are not queues.** `heapq` in Python is often called a priority queue, but it processes by priority, not by arrival order. Don't conflate the two.

---

## Interview Angle

**What they're really testing:** Whether you reach for BFS when the problem asks for shortest path or level-order traversal — and whether you implement it correctly.

**Common question form:** Level-order tree traversal, shortest path in a grid/graph, rotting oranges, word ladder.

**The depth signal:** A junior uses BFS but marks nodes visited on dequeue, causing duplicate processing. A senior marks on enqueue, uses a deque correctly, and can explain *why* BFS guarantees shortest path on unweighted graphs: it processes nodes in non-decreasing distance order, so the first time you reach a node is always via the shortest route.

---

## Related Topics

- [[algorithms/stack.md]] — The LIFO counterpart; BFS vs DFS is the queue vs stack comparison.
- [[algorithms/graph.md]] — BFS is one of two fundamental graph traversal strategies.
- [[algorithms/heap.md]] — A priority queue replaces a regular queue when order is by priority, not arrival.

---

## Source

https://docs.python.org/3/library/collections.html#collections.deque

---

*Last updated: 2026-03-24*