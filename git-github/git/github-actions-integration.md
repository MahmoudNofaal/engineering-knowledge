# GitHub Actions Integration

> GitHub Actions is a CI/CD platform built into GitHub that runs automated workflows — defined as YAML files — triggered by repository events like push, pull request, or release.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Event-driven automation platform built into GitHub, using YAML workflow files |
| **Use when** | Automating CI/CD, code quality gates, deployments, and repo maintenance triggered by Git events |
| **Avoid when** | Your org has deep investment in another CI platform or needs specialized on-premise hardware |
| **Version** | Launched October 2018; reusable workflows November 2021; merge queue 2023 |
| **Key location** | `.github/workflows/*.yml` (workflow files) |
| **Key commands** | `gh workflow run`, `gh run list`, `gh run view`, `gh run watch` |

---

## When To Use It

Use GitHub Actions for any automation that should happen in response to Git events: running tests on every PR, building and publishing Docker images on merge to main, deploying to staging when a release branch is created, or enforcing code quality gates before merge. It's the natural choice when your code is already on GitHub because there's no separate CI infrastructure to manage. It becomes a poor fit when your pipelines need significantly more compute than Actions runners provide, require specialized on-premise hardware, or when your organization already has deep investment in a different CI platform (Jenkins, TeamCity, Azure DevOps).

---

## Core Concept

A workflow is a YAML file in `.github/workflows/` that defines: when to run (triggers), what environment to run in (runners), and what to do (jobs and steps). Jobs run in parallel by default; you add `needs:` to make them sequential. Each step either runs a shell command or uses a reusable action (from the marketplace or your own repo). The most important mental model is that every job gets a fresh runner — no state carries over between jobs unless you explicitly pass it through artifacts or caches. Secrets are injected as environment variables from the repository settings, never stored in the YAML.

---

## Version History

| Date | Feature |
|---|---|
| October 2018 | GitHub Actions launched (limited beta) |
| November 2019 | GitHub Actions GA — free minutes for public repos |
| 2020 | `concurrency` control, `environment` protection rules |
| 2021 | Reusable workflows (`workflow_call`) — share pipelines across repos |
| 2021 | OIDC token exchange — cloud auth without long-lived secrets |
| 2022 | Composite actions, `merge_group` trigger |
| 2023 | Merge queue GA, larger runners, GPU runners |
| 2024 | Actions Cache v2 improvements; M1/ARM runners |

*OIDC token exchange (2021) is the most impactful security improvement in Actions history. It allows jobs to authenticate to AWS, Azure, and GCP using a short-lived GitHub-issued token instead of long-lived service account credentials stored as secrets. If your pipelines deploy to cloud services, migrating to OIDC should be a high priority.*

---

## Performance

| Optimization | Before | After | Mechanism |
|---|---|---|---|
| Dependency caching | Full install every run | Skip when `package-lock.json` unchanged | `actions/cache` with lockfile hash |
| Sparse checkout | Full clone | Only needed directories | `sparse-checkout` in `actions/checkout` |
| Conditional jobs | All jobs always | Skip unchanged projects | `paths` filters + `needs` skipping |
| Artifact reuse | Rebuild every job | Build once, share | `actions/upload-artifact` + `download` |
| Concurrency groups | Queue all pushes | Cancel superseded runs | `concurrency:` with `cancel-in-progress: true` |

**Runner minute costs (GitHub-hosted, 2024):**
- Linux: 1× multiplier (cheapest, use by default)
- Windows: 2× multiplier
- macOS: 10× multiplier (expensive — use only when necessary)
- Larger runners (8-core+): 4–12× multiplier

**Benchmark notes:** The #1 CI cost reduction opportunity is dependency caching. A Node.js project with `npm ci` taking 3 minutes per run can be reduced to 15 seconds with proper caching. Second biggest: path-filter triggers — don't run 10 service builds on a change to one service's README.

---

## The Code

**Standard PR validation pipeline**
```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

# Cancel in-progress runs when new commits are pushed to the same PR
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Cache NuGet packages
        uses: actions/cache@v4
        with:
          path: ~/.nuget/packages
          key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj', '**/packages.lock.json') }}
          restore-keys: |
            ${{ runner.os }}-nuget-

      - name: Restore dependencies
        run: dotnet restore

      - name: Build
        run: dotnet build --no-restore --configuration Release

      - name: Test
        run: dotnet test --no-build --configuration Release --logger trx

      - name: Upload test results
        if: always()   # run even if tests fail
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: "**/*.trx"
          retention-days: 7
```

