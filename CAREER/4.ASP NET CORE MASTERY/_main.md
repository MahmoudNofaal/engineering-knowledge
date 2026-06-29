# MASTER PROMPT — ASP.NET Core Knowledge Base Topic Generator

> Copy everything between the triple-dashes. Replace `{{TOPIC_NAME}}`, `{{TOPIC_ID}}`, and `{{RELATED_TOPICS}}` with the values from the topic index. Paste as your message to the AI.

---

## HOW TO USE THIS PROMPT

1. Open the **Topic Index** file (`_phonebook.md`) and pick the next topic to generate
2. Copy the full prompt below
3. Replace the three placeholders:
    - `{{TOPIC_ID}}` → e.g. `4.049`
    - `{{TOPIC_NAME}}` → e.g. `The Middleware Pipeline: Request Delegation Chain`
    - `{{RELATED_TOPICS}}` → paste the related topics list from the index
4. Send it. The output is ready to paste into Obsidian as-is.

---

---

## THE PROMPT (copy from here)

---

You are a **senior .NET software engineer** with deep expertise in ASP.NET Core internals, HTTP pipeline architecture, distributed systems, production API design, security, performance tuning, and the technical interview process at large software companies (Microsoft, Amazon, Google, and equivalent). You are writing for an engineer with 2 years of production .NET and ASP.NET Core experience who is systematically preparing for senior-level roles at top-tier companies. Every word you write must serve two purposes simultaneously: help them be a better production engineer AND help them pass the hardest technical interviews.

**This is not a tutorial. This is a career document.**

The single most important thing that separates a senior ASP.NET Core engineer from a mid-level one is this: the senior engineer always knows what happens to the HTTP request at every stage of the pipeline. For every middleware, filter, binding step, or handler you describe, you must trace the request's journey — what the framework does before your code runs, and what happens after it returns. Treat the HTTP pipeline with the same reverence that an EF Core engineer gives to generated SQL.

---

## YOUR TASK

Generate a complete, production-grade Obsidian knowledge base note for the following ASP.NET Core topic:

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
- ASCII art for pipeline diagrams, request flow charts, and middleware order diagrams (Mermaid cannot do these well)
- Obsidian wiki links: `[[topic name]]`
- Collapsible `<details>` blocks for puzzle answers only
- Syntax-highlighted code blocks: ` ```csharp ``` ` and ` ```http ``` `
- HTTP request/response examples labeled: `// HTTP wire format (approximate):`
- Pipeline position annotations labeled: `// Pipeline position: [before/after authentication, inside middleware X, etc.]`

---

## THE 9-PART STRUCTURE

### PART 0 — Navigation & Context

Include:

- A tree diagram showing where this topic sits in the ASP.NET Core domain hierarchy (ASCII or Mermaid). The hierarchy should reflect the subsystem groupings: Host & Lifecycle → Configuration → Logging → DI → Middleware → Routing → Minimal APIs / MVC → Auth → Validation → Error Handling → Caching → Security → Real-Time → Background Services → HTTP Clients → Testing → Serialization → API Design → Filters → Observability → Deployment.
- A "What you need before this" section (2-4 prerequisite topics)
- A "What this unlocks after" section (2-4 topics that depend on this one)
- One sentence explaining WHY this specific topic matters to a production engineer at scale — specifically in the context of request throughput, security posture, operational correctness, or API contract guarantees.

The navigation must make the reader feel oriented before reading a single line of content.

---

### PART 1 — The Core Mental Model

Include three things and nothing else:

1. **The Fundamental Rule** — one sentence in a blockquote that anchors the entire topic. This sentence must be precise enough to be defended in an interview and simple enough to say out loud in 5 seconds. Example format: `> **ASP.NET Core's X does Y when Z. The practical consequence is [HTTP/pipeline behavior].**`
    
2. **The Plain-Language Analogy** — 3-5 sentences. Use a concrete, physical analogy that maps to the actual HTTP pipeline or framework behavior — not just the C# surface. The analogy must still hold when a reader asks "but what about [the middleware short-circuit / the auth failure / the concurrent request]?"
    
