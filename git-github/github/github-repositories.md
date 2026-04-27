# GitHub Repositories

> A GitHub repository is a Git repository hosted on GitHub with additional platform features: branch protection, issue tracking, access control, webhooks, Actions, and Packages — all configurable per repo.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A hosted Git repo + GitHub platform features (protection, CI, access control) |
| **Use when** | Every project needs one — this is the foundation of all GitHub workflows |
| **Key settings** | Branch protection, default branch, merge strategies, auto-delete, CODEOWNERS |
| **Key features** | Branch protection rules, Rulesets (new), Topics, Environments, Dependabot |
| **Key commands** | `gh repo create`, `gh repo clone`, `gh repo view`, `gh repo edit` |
| **Visibility** | Public / Private / Internal (Enterprise only) |

---

## Core Concept

A GitHub repository extends a bare Git repo with: access control (who can read/write), branch protection rules (what must be true before a branch can be updated), webhooks (events pushed to external systems), Actions (automated workflows), Environments (deployment targets with protection rules), and settings that enforce team conventions. The most impactful settings are branch protection rules — they determine what a PR must satisfy before merging and are the enforcement layer for all team Git workflows.

---

## Version History

| Year | Feature |
|---|---|
| 2008 | GitHub launches — repositories, forks, basic collaboration |
| 2011 | Branch protection rules (required reviews) |
| 2016 | CODEOWNERS file for automatic reviewer assignment |
| 2017 | Required status checks (CI must pass before merge) |
| 2020 | Environments with deployment protection rules |
| 2022 | Repository Rulesets (beta) — more flexible than branch protection |
| 2023 | Repository Rulesets GA; merge queues GA |
| 2024 | Auto-merge, push rulesets for org-wide enforcement |

---

## The Code

**Creating and configuring a repository**
```bash
# Create a new repo via GitHub CLI
gh repo create org/my-service \
  --private \
  --description "Payment processing microservice" \
  --clone

# Clone an existing repo
gh repo clone org/my-service

# View repo settings summary
gh repo view org/my-service

# Edit repo settings
gh repo edit org/my-service \
  --default-branch main \
  --enable-auto-merge \
  --delete-branch-on-merge \
  --enable-squash-merge \
  --disable-merge-commit \
  --disable-rebase-merge
```

**Branch protection rules via GitHub CLI**
```bash
# Configure branch protection on main (requires GitHub API)
gh api repos/org/my-service/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["ci/build","ci/test"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false \
  --field required_conversation_resolution=true

# Verify protection is set
gh api repos/org/my-service/branches/main/protection
```

**Repository Rulesets (modern alternative to branch protection)**
```bash
# Rulesets can be applied to multiple branches/tags via patterns
# and can be set at organisation level (applies to all repos)
# Configure via UI: Settings → Rules → Rulesets → New ruleset

# Key ruleset rules:
# - Require a pull request before merging
# - Require status checks to pass
# - Require signed commits
# - Block force pushes
# - Require linear history
# - Require deployments to succeed

# Via API (more complex — use UI for initial setup):
gh api orgs/my-org/rulesets --method POST \
  --field name="Main branch protection" \
  --field target="branch" \
  --field enforcement="active" \
  --field conditions='{"ref_name":{"include":["refs/heads/main","refs/heads/release/*"],"exclude":[]}}' \
  --field rules='[{"type":"required_linear_history"},{"type":"required_pull_request","parameters":{"required_approving_review_count":1}}]'
```

**Repository secrets and variables**
```bash
# Set a repository secret (encrypted, not visible in logs)
gh secret set DATABASE_URL --body "postgresql://..."
gh secret set API_KEY < /path/to/keyfile

# Set environment-specific secrets (scoped to deployment environment)
gh secret set DATABASE_URL \
  --env production \
  --body "postgresql://prod-server/db"

# Set repository variables (not secrets — visible in logs)
gh variable set APP_ENV --body "production"
gh variable set REGION --body "eu-west-1"

# List all secrets (names only — values never shown)
gh secret list
gh secret list --env production
```

**CODEOWNERS configuration**
```
# .github/CODEOWNERS
# Last matching rule wins

# Default owner for everything
*                           @org/platform-team

# Service ownership
/apps/api/                  @org/backend-team
/apps/frontend/             @org/frontend-team
/apps/payments/             @org/payments-team @org/security-team  # requires both

# Shared library ownership
/libs/                      @org/platform-team

# Infrastructure
/infra/                     @org/devops-team

# GitHub config requires platform team review
/.github/                   @org/platform-team

# Specific files
/SECURITY.md                @org/security-team
/LICENSE                    @org/legal-team
```

**Repository topics and discovery**
```bash
# Add topics for discoverability (via API)
gh api repos/org/my-service/topics \
  --method PUT \
  --field names='["microservice","dotnet","payments","internal"]'

# Search for repos by topic
gh repo list org --topic payments
gh search repos "topic:microservice org:myorg"
```

**Repository Templates**
```bash
# Mark a repo as a template (for creating standardised new repos)
gh repo edit org/service-template --template

# Create a new repo from a template
gh repo create org/new-service \
  --template org/service-template \
  --private \
  --clone
# New repo gets all files, directory structure, and Actions from template
# Does NOT get: issues, PRs, releases, or git history
```

