# Domain 5 — Data Structures & Algorithms

## Note Generation Prompt

**Purpose:** This file is the generation spec for all Domain 5 notes. When generating a note, read this file first, then produce the complete note in the exact structure below. No narration. No reasoning overhead. Output the file directly.

---

## Domain Identity

- **Domain Number:** 5
- **Domain Name:** Data Structures & Algorithms
- **Scope:** Every data structure and algorithm pattern required for senior-level technical interviews at large companies — implemented in C# with idiomatic .NET collections, with full complexity analysis and pattern recognition training
- **Audience:** Interview preparation (primary) and production engineering reference (secondary)
- **Quality Bar:** Every note must be immediately usable in an interview setting. Complexity analysis must be derived, not stated. Implementations must be bug-free on the first read. Problem patterns must be recognizable from the description alone.

---

## File Naming Convention

```
5_XXX_Topic_Name_With_Underscores.md
```

Examples:

- `5_001_Big_O_Notation_and_Complexity_Analysis.md`
- `5_037_BFS_Shortest_Path_and_Level_Order.md`
- `5_060_1D_Dynamic_Programming.md`

---

## YAML Frontmatter

```yaml
---
id: "5.XXX"
title: "Topic Name"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Group Name"
tags: [dsa, algorithms, data-structures, csharp, interviews]
priority: X
prerequisites:
  - "[[5.XXX — Topic Name]]"
related:
  - "[[5.XXX — Topic Name]]"
  - "[[2.XXX — Topic Name]]"
created: YYYY-MM-DD
---
```

**Valid group values:** `Foundations` | `Arrays and Strings` | `Linked Lists` | `Stacks and Queues` | `Hash Maps and Sets` | `Trees` | `Heaps and Priority Queues` | `Graphs` | `Binary Search` | `Sorting` | `Greedy Algorithms` | `Backtracking` | `Dynamic Programming`

**Priority values:** `1` = Critical | `2` = High | `3` = Medium | `4` = Reference

---

## Note Structure — 9 Mandatory Sections

Every note contains exactly these 9 sections in this order. No omissions. No reordering. No placeholder text left in the output.

---

### Section 1 — Navigation & Context

```markdown
## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** [Group Name]
**Previous:** [[5.XXX — Previous Topic]] | **Next:** [[5.XXX — Next Topic]]

### Prerequisites
- [[5.XXX — Topic]] — one sentence on why it is required
- [[2.XXX — C# Topic]] — if a language feature is a prerequisite

### Where This Fits
One paragraph (3–5 sentences). What problem class does this data structure or
algorithm solve? Where does it appear in the interview problem space — which LeetCode
categories, which system design contexts, which production scenarios? Why is mastering
it non-negotiable for a senior interview?
```

---

### Section 2 — Core Mental Model

````markdown
## Core Mental Model

One precise paragraph. Not a textbook definition — a pattern-recognition trigger.
What is the core idea that lets you recognize when this structure or algorithm applies?
What invariant does it maintain? What property does it exploit?

### Classification

**For data structures:** show the taxonomy — where it fits in the broader hierarchy of
structures, what contract it satisfies (`ICollection<T>`, `IEnumerable<T>`, etc.),
what distinguishes it from its nearest alternatives.
**For algorithms:** show the paradigm (Divide and Conquer, Greedy, Dynamic Programming,
Graph Traversal, etc.), what problem property it exploits, and which family of problems
it solves.

[REQUIRED Mermaid diagram]

For **data structures**: draw the structure itself — nodes, pointers, levels, layers.
For **algorithms**: draw the execution pattern — recursion tree, state space, graph
traversal order, DP table filling direction.
For **patterns** (Two Pointers, Sliding Window, etc.): draw the pointer/window movement
over an example array or string.

```mermaid
[diagram here]
````

### Key Properties

|Property|Value|Derivation|
|---|---|---|
|[Operation]|O(?)|[one-sentence derivation]|
|[Operation]|O(?)|[one-sentence derivation]|
|Space|O(?)|[one-sentence derivation]|

For data structures: list all primary operations (insert, delete, search, peek, etc.) For algorithms: list time complexity (best, average, worst) and space complexity

````

---

### Section 3 — Deep Mechanics

```markdown
## Deep Mechanics

### How It Works

