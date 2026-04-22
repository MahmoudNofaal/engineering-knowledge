# Heap Sort

> A comparison-based sort that builds a max-heap from the array and repeatedly extracts the maximum — O(n log n) guaranteed, in-place, not stable.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Build max-heap in O(n); extract max n-1 times in O(n log n) |
| **Use when** | Guaranteed O(n log n) with O(1) extra space; introsort fallback |
| **Avoid when** | Stability required; cache performance critical (quicksort is faster in practice) |
| **C# version** | C# 1.0+; used internally by `Array.Sort` as introsort's fallback |
| **Namespace** | None — custom implementation |
| **Key types** | Array indices `int root`, `int heapSize` |

---

## When To Use It

Use heap sort when you need guaranteed O(n log n) worst-case with O(1) extra space and don't require stability. It's the right choice in memory-constrained environments where merge sort's O(n) buffer is unacceptable and quicksort's O(n²) worst case is unacceptable. In practice, C#'s `Array.Sort` (introsort) uses quicksort first and falls back to heapsort automatically when recursion depth exceeds 2 log n — you rarely implement heapsort directly.

---

## Core Concept

**Phase 1 — Build max-heap in O(n):** Start from the last non-leaf (index `n/2 - 1`) and sift each node down. This is O(n) — not O(n log n) — because lower nodes (which are more numerous) require fewer sift-down steps. The geometric series sums to O(n).

**Phase 2 — Extract max n-1 times:** Swap the root (max element) with the last element, shrink the heap by one, sift the new root down to restore the heap property. Repeat. After n-1 extractions, the array is sorted ascending.

---

## Algorithm History

| Year | Development |
|---|---|
| 1964 | J.W.J. Williams invents heapsort and defines the binary heap data structure |
| 1964 | Robert Floyd improves build-heap to O(n) |
| 1997 | David Musser's introsort uses heapsort as the O(n log n) fallback for quicksort |
| 2000s | Smoothsort (Leonardo heaps) and poplar sort developed as cache-friendlier variants |

---

## Performance

| Operation | Time | Space | Notes |
|---|---|---|---|
| Build heap | O(n) | O(1) | Bottom-up — not O(n log n) |
| Extract max (×n) | O(n log n) | O(1) | n × O(log n) sift-downs |
| Overall | O(n log n) | O(1) | Guaranteed — no worst case like quicksort |
| Stack depth | O(log n) | O(log n) | If sift-down is recursive |

**Allocation behaviour:** Zero heap (memory) allocation. All operations are in-place on the input array. The recursive sift-down uses O(log n) stack frames — convert to iterative to eliminate stack usage entirely.

**Benchmark notes:** Heapsort is typically 2–3× slower than quicksort in practice due to poor cache locality. Sift-down accesses parent → child at indices i → 2i+1, which are far apart in memory for large heaps. CPU prefetching can't help with these irregular access patterns.

---

## The Code

**Scenario 1 — full heap sort implementation**
```csharp
public static void HeapSort(int[] arr)
{
    int n = arr.Length;

    // Phase 1: build max-heap in O(n)
    // Start from last non-leaf: index n/2 - 1
    for (int i = n / 2 - 1; i >= 0; i--)
        SiftDown(arr, n, i);

    // Phase 2: extract max n-1 times
    for (int end = n - 1; end > 0; end--)
    {
        (arr[0], arr[end]) = (arr[end], arr[0]); // move max to sorted region
        SiftDown(arr, end, 0);                   // restore heap on reduced range
    }
}

private static void SiftDown(int[] arr, int heapSize, int root)
{
    while (true)
    {
        int largest = root;
        int left    = 2 * root + 1;
        int right   = 2 * root + 2;

        if (left  < heapSize && arr[left]  > arr[largest]) largest = left;
        if (right < heapSize && arr[right] > arr[largest]) largest = right;

        if (largest == root) break; // heap property satisfied

        (arr[root], arr[largest]) = (arr[largest], arr[root]);
        root = largest; // continue sifting down
    }
}
```

**Scenario 2 — verify build-heap is O(n), not O(n log n)**
```csharp
// Intuition for O(n) build-heap:
// Height of a node at level h from the bottom = h
// Number of nodes at level h ≈ n / 2^(h+1)
// Work per node at level h = O(h) sift-down steps
// Total work = Σ (n / 2^(h+1)) × h  for h = 0 to log n
//            = n × Σ h / 2^(h+1)
//            = n × 2  (geometric series)
//            = O(n)

// Demonstration: compare build-heap to n individual inserts
var rand = new Random(42);
int[] arr = Enumerable.Range(0, 1_000_000).Select(_ => rand.Next()).ToArray();

// Build-heap: O(n)
var heapCopy = arr.ToArray();
for (int i = heapCopy.Length / 2 - 1; i >= 0; i--)
    SiftDown(heapCopy, heapCopy.Length, i);

// n individual inserts (sift-up each): O(n log n)
// These produce equivalent max-heaps but build-heap is ~2× faster in practice
```

**Scenario 3 — heapsort for external partial sort (top-K from large file)**
```csharp
// When K << N: maintain a min-heap of size K.
// For each element: if > heap min, replace min and sift down.
// Result: K largest elements in O(n log K) time, O(K) space.
public static int[] TopKLargest(IEnumerable<int> stream, int k)
{
    // Use PriorityQueue as min-heap of size K
    var minHeap = new PriorityQueue<int, int>(k + 1);
    foreach (int val in stream)
    {
        minHeap.Enqueue(val, val);          // O(log k)
        if (minHeap.Count > k)
            minHeap.Dequeue();              // O(log k) — remove smallest
    }
    return minHeap.UnorderedItems.Select(x => x.Element).ToArray();
    // Total: O(n log k) — optimal for streaming top-K
}
```

