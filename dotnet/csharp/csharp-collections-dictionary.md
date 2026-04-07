# C# Collections — Dictionary\<TKey, TValue\>

> A hash table that maps unique keys to values — O(1) average lookup, insert, and delete by key. The go-to structure whenever you need to find something by a key rather than by position.

---

## Quick Reference

| Operation | Average | Worst case |
|---|---|---|
| `Add` / `this[key] =` | O(1) | O(n) — all keys collide |
| `TryGetValue` / `this[key]` | O(1) | O(n) |
| `Remove` | O(1) | O(n) |
| `ContainsKey` | O(1) | O(n) |
| `Count` | O(1) | — |
| Iteration | O(n) | — |

---

## When To Use It

Use a dictionary when you need to find, add, or remove items by a key rather than by position. The canonical cases: caches, lookup tables, grouping data by category, counting occurrences, mapping IDs to objects.

Don't use it when you just need an ordered sequence (`List<T>`), or when you only care about whether a value exists with no associated data (`HashSet<T>`).

---

## Core Concept

A dictionary is a hash table. On insert, it runs `GetHashCode()` on the key to compute a bucket index, then stores the key-value pair in that bucket. On lookup, it hashes the key again to find the right bucket, then uses `Equals` to confirm the match within the bucket.

The entire contract depends on two rules:
1. **Keys must be unique** — adding a duplicate key throws (or overwrites with the indexer)
2. **A key's hash code must not change while it's in the dictionary** — mutable keys that change their hash break lookups silently

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 2.0 | .NET 2.0 | `Dictionary<K,V>` introduced (replaced `Hashtable`) |
| C# 3.0 | .NET 3.5 | Collection initializer: `new Dictionary<K,V> { {"a", 1} }` |
| C# 6.0 | .NET 4.6 | Index initializer: `new Dictionary<K,V> { ["a"] = 1 }` |
| .NET Core 2.0 | — | `GetValueOrDefault` extension |
| .NET 6 | — | `TryAdd` on the instance itself |

---

## Performance

**Allocation behaviour:** One backing array allocation. Growing triggers rehash of all entries. Pre-sizing with `new Dictionary<K,V>(capacity)` prevents intermediate rehashes for large known sets.

**Load factor:** The dictionary rehashes when the load factor (entries/buckets) exceeds a threshold (~0.72). A good hash function keeps collisions rare and average case stays O(1). A pathological hash function (all keys return the same hash) degrades to O(n) for every operation.

---

## The Code

**Basic operations and safe access**
```csharp
var scores = new Dictionary<string, int>
{
    ["Alice"] = 95,
    ["Bob"]   = 82
};

scores["Charlie"] = 74;   // add new key
scores["Alice"]   = 97;   // update existing key

Console.WriteLine(scores["Alice"]);         // 97
Console.WriteLine(scores.ContainsKey("Bob")); // true
scores.Remove("Bob");

// SAFE: TryGetValue — never throws on missing key
if (scores.TryGetValue("Alice", out int score))
    Console.WriteLine($"Score: {score}");
else
    Console.WriteLine("Not found");

// Default if missing
int val = scores.GetValueOrDefault("Dave", -1); // -1 if not found
```

**Counting occurrences — idiomatic pattern**
```csharp
string[] words = { "apple", "banana", "apple", "cherry", "banana", "apple" };

var counts = new Dictionary<string, int>();
foreach (var word in words)
    counts[word] = counts.GetValueOrDefault(word) + 1;

// Or with TryGetValue for a single lookup per word
foreach (var word in words)
{
    if (counts.TryGetValue(word, out int current))
        counts[word] = current + 1;
    else
        counts[word] = 1;
}
```

**Iteration**
```csharp
foreach (var (key, value) in scores)    // deconstruct KeyValuePair
    Console.WriteLine($"{key}: {value}");

foreach (string key in scores.Keys)     // keys only
    Console.WriteLine(key);

foreach (int val in scores.Values)     // values only
    Console.WriteLine(val);
```

**`ConcurrentDictionary` for thread-safe scenarios**
```csharp
var cache = new ConcurrentDictionary<int, string>();

// GetOrAdd is atomic — only calls factory if key missing
string v = cache.GetOrAdd(1, key => $"computed_{key}");

// AddOrUpdate — atomic read-modify-write
cache.AddOrUpdate(
    key: 1,
    addValue: "new",
    updateValueFactory: (key, existing) => existing + "_updated");

cache.TryRemove(1, out _);
```

