# Pull Requests

> A pull request is a formal request to merge a branch into another, used as the checkpoint for code review, discussion, and CI validation before integration.

---

## Quick Reference

| | |
|---|---|
| **What it is** | An asynchronous communication and quality gate wrapping a branch merge |
| **Use when** | Any code moving from a feature branch to a shared branch |
| **Avoid when** | Solo projects or trivial solo commits to non-protected branches |
| **Git version** | Not a Git feature — a GitHub/GitLab/Bitbucket platform feature (GitHub: 2008) |
| **Key location** | Hosted on the remote platform; locally managed via `gh pr` CLI or web UI |
| **Key commands** | `gh pr create`, `gh pr checkout`, `git push --force-with-lease`, `gh pr merge` |

---

## When To Use It

Any time code moves from a feature branch into a shared branch (main, develop, release), it should go through a PR. Skip PRs only on solo projects or trivial solo commits to non-protected branches. PRs matter most when multiple engineers touch the same codebase — they're the primary mechanism for catching bugs before they hit shared state, not after.

---

## Core Concept

A PR is not just a merge mechanism — it's an asynchronous communication tool. You're telling your team: here's what I changed, here's why, here's what to look at. The code diff is evidence; the PR description is the argument. Good PRs are small enough to review in one sitting (under 400 lines of meaningful diff as a rough guide), have a single clear purpose, and give reviewers enough context to evaluate correctness without opening Slack. A PR that takes two days to review isn't a review problem — it's a PR size problem.

---

## Version History

| Platform/Feature | When |
|---|---|
| GitHub Pull Requests | February 2008 — launched with GitHub |
| PR Templates (`.github/pull_request_template.md`) | 2016 |
| Draft Pull Requests | February 2019 |
| Required Reviewers via CODEOWNERS | 2017 |
| Merge Queue (GitHub) | 2023 — GA |
| Auto-merge | 2021 |
| PR Dependency / Stacked PRs (GitHub) | 2024 (beta) |

*Draft PRs (2019) are underused. Opening a PR as draft immediately triggers CI and makes work visible to teammates without signalling "ready for review." Use drafts whenever a PR will take more than one work session to complete — it prevents the "is this done?" Slack message.*

---

## Performance

| PR characteristic | Review time impact |
|---|---|
| < 200 lines changed | Same-day review typical |
| 200–400 lines | 1–2 day turnaround |
| 400–800 lines | Often split into sub-PRs |
| 800+ lines | Review quality degrades significantly |
| Mixed concerns (bug + refactor + feature) | Unpredictable — reviewers lose context |

**The 400-line guideline:** Google's internal research found that reviewers catch bugs at the same rate for PRs under 400 lines, then effectiveness drops sharply. It's not about line count specifically — it's about cognitive load. A reviewer can hold ~400 lines of changes in working memory and reason about their interactions. Beyond that, they're pattern-matching, not understanding.

**Benchmark notes:** PR cycle time (open → merge) is the key metric. Aim for < 24 hours on feature branches. PRs open for 3+ days typically mean: the branch has drifted too far from main, the PR is too large to review in one session, or there's a blocked dependency. All three are fixable — only the last requires waiting.

---

## The Code

**Opening a clean PR**
```bash
# 1. Rebase onto latest main before pushing — reviewers see clean diff
git fetch origin
git rebase origin/main

# 2. Push branch
git push origin feat/add-refresh-token

# 3. Open PR via GitHub CLI
gh pr create \
  --title "feat: add refresh token rotation" \
  --body "$(cat .github/pull_request_template.md)" \
  --reviewer alice,bob \
  --label "backend" \
  --draft                    # open as draft until ready for review

# 4. Mark ready when done
gh pr ready
```

**Reviewing a PR locally**
```bash
# Check out the PR branch to actually run and test it — not just read the diff
gh pr checkout 142

# Run the tests, start the app, poke around
dotnet test
dotnet run

# View all PR comments in the terminal
gh pr view 142 --comments

# Return to your branch when done
git switch -
```

