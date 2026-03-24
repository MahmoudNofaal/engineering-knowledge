# Branching Strategy

> A branching strategy defines what branches exist in a repo, what purpose each serves, how long they live, and where they merge.

---

## When To Use It

Every repo that has more than one person committing to it needs an explicit branching strategy — even if that strategy is "we all commit to main." The strategy becomes load-bearing once you need to hotfix a production issue while a half-finished feature is in progress, or when two engineers are working on conflicting areas simultaneously. Without a defined strategy, these situations get resolved inconsistently every time.

---

## Core Concept

A branching strategy is really an answer to four questions: Where does production-ready code live? Where does in-progress work live? How does work get promoted between those places? And what happens when something is broken in production right now? The answers produce your branch model. Trunk-based says: one branch, promote via feature flags, deploy fast. Gitflow says: separate development and release concerns with long-lived branches. GitHub Flow is in the middle: short-lived feature branches off main, merged frequently. The right answer depends on your deployment model — not on what looks cleanest on a diagram.

---

## The Code
```bash
# ── Trunk-Based: minimal branch structure ───────────────────────────

main                        # always deployable
  └── feat/short-lived      # lives max 1-2 days, then deleted after merge

# Feature flag example (C# — hides unfinished work on main)
if (_featureFlags.IsEnabled("new-payment-flow", userId))
{
    return await _newPaymentService.ProcessAsync(order);
}
return await _legacyPaymentService.ProcessAsync(order);
```
```bash
# ── GitHub Flow: branch structure + lifecycle ────────────────────────

main                            # protected, always deployable
  └── feat/user-profile-v2      # branch off main
  └── fix/checkout-null-ref     # branch off main
  └── chore/upgrade-dotnet8     # branch off main

# All branches merge back to main via PR, then are deleted
# No develop branch. No release branch (unless tagging releases).
```
```bash
# ── Gitflow: full branch map ─────────────────────────────────────────

main                            # production-only, tagged on release
develop                         # integration branch
  └── feature/stripe-webhooks   # branches off develop
  └── feature/email-templates   # branches off develop
release/2.3.0                   # branches off develop, merges to main + develop
hotfix/fix-payment-crash         # branches off main, merges to main + develop

# Creating a hotfix correctly in Gitflow:
git checkout -b hotfix/fix-payment-crash main
# ... fix the bug ...
git checkout main
git merge --no-ff hotfix/fix-payment-crash
git tag -a v2.2.1
git checkout develop
git merge --no-ff hotfix/fix-payment-crash   # ← this step is always forgotten
git branch -d hotfix/fix-payment-crash
```
```bash
# ── Branch naming convention (enforce via CI or pre-push hook) ───────

# Pattern: <type>/<short-description>
feat/add-oauth-login
fix/null-ref-in-cart
chore/remove-deprecated-api
release/3.1.0
hotfix/session-expiry-crash

# Pre-push hook to enforce pattern (.git/hooks/pre-push)
#!/bin/bash
branch=$(git rev-parse --abbrev-ref HEAD)
pattern='^(feat|fix|chore|release|hotfix)/.+'
if ! [[ $branch =~ $pattern ]]; then
  echo "Branch name '$branch' doesn't match required pattern."
  exit 1
fi
```

---

## Gotchas

- **Gitflow's back-merge from hotfix to develop is skipped under pressure.** Every team that uses Gitflow has reintroduced a production bug this way. The merge to `develop` after a hotfix is not optional.
- **"Short-lived branches" in trunk-based requires actual CI speed.** If your pipeline takes 40 minutes, nobody merges daily. The branch strategy and the build speed are coupled — committing to trunk-based without fast CI just means undisciplined long-lived branches with a different name.
- **Branch protection rules are the strategy's enforcement mechanism.** A strategy documented in a README but not enforced via required reviews and status checks is just a suggestion that erodes under deadline pressure.
- **Release branches in Gitflow are for hardening only — no new features.** Teams that add last-minute features to a release branch and then forget to merge them back to develop create permanent divergence.
- **Deleting merged branches is mandatory, not optional.** Stale branches in a busy repo add noise to `git branch -r` and create ambiguity about what's still in flight. Automate deletion on merge.

---

## Interview Angle

**What they're really testing:** Whether you understand that a branching strategy is a deployment and integration policy, not just a naming convention.

**Common question form:** "What branching strategy do you use and why?" or "How would you set up branching for a team of 8 engineers?"

**The depth signal:** A junior describes the branch types. A senior explains the coupling between branching strategy and deployment model — specifically, that Gitflow's release branches exist to delay integration, which is incompatible with continuous deployment, and that trunk-based development only works if you have fast CI and a feature flag system, because those two things replace the isolation that long-lived branches provide.

---

## Related Topics

- [[git/git-workflows.md]] — Workflows describe the full process (PR, review, merge); branching strategy is specifically the branch topology that workflow sits on top of.
- [[git/git-pull-requests.md]] — PRs are the gate between branches; the branching strategy defines what the source and target of every PR should be.
- [[git/git-merge-conflicts.md]] — Long-lived branches with many diverged commits are the primary cause of complex merge conflicts.
- [[devops/ci-cd-pipelines.md]] — Your CI pipeline must be configured per-branch; branch strategy and pipeline triggers are tightly coupled.

---

## Source

[Atlassian — Git Branching Strategies](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)

---
*Last updated: 2026-03-24*