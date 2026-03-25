# Hash Table
> A data structure that maps keys to values using a hash function, giving O(1) average-case lookup, insert, and delete.

---

## When To Use It
Use a hash table any time you need to look up, count, or deduplicate by a key in O(1). It's the single most common structure for trading space for time. Avoid it when you need sorted order, range queries, or worst-case O(1) guarantees — hash tables are average-case, and a sorted structure like a BST gives O(log n) with ordering support.

---

## Core Concept
A hash function takes a key and maps it to an index in an array. Ideally each key maps to a unique slot, giving O(1) access. In practice, two keys can hash to the same slot — a collision. The two standard fixes: chaining (each slot holds a linked list of colliding entries) and open addressing (probe for the next empty slot). Python's `dict` uses open addressing with pseudo-random probing. The hash table degrades to O(n) when collisions pile up, but a good hash function and a load factor limit (typically 0.75) keep this rare.

---

## The Code

**C# Dictionary — the standard hash table**
```csharp
var freq = new Dictionary<string, int>();
var items = new[] { "a", "b", "a", "c", "b", "a" };

foreach (var item in items)
{
    if (freq.ContainsKey(item))
        freq[item]++;
    else
        freq[item] = 1;  // O(1) average per operation
}

Console.WriteLine(string.Join(", ", freq));  // {'a': 3, 'b': 2, 'c': 1}
```

**Two-sum — O(n) with a hash map**
```csharp
public static (int, int) TwoSum(List<int> nums, int target)
{
    var seen = new Dictionary<int, int>();  // value → index
    for (int i = 0; i < nums.Count; i++)
    {
        int complement = target - nums[i];
        if (seen.ContainsKey(complement))
            return (seen[complement], i);
        if (!seen.ContainsKey(nums[i]))
            seen[nums[i]] = i;
    }
    return (-1, -1);
}
```

**Frequency count and grouping**
```csharp
using System.Linq;

// Count frequencies
var counter = new Dictionary<string, int>();
foreach (var item in new[] { "a", "b", "a", "c" })
{
    if (counter.ContainsKey(item))
        counter[item]++;
    else
        counter[item] = 1;
}
// Get most common 2
var mostCommon = counter.OrderByDescending(x => x.Value).Take(2);
foreach (var kvp in mostCommon)
    Console.WriteLine($"({kvp.Key}, {kvp.Value})");  // (a, 2), (b, 1)

// Group items by key
var groups = new Dictionary<char, List<string>>();
foreach (var word in new[] { "cat", "car", "bat", "can" })
{
    char key = word[0];
    if (!groups.ContainsKey(key))
        groups[key] = new List<string>();
    groups[key].Add(word);
}
// {'c': ['cat', 'car', 'can'], 'b': ['bat']}
```

**Implementing a basic hash table from scratch**
```csharp
public class HashTable
{
    private List<(string key, object value)>[] buckets;

    public HashTable(int size = 16)
    {
        buckets = new List<(string, object)>[size];
        for (int i = 0; i < size; i++)
            buckets[i] = new List<(string, object)>();
    }

    private int Hash(string key)
    {
        return key.GetHashCode() % buckets.Length;
    }

    public void Put(string key, object value)
    {
        var bucket = buckets[Hash(key)];
        for (int i = 0; i < bucket.Count; i++)
        {
            if (bucket[i].key == key)
            {
                bucket[i] = (key, value);  // update existing
                return;
            }
        }
        bucket.Add((key, value));  // new entry via chaining
    }

    public object Get(string key)
    {
        var bucket = buckets[Hash(key)];
        foreach (var (k, v) in bucket)
        {
            if (k == key)
                return v;
        }
        return null;
    }
}
```

---

## Gotchas

- **O(1) is average-case, not worst-case.** A deliberately crafted input that causes all keys to collide degrades to O(n). Python randomizes its hash seed at startup specifically to prevent algorithmic complexity attacks.
- **Mutable objects cannot be dictionary keys in Python.** Lists, sets, and dicts are unhashable. Use tuples. This trips people up when trying to use a list as a key for memoization.
- **Insertion order is preserved in Python 3.7+ dicts.** This is a language guarantee, not an implementation detail. But it does not make a dict a sorted structure — insertion order ≠ key order.
- **Load factor determines when rehashing occurs.** When the table is too full, every key must be rehashed into a larger array. This is O(n) and happens silently. Python manages this automatically, but it means that occasional insertions cost more than O(1).
- **`defaultdict` and `Counter` solve 80% of hash table interview sub-problems.** Knowing these exist and reaching for them signals fluency. Reimplementing them from scratch in an interview wastes time.

---

## Interview Angle

**What they're really testing:** Whether you instinctively reach for a hash map to convert a nested loop into a single pass.

**Common question form:** Two-sum, group anagrams, longest substring without repeating characters, find duplicate, subarray sum equals k.

**The depth signal:** A junior uses a nested loop and gets O(n²). A senior immediately asks "can I use a hash map?" and restructures to a single pass. The next level up: a senior can explain what happens under the hood — hash function, collision resolution, load factor — and knows why Python dicts use open addressing instead of chaining (better cache locality).

---

## Related Topics

- [[algorithms/array.md]] — Hash maps are commonly used alongside arrays to avoid O(n) lookups inside loops.
- [[algorithms/linked-list.md]] — Chaining uses linked lists at each bucket to resolve collisions.
- [[algorithms/balanced-bst.md]] — When you need sorted keys or range queries, a BST beats a hash table despite worse Big-O.

---

## Source

https://docs.python.org/3/library/stdtypes.html#mapping-types-dict

---

*Last updated: 2026-03-24*