**Sequential jobs with outputs passed between them**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.tag.outputs.value }}
      should-deploy: ${{ steps.check.outputs.deploy }}
    steps:
      - uses: actions/checkout@v4

      - name: Set image tag
        id: tag
        run: echo "value=${{ github.sha }}" >> $GITHUB_OUTPUT

      - name: Check if deployment needed
        id: check
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "deploy=true" >> $GITHUB_OUTPUT
          else
            echo "deploy=false" >> $GITHUB_OUTPUT
          fi

      - name: Build Docker image
        run: docker build -t myapp:${{ steps.tag.outputs.value }} .

  deploy:
    needs: build
    if: needs.build.outputs.should-deploy == 'true'
    runs-on: ubuntu-latest
    environment: production   # requires manual approval if configured
    steps:
      - name: Deploy
        run: echo "Deploying ${{ needs.build.outputs.image-tag }}"
```

**Monorepo — path-filtered per-service pipelines**
```yaml
# .github/workflows/api-ci.yml
on:
  push:
    paths:
      - 'apps/api/**'
      - 'libs/shared-models/**'
      - '.github/workflows/api-ci.yml'
  pull_request:
    paths:
      - 'apps/api/**'
      - 'libs/shared-models/**'

jobs:
  test-api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          # Only materialise what this job needs
          sparse-checkout: |
            apps/api
            libs/shared-models
          sparse-checkout-cone-mode: true
```

**OIDC — cloud auth without long-lived secrets**
```yaml
# Authenticate to AWS without storing AWS credentials as secrets
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write   # required for OIDC
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/GitHubActionsRole
          aws-region: eu-west-1
          # No secrets needed — GitHub issues a short-lived token
          # AWS role trust policy must allow github.com OIDC provider

      - name: Deploy to ECS
        run: aws ecs update-service --cluster prod --service api --force-new-deployment
```

**Matrix strategy — test across versions and OS**
```yaml
jobs:
  test:
    strategy:
      fail-fast: false   # continue other matrix runs even if one fails
      matrix:
        dotnet-version: ['7.0.x', '8.0.x']
        os: [ubuntu-latest, windows-latest]
        exclude:
          - os: windows-latest
            dotnet-version: '7.0.x'   # skip this combination

    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ matrix.dotnet-version }}
      - run: dotnet test
```

**Reusable workflow — share CI pipeline across repos**
```yaml
# .github/workflows/shared-ci.yml (in a central repo)
on:
  workflow_call:
    inputs:
      dotnet-version:
        required: true
        type: string
      run-integration-tests:
        required: false
        type: boolean
        default: false
    secrets:
      NUGET_TOKEN:
        required: true

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ inputs.dotnet-version }}
      - run: dotnet test
      - if: inputs.run-integration-tests
        run: dotnet test --filter "Category=Integration"

---
# In consuming repo — .github/workflows/ci.yml
jobs:
  ci:
    uses: org/central-repo/.github/workflows/shared-ci.yml@main
    with:
      dotnet-version: '8.0.x'
      run-integration-tests: true
    secrets:
      NUGET_TOKEN: ${{ secrets.NUGET_TOKEN }}
```

**Security — pin actions to SHA, not tags**
```yaml
# INSECURE — tag v4 can be silently moved to a malicious commit
- uses: actions/checkout@v4

# SECURE — pinned to an immutable commit SHA
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

# Automate SHA pinning with Dependabot
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    # Dependabot updates pinned SHAs automatically on new releases
```

---

## Real World Example

A fintech startup had 8 microservices in a monorepo. Their initial CI was naive — every push rebuilt all 8 services regardless of what changed. Each CI run took 18 minutes and cost roughly $0.24 in runner minutes. With 40 commits/day across the team, that was $9.60/day or ~$3,500/year in wasted CI compute. After optimisation, each run took 2–4 minutes and only built affected services.

```yaml
# Before: naive pipeline — rebuilds everything on every commit
# .github/workflows/ci.yml (bad version)
jobs:
  build-all:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: dotnet build apps/api
      - run: dotnet build apps/worker
      - run: dotnet build apps/notifications
      - run: dotnet build apps/payments
      - run: dotnet build apps/reporting
      - run: dotnet build apps/auth
      - run: dotnet build apps/gateway
      - run: dotnet build apps/scheduler
      # 18 minutes × 40 commits/day × $0.008/minute = $5.76/day

# After: affected detection + path filters + caching
# .github/workflows/detect-changes.yml
name: Detect Changes
on: [push, pull_request]

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      api: ${{ steps.filter.outputs.api }}
      worker: ${{ steps.filter.outputs.worker }}
      payments: ${{ steps.filter.outputs.payments }}
      # ... etc
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            api:
              - 'apps/api/**'
              - 'libs/shared-models/**'
            worker:
              - 'apps/worker/**'
              - 'libs/shared-models/**'
            payments:
              - 'apps/payments/**'
              - 'libs/shared-models/**'

  build-api:
    needs: changes
    if: needs.changes.outputs.api == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4
        with:
          sparse-checkout: |
            apps/api
            libs/shared-models
      - uses: actions/cache@v4
        with:
          path: ~/.nuget/packages
          key: nuget-api-${{ hashFiles('apps/api/**/*.csproj') }}
      - run: dotnet build apps/api --configuration Release
      - run: dotnet test apps/api

  # ... similar job for each service

