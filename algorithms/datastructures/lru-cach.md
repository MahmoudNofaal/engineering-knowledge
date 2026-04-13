# LRU Cache

> A fixed-capacity cache that evicts the least recently used item when full, with O(1) get and put operations.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Capacity-bounded cache — O(1) get/put with LRU eviction |
| **Use when** | Bounded memory cache with recency-based eviction |
| **Avoid when** | LFU (frequency-based) or TTL-based eviction is needed |
| **C# version** | C# 2.0+ (`Dictionary` + `LinkedList`) |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `Dictionary<int, LinkedListNode<(int key, int val)>>`, `LinkedList<(int, int)>` |

---

## When To Use It

Use an LRU cache when you have a fixed memory budget and want to keep the most recently accessed items in memory, evicting the oldest-accessed item when capacity is exceeded. It's the right model for: browser page caches, DNS caches, database query result caches, CPU instruction caches, and any scenario where "recently used is likely to be used again" holds (the temporal locality assumption).

In production .NET, `MemoryCache` (from `Microsoft.Extensions.Caching.Memory`) includes LRU-like eviction policies and is the right default for application-level caching. Implement LRU from scratch when an interview requires it, when you need exact control over eviction ordering, or when building a cache for a data structure in competitive programming.

Avoid LRU when items should be evicted by access frequency (use LFU — Least Frequently Used), by expiration time (use TTL eviction), or by insertion order rather than access order (use a simple FIFO queue).

---

## Core Concept

An LRU cache needs two capabilities simultaneously:

1. **O(1) key lookup** — to retrieve or update a cached value by key.
2. **O(1) eviction of the least recently used item** — when the cache is full, remove the item that was accessed longest ago.

Neither capability alone is hard: a hash map gives O(1) lookup; a queue gives O(1) access to the oldest item. The challenge is doing both together.

The solution: a **hash map + doubly linked list**.

- The **doubly linked list** maintains access order. The most recently used item is always at the head; the least recently used is always at the tail.
- The **hash map** maps each key to its `LinkedListNode` — giving O(1) access to any node's position in the list without scanning.

On every `Get`: move the node to the head (O(1) with a doubly linked list + node reference).
On every `Put`: if the key exists, update and move to head. If the cache is full, evict the tail node, then insert the new node at the head.

Every operation is O(1) because the hash map eliminates the O(n) search, and the doubly linked list enables O(1) node removal given a direct reference.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 2.0 | .NET 2.0 | `Dictionary<K,V>` + `LinkedList<T>` — the standard LRU building blocks |
| C# 4.0 | .NET 4.0 | `MemoryCache` added to BCL — production LRU-like cache with TTL |
| C# 5.0 | .NET 4.5 | `IMemoryCache` interface — testable cache abstraction |
| C# 9.0 | .NET 5 | `record` types clean up the linked list node's value tuple |
| C# 10.0 | .NET 6 | `IMemoryCache.GetOrCreate` with `MemoryCacheEntryOptions.Size` for capacity |

*`MemoryCache` uses a combination of size limits and a sliding expiration — not pure LRU — but it's the right choice for production. Hand-rolled LRU is for interviews and exact-eviction-order requirements.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Get | O(1) | Hash map lookup + move-to-head in doubly linked list |
| Put (key exists) | O(1) | Update value + move-to-head |
| Put (key new, not full) | O(1) | Insert at head + hash map insert |
| Put (key new, full) | O(1) | Evict tail + insert at head + hash map update |
| Space | O(capacity) | Hash map + linked list, both bounded by capacity |

**Allocation behaviour:** Each cached entry allocates one `LinkedListNode<(int key, int val)>` on the managed heap (via `LinkedList<T>.AddFirst`). The hash map stores `LinkedListNode<T>` references. Total memory: approximately `capacity × (node size + dict entry size)` — roughly 80–120 bytes per entry on 64-bit depending on key/value types.

**Benchmark notes:** In practice, `Dictionary<K,V>` lookup involves a hash computation and possible chain scan. For `int` keys this is extremely fast (identity hash). For `string` keys, hash computation touches every character — cache key design matters for throughput.

---

## The Code

