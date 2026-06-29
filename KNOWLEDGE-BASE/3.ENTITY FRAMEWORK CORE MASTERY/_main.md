# MASTER PROMPT — EF Core Knowledge Base Topic Generator

> Copy everything between the triple-dashes. Replace `{{TOPIC_NAME}}`, `{{TOPIC_ID}}`, and `{{RELATED_TOPICS}}` with the values from the topic index. Paste as your message to the AI.

---

## HOW TO USE THIS PROMPT

1. Open the **Topic Index** file (`_phonebook_efcore.md`) and pick the next topic to generate
2. Copy the full prompt below
3. Replace the three placeholders:
    - `{{TOPIC_ID}}` → e.g. `3.03`
    - `{{TOPIC_NAME}}` → e.g. `LINQ to SQL: Query Translation Pipeline`
    - `{{RELATED_TOPICS}}` → paste the related topics list from the index
4. Send it. The output is ready to paste into Obsidian as-is.

---

---

## THE PROMPT (copy from here)

---

You are a **senior .NET software engineer** with deep expertise in Entity Framework Core internals, ORM query translation, SQL generation, database performance, production data access layer design, and the technical interview process at large software companies (Microsoft, Amazon, Google, and equivalent). You are writing for an engineer with 2 years of production .NET and EF Core experience who is systematically preparing for senior-level roles at top-tier companies. Every word you write must serve two purposes simultaneously: help them be a better production engineer AND help them pass the hardest technical interviews.

**This is not a tutorial. This is a career document.**

The single most important thing that separates a senior EF Core engineer from a mid-level one is this: the senior engineer always knows what SQL their code generates. Every LINQ query you write must be accompanied by the SQL it produces. Treat the generated SQL with the same reverence you would give IL output in a C# internals note.

---

## YOUR TASK

Generate a complete, production-grade Obsidian knowledge base note for the following EF Core topic:

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
- ASCII art for Change Tracker state maps, query pipeline diagrams, and memory layout (Mermaid cannot do these)
- Obsidian wiki links: `[[topic name]]`
- Collapsible `<details>` blocks for puzzle answers only
- Syntax-highlighted code blocks: ` ```csharp ``` ` and ` ```sql ``` `
- Generated SQL blocks labeled: `// EF Core generates (SQL Server, approximate):`

---

## THE 9-PART STRUCTURE

### PART 0 — Navigation & Context

Include:

- A tree diagram showing where this topic sits in the EF Core domain hierarchy (ASCII or Mermaid). The hierarchy should reflect: Configuration Layer → Query Layer → Write Layer → Advanced Features → Architecture Patterns.
- A "What you need before this" section (2-4 prerequisite topics)
- A "What this unlocks after" section (2-4 topics that depend on this one)
- One sentence explaining WHY this specific topic matters to a production engineer at scale — specifically in the context of databases, query performance, or data correctness.

The navigation must make the reader feel oriented before reading a single line of content.

---

### PART 1 — The Core Mental Model

Include three things and nothing else:

1. **The Fundamental Rule** — one sentence in a blockquote that anchors the entire topic. This sentence must be precise enough to be defended in an interview and simple enough to say out loud in 5 seconds. Example format: `> **EF Core's X does Y when Z. The practical consequence is [database behavior].**`
    
2. **The Plain-Language Analogy** — 3-5 sentences. Use a concrete, physical analogy that maps to the actual database/ORM behavior — not just the C# surface. The analogy must still hold when a reader asks "but what about [the N+1 case / the transaction rollback / the schema mismatch]?"
    
3. **The Taxonomy Diagram** — a Mermaid diagram showing the full classification structure of this topic: all variants, strategies, related EF Core constructs, and their relationships. This must be complete — not a simplified version. Color-code groups: configuration vs. query vs. write vs. advanced.
    

---

### PART 2 — Deep Mechanics

This is the longest and most technically dense section. It must explain what EF Core is actually doing — not just what the documentation says.

**Every sub-section must include at minimum:**

- **Generated SQL**: For any LINQ query or EF Core operation, show the approximate SQL EF Core generates. Use labeled comment blocks:
    
    ```
    // EF Core generates (SQL Server, approximate):
    // SELECT o.Id, o.Amount, c.Email
    // FROM Orders AS o
    // INNER JOIN Customers AS c ON o.CustomerId = c.Id
    // WHERE o.Status = 1
    ```
    
    If the SQL differs meaningfully between providers (SQL Server vs PostgreSQL vs SQLite), note the most important variant.
    
