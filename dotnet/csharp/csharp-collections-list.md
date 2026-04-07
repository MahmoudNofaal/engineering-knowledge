# C# Collections — List\<T\>

> `List<T>` is a resizable array that holds an ordered sequence of items of a single type — O(1) index access, O(1) amortised append, the default collection for most scenarios.

---

## Quick Reference

| Operation | Complexity | Notes |
|---|---|---|
| `Add` | O(1) amortised | O(n) on resize |
| `Insert(i, x)` | O(n) | Shifts everything after `i` |
| `RemoveAt(i)` | O(n) | Shifts everything after `i` |
| `this[i]` | O(1) | Direct array index |
| `Contains` | O(n) | Linear scan |
| `Sort` | O(n log n) | In-place TimSort |
| `BinarySearch` | O(log n) | Only on sorted list |

---

## When To Use It

`List<T>` is the default ordered collection. Use it when you need to add items, iterate in order, and access by position. Replace it with a more specific collection only when you have a measured reason:

- `HashSet<T>` when you only care about membership and uniqueness
- `Dictionary<K,V>` when you need O(1) lookup by key
- `LinkedList<T>` when you need frequent O(1) mid-list insertion with a node reference
- Array when size is fixed and performance is critical

---

## Core Concept

`List<T>` wraps a plain `T[]` array with a count of how many slots are actually used. When you `Add` and the array is full, it allocates a new array **twice** the current capacity and copies everything over — that's the amortised O(1) cost. The doubling strategy means the total copy work across n inserts is O(n), making the per-insert amortised cost O(1).

Knowing the backing is an array tells you everything about performance: index access is O(1) (direct offset), appending is O(1) amortised, but inserting or removing at the front or middle is O(n) because everything after must shift.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 2.0 | .NET 2.0 | `List<T>` introduced (replaced `ArrayList`) |
| C# 3.0 | .NET 3.5 | Collection initializer: `new List<int> { 1, 2, 3 }` |
| C# 12.0 | .NET 8 | Collection expressions: `List<int> x = [1, 2, 3]` |

---

## Performance

**Allocation behaviour:** One heap allocation for the backing array. Growing triggers a new allocation + copy. Pre-sizing with `new List<T>(capacity)` avoids intermediate resizes for large known sets.

**Count vs Count():** `list.Count` is an O(1) property. `list.Count()` (LINQ extension) checks for `ICollection<T>` and short-circuits to `.Count` — also O(1) for `List<T>`. But `query.Where(...).Count()` after a LINQ chain is always O(n).

---

## The Code

**Basic operations**
```csharp
var names = new List<string> { "Alice", "Bob", "Charlie" };

names.Add("Dave");                // append — O(1) amortised
names.Insert(1, "Zara");         // insert at index 1 — O(n) shift
names.Remove("Bob");             // first match by value — O(n) scan + shift
names.RemoveAt(0);               // by index — O(n) shift
names.RemoveAll(n => n.Length > 5); // removes all matches in one pass

Console.WriteLine(names.Count);             // current element count
Console.WriteLine(names[0]);               // O(1) index access
Console.WriteLine(names.Contains("Dave")); // O(n) linear scan
```

**Capacity management**
```csharp
var list = new List<int>();
Console.WriteLine(list.Capacity); // 0

list.Add(1);
Console.WriteLine(list.Capacity); // 4 — first growth

// Pre-allocate when you know the size — avoids intermediate resizes
var preallocated = new List<int>(capacity: 10_000);

// Trim back to Count after bulk loading if memory matters
list.TrimExcess();
```

**Sorting and searching**
```csharp
var scores = new List<int> { 42, 7, 99, 3, 55 };

scores.Sort();                                    // in-place TimSort
int idx = scores.BinarySearch(42);               // valid only after Sort — O(log n)
// idx < 0 means not found; ~idx is insertion point

// Custom comparer
var orders = new List<Order> { ... };
orders.Sort((a, b) => a.Total.CompareTo(b.Total));

// LINQ alternatives — return new sequences, don't mutate
var sorted   = orders.OrderBy(o => o.Total).ToList();
var filtered = orders.Where(o => o.Total > 100).ToList();
```

