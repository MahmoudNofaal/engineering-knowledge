# GitHub CODEOWNERS

> CODEOWNERS is a file that maps file paths to GitHub users or teams — GitHub automatically requests reviews from the appropriate owners whenever a PR touches their files.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A path-to-reviewer mapping that automates PR review assignment |
| **Use when** | Any repo where different people/teams own different parts of the codebase |
| **Avoid when** | Solo repos or tiny teams where everyone reviews everything |
| **Git version** | Not a Git feature — a GitHub platform feature (2017) |
| **Key location** | `.github/CODEOWNERS`, `CODEOWNERS`, or `docs/CODEOWNERS` (checked in this order) |
| **Key commands** | No CLI commands — configured via file, enforced via branch protection |

---

## When To Use It

Use CODEOWNERS in any repo where ownership is meaningful — where some files should require review from specific domain experts regardless of who opens the PR. Without CODEOWNERS, PR reviewers are either manually assigned (error-prone, inconsistent) or auto-assigned by round-robin (ignores expertise). CODEOWNERS combined with "Require review from code owners" in branch protection makes domain expertise a merge requirement, not a suggestion.

---

## Core Concept

CODEOWNERS is a plain text file where each line maps a path pattern to one or more GitHub usernames or team slugs. When a PR touches a file matching a pattern, GitHub automatically adds the corresponding owner(s) as required reviewers. The last matching rule wins — more specific rules override more general ones. If a PR touches files owned by three different teams, all three are requested. CODEOWNERS only has effect when "Require review from code owners" is enabled in branch protection.

---

## Version History

| Year | Feature |
|---|---|
| 2017 | CODEOWNERS introduced by GitHub |
| 2019 | Team CODEOWNERS (`@org/team-name`) support improved |
| 2020 | `CODEOWNERS` validated on PR open — syntax errors shown as warnings |
| 2021 | "Require last push approval" added — code owner must approve after last commit |
| 2022 | CODEOWNERS entries in Rulesets (org-level code owner requirements) |
| 2023 | `CODEOWNERS` syntax highlighting in GitHub web editor |

---

## The Code

**CODEOWNERS syntax**
```
# .github/CODEOWNERS
# Syntax: <pattern> <owner1> [owner2] [...]
# Patterns follow .gitignore rules (glob, **, !, etc.)
# Last matching rule wins

# Global fallback — owns everything not claimed below
*                               @org/platform-team

# Directory ownership
/apps/api/                      @org/backend-team
/apps/frontend/                 @org/frontend-team
/apps/payments/                 @org/payments-team

# Multiple owners — ALL must approve (or one from each, see notes)
/apps/payments/                 @org/payments-team @org/security-team

# Shared libraries
/libs/shared-models/            @org/platform-team
/libs/auth/                     @org/security-team

# Infrastructure requires DevOps
/infra/                         @org/devops-team
/docker-compose*.yml            @org/devops-team
/Dockerfile*                    @org/devops-team

# GitHub config — platform team must approve changes to CI/CD config
/.github/                       @org/platform-team
/.github/workflows/             @org/platform-team

# Security-sensitive files
/SECURITY.md                    @org/security-team
/src/*/Auth*/                   @org/security-team

# Individual ownership (avoid where possible — use teams)
/src/legacy-payment-engine/     @senior-dev-alice

# Negation — exclude specific files from a broader pattern
# (not widely supported — test in your version of GitHub)
```

**Precedence rules — last match wins**
```
# Example CODEOWNERS:
*                    @org/platform-team      # line 1: catch-all
/apps/api/           @org/backend-team       # line 2: api directory
/apps/api/auth/      @org/security-team      # line 3: auth subdirectory

# For a file: apps/api/auth/TokenService.cs
# Line 1 matches: @platform-team
# Line 2 matches: @backend-team  (overrides line 1)
# Line 3 matches: @security-team (overrides line 2)
# Result: @security-team is required reviewer

# For a file: apps/api/OrderService.cs
# Line 1 matches: @platform-team
# Line 2 matches: @backend-team  (overrides line 1)
# Line 3 doesn't match
# Result: @backend-team is required reviewer

# For a file: README.md
# Line 1 matches: @platform-team
# Lines 2, 3 don't match
# Result: @platform-team is required reviewer
```

**Multiple owners — review requirements**
```
# When multiple owners are listed on one line:
/apps/payments/   @org/payments-team @org/security-team

# GitHub requests review from BOTH teams
# Branch protection "Require review from code owners":
# - Needs at least 1 approval from EACH owner entity listed
# - So: 1 from @payments-team AND 1 from @security-team
# - The PR can't merge with only 1 total review

# This is how you enforce "payments changes need security sign-off"
```

**Validating CODEOWNERS syntax**
```bash
# GitHub validates CODEOWNERS when a PR opens
# Errors appear as a warning banner on the PR

# Common errors:
# - Username doesn't exist: @non-existent-user
# - Team doesn't exist: @org/non-existent-team
# - Invalid pattern syntax

# Test locally using GitHub's validator
# (No official CLI tool — use this heuristic approach)
cat .github/CODEOWNERS | while IFS= read -r line; do
  # Skip comments and empty lines
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// }" ]] && continue

  # Extract owner (everything after the first space-separated field)
  owners=$(echo "$line" | awk '{for(i=2;i<=NF;i++) print $i}')

  for owner in $owners; do
    if [[ "$owner" == @* ]]; then
      echo "Check owner: $owner"
    fi
  done
done
```