- **Client vs. Server Evaluation**: Explicitly identify which parts of an expression tree run as SQL and which fall back to C# evaluation in memory. Name the line where the query "leaves the database". If client evaluation silently occurs, call it out as a danger.
    
- **Change Tracker State Diagrams**: For any topic involving entity writes, show the entity state transitions using ASCII art:
    
    ```
    Detached ──Add()──► Added ──SaveChanges()──► Unchanged
                                                      │
                                                Modify property
                                                      │
                                                      ▼
                                                 Modified ──SaveChanges()──► Unchanged
    ```
    
- **Query Pipeline Internals**: Show where in the EF Core pipeline a concept lives — model building, query compilation, query execution, result materialization. A simple ASCII pipeline is sufficient.
    
- **Runtime Cost Labels**: Every operation must carry its cost: `~N SQL round trips`, `O(n) Change Tracker scan`, `one heap allocation per row`, `zero-allocation with AsNoTracking`.
    
- **The Edge Cases That Bite Engineers**: Every sub-topic must include the non-obvious behavior — not what works, but what surprises teams at scale (N+1 under lazy loading, phantom reads under Read Committed, client-evaluation fallback that silently loads 50,000 rows).
    

Minimum: 4 sub-sections, each with a SQL block or diagram and a cost label.

---

### PART 3 — Production Code Patterns

Include 5-7 code patterns. Each pattern must:

1. Have a title that names the pattern, not describes the code (e.g., "The Projection Firewall" not "Using Select to limit columns")
2. Show production-quality C# with comments explaining **why the decision was made**, not what the code does
3. Show the generated SQL immediately after the C# code in a `// EF Core generates:` block
4. Include the anti-pattern version immediately before the correct version where one exists
5. Use `// ⚠️ WRONG:` and `// ✅ CORRECT:` labels consistently
6. Have code that could be pasted into a real production codebase without modification
7. Name a real enterprise domain scenario: payment processing, order management, user services, inventory, logistics

**Prohibited in this section:**

- LINQ queries without their generated SQL
- Trivial examples that exist only to demonstrate syntax
- `foo`, `bar`, `MyClass`, `SomeRepo` as names
- Examples where the domain is not named

---

### PART 4 — Gotchas & Anti-Patterns

Include exactly **5 gotchas**. Each one must follow this exact format:

```
### Gotcha N: [Name of the Bug or Misconception]

[1-2 sentences explaining the wrong mental model and why experienced engineers fall into this trap]

// ⚠️ WRONG CODE
[wrong code]

// EF Core generates (WRONG path):
// [the bad SQL, or description of the client-side fallback behavior]

// ✅ CORRECT CODE
[correct code]

// EF Core generates (CORRECT path):
// [the good SQL]

// WHY: [1-3 sentences explaining the database/EF Core reason this works]
```

Every gotcha must be a bug that appears in production EF Core codebases written by experienced engineers. If a beginner would also know to avoid it, it is not a gotcha. Focus on:

- Silent N+1 queries caused by navigation property access
- Client-evaluation fallbacks that load far more data than intended
- Change Tracker overhead in read-heavy paths
- Transaction scope surprises
- Concurrency conflicts on high-traffic entities

---

### PART 5 — Performance Implications

Include:

1. **Query Characteristics Table** — a markdown table with columns: `Scenario | SQL Queries Generated | Approx Rows Fetched | Allocation Behavior | Recommendation`. Minimum 8 rows. Cover both expensive and cheap paths.
    
2. **BenchmarkDotNet Code** — a complete, runnable benchmark class using `[MemoryDiagnoser]` and `[Benchmark]` attributes. The benchmark must compare at least 3 variants (naive → optimized → optimal). Include expected output labeled `// Expected output (approximate, .NET 8, SQL Server local, 1000 rows):`. Add a note about what to profile with MiniProfiler or EF Core logging alongside BenchmarkDotNet for real SQL profiling.
    
3. **When to Care / When to Ignore** — two explicit sub-sections:
    
    - "When this costs you": specific production scenarios — latency spikes, GC pauses, connection pool exhaustion, N+1 at 10k requests/minute
    - "When this doesn't matter": admin endpoints, one-time scripts, low-traffic internal tools

---

### PART 6 — Interview Arsenal

This section is the most important for interview preparation. It must include:

**A. The Question Bank (3-5 questions)**

For each question, provide:

- The question exactly as an interviewer would ask it
- **Average Answer** (1-2 sentences): what most candidates say — correct but shallow
- **Why That's Insufficient** (1 sentence): what it misses
- **Great Answer** (3-6 sentences in a blockquote): what a senior engineer says. Must be written in first-person, conversational, ready to speak aloud. Must reference the SQL generated, the database behavior at scale, or a concrete trade-off the candidate has made in production.

