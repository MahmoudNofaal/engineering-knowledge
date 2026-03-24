# C# Arrays

> A fixed-size, ordered collection of elements of the same type, stored in contiguous memory and accessed by zero-based index.

---

## When To Use It
Use arrays when the size is known upfront and won't change, and when raw performance or memory layout matters — arrays are the fastest collection in .NET because elements sit in contiguous memory with no overhead. Don't use arrays when you need to add or remove elements dynamically; use `List<T>` instead. Arrays are the right choice for buffers, fixed lookup tables, interop with native code, and anywhere you're working close to the metal (image processing, binary parsing, `Span<T>` slicing).

---

## Core Concept
An array in C# is a single block of memory divided into equal-sized slots. When you write `int[] nums = new int[5]`, the runtime allocates one contiguous chunk for five integers. Accessing `nums[2]` is a direct memory offset calculation — no searching, no indirection — which is why array reads are O(1) and cache-friendly. The fixed size is the tradeoff: you commit to it at creation time and can't grow it without allocating a new array and copying. Multi-dimensional arrays come in two flavours: rectangular (`int[,]`) where every row has the same length, and jagged (`int[][]`) which is an array of arrays with potentially different lengths — they look similar but have completely different memory layouts and performance characteristics.

---

## The Code

**Declaration, initialisation, and access**
```csharp
// Declare and allocate — elements default to 0/null/false
int[] nums = new int[5];
nums[0] = 10;
nums[4] = 50;

// Declare with initialiser — size inferred from the values
int[] scores = { 85, 92, 78, 95, 60 };
string[] names = new string[] { "Alice", "Bob", "Charlie" };

// Access by index
Console.WriteLine(scores[0]);          // 85 — zero-based
Console.WriteLine(scores[^1]);         // 60 — index from end (C# 8+)
Console.WriteLine(scores[^2]);         // 95

// Array length
Console.WriteLine(scores.Length);      // 5

// Bounds check: accessing outside [0, Length-1] throws IndexOutOfRangeException
// scores[5] — throws at runtime, not compile time
```

**Iteration**
```csharp
int[] values = { 3, 1, 4, 1, 5, 9 };

// foreach — cleanest when you don't need the index
foreach (int v in values)
    Console.Write(v + " ");

// for — when you need the index or want to modify elements
for (int i = 0; i < values.Length; i++)
    values[i] *= 2;

// Iterate with index without a for loop (LINQ)
foreach (var (item, i) in values.Select((v, i) => (v, i)))
    Console.WriteLine($"[{i}] = {item}");
```

