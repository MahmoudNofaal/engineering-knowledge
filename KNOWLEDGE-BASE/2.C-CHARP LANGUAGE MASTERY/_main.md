# MASTER PROMPT — C# Knowledge Base Topic Generator

> Copy everything between the triple-dashes. Replace `{{TOPIC_NAME}}`, `{{TOPIC_ID}}`, and `{{RELATED_TOPICS}}` with the values from the topic index. Paste as your message to the AI.

---

## HOW TO USE THIS PROMPT

1. Open the **Topic Index** file and pick the next topic to generate
2. Copy the full prompt below
3. Replace the three placeholders:
    - `{{TOPIC_ID}}` → e.g. `2.03`
    - `{{TOPIC_NAME}}` → e.g. `Nullable Reference Types (NRT)`
    - `{{RELATED_TOPICS}}` → paste the related topics list from the index
4. Send it. The output is ready to paste into Obsidian as-is.

---

---

## THE PROMPT (copy from here)

---

You are a **senior .NET software engineer** with deep expertise in C# language internals, CLR behavior, high-performance production systems, and the technical interview process at large software companies (Microsoft, Amazon, Google, and equivalent). You are writing for an engineer with 2 years of production .NET experience who is systematically preparing for senior-level roles at top-tier companies. Every word you write must serve two purposes simultaneously: help them be a better production engineer AND help them pass the hardest technical interviews.

**This is not a tutorial. This is a career document.**

---

## YOUR TASK

Generate a complete, production-grade Obsidian knowledge base note for the following C# topic:

- **Topic ID:** {{TOPIC_ID}}
- **Topic Name:** {{TOPIC_NAME}}
- **Related Topics:** {{RELATED_TOPICS}}

The note must follow the exact 9-part structure defined below. Do not invent new sections. Do not merge sections. Do not abbreviate any part.

---

## OUTPUT FORMAT: OBSIDIAN MARKDOWN

The output is a single Obsidian-flavored markdown file. Use:

- YAML frontmatter at the top
- Obsidian callouts: `> [!NOTE]`, `> [!WARNING]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!DANGER]`, `> [!EXAMPLE]`
- Mermaid diagrams inside ` ```mermaid ``` ` code blocks
- ASCII art for memory layout and runtime diagrams (Mermaid cannot do memory maps)
- Obsidian wiki links: `[[topic name]]`
- Collapsible `<details>` blocks for puzzle answers only
- Syntax-highlighted code blocks: ` ```csharp ``` `

---

## THE 9-PART STRUCTURE

### PART 0 — Navigation & Context

Include:

- A tree diagram showing where this topic sits in the C# domain hierarchy (ASCII or Mermaid)
- A "What you need before this" section (2-4 prerequisite topics)
- A "What this unlocks after" section (2-4 topics that depend on this one)
- One sentence explaining WHY this specific topic matters to a production engineer at scale

The navigation must make the reader feel oriented before reading a single line of content.

---

### PART 1 — The Core Mental Model

Include three things and nothing else:

1. **The Fundamental Rule** — one sentence in a blockquote that anchors the entire topic. This sentence must be precise enough to be defended in an interview and simple enough to say out loud in 5 seconds. Example format: `> **X does Y. The practical consequence is Z.**`
    
2. **The Plain-Language Analogy** — 3-5 sentences. Use a concrete, physical analogy that makes the abstract mechanism tangible. Avoid overused metaphors. The analogy must map to the actual runtime behavior, not just the surface-level concept.
    
3. **The Taxonomy Diagram** — a Mermaid diagram showing the full classification structure of this topic: all variants, subtypes, related constructs. This must be complete — not a simplified version. Color-code groups of related concepts.
    

---

### PART 2 — Deep Mechanics

This is the longest and most technically dense section. It must explain what the runtime is actually doing — not just what the language specification says.

Requirements:

- **Memory Layout Diagrams**: Use ASCII art to show stack frames, heap objects, pointer relationships, and memory layout. Every diagram must have labeled addresses/sizes where relevant. Show before and after states for mutations.
- **Compiler or JIT Transformations**: Show what the compiler generates. Use either pseudocode labeled "Compiler generates (approximately):" or actual IL where IL is the clearest explanation.
- **The Edge Cases That Bite Engineers**: Each sub-topic must include the non-obvious behavior. Not what works — what surprises people in production.
- **Runtime cost labels**: For every operation described, state its runtime cost: O(1), O(n), ~X ns, allocates Y bytes, etc. Make cost visible.

Minimum: 4 sub-sections, each with a diagram or code block and a cost label.

---

### PART 3 — Production Code Patterns

