# C# — LINQ Ordering

> The `OrderBy`, `OrderByDescending`, `ThenBy`, and `ThenByDescending` operators that sort a sequence by one or more keys — and `Reverse` for flipping the current order.

---

## When To Use It

Use LINQ ordering when you need to sort an in-memory sequence before presenting, paginating, or processing it. It's the right tool for sorting collections of objects by one or more properties without writing comparison logic by hand. Don't chain multiple `OrderBy` calls to sort by multiple fields — each new `OrderBy` discards the previous sort entirely; use `ThenBy` for secondary keys. In EF Core, LINQ ordering translates to SQL `ORDER BY` and is required before any `Skip`/`Take` pagination — skipping without ordering produces non-deterministic results.

---

## Core Concept

`OrderBy` doesn't sort in place — it returns a new sequence that will be sorted when enumerated. Internally it performs a stable sort, meaning elements that compare as equal preserve their original relative order. The result of `OrderBy` isn't an `IEnumerable<T>` — it's an `IOrderedEnumerable<T>`, which is what allows you to chain `ThenBy` onto it. `ThenBy` only breaks ties left by the previous sort; it has no effect on elements the primary key already distinguished. Chaining a second `OrderBy` instead of `ThenBy` throws away all the work the first sort did and starts a completely fresh sort on the whole sequence — this is the most common ordering mistake in LINQ.

---

## The Code

### OrderBy and OrderByDescending — single key
```csharp
record Employee(string Name, string Department, int Salary, DateTime HireDate);

var employees = new List<Employee>
{
    new("Charlie", "Engineering", 95_000, new DateTime(2019, 3, 1)),
    new("Alice",   "Engineering", 95_000, new DateTime(2021, 6, 15)),
    new("Bob",     "Marketing",   72_000, new DateTime(2018, 1, 10)),
    new("Diana",   "Marketing",   88_000, new DateTime(2020, 9, 5)),
};

var byName = employees.OrderBy(e => e.Name);
// Alice, Bob, Charlie, Diana

var bySalaryDesc = employees.OrderByDescending(e => e.Salary);
// Charlie, Alice (tie at 95k — stable: Charlie first), Diana, Bob
```

### ThenBy — secondary sort key (not a second OrderBy)
```csharp
var sorted = employees
    .OrderBy(e => e.Department)          // primary: Department A→Z
    .ThenByDescending(e => e.Salary)     // secondary: Salary high→low within dept
    .ThenBy(e => e.Name);                // tertiary: Name A→Z to break salary ties

foreach (var e in sorted)
    Console.WriteLine($"{e.Department,-15} {e.Salary,8:N0}  {e.Name}");
// Engineering      95,000  Alice
// Engineering      95,000  Charlie
// Marketing        88,000  Diana
// Marketing        72,000  Bob
```

### The double-OrderBy bug — what NOT to do
```csharp
// WRONG — second OrderBy discards the first entirely
var wrong = employees
    .OrderBy(e => e.Department)
    .OrderBy(e => e.Salary);    // replaces dept sort — result is only by salary

// CORRECT
var correct = employees
    .OrderBy(e => e.Department)
    .ThenBy(e => e.Salary);
```

### Sorting strings with culture-aware comparison
```csharp
var names = new[] { "éclair", "apple", "Banana", "ångström" };

// Default OrderBy uses ordinal comparison — uppercase before lowercase,
// accented chars sorted by code point, not alphabetically
var ordinal = names.OrderBy(n => n);
// Banana, apple, éclair, ångström  ← probably not what you want

// Culture-aware sort using StringComparer
var cultural = names.OrderBy(n => n, StringComparer.CurrentCultureIgnoreCase);
// ångström, apple, Banana, éclair  ← locale-correct alphabetical order
```

### Sorting by computed or conditional key
```csharp
// Sort by absolute value — key selector can be any expression
var numbers = new[] { -5, 3, -1, 4, -2 };
var byAbsolute = numbers.OrderBy(n => Math.Abs(n));
// -1, -2, 3, 4, -5

// Conditional sort — nulls last
var withNulls = new[] { "banana", null, "apple", null, "cherry" };
var nullsLast = withNulls.OrderBy(s => s is null ? 1 : 0).ThenBy(s => s);
// apple, banana, cherry, null, null
```

