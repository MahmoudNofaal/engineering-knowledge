# GitHub Issues

> GitHub Issues is a lightweight project tracking system built into every repository — each issue is a threaded discussion with labels, assignees, milestones, and bidirectional links to commits and PRs.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Threaded issue tracker integrated with GitHub code and PRs |
| **Use when** | Bug reports, feature requests, tasks, questions — anything that needs tracking and discussion |
| **Key features** | Templates, labels, milestones, assignees, closing keywords, Projects integration |
| **Key commands** | `gh issue create`, `gh issue list`, `gh issue view`, `gh issue close` |
| **Closing keywords** | `Fixes #N`, `Closes #N`, `Resolves #N` in PR description auto-closes the issue on merge |

---

## Core Concept

Issues are the unit of work in GitHub's project management model. Every issue has: a number (`#89`), a title, a body (Markdown), labels (category/priority/status tags), assignees, a milestone, and a project association. Issues link bidirectionally with PRs — a PR description containing `Fixes #89` creates a link, and when that PR merges to the default branch, GitHub automatically closes the issue. The issue becomes the permanent record of why a change was made.

---

## The Code

**Issue templates — standardise what reporters provide**
```markdown
<!-- .github/ISSUE_TEMPLATE/bug_report.md -->
---
name: Bug Report
about: Something isn't working as expected
labels: bug
assignees: ''
---

## What happened?
<!-- Clear description of the bug -->

## Expected behaviour
<!-- What you expected to happen -->

## Steps to reproduce
1.
2.
3.

## Environment
- OS:
- Version:
- Browser (if relevant):

## Logs / screenshots
<!-- Paste relevant logs or attach screenshots -->
```

```markdown
<!-- .github/ISSUE_TEMPLATE/feature_request.md -->
---
name: Feature Request
about: Suggest a new feature or enhancement
labels: enhancement
---

## Problem to solve
<!-- What user problem does this feature address? -->

## Proposed solution
<!-- How would you like to see this solved? -->

## Alternatives considered
<!-- What other approaches did you consider? -->
```

```yaml
# .github/ISSUE_TEMPLATE/config.yml — disable blank issues, add external links
blank_issues_enabled: false
contact_links:
  - name: Security Vulnerability
    url: https://github.com/org/repo/security/advisories/new
    about: Please report security vulnerabilities via private advisory
  - name: Questions & Discussion
    url: https://github.com/org/repo/discussions
    about: For questions and general discussion
```

**Working with issues via CLI**
```bash
# Create an issue
gh issue create \
  --title "Null reference when cart is empty at checkout" \
  --body-file .github/ISSUE_TEMPLATE/bug_report.md \
  --label "bug,high-priority,payments" \
  --assignee alice \
  --milestone "v2.1"

# List issues with filters
gh issue list --label "bug"
gh issue list --assignee @me --state open
gh issue list --milestone "v2.1"

# View an issue
gh issue view 89
gh issue view 89 --comments

# Add a comment
gh issue comment 89 --body "Investigating — looks related to #87"

# Close with a comment
gh issue close 89 --comment "Fixed in PR #142. Released in v2.1.0."

# Transfer an issue to another repo
gh api repos/org/repo/issues/89/transfer \
  --method POST \
  --field new_repository="org/other-repo"
```

**Labels — a lightweight taxonomy**
```bash
# Create a standard label set (run once on new repos)
labels=(
  "bug:CC0000:Something isn't working"
  "enhancement:84b6eb:New feature or request"
  "good first issue:7057ff:Good for newcomers"
  "help wanted:008672:Extra attention needed"
  "security:e11d48:Security vulnerability"
  "dependencies:0075ca:Dependency updates"
  "documentation:0075ca:Documentation improvements"
  "P0:b60205:Critical - production down"
  "P1:d93f0b:High priority"
  "P2:fbca04:Medium priority"
  "P3:0e8a16:Low priority"
)

for label in "${labels[@]}"; do
  IFS=':' read name color description <<< "$label"
  gh label create "$name" --color "#$color" --description "$description" || true
done
```

**Closing keywords — auto-close on PR merge**
```markdown
# In PR description or commit message:
Fixes #89          # closes issue 89 when PR merges to default branch
Closes #89         # same effect
Resolves #89       # same effect
Fix #89, fix #90   # closes multiple issues

# Partial fix (doesn't close):
Related to #89
See also #90

# The issue is only closed if the PR merges to the DEFAULT branch
# Merging to a feature branch does not close the issue
```

---

## Common Misconceptions

**"Issues are only for bugs"**
Issues are general-purpose units of work — bugs, features, tasks, questions, architectural decisions, spike investigations. Many teams use GitHub Issues as their complete project management system, with labels and milestones providing the structure. The "Issues" name is historical; think of them as "discussions with tracking."

**"Closing keywords work with any branch"**
Closing keywords only auto-close issues when the PR merges to the **default branch** (usually `main`). If you merge a PR to `develop` with "Fixes #89," the issue stays open. It closes when a PR containing that commit eventually merges to `main`.

---

## Related Topics

- [github-pull-requests-advanced.md](github-pull-requests-advanced.md) — PRs and issues link bidirectionally; closing keywords connect them.
- [github-projects.md](github-projects.md) — GitHub Projects provides a board/table view on top of issues.
- [github-discussions.md](github-discussions.md) — Discussions vs Issues: when to use which.

---

## Source

[GitHub Docs — About Issues](https://docs.github.com/en/issues/tracking-your-work-with-issues/about-issues)

---
*Last updated: 2026-04-24*