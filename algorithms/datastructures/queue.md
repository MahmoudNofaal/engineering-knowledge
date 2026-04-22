# Queue

> A FIFO (First-In-First-Out) data structure that supports O(1) enqueue and dequeue — the foundation of BFS, task scheduling, and producer-consumer pipelines.

---

## Quick Reference

| | |
|---|---|
| **What it is** | FIFO collection — first enqueued is first dequeued |
| **Use when** | BFS, task scheduling, rate limiting, sliding window max (deque) |
| **Avoid when** | LIFO ordering needed (use Stack); random access needed (use List) |
| **C# version** | `Queue<T>` since C# 2.0; `Channel<T>` since .NET Core 3.0 |
| **Namespace** | `System.Collections.Generic`; `System.Threading.Channels` |
| **Key types** | `Queue<T>`, `PriorityQueue<T,P>`, `Channel<T>` |

---

## When To Use It

Use a queue for BFS (level-order traversal, shortest path on unweighted graphs), task scheduling (process in arrival order), and any pipeline where producers and consumers operate at different rates. The `PriorityQueue<T,P>` variant (added in .NET 6) is used for Dijkstra and A* — it dequeues the lowest-priority item. Use `Channel<T>` for async producer-consumer pipelines. Don't use a `List<T>` as a queue — `list.RemoveAt(0)` is O(n) and turns BFS into O(n²).

---

## Core Concept

A queue restricts insertion to one end (rear/enqueue) and removal to the other (front/dequeue). The FIFO property ensures requests are processed in arrival order — fair scheduling. C#'s `Queue<T>` is backed by a circular buffer (ring buffer): a fixed array with head and tail indices that wrap around. This gives O(1) amortised enqueue and dequeue without shifting elements.

`PriorityQueue<TElement, TPriority>` dequeues the element with the lowest priority value first (min-heap). Use it when "first" means "most urgent" rather than "oldest."

---

## Algorithm History

| Year | Development |
|---|---|
| 1960s | Operating systems use queues for process scheduling and I/O buffering |
| 1970s | BFS algorithm formalized — inherently queue-based |
| 2005 | C# 2.0 generic `Queue<T>` |
| 2019 | `Channel<T>` for async producer-consumer in .NET Core 3.0 |
| 2021 | `PriorityQueue<T,P>` added in .NET 6 — finally a standard min-heap |

---

## Performance

| Operation | Queue<T> | PriorityQueue<T,P> | Notes |
|---|---|---|---|
| Enqueue | O(1) amortised | O(log n) | PQ uses min-heap |
| Dequeue | O(1) | O(log n) | PQ pops min priority |
| Peek | O(1) | O(1) | |
| Count | O(1) | O(1) | |
| Contains | O(n) | O(n) | Linear scan |

**Allocation behaviour:** `Queue<T>` uses a circular buffer — one array, wraps around. Doubles on overflow. `PriorityQueue<T,P>` uses an array-based min-heap. Both are cache-friendly.

---

## The Code

**Scenario 1 — BFS shortest path**
```csharp
public int BfsShortestPath(Dictionary<int, List<int>> graph, int start, int end)
{
    var visited = new HashSet<int> { start };
    var queue   = new Queue<(int Node, int Dist)>();
    queue.Enqueue((start, 0));

    while (queue.Count > 0)
    {
        var (node, dist) = queue.Dequeue();
        if (node == end) return dist;
        foreach (int neighbour in graph[node])
            if (visited.Add(neighbour))          // Add returns false if already visited
                queue.Enqueue((neighbour, dist + 1));
    }
    return -1;
}
```

**Scenario 2 — PriorityQueue for Dijkstra**
```csharp
public Dictionary<int, int> Dijkstra(Dictionary<int, List<(int Weight, int Node)>> graph, int start)
{
    var dist = graph.Keys.ToDictionary(k => k, _ => int.MaxValue);
    dist[start] = 0;
    var pq = new PriorityQueue<int, int>(); // (node, distance as priority)
    pq.Enqueue(start, 0);

    while (pq.Count > 0)
    {
        pq.TryDequeue(out int node, out int d);
        if (d > dist[node]) continue; // stale entry
        foreach (var (weight, neighbour) in graph[node])
        {
            int newDist = d + weight;
            if (newDist < dist[neighbour])
            {
                dist[neighbour] = newDist;
                pq.Enqueue(neighbour, newDist);
            }
        }
    }
    return dist;
}
```

**Scenario 3 — sliding window maximum using deque**
```csharp
// LinkedList<int> used as a deque (double-ended queue) for sliding window max
public int[] SlidingWindowMax(int[] nums, int k)
{
    var result = new int[nums.Length - k + 1];
    var deque  = new LinkedList<int>(); // stores indices; front = max of current window

    for (int i = 0; i < nums.Length; i++)
    {
        // Remove indices outside the window from the front
        while (deque.Count > 0 && deque.First!.Value < i - k + 1)
            deque.RemoveFirst();

        // Remove indices with smaller values from the back (monotonic decreasing)
        while (deque.Count > 0 && nums[deque.Last!.Value] < nums[i])
            deque.RemoveLast();

        deque.AddLast(i);
        if (i >= k - 1) result[i - k + 1] = nums[deque.First!.Value];
    }
    return result;
}
```

