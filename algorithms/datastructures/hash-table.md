# Hash Table

> A data structure that maps keys to values using a hash function, providing O(1) average-case insertion, deletion, and lookup — at the cost of O(n) extra space.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Key-value store with O(1) average lookup via hashing |
| **Use when** | Fast lookup by key, frequency counting, deduplication |
| **Avoid when** | Ordered iteration needed; worst-case O(1) required (use BST or sorted dict) |
| **C# version** | `Hashtable` C# 1.0; `Dictionary<K,V>` C# 2.0; `HashSet<T>` C# 2.0 |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `Dictionary<TKey, TValue>`, `HashSet<T>`, `ConcurrentDictionary<K,V>` |

---

## When To Use It

Use a hash table whenever you need O(1) lookup by key — frequency counting, grouping, memoization, two-sum complement checking, deduplication, and caching. It's the single most impactful data structure for converting O(n²) brute-force solutions to O(n). Don't use it when you need keys in sorted order (use `SortedDictionary<K,V>`) or when worst-case O(1) is required (adversarial hash collisions can degrade to O(n) — use a tree-based map for those cases).

---

## Core Concept

A hash table stores key-value pairs in an array of "buckets." To store or retrieve a key, compute `hash(key) % bucketCount` to find the bucket index. Collisions (two keys mapping to the same bucket) are resolved by either **chaining** (each bucket holds a linked list of entries) or **open addressing** (probe for the next empty slot).

C#'s `Dictionary<K,V>` uses open addressing with a mix of techniques. The load factor (entries / buckets) is kept below ~0.72 — when exceeded, the table is resized to roughly double capacity and all keys are rehashed. This rehash is O(n) but amortised O(1) per insertion.

The quality of `GetHashCode()` determines performance. A poor hash function that returns the same value for all keys degrades every operation to O(n) — all keys land in the same bucket, turning lookup into a linear scan.

---

## Algorithm History

| Year | Development |
|---|---|
| 1953 | Hans Peter Luhn (IBM) proposes hashing for symbol tables |
| 1956 | Arnold Dumey popularises the concept in "Computers and Automation" |
| 1968 | Donald Knuth analyses hashing formally in TAOCP |
| 1998 | C# 1.0 ships `Hashtable` (non-generic, object keys) |
| 2005 | C# 2.0 generics: `Dictionary<K,V>` and `HashSet<T>` |
| 2010 | .NET 4.0 adds `ConcurrentDictionary<K,V>` for thread-safe access |
| 2012 | .NET randomises string hash seeds per-process to prevent hash-flooding DoS attacks |

---

## Performance

| Operation | Average | Worst Case | Notes |
|---|---|---|---|
| Lookup `dict[key]` | O(1) | O(n) | Worst case on hash collision flood |
| Insert | O(1) amortised | O(n) | O(n) on resize; amortised O(1) |
| Delete | O(1) | O(n) | |
| Contains key | O(1) | O(n) | |
| Iteration | O(n) | O(n) | No guaranteed order |
| Memory | O(n) | O(n) | ~1.3–2× overhead vs raw data |

**Allocation behaviour:** `Dictionary<K,V>` allocates an internal array of `Entry` structs. Each `Entry` holds the hash code, key, value, and a next-bucket pointer. Pre-sizing with `new Dictionary<K,V>(expectedCount)` avoids rehash resizes.

**Benchmark notes:** `Dictionary<K,V>` is ~3–5× slower than array index access for lookups (hash computation + bucket traversal vs direct memory address). For integer keys in a known range, an array outperforms a dictionary. The dictionary advantage is when keys are sparse or non-integer.

---

## The Code

**Scenario 1 — frequency count and two-sum pattern**
```csharp
// Frequency count — O(n) time, O(k) space where k = distinct values
public Dictionary<char, int> CharFrequency(string s)
{
    var freq = new Dictionary<char, int>();
    foreach (char c in s)
        freq[c] = freq.GetValueOrDefault(c) + 1;
    return freq;
}

// Two-sum — O(n) using complement lookup
public (int, int) TwoSum(int[] nums, int target)
{
    var seen = new Dictionary<int, int>(); // value → index
    for (int i = 0; i < nums.Length; i++)
    {
        int complement = target - nums[i];
        if (seen.TryGetValue(complement, out int j))
            return (j, i);
        seen[nums[i]] = i;
    }
    return (-1, -1);
}
```

