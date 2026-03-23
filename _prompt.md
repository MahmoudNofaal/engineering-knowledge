You are helping me build my personal engineering knowledge base.
It lives in a GitHub repo called `engineering-knowledge/` with this folder structure:

    dotnet/          → C# / .NET Backend
    system-design/   → System Design
    devops/          → DevOps & Docker
    databases/       → Databases (SQL + NoSQL)
    git/             → Git & Version Control
    ai-engineering/  → AI Engineering
    algorithms/      → Algorithms & Data Structures
    code-examples/   → Runnable code by domain

Every topic follows a fixed 8-section template. Never deviate from it.
Never skip a section. Never add extra sections.

---

TEMPLATE (use exactly this structure, exactly this order):

# [Topic Name]

> [One sentence. What is this thing, in plain language.]

---

## When To Use It
[2–4 sentences. When does this concept matter? When should you NOT
use it? What problem does it solve?]

---

## Core Concept
[In my own words — not copied from docs. Written like I'm explaining
to myself 6 months ago. Short paragraph. If it needs more than that,
the concept isn't understood well enough yet.]

---

## The Code
[One or more minimal, runnable code blocks. Real code, not pseudocode.
Comments only on non-obvious lines. Each block has a clear label
showing what it demonstrates. Use the right language for the topic:
csharp for .NET, python for AI/Python topics, sql for database topics.]

---

## Gotchas
[3–5 bullet points. Things that trip people up. Edge cases.
What the official docs don't emphasize. Production mistakes.
No generic advice — only specific, concrete gotchas for this topic.]

---

## Interview Angle
**What they're really testing:** [The underlying concept behind the question]
**Common question form:** [How this topic usually appears in interviews]
**The depth signal:** [Concrete difference between a junior and senior
answer — specific, not generic. What exact knowledge separates them.]

---

## Related Topics
[2–4 links to other files in the repo. Format: [[folder/filename]] —
one line explaining why it's related. Only link to concepts that
genuinely connect — not just topics in the same domain.]

---

## Source
[One link only. Official docs or the single best resource for this topic.]

---
*Last updated: YYYY-MM-DD*

---

RULES:
- Write in plain, clear language. No marketing tone. No filler sentences.
- The Core Concept section must be in simple words — never copied from docs.
- The Code section must have real, runnable examples — not pseudocode.
- The Gotchas must be specific and concrete — not generic advice.
- The Interview Angle depth signal must clearly separate junior vs senior.
- Related Topics must use the format [[folder/filename]] so links work in GitHub.
- Output the file path as the first line before the content, like this:
  FILE: dotnet/topic-name.md
- Use kebab-case for the filename. Match the folder to the domain.
- Today's date goes in Last Updated.

---

TOPIC TO WRITE: [TOPIC NAME HERE]
DOMAIN: [dotnet / system-design / devops / databases / git / ai-engineering / algorithms]