**Scenario 4 — what NOT to do: off-by-one in build-heap**
```csharp
// BAD: starting from n/2 instead of n/2 - 1
// Misses the last non-leaf node — heap property not established for that subtree
public static void HeapSortBad(int[] arr)
{
    int n = arr.Length;
    for (int i = n / 2; i >= 0; i--) // BUG: should be n/2 - 1
        SiftDown(arr, n, i);          // i = n/2 is a leaf — wastes one call but still wrong for 0-based

    for (int end = n - 1; end > 0; end--)
    {
        (arr[0], arr[end]) = (arr[end], arr[0]);
        SiftDown(arr, end, 0);
    }
}
// GOOD: last non-leaf index is (n/2 - 1) for 0-based indexing.
// For n=8: last non-leaf = 8/2 - 1 = 3 (children: 7 and 8, but 8 is out of bounds — so 7)
// Starting at n/2 = 4 skips index 3 and processes a leaf — breaks the heap build.
```

---

## Real World Example

The `AlertEscalationService` in a site reliability platform processes incoming alerts and always escalates the highest-severity one first. The service uses the heap's extract-max semantics — O(log n) per escalation, O(n) to build from a batch of pending alerts. Unlike a sorted list (which must be rebuilt on each new alert), the heap handles dynamic insertions efficiently.

```csharp
public class AlertEscalationService
{
    public record Alert(Guid Id, int Severity, string Message, DateTimeOffset ReceivedAt);

    // Internal max-heap ordered by severity (negate for PriorityQueue min-heap)
    private readonly PriorityQueue<Alert, int> _heap = new();

    // O(n) — batch-load existing alerts using O(n) heapify
    public void LoadBatch(IEnumerable<Alert> alerts)
    {
        foreach (var alert in alerts)
            _heap.Enqueue(alert, -alert.Severity); // O(log n) per insert
        // Note: .NET PriorityQueue doesn't expose O(n) batch heapify directly.
        // For production, create with initial items in constructor where available.
    }

    // O(log n) — enqueue a new alert into the live heap
    public void Enqueue(Alert alert) => _heap.Enqueue(alert, -alert.Severity);

    // O(log n) — always get the highest-severity alert
    public Alert? EscalateNext()
    {
        if (_heap.Count == 0) return null;
        return _heap.Dequeue();
    }

    // O(1) — peek without removing
    public Alert? PeekNext() => _heap.Count > 0
        ? _heap.UnorderedItems.MinBy(x => x.Priority).Element
        : null;
}
```

*The key insight: build-heap from a batch is O(n) — building incrementally with n individual inserts would be O(n log n). For batches of existing alerts (e.g., loading from a database on service restart), the O(n) path is twice as fast at n=1M.*

---

## Common Misconceptions

**"Build-heap is O(n log n) because each sift-down is O(log n)"**
The O(n log n) upper bound is too loose. Most nodes are near the leaves and require very few sift-down steps. The exact sum is n × Σ(h/2^h) = O(n). This is one of the most commonly mis-stated complexity facts in interviews.

**"Heapsort is the best in-place O(n log n) sort"**
By complexity, yes. By real-world performance, no — quicksort and introsort are significantly faster in practice because of cache locality. Heapsort's sift-down accesses non-contiguous memory positions, causing cache misses. It's the right choice when worst-case guarantees matter and no extra space is available.

**"Heapsort is stable"**
No. The swap-to-end step in phase 2 can reorder equal elements. There is no known practical in-place stable sort with O(n log n) worst case.

---

## Gotchas

- **Last non-leaf is `n/2 - 1` for 0-based indexing.** Starting at `n/2` skips this node — the heap property isn't established for that subtree. This is the most common heapsort implementation bug.
- **Sift-down iteratively to eliminate O(log n) stack.** Recursive sift-down uses O(log n) call stack. An iterative version (track `root` with a while loop) is O(1) stack — pure in-place.
- **Sorted region grows from the right.** Elements are placed at `arr[end]` downward. The heap occupies `arr[0..end-1]` and shrinks by one per extraction.
- **For max-heap order, children must be ≤ parent.** Accidentally using `<` instead of `>` in the child comparison produces a min-heap — phase 2 would sort descending.

---

## Interview Angle

**What they're really testing:** Whether you can connect the heap data structure to the sort algorithm and whether you know the O(n) build-heap fact.

**Common question forms:** Implement heap sort. What sort gives O(n log n) guaranteed in-place? What is introsort?

**The depth signal:** A senior derives the O(n) build-heap cost via the geometric series argument (not just asserting it), explains why heapsort is slower than quicksort in practice (cache misses from sift-down's irregular access), and knows introsort uses heapsort as the O(n log n) fallback.

**Follow-up questions to expect:**
- "Why is build-heap O(n)?" → Most nodes are near the leaves with height O(1). The total work sums via geometric series to O(n).
- "Why is heapsort slower than quicksort despite equal Big-O?" → Cache locality. Quicksort accesses nearby elements; sift-down jumps from index i to 2i+1 — far apart in memory for large heaps.

---

## Related Topics

- [[algorithms/datastructures/heap.md]] — The data structure heapsort is built on.
- [[algorithms/sorting-algorithms/quick-sort.md]] — Faster in practice; introsort uses quicksort first, heapsort as fallback.
- [[algorithms/sorting-algorithms/merge-sort.md]] — Also O(n log n) guaranteed, stable, but O(n) space.
- [[algorithms/sorting-algorithms/sorting-in-practice.md]] — Where heapsort fits in real-world sorting (introsort).

---

## Source

https://en.wikipedia.org/wiki/Heapsort

---

*Last updated: 2026-04-21*