# C# Unsafe Code

> Code marked with the `unsafe` keyword that can use raw pointers — bypassing the managed type system for direct memory access, interop with native libraries, or maximum performance in extremely specific scenarios.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Direct pointer arithmetic, fixed memory addresses, unmanaged struct access |
| **Enable** | `<AllowUnsafeBlocks>true</AllowUnsafeBlocks>` in `.csproj` |
| **Use when** | P/Invoke interop, SIMD intrinsics, specific zero-copy patterns |
| **Avoid when** | Any scenario Span\<T\> or managed code can handle |
| **C# version** | C# 1.0 |

---

## When To Use It

Use `unsafe` code only when the managed alternatives genuinely can't meet the requirement — usually P/Invoke interop with native libraries that accept `void*`, or when writing vectorised SIMD code with `System.Runtime.Intrinsics`. For everything else — zero-allocation processing, slicing, binary parsing — `Span<T>` and `stackalloc` cover the use cases without unsafe semantics.

---

## Core Concept

In managed C#, the GC can move objects in memory (compaction). Pointers to managed objects would become invalid after a GC compaction. `unsafe` pointers bypass the managed type system, so you must either:
1. `fixed` pin a managed object so the GC can't move it (temporary)
2. Use `stackalloc` (stack memory — GC never moves it)
3. Use unmanaged memory (`Marshal.AllocHGlobal`, `NativeMemory.Alloc`)

Everything inside an `unsafe` block bypasses bounds checking and type safety. A wrong pointer arithmetic expression causes memory corruption or a crash — no `IndexOutOfRangeException`.

---

## The Code

**`fixed` — pin managed memory for pointer access**
```csharp
unsafe void CopyBytes(byte[] source, byte[] dest, int count)
{
    fixed (byte* src = source, dst = dest)
    {
        // src and dst are pinned — GC won't move them during this block
        Buffer.MemoryCopy(src, dst, dest.Length, count);
    }
    // Pinning released when fixed block exits
}
```

**Pointer arithmetic and struct access**
```csharp
unsafe void ProcessPixels(byte* pixels, int pixelCount)
{
    for (int i = 0; i < pixelCount; i++)
    {
        byte* px = pixels + (i * 4); // RGBA
        px[0] = (byte)(px[0] * 0.9); // darken red channel
        px[1] = (byte)(px[1] * 0.9);
        px[2] = (byte)(px[2] * 0.9);
        // px[3] — alpha unchanged
    }
}
```

**P/Invoke interop pattern**
```csharp
using System.Runtime.InteropServices;

// Preferred: use LibraryImport (source-gen P/Invoke, C# 11+)
[LibraryImport("native.dll")]
private static partial int NativeCompress(byte* input, int inputLen, byte* output, int outputLen);

// Or classic DllImport
[DllImport("native.dll")]
private static extern int NativeCompress(IntPtr input, int inputLen, IntPtr output, int outputLen);

unsafe int Compress(ReadOnlySpan<byte> data, Span<byte> output)
{
    fixed (byte* inputPtr  = data,
                 outputPtr = output)
    {
        return NativeCompress(inputPtr, data.Length, outputPtr, output.Length);
    }
}
```

**`sizeof` — compile-time struct size**
```csharp
unsafe void Example()
{
    Console.WriteLine(sizeof(int));     // 4
    Console.WriteLine(sizeof(long));    // 8
    Console.WriteLine(sizeof(double));  // 8

    // sizeof on unmanaged user-defined struct
    Console.WriteLine(sizeof(Point));  // depends on layout
}

struct Point { public float X, Y; } // 8 bytes
```

---

## Gotchas

- **Unpinned managed objects can be moved by GC mid-operation.** Always use `fixed` when working with pointers to managed memory.
- **No bounds checking.** `ptr[10000]` will access arbitrary memory. Every pointer arithmetic operation must be manually verified.
- **`fixed` has a cost.** Pinned objects cannot be compacted — pinning many objects or holding pins too long degrades GC efficiency.
- **`unsafe` code can corrupt managed state.** A pointer write into managed object headers crashes the process in unpredictable ways.
- **Prefer `Span<T>` over `unsafe` for most slicing/parsing scenarios.** `Span<T>` is safe, readable, and nearly as fast.

---

## Interview Angle

**What they're really testing:** Whether you understand the managed/unmanaged boundary and know that `Span<T>` handles most "I need unsafe" scenarios safely.

**Common question forms:**
- "When would you use `unsafe` code?"
- "What does `fixed` do?"

**The depth signal:** A senior reaches for `Span<T>` and `stackalloc` first and uses `unsafe` only when those can't work — typically P/Invoke interop. They know `fixed` pins objects to prevent GC movement and should be held as briefly as possible.

---

## Related Topics

- [[dotnet/csharp/csharp-span-memory.md]] — The safe alternative for most zero-copy operations
- [[dotnet/csharp/csharp-stackalloc.md]] — Stack allocation — usable without `unsafe` via `Span<T>`

---

## Source

[Unsafe code — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/unsafe-code)

---
*Last updated: 2026-04-06*