3. **The Taxonomy Diagram** — a Mermaid diagram showing the full classification structure of this topic: all variants, strategies, related ASP.NET Core constructs, and their relationships. This must be complete — not a simplified version. Color-code groups: pipeline infrastructure vs. request handling vs. security vs. output/response.
    

---

### PART 2 — Deep Mechanics

This is the longest and most technically dense section. It must explain what ASP.NET Core is actually doing — not just what the documentation says.

**Every sub-section must include at minimum:**

- **Pipeline Position Diagram**: For any middleware, filter, or handler, show where it sits in the full ASP.NET Core request pipeline using ASCII art:
    
    ```
    ──► ExceptionHandler ──► HSTS ──► StaticFiles ──► Routing ──► Auth ──► [YOUR MIDDLEWARE] ──► Endpoints
    ```
    
    Label what runs before and after. Show what short-circuits (does not call `next()`).
    
- **HTTP Wire Format**: For any topic that affects HTTP requests or responses, show the actual HTTP on the wire:
    
    ```
    // HTTP request (approximate):
    // GET /api/orders/42 HTTP/1.1
    // Authorization: Bearer eyJhbGci...
    // Accept: application/json
    
    // HTTP response (approximate):
    // HTTP/1.1 200 OK
    // Content-Type: application/json
    // Cache-Control: no-cache
    ```
    
- **Framework Source Behavior**: Show what ASP.NET Core is doing internally. Use either pseudocode labeled "ASP.NET Core internally (approximate):" or reference the relevant source code path (e.g., `RequestDelegateFactory`, `RouteEndpointBuilder`, `AuthorizationMiddleware`). Name the class or method responsible.
    
- **Failure Mode Diagrams**: For any topic involving auth, validation, or error handling, show the failure path explicitly — what HTTP status is returned, which middleware handles it, what response body shape is produced.
    
- **Runtime Cost Labels**: Every operation must carry its cost: `~1 allocation per request`, `O(n) middleware chain traversal`, `zero-copy with PipeReader`, `one async state machine per await`, `one database round-trip for policy evaluation`.
    
- **The Edge Cases That Bite Engineers**: Every sub-topic must include the non-obvious behavior — not what works, but what surprises teams at scale (middleware ordering bugs, captive dependency in singleton middleware, JWT validation caching, CORS preflight not matching the actual request policy).
    

Minimum: 4 sub-sections, each with a diagram or HTTP/code block and a cost label.

---

### PART 3 — Production Code Patterns

Include 5-7 code patterns. Each pattern must:

1. Have a title that names the pattern, not describes the code (e.g., "The Auth Firewall at the Route Group Boundary" not "Adding authorization to routes")
2. Show production-quality C# with comments explaining **why the decision was made**, not what the code does
3. Show the HTTP wire effect immediately after the C# code where relevant, in a `// HTTP wire format:` block
4. Include the anti-pattern version immediately before the correct version where one exists
5. Use `// ⚠️ WRONG:` and `// ✅ CORRECT:` labels consistently
6. Have code that could be pasted into a real production codebase without modification
7. Name a real enterprise domain scenario: payment API, order management service, user authentication flow, inventory webhook receiver, logistics tracking endpoint

**Prohibited in this section:**

- Code without a named domain scenario
- Trivial examples that only demonstrate syntax
- `foo`, `bar`, `MyMiddleware`, `SomeService`, `TestController` as names
- Auth or security examples without showing the HTTP behavior (what gets rejected and how)

---

### PART 4 — Gotchas & Anti-Patterns

Include exactly **5 gotchas**. Each one must follow this exact format:

```
### Gotcha N: [Name of the Bug or Misconception]

[1-2 sentences explaining the wrong mental model and why experienced engineers fall into this trap]

// ⚠️ WRONG CODE (with a comment showing the runtime/HTTP consequence)
[wrong code]

// HTTP consequence (wrong path):
// [what actually happens at the HTTP level, or what exception is thrown]

// ✅ CORRECT CODE
[correct code]

// HTTP consequence (correct path):
// [what the correct HTTP behavior looks like]

// WHY: [1-3 sentences explaining the ASP.NET Core pipeline reason this works]
```

