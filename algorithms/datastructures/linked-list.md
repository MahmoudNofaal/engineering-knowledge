# Linked List

> A sequence of nodes where each node holds a value and a pointer to the next node — providing O(1) insertion/deletion at a known position but O(n) random access.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Chain of heap-allocated nodes, each pointing to the next |
| **Use when** | O(1) insert/delete at head or tail; unknown final size; LRU cache internals |
| **Avoid when** | Random access by index; cache-efficient iteration; sorted search |
| **C# version** | `LinkedList<T>` since C# 2.0 |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `LinkedList<T>`, `LinkedListNode<T>` |

---

## When To Use It

Use a linked list when you need O(1) insertion or deletion at a position you already have a reference to (a `LinkedListNode<T>`). Classic use cases: LRU cache (move-to-front in O(1) + O(1) eviction from tail), implementing a deque, or when node identity matters and you're managing references explicitly. For everything else — iteration, search, general collections — a `List<T>` (dynamic array) is faster due to cache locality. A linked list's nodes are scattered across the heap; traversal causes a cache miss per node.

---

## Core Concept

Each node stores a value and a `Next` pointer (singly linked) or both `Next` and `Prev` pointers (doubly linked). C#'s `LinkedList<T>` is doubly linked and circular — the last node's `Next` points to `null`, but the internal sentinel head node makes operations uniform. Insertion and deletion require updating two pointers — O(1) if you have the node reference, O(n) if you must search for the position.

The fundamental trade-off vs array: arrays pay O(n) for mid-list insert/delete (shifting); linked lists pay O(1) for insert/delete but O(n) for access-by-index. If you find yourself frequently doing `list[i]` on a `LinkedList`, switch to `List<T>`.

---

## Algorithm History

| Year | Development |
|---|---|
| 1955 | First linked list implemented in IPL (Information Processing Language) by Newell & Shaw |
| 1960s | Lisp is built around linked list (cons cells) as the fundamental data structure |
| 1970s | Knuth formalises singly and doubly linked lists in TAOCP |
| 2005 | C# 2.0 ships `LinkedList<T>` (doubly linked) in `System.Collections.Generic` |

---

## Performance

| Operation | Singly Linked | Doubly Linked | Notes |
|---|---|---|---|
| Access by index | O(n) | O(n) | Must traverse from head |
| Insert at head | O(1) | O(1) | Update head pointer |
| Insert at tail | O(n) / O(1)* | O(1) | O(1) with tail pointer |
| Insert after node (given ref) | O(1) | O(1) | Pointer update only |
| Delete head | O(1) | O(1) | |
| Delete tail | O(n) | O(1) | Singly linked needs traversal |
| Delete node (given ref) | O(1)** | O(1) | **Singly: O(n) to find prev |
| Search | O(n) | O(n) | No random access |
| Iteration | O(n) | O(n) | Cache-unfriendly — one miss per node |

**Allocation behaviour:** Every node is a separate heap object. For a list of n integers, that's n separate allocations vs one contiguous block for an array. GC pressure is higher; iteration triggers more cache misses.

---

## The Code

**Scenario 1 — basic LinkedList<T> operations**
```csharp
var list = new LinkedList<int>();
list.AddLast(1);           // [1]
list.AddLast(2);           // [1, 2]
list.AddFirst(0);          // [0, 1, 2]

LinkedListNode<int> node = list.Find(1)!;
list.AddAfter(node, 99);   // [0, 1, 99, 2]
list.Remove(node);         // [0, 99, 2] — O(1) given the node reference

Console.WriteLine(list.First!.Value); // 0
Console.WriteLine(list.Last!.Value);  // 2
```

**Scenario 2 — reverse a linked list in-place**
```csharp
public ListNode? ReverseList(ListNode? head)
{
    ListNode? prev = null, curr = head;
    while (curr != null)
    {
        ListNode? next = curr.Next; // save next before overwriting
        curr.Next = prev;           // reverse the pointer
        prev = curr;                // advance prev
        curr = next;                // advance curr
    }
    return prev; // prev is the new head
}

public class ListNode { public int Val; public ListNode? Next; }
```

**Scenario 3 — LRU cache using LinkedList + Dictionary**
```csharp
public class LRUCache
{
    private readonly int _capacity;
    private readonly Dictionary<int, LinkedListNode<(int Key, int Value)>> _map = new();
    private readonly LinkedList<(int Key, int Value)> _list = new();

    public LRUCache(int capacity) => _capacity = capacity;

    public int Get(int key)
    {
        if (!_map.TryGetValue(key, out var node)) return -1;
        _list.Remove(node);           // O(1) — have the node reference
        _list.AddFirst(node.Value);   // move to front (most recently used)
        _map[key] = _list.First!;
        return node.Value.Value;
    }

    public void Put(int key, int value)
    {
        if (_map.TryGetValue(key, out var existing))
            _list.Remove(existing);
        else if (_list.Count == _capacity)
        {
            _map.Remove(_list.Last!.Value.Key); // evict LRU — O(1) from tail
            _list.RemoveLast();
        }
        _list.AddFirst((key, value));  // most recently used goes to front
        _map[key] = _list.First!;
    }
}
```

