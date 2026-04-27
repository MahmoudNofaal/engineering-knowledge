# Branching Strategy

> A branching strategy defines what branches exist in a repo, what purpose each serves, how long they live, and where they merge.

---

## Quick Reference

| | |
|---|---|
| **What it is** | The branch topology agreement that your workflow operates on top of |
| **Use when** | Any repo with more than one person committing — even a "strategy" of committing to main is a strategy |
| **Avoid when** | Over-engineering a solo project |
| **Git version** | Not a Git feature — a team convention |
| **Key decision** | Branch lifetime and promotion path, not branch naming |
| **Key models** | Trunk-Based, GitHub Flow, Gitflow, Release Branch, Environment Branch |

---

## When To Use It

Every repo that has more than one person committing to it needs an explicit branching strategy — even if that strategy is "we all commit to main." The strategy becomes load-bearing once you need to hotfix a production issue while a half-finished feature is in progress, or when two engineers are working on conflicting areas simultaneously. Without a defined strategy, these situations get resolved inconsistently every time.

---

## Core Concept

A branching strategy is really an answer to four questions: Where does production-ready code live? Where does in-progress work live? How does work get promoted between those places? And what happens when something is broken in production right now? The answers produce your branch model. Trunk-based says: one branch, promote via feature flags, deploy fast. Gitflow says: separate development and release concerns with long-lived branches. GitHub Flow is in the middle: short-lived feature branches off main, merged frequently. The right answer depends on your deployment model — not on what looks cleanest on a diagram.

---

## Version History

| Year | Milestone |
|---|---|
| 2010 | Vincent Driessen publishes Gitflow — becomes dominant model for a decade |
| 2011 | GitHub Flow documented — simpler for continuous deployment teams |
| 2014 | Feature flags/toggles emerge as trunk-based enabler |
| 2018 | DORA research shows trunk-based correlates with elite DevOps performance |
| 2021 | Gitflow author recommends against it for CD teams |
| 2023 | GitHub merge queues GA — solves the "merged but broke main" problem for high-velocity teams |

*The DORA (DevOps Research and Assessment) State of DevOps reports consistently show that trunk-based development is one of the strongest predictors of software delivery performance — correlated with more frequent deployments, shorter lead times, and lower failure rates.*

---

## Performance

| Strategy | Merge conflict risk | Deployment flexibility | Complexity |
|---|---|---|---|
| Trunk-Based | Very low | Continuous | Low (few branches) |
| GitHub Flow | Low | Same day | Low-Medium |
| Gitflow | Medium-High | Scheduled | High (many branches) |
| Environment branches | Very High | Confusing | Very High |

**The integration tax:** Every day a branch exists and diverges from main adds an integration cost. This cost is non-linear — it grows faster than the age of the branch because main itself moves. A branch that's 10 days old is not 10× harder to merge than a 1-day-old branch; it can be 100× harder if main had many changes in those 10 days that touched the same files.

**Benchmark notes:** Teams measuring PR cycle time (open → merge) as a workflow health metric typically see: trunk-based teams average < 24 hours; GitHub Flow teams average 1–3 days; Gitflow teams average 3–10 days. The difference is almost entirely branch age and PR size.

---

## The Code

**Trunk-Based: minimal branch structure**
```bash
main                        # always deployable, deploys automatically on merge
  └── feat/short-lived      # lives max 1–2 days, then deleted after merge

# Feature flag example (C# — hides unfinished work on main)
// In code: guard with a flag
if (_featureFlags.IsEnabled("new-payment-flow", userId))
{
    return await _newPaymentService.ProcessAsync(order);
}
return await _legacyPaymentService.ProcessAsync(order);

# Flag lifecycle:
# Week 1: flag = false everywhere (feature invisible)
# Week 4: flag = true for beta users (canary)
# Week 6: flag = true for all (full rollout)
# Week 7: cleanup PR — remove flag, delete old code path
```

**GitHub Flow: branch lifecycle**
```bash
main                            # protected, always deployable
  └── feat/user-profile-v2      # branch off main, PR, squash merge, delete
  └── fix/checkout-null-ref     # branch off main, PR, squash merge, delete

# Enforce the lifecycle: branch protection + auto-delete merged branches
# GitHub repo settings → Branches:
# ✅ Require pull request before merging
# ✅ Require status checks to pass
# ✅ Automatically delete head branches
```

