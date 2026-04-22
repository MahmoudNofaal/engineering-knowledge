# Heap

> A complete binary tree stored as an array, where every parent is smaller (min-heap) or larger (max-heap) than its children — providing O(log n) insert/delete and O(1) min/max access.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Array-backed complete binary tree with heap ordering property |
| **Use when** | Top-K elements, Dijkstra/A*, task scheduling by priority, streaming median |
| **Avoid when** | Need arbitrary element access; need sorted iteration (use sorted list) |
| **C# version** | `PriorityQueue<T,P>` since .NET 6 (C# 10); manual before that |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `PriorityQueue<TElement, TPriority>` |

---

## When To Use It

Use a heap when you repeatedly need the minimum or maximum element from a dynamic collection — adding items and extracting the min/max over time. Classic use cases: Dijkstra's algorithm (always settle the nearest node), merge k sorted lists (always take the smallest head), top-K most frequent elements, and streaming median (two heaps). Don't use a heap for sorted iteration — extracting all n elements is O(n log n), the same as sorting. Use `SortedSet<T>` if you need both sorted order and O(log n) operations.

---

## Core Concept

A heap is stored as a flat array. For element at index i: left child at `2i+1`, right child at `2i+2`, parent at `(i-1)/2`. This compact representation avoids pointer overhead and is cache-friendly. The **heap property**: every node is ≤ (min-heap) or ≥ (max-heap) its children. This ensures the root is always the minimum or maximum.

**Insert (push):** append to the end of the array, then sift up — repeatedly swap with parent until the heap property is restored. O(log n).
**Extract-min (pop):** swap root with last element, remove last, sift the new root down — swap with the smaller child until the property is restored. O(log n).
**Build heap from n elements:** start from the last non-leaf (`n/2 - 1`) and sift down each. O(n) total (not O(n log n)) — the geometric series argument.

---

## Algorithm History

| Year | Development |
|---|---|
| 1964 | J.W.J. Williams invents heapsort and defines the heap data structure |
| 1964 | Robert Floyd introduces O(n) heapify (build-heap) |
| 1984 | Fibonacci heap introduced by Fredman and Tarjan — O(1) amortised insert |
| 2021 | .NET 6 ships `PriorityQueue<TElement, TPriority>` — first standard heap in C# |

*Before .NET 6, C# had no built-in priority queue. Production code used NuGet packages or manual implementations.*

---

## Performance

| Operation | Time | Notes |
|---|---|---|
| Peek (min/max) | O(1) | Root is always min/max |
| Enqueue (insert) | O(log n) | Sift up |
| Dequeue (extract min) | O(log n) | Sift down |
| Build heap from array | O(n) | Bottom-up heapify |
| Heapsort | O(n log n) | n × O(log n) extractions |
| Decrease-key | O(log n) | Not supported in PriorityQueue — push duplicate |

**Allocation behaviour:** Single array of capacity n. No per-element allocation. `PriorityQueue<T,P>` stores `(element, priority)` pairs as value tuples in the internal array — zero heap allocation per enqueue.

**Benchmark notes:** A binary heap is typically 2–3× faster than a sorted set (`SortedSet<T>`) for priority queue workloads because of better cache behaviour (array vs tree nodes). Fibonacci heap has better theoretical complexity but is rarely faster in practice due to high constant factors.

---

## The Code

**Scenario 1 — top-K smallest elements**
```csharp
// Use a MAX-heap of size K. If new element < heap max, replace max.
// Result: the K smallest elements remain in the heap.
public int[] TopKSmallest(int[] nums, int k)
{
    // PriorityQueue is a min-heap. Negate priority for max-heap behaviour.
    var maxHeap = new PriorityQueue<int, int>(k + 1);
    foreach (int num in nums)
    {
        maxHeap.Enqueue(num, -num); // negative priority = max-heap
        if (maxHeap.Count > k)
            maxHeap.Dequeue();      // remove the largest in the heap
    }
    return maxHeap.UnorderedItems.Select(x => x.Element).ToArray();
}
```

**Scenario 2 — merge K sorted lists**
```csharp
public ListNode? MergeKLists(ListNode?[] lists)
{
    // Seed the heap with the head of each list
    var pq = new PriorityQueue<ListNode, int>();
    foreach (var head in lists)
        if (head != null) pq.Enqueue(head, head.Val);

    var dummy = new ListNode(0);
    var curr  = dummy;
    while (pq.Count > 0)
    {
        var node = pq.Dequeue();    // O(log k)
        curr.Next = node;
        curr = curr.Next;
        if (node.Next != null)
            pq.Enqueue(node.Next, node.Next.Val);
    }
    return dummy.Next;
}
// Time: O(n log k) — n total nodes, log k per heap operation
```