**Updating a PR after review feedback**
```bash
# Make the changes requested in review
git add src/Auth/TokenService.cs
git commit -m "fixup: handle token expiry edge case per review"

# OR amend if it's a small fix to the last commit
git add src/Auth/TokenService.cs
git commit --amend --no-edit

# Push — force-with-lease is safe, --force is not
git push origin feat/add-refresh-token --force-with-lease
# --force-with-lease fails if someone else pushed to your branch since your last fetch
# Prevents accidentally overwriting a reviewer's suggested commit
```

**PR description template**
```markdown
<!-- .github/pull_request_template.md -->

## What
<!-- One paragraph. What does this change do? -->

## Why
<!-- Context: what problem does this solve? Link to issue/ticket. -->
Closes #

## How
<!-- Non-obvious implementation decisions worth explaining. -->
<!-- Skip if the code is self-documenting. -->

## Test Plan
<!-- How was this tested? What scenarios were manually verified? -->
- [ ] Unit tests added/updated
- [ ] Tested locally with [describe scenario]
- [ ] Edge case: [describe]

## Checklist
- [ ] No debug code or console.log left in
- [ ] Migrations are backwards-compatible
- [ ] Breaking API changes documented
- [ ] Performance impact considered for large datasets
```

**Draft PR workflow for long-running work**
```bash
# Day 1 — start work, open draft PR immediately for visibility
git switch -c feat/payment-webhook-handler
git commit -m "WIP: scaffold webhook endpoint"
git push origin feat/payment-webhook-handler
gh pr create --draft \
  --title "feat: add Stripe webhook handler" \
  --body "Working on the Stripe webhook integration. ETA: Thursday."

# Day 2–3 — continue committing, pushing; CI runs automatically
git commit -m "feat: verify webhook signature"
git push origin feat/payment-webhook-handler

# Day 3 — cleanup history, mark ready
git rebase -i HEAD~4   # squash WIP commits
git push --force-with-lease origin feat/payment-webhook-handler
gh pr ready            # now reviewers are notified
```

**Merge queue (GitHub)**
```bash
# In repos with high merge frequency, the merge queue prevents
# "the branch that passed CI but failed after merging" problem

# Configure in repo settings:
# Branch protection → Require merge queue

# Developers add their PR to the queue instead of merging directly
gh pr merge 142 --merge --auto   # queued for merge when approved + CI passes

# The merge queue:
# 1. Takes approved PRs in order
# 2. Merges each one onto a "virtual base" that includes queued-ahead PRs
# 3. Runs CI on the combined result
# 4. Merges to main only if CI passes
# → Eliminates the "merged a PR that broke the build" scenario
```

---

## Real World Example

A 20-person engineering team was averaging 4.2 days per PR cycle time. Code review was considered a bottleneck, but analysis showed only 18% of PRs were delayed because of slow reviewers — the other 82% were delayed because PRs were too large, descriptions were too thin, or the branch had drifted and reviewers were waiting for a rebase. They implemented a PR health check bot and saw cycle time drop to 1.1 days within a month.

```python
# .github/workflows/pr-health-check.yml (conceptual — uses GitHub API)
# Runs on PR open and update; posts a health report as a PR comment

import os
import subprocess
from github import Github

def check_pr_health(pr_number: int) -> dict:
    g = Github(os.environ["GITHUB_TOKEN"])
    repo = g.get_repo(os.environ["GITHUB_REPOSITORY"])
    pr = repo.get_pull(pr_number)

    issues = []
    suggestions = []

    # Check 1: PR size
    total_changes = pr.additions + pr.deletions
    if total_changes > 400:
        issues.append(f"⚠️ Large PR: {total_changes} lines changed (recommended: < 400)")
        suggestions.append("Consider splitting into smaller PRs by concern")

    # Check 2: Description completeness
    if len(pr.body or "") < 100:
        issues.append("⚠️ Thin description — reviewers may lack context")
        suggestions.append("Add 'What', 'Why', and 'Test Plan' sections")

    # Check 3: Branch staleness
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", "origin/main", pr.head.sha],
        capture_output=True
    )
    if result.returncode != 0:
        issues.append("⚠️ Branch is behind main — needs rebase")
        suggestions.append("Run: git fetch origin && git rebase origin/main")

    # Check 4: Mixed concerns (heuristic — many directories touched)
    files = [f.filename for f in pr.get_files()]
    top_dirs = set(f.split('/')[0] for f in files)
    if len(top_dirs) > 4:
        issues.append(f"⚠️ Changes span {len(top_dirs)} top-level directories")
        suggestions.append("Mixed concerns can slow review — one concern per PR")

    return {"issues": issues, "suggestions": suggestions, "healthy": len(issues) == 0}
```

