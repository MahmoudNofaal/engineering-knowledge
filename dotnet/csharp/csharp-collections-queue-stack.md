# C# Collections — Queue\<T\> and Stack\<T\>

> Queue gives you FIFO (first-in, first-out) access; Stack gives you LIFO (last-in, first-out). Both are O(1) for their primary operations and enforce a specific access discipline.

---

## Quick Reference

| | `Queue<T>` | `Stack<T>` |
|---|---|---|
| **Order** | FIFO | LIFO |
| **Add** | `Enqueue` | `Push` |
| **Remove** | `Dequeue` | `Pop` |
| **Peek** | `Peek` | `Peek` |
| **Safe variant** | `TryDequeue` | `TryPop` |
| **Backing store** | Circular buffer | Array |
| **Use for** | BFS, task queues | DFS, undo/redo, call simulation |

---

## When To Use It

Use `Queue<T>` when processing order must match arrival order — task schedulers, BFS traversal, message buffers. Use `Stack<T>` when you need LIFO — expression parsing, call-stack simulation, DFS traversal, undo/redo history.

Don't use either when you need arbitrary index access — that's `List<T>`.

---

## Core Concept

Both enforce a single access discipline at one end (or both ends for Queue). You're trading indexing flexibility for guaranteed ordering semantics. Internally, `Stack<T>` is an array (like `List<T>`) and `Queue<T>` is a circular buffer — both are O(1) amortised for their core operations.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 2.0 | .NET 2.0 | Generic `Queue<T>` and `Stack<T>` introduced |
| .NET 6 | — | `PriorityQueue<TElement, TPriority>` added |

---

## The Code

**Queue\<T\> — basic usage and BFS**
```csharp
var queue = new Queue<string>();
queue.Enqueue("first");
queue.Enqueue("second");
queue.Enqueue("third");

Console.WriteLine(queue.Peek());    // "first" — looks without removing
Console.WriteLine(queue.Dequeue()); // "first" — removes and returns
Console.WriteLine(queue.Count);     // 2

// Safe dequeue — prefer in code where empty is possible
if (queue.TryDequeue(out var item))
    Console.WriteLine($"Processing: {item}");

// BFS skeleton
void Bfs(TreeNode root)
{
    var queue = new Queue<TreeNode>();
    queue.Enqueue(root);
    while (queue.Count > 0)
    {
        var current = queue.Dequeue();
        Console.WriteLine(current.Value);
        foreach (var child in current.Children)
            queue.Enqueue(child);
    }
}
```

**Stack\<T\> — basic usage and undo/redo**
```csharp
var stack = new Stack<int>();
stack.Push(1); stack.Push(2); stack.Push(3);

Console.WriteLine(stack.Peek()); // 3 — top, not removed
Console.WriteLine(stack.Pop());  // 3 — removes and returns
Console.WriteLine(stack.Count);  // 2

// Undo/redo pattern
var undoStack = new Stack<string>();
var redoStack = new Stack<string>();

void DoAction(string action) { undoStack.Push(action); redoStack.Clear(); }
void Undo() { if (undoStack.TryPop(out var a)) redoStack.Push(a); }
void Redo() { if (redoStack.TryPop(out var a)) undoStack.Push(a); }

// Bracket matching — classic Stack use case
bool IsBalanced(string expr)
{
    var stack = new Stack<char>();
    foreach (char c in expr)
    {
        if (c is '(' or '[' or '{') stack.Push(c);
        else if (c is ')' or ']' or '}')
        {
            if (stack.Count == 0) return false;
            var top = stack.Pop();
            if ((c == ')' && top != '(') || (c == ']' && top != '[') || (c == '}' && top != '{'))
                return false;
        }
    }
    return stack.Count == 0;
}
```

**PriorityQueue\<TElement, TPriority\> (NET 6+)**
```csharp
// Min-heap by default — lowest priority value dequeues first
var pq = new PriorityQueue<string, int>();
pq.Enqueue("low",    3);
pq.Enqueue("high",   1);
pq.Enqueue("medium", 2);

while (pq.TryDequeue(out var item, out int priority))
    Console.WriteLine($"{priority}: {item}"); // 1: high, 2: medium, 3: low
```

---

## Real World Example

A job processor uses `Queue<T>` for fair FIFO scheduling plus a priority queue for urgent jobs.

```csharp
public class JobScheduler
{
    private readonly PriorityQueue<Job, int> _urgent = new();  // priority = urgency
    private readonly Queue<Job> _normal = new();

    public void Enqueue(Job job)
    {
        if (job.IsUrgent) _urgent.Enqueue(job, job.Priority);
        else              _normal.Enqueue(job);
    }

    public Job? Dequeue()
    {
        // Urgent jobs first, then normal FIFO
        if (_urgent.TryDequeue(out var urgent, out _)) return urgent;
        return _normal.TryDequeue(out var normal) ? normal : null;
    }
}
```

---

## Gotchas

- **`Dequeue()` and `Pop()` throw `InvalidOperationException` on empty.** Always check `Count > 0` or use the `Try*` variants.
- **Neither is thread-safe.** Use `ConcurrentQueue<T>` / `ConcurrentStack<T>` for multi-threaded access.
- **`Stack<T>` iterates top-to-bottom** in `foreach` — not insertion order. Surprises people who assume FIFO enumeration.
- **`PriorityQueue` doesn't support updating priorities.** To change a priority, remove-and-reinsert is not supported; maintain an external validity map if needed.

---

## Interview Angle

**What they're really testing:** Whether you understand access patterns and algorithmic constraints — not just API familiarity.

**Common question forms:**
- "Implement browser back/forward navigation"
- "Check if brackets are balanced"
- "Process tasks in arrival order"

**The depth signal:** A senior reaches for `ConcurrentQueue<T>` unprompted for producer/consumer, or `Channel<T>` for async pipelines, and knows `Stack<T>` enumeration goes top-to-bottom.

---

## Related Topics

- [[dotnet/csharp/csharp-concurrent-collections.md]] — Thread-safe `ConcurrentQueue<T>` and `ConcurrentStack<T>`
- [[dotnet/csharp/csharp-channels.md]] — `Channel<T>` for async producer/consumer pipelines

---

## Source

[Queue\<T\> — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.queue-1)

---
*Last updated: 2026-04-06*