**Scenario 2 — grouping and memoization**
```csharp
// Group anagrams — O(n × k log k) where k = average string length
public List<List<string>> GroupAnagrams(string[] words)
{
    var groups = new Dictionary<string, List<string>>();
    foreach (string word in words)
    {
        char[] key = word.ToCharArray();
        Array.Sort(key);                       // canonical form — O(k log k)
        string canonical = new string(key);
        if (!groups.ContainsKey(canonical))
            groups[canonical] = new List<string>();
        groups[canonical].Add(word);
    }
    return groups.Values.ToList();
}

// Memoization cache for recursive Fibonacci
private Dictionary<int, long> _fibCache = new() { [0] = 0, [1] = 1 };
public long Fib(int n)
{
    if (_fibCache.TryGetValue(n, out long cached)) return cached;
    return _fibCache[n] = Fib(n - 1) + Fib(n - 2);
}
```

**Scenario 3 — custom GetHashCode for composite keys**
```csharp
// Using ValueTuple as a composite key — tuple implements GetHashCode correctly
var grid = new Dictionary<(int Row, int Col), char>();
grid[(0, 0)] = 'X';
grid[(1, 2)] = 'O';
Console.WriteLine(grid[(0, 0)]); // 'X'

// Custom record key — record auto-generates GetHashCode from all properties
public record Point(int X, int Y); // GetHashCode and Equals auto-generated
var pointMap = new Dictionary<Point, string>();
pointMap[new Point(3, 4)] = "origin";
Console.WriteLine(pointMap[new Point(3, 4)]); // "origin" — value equality works
```

**Scenario 4 — what NOT to do: mutable keys**
```csharp
// BAD: mutable object as a key — GetHashCode changes after mutation → key is "lost"
public class MutableKey { public int Value { get; set; } }
var dict = new Dictionary<MutableKey, string>();
var key = new MutableKey { Value = 1 };
dict[key] = "found";
key.Value = 2;                   // mutate the key AFTER inserting
Console.WriteLine(dict.ContainsKey(key)); // FALSE — hash changed, key is orphaned in wrong bucket

// GOOD: use immutable keys — strings, int, record types, or ValueTuple
var immutableDict = new Dictionary<(int, int), string>();
immutableDict[(1, 2)] = "found";
// (1, 2) is immutable — hash never changes after insertion
```

---

## Real World Example

The `SessionCacheService` in a web API stores active user sessions. Each request looks up the session by token — an O(1) operation with a `Dictionary`. Under peak load (50,000 concurrent sessions, 10,000 requests/second), the previous implementation used a sorted list (O(log n) lookup, 0.013ms per lookup). The dictionary replacement is O(1) average (0.0001ms). At 10,000 req/s, that's 129ms vs 1ms of CPU time per second just on session lookups.

```csharp
public class SessionCacheService
{
    private readonly Dictionary<string, UserSession> _sessions = new(capacity: 60_000);
    private readonly TimeSpan _sessionTimeout;
    private readonly object _lock = new(); // simple lock for demo; use ConcurrentDictionary in prod

    public SessionCacheService(TimeSpan sessionTimeout)
        => _sessionTimeout = sessionTimeout;

    // O(1) average — hash lookup by token string
    public UserSession? GetSession(string token)
    {
        lock (_lock)
        {
            if (!_sessions.TryGetValue(token, out var session)) return null;
            if (DateTimeOffset.UtcNow - session.LastAccessed > _sessionTimeout)
            {
                _sessions.Remove(token); // evict expired — O(1)
                return null;
            }
            session.LastAccessed = DateTimeOffset.UtcNow;
            return session;
        }
    }

    // O(1) amortised — inserts or overwrites
    public void SetSession(string token, UserSession session)
    {
        lock (_lock)
            _sessions[token] = session;
    }

    // O(n) — evicts all expired sessions; run periodically, not per-request
    public int EvictExpired()
    {
        lock (_lock)
        {
            var cutoff = DateTimeOffset.UtcNow - _sessionTimeout;
            var expired = _sessions
                .Where(kv => kv.Value.LastAccessed < cutoff)
                .Select(kv => kv.Key)
                .ToList();
            foreach (var key in expired) _sessions.Remove(key);
            return expired.Count;
        }
    }

    public record UserSession(int UserId, string Role, DateTimeOffset CreatedAt)
    {
        public DateTimeOffset LastAccessed { get; set; } = CreatedAt;
    }
}
```

