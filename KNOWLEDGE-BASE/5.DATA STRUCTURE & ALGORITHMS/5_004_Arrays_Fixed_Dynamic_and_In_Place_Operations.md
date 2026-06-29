---
id: "5.004"
studied_well: false
title: "Arrays — Fixed, Dynamic, and In-Place Operations"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Arrays and Strings"
tags: [dsa, algorithms, data-structures, arrays, csharp, interviews, in-place]
priority: 1
prerequisites:
  - "[[5.001 — Big-O Notation and Complexity Analysis]]"
related:
  - "[[5.002 — Recursion and the Call Stack]]"
  - "[[5.005 — Two Pointers]]"
  - "[[5.006 — Sliding Window]]"
  - "[[2.XXX — Span<T> and Memory<T>]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Arrays and Strings
**Previous:** [[5.002 — Recursion and the Call Stack]] | **Next:** [[5.005 — Two Pointers]]

### Prerequisites
- [[5.001 — Big-O Notation and Complexity Analysis]] — array operation complexity (indexing, insertion, deletion) must be derived from memory layout, not memorized.

### Where This Fits
Arrays are the most fundamental data structure in computing — contiguous memory blocks indexed by offset. Every other data structure (heaps, hash tables, trees) either uses an array as its backing storage or trades array properties for other guarantees. In interviews, arrays appear in approximately 70% of all problems, either as the primary structure or as the foundation for more complex structures. In-place array manipulation — modifying the input without allocating new memory — is the single most commonly tested optimization pattern because it forces candidates to reason about indices, bounds, and memory layout simultaneously.

---

## Core Mental Model

An array is a contiguous block of memory where each element is at a fixed offset from the base address: `address(base) + index × sizeof(element)`. This gives O(1) random access — the core property that distinguishes arrays from linked lists. The trade-off is that fixed-size arrays cannot grow, and dynamic arrays (like `List<T>`) require O(n) resizing when capacity is exhausted. In-place operations exploit the array's contiguity to avoid allocating new memory, shuffling elements within the existing block instead.

### Classification

Arrays implement `IList<T>`, `ICollection<T>`, and `IEnumerable<T>`. The .NET type hierarchy distinguishes single-dimensional arrays (`T[]`), multidimensional arrays (`T[,]`), and jagged arrays (`T[][]`). Dynamic arrays (`List<T>`) add resizing on top of the fixed array contract.

```mermaid
graph TD
    A[Array Types in .NET] --> B[Single-dimensional T[]]
    A --> C[Multidimensional T[,]]
    A --> D[Jagged T[][]]
    A --> E[Dynamic List<T>]
    B --> F[Contiguous, indexable, fixed-size]
    C --> G[Rectangular matrix, fixed-size]
    D --> H[Array of arrays, each row can vary]
    E --> I[Backed by T[], auto-resizes]
    I --> J[Capacity doubles on overflow]
    I --> K[Amortized O(1) append]
```

### Key Properties

|Property|Value|Derivation|
|---|---|---|
|Random access (read/write by index)|O(1)|Direct memory offset: base + index × sizeof(T)|
|Insert at beginning|O(n)|All subsequent elements shift right by one|
|Insert at end (fixed array)|O(1) if space, impossible if full|No shift needed; can only write to existing slot|
|Insert at end (List<T>, dynamic)|O(1) amortized|Resize O(n) happens every n appends; amortized to O(1)|
|Delete at beginning|O(n)|All subsequent elements shift left by one|
|Search (unsorted)|O(n)|Must examine every element in worst case|
|Search (sorted via binary search)|O(log n)|Halving the search space each iteration|
|Space|O(n)|Contiguous allocation of n × sizeof(T)|

---

## Deep Mechanics

### How It Works

**Memory layout:** `int[] arr = new int[5]` allocates 20 contiguous bytes (5 × 4 bytes per int) on the heap. The variable `arr` holds a reference (8 bytes on 64-bit) to the base address. Accessing `arr[3]` computes `base_address + 3 * sizeof(int)` in a single CPU instruction — this is the fastest possible memory access pattern.

