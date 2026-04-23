# Pull Requests

> A pull request is a formal request to merge a branch into another, used as the checkpoint for code review, discussion, and CI validation before integration.

---

## When To Use It

Any time code moves from a feature branch into a shared branch (main, develop, release), it should go through a PR. Skip PRs only on solo projects or trivial solo commits directly to non-protected branches. PRs matter most when multiple engineers touch the same codebase — they're the primary mechanism for catching bugs before they hit shared state, not after.

---

## Core Concept

A PR is not just a merge mechanism — it's an asynchronous communication tool. You're telling your team: here's what I changed, here's why, here's what to look at. The code diff is evidence; the PR description is the argument. Good PRs are small enough to review in one sitting (under 400 lines of meaningful diff as a rough guide), have a single clear purpose, and give reviewers enough context to evaluate correctness without opening Slack. A PR that takes two days to review isn't a review problem — it's a PR size problem.

---

## The Code
```bash
# ── Opening a clean PR ───────────────────────────────────────────────

# 1. Rebase onto latest main before pushing — reviewers see clean diff
git fetch origin
git rebase origin/main

# 2. Push branch
git push origin feat/add-refresh-token

# 3. Open PR via GitHub CLI (or UI)
gh pr create \
  --title "feat: add refresh token rotation" \
  --body "$(cat .github/pull_request_template.md)" \
  --reviewer alice,bob \
  --label "backend"
```
```bash
# ── Reviewing a PR locally ───────────────────────────────────────────

# Check out the PR branch to test it, not just read the diff
gh pr checkout 142

# Run tests, poke around, then go back
git checkout main
```
```bash
# ── Updating a PR after review feedback ─────────────────────────────

# Make changes, then amend or add commits
git add src/Auth/TokenService.cs
git commit --amend --no-edit   # if it's a fixup on the last commit

# OR keep a separate fixup commit — squash before merge
git commit -m "fixup: handle token expiry edge case"

git push origin feat/add-refresh-token --force-with-lease
# --force-with-lease is safer than --force: fails if someone else pushed
```
```markdown
<!-- .github/pull_request_template.md — put this in your repo -->

## What
Brief description of the change.

## Why
Context: what problem does this solve, what ticket/issue is this tied to?

## How
Any non-obvious implementation decisions worth explaining.

## Test Plan
How was this tested? What scenarios were covered?

## Checklist
- [ ] Tests added/updated
- [ ] No debug code left in
- [ ] Migrations are backwards-compatible
```

---

## Gotchas

- **`--force` on a shared branch destroys teammates' local history.** Always use `--force-with-lease` when rebasing a PR branch — it refuses to push if the remote has commits you haven't seen.
- **Draft PRs don't block CI by default on all platforms.** Some teams open draft PRs for early feedback and forget that required status checks may not run until it's marked ready — check your branch protection rules.
- **A PR that fixes the bug AND refactors the module is two PRs.** Mixing concerns makes review harder and makes reverting one change impossible without losing the other.
- **Approval doesn't mean the reviewer ran the code.** Code review is mostly static analysis by human. Critical paths still need actual test coverage — approval is not a test.
- **Stale PR branches that sit open accumulate silent conflicts.** A branch open for two weeks might pass CI but conflict semantically with merged work in ways that compile cleanly and fail at runtime.

---

## Interview Angle

**What they're really testing:** Whether you treat code review as a quality gate and communication tool, or just a bureaucratic step before merging.

**Common question form:** "How do you handle code review on your team?" or "What makes a good pull request?"

**The depth signal:** A junior talks about adding reviewers and waiting for approval. A senior talks about PR size as the primary lever for review quality, using PR descriptions to front-load context so reviewers don't need a Slack thread to understand intent, and the distinction between blocking comments (must fix) vs. non-blocking suggestions (nice to have) — and why that distinction matters for keeping velocity without skipping quality.

---

## Related Topics

- [[git/git-code-review.md]] — PRs are the container; code review is what happens inside them — different skills, different mindset.
- [[git/git-workflows.md]] — The workflow determines when PRs are opened, to which branches, and with what merge strategy (squash vs merge commit vs rebase).
- [[git/git-merge-conflicts.md]] — Long-lived PR branches are the primary source of merge conflicts; resolving them correctly is part of the PR lifecycle.
- [[git/git-branching-strategy.md]] — Branch naming, lifetime, and purpose are defined by strategy; PRs enforce those conventions at merge time.

---

## Source

[GitHub Docs — About Pull Requests](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests)

---
*Last updated: 2026-03-24*