# Result:
# Average run time: 2.8 minutes (from 18 minutes)
# Average services built per run: 1.4 (from 8)
# Monthly CI cost: $290 (from $1,728)
# Savings: 83% cost reduction, 84% time reduction
```

*The key insight: CI cost and speed are directly proportional to "how smart is the system about what actually needs to build?" The technical mechanism (path filters + affected detection + sparse checkout + caching) is straightforward. The organisational mechanism — getting teams to maintain the filter configuration as projects evolve — requires ongoing discipline.*

---

## Common Misconceptions

**"A workflow that passes CI means the code is correct"**
CI passing means the code passed the tests that exist. A workflow can pass CI perfectly while introducing a security vulnerability, a performance regression, or a feature that doesn't match the spec — if there are no tests for those things. CI is a bar, not a guarantee. The height of the bar depends entirely on test quality.

**"Secrets stored in GitHub Actions are safe to use in any step"**
Secrets are masked in logs, but can be exfiltrated via a malicious action, a compromised third-party action, or a `run:` step that prints them to an artifact. The threat model for secrets in CI is fundamentally different from secrets on a server. Use OIDC instead of long-lived credentials wherever possible. Pin all third-party actions to SHAs — a tag like `@v4` can be silently moved.

**"Self-hosted runners are free"**
Self-hosted runners don't pay GitHub per-minute fees, but they have real costs: infrastructure (EC2, VMs), maintenance, security patching, scaling, and the engineering time to manage them. For most teams, GitHub-hosted runners are cheaper in total cost of ownership up to medium scale. Evaluate self-hosted runners when: you need specialized hardware, your minute consumption exceeds 10,000+/month, or you have strict data residency requirements.

---

## Gotchas

- **Third-party actions are supply chain risk.** `uses: some-org/some-action@v2` executes arbitrary code in your pipeline with access to your secrets. Pin to SHAs and audit actions before using them. Automate SHA updates with Dependabot.

- **`pull_request` workflows from forks don't get access to secrets.** This is intentional security behaviour — a fork contributor could modify the workflow to exfiltrate secrets. Use `pull_request_target` only if you understand the security implications and add explicit trust checks.

- **Each job starts with a clean runner — no files from previous jobs.** Pass data between jobs using `actions/upload-artifact` + `actions/download-artifact`, or via `outputs:` for small values.

- **Without path filters on a monorepo, every commit triggers every workflow.** One frontend change rebuilds and redeploys your backend. Add `on: push: paths:` filters scoped to each project's directories.

- **Workflow YAML syntax errors fail silently on push.** GitHub shows the error only when you view the Actions tab. Validate locally with `actionlint` before pushing workflow changes: `brew install actionlint && actionlint`.

- **Concurrency groups without `cancel-in-progress` queue all runs.** If 10 commits are pushed rapidly, you queue 10 CI runs. Add `concurrency: { group: ..., cancel-in-progress: true }` to cancel superseded runs and only test the latest.

---

## Interview Angle

**What they're really testing:** Whether you understand CI/CD automation at a practical level — can you set up a reliable, secure, efficient pipeline, or do you just know that CI exists?

**Common question forms:**
- "How would you set up CI/CD for a new microservice?"
- "What do you look for when reviewing a GitHub Actions workflow?"
- "How would you secure your CI pipeline?"

**The depth signal:** A junior can describe a basic push-triggered workflow with checkout, build, and test. A senior explains: the security model (OIDC vs long-lived secrets, SHA pinning vs tag pinning, `pull_request` vs `pull_request_target`), the job isolation model and how to pass data between jobs, path-filter triggering for monorepos, caching strategies, and concurrency controls. They treat CI configuration as production infrastructure requiring the same security scrutiny as application code.

**Follow-up questions to expect:**
- "What's the risk of using `uses: actions/checkout@v4` vs `uses: actions/checkout@<sha>`?"
- "How would you optimize a CI pipeline that's taking 20 minutes?"

---

## Related Topics

- [git-hooks.md](git-hooks.md) — Hooks provide fast local enforcement before code reaches CI; Actions provides authoritative remote enforcement.
- [git-monorepo.md](git-monorepo.md) — Monorepo CI on Actions requires path filters and affected detection; the default "run everything" behavior breaks at monorepo scale.
- [git-submodules.md](git-submodules.md) — Repos with submodules need `actions/checkout` configured with `submodules: recursive`.
- [github-actions-security.md](github-actions-security.md) — Deep dive on Actions security: OIDC, permissions model, secret scanning, and supply chain protection.
- [github-releases.md](github-releases.md) — Release pipelines in Actions — building, tagging, and publishing artifacts triggered by Git tags.

---

## Source

[GitHub Actions Documentation](https://docs.github.com/en/actions)

---
*Last updated: 2026-04-24*