**Safe iteration when modifying**
```csharp
// WRONG: throws InvalidOperationException during foreach
foreach (var item in list)
    if (item.IsExpired) list.Remove(item); // modifies collection mid-iteration

// RIGHT option 1: RemoveAll — one pass, no re-iteration
list.RemoveAll(item => item.IsExpired);

// RIGHT option 2: iterate backwards with for
for (int i = list.Count - 1; i >= 0; i--)
    if (list[i].IsExpired) list.RemoveAt(i);
```

**Expose as read-only**
```csharp
// Give callers a read-only view — prevents Add/Remove/Clear
public IReadOnlyList<Order> GetOrders() => _orders.AsReadOnly();

// Or return IReadOnlyList<T> directly — signals immutability
public IReadOnlyList<Order> Orders { get; } = new List<Order>();
```

---

## Real World Example

An in-memory product catalogue uses `List<T>` with capacity pre-sizing on startup, then exposes read-only access to callers.

```csharp
public class ProductCatalogue
{
    private readonly List<Product> _products;
    private readonly Dictionary<int, int> _indexById; // O(1) lookup

    public ProductCatalogue(IEnumerable<Product> products)
    {
        var list = products.ToList();
        _products   = new List<Product>(list.Count); // pre-size — no resizes
        _indexById  = new Dictionary<int, int>(list.Count);

        foreach (var p in list)
        {
            _indexById[p.Id] = _products.Count;
            _products.Add(p);
        }
    }

    public IReadOnlyList<Product> All => _products.AsReadOnly();

    public Product? FindById(int id)
        => _indexById.TryGetValue(id, out int idx) ? _products[idx] : null;

    public IReadOnlyList<Product> FindByCategory(string category)
        => _products.Where(p => p.Category == category).ToList().AsReadOnly();

    public int Count => _products.Count;
}
```

*The key insight: the catalogue pre-sizes its `List<T>` to avoid any resizing after initial load, and exposes only `IReadOnlyList<T>` to callers — no one outside can add or remove products. A companion `Dictionary<int, int>` maps product IDs to list indices for O(1) lookup without giving up the ordered, indexed `List<T>` as the primary data store.*

---

## Common Misconceptions

**"Insert is always O(1) like Add"**
`Add` appends at the end — O(1) amortised. `Insert(0, item)` inserts at the beginning — O(n) because every existing element shifts right. If you need frequent front-insertions, `LinkedList<T>` or `Queue<T>` is the right structure.

**"`List<T>.Count()` (LINQ) and `List<T>.Count` (property) are the same"**
For a plain `List<T>` they short-circuit to the same result, but once any LINQ operator wraps the list (like `Where`), `Count()` walks every element. `list.Where(x => x.Active).Count()` is always O(n).

---

## Gotchas

- **Modifying during `foreach` throws.** The enumerator checks a version counter. Any `Add`, `Remove`, or `Clear` increments it. Use `RemoveAll` or iterate backwards with `for`.
- **`BinarySearch` on unsorted data returns garbage.** No exception — just a wrong result. Sort first.
- **`List<T>` is not thread-safe.** Concurrent writes corrupt state. Use `ConcurrentBag<T>` or a lock.
- **`Remove(item)` uses `Equals` semantics.** If `Equals` is overridden on your type, it may remove an unexpected item.

---

## Interview Angle

**What they're really testing:** Whether you understand the backing array model, amortised O(1) append, and when List falls short.

**Common question forms:**
- "What's the time complexity of adding to a `List<T>`?"
- "What happens internally when you exceed a list's capacity?"
- "Why is `Insert(0, x)` slow?"

**The depth signal:** A senior explains the doubling strategy for amortised O(1) append, knows `Insert(0, x)` is O(n), and can articulate when to switch to `LinkedList<T>`, `Queue<T>`, or a pre-sized array.

---

## Related Topics

- [[dotnet/csharp/csharp-arrays.md]] — The fixed-size counterpart; `List<T>` wraps an array internally
- [[dotnet/csharp/csharp-collections-dictionary.md]] — O(1) key-based lookup vs O(n) linear scan
- [[dotnet/csharp/csharp-linq-basics.md]] — LINQ operators work on `IEnumerable<T>` and are the primary query API for lists

---

## Source

[List\<T\> — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.list-1)

---
*Last updated: 2026-04-06*