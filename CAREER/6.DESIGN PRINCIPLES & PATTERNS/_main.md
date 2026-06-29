# Domain 6 — Design Principles & Patterns

## Note Generation Prompt

**Purpose:** This file is the generation spec for all Domain 6 notes. When generating a note, read this file first, then produce the complete note in the exact structure below. No narration. No reasoning overhead. Output the file directly.

---

## Domain Identity

- **Domain Number:** 6
- **Domain Name:** Design Principles & Patterns
- **Scope:** SOLID principles, general design principles, clean code practices, GoF creational / structural / behavioral patterns, and refactoring techniques — all implemented in C# with .NET-idiomatic examples
- **Audience:** Senior-level interview preparation and production .NET engineering reference
- **Quality Bar:** Every note must be immediately usable without editing. Production-realistic examples only. No tutorial padding. No `foo` / `bar` / `baz`.

---

## File Naming Convention

```
6_XXX_Topic_Name_With_Underscores.md
```

Examples:

- `6_001_Single_Responsibility_Principle.md`
- `6_029_Strategy_Pattern.md`
- `6_038_Code_Smell_Catalog_Bloaters.md`

---

## YAML Frontmatter

```yaml
---
id: "6.XXX"
title: "Topic Name"
domain: "Design Principles & Patterns"
domain_id: 6
group: "Group Name"
tags: [design-principles, patterns, csharp, dotnet]
priority: X
prerequisites:
  - "[[6.XXX — Topic Name]]"
related:
  - "[[6.XXX — Topic Name]]"
  - "[[4.XXX — Topic Name]]"
created: YYYY-MM-DD
---
```

**Valid group values:** `SOLID Principles` | `General Principles` | `Clean Code` | `Creational Patterns` | `Structural Patterns` | `Behavioral Patterns` | `Refactoring`

**Priority values:** `1` = Critical | `2` = High | `3` = Medium | `4` = Reference

---

## Note Structure — 9 Mandatory Sections

Every note contains exactly these 9 sections in this order. No omissions. No reordering. No placeholder text left in the output.

---

### Section 1 — Navigation & Context

```markdown
## Navigation

**Domain:** [[6 — Design Principles & Patterns]] > **Group:** [Group Name]
**Previous:** [[6.XXX — Previous Topic]] | **Next:** [[6.XXX — Next Topic]]

### Prerequisites
- [[6.XXX — Topic]] — one sentence on why it is required
- [[2.XXX — C# Topic]] — if a C# language concept is a prerequisite

### Where This Fits
One paragraph (3–5 sentences) placing this topic in engineering context. Why does this
principle or pattern exist? What recurring problem does it solve? Where in a .NET
codebase will a senior engineer encounter it or be expected to apply it?
```

---

### Section 2 — Core Mental Model

````markdown
## Core Mental Model

One precise paragraph defining the principle or pattern. Not a textbook definition —
an engineer's working definition. What is the core idea in one sentence? What does it
prevent? What does it enable?

### Classification

**For principles:** show the principle family and its relationship to sibling principles.
**For patterns:** show the GoF classification (Creational / Structural / Behavioral),
intent, and participants.

[REQUIRED Mermaid diagram]

For **patterns**: class diagram showing all participants with their relationships
(interface hierarchy, composition arrows, dependency arrows).
For **principles**: side-by-side concept diagram showing the violation structure vs.
the correct structure.

```mermaid
classDiagram
    class [Participant] {
        +Method()
    }
    [Participant] <|-- [ConcreteParticipant]
````

### Participants (patterns) / Dimensions (principles)

- **Name** — precise single-sentence role description
- (all participants / dimensions listed)

````

---

### Section 3 — Deep Mechanics

```markdown
## Deep Mechanics

### How It Works

Step-by-step walkthrough of the mechanism.

For **patterns**: trace the full call sequence from client → context → abstraction →
concrete implementation → return path. Name each step.
For **principles**: show the before-state (violation) structurally, then the after-state
(correct), and explain what changed at the class or module boundary level — not just
what the code looks like.

### .NET Runtime Behavior

Where the CLR, JIT, or .NET type system interacts with this pattern or principle,
explain it here. Examples:

- **Singleton**: JIT and double-checked locking; why `Lazy<T>` is preferred
- **Observer**: `IObservable<T>` / `IObserver<T>` vs. C# `event` — what the runtime
  provides vs. what you add
- **Iterator**: how `IEnumerable<T>` + `yield return` compiles to a state machine
- **Decorator**: interface dispatch cost vs. inheritance; how the JIT devirtualizes
- **Strategy**: how the JIT handles virtual dispatch on hot paths

