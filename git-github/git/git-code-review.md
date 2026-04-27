# Code Review

> Code review is the practice of having one or more engineers read and evaluate a proposed change before it merges, with the goal of catching bugs, maintaining consistency, and spreading knowledge.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A human quality gate combining defect detection and knowledge transfer |
| **Use when** | Any change reaching a shared branch — no exceptions for "small" changes |
| **Avoid when** | True production emergencies — review after the fact |
| **Git version** | Not a Git feature — a team practice hosted on GitHub/GitLab/Bitbucket |
| **Key principle** | Code review is the reviewer's job AND the author's responsibility |
| **Key tools** | GitHub review UI, `gh pr review`, local checkout via `gh pr checkout` |

---

## When To Use It

Code review should be on every change that reaches a shared branch — no exceptions for "small" changes, because production incidents routinely trace back to one-line changes that skipped review. The intensity scales with risk: a CSS tweak and a database migration both get reviewed, but the migration gets more scrutiny and a different set of reviewers. The only context where you skip review is a true production emergency where every minute counts — and even then, you review after the fact.

---

## Core Concept

Code review has two jobs that people often conflate: catching defects and transferring knowledge. Defect-catching is reactive — you're looking at what's there. Knowledge transfer is proactive — you're making sure at least one other person understands what changed and why. Both matter. The thing most teams get wrong is treating review purely as a quality gate and ignoring the knowledge transfer side, which is why codebases develop "owner silos" where only one person understands a module. Review is also not a style debate — style is enforced by linters and formatters before code reaches a human reviewer.

---

## Version History

| Year | Development |
|---|---|
| 1990s | Formal code inspection (Fagan inspections) in enterprise software |
| 2008 | GitHub launches with pull request review as a core feature |
| 2010s | Code review becomes standard practice in software engineering |
| 2020 | GitHub introduces "Suggested changes" — reviewers can propose exact edits |
| 2022 | GitHub introduces "Copilot for PRs" — AI-assisted review summaries |
| 2023 | GitHub "Merge Queue" GA — prevents "reviewed but broken after merge" |
| 2024 | AI code review tools (CodeRabbit, Sourcery) become mainstream |

*The "Suggested changes" feature (GitHub 2020) significantly improved review efficiency for nitpick-level feedback — reviewers can propose the exact fix rather than describing it in prose, and authors can accept with one click. This reduced the round-trip cost of small feedback from hours to seconds.*

---

## Performance

| PR characteristic | Review effectiveness |
|---|---|
| < 200 lines | High — reviewer can hold entire change in working memory |
| 200–400 lines | Good — some context-switching required |
| 400–800 lines | Degraded — reviewers skim rather than read |
| 800+ lines | Poor — "LGTM" reviews dominate |
| Mixed concerns | Very poor — reviewer can't reason about correctness of one concern without understanding all |

**Review time benchmarks:** Google's internal research found meaningful review of 200 lines takes ~20 minutes. 400 lines: ~45 minutes. These are *meaningful* reviews — not approval-stamping. If your team's average review time is 2 minutes on 300-line PRs, the review is not adding quality.

**Cycle time targets:** Best-in-class teams maintain < 24-hour PR cycle time (open → merge). Reviews sitting open for 3+ days typically indicate: PRs are too large to prioritize easily, reviewers are over-allocated, or there's no culture of review-as-first-priority work.

---

## The Code

**Reviewer workflow — run the code, don't just read it**
```bash
# Check out and run the PR branch — don't just read the diff
gh pr checkout 217

# Run tests before forming an opinion
dotnet test
# or
npm test

# Check what actually changed (file-level summary first)
git diff main...HEAD --stat

# Then read the meaningful diff (ignore whitespace noise)
git diff main...HEAD -w

# Look at the full context around changed lines
git diff main...HEAD -U10    # 10 lines of context instead of default 3

# Return to your branch
git switch main
```

**Leaving actionable review comments**
```bash
# Comment prefixes signal intent clearly — use these consistently:
# [blocking]   — must fix before merge
# [nit]        — style/preference, non-blocking, author's call
# [question]   — genuinely unclear, not a change request
# [suggestion] — take it or leave it
# [praise]     — explicitly acknowledge good work
```

```
[blocking] This will throw NullReferenceException if order.Customer is null,
which is possible when order comes from the legacy importer. Add a null
check or assert upstream that Customer is always populated.

[nit] Variable name `data` is too generic — `customerInvoices` would make
the loop below self-documenting.

[question] Why is this using raw HttpClient instead of the typed
IOrderServiceClient already registered in DI? Oversight or intentional?

[suggestion] Consider extracting the retry logic into a dedicated
RetryPolicy class — it's duplicated in PaymentService now too.

[praise] The way you've structured the repository tests here makes
them genuinely independent — this is a good pattern for the team.
```

**What to look for — a reviewer's mental checklist**
```csharp
// 1. Correctness — does it actually do what the PR says?
// 2. Edge cases — null inputs, empty collections, concurrent access
// 3. Error handling — are exceptions caught at the right level?
// 4. Tests — do they test behavior, not implementation? Would they catch a regression?
// 5. Security — SQL built from user input? Secrets hardcoded? Auth bypass possible?
// 6. Performance — N+1 queries? Unbounded loops on large data? Unnecessary allocations?
// 7. Consistency — does it follow patterns already established in this codebase?
// 8. Reversibility — if this goes wrong, how easy is it to roll back?

// NOT your job as reviewer:
// - Reformatting code (that's the formatter's job)
// - Debating conventions not in the style guide
// - Requesting architectural changes that weren't scoped to this PR
// - Blocking on preference when both approaches are valid
```

**GitHub review workflow via CLI**
```bash
# View all open PRs
gh pr list

# View a specific PR with comments
gh pr view 217

# Submit a review
gh pr review 217 --approve -b "LGTM — logic is sound, tests cover the edge cases"
gh pr review 217 --request-changes -b "Blocking issue: null ref in payment path"
gh pr review 217 --comment -b "Some questions and suggestions inline"

# See all reviewers and their status
gh pr view 217 --json reviews
```

**Reviewer assignment strategy**
```bash
# CODEOWNERS auto-assigns reviewers based on file paths
# .github/CODEOWNERS
/src/Payments/    @payments-team @security-lead   # payments requires security sign-off
/src/Auth/        @security-team
/infra/           @devops-team

# For PRs touching multiple domains, require one reviewer per domain
# Configure in branch protection:
# - Require review from code owners
# - Dismiss stale reviews when new commits are pushed
# - Require review from at least 1 person who didn't write the code

# Rule of thumb on reviewer count:
# 1 reviewer  = fast and accountable
# 2 reviewers = good for high-risk changes
# 3+ reviewers = diffusion of responsibility kicks in — each waits for others
```

---

## Real World Example

A team of 14 engineers had a review culture problem that wasn't obvious: reviews were getting "done" in under 3 minutes for 200+ line PRs. The team lead suspected rubber-stamping but couldn't prove it. They ran a 4-week experiment tracking review quality indirectly — measuring post-merge defect rate per reviewer.

```python
# Review quality audit — tracking bugs traceable to reviewed PRs
# (pseudocode — actual implementation uses GitHub API)

def audit_review_quality(repo: str, lookback_days: int = 90) -> dict:
    """
    For each reviewer, calculate:
    - PRs reviewed
    - Average review time (PR opened → review submitted)
    - Bugs in production traced to PRs they approved
    - Average review comment depth (blocking/question/nit ratio)
    """
    from github import Github
    import datetime

    g = Github(os.environ["GITHUB_TOKEN"])
    repo = g.get_repo(repo)

    since = datetime.datetime.now() - datetime.timedelta(days=lookback_days)
    reviewer_stats = {}

    for pr in repo.get_pulls(state='closed', sort='updated', direction='desc'):
        if pr.merged_at and pr.merged_at > since:
            for review in pr.get_reviews():
                reviewer = review.user.login
                if reviewer not in reviewer_stats:
                    reviewer_stats[reviewer] = {
                        'prs_reviewed': 0,
                        'avg_review_hours': [],
                        'comment_count': []
                    }

                hours = (review.submitted_at - pr.created_at).total_seconds() / 3600
                reviewer_stats[reviewer]['prs_reviewed'] += 1
                reviewer_stats[reviewer]['avg_review_hours'].append(hours)
                reviewer_stats[reviewer]['comment_count'].append(
                    pr.get_review_comments().totalCount
                )

    return reviewer_stats

# Finding: three reviewers had average review time of 4 minutes on 300-line PRs
# and 0.2 comments per review (vs team average of 3.1)
# Those same reviewers had 2.8× the post-merge defect rate of careful reviewers

# Fix implemented:
# 1. Team discussion: review is the highest-leverage activity, not an interruption
# 2. "Review slots" — two 45-minute focused review windows per day, no interruptions
# 3. Review quality visible in weekly retro: comment count, blocking issue rate
# 4. PR size limit enforced (bot comments if > 400 lines, blocks merge if > 600)
```

*The key insight: review culture is revealed by metrics, not stated values. A team that says "we take code review seriously" but averages 3-minute reviews on 300-line PRs is describing an aspiration, not a reality. Making the metrics visible — without attaching them to performance reviews — shifted the culture more effectively than any process mandate.*

---

## Common Misconceptions

**"Approving a PR means the reviewer verified correctness"**
Approval means "I read this diff and didn't see obvious problems." It is not a correctness guarantee. Most reviewers don't run the code locally for every PR. Tests, CI, staging environments, and feature flags are the correctness mechanisms — review is one layer of a multi-layer defense. A PR can be reviewed and approved by five senior engineers and still have a subtle bug.

**"More reviewers = higher quality"**
Three required reviewers sounds thorough. In practice, it creates diffusion of responsibility — each reviewer assumes the others looked carefully, so each looks less carefully. One accountable reviewer who actually runs the code beats three passive reviewers who skimmed the diff. If risk is high, require review from specific domain experts, not arbitrary headcount.

**"Review is the reviewer's responsibility"**
Review quality is co-owned by the author and the reviewer. The author controls: PR size (should be reviewable in one sitting), description quality (context the reviewer needs), test coverage (reducing the reviewer's need to mentally simulate execution), and how promptly they respond to feedback. Authors who write 800-line PRs with no description and then complain about slow reviews are creating the problem they're complaining about.

---

## Gotchas

- **"LGTM" after two minutes means nobody actually reviewed it.** A meaningful review of 300 changed lines takes at least 15–20 minutes. If your team's reviews are consistently instant, they're rubber stamps.

- **Blocking on style when a linter exists is a trust tax on the author.** If ESLint, Prettier, or dotnet-format is configured, you don't leave style comments — you point them to the linter config and move on.

- **Asking for large architectural changes at review time is too late.** That conversation belongs in the design phase or in a spike PR. Reviewing a week of work and saying "we should rethink the whole approach" breaks trust and wastes time.

- **Reviewer over-assignment causes diffusion of responsibility.** One accountable reviewer beats three passive ones. If a change is risky, pick the two people most qualified, not five people for coverage.

- **Comments without suggested fixes are harder to act on.** "This could throw" is less useful than "This could throw — add `.FirstOrDefault()` and handle the null case." When you spot a problem, include the fix if you can.

- **Stale review approvals should be dismissed when new commits are pushed.** A reviewer who approved a PR 3 days ago hasn't reviewed the last 8 commits. Configure "Dismiss stale pull request approvals when new commits are pushed" in branch protection.

---

## Interview Angle

**What they're really testing:** Whether you approach review as a collaborative quality practice or as a gatekeeping exercise, and whether you understand both sides — giving and receiving.

**Common question forms:**
- "How do you approach code review?"
- "Tell me about a time you gave or received difficult feedback in a review."
- "What makes a good code review?"

**The depth signal:** A junior describes what they look for (bugs, style, tests). A senior also talks about the reviewer's responsibility for knowledge distribution, how to calibrate blocking vs. non-blocking feedback to avoid slowing velocity unnecessarily, co-ownership of review quality by the author (PR size, description), and how review culture reflects team trust — a team where authors get defensive or reviewers feel pressure to approve quickly has a process problem, not a people problem.

**Follow-up questions to expect:**
- "How would you handle a teammate who consistently submits very large PRs?"
- "What's the difference between a blocking and a non-blocking review comment?"

---

## Related Topics

- [git-pull-requests.md](git-pull-requests.md) — PRs are the container; code review is what happens inside them.
- [git-branching-strategy.md](git-branching-strategy.md) — Branch strategy determines who reviews what and when.
- [git-hooks.md](git-hooks.md) — Automated checks (lint, test, security scan) should run before human review begins.
- [github-codeowners.md](../github/github-codeowners.md) — CODEOWNERS automates reviewer assignment and enforces domain expertise requirements.
- [github-branch-protection.md](../github/github-branch-protection.md) — Branch protection rules define what must be satisfied before a review can result in a merge.

---

## Source

[Google Engineering Practices — Code Review](https://google.github.io/eng-practices/review/)

---
*Last updated: 2026-04-24*