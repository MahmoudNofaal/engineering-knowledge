# C# — LINQ Ordering

> `OrderBy`, `OrderByDescending`, `ThenBy`, `ThenByDescending` — sort a sequence by one or more keys. `Reverse` flips the current order.

---

## Quick Reference

| Common mistake | Fix |
|---|---|
| Second `OrderBy` discards first | Use `ThenBy` for multi-key sort |
| String sort by code point (wrong language) | Pass `StringComparer.CurrentCultureIgnoreCase` |
| `Skip`/`Take` without `OrderBy` | Always sort before paginating |
| `list.Reverse()` mutates list | Use `.Reverse<T>()` or `Enumerable.Reverse` |

---

## Core Concept

`OrderBy` returns an `IOrderedEnumerable<T>` — a special interface that lets `ThenBy` access existing sort keys and compose a multi-key comparer. A second `OrderBy` drops back to `IEnumerable<T>` and starts a fresh single-key sort, **discarding all previous ordering**. Always use `ThenBy`/`ThenByDescending` for secondary and tertiary keys.

Sorting is deferred — `OrderBy` is lazy. It re-sorts on every enumeration unless materialised.

---

## The Code

**Multi-key sort — the right and wrong way**
```csharp
record Employee(string Name, string Department, int Salary);
var employees = new List<Employee> { /* ... */ };

// WRONG: second OrderBy discards the first entirely
var wrong = employees.OrderBy(e => e.Department).OrderBy(e => e.Salary);

// CORRECT: ThenBy for secondary keys
var sorted = employees
    .OrderBy(e => e.Department)
    .ThenByDescending(e => e.Salary)
    .ThenBy(e => e.Name);
```

**Culture-aware string sort**
```csharp
var names = new[] { "éclair", "apple", "Banana", "ångström" };

// Default: ordinal — uppercase before lowercase, accented by code point
var ordinal = names.OrderBy(n => n);

// Culture-aware: locale-correct alphabetical order
var cultural = names.OrderBy(n => n, StringComparer.CurrentCultureIgnoreCase);
```

**Nulls last**
```csharp
var withNulls = new[] { "banana", null, "apple", null, "cherry" };
var nullsLast = withNulls.OrderBy(s => s is null ? 1 : 0).ThenBy(s => s);
```

**Pagination — always sort before Skip/Take**
```csharp
// Without OrderBy: Skip/Take results are non-deterministic in EF Core
var page2 = employees.OrderBy(e => e.Name).Skip(10).Take(10);
```

---

## Gotchas

- **A second `OrderBy` replaces the first.** This is a silent correctness bug — no warning, wrong results.
- **`OrderBy` is deferred** — re-sorts on every enumeration. Materialise with `ToList()` for reuse.
- **Default string comparison is ordinal.** Pass `StringComparer` explicitly for user-facing sorts.
- **`Skip` without `OrderBy` is non-deterministic in EF Core.** Different rows may appear on different pages or not at all.
- **`List<T>.Reverse()` is in-place/mutating.** `Enumerable.Reverse<T>()` returns a new sequence.

---

## Source

[Sorting Data — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/sorting-data)

---
*Last updated: 2026-04-06*