**Ranges and slices (C# 8+)**
```csharp
int[] data = { 10, 20, 30, 40, 50 };

int[] middle = data[1..4];    // { 20, 30, 40 } — indices 1, 2, 3 (end is exclusive)
int[] last3  = data[^3..];    // { 30, 40, 50 }
int[] first2 = data[..2];     // { 10, 20 }
int[] copy   = data[..];      // full copy

// Ranges create a new array — they don't slice in-place
// For zero-copy slicing, use Span<T>
Span<int> span = data.AsSpan()[1..4];   // no allocation
```

**Sorting and searching**
```csharp
int[] nums = { 5, 3, 8, 1, 9, 2 };

Array.Sort(nums);                        // in-place sort: { 1, 2, 3, 5, 8, 9 }
Array.Reverse(nums);                     // in-place reverse: { 9, 8, 5, 3, 2, 1 }

int idx = Array.BinarySearch(nums, 5);  // only valid on a sorted array — returns index or negative
int idx2 = Array.IndexOf(nums, 5);      // linear search — works on unsorted arrays

// Sort with custom comparer
string[] words = { "banana", "apple", "cherry" };
Array.Sort(words, (a, b) => a.Length.CompareTo(b.Length));  // sort by length
```

**Array utility methods**
```csharp
int[] source = { 1, 2, 3, 4, 5 };

// Copy
int[] dest = new int[5];
Array.Copy(source, dest, source.Length);

// Clone (shallow copy)
int[] clone = (int[])source.Clone();

// Fill
int[] filled = new int[5];
Array.Fill(filled, 7);   // { 7, 7, 7, 7, 7 }

// Clear (set to default value)
Array.Clear(source, 1, 3);  // source becomes { 1, 0, 0, 0, 5 }
```

**Multi-dimensional: rectangular vs jagged**
```csharp
// Rectangular array: single block, every row same length
int[,] grid = new int[3, 4];       // 3 rows, 4 columns
grid[1, 2] = 42;
Console.WriteLine(grid.GetLength(0));  // 3 (rows)
Console.WriteLine(grid.GetLength(1));  // 4 (columns)

int[,] matrix = {
    { 1, 2, 3 },
    { 4, 5, 6 }
};

// Jagged array: array of arrays, rows can differ in length
int[][] jagged = new int[3][];
jagged[0] = new int[] { 1, 2 };
jagged[1] = new int[] { 3, 4, 5, 6 };
jagged[2] = new int[] { 7 };

// Jagged is generally faster for large data — better CPU cache behaviour
// because each row is a separate array with its own memory
Console.WriteLine(jagged[1][2]);  // 5
```

**Arrays as method parameters and covariance trap**
```csharp
// Arrays are reference types — the method can mutate the original
void Double(int[] arr)
{
    for (int i = 0; i < arr.Length; i++)
        arr[i] *= 2;
}

int[] nums = { 1, 2, 3 };
Double(nums);
Console.WriteLine(nums[0]);  // 2 — original was mutated

// Array covariance: string[] can be assigned to object[] — but writing to it throws
object[] objs = new string[3];   // compiles fine
objs[0] = "hello";               // fine
objs[1] = 42;                    // throws ArrayTypeMismatchException at runtime
```

---

## Gotchas

- **Array bounds are checked at runtime, not compile time.** `arr[arr.Length]` is always wrong but compiles without any warning. You get `IndexOutOfRangeException` only when the line executes. The `^` index-from-end syntax helps (`arr[^1]` is always the last element), but manual index arithmetic is still a source of off-by-one bugs.
- **Passing an array to a method gives the method full write access to the original.** There's no `readonly` parameter modifier for arrays. If you need to protect the caller's data, pass a copy (`arr.ToArray()`) or pass a `ReadOnlySpan<T>` instead. This surprises people who expect value-type-like copy semantics.
- **Array covariance is a runtime trap.** `string[]` is assignable to `object[]` because C# allows covariant array assignment for reference types. But writing a non-string into that `object[]` variable throws `ArrayTypeMismatchException` at runtime. The compiler accepts it. This is a known design flaw in C# that was inherited from Java. Generic collections (`List<string>`) don't have this problem.
- **`Array.BinarySearch` requires the array to be sorted first** — if it isn't, the result is undefined (you get a wrong index, not an exception). And it returns a *negative* number (not `-1`) when the element isn't found — specifically the bitwise complement of the insertion point. `if (idx < 0)` is the correct not-found check, not `if (idx == -1)`.
- **Rectangular `int[,]` and jagged `int[][]` are not interchangeable.** They have different syntax, different LINQ support (jagged works with LINQ; rectangular doesn't cleanly), and different performance profiles. Most .NET APIs that accept matrices expect jagged arrays. Picking rectangular because it looks cleaner and then hitting an API that only accepts `T[][]` is a painful refactor.

---

## Interview Angle
**What they're really testing:** Memory model understanding — contiguous allocation, cache locality, O(1) access — and whether you know the tradeoffs vs dynamic collections.

**Common question form:** "When would you use an array over a `List<T>`?" / "What's the difference between a jagged and a rectangular array?" / "What happens if you access an index out of bounds?"

**The depth signal:** A junior says arrays are fixed-size and `List<T>` is dynamic. A senior talks about *why* that matters: arrays give contiguous memory layout, better CPU cache utilisation for sequential access, and zero overhead per element — which is why buffers, `Span<T>` slices, and performance-critical code use arrays. They also know the covariance trap (`string[]` → `object[]` → runtime crash), that `BinarySearch` returns a bitwise complement on miss, and that jagged arrays generally outperform rectangular ones for large data because each row is independently allocated and avoids false sharing in cache lines.

---

## Related Topics
- [[dotnet/csharp-collections.md]] — `List<T>`, `Dictionary<K,V>`, and `HashSet<T>` are the dynamic alternatives to arrays; knowing when each is right requires understanding both
- [[dotnet/csharp-span-and-memory.md]] — `Span<T>` and `Memory<T>` are the zero-allocation slice APIs built on top of arrays; hot-path code moves from arrays to spans
- [[dotnet/csharp-linq.md]] — Most LINQ operators work on `IEnumerable<T>`, which arrays implement; LINQ is the primary way to query and transform array data without manual loops
- [[algorithms/sorting.md]] — Sorting algorithms operate on arrays by definition; understanding array memory layout explains why in-place sort algorithms like quicksort are cache-efficient

---

## Source
[Arrays — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/arrays/)

---
*Last updated: 2026-03-23*