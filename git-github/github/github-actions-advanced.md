# GitHub Actions (Advanced)

> Advanced GitHub Actions patterns: reusable workflows, composite actions, OIDC authentication, merge queues, self-hosted runners, and environment protection rules.

---

## Quick Reference

| | |
|---|---|
| **What it is** | The advanced layer of GitHub Actions beyond basic push-triggered CI |
| **Key patterns** | Reusable workflows, composite actions, OIDC cloud auth, matrix strategies, environment gates |
| **Use when** | Sharing CI/CD logic across repos, deploying to cloud without long-lived secrets, multi-stage pipelines |
| **Key features** | `workflow_call`, `workflow_dispatch`, OIDC, environments, merge queue, self-hosted runners |
| **Pricing** | Free for public repos; minutes-based for private (Linux 1×, Windows 2×, macOS 10×) |

---

## Core Concept

Beyond basic CI, GitHub Actions supports: reusable workflows (share an entire pipeline across repos via `workflow_call`), composite actions (bundle multiple steps into a reusable action), OIDC token exchange (authenticate to cloud providers without storing credentials), environment protection rules (require manual approval or deployment branch restrictions), and merge queues (prevent "merged but broke main" by testing the combined result before merging). These patterns are what separate "GitHub Actions as a YAML file" from "GitHub Actions as a CI/CD platform."

---

## The Code

**Reusable workflows — share an entire pipeline**
```yaml
# .github/workflows/shared-dotnet-ci.yml (in a "central-workflows" repo)
name: Shared .NET CI

on:
  workflow_call:
    inputs:
      dotnet-version:
        required: true
        type: string
        description: ".NET SDK version to use"
      run-integration-tests:
        required: false
        type: boolean
        default: false
      solution-path:
        required: false
        type: string
        default: "."
    secrets:
      NUGET_TOKEN:
        required: false
        description: "NuGet feed token (required for private packages)"
    outputs:
      artifact-name:
        description: "Name of the published artifact"
        value: ${{ jobs.build.outputs.artifact-name }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      artifact-name: ${{ steps.artifact.outputs.name }}
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4

      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ inputs.dotnet-version }}

      - name: Add private NuGet feed
        if: secrets.NUGET_TOKEN != ''
        run: dotnet nuget add source $NUGET_URL --username github --password ${{ secrets.NUGET_TOKEN }}

      - name: Restore and build
        run: |
          dotnet restore ${{ inputs.solution-path }}
          dotnet build --no-restore --configuration Release ${{ inputs.solution-path }}

      - name: Run unit tests
        run: dotnet test --no-build --configuration Release --filter "Category!=Integration"

      - name: Run integration tests
        if: inputs.run-integration-tests
        run: dotnet test --no-build --configuration Release --filter "Category=Integration"

      - name: Publish artifact
        id: artifact
        run: |
          NAME="build-$(echo ${{ github.sha }} | cut -c1-8)"
          dotnet publish --no-build --configuration Release -o ./publish
          echo "name=$NAME" >> $GITHUB_OUTPUT

      - uses: actions/upload-artifact@v4
        with:
          name: ${{ steps.artifact.outputs.name }}
          path: ./publish/

---
# In a consuming service repo: .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  ci:
    uses: myorg/central-workflows/.github/workflows/shared-dotnet-ci.yml@main
    with:
      dotnet-version: "8.0.x"
      run-integration-tests: ${{ github.ref == 'refs/heads/main' }}
    secrets:
      NUGET_TOKEN: ${{ secrets.NUGET_TOKEN }}
```

**Composite actions — bundle multiple steps**
```yaml
# .github/actions/setup-dotnet-env/action.yml
# A composite action is a local or published action that runs multiple steps
name: "Setup .NET Environment"
description: "Set up .NET with caching and private feeds"

inputs:
  dotnet-version:
    required: true
  nuget-token:
    required: false
    default: ""

outputs:
  cache-hit:
    description: "Whether the NuGet cache was hit"
    value: ${{ steps.cache.outputs.cache-hit }}

runs:
  using: "composite"
  steps:
    - uses: actions/setup-dotnet@v4
      with:
        dotnet-version: ${{ inputs.dotnet-version }}

    - id: cache
      uses: actions/cache@v4
      with:
        path: ~/.nuget/packages
        key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj') }}
        restore-keys: ${{ runner.os }}-nuget-

    - name: Add private NuGet source
      if: inputs.nuget-token != ''
      shell: bash
      run: |
        dotnet nuget add source "https://nuget.pkg.github.com/${{ github.repository_owner }}/index.json" \
          --name github \
          --username ${{ github.actor }} \
          --password ${{ inputs.nuget-token }} \
          --store-password-in-clear-text

---
# Using the composite action in a workflow
steps:
  - uses: actions/checkout@v4
  - uses: ./.github/actions/setup-dotnet-env
    with:
      dotnet-version: "8.0.x"
      nuget-token: ${{ secrets.NUGET_TOKEN }}
```

