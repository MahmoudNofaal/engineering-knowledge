# GitHub Actions Integration

> GitHub Actions is a CI/CD platform built into GitHub that runs automated workflows — defined as YAML files — triggered by repository events like push, pull request, or release.

---

## When To Use It

Use GitHub Actions for any automation that should happen in response to Git events: running tests on every PR, building and publishing Docker images on merge to main, deploying to staging when a release branch is created, or enforcing code quality gates before merge. It's the natural choice when your code is already on GitHub because there's no separate CI infrastructure to manage. It becomes a poor fit when your pipelines need significantly more compute than Actions runners provide, require specialized on-premise hardware, or when your organization already has deep investment in a different CI platform (Jenkins, TeamCity, Azure DevOps).

---

## Core Concept

A workflow is a YAML file in `.github/workflows/` that defines: when to run (triggers), what environment to run in (runners), and what to do (jobs and steps). Jobs run in parallel by default; you add `needs:` to make them sequential. Each step either runs a shell command or uses a reusable action (from the marketplace or your own repo). The most important mental model is that every job gets a fresh runner — no state carries over between jobs unless you explicitly pass it through artifacts or caches. Secrets are injected as environment variables from the repository settings, never stored in the YAML.

---

## The Code
```yaml
# ── .github/workflows/ci.yml — Standard PR validation pipeline ───────
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Restore dependencies
        run: dotnet restore

      - name: Build
        run: dotnet build --no-restore --configuration Release

      - name: Test
        run: dotnet test --no-build --configuration Release --logger trx

      - name: Upload test results
        if: always()                     # run even if tests fail
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: "**/*.trx"
```
```yaml
# ── Dependency caching (avoids re-downloading packages every run) ─────
      - name: Cache NuGet packages
        uses: actions/cache@v4
        with:
          path: ~/.nuget/packages
          key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj') }}
          restore-keys: |
            ${{ runner.os }}-nuget-
```
```yaml
# ── Monorepo: only run when relevant paths change ─────────────────────
on:
  push:
    paths:
      - 'apps/api/**'
      - 'libs/shared-models/**'
      - '.github/workflows/api-ci.yml'
```
```yaml
# ── Sequential jobs with dependency + passing values between jobs ─────
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.tag.outputs.value }}
    steps:
      - id: tag
        run: echo "value=${{ github.sha }}" >> $GITHUB_OUTPUT

  deploy:
    needs: build                         # waits for build to succeed
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying ${{ needs.build.outputs.image-tag }}"
```
```yaml
# ── Using secrets + environment protection rules ──────────────────────
jobs:
  deploy-production:
    runs-on: ubuntu-latest
    environment: production              # requires manual approval if configured
    steps:
      - name: Deploy
        env:
          API_KEY: ${{ secrets.PROD_API_KEY }}     # from repo/org secrets
          CONNECTION_STRING: ${{ secrets.PROD_DB_CONNECTION }}
        run: ./scripts/deploy.sh
```
```yaml
# ── Matrix strategy: test against multiple versions ───────────────────
jobs:
  test:
    strategy:
      matrix:
        dotnet-version: ['7.0.x', '8.0.x']
        os: [ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ matrix.dotnet-version }}
      - run: dotnet test
```

---

## Gotchas

- **Secrets are masked in logs but can be exfiltrated via a malicious action or a `run:` step that prints them.** Always pin third-party actions to a full commit SHA (`uses: actions/checkout@abc1234`), not a tag (`@v4`). Tags are mutable — `@v4` can be pointed at a different commit silently.
- **`pull_request` workflows from forks don't get access to secrets by default.** This is intentional security behavior — a fork contributor could modify the workflow to exfiltrate secrets. Use `pull_request_target` only if you understand the security implications and add explicit checks.
- **Each job starts with a clean runner — no files from previous jobs.** Pass data between jobs using `actions/upload-artifact` + `actions/download-artifact`, or via `outputs:` for small values. Forgetting this causes "file not found" errors that are confusing until you understand the job isolation model.
- **Without path filters on a monorepo, every commit triggers every workflow.** One frontend change rebuilds and redeploys your backend. Add `on: push: paths:` filters scoped to each project's directories.
- **Workflow YAML syntax errors fail silently on push.** GitHub shows the error only when you view the Actions tab — not in the push output. Validate locally with `actionlint` before pushing workflow changes.

---

## Interview Angle

**What they're really testing:** Whether you understand CI/CD automation at a practical level — can you actually set up a reliable pipeline, or do you just know it exists?

**Common question form:** "How would you set up CI/CD for a new microservice?" or "What do you look for in a GitHub Actions workflow?"

**The depth signal:** A junior can describe a basic push-triggered workflow with checkout, build, and test steps. A senior explains the security model (secret exposure in fork PRs, why to pin action versions to SHAs not tags), the job isolation model and how to pass data between jobs, path-filter triggering for monorepos, and how to use environment protection rules to require manual approval before production deployments — treating CI configuration as production code that needs the same security scrutiny as application code.

---

## Related Topics

- [[git/git-hooks.md]] — Hooks provide fast local enforcement before code reaches CI; Actions provides authoritative remote enforcement. They're complementary, not redundant.
- [[git/git-monorepo.md]] — Monorepo CI on Actions requires path filters and matrix strategies; the default "run everything" behavior breaks at monorepo scale.
- [[git/git-submodules.md]] — Repos with submodules need `actions/checkout` configured with `submodules: recursive` or builds fail on empty directories.
- [[devops/ci-cd-pipelines.md]] — Actions is one implementation of a CI/CD pipeline; understanding the general pipeline concepts helps reason about what Actions is doing and where its limits are.

---

## Source

[GitHub Actions Documentation](https://docs.github.com/en/actions)

---
*Last updated: 2026-03-24*