---
id: "5.051"
studied_well: false
title: "Sorting in .NET — Array.Sort, List.Sort, Custom Comparers, Stability"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Sorting"
tags: [dsa, algorithms, sorting, dotnet, arraysort, listsort, comparer, stable-sort, csharp, interviews]
priority: 3
prerequisites:
  - "[[5.049 — Comparison-Based Sorting — Merge Sort, Quick Sort, Heap Sort]]"
related:
  - "[[5.050 — Non-Comparison Sorting — Counting, Radix, Bucket Sort]]"
  - "[[2.010 — IComparable<T> and IComparer<T>]]"
  - "[[2.005 — SortedSet<T> and SortedDictionary<TKey,TValue>]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Sorting
**Previous:** [[5.050 — Non-Comparison Sorting — Counting, Radix, Bucket Sort]] | **Next:** [[5.052 — Greedy Choice Property and Optimal Substructure]]

### Prerequisites
- [[5.049 — Comparison-Based Sorting — Merge Sort, Quick Sort, Heap Sort]] — understanding the underlying algorithms (quicksort, heapsort, insertion sort) helps understand introsort's behavior.

### Where This Fits
.NET's sorting implementation matters in interviews when choosing between sort methods, understanding stability guarantees, and writing correct custom comparers. `Array.Sort` uses introsort (hybrid: quicksort + heapsort + insertion sort). `List.Sort` uses the same. `Enumerable.OrderBy` uses a stable quicksort. `Array.Sort` for small arrays uses insertion sort directly. Custom comparer pitfalls (non-transitive, inconsistent with Equals) are common interview discussion topics.

### Key Facts

- **Array.Sort** — Uses introsort (introspective sort): starts with quicksort, switches to heapsort when recursion depth exceeds 2 log n (to avoid O(n²) worst-case), and switches to insertion sort for partitions ≤ 16 elements.
- **Stability** — `Array.Sort` and `List.Sort` are **not stable** (equal elements may change relative order). `Enumerable.OrderBy` (LINQ) is **stable**.
- **Custom comparer** — Must return consistent results: compare(a,b) < 0, compare(b,a) > 0 must hold. If compare(a,b) == 0, the sort may treat elements as equal even if `Equals` returns false.
- **Span<T>.Sort** — Available in .NET 5+ for sorting spans without allocations.
- **Array.Sort<T>(T[], Comparison<T>)** — Accepts a delegate for simple custom sorts without a separate comparer class.

### Usage Patterns

```csharp
// Basic sort
int[] arr = { 5, 3, 1, 4, 2 };
Array.Sort(arr);  // [1, 2, 3, 4, 5]

// Custom comparer (descending)
Array.Sort(arr, Comparer<int>.Create((a, b) => b.CompareTo(a)));

// Using Comparison<T> delegate
Array.Sort(arr, (a, b) => b.CompareTo(a));

// Sort with range
Array.Sort(arr, 1, 3);  // Sort indices [1, 3)

// List.Sort
var list = new List<int> { 5, 3, 1 };
list.Sort();
list.Sort((a, b) => b.CompareTo(a));

// LINQ — stable
var sorted = arr.OrderBy(x => x).ToArray();
var sortedDesc = arr.OrderByDescending(x => x).ToArray();

// Custom comparer class
public class Person { public string Name; public int Age; }
var people = new List<Person>();
people.Sort((a, b) => a.Age.CompareTo(b.Age));

// Complex sort — primary key ascending, secondary descending
Array.Sort(arr, Comparer<int>.Create((a, b) =>
{
    int cmp = (a % 2).CompareTo(b % 2);  // Even first
    if (cmp != 0) return cmp;
    return b.CompareTo(a);  // Descending within same parity
}));
```

### Gotchas

- **Non-stable sort** — If order of equal elements matters, use `OrderBy` (stable LINQ) or implement a stable sort manually.
- **Comparer inconsistency** — If `compare(a,b) < 0 && compare(b,c) < 0` but `compare(a,c) >= 0`, the comparer is non-transitive and can crash with `ArgumentException: IComparer failed`.
- **CompareTo null** — For nullable types, check for null explicitly in custom comparers.
- **String sorting** — Default is culture-sensitive (`StringComparer.CurrentCulture`). For ordinal (byte-level) sort, use `StringComparer.Ordinal`.
- **Array.Sort on multi-dimensional arrays** — Not supported. Flatten to 1D first.
- **Large allocation** — `OrderBy` allocates an intermediate buffer. For performance-critical sorts, use `Array.Sort` in-place.
- **Introsort depth** — `.NET` uses a recursion depth limit of `2 * log2(n)`. Beyond this depth, heapsort is used instead of quicksort.

