# Domain 7 — System Design & Distributed Systems

## Note Generation Prompt

**Purpose:** Generation spec for all Domain 7 notes. Read this file first, then produce the complete note directly. No narration. No reasoning overhead.

---

## Domain Identity

- **Domain Number:** 7
- **Domain Name:** System Design & Distributed Systems
- **Scope:** Architecture patterns (Clean Architecture, DDD, CQRS, Event Sourcing), distributed systems theory, scalability, caching, messaging, microservices, resilience, API design, networking, storage, observability, Azure, Kubernetes, CI/CD, NoSQL, security architecture, performance, and classic system design problems
- **Audience:** Senior and staff-level interview preparation; production .NET engineering reference
- **Quality Bar:** Every note must be immediately usable in a system design interview. Every claim about tradeoffs must be precise and defensible. No hand-waving. Production-realistic .NET examples throughout.

---

## File Naming Convention

```
7_XXX_Topic_Name_With_Underscores.md
7_1000_Bloom_Filters.md
7_1146_Design_URL_Shortener_Requirements.md
```

---

## YAML Frontmatter

```yaml
---
id: "7.XXX"
title: "Topic Name"
domain: "System Design & Distributed Systems"
domain_id: 7
group: "Group Name"
tags: [system-design, distributed-systems, dotnet, azure]
priority: X
prerequisites:
  - "[[7.XXX — Topic Name]]"
related:
  - "[[7.XXX — Topic Name]]"
  - "[[6.XXX — Topic Name]]"
created: YYYY-MM-DD
---
```

**Valid group values:** `Clean Architecture` | `Domain-Driven Design` | `CQRS and Event Sourcing` | `Integration Patterns` | `Distributed Systems Theory` | `Scalability Patterns` | `Caching` | `Message Brokers` | `Microservices` | `Resilience Patterns` | `API Design` | `Networking` | `Storage Systems` | `Stream Processing` | `Search Systems` | `Reliability and SLO` | `Deployment Strategies` | `Observability` | `Azure Architecture` | `Containerization` | `Kubernetes` | `CI/CD` | `NoSQL Systems` | `Distributed Algorithms` | `Real-Time Systems` | `Performance` | `Security Architecture` | `System Design Problems` | `Interview Process`

---

## Note Structure — 9 Mandatory Sections

---

### Section 1 — Navigation & Context

```markdown
## Navigation

**Domain:** [[7 — System Design & Distributed Systems]] > **Group:** [Group Name]
**Previous:** [[7.XXX — Topic]] | **Next:** [[7.XXX — Topic]]

### Prerequisites
- [[7.XXX — Topic]] — why required (one sentence)
- [[6.XXX — Pattern]] — if a design pattern underpins this concept

### Where This Fits
2–4 sentences. What architectural problem does this solve? At what scale does it become necessary? Where in a .NET production system does an engineer encounter it? What goes wrong without it?
```

---

### Section 2 — Core Mental Model

````markdown
## Core Mental Model

One precise paragraph. The engineering definition — not the textbook one. What is the single invariant this concept maintains? What does it trade to maintain it? What is the recognition trigger — the symptom in a system that says "apply this here"?

### Classification

**For architectural patterns:** where it sits in the layering hierarchy, which problems it is scoped to solve, what it explicitly does not solve.
**For distributed systems concepts:** which consistency/availability/latency axis it occupies, what class of failure it prevents.
**For infrastructure topics (K8s, Docker, CI/CD):** what abstraction layer it operates at and what it hides from the layer above.
**For system design problems:** the problem class, the scale trigger, the core architectural tension.

[REQUIRED Mermaid diagram]

For **architecture patterns**: component diagram showing the layers, dependencies, and data flow direction.
For **distributed systems**: sequence diagram or state machine showing the protocol or failure scenario.
For **system design problems**: high-level architecture diagram showing major components and their interactions.
For **infrastructure**: resource relationship diagram (pod → deployment → service → ingress, etc.)