Step-by-step explanation of the internal mechanism.

For **data structures**: explain each primary operation — what happens at the memory
level, what invariants are maintained, what the worst-case trigger is.
For **algorithms**: trace the execution on a small concrete example. Show every step.
Name what changes at each step. Derive the complexity from the trace, not from memory.
For **patterns**: explain the intuition — why the pattern works, what property of the
input it exploits, why a brute force does not exploit that property.

### Complexity Derivation

Do not state complexity — derive it.

**Time:** Walk through the execution and count operations. Show the recurrence relation
for recursive algorithms and solve it (Master Theorem where applicable). For iterative
algorithms, count loop iterations explicitly.

**Space:** Account for every allocation — the input, the auxiliary data structure, the
call stack for recursive solutions.

### .NET Runtime Notes

How does the .NET runtime or standard library interact with this structure or algorithm?

- **Collections:** Does `List<T>`, `Dictionary<TKey,TValue>`, `SortedSet<T>`,
  `PriorityQueue<TElement,TPriority>`, `Stack<T>`, `Queue<T>` implement this? What
  does the .NET implementation hide or expose? What is its internal backing structure?
- **Sorting:** Does `Array.Sort` use this algorithm? When? What is the .NET sort
  algorithm (introsort = quicksort + heapsort + insertion sort)?
- **LINQ:** Does any LINQ operator use this pattern under the hood?
- **Memory:** Does this structure trigger LOH allocations? Does it cause GC pressure
  in hot loops?

If no meaningful .NET runtime behavior applies, replace with:

### Why This Pattern Exists
Explain the problem that motivated this structure or algorithm — the brute force
approach, why it is inadequate, and what insight the structure or algorithm exploits
to improve it.
````

---

### Section 4 — Implementation and Problem Patterns

````markdown
## Implementation and Problem Patterns

### C# Implementation

**For data structures:** Implement the structure from scratch in C# — not just using
the built-in collection, but building the underlying mechanism. Then show the idiomatic
.NET equivalent. Requirements:
- Full implementation with all primary operations
- XML doc comments on public members
- Realistic type parameters and naming (`T`, `TKey`, `TValue` — not `Foo`)
- Edge case handling (empty structure, single element, duplicate keys)

**For algorithms:** Implement the algorithm cleanly in C# — both recursive and
iterative versions where both are meaningful. Requirements:
- Method signature with clear parameter names and return type
- Inline comments explaining non-obvious steps (not obvious ones)
- Show both the clean implementation and any optimization (memo table, early exit)

```csharp
// Implementation here
````

### The .NET Idiomatic Version

Show how to accomplish the same goal using .NET's built-in collections:

```csharp
// .NET built-in equivalent — when to use this vs. the scratch implementation
```

### Classic Problem Patterns

List the canonical problem types this structure or algorithm solves. For each pattern:

- **Pattern name** — one sentence describing what triggers it
- Representative LeetCode problem title (no solution, just recognition)
- The key insight that connects the problem to this structure/algorithm

Minimum 3 patterns. Maximum 6.

### Template / Skeleton

For patterns (Two Pointers, Sliding Window, BFS, DFS, Backtracking, DP, Binary Search): provide the reusable code skeleton that applies to any problem of this type:

```csharp
// [Pattern Name] Template
// When to use: [trigger condition in one sentence]
// Time: O(??) | Space: O(??)

[skeleton code with TODO comments marking the problem-specific parts]
```

````

---

### Section 5 — Gotchas and Edge Cases

```markdown
## Gotchas and Edge Cases

Format for every entry: **Mistake** → **Fix** → **Consequence**

Minimum 4 entries. Maximum 7. Focus on:
1. The off-by-one error specific to this structure or algorithm
2. The empty input / single-element case that breaks naive implementations
3. The integer overflow trap (indices, sums, counts)
4. The C#-specific pitfall (.NET collection behavior, LINQ deferred execution, etc.)
5. The interview-specific mistake (the answer that looks right but fails a test case)

### [Mistake Name]

**Mistake:** One sentence describing the incorrect approach or assumption.

