# C# — Span<T> and Memory<T>

> Stack-allocated views over contiguous memory — a way to slice and read arrays, strings, and buffers without copying anything or allocating on the heap.

---

## When To Use It

Use `Span<T>` when you need to work with a slice of an array, string, or stack-allocated buffer in a hot path where allocations matter — parsers, serializers, binary protocol handlers, and anything processing large byte streams. Use `Memory<T>` when you need the same thing but across `async` boundaries, since `Span<T>` can't be stored on the heap or used in async methods. Don't reach for either in ordinary business logic — the complexity cost isn't worth it unless you've profiled and confirmed that allocations are the bottleneck.

---

## Core Concept

Normally, when you take a substring or a slice of an array, C# allocates a new object on the heap and copies the data into it. `Span<T>` avoids that entirely — it's just a pointer and a length, stored on the stack, pointing into whatever memory already exists. You can slice a `Span<T>` ten times and never allocate. The constraint that makes this safe is that `Span<T>` is a `ref struct` — the compiler forbids it from ever leaving the stack, which means no heap allocation, no GC pressure, but also no storing it in a field, no boxing it, and no using it in async methods. `Memory<T>` is the heap-safe wrapper that trades the stack restriction for async compatibility — it can be stored in fields and awaited, but it costs slightly more to convert back to a `Span<T>` when you need to actually read/write the data.

---

## The Code

### Span<T> — slice without allocating
```csharp
byte[] buffer = new byte[] { 1, 2, 3, 4, 5, 6, 7, 8 };

Span<byte> full = buffer;          // no allocation — just a view
Span<byte> slice = full.Slice(2, 4); // bytes 3,4,5,6 — still no allocation

slice[0] = 99; // writes directly into the original buffer
Console.WriteLine(buffer[2]); // 99 — same memory
```

### Parsing without allocating a substring
```csharp
// Old way — allocates a new string for each Split segment
string csv = "alice,bob,charlie";
string[] parts = csv.Split(','); // 3 heap allocations

// Span way — zero allocations
ReadOnlySpan<char> span = csv.AsSpan();

while (true)
{
    int comma = span.IndexOf(',');
    ReadOnlySpan<char> segment = comma == -1 ? span : span[..comma];

    Console.WriteLine(segment.ToString()); // ToString only when actually needed
    
    if (comma == -1) break;
    span = span[(comma + 1)..];
}
```

### stackalloc — allocate on the stack entirely
```csharp
// No heap allocation at all — buffer lives on the stack
Span<byte> stackBuffer = stackalloc byte[256];

for (int i = 0; i < stackBuffer.Length; i++)
    stackBuffer[i] = (byte)i;

// Safe to pass to any method that accepts Span<byte>
ProcessBuffer(stackBuffer);

void ProcessBuffer(Span<byte> data) =>
    Console.WriteLine($"First byte: {data[0]}, Length: {data.Length}");
```

### Memory<T> — when you need to cross async boundaries
```csharp
class DataProcessor
{
    // Memory<T> can live in a field; Span<T> cannot
    private readonly Memory<byte> _buffer;

    public DataProcessor(byte[] data)
    {
        _buffer = data.AsMemory();
    }

    public async Task ProcessAsync()
    {
        // Convert to Span only when doing synchronous work
        Span<byte> span = _buffer.Span;
        span[0] = 0xFF;

        await Task.Delay(10); // can await freely; Memory<T> survives this

        // Can slice Memory<T> same as Span<T>
        Memory<byte> slice = _buffer.Slice(1, 4);
        await WriteAsync(slice);
    }

    private Task WriteAsync(Memory<byte> data) => Task.CompletedTask;
}
```

### MemoryMarshal — interop and reinterpretation
```csharp
byte[] raw = new byte[8];
// Reinterpret the byte array as a span of longs — zero copy, zero allocation
Span<long> longs = MemoryMarshal.Cast<byte, long>(raw);

longs[0] = 0x0102030405060708L;

// raw now contains the bytes of that long value
Console.WriteLine(raw[0]); // endian-dependent byte value
```

---

## Gotchas

- **`Span<T>` cannot be used in async methods at all** — the compiler error ("cannot use ref struct in async method") means you have to convert to `Memory<T>` before the async boundary and convert back to `Span<T>` inside the synchronous segments. Trying to work around this with `Task.Run` or casting will not work.
- **`stackalloc` over ~1KB risks stack overflow** — the stack is limited (typically 1MB on .NET). For anything larger or of unknown size, use a heap-allocated array or `ArrayPool<T>` instead. A common pattern is `stackalloc` for small sizes, `ArrayPool` for large ones, guarded by a size check.
- **Slicing does not copy — writes affect the original** — this is the point, but it surprises people. If you hand a `Span<T>` slice to a method, that method can mutate your original buffer. Use `ReadOnlySpan<T>` to prevent this.
- **`Span<T>` cannot be stored in a class field** — because it's a `ref struct`, the compiler will reject any attempt to put it in a field, capture it in a lambda, or store it in a generic type. If you hit this, `Memory<T>` is always the answer.
- **`string.AsSpan()` returns `ReadOnlySpan<char>`, not `Span<char>`** — strings are immutable in .NET, so you can never get a writable `Span<char>` from a `string`. If you need to mutate characters in place, you need a `char[]` or use `stackalloc char[n]` to build it yourself.

---

## Interview Angle

**What they're really testing:** Whether you understand memory layout, heap vs stack allocation, and how .NET's GC creates performance pressure — not just that `Span<T>` is "faster."

**Common question form:** "How would you parse a large file/stream without excessive allocations?" or "What's the difference between `Span<T>` and `Memory<T>`?" or "What is a `ref struct` and why does it matter?"

**The depth signal:** A junior says `Span<T>` avoids copies and is faster than substring. A senior explains *why*: that heap allocations aren't free because they pressure the GC, that `Span<T>` is a `ref struct` which means the CLR can enforce stack-only lifetime without a GC handle, and that `Memory<T>` exists precisely because `async` state machines are compiler-generated classes that store locals as fields — which is why a `ref struct` can't survive an `await`. The senior also knows `ArrayPool<T>` as the companion pattern for when `stackalloc` sizes are too large or dynamic.

---

## Related Topics

- [[dotnet/csharp-arraypool.md]] — `ArrayPool<T>` is the companion to `Span<T>` for heap-allocated buffers that need to be rented and returned rather than GC'd; used together in high-throughput code.
- [[dotnet/csharp-ref-struct.md]] — `Span<T>` is a `ref struct`; understanding what that constraint means explains every limitation `Span<T>` has.
- [[dotnet/csharp-ienumerable.md]] — Contrasts with `IEnumerable<T>`'s heap-based, GC-pressuring iteration model; clarifies when to reach for each.
- [[dotnet/csharp-unsafe-pointers.md]] — `Span<T>` is the safe alternative to raw pointer arithmetic; understanding both shows where the boundary between safe and unsafe performance code sits.

---

## Source

https://learn.microsoft.com/en-us/dotnet/standard/memory-and-spans/memory-t-usage-guidelines

---
*Last updated: 2026-03-23*