**Standard LRU Cache implementation**
```csharp
public class LRUCache
{
    private readonly int _capacity;
    // Maps key → its node in the linked list
    private readonly Dictionary<int, LinkedListNode<(int key, int val)>> _map = new();
    // Head = most recently used, Tail = least recently used
    private readonly LinkedList<(int key, int val)> _list = new();

    public LRUCache(int capacity) => _capacity = capacity;

    public int Get(int key)
    {
        if (!_map.TryGetValue(key, out var node))
            return -1;   // cache miss

        MoveToFront(node);
        return node.Value.val;
    }

    public void Put(int key, int value)
    {
        if (_map.TryGetValue(key, out var existing))
        {
            // Key exists — update value and move to front
            _list.Remove(existing);
            _map.Remove(key);
        }
        else if (_map.Count >= _capacity)
        {
            // Cache full — evict the LRU item (tail)
            var lru = _list.Last!;
            _map.Remove(lru.Value.key);
            _list.RemoveLast();
        }

        // Insert new node at head (most recently used)
        var node = _list.AddFirst((key, value));
        _map[key] = node;
    }

    private void MoveToFront(LinkedListNode<(int key, int val)> node)
    {
        _list.Remove(node);
        _list.AddFirst(node);   // LinkedList<T>.AddFirst(node) reuses the node object
    }
}

// Usage
var cache = new LRUCache(2);
cache.Put(1, 1);    // cache: {1=1}
cache.Put(2, 2);    // cache: {2=2, 1=1}
cache.Get(1);       // returns 1; cache: {1=1, 2=2}  ← 1 moved to front
cache.Put(3, 3);    // evicts 2 (LRU); cache: {3=3, 1=1}
cache.Get(2);       // returns -1 (evicted)
```

**Generic version — works with any key/value type**
```csharp
public class LRUCache<TKey, TValue> where TKey : notnull
{
    private readonly int _capacity;
    private readonly Dictionary<TKey, LinkedListNode<(TKey key, TValue val)>> _map = new();
    private readonly LinkedList<(TKey key, TValue val)> _list = new();

    public LRUCache(int capacity) => _capacity = capacity;

    public bool TryGet(TKey key, out TValue? value)
    {
        if (!_map.TryGetValue(key, out var node)) { value = default; return false; }
        _list.Remove(node);
        _list.AddFirst(node);
        value = node.Value.val;
        return true;
    }

    public void Put(TKey key, TValue value)
    {
        if (_map.TryGetValue(key, out var existing))
        {
            _list.Remove(existing);
            _map.Remove(key);
        }
        else if (_map.Count >= _capacity)
        {
            _map.Remove(_list.Last!.Value.key);
            _list.RemoveLast();
        }
        _map[key] = _list.AddFirst((key, value));
    }

    public int Count    => _map.Count;
    public bool Contains(TKey key) => _map.ContainsKey(key);
}
```

**Thread-safe LRU — lock the critical sections**
```csharp
public class ThreadSafeLRUCache<TKey, TValue> where TKey : notnull
{
    private readonly LRUCache<TKey, TValue> _inner;
    private readonly ReaderWriterLockSlim _lock = new();

    public ThreadSafeLRUCache(int capacity)
        => _inner = new LRUCache<TKey, TValue>(capacity);

    public bool TryGet(TKey key, out TValue? value)
    {
        // Get is a write operation — it mutates access order
        _lock.EnterWriteLock();
        try { return _inner.TryGet(key, out value); }
        finally { _lock.ExitWriteLock(); }
    }

    public void Put(TKey key, TValue value)
    {
        _lock.EnterWriteLock();
        try { _inner.Put(key, value); }
        finally { _lock.ExitWriteLock(); }
    }
}
```

**What NOT to do — and the fix**
```csharp
// BAD: using only a Dictionary — no eviction order, no LRU
var bad = new Dictionary<int, int>(capacity: 100);
// When full, you have no way to know which key was accessed longest ago.

// ALSO BAD: using a SortedDictionary keyed on access timestamp
// — O(log n) per operation, and timestamps can collide in high-throughput scenarios

// GOOD: Dictionary + DoublyLinkedList — O(1) for both lookup and eviction order
// (see the standard implementation above)
```

---

## Real World Example

A read-heavy API serves product detail pages. Most traffic concentrates on a small subset of popular products. Fetching from the database takes ~50 ms; the API budget is 5 ms. An LRU cache of 10,000 products holds the hot set in memory. On cache hit the response is served in under 1 ms; on miss the database is consulted and the result is cached, evicting the least recently accessed product if at capacity.

```csharp
public class ProductCache
{
    private readonly LRUCache<string, Product> _cache;
    private readonly IProductRepository _repo;

    // Metrics
    private long _hits, _misses;

    public ProductCache(IProductRepository repo, int capacity = 10_000)
    {
        _cache = new LRUCache<string, Product>(capacity);
        _repo  = repo;
    }

    public async Task<Product?> GetAsync(string productId, CancellationToken ct)
    {
        if (_cache.TryGet(productId, out Product? cached))
        {
            Interlocked.Increment(ref _hits);
            return cached;
        }

        Interlocked.Increment(ref _misses);
        Product? product = await _repo.FindByIdAsync(productId, ct);

        if (product != null)
            _cache.Put(productId, product);

        return product;
    }

    public double HitRate
        => _hits + _misses == 0 ? 0 : (double)_hits / (_hits + _misses);
}
```

