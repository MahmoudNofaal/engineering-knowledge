# Heap
> A complete binary tree satisfying the heap property: every parent is smaller (min-heap) or larger (max-heap) than its children.

---

## When To Use It
Use a heap when you repeatedly need the minimum or maximum element from a changing dataset. Classic use cases: priority queues, scheduling, Dijkstra's algorithm, top-k problems, median maintenance. Avoid it when you need arbitrary lookup or sorted iteration — a heap only gives you fast access to the root.

---

## Core Concept
A heap is stored as an array, not a linked structure. For node at index i: left child is at 2i+1, right child is at 2i+2, parent is at (i-1)//2. This math means you never need pointers. The heap property is maintained through two operations: sift-up (after insert — bubble the new element up until the property holds) and sift-down (after removing root — put the last element at the root and push it down). Both are O(log n). Python's `heapq` is a min-heap only — negate values to simulate a max-heap.

---

## The Code

**Basic heap operations with heapq**
```python
import heapq

heap = []
heapq.heappush(heap, 5)
heapq.heappush(heap, 2)
heapq.heappush(heap, 8)

print(heap[0])            # 2 — peek min, O(1)
val = heapq.heappop(heap) # 2 — remove min, O(log n)

# Build a heap from an existing list — O(n), faster than n pushes
items = [5, 2, 8, 1, 9]
heapq.heapify(items)
```

**Max-heap — negate values**
```python
import heapq

max_heap = []
for val in [5, 2, 8, 1, 9]:
    heapq.heappush(max_heap, -val)  # store negated

max_val = -heapq.heappop(max_heap)  # negate on retrieval
print(max_val)  # 9
```

**Top-k largest elements — O(n log k)**
```python
import heapq

def top_k(items: list, k: int) -> list:
    # maintain a min-heap of size k
    heap = items[:k]
    heapq.heapify(heap)
    for val in items[k:]:
        if val > heap[0]:           # current val beats the smallest in top-k
            heapq.heapreplace(heap, val)  # pop min, push val — O(log k)
    return sorted(heap, reverse=True)
```

**Merge k sorted lists — O(n log k)**
```python
import heapq

def merge_k_sorted(lists: list[list]) -> list:
    result = []
    # heap stores (value, list_index, element_index)
    heap = [(lst[0], i, 0) for i, lst in enumerate(lists) if lst]
    heapq.heapify(heap)
    while heap:
        val, i, j = heapq.heappop(heap)
        result.append(val)
        if j + 1 < len(lists[i]):
            heapq.heappush(heap, (lists[i][j + 1], i, j + 1))
    return result
```

**Running median with two heaps**
```python
import heapq

class MedianFinder:
    def __init__(self):
        self.lo = []   # max-heap (negated) — lower half
        self.hi = []   # min-heap — upper half

    def add(self, num: int) -> None:
        heapq.heappush(self.lo, -num)
        # balance: lo top must be ≤ hi top
        heapq.heappush(self.hi, -heapq.heappop(self.lo))
        if len(self.hi) > len(self.lo):
            heapq.heappush(self.lo, -heapq.heappop(self.hi))

    def median(self) -> float:
        if len(self.lo) > len(self.hi):
            return -self.lo[0]
        return (-self.lo[0] + self.hi[0]) / 2
```

---

## Gotchas

- **`heapq` is a min-heap only.** Negate values for max-heap behavior. For tuples, negate only the priority key: `(-priority, value)`.
- **`heapify` is O(n), not O(n log n).** Building a heap from an existing list uses a bottom-up algorithm that's proven to be O(n). This is faster than pushing n elements one at a time.
- **Heap elements must be comparable.** If you push tuples, Python compares them lexicographically. If the first elements tie, it compares the second. Push `(priority, counter, item)` where counter is a tiebreaker to avoid comparing non-comparable items.
- **A heap does not support arbitrary element removal in O(log n).** You can't efficiently delete an element that isn't the root. The workaround is lazy deletion: mark it as invalid and skip it when it surfaces.
- **Heap is not sorted.** `heap[1]` is not the second smallest. The heap property only guarantees the root is the minimum — not that the rest of the array is in any particular order.

---

## Interview Angle

**What they're really testing:** Whether you recognize "top-k" and "streaming min/max" as heap problems, and whether you know the two-heap trick for median.

**Common question form:** Kth largest element, merge k sorted lists, find median from data stream, task scheduler, Dijkstra's shortest path.

**The depth signal:** A junior sorts and slices for top-k problems — O(n log n). A senior uses a size-k min-heap for O(n log k), which is strictly better when k ≪ n. The two-heap median pattern and lazy deletion for arbitrary removal are the signals that separate strong candidates from exceptional ones.

---

## Related Topics

- [[algorithms/balanced-bst.md]] — Also gives O(log n) insert/delete, but supports range queries that a heap cannot.
- [[algorithms/graph.md]] — Dijkstra's algorithm uses a min-heap as its priority queue.
- [[algorithms/queue.md]] — A heap implements a priority queue — same interface, ordered by priority instead of arrival.

---

## Source

https://docs.python.org/3/library/heapq.html

---

*Last updated: 2026-03-24*