---

## Real World Example

A platform team at a 200-person engineering organisation was spending 2 hours per new service on manual setup: creating the repo, setting branch protection, adding CODEOWNERS, configuring secrets, and wiring up CI. They automated the entire workflow with a template repo and a setup script.

```bash
#!/bin/bash
# scripts/create-service.sh
# Usage: ./create-service.sh <service-name> <team> <description>

SERVICE=$1
TEAM=$2
DESCRIPTION=$3

echo "Creating service: $SERVICE"

# 1. Create from template
gh repo create "myorg/$SERVICE" \
  --template myorg/service-template \
  --private \
  --description "$DESCRIPTION"

# 2. Configure branch protection
gh api "repos/myorg/$SERVICE/branches/main/protection" \
  --method PUT \
  --silent \
  --input - << 'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["CI / build", "CI / test", "CI / security-scan"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON

# 3. Add team access
gh api "repos/myorg/$SERVICE/teams/$TEAM" \
  --method PUT \
  --field permission=push

# 4. Add platform team as admins
gh api "repos/myorg/$SERVICE/teams/platform-team" \
  --method PUT \
  --field permission=admin

# 5. Configure secrets from vault
vault read "secret/services/$SERVICE" | \
  jq -r 'to_entries[] | "\(.key)=\(.value)"' | \
  while IFS='=' read key value; do
    gh secret set "$key" --repo "myorg/$SERVICE" --body "$value"
  done

# 6. Enable Dependabot
gh api "repos/myorg/$SERVICE/vulnerability-alerts" --method PUT --silent
gh api "repos/myorg/$SERVICE/automated-security-fixes" --method PUT --silent

echo "✓ $SERVICE created and configured"
echo "  URL: https://github.com/myorg/$SERVICE"
echo "  Setup time: ~15 seconds (was 2 hours manual)"
```

*The key insight: repository configuration is infrastructure as code. Every manual repository setup is a configuration drift risk — next month's repo will be set up slightly differently. Template repos + automation scripts make every new repo identical to the last, and the configuration is reviewable, version-controlled, and auditable.*

---

## Common Misconceptions

**"Branch protection rules apply to admins"**
By default, branch protection rules can be bypassed by repository admins. `enforce_admins: true` (or "Include administrators" in the UI) makes the rules apply to everyone including admins. Without this, an admin can force-push to main, directly commit, or merge unreviewed PRs — defeating the purpose of the protection rules. Always enable this for teams with compliance requirements.

**"Repository Rulesets replace branch protection rules"**
Repository Rulesets (2022+) are more powerful than branch protection rules — they support organisation-level enforcement, tag rules, and more rule types. However, they're a different system, not a drop-in replacement. Both can coexist; if both are set, the most restrictive combination applies. For new repos, prefer Rulesets; for existing repos with branch protection, migrating is optional.

**"Private repos are invisible to everyone outside the org"**
Private repos are invisible to the public and to non-member users. But within an organisation, visibility depends on the org's base permissions (`read`, `write`, or `none`). If base permissions are `read`, all org members can read all private repos by default. Use "Internal" visibility (GitHub Enterprise) or explicit team-based access to restrict within an org.

---

## Gotchas

- **`enforce_admins: true` must be explicitly set** — the default is false, meaning admins bypass all rules. Always set this for production repos.

- **Branch protection doesn't prevent local commits** — it only enforces rules on push. An admin can still commit directly locally; the protection fires when they try to push.

- **Auto-delete merged branches only deletes PR head branches** — it doesn't delete branches that were merged without a PR or that were the PR target (like `develop` in Gitflow). Configure it accordingly.

- **CODEOWNERS is a best-effort mechanism in some cases** — if all listed owners are not available (e.g., on leave), GitHub still requires a review from one of them. Plan for this with team-based ownership rather than individual ownership.

- **Template repositories copy files but not settings** — branch protection, secrets, Actions variables, and integrations are not copied from the template. This must be scripted separately.

---

## Interview Angle

**What they're really testing:** Whether you've thought about repository governance at scale — not just using Git, but managing many repos consistently and securely.

**Common question forms:**
- "How do you enforce branch protection across an organisation?"
- "What's your repo setup process for a new service?"
- "How do CODEOWNERS work?"

**The depth signal:** A junior knows repos exist and branch protection is a setting. A senior knows `enforce_admins` must be explicit, the difference between branch protection and Rulesets, how to automate repo setup from a template, CODEOWNERS precedence rules (last match wins), and how to scope secrets to environments rather than putting all secrets at the repo level.

---

## Related Topics

- [github-branch-protection.md](github-branch-protection.md) — Deep dive on protection rules and rulesets.
- [github-codeowners.md](github-codeowners.md) — Full CODEOWNERS syntax and precedence rules.
- [github-actions-integration.md](../git/github-actions-integration.md) — Actions are configured at the repo level and triggered by repo events.
- [github-security-features.md](github-security-features.md) — Dependabot, secret scanning, code scanning — all configured per-repo.

---

## Source

[GitHub Docs — About Repositories](https://docs.github.com/en/repositories/creating-and-managing-repositories/about-repositories)

---
*Last updated: 2026-04-24*