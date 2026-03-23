# C# Unsafe Code

> Unsafe code lets you work directly with raw memory pointers in C#, bypassing the GC and the type system entirely.

---

## When To Use It

Use it when you need to squeeze the last bit of performance out of memory-intensive operations: parsing binary protocols, writing image/audio processing pipelines, interoperating with native libraries that expect raw pointers, or implementing data structures that can't afford GC overhead. Don't reach for it until you've exhausted `Span<T>`, `Memory<T>`, and `stackalloc` — those cover 90% of low-level memory needs without the risks. Unsafe code requires the `<AllowUnsafeBlocks>true</AllowUnsafeBlocks>` MSBuild property and conscious sign-off that you're taking ownership of memory safety.

---

## Core Concept

Normally the CLR tracks every object reference so the GC can move objects around during compaction without breaking your code. Unsafe code steps outside that guarantee. You get a raw pointer — just an integer holding a memory address — and you can read or write whatever is at that address. Nothing stops you from going one element past the end of an array, writing into memory owned by another object, or dereferencing a pointer after the GC has moved or collected what it pointed to. The `fixed` statement is the bridge: it pins a managed object in place so the GC can't move it while you hold a pointer to it. Once you leave the `fixed` block, the pin is released and the GC can do what it wants again. Everything unsafe must live inside an `unsafe` block or method marked `unsafe`.

---

## The Code
```csharp
// --- Basic pointer arithmetic: sum an array without bounds checks ---
unsafe static long SumFast(int[] data)
{
    long total = 0;
    fixed (int* ptr = data)          // pin the array; ptr is a raw pointer to element 0
    {
        int* end = ptr + data.Length;
        for (int* p = ptr; p < end; p++)
            total += *p;             // dereference pointer to read the int
    }                                // array is unpinned here
    return total;
}
```
```csharp
// --- stackalloc: allocate a buffer on the stack, no GC involved ---
unsafe static void ParseHeader(ReadOnlySpan<byte> input)
{
    // stackalloc returns a pointer; wrapping in Span<byte> keeps it manageable
    Span<byte> buffer = stackalloc byte[64];
    input[..Math.Min(input.Length, 64)].CopyTo(buffer);

    fixed (byte* ptr = buffer)
    {
        // read a little-endian int32 at offset 0
        int magic = *(int*)ptr;
        Console.WriteLine($"Magic: 0x{magic:X8}");
    }
}
```
```csharp
// --- Struct pointer: mutate a struct in place without copying ---
public struct Vector3
{
    public float X, Y, Z;
}

unsafe static void Normalize(Vector3* v)
{
    float len = MathF.Sqrt(v->X * v->X + v->Y * v->Y + v->Z * v->Z);
    if (len == 0) return;
    v->X /= len;
    v->Y /= len;
    v->Z /= len;
}

unsafe static void Example()
{
    var vec = new Vector3 { X = 3, Y = 4, Z = 0 };
    Normalize(&vec);                 // pass address of stack-allocated struct
    Console.WriteLine(vec.X);       // 0.6
}
```
```csharp
// --- Casting via pointer: reinterpret bytes without allocation ---
// Classic trick to get the raw bits of a float as an int
unsafe static int FloatToIntBits(float f)
{
    return *(int*)&f;                // reinterpret the 4 bytes of f as an int
}
```
```csharp
// --- Interop: passing a pinned buffer to a native function ---
// Avoids marshalling overhead when the native API expects a raw byte pointer
[DllImport("native.dll")]
static extern void ProcessBuffer(byte* data, int length);

unsafe static void CallNative(byte[] managed)
{
    fixed (byte* ptr = managed)
    {
        ProcessBuffer(ptr, managed.Length);
    }
}
```

---

## Gotchas

- **Pinning causes GC heap fragmentation.** Every `fixed` block pins an object, which means the GC can't move it during compaction. If you pin many small objects simultaneously — or hold a pin open for a long time — you fragment the managed heap and force the GC to work harder. For long-lived native interop scenarios, allocate buffers with `GCHandle.Alloc(obj, GCHandleType.Pinned)` explicitly so you control pin lifetime, or use `NativeMemory.Alloc` to stay off the managed heap entirely.
- **`stackalloc` will silently blow the stack if the size isn't bounded.** Stack space is typically 1 MB per thread. `stackalloc byte[userInput]` with unvalidated input will cause a `StackOverflowException` that can't be caught and crashes the process. Always cap the size with a hard constant or a checked min.
- **Pointer arithmetic doesn't throw on out-of-bounds — it silently corrupts memory.** There's no `IndexOutOfRangeException`. Writing past the end of a pinned array overwrites whatever happens to be at that address — another object, GC metadata, or the return address of a stack frame. These bugs are hard to reproduce and produce symptoms far from the actual mistake.
- **`fixed` can only pin blittable types.** A type is blittable if it has the same memory representation in managed and unmanaged code — `int`, `float`, `byte`, structs of those. If your struct contains a `string`, `bool`, or reference type, `fixed` will refuse to compile. You need to manually marshal or restructure the type.
- **The `unsafe` keyword doesn't make `Span<T>` unnecessary — it's the opposite.** Most code that used to require `unsafe` can now use `Span<T>` and `MemoryMarshal`, which are bounds-safe and work without `AllowUnsafeBlocks`. If you're writing new code and find yourself reaching for pointers, check `MemoryMarshal.Cast`, `MemoryMarshal.Read`, and `Unsafe.As` first — they may give you what you need without a raw pointer in sight.

---

## Interview Angle

**What they're really testing:** Whether you understand the CLR's memory model, what the GC actually does during compaction, and where the boundaries of the managed runtime are.

**Common question form:** "When would you use unsafe code in C#?" or "What is `fixed` and why does it exist?" or "How does `stackalloc` differ from a normal array allocation?"

**The depth signal:** A junior knows that unsafe code "lets you use pointers" and is "faster." A senior explains the specific mechanism: the GC compacts the heap by moving objects, which invalidates any raw pointer into managed memory — `fixed` exists to temporarily suspend that freedom for a specific object. They also know that `stackalloc` bypasses the heap entirely (no GC involvement, no allocation cost, automatic cleanup when the stack frame is popped), and can articulate why `Span<T>` over `stackalloc` is preferred over raw pointers for new code — it gives you bounds checking, slicing, and compatibility with the rest of the BCL without leaving the safety guarantees of the CLR.

---

## Related Topics

- [[dotnet/memory-and-span.md]] — `Span<T>` and `MemoryMarshal` cover most of what used to require unsafe code, with bounds safety intact; know this before reaching for pointers
- [[dotnet/csharp-garbage-collector.md]] — GC compaction is exactly why `fixed` exists; understanding Gen 2 collections and LOH makes pinning costs concrete
- [[dotnet/csharp-idisposable.md]] — `NativeMemory.Alloc` and `GCHandle` both need explicit cleanup; the `IDisposable` pattern is how you wrap them safely
- [[dotnet/interop-and-pinvoke.md]] — native interop is the most common production reason to pin managed memory; unsafe code and P/Invoke are frequently used together

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/unsafe-code](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/unsafe-code)

---
*Last updated: 2026-03-23*