```mermaid
[diagram here — valid syntax required]
````

### Key Properties / Guarantees

|Property|Value|Condition|
|---|---|---|
|[What it guarantees]|[The guarantee]|[When/under what conditions]|
|[What it sacrifices]|[The cost]|[When the cost is paid]|

````

---

### Section 3 — Deep Mechanics

```markdown
## Deep Mechanics

### How It Works

Step-by-step. For architectural patterns: trace a request or event from entry to exit through all components, naming what each does. For distributed concepts: walk the protocol — what each node sends, what it waits for, what it does on success and failure. For infrastructure: explain what the control loop does, how reconciliation works, what the scheduler/controller decides. For system design problems: walk the read path and write path separately.

### Failure Modes

What breaks and how. Every topic in this domain has at least one non-obvious failure mode that trips engineers who only know the happy path. Name it. Show what the system does. Show how to detect it (what metric or log entry reveals it). Show how to recover or prevent it.

### .NET and Azure Integration

Where this concept appears in the .NET ecosystem or Azure platform:
- **ASP.NET Core:** which middleware, filter, or service embodies this
- **EF Core:** where this pattern applies to data access
- **Azure services:** which Azure service implements or requires this
- **.NET libraries:** Polly, MediatR, MassTransit, Refit, FluentValidation — which is relevant
- **Configuration:** how to wire this in Program.cs or appsettings.json

```csharp
// Production-realistic .NET code showing the integration point
// Use realistic domain names — OrderService, PaymentGateway, not Foo/Bar
````

````

---

### Section 4 — Production Patterns and Implementation

```markdown
## Production Patterns and Implementation

### Primary Implementation

The complete, idiomatic .NET implementation of this concept. Requirements:
- Realistic domain names — OrderProcessor, PaymentGateway, InventoryService, ReportBuilder — never Foo/Bar/Widget as the primary example
- Modern C# — records, pattern matching, primary constructors where appropriate
- XML doc comments on public members
- Async where I/O is involved — always `CancellationToken` parameter
- Wire-up code showing registration in `IServiceCollection`

```csharp
// Implementation here
// Label each architectural role with a comment: // Port | // Adapter | // Use Case | etc.
````

### Configuration and Wiring

```csharp
// Program.cs / Startup.cs registration
builder.Services.AddXxx<Implementation>(options =>
{
    // configuration
});
```

### Common Variants

For topics with multiple implementation approaches (e.g., choreography vs orchestration sagas, cache-aside vs write-through), show the decision-driving difference in code — not just prose. A 10-line snippet per variant is enough.

### Real-World .NET Ecosystem Example

Name the production library or framework that uses this pattern and show how it surfaces:

- MediatR pipeline behaviors = Chain of Responsibility + Decorator
- ASP.NET Core middleware = Chain of Responsibility
- Polly ResiliencePipeline = Decorator + Strategy
- EF Core interceptors = Interceptor pattern
- Azure SDK retry = Polly under the hood

````

---

### Section 5 — Gotchas and Production Pitfalls

```markdown
## Gotchas and Production Pitfalls

Format: **Pitfall** → **Symptom** → **Fix** → **Cost of not fixing**

Minimum 4. Maximum 8. Every entry must be real — something that has burned production systems. Not "make sure to validate inputs." Specific failure modes, specific .NET traps, specific Azure behavior surprises.

### [Pitfall Name]

**Pitfall:** What the engineer does wrong. One sentence.

```csharp
// ❌ The wrong code or configuration
````

**Symptom:** What breaks in production. The metric that spikes. The error that appears in logs. The customer complaint that arrives.

**Fix:** The correct approach.

```csharp
// ✅ The fix
```

**Cost of not fixing:** What happens at 3 AM when this is in production at scale. Be specific — "memory leak leading to pod restart every 4 hours" not "performance issues."

````

---

### Section 6 — Tradeoffs and Decision Framework

```markdown
## Tradeoffs and Decision Framework

### Tradeoff Matrix

| Dimension | This Approach | Alternative A | Alternative B |
|---|---|---|---|
| Consistency | | | |
| Availability | | | |
| Latency | | | |
| Operational complexity | | | |
| Team expertise required | | | |
| .NET ecosystem fit | | | |

### When to Apply

