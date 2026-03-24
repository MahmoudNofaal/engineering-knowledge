# C# stackalloc

> `stackalloc` allocates a block of memory directly on the current thread's stack instead of the managed heap — no GC involvement, no allocation overhead, automatic cleanup when the method returns.

---

## When To Use It

Use it for short-lived, fixed-size buffers in hot paths where you want to avoid heap allocations entirely: parsing binary data, building temporary byte sequences, working with cryptographic inputs, or any tight loop that would otherwise create and discard small arrays on every iteration. The size must be known at the call site and must be small — stack space is typically 1 MB per thread. Don't use it for buffers whose size is determined by untrusted user input, and don't use it for anything that needs to outlive the current method's stack frame.

---

## Core Concept

Every thread gets a fixed-size stack. When you call a method, a stack frame is pushed; when the method returns, that frame is popped and the memory is automatically reclaimed — no GC, no finalizer, nothing. `stackalloc` carves out a slice of that frame for you. Before C# 7.2 you had to use `unsafe` code and work with raw pointers. Now you can assign the result directly to a `Span<T>`, which gives you bounds checking and full BCL compatibility while staying on the stack. The only real constraints are: the size has to fit the stack (keep it under a few kilobytes as a rule of thumb), and the `Span<T>` you assign it to cannot be stored in a field, returned from the method, or captured in a lambda — because once the frame is gone, that memory is gone.

---

## The Code
```csharp
// --- Basic: stack-allocate a buffer and use it via Span<T> ---
// No unsafe keyword needed when assigning to Span<T>
static int SumSmallArray(ReadOnlySpan<int> input)
{
    Span<int> buffer = stackalloc int[8];   // 8 ints = 32 bytes on the stack
    input[..Math.Min(input.Length, 8)].CopyTo(buffer);

    int sum = 0;
    foreach (int n in buffer[..Math.Min(input.Length, 8)])
        sum += n;
    return sum;
}
```
```csharp
// --- Parsing: avoid allocating a temporary byte array ---
static Guid ParseGuidFast(ReadOnlySpan<char> input)
{
    Span<byte> bytes = stackalloc byte[16];
    // Convert.FromHexString overload that writes into a Span avoids any heap allocation
    // This pattern is common in high-throughput request parsing
    if (Guid.TryParseExact(input, "N", out var result))
        return result;
    return Guid.Empty;
}
```
```csharp
// --- Conditional stackalloc: fall back to heap for large inputs ---
// Standard pattern in the BCL (e.g., System.Text.Json internals)
const int StackThreshold = 256;

static void ProcessData(ReadOnlySpan<byte> input)
{
    byte[]? rentedArray = null;
    Span<byte> buffer = input.Length <= StackThreshold
        ? stackalloc byte[StackThreshold]
        : (rentedArray = System.Buffers.ArrayPool<byte>.Shared.Rent(input.Length));

    try
    {
        input.CopyTo(buffer);
        // work with buffer...
    }
    finally
    {
        if (rentedArray is not null)
            System.Buffers.ArrayPool<byte>.Shared.Return(rentedArray);
    }
}
```
```csharp
// --- Raw unsafe pointer style (pre-C# 7.2, still valid) ---
unsafe static void LegacyStyle()
{
    byte* ptr = stackalloc byte[64];
    ptr[0] = 0xFF;
    ptr[1] = 0x00;
    // no bounds checking — ptr[100] would silently corrupt memory
}
```
```csharp
// --- What NOT to do: returning a Span backed by stackalloc ---
// This does not compile — the compiler catches it:
// static Span<int> DangerousReturn()
// {
//     Span<int> local = stackalloc int[4];
//     return local;   // CS8352: cannot use local in this context
// }

// Also illegal — storing it in a field:
// class Bad { Span<int> _field = stackalloc int[4]; } // ref struct can't be a field
```

---

## Gotchas

- **The size expression is evaluated at runtime but must fit the stack right now.** `stackalloc byte[n]` where `n` comes from user input will compile without complaint and cause a `StackOverflowException` at runtime if `n` is large — and `StackOverflowException` cannot be caught; it kills the process. Always cap with a constant: `stackalloc byte[Math.Min(n, MaxStack)]` or use the conditional heap-fallback pattern above.
- **`stackalloc` memory is not zero-initialized by default in unsafe contexts — but it is when assigned to `Span<T>`.** When you write `Span<byte> buf = stackalloc byte[64]`, the CLR zero-initializes the buffer for safety. In an `unsafe` block with a raw pointer, you get whatever garbage was on the stack. This difference matters for security-sensitive code where you might otherwise assume the buffer is clean.
- **You can't use `stackalloc` inside a `try` block with certain catches in older C#.** Prior to C# 9, using `stackalloc` in a method that had a `try/catch` could produce a compile error in some configurations. This is largely resolved in modern C#, but if you're targeting netstandard2.0 or older tooling and hitting a strange error, this is why.
- **`Span<T>` backed by `stackalloc` is a `ref struct` — it cannot cross async boundaries.** You cannot `await` anything after creating a stack-allocated `Span<T>` in the same scope, because the async state machine would need to preserve the `Span` across a suspension point, which requires it to be stored on the heap. The compiler enforces this, but the error message ("cannot use ref struct in async method") can be confusing if you don't know why.
- **Recursive methods with `stackalloc` multiply stack usage by call depth.** Each recursive call allocates another slice. A method that allocates 512 bytes via `stackalloc` and recurses 200 levels deep uses 100 KB of stack — half your budget. Never use `stackalloc` in recursive code without a hard depth limit.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between stack and heap memory, and whether you know how to write allocation-free code in .NET beyond just "use structs."

**Common question form:** "How would you avoid allocations in a hot path that needs a temporary buffer?" or "What's the difference between `stackalloc` and `ArrayPool`?" or "Why can't you return a `Span<T>` from a method?"

**The depth signal:** A junior knows `stackalloc` puts memory on the stack and is "faster." A senior explains the *zero-initialization difference* between `Span<T>` and pointer assignment, knows the conditional `stackalloc`-or-`ArrayPool` pattern that the BCL itself uses (e.g., in `System.Text.Json`, `Encoding`, and `Regex`), and can articulate exactly why `Span<T>` can't cross an `await` — the async state machine is a heap-allocated class, and storing a stack pointer inside a heap object would be a dangling reference the moment the stack frame is reclaimed.

---

## Related Topics

- [[dotnet/memory-and-span.md]] — `Span<T>` is the safe wrapper that makes `stackalloc` usable without `unsafe`; the two are inseparable in modern low-allocation code
- [[dotnet/csharp-unsafe-code.md]] — the pre-`Span` way to use `stackalloc` via raw pointers; explains why the pointer-based version requires `unsafe` and has no bounds checking
- [[dotnet/csharp-garbage-collector.md]] — the entire motivation for `stackalloc` is avoiding Gen 0 allocations; understanding GC pressure makes the trade-off concrete
- [[dotnet/csharp-ref-out-in.md]] — `ref` returns and `ref` locals work alongside `Span<T>` to pass stack memory between methods without copying it to the heap

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/stackalloc](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/stackalloc)

---
*Last updated: 2026-03-24*