**OIDC — cloud authentication without secrets**
```yaml
# Authenticate to AWS using GitHub's OIDC token (no AWS credentials stored)
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write    # REQUIRED for OIDC
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: eu-west-1
          # GitHub exchanges its OIDC token for temporary AWS credentials
          # No AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY needed

      - name: Deploy to ECS
        run: aws ecs update-service --cluster prod --service api --force-new-deployment

---
# AWS IAM role trust policy (set up once in AWS):
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:*"
        }
      }
    }
  ]
}
```

**Environment protection rules**
```yaml
# Environments add approval gates and deployment tracking
# Configure: Settings → Environments → production

# In workflow: reference the environment
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.myapp.com  # shown in GitHub deployment tracking
    steps:
      - run: ./deploy.sh staging

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment:
      name: production    # configured with required reviewers
      url: https://myapp.com
    # GitHub pauses here and waits for manual approval from required reviewers
    steps:
      - run: ./deploy.sh production

---
# Configure environment via API
gh api repos/org/repo/environments/production \
  --method PUT \
  --field wait_timer=10 \  # wait 10 minutes before allowing deployment
  --field reviewers='[{"type":"Team","id":12345}]' \
  --field deployment_branch_policy='{"protected_branches":true,"custom_branch_policies":false}'
```

**Merge queue configuration**
```yaml
# Merge queue: PRs are tested together before merging
# Prevents: "passed CI individually but broke when combined"
# Configure: Settings → Branches → main → Require merge queue

# Workflow that runs on merge queue (not just PR)
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  merge_group:              # ← runs when PR enters merge queue
    types: [checks_requested]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: dotnet test
```

**Self-hosted runners**
```yaml
# Register a self-hosted runner (run on your own infrastructure)
# 1. Settings → Actions → Runners → New self-hosted runner
# 2. Follow instructions to download and configure the runner agent
# 3. Start the runner: ./run.sh

# Use a self-hosted runner in a workflow
jobs:
  build-on-premise:
    runs-on: [self-hosted, linux, x64, gpu]  # label-based matching
    steps:
      - uses: actions/checkout@v4
      - name: Run GPU training
        run: python train.py --device cuda

# Auto-scaling self-hosted runners with GitHub Actions Runner Controller (ARC)
# Deploy to Kubernetes:
# helm install arc \
#   --namespace arc-systems \
#   oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

# Scale set definition:
# runners scale from 0 to N based on queue depth automatically
```

**Advanced matrix with strategy**
```yaml
jobs:
  test:
    strategy:
      fail-fast: false
      max-parallel: 4
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        dotnet: ["7.0.x", "8.0.x"]
        include:
          # Add extra variable for a specific combination
          - os: ubuntu-latest
            dotnet: "8.0.x"
            run-coverage: true
        exclude:
          # Skip macOS + .NET 7 (not needed)
          - os: macos-latest
            dotnet: "7.0.x"

    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ matrix.dotnet }}
      - run: dotnet test
      - name: Generate coverage
        if: matrix.run-coverage
        run: dotnet test --collect:"XPlat Code Coverage"
```

---

## Real World Example

A platform team managing CI/CD for 40 microservices was copy-pasting the same 200-line workflow YAML into each repo. When the team wanted to add a security scan step to all pipelines, they had to update 40 repos individually. After migrating to a reusable workflow pattern, adding a step became a one-line change in one place.