**Gitflow: complete branch map**
```bash
main                            # production-only, tagged on every release
develop                         # integration branch, always deployable to staging
  └── feature/stripe-webhooks   # branches off develop, merges back to develop
  └── feature/email-templates   # branches off develop
release/2.3.0                   # branches off develop, merges to BOTH main + develop
hotfix/fix-payment-crash        # branches off MAIN, merges to BOTH main + develop

# Hotfix correctly done in Gitflow (the step people forget):
git checkout -b hotfix/fix-payment-crash main
# ... fix the bug ...
git checkout main
git merge --no-ff hotfix/fix-payment-crash
git tag -a v2.2.1 -m "Hotfix: payment crash"
git push origin main --follow-tags

git checkout develop
git merge --no-ff hotfix/fix-payment-crash   # ← THIS IS THE FORGOTTEN STEP
git push origin develop
git branch -d hotfix/fix-payment-crash
```

**Release branch strategy (for teams with multiple supported versions)**
```bash
# Maintain N versions simultaneously
main              # current development (v4.x)
release/v3.x      # maintained LTS branch (v3.x)
release/v2.x      # end-of-life (security only)

# Bug fixed on main → backport to supported releases
git cherry-pick -x <fix-commit>   # to release/v3.x
# Tag patch releases from release branches
git tag -a v3.2.1 -m "Patch release"
git tag -a v2.4.8 -m "Security patch"
```

**Branch naming convention enforcement**
```bash
# .githooks/pre-push — enforce naming on push
#!/bin/bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Allow protected branches
echo "$BRANCH" | grep -qE "^(main|master|develop|release/.+)$" && exit 0

# Enforce feature branch naming
PATTERN='^(feat|fix|chore|docs|refactor|test|ci|perf|hotfix)/[a-z0-9][a-z0-9-]{0,50}$'
if ! echo "$BRANCH" | grep -qE "$PATTERN"; then
  echo "❌ Branch name '$BRANCH' doesn't match required pattern."
  echo "   Pattern: <type>/<short-description>"
  echo "   Types:   feat|fix|chore|docs|refactor|test|ci|perf|hotfix"
  echo "   Example: feat/add-oauth-login"
  exit 1
fi
exit 0
```

**CODEOWNERS — ownership by branch target**
```
# .github/CODEOWNERS
# Global ownership — required review from platform team on any PR to main
*                   @org/platform-team

# Directory-level ownership — auto-requests correct reviewers
/src/Payments/      @org/payments-team
/src/Auth/          @org/security-team
/infra/             @org/devops-team
/.github/           @org/platform-team

# Release branches require senior review
# (handled via branch protection rules, not CODEOWNERS)
```

---

## Real World Example

A financial services company ran Gitflow for 4 years and had 12-person teams spending 2–3 days per release on "integration sprints" — doing nothing but resolving merge conflicts between 20+ feature branches that had been developed in isolation for 3 weeks each. A re-architecture team was brought in. They migrated to GitHub Flow + feature flags in 8 weeks and tracked the before/after metrics over 6 months.

```bash
# Before migration — the integration sprint reality:
# Release branch created: 22 feature branches to merge
# Each merge: average 4.3 conflicts
# Total integration work: ~94 conflict resolutions over 2.5 days
# Integration failures (post-release bugs): 3.2 per release

# After migration — first 6 months:
# Average PR cycle time: 0.9 days (was 8.4 days)
# Average PR size: 212 lines (was 847 lines)
# Merge conflicts: 1.1 per week total (was 94 per release cycle = ~31/week)
# Integration failures: 0.3 per week (was 3.2 per 3-week cycle = ~1.07/week)
# Deploy frequency: 4.2× per week (was 0.3× per week)

# The technical migration path they used:
# Week 1-2: Branch protection rules + PR templates
# Week 3-4: Feature flag infrastructure
# Week 5-6: Migrate in-progress features to flag-gated main commits
# Week 7-8: Retire develop branch, retire Gitflow automation scripts

# The hardest part wasn't technical — it was cultural:
# Engineers had to ship "incomplete" features hidden behind flags
# Managers had to trust that "merged to main" didn't mean "live for users"
# The first feature flag rollout required a 1-hour team demo before people trusted it
```