If no meaningful runtime behavior applies, replace with:

### Why It Matters at Scale
Explain the engineering consequence of ignoring this principle or pattern across a
codebase of 100k+ lines or a team of 10+ engineers.
````

---

### Section 4 — Production Code Patterns

````markdown
## Production Code Patterns

### Implementation in C#

Complete, idiomatic C# implementation. Requirements:

- **Realistic domain names** — OrderProcessor, PaymentGateway, NotificationService,
  ReportBuilder, InventoryManager, ShippingCalculator, AuditLogger. Never Foo/Bar as
  domain examples. Animal/Dog/Cat is acceptable only when demonstrating LSP directly.
- Show the **full structure**: interfaces or abstract classes, at least two concrete
  implementations, and the client call site
- Use **modern C# features** where appropriate: records, pattern matching, primary
  constructors, file-scoped namespaces, `required` members
- Add **XML doc comments** on public members
- For **principles**: show the VIOLATION labeled `// ❌ Violation` and the CORRECT
  version labeled `// ✅ Correct`, with a structural comment explaining the difference
- For **patterns**: show all named participants clearly with a comment labeling each
  role (// Context, // Strategy, // ConcreteStrategy, etc.)

### ASP.NET Core / .NET Ecosystem Integration

Show where this principle or pattern appears in the .NET ecosystem itself. Every note
must have at least one real-world ecosystem example from:

- ASP.NET Core internals (middleware pipeline, filter pipeline, DI container)
- EF Core (interceptors, query filters, owned entities)
- MediatR (pipeline behaviors, notifications — for Mediator, Command, Observer)
- Polly (retry, circuit breaker — for Strategy, Chain of Responsibility)
- FluentValidation, AutoMapper, Scrutor, or other widely-used .NET libraries

```csharp
// Show how to wire this pattern into IServiceCollection registration
services.AddXxx<Implementation>();
````

````

---

### Section 5 — Gotchas & Anti-Patterns

```markdown
## Gotchas & Anti-Patterns

Format for every entry: **Wrong** → **Right** → **Consequence**

Minimum 4 entries. Maximum 7. Focus on:
1. The most common misapplication in production .NET code
2. The "clever" usage that defeats the pattern's purpose
3. The .NET-specific trap (e.g., DI container misuse, async pitfall, EF Core context)
4. The interview trap — the answer that sounds right but reveals shallow understanding

### [Anti-Pattern Name]

**Wrong:** One sentence describing the incorrect approach. Include a 3–5 line code
snippet if the mistake is in the code itself.

```csharp
// ❌ Wrong
````

**Right:** The correct approach with the fix shown.

```csharp
// ✅ Right
```

**Consequence:** What breaks — at runtime, in maintenance, in a team context, or in a production incident — if this is not corrected.

````

---

### Section 6 — Performance Implications

```markdown
## Performance Implications

### Dispatch and Allocation Cost

Quantify or qualify the performance characteristics honestly:

- For patterns with **virtual dispatch** (Strategy, Observer, Decorator, Proxy): explain
  the cost of interface dispatch vs. direct calls; when the JIT devirtualizes; at what
  call frequency the difference is measurable
- For patterns with **object creation** (Factory, Builder, Prototype): explain allocation
  implications; when pooling or caching the created objects matters
- For **principles**: explain what following the principle costs (abstraction overhead,
  extra allocations) vs. what violating it costs in long-term maintenance and defect rate

### BenchmarkDotNet

```csharp
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net90)]
public class [TopicName]Benchmark
{
    // [Setup] fields here

    [GlobalSetup]
    public void Setup()
    {
        // initialize
    }

    [Benchmark(Baseline = true)]
    public [ReturnType] Direct_[Operation]()
    {
        // Implementation without the pattern (baseline)
    }

    [Benchmark]
    public [ReturnType] Via_[PatternName]()
    {
        // Implementation through the pattern abstraction
    }
}
````

**Expected results (approximate on .NET 9, x64):**

|Method|Mean|Gen0|Allocated|
|---|---|---|---|
|Direct_[Operation]|~X ns|-|0 B|
|Via_[PatternName]|~X ns|0.XXXX|Y B|

**Interpretation:** [One sentence on what the numbers mean and when the overhead matters vs. when it is irrelevant.]

If no meaningful performance difference exists (pure design principles, structural refactoring), omit the benchmark and replace with:

### Maintenance Cost Model

A table showing defect probability, change impact, and onboarding cost at small-team vs. large-team scale when the principle is followed vs. violated.

````

---

### Section 7 — Interview Arsenal

```markdown
## Interview Arsenal

### Question Bank

6–8 questions ordered foundational → advanced:

1. [Definition/recognition — "What is X?"]
2. [Application — "When would you use X?"]
3. [Comparison — "What is the difference between X and Y?"]
4. [Tradeoff — "What do you give up by applying X?"]
5. [Anti-pattern identification — "What is wrong with this code?"]
6. [System design integration — "How does X appear in a production ASP.NET Core system?"]
7. [Trick — tests understanding of the limits or edge cases of X]
8. [Advanced — tests internals, .NET runtime behavior, or pattern combination]

### Spoken Answers

Provide full spoken-narrative answers for questions 1, 3, and the trick question.
Two tiers each:

**Q: [Question]**

> **Average answer:** What most candidates say. Technically correct but shallow — misses
> the tradeoff, the production implication, or the .NET-specific context.

> **Great answer:** What a senior engineer says. Names the tradeoff explicitly. Cites a
> concrete .NET ecosystem example (ASP.NET Core middleware, MediatR, Polly, EF Core).
> Addresses the edge case or the failure mode. Uses precise vocabulary.

### Trick Question

**"[The trap question for this topic]"**

Why it is a trap: [one sentence].
Correct answer: [the nuanced response that demonstrates real understanding].

### Comparison Table

| Aspect | [This] | [Most Confused With] |
|---|---|---|
| Intent | | |
| Participants | | |
| When to use | | |
| .NET example | | |
| Key difference | | |
````

---

### Section 8 — Decision Framework

````markdown
## Decision Framework

### When to Apply [Name]

```mermaid
flowchart TD
    A[Problem or trigger condition] --> B{First decision}
    B -->|condition A| C[Apply this pattern/principle]
    B -->|condition B| D{Secondary decision}
    D -->|condition C| E[Alternative approach]
    D -->|condition D| F[Third alternative]
    C --> G[Expected structural outcome]
    E --> H[Expected structural outcome]
````

### Application Checklist

- [ ] The problem this solves is present in my code
- [ ] At least two participants / implementations exist or are anticipated
- [ ] The abstraction cost is justified by the variation it encapsulates
- [ ] Team members will recognize the pattern without a comment explaining it
- [ ] I am not applying this speculatively (YAGNI check)

### Tradeoff Summary

|What You Gain|What You Give Up|
|---|---|
|[Gain 1]|[Cost 1]|
|[Gain 2]|[Cost 2]|
|[Gain 3]|[Cost 3]|

````

---

### Section 9 — Self-Check

```markdown
## Self-Check

### Conceptual Questions

1. [Tests fundamental understanding — what, not how]
2. [Tests the why — what problem does this solve?]
3. [Tests violation identification — can you spot it?]
4. [Tests relationship to a sibling principle or pattern]
5. [Tests .NET-specific application]
6. [Tests when NOT to apply]
7. [Tests performance or maintenance consequence]
8. [Tests comparison with the most commonly confused alternative]
9. [Tests anti-pattern recognition in a code snippet]
10. [Tests integration in a real system design]

<details>
<summary>Answers</summary>

1. [Answer]
2. [Answer]
3. [Answer]
4. [Answer]
5. [Answer]
6. [Answer]
7. [Answer]
8. [Answer]
9. [Answer]
10. [Answer]

</details>

---

### Code Puzzles

**Puzzle 1 — Identify the violation**

```csharp
// [Code with a design principle violation — realistic domain, not contrived]
````

<details> <summary>Answer</summary>

**Violation:** [Which principle or pattern rule is broken] **Why:** [Structural explanation] **Fix:** [Corrected code or structural change]

</details>

---

**Puzzle 2 — Complete the pattern**

```csharp
// [Incomplete pattern implementation — one participant or wiring step is missing]
// TODO: complete [missing piece]
```

<details> <summary>Answer</summary>

```csharp
// [Complete implementation]
```

**Explanation:** [Why this completes the pattern correctly]

</details>

---

**Puzzle 3 — Choose the right pattern**

**Scenario:** [A real-world situation — 2–3 sentences describing the requirement]. Which pattern applies, and why? What would the wrong choice be?

<details> <summary>Answer</summary>

**Correct pattern:** [Name] — [one sentence justification referencing the scenario] **Wrong choice:** [Name] — [why it does not fit] **Implementation sketch:** [3–5 lines of C# showing the key structural decision]

</details>

---

**Puzzle 4 — Spot the anti-pattern**

```csharp
// [Code that uses the pattern but incorrectly — classic misapplication]
```

<details> <summary>Answer</summary>

**Anti-pattern:** [Name of the misapplication] **Consequence:** [What breaks] **Corrected version:**

```csharp
// [Fixed code]
```

</details>

---

**Puzzle 5 — Refactor to apply**

```csharp
// [Production-realistic code that would benefit from this principle or pattern
//  but does not yet use it]
```

<details> <summary>Answer</summary>

```csharp
// [Refactored version applying the principle or pattern]
```

**What changed:** [Structural explanation — not style commentary] **Why it is better:** [Engineering consequence — testability, extensibility, clarity]

</details> ```

---

## Domain-Specific Generation Rules

### Rule 1 — No Isolated Academic Examples

Every code example must have a plausible production context. Use names from this approved set or invent equivalents: `OrderProcessor`, `PaymentGateway`, `NotificationService`, `ReportBuilder`, `InventoryManager`, `ShippingCalculator`, `AuditLogger`, `UserRepository`, `DocumentConverter`, `PricingEngine`, `EmailDispatcher`, `InvoiceGenerator`. The code should read like it belongs in a real .NET backend codebase.

### Rule 2 — Always Show .NET Ecosystem Integration

Every note must include at least one concrete example of how this pattern appears in ASP.NET Core, EF Core, MediatR, Polly, FluentValidation, AutoMapper, or another major .NET library. If the pattern is structurally present in the framework itself (e.g., middleware = Chain of Responsibility + Decorator, `IEnumerable<T>` = Iterator, DI container = Factory), name it explicitly.

### Rule 3 — Violations Must Be Vivid

The anti-pattern code in Section 5 and the violation in Section 4 must show a recognizable mistake — not a contrived strawman. The standard: if a senior engineer reads the violation code and thinks "I've seen this in production," the note is doing its job.

### Rule 4 — Principles Get Double-Sided Treatment

For every SOLID and General Principle note, Section 4 must show both the violation and the corrected version side by side. The structural transformation between them is the core teaching, not the definition.

### Rule 5 — Patterns Show All Participants

For every GoF pattern note, every named participant in the pattern must appear in the code with a `// Role: [Name]` comment. Do not hand-wave participant interactions. Show the actual call sequence.

### Rule 6 — Refactoring Notes Are Before and After

Every refactoring technique note must contain a realistic "before" block (with the smell labeled and its category noted) and a complete "after" block (with the structural change explained — not just "cleaner code").

### Rule 7 — Cross-References Are Mandatory

Every note must link to at least 3 other notes via wiki-link. Required cross-references:

- At least 1 link within Domain 6 (sibling principle or related pattern)
- At least 1 link to Domain 2 (C# language feature that underpins the pattern)
- At least 1 link to Domain 4 (ASP.NET Core) or Domain 7 (System Design) where the pattern appears at the architecture level

### Rule 8 — Comparison Is Always Present

Every pattern note must address its single "most confused with" counterpart in Section 7. Every principle note must explain how it relates to its nearest sibling: SRP ↔ ISP, OCP ↔ DIP, DRY ↔ YAGNI, Composition ↔ Inheritance.

### Rule 9 — Benchmark or Maintenance Cost — No Empty Section 6

If a benchmark is not meaningful (pure structural principle), Section 6 must still be populated — replace with a maintenance cost model, a defect rate analysis, or a concrete measurement from a production codebase (cite with realistic numbers).

---

## Priority Tier Reference

|Tier|Label|Interview frequency|Generation order|
|---|---|---|---|
|1|Critical|Near-certain to appear|Generate first|
|2|High|Likely in senior interviews|Generate second|
|3|Medium|Appears in deep-dive or specialized rounds|Generate third|
|4|Reference|Rarely tested directly; completeness only|Generate last|

---

## Pre-Save Checklist

- [ ] YAML frontmatter complete — id, title, domain_id, group, priority, prerequisites, related
- [ ] All 9 sections present, fully populated, no placeholder text remaining
- [ ] Mermaid diagram in Section 2 (class diagram or concept diagram — valid syntax)
- [ ] Mermaid flowchart in Section 8 (decision tree — valid syntax)
- [ ] Section 4 shows violation + correct (principles) OR all named participants (patterns)
- [ ] Section 5 has minimum 4 anti-patterns in Wrong → Right → Consequence format
- [ ] Section 6 has BenchmarkDotNet code OR maintenance cost model — not empty
- [ ] Section 7 has spoken answers at two tiers for at least 3 questions
- [ ] Section 7 has a comparison table against the most-confused-with concept
- [ ] Section 9 has exactly 10 conceptual questions + 5 code puzzles with collapsed answers
- [ ] Minimum 3 wiki-links present (at least 1 cross-domain)
- [ ] No `foo`, `bar`, `baz` used as domain names
- [ ] File saved as `6_XXX_Topic_Name_With_Underscores.md`