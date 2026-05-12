# C# Span\<T\> and Memory\<T\>

> `Span<T>` is a stack-only, zero-allocation window into a contiguous region of memory — an array slice, a string segment, or a stack-allocated buffer — without copying. `Memory<T>` is the heap-safe version for async contexts.

---

## Quick Reference

| | `Span<T>` | `Memory<T>` |
|---|---|---|
| **Backing** | Array, stack, unmanaged | Array, string (via `AsMemory()`) |
| **Storage** | Stack only (`ref struct`) | Heap-safe (regular struct) |
| **Async** | ❌ Cannot survive `await` | ✅ Can survive `await` |
| **Allocation** | Zero | Zero (wrapper struct) |
| **Convert** | `.AsSpan()` | `.AsMemory()` |
| **C# version** | C# 7.2 / .NET Core 2.1 | C# 7.2 / .NET Core 2.1 |

---

## When To Use It

Use `Span<T>` / `ReadOnlySpan<T>` whenever you need to process a sub-region of an array or string **without allocating a copy**. Canonical use cases: parsing protocols/CSV/JSON, slice-and-process without heap pressure, passing sub-arrays into methods that accept `ReadOnlySpan<byte>`.

Use `Memory<T>` when the slice needs to survive an `await` — `Span<T>` is a `ref struct` and cannot be stored on the heap (which the async state machine requires). Switch to `Memory<T>` at `async` boundaries, then call `.Span` inside synchronous sections.

---

## Core Concept

A `Span<T>` is a **ref struct** — a struct that can only live on the stack. It contains a pointer to the start of a memory region and a length. Creating one against an array, string, or `stackalloc` buffer costs nothing — no new object, no copy. Reading or writing through it accesses the underlying memory directly.

Because it must stay on the stack, `Span<T>` cannot:
- Be stored in a class field
- Be captured in a lambda
- Cross an `async`/`await` boundary
- Be boxed

`Memory<T>` lifts these restrictions by storing an object reference + offset + length instead of a raw pointer, at the cost of the `ref struct` guarantee. Access the `Span<T>` inside it via `.Span` property.

---

## The Code

**Creating spans from different sources**
```csharp
// From array
int[] array = { 1, 2, 3, 4, 5 };
Span<int> full   = array.AsSpan();
Span<int> slice  = array.AsSpan(1, 3);  // { 2, 3, 4 } — no copy
// Or: Span<int> slice = array.AsSpan()[1..4];

// From string
string text = "Hello, World!";
ReadOnlySpan<char> word = text.AsSpan(0, 5); // "Hello" — no copy

// Stack allocation — never touches heap
Span<byte> buffer = stackalloc byte[256];
buffer.Fill(0);
```

**Zero-allocation parsing**
```csharp
// Parse CSV row without allocating substrings
static void ParseRow(ReadOnlySpan<char> row)
{
    while (row.Length > 0)
    {
        int comma = row.IndexOf(',');
        ReadOnlySpan<char> field = comma >= 0 ? row[..comma] : row;

        // MemoryExtensions.TryParse — parse directly from span, no substring
        if (int.TryParse(field, out int value))
            Console.WriteLine($"int: {value}");
        else
            Console.WriteLine($"text: {field.ToString()}"); // allocate only for display

        if (comma < 0) break;
        row = row[(comma + 1)..];
    }
}

ParseRow("42,hello,99,world".AsSpan()); // zero allocations in the loop
```

**Span is a live view — mutations affect the original**
```csharp
int[] data = { 1, 2, 3, 4, 5 };
Span<int> mid = data.AsSpan(1, 3); // { 2, 3, 4 }
mid[0] = 99;
Console.WriteLine(data[1]); // 99 — Span and array share memory
```

**Crossing async boundaries — use Memory\<T\>**
```csharp
// WRONG: Span<T> can't survive await
async Task ProcessAsync(Span<byte> data, CancellationToken ct)
{
    await Task.Delay(1, ct); // compile error: cannot use Span<T> in async
}

// CORRECT: Memory<T> across await; slice to Span<T> inside sync sections
async Task ProcessAsync(Memory<byte> data, CancellationToken ct)
{
    await Task.Delay(1, ct); // fine — Memory<T> is a regular struct

    ReadOnlySpan<byte> sync = data.Span; // back to Span<T> for sync processing
    Console.WriteLine(sync.Length);
}
```