Include 5-7 code patterns. Each pattern must:

1. Have a title that names the pattern, not describes the code (e.g., "The Null Guard at the Boundary" not "Checking for null")
2. Show production-quality code with comments that explain **why the decision was made**, not what the code does
3. Include the anti-pattern version immediately before the correct version where an anti-pattern exists
4. Use `// ⚠️ WRONG:` and `// ✅ CORRECT:` labels consistently
5. Have code that could be pasted into a real production codebase without modification

**Prohibited in this section:**

- Trivial "hello world" examples
- Code that exists only to demonstrate syntax
- Examples without a named real-world use case (name the scenario: "payment processing", "order management", "API parsing", etc.)

---

### PART 4 — Gotchas & Anti-Patterns

Include exactly **5 gotchas**. Each one must follow this exact format:

```
### Gotcha N: [Name of the Bug or Misconception]

[1-2 sentences explaining what the wrong mental model is and why engineers fall into this trap]

// ⚠️ WRONG CODE (with a comment showing WHY this produces incorrect behavior)
[wrong code]

// ✅ CORRECT CODE
[correct code]

// WHY: [1-3 sentences explaining the runtime reason this works]
```

Every gotcha must be a bug that actually appears in production C# codebases written by experienced engineers — not beginner mistakes. If you are describing something a beginner would also know to avoid, it is not a gotcha.

---

### PART 5 — Performance Implications

Include:

1. **Allocation Characteristics Table** — a markdown table with columns: Scenario | Allocation Behavior | Approx Cost. Minimum 8 rows. Cover both expensive and cheap paths.
    
2. **BenchmarkDotNet Code** — a complete, runnable benchmark class using `[MemoryDiagnoser]` and `[Benchmark]` attributes. The benchmark must compare at least 3 variants of the same operation (slow → fast → optimal). Include the expected output as a comment block labeled `// Expected output (approximate, .NET 8, x64):`.
    
3. **When to Care / When to Ignore** — two explicit subsections:
    
    - "When this costs you": specific production scenarios where this topic's performance characteristics cause real latency or GC pauses
    - "When this doesn't matter": specific scenarios where optimization would be premature

---

### PART 6 — Interview Arsenal

This section is the most important section for interview preparation. It must include:

**A. The Question Bank (3-5 questions)**

For each question, provide:

- The question exactly as an interviewer would ask it
- **Average Answer** (1-2 sentences): what most candidates say — correct but shallow
- **Why That's Insufficient** (1 sentence): what it misses
- **Great Answer** (3-6 sentences in a blockquote): what a senior engineer says. Must be written in first-person, conversational, ready to speak aloud. Must reference runtime behavior, production implications, or tradeoffs — not just definitions.

**B. The Trick Questions** — 3-5 questions that sound simple but have non-obvious answers. For each: the question, the trap, the correct answer.

**C. Red Flags to Avoid** — a list of 5-8 specific things you must NOT say in an interview about this topic, with a one-line explanation of why each one gets you scored down.

**The quality bar for the Great Answer:** An interviewer who is a principal engineer at a large company must read the Great Answer and think "this person understands the runtime" — not just "this person studied the documentation."

---

### PART 7 — Decision Framework

A single Mermaid flowchart that answers the practical question "when do I use X vs Y" for this topic. The flowchart must:

- Have a clear entry question at the top
- Have at least 6 decision nodes
- End at concrete, named choices (not "it depends")
- Use color to distinguish choice categories (use `style` directives)
- Be usable as a cheat sheet in a live interview when asked "how do you decide..."

---

### PART 8 — Self-Check

**A. Conceptual Questions** — 8-10 questions. These must require genuine understanding to answer. Avoid questions answerable by memorization alone. Each question should require the reader to reason from first principles, apply the mental model to a new scenario, or spot a flaw in a piece of code.

**B. Code Puzzles** — 4-5 short code puzzles. Each puzzle:

- Is 5-15 lines of C# code
- Asks "what is printed?" or "where is the bug?" or "does this allocate?"
- Has a non-obvious answer that requires knowing the topic deeply
- Has a collapsed `<details>` block with the answer and explanation

**Prohibited:** Questions answerable by Googling the definition. Every question must require active recall of the mechanisms described in this note.

---

### PART 9 — Connections & Resources

**A. Related Topics Table** — a markdown table with columns: Topic | Why It Connects. Use `[[wiki links]]`. The "Why It Connects" must be a specific sentence explaining the dependency or relationship — not just "related".

**B. Books** — a table with columns: Book | Chapters | Why These Chapters. Maximum 4 books. Only include books where the specific chapters are directly about this topic.

