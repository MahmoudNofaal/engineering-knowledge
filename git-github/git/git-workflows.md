# Git Workflows

> A Git workflow is a convention for how a team branches, merges, and releases code using Git.

---

## When To Use It

Every team using Git needs a workflow, even if they haven't named it. The right one depends on team size, release cadence, and deployment model. A simple trunk-based approach works well for small teams shipping continuously; Gitflow suits teams with scheduled releases and parallel version support. The wrong workflow creates merge hell, broken main branches, or release bottlenecks.

---

## Core Concept

A Git workflow is just an agreement about what branches exist, when you create them, and where they merge. The three common models are: **trunk-based** (everyone commits to main frequently, feature flags gate unfinished work), **Gitflow** (long-lived develop/main branches + feature/release/hotfix branches), and **GitHub Flow** (short-lived feature branches off main, merged via PR, deployed immediately). The trend in modern engineering is toward trunk-based because long-lived branches accumulate drift and make integration painful. The branch isn't the feature — it's a temporary isolation unit.

---

## The Code
```bash
# ── GitHub Flow (most common for web teams) ──────────────────────────

# 1. Start from an up-to-date main
git checkout main
git pull origin main

# 2. Create a short-lived feature branch
git checkout -b feat/user-auth-jwt

# 3. Work, commit in small logical units
git add .
git commit -m "feat: add JWT validation middleware"

# 4. Keep branch current — rebase, not merge, to keep history clean
git fetch origin
git rebase origin/main

# 5. Push and open PR
git push origin feat/user-auth-jwt
# → open PR on GitHub, squash-merge after approval

# 6. Delete branch after merge
git branch -d feat/user-auth-jwt
git push origin --delete feat/user-auth-jwt
```
```bash
# ── Gitflow — branch structure only ─────────────────────────────────

git checkout -b develop main          # long-lived integration branch
git checkout -b feature/payments develop   # feature branches off develop
git checkout -b release/1.4.0 develop     # release branch for hardening
git checkout -b hotfix/null-ref main      # hotfix branches off main directly

# hotfix must merge to BOTH main and develop
git checkout main && git merge hotfix/null-ref
git checkout develop && git merge hotfix/null-ref
```
```bash
# ── Trunk-Based (CI/CD teams) ────────────────────────────────────────

# Short branch, merged within a day or two
git checkout -b fix/order-total-rounding
git commit -m "fix: correct floating point in order total"

# If feature isn't done, hide it behind a flag — don't keep the branch open
# In code: if (FeatureFlags.IsEnabled("new-checkout")) { ... }

git push origin fix/order-total-rounding
# → PR reviewed same day, merged to main, pipeline deploys automatically
```

---

## Gotchas

- **Gitflow looks organized until your hotfix diverges from develop.** If you merge a hotfix to main but forget to back-merge to develop, the next release reintroduces the bug. This happens constantly.
- **Squash merge hides co-author history but destroys bisect granularity.** `git bisect` becomes useless if every PR is one giant squash commit. Prefer merge commits or rebase-merge for repos where bisect matters.
- **Long-lived feature branches don't just drift — they rot.** After two weeks of not rebasing, you're not integrating incrementally; you're doing a mini-waterfall merge at the end.
- **Branch naming conventions without enforcement are fiction.** If your workflow depends on branches starting with `feat/` or `hotfix/`, enforce it in CI or a pre-push hook — not a README.
- **GitHub Flow assumes continuous deployment.** If you open a PR and it sits for a week because deployment is manual or gated, you've recreated Gitflow's problems without its structure.

---

## Interview Angle

**What they're really testing:** Whether you understand the tradeoffs between integration frequency and isolation — not whether you can recite branch names.

**Common question form:** "Walk me through your team's Git workflow" or "What's the difference between Gitflow and trunk-based development?"

**The depth signal:** A junior describes the branch names and when to create them. A senior explains *why* long-lived branches increase merge risk proportional to team size, when feature flags replace branches as the isolation mechanism, and what your branching strategy implies about your deployment pipeline — e.g., Gitflow only makes sense if you're not doing continuous deployment, because release branches exist to delay integration, which is the opposite of CD.

---

## Related Topics

- [[git/merge-vs-rebase.md]] — The mechanics that make or break any workflow: rebase keeps history linear, merge preserves branch topology; wrong choice compounds across a team.
- [[git/commit-conventions.md]] — Conventional commits (feat/fix/chore) only add value if your workflow enforces them at PR time; otherwise they're noise.
- [[devops/ci-cd-pipelines.md]] — Your workflow dictates your pipeline: trunk-based requires feature flags and fast CI; Gitflow requires branch-specific pipeline stages.
- [[git/pull-request-process.md]] — PR review culture is the enforcement layer for any workflow; without it, the branch model is just suggestions.

---

## Source

[Atlassian Git Workflows Comparison](https://www.atlassian.com/git/tutorials/comparing-workflows)

---
*Last updated: 2026-03-24*