```mermaid
flowchart TD
    A[Trigger: describe the problem symptom] --> B{Scale question}
    B -->|Single service, low scale| C[Simpler alternative]
    B -->|Multiple services or high scale| D{Consistency requirement}
    D -->|Strong consistency required| E[This approach]
    D -->|Eventual is acceptable| F[Alternative approach]
    E --> G[Expected architectural outcome]
````

### When NOT to Apply

Explicit list of conditions under which this pattern or concept is wrong, over-engineered, or harmful. The "don't reach for this unless..." statement. Most engineers only know when to use a pattern — the senior engineer also knows when not to.

- [ ] Condition that rules it out
- [ ] Scale threshold below which it's overkill
- [ ] Organizational prerequisite that isn't met

### Scale Thresholds

At what QPS, data volume, team size, or service count does this become necessary? Give real numbers:

- "Worth considering above ~1,000 req/s per service"
- "Required when more than 3 services share a database"
- "Justified when replication lag exceeds your SLO"

````

---

### Section 7 — Interview Arsenal

```markdown
## Interview Arsenal

### Question Bank

6–8 questions, foundational → advanced:

1. [Definition — what it is and what problem it solves]
2. [Mechanism — how it works internally]
3. [Tradeoff — what you give up to get it]
4. [Failure mode — what breaks and how you detect it]
5. [Comparison — this vs the most commonly confused alternative]
6. [Design application — "design a system that uses this"]
7. [Scale — "how does this behave at 10x the load?"]
8. [Advanced — the non-obvious property that only practitioners know]

### Spoken Answers

Full spoken-narrative for questions 1, 5, and the most advanced question. Two tiers:

**Q: [Question]**

> **Average answer:** What most candidates say. Correct but surface-level. Missing the production implication or the .NET-specific context.

> **Great answer:** What a senior candidate says. Derives the tradeoff from first principles. Names a concrete .NET/Azure example. Addresses the failure mode before being asked. Uses precise vocabulary — not "it makes things faster" but "it reduces P99 latency by eliminating synchronous dependency on the downstream service during peak load."

### System Design Interview Trigger

One paragraph. If this concept appears in a system design interview, what prompt does it answer? Which classic design problem requires it? What is the interviewer testing when they probe this area?

Example: "If an interviewer asks you to design a payment system and then asks 'how do you handle the case where the payment succeeds but the notification fails?', they are testing whether you know the outbox pattern and idempotency."

### Comparison Table

| | [This] | [Most Confused With] |
|---|---|---|
| Core guarantee | | |
| Trade-off | | |
| .NET implementation | | |
| Failure mode | | |
| When to choose | | |
````

---

### Section 8 — Architecture Decision Record Template

```markdown
## Architecture Decision Record

*When generating this note, fill this ADR with the real decision context for this topic.*

**Status:** Accepted / Superseded by [ID] / Under Review

**Context:**
[The specific engineering situation in which this decision arises. What is the system doing? What constraint or requirement is driving the need to choose?]

**Options Considered:**

1. **[This approach]** — [one sentence on what it does]
2. **[Alternative A]** — [one sentence]
3. **[Alternative B]** — [one sentence]

**Decision:** [This approach], because [the specific engineering reason — not "it's better" but the concrete property that makes it fit].

**Consequences:**
- ✅ [What you gain]
- ✅ [What you gain]
- ⚠️ [What you now must manage]
- ❌ [What you give up]

**Review Trigger:** Revisit this decision if [the specific condition that would make the alternative more attractive — a scale threshold, a team change, a product requirement shift].
```

---

### Section 9 — Self-Check

````markdown
## Self-Check

### Conceptual Questions

