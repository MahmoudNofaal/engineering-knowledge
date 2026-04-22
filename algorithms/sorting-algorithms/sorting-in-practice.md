# Sorting in Practice

> The decision layer above individual sorting algorithms — understanding what's inside language built-ins, when to deviate from them, and how to choose the right sort for any given situation.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Guide to real-world sorting algorithm selection and built-in internals |
| **Use when** | Choosing between sorting approaches in production or interview discussions |
| **Avoid when** | N/A — this is a decision framework |
| **C# version** | `Array.Sort` uses introsort (C# 1.0+); `Enumerable.OrderBy` uses stable merge sort |
| **Namespace** | `System`, `System.Linq` |
| **Key types** | `Array.Sort`, `List<T>.Sort`, `Enumerable.OrderBy`, `Enumerable.ThenBy` |

---

## When To Use It

Always use the language built-in sort unless you have a measured performance reason to do otherwise. The built-ins are heavily optimised, tested, and often adaptive. Deviation is justified only when: (1) the built-in's complexity is wrong for your input distribution, (2) stability is required and the built-in is unstable, or (3) the key type enables a linear-time sort (counting/radix) and n is large enough to matter.

---

## Core Concept

No single algorithm dominates across all cases. Real implementations are hybrids:

**Introsort** (C#'s `Array.Sort`, C++'s `std::sort`): starts with randomised quicksort for cache performance, switches to heapsort if recursion depth exceeds 2 log n (preventing O(n²) worst case), falls back to insertion sort for subarrays ≤ 16 elements. Result: O(n log n) worst case, fast average case, in-place, not stable.

**Timsort** (Python `list.sort()`, Java `Arrays.sort()` for objects, .NET `Enumerable.OrderBy`): scans input for natural runs (already-sorted subsequences), uses insertion sort to extend short runs to a minimum size (32–64 elements), then merges runs using merge sort. Best case O(n) on sorted/nearly-sorted input. Always stable.

The crossover points matter: insertion sort beats all O(n log n) algorithms below ~16–32 elements due to lower constant factors. Every major sort implementation uses insertion sort for small subarrays.

---

## Algorithm History

| Year | Development |
|---|---|
| 1993 | Tim Peters creates Timsort for Python 2.2 |
| 1997 | David Musser invents introsort — quicksort + heapsort fallback |
| 2002 | Java 1.5 adopts merge sort for `Arrays.sort(Object[])` |
| 2009 | Java 7 adopts Timsort for `Arrays.sort(Object[])` |
| 2011 | Android's Java was found using broken TimSort — widely publicised sort bug |
| 2021 | Pdqsort (pattern-defeating quicksort) — introsort + sentinel-based optimisations — adopted in Rust |

---

## Performance

| Algorithm | Best | Average | Worst | Space | Stable | Used by |
|---|---|---|---|---|---|---|
| Introsort | O(n log n) | O(n log n) | O(n log n) | O(log n) | No | C# `Array.Sort`, C++ `std::sort` |
| Timsort | O(n) | O(n log n) | O(n log n) | O(n) | Yes | Python, Java objects, .NET `OrderBy` |
| Pdqsort | O(n) | O(n log n) | O(n log n) | O(log n) | No | Rust `slice::sort_unstable` |
| Merge sort | O(n log n) | O(n log n) | O(n log n) | O(n) | Yes | Foundation of Timsort |
| Radix sort | O(n) | O(n) | O(n) | O(n) | Yes | Custom — no built-in |

**Allocation behaviour:** `Array.Sort` / `List<T>.Sort` — O(log n) stack only (in-place introsort). `Enumerable.OrderBy` — O(n) heap (Timsort buffer). Custom radix sort — O(n) buffer.

**Benchmark notes:** At n = 1,000,000 random integers: `Array.Sort` ≈ 120ms, `OrderBy` ≈ 200ms (stability overhead), radix sort base 256 ≈ 80ms. At n = 1,000: all three are < 1ms — don't optimise sort at small n.

---

## The Code

**Scenario 1 — C# built-in sort options**
```csharp
// Array.Sort — in-place introsort, unstable, O(n log n) worst case
int[] arr = { 3, 1, 4, 1, 5, 9, 2, 6 };
Array.Sort(arr);                              // sorts ascending
Array.Sort(arr, (a, b) => b.CompareTo(a));   // custom comparator — descending

// List<T>.Sort — same introsort, in-place
var list = new List<int> { 3, 1, 4, 1, 5 };
list.Sort();
list.Sort((a, b) => b - a); // descending

// Enumerable.OrderBy — stable Timsort, returns new IOrderedEnumerable (not in-place)
var sorted = arr.OrderBy(x => x).ToArray();  // stable, O(n) extra space

// Multi-key sort — stable: primary by age descending, secondary by name ascending
var people = new[] { ("Alice", 30), ("Bob", 25), ("Carol", 30), ("Dave", 25) };
var multiSorted = people
    .OrderByDescending(p => p.Item2) // primary: age desc
    .ThenBy(p => p.Item1)            // secondary: name asc (stable preserves this)
    .ToArray();
```

**Scenario 2 — when to use each**
```csharp
// Decision tree:
void ChooseSort<T>(T[] data, bool stable, int? keyRange = null) where T : IComparable<T>
{
    if (data.Length < 32)
    {
        // Insertion sort (or just use Array.Sort — it does this internally)
        // Array.Sort is fine; don't overthink small n
    }
    else if (stable)
    {
        // data.OrderBy(...).ToArray() — stable Timsort
        // OR: manual stable sort if avoiding LINQ allocation
    }
    else if (keyRange.HasValue && keyRange.Value <= data.Length * 4)
    {
        // Counting sort / radix sort — O(n) when key range ≈ n
    }
    else
    {
        // Array.Sort() — introsort, O(n log n) guaranteed, in-place
    }
}
```

**Scenario 3 — stable vs unstable: why it matters**
```csharp
// Stable sort preserves relative order of equal elements.
// This enables the "sort twice" pattern for multi-key sorting:
// Sort by secondary key first (stable), then by primary key (stable).
// Equal primary keys preserve the secondary ordering.

var events = new[]
{
    (Name: "Login",  Time: 10, UserId: 3),
    (Name: "Logout", Time: 10, UserId: 1),
    (Name: "Login",  Time: 10, UserId: 2),
};

// Stable sort by UserId first, then by Time:
var result = events
    .OrderBy(e => e.UserId)  // stable pass 1
    .OrderBy(e => e.Time)    // stable pass 2 — equal Times preserve UserId order
    .ToArray();
// Result: ordered by Time, then by UserId within same Time

// Unstable Array.Sort would destroy the UserId ordering in pass 2.
// This "sort by secondary then primary" trick ONLY works with stable sorts.
```

**Scenario 4 — what NOT to do: LINQ OrderBy then First for minimum**
```csharp
// BAD: OrderBy().First() is O(n log n) — sorts everything to get one element
int[] scores = { 5, 3, 8, 1, 9, 2 };
int minBad = scores.OrderBy(x => x).First(); // O(n log n)

// GOOD: MinBy / Min is O(n) — single pass
int minGood = scores.Min();                  // O(n)
int minGoodBy = scores.MinBy(x => x);        // O(n) — .NET 6+

// Also BAD: using sorted list for repeated min-extraction when heap is better
// Sorting: O(n log n) upfront + O(1) per extraction
// Heap: O(n) build + O(log n) per extraction — better when not all elements extracted
```

---

## Real World Example

The `ProductCatalogueService` sorts product listings for display. Products have multiple sort keys: primary by in-stock status, secondary by rating (descending), tertiary by name (ascending). Stability is required — the secondary and tertiary orderings must be preserved when primary keys are equal. The team chose `OrderBy().ThenByDescending().ThenBy()` (stable Timsort chain) over a custom comparator on `Array.Sort` (unstable).

```csharp
public class ProductCatalogueService
{
    public record Product(int Id, string Name, decimal Price, double Rating, bool InStock, int StockCount);

    // Stable multi-key sort: in-stock first, then by rating desc, then by name asc.
    // Stability ensures ties in rating preserve alphabetical name order.
    public List<Product> GetSortedCatalogue(List<Product> products)
    {
        return products
            .OrderByDescending(p => p.InStock)          // primary: in-stock first
            .ThenByDescending(p => p.Rating)             // secondary: highest rated
            .ThenBy(p => p.Name, StringComparer.Ordinal) // tertiary: alphabetical
            .ToList();
        // Each ThenBy is stable — equal primaries preserve the secondary ordering,
        // equal (primary + secondary) preserve the tertiary ordering.
    }

    // For large catalogues (100k+ products), materialise once and cache:
    private Product[]? _sortedCache;
    private DateTimeOffset _cacheTime;

    public Product[] GetCachedSortedCatalogue(List<Product> products, TimeSpan cacheTtl)
    {
        if (_sortedCache != null && DateTimeOffset.UtcNow - _cacheTime < cacheTtl)
            return _sortedCache;

        _sortedCache = GetSortedCatalogue(products).ToArray();
        _cacheTime   = DateTimeOffset.UtcNow;
        return _sortedCache;
    }
}
```

*The key insight: `OrderByDescending().ThenByDescending().ThenBy()` is the idiomatic C# way to express multi-key stable sorting. Each `ThenBy` is a stable pass — it preserves the ordering of earlier keys within equal elements at the current key. This is not possible with `Array.Sort` and a single comparator unless the comparator encodes all keys simultaneously.*

---

## Common Misconceptions

**"Array.Sort is stable"**
No — `Array.Sort` uses introsort which is unstable. Equal elements may be reordered. Use `Enumerable.OrderBy` (stable Timsort) when stability is required.

**"Timsort is O(n) — it's always faster than O(n log n) sorts"**
Timsort is O(n) only for sorted or nearly-sorted input (it detects natural runs). For random input, Timsort is O(n log n) with a larger constant than introsort due to the run detection and merging overhead. Introsort is faster for random data; Timsort is faster for nearly-sorted data.

**"Java's `Arrays.sort()` for primitives and objects is the same algorithm"**
They are different. `Arrays.sort(int[])` (primitives) uses dual-pivot quicksort — unstable but fast. `Arrays.sort(Object[])` uses Timsort — stable. Mixing the two assumptions produces subtle bugs when sorting arrays of boxed Integer vs int.

---

## Gotchas

- **`string.CompareTo` is culture-sensitive.** `Array.Sort` on strings uses the current culture by default, which can produce unexpected orderings for non-ASCII characters. Use `StringComparer.Ordinal` for byte-level ordering or `StringComparer.OrdinalIgnoreCase` for case-insensitive.
- **`Enumerable.OrderBy` is lazy until materialised.** `var sorted = data.OrderBy(x => x)` doesn't sort — it creates a lazy query. The sort executes when you call `.ToArray()`, `.ToList()`, or iterate. Forgetting to materialise and sorting multiple times is a common performance bug.
- **`Array.Sort` with a custom `IComparer<T>` can be slower than the default.** Each comparison goes through a virtual dispatch. For performance-critical sorts, consider a non-virtual struct comparer.
- **Null handling in comparators.** If your data contains nulls and your comparator doesn't handle them, `Array.Sort` throws a `NullReferenceException`. Always guard for null in custom comparators.
- **`List<T>.Sort` is in-place; `OrderBy` is not.** `list.Sort()` modifies `list`. `list.OrderBy(x => x)` returns a new sequence without touching `list`. Using `OrderBy` when you expect an in-place sort is a common mistake.

---

## Interview Angle

**What they're really testing:** Whether you have practical judgment about sorting — not just academic knowledge of algorithms, but knowing which tool fits which situation and why language implementors made the choices they did.

**Common question forms:** "Which sorting algorithm would you use here and why?" with constraints like stability, memory limits, data distribution, or data type. "What does `Array.Sort` use internally?" "When would you write a custom sort?"

**The depth signal:** A junior picks merge sort or quicksort and justifies with Big-O. A senior explains introsort vs Timsort, knows `Array.Sort` is unstable and `OrderBy` is stable, cites the practical crossover points (insertion sort for n < 32, radix sort for large integer arrays), and knows Java's primitive vs object sort difference. The elite signal: knowing that `Arrays.sort(int[])` is dual-pivot quicksort and why primitives can use unstable sort (no object identity to preserve).

**Follow-up questions to expect:**
- "What's the difference between `Array.Sort` and `OrderBy`?" → Array.Sort is introsort (unstable, in-place, O(log n) space). OrderBy is Timsort (stable, O(n) space). Use Array.Sort for speed; OrderBy for stability.
- "When would you implement a custom sort instead of using the built-in?" → When the key type enables O(n) sorting (radix/counting) and n is large enough that the O(n log n) built-in is measured to be too slow.

---

## Related Topics

- [[algorithms/sorting-algorithms/merge-sort.md]] — Stable O(n log n); the base of Timsort.
- [[algorithms/sorting-algorithms/quick-sort.md]] — Cache-efficient; the base of introsort.
- [[algorithms/sorting-algorithms/heap-sort.md]] — O(n log n) in-place; introsort's fallback.
- [[algorithms/sorting-algorithms/counting-radix-sort.md]] — When to break out of O(n log n) with linear-time sorts.

---

## Source

https://en.wikipedia.org/wiki/Timsort

---

*Last updated: 2026-04-21*