**`stackalloc` with Span — zero-heap buffer**
```csharp
void EncodeSmallMessage(ReadOnlySpan<byte> payload, Span<byte> output)
{
    Span<byte> header = stackalloc byte[4]; // stack — no GC
    System.Buffers.Binary.BinaryPrimitives.WriteInt32BigEndian(header, payload.Length);
    header.CopyTo(output);
    payload.CopyTo(output[4..]);
}
```

---

## Real World Example

A binary frame reader parses protocol headers directly from a network buffer using `ReadOnlySpan<byte>` — zero intermediate allocations per frame on a high-throughput socket server.

```csharp
public readonly ref struct ParsedFrame
{
    public ushort CommandId { get; init; }
    public ushort Flags     { get; init; }
    public ReadOnlySpan<byte> Payload { get; init; }
}

public static bool TryParseFrame(ReadOnlySpan<byte> buffer, out ParsedFrame frame)
{
    frame = default;
    if (buffer.Length < 8) return false;

    ushort magic = System.Buffers.Binary.BinaryPrimitives.ReadUInt16BigEndian(buffer[..2]);
    if (magic != 0xFACE) return false;

    ushort commandId     = BinaryPrimitives.ReadUInt16BigEndian(buffer[2..4]);
    ushort flags         = BinaryPrimitives.ReadUInt16BigEndian(buffer[4..6]);
    ushort payloadLength = BinaryPrimitives.ReadUInt16BigEndian(buffer[6..8]);

    if (buffer.Length < 8 + payloadLength) return false;

    frame = new ParsedFrame
    {
        CommandId = commandId,
        Flags     = flags,
        Payload   = buffer.Slice(8, payloadLength)
    };
    return true;
}
```

*The `ParsedFrame` is itself a `ref struct`, meaning it can contain a `ReadOnlySpan<byte>` field. At 100,000 frames/second, zero heap allocations per parse keeps GC pauses out of the critical path.*

---

## Gotchas

- **`Span<T>` cannot be stored in a field or captured in a lambda.** It's a `ref struct` — stack only. The compiler enforces this.
- **`Span<T>` cannot survive `await`.** Async state machines are heap classes that store locals as fields. Use `Memory<T>` as the parameter type across async boundaries.
- **Mutations through `Span<T>` affect the original.** A `Span<T>` is a view, not a copy. `span[0] = 99` writes to the original array.
- **`stackalloc` inside a loop allocates per iteration.** Move it outside the loop or use a fixed-size inline array (`[InlineArray]` in .NET 8).
- **`Memory<T>.Span` has a cost.** Each call to `.Span` on a non-array `Memory<T>` does work. Cache the span in a local if you call it multiple times in a tight loop.

---

## Interview Angle

**What they're really testing:** Whether you understand the stack-only constraint, why it exists, and when to use `Memory<T>` vs `Span<T>`.

**Common question forms:**
- "What is `Span<T>` and when would you use it?"
- "Why can't you use `Span<T>` in an async method?"
- "What's the difference between `Span<T>` and `Memory<T>`?"

**The depth signal:** A senior explains `ref struct` — the stack-only constraint exists because the async state machine is a heap-allocated class that would need to store the span as a field, which violates the `ref struct` rule. They know `Memory<T>` stores an object reference + offset instead of a raw pointer, enabling heap storage. They reach for `ReadOnlySpan<char>` for string parsing to avoid intermediate substring allocations.

---

## Related Topics

- [[dotnet/csharp/csharp-arrays.md]] — `Span<T>` is most commonly backed by arrays
- [[dotnet/csharp/csharp-strings.md]] — `ReadOnlySpan<char>` slices strings without allocation
- [[dotnet/csharp/csharp-stackalloc.md]] — Stack allocation creates the buffer that `Span<T>` wraps
- [[dotnet/csharp/csharp-async-await.md]] — The async boundary that forces `Span<T>` → `Memory<T>` switch

---

## Source

[Memory and Span — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/memory-and-spans/)

---
*Last updated: 2026-04-06*