```csharp
// ❌ Wrong
````

**Fix:** The correct approach.

```csharp
// ✅ Correct
```

**Consequence:** What fails — wrong answer, infinite loop, index out of range, TLE (Time Limit Exceeded), stack overflow, or silent data corruption.

````

---

### Section 6 — Complexity Analysis and Benchmarks

```markdown
## Complexity Analysis and Benchmarks

### Operation Complexity Table

| Operation | Time (Best) | Time (Average) | Time (Worst) | Space | Notes |
|---|---|---|---|---|---|
| [Operation 1] | O(?) | O(?) | O(?) | O(?) | [when worst case triggers] |
| [Operation 2] | O(?) | O(?) | O(?) | O(?) | [when worst case triggers] |

**Derivation for the non-obvious entries:** [Explain any complexity that is not
immediately obvious from the operation name. Show the mathematical reasoning.]

### Comparison with Alternatives

| Structure / Algorithm | Time | Space | Best When |
|---|---|---|---|
| [This] | O(?) | O(?) | [scenario] |
| [Alternative 1] | O(?) | O(?) | [scenario] |
| [Alternative 2] | O(?) | O(?) | [scenario] |

### BenchmarkDotNet

```csharp
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net90)]
public class [TopicName]Benchmark
{
    private [InputType] _input = default!;

    [Params(100, 1_000, 10_000)]
    public int N { get; set; }

    [GlobalSetup]
    public void Setup()
    {
        // initialize _input with N elements
    }

    [Benchmark(Baseline = true)]
    public [ReturnType] BruteForce()
    {
        // O(n²) or naive approach
    }

    [Benchmark]
    public [ReturnType] Optimized()
    {
        // This structure/algorithm's approach
    }
}
````

**Expected results (approximate, .NET 9, x64):**

|Method|N|Mean|Allocated|
|---|---|---|---|
|BruteForce|100|~X μs|Y KB|
|Optimized|100|~X ns|Z B|
|BruteForce|10_000|~X ms|Y MB|
|Optimized|10_000|~X μs|Z KB|

**Interpretation:** [One sentence on what the scaling behavior demonstrates and at what input size the algorithm choice starts to matter in production.]

````

---

### Section 7 — Interview Arsenal

```markdown
## Interview Arsenal

### Question Bank

6–8 questions ordered foundational → advanced:

1. [Definition — "What is X and what problem does it solve?"]
2. [Complexity — "What is the time complexity of [operation] and why?"]
3. [Implementation — "Implement [operation] from scratch"]
4. [Recognition — "Which data structure would you use for [problem]?"]
5. [Comparison — "When would you choose X over Y?"]
6. [Trick — tests a non-obvious property or edge case]
7. [System design integration — "How would you use X in a production system?"]
8. [Optimization — "How would you improve X for [constraint]?"]

### Spoken Answers

Full spoken-narrative answers for questions 1, 3 (approach narration), and the trick
question. Two tiers each:

**Q: [Question]**

> **Average answer:** What most candidates say — correct but surface-level. Missing the
> complexity derivation, the edge case awareness, or the .NET context.

> **Great answer:** What a senior candidate says — derives complexity from first
> principles, names the specific edge cases, mentions the .NET standard library
> equivalent and when to use it vs. a scratch implementation, connects to a real
> system design scenario.

### Trick Question

**"[The trap for this topic]"**

Why it is a trap: [one sentence — what the wrong intuition says].
Correct answer: [the precise, complete response].

### Pattern Recognition Table

| If the problem has... | Then consider... | Because... |
|---|---|---|
| [Input characteristic] | [This structure/algorithm] | [Matching property] |
| [Input characteristic] | [This structure/algorithm] | [Matching property] |
| [Input characteristic] | [This structure/algorithm] | [Matching property] |
````

---

### Section 8 — Decision Framework

````markdown
## Decision Framework

### When to Apply

```mermaid
flowchart TD
    A[Problem input or constraint] --> B{Key decision}
    B -->|condition A| C[Use this structure/algorithm]
    B -->|condition B| D{Secondary decision}
    D -->|condition C| E[Alternative approach]
    D -->|condition D| F[Third option]
    C --> G[Expected time/space outcome]
````

### Recognition Checklist

Indicators that this structure or algorithm is the right choice:

- [ ] [Signal 1 in the problem statement]
- [ ] [Signal 2 in the constraints]
- [ ] [Signal 3 in the expected output]
- [ ] Brute force is O(n²) or worse and the input size suggests it will TLE

Counter-indicators — do NOT apply here:

- [ ] [Condition that rules it out]
- [ ] [Condition that favors an alternative]

### Tradeoff Summary

|What You Gain|What You Give Up|
|---|---|
|[Time improvement]|[Space cost]|
|[Simplicity in one dimension]|[Complexity in another]|
|[What the structure guarantees]|[What it cannot do]|

````

---

### Section 9 — Self-Check

```markdown
## Self-Check

