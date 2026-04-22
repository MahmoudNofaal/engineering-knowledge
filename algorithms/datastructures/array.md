# Array

> A contiguous block of memory holding elements of the same type, accessible in O(1) by index — the foundation of nearly every other data structure.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Fixed-size contiguous memory block, O(1) index access |
| **Use when** | Known size, frequent random access, cache-efficient iteration |
| **Avoid when** | Frequent insert/delete in the middle; unknown or highly variable size |
| **C# version** | C# 1.0 (`int[]`); `List<T>` dynamic array since C# 2.0 |
| **Namespace** | `System.Collections.Generic` for `List<T>` |
| **Key types** | `int[]`, `T[]`, `List<T>`, `ArraySegment<T>`, `Span<T>` |

---

## When To Use It

Use a fixed array (`T[]`) when the size is known at creation time and you need the best possible cache performance. Use `List<T>` (a dynamic array) when you need to grow the collection. Prefer arrays over linked lists for sequential access — contiguous memory enables CPU cache prefetching, making iteration 3–5× faster in practice. Avoid arrays for frequent mid-collection insertion/deletion — that requires shifting all subsequent elements (O(n)).

---

## Core Concept

An array stores n elements at consecutive memory addresses. Element i is at `baseAddress + i × elementSize` — this is why index lookup is O(1): it's arithmetic, not a search. The CPU can prefetch the next cache line while you process the current one, which is why iterating an array is faster than traversing a linked list even though both are O(n).

`List<T>` in C# is a dynamic array backed by a `T[]`. When capacity is exceeded, it allocates a new array of double the size and copies all elements — O(n) for that resize, O(1) amortised per Add. The doubling strategy means the total copying work across all resizes is O(n).

---

## Algorithm History

| Year | Development |
|---|---|
| 1950s | Arrays are the first data structure in early programming languages (Fortran, COBOL) |
| 1960s | Random access memory makes O(1) index access practical |
| 1970s | Knuth formalises array analysis in TAOCP |
| 1998 | C# 1.0 ships with `System.Array` and `T[]` syntax |
| 2005 | `List<T>` introduced in C# 2.0 with generics |
| 2017 | `Span<T>` and `Memory<T>` added in C# 7.2 / .NET Core 2.1 for zero-copy slicing |

---

## Performance

| Operation | `T[]` | `List<T>` | Notes |
|---|---|---|---|
| Index access `arr[i]` | O(1) | O(1) | Direct memory address calculation |
| Append (Add) | N/A | O(1) amortised | O(n) on resize; amortised O(1) |
| Insert at index i | O(n) | O(n) | Must shift elements i..n-1 right |
| Delete at index i | O(n) | O(n) | Must shift elements i+1..n left |
| Search (unsorted) | O(n) | O(n) | Linear scan |
| Search (sorted) | O(log n) | O(log n) | Binary search |
| Iteration | O(n) | O(n) | Cache-friendly — fastest sequential access |

**Allocation behaviour:** `T[]` allocates once on the heap. `List<T>` may reallocate multiple times during growth, but the final backing array is a single contiguous block. `Span<T>` is stack-allocated and avoids heap allocation entirely for slices of existing arrays.

**Benchmark notes:** Iterating a `T[]` is ~3–5× faster than a `LinkedList<T>` for the same data due to cache locality. For random access, `T[]` and `List<T>` are identical. For small collections (< 16 elements), arrays beat hash maps even for "contains" checks due to CPU cache effects.

---

## The Code

**Scenario 1 — fixed array vs List<T>**
```csharp
// Fixed array: size must be known at creation
int[] scores = new int[5];
scores[0] = 95; scores[1] = 87;

// List<T>: dynamic — grows as needed
var names = new List<string> { "Alice", "Bob" };
names.Add("Carol");               // O(1) amortised
names.Insert(1, "Dave");          // O(n) — shifts Bob and Carol right
names.RemoveAt(0);                // O(n) — shifts remaining left
Console.WriteLine(names[0]);      // O(1) — still index access

// Pre-size when count is known — avoids all resizes
var known = new List<int>(1000);  // capacity 1000, count 0
```

