# Domain 9 — Production Engineering

## Note Generation Prompt

**Purpose:** Generation spec for all Domain 9 notes. Read this file first, then produce the complete note directly. No narration. No reasoning overhead.

---

## Domain Identity

- **Domain Number:** 9
- **Domain Name:** Production Engineering
- **Scope:** Hands-on engineering practice — Git and GitHub workflows, developer tooling, terminal/shell fluency, Docker authoring and debugging, Kubernetes day-2 operations, Helm, CI/CD pipeline authoring, observability implementation, Azure CLI and resource provisioning, Infrastructure as Code authoring (Bicep/Terraform), production debugging, performance tuning, incident response, scripting and automation
- **Explicit Non-Scope:** Architectural concepts (what a service mesh is, what consistency models mean, when to choose microservices) belong to **Domain 7 — System Design & Distributed Systems**. Domain 9 never re-teaches "what is Kubernetes" — it teaches "how do you write this manifest, debug this pod, and fix this pipeline." If a note finds itself explaining a concept rather than a procedure, it is in the wrong domain.
- **Audience:** Engineers who need to actually operate systems — write the Dockerfile, run the kubectl command, fix the broken pipeline, resolve the merge conflict — not just discuss them in an interview.
- **Quality Bar:** Every command must be copy-pasteable and correct. Every walkthrough must reflect a real terminal session, not a sanitized abstraction. Every troubleshooting scenario must include the actual error message as it appears on screen.

---

## File Naming Convention

```
9_XXX_Topic_Name_With_Underscores.md
9_001_Git_Init_Clone_and_Remote_Basics.md
9_146_Writing_a_Multi_Stage_Dockerfile.md
```

---

## YAML Frontmatter

```yaml
---
id: "9.XXX"
title: "Topic Name"
domain: "Production Engineering"
domain_id: 9
group: "Group Name"
tags: [production-engineering, devops, dotnet, hands-on]
priority: X
prerequisites:
  - "[[9.XXX — Topic Name]]"
related:
  - "[[9.XXX — Topic Name]]"
  - "[[7.XXX — Architectural Concept]]"
created: YYYY-MM-DD
---
```

**Valid group values:** `Git Fundamentals` | `Git Advanced` | `GitHub Workflow` | `Terminal and Shell` | `IDE and Editor` | `Docker Hands-On` | `Docker Compose` | `Kubernetes Hands-On` | `Helm` | `CI/CD GitHub Actions` | `CI/CD Azure DevOps` | `Observability Implementation` | `Dashboards and Alerting` | `Azure CLI and Provisioning` | `IaC Bicep` | `IaC Terraform` | `Production Debugging` | `Performance Tuning Hands-On` | `Incident Response Drills` | `Scripting and Automation` | `Package Management` | `Environment and Secrets`

---

## Note Structure — 9 Mandatory Sections

This domain's structure differs from conceptual domains. Every section is built around **doing**, not **knowing**.

---

### Section 1 — Navigation & Context

```markdown
## Navigation

**Domain:** [[9 — Production Engineering]] > **Group:** [Group Name]
**Previous:** [[9.XXX — Topic]] | **Next:** [[9.XXX — Topic]]

### Prerequisites
- [[9.XXX — Topic]] — what hands-on skill is assumed
- [[7.XXX — Concept]] — if architectural understanding is assumed (link out, don't re-explain)

### Where This Fits
2–3 sentences. What task does an engineer sit down to do that requires this? What does the day-to-day moment look like — "you just got paged," "you're setting up a new repo," "your pipeline just turned red"? This is not a conceptual framing — it's a concrete trigger moment.
```

---

### Section 2 — What You're Doing and Why

