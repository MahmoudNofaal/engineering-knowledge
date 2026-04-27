# GitHub Security Features

> GitHub's built-in security layer: Dependabot (dependency alerts and auto-PRs), secret scanning, code scanning (CodeQL), and security advisories — all configurable per repository.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A suite of automated security tools integrated into the GitHub platform |
| **Key features** | Dependabot alerts, Dependabot auto-PRs, secret scanning, code scanning (CodeQL), private vulnerability reporting |
| **Use when** | Every production repository — these should be enabled by default, not as an afterthought |
| **Free tier** | All features free for public repos; private repos need GitHub Advanced Security (Teams/Enterprise) |
| **Key location** | Settings → Security → Code security and analysis |

---

## Core Concept

GitHub Security features are automated scanners that run on your repository continuously. Dependabot watches your dependency files (`package.json`, `*.csproj`, `Gemfile`) and alerts you when a dependency has a known CVE — optionally opening PRs to upgrade it. Secret scanning watches every push for patterns matching API keys, tokens, and credentials. Code scanning (CodeQL) runs static analysis on your source code to find security vulnerabilities before they reach production. Together they form a continuous security layer that requires minimal setup and no expertise to operate.

---

## The Code

**Enable all security features**
```bash
# Via GitHub CLI — enable all security features on a repo
gh api repos/org/repo/vulnerability-alerts --method PUT          # Dependabot alerts
gh api repos/org/repo/automated-security-fixes --method PUT      # Dependabot auto-PRs

# For private repos (requires GitHub Advanced Security):
# Enable via UI: Settings → Security → Code security and analysis
# Or via API (org-level):
gh api orgs/myorg/security-and-analysis \
  --method PATCH \
  --field advanced_security='{"status":"enabled"}' \
  --field secret_scanning='{"status":"enabled"}' \
  --field secret_scanning_push_protection='{"status":"enabled"}'
```

**Dependabot configuration**
```yaml
# .github/dependabot.yml — controls update scheduling and scope

version: 2
updates:
  # npm dependencies
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "Africa/Cairo"
    open-pull-requests-limit: 5
    reviewers:
      - "org/platform-team"
    labels:
      - "dependencies"
      - "automated"
    # Group minor and patch updates (fewer PRs)
    groups:
      minor-and-patch:
        update-types:
          - "minor"
          - "patch"

  # NuGet (.NET)
  - package-ecosystem: "nuget"
    directory: "/"
    schedule:
      interval: "weekly"
    ignore:
      # Don't auto-update major versions (breaking changes)
      - dependency-name: "*"
        update-types: ["version-update:semver-major"]

  # Docker base images
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"

  # GitHub Actions — pin to SHAs and keep them updated
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

**Code scanning with CodeQL**
```yaml
# .github/workflows/codeql.yml
name: "CodeQL Security Analysis"

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    # Run weekly even without code changes (new vulnerability rules released)
    - cron: "0 2 * * 1"

jobs:
  analyze:
    name: Analyze
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write   # required to upload results

    strategy:
      fail-fast: false
      matrix:
        language: ["csharp", "javascript"]  # all languages in your repo

    steps:
      - uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: ${{ matrix.language }}
          # Use extended query suite for more comprehensive analysis
          queries: security-extended

      - name: Build (required for compiled languages)
        if: matrix.language == 'csharp'
        run: dotnet build --configuration Release

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: "/language:${{ matrix.language }}"
```

**Secret scanning push protection**
```bash
# Push protection: blocks pushes containing secrets BEFORE they reach GitHub
# Enable: Settings → Security → Secret scanning → Push protection

# What it detects (100+ patterns):
# - AWS access keys and secret keys
# - GitHub tokens (PAT, OAuth, GitHub App)
# - Azure credentials
# - Google API keys
# - Stripe API keys
# - Slack webhooks
# - SSH private keys
# - Database connection strings with credentials