```yaml
# central-workflows repo: .github/workflows/dotnet-service-ci.yml
# This ONE file serves 40 services

on:
  workflow_call:
    inputs:
      service-name:
        required: true
        type: string
      dotnet-version:
        required: false
        type: string
        default: "8.0.x"
      deploy-environment:
        required: false
        type: string
        default: "none"
    secrets:
      DEPLOY_TOKEN:
        required: false

jobs:
  ci:
    uses: myorg/central-workflows/.github/workflows/shared-dotnet-ci.yml@main
    with:
      dotnet-version: ${{ inputs.dotnet-version }}

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: github/codeql-action/init@v3
        with:
          languages: csharp
      - uses: github/codeql-action/analyze@v3
      # Adding this step here = added to ALL 40 services automatically

  deploy:
    if: inputs.deploy-environment != 'none' && github.ref == 'refs/heads/main'
    needs: [ci, security-scan]
    uses: myorg/central-workflows/.github/workflows/deploy-service.yml@main
    with:
      environment: ${{ inputs.deploy-environment }}
      service-name: ${{ inputs.service-name }}
    secrets:
      DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}

---
# Each of the 40 services: .github/workflows/ci.yml (8 lines instead of 200)
name: CI/CD
on: [push, pull_request]

jobs:
  pipeline:
    uses: myorg/central-workflows/.github/workflows/dotnet-service-ci.yml@main
    with:
      service-name: "payment-service"
      deploy-environment: "production"
    secrets:
      DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}

# Result: security scan step added to 40 services in 1 commit to central-workflows
```

---

## Common Misconceptions

**"Self-hosted runners are free"**
Self-hosted runners don't pay GitHub per-minute fees, but have real costs: EC2/VM infrastructure, maintenance, security patching, and engineering time to manage them. For most teams, GitHub-hosted runners are cheaper in total cost of ownership. Self-hosted runners make sense when: you need specialized hardware (GPUs, ARM), strict data residency, or your minute consumption is so high that infrastructure costs are lower than GitHub's per-minute rate.

**"Reusable workflows and composite actions are the same"**
A reusable workflow is a complete workflow file called from another workflow — it runs in its own context with its own jobs and runners. A composite action is a bundle of steps that run in the calling job's runner context. Use reusable workflows for complete pipelines; use composite actions for bundling frequently-used setup steps.

**"OIDC is just another way to store credentials"**
OIDC doesn't store credentials at all. GitHub issues a short-lived cryptographically signed token that your cloud provider accepts in exchange for temporary credentials valid for the duration of the job (typically 1 hour). There's nothing to rotate, nothing to leak, and nothing to manage. The only setup is the cloud provider's OIDC trust policy — done once.

---

## Gotchas

- **`workflow_call` inputs are strings by default.** Boolean inputs must be explicitly typed as `type: boolean`. Passing `"true"` (a string) to a `type: string` input and then doing `if: inputs.some-flag` evaluates as truthy (non-empty string), but passing `true` (boolean) to a `type: string` input coerces incorrectly. Type your inputs explicitly.

- **OIDC requires `permissions: id-token: write` in the job.** Without this explicit permission, the OIDC token is not issued and cloud authentication fails with a cryptic error. This is not the default — it must be set.

- **Merge queue uses `merge_group` trigger, not `push`.** If your CI only runs on `push` and `pull_request`, it won't run in the merge queue. Add `merge_group: types: [checks_requested]` to ensure CI runs on queue entries.

- **Environment secrets are not available to PRs from forks by default.** Production deployment environments with `protected_branches: true` only allow deployments from protected branches — fork PRs can't trigger them. This is correct security behaviour.

- **Composite actions don't support `uses:` at the step level for other actions in some configurations.** Composite actions can use `uses:` steps, but there are limitations with certain action types. Always test composite actions in a real workflow before publishing.

---

## Interview Angle

**What they're really testing:** Whether you can design CI/CD at scale — beyond one-repo workflows to shared infrastructure that serves many teams.

**Common question forms:**
- "How do you share CI configuration across multiple repositories?"
- "How do you deploy to production without storing cloud credentials in GitHub?"
- "What's a reusable workflow vs a composite action?"

**The depth signal:** A junior knows basic workflow syntax. A senior designs reusable workflows to centralise CI logic, uses OIDC instead of stored credentials, understands environment protection rules for deployment gates, knows the merge queue solves the "merged but broke main" problem, and can explain the operational model for self-hosted runners including their real costs.

---

## Related Topics

- [github-actions-integration.md](../git/github-actions-integration.md) — Foundational Actions concepts (triggers, jobs, steps, caching).
- [github-actions-security.md](github-actions-security.md) — SHA pinning, permissions model, secret scanning, supply chain.
- [github-releases.md](github-releases.md) — Release automation via Actions — the `on: push: tags:` trigger pattern.
- [github-branch-protection.md](github-branch-protection.md) — Status checks from Actions are enforced via branch protection.

---

## Source

[GitHub Actions — Reusing Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)

---
*Last updated: 2026-04-24*