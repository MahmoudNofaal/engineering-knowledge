# C# Collections — Queue & Stack

> Queue and Stack are in-memory, ordered collections that enforce a specific access pattern: Queue gives you FIFO (first-in, first-out), Stack gives you LIFO (last-in, first-out).

---

## When To Use It

Use `Queue<T>` when order of processing must match order of arrival — task schedulers, message buffers, BFS traversal. Use `Stack<T>` when you need to reverse or undo — expression parsing, call-stack simulation, DFS traversal, undo/redo history. Don't use either when you need arbitrary access by index; that's what `List<T>` is for. Don't use the non-generic `Queue` or `Stack` (from `System.Collections`) in new code — they're untyped and pre-generics legacy.

---

## Core Concept

Both are wrappers around a linear sequence, but they only let you touch one end (or both ends in the case of Queue). Stack is like a pile of plates — you add to the top, take from the top. Queue is like a line at a bank — you join at the back, leave from the front. The key insight: neither gives you random access. You're trading flexibility for guaranteed ordering semantics. Internally, `Stack<T>` is backed by an array (like `List<T>`), and `Queue<T>` uses a circular buffer — so both are O(1) amortized for their core operations.

---

## The Code

### Queue<T> — basic usage
```csharp
var queue = new Queue<string>();

queue.Enqueue("first");
queue.Enqueue("second");
queue.Enqueue("third");

Console.WriteLine(queue.Peek());    // "first" — looks without removing
Console.WriteLine(queue.Dequeue()); // "first" — removes and returns
Console.WriteLine(queue.Count);     // 2
```

### Queue<T> — safe dequeue with TryDequeue
```csharp
// Prefer TryDequeue in concurrent-ish code or when empty queue is possible
if (queue.TryDequeue(out var item))
{
    Console.WriteLine($"Processing: {item}");
}
else
{
    Console.WriteLine("Queue was empty — nothing to process");
}
```

### Stack<T> — basic usage
```csharp
var stack = new Stack<int>();

stack.Push(1);
stack.Push(2);
stack.Push(3);

Console.WriteLine(stack.Peek()); // 3 — top of stack, not removed
Console.WriteLine(stack.Pop());  // 3 — removes and returns
Console.WriteLine(stack.Count);  // 2
```

### Stack<T> — undo/redo pattern
```csharp
var undoStack = new Stack<string>();
var redoStack = new Stack<string>();

void DoAction(string action)
{
    undoStack.Push(action);
    redoStack.Clear(); // new action invalidates redo history
}

void Undo()
{
    if (undoStack.TryPop(out var last))
        redoStack.Push(last);
}

void Redo()
{
    if (redoStack.TryPop(out var action))
        undoStack.Push(action);
}
```

### Queue<T> — BFS skeleton
```csharp
void Bfs(Node root)
{
    var queue = new Queue<Node>();
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

---

## Gotchas

- **`Dequeue()` and `Pop()` throw on empty** — `InvalidOperationException`. Always check `Count > 0` or use the `Try*` variants (`TryDequeue`, `TryPop`) to avoid this in production code.
- **Neither is thread-safe** — `Queue<T>` and `Stack<T>` will corrupt silently under concurrent access. Use `ConcurrentQueue<T>` or `ConcurrentStack<T>` from `System.Collections.Concurrent` if multiple threads are involved.
- **`Stack<T>` is backed by an array** — iterating it with `foreach` goes from top to bottom (LIFO order), not insertion order. This surprises people who assume it iterates the same way items were pushed.
- **`Queue<T>` uses a circular buffer internally** — resizing happens when capacity is exceeded, which means occasional O(n) cost. Pre-size with `new Queue<T>(capacity)` if you know the upper bound.
- **No index access** — you can't do `queue[2]`. If you're tempted to, you want a `List<T>` or `LinkedList<T>`, not a Queue or Stack.

---

## Interview Angle

**What they're really testing:** Whether you understand access patterns and algorithmic constraints — not just API familiarity.

**Common question form:** "Implement a browser history (back/forward)," "process tasks in order," or "check if a string of brackets is balanced."

**The depth signal:** A junior reaches for Stack or Queue because the problem says LIFO/FIFO. A senior explains *why* the access pattern maps to that structure — and knows when to swap in `ConcurrentQueue<T>` for producer-consumer scenarios, or `Channel<T>` (from `System.Threading.Channels`) when async throughput is needed. The senior also knows that `Stack<T>` iteration order surprises people and can explain why (array backing, index walks from top).

---

## Related Topics

- [[algorithms/bfs-dfs.md]] — Queue drives BFS; Stack (or the call stack) drives DFS. Understanding why is foundational.
- [[dotnet/csharp-collections-list-linkedlist.md]] — Covers the index-accessible counterparts; helps clarify when NOT to use Queue/Stack.
- [[dotnet/concurrency-concurrent-collections.md]] — `ConcurrentQueue<T>` and `ConcurrentStack<T>` are the thread-safe versions; required reading before using these in async code.
- [[dotnet/channels.md]] — `System.Threading.Channels` is the modern replacement for queue-based producer-consumer pipelines in async .NET.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.queue-1](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.queue-1)

---
*Last updated: 2026-03-23*