# C# — ref, out, and in Parameters

> Three modifiers that change how arguments are passed to methods — all three pass a reference to the variable rather than a copy, but with different mutation and initialisation rules.

---

## Quick Reference

| Modifier | Caller pre-initialise? | Method can write? | Use for |
|---|---|---|---|
| `ref` | Required | Yes | Read + write same variable |
| `out` | Not required | Must before return | Return multiple values |
| `in` | Required | No | Read-only pass of large struct |

---

## Core Concept

By default, C# passes arguments by value — the method gets a copy. For value types (structs) this means mutations inside the method don't affect the caller's variable. `ref`, `out`, and `in` all pass a reference to the caller's variable instead.

- **`ref`**: bidirectional — method reads and writes the caller's variable. Caller must initialise before passing.
- **`out`**: write-only from the caller's perspective — method must assign before returning. Caller doesn't need to initialise. The pattern for returning multiple values before tuples existed.
- **`in`**: read-only reference — passes large structs by reference to avoid copying, but prevents mutation. Without `readonly struct`, the compiler may make a defensive copy.

---

## The Code

**`ref` — bidirectional pass**
```csharp
void Double(ref int n) => n *= 2;

int x = 5;
Double(ref x);         // must use 'ref' at call site
Console.WriteLine(x);  // 10 — caller's variable modified
```

**`out` — return multiple values**
```csharp
bool TryDivide(int a, int b, out int result, out string error)
{
    if (b == 0) { result = 0; error = "Divide by zero"; return false; }
    result = a / b; error = ""; return true;
}

if (TryDivide(10, 2, out int r, out string err))
    Console.WriteLine($"Result: {r}");
```

**`in` — large struct without copy**
```csharp
static double Length(in Matrix4x4 m)
    => Math.Sqrt(m.M11 * m.M11 + m.M22 * m.M22 + m.M33 * m.M33 + m.M44 * m.M44);

var matrix = new Matrix4x4 { /* ... */ };
double len = Length(in matrix);  // passes reference — no 64-byte copy
// Length(matrix); // also works — 'in' is optional at call site
```

**`ref` struct members (C# 11+)**
```csharp
// ref fields in ref structs — allows Span<T>-like types
ref struct SpanWrapper<T>
{
    private ref T _ref;
    public SpanWrapper(ref T value) => _ref = ref value;
    public ref T Value => ref _ref;
}
```

---

## Gotchas

- **`out` variables declared inline are scoped to the `if` block and beyond (C# 7+).** `if (int.TryParse(s, out int n))` — `n` is accessible after the `if`.
- **`in` without `readonly struct` may produce defensive copies.** The compiler copies the struct before calling methods on it to ensure the method can't observe mutations. Use `readonly struct` to eliminate this.
- **`ref return` and `ref local` (C# 7) allow returning references.** Rare but powerful for direct array element manipulation.
- **Don't use `ref`/`out` as a substitute for a return type.** For most multiple-return scenarios, tuples or records are cleaner.

---

## Source

[Parameter modifiers — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/method-parameters)

---
*Last updated: 2026-04-06*