1. [Tests: definition without looking it up]
2. [Tests: deriving the tradeoff from first principles]
3. [Tests: identifying when this applies vs when it does not]
4. [Tests: naming the failure mode and its detection]
5. [Tests: .NET/Azure-specific implementation detail]
6. [Tests: comparison with the most commonly confused alternative]
7. [Tests: the scale threshold — below which it's overkill]
8. [Tests: connection to another Domain 7 topic]
9. [Tests: the non-obvious production consequence]
10. [Tests: interview articulation — can you explain this in 60 seconds to a non-expert?]

<details>
<summary>Answers</summary>

1. [Answer]
2. [Answer — with derivation, not just the conclusion]
3. [Answer with specific counter-example]
4. [Answer naming the specific log entry or metric]
5. [Answer naming the specific .NET class or Azure feature]
6. [Answer with the structural distinction]
7. [Answer with real numbers]
8. [Answer with wiki-link to the related note]
9. [Answer]
10. [Answer as a 60-second spoken narrative]

</details>

---

### Scenario Challenges

**Scenario 1 — Diagnose the problem**
[A production system description with a specific symptom. 3–5 sentences. The symptom points to this concept being missing or misapplied.]

<details>
<summary>Diagnosis</summary>

**Root cause:** [What is missing or wrong]
**Evidence:** [Which metric or log entry reveals it]
**Fix:** [Architectural change required]
**Prevention:** [What to add to avoid this class of problem in future systems]

</details>

---

**Scenario 2 — Design decision**
You are designing [a specific system] and need to decide [specific decision this topic addresses]. The system has [specific constraints — scale, team size, consistency requirement]. What do you choose and why?

<details>
<summary>Decision and Reasoning</summary>

**Choice:** [This approach / alternative — with justification tied to the constraints]
**Tradeoffs accepted:** [What you are giving up and why that's acceptable here]
**Implementation sketch:**

```csharp
// Key code or configuration showing the decision in practice
````

</details>

---

**Scenario 3 — Failure mode** Your [system type] is exhibiting [specific symptom]. The on-call engineer suspects [this concept] is involved. Walk through the investigation and remediation.

<details> <summary>Investigation and Fix</summary>

**Investigation steps:** [What to check first, second, third] **Confirming evidence:** [The specific log line or metric that confirms the hypothesis] **Immediate mitigation:** [What to do right now to stop the bleeding] **Permanent fix:** [The architectural change] **Post-mortem item:** [What goes in the ADR to prevent recurrence]

</details>

---

**Scenario 4 — Scale it** Your system currently handles [X] requests per second with [current architecture]. You need to handle [10X] within [time constraint]. How does [this concept] fit into the scaling strategy?

<details> <summary>Scaling Strategy</summary>

**Bottleneck this addresses:** [What breaks at 10X without this] **How it helps:** [The specific mechanism] **What it does not solve:** [The other bottleneck that remains] **Implementation order:** [What to do first, what can wait]

</details>

---

**Scenario 5 — Interview simulation** The interviewer says: "[System design prompt that naturally requires this concept]". Walk through your response, specifically handling the part that requires [this concept].

<details> <summary>Model Response</summary>

[Full spoken-narrative response, 150–250 words, at senior engineer level. Includes: clarifying question asked, scale estimation made, architectural decision explained with tradeoff named, failure mode addressed proactively.]

</details> ```

---

## Domain-Specific Generation Rules

### Rule 1 — Tradeoffs Are Named, Not Implied

Every design decision in this domain has a cost. Never write "use X because it's better." Write "use X because it gives you Y, at the cost of Z, which is acceptable when [condition]." If the cost cannot be named, the understanding is shallow.

### Rule 2 — Scale Numbers Are Concrete

"High traffic" and "large scale" are meaningless. Every note that involves scale must use real numbers: QPS, data volume in GB/TB, number of services, replication lag in milliseconds, P99 latency in ms. Estimate when exact numbers are unknown, but estimate specifically: "~10,000 req/s" not "high load."

### Rule 3 — .NET Integration Is Mandatory

Every note must include a complete, runnable code example using idiomatic .NET — not pseudocode, not Python-translated-to-C#. The example must use modern C# features and show `IServiceCollection` registration where applicable. Realistic domain names always.

### Rule 4 — Failure Modes Are the Primary Teaching

For every concept in this domain, the failure mode is as important as the happy path. Section 5 must show failures that have actually happened in production systems. The test: would a senior engineer reading this say "yes, I've seen that"?

### Rule 5 — ADR Format Is Required

Every note must contain a filled-in Architecture Decision Record (Section 8). This is what separates a reference note from an engineering artifact. The ADR must have real consequences and a specific review trigger — not generic statements.

### Rule 6 — System Design Problems Get Full Architecture

Notes in Group AF (System Design Problems) are structured differently from concept notes. They must include:

- A complete high-level architecture diagram (Mermaid)
- Separate read path and write path walkthroughs
- Scale estimation (QPS, storage, bandwidth) with numbers
- At least 3 component deep dives (database choice, caching strategy, consistency model)
- Failure scenarios and how the design handles them
- What an interviewer is testing with this problem

### Rule 7 — Cross-References Are Structural

Every note links to at least 3 other Domain 7 notes plus at least 1 cross-domain link. Cross-references must explain the relationship in one sentence — not just the link. "[[7.229 — Consistent Hashing]] — required because this system uses consistent hashing to distribute cache keys across nodes" not just "[[7.229]]."

### Rule 8 — Azure Is the Primary Cloud

Since this is a .NET domain, Azure is the default cloud platform. When a cloud service is relevant, use the Azure equivalent first, with AWS in parentheses where helpful for breadth: "Azure Service Bus (analogous to AWS SQS + SNS)."

### Rule 9 — Interview Arsenal Speaks in Spoken English

The spoken answers in Section 7 must read like someone actually talking — not bullet points, not academic prose. They should be deliverable verbatim at a whiteboard. Start with the definition, move to the mechanism, name the tradeoff, give the .NET example, address the edge case.

### Rule 10 — Consistency Models Are Always Addressed

Any note about a distributed data system (cache, database, message broker, event store) must include a subsection on what consistency model it uses, what anomalies are possible, and what the .NET client code must account for.

---

## Group-Specific Addenda

### For Group AF — System Design Problems

Every system design problem note follows this extended structure replacing Sections 4–6:

**Section 4:** Requirements and Scale Estimation

- Functional requirements (what the system does)
- Non-functional requirements (latency, availability, consistency SLOs)
- Scale estimation: DAU → QPS → storage → bandwidth (with numbers)

**Section 5:** High-Level Architecture

- Component diagram (Mermaid)
- Component list with one-sentence role per component
- Key architectural decisions made and why

**Section 6:** Deep Dives (pick the 3 most interesting components)

- Database choice and schema sketch
- Caching layer and invalidation strategy
- Consistency model and how it's enforced

**Section 7:** Failure Scenarios

- What happens when [critical component] fails
- How the system degrades gracefully
- What the on-call engineer does

**Section 8:** Interview Guide for This Problem

- What the interviewer is testing
- Common mistakes candidates make
- The non-obvious follow-up question and its answer

---

## Priority Tier Reference

|Tier|Label|Interview frequency|
|---|---|---|
|1|Critical|Will appear; must be fluent|
|2|High|Likely in senior rounds|
|3|Medium|Deep-dive or specialized|
|4|Reference|Completeness only|

---

## Pre-Save Checklist

- [ ] YAML frontmatter complete — id, group, priority, prerequisites, related
- [ ] All 9 sections present (or AF-variant for system design problems)
- [ ] Mermaid diagram in Section 2 — valid syntax
- [ ] Mermaid decision flowchart in Section 6
- [ ] Section 3 includes failure modes
- [ ] Section 3 includes .NET/Azure integration with code
- [ ] Section 4 has complete runnable .NET implementation
- [ ] Section 4 shows IServiceCollection registration
- [ ] Section 5 has minimum 4 pitfalls in Pitfall → Symptom → Fix → Cost format
- [ ] Section 6 has tradeoff matrix with at least 2 alternatives
- [ ] Section 7 has spoken answers at two tiers for 3+ questions
- [ ] Section 7 has interview trigger paragraph
- [ ] Section 8 ADR is fully populated — not left as template
- [ ] Section 9 has 10 conceptual questions + 5 scenarios with collapsed answers
- [ ] Minimum 3 Domain 7 wiki-links + 1 cross-domain link
- [ ] No `foo`, `bar`, `baz` in domain examples
- [ ] Scale numbers are specific, not vague
- [ ] File saved as `7_XXX_Topic_Name.md`