**Scenario 2 — two-pointer and sliding window on arrays (core pattern)**
```csharp
// Reverse in-place — O(n) time, O(1) space
public static void Reverse(int[] arr)
{
    int lo = 0, hi = arr.Length - 1;
    while (lo < hi)
    {
        (arr[lo], arr[hi]) = (arr[hi], arr[lo]);
        lo++; hi--;
    }
}

// Rotate array right by k positions — O(n) time, O(1) space (three reverses)
public static void Rotate(int[] arr, int k)
{
    k %= arr.Length;
    Reverse(arr, 0, arr.Length - 1);
    Reverse(arr, 0, k - 1);
    Reverse(arr, k, arr.Length - 1);
}

private static void Reverse(int[] arr, int lo, int hi)
{
    while (lo < hi) { (arr[lo], arr[hi]) = (arr[hi], arr[lo]); lo++; hi--; }
}
```

**Scenario 3 — Span<T> for zero-copy slicing**
```csharp
// Without Span: allocates a new array
int[] original = { 1, 2, 3, 4, 5, 6, 7, 8 };
int[] slice = original[2..5]; // new allocation: [3, 4, 5]

// With Span: no allocation — a view into the original
Span<int> span = original.AsSpan(2, 3); // [3, 4, 5] — zero allocation
span[0] = 99; // mutates original[2]
Console.WriteLine(original[2]); // 99

// Span is stack-allocated and can't be stored in class fields
// Use Memory<T> for heap-stored slices
Memory<int> memory = original.AsMemory(2, 3); // heap-safe slice
```

**Scenario 4 — what NOT to do: List.Insert/Remove in hot loops**
```csharp
// BAD: O(n²) — Insert(0, ...) shifts all elements every call
public List<int> PrependAllBad(int[] items)
{
    var list = new List<int>();
    foreach (int item in items)
        list.Insert(0, item); // O(n) each time — total O(n²)
    return list;
}

// GOOD: append then reverse — O(n) total
public List<int> PrependAllGood(int[] items)
{
    var list = new List<int>(items.Length);
    foreach (int item in items)
        list.Add(item);     // O(1) amortised
    list.Reverse();         // O(n) once
    return list;
}

// ALSO GOOD: use a LinkedList if frequent front-insertion is required
public LinkedList<int> PrependAllLinked(int[] items)
{
    var list = new LinkedList<int>();
    foreach (int item in items)
        list.AddFirst(item); // O(1) — no shifting
    return list;
}
```

---

## Real World Example

The `EventAggregatorService` processes a high-volume stream of sensor readings. Each reading is appended to a pre-sized buffer array. The service then runs a sliding window over the buffer to compute rolling averages. Pre-sizing the array eliminates all GC pressure from `List<T>` resizes, and operating on a `Span<T>` slice avoids copying the window each iteration.

```csharp
public class EventAggregatorService
{
    private readonly int[] _buffer;
    private int _count;
    private readonly int _windowSize;

    public EventAggregatorService(int capacity, int windowSize)
    {
        _buffer     = new int[capacity]; // pre-sized — zero resizes, zero GC
        _windowSize = windowSize;
    }

    public void Append(int value)
    {
        if (_count >= _buffer.Length)
            throw new InvalidOperationException("Buffer full — flush before appending.");
        _buffer[_count++] = value; // O(1) — direct index write
    }

    // Returns rolling averages for every window of size _windowSize.
    // Uses a Span<T> view — no intermediate array allocation.
    public double[] ComputeRollingAverages()
    {
        if (_count < _windowSize) return Array.Empty<double>();

        int resultCount = _count - _windowSize + 1;
        var result      = new double[resultCount];

        // Build first window sum
        var data     = _buffer.AsSpan(0, _count); // zero-copy view
        int windowSum = 0;
        for (int i = 0; i < _windowSize; i++)
            windowSum += data[i];

        result[0] = (double)windowSum / _windowSize;

        // Slide the window — O(1) per step
        for (int i = 1; i < resultCount; i++)
        {
            windowSum += data[i + _windowSize - 1]; // add new right element
            windowSum -= data[i - 1];               // remove old left element
            result[i] = (double)windowSum / _windowSize;
        }

        return result;
    }

    public void Reset() => _count = 0; // O(1) — just reset the counter
}
```

