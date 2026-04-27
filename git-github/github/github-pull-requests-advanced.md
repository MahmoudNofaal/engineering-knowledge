# GitHub Pull Requests (Advanced)

> Advanced GitHub PR features: draft PRs, required reviewers, merge strategies, auto-merge, merge queue, PR templates, and the review workflow at scale.

---

## Quick Reference

| | |
|---|---|
| **What it is** | GitHub's platform layer on top of a branch merge request — with reviews, CI gates, and merge controls |
| **Key advanced features** | Draft PRs, auto-merge, merge queue, suggested changes, review environments, PR templates |
| **Key controls** | Branch protection (required reviews, status checks), CODEOWNERS (auto-assign), merge strategy |
| **Key commands** | `gh pr create --draft`, `gh pr merge --auto`, `gh pr review`, `gh pr ready` |

---

## Core Concept

Beyond the basics (open PR, get review, merge), GitHub PRs support: draft state (visible but not requesting review), suggested changes (reviewers propose exact edits the author can accept in one click), auto-merge (PR merges automatically when all requirements are satisfied), merge queue (PRs tested together before merging), and deployment reviews (environments that require human approval before deployment). These features turn a simple merge mechanism into a complete code change management system.

---

## The Code

**Draft PR workflow**
```bash
# Open as draft — CI runs, but no review requests sent
gh pr create \
  --title "feat: add payment webhook handler" \
  --draft \
  --body "Work in progress — completing the retry logic"

# Continue committing and pushing (CI runs automatically)
git commit -m "feat: add retry logic"
git push

# Mark ready when done (triggers review requests)
gh pr ready

# Convert back to draft if more work is needed
gh pr convert-to-draft 142
```

**Suggested changes — reviewer proposes exact edits**
```markdown
<!-- Reviewer leaves a suggestion in the diff view -->
<!-- In the GitHub web UI: click the ± icon in the diff to add a suggestion -->

```suggestion
public decimal CalculateTotal(Order order)
{
    return order.Subtotal * 1.14m + order.ShippingCost;
}
```

The author can accept this suggestion with one click — it commits the exact
proposed change without leaving the PR. Multiple suggestions can be batched
into a single commit.
```

```bash
# Accept a suggestion via API (programmatic)
gh api repos/org/repo/pulls/142/reviews \
  --method POST \
  --field body="Accepting suggested changes" \
  --field event="APPROVE"

# Commit all pending suggestions (via UI click or API)
# The commit message is auto-generated: "Apply suggestions from code review"
```

**Auto-merge — merge when all requirements satisfied**
```bash
# Enable auto-merge on a PR (will merge when all checks pass + reviews done)
gh pr merge 142 --auto --squash

# Auto-merge options:
gh pr merge 142 --auto --squash      # squash all commits (cleanest main history)
gh pr merge 142 --auto --merge       # merge commit (preserves branch topology)
gh pr merge 142 --auto --rebase      # rebase and merge (linear, no merge commit)

# Disable auto-merge (e.g., if there's an issue and you want to delay)
gh pr merge 142 --disable-auto

# Check auto-merge status
gh pr view 142 --json autoMergeRequest
```

**Merge queue — prevent "merged but broke main"**
```bash
# With merge queue enabled on the branch:
# PRs don't merge directly — they enter a queue
# The queue merges PRs onto a "virtual" base that includes all queued-ahead PRs
# CI runs on the combined result
# Only if CI passes does the PR merge to main

# Add PR to the merge queue (instead of merging directly)
gh pr merge 142 --auto    # queues when all initial requirements are met

# PRs in queue are visible:
gh api repos/org/repo/merge-queue/entries

# The merge queue automatically handles ordering and cancels entries if CI fails
```

**PR templates**
```markdown
<!-- .github/pull_request_template.md -->
## Summary
<!-- What does this PR do? Link to issue if applicable. -->
Closes #

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Refactor (no functional changes)

## How was this tested?
<!-- Describe your test approach -->

## Checklist
- [ ] My code follows the project style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have added tests for my changes
- [ ] New and existing unit tests pass locally
- [ ] I have updated documentation if needed
- [ ] My changes don't introduce new warnings
```

```bash
# Multiple templates (stored in .github/PULL_REQUEST_TEMPLATE/ directory)
# Users select via ?template= query param or from template chooser
.github/PULL_REQUEST_TEMPLATE/
├── feature.md
├── bugfix.md
└── hotfix.md
```

**Review workflow patterns**
```bash
# Request specific reviewers (in addition to CODEOWNERS auto-assignment)
gh pr create \
  --reviewer alice,bob,org/security-team

# Approve a PR with a message
gh pr review 142 \
  --approve \
  --body "LGTM — tested locally, edge cases covered"

# Request changes
gh pr review 142 \
  --request-changes \
  --body "Two blocking issues:
1. NullRef on empty cart (line 142)
2. Missing test for the zero-quantity case"

# Leave a comment-only review (no approve/reject)
gh pr review 142 \
  --comment \
  --body "Looks good direction-wise — see inline comments"

# Dismiss a stale review (if someone approved before major changes)
gh api repos/org/repo/pulls/142/reviews/REV_ID/dismissals \
  --method PUT \
  --field message="Major changes after this review — re-review needed"
```

**PR size analysis**
```bash
# Quick PR size check before creating
git diff origin/main...HEAD --stat | tail -1
# 12 files changed, 234 insertions(+), 89 deletions(-)

# List large open PRs (potential review bottlenecks)
gh pr list --json number,title,additions,deletions \
  --jq 'map(select(.additions + .deletions > 400)) | .[] | "\(.number): \(.title) (\(.additions + .deletions) lines)"'
```

---

## Common Misconceptions

**"Auto-merge bypasses branch protection"**
Auto-merge does not bypass branch protection rules. Auto-merge queues the merge to happen automatically once ALL branch protection requirements are satisfied: required reviews approved, all status checks passing, conversations resolved. It's a convenience feature that avoids the "now go click merge" last step — not a bypass.

**"Draft PRs don't run CI"**
Draft PRs trigger CI by default — the `pull_request` trigger fires regardless of draft state. The difference is: GitHub doesn't automatically request reviews from CODEOWNERS on draft PRs, and the PR is marked visually as not-ready. You can configure some workflows to skip drafts with: `if: github.event.pull_request.draft == false`.

---

## Related Topics

- [git-pull-requests.md](../git/git-pull-requests.md) — The Git/workflow fundamentals of PRs.
- [github-branch-protection.md](github-branch-protection.md) — Branch protection determines what PRs must satisfy before merging.
- [github-codeowners.md](github-codeowners.md) — CODEOWNERS automates reviewer assignment on PR creation.

---

## Source

[GitHub Docs — About Pull Requests](https://docs.github.com/en/pull-requests)

---
*Last updated: 2026-04-24*