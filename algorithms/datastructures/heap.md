# Heap

> A complete binary tree satisfying the heap property: every parent is smaller (min-heap) or larger (max-heap) than its children.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Array-backed priority queue via heap property |
| **Use when** | Repeated min/max from a changing dataset |
| **Avoid when** | Arbitrary lookup, sorted iteration, or range queries |
| **C# version** | C# 10 / .NET 6 (`PriorityQueue<T, TPriority>`) |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `PriorityQueue<TElement, TPriority>` |

---

## When To Use It

Use a heap when you repeatedly need the minimum or maximum element from a changing dataset. Classic use cases: priority queues, Dijkstra's algorithm, top-k problems, task scheduling, median maintenance. The defining property is O(log n) insert and O(log n) remove-min/max — better than O(n) linear scan, and unlike a sorted array you don't pay O(n) to insert.

Avoid it when you need arbitrary lookup (a heap only gives you fast access to the root), sorted iteration (use a `SortedSet<T>` or sort at the end), or range queries (use a segment tree or BST). Also avoid `PriorityQueue<T, TPriority>` when you need to update a priority — .NET's implementation has no `DecreaseKey` operation. The workaround is lazy deletion: enqueue a new entry with the updated priority and ignore stale entries when they surface.

---

## Core Concept

A heap is stored as an array, not a linked structure. For a node at index `i`: left child at `2i + 1`, right child at `2i + 2`, parent at `(i - 1) / 2`. This arithmetic means you never need pointers — the tree is implicit in the array layout.

The heap property is maintained by two operations:

**Sift-up (after insert):** Place the new element at the end of the array, then repeatedly swap it with its parent while it violates the heap property. At most O(log n) swaps.

**Sift-down (after extract-min):** Swap the root with the last element, reduce size by one, then push the new root down by swapping with its smaller child until the property holds. Also O(log n).

Building a heap from n unsorted elements via the "heapify" algorithm is O(n) — not O(n log n). The proof is non-obvious: most nodes are near the bottom and barely need to sift down. This is why initialising a `PriorityQueue` from an existing collection is significantly faster than inserting elements one by one.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | No BCL heap — developers used sorted collections or third-party libs |
| C# 2.0 | .NET 2.0 | `SortedDictionary<K,V>` available — used as a makeshift priority queue |
| C# 6.0 | .NET 4.6 | Still no native heap; NuGet `System.Collections.Specialized` filled the gap |
| C# 10.0 | .NET 6 | `PriorityQueue<TElement, TPriority>` added to BCL — min-heap semantics |
| C# 12.0 | .NET 8 | `PriorityQueue` gains `EnqueueDequeue` and `EnqueueRange` for batch operations |

*Before .NET 6, C# developers either used `SortedSet<T>` (which doesn't allow duplicates), rolled their own heap, or brought in a NuGet package. The absence of a built-in priority queue was a long-standing gap.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Enqueue | O(log n) | Sift-up — at most log n swaps |
| Dequeue (min) | O(log n) | Sift-down — at most log n swaps |
| Peek (min) | O(1) | Root is always at index 0 |
| Build from collection | O(n) | Heapify — not O(n log n) |
| Arbitrary element access | O(n) | No index structure — must scan |
| Remove arbitrary element | O(n) | Find it (O(n)) then sift (O(log n)) |

**Allocation behaviour:** The internal array is a single heap-allocated `(TElement, TPriority)[]`. Resizing doubles the array — same strategy as `List<T>`. For small heaps the entire array typically stays in CPU cache, making constant factors small in practice.

**Benchmark notes:** For the top-k problem, a size-k min-heap over n elements runs in O(n log k) — strictly better than O(n log n) sort when k ≪ n. At k = 1,000 and n = 1,000,000, that's roughly 10× fewer comparisons than sorting.

---

## The Code

**Basic min-heap operations**
```csharp
var heap = new PriorityQueue<string, int>();
heap.Enqueue("low",    10);
heap.Enqueue("urgent", 1);
heap.Enqueue("medium", 5);

string top = heap.Peek();             // "urgent" — O(1), doesn't remove
string val = heap.Dequeue();          // "urgent" — O(log n)
Console.WriteLine(heap.Count);        // 2
```

