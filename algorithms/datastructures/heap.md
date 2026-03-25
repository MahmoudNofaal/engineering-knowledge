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

**Basic heap operations using a PriorityQueue (C# 10+)**
```csharp
using System.Collections.Generic;

var heap = new PriorityQueue<int, int>();
heap.Enqueue(5, 5);
heap.Enqueue(2, 2);
heap.Enqueue(8, 8);

Console.WriteLine(heap.Peek());  // 2 — peek min, O(1)
int val = heap.Dequeue();        // 2 — remove min, O(log n)

// For older C# or max-heap, use SortedDictionary
var heapAlt = new SortedDictionary<int, List<int>>();
```

**Max-heap — negate values**
```csharp
using System.Collections.Generic;

var maxHeap = new PriorityQueue<int, int>();
var values = new[] { 5, 2, 8, 1, 9 };
foreach (var val in values)
    maxHeap.Enqueue(val, -val);  // store with negated priority for max-heap

int maxVal = maxHeap.Dequeue();  // retrieves with highest original value
Console.WriteLine(maxVal);       // 9
```

**Top-k largest elements — O(n log k)**
```csharp
public static List<int> TopK(List<int> items, int k)
{
    var heap = new PriorityQueue<int, int>();
    
    for (int i = 0; i < items.Count; i++)
    {
        if (i < k)
        {
            heap.Enqueue(items[i], items[i]);
        }
        else if (items[i] > heap.Peek())
        {
            heap.Dequeue();
            heap.Enqueue(items[i], items[i]);
        }
    }
    
    var result = new List<int>();
    while (heap.Count > 0)
        result.Add(heap.Dequeue());
    result.Sort((a, b) => b.CompareTo(a));
    return result;
}
```

**Merge k sorted lists — O(n log k)**
```csharp
public static List<int> MergeKSorted(List<List<int>> lists)
{
    var result = new List<int>();
    // heap stores (value, list_index, element_index)
    var heap = new PriorityQueue<(int val, int i, int j), int>();
    
    for (int i = 0; i < lists.Count; i++)
    {
        if (lists[i].Count > 0)
            heap.Enqueue((lists[i][0], i, 0), lists[i][0]);
    }
    
    while (heap.Count > 0)
    {
        var (val, i, j) = heap.Dequeue();
        result.Add(val);
        
        if (j + 1 < lists[i].Count)
        {
            int nextVal = lists[i][j + 1];
            heap.Enqueue((nextVal, i, j + 1), nextVal);
        }
    }
    return result;
}
```

**Running median with two heaps**
```csharp
public class MedianFinder
{
    private PriorityQueue<int, int> lo;   // max-heap (negated) — lower half
    private PriorityQueue<int, int> hi;   // min-heap — upper half

    public MedianFinder()
    {
        lo = new PriorityQueue<int, int>();
        hi = new PriorityQueue<int, int>();
    }

    public void Add(int num)
    {
        lo.Enqueue(num, -num);  // max-heap via negation
        
        // balance: lo top must be ≤ hi top
        if (lo.Count > 0 && hi.Count > 0 && (-lo.Peek()) > hi.Peek())
        {
            int maxLo = lo.Dequeue();
            int minHi = hi.Dequeue();
            lo.Enqueue(minHi, -minHi);
            hi.Enqueue(-maxLo, -maxLo);
        }
        
        if (lo.Count > hi.Count + 1)
        {
            int val = lo.Dequeue();
            hi.Enqueue(-val, -val);
        }
        if (hi.Count > lo.Count)
        {
            int val = hi.Dequeue();
            lo.Enqueue(-val, -val);
        }
    }

    public double Median()
    {
        if (lo.Count > hi.Count)
            return -lo.Peek();
        return (-lo.Peek() + hi.Peek()) / 2.0;
    }
}
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