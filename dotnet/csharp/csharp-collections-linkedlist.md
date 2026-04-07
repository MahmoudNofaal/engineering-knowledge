# C# Collections — LinkedList\<T\>

> A doubly linked list where every node holds a value and pointers to its neighbours — O(1) insertion and deletion at any position when you hold a node reference.

---

## Quick Reference

| Operation | Complexity | Notes |
|---|---|---|
| `AddFirst`/`AddLast` | O(1) | |
| `AddBefore`/`AddAfter` (with node) | O(1) | Must have node reference |
| `Remove(node)` | O(1) | Must have node reference |
| `Find(value)` | O(n) | Linear scan |
| Index access | O(n) | No indexer — must walk |

---

## When To Use It

Use `LinkedList<T>` when you need O(1) insertion or deletion at arbitrary positions and you already have a reference to the node where the change happens. Classic use cases: LRU cache implementation, ordered job queues where items move positions, undo/redo stacks with rearrangement.

Don't use it when you need random access by index (`List<T>`) or when your workload is mostly reads — cache locality of arrays beats linked list pointer-chasing in practice for most real data sizes.

---

## Core Concept

Each `LinkedListNode<T>` is a separate heap object with `Value`, `Previous`, and `Next` pointers. Insertion between two nodes is just pointer rewiring — three assignments, O(1). But finding a node by value or position requires walking the chain — O(n). The standard pattern is pairing `LinkedList<T>` with a `Dictionary<TKey, LinkedListNode<T>>` so that finding a node is O(1), and then the linked list operation is O(1).

---

## The Code

**Basic operations**
```csharp
var list = new LinkedList<string>();
list.AddLast("a");
list.AddLast("b");
list.AddLast("c");
list.AddFirst("start");

foreach (var val in list) Console.Write(val + " "); // start a b c

var nodeB = list.Find("b");
list.AddBefore(nodeB!, "before-b");
list.AddAfter(nodeB!, "after-b");
list.Remove(nodeB!); // O(1) — we already have the reference
```

**LRU Cache — the canonical use case**
```csharp
public class LruCache<TKey, TValue> where TKey : notnull
{
    private readonly int _capacity;
    private readonly Dictionary<TKey, LinkedListNode<(TKey Key, TValue Value)>> _map;
    private readonly LinkedList<(TKey Key, TValue Value)> _order;

    public LruCache(int capacity)
    {
        _capacity = capacity;
        _map   = new Dictionary<TKey, LinkedListNode<(TKey, TValue)>>(capacity);
        _order = new LinkedList<(TKey, TValue)>();
    }

    public bool TryGet(TKey key, out TValue value)
    {
        if (!_map.TryGetValue(key, out var node)) { value = default!; return false; }
        _order.Remove(node);       // O(1) — have the node
        _order.AddFirst(node);     // move to front = most recently used
        value = node.Value.Value;
        return true;
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

*The insight: dictionary gives O(1) node lookup; linked list gives O(1) reorder. Without the dictionary, every `Get` would be O(n) to find the node.*

---

## Gotchas

- **`Find()` is O(n)** — don't use it in a hot path. Hold onto `LinkedListNode<T>` references directly.
- **Iterating and removing mid-traversal throws.** Save `current.Next` before `Remove(current)`.
- **Each node is a separate heap object** — poor cache locality for large collections vs arrays.

---

## Source

[LinkedList\<T\> — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.linkedlist-1)

---
*Last updated: 2026-04-06*