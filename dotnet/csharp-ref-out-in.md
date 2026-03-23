# C# ref, out, and in Parameters

> `ref`, `out`, and `in` let you pass a variable by reference instead of by value — meaning the method works with the original memory location, not a copy.

---

## When To Use It

Use `out` when a method needs to return multiple values and one of them signals success/failure — the `TryParse` / `TryGet` pattern everywhere in the BCL. Use `ref` when you need to both read and write a caller's variable from inside a method, or when passing a large struct you want to mutate without copying. Use `in` when passing a large readonly struct to avoid the copy cost without allowing mutation. Don't use any of these as a substitute for returning a well-designed type — if you find yourself with four `out` parameters, return a record instead.

---

## Core Concept

By default C# passes everything by value: the method gets a copy of the argument, and changes to the parameter don't affect the caller's variable. These three keywords change that by passing the variable's address instead of its value. `ref` says "I might read and write this." `out` says "I will definitely write this before returning — I promise — and the caller's variable doesn't need to be initialized first." `in` says "I'll read this but never write it, and I want to avoid the copy cost." For value types the performance difference is real — passing a 64-byte struct by `in` or `ref` costs 8 bytes (a pointer) instead of 64. For reference types, you're already passing a reference, so `ref` on a reference type means "the method can replace the reference itself," which is rarely what you want.

---

## The Code
```csharp
// --- out: the TryParse pattern ---
// The caller doesn't need to initialize result before passing it.
// The method must assign it on every code path.
static bool TryDivide(int numerator, int denominator, out double result)
{
    if (denominator == 0)
    {
        result = 0;          // must assign even on the failure path
        return false;
    }
    result = (double)numerator / denominator;
    return true;
}

if (TryDivide(10, 3, out double quotient))
    Console.WriteLine(quotient);         // 3.333...

// Discard an out you don't care about
int.TryParse("abc", out _);
```
```csharp
// --- ref: read AND write the caller's variable ---
static void Swap(ref int a, ref int b)
{
    int temp = a;
    a = b;
    b = temp;
}

int x = 1, y = 2;
Swap(ref x, ref y);
Console.WriteLine($"{x} {y}");   // 2 1 — original variables changed
```
```csharp
// --- ref with structs: avoid copying a large struct ---
public struct Matrix4x4          // hypothetical 64-byte struct
{
    public float M11, M12, M13, M14;
    public float M21, M22, M23, M24;
    public float M31, M32, M33, M34;
    public float M41, M42, M43, M44;
}

// Without ref: copies 64 bytes on every call
static void ScaleWithoutRef(Matrix4x4 m, float factor) { /* m is a copy */ }

// With ref: passes an 8-byte pointer; mutation affects the caller's struct
static void Scale(ref Matrix4x4 m, float factor)
{
    m.M11 *= factor;
    m.M22 *= factor;
    m.M33 *= factor;
}
```
```csharp
// --- in: readonly ref — avoid the copy, prevent mutation ---
// Compiler error if you try to assign to an `in` parameter inside the method.
static float Trace(in Matrix4x4 m)
{
    return m.M11 + m.M22 + m.M33 + m.M44;   // read-only; no copy
    // m.M11 = 0; // compile error
}

var mat = new Matrix4x4 { M11 = 1, M22 = 2, M33 = 3, M44 = 4 };
Console.WriteLine(Trace(in mat));   // 10
```
```csharp
// --- ref returns and ref locals (advanced) ---
// Return a reference to an element inside an array — no copy
static ref int FindFirst(int[] arr, int target)
{
    for (int i = 0; i < arr.Length; i++)
        if (arr[i] == target)
            return ref arr[i];              // return the actual slot, not a copy
    throw new InvalidOperationException("Not found");
}

int[] data = { 10, 20, 30 };
ref int slot = ref FindFirst(data, 20);
slot = 99;                                 // modifies data[1] directly
Console.WriteLine(data[1]);               // 99
```

---

## Gotchas

- **`out` parameters must be assigned on every code path, but the compiler only checks assignments — not that the value is meaningful.** Assigning `result = default` on an error path satisfies the compiler but can produce confusing behaviour if the caller ignores the return value and uses the `out` variable anyway. Document what the `out` value means on failure, or use a nullable return type instead.
- **`in` doesn't guarantee a copy is never made.** If you call a method that takes `in T` and pass a variable that isn't already in a fixed location (e.g., a property that requires a getter call), the compiler silently materializes a temporary copy and passes a reference to that. You get the reference semantics with none of the savings. This is called a *defensive copy*. It shows up with interface calls on `in` struct parameters — the JIT can't be sure the method won't mutate the struct through the interface, so it copies.
- **`ref` on a reference type passes a reference to the reference.** `ref string s` lets the method replace the caller's `string` variable with a different string entirely. This is almost never what you want and confuses readers. If you just want to mutate the object's contents, pass it normally — reference types are already passed by reference in the sense that both caller and callee share the same object.
- **You can't use `ref` / `out` / `in` with async methods or iterators.** The parameters can't be captured in a state machine. If you need to return multiple values from an async method, return a tuple or a record. This is a compile error, not a runtime one, but it catches people who try to port synchronous `TryGet` patterns to async.
- **`ref` locals and `ref` returns can dangle.** A `ref` to a local variable inside a method is invalid once the method returns — the stack frame is gone. The compiler catches obvious cases, but with `ref` returns from methods that return stack-allocated memory (e.g., `stackalloc`), you can produce a genuinely dangerous dangling reference in unsafe contexts.

---

## Interview Angle

**What they're really testing:** Whether you understand value semantics vs. reference semantics at the call site, and whether you can reason about when copies happen.

**Common question form:** "What's the difference between `ref` and `out`?" or "When would you use `in` on a parameter?" or "Why does `TryParse` use `out` instead of just returning a nullable?"

**The depth signal:** A junior knows `out` means "the method sets it" and `ref` means "two-way." A senior explains the *defensive copy* problem with `in` and struct interfaces, knows that `ref` returns let you alias into collections without copying (and why Span-based APIs use this internally), and can articulate why `out` exists as a distinct keyword from `ref` — it allows the compiler to enforce definite assignment, which is what makes the `TryParse` pattern safe: the caller is guaranteed the variable is written before it's read, regardless of which branch the method took.

---

## Related Topics

- [[dotnet/value-types-vs-reference-types.md]] — the entire point of these keywords is controlling copy semantics for value types; they're meaningless without that foundation
- [[dotnet/memory-and-span.md]] — `Span<T>` and `ref struct` types rely heavily on ref semantics internally; understanding `ref` returns is prerequisite knowledge
- [[dotnet/csharp-boxing-unboxing.md]] — passing a value type as `object` boxes it; `in` / `ref` are how you pass large structs without boxing or copying
- [[dotnet/csharp-unsafe-code.md]] — `ref` locals and `ref` returns are the managed alternative to pointer arithmetic for in-place mutation; both solve the same performance problem from different directions

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/ref](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/ref)

---
*Last updated: 2026-03-24*