**Scenario 3 — streaming median (two heaps)**
```csharp
public class MedianFinder
{
    // maxHeap: lower half — peek gives the largest of the lower half
    private readonly PriorityQueue<int, int> _maxHeap = new();
    // minHeap: upper half — peek gives the smallest of the upper half
    private readonly PriorityQueue<int, int> _minHeap = new();

    public void AddNum(int num)
    {
        _maxHeap.Enqueue(num, -num); // negate for max-heap
        // Balance: max of lower half must not exceed min of upper half
        int maxLower = -_maxHeap.UnorderedItems.First().Priority;
        int? minUpper = _minHeap.Count > 0 ? _minHeap.Peek() : (int?)null;

        if (minUpper.HasValue && maxLower > minUpper.Value)
        {
            _minHeap.Enqueue(_maxHeap.Dequeue(), _maxHeap.Count > 0 ? 0 : int.MaxValue);
            // Simplified: move max of lower to upper
        }
        // Keep sizes balanced (maxHeap can have at most 1 extra)
        if (_maxHeap.Count > _minHeap.Count + 1)
            _minHeap.Enqueue(_maxHeap.Dequeue(), _minHeap.Count);
        else if (_minHeap.Count > _maxHeap.Count)
            _maxHeap.Enqueue(_minHeap.Dequeue(), -_minHeap.Count);
    }

    public double FindMedian() => _maxHeap.Count == _minHeap.Count
        ? (_maxHeap.UnorderedItems.First().Element + _minHeap.Peek()) / 2.0
        : _maxHeap.UnorderedItems.First().Element;
}
```

**Scenario 4 — what NOT to do: sorting for repeated min extractions**
```csharp
// BAD: O(n log n) upfront + O(n) per extraction = O(n²) for k extractions
public int[] ExtractKMinBad(int[] nums, int k)
{
    Array.Sort(nums);                  // O(n log n) — sorts everything even if k << n
    return nums[..k];
}

// GOOD: O(n) build heap + O(k log n) for k extractions = O(n + k log n)
public int[] ExtractKMinGood(int[] nums, int k)
{
    var pq = new PriorityQueue<int, int>();
    foreach (int n in nums) pq.Enqueue(n, n); // O(n log n) — or use O(n) heapify
    var result = new int[k];
    for (int i = 0; i < k; i++) result[i] = pq.Dequeue(); // O(k log n)
    return result;
    // For k << n, O(n + k log n) << O(n log n)
}
```

---

## Real World Example

The `AlertPriorityService` in a monitoring platform processes incoming alerts and always handles the most critical one first. Alerts arrive continuously; the service dequeues by severity. Without a heap, finding the highest-severity unhandled alert would require scanning all pending alerts each time — O(n) per extraction. With a max-heap (min-heap with negated severity), extraction is O(log n).

```csharp
public class AlertPriorityService
{
    public record Alert(Guid Id, string Message, int Severity, DateTimeOffset ReceivedAt);

    // Max-heap by severity (negate for PriorityQueue min-heap semantics)
    private readonly PriorityQueue<Alert, int> _queue = new();
    private readonly HashSet<Guid> _cancelled = new();

    public void Enqueue(Alert alert)
        => _queue.Enqueue(alert, -alert.Severity); // O(log n)

    public void Cancel(Guid alertId)
        => _cancelled.Add(alertId); // lazy deletion — O(1)

    // Returns the highest-severity active alert
    public Alert? DequeueNext()
    {
        while (_queue.Count > 0)
        {
            var alert = _queue.Dequeue(); // O(log n)
            if (!_cancelled.Remove(alert.Id)) // Remove returns true if found
                return alert;
            // Was cancelled — discard and try next
        }
        return null;
    }
}
```

*The key insight: lazy deletion (mark as cancelled in a HashSet, skip on dequeue) avoids the O(n) cost of finding and removing an element from the middle of the heap. This is the standard workaround for the missing decrease-key/remove operation in `PriorityQueue`.*

---

## Common Misconceptions

**"`PriorityQueue<T,P>` dequeues the highest priority"**
No — it dequeues the element with the **lowest** priority value (min-heap). To simulate a max-heap, negate the priority: `pq.Enqueue(item, -priorityValue)`.

**"Heap sort is O(n log n) so it's as fast as merge sort"**
Same asymptotic complexity but heap sort has worse cache performance because sift-down accesses non-contiguous memory (parent to child jumps are `i → 2i+1`). Merge sort accesses memory sequentially. In practice, heap sort is 2–3× slower than merge sort on modern hardware.

**"Building a heap from n elements is O(n log n)"**
No — O(n). Bottom-up heapify starts from the last non-leaf and sifts down. Most elements are near the leaves and require very few sift-down steps. The total work is bounded by the geometric series sum, giving O(n).

---

## Gotchas

- **`PriorityQueue` has no decrease-key.** To update a priority, push a new entry and use lazy deletion to skip the stale one when it's dequeued.
- **`UnorderedItems` returns items in heap order, not sorted order.** Don't assume any order from `UnorderedItems` — it's a raw view of the internal array.
- **For max-heap, negate the priority.** C#'s `PriorityQueue` is always a min-heap. There is no built-in max-heap.
- **`n/2 - 1` is the last non-leaf index for 0-based arrays.** This is the starting point for O(n) build-heap.

---

## Interview Angle

**What they're really testing:** Whether you reach for a heap for top-K and streaming problems, and whether you know the O(n) build-heap fact.

**Common question forms:** Top K frequent elements. Kth largest element in stream. Merge K sorted lists. Find median from data stream. Task scheduler.

**The depth signal:** A junior sorts everything. A senior uses a heap, knows O(n) heapify vs O(n log n) sort, and implements the two-heap streaming median. They also know the lazy deletion pattern for `PriorityQueue`.

---

## Related Topics

- [[algorithms/sorting-algorithms/heap-sort.md]] — Heapsort uses the heap's extract-max to sort in-place.
- [[algorithms/searching/dijkstra.md]] — Dijkstra requires a min-heap (PriorityQueue) for correct O((V+E) log V) complexity.
- [[algorithms/datastructures/tree.md]] — A heap is a specialised tree stored as an array.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.priorityqueue-2

---

*Last updated: 2026-04-21*