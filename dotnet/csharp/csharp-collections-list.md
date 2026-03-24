# C# Collections — List<T>

> `List<T>` is a resizable array that holds an ordered sequence of items of a single type, with O(1) access by index and O(1) amortized append.

---

## When To Use It
Use `List<T>` when you need an ordered collection you can add to, remove from, and index into by position. It's the default go-to for most in-memory sequences. Don't use it when insertion order doesn't matter and you're mostly checking membership — that's `HashSet<T>`. Don't use it for key-value lookups — that's `Dictionary<TKey, TValue>`. Don't use it when you need constant-size, allocation-sensitive storage — that's an array.

---

## Core Concept
`List<T>` is a wrapper around a plain array. Internally it keeps a `T[]` and a count of how many slots are actually used. When you `Add` an item and the array is full, it allocates a new array twice the size and copies everything over — that's the amortized O(1) cost. Random access by index (`list[3]`) is O(1) because it's just indexing the backing array. Inserting or removing at the front or middle is O(n) because everything after the insertion point has to shift. Knowing this tells you when `List<T>` is the right tool and when it isn't.

---

## The Code

**Basic operations**
```csharp
var names = new List<string> { "Alice", "Bob", "Charlie" };

names.Add("Dave");               // append — O(1) amortized
names.Insert(1, "Zara");         // insert at index 1 — O(n), shifts everything right
names.Remove("Bob");             // removes first match by value — O(n) scan
names.RemoveAt(0);               // removes by index — O(n) shift

Console.WriteLine(names.Count);         // number of elements
Console.WriteLine(names.Contains("Dave")); // O(n) linear scan
Console.WriteLine(names[0]);            // index access — O(1)
```

**Searching and sorting**
```csharp
var scores = new List<int> { 42, 7, 99, 3, 55 };

scores.Sort();                           // in-place, uses introsort — O(n log n)
int idx = scores.BinarySearch(42);       // only valid on a sorted list — O(log n)
Console.WriteLine(idx);                  // index of 42

var orders = new List<Order>
{
    new Order(3, "Charlie"),
    new Order(1, "Alice"),
    new Order(2, "Bob")
};

// Sort by custom key
orders.Sort((a, b) => a.Id.CompareTo(b.Id));

// LINQ alternatives — return new sequences, don't mutate
var sorted  = orders.OrderBy(o => o.Customer).ToList();
var filtered = orders.Where(o => o.Id > 1).ToList();
```

**Capacity vs Count**
```csharp
// Count = number of items actually in the list
// Capacity = size of the backing array (includes unused slots)

var list = new List<int>();
Console.WriteLine(list.Capacity); // 0 initially

list.Add(1);
Console.WriteLine(list.Capacity); // 4 — first growth step

// Pre-allocate when you know the size — avoids resize copies
var preallocated = new List<int>(capacity: 1000);

// If you're done adding and memory matters:
list.TrimExcess(); // shrinks Capacity down to Count
```

**Common patterns**
```csharp
// Expose as read-only to callers — prevents external mutation
public IReadOnlyList<Order> GetOrders() => _orders.AsReadOnly();

// Convert to array when you need a fixed snapshot
int[] snapshot = scores.ToArray();

// AddRange — more efficient than looping Add
var extra = new[] { 10, 20, 30 };
scores.AddRange(extra);

// RemoveAll — removes every element matching a predicate in one pass
int removed = scores.RemoveAll(x => x < 10);
```

---

## Gotchas

- **Modifying a list while iterating with `foreach` throws `InvalidOperationException`.** The enumerator checks a version counter on the list. Any `Add`, `Remove`, or `Clear` during iteration increments the version and the enumerator throws. Collect items to remove in a separate list, then remove after, or iterate backwards with a `for` loop.
- **`Remove(item)` uses `Equals` to find the item, not reference equality.** If you override `Equals` on your type, `Remove` may delete an item you didn't expect. If you override `Equals` on a mutable type and then mutate it after insertion, `Remove` may not find it at all.
- **`BinarySearch` on an unsorted list returns garbage.** It gives you a result — no exception — but the result is meaningless if the list isn't sorted. It also returns a negative number (bitwise complement of the insertion point) when the item isn't found, not `-1`.
- **`List<T>` is not thread-safe.** Concurrent reads are fine, but any concurrent write — including `Add` — causes data corruption or exceptions. Use `ConcurrentBag<T>`, `ConcurrentQueue<T>`, or a lock if multiple threads write to the list.
- **Returning `List<T>` directly from a public API gives callers full mutation access.** They can `Add`, `Clear`, or `RemoveAll` your internal list. Return `IReadOnlyList<T>` or call `.AsReadOnly()` to prevent this. This is the collection equivalent of the encapsulation gotcha on public setters.

---

## Interview Angle
**What they're really testing:** Whether you understand the backing array model, Big-O for each operation, and the capacity growth mechanism — not just "it's a dynamic array."

**Common question form:** "What's the time complexity of adding to a `List<T>`?" or "How does `List<T>` differ from an array?" or "What happens internally when you exceed a list's capacity?"

**The depth signal:** A junior says "Add is O(1) and it automatically resizes." A senior explains the amortized analysis: individual adds are O(1) unless a resize is needed, which is O(n) — but resizes double the capacity each time, so the total cost across n inserts is O(n), making the per-insert amortized cost O(1). They'll also know that `Insert(0, item)` is O(n) because every element shifts, that `RemoveAt(0)` is also O(n) for the same reason, and that if you need frequent front-insertions or removals a `LinkedList<T>` or `Queue<T>` is a better fit. A senior will also mention the thread-safety issue unprompted.

---

## Related Topics
- [[dotnet/csharp-generics.md]] — `List<T>` is a generic type; understanding `T` and type constraints is the foundation for using collections correctly.
- [[dotnet/csharp-collections-dictionary.md]] — The natural next collection to know; O(1) key-based lookup vs O(n) linear scan in a list.
- [[dotnet/csharp-collections-hashset.md]] — Use when you care about membership and uniqueness, not order or index.
- [[dotnet/csharp-linq.md]] — LINQ methods (`Where`, `Select`, `OrderBy`) operate on `IEnumerable<T>` and are used constantly with lists; understanding both together is essential.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.list-1](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.list-1)

---
*Last updated: 2026-03-23*