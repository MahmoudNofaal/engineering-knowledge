# GitHub Branch Protection

> Branch protection rules (and the newer Repository Rulesets) define conditions that must be met before a branch can be updated — requiring PR reviews, passing CI, signed commits, or linear history.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Server-side enforcement layer that gates what changes can reach protected branches |
| **Use when** | Any shared branch that shouldn't receive direct pushes (main, release/*, develop) |
| **Avoid when** | Solo repos or personal forks where the overhead adds no value |
| **Location** | Settings → Branches (Branch protection) or Settings → Rules → Rulesets |
| **Key rules** | Require PR, Require status checks, Require reviews, Block force push, Require linear history |
| **Two systems** | Branch Protection Rules (classic) vs Repository Rulesets (modern, more powerful) |

---

## Core Concept

Branch protection rules are GitHub's enforcement layer for team conventions — they run on the server and cannot be bypassed by developer tooling (unlike pre-push hooks, which can be skipped with `--no-verify`). The classic Branch Protection Rules are configured per branch name or pattern. Repository Rulesets (2022+) extend this with: organisation-level enforcement across all repos, tag protection, more rule types, bypass lists, and audit logging. Both systems can coexist; the most restrictive combination applies.

---

## Version History

| Year | Feature |
|---|---|
| 2013 | Basic branch protection (prevent direct push) |
| 2015 | Required PR reviews |
| 2017 | Required status checks (CI must pass) |
| 2019 | Dismiss stale reviews on new commits |
| 2021 | Required conversation resolution |
| 2022 | Repository Rulesets beta |
| 2023 | Rulesets GA; require deployments to succeed; merge queue integration |
| 2024 | Organisation-level Rulesets; push rulesets |

---

## The Code

**Branch Protection Rules — key settings**
```yaml
# Via GitHub UI: Settings → Branches → Add rule
# Pattern: main (or release/*, develop, etc.)

# Essential settings for most teams:
Require a pull request before merging: ✅
  Required approving reviews: 1
  Dismiss stale pull request approvals when new commits are pushed: ✅
  Require review from code owners: ✅ (if CODEOWNERS exists)

Require status checks to pass before merging: ✅
  Require branches to be up to date before merging: ✅ (strict mode)
  Status checks: [CI / build, CI / test]  ← exact names from your Actions

Require conversation resolution before merging: ✅
Require signed commits: ✅ (if team uses signing)
Require linear history: ✅ (forces squash or rebase merge only)
Include administrators: ✅ (critical — without this, admins bypass all rules)
Allow force pushes: ❌
Allow deletions: ❌
```

**Configure via GitHub API**
```bash
# Set comprehensive branch protection via API
gh api repos/org/repo/branches/main/protection \
  --method PUT \
  --input - << 'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["CI / build", "CI / test", "CI / security-scan"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismissal_restrictions": {},
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1,
    "require_last_push_approval": true
  },
  "required_conversation_resolution": true,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": true,
  "lock_branch": false
}
EOF

# Check current protection
gh api repos/org/repo/branches/main/protection
```

**Repository Rulesets — modern approach**
```bash
# Rulesets support:
# - Multiple branch patterns in one ruleset
# - Organisation-level (applies to all org repos)
# - Bypass lists (specific actors who can skip the rules)
# - Tag rules
# - Audit log for all ruleset evaluations

# Create an org-level ruleset via API
gh api orgs/my-org/rulesets --method POST \
  --input - << 'EOF'
{
  "name": "Production branch protection",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "Team",
      "bypass_mode": "always"
    }
  ],
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main", "refs/heads/release/*"],
      "exclude": []
    }
  },
  "rules": [
    {"type": "required_linear_history"},
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {
      "type": "required_pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {"context": "CI / build"},
          {"context": "CI / test"}
        ]
      }
    }
  ]
}
EOF
```

**Terraform — infrastructure as code for branch protection**
```hcl
# terraform/github.tf
resource "github_branch_protection" "main" {
  repository_id = github_repository.service.node_id
  pattern       = "main"

  required_status_checks {
    strict   = true
    contexts = ["CI / build", "CI / test", "CI / security-scan"]
  }

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
    require_last_push_approval      = true
  }

  required_linear_history = true
  enforce_admins          = true
  allows_force_pushes     = false
  allows_deletions        = false
  require_conversation_resolution = true
}

resource "github_branch_protection" "release" {
  repository_id = github_repository.service.node_id
  pattern       = "release/*"

  required_status_checks {
    strict   = true
    contexts = ["CI / build", "CI / test"]
  }

  required_pull_request_reviews {
    required_approving_review_count = 2  # release branches require 2 reviews
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
  }

  enforce_admins      = true
  allows_force_pushes = false
  allows_deletions    = false
}
```