**B. The Trick Questions** — 3-5 questions that sound simple but have non-obvious answers. For each: the question, the trap, and the correct answer (including the SQL or behavior that proves the answer).

**C. Red Flags to Avoid** — 5-8 specific things you must NOT say in an interview about this topic, with one line explaining why each gets you scored down.

**The quality bar for the Great Answer:** An interviewer who is a principal engineer must read the Great Answer and think "this person knows what SQL is going out over the wire" — not just "this person read the EF Core docs."

---

### PART 7 — Decision Framework

A single Mermaid flowchart that answers the practical question "when do I use X vs Y" for this topic. The flowchart must:

- Have a clear entry question at the top
- Have at least 6 decision nodes
- End at concrete, named choices (not "it depends")
- Use color to distinguish choice categories (query strategy vs. write strategy vs. configuration)
- Be usable as a cheat sheet during a live interview when asked "how do you decide..."

---

### PART 8 — Self-Check

**A. Conceptual Questions** — 8-10 questions. Must require genuine understanding, not memorization. At least 2 questions must be of the form "What SQL does this LINQ expression generate, and is that what you intended?" Another 2 must require reasoning about Change Tracker state or transaction scope.

**B. Code Puzzles** — 4-5 short code puzzles. Each puzzle:

- Is 5-15 lines of C# using EF Core
- Asks "what SQL is generated?", "how many queries does this send?", "where is the bug?", or "does this hit the database?"
- Has a non-obvious answer that requires knowing the topic deeply
- Has a collapsed `<details>` block with the answer, the SQL produced, and the explanation

**The 5-puzzle rule:** At least one puzzle must involve a bug caused by the most common misunderstanding of this specific topic (e.g., the N+1 for loading topics, the detached entity for change tracking topics, the client-evaluation fallback for query topics).

---

### PART 9 — Connections & Resources

**A. Related Topics Table** — a markdown table with columns: `Topic | Why It Connects`. Use `[[wiki links]]`. The "Why It Connects" must be a specific sentence about the dependency — not just "related". Cross-reference both EF Core topics (3.XX) and C# language topics (2.XX) where genuinely relevant.

**B. Books** — a table with columns: `Book | Chapters | Why These Chapters`. Maximum 4 books. Only include books where specific chapters directly address this topic.

**C. Essential Articles & Docs** — 4-6 links. Only include:

- Official Microsoft EF Core Docs / EF Core GitHub issues
- Arthur Vickers, Brice Lambson, Shay Rojansky, or equivalent EF Core team authors
- Julie Lerman (Entity Framework in Action)
- No SEO-driven tutorial sites

**D. Template Meta-Note** — a `> [!NOTE]` callout at the very end reminding the reader what each of the 9 parts is for (one line per part). This is the template's signature — it must appear on every generated note.

---

## QUALITY REQUIREMENTS

Apply these to the entire document without exception:

**1. SQL Visibility.** Every LINQ query or EF Core operation that touches the database must be accompanied by the approximate SQL it generates. Labeled `// EF Core generates (SQL Server, approximate):`. No exceptions. This is the single most important requirement for EF Core notes. A developer who cannot predict the SQL their queries generate is not a senior engineer.

**2. Abstraction Awareness.** Every major section must identify at least one place where EF Core's abstraction breaks down — a query that cannot be translated to SQL (client evaluation), a behavior that differs from raw SQL expectations, a performance cliff that only appears at scale (> 10k rows, > 100 req/s). Do not pretend the ORM is transparent.

**3. No definition-first writing.** Never start a section with "X is a feature that...". Start with impact, behavior, or the problem it solves.

**4. No shallow analogies.** Every analogy must map to the actual database/ORM mechanism. If you use a physical analogy in Part 1, it must still hold when a reader asks "but what about [the disconnected scenario / the concurrent update / the rollback]?"

**5. Cost visibility.** Every non-trivial operation must have its cost labeled. "1 SQL query", "N+1 queries", "O(n) Change Tracker scan", "one heap allocation per materialized entity", "zero allocation with AsNoTracking + projection".

**6. Production scenarios.** Every code example must name the domain it comes from: order management, payment processing, inventory, user service, logistics. Never use `Foo`, `Bar`, `MyEntity`, `SomeRepo`.

**7. Interview answer narrative.** Great Answers in Part 6 must be written to be spoken aloud, in first person, with natural transitions. They must NOT be bullet lists. They must reference SQL output or database behavior, not just LINQ syntax.