**Scenario 4 — what NOT to do: List as queue**
```csharp
// BAD: List.RemoveAt(0) is O(n) — turns BFS into O(n²)
var queueBad = new List<int>();
queueBad.Add(1); queueBad.Add(2);
int frontBad = queueBad[0];
queueBad.RemoveAt(0); // O(n) — shifts every remaining element left

// GOOD: Queue<T> is O(1) dequeue via circular buffer
var queue = new Queue<int>();
queue.Enqueue(1); queue.Enqueue(2);
int front = queue.Dequeue(); // O(1)
```

---

## Real World Example

The `BackgroundJobQueue` in a web API accepts fire-and-forget tasks from request handlers and processes them on a background thread pool. Requests enqueue work items; workers dequeue and execute them. `Channel<T>` provides the async-safe, backpressure-aware version.

```csharp
public class BackgroundJobQueue
{
    private readonly Channel<Func<CancellationToken, Task>> _channel;

    public BackgroundJobQueue(int maxQueueSize = 100)
    {
        var options = new BoundedChannelOptions(maxQueueSize)
        {
            FullMode = BoundedChannelFullMode.Wait // backpressure: slow down producers
        };
        _channel = Channel.CreateBounded<Func<CancellationToken, Task>>(options);
    }

    // O(1) — enqueue a job from a request handler
    public async ValueTask EnqueueAsync(Func<CancellationToken, Task> job,
        CancellationToken ct = default)
        => await _channel.Writer.WriteAsync(job, ct);

    // O(1) per job — dequeue and execute; called by background worker
    public async Task ProcessAsync(CancellationToken ct)
    {
        await foreach (var job in _channel.Reader.ReadAllAsync(ct))
        {
            try   { await job(ct); }
            catch (Exception ex) { Console.Error.WriteLine($"Job failed: {ex.Message}"); }
        }
    }

    public void Complete() => _channel.Writer.Complete();
}
```

*The key insight: `BoundedChannelOptions` with `FullMode = Wait` provides natural backpressure — when the queue is full, producers slow down rather than allocating unboundedly. An unbounded queue under overload will consume all available memory.*

---

## Common Misconceptions

**"`Queue<T>` is slower than `List<T>` because of the circular buffer overhead"**
The opposite is true. `Queue<T>.Dequeue` is O(1); `List<T>.RemoveAt(0)` is O(n). For BFS on a graph with 1,000 nodes, `List.RemoveAt(0)` turns the O(V+E) BFS into O(V² + E). Always use `Queue<T>` for BFS.

**"`PriorityQueue<T,P>` in .NET dequeues the highest priority"**
No — it dequeues the element with the lowest priority value (min-heap). To simulate a max-heap, negate the priority: `pq.Enqueue(item, -priorityValue)`.

**"Channel<T> and Queue<T> are interchangeable"**
`Queue<T>` is synchronous and single-threaded. `Channel<T>` is async, thread-safe, and supports backpressure. Use `Queue<T>` for single-threaded BFS. Use `Channel<T>` for async producer-consumer pipelines.

---

## Gotchas

- **Never use `List<T>` as a queue.** `RemoveAt(0)` is O(n). At n=10,000 nodes in BFS, that's 50M extra operations.
- **Mark nodes visited when enqueued, not when dequeued.** If you mark on dequeue, the same node can be enqueued multiple times, causing duplicate processing and infinite loops in cyclic graphs.
- **`PriorityQueue` has no decrease-key operation.** Push a new `(item, newPriority)` and skip stale dequeued entries with a `dist > known[node]` guard.
- **`Queue<T>.Peek()` throws on empty.** Use `TryPeek` and `TryDequeue` for non-throwing variants (.NET Core 2.0+).

---

## Interview Angle

**What they're really testing:** Whether you use `Queue<T>` for BFS (not `List`), and whether you know `PriorityQueue` for weighted graph problems.

**Common question forms:** Level order tree traversal. Shortest path in unweighted graph. Rotting oranges. Task scheduler. Sliding window maximum.

**The depth signal:** A junior does BFS with a `List` and `RemoveAt(0)`. A senior uses `Queue<T>`, marks visited on enqueue, knows `PriorityQueue<T,P>` for Dijkstra, and uses `LinkedList` as a deque for sliding window max.

---

## Related Topics

- [[algorithms/searching/breadth-first-search.md]] — BFS is built entirely on Queue semantics.
- [[algorithms/datastructures/stack.md]] — The LIFO counterpart; DFS uses a stack where BFS uses a queue.
- [[algorithms/datastructures/heap.md]] — PriorityQueue is a heap; understanding heap operations explains the O(log n) complexity.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.queue-1

---

*Last updated: 2026-04-21*