*The key insight: pre-sizing `new int[capacity]` allocates once and eliminates all GC pauses during ingestion. `Span<T>` makes the sliding window computation allocation-free in the hot path — critical for high-frequency sensor data where GC pauses cause missed readings.*

---

## Common Misconceptions

**"List<T> is slower than T[] because it's wrapped"**
For index access and iteration, `List<T>` is within ~5% of `T[]` because it's backed by a `T[]` internally. The overhead is one bounds check and one field dereference per access — negligible. The real performance difference is allocation strategy (pre-size `List<T>`) and GC pressure from resizes, not the abstraction itself.

**"Array.Copy is O(1) because it's a built-in"**
`Array.Copy` is O(n) — it copies n elements. It's faster than a manual loop because it uses `memcpy` internally, but the work is proportional to n. Don't assume built-in methods are O(1).

**"Deleting from an array removes the element"**
Arrays have fixed size. "Deleting" from a `T[]` means either overwriting with a sentinel, shuffling the last element into the deleted slot (O(1) but unordered), or shifting all subsequent elements left (O(n) but ordered). `List<T>.RemoveAt` does the latter. Neither actually shrinks the backing memory.

---

## Gotchas

- **`List<T>` count vs capacity.** `Count` is the number of elements. `Capacity` is the size of the backing array. `Count <= Capacity` always. If `Count == Capacity`, the next `Add` triggers a resize. Pre-set `Capacity` when the final count is known.

- **`new int[n]` zero-initialises.** C# always zero-initialises arrays. `new int[1000]` gives you 1000 zeros. This is safe but costs time proportional to n — avoid large array allocation in hot paths if the first operation is a write.

- **Range indexing `arr[2..5]` creates a new array.** Unlike Python slices (which are views), C# array slices copy. Use `AsSpan(start, length)` for a zero-copy view when you don't need a new allocation.

- **Off-by-one in loop bounds.** `for (int i = 0; i < arr.Length; i++)` — `<` not `<=`. The last valid index is `arr.Length - 1`. `arr[arr.Length]` throws `IndexOutOfRangeException`.

- **`Array.Sort` uses an unstable introsort.** Equal elements may not preserve their original relative order. If stability is required, use `OrderBy` (LINQ) which uses a stable merge sort.

---

## Interview Angle

**What they're really testing:** Whether you understand index arithmetic, know when to use arrays vs linked lists, and can apply two-pointer / sliding window patterns directly on arrays.

**Common question forms:**
- "Reverse an array in-place."
- "Rotate an array by k positions."
- "Remove duplicates from a sorted array in-place."
- "Find the maximum subarray sum."

**The depth signal:** A junior iterates correctly. A senior pre-sizes `List<T>`, uses `Span<T>` for zero-copy slicing in hot paths, knows the cache-locality advantage over linked lists, and identifies `List.Insert(0, ...)` as O(n) hidden in what looks like a loop.

**Follow-up questions to expect:**
- "When would you use a linked list over an array?" → Frequent O(1) insertion/deletion at a known position (head/tail). Arrays win for random access and cache performance.
- "What's the difference between `List<T>` capacity and count?" → Count is elements stored; capacity is the backing array size. Reaching capacity triggers an O(n) resize and doubling.

---

## Related Topics

- [[algorithms/patterns/two-pointers.md]] — The primary pattern applied directly to sorted arrays.
- [[algorithms/patterns/sliding-window.md]] — Requires O(1) index access — array-native.
- [[algorithms/patterns/prefix-sum.md]] — Precomputed array for O(1) range queries.
- [[algorithms/datastructures/linked-list.md]] — The alternative when O(1) insertion/deletion matters more than random access.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.list-1

---

*Last updated: 2026-04-21*