---

## Real World Example

A regulated fintech company needed SOC 2 compliance requiring audit evidence that all production changes went through: peer review, automated testing, and security scanning before deployment. They implemented branch protection + Rulesets + deployment environments to create a complete audit trail.

```bash
# SOC 2 compliant GitHub setup:

# 1. Branch protection on main with all guards
# (configured via Terraform — see above)

# 2. Deployment environment with manual approval
# Settings → Environments → production → Required reviewers: [security-team]

# 3. CI/CD pipeline that gates deployment
# .github/workflows/deploy.yml
on:
  push:
    branches: [main]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: SAST scan
        uses: github/codeql-action/analyze@v3

  deploy:
    needs: [build, test, security-scan]
    environment: production   # requires manual approval from security-team
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to production
        run: ./scripts/deploy.sh

# 4. Audit evidence collection
# GitHub provides: PR review records, status check results, deployment logs
# All linked by commit SHA — auditor can trace: commit → PR → reviews → CI → deployment

# Evidence query for auditor:
gh api repos/org/service/deployments \
  --jq '.[] | {sha: .sha, environment: .environment, creator: .creator.login, created_at: .created_at}'
```

---

## Common Misconceptions

**"Branch protection applies to everyone including admins"**
By default, repository admins can bypass branch protection rules. You must explicitly check "Include administrators" (or set `enforce_admins: true` via API) to make rules apply to admins. Without this, any admin can force-push, directly commit, or merge without review — completely defeating compliance controls.

**"Required status checks automatically know which checks to require"**
You must explicitly list the status check names (e.g., "CI / build", "CI / test") in the protection rule. If you don't add them, the rule won't enforce CI. Also important: the check name must match exactly — including capitalisation and the workflow name. A common mistake is requiring "build" when the actual check is "CI / build".

**"Rulesets replace branch protection rules"**
They're two separate systems. Both can be active simultaneously; the most restrictive combination applies. Old repos typically use branch protection rules; new repos can start with Rulesets for their additional capabilities. There's no migration path that converts one to the other — if you want to switch, you configure Rulesets and manually remove the old branch protection rules.

---

## Gotchas

- **`strict: true` in required status checks means the branch must be up to date.** Without strict mode, a PR can pass CI on its own but fail after merging because main moved. With strict mode, GitHub requires a rebase/update before merging — adds friction but prevents "merged and broke main."

- **Status check names are case-sensitive and must match exactly.** If your Actions workflow has `name: CI` and a job named `build`, the status check name is "CI / build". If you protect against "ci/build" or "CI/Build", it won't match.

- **Branch protection pattern `release/*` does NOT match `release/v1.0.0/patch`.** The `*` glob doesn't cross `/`. Use `release/**` to match nested paths.

- **Required reviewers can block their own PR from merging.** If a code owner is required for review but their own code changes trigger their CODEOWNERS entry, they can't review their own PR. Design CODEOWNERS to use team ownership (not individual) to avoid this.

---

## Interview Angle

**What they're really testing:** Whether you understand how branch protection works as the enforcement layer for team conventions — and the gaps in the default configuration.

**Common question forms:**
- "How do you enforce that all PRs must be reviewed before merging?"
- "Can a repo admin bypass branch protection?"
- "What's the difference between branch protection rules and Repository Rulesets?"

**The depth signal:** A junior knows branch protection prevents direct pushes. A senior knows `enforce_admins` must be explicit, strict vs non-strict status checks, exact status check naming requirements, and the difference between Branch Protection Rules (per-repo, classic) and Rulesets (org-level, modern, bypass lists, audit logging).

---

## Related Topics

- [github-repositories.md](github-repositories.md) — Branch protection is configured at the repository level.
- [github-codeowners.md](github-codeowners.md) — CODEOWNERS + "require code owner review" work together.
- [github-actions-integration.md](../git/github-actions-integration.md) — Actions provide the status checks that branch protection enforces.
- [github-pull-requests-advanced.md](github-pull-requests-advanced.md) — Branch protection determines what a PR must satisfy before it can merge.

---

## Source

[GitHub Docs — About Protected Branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)

---
*Last updated: 2026-04-24*