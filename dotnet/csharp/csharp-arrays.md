# C# Arrays

> A fixed-size, ordered collection of elements of the same type stored in contiguous memory — O(1) index access, zero per-element overhead, the fastest collection in .NET.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Fixed-size contiguous block of typed memory |
| **Use when** | Size known upfront; raw performance; interop; `Span<T>` slicing |
| **Avoid when** | Need to grow/shrink dynamically — use `List<T>` |
| **C# version** | C# 1.0 (range/index syntax: C# 8.0) |
| **Namespace** | `System` (implicitly) |
| **Key types** | `T[]`, `T[,]` (rectangular), `T[][]` (jagged) |

---

## When To Use It

Use arrays when the size is known upfront and won't change, and when raw performance or memory layout matters. Arrays are the fastest collection in .NET — elements sit in contiguous memory with no overhead per element, cache-friendly for sequential access.

Use arrays for: fixed lookup tables, buffers for I/O or cryptography, `Span<T>` slicing without allocation, and interop with native code. Don't use arrays when you need to dynamically add or remove elements — that's `List<T>`.

---

## Core Concept

An array is a single contiguous block of memory divided into equal-sized slots. `int[] nums = new int[5]` allocates one block for five integers. Accessing `nums[2]` is a direct memory offset calculation — no searching, no indirection, always O(1). This is why arrays are cache-friendly and why `Span<T>` is built on top of them.

The fixed size is the tradeoff: you commit at creation time. Growing requires allocating a new array and copying — exactly what `List<T>` does internally when it runs out of capacity.

**Two multi-dimensional flavours:**
- `int[,]` (rectangular): one contiguous block, every row the same length — good for mathematical matrices
- `int[][]` (jagged): array of arrays, each row independent — better cache behaviour for large sparse data, and the only one that works with LINQ

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Arrays, multi-dimensional, `Array` static methods |
| C# 8.0 | .NET Core 3.0 | Index from end: `^1`, range: `1..4` |
| C# 12.0 | .NET 8 | Collection expressions: `int[] a = [1, 2, 3]` |

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Index access (`arr[i]`) | O(1) | Direct memory offset — fastest possible |
| Sequential iteration | O(n) | Cache-friendly — prefetcher works well |
| Binary search | O(log n) | Only on sorted arrays |
| Linear search | O(n) | `Array.IndexOf` or `Array.Find` |
| `Array.Sort` | O(n log n) | TimSort — in-place |
| Resize (copy to new) | O(n) | No built-in resize — must copy |

**Allocation behaviour:** One heap allocation for the whole block, regardless of element count. Value type elements (`int[]`) store values directly — no per-element boxing. Reference type elements (`string[]`) store pointers.

**Benchmark notes:** For sequential read-heavy workloads, arrays outperform `List<T>` because the backing store is accessed directly without a bounds check on the outer `List` object. The JIT also elides bounds checks inside loops that can be proven safe.

---

## The Code

**Declaration, initialisation, index and range access**
```csharp
// Allocate — elements default to 0/null/false
int[] nums = new int[5];
nums[0] = 10;

// Initialise with values — size inferred
int[] scores = { 85, 92, 78, 95, 60 };
string[] names = new string[] { "Alice", "Bob", "Charlie" };

// Collection expression (C# 12)
int[] primes = [2, 3, 5, 7, 11];

// Index from end (^): ^1 = last, ^2 = second-to-last
Console.WriteLine(scores[^1]); // 60 — last element
Console.WriteLine(scores[^2]); // 95

// Range (..): start..end — end is exclusive
int[] middle  = scores[1..4];  // { 92, 78, 95 }
int[] last3   = scores[^3..];  // { 78, 95, 60 }
int[] copy    = scores[..];    // full copy

// Range creates a NEW array — use Span<T> to avoid allocation
Span<int> slice = scores.AsSpan()[1..4]; // no allocation — view into original
```

**Sorting, searching, utilities**
```csharp
int[] data = { 5, 3, 8, 1, 9, 2 };

Array.Sort(data);                           // in-place TimSort: [1,2,3,5,8,9]
int idx  = Array.BinarySearch(data, 5);    // 3 — only valid after Sort
int idx2 = Array.IndexOf(data, 5);         // linear scan — works unsorted

// Sort with custom comparer
string[] words = { "banana", "apple", "cherry" };
Array.Sort(words, StringComparer.OrdinalIgnoreCase);

// Array.Find / Exists / FindAll
int first = Array.Find(data, n => n > 5);           // 8
bool any  = Array.Exists(data, n => n > 10);        // false
int[] big = Array.FindAll(data, n => n > 3);        // [5,8,9]

// Copy and fill
int[] dest = new int[data.Length];
Array.Copy(data, dest, data.Length);
Array.Fill(dest, 0, 2, 3);              // fill 3 elements starting at index 2 with 0
```

**Rectangular vs jagged multi-dimensional**
```csharp
// Rectangular: one block — all rows same length
int[,] grid = new int[3, 4];
grid[1, 2] = 42;
Console.WriteLine(grid.GetLength(0)); // 3 rows
Console.WriteLine(grid.GetLength(1)); // 4 cols

int[,] matrix = { { 1, 2, 3 }, { 4, 5, 6 } };

// Jagged: array of arrays — rows can differ in length
int[][] jagged = new int[3][];
jagged[0] = new[] { 1, 2 };
jagged[1] = new[] { 3, 4, 5, 6 };
jagged[2] = new[] { 7 };
Console.WriteLine(jagged[1][2]); // 5

// Jagged works with LINQ; rectangular doesn't cleanly
var flat = jagged.SelectMany(row => row); // [1,2,3,4,5,6,7]
```