### Conceptual Questions

1. [Tests: definition and purpose]
2. [Tests: complexity derivation from first principles]
3. [Tests: recognizing the pattern in a problem description]
4. [Tests: choosing between this and its nearest alternative]
5. [Tests: the specific edge case that breaks naive implementations]
6. [Tests: .NET standard library knowledge — which built-in uses this]
7. [Tests: the invariant that must be maintained during operations]
8. [Tests: what changes if a constraint is modified — sorted vs. unsorted, bounded vs. unbounded]
9. [Tests: connecting this to a system design or production scenario]
10. [Tests: the trick — a non-obvious property or counter-intuitive result]

<details>
<summary>Answers</summary>

1. [Answer]
2. [Answer with derivation, not just the answer]
3. [Answer]
4. [Answer with comparison]
5. [Answer with the fix]
6. [Answer naming the specific .NET type]
7. [Answer]
8. [Answer]
9. [Answer]
10. [Answer explaining why the intuition is wrong]

</details>

---

### Coding Challenges

**Challenge 1 — Implement from scratch**

Implement [specific operation or variant] without using any built-in collection for
the core mechanism.

```csharp
public [ReturnType] [MethodName]([Parameters])
{
    // Your implementation here
}
````

<details> <summary>Solution</summary>

```csharp
public [ReturnType] [MethodName]([Parameters])
{
    // Complete solution
}
```

**Complexity:** Time O(??) | Space O(??) **Key insight:** [One sentence on the non-obvious part]

</details>

---

**Challenge 2 — Trace the execution**

Given this input: `[specific input]` Trace [this algorithm/structure operation] step by step. What is the state after each step? What is the final output?

<details> <summary>Solution</summary>

Step 1: [state] Step 2: [state] ... Final: [output]

**Why:** [Explanation connecting the trace to the algorithm's invariant]

</details>

---

**Challenge 3 — Fix the bug**

```csharp
// This implementation has a bug that fails on [specific input type]
[buggy code — realistic off-by-one or logic error]
```

<details> <summary>Solution</summary>

**Bug:** [Precise description of what is wrong] **Fix:**

```csharp
[corrected code with the fix highlighted via comment]
```

**Test case that exposes it:** `[input]` → expected `[output]`, actual `[wrong output]`

</details>

---

**Challenge 4 — Recognize and apply**

**Problem:** [2–3 sentence description of a LeetCode-style problem without naming it]. Which pattern applies? Write the solution.

<details> <summary>Solution</summary>

**Pattern:** [Name] — [one sentence on why this pattern applies]

```csharp
// Solution
```

**Complexity:** Time O(??) | Space O(??)

</details>

---

**Challenge 5 — Optimize**

```csharp
// This solution is correct but O(n²) time / O(n) space
// Optimize it to O(n) time / O(1) space [or whatever the target is]
[working but suboptimal solution]
```

<details> <summary>Solution</summary>

**Insight:** [What property allows the optimization]

```csharp
// Optimized solution
```

**Complexity:** Time O(??) | Space O(??)

</details> ```

---

## Domain-Specific Generation Rules

### Rule 1 — Complexity Must Be Derived, Not Stated

Never write "Time complexity is O(n log n)." Always write: "Each element is processed once — O(n). The heap maintains the invariant in O(log k) per insertion — giving O(n log k) total." If the derivation cannot be shown in two sentences, use a bullet list.

### Rule 2 — Implementations Must Be Bug-Free and Complete

Every code block must be correct on the first read. Test it mentally against: empty input, single element, all-same elements, maximum size, negative numbers (where applicable), and the specific edge case mentioned in Section 5. Do not leave TODO comments in the implementation — only in the template skeleton.

### Rule 3 — Use Idiomatic C# and .NET Collections