### Pagination — OrderBy is required before Skip/Take
```csharp
int page     = 2;
int pageSize = 10;

// Always order before paginating — without OrderBy, Skip/Take results
// are non-deterministic (different rows may appear on different calls)
var page2 = employees
    .OrderBy(e => e.Name)
    .Skip((page - 1) * pageSize)
    .Take(pageSize);
```

### Reverse — flip current enumeration order
```csharp
var list = new List<int> { 1, 2, 3, 4, 5 };

// Reverse() is NOT the same as OrderByDescending —
// it just flips whatever order the sequence already has
var flipped = list.Reverse<int>(); // 5, 4, 3, 2, 1

// On List<T>, avoid list.Reverse() (no type arg) — that's the in-place
// List<T> method that mutates the original and returns void
```

---

## Gotchas

- **A second `OrderBy` replaces the first, not appends to it** — `sequence.OrderBy(x => x.A).OrderBy(x => x.B)` produces a result sorted only by `B`. The sort by `A` is completely discarded. Every multi-key sort must use `ThenBy`/`ThenByDescending` for every key after the first. This compiles silently and produces wrong results — there's no warning.
- **`List<T>.Reverse()` vs `Enumerable.Reverse<T>()`** — calling `.Reverse()` on a `List<T>` without a type argument calls the void in-place instance method, mutating the original list. Calling `.Reverse<T>()` with the type argument (or on a non-List sequence) calls the LINQ extension method, returning a new sequence. In a LINQ chain on a `List<T>`, write `.Reverse<Employee>()` explicitly to avoid the mutating overload.
- **`OrderBy` is deferred — the sort runs on every enumeration** — sorting a list of 100,000 elements and then iterating the sorted sequence three times sorts it three times. Materialize with `.ToList()` after `.OrderBy()` when the sorted result is used more than once.
- **Default string comparison is ordinal, not linguistic** — `OrderBy(x => x.Name)` uses `StringComparer.Ordinal` by default: uppercase before lowercase, accented characters sorted by Unicode code point. For user-facing sorts, always pass `StringComparer.CurrentCultureIgnoreCase` or `StringComparer.InvariantCultureIgnoreCase` explicitly.
- **Skip without OrderBy is non-deterministic in EF Core** — SQL has no guaranteed row order unless `ORDER BY` is specified. EF Core will warn about this in recent versions, but older versions silently paginate against an unordered result set, causing rows to appear on multiple pages or not at all depending on the query plan.

---

## Interview Angle

**What they're really testing:** Whether you understand stable sort semantics, the `IOrderedEnumerable<T>` contract that enables `ThenBy`, and the non-determinism risk in paginated queries without an explicit order.

**Common question form:** "Sort this list by department, then by salary descending," or "What's wrong with this paginated query?" (showing `Skip`/`Take` without `OrderBy`), or "Why does chaining two `OrderBy` calls give the wrong result?"

**The depth signal:** A junior chains two `OrderBy` calls and wonders why only the second key is respected. A senior explains that `OrderBy` returns `IOrderedEnumerable<T>` specifically so that `ThenBy` can access the existing sort keys and compose a multi-key comparer — a second `OrderBy` drops back to `IEnumerable<T>` and starts a fresh single-key sort, discarding all previous ordering. The senior also knows that LINQ's sort is guaranteed stable (since .NET 5 with `Array.Sort` using TimSort), that string sorts require an explicit `StringComparer` for locale-correct behavior, and that any paginated EF Core query without `OrderBy` is a latent data-consistency bug.

---

## Related Topics

- [[dotnet/csharp-linq-basics.md]] — Deferred execution applies to ordering; `OrderBy` is lazy and re-sorts on every enumeration unless materialized.
- [[dotnet/csharp-linq-grouping.md]] — Groups are often sorted after grouping; `OrderBy` and `ThenBy` are how you control group and within-group order.
- [[databases/ef-core-queries.md]] — EF Core translates `OrderBy`/`ThenBy` to SQL `ORDER BY`; required before `Skip`/`Take` for correct pagination behavior.
- [[algorithms/sorting.md]] — Understanding stable vs unstable sort, TimSort, and comparison-based sort complexity explains why LINQ's ordering behaves the way it does.

---

## Source

https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/sorting-data

---
*Last updated: 2026-03-23*