**Max-heap — negate the priority**
```csharp
// PriorityQueue is min-heap only; negate to simulate max-heap
var maxHeap = new PriorityQueue<int, int>();
int[] nums = { 3, 1, 9, 2, 7 };
foreach (int n in nums)
    maxHeap.Enqueue(n, -n);           // store with negated priority

int largest = maxHeap.Dequeue();      // 9
```

**Top-k largest elements — O(n log k)**
```csharp
public static List<int> TopKLargest(int[] nums, int k)
{
    // Keep a size-k MIN-heap. If a new element exceeds the heap's min, swap it in.
    var heap = new PriorityQueue<int, int>();

    foreach (int n in nums)
    {
        heap.Enqueue(n, n);
        if (heap.Count > k)
            heap.Dequeue();           // evict the smallest so far
    }

    var result = new List<int>();
    while (heap.Count > 0)
        result.Add(heap.Dequeue());
    result.Reverse();
    return result;
}
// TopKLargest([3,1,9,2,7,4,8], 3) → [7, 8, 9]
```

**Merge k sorted arrays — O(n log k)**
```csharp
public static List<int> MergeKSorted(List<int[]> arrays)
{
    var result = new List<int>();
    // heap stores (value, arrayIndex, elementIndex)
    var heap = new PriorityQueue<(int val, int i, int j), int>();

    for (int i = 0; i < arrays.Count; i++)
        if (arrays[i].Length > 0)
            heap.Enqueue((arrays[i][0], i, 0), arrays[i][0]);

    while (heap.Count > 0)
    {
        var (val, i, j) = heap.Dequeue();
        result.Add(val);
        if (j + 1 < arrays[i].Length)
        {
            int next = arrays[i][j + 1];
            heap.Enqueue((next, i, j + 1), next);
        }
    }
    return result;
}
```

**What NOT to do — and the fix**
```csharp
// BAD: sorting to find the top-k — O(n log n), ignores that k ≪ n
public static List<int> TopKBad(int[] nums, int k)
{
    return nums.OrderByDescending(x => x).Take(k).ToList();
}

// GOOD: size-k heap — O(n log k), far faster when k is small
public static List<int> TopKGood(int[] nums, int k)
    => TopKLargest(nums, k);   // see above — O(n log k)
```

---

## Real World Example

A distributed task scheduler assigns jobs to workers. Jobs arrive continuously with varying priorities (SLA tier: critical, high, standard). Workers poll for the next job. The scheduler must always hand out the highest-priority job available, even as new high-priority jobs arrive mid-queue. A `PriorityQueue` handles this naturally — enqueue on arrival, dequeue gives the highest-priority item regardless of insertion order.

```csharp
public enum JobPriority { Critical = 0, High = 1, Standard = 2 }

public record Job(string Id, string Description, JobPriority Priority, DateTime CreatedAt);

public class TaskScheduler
{
    // Min-heap on (priority level, createdAt) — lower number = higher urgency
    private readonly PriorityQueue<Job, (int priority, DateTime created)> _queue = new();
    private readonly object _lock = new();

    public void Enqueue(Job job)
    {
        lock (_lock)
        {
            // Primary: priority level. Secondary: FIFO within same priority.
            _queue.Enqueue(job, ((int)job.Priority, job.CreatedAt));
        }
    }

    public bool TryDequeue(out Job? job)
    {
        lock (_lock)
        {
            if (_queue.Count == 0) { job = null; return false; }
            job = _queue.Dequeue();
            return true;
        }
    }

    public Job? Peek()
    {
        lock (_lock)
        {
            return _queue.TryPeek(out var job, out _) ? job : null;
        }
    }

    public int Pending => _queue.Count;
}
```

*The key insight is the composite priority key `(int priority, DateTime created)`: tuples compare lexicographically in C#, so jobs sort by priority level first, and within the same priority they sort by creation time — giving FIFO behaviour within each tier at no extra cost.*

