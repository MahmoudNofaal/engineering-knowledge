---
id: "5.032"
studied_well: false
title: "PriorityQueue in .NET — Correct Usage and Patterns"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Heaps and Priority Queues"
tags: [dsa, algorithms, heap, priority-queue, dotnet, priorityqueue, csharp, interviews]
priority: 3
prerequisites:
  - "[[5.031 — Min-Heap and Max-Heap — Structure and Heapify]]"
related:
  - "[[5.033 — Top-K and K-th Element Problems]]"
  - "[[5.034 — Merge K Sorted Lists]]"
  - "[[5.035 — Median of a Data Stream — Two Heaps]]"
  - "[[5.041 — Dijkstra's Algorithm]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Analytics]] > **Group:** Heaps and Priority Queues
**Previous:** [[5.031 — Min-Heap and Max-Heap — Structure and Heapify]] | **Next:** [[5.033 — Top-K and K-th Element Problems]]

### Prerequisites
- [[5.031 — Min-Heap and Max-Heap — Structure and Heapify]] — PriorityQueue is a heap; understanding heap property, heapify, and heap operations is required.

### Where This Fits
`PriorityQueue<TElement, TPriority>` was introduced in .NET 6. It is a min-heap implementation that dequeues elements in order of increasing priority (smallest priority first). Its API separates the element from its priority (unlike Java's `PriorityQueue<E>` where the element is its own priority). This note covers the correct API usage, custom comparers for max-heap behavior, and the common patterns (Top-K, Dijkstra, median finding, task scheduling). The PriorityQueue replaces manual heap implementations in most production and interview scenarios.

---

## Core Mental Model

`PriorityQueue<TElement,TPriority>` is a binary min-heap: the element with the smallest priority value is always at the front. Dequeue removes it, and the next smallest rises to the top. The priority and the element are separate — you can enqueue the same element with different priorities (useful for Dijkstra's relaxation) or different elements with the same priority. To get a max-heap, provide a reverse comparer.

### Key Properties

|Operation|PriorityQueue<TElement,TPriority>|Manual heap|
|---|---|---|
|Enqueue|O(log n)|O(log n)|
|Dequeue|O(log n)|O(log n)|
|Peek|O(1)|O(1)|
|Count|O(1)|O(1)|
|EnqueueDequeue (atomic)|O(log n) amortized|Not available|

### How It Works

The `PriorityQueue` stores elements in an array-backed binary heap. Enqueue adds to the end and bubbles up. Dequeue removes the root and sinks down the last element. The priority determines order through a `IComparer<TPriority>` (default: `Comparer<TPriority>.Default`).

### API Usage

```csharp
// Min-heap (default — smallest priority dequeued first)
var pq = new PriorityQueue<string, int>();
pq.Enqueue("low", 3);
pq.Enqueue("high", 1);
pq.Enqueue("medium", 2);

string next = pq.Dequeue();  // "high" (priority 1)
string peek = pq.Peek();     // "medium" (priority 2)

// Max-heap — reverse comparer
var maxPq = new PriorityQueue<string, int>(
    Comparer<int>.Create((a, b) => b.CompareTo(a))
);
maxPq.Enqueue("low", 1);
maxPq.Enqueue("high", 10);
maxPq.Enqueue("medium", 5);
string top = maxPq.Dequeue();  // "high" (priority 10)

// EnqueueDequeue — atomic insert + remove
string result = pq.EnqueueDequeue("new", 0);
// Inserts "new" with priority 0, then removes and returns the smallest
// More efficient than separate Enqueue + Dequeue

// Dequeue + Peek in one call
(bool found, string element, int priority) = pq.TryPeek();
(bool removed, string element, int priority) = pq.TryDequeue();

// Remove all
while (pq.Count > 0)
{
    var (element, priority) = (pq.Peek(), ...);
    // Process
    pq.Dequeue();
}

// Remove all with Dequeue (destructive)
var items = new List<string>();
while (pq.TryDequeue(out string? el, out _))
    items.Add(el);
```

### Classic Problem Patterns

- **Top-K largest (LeetCode 215)** — Min-heap of size K; EnqueueDequeue keeps the heap at exactly K elements.
- **Merge K sorted lists (LeetCode 23)** — Enqueue the head of each list; dequeue min, enqueue the next from that list.
- **Median of data stream (LeetCode 295)** — Two heaps: max-heap for lower half, min-heap for upper half.
- **Dijkstra's algorithm** — Enqueue (node, distance); dequeue the closest unvisited node.
- **Task scheduler (LeetCode 621)** — Max-heap of remaining task counts; dequeue and process, re-enqueue after cooldown.

### Template

```csharp
// Top-K Template using PriorityQueue
// When to use: find K largest/smallest elements in a stream
// Time: O(n log K) | Space: O(K)

public int[] TopK(int[] nums, int k)
{
    // Min-heap for K largest
    var pq = new PriorityQueue<int, int>();

    foreach (var num in nums)
    {
        pq.Enqueue(num, num);
        if (pq.Count > k)
            pq.Dequeue();  // Remove smallest, keep K largest
    }

    var result = new int[k];
    int i = 0;
    while (pq.Count > 0)
        result[i++] = pq.Dequeue();
    return result;
}
```

### Gotchas

- **Separate element and priority types** — Enqueue takes (element, priority). They can be different types.
- **Same priority** — FIFO is NOT guaranteed for equal-priority elements.
- **Empty queue** — Dequeue and Peek throw `InvalidOperationException`. Use `TryDequeue` / `TryPeek`.
- **Custom comparer** — Pass `Comparer<T>.Create(...)` for max-heap. The comparer is on `TPriority`, not `TElement`.
- **No Remove(T)** — Cannot remove arbitrary elements. For lazy deletion, track a separate set of "removed" items.
- **No UpdatePriority** — Cannot decrease a key. Dijkstra's must enqueue duplicates and check visited.