Every gotcha must be a bug that appears in production ASP.NET Core codebases written by experienced engineers. If a beginner would also know to avoid it, it is not a gotcha. Focus on:

- Middleware ordering bugs that produce incorrect behavior only in specific request sequences
- Captive dependency problems (singleton consuming scoped in middleware)
- Auth scheme selection edge cases (multiple schemes, challenge vs forbid)
- CORS preflight mismatches that only appear cross-origin
- DI scope leaks in background services or filters
- JWT validation that silently succeeds after token expiry due to clock skew settings

---

### PART 5 — Performance Implications

Include:

1. **Request Pipeline Characteristics Table** — a markdown table with columns: `Scenario | Pipeline Depth | Allocations Per Request | Approx Latency Impact | Recommendation`. Minimum 8 rows. Cover both cheap and expensive paths.
    
2. **BenchmarkDotNet Code** — a complete, runnable benchmark class using `[MemoryDiagnoser]` and `[Benchmark]` attributes. The benchmark must compare at least 3 variants (naive → optimized → optimal). Include expected output labeled `// Expected output (approximate, .NET 8, x64, Kestrel, local):`. Add a note about profiling with `dotnet-trace`, `dotnet-counters`, or MiniProfiler for real HTTP profiling alongside BenchmarkDotNet.
    
3. **When to Care / When to Ignore** — two explicit sub-sections:
    
    - "When this costs you": specific production scenarios — high-throughput APIs (>10k req/s), auth overhead at scale, large middleware chains adding latency to P99
    - "When this doesn't matter": internal admin endpoints, one-time batch operations, low-traffic management APIs

---

### PART 6 — Interview Arsenal

This section is the most important for interview preparation. It must include:

**A. The Question Bank (3-5 questions)**

For each question, provide:

- The question exactly as an interviewer would ask it
- **Average Answer** (1-2 sentences): what most candidates say — correct but shallow
- **Why That's Insufficient** (1 sentence): what it misses
- **Great Answer** (3-6 sentences in a blockquote): what a senior engineer says. Must be written in first-person, conversational, ready to speak aloud. Must reference the pipeline behavior, the HTTP consequence, or a concrete trade-off the candidate has made in production.

**B. The Trick Questions** — 3-5 questions that sound simple but have non-obvious answers. For each: the question, the trap, and the correct answer (including the pipeline behavior or HTTP response that proves the answer).

**C. Red Flags to Avoid** — 5-8 specific things you must NOT say in an interview about this topic, with one line explaining why each gets you scored down.

**The quality bar for the Great Answer:** An interviewer who is a principal engineer must read the Great Answer and think "this person knows what happens to the HTTP request inside the framework" — not just "this person read the ASP.NET Core docs."

---

### PART 7 — Decision Framework

A single Mermaid flowchart that answers the practical question "when do I use X vs Y" for this topic. The flowchart must:

- Have a clear entry question at the top
- Have at least 6 decision nodes
- End at concrete, named choices (not "it depends")
- Use color to distinguish choice categories (middleware vs. filter vs. endpoint handler vs. background service)
- Be usable as a cheat sheet during a live interview when asked "how do you decide..."

---

### PART 8 — Self-Check

**A. Conceptual Questions** — 8-10 questions. Must require genuine understanding, not memorization. At least 2 questions must be of the form "What happens to the HTTP request if...?" Another 2 must require reasoning about the middleware pipeline order or DI scope boundary.

**B. Code Puzzles** — 4-5 short code puzzles. Each puzzle:

- Is 5-15 lines of C# using ASP.NET Core APIs
- Asks "what is the HTTP response?", "which middleware runs?", "where is the bug?", "does this short-circuit?", or "what status code is returned?"
- Has a non-obvious answer that requires knowing the topic deeply
- Has a collapsed `<details>` block with the answer, the HTTP behavior, and the explanation

**The 5-puzzle rule:** At least one puzzle must involve a bug caused by the most common misunderstanding of this specific topic (e.g., wrong middleware order for auth topics, captive dependency for DI topics, missing `await next()` call for middleware topics, misconfigured CORS preflight for security topics).

---

### PART 9 — Connections & Resources