**CODEOWNERS for a monorepo**
```
# .github/CODEOWNERS for a monorepo with 10 services

# Platform team owns everything unclaimed
*                               @org/platform-team

# ============================================================
# SERVICE OWNERSHIP
# ============================================================
/apps/api/                      @org/backend-team
/apps/worker/                   @org/backend-team
/apps/gateway/                  @org/backend-team @org/security-team
/apps/frontend/                 @org/frontend-team
/apps/mobile/                   @org/mobile-team

# ============================================================
# SHARED LIBRARIES
# ============================================================
/libs/shared-models/            @org/platform-team
/libs/auth/                     @org/security-team
/libs/observability/            @org/platform-team @org/devops-team
/libs/testing/                  @org/quality-team

# ============================================================
# INFRASTRUCTURE & CI
# ============================================================
/infra/                         @org/devops-team
/.github/workflows/             @org/platform-team
/.github/CODEOWNERS             @org/platform-team  # changes to this file itself

# ============================================================
# SECURITY-SENSITIVE (always require security review)
# ============================================================
**/Auth*/                       @org/security-team
**/Security*/                   @org/security-team
**/Crypto*/                     @org/security-team
/SECURITY.md                    @org/security-team
```

---

## Real World Example

A platform engineering team at a fintech company found that payment-related PRs were frequently approved by engineers without payments domain knowledge — reviewers who were technically competent but didn't know the regulatory requirements around transaction data handling. CODEOWNERS + branch protection closed the gap.

```
# Before: payment PRs approved by whoever was available
# After: payment PRs REQUIRE @payments-team AND @compliance-team

# .github/CODEOWNERS excerpt
/apps/payments/                 @org/payments-team @org/compliance-team
/apps/payments/src/Reporting/   @org/payments-team @org/compliance-team @org/finance-team

# Result:
# - /apps/payments/PaymentProcessor.cs: needs 1 from payments-team + 1 from compliance-team
# - /apps/payments/src/Reporting/TxnReport.cs: needs 1 from each of 3 teams
# - A payments engineer alone cannot merge their own payment code
# - A non-payments engineer cannot sneak payment code through

# Audit benefit: every merged payment PR has audit trail showing
# compliance team explicitly approved the change
```

---

## Common Misconceptions

**"CODEOWNERS makes specific people required reviewers"**
CODEOWNERS makes the *owner entity* required — which could be a team. If `@org/backend-team` is the code owner, any member of that team can approve. GitHub doesn't require a specific individual. Using team ownership (not individual `@username`) is strongly preferred: individuals go on vacation, leave companies, or change roles — teams don't have these availability issues.

**"The first matching rule wins"**
The **last** matching rule wins. This is the opposite of most pattern-matching intuition. More specific rules should come **after** more general rules, not before. If you put `/apps/api/auth/ @security-team` before `* @platform-team`, the catch-all overrides the specific rule.

**"CODEOWNERS works without branch protection"**
CODEOWNERS without "Require review from code owners" in branch protection is purely informational — GitHub requests reviews from owners but doesn't enforce them. Any reviewer can approve and the PR can merge. CODEOWNERS is only enforced when branch protection requires code owner reviews.

---

## Gotchas

- **Last match wins, not first.** Put specific rules after general rules. The catch-all `*` should be the first line, not the last.

- **Teams must exist in the GitHub org.** An entry for `@org/non-existent-team` silently fails — GitHub skips it. Validate team names exist when updating CODEOWNERS.

- **Code owners can't approve their own PRs.** If you push code that triggers your own CODEOWNERS entry, GitHub won't let you approve your own PR to satisfy the code owner requirement. Use team ownership to avoid this — another team member can approve.

- **CODEOWNERS doesn't apply to draft PRs by default.** Review requests from CODEOWNERS are triggered when a PR becomes ready for review, not when it's opened as a draft.

- **`**/pattern` matches at any directory depth; `/pattern` anchors to root.** `**/Auth*/` matches `apps/api/Auth/` and `libs/auth/AuthHelper.cs`; `/Auth*/` only matches at repo root.

---

## Interview Angle

**What they're really testing:** Whether you understand how to enforce domain expertise in PR reviews at scale.

**Common question forms:**
- "How do you ensure the right people review the right code?"
- "How does CODEOWNERS work?"
- "Does CODEOWNERS enforce reviews or just suggest reviewers?"

**The depth signal:** A junior knows CODEOWNERS requests reviewers automatically. A senior knows last-match-wins precedence, that enforcement requires branch protection, that team ownership is preferred over individual, the multiple-owners-require-all-approval behaviour, and the gotcha that code owners can't approve their own PRs.

---

## Related Topics

- [github-branch-protection.md](github-branch-protection.md) — "Require review from code owners" is the enforcement mechanism for CODEOWNERS.
- [github-repositories.md](github-repositories.md) — CODEOWNERS lives in the repo; understanding repo structure is prerequisite.
- [github-pull-requests-advanced.md](github-pull-requests-advanced.md) — CODEOWNERS is triggered at PR creation; understanding PR lifecycle matters.

---

## Source

[GitHub Docs — About Code Owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)

---
*Last updated: 2026-04-24*