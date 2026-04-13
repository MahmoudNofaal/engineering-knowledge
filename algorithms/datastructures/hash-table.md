# Hash Table

> A data structure that maps keys to values using a hash function, giving O(1) average-case lookup, insert, and delete.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Key-value store via hash function + array |
| **Use when** | O(1) lookup, counting, deduplication by key |
| **Avoid when** | Sorted order, range queries, or worst-case O(1) needed |
| **C# version** | C# 2.0 (`Dictionary<TKey, TValue>`) |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `Dictionary<TKey,TValue>`, `HashSet<T>`, `ConcurrentDictionary<TKey,TValue>` |

---

## When To Use It

Use a hash table any time you need to look up, count, or deduplicate by a key in O(1). It's the single most common structure for trading space for time — the go-to when a nested loop is too slow. If you find yourself writing "check if this value has been seen before" or "count how many times each X appears," you want a hash table.

Avoid it when you need sorted order or range queries — a `SortedDictionary<TKey, TValue>` (backed by a Red-Black tree) gives O(log n) with key ordering. Avoid it when you need guaranteed worst-case O(1) — hash tables are average-case O(1) and degrade to O(n) under adversarial input or a poor hash function. Avoid it when keys are not hashable (mutable objects in Python, unhashable types in C#).

---

## Core Concept

A hash function takes a key and maps it to an integer index in an array of buckets. Ideally each key maps to a unique bucket, giving O(1) access. In practice, two different keys can hash to the same bucket — a **collision**. There are two standard resolution strategies:

**Chaining:** Each bucket holds a linked list of entries. On collision, the new entry is appended to the list. Lookup scans the list. Works well at high load factors because buckets grow rather than displacing each other.

**Open addressing:** All entries live directly in the array. On collision, probe to the next open slot (linear, quadratic, or pseudo-random probing). Lookup follows the same probe sequence. Better cache locality than chaining but degrades faster at high load.

.NET's `Dictionary<TKey, TValue>` uses **chaining with an array of linked "entry" structs** — the chains are not heap-allocated linked lists but compact struct arrays, giving better cache behaviour than classical chaining. The load factor limit is approximately 1.0; when exceeded the table resizes (doubles) and rehashes all entries — O(n) occasionally, O(1) amortised.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | `Hashtable` — non-generic, keys and values as `object`, boxing required |
| C# 2.0 | .NET 2.0 | `Dictionary<TKey,TValue>` and `HashSet<T>` — generic, type-safe, no boxing |
| C# 4.0 | .NET 4.0 | `ConcurrentDictionary<TKey,TValue>` — thread-safe, lock striping |
| C# 6.0 | .NET 4.6 | Dictionary initialiser syntax: `new Dictionary<K,V> { ["key"] = value }` |
| C# 9.0 | .NET 5 | `Dictionary<TKey,TValue>` optimised for `string` keys via randomised hash seed |
| C# 12.0 | .NET 8 | Collection expressions unify dictionary literals; `FrozenDictionary<K,V>` for read-only |

*In .NET 5+, string hash codes are randomised per process startup to prevent hash-flooding attacks. This means string-keyed dictionaries produce different iteration orders each run — never rely on that order.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Lookup by key | O(1) average | O(n) worst case on all-collision input |
| Insert | O(1) amortised | Occasional O(n) resize-and-rehash |
| Delete | O(1) average | Marks slot as deleted; compaction deferred |
| Iterate | O(n) | Visits all buckets — order is unspecified |
| Contains key | O(1) average | Same as lookup |

**Allocation behaviour:** `Dictionary<TKey, TValue>` allocates a single `Entry[]` struct array on the managed heap plus a `int[]` for bucket indices. Entries are value types (struct), so key-value pairs are stored inline — no per-entry heap allocation. Growing the table triggers one `Array.Copy`-based rehash.

**Benchmark notes:** For small dictionaries (under ~20 entries), the overhead of hashing can make a simple linear scan over a `List<(K,V)>` faster due to better cache behaviour. Above that threshold, the hash table wins decisively. For extreme read-heavy workloads on a fixed dataset, `FrozenDictionary<K,V>` (.NET 8) pre-computes an optimal layout and is measurably faster on lookup at the cost of immutability.

---

## The Code

**Frequency counting — most common pattern**
```csharp
var freq = new Dictionary<string, int>();
string[] words = { "the", "cat", "sat", "on", "the", "mat", "the" };

foreach (string word in words)
{
    freq[word] = freq.GetValueOrDefault(word) + 1;   // cleaner than ContainsKey
}

// Top entry
var (topWord, count) = freq.MaxBy(kv => kv.Value);
Console.WriteLine($"{topWord}: {count}");   // the: 3
```

**Two-sum — O(n) with a hash map**
```csharp
public static (int i, int j) TwoSum(int[] nums, int target)
{
    var seen = new Dictionary<int, int>();  // value → index

    for (int i = 0; i < nums.Length; i++)
    {
        int complement = target - nums[i];
        if (seen.TryGetValue(complement, out int j))
            return (j, i);
        seen.TryAdd(nums[i], i);   // TryAdd won't overwrite if duplicate
    }
    return (-1, -1);
}
// TwoSum([2, 7, 11, 15], 9) → (0, 1)
```

**Grouping — group anagrams**
```csharp
public static List<List<string>> GroupAnagrams(string[] words)
{
    var groups = new Dictionary<string, List<string>>();

    foreach (string word in words)
    {
        char[] chars = word.ToCharArray();
        Array.Sort(chars);
        string key = new string(chars);   // sorted chars = canonical anagram key

        if (!groups.TryGetValue(key, out var group))
        {
            group = new List<string>();
            groups[key] = group;
        }
        group.Add(word);
    }
    return new List<List<string>>(groups.Values);
}
// GroupAnagrams(["eat","tea","tan","ate","nat","bat"])
// → [["eat","tea","ate"], ["tan","nat"], ["bat"]]
```

**What NOT to do — and the fix**
```csharp
// BAD: ContainsKey + indexer = two lookups
if (dict.ContainsKey(key))
    return dict[key];             // hashes key twice

// GOOD: TryGetValue = one lookup
if (dict.TryGetValue(key, out var value))
    return value;

// ALSO BAD: mutating a dictionary while iterating it throws
foreach (var kv in dict)
    dict.Remove(kv.Key);          // InvalidOperationException

// GOOD: collect keys first, then remove
var keysToRemove = dict.Keys.Where(k => ShouldRemove(k)).ToList();
foreach (var k in keysToRemove)
    dict.Remove(k);
```

---

## Real World Example

A real-time analytics service receives a stream of user events (page views, clicks, purchases) and needs to answer "how many unique users performed action X in the last 5 minutes?" for hundreds of action types simultaneously. The naive approach — a list of events scanned on every query — is O(events × query_count). A two-level dictionary (action → `HashSet<userId>`) reduces each query to a single `HashSet.Count` call.

```csharp
public class ActionTracker
{
    // action → set of unique user IDs who performed it
    private readonly Dictionary<string, HashSet<string>> _uniqueUsers = new();
    // action → queue of (userId, timestamp) for expiry
    private readonly Dictionary<string, Queue<(string userId, DateTime at)>> _expiry = new();
    private readonly TimeSpan _window;

    public ActionTracker(TimeSpan window) => _window = window;

    public void Record(string action, string userId)
    {
        if (!_uniqueUsers.ContainsKey(action))
        {
            _uniqueUsers[action] = new HashSet<string>();
            _expiry[action]      = new Queue<(string, DateTime)>();
        }
        _uniqueUsers[action].Add(userId);
        _expiry[action].Enqueue((userId, DateTime.UtcNow));
    }

    public int UniqueUsersFor(string action)
    {
        Expire(action);
        return _uniqueUsers.TryGetValue(action, out var set) ? set.Count : 0;
    }

    private void Expire(string action)
    {
        if (!_expiry.TryGetValue(action, out var q)) return;
        var cutoff = DateTime.UtcNow - _window;
        while (q.Count > 0 && q.Peek().at < cutoff)
        {
            var (userId, _) = q.Dequeue();
            // Only remove from the set if no later event for same user exists
            if (q.All(e => e.userId != userId))
                _uniqueUsers[action].Remove(userId);
        }
    }
}
```

*The key insight is that the outer `Dictionary` gives O(1) routing to the right action's data, and the inner `HashSet` gives O(1) deduplication — the combination answers "unique users per action" without ever scanning the full event stream.*

---

## Common Misconceptions

**"Dictionary iteration order is insertion order in C#"**
It's not guaranteed. Unlike Python 3.7+ where dict preserves insertion order by spec, C#'s `Dictionary<TKey, TValue>` makes no ordering guarantees. Iteration order is implementation-defined and may change between .NET versions or after a resize. If you need insertion order, use a separate `List<TKey>` alongside the dictionary, or use a sorted structure.

**"O(1) means fast"**
O(1) means the time doesn't grow with n — it doesn't mean the constant is small. A hash table lookup involves: compute hash, modulo to bucket index, scan the collision chain. For a `string` key, the hash involves touching every character. For small collections, a linear scan over a `List<(K,V)>` is often faster because of better cache behaviour. Profile, don't assume.

**"HashSet<T> and Dictionary<TKey,TValue> are different data structures"**
Internally they're the same thing. `HashSet<T>` is a `Dictionary<T, bool>` without the value — it's purely an existence check table. The API surface differs but the underlying hash table machinery is identical. Knowing this means you can reason about `HashSet<T>` performance exactly as you would `Dictionary<TKey,TValue>`.

---

## Gotchas

- **Custom types used as keys must implement `GetHashCode` and `Equals` consistently.** The contract: if `a.Equals(b)`, then `a.GetHashCode() == b.GetHashCode()`. Violating this causes lost entries — you insert with one hash, look up with another, and get a miss. Always override both together, never one without the other.

- **Mutable keys break the invariant silently.** If you mutate a key after insertion, its hash code changes but the bucket assignment doesn't. The entry becomes unreachable — the dictionary "loses" it. Never mutate an object that's being used as a dictionary key.

- **String hash codes are randomised per process in .NET 5+.** Two runs of the same program produce different hash values for the same strings. Don't persist or compare hash codes across process boundaries.

- **`ContainsKey` + `[]` indexer is two hash computations.** Always use `TryGetValue` for conditional lookup. Similarly, `GetValueOrDefault(key)` or `dict.TryAdd(key, value)` are single-lookup alternatives to the pattern of checking first then writing.

- **`ConcurrentDictionary` is not always the right thread-safe choice.** It's lock-striped (good for high-concurrency reads and independent key updates), but `AddOrUpdate` and `GetOrAdd` callbacks are not atomic — they can execute multiple times under contention. For atomic compound operations, you still need external locking.

---

## Interview Angle

**What they're really testing:** Whether you instinctively reach for a hash map to convert a nested loop into a single pass — the space-for-time trade is one of the most fundamental optimisation moves in algorithm problems.

**Common question forms:**
- "Two sum" (O(n²) → O(n) with a hash map)
- "Group anagrams" (canonical key → group mapping)
- "Longest substring without repeating characters" (sliding window + char-to-index map)
- "Find all duplicates in an array"
- "Subarray sum equals k" (prefix sum + hash map)

**The depth signal:** A junior uses a nested loop and gets O(n²). A senior immediately asks "can I use a hash map?" and restructures to a single pass. The next level: a senior can explain what happens under the hood — hash function, collision resolution (chaining vs open addressing), load factor — and knows why you use `TryGetValue` instead of `ContainsKey + []`. The elite signal is `GetHashCode`/`Equals` contract knowledge and awareness of the randomised hash seed in .NET 5+.

**Follow-up questions to expect:**
- "What's the worst-case complexity and when does it occur?" (O(n) — all keys collide, one bucket becomes a linear list)
- "How would you implement a hash map from scratch?" (Array of buckets, chaining, resize at load factor threshold)
- "What's the difference between HashMap and TreeMap in Java?" (O(1) vs O(log n), unordered vs sorted — same trade-off as `Dictionary` vs `SortedDictionary` in C#)

---

## Related Topics

- [[algorithms/datastructures/array.md]] — The backing data structure inside every hash table; hash tables are arrays with clever indexing.
- [[algorithms/datastructures/balanced-bst.md]] — The ordered alternative: O(log n) but supports range queries and sorted iteration.
- [[algorithms/datastructures/linked-list.md]] — Chaining resolution uses linked lists per bucket to handle collisions.
- [[algorithms/patterns/sliding-window.md]] — Sliding window problems frequently pair a window with a hash map tracking window contents.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.dictionary-2

---

*Last updated: 2026-04-12*