---

## Common Misconceptions

**"`PriorityQueue` in C# is a max-heap"**
It's a min-heap. The element with the *lowest* priority value is dequeued first. To get max-heap behaviour, negate the priority value when enqueueing: `heap.Enqueue(item, -priority)`.

**"Building a heap from n elements is O(n log n)"**
It's O(n). The "heapify" algorithm (bottom-up construction) runs in linear time because most nodes are near the leaves and require very few sift-down comparisons. Inserting n elements one-by-one *is* O(n log n). Use `PriorityQueue<T,P>.EnqueueRange` or construct from a collection when you have all elements upfront.

**"A heap is sorted — heap[1] is the second smallest"**
A heap is partially ordered, not fully sorted. The root is guaranteed to be the minimum. Everything else is only constrained relative to its parent. `heap[1]` in the internal array is one of the root's children — the smaller of the two — but not necessarily the second-smallest element overall.

---

## Gotchas

- **`PriorityQueue<T, TPriority>` has no `DecreaseKey` operation.** You can't update the priority of an element already in the queue. The standard workaround is **lazy deletion**: enqueue a new entry with the updated priority, and when you dequeue the old entry, check if it's stale and skip it. Dijkstra's implementations in C# commonly use this pattern.

- **`PriorityQueue` allows duplicate priorities; dequeue order within the same priority is unspecified.** It's not FIFO within a priority level unless you include a sequence number or timestamp in the priority key (as shown in the Real World Example above).

- **The two-heap median trick is a classic that gets missed.** Maintaining a running median requires two heaps — a max-heap for the lower half and a min-heap for the upper half — kept within 1 element of each other in size. The median is then the max of the lower half (or average of both tops for even count). This pattern appears in the "Find Median from Data Stream" problem.

- **Heapify is O(n) but `EnqueueRange` may not use it.** Check the .NET docs for the version you're on — early .NET 6 shipped `EnqueueRange` as repeated O(log n) inserts. Later versions may optimise. When performance matters, profile rather than assume.

- **`SortedSet<T>` is not a heap substitute.** It gives O(log n) insert and O(log n) min/max, but it doesn't allow duplicates and its memory overhead per node is higher. Use it when you need sorted iteration or range queries alongside min/max; use `PriorityQueue` when you only need the priority queue operations.

---

## Interview Angle

**What they're really testing:** Whether you recognise "repeated min/max from a changing collection" as a heap problem, and whether you know the two-heap median trick and the top-k optimisation.

**Common question forms:**
- "Kth largest element in an array"
- "Merge k sorted lists"
- "Find median from a data stream"
- "Task scheduler / minimum number of CPUs"
- "Dijkstra's shortest path"

**The depth signal:** A junior sorts and slices for top-k — O(n log n). A senior uses a size-k min-heap for O(n log k) and explains why: you only need to track k candidates, not sort everything. The two-heap median pattern and lazy deletion for `DecreaseKey` are the signals that separate strong candidates from exceptional ones.

**Follow-up questions to expect:**
- "What if k is close to n?" (Sorting becomes competitive; the crossover depends on constants)
- "How would you update a priority?" (Lazy deletion — mark stale, enqueue new, skip stale on dequeue)
- "What's the difference between a heap and a BST for this problem?" (Heap: O(1) min, O(log n) insert/extract, no range queries; BST: O(log n) min with range support)

---

## Related Topics

- [[algorithms/datastructures/balanced-bst.md]] — Also O(log n) insert/delete but supports range queries that a heap cannot.
- [[algorithms/datastructures/graph.md]] — Dijkstra's algorithm uses a min-heap as its priority queue.
- [[algorithms/datastructures/queue.md]] — A heap implements a priority queue — same interface, ordered by priority instead of arrival.
- [[algorithms/datastructures/segment-tree.md]] — For range min/max queries on a mutable array — complements the heap's per-element priority model.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.priorityqueue-2

---

*Last updated: 2026-04-12*