# If a secret is detected on push:
# git push origin main
# remote: error: GH013: Repository rule violations found for refs/heads/main.
# remote: - GITHUB PUSH PROTECTION
# remote:   —— GitHub Personal Access Token ——
# remote:    Location: src/config.py:12
# remote:    Commit:   abc1234
# remote:   To push, remove the secrets from your commit or bypass the protection.

# Bypass (with audit trail — use only for false positives):
# GitHub provides a URL to bypass with a justification reason
```

**Security advisories — private vulnerability disclosure**
```bash
# Report a vulnerability privately (before public disclosure)
# Repository → Security → Advisories → Report a vulnerability

# For maintainers: review and triage
# Repository → Security → Advisories → Review submitted reports

# Create a temporary private fork for the fix
# (GitHub creates a private fork where you can develop the fix without disclosure)

# Publish the advisory after fix is deployed
# GitHub assigns CVE numbers automatically for advisories meeting criteria
```

**Viewing security alerts**
```bash
# List Dependabot alerts via CLI
gh api repos/org/repo/dependabot/alerts \
  --jq '.[] | select(.state=="open") | {package: .security_vulnerability.package.name, severity: .security_vulnerability.severity, summary: .security_advisory.summary}'

# List code scanning alerts
gh api repos/org/repo/code-scanning/alerts \
  --jq '.[] | select(.state=="open") | {rule: .rule.id, severity: .rule.severity, location: .most_recent_instance.location.path}'

# List secret scanning alerts
gh api repos/org/repo/secret-scanning/alerts \
  --jq '.[] | select(.state=="open") | {type: .secret_type, url: .html_url}'
```

---

## Common Misconceptions

**"Dependabot PRs are safe to auto-merge"**
Dependabot PRs update dependencies — minor and patch updates are usually safe, but can break things. Always require CI to pass before auto-merge, and consider requiring human review for major version bumps. Auto-merging with `--auto-merge` flag + branch protection (CI required) is the right pattern for minor/patch, not unconditional auto-merge.

**"Secret scanning protects against all credential exposure"**
Secret scanning detects known-pattern credentials on push and in commits. It doesn't detect: credentials in binary files, custom internal token formats not in its database, credentials accidentally logged to stdout (visible in Actions logs), or credentials already committed before scanning was enabled. It's a safety net, not a complete solution.

**"CodeQL finds all security vulnerabilities"**
CodeQL is a static analysis tool — it finds patterns that could indicate vulnerabilities in code paths it can analyse. It can't detect: logic errors that require business domain knowledge, runtime-only vulnerabilities (e.g., environment-specific configuration issues), or vulnerabilities in third-party dependencies (that's Dependabot's job). It's one layer of a security posture, not the complete picture.

---

## Gotchas

- **Dependabot needs read access to all ecosystems in the repo.** If your `.gitmodules` references private repos, Dependabot needs access to them. Configure Dependabot access in Settings → Security → Granted repositories.

- **CodeQL must build compiled languages.** For C#, Java, Go — CodeQL needs to compile the code to analyze it. Your CodeQL workflow must include a build step. Auto-build often works but may fail on complex build setups.

- **Secret scanning doesn't retroactively scan existing commits.** It scans new pushes and the current state of the repo. Secrets that were committed before enabling scanning and then deleted from the latest commit may still be in history. Use `git filter-repo` to remove secrets from history.

- **Push protection can be bypassed by the pusher with a justification.** It creates an audit trail but doesn't absolutely prevent the push. Pair with monitoring (secret scanning alerts → Slack) so bypasses are reviewed.

---

## Related Topics

- [github-repositories.md](github-repositories.md) — Security features are enabled at the repository level.
- [github-actions-advanced.md](github-actions-advanced.md) — CodeQL runs as a GitHub Actions workflow.
- [git-signing-gpg.md](../git/git-signing-gpg.md) — Commit signing is another layer of supply chain security, complementary to secret scanning.

---

## Source

[GitHub Docs — GitHub Security Features](https://docs.github.com/en/code-security/getting-started/github-security-features)

---
*Last updated: 2026-04-24*