*The key insight: the migration's biggest lesson was that Gitflow's long-lived branches weren't protecting product quality — they were delaying the discovery of integration problems until the worst possible moment (the day before release). GitHub Flow surfaces those same problems on day 1, when they're cheap to fix. The workflow doesn't create quality; it determines when you pay for lack of it.*

---

## Common Misconceptions

**"The branching strategy is a developer preference"**
The branching strategy is an organisational decision that affects deployment frequency, incident response time, and product velocity. It's coupled to your CI/CD pipeline, your feature flagging capabilities, and your team's communication patterns. A development team choosing their branching strategy without input from DevOps and product is making an incomplete decision.

**"More branches = more control"**
More branches = more surface area for divergence. Each additional long-lived branch is a bet that the divergence cost will be lower than the isolation benefit. For release branches (maintaining v2.x while building v3.x), that bet is correct. For feature branches open for 3 weeks, it's almost always incorrect — the isolation benefits could have been achieved with a feature flag at a fraction of the integration cost.

**"Trunk-based is only for small teams"**
Google, Facebook, and Microsoft use trunk-based development at thousands of engineers. The mechanism that makes it scale is the same at any team size: small, frequent commits; fast CI; feature flags for isolation. What changes at scale is the sophistication of the feature flagging infrastructure (LaunchDarkly, Unleash, etc.) — not the branching strategy itself.

---

## Gotchas

- **Gitflow's back-merge from hotfix to develop is skipped under pressure.** Every team that uses Gitflow has reintroduced a production bug this way. Automate it or add it to your definition of done for every hotfix.

- **"Short-lived branches" in trunk-based requires actual fast CI.** If your pipeline takes 40 minutes, nobody merges daily. Trunk-based development without fast CI is just undisciplined Gitflow with good intentions.

- **Branch protection rules are the strategy's only enforcement mechanism.** A branching strategy documented in a README but not enforced via required reviews and status checks erodes under deadline pressure within weeks.

- **Release branches in Gitflow are for hardening only — no new features.** Teams that add last-minute features to a release branch and then forget to merge them back to develop create permanent divergence that shows up as "we fixed this but it came back" bugs months later.

- **Environment branches (staging, production) are an anti-pattern.** Having separate branches for environments means your codebase diverges from what's actually deployed. Use deployment pipelines and configuration management instead — the same code should be promotable through environments.

---

## Interview Angle

**What they're really testing:** Whether you understand that a branching strategy is a deployment and integration policy, not a naming convention.

**Common question forms:**
- "How would you set up branching for a team of 8 engineers?"
- "What branching strategy does your current team use and why?"
- "How would you handle a 6-week feature in a trunk-based workflow?"

**The depth signal:** A junior describes the branch types. A senior explains the coupling between branching strategy and deployment model — specifically, that Gitflow's release branches exist to delay integration, which is incompatible with continuous deployment, and that trunk-based development requires fast CI and feature flags because those two things replace the isolation that long-lived branches provide. They also know the DORA correlation between trunk-based and elite performance.

**Follow-up questions to expect:**
- "What's the downside of trunk-based development?"
- "How do you handle a situation where two engineers are working on the same file in a trunk-based workflow?"

---

## Related Topics

- [git-workflows.md](git-workflows.md) — Workflows describe the full process (PR, review, merge); branching strategy is the branch topology that workflow operates on.
- [git-pull-requests.md](git-pull-requests.md) — PRs enforce the strategy at merge time; PR size and lifetime reflect the health of the strategy.
- [git-merge-conflicts.md](git-merge-conflicts.md) — Long-lived branches are the primary cause of complex merge conflicts; strategy choice determines conflict frequency.
- [github-branch-protection.md](../github/github-branch-protection.md) — Branch protection rules are the mechanism that enforces strategy; without them, the strategy is just documentation.

---

## Source

[Atlassian — Git Branching Strategies](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)

---
*Last updated: 2026-04-24*