```markdown
## What You're Doing and Why

One precise paragraph. Skip the textbook definition — say what action this enables and why it's the right tool for that action. If a concept must be explained to make the command meaningful, explain it in one sentence and link to the Domain 7 note for depth — never re-derive architecture here.

### Mental Model

A short, concrete analogy or operational model — not a class diagram. For Git: think of it as snapshots and pointers. For Kubernetes: think of it as a loop that keeps pushing reality toward the spec. For CI/CD: think of it as a vending machine — same input, same output, every time.

[OPTIONAL Mermaid diagram — only if a flow or state transition genuinely clarifies a multi-step process. Skip the diagram requirement that conceptual domains have; this domain prioritizes terminal output over diagrams.]

### Command / Tool Quick Reference

| Command / Action | What It Does | When You Reach for It |
|---|---|---|
| `command --flag` | [one line] | [trigger] |
| `command --flag` | [one line] | [trigger] |
```

---

### Section 3 — Step-by-Step Walkthrough

````markdown
## Step-by-Step Walkthrough

### The Scenario

A specific, realistic situation. Name the repo (`InterVision`, `OrderService`, `PaymentGateway`), the branch, the error — not "a project." 2–3 sentences.

### Full Walkthrough

Show the actual terminal session — commands and realistic output together, in order, exactly as it would appear on screen.

```bash
$ git status
On branch feature/order-refunds
Your branch is up to date with 'origin/feature/order-refunds'.

Changes not staged for commit:
  modified:   src/OrderService/RefundHandler.cs

$ git add src/OrderService/RefundHandler.cs
$ git commit -m "fix: prevent double refund on concurrent requests"
[feature/order-refunds 4a3f9c2] fix: prevent double refund on concurrent requests
 1 file changed, 12 insertions(+), 3 deletions(-)
````

Every step gets a one-line comment explaining _why this step_, not _what the command does syntactically_ — the table above already covered syntax.

### What Could Go Wrong Mid-Walkthrough

If this procedure has a common branch point (e.g., "if you see a merge conflict here instead"), show that branch explicitly with its own mini-walkthrough.

````

---

### Section 4 — Production Scenario

```markdown
## Production Scenario

### Realistic Context

A complete, specific production situation using realistic .NET service names (`OrderService`, `PaymentGateway`, `InventoryApi`, `NotificationWorker`) — not toy examples. 3–5 sentences setting up: what system, what's broken or what's being built, what's at stake.

### Full Implementation / Resolution

```yaml
# or .bash / .dockerfile / .tf / .bicep — whatever format fits
# Complete, real, copy-pasteable. No "// rest of config here" placeholders.
````

```bash
# The commands run against this configuration, with realistic output
```

### Verifying It Worked

The specific command or check that confirms success — not "it should work now" but `kubectl get pods` showing `Running` status, or `curl` returning `200 OK` with a specific body, or the CI pipeline showing a green checkmark with a specific run URL pattern.

````

---

### Section 5 — Gotchas and Troubleshooting

```markdown
## Gotchas and Troubleshooting

Format: **Symptom (exact error text)** → **Root Cause** → **Fix** → **Prevention**

Minimum 4. Maximum 7. The symptom must be the *actual error message* a person would see — copy real Git/Docker/kubectl/Azure CLI error text, not a paraphrase.

### "[Exact error message or symptom]"

**Root cause:** What's actually happening underneath.

```bash
# The command or state that caused it
````

**Fix:**

```bash
# The exact resolution command(s)
```

**Prevention:** What habit, alias, or config setting avoids hitting this again.

````

---

### Section 6 — Speed and Efficiency

```markdown
## Speed and Efficiency

### Aliases and Shortcuts

```bash
# Git aliases, shell functions, kubectl aliases — things that save keystrokes daily
alias gco='git checkout'
alias k='kubectl'
````

### Automation Opportunity

Is there a script, a Makefile target, a VS Code task, or a pre-commit hook that turns this multi-step manual process into a one-liner? Show it.

```bash
#!/usr/bin/env bash
# scripts/deploy-local.sh — what it automates and why it's worth having
```

### Keyboard / CLI Efficiency Notes

For IDE and terminal topics specifically: the 3–5 keybindings or CLI flags that separate someone who's fast at this from someone who isn't.

````

---

### Section 7 — Interview Arsenal

```markdown
## Interview Arsenal

### Question Bank

5–7 questions. This domain's interview questions skew toward "walk me through how you'd..." rather than "define X":