**Scenario 4 — what NOT to do: index access on LinkedList**
```csharp
// BAD: O(n²) — ElementAt traverses from head each call
public void PrintAllBad(LinkedList<int> list)
{
    for (int i = 0; i < list.Count; i++)
        Console.WriteLine(list.ElementAt(i)); // O(n) per call → O(n²) total
}

// GOOD: iterate with foreach — O(n) total
public void PrintAllGood(LinkedList<int> list)
{
    foreach (int val in list) // uses the enumerator — O(1) per step
        Console.WriteLine(val);
}
```

---

## Real World Example

The `RequestQueueService` in an API gateway maintains a priority queue of pending requests. Completed requests are removed from the middle of the queue when their response arrives — a position where array-backed structures require O(n) shifts. Because requests hold a `LinkedListNode<T>` reference, removal is O(1).

```csharp
public class RequestQueueService
{
    private readonly LinkedList<PendingRequest> _queue = new();
    private readonly Dictionary<Guid, LinkedListNode<PendingRequest>> _nodeMap = new();

    public void Enqueue(PendingRequest request)
    {
        var node = _queue.AddLast(request); // O(1)
        _nodeMap[request.RequestId] = node;
    }

    // O(1) — remove from anywhere in the list given the node reference
    public void Complete(Guid requestId)
    {
        if (_nodeMap.TryGetValue(requestId, out var node))
        {
            _queue.Remove(node);           // O(1) — doubly linked, no traversal
            _nodeMap.Remove(requestId);
        }
    }

    public PendingRequest? DequeueOldest() // O(1)
    {
        if (_queue.First == null) return null;
        var request = _queue.First.Value;
        _nodeMap.Remove(request.RequestId);
        _queue.RemoveFirst();
        return request;
    }

    public record PendingRequest(Guid RequestId, DateTimeOffset Timestamp, string Endpoint);
}
```

*The key insight: storing the `LinkedListNode<T>` reference in the dictionary is what makes O(1) mid-list removal possible. Without the reference, you'd have to call `_queue.Find(request)` — an O(n) scan.*

---

## Common Misconceptions

**"LinkedList is always better than List for insert/delete"**
Only if you have the node reference. If you need to find the position first (by value or index), that's O(n) — identical to shifting in a `List<T>`. And `List<T>` is faster for the common case (append, iterate) due to cache locality. Linked lists win only in specific cases: O(1) operations at known node positions.

**"Reversing a linked list requires extra memory"**
No. In-place reversal requires only three pointers (`prev`, `curr`, `next`) — O(1) space. The common mistake is creating a new list instead of rewiring the existing nodes.

**"LinkedList<T> in C# is singly linked"**
It's doubly linked. Each `LinkedListNode<T>` has both a `Next` and `Previous` property. This makes O(1) removal from any position (given the node) and O(1) insertion before/after any node.

---

## Gotchas

- **`list.Find(value)` is O(n).** It scans from head. If you need O(1) removal by value, maintain a `Dictionary<TValue, LinkedListNode<T>>` alongside the list — exactly the LRU cache pattern.
- **Forgetting to save `curr.Next` before rewiring.** In manual list reversal, `curr.Next = prev` destroys the only reference to the rest of the list. Always save `next` before the pointer swap.
- **`LinkedList<T>` doesn't support index access.** There is no `list[i]` — it throws. Use `ElementAt(i)` (O(n)) or redesign to hold node references.
- **Each node is a separate heap object.** For value types like `int`, a `LinkedList<int>` boxes each value. Prefer `List<int>` for value type collections.

---

## Interview Angle

**What they're really testing:** Pointer manipulation — can you reverse a list, detect a cycle, merge two sorted lists, and find the midpoint, all in O(1) space?

**Common question forms:** Reverse a linked list. Detect a cycle (fast/slow pointers). Merge two sorted lists. Find the middle node. Remove nth from end.

**The depth signal:** A junior reverses iteratively. A senior reverses in-place with O(1) space, knows the fast/slow pointer patterns cold, and can implement the LRU cache combining `LinkedList<T>` with `Dictionary`.

---

## Related Topics

- [[algorithms/patterns/fast-slow-pointers.md]] — The primary pattern for linked list cycle detection and midpoint.
- [[algorithms/datastructures/array.md]] — The cache-efficient alternative for most sequential use cases.
- [[algorithms/datastructures/hash-table.md]] — Combined with LinkedList for the LRU cache pattern.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.linkedlist-1

---

*Last updated: 2026-04-21*