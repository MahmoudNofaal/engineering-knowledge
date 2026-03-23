# C# Collections — HashSet<T>

> `HashSet<T>` is an unordered collection of unique values that uses a hash table to give O(1) average-case add, remove, and membership checks.

---

## When To Use It
Use `HashSet<T>` when you need fast membership testing, deduplication, or set operations like union and intersection. It's the right tool when you only care whether something exists — not where it is, how many times it appears, or what it maps to. Don't use it when you need indexed access by position (use `List<T>`), key-value pairs (use `Dictionary<TKey, TValue>`), or sorted order (use `SortedSet<T>`).

---

## Core Concept
`HashSet<T>` is a dictionary with no values — just keys. Internally it's the same hash table: `GetHashCode()` maps an item to a bucket, `Equals` confirms the match, and the constraint is that every item must be unique. The payoff is that `Contains` is O(1) average case instead of O(n) like `List<T>`. The set operation methods (`UnionWith`, `IntersectWith`, `ExceptWith`) are what make it more than just a fast membership check — they let you treat two collections as mathematical sets and compute their relationships efficiently.

---

## The Code

**Basic operations**
```csharp
var tags = new HashSet<string> { "csharp", "dotnet", "backend" };

tags.Add("api");               // true — added
tags.Add("csharp");            // false — already exists, no duplicate added
tags.Remove("backend");        // true — removed
bool has = tags.Contains("dotnet"); // true — O(1)

Console.WriteLine(tags.Count); // 3
Console.WriteLine(has);        // True
```

**Deduplication — the most common practical use**
```csharp
var rawIds = new List<int> { 1, 2, 2, 3, 1, 4, 3 };

// Pass a collection to the constructor — duplicates are silently dropped
var uniqueIds = new HashSet<int>(rawIds);

Console.WriteLine(uniqueIds.Count);                  // 4
Console.WriteLine(string.Join(", ", uniqueIds));     // order not guaranteed
```

**Set operations**
```csharp
var setA = new HashSet<int> { 1, 2, 3, 4, 5 };
var setB = new HashSet<int> { 3, 4, 5, 6, 7 };

// These methods MUTATE setA in place
var union     = new HashSet<int>(setA); union.UnionWith(setB);
    // {1,2,3,4,5,6,7}

var intersect = new HashSet<int>(setA); intersect.IntersectWith(setB);
    // {3,4,5}

var except    = new HashSet<int>(setA); except.ExceptWith(setB);
    // {1,2} — items in A that are not in B

var symDiff   = new HashSet<int>(setA); symDiff.SymmetricExceptWith(setB);
    // {1,2,6,7} — items in one but not both

// Predicate checks — do not mutate
Console.WriteLine(setA.IsSubsetOf(union));       // True
Console.WriteLine(setA.IsSupersetOf(intersect)); // True
Console.WriteLine(setA.Overlaps(setB));          // True
Console.WriteLine(setA.SetEquals(setB));         // False
```

**`Contains` vs `List.Contains` — the performance case**
```csharp
var list = Enumerable.Range(0, 100_000).ToList();
var set  = Enumerable.Range(0, 100_000).ToHashSet();

// list.Contains(99_999) — scans up to 100,000 items: O(n)
// set.Contains(99_999)  — one hash lookup: O(1)

// Rule of thumb: if you're calling Contains more than once on a large
// collection, convert it to a HashSet first
var lookup = list.ToHashSet();
bool found = lookup.Contains(99_999); // now O(1)
```

**Custom equality — controlling what "unique" means**
```csharp
// Case-insensitive string set
var caseInsensitive = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
caseInsensitive.Add("CSharp");
caseInsensitive.Add("csharp"); // not added — treated as duplicate

Console.WriteLine(caseInsensitive.Count); // 1

// Custom comparer for a type
public class UserByEmail : IEqualityComparer<User>
{
    public bool Equals(User? x, User? y) =>
        string.Equals(x?.Email, y?.Email, StringComparison.OrdinalIgnoreCase);

    public int GetHashCode(User obj) =>
        obj.Email.ToLowerInvariant().GetHashCode();
}

var users = new HashSet<User>(new UserByEmail());
```

---

## Gotchas

- **Enumeration order is not insertion order and not stable across .NET versions.** Items come out in internal bucket order, which depends on hash values and the current internal array size. Never write code that assumes a specific enumeration order from a `HashSet<T>`. If you need ordered output, call `.OrderBy(...)` explicitly.
- **Set operation methods mutate the receiver — they don't return a new set.** `setA.IntersectWith(setB)` modifies `setA` in place. If you need the original preserved, copy it first: `new HashSet<T>(setA)`. This is the most common `HashSet` mistake in code review.
- **The same `Equals`/`GetHashCode` contract applies here as in `Dictionary`.** If your type overrides `Equals` but not `GetHashCode`, two "equal" items will land in different buckets and both get added — silently breaking uniqueness. If you use a custom `IEqualityComparer<T>`, the comparer's `GetHashCode` must be consistent with its `Equals`.
- **`Add` returns `bool` — most people ignore it.** `true` means the item was new; `false` means it was already there. This is useful when you want to detect duplicates rather than just discard them, but since most code writes `set.Add(x)` as a statement and discards the return value, the information is lost.
- **`HashSet<T>` is not thread-safe.** Concurrent reads are fine; any concurrent write causes data corruption. Use locks or `ConcurrentDictionary<T, byte>` (with a dummy value) as a thread-safe set substitute — there is no `ConcurrentHashSet<T>` in the BCL.

---

## Interview Angle
**What they're really testing:** Whether you know when to reach for a set instead of a list, understand the O(1) membership check and why it matters, and can explain the hash table contract that underpins it.

**Common question form:** "How would you efficiently check if a value exists in a large collection?" or "What's the difference between `HashSet<T>` and `List<T>`?" or "How would you find the intersection of two collections?"

**The depth signal:** A junior says "`HashSet` is faster for `Contains` because it uses hashing." A senior explains the full picture: `List.Contains` is O(n) — it scans every element. `HashSet.Contains` is O(1) average because it hashes the item to a bucket and checks only that bucket. They'll articulate the constraint: the hash table only works if `GetHashCode` is consistent with `Equals`, and mutable items used in a set are a correctness risk for the same reason as dictionary keys. They'll also know the set operation methods mutate in place, name `SortedSet<T>` as the alternative when order matters (O(log n) for all operations, Red-Black tree internally), and mention that there's no `ConcurrentHashSet<T>` — and what the workaround is.

---

## Related Topics
- [[dotnet/csharp-collections-dictionary.md]] — Same hash table internals; `HashSet<T>` is a `Dictionary<T, byte>` without the values — understanding one explains the other.
- [[dotnet/csharp-collections-list.md]] — The primary comparison: ordered, indexed, O(n) membership vs unordered, unique, O(1) membership.
- [[dotnet/csharp-object-class.md]] — `GetHashCode` and `Equals` are inherited from `object`; they're the exact methods `HashSet` depends on for every operation.
- [[dotnet/csharp-generics.md]] — `HashSet<T>` is a generic type; custom comparers via `IEqualityComparer<T>` are a generic interface pattern.

---

## Source
[https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.hashset-1](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.hashset-1)

---
*Last updated: 2026-03-23*