*The key insight is what the LRU eviction policy optimises for: under temporal locality (recently accessed items are likely to be accessed again), evicting the least recently used item maximises hit rate for any given capacity. Products viewed yesterday may be relevant; products not viewed in hours are less likely to be re-requested. LRU naturally reflects this by keeping recent accesses warm.*

---

## Common Misconceptions

**"LRU cache `Get` is a read-only operation"**
It's not. Every `Get` must update the access order — the retrieved item moves to the "most recently used" position. This means `Get` mutates the internal linked list. In a thread-safe implementation, `Get` requires a write lock, not a read lock. This surprises people and is a common concurrency bug in LRU implementations.

**"You can implement LRU with just an `OrderedDictionary`"**
`OrderedDictionary` maintains insertion order, not access order. After a `Get`, you'd need to remove and re-insert the entry to update its position — that's O(n) because `OrderedDictionary` is backed by a hash table + array with no direct node reference. The doubly linked list + hash map approach is O(1) because the hash map gives you a direct pointer to the node.

**"LRU is always the best eviction policy"**
LRU performs well under temporal locality — recently used items are likely to be used again. It fails under sequential access patterns (scanning a dataset larger than the cache): every item is used exactly once, the LRU item is always the one needed next, and the hit rate is 0%. LFU (Least Frequently Used) handles frequency patterns better; ARC (Adaptive Replacement Cache) combines both.

---

## Gotchas

- **`Get` is a mutating operation — always acquire a write lock in threaded code.** Using a read lock for `Get` and a write lock for `Put` is incorrect. `Get` moves a node to the front of the list, which is a write to shared state.

- **`LinkedList<T>.AddFirst(node)` reuses the existing node object.** When moving a node to the front, call `list.Remove(node)` then `list.AddFirst(node)` — not `list.AddFirst(node.Value)`. The latter allocates a new node and you'd need to update the map entry. The former reuses the same node object and the map entry stays valid.

- **The hash map must be keyed by the original key, not the list value.** When evicting the tail, you need `_map.Remove(lru.Value.key)` — not the node itself. This is why the linked list stores `(key, val)` tuples, not just `val`.

- **Capacity of 0 is a degenerate case.** Decide upfront whether `Put` on a zero-capacity cache is a no-op or an error. The standard LeetCode contract treats capacity ≥ 1 as given.

- **For very high throughput, `LinkedList<T>` GC pressure is real.** Each `AddFirst` allocates a `LinkedListNode<T>` on the heap. A circular buffer deque-based LRU (pre-allocated node pool or array-based intrusive list) eliminates this. Profile before optimising, but be aware the issue exists.

---

## Interview Angle

**What they're really testing:** Whether you can identify that O(1) for both operations requires two data structures working together — and whether you know which two and how they interact.

**Common question forms:**
- "Design an LRU cache with O(1) get and put" (LeetCode 146 — the canonical problem)
- "Implement a cache for a URL shortener service"
- "How would you implement a browser's page cache?"

**The depth signal:** A junior knows you need a hash map and some order-tracking structure but reaches for a sorted structure (O(log n)) or rebuilds ordering on every access (O(n)). A senior says "hash map + doubly linked list" immediately and explains why: the hash map gives O(1) lookup; the doubly linked list gives O(1) move-to-front and O(1) evict-from-tail — but only because the hash map stores direct node references, eliminating the O(n) search. The elite signal is knowing that `Get` is a write operation (breaks the read/write lock assumption), knowing the `AddFirst(node)` vs `AddFirst(node.Value)` distinction, and being able to generalise to LFU or thread-safe variants.

**Follow-up questions to expect:**
- "How would you make this thread-safe?" (Write lock on both Get and Put — Get mutates access order)
- "How would you implement LFU instead?" (Min-heap or frequency-bucket doubly linked list — O(1) is harder)
- "What eviction policy would you use for a sequential scan workload?" (LRU fails; LFU or random eviction often performs better)

---

## Related Topics

- [[algorithms/datastructures/linked-list.md]] — The doubly linked list is the backbone of LRU; O(1) node removal requires a direct node reference.
- [[algorithms/datastructures/hash-table.md]] — The dictionary gives O(1) key lookup and maps keys to node references.
- [[algorithms/datastructures/deque.md]] — A deque can replace the linked list in some LRU implementations — O(1) on both ends.

---

## Source

https://leetcode.com/problems/lru-cache/

---

*Last updated: 2026-04-12*