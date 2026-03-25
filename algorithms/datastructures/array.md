# Array
> A fixed-size, ordered collection of elements stored in contiguous memory, accessible by index in O(1).

---

## When To Use It
Use an array when you need fast index-based access and your data size is known or bounded. It's the default structure for ordered data. Avoid it when you need frequent insertions or deletions in the middle — shifting elements is O(n) and gets expensive fast.

---

## Core Concept
An array maps directly to a block of memory. Element 0 starts at the base address; element k is at base + (k × element_size). That's why index access is O(1) — it's a single arithmetic operation, not a search. The trade-off is rigidity: size is fixed at allocation, and inserting anywhere except the end requires shifting everything after it. Dynamic arrays (Python lists, C# List<T>) hide this by over-allocating and copying when they grow — amortized O(1) append, but occasionally expensive.

---

## The Code

**Basic operations**
```csharp
var items = new List<int> { 10, 20, 30, 40, 50 };

// O(1) access
Console.WriteLine(items[2]);        // 30

// O(1) append (amortized)
items.Add(60);

// O(n) insert at arbitrary position — everything after shifts right
items.Insert(1, 99);

// O(n) delete at arbitrary position — everything after shifts left
items.RemoveAt(1);

// O(n) search — no index to help, must scan
Console.WriteLine(items.Contains(42));
```

**Sliding window — O(n) instead of O(n²)**
```csharp
public static int MaxSumSubarray(List<int> items, int k)
{
    int window = items.Take(k).Sum();
    int best = window;
    for (int i = k; i < items.Count; i++)
    {
        window += items[i] - items[i - k];  // slide: add right, drop left
        best = Math.Max(best, window);
    }
    return best;
}
```

**Two-pointer — O(n) pair search on sorted array**
```csharp
public static (int, int) TwoSumSorted(List<int> items, int target)
{
    int lo = 0, hi = items.Count - 1;
    while (lo < hi)
    {
        int s = items[lo] + items[hi];
        if (s == target)
            return (lo, hi);
        else if (s < target)
            lo++;
        else
            hi--;
    }
    return (-1, -1);
}
```

---

## Gotchas

- **Off-by-one errors are the most common bug.** Ranges in Python are exclusive at the end. `items[0:n]` gives n elements; `items[n]` is out of bounds. Always verify boundary conditions on loops and slices.
- **Python lists are dynamic arrays, not true fixed-size arrays.** If you need a real fixed-size array in Python, use `array.array` or `numpy.ndarray`. The difference matters for memory layout and performance at scale.
- **Copying a slice creates a new array.** `items[1:4]` allocates new memory. Modifying the slice doesn't affect the original. This surprises people coming from languages where slices are views.
- **Insert and delete at position 0 is O(n).** Every element shifts. If you do this frequently, you want a deque, not an array.
- **Cache performance is a real advantage.** Because elements are contiguous in memory, iterating an array is CPU-cache-friendly. Linked lists are not. For tight loops over large data, this matters more than theoretical complexity.

---

## Interview Angle

**What they're really testing:** Whether you know when to use index tricks (two pointers, sliding window, prefix sums) instead of brute-force nested loops.

**Common question form:** "Find X in this array" — where the naive answer is O(n²) and the expected answer uses a single pass with a hash map, two pointers, or sorting first.

**The depth signal:** A junior loops and checks. A senior asks: "Is the array sorted? Can I sort it first? Can I use a hash map to trade space for time?" Seniors also know that prefix sums convert range-sum queries from O(n) per query to O(1) — and can implement that pattern without prompting.

---

## Related Topics

- [[algorithms/hash-table.md]] — Often paired with arrays to reduce O(n) search to O(1).
- [[algorithms/sliding-window.md]] — Core pattern built entirely on array index arithmetic.
- [[algorithms/sorting-algorithms.md]] — Many array techniques require a sorted input as a prerequisite.
- [[algorithms/dynamic-programming.md]] — DP tables are almost always implemented as arrays or 2D arrays.

---

## Source

https://docs.python.org/3/library/stdtypes.html#lists

---

*Last updated: 2026-03-24*