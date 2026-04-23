# Code Review

> Code review is the practice of having one or more engineers read and evaluate a proposed change before it merges, with the goal of catching bugs, maintaining consistency, and spreading knowledge.

---

## When To Use It

Code review should be on every change that reaches a shared branch — no exceptions for "small" changes, because production incidents routinely trace back to one-line changes that skipped review. The intensity scales with risk: a CSS tweak and a database migration both get reviewed, but the migration gets more scrutiny and a different set of reviewers. The only context where you skip review is a true production emergency where every minute counts — and even then, you review after the fact.

---

## Core Concept

Code review has two jobs that people often conflate: catching defects and transferring knowledge. Defect-catching is reactive — you're looking at what's there. Knowledge transfer is proactive — you're making sure at least one other person understands what changed and why. Both matter. The thing most teams get wrong is treating review purely as a quality gate and ignoring the knowledge transfer side, which is why codebases develop "owner silos" where only one person understands a module. Review is also not a style debate — style is enforced by linters and formatters before code reaches a human reviewer.

---

## The Code
```bash
# ── Reviewer workflow: check out and run the code ────────────────────

# Don't just read the diff — pull the branch and run it
gh pr checkout 217

# Run tests before forming an opinion
dotnet test                    # .NET
pytest                         # Python
npm test                       # Node

# Check what actually changed (file-level summary first)
git diff main...HEAD --stat

# Then read the meaningful diff (ignore whitespace noise)
git diff main...HEAD -w
```
```bash
# ── Leaving actionable review comments ──────────────────────────────

# Prefix comments to signal intent clearly:
# [blocking]   — must fix before merge
# [nit]        — style/preference, non-blocking
# [question]   — genuinely unclear, not a change request
# [suggestion] — take it or leave it

# Example comment bodies:

# [blocking] This will throw a NullReferenceException if order.Customer
# is null, which is possible when order comes from the legacy importer.
# Add a null check or assert upstream that Customer is always set.

# [nit] Variable name `data` is too generic here — `customerInvoices`
# would make the loop below self-documenting.

# [question] Why is this using a raw HttpClient instead of the typed
# IOrderServiceClient that's already registered in DI? Oversight or
# intentional?
```
```csharp
// ── What to look for: a mental checklist ────────────────────────────

// 1. Correctness — does it actually do what the PR says?
// 2. Edge cases — null inputs, empty collections, concurrent access
// 3. Error handling — are exceptions caught at the right level?
// 4. Tests — do they test behavior, not implementation details?
// 5. Security — any SQL built from user input? Secrets in code?
// 6. Performance — N+1 queries, unbounded loops on large data sets
// 7. Consistency — does it follow patterns already established in this repo?

// NOT your job in review:
// - Reformatting code (that's the formatter's job)
// - Debating naming conventions not in the style guide
// - Requesting architectural changes that weren't scoped to this PR
```

---

## Gotchas

- **"LGTM" after two minutes means nobody actually reviewed it.** A meaningful review of 300 changed lines takes at least 15–20 minutes. If your team's reviews are consistently instant, they're rubber stamps.
- **Blocking on style when a linter exists is a trust tax on the author.** If ESLint, Prettier, or dotnet-format is configured, you don't leave style comments — you point them to the linter config and move on.
- **Asking for large architectural changes at review time is too late.** That conversation belongs in the design phase or in a spike PR. Reviewing a week of work and saying "we should rethink the whole approach" breaks trust and wastes time.
- **Reviewers get diffusion of responsibility with too many assigned.** Three required reviewers sounds thorough — it often means each one assumes the others looked carefully. One accountable reviewer beats three passive ones.
- **Comments without suggested fixes are harder to act on.** When you spot a problem, include a concrete suggestion if you can. "This could throw" is less useful than "This could throw — add `.FirstOrDefault()` and handle the null case."

---

## Interview Angle

**What they're really testing:** Whether you approach review as a collaborative quality practice or as a gatekeeping exercise, and whether you understand both sides of the review — giving and receiving.

**Common question form:** "How do you approach code review?" or "Tell me about a time you gave or received difficult feedback in a review."

**The depth signal:** A junior describes what they look for in the diff (bugs, style, tests). A senior also talks about the reviewer's responsibility for knowledge distribution, how to calibrate blocking vs. non-blocking feedback to avoid slowing velocity unnecessarily, and how review culture reflects team trust — specifically that a team where authors get defensive about feedback, or reviewers feel pressure to approve quickly, has a process problem not a people problem.

---

## Related Topics

- [[git/git-pull-requests.md]] — PRs are the mechanism that hosts the review; PR quality (size, description, context) directly determines review quality.
- [[git/git-branching-strategy.md]] — Branch strategy determines who reviews what and when — trunk-based teams review more frequently on smaller changesets than Gitflow teams.
- [[git/git-workflows.md]] — The workflow defines what "done" means for a PR; review is the human step inside that workflow.
- [[devops/ci-cd-pipelines.md]] — Automated checks (lint, test, security scan) should run before human review begins — reviewers shouldn't be finding things that tooling can catch.

---

## Source

[Google Engineering Practices — Code Review](https://google.github.io/eng-practices/review/)

---
*Last updated: 2026-03-24*