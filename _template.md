# [Topic Name]

> [One sentence. What is this thing, in plain language — the definition a senior dev would give.]

---

## Quick Reference

| | |
|---|---|
| **What it is** | [5-word answer] |
| **Use when** | [one phrase] |
| **Avoid when** | [one phrase] |
| **C# version** | [e.g. C# 2.0 / C# 7.2 / C# 8.0] |
| **Namespace** | [e.g. `System.Collections.Generic`] |
| **Key types** | [e.g. `List<T>`, `IEnumerable<T>`] |

---

## When To Use It

[2–4 sentences. The context — when does this concept matter?
When should you NOT use it? What problem does it solve?
Name the specific alternative if "don't use this" applies.]

---

## Core Concept

[Explain it in your own words. Not copied from docs.
Write it like you're explaining to yourself 6 months ago.
No more than 2 short paragraphs.
Include the *why* behind the design decision, not just *what* it does.]

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| [e.g. C# 2.0] | [e.g. .NET 2.0] | [e.g. Introduced generics] |
| [e.g. C# 7.2] | [e.g. .NET Core 2.0] | [e.g. Added `in` parameter modifier] |
| [e.g. C# 9.0] | [e.g. .NET 5] | [e.g. Added `init` accessor] |

*[Any noteworthy evolution notes — e.g. "Before C# 7, you had to use X instead."]*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| [e.g. Add] | O(1) amortized | [e.g. Occasional O(n) resize] |
| [e.g. Lookup by key] | O(1) average | [e.g. O(n) worst case on hash collision] |
| [e.g. Remove] | O(n) | [e.g. Must shift elements] |

**Allocation behaviour:** [Describe whether this allocates on heap, uses stack, causes boxing, etc.]

**Benchmark notes:** [When does this become measurably slow? What's the practical threshold?
e.g. "Under 1,000 elements, performance difference vs X is negligible."]

---

## The Code

**[Scenario 1 — most basic usage]**
```csharp
// Minimal working example.
// Comments only on non-obvious lines.
```

**[Scenario 2 — common real pattern]**
```csharp
// Second most common usage pattern.
// Cover a different use case than scenario 1.
```

**[Scenario 3 — edge case or advanced usage]**
```csharp
// Something that trips people up,
// or a pattern only seniors know.
```

**[Scenario 4 — what NOT to do, with the fix]**
```csharp
// BAD: explain why this is wrong
var bad = ...;

// GOOD: the correct approach
var good = ...;
```

---

## Real World Example

[One paragraph setting the production context — the system, the problem being solved, why this feature was the right tool.]

```csharp
// A complete, realistic code snippet from a production-style system.
// Should be 20–40 lines. Not a toy example.
// Use realistic names: OrderService, ProductRepository, CustomerDto, etc.
// Show the feature in context with other code around it.
// Include error handling or edge cases if they're part of the realistic story.
```

*[One sentence after the snippet explaining what the key insight is — what the snippet demonstrates that the earlier examples didn't.]*

---

## Common Misconceptions

**"[State the misconception as someone would actually say it]"**
[Correct it in 2–3 sentences. Be direct. Explain what actually happens.]

**"[Second misconception]"**
[Correction. If possible, show a short code snippet that proves the point.]

```csharp
// Short proof snippet if needed
```

**"[Third misconception]"**
[Correction.]

---

## Gotchas

- **[Trap name in bold].** [Explanation of what goes wrong, why it's subtle, and the fix. Aim for 2–3 sentences per bullet.]

- **[Second trap].** [Same format — name it, explain the failure mode, give the fix or the guard.]

- **[Third trap].** [...]

- **[Fourth trap].** [...]

- **[Fifth trap].** [...]

---

## Interview Angle

**What they're really testing:** [The underlying concept behind the question — what separates someone who memorised the answer from someone who understands it.]

**Common question forms:**
- "[Exact phrasing they use]"
- "[Alternative phrasing of same concept]"
- "[Follow-up question they ask after the first answer]"

**The depth signal:** A junior says "[typical shallow answer]." A senior says "[the nuanced answer that shows real understanding]" — specifically explaining [the one thing that proves depth on this topic].

**Follow-up questions to expect:**
- "[What they ask when your first answer is good]"
- "[The trap follow-up]"

---

## Related Topics

- [[folder/topic-name.md]] — [one line on why it's related and how the concepts connect]
- [[folder/topic-name.md]] — [one line]
- [[folder/topic-name.md]] — [one line]
- [[folder/topic-name.md]] — [one line]

---

## Source

[Official docs or single best resource — one link only]

---

*Last updated: YYYY-MM-DD*