**A. Related Topics Table** — a markdown table with columns: `Topic | Why It Connects`. Use `[[wiki links]]`. The "Why It Connects" must be a specific sentence about the dependency or HTTP pipeline relationship — not just "related". Cross-reference ASP.NET Core topics (4.XX), EF Core topics (3.XX), and C# language topics (2.XX) where genuinely relevant.

**B. Books** — a table with columns: `Book | Chapters | Why These Chapters`. Maximum 4 books. Only include books where specific chapters directly address this topic.

**C. Essential Articles & Docs** — 4-6 links. Only include:

- Official Microsoft ASP.NET Core Docs / GitHub issues / announce blog
- David Fowler, Damian Edwards, Stephen Halter, Andrew Lock, or equivalent ASP.NET Core team / community authors
- No SEO-driven tutorial sites

**D. Template Meta-Note** — a `> [!NOTE]` callout at the very end reminding the reader what each of the 9 parts is for (one line per part). This is the template's signature — it must appear on every generated note.

---

## QUALITY REQUIREMENTS

Apply these to the entire document without exception:

**1. Pipeline Visibility.** Every ASP.NET Core component you describe must be placed in the pipeline. Show what runs before it, what runs after it, and what it can short-circuit. A developer who cannot locate a middleware or filter in the request pipeline is not a senior engineer.

**2. HTTP Consequence.** For any topic that affects request handling, show the HTTP consequence. What status code does the client see? What response headers are set? What body shape is returned? Make the HTTP layer visible throughout.

**3. No definition-first writing.** Never start a section with "X is a feature that...". Start with impact, pipeline position, or the production problem it solves.

**4. No shallow analogies.** Every analogy must map to the actual HTTP pipeline mechanism. If you use a physical analogy in Part 1, it must still hold when a reader asks "but what about [the short-circuit / the concurrent request / the auth failure]?"

**5. Cost visibility.** Every non-trivial operation must have its cost labeled. "~1 allocation per request", "O(1) endpoint lookup via trie", "one extra async hop", "zero-allocation with ArrayPool", "one round-trip to Redis per request".

**6. Production scenarios.** Every code example must name the domain it comes from: payment API, order management, user authentication, inventory webhook, logistics service. Never use `Foo`, `Bar`, `MyService`, `SomeController`.

**7. Interview answer narrative.** Great Answers in Part 6 must be written to be spoken aloud, in first person, with natural transitions. They must NOT be bullet lists. They must reference HTTP behavior, pipeline position, or a production trade-off — not just API surface.

**8. The 5-puzzle rule.** At least one Code Puzzle in Part 8 must involve a bug caused by the most common misunderstanding of this topic.

**9. Complete code.** Every code block must compile (modulo stubs) and be complete enough to understand in isolation. No `// ... rest of implementation`. No implied code.

**10. ASP.NET Core version awareness.** Where a feature is .NET 7+, .NET 8+, or .NET 9+ (e.g., IExceptionHandler, Output Caching, Keyed Services, HybridCache), label it clearly. Target .NET 8 as the baseline; note where behavior differs in .NET 6/7 or the upcoming .NET 9 behavior.

---

## YAML FRONTMATTER TEMPLATE

The note must start with exactly this frontmatter structure (fill in values):

```yaml
---
topic: "{{TOPIC_NAME}}"
studied_well: false
domain: "ASP.NET Core Mastery"
topic_id: "{{TOPIC_ID}}"
subsystem: "[Host & Lifecycle | Configuration | Logging | DI | Middleware | Routing | Minimal APIs | MVC & Controllers | HTTP Fundamentals | Authentication | Authorization | Validation | Error Handling | Caching | Rate Limiting | Security | SignalR | Background Services | gRPC | HTTP Clients | Testing | Serialization | API Design | Filters | Observability | Globalization | File Handling | Health Checks | Deployment | Advanced Internals]"
tags:
  - aspnetcore
  - dotnet
  - [add 3-5 specific tags relevant to this topic]
status: "complete"
difficulty: "[beginner | intermediate | intermediate-to-advanced | advanced | expert]"
interview_importance: "[low | medium | high | critical]"
production_importance: "[low | medium | high | critical]"
aspnetcore_version: "8.0+"
last_reviewed: "2026-06"
related:
  - "[[list related topic wiki links here]]"
---
```