*The key insight: cycle time is owned by the PR author, not the reviewer. The author controls size, description quality, and branch freshness — the three factors that account for 82% of review delays. Making those factors visible (via a bot comment) changes behavior faster than any process mandate.*

---

## Common Misconceptions

**"A PR review means someone verified the code is correct"**
Code review is primarily static analysis by humans — reviewers read the diff, reason about it, and leave comments. Most reviewers don't run the code locally for every PR. Approval means "I read this and didn't see obvious problems." It does not mean "I verified this works." That's what tests, CI, and staging environments are for.

**"Small PRs are harder to write than large ones"**
Large PRs are easier to write because you don't have to think about decomposition — you just keep adding code until the feature is done. Small PRs require more upfront planning: what's the minimum change that delivers value and is safely mergeable? This planning cost is real but pays back immediately in review velocity. A team average of 4 small PRs per week moves faster than 1 large PR with 4 days of review delay.

**"Draft PRs mean don't review yet"**
Draft PRs mean "not ready for formal review" — they don't mean "invisible." Teammates can still look at draft PRs, leave early comments, and spot architectural issues before too much code is written in the wrong direction. Opening a PR as draft on day 1 of a feature is better collaboration than a surprise large PR on day 5.

---

## Gotchas

- **`--force` on a PR branch destroys teammate-suggested commits.** If a reviewer pushed a suggested commit to your branch, `--force` silently deletes it. Always use `--force-with-lease` — it fails if the remote has commits you haven't fetched.

- **Draft PRs don't block CI by default on all platforms.** Some teams open draft PRs for early feedback and forget that required status checks may not run until it's marked ready — check your branch protection rules.

- **A PR that fixes the bug AND refactors the module is two PRs.** Mixing concerns makes review harder and makes reverting one change impossible without losing the other. The refactor and the fix have different risk profiles and different reviewers.

- **Stale PR branches that sit open accumulate silent semantic conflicts.** A branch open for two weeks might pass CI but conflict logically with merged work. Rebase onto main before requesting final review.

- **Auto-merge without merge queue can still produce broken main.** Auto-merge triggers when CI passes on the PR branch — not on the post-merge result. If two PRs both pass CI independently but conflict at runtime, both can merge and break main. The merge queue solves this.

---

## Interview Angle

**What they're really testing:** Whether you treat code review as a quality gate and communication tool, or just a bureaucratic step before merging.

**Common question forms:**
- "How do you handle code review on your team?"
- "What makes a good pull request?"
- "How do you reduce PR cycle time?"

**The depth signal:** A junior talks about adding reviewers and waiting for approval. A senior talks about PR size as the primary lever for review quality, using PR descriptions to front-load context so reviewers don't need a Slack thread to understand intent, the distinction between blocking and non-blocking comments, and owns cycle time as an author responsibility — not a reviewer responsibility. They know draft PRs, merge queues, and `--force-with-lease`.

**Follow-up questions to expect:**
- "How would you handle a situation where a PR has been in review for 5 days?"
- "What's the difference between auto-merge and a merge queue?"

---

## Related Topics

- [git-code-review.md](git-code-review.md) — PRs are the container; code review is what happens inside them.
- [git-workflows.md](git-workflows.md) — The workflow determines when PRs are opened, to which branches, and with what merge strategy.
- [git-merge-conflicts.md](git-merge-conflicts.md) — Long-lived PR branches are the primary source of merge conflicts.
- [git-branching-strategy.md](git-branching-strategy.md) — Branch naming, lifetime, and purpose are defined by strategy; PRs enforce those conventions at merge time.
- [github-branch-protection.md](../github/github-branch-protection.md) — Branch protection rules define what a PR must satisfy before merging.
- [github-codeowners.md](../github/github-codeowners.md) — CODEOWNERS determines which reviewers are automatically requested on a PR.

---

## Source

[GitHub Docs — About Pull Requests](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests)

---
*Last updated: 2026-04-24*