---

## Real World Example

An order lookup service builds an in-memory index from a database load. A dictionary enables O(1) lookup by order ID while an inverted index supports customer lookups.

```csharp
public class OrderIndex
{
    private readonly Dictionary<Guid, Order> _byId;
    private readonly Dictionary<string, List<Order>> _byCustomer;

    public OrderIndex(IEnumerable<Order> orders)
    {
        var list = orders.ToList();
        _byId       = new Dictionary<Guid, Order>(list.Count);
        _byCustomer = new Dictionary<string, List<Order>>(StringComparer.OrdinalIgnoreCase);

        foreach (var order in list)
        {
            _byId[order.Id] = order;

            if (!_byCustomer.TryGetValue(order.CustomerEmail, out var customerOrders))
            {
                customerOrders = new List<Order>();
                _byCustomer[order.CustomerEmail] = customerOrders;
            }
            customerOrders.Add(order);
        }
    }

    public Order? Find(Guid id)
        => _byId.GetValueOrDefault(id);

    public IReadOnlyList<Order> FindByCustomer(string email)
        => _byCustomer.TryGetValue(email, out var orders)
            ? orders.AsReadOnly()
            : Array.Empty<Order>();
}
```

*The key insight: `_byCustomer` uses `StringComparer.OrdinalIgnoreCase` so `"alice@example.com"` and `"Alice@Example.COM"` resolve to the same bucket. The dictionary constructor accepts a custom `IEqualityComparer<TKey>` precisely for this use case.*

---

## Common Misconceptions

**"Iteration order is insertion order"**
`Dictionary<K,V>` makes no guarantee about enumeration order. It's determined by bucket layout, which depends on hash values and capacity. Use `SortedDictionary<K,V>` for sorted key order, or `List<KeyValuePair<K,V>>` with a sort if you need insertion order (or just use a `List<T>` of tuples).

**"`ContainsKey` followed by indexer is safe"**
It's correct but inefficient — two hash lookups. Use `TryGetValue` to get the value in one lookup: `if (dict.TryGetValue(key, out var val)) Use(val);`.

---

## Gotchas

- **`dictionary[key]` throws `KeyNotFoundException`, not returns null.** Always use `TryGetValue` or `GetValueOrDefault` for keys that might be absent.
- **Mutable objects as keys are a silent disaster.** If you insert a key then mutate it (changing its `GetHashCode()`), the dictionary looks in the wrong bucket on the next lookup. Strings and value types are safe; custom classes used as keys need stable, immutable hash inputs.
- **`ContainsKey` then indexer is a double-lookup.** Use `TryGetValue` — it does one lookup.
- **Default initial capacity triggers multiple resizes.** If you know you'll insert ~10,000 items, `new Dictionary<K,V>(10000)` avoids several intermediate rehashes.

---

## Interview Angle

**What they're really testing:** Whether you understand hash table mechanics — how keys map to buckets, what makes a good key, what breaks O(1) performance.

**Common question forms:**
- "How does a dictionary work internally?"
- "What are the requirements for a dictionary key?"
- "What's the time complexity of a dictionary lookup?"

**The depth signal:** A senior explains the full picture: `GetHashCode()` maps the key to a bucket, `Equals` confirms the match within the bucket, O(1) is average case — worst case is O(n) when all keys collide. They explain why mutable keys are dangerous, articulate the `Equals`/`GetHashCode` contract, and know that `ConcurrentDictionary.GetOrAdd`'s factory can run multiple times under contention.

---

## Related Topics

- [[dotnet/csharp/csharp-object-class.md]] — `Equals` and `GetHashCode` on `object` are the exact methods the dictionary depends on
- [[dotnet/csharp/csharp-collections-hashset.md]] — `HashSet<T>` is a dictionary with no values; same mechanics, less memory
- [[dotnet/csharp/csharp-concurrent-collections.md]] — `ConcurrentDictionary` for thread-safe scenarios

---

## Source

[Dictionary\<K,V\> — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.dictionary-2)

---
*Last updated: 2026-04-06*