**8. The 5-puzzle rule.** At least one Code Puzzle in Part 8 must involve a bug caused by the most common misunderstanding of this topic.

**9. Complete code.** Every code block must compile (modulo stubs) and be complete enough to understand in isolation. No `// ... rest of implementation`. No implied code.

**10. EF Core version awareness.** Where a feature is EF7+ or EF8+ (e.g., ExecuteUpdate/ExecuteDelete, JSON columns, complex types), label it clearly. Target EF Core 8 as the baseline; note where behavior differs in EF Core 6/7.

---

## YAML FRONTMATTER TEMPLATE

The note must start with exactly this frontmatter structure (fill in values):

```yaml
---
topic: "{{TOPIC_NAME}}"
studied_well: false
domain: "EF Core Mastery"
topic_id: "{{TOPIC_ID}}"
tags:
  - efcore
  - dotnet
  - orm
  - [add 3-5 specific tags relevant to this topic]
status: "complete"
difficulty: "[beginner | intermediate | intermediate-to-advanced | advanced | expert]"
interview_importance: "[low | medium | high | critical]"
production_importance: "[low | medium | high | critical]"
ef_core_version: "8.0+"
last_reviewed: "2026-06"
related:
  - "[[list related topic wiki links here]]"
---
```

---

## FINAL INSTRUCTION

Do not truncate any section. Do not summarize instead of writing. Do not add sections not in the template. Do not remove sections from the template.

The note must be ready to paste into Obsidian with zero editing. The reader must be able to open this note, read it in 45-60 minutes, and be meaningfully better at both writing production EF Core code and answering interview questions about this topic than before they read it.

Generate the complete note for **{{TOPIC_ID}} — {{TOPIC_NAME}}** now.

---

## END OF PROMPT

---

---

## QUICK REFERENCE — What Each Part Does

|Part|Name|Purpose|EF Core-specific requirement|
|---|---|---|---|
|0|Navigation|Orientation, prerequisites, context|Show EF Core domain hierarchy|
|1|Core Mental Model|One sentence + analogy + taxonomy|Analogy must map to DB/ORM behavior|
|2|Deep Mechanics|Runtime behavior, query pipeline, internals|**Generated SQL required in every block**|
|3|Production Code|5-7 annotated real-world patterns|SQL shown after every LINQ query|
|4|Gotchas|5 production bugs with wrong→right→why|Include wrong SQL and correct SQL|
|5|Performance|Query table + benchmark + when to care|Query count + row count metrics|
|6|Interview Arsenal|Full questions + great answers + tricks + red flags|Great Answers reference SQL output|
|7|Decision Framework|Flowchart for when to use what|Must answer "what query strategy?"|
|8|Self-Check|8-10 questions + 4-5 code puzzles|Puzzles ask "how many queries?" and "what SQL?"|
|9|Connections|Wiki links + books + articles + meta-note|Cross-link EF Core (3.XX) and C# (2.XX)|

---

## TIPS FOR BEST RESULTS

**If Part 2 SQL blocks feel vague:** Add to the prompt: _"Every SQL block in Part 2 must be complete enough to run against a real database. Include the full SELECT clause, all JOINs, the WHERE clause, and any ORDER BY or TOP/LIMIT. No '...' in SQL blocks."_

**If Part 6 interview answers mention features without database behavior:** Add: _"Every Great Answer must include at least one sentence that explicitly states what SQL is generated, how many queries go to the database, or what happens to the Change Tracker. Answers that only discuss LINQ syntax without mentioning the database layer are insufficient."_

**If the code examples feel generic (no domain):** Add: _"Every code example must be from one of these domains: e-commerce order management, fintech payment processing, healthcare patient records, or logistics shipment tracking. Class names, method names, and variable names must reflect the business concept. No generic names."_

**If Part 4 gotchas are too basic:** Add: _"Every gotcha must be a bug that a developer with 2+ years of EF Core experience would still make. Show the wrong SQL that the anti-pattern generates — the badness of the SQL is what makes it a gotcha, not just a style issue."_

**If the note reads like documentation rather than study material:** Add: _"The tone must be that of a senior engineer who has debugged this in production — direct, occasionally blunt about what the ORM is hiding from you, and specific about failure modes at scale. Do not write marketing copy for EF Core."_

**If Change Tracker state transitions are missing:** Add: _"For every write operation in Part 2 and Part 3, include an ASCII state diagram showing the entity moving through Added → Unchanged → Modified → Deleted states. Show where SaveChanges() flushes the state. Show what AsNoTracking() bypasses."_
