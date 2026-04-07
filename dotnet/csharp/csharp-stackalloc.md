# C# stackalloc

> Allocates a block of memory on the stack instead of the heap — zero GC involvement, automatically freed when the method returns, used with `Span<T>` for small fixed-size buffers in performance-critical code.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Stack memory allocation — no GC, freed on method return |
| **Syntax** | `Span<byte> buf = stackalloc byte[256]` |
| **Use when** | Small temporary buffer in hot path; want zero GC pressure |
| **Avoid when** | Size known only at runtime and could be large; async methods |
| **C# version** | C# 1.0 (unsafe pointer), C# 7.2 (Span\<T\> safe form) |
| **Limit** | Stack is ~1 MB — large allocations cause `StackOverflowException` |

---

## When To Use It

Use `stackalloc` for small, fixed-size temporary buffers in synchronous hot-path code where you need zero heap allocation — cryptography, binary serialisation, protocol encoding, tiny scratch buffers.

Don't use it in `async` methods (state machine stores locals on heap, defeating the purpose), when size is user-controlled (overflow risk), or when the buffer might be large.

---

## Core Concept

When you write `Span<byte> buffer = stackalloc byte[256]`, the runtime moves the stack pointer — one CPU instruction. The 256 bytes are available instantly with no GC tracking. When the method returns, the stack pointer moves back and those bytes are gone. No allocation, no collection, no finaliser.

Before C# 7.2, `stackalloc` required `unsafe` code and produced a `byte*` pointer. Since 7.2, assigning to `Span<T>` is safe and doesn't require `unsafe`.

**The risk**: stack space is limited (default ~1 MB on .NET). A `stackalloc` of more than a few KB risks a `StackOverflowException`, especially in recursive methods. Keep `stackalloc` under ~1 KB and prefer heap allocation for anything larger.

---

## The Code

**Safe form with Span\<T\> (C# 7.2+)**
```csharp
void HashData(ReadOnlySpan<byte> data, Span<byte> output)
{
    Span<byte> temp = stackalloc byte[32]; // 32 bytes on stack — zero allocation
    System.Security.Cryptography.SHA256.HashData(data, temp);
    temp.CopyTo(output);
}
```

**Conditional stackalloc — use heap for larger sizes**
```csharp
const int StackThreshold = 256;

void ProcessBuffer(int size, ReadOnlySpan<byte> input)
{
    // Use stack for small, heap for large — avoids StackOverflow
    byte[]? heapBuffer = size > StackThreshold ? new byte[size] : null;
    Span<byte> buffer  = heapBuffer ?? stackalloc byte[StackThreshold];

    // ... use buffer ...
    // heapBuffer GC'd normally; stackalloc freed on method return
}
```

**`stackalloc` with inline array (NET 8 — [InlineArray])**
```csharp
// For fixed-size zero-allocation buffers — the modern pattern
[System.Runtime.CompilerServices.InlineArray(16)]
private struct Buffer16 { private byte _element; }

void WriteHeader(ref Buffer16 buf)
{
    Span<byte> span = buf; // zero allocation
    span[0] = 0xFF;
}
```

---

## Gotchas

- **Stack overflow on large or recursive allocations.** Keep `stackalloc` under ~1 KB. Never use it with a user-supplied size without capping it.
- **Cannot be used in `async` methods.** The async state machine stores locals on the heap, breaking stack semantics. Use `ArrayPool<byte>.Rent` for async hot paths.
- **`Span<T>` assigned from `stackalloc` must not outlive the method.** The compiler enforces this — you can't return a `Span<T>` that wraps a `stackalloc` buffer.
- **Initialisation: `stackalloc byte[n]` is zero-initialised by default in safe context.** Call `MemoryMarshal.CreateSpan` or `stackalloc byte[n] { ... }` with initializers.

---

## Source

[stackalloc — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/stackalloc)

---
*Last updated: 2026-04-06*