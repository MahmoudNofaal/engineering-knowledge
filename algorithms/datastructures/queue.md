# Queue

> A first-in, first-out (FIFO) data structure where elements are added at the back and removed from the front.

---

## Quick Reference

| | |
|---|---|
| **What it is** | FIFO container — enqueue back, dequeue front |
| **Use when** | Processing order must match arrival order |
| **Avoid when** | Priority ordering or arbitrary access needed |
| **C# version** | C# 2.0 (`Queue<T>`) |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `Queue<T>`, `PriorityQueue<T, TPriority>`, `Channel<T>` |

---

## When To Use It

Use a queue when processing order must match arrival order — BFS traversal, task scheduling, rate limiting, print spoolers, event streams. It's the right structure any time fairness or sequencing matters: the first request in must be the first one handled.

Avoid it when you need to jump to arbitrary elements (use a list), process by priority instead of arrival order (use a `PriorityQueue<T, TPriority>`), or need high-throughput producer-consumer pipelines (use `Channel<T>` from `System.Threading.Channels` — it's lock-free and built for async). A plain `Queue<T>` is fine for single-threaded BFS; it's not thread-safe for concurrent producers and consumers.

---

## Core Concept

A queue enforces strict ordering: the first element in is the first element out. Enqueue adds to the back; dequeue removes from the front. Both must be O(1) — which is the reason you should not simulate a queue using a `List<T>` with `RemoveAt(0)`. That remove shifts every remaining element left, making dequeue O(n).

`Queue<T>` in .NET is backed by a circular buffer — a fixed-size array with a head pointer and a tail pointer. Enqueue advances the tail; dequeue advances the head. When either pointer reaches the end of the array, it wraps around. This gives true O(1) on both ends with no element shifting. When the buffer fills, it resizes (doubles) and copies — O(n) occasionally, O(1) amortised.

BFS is the canonical use case. You need to process nodes layer by layer, and a queue naturally enforces that ordering: you enqueue all neighbours of a node before processing any of them, so the level-by-level guarantee holds automatically.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Non-generic `Queue` in `System.Collections` — stores `object` |
| C# 2.0 | .NET 2.0 | Generic `Queue<T>` — type-safe, circular buffer implementation |
| C# 5.0 | .NET 4.5 | `ConcurrentQueue<T>` — lock-free thread-safe queue for producer-consumer |
| C# 9.0 | .NET 5 | `PriorityQueue<TElement, TPriority>` added to BCL |
| C# 10.0 | .NET 6 | `Queue<T>` gains `TryDequeue` and `TryPeek` — safe non-throwing variants |

*Before `PriorityQueue<T, TPriority>` (.NET 6), priority queues required a third-party library or a hand-rolled heap. Before `Channel<T>`, async producer-consumer patterns were significantly harder to implement correctly.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Enqueue | O(1) amortised | Circular buffer advance; occasional O(n) resize |
| Dequeue | O(1) | Head pointer advance — no element shifting |
| Peek | O(1) | Reads front without removing |
| Contains | O(n) | Linear scan — no index structure |
| Iterate | O(n) | `foreach` visits front-to-back (FIFO order) |

**Allocation behaviour:** The internal circular buffer is a single `T[]` on the managed heap. Initial capacity is 4. Each resize doubles and copies — identical strategy to `List<T>`. For value types, elements are stored inline with no boxing.

**Benchmark notes:** `Queue<T>` and `Stack<T>` have nearly identical throughput for push/pop since both are array-backed. The practical difference only appears in access pattern: `Queue<T>` dequeue from the front costs O(1) via pointer arithmetic, while a `List<T>` doing `RemoveAt(0)` is O(n). At 10,000 elements that's a measurable difference; at 100,000 it's dramatic.

---

## The Code

**Basic enqueue, peek, dequeue**
```csharp
var queue = new Queue<int>();
queue.Enqueue(1);
queue.Enqueue(2);
queue.Enqueue(3);

int front = queue.Peek();      // 1 — look without removing, O(1)
int val   = queue.Dequeue();   // 1 — remove front, O(1)
Console.WriteLine(queue.Count); // 2

// Safe versions (.NET 6+)
if (queue.TryDequeue(out int result))
    Console.WriteLine(result);  // 2 — no exception on empty queue
```

**BFS — the definitive queue application**
```csharp
public static List<int> Bfs(Dictionary<int, List<int>> graph, int start)
{
    var visited = new HashSet<int> { start };
    var queue   = new Queue<int>();
    var order   = new List<int>();

    queue.Enqueue(start);
    while (queue.Count > 0)
    {
        int node = queue.Dequeue();
        order.Add(node);

        foreach (int neighbour in graph[node])
        {
            if (!visited.Contains(neighbour))
            {
                visited.Add(neighbour);     // mark on enqueue, not dequeue
                queue.Enqueue(neighbour);
            }
        }
    }
    return order;
}
```

**BFS shortest path — track distance per node**
```csharp
public static int ShortestPath(
    Dictionary<int, List<int>> graph, int start, int end)
{
    var visited = new HashSet<int> { start };
    var queue   = new Queue<(int node, int dist)>();
    queue.Enqueue((start, 0));

    while (queue.Count > 0)
    {
        var (node, dist) = queue.Dequeue();
        if (node == end) return dist;

        foreach (int neighbour in graph[node])
        {
            if (!visited.Contains(neighbour))
            {
                visited.Add(neighbour);
                queue.Enqueue((neighbour, dist + 1));
            }
        }
    }
    return -1;   // unreachable
}
```

**Level-order tree traversal — snapshot the level size**
```csharp
public static List<List<int>> LevelOrder(TreeNode root)
{
    if (root == null) return new List<List<int>>();

    var result = new List<List<int>>();
    var queue  = new Queue<TreeNode>();
    queue.Enqueue(root);

    while (queue.Count > 0)
    {
        int levelSize = queue.Count;   // snapshot before adding children
        var level = new List<int>();

        for (int i = 0; i < levelSize; i++)
        {
            TreeNode node = queue.Dequeue();
            level.Add(node.Val);
            if (node.Left  != null) queue.Enqueue(node.Left);
            if (node.Right != null) queue.Enqueue(node.Right);
        }
        result.Add(level);
    }
    return result;
}
```

**What NOT to do — and the fix**
```csharp
// BAD: using List<T> as a queue — O(n) dequeue due to element shifting
var fakeQueue = new List<int>();
fakeQueue.Add(1);
fakeQueue.Add(2);
int first = fakeQueue[0];
fakeQueue.RemoveAt(0);   // O(n) — every element shifts left

// GOOD: Queue<T> — O(1) dequeue via circular buffer
var realQueue = new Queue<int>();
realQueue.Enqueue(1);
realQueue.Enqueue(2);
int front = realQueue.Dequeue();   // O(1)
```

---

## Real World Example

A background job system processes customer-submitted export requests (PDF reports, CSV dumps) in the order they arrive. Requests must never starve: a request submitted first must be processed first, regardless of size. A `Channel<ExportRequest>` gives an async-friendly, bounded, backpressure-aware FIFO queue: the writer blocks when the channel is full, and the reader processes one item at a time in arrival order.

```csharp
using System.Threading.Channels;

public record ExportRequest(string UserId, string ReportType, DateTime SubmittedAt);

public class ExportJobQueue
{
    private readonly Channel<ExportRequest> _channel;
    private readonly ChannelWriter<ExportRequest> _writer;
    private readonly ChannelReader<ExportRequest> _reader;

    public ExportJobQueue(int capacity = 500)
    {
        _channel = Channel.CreateBounded<ExportRequest>(
            new BoundedChannelOptions(capacity)
            {
                FullMode            = BoundedChannelFullMode.Wait,  // backpressure
                SingleReader        = true,
                SingleWriter        = false   // multiple HTTP threads may enqueue
            });
        _writer = _channel.Writer;
        _reader = _channel.Reader;
    }

    // Called by HTTP handler — awaits if queue is at capacity
    public ValueTask SubmitAsync(ExportRequest request, CancellationToken ct)
        => _writer.WriteAsync(request, ct);

    // Called by the background worker loop
    public async Task ProcessAsync(
        Func<ExportRequest, CancellationToken, Task> handler,
        CancellationToken ct)
    {
        await foreach (ExportRequest request in _reader.ReadAllAsync(ct))
        {
            try   { await handler(request, ct); }
            catch (Exception ex)
            {
                // Log and continue — one bad job shouldn't stop the queue
                Console.Error.WriteLine($"Export failed for {request.UserId}: {ex.Message}");
            }
        }
    }

    public void Complete() => _writer.Complete();
}
```

*The key insight is that `Channel<T>` is a production-grade evolution of `Queue<T>`: it's async-first, bounded (backpressure included), and thread-safe — while a plain `Queue<T>` is none of those things out of the box.*

---

## Common Misconceptions

**"Any collection with Add and Remove can act as a queue"**
The performance contract matters. A `List<T>` with `Add` and `RemoveAt(0)` looks like a queue but dequeue is O(n). At scale — task schedulers handling thousands of jobs per second — this becomes the bottleneck. Only use structures that guarantee O(1) on both ends: `Queue<T>`, `LinkedList<T>`, or `Channel<T>`.

**"BFS finds the shortest path on any graph"**
BFS finds the shortest path only on **unweighted** graphs (or graphs where all edge weights are equal). Add weights and BFS gives wrong answers — you need Dijkstra's algorithm (a priority queue replacing the plain queue) or Bellman-Ford for negative weights.

**"Marking nodes visited on dequeue is fine"**
It's not. If you mark nodes visited when you dequeue them (rather than when you enqueue them), the same node can be enqueued multiple times before it's ever processed. In a dense graph this causes exponential redundant work. Always mark on enqueue.

---

## Gotchas

- **Always guard before dequeuing or peeking.** Both `Dequeue()` and `Peek()` throw `InvalidOperationException` on an empty queue. Use `queue.Count > 0`, or `TryDequeue` / `TryPeek` (.NET 6+) for the safe path.

- **Mark visited on enqueue, not on dequeue.** This is the most common BFS implementation bug. Marking on dequeue allows duplicate enqueues of the same node, bloating the queue and causing redundant processing — or an infinite loop if the graph is cyclic.

- **Level-order traversal requires snapshotting `queue.Count` before the inner loop.** If you don't capture the level size before adding children, you'll process children in the same iteration as their parents — mixing levels.

- **`Queue<T>` is not thread-safe.** For concurrent producer-consumer workloads, use `ConcurrentQueue<T>` or `Channel<T>`. `ConcurrentQueue<T>` is lock-free; `Channel<T>` adds async support and optional backpressure.

- **`PriorityQueue<T, TPriority>` is not a FIFO queue.** Elements are dequeued by priority, not by insertion order. When priorities tie, dequeue order is unspecified — it's not FIFO within the same priority level. If FIFO within priority is needed, use a composite key `(priority, insertionTimestamp)`.

---

## Interview Angle

**What they're really testing:** Whether you reach for BFS when the problem asks for shortest path or level-order traversal, and whether you implement it correctly — specifically, whether you mark visited on enqueue.

**Common question forms:**
- "Level-order traversal of a binary tree"
- "Shortest path in an unweighted grid"
- "Word ladder — minimum transformations"
- "Rotting oranges — BFS from multiple sources"
- "Number of islands" (can be BFS or DFS)

**The depth signal:** A junior uses BFS but marks nodes visited on dequeue, causing duplicate processing. A senior marks on enqueue, uses `Queue<T>` correctly, and can explain *why* BFS guarantees shortest path on unweighted graphs: it processes nodes in non-decreasing distance order, so the first time you reach a node is always via the shortest route. The follow-up signal is knowing that replacing `Queue<T>` with `PriorityQueue<T, TPriority>` turns BFS into Dijkstra's — the same skeleton, different container.

**Follow-up questions to expect:**
- "What if the graph is weighted?" (Dijkstra — swap queue for priority queue)
- "How do you do multi-source BFS?" (Enqueue all sources at distance 0 before the loop — the "rotting oranges" pattern)
- "How would you make this work with async I/O?" (`Channel<T>` with `ReadAllAsync` — the production queue pattern)

---

## Related Topics

- [[algorithms/datastructures/stack.md]] — The LIFO counterpart; BFS vs DFS is the queue vs stack comparison.
- [[algorithms/datastructures/monotonic-queue.md]] — A deque-based structure that maintains a sliding window min/max in O(1).
- [[algorithms/searching/breadth-first-search.md]] — BFS is the canonical queue algorithm; queue choice determines traversal order.
- [[algorithms/datastructures/heap.md]] — A priority queue replaces a plain queue when order is by priority, not arrival.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.queue-1

---

*Last updated: 2026-04-12*