*The key insight: pre-sizing with `capacity: 60_000` prevents any rehash resize during steady-state operation. Resizes are O(n) and cause latency spikes — in a high-traffic API, even one spike during peak load is visible in p99 latency metrics.*

---

## Common Misconceptions

**"Dictionary lookup is always O(1)"**
Average case is O(1). Worst case is O(n) when many keys hash to the same bucket (a hash collision attack). .NET mitigates this with per-process hash randomisation for strings, but integer keys or custom types with poor `GetHashCode` implementations can still degrade. For security-sensitive code with external keys, use `ConcurrentDictionary` with a randomised seed or validate inputs.

**"Dictionary iteration order is random"**
In .NET, `Dictionary<K,V>` preserves insertion order for iterations in practice (CPython-like since .NET Core 3.0), but this is an implementation detail, not a contract. Never rely on it. If you need ordered iteration, use `SortedDictionary<K,V>` (by key) or maintain a separate `List<K>` for insertion-order guarantees.

**"GetHashCode being equal means the keys are equal"**
No — equal hash codes only mean the keys are in the same bucket. Two different keys can have the same hash code (collision). `Equals` is always called to confirm identity after the hash match. Equal `GetHashCode` does NOT imply equal objects; equal objects MUST have equal `GetHashCode`.

---

## Gotchas

- **Never mutate a key after inserting it.** The key's hash code determines its bucket. Mutating the key changes its hash, orphaning it in the wrong bucket — `ContainsKey` returns false even though the entry exists.

- **`dict[key]` throws `KeyNotFoundException`; `TryGetValue` doesn't.** Always use `TryGetValue` in code that handles missing keys gracefully. The `[]` indexer is only safe when you're certain the key exists.

- **Custom types need both `GetHashCode` and `Equals` overridden together.** If two objects are `Equals`, they must return the same `GetHashCode`. Breaking this contract silently breaks dictionary and `HashSet` behaviour.

- **`HashSet<T>` vs `List<T>.Contains`.** Both check membership. `HashSet.Contains` is O(1); `List.Contains` is O(n). Use `HashSet` for membership tests. Use `List` when order matters or duplicates are needed.

- **`ConcurrentDictionary` is thread-safe but not atomic for multi-step operations.** `AddOrUpdate` and `GetOrAdd` are atomic per-call. A read followed by a write is not atomic — use `AddOrUpdate` for "check then insert" patterns in concurrent contexts.

---

## Interview Angle

**What they're really testing:** Whether you reach for a hash map to convert O(n) lookups to O(1), and whether you know the implementation details that affect correctness.

**Common question forms:**
- "Two-sum — find two numbers that add to target."
- "Group anagrams."
- "Find the first non-repeating character."
- "Longest substring without repeating characters."
- "Design an LRU cache."

**The depth signal:** A junior uses a dictionary correctly. A senior pre-sizes it, uses `TryGetValue` over `[]`, knows the `GetHashCode`/`Equals` contract, and can explain why mutable keys break the invariant. They also know `Dictionary` preserves insertion order in .NET but that relying on it is an antipattern.

**Follow-up questions to expect:**
- "What happens with hash collisions?" → Chaining (each bucket is a linked list) or open addressing (probe for next empty slot). C# uses open addressing internally.
- "When would you use `SortedDictionary` over `Dictionary`?" → When you need O(log n) ordered iteration or range queries by key. `Dictionary` is O(1) unordered; `SortedDictionary` is O(log n) but maintains sorted key order.

---

## Related Topics

- [[algorithms/datastructures/array.md]] — The underlying storage of a hash table's bucket array.
- [[algorithms/patterns/sliding-window.md]] — Variable-size windows use a frequency map (Dictionary) to track window state.
- [[algorithms/patterns/dynamic-programming.md]] — Top-down memoization uses a Dictionary as the memo table.
- [[algorithms/datastructures/balanced-bst.md]] — The ordered alternative when sorted key iteration is needed.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.dictionary-2

---

*Last updated: 2026-04-21*