**Resizing a List<T>:** `List<T>` is backed by an internal `T[]` array. When `Add` is called and the internal array is full, a new array of double the capacity is allocated, all elements are copied via `Array.Copy` (which uses CPU's `rep movs` instruction for maximum throughput), and the old array is garbage collected. This doubling strategy ensures that the total copy cost across n insertions is O(n), giving O(1) amortized per insertion.

**In-place operations:** "In-place" means the algorithm modifies the input array directly rather than creating a copy. This is useful when:
- The array is large and allocating a copy would exceed memory constraints
- The problem explicitly asks for O(1) auxiliary space
- The algorithm naturally processes elements by overwriting earlier positions

### Complexity Derivation

**Time — Resize cost:** First insertion: array size 1, insert O(1). Second: resize to 2, copy 1 element. Third: resize to 4, copy 2. Fifth: resize to 8, copy 4. The sum of copied elements across all resizes up to n is 1 + 2 + 4 + 8 + ... + n/2 + n < 2n. So total copy cost across n insertions is O(2n) = O(n), giving O(1) amortized per insert.

**Space — Allocation overhead:** Every `T[]` allocation on the heap has overhead: sync block (8 bytes), method table pointer (8 bytes), array length (4 bytes), padding. A `List<T>` wrapper adds an additional ~40 bytes for its own fields. For large arrays, this overhead is negligible; for many small arrays, it compounds.

### .NET Runtime Notes

- **Array bounds checking:** Every array access in .NET is bounds-checked at runtime. The JIT can elide bounds checks for loops where the index is provably within bounds (e.g., `for(int i = 0; i < arr.Length; i++)`). The `[SkipLocalsInit]` attribute and unsafe code can bypass initialization but also bypass bounds checks.
- **Large Object Heap (LOH):** Arrays larger than 85,000 bytes go to the LOH. LOH is not compacted in the default GC mode, which can cause fragmentation. `List<T>` with many elements triggers LOH allocations on resize.
- **`Span<T>` and `Memory<T>`:** `Span<T>` provides a heap-allocation-free view over any contiguous memory (arrays, unmanaged memory, stack-allocated buffers). It is a ref struct and cannot be used as a field in a class. For array slices without allocation, use `arr.AsSpan(start, length)`.
- **`ArrayPool<T>`:** .NET provides a shared buffer pool: `ArrayPool<T>.Shared.Rent(minimumLength)` returns a potentially reused array. This reduces GC pressure in hot paths but requires careful return semantics.

---

## Implementation and Problem Patterns

### C# Implementation

```csharp
/// <summary>
/// Scratch implementation of a dynamic array (similar to List<T>).
/// </summary>
public class DynamicArray<T>
{
    private T[] _items;
    private int _count;

    public DynamicArray(int capacity = 4)
    {
        if (capacity <= 0) throw new ArgumentOutOfRangeException(nameof(capacity));
        _items = new T[capacity];
        _count = 0;
    }

    public int Count => _count;
    public int Capacity => _items.Length;

    public T this[int index]
    {
        get
        {
            if ((uint)index >= (uint)_count) throw new IndexOutOfRangeException();
            return _items[index];
        }
        set
        {
            if ((uint)index >= (uint)_count) throw new IndexOutOfRangeException();
            _items[index] = value;
        }
    }

    public void Add(T item)
    {
        if (_count == _items.Length)
        {
            Resize(_items.Length * 2);
        }
        _items[_count++] = item;
    }

    public void InsertAt(int index, T item)
    {
        if ((uint)index > (uint)_count) throw new ArgumentOutOfRangeException(nameof(index));
        if (_count == _items.Length) Resize(_items.Length * 2);
        Array.Copy(_items, index, _items, index + 1, _count - index);
        _items[index] = item;
        _count++;
    }

    public void RemoveAt(int index)
    {
        if ((uint)index >= (uint)_count) throw new ArgumentOutOfRangeException(nameof(index));
        _count--;
        if (index < _count)
            Array.Copy(_items, index + 1, _items, index, _count - index);
        _items[_count] = default!;
    }

    private void Resize(int newCapacity)
    {
        var newArray = new T[newCapacity];
        Array.Copy(_items, newArray, _count);
        _items = newArray;
    }
}

/// <summary>
/// In-place array utilities — operate on the array without allocating new memory.
/// </summary>
public static class InPlaceOperations
{
    // In-place reverse — O(n/2) swaps, O(1) space
    public static void Reverse<T>(T[] arr)
    {
        int left = 0, right = arr.Length - 1;
        while (left < right)
        {
            (arr[left], arr[right]) = (arr[right], arr[left]);
            left++;
            right--;
        }
    }

    // In-place remove all occurrences of a value — O(n), O(1) space
    // Returns the new length (elements beyond it are undefined)
    public static int RemoveValue(int[] arr, int val)
    {
        int write = 0;
        for (int read = 0; read < arr.Length; read++)
        {
            if (arr[read] != val)
                arr[write++] = arr[read];
        }
        return write;
    }

    // In-place remove duplicates from sorted array — O(n), O(1) space
    public static int RemoveDuplicates(int[] sorted)
    {
        if (sorted.Length == 0) return 0;
        int write = 1;
        for (int read = 1; read < sorted.Length; read++)
        {
            if (sorted[read] != sorted[write - 1])
                sorted[write++] = sorted[read];
        }
        return write;
    }

    // In-place move all zeros to the end, maintaining relative order
    public static void MoveZerosToEnd(int[] arr)
    {
        int write = 0;
        for (int read = 0; read < arr.Length; read++)
            if (arr[read] != 0)
                arr[write++] = arr[read];
        while (write < arr.Length)
            arr[write++] = 0;
    }
}
```

### The .NET Idiomatic Version

```csharp
public static class ArrayIdiomatic
{
    // Dynamic array — use List<T>
    public static void DynamicArrayExample()
    {
        var list = new List<int> { 1, 2, 3 };
        list.Add(4);
        list.Insert(0, 0);
        list.RemoveAt(2);
        // List<T>.TrimExcess() reduces capacity to match count
    }

    // Reverse — Array.Reverse uses the same in-place algorithm
    public static void ReverseExample<T>(T[] arr) => Array.Reverse(arr);

    // Resize — allocates a new array and copies
    public static void ResizeExample<T>(ref T[] arr, int newSize) =>
        Array.Resize(ref arr, newSize);

    // Copy a segment without allocation — use Span<T>
    public static Span<T> SliceExample<T>(T[] arr, int start, int length) =>
        arr.AsSpan(start, length);

    // Buffering — use ArrayPool<T> to avoid allocation in hot paths
    public static void ArrayPoolExample(int size)
    {
        var pool = ArrayPool<byte>.Shared;
        byte[] buffer = pool.Rent(size);
        try
        {
            // use buffer
        }
        finally
        {
            pool.Return(buffer);
        }
    }
}
```

### Classic Problem Patterns

1. **In-place duplicates removal** — Given a sorted array, remove duplicates in O(1) space. Key insight: the write-pointer pattern separates reading from writing — read scans ahead, write marks where the next unique element goes.
2. **Rotate array by K positions** — Left or right rotation without allocating a copy. Key insight: reverse the whole array, then reverse the two parts independently (reverse-based rotation).
3. **Dutch National Flag (3-way partition)** — Sort an array of 0s, 1s, and 2s in O(1) space. Key insight: three pointers partition the array into the three value regions in a single pass.

### Template / Skeleton

```csharp
// In-Place Write-Pointer Template
// When to use: filtering or transforming an array while overwriting elements
// Time: O(n) | Space: O(1)

public static int WritePointerTemplate<T>(T[] arr, Func<T, bool> shouldKeep)
{
    int write = 0;
    for (int read = 0; read < arr.Length; read++)
    {
        // TODO: define the keep condition
        if (shouldKeep(arr[read]))
        {
            arr[write++] = arr[read];
        }
    }
    // TODO: if returning array, resize or return the write index
    return write; // new logical length; elements beyond write are undefined
}
```

---

## Gotchas and Edge Cases

### Off-by-One in Bounds Checks

**Mistake:** Using `arr[index]` without verifying index is strictly less than length.

```csharp
// ❌ Wrong — allows index == length, which is out of bounds
for (int i = 0; i <= arr.Length; i++)
    arr[i] = i;
```

**Fix:** Use strict less-than: `i < arr.Length`.

```csharp
// ✅ Correct — strict less-than ensures valid index
for (int i = 0; i < arr.Length; i++)
    arr[i] = i;
```

**Consequence:** `IndexOutOfRangeException` at runtime — immediate disqualification in an interview.

### Forgetting List<T>.Count vs Capacity

**Mistake:** Accessing `list[i]` for indices >= Count but < Capacity.

```csharp
// ❌ Wrong — accessing beyond Count, even if within Capacity
var list = new List<int> { 1, 2, 3 };
int third = list[3]; // IndexOutOfRangeException — Count is 3
```

**Fix:** Always check Count, not Capacity.

```csharp
// ✅ Correct — Count tracks logical size
var list = new List<int> { 1, 2, 3 };
if (list.Count > 3) int third = list[3];
```

**Consequence:** `IndexOutOfRangeException` — the internal array is larger than the list, but elements beyond Count are `default` and logically undefined.

### In-Place Overwriting Leading to Incorrect Results

**Mistake:** Overwriting an element that is still needed later in the same pass.

```csharp
// ❌ Wrong — overwrites arr[0] before reading it for the shift
int temp = arr[0];
for (int i = 0; i < arr.Length - 1; i++)
    arr[i] = arr[i + 1];
arr[arr.Length - 1] = temp; // arr[0] is already lost
```

**Fix:** Store the displaced value in a temporary and assign at the end.

```csharp
// ✅ Correct — save the displaced value
int temp = arr[0];
for (int i = 0; i < arr.Length - 1; i++)
    arr[i] = arr[i + 1];
arr[arr.Length - 1] = temp;
```

**Consequence:** Silent data corruption — the rotated value is wrong, but no exception is thrown.

### Forgetting Array.Resize Creates a New Array

**Mistake:** Passing an array to a method that calls `Array.Resize` and expecting the caller's reference to update.

```csharp
// ❌ Wrong — Resize creates a new array; caller still holds the old reference
void EnsureCapacity(int[] arr, int minSize)
{
    if (arr.Length < minSize)
        Array.Resize(ref arr, minSize); // only updates local reference? No — ref fixes this
}
```

**Fix:** Use `ref` parameter to pass the array by reference.

```csharp
// ✅ Correct — ref ensures the caller's reference is updated
void EnsureCapacity(ref int[] arr, int minSize)
{
    if (arr.Length < minSize)
        Array.Resize(ref arr, minSize);
}
```

**Consequence:** The caller continues using the old small array; the enlarged array is garbage collected — data is lost.

---

## Complexity Analysis and Benchmarks

### Operation Complexity Table

|Operation|Time (Best)|Time (Average)|Time (Worst)|Space|Notes|
|---|---|---|---|---|---|
|Index (read/write)|O(1)|O(1)|O(1)|O(1)|Direct memory offset|
|Linear search (unsorted)|O(1)|O(n/2)|O(n)|O(1)|Found at first position ... found at last|
|Binary search (sorted)|O(1)|O(log n)|O(log n)|O(1)|Halving the search space|
|List.Add|O(1)|O(1) amortized|O(n)|O(n) resize|Resize copy when capacity doubles|
|List.Insert(0)|O(n)|O(n)|O(n)|O(1)|Shift all elements right|
|List.RemoveAt(0)|O(n)|O(n)|O(n)|O(1)|Shift all elements left|

**Derivation for the non-obvious entries:** `List.Add` has worst-case O(n) when the internal array is full and must resize. The amortized O(1) comes from the geometric doubling: the sum of all copy costs across n insertions is less than 2n. Each individual insert may be O(n), but the sequence averages to O(1).

### Comparison with Alternatives

|Structure / Algorithm|Time (Index)|Time (Insert Front)|Time (Delete Front)|Best When|
|---|---|---|---|---|
|Array (T[])|O(1)|O(n)|O(n)|Fixed size, index-heavy access|
|List<T>|O(1)|O(n)|O(n)|Unknown size, append-heavy|
|LinkedList<T>|O(n)|O(1) known node|O(1) known node|Frequent insert/delete at known positions|
|Stack<T>|N/A|O(1) push|O(1) pop|LIFO access pattern|

### BenchmarkDotNet

```csharp
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net90)]
public class ArrayBenchmark
{
    [Params(1_000, 10_000)]
    public int N { get; set; }

    private int[] _data = null!;

    [GlobalSetup]
    public void Setup()
    {
        _data = Enumerable.Range(0, N).ToArray();
    }

    [Benchmark(Baseline = true)]
    public int[] InPlaceRemoveValue()
    {
        var arr = (int[])_data.Clone();
        int write = 0;
        for (int read = 0; read < arr.Length; read++)
            if (arr[read] % 2 == 0)
                arr[write++] = arr[read];
        return arr;
    }

    [Benchmark]
    public int[] ListFilter()
    {
        return _data.Where(x => x % 2 == 0).ToArray();
    }

    [Benchmark]
    public int[] ListRemoveAll()
    {
        var list = new List<int>(_data);
        list.RemoveAll(x => x % 2 != 0);
        return list.ToArray();
    }
}
```

**Expected results (approximate, .NET 9, x64):**

|Method|N|Mean|Allocated|
|---|---|---|---|
|InPlaceRemoveValue|1,000|~2 μs|4 KB|
|InPlaceRemoveValue|10,000|~20 μs|40 KB|
|ListFilter|1,000|~8 μs|16 KB|
|ListFilter|10,000|~80 μs|160 KB|
|ListRemoveAll|1,000|~12 μs|24 KB|
|ListRemoveAll|10,000|~120 μs|240 KB|

**Interpretation:** The in-place approach is both faster and allocates less memory because it avoids creating intermediate enumerators and secondary arrays. The gap widens with N as allocation overhead dominates the ListFilter path.

---

## Interview Arsenal

### Question Bank

1. [Definition] What is the fundamental property of an array and what operations does it make fast?
2. [Complexity] Why is `List<T>.Add` O(1) amortized? Derive this from the resizing strategy.
3. [Implementation] Implement in-place removal of all occurrences of a value from an array.
4. [Recognition] Given a problem, when would you use a fixed array vs. List<T> vs. LinkedList<T>?
5. [Comparison] Compare `Array.Copy`, `Buffer.BlockCopy`, and `Span<T>.CopyTo` for performance.
6. [Trick] What happens when you access `list[list.Count]` on a List<T> with capacity 16 and count 5?
7. [System Design] How would you handle a scenario where an in-memory array grows to gigabytes? What GC and fragmentation concerns arise?
8. [Optimization] How would you optimize a method that frequently inserts at position 0 of a large List<T>?

### Spoken Answers

**Q: Why is `List<T>.Add` O(1) amortized? Derive this from the resizing strategy.**

> **Average answer:** It's O(1) most of the time, but when the array is full, it copies everything, which is O(n).

> **Great answer:** `List<T>` uses a geometric resizing strategy: when the internal array is full, it doubles the capacity. Let me derive the amortized cost. Starting with capacity 1, inserting n elements triggers resizes at sizes 1, 2, 4, 8, ..., up to n. The total number of elements copied across all resizes is 1 + 2 + 4 + ... + n/2 < n. But I need to be more precise: the sum is 1 + 2 + 4 + ... + n/2 = n - 1. Actually, let me recalculate: the last resize copies n/2 elements, the one before copies n/4, and so on. The sum is less than n. So across n insertions, the total copy cost is O(n). Dividing by n insertions gives O(1) amortized. The trap is confusing worst-case per-operation cost — the single insertion that triggers the resize is O(n) — with the amortized cost across a sequence, which is O(1). In production, this matters because individual request latency can spike during resize, which is why some systems pre-size with `new List<T>(capacity)`.

**Q: Implement in-place removal of all occurrences of a value from an array.**

> **Average answer:** Loop through the array and when you find the value, shift everything left.

> **Great answer:** I'll use the write-pointer pattern. Initialize a write index at 0. Iterate a read index from 0 to n-1. For each element, if it is not the value to remove, copy it to the write position and advance write. At the end, write is the new logical length. This is O(n) time and O(1) space. The key insight is that read always advances, and write only advances when we keep an element — so read is always >= write, and we never overwrite an element we haven't processed yet. I should note that elements beyond the returned length are undefined per the problem spec, but in a production system, I might want to null them out to avoid memory leaks if T is a reference type.

**Q: [Trick] What happens when you access `list[list.Count]` on a List<T> with capacity 16 and count 5?**

> **Average answer:** It crashes with IndexOutOfRangeException.

> **Great answer:** It throws `ArgumentOutOfRangeException`, not `IndexOutOfRangeException`. In .NET's `List<T>`, the indexer checks `(uint)index >= (uint)_size`, which throws `ArgumentOutOfRangeException` when the index equals `_size`. The capacity being 16 is irrelevant — `List<T>` only allows access to elements within `Count` (the logical size), not `Capacity` (the backing array length). The trap is that candidates might think capacity matters for access, or conflate the exception type with `IndexOutOfRangeException` from raw array access. At the whiteboard, I'd write out the range check: `if ((uint)index >= (uint)_count) throw new ArgumentOutOfRangeException();`.

### Trick Question

**"You have an array of n elements. You remove one element from the middle. What is the time complexity?"**

Why it is a trap: The answer depends on what "remove" means. If by "remove" you mean "mark as deleted without preserving order", it is O(1) — swap with the last element and decrement length. If you mean "remove and preserve relative order", it is O(n) because you must shift remaining elements.

Correct answer: It depends on whether order must be preserved. If order does not matter, swap with the last element and truncate — O(1). If order matters, shift all subsequent elements left — O(n). In an interview, always clarify the constraint before answering.

### Pattern Recognition Table

|If the problem has...|Then consider...|Because...|
|---|---|---|
|Sorted input array|Two pointers or binary search|The sorted property enables O(log n) search and O(n) merging|
|In-place constraint (O(1) memory)|Write-pointer pattern|Overwrite elements to avoid allocation|
|Large contiguous data, index-heavy access|T[] over List<T>|Array has less overhead and better cache locality|
|Unknown final size, append-heavy|List<T>|Amortized O(1) append with automatic growth|
|Frequent insertions at front|LinkedList<T> or reverse the array|List.Insert(0) is O(n) each time|

---

## Decision Framework

### When to Apply

```mermaid
flowchart TD
    A[Need to store sequential data] --> B{Size known at creation?}
    B -->|Yes, fixed| C[Use T[]]
    B -->|No, grows| D[Use List<T>]
    C --> E{Need to modify size later?}
    E -->|Yes| D
    E -->|No| C
    D --> F{Frequent insert at front?}
    F -->|Yes| G[Consider LinkedList<T> or use Deque]
    F -->|No| H[List<T> is fine]
    C --> I{Memory constrained?}
    I -->|Yes, use ArrayPool<T>| J[Rent and Return]
    I -->|No| K[Direct allocation is fine]
```

### Recognition Checklist

Indicators that an array (or in-place operation) is the right choice:

- [ ] Problem specifies "O(1) extra memory" or "in-place"
- [ ] Data is accessed sequentially by index
- [ ] Random access by position is required
- [ ] Input size is known and fixed

Counter-indicators — do NOT apply here:

- [ ] Frequent insertion or deletion at arbitrary positions (prefer LinkedList<T>)
- [ ] LIFO-only access pattern (prefer Stack<T>)
- [ ] FIFO-only access pattern (prefer Queue<T>)

### Tradeoff Summary

|What You Gain|What You Give Up|
|---|---|
|O(1) random access by index|O(n) insert/delete at arbitrary positions|
|Best cache locality of any structure|Fixed maximum size (T[]) or O(n) resize cost (List<T>)|
|Minimal memory overhead per element|No built-in search beyond linear scan|

---

## Self-Check

### Conceptual Questions

1. What is the memory address formula for accessing `arr[i]`?
2. Derive the amortized O(1) cost of `List<T>.Add` using the doubling strategy.
3. Recognizing from a problem: if you need O(1) lookups by index and O(1) insert at end, which structure?
4. When would you use a fixed `T[]` array instead of `List<T>` in production code?
5. What specific edge case causes the write-pointer pattern to fail if not careful?
6. What .NET type provides a reusable buffer to avoid array allocation in hot paths?
7. What invariant must hold for an array to be binary-searchable?
8. How does `Span<T>` change the way you work with array segments, and what are its limitations?
9. In a production API that processes thousands of requests per second, why might `List<T>` resizing cause latency spikes?
10. What is the trick question about "removing an element from the middle" and why?

<details>
<summary>Answers</summary>

1. `base_address + (index - lower_bound) × sizeof(T)`. For zero-based arrays: `base_address + index × sizeof(T)`.
2. Starting at capacity 1, resizes happen at 2, 4, 8, ..., n/2. Total elements copied: 1 + 2 + 4 + ... + n/2 < n. Total insert operations: n. Amortized cost: (n + n) / n = O(1).
3. `List<T>` (dynamic array) — O(1) index access and O(1) amortized append.
4. When the maximum size is known and fixed (e.g., a fixed lookup table of 256 entries), or when interop with unmanaged code requires a fixed buffer, or when maximum performance and minimum overhead are critical (e.g., high-frequency trading).
5. The write-pointer pattern fails if the `shouldKeep` condition reads elements that have already been overwritten. The invariant is `read >= write` — read always stays ahead of write to avoid reading overwritten data.
6. `ArrayPool<T>.Shared` — provides a shared pool of arrays to reduce allocation frequency.
7. The array must be sorted in non-decreasing order, and the comparison function must be consistent and transitive.
8. `Span<T>` provides allocation-free slices over contiguous memory. Limitations: ref struct (cannot be stored on heap, used in async methods, or used as generic type argument), stack-only.
9. Each resize allocates a new array on the LOH (if > 85 KB), which triggers a GC collection. Under high concurrency, multiple requests may trigger GC simultaneously, causing stop-the-world pauses.
10. The trap is the ambiguity of "remove" — if order preservation is not required, O(1) swap-and-pop. If order must be preserved, O(n) shift. Always clarify.

</details>

---

### Coding Challenges

**Challenge 1 — Implement from scratch**

Implement a circular buffer (ring buffer) of fixed capacity using an array. Support `Write`, `Read`, and `IsFull`.

```csharp
public class CircularBuffer<T>
{
    private readonly T[] _buffer;
    private int _head;
    private int _tail;
    private int _count;

    public CircularBuffer(int capacity)
    {
        _buffer = new T[capacity];
    }

    public bool IsFull => _count == _buffer.Length;
    public bool IsEmpty => _count == 0;

    public void Write(T item)
    {
        // Your implementation here
    }

    public T Read()
    {
        // Your implementation here
    }
}
```

<details> <summary>Solution</summary>

```csharp
public class CircularBuffer<T>
{
    private readonly T[] _buffer;
    private int _head;
    private int _tail;
    private int _count;

    public CircularBuffer(int capacity)
    {
        _buffer = new T[capacity];
    }

    public bool IsFull => _count == _buffer.Length;
    public bool IsEmpty => _count == 0;
    public int Count => _count;

    public void Write(T item)
    {
        _buffer[_tail] = item;
        _tail = (_tail + 1) % _buffer.Length;
        if (_count == _buffer.Length)
            _head = (_head + 1) % _buffer.Length; // overwrite oldest
        else
            _count++;
    }

    public T Read()
    {
        if (IsEmpty) throw new InvalidOperationException("Buffer is empty");
        T item = _buffer[_head];
        _head = (_head + 1) % _buffer.Length;
        _count--;
        return item;
    }
}
```

**Complexity:** Time O(1) for both operations | Space O(capacity) **Key insight:** The modulo arithmetic wraps indices around the buffer. Count tracks logical size; head/tail positions advance independently.

</details>

---

**Challenge 2 — Trace the execution**

Given `arr = [1, 0, 2, 0, 3]`, trace the in-place `MoveZerosToEnd` algorithm step by step.

<details> <summary>Solution</summary>

Initial: read=0, write=0, arr=[1, 0, 2, 0, 3]

Step 1: read=0, arr[0]=1 ≠ 0 → copy to write=0: arr=[1, 0, 2, 0, 3], write=1
Step 2: read=1, arr[1]=0 == 0 → skip, write=1
Step 3: read=2, arr[2]=2 ≠ 0 → copy to write=1: arr=[1, 2, 2, 0, 3], write=2
Step 4: read=3, arr[3]=0 == 0 → skip, write=2
Step 5: read=4, arr[4]=3 ≠ 0 → copy to write=2: arr=[1, 2, 3, 0, 3], write=3

Fill remaining positions (write=3 to end) with zeros: arr=[1, 2, 3, 0, 0]

**Why:** The write pointer always lags behind or equals the read pointer, ensuring we never overwrite unread data. The zero-fill at the end sets the remaining positions to zero.

</details>

---

**Challenge 3 — Fix the bug**

```csharp
// This implementation has a bug that fails on specific input types
public static int RemoveElement(int[] arr, int val)
{
    int write = 0;
    for (int read = 0; read < arr.Length; read++)
    {
        if (arr[read] != val)
            arr[write] = arr[read];  // BUG: missing write increment on keep
    }
    return write; // Returns 0 always
}
```

<details> <summary>Solution</summary>

**Bug:** The `write` pointer is never incremented, so all kept elements are written to position 0, and the function always returns 0.

**Fix:**

```csharp
public static int RemoveElement(int[] arr, int val)
{
    int write = 0;
    for (int read = 0; read < arr.Length; read++)
    {
        if (arr[read] != val)
            arr[write++] = arr[read];  // FIXED: increment write
    }
    return write;
}
```

**Test case that exposes it:** `arr = [1, 2, 3], val = 2` → expected `2` with arr being `[1, 3, 3]`, actual returns `0` with arr being `[3, 2, 3]`.

</details>

---

**Challenge 4 — Recognize and apply**

**Problem:** You are given two sorted integer arrays `nums1` and `nums2`. Merge `nums2` into `nums1` as one sorted array. `nums1` has length `m + n` where the first `m` elements are the data and the last `n` are zeros (placeholder). Which pattern applies? Write the solution.

<details> <summary>Solution</summary>

**Pattern:** In-place merge from the end — fill from the back to avoid overwriting elements in nums1 that have not been processed yet.

```csharp
public static void Merge(int[] nums1, int m, int[] nums2, int n)
{
    int p1 = m - 1;
    int p2 = n - 1;
    int p = m + n - 1;

    while (p2 >= 0)
    {
        if (p1 >= 0 && nums1[p1] > nums2[p2])
            nums1[p--] = nums1[p1--];
        else
            nums1[p--] = nums2[p2--];
    }
}
```

**Complexity:** Time O(m + n) | Space O(1)

</details>

---

**Challenge 5 — Optimize**

```csharp
// This solution is correct but allocates O(n) extra space
// Optimize it to O(1) extra space
public static int[] RemoveDuplicatesFromSorted(int[] nums)
{
    var list = new List<int>();
    for (int i = 0; i < nums.Length; i++)
        if (i == 0 || nums[i] != nums[i - 1])
            list.Add(nums[i]);
    return list.ToArray();
}
```

<details> <summary>Solution</summary>

**Insight:** In a sorted array, duplicates are adjacent. Use the write-pointer pattern to overwrite duplicates in-place.

```csharp
public static int RemoveDuplicatesFromSorted(int[] nums)
{
    if (nums.Length == 0) return 0;
    int write = 1;
    for (int read = 1; read < nums.Length; read++)
        if (nums[read] != nums[read - 1])
            nums[write++] = nums[read];
    return write;
}
```

**Complexity:** Time O(n) | Space O(1)

</details>
