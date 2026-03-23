# C# Collections — Dictionary<TKey, TValue>

> `Dictionary<TKey, TValue>` is a hash table that maps unique keys to values, giving O(1) average-case lookup, insert, and delete by key.

---

## When To Use It
Use a dictionary when you need to find, add, or remove items by a key rather than by position. The canonical cases are caches, lookup tables, grouping data by category, and counting occurrences. Don't use it when you just need an ordered sequence — that's `List<T>`. Don't use it when you only care about whether a value exists with no associated data — that's `HashSet<T>`, which is faster and uses less memory for membership checks.

---

## Core Concept
A dictionary is a hash table under the hood. When you insert a key, it runs `GetHashCode()` on the key to compute a bucket index, then stores the key-value pair in that bucket. On lookup, it hashes the key again to find the right bucket, then uses `Equals` to confirm the match within the bucket. When too many items land in the same bucket (a collision), lookup degrades — but a good hash function keeps collisions rare and average case stays O(1). The entire contract depends on two rules: keys must be unique, and a key's hash code must not change while it's in the dictionary.

---

## The Code

**Basic operations**
```csharp
var scores = new Dictionary<string, int>
{
    ["Alice"] = 95,
    ["Bob"]   = 82
};

scores["Charlie"] = 74;           // add new key
scores["Alice"] = 97;             // update existing key

Console.WriteLine(scores["Alice"]);   // 97 — O(1) lookup
Console.WriteLine(scores.Count);      // 3

scores.Remove("Bob");                 // O(1) remove
Console.WriteLine(scores.ContainsKey("Bob")); // False
```

**Safe access — avoiding `KeyNotFoundException`**
```csharp
var config = new Dictionary<string, string>
{
    ["host"] = "localhost",
    ["port"] = "5432"
};

// UNSAFE — throws KeyNotFoundException if key missing
string host = config["host"];

// SAFE — returns false, doesn't throw
if (config.TryGetValue("timeout", out string? timeout))
    Console.WriteLine($"Timeout: {timeout}");
else
    Console.WriteLine("timeout not set");

// Default if missing — using GetValueOrDefault (C# 7.4+)
string port = config.GetValueOrDefault("port", "3306");
```

**Iterating**
```csharp
var wordCount = new Dictionary<string, int>
{
    ["the"] = 42, ["quick"] = 7, ["brown"] = 3
};

// Iterate key-value pairs
foreach (var (word, count) in wordCount)
    Console.WriteLine($"{word}: {count}");

// Keys and values separately
foreach (string word in wordCount.Keys)
    Console.WriteLine(word);

foreach (int count in wordCount.Values)
    Console.WriteLine(count);
```

**Counting occurrences — common pattern**
```csharp
string[] words = { "apple", "banana", "apple", "cherry", "banana", "apple" };

var counts = new Dictionary<string, int>();

foreach (var word in words)
{
    // TryGetValue avoids double-lookup vs ContainsKey + indexer
    if (counts.TryGetValue(word, out int current))
        counts[word] = current + 1;
    else
        counts[word] = 1;
}

// Modern shorthand with GetValueOrDefault
foreach (var word in words)
    counts[word] = counts.GetValueOrDefault(word) + 1;
```

**`ConcurrentDictionary` for thread-safe scenarios**
```csharp
var cache = new ConcurrentDictionary<int, string>();

cache.TryAdd(1, "one");

// GetOrAdd is atomic — only calls the factory if key is missing
string val = cache.GetOrAdd(2, key => $"computed_{key}");

// AddOrUpdate — read-modify-write in one call
cache.AddOrUpdate(
    key: 1,
    addValue: "one",
    updateValueFactory: (key, existing) => existing + "_updated"
);
```

---

## Gotchas

- **Using a mutable object as a key is a silent disaster.** If you insert a key and then mutate it in a way that changes its `GetHashCode()`, the dictionary will look in the wrong bucket on the next lookup and return nothing — no exception, just `false` from `ContainsKey`. Strings and value types are safe because they're either immutable or hash by value. Custom classes used as keys must have stable, immutable hash inputs.
- **`dictionary[key]` throws `KeyNotFoundException` — not `null`, not `-1`.** Every beginner gets this once. The exception message includes the key type but not the key value, which makes debugging harder. Use `TryGetValue` by default unless you're certain the key exists and want an error if it doesn't.
- **Iteration order is not insertion order.** `Dictionary<TKey, TValue>` makes no guarantees about enumeration order. If order matters, use `SortedDictionary<TKey, TValue>` (O(log n) operations, sorted by key) or `List<KeyValuePair<K,V>>` with a sort. An informal observation that iteration tends to follow insertion order in practice is an implementation detail, not a contract — don't rely on it.
- **`ContainsKey` followed by indexer is a double-lookup.** `if (dict.ContainsKey(k)) return dict[k]` hashes the key twice. `TryGetValue` does it once. In tight loops over large dictionaries this is a measurable difference.
- **Default initial capacity is 0 and growth causes rehashing.** When the load factor threshold is exceeded, the dictionary allocates a larger internal array and re-inserts every existing entry. If you know you'll be inserting ~10,000 items, `new Dictionary<K,V>(10000)` avoids several intermediate rehashes and is meaningfully faster for bulk inserts.

---

## Interview Angle
**What they're really testing:** Whether you understand hash table mechanics — how keys map to buckets, what makes a good key, and what breaks O(1) performance.

**Common question form:** "How does a dictionary work internally?" or "What are the requirements for a dictionary key?" or "What's the time complexity of a dictionary lookup?"

**The depth signal:** A junior says "lookup is O(1) because it uses a hash." A senior explains the full picture: `GetHashCode()` maps the key to a bucket, `Equals` confirms the match within the bucket, and O(1) is an average case — worst case is O(n) when all keys collide into one bucket. They'll explain why mutable keys are dangerous (hash changes, wrong bucket), articulate the `Equals`/`GetHashCode` contract (equal objects must have equal hashes), and know that `ConcurrentDictionary` exists for thread safety but comes with its own atomicity gotchas — `GetOrAdd`'s factory can be called multiple times under contention even though only one value is stored.

---

## Related Topics
- [[dotnet/csharp-object-class.md]] — `Equals` and `GetHashCode` on `object` are the exact methods the dictionary depends on for every key operation.
- [[dotnet/csharp-collections-hashset.md]] — `HashSet<T>` is essentially a dictionary with no values; same hash table mechanics, less memory, for membership-only use cases.
- [[dotnet/csharp-collections-list.md]] — The ordered-by-position counterpart; understanding when to use each is a core data structure decision.
- [[dotnet/csharp-linq.md]] — LINQ's `GroupBy`, `ToDictionary`, and `ToLookup` all produce dictionary-like structures; they're built on the same key-hashing model.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.dictionary-2](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.dictionary-2)

---
*Last updated: 2026-03-23*