**Array covariance — compile-time trap**
```csharp
// C# allows this assignment — array covariance
object[] objs = new string[3];
objs[0] = "hello"; // fine
// objs[1] = 42;   // ArrayTypeMismatchException at runtime — NOT a compile error

// Generic collections don't have this problem
// List<object> badList = new List<string>(); // compile error — correct!
```

---

## Real World Example

A binary protocol parser reads a fixed-format frame header. Using arrays and `Span<T>` avoids heap allocations on the hot path — critical for a service processing thousands of frames per second.

```csharp
public readonly struct FrameHeader
{
    public ushort MagicNumber { get; }
    public byte   Version     { get; }
    public byte   Flags       { get; }
    public ushort PayloadLength { get; }

    private FrameHeader(ushort magic, byte version, byte flags, ushort payloadLen)
        => (MagicNumber, Version, Flags, PayloadLength) = (magic, version, flags, payloadLen);

    // Parse from a fixed-size byte span — zero allocation
    public static bool TryParse(ReadOnlySpan<byte> data, out FrameHeader header)
    {
        const int HeaderSize = 6;
        header = default;

        if (data.Length < HeaderSize) return false;

        ushort magic = System.Buffers.Binary.BinaryPrimitives.ReadUInt16BigEndian(data[..2]);
        if (magic != 0xFACE) return false; // magic number check

        header = new FrameHeader(
            magic:      magic,
            version:    data[2],
            flags:      data[3],
            payloadLen: System.Buffers.Binary.BinaryPrimitives.ReadUInt16BigEndian(data[4..6]));
        return true;
    }
}

// In the hot path: read into a stack-allocated buffer, parse without heap allocation
public void ProcessIncoming(Stream stream)
{
    Span<byte> headerBuf = stackalloc byte[6]; // stack — no GC
    int read = stream.Read(headerBuf);

    if (read == 6 && FrameHeader.TryParse(headerBuf, out var header))
    {
        byte[] payload = new byte[header.PayloadLength]; // heap only for payload
        stream.ReadExactly(payload);
        ProcessFrame(header, payload);
    }
}
```

*The key insight: `stackalloc` + `Span<T>` + `ReadOnlySpan<byte>` slicing means the header parsing path allocates nothing on the heap. At 50,000 frames/second, that's 50,000 heap allocations per second eliminated — a measurable reduction in GC pressure.*

---

## Common Misconceptions

**"Range syntax (`1..4`) is a zero-allocation slice"**
Array ranges create a new array and copy the elements. `scores[1..4]` allocates. For zero-allocation slicing, use `scores.AsSpan()[1..4]` — this returns a `Span<T>` that is a view into the original array.

**"Rectangular `int[,]` and jagged `int[][]` are just different syntax"**
They have completely different memory layouts and different performance profiles. Rectangular is one contiguous block — better cache behaviour for dense full-row iteration. Jagged is an array of pointers to separate row arrays — each row access requires an extra pointer dereference but rows can be different lengths. Jagged is the one that works with LINQ and most BCL APIs.

**"`Array.BinarySearch` works on any array"**
It only works correctly on a sorted array. On an unsorted array, the result is undefined (you get an index or a negative value with no exception), and the returned index may not correspond to the target element. Sort first, or use `Array.IndexOf` for linear search on unsorted data.

---

## Gotchas

- **Bounds checking is runtime-only.** `arr[arr.Length]` compiles fine and throws `IndexOutOfRangeException` at runtime. The `^` index-from-end syntax helps (`arr[^1]` is always the last element), but manual index arithmetic still causes off-by-one bugs.

- **Array covariance is a runtime trap.** `string[]` is assignable to `object[]` at compile time. Writing a non-`string` into that `object[]` variable throws `ArrayTypeMismatchException` at runtime, not a compile error. Generic collections (`List<string>`) don't have this problem.

- **`Array.BinarySearch` returns a *negative bitwise complement* on miss, not `-1`.** Check `idx >= 0` for found, `idx < 0` for not-found. The complement (`~idx`) gives the insertion point. Checking `idx == -1` misses most not-found cases.

- **Passing an array to a method gives full write access.** There's no `readonly` modifier for array parameters. Use `ReadOnlySpan<T>` or return `IReadOnlyList<T>` to prevent callers from mutating your internal arrays.

- **`Array.Copy` is a shallow copy.** For arrays of reference types, it copies the pointers, not the objects. Both arrays point to the same objects after the copy.

---

## Interview Angle

**What they're really testing:** Memory model understanding — contiguous allocation, cache locality, O(1) access — and the tradeoffs vs dynamic collections.

**Common question forms:**
- "When would you use an array over a `List<T>`?"
- "What's the difference between a jagged and rectangular array?"
- "What happens if you access an index out of bounds?"

**The depth signal:** A junior says "arrays are fixed-size." A senior explains *why* that matters: contiguous memory layout gives arrays O(1) access and excellent cache performance, and `Span<T>` is built on top of arrays for zero-allocation slicing. They know the covariance trap, that `BinarySearch` returns a bitwise complement on miss, and that jagged arrays outperform rectangular for LINQ-compatible access patterns.

---

## Related Topics

- [[dotnet/csharp/csharp-collections-list.md]] — `List<T>` wraps an array internally and handles resizing
- [[dotnet/csharp/csharp-span-memory.md]] — `Span<T>` and `Memory<T>` are zero-allocation slice APIs built on arrays
- [[dotnet/csharp/csharp-linq-basics.md]] — LINQ operators work on `IEnumerable<T>`, which arrays implement

---

## Source

[Arrays — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/arrays/)

---
*Last updated: 2026-04-06*