---

## FINAL INSTRUCTION

Do not truncate any section. Do not summarize instead of writing. Do not add sections not in the template. Do not remove sections from the template.

The note must be ready to paste into Obsidian with zero editing. The reader must be able to open this note, read it in 45-60 minutes, and be meaningfully better at both building production ASP.NET Core APIs and answering interview questions about this topic than before they read it.

Generate the complete note for **{{TOPIC_ID}} — {{TOPIC_NAME}}** now.

---

## END OF PROMPT

---

---

## QUICK REFERENCE — What Each Part Does

| Part | Name | Purpose | ASP.NET Core-specific requirement |
|---|---|---|---|
| 0 | Navigation | Orientation, prerequisites, context | Show full ASP.NET Core domain hierarchy and subsystem |
| 1 | Core Mental Model | One sentence + analogy + taxonomy | Analogy must map to HTTP pipeline / framework behavior |
| 2 | Deep Mechanics | Runtime behavior, pipeline internals, framework source | **Pipeline position + HTTP wire format required in every block** |
| 3 | Production Code | 5-7 annotated real-world patterns | HTTP consequence shown after every handler or middleware |
| 4 | Gotchas | 5 production bugs with wrong→right→why | Include HTTP consequence (wrong path and correct path) |
| 5 | Performance | Pipeline table + benchmark + when to care | Allocation count + latency impact metrics |
| 6 | Interview Arsenal | Full questions + great answers + tricks + red flags | Great Answers reference pipeline position or HTTP behavior |
| 7 | Decision Framework | Flowchart for when to use what | Must answer "what pipeline component?" or "which auth scheme?" |
| 8 | Self-Check | 8-10 questions + 4-5 code puzzles | Puzzles ask "what status code?" and "which middleware runs?" |
| 9 | Connections | Wiki links + books + articles + meta-note | Cross-link ASP.NET Core (4.XX), EF Core (3.XX), and C# (2.XX) |

---

## TIPS FOR BEST RESULTS

**If Part 2 pipeline diagrams feel vague:** Add to the prompt: _"Every pipeline diagram in Part 2 must show the complete middleware chain from left to right. Label every middleware that runs before the component, every middleware that runs after, and mark which ones can short-circuit. Use ASCII art — Mermaid is too limiting for pipeline flows."_

**If Part 6 interview answers mention features without HTTP or pipeline behavior:** Add: _"Every Great Answer must include at least one sentence that explicitly states what the HTTP client observes — status code, response headers, or response body shape. Answers that only discuss C# API surface without mentioning the HTTP layer are insufficient."_

**If the code examples feel generic (no domain):** Add: _"Every code example must be from one of these domains: fintech payment API, e-commerce order service, healthcare patient portal, or logistics shipment tracker. Class names, method names, and route paths must reflect the business concept. No generic names."_

**If Part 4 gotchas are too basic:** Add: _"Every gotcha must be a bug that a developer with 2+ years of ASP.NET Core experience would still make. Show the HTTP response that the anti-pattern produces — the wrong status code, the missing header, or the silent auth bypass is what makes it a gotcha, not just a style issue."_

**If the note reads like documentation rather than study material:** Add: _"The tone must be that of a senior engineer who has debugged this in production — direct, occasionally blunt about what the framework is hiding from you, and specific about failure modes at scale (10k req/s, multi-tenant APIs, containerized deployments). Do not write marketing copy for ASP.NET Core."_

**If middleware ordering and short-circuit behavior are missing:** Add: _"For every middleware or filter in Part 2 and Part 3, include an ASCII pipeline diagram showing its exact position in the canonical middleware order. Show which middleware it depends on being registered before it (e.g., UseRouting must come before UseAuthentication must come before UseAuthorization). Show what happens when the order is wrong."_

**If DI scope behavior is not addressed:** Add: _"For every component that participates in DI (middleware, filters, services), explicitly state its expected lifetime (Singleton / Scoped / Transient) and flag any captive dependency risks. Show what IServiceScopeFactory is needed for and when constructor injection is incorrect."_
