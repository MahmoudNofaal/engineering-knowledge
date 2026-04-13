# Deque (Double-Ended Queue)

> A sequential data structure that supports O(1) insertion and removal from both the front and the back.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Double-ended queue — O(1) on both ends |
| **Use when** | Need front AND back access; sliding window; palindrome check |
| **Avoid when** | Only one end needed (use Stack or Queue) |
| **C# version** | C# 2.0 (`LinkedList<T>`); no dedicated `Deque<T>` in BCL |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `LinkedList<T>` (O(1) both ends), custom circular buffer |

---

## When To Use It

Use a deque when you need O(1) access — read, insert, or remove — on both the front and the back simultaneously. Typical cases: implementing a monotonic queue (sliding window max/min), building an LRU cache eviction list, breadth-first search where you need to add high-priority nodes to the front (0-1 BFS), palindrome checking (compare from both ends inward), and task-stealing schedulers (workers steal from the back of each other's deque while processing from their own front).

Avoid it when you only need one end — a `Stack<T>` or `Queue<T>` is simpler and communicates intent more clearly. Don't use `LinkedList<T>` as a general-purpose list — its random-access penalty (O(n)) makes it a poor `List<T>` substitute. Its strength is exclusively the O(1) both-ends property.

---

## Core Concept

A deque generalises both a stack and a queue. A stack exposes only one end (LIFO). A queue exposes one end for writing and the other for reading (FIFO). A deque exposes both ends for both reading and writing — four operations total: push-front, push-back, pop-front, pop-back.

Two implementation strategies:

**Doubly linked list:** Each node holds a value plus `prev` and `next` pointers. Push/pop on either end rewires two pointers — genuinely O(1). Node allocation per element means GC pressure at high throughput.

**Circular buffer:** A fixed-size array with `head` and `tail` indices that wrap around. Push/pop are index arithmetic — O(1) with no allocation. Resize requires copying. This is what most production deques (C++ `std::deque`, Python's `collections.deque`) use internally.

C# provides no `Deque<T>` in the BCL. `LinkedList<T>` is the standard substitute for O(1) both-ends access. For performance-sensitive paths, implement a circular buffer deque manually (under 50 lines).

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | No deque — `Queue` and `Stack` are single-ended only |
| C# 2.0 | .NET 2.0 | `LinkedList<T>` introduced — O(1) both ends via `AddFirst`/`AddLast`/`RemoveFirst`/`RemoveLast` |
| C# 5.0 | .NET 4.5 | `ConcurrentQueue<T>` — thread-safe but FIFO only, not a deque |
| C# 10.0 | .NET 6 | No `Deque<T>` added; community requests ongoing |

*As of .NET 8, there is still no `Deque<T>` in the BCL. This is a long-standing gap. The `System.Collections.Generic.Deque<T>` class exists in third-party libraries (e.g. `Nito.Collections.Deque`) and is the recommended alternative for production code that needs a true circular-buffer deque.*

---

## Performance

| Operation | LinkedList<T> | Circular Buffer |
|---|---|---|
| Push front | O(1) | O(1) amortised |
| Push back | O(1) | O(1) amortised |
| Pop front | O(1) | O(1) |
| Pop back | O(1) | O(1) |
| Peek front / back | O(1) | O(1) |
| Index access | O(n) | O(1) |
| Memory per element | ~40 bytes (node + pointers) | ~element size (packed array) |

**Allocation behaviour:** `LinkedList<T>` allocates one `LinkedListNode<T>` heap object per element — high GC pressure at scale. A circular buffer deque allocates one array and resizes by doubling — same strategy as `List<T>`, much lower GC pressure.

**Benchmark notes:** For the monotonic queue pattern (sliding window max/min), `LinkedList<T>` is sufficient for interview code and moderate throughput. Above ~500,000 operations per second in a hot path, the node-per-element allocation becomes measurable. Profile before switching to a custom circular buffer, but be aware the option exists.

---

## The Code

**Deque using LinkedList<T> — the standard C# idiom**
```csharp
var dq = new LinkedList<int>();

// Push
dq.AddFirst(1);     // push front — O(1)
dq.AddLast(2);      // push back  — O(1)
dq.AddFirst(0);     // push front — [0, 1, 2]

// Peek
int front = dq.First!.Value;   // 0 — O(1)
int back  = dq.Last!.Value;    // 2 — O(1)

// Pop
dq.RemoveFirst();   // pop front — O(1), dq = [1, 2]
dq.RemoveLast();    // pop back  — O(1), dq = [1]

Console.WriteLine(dq.Count);   // 1
```

**Circular buffer deque — O(1) amortised, zero per-element allocation**
```csharp
public class Deque<T>
{
    private T[] _buf;
    private int _head, _tail, _count;

    public Deque(int capacity = 8)
    {
        _buf  = new T[capacity];
        _head = 0; _tail = 0; _count = 0;
    }

    public int Count => _count;

    private void Grow()
    {
        var next = new T[_buf.Length * 2];
        for (int i = 0; i < _count; i++)
            next[i] = _buf[(_head + i) % _buf.Length];
        _head = 0; _tail = _count; _buf = next;
    }

    public void PushBack(T item)
    {
        if (_count == _buf.Length) Grow();
        _buf[_tail] = item;
        _tail = (_tail + 1) % _buf.Length;
        _count++;
    }

    public void PushFront(T item)
    {
        if (_count == _buf.Length) Grow();
        _head = (_head - 1 + _buf.Length) % _buf.Length;
        _buf[_head] = item;
        _count++;
    }

    public T PopBack()
    {
        if (_count == 0) throw new InvalidOperationException("Deque is empty.");
        _tail = (_tail - 1 + _buf.Length) % _buf.Length;
        _count--;
        return _buf[_tail];
    }

    public T PopFront()
    {
        if (_count == 0) throw new InvalidOperationException("Deque is empty.");
        T val = _buf[_head];
        _head = (_head + 1) % _buf.Length;
        _count--;
        return val;
    }

    public T PeekFront() => _count == 0 ? throw new InvalidOperationException() : _buf[_head];
    public T PeekBack()  => _count == 0 ? throw new InvalidOperationException() : _buf[(_tail - 1 + _buf.Length) % _buf.Length];
}
```

**0-1 BFS — deque replaces queue for edge weights of 0 or 1**
```csharp
// In a graph where edges have weight 0 or 1, deque-BFS gives shortest paths
// in O(V + E) — faster than Dijkstra's O((V + E) log V)
public static int[] ZeroOneBFS(
    int n, List<(int to, int weight)>[] graph, int start)
{
    int[] dist = new int[n];
    Array.Fill(dist, int.MaxValue);
    dist[start] = 0;

    var dq = new LinkedList<int>();
    dq.AddFirst(start);

    while (dq.Count > 0)
    {
        int node = dq.First!.Value;
        dq.RemoveFirst();

        foreach (var (to, w) in graph[node])
        {
            int newDist = dist[node] + w;
            if (newDist < dist[to])
            {
                dist[to] = newDist;
                if (w == 0) dq.AddFirst(to);    // weight 0: process next (front)
                else        dq.AddLast(to);      // weight 1: process later (back)
            }
        }
    }
    return dist;
}
```

**Palindrome check using two pointers on a deque**
```csharp
public static bool IsPalindrome(string s)
{
    var dq = new LinkedList<char>(s);
    while (dq.Count > 1)
    {
        if (dq.First!.Value != dq.Last!.Value) return false;
        dq.RemoveFirst();
        dq.RemoveLast();
    }
    return true;
}
// Illustrative — in practice, two-pointer on the string directly is cleaner.
// This pattern appears in problems that process a sequence destructively.
```

**What NOT to do — and the fix**
```csharp
// BAD: using List<T> as a deque — O(n) insert/remove at front
var bad = new List<int>();
bad.Insert(0, 5);    // O(n) — shifts all elements
bad.RemoveAt(0);     // O(n) — shifts all elements

// GOOD: LinkedList<T> for O(1) both-ends access
var good = new LinkedList<int>();
good.AddFirst(5);    // O(1)
good.RemoveFirst();  // O(1)
```

---

## Real World Example

A browser's back/forward navigation maintains two stacks: one for backward history and one for forward history. But a deque is a cleaner model: the current page is always in the middle, backward navigation pops from the front, forward navigation pops from the back, and navigating to a new page clears the forward history and pushes to the back. A doubly linked list models this exactly — the current position is a pointer into the list, not a fixed end.

```csharp
public class BrowserHistory
{
    private readonly LinkedList<string> _history = new();
    private LinkedListNode<string>? _current;

    public BrowserHistory(string homepage)
    {
        _current = _history.AddFirst(homepage);
    }

    // Navigate to a new URL — clears forward history
    public void Visit(string url)
    {
        // Remove everything after current
        while (_history.Last != _current)
            _history.RemoveLast();

        _current = _history.AddLast(url);
    }

    // Go back up to `steps` pages — returns the page landed on
    public string Back(int steps)
    {
        while (steps-- > 0 && _current!.Previous != null)
            _current = _current.Previous;
        return _current!.Value;
    }

    // Go forward up to `steps` pages — returns the page landed on
    public string Forward(int steps)
    {
        while (steps-- > 0 && _current!.Next != null)
            _current = _current.Next;
        return _current!.Value;
    }
}
```

*The key insight is that `LinkedList<T>` node references (`LinkedListNode<T>`) let you hold a stable pointer into the middle of the list. The current page pointer moves forward and backward in O(1) per step without any searching — the doubly linked structure makes navigation in both directions O(steps), not O(n).*

---

## Common Misconceptions

**"C# has a built-in Deque<T>"**
It doesn't. This is a genuine BCL gap. `LinkedList<T>` provides the deque interface (O(1) both ends) but isn't called a deque and has no `Deque`-named methods. The method names are `AddFirst`, `AddLast`, `RemoveFirst`, `RemoveLast`. Third-party `Nito.Collections.Deque` is the production-grade circular buffer alternative.

**"LinkedList<T> and Deque<T> are the same thing"**
`LinkedList<T>` is a doubly linked list that happens to support O(1) both-ends access — making it usable as a deque. But it also supports insertion in the middle (O(1) given a node reference), iteration in both directions, and node-level manipulation. A pure deque exposes only the four endpoint operations. Using `LinkedList<T>` as a deque means constraining yourself to `AddFirst`, `AddLast`, `RemoveFirst`, `RemoveLast` — don't exploit the full linked list API in code that's conceptually a deque.

**"A deque is just a queue you can also push to the front"**
This undersells it. The deque is the base structure from which both queues and stacks are derived by restriction. A stack is a deque where only one end is used. A queue is a deque where the input end and output end are different but fixed. The deque's generality is what makes it the right substrate for the monotonic queue pattern — you need to pop from both ends during the algorithm.

---

## Gotchas

- **`LinkedList<T>.First` and `.Last` return `null` on an empty list.** Always null-check before accessing `.Value`. The `!` null-forgiving operator works in known-non-empty contexts but will throw at runtime if the list is actually empty.

- **Modifying `LinkedList<T>` while iterating it throws `InvalidOperationException`.** If you need to remove elements during a foreach, collect them first or use a `while (dq.Count > 0)` loop instead.

- **`LinkedList<T>` doesn't implement `IList<T>`.** You can't index into it with `[i]`. If you need index access alongside deque operations, use a circular buffer deque or maintain a parallel `List<T>`.

- **The circular buffer deque's `(_head - 1 + _buf.Length) % _buf.Length` for PushFront.** The `+ _buf.Length` before the modulo prevents negative modulo results in C# (unlike Python, C# `%` can return negative values for negative operands). Forgetting this causes `ArrayIndexOutOfRangeException` on the first PushFront when `_head == 0`.

- **0-1 BFS requires a deque, not a queue.** The key property is that zero-weight edges process their destination next (push to front) while one-weight edges process theirs later (push to back). A plain `Queue<T>` can't push to the front — the algorithm is impossible without a deque.

---

## Interview Angle

**What they're really testing:** Usually, the deque appears as a prerequisite for a harder problem — the interviewer is checking whether you know the right data structure (deque/LinkedList) without prompting. Direct "implement a deque" questions are rare; indirect appearances in monotonic queue, 0-1 BFS, or LRU cache problems are common.

**Common question forms:**
- "Sliding window maximum" (monotonic queue — needs deque under the hood)
- "Design a browser history" (deque navigation)
- "0-1 BFS on a grid"
- "Design a hit counter" (sliding window with deque-based expiry)

**The depth signal:** A junior reaches for a `List<T>` and takes O(n) at one end. A senior immediately says `LinkedList<T>` for O(1) both ends and can explain why — the doubly linked structure allows front and back access without shifting. The elite signal is knowing the circular buffer alternative (zero per-element allocation), the 0-1 BFS pattern (deque enables priority-based BFS without a full priority queue), and being able to implement the circular buffer's `PushFront` with the `+_buf.Length` modulo trick.

**Follow-up questions to expect:**
- "Why not use a priority queue for 0-1 BFS?" (O(log V) per enqueue vs O(1) with a deque — deque is better for binary weights)
- "What's the memory difference between LinkedList deque and circular buffer deque?" (LinkedList: ~40 bytes per node; circular buffer: ~element_size per slot)
- "How would you implement a thread-safe deque?" (`ConcurrentQueue<T>` gives FIFO only; a true thread-safe deque needs a lock or a complex lock-free algorithm)

---

## Related Topics

- [[algorithms/datastructures/monotonic-queue.md]] — The primary application of a deque in competitive programming; uses both ends to maintain window min/max.
- [[algorithms/datastructures/stack.md]] — A deque restricted to one end; use when LIFO semantics are all you need.
- [[algorithms/datastructures/queue.md]] — A deque restricted to one-end-in, other-end-out; use when FIFO semantics are all you need.
- [[algorithms/datastructures/lru-cache.md]] — Uses a doubly linked list (deque) for O(1) move-to-front and evict-from-tail.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.linkedlist-1

---

*Last updated: 2026-04-12*