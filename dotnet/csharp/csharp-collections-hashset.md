# C# Collections — HashSet\<T\>

> An unordered collection of unique values with O(1) average add, remove, and membership checks — essentially a dictionary with no values, plus set operations (union, intersection, difference).

---

## Quick Reference

| Operation | Average | Notes |
|---|---|---|
| `Add` | O(1) | Returns `false` if already present |
| `Contains` | O(1) | vs O(n) for `List<T>` |
| `Remove` | O(1) | |
| `UnionWith` | O(n) | Mutates in place |
| `IntersectWith` | O(n) | Mutates in place |
| `ExceptWith` | O(n) | Mutates in place |
| Iteration | O(n) | Order not guaranteed |

---

## When To Use It

Use `HashSet<T>` when you need:
- **Fast membership testing** — `Contains` is O(1) vs O(n) for a list
- **Deduplication** — pass any collection to the constructor to eliminate duplicates
- **Set operations** — union, intersection, difference, subset/superset checks

Don't use it when you need: index access by position (`List<T>`), key-value pairs (`Dictionary<K,V>`), sorted order (`SortedSet<T>`).

---

## Core Concept

`HashSet<T>` is a dictionary with no values — just keys. Same hash table internals: `GetHashCode()` maps an item to a bucket, `Equals` confirms the match, and every item must be unique. The payoff: `Contains` is O(1) average case instead of O(n) like `List<T>`.

The set operation methods (`UnionWith`, `IntersectWith`, `ExceptWith`, `SymmetricExceptWith`) treat two collections as mathematical sets. Crucially, **they mutate the receiver in place** — always copy first if you need the original preserved.

---

## The Code

**Basic operations and deduplication**
```csharp
var tags = new HashSet<string> { "csharp", "dotnet", "backend" };

tags.Add("api");       // true — added
tags.Add("csharp");    // false — already exists
tags.Remove("backend"); // true
bool has = tags.Contains("dotnet"); // true — O(1)

// Deduplication: pass any IEnumerable — duplicates silently dropped
var rawIds = new List<int> { 1, 2, 2, 3, 1, 4, 3 };
var unique = new HashSet<int>(rawIds); // { 1, 2, 3, 4 }
Console.WriteLine(unique.Count); // 4
```

**Set operations — all mutate the receiver**
```csharp
var setA = new HashSet<int> { 1, 2, 3, 4, 5 };
var setB = new HashSet<int> { 3, 4, 5, 6, 7 };

// Copy before mutating if you need the original
var union     = new HashSet<int>(setA); union.UnionWith(setB);       // {1,2,3,4,5,6,7}
var intersect = new HashSet<int>(setA); intersect.IntersectWith(setB); // {3,4,5}
var except    = new HashSet<int>(setA); except.ExceptWith(setB);     // {1,2}
var symDiff   = new HashSet<int>(setA); symDiff.SymmetricExceptWith(setB); // {1,2,6,7}

// Predicate checks — do NOT mutate
Console.WriteLine(setA.IsSubsetOf(union));       // true
Console.WriteLine(setA.IsSupersetOf(intersect)); // true
Console.WriteLine(setA.Overlaps(setB));          // true
Console.WriteLine(setA.SetEquals(setB));         // false
```

**Custom equality — controlling what "unique" means**
```csharp
// Case-insensitive string deduplication
var caseInsensitive = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
caseInsensitive.Add("CSharp");
caseInsensitive.Add("csharp"); // not added — same under OrdinalIgnoreCase
Console.WriteLine(caseInsensitive.Count); // 1

// Custom comparer for domain types
public class UserByEmail : IEqualityComparer<User>
{
    public bool Equals(User? x, User? y)
        => string.Equals(x?.Email, y?.Email, StringComparison.OrdinalIgnoreCase);

    public int GetHashCode(User obj)
        => obj.Email.ToUpperInvariant().GetHashCode();
}

var users = new HashSet<User>(new UserByEmail());
```

**Performance comparison: `Contains` on large collections**
```csharp
var list = Enumerable.Range(0, 100_000).ToList();
var set  = Enumerable.Range(0, 100_000).ToHashSet();

// list.Contains(99_999) — scans up to 100,000 items: O(n)
// set.Contains(99_999)  — one hash lookup: O(1)

// Convert a list to a set when you need repeated Contains calls
var lookup = new HashSet<int>(list);
bool found = lookup.Contains(99_999); // O(1) — worth the one-time O(n) setup cost
```

---

## Real World Example

An access control check uses a `HashSet<string>` for permission lookup — O(1) per check instead of scanning a list on every API call.

```csharp
public class UserPermissions
{
    private readonly HashSet<string> _permissions;

    public UserPermissions(IEnumerable<string> permissions)
        // OrdinalIgnoreCase: "orders:read" == "Orders:Read"
        => _permissions = new HashSet<string>(permissions, StringComparer.OrdinalIgnoreCase);

    public bool Has(string permission) => _permissions.Contains(permission);

    public bool HasAll(IEnumerable<string> required)
        => required.All(_permissions.Contains);

    public bool HasAny(IEnumerable<string> required)
        => required.Any(_permissions.Contains);

    // Efficient: set subset check — O(|required|) not O(|permissions| * |required|)
    public bool IsSubsetOf(IEnumerable<string> available)
    {
        var availableSet = new HashSet<string>(available, StringComparer.OrdinalIgnoreCase);
        return _permissions.IsSubsetOf(availableSet);
    }
}

var perms = new UserPermissions(["orders:read", "orders:write", "products:read"]);
Console.WriteLine(perms.Has("orders:read"));               // true
Console.WriteLine(perms.HasAll(["orders:read", "orders:write"])); // true
Console.WriteLine(perms.Has("admin:delete"));             // false
```

---

## Gotchas

- **Enumeration order is not insertion order** and not stable across .NET versions. Never rely on enumeration order from a `HashSet<T>`.
- **Set operation methods mutate the receiver.** `setA.IntersectWith(setB)` modifies `setA` in place. Always copy first if you need the original: `new HashSet<T>(setA)`.
- **`Add` returns `bool` — most people ignore it.** `true` means new; `false` means already present. Useful for detecting duplicates.
- **Same `Equals`/`GetHashCode` contract as `Dictionary`.** Two "equal" items with different hash codes both get added — silently breaking uniqueness.
- **No `ConcurrentHashSet<T>` in BCL.** Use `ConcurrentDictionary<T, byte>` with a dummy value, or lock around a regular `HashSet`.

---

## Interview Angle

**What they're really testing:** Whether you know when to reach for a set instead of a list, understand the O(1) membership check, and can explain the hash table contract.

**Common question forms:**
- "How would you efficiently check if a value exists in a large collection?"
- "What's the difference between `HashSet<T>` and `List<T>`?"
- "How would you find the intersection of two collections?"

**The depth signal:** A senior explains `Contains` is O(1) because it hashes to a bucket rather than scanning; knows the set operations mutate in place; and names `SortedSet<T>` as the alternative when order matters (O(log n), Red-Black tree).

---

## Related Topics

- [[dotnet/csharp/csharp-collections-dictionary.md]] — Same hash table internals; `HashSet<T>` is a `Dictionary<T, byte>` without the values
- [[dotnet/csharp/csharp-object-class.md]] — `GetHashCode` and `Equals` are the methods `HashSet` depends on

---

## Source

[HashSet\<T\> — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.hashset-1)

---
*Last updated: 2026-04-06*