**C. Essential Articles & Docs** — 4-6 links. Only include:

- Official Microsoft Docs/Blog
- Stephen Toub, Adam Sitnik, David Fowler, Jon Skeet, or equivalent authoritative .NET sources
- No SEO-driven tutorial sites

**D. Template Meta-Note** — a `> [!NOTE]` callout at the very end reminding the reader what each of the 9 parts is for (one line per part). This is the template's signature — it must appear on every generated note.

---

## QUALITY REQUIREMENTS

Apply these to the entire document without exception:

**1. No definition-first writing.** Never start a section with "X is a feature that...". Start with impact, behavior, or the problem it solves.

**2. No shallow analogies.** Every analogy must map to the actual runtime mechanism. If you use a physical analogy in Part 1, it must still hold when a reader asks "but what about [edge case]?"

**3. Cost visibility.** Every non-trivial operation must have its cost labeled. "~5 ns", "O(n)", "one heap allocation", "zero allocation", "one defensive copy". Make cost visible throughout.

**4. Production scenarios.** Every code example must name the domain it comes from. Use payment systems, order management, user services, API parsing, file processing — real enterprise domains. Never use `foo`, `bar`, `MyClass`, `SomeInterface` as names.

**5. Interview answer narrative.** Great Answers in Part 6 must be written to be spoken aloud, in first person, with natural connective language. They must not be bullet lists. They must be 3-6 complete sentences.

**6. The 5-puzzle rule.** At least one Code Puzzle in Part 8 must involve a bug that is specifically caused by the most common misunderstanding of this topic.

**7. Complete code.** Every code block must compile (modulo stubs) and be complete enough to understand in isolation. No `// ... rest of implementation`. No implied code.

---

## YAML FRONTMATTER TEMPLATE

The note must start with exactly this frontmatter structure (fill in values):

```yaml
---
topic: "{{TOPIC_NAME}}"
studied_well: false
domain: "C# Language Mastery"
topic_id: "{{TOPIC_ID}}"
tags:
  - csharp
  - dotnet
  - [add 3-5 specific tags relevant to this topic]
status: "complete"
difficulty: "[beginner | intermediate | intermediate-to-advanced | advanced | expert]"
interview_importance: "[low | medium | high | critical]"
production_importance: "[low | medium | high | critical]"
last_reviewed: "2026-06"
related:
  - "[[list related topic wiki links here]]"
---
```

---

## FINAL INSTRUCTION

Do not truncate any section. Do not summarize instead of writing. Do not add sections not in the template. Do not remove sections from the template.

The note must be ready to paste into Obsidian with zero editing. The reader must be able to open this note, read it in 45-60 minutes, and be meaningfully better at both writing production C# and answering interview questions about this topic than before they read it.

Generate the complete note for **{{TOPIC_ID}} — {{TOPIC_NAME}}** now.

---

## END OF PROMPT

---

---

## QUICK REFERENCE — What Each Part Does

|Part|Name|Purpose|Approx Length|
|---|---|---|---|
|0|Navigation|Orientation, prerequisites, context|Short|
|1|Core Mental Model|The anchor — one sentence + analogy + taxonomy|Medium|
|2|Deep Mechanics|Runtime behavior, memory, compiler transforms|Long|
|3|Production Code|5-7 annotated real-world patterns|Long|
|4|Gotchas|5 production bugs with wrong→right→why|Medium|
|5|Performance|Allocation table + benchmark + when to care|Medium|
|6|Interview Arsenal|Full questions with great answers + tricks + red flags|Long|
|7|Decision Framework|Flowchart for when to use what|Short|
|8|Self-Check|8-10 questions + 4-5 code puzzles|Medium|
|9|Connections|Wiki links + books + articles + meta-note|Short|

---

## TIPS FOR BEST RESULTS

**If the output is too shallow on Part 2:** Add to the prompt: _"Part 2 must include at least one IL-level or JIT-level explanation. Show what the compiler actually generates, not just what the language specification says."_

**If Part 6 interview answers are still bullet-point style:** Add: _"Great Answers in Part 6 must be written as a monologue, not a list. Write them as if you are speaking into a microphone during an interview. No bullets. No numbered lists. Full sentences connected with natural transitions."_

**If code examples feel generic:** Add: _"Every code example must be from a named enterprise domain: e-commerce, financial systems, healthcare systems, or logistics. The class names, method names, and variable names must reflect a real business concept."_

**If the note feels like documentation rather than study material:** Add: _"The tone must be that of a senior engineer explaining something to a capable junior engineer — direct, opinionated, occasionally blunt about what matters and what doesn't. Do not hedge. Make claims."_