Use .NET's built-in types naturally: `Dictionary<TKey,TValue>` for hash maps, `PriorityQueue<TElement,TPriority>` for heaps, `Stack<T>` and `Queue<T>` for the respective structures, `SortedSet<T>` and `SortedDictionary<TKey,TValue>` where ordered access matters. Always note when the built-in type is preferred over a scratch implementation in production.

### Rule 4 — Pattern Templates Are Non-Negotiable

For every pattern-based topic (Sliding Window, Two Pointers, BFS, DFS, Backtracking, Binary Search on Answer, DP), Section 4 must include a reusable skeleton with TODO markers for the problem-specific parts. This skeleton should be memorizable and applicable verbatim to new problems of the same type.

### Rule 5 — Interview Communication Is Modeled

Section 7's spoken answers must model exactly how a senior candidate would talk through a problem out loud — stating the approach before writing code, narrating complexity derivation, naming edge cases before being asked. The "great answer" tier should sound like someone explaining it at a whiteboard.

### Rule 6 — Comparisons Are Concrete

Every comparison between alternatives (Section 6 comparison table, Section 8 tradeoff table) must include a concrete input scenario for each option. Not "use a heap when you need sorted order" but "use a heap when you need the k-th largest element and k << n — otherwise Array.Sort is simpler and has better cache locality for small n."

### Rule 7 — Cross-References Connect Patterns to Problems

Every note must link to at least 3 other notes. Within-domain links should connect structural relationships: BFS links to Graph Representation, Monotonic Stack links to Sliding Window, DP links to Recursion. Cross-domain links: Graphs → System Design (Dijkstra → shortest path in routing), Trees → Domain 2 (IEnumerable<T> + yield return → Iterator), Heaps → Domain 4 (PriorityQueue in background job scheduling).

### Rule 8 — LeetCode Problems Are Named but Not Solved

Section 4's "Classic Problem Patterns" should name recognizable LeetCode problems to anchor the pattern (e.g., "Two Sum", "Sliding Window Maximum", "Course Schedule"). Do not provide solutions to those problems in the note — the note teaches the pattern; the practice solves the problems.

### Rule 9 — The Benchmark Must Show the Scaling Difference

Section 6's BenchmarkDotNet code must use `[Params(100, 1_000, 10_000)]` or similar so the output shows how the algorithms scale — not just a single data point. The table must show at least two N values so the O(n) vs O(n²) or O(n log n) difference is visible in the numbers.

---

## Priority Tier Reference

|Tier|Label|Interview frequency|Generation order|
|---|---|---|---|
|1|Critical|Appears in nearly every coding interview|Generate first|
|2|High|Appears in most senior-level coding rounds|Generate second|
|3|Medium|Appears in specialized or advanced rounds|Generate third|
|4|Reference|Rarely tested directly; completeness only|Generate last|

---

## Pre-Save Checklist

- [ ] YAML frontmatter complete — id, title, domain_id, group, priority, prerequisites, related
- [ ] All 9 sections present, fully populated, no placeholder text remaining
- [ ] Mermaid diagram in Section 2 — visualizes the structure or algorithm execution
- [ ] Mermaid flowchart in Section 8 — decision tree for when to apply
- [ ] Section 2 Key Properties table has all primary operations with derived complexity
- [ ] Section 3 complexity derivation is shown step by step, not stated
- [ ] Section 4 has scratch C# implementation AND .NET idiomatic equivalent
- [ ] Section 4 has minimum 3 classic problem patterns with recognition triggers
- [ ] Section 4 has a reusable template/skeleton (for pattern-based topics)
- [ ] Section 5 has minimum 4 gotchas in Mistake → Fix → Consequence format
- [ ] Section 6 has operation complexity table with best/average/worst
- [ ] Section 6 has BenchmarkDotNet code with Params and baseline
- [ ] Section 7 has spoken answers at two tiers for at least 3 questions
- [ ] Section 7 has a Pattern Recognition Table
- [ ] Section 9 has exactly 10 conceptual questions + 5 coding challenges with collapsed answers
- [ ] Minimum 3 wiki-links present (at least 1 cross-domain)
- [ ] All code blocks are correct — verified mentally against empty, single, and edge case inputs
- [ ] File saved as `5_XXX_Topic_Name_With_Underscores.md`