1. [Walk-through — "how would you do X step by step"]
2. [Troubleshooting — "this command fails with [error], what do you check"]
3. [Comparison — this tool/approach vs the alternative]
4. [Real incident — "tell me about a time this broke in production"]
5. [Efficiency — "how do you make this faster/safer"]
6. [Edge case — the non-obvious failure mode]

### Spoken Answers

Two tiers for questions 1, 2, and 4:

**Q: [Question]**

> **Average answer:** States the command without the reasoning — gets the syntax right but can't explain why this approach over another, or what they'd check if it failed.

> **Great answer:** Narrates the diagnostic process out loud — what they'd check first and why, names the specific log/output that confirms the hypothesis, mentions the prevention habit unprompted.

### War Story Prompt

One realistic incident narrative (3–4 sentences) that this skill would have prevented or resolved — written as something a candidate could adapt and tell as their own experience if they've lived through something similar.
````

---

### Section 8 — Decision Framework

```markdown
## Decision Framework

### When to Reach for This

A short checklist, not a flowchart (this domain favors checklists over architecture diagrams since the decision is usually "is this the right tool for this five-minute task," not "what's the system architecture"):

- [ ] [Trigger condition 1]
- [ ] [Trigger condition 2]
- [ ] [Trigger condition 3]

### When NOT To

- [ ] [Condition where a simpler tool/command is correct instead]
- [ ] [Condition where this is overkill for the task size]

### Tool Comparison

| | This Approach | Alternative |
|---|---|---|
| Speed | | |
| Safety/reversibility | | |
| When it's the right call | | |
```

---

### Section 9 — Self-Check

````markdown
## Self-Check

### Conceptual Questions

1. [Tests: can you state what this command/tool does without looking it up]
2. [Tests: can you predict the output of a specific command]
3. [Tests: do you know the flag/option that changes default behavior]
4. [Tests: can you diagnose a specific error message]
5. [Tests: do you know the safer/faster alternative]
6. [Tests: do you know what NOT to do here]
7. [Tests: connection to a related Domain 9 or Domain 7 topic]

<details>
<summary>Answers</summary>

1. [Answer]
2. [Answer — show the actual predicted output]
3. [Answer naming the exact flag]
4. [Answer with root cause]
5. [Answer]
6. [Answer]
7. [Answer with link]

</details>

---

### Hands-On Drills

**Drill 1 — Do it from a clean state**

[A specific task stated as an instruction: "Starting from a fresh clone of a repo with two unmerged feature branches, do X."]

<details>
<summary>Solution</summary>

```bash
# Exact command sequence with expected output at each step
````

</details>

---

**Drill 2 — Fix the broken thing**

```bash
# A realistic broken state — a failing command with its actual error output
```

<details> <summary>Solution</summary>

**Diagnosis:** [what's wrong]

```bash
# Fix commands
```

</details>

---

**Drill 3 — Under time pressure**

[A scenario with a constraint: "Production is down. You have to roll back in under 2 minutes. Walk through exactly what you type."]

<details> <summary>Solution</summary>

```bash
# The fastest correct sequence, with a one-line justification per command for why it's safe under pressure
```

</details> ```

---

## Domain-Specific Generation Rules

### Rule 1 — Commands Are Real, Not Illustrative

Every command block must be something that actually runs and produces the output shown. No `<your-command-here>` placeholders in the walkthrough sections (placeholders are fine only in the Quick Reference table). If a flag or option is shown, it must be a real flag for that real tool/version.

### Rule 2 — Errors Are Verbatim

Every "Gotchas" entry uses the actual error text a tool produces — `fatal: refusing to merge unrelated histories`, not "Git complains about unrelated history." Verbatim error text is what makes a note findable when someone is panic-searching at 2 AM.

### Rule 3 — No Re-Teaching Domain 7 Concepts

If a note is about to explain what a Kubernetes Service is, what CAP theorem means, or why microservices decompose by bounded context — stop. Link to the Domain 7 note instead: "see [[7.394 — Kubernetes Services]] for the concept; this note covers writing and debugging the manifest." Domain 9 assumes the reader either knows the concept or will look it up in Domain 7.

### Rule 4 — Every Walkthrough Uses Realistic .NET Service Names

`OrderService`, `PaymentGateway`, `InventoryApi`, `NotificationWorker`, `InterVision` — never `my-app`, `test-repo`, `foo-service`.

### Rule 5 — Speed and Efficiency Section Is Never Empty

Every note must contain at least one alias, script, or keybinding that a working engineer would actually adopt. If genuinely nothing applies, replace with a "Common Workflow Integration" subsection showing how this fits into a Makefile, npm script, or dotnet tool.

### Rule 6 — Troubleshooting Outranks Theory

The Gotchas section (Section 5) is weighted as heavily as the Walkthrough (Section 3). A note that's all happy-path and one throwaway gotcha has failed its purpose — this domain exists because production breaks in specific, recognizable ways.

### Rule 7 — Cross-Reference Domain 7 for Architecture, Domain 9 for Procedure

Required cross-references: at least 2 links within Domain 9 (related procedures) and at least 1 link to Domain 7 (the architectural concept this procedure implements). Example: a note on writing a Kubernetes HPA manifest links to [[7.890 — Kubernetes HPA]] for the concept and to [[9.XXX — kubectl apply and Dry-Run Workflows]] for the related procedure.

### Rule 8 — War Stories Are Plausible, Not Generic

The "War Story Prompt" in Section 7 must be specific enough to feel real — a specific symptom, a specific wrong assumption, a specific fix — not "we had a bug and fixed it."

### Rule 9 — Terminal Output Formatting

All terminal sessions use `$` for shell prompts and show realistic output including timestamps, hashes, and exit codes where relevant. PowerShell sessions use `PS>` . This signals to the reader which shell context applies.

---

## Group-Specific Notes

### Git Fundamentals / Git Advanced

Every note assumes a multi-branch, multi-contributor repo — never a single-branch toy example. Show `git log --oneline --graph` output to visualize history where relevant.

### Docker Hands-On / Docker Compose

Every Dockerfile example targets ASP.NET Core specifically — `mcr.microsoft.com/dotnet/aspnet` and `mcr.microsoft.com/dotnet/sdk` base images, not generic Linux examples.

### Kubernetes Hands-On / Helm

Every manifest example is a complete, valid YAML file for a realistic .NET service deployment — not a fragment. Show the full `kubectl` command and its real output format.

### CI/CD GitHub Actions / Azure DevOps

Every pipeline YAML is complete and would actually run — restore, build, test, publish, deploy stages all present, not abbreviated.

### Observability Implementation

Every note shows actual `Program.cs` wiring code, not just configuration concepts — this is the hands-on counterpart to Domain 7's observability architecture notes.

### Azure CLI and Provisioning / IaC Bicep / IaC Terraform

Every `az` command, every Bicep/Terraform file must be complete enough to actually provision the resource described.

---

## Priority Tier Reference

|Tier|Label|Why It Matters|
|---|---|---|
|1|Critical|Daily-use skill; absence is immediately visible to any team|
|2|High|Used weekly; expected of any mid-to-senior engineer|
|3|Medium|Used occasionally; matters during incidents or setup|
|4|Reference|Specialized or rarely needed; completeness only|

---

## Pre-Save Checklist

- [ ] YAML frontmatter complete
- [ ] All 9 sections present, fully populated
- [ ] Section 3 walkthrough shows real terminal output, not abstracted steps
- [ ] Section 4 uses a realistic .NET production scenario with real service names
- [ ] Section 5 has minimum 4 gotchas with verbatim error text
- [ ] Section 6 has at least one real alias/script/keybinding
- [ ] Section 7 has spoken answers for 3 questions + a war story prompt
- [ ] Section 9 has 7 conceptual questions + 3 hands-on drills with collapsed solutions
- [ ] At least 2 Domain 9 links + 1 Domain 7 conceptual link
- [ ] No placeholder commands in walkthroughs (`<your-command>`) outside the Quick Reference table
- [ ] No generic names (`my-app`, `foo-service`, `test-repo`)
- [ ] File saved as `9_XXX_Topic_Name.md`