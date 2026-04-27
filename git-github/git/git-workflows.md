# Git Workflows

> A Git workflow is a convention for how a team branches, merges, and releases code using Git.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A team agreement on branch naming, lifetime, merge targets, and release process |
| **Use when** | Any team of 2+ engineers committing to a shared repo |
| **Avoid when** | Over-engineering — a solo project needs no formal workflow |
| **Git version** | Not a Git feature — workflows are conventions on top of Git |
| **Key models** | Trunk-Based Development, GitHub Flow, Gitflow |
| **Key decision** | Your deployment model dictates your workflow, not aesthetics |

---

## When To Use It

Every team using Git needs a workflow, even if they haven't named it. The right one depends on team size, release cadence, and deployment model. A simple trunk-based approach works well for small teams shipping continuously; Gitflow suits teams with scheduled releases and parallel version support. The wrong workflow creates merge hell, broken main branches, or release bottlenecks.

---

## Core Concept

A Git workflow is just an agreement about what branches exist, when you create them, and where they merge. The three common models are: **trunk-based** (everyone commits to main frequently, feature flags gate unfinished work), **Gitflow** (long-lived develop/main branches + feature/release/hotfix branches), and **GitHub Flow** (short-lived feature branches off main, merged via PR, deployed immediately). The trend in modern engineering is toward trunk-based because long-lived branches accumulate drift and make integration painful. The branch isn't the feature — it's a temporary isolation unit.

---

## Version History

| Year | Development |
|---|---|
| 2005 | Git created — workflows were team conventions from day one |
| 2010 | Vincent Driessen publishes "A successful Git branching model" (Gitflow) |
| 2011 | GitHub Flow described by Scott Chacon as simpler alternative |
| 2013 | Trunk-Based Development popularised by Paul Hammant |
| 2015 | Feature flags / feature toggles become mainstream CI/CD enabler |
| 2017–2020 | Industry shift toward trunk-based for teams doing CD |
| 2021 | Gitflow author adds note recommending trunk-based for CD teams |

*In 2021, Vincent Driessen — the author of Gitflow — added a note to his original blog post recommending against Gitflow for teams doing continuous delivery: "If your team is doing continuous delivery of software, I would suggest to adopt a much simpler workflow (like GitHub Flow) instead of trying to use this model." This was a significant shift in the community.*

---

## Performance

| Workflow | Integration frequency | Conflict risk | Deployment speed |
|---|---|---|---|
| Trunk-Based | Multiple times/day | Very low (tiny diffs) | Immediate |
| GitHub Flow | 1–3× per week per engineer | Low | Same day |
| Gitflow | Weekly to monthly | Medium–High | Scheduled release |

**The compounding conflict cost:** Conflict complexity grows super-linearly with branch age. A branch open 1 day has a roughly linear conflict surface. A branch open 2 weeks has an exponentially larger surface because other branches have also moved. The merge cost difference between a 1-day and 2-week branch is not 14×, it's often 50–100× in engineer-hours due to conflict complexity.

**Benchmark notes:** Teams that switch from Gitflow to trunk-based typically report 40–70% reduction in integration-related incidents within the first 3 months — not because the code is better, but because bugs surface within hours (next deploy) rather than weeks (next release).

---

## The Code

**GitHub Flow — most common for web/SaaS teams**
```bash
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
gh pr create --title "feat: add JWT validation" --reviewer alice

# 6. After approval and CI pass — squash merge for clean main history
gh pr merge --squash

# 7. Delete branch after merge (automate this in repo settings)
git branch -d feat/user-auth-jwt
git push origin --delete feat/user-auth-jwt
```

**Trunk-Based Development**
```bash
# Short branch, merged within 1–2 days maximum
git checkout -b fix/order-total-rounding
git commit -m "fix: correct floating point in order total"

# If feature isn't done, hide it behind a flag — don't keep the branch open
# In C#:
if (_featureFlags.IsEnabled("new-checkout", userId))
{
    return await _newCheckoutService.ProcessAsync(order);
}
return await _legacyCheckoutService.ProcessAsync(order);

git push origin fix/order-total-rounding
# → PR reviewed same day, merged to main, pipeline deploys automatically

# Feature flags cleaned up after full rollout:
# 1. Remove flag check, keep only new code path
# 2. Archive/delete the flag from the config/dashboard
# 3. Commit as a cleanup PR
```

**Gitflow — full branch structure**
```bash
# Long-lived branches
git checkout -b develop main          # integration branch
git checkout -b release/1.4.0 develop # release branch for hardening
git checkout -b hotfix/null-ref main  # hotfix branches off MAIN directly

# Feature workflow in Gitflow
git checkout -b feature/payments develop   # branches off develop
# ... work ...
git checkout develop
git merge --no-ff feature/payments          # preserve branch topology
git branch -d feature/payments

# Release workflow
git checkout -b release/1.4.0 develop
# Only bug fixes in release branch — no new features
git commit -m "fix: edge case in payment timeout"

# Complete the release
git checkout main
git merge --no-ff release/1.4.0
git tag -a v1.4.0 -m "Release 1.4.0"

# CRITICAL: back-merge to develop (most-forgotten step in Gitflow)
git checkout develop
git merge --no-ff release/1.4.0
git branch -d release/1.4.0

# Hotfix workflow (must merge to BOTH main and develop)
git checkout -b hotfix/null-ref main
git commit -m "fix: null ref in payment processor"
git checkout main && git merge --no-ff hotfix/null-ref && git tag -a v1.3.1
git checkout develop && git merge --no-ff hotfix/null-ref  # ← most forgotten step
git branch -d hotfix/null-ref
```

**Branch naming enforcement — pre-push hook**
```bash
# .githooks/pre-push
#!/bin/bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Define patterns by workflow
GITHUB_FLOW_PATTERN='^(feat|fix|chore|docs|refactor|test|ci|perf)/[a-z0-9-]+$'
GITFLOW_PATTERN='^(feature|release|hotfix|bugfix)/[a-z0-9._-]+$'
PROTECTED='^(main|master|develop)$'

# Skip protected branches (developers shouldn't be pushing directly anyway)
if echo "$BRANCH" | grep -qE "$PROTECTED"; then
  exit 0
fi

if ! echo "$BRANCH" | grep -qE "$GITHUB_FLOW_PATTERN"; then
  echo "❌ Branch name '$BRANCH' doesn't match required pattern."
  echo "   Expected: feat|fix|chore|docs|.../short-description"
  echo "   Example:  feat/add-oauth-login"
  exit 1
fi
exit 0
```

**Feature flag infrastructure — minimal implementation**
```csharp
// Simple feature flag for trunk-based development
// Production-grade: use LaunchDarkly, Azure App Configuration, etc.

public interface IFeatureFlags
{
    bool IsEnabled(string flagName, string? userId = null);
}

public class ConfigFeatureFlags : IFeatureFlags
{
    private readonly IConfiguration _config;

    public ConfigFeatureFlags(IConfiguration config) => _config = config;

    public bool IsEnabled(string flagName, string? userId = null)
    {
        // Check environment variable first (CI/CD overrides)
        var envKey = $"FEATURE_{flagName.ToUpper().Replace("-", "_")}";
        if (bool.TryParse(Environment.GetEnvironmentVariable(envKey), out var envVal))
            return envVal;

        // Then check appsettings.json
        return _config.GetValue<bool>($"FeatureFlags:{flagName}");
    }
}

// appsettings.json
{
  "FeatureFlags": {
    "new-checkout": false,     // disabled in production
    "new-search": true         // enabled for all users
  }
}

// appsettings.Development.json
{
  "FeatureFlags": {
    "new-checkout": true,      // enabled locally for development
    "new-search": true
  }
}
```

---

## Real World Example

A 35-person fintech engineering team was using Gitflow with 3-week release cycles. Their `develop` branch had 47 open feature branches at any given time, and every release involved 3–4 days of "integration hell" — resolving conflicts between branches that had each been developed in isolation for weeks. After switching to GitHub Flow with bi-weekly deployments and feature flags, integration incidents dropped to near zero and deploy frequency went from 17 per year to 104 per year.

```bash
# Before (Gitflow — actual state of their develop branch one release cycle):
git branch | grep feature/ | wc -l
# 47 feature branches
git log --oneline --graph develop | head -30
# A visual mess of merge commits from 47 independent timelines converging

# The "integration hell" sequence every release:
git checkout release/2023-Q4
git merge feature/payment-gateway        # 3 conflicts
git merge feature/reporting-dashboard    # 7 conflicts
git merge feature/user-permissions       # 12 conflicts (touched same auth code)
# ... 44 more merges, each potentially conflicting with all previous

# After (GitHub Flow — same team, 6 months later):
# Average branch age: 1.4 days
# Average PR size: 186 lines
# Merge conflicts: 2.1 per week (down from ~40 per release cycle)
# Releases per year: 104 (up from 17)

# The key enabler — feature flag for the biggest in-progress feature:
# Payment gateway was a 3-month project
# Instead of keeping a giant branch open:

# Week 1: scaffold with flag (immediately merged to main)
git checkout -b feat/payment-gateway-scaffold
# All new code behind: if (_flags.IsEnabled("payment-gateway")) { ... }
git push && gh pr create && gh pr merge --squash

# Week 2–12: incremental additions, all behind the same flag
# Each week: 3–5 small PRs, each reviewable in < 30 minutes
# Flag stays off in production throughout

# Week 12: flag enabled for 1% of users (canary)
# Week 13: 100% rollout, flag removed, cleanup PR
```

*The key insight: the workflow choice is really a question of "how long can an engineer's work be invisible to the rest of the team?" Gitflow says: weeks. GitHub Flow says: days. Trunk-based says: hours. The answer determines your integration risk, conflict frequency, and deployment speed. There's no universally correct answer — but the tradeoff is deterministic.*

---

## Common Misconceptions

**"Trunk-based development means no branches"**
Trunk-based development means *short-lived* branches — typically 1–2 days maximum, merged to main via PR. It does not mean committing directly to main (though some teams do). The key difference from Gitflow is not the absence of branches but their *lifetime*. A branch open for 2 hours vs. 2 weeks is the difference between a speed bump and a road block.

**"Gitflow is more professional because it's more structured"**
Gitflow adds structure to manage the complexity of long-lived branches and scheduled releases. If you're doing continuous deployment, Gitflow adds structure to solve a problem you don't have — while creating problems you didn't have (merge hell, integration delays, stale branches). Structure should solve real problems. If your team deploys multiple times per day, Gitflow's release branches are friction, not professionalism.

**"The workflow is a developer choice, not an ops choice"**
The workflow and the CI/CD pipeline are tightly coupled. Trunk-based development requires fast CI (< 10 minutes), automated deployment, and a feature flag system. Gitflow requires branch-specific pipeline stages and scheduled deployment coordination. Choosing a workflow without considering your pipeline capabilities — or your pipeline capabilities without considering your workflow — leads to contradictory systems.

---

## Gotchas

- **Gitflow's back-merge from hotfix to develop is skipped under pressure.** Every team that uses Gitflow has reintroduced a production bug this way. The merge to `develop` after a hotfix is not optional — make it a checklist item or automate it.

- **"Short-lived branches" in trunk-based requires actual CI speed.** If your pipeline takes 40 minutes, nobody merges daily. Committing to trunk-based without fast CI just means undisciplined long-lived branches with a different name.

- **Branch protection rules are the workflow's enforcement mechanism.** A workflow documented in a README but not enforced via required reviews and status checks is just a suggestion that erodes under deadline pressure.

- **Squash merge loses individual commit granularity for `git bisect`.** If you squash every PR into one commit on main, and a PR contains 15 commits across 5 logical changes, bisect will point to a 500-line diff instead of a 30-line one. Use squash merge with good PR scoping (one concern per PR), or use merge commits and rely on PR-level bisect.

- **Feature flags must be cleaned up or they become permanent debt.** Every feature flag is a branch in code. 50 stale feature flags is the equivalent of 50 stale git branches — except they're invisible and can interact with each other. Track flags with expiry dates and make cleanup PRs part of the feature completion definition.

---

## Interview Angle

**What they're really testing:** Whether you understand that a branching strategy is a deployment and integration policy, not just a naming convention.

**Common question forms:**
- "What branching strategy do you use and why?"
- "Walk me through your team's Git workflow."
- "What's the difference between Gitflow and trunk-based development?"

**The depth signal:** A junior describes the branch types. A senior explains the coupling between branching strategy and deployment model — specifically, that Gitflow's release branches exist to delay integration, which is incompatible with continuous deployment, and that trunk-based development only works if you have fast CI and a feature flag system, because those two things replace the isolation that long-lived branches provide.

**Follow-up questions to expect:**
- "How do you handle a feature that takes 6 weeks to build in a trunk-based workflow?"
- "What happens in Gitflow if you forget to back-merge a hotfix to develop?"

---

## Related Topics

- [git-branching-strategy.md](git-branching-strategy.md) — The branch topology that the workflow sits on top of; strategy is the "what exists," workflow is the "what do you do with it."
- [git-merging.md](git-merging.md) — Merge vs. squash vs. rebase merge — the workflow determines which merge strategy you use at PR time.
- [git-hooks.md](git-hooks.md) — Hooks enforce workflow conventions locally; CI enforces them remotely.
- [git-pull-requests.md](git-pull-requests.md) — PRs are the human step in the workflow; their quality determines whether the workflow works.
- [github-actions-integration.md](github-actions-integration.md) — Your CI pipeline must align with your workflow; trunk-based and Gitflow need fundamentally different pipeline designs.

---

## Source

[Atlassian Git Workflows Comparison](https://www.atlassian.com/git/tutorials/comparing-workflows)

---
*Last updated: 2026-04-24*