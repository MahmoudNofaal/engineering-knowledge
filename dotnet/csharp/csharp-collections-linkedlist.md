# C# Collections — LinkedList<T>

> A doubly linked list where every node holds a value plus pointers to the node before and after it — giving you O(1) insertions and deletions anywhere in the list, at the cost of no index access.

---

## When To Use It

Use `LinkedList<T>` when you need frequent insertions or deletions in the middle of a collection and you already have a reference to the node where the change happens. It's the right call for things like LRU cache implementation, ordered job queues where items get promoted or removed mid-list, or any structure where you're constantly splicing. Don't use it when you need index access (`list[i]`) or when your workload is mostly reads — cache locality on arrays will beat linked list pointer-chasing every time in practice.

---

## Core Concept

A `List<T>` is a resizable array — great for reads, painful for mid-list inserts because everything after the insertion point has to shift. `LinkedList<T>` solves that by making each element its own object (`LinkedListNode<T>`) that knows its neighbors. Inserting between two nodes is just pointer rewiring — three assignments, done. The tradeoff is that there's no way to jump to position N without walking the chain from the front or back, and each node is a separate heap allocation, so memory is scattered. The C# implementation is doubly linked and circular — `Last.Next` wraps to `First`.

---

## The Code

### Basic add, remove, traverse
```csharp
var list = new LinkedList<string>();

list.AddLast("a");
list.AddLast("b");
list.AddLast("c");
list.AddFirst("start");

// Traverse — no index, always walk
foreach (var val in list)
    Console.WriteLine(val); // start, a, b, c

// Find a node, then insert relative to it
var nodeB = list.Find("b");
list.AddBefore(nodeB, "before-b");
list.AddAfter(nodeB, "after-b");

list.Remove(nodeB); // O(1) — we already have the reference
```

### Working with LinkedListNode<T> directly
```csharp
var list = new LinkedList<int>(new[] { 1, 2, 3, 4, 5 });

LinkedListNode<int>? current = list.First;

while (current != null)
{
    if (current.Value % 2 == 0)
    {
        var next = current.Next; // capture before removal
        list.Remove(current);   // O(1) — safe mid-traversal if you saved Next
        current = next;
    }
    else
    {
        current = current.Next;
    }
}
// Result: 1, 3, 5
```

### LRU Cache skeleton (the canonical LinkedList interview problem)
```csharp
class LruCache<TKey, TValue> where TKey : notnull
{
    private readonly int _capacity;
    private readonly Dictionary<TKey, LinkedListNode<(TKey Key, TValue Value)>> _map;
    private readonly LinkedList<(TKey Key, TValue Value)> _order;

    public LruCache(int capacity)
    {
        _capacity = capacity;
        _map = new(capacity);
        _order = new();
    }

    public TValue Get(TKey key)
    {
        if (!_map.TryGetValue(key, out var node))
            throw new KeyNotFoundException();

        _order.Remove(node);        // O(1) — have the node reference
        _order.AddFirst(node);      // move to front = most recently used
        return node.Value.Value;
    }

    public void Put(TKey key, TValue value)
    {
        if (_map.TryGetValue(key, out var existing))
        {
            _order.Remove(existing);
            _map.Remove(key);
        }
        else if (_map.Count == _capacity)
        {
            var lru = _order.Last!;
            _order.RemoveLast();
            _map.Remove(lru.Value.Key);
        }

        var node = _order.AddFirst((key, value));
        _map[key] = node;
    }
}
```

---

## Gotchas

- **`Find()` is O(n)** — it walks the list linearly. If you call `Find()` then immediately `Remove()`, you've paid O(n) for what should be O(1). Always hold onto `LinkedListNode<T>` references directly when you know you'll need to modify around them.
- **Removing during foreach throws** — the enumerator detects structural changes and throws `InvalidOperationException`. Walk via `node = node.Next` manually if you need to remove mid-traversal (as shown in the second example above).
- **Each node is a separate heap object** — for large collections this means GC pressure and poor CPU cache utilization compared to arrays. Benchmarks that favor `LinkedList` over `List` for mid-list inserts often don't account for this in real workloads.
- **`AddBefore` / `AddAfter` accept a node from a different list** — .NET won't throw immediately in all cases, but the list state will corrupt. Always verify node ownership if nodes are passed around across list instances.
- **There's no `LinkedList<T>` in `System.Collections.Concurrent`** — there's no thread-safe linked list in the BCL. If you need concurrent access, you'll have to wrap it with a lock yourself.

---

## Interview Angle

**What they're really testing:** Whether you understand pointer-based data structures and when O(1) node access actually matters versus when it's theoretical.

**Common question form:** "Implement an LRU cache," "design a browser history," or "remove all even numbers from a list without extra allocations."

**The depth signal:** A junior knows that linked lists have O(1) insert/delete and codes up the LRU cache. A senior explains that the O(1) only holds if you already have the `LinkedListNode<T>` reference — and that's exactly why the LRU cache pairs `LinkedList<T>` with a `Dictionary<TKey, LinkedListNode<T>>`: the dictionary gives you O(1) lookup to find the node, and then the linked list gives you O(1) relinking. Without the dictionary, every `Get` degrades to O(n). That pairing is the actual insight.

---

## Related Topics

- [[dotnet/csharp-collections-list-linkedlist.md]] — Direct comparison with `List<T>`; explains when the array-backed structure wins on cache locality despite worse asymptotic insert cost.
- [[dotnet/csharp-collections-dictionary.md]] — `Dictionary<TKey, LinkedListNode<T>>` is the other half of every serious `LinkedList<T>` use case; the two structures compose.
- [[algorithms/lru-cache.md]] — Full LRU cache walkthrough including eviction policy and complexity analysis.
- [[dotnet/csharp-collections-queue-stack.md]] — Queue and Stack offer constrained access patterns; useful contrast when deciding whether you need mid-list access at all.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.linkedlist-1

---
*Last updated: 2026-03-23*