# Monorepo

> A monorepo is a single Git repository that houses multiple distinct projects, services, or packages — as opposed to one repository per project (polyrepo).

---

## Quick Reference

| | |
|---|---|
| **What it is** | One Git repo containing multiple independently deployable projects |
| **Use when** | Projects share code frequently, change together often, or need atomic cross-project commits |
| **Avoid when** | Teams are truly independent, or repo size will outgrow Git's capabilities without tooling investment |
| **Git version** | No special Git version — but sparse checkout (2.25+) and partial clone (2.22+) are critical at scale |
| **Key tools** | Nx, Turborepo (JS/TS), Bazel (multi-language), Gradle (JVM), `git sparse-checkout` |
| **Key commands** | `git sparse-checkout`, `git clone --filter=blob:none`, `nx affected`, `turbo run` |

---

## When To Use It

Consider a monorepo when you have multiple services or packages that change together frequently, share significant code, or need coordinated versioning and deployments. It's particularly effective for teams that experience "cross-repo PR hell" — where one feature requires coordinated changes across three separate repos and three separate review cycles. Avoid it when teams are truly independent with no shared code, when repo size will cause Git performance problems without investment in tooling, or when different projects have fundamentally incompatible release cadences.

---

## Core Concept

A monorepo solves the coordination cost of polyrepos by putting everything in one place — one PR can change a shared library and all its consumers atomically. The tradeoff is operational complexity: CI must be smart enough to only build what changed (otherwise every commit triggers a full rebuild of every service), tooling like Nx, Turborepo, or Bazel becomes necessary at scale, and Git itself starts to struggle with large histories and many files without configuration tuning. The most important principle in a monorepo is affected-change detection — only running tests and builds for the projects that are actually impacted by a given commit.

---

## Version History

| Git Feature | Version | Monorepo relevance |
|---|---|---|
| Partial clone (`--filter=blob:none`) | Git 2.22 | Clone without blob objects — fetch only on checkout |
| Sparse checkout v2 (cone mode) | Git 2.25 | Materialise only specific directories |
| `git sparse-checkout` command | Git 2.25 | Official sparse checkout UI |
| `--sparse` flag on clone | Git 2.27 | Combine partial clone + sparse checkout |
| Commit graph file | Git 2.22 | Speeds up `git log` traversal on large repos |
| `git maintenance` | Git 2.29 | Background maintenance for large repo health |
| Multi-pack index | Git 2.27 | Faster object lookup with many pack files |

*The combination of `git clone --filter=blob:none --sparse` (Git 2.27+) is the key to making Git practical for monorepos with millions of files. A developer working on `apps/api/` doesn't need to materialize the 200,000 files in `apps/frontend/` on their disk.*

---

## Performance

| Scenario | Polyrepo | Monorepo (without tooling) | Monorepo (with tooling) |
|---|---|---|---|
| Clone time | Fast (one project) | Slow (entire codebase) | Fast (sparse checkout) |
| CI trigger | Per-repo | Every service on every commit | Affected services only |
| Cross-project change | Multi-repo PR | Single atomic PR | Single atomic PR |
| Dependency update | Manual per-repo | One commit, all consumers | One commit + affected rebuild |
| `git log` on large history | Fast | Slow without commit graph | Fast with commit graph file |

**The CI cost without affected detection:** A monorepo with 15 services and no affected detection rebuilds all 15 on every commit. If each build takes 3 minutes, every PR runs 45 minutes of builds. With affected detection, a PR touching only `apps/api/` runs 1 build — 3 minutes. The 15× difference determines whether the monorepo is viable.

**Benchmark notes:** Google's monorepo has billions of files. They use Piper (internal VCS) not Git, because Git doesn't scale to that level without modification. Practical Git monorepo limits without heavy tooling: ~100,000 files, ~500,000 commits. With sparse checkout + partial clone + commit graph: ~1,000,000 files. Beyond that, consider Mercurial with remotefilelog or a purpose-built system.

---

## The Code

**Typical monorepo folder structure**
```bash
monorepo/
├── apps/
│   ├── api/              # ASP.NET Core service
│   ├── worker/           # Background job service
│   └── frontend/         # React app
├── libs/
│   ├── shared-models/    # Shared DTOs / domain models
│   ├── auth/             # Shared authentication middleware
│   └── testing/          # Shared test utilities
├── infra/                # Terraform / Docker configs
├── .github/
│   ├── CODEOWNERS        # Per-directory ownership
│   └── workflows/        # Per-project CI workflows
├── nx.json               # Nx workspace config
└── turbo.json            # Turborepo pipeline config (alternative to Nx)
```

**Turborepo pipeline config**
```json
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],     // build dependencies before dependents
      "outputs": ["dist/**", "bin/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "inputs": ["src/**", "tests/**", "../../libs/**"]
    },
    "lint": {
      "inputs": ["src/**", "*.json"]
    },
    "deploy": {
      "dependsOn": ["build", "test"],
      "cache": false               // don't cache deploy operations
    }
  }
}
```

**Affected-only builds with Nx**
```bash
# Build only what changed vs main
npx nx affected:build --base=main

# Test only affected projects
npx nx affected:test --base=main

# See what's affected before running anything
npx nx affected:graph --base=main    # visual dependency graph

# Run any target on affected projects
npx nx affected --target=lint --base=main

# In CI — use the PR's base branch
npx nx affected:build --base=origin/main --head=HEAD
```

**Git sparse checkout — materialise only what you need**
```bash
# Clone with partial clone + sparse checkout (fastest for large monorepos)
git clone --filter=blob:none --sparse https://github.com/org/monorepo.git
cd monorepo

# Add only the directories you need (cone mode — much faster than pattern mode)
git sparse-checkout set apps/api libs/shared-models libs/auth

# Verify — only these directories are on disk
ls
# apps/  libs/   .github/  nx.json  (only the specified paths + root files)

# Add more directories later
git sparse-checkout add infra/kubernetes

# Remove directories you no longer need
git sparse-checkout set apps/api    # re-specify only what you want

# See current sparse-checkout configuration
git sparse-checkout list
```

**GitHub Actions — per-project CI with path filters**
```yaml
# .github/workflows/api-ci.yml
name: API CI

on:
  push:
    paths:
      - 'apps/api/**'
      - 'libs/shared-models/**'
      - 'libs/auth/**'
      - '.github/workflows/api-ci.yml'
  pull_request:
    paths:
      - 'apps/api/**'
      - 'libs/shared-models/**'
      - 'libs/auth/**'

jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          sparse-checkout: |
            apps/api
            libs/shared-models
            libs/auth
          sparse-checkout-cone-mode: true

      - name: Build API
        working-directory: apps/api
        run: dotnet build

      - name: Test API
        working-directory: apps/api
        run: dotnet test
```

**CODEOWNERS for monorepo**
```
# .github/CODEOWNERS

# Global fallback — platform team owns unclaimed files
*                           @org/platform-team

# App-level ownership — auto-requests correct team reviewers
/apps/api/                  @org/backend-team
/apps/worker/               @org/backend-team
/apps/frontend/             @org/frontend-team

# Shared library ownership
/libs/shared-models/        @org/platform-team
/libs/auth/                 @org/security-team

# Infrastructure — requires DevOps review
/infra/                     @org/devops-team

# CI config changes require platform team approval
/.github/                   @org/platform-team
```

**Shallow clone for CI (reduces clone time)**
```bash
# Shallow clone — only the latest commit (enough for most CI builds)
git clone --depth=1 https://github.com/org/monorepo.git

# With sparse checkout for monorepos
git clone --depth=1 --filter=blob:none --sparse https://github.com/org/monorepo.git
git sparse-checkout set apps/api libs/shared-models

# For affected detection, you need enough history to find the merge base
git fetch --depth=50 origin main   # enough history for most PR ranges
```

---

## Real World Example

A SaaS company had grown from 1 repo to 18 repos over 4 years. Features increasingly required changes in 3–5 repos simultaneously, each needing its own PR, review cycle, and coordinated deployment. Engineers were spending 30% of their time on "multi-repo choreography." They migrated to a monorepo over 6 months and tracked the impact.

```bash
# Before migration — a typical feature delivery:
# 1. Create PR in repo-a (shared-models change) → wait for review (1.5 days)
# 2. Publish new shared-models package version
# 3. Create PR in repo-b (api) referencing new package → wait (1 day)
# 4. Create PR in repo-c (frontend) referencing new api types → wait (0.8 days)
# 5. Coordinate 3 deployments in order
# Total: 4.5 days, 3 code reviews, 3 deployment windows

# After migration — same feature:
# 1. Create one PR touching all 3 directories → review 1 time → merge → deploy
# Total: 1.2 days average, 1 code review, 1 deployment

# Migration approach:
# Phase 1: Create monorepo skeleton
mkdir monorepo && cd monorepo && git init

# Import repos preserving full history
# (using git-filter-repo to rewrite paths)
for repo in shared-models api frontend worker; do
  git remote add $repo git@github.com:org/$repo.git
  git fetch $repo --no-tags

  # Rewrite history to put code in a subdirectory
  git filter-repo --to-subdirectory-filter "projects/$repo" \
    --source <(git remote show $repo | grep -E "HEAD|main")

  git merge --allow-unrelated-histories $repo/main \
    -m "chore: import $repo into monorepo"
done

# Phase 2: Set up build tooling (Nx)
npx create-nx-workspace@latest --preset=empty
# Move existing package.json / *.csproj into Nx project structure

# Phase 3: Configure CI with path filters (see GitHub Actions section above)

# Phase 4: Set up CODEOWNERS
# Each team owns their directory — cross-cutting changes need multi-team review

# Metrics after 3 months:
# Average feature lead time: 4.5 days → 1.2 days (−73%)
# "Multi-repo coordination" complaints: 8/week → 0
# CI build time per PR: 18 min (all 18 repos) → 3 min (affected only)
# Engineer satisfaction with tooling: 4.1/10 → 7.8/10
```

*The key insight: the monorepo migration's biggest benefit wasn't technical — it was social. Cross-team features that previously required 4 async review cycles now happen in 1. The atomic commit (one PR touching multiple projects) replaced the "version choreography" that was consuming 30% of engineering time.*

---

## Common Misconceptions

**"A monorepo means everything deploys together"**
A monorepo is a source code organisation choice — it says nothing about deployment. Projects in a monorepo can (and should) deploy independently. The monorepo just means their source code and shared dependencies live in the same Git history. Each project can have its own CI pipeline triggered by path filters, its own deployment pipeline, and its own release cadence.

**"Monorepos are only for big companies"**
Google and Facebook use monorepos at extreme scale with custom tooling. But a 5-person team with 3 related services benefits from a monorepo for the same reason: atomic changes, shared code, single place to look. The tooling overhead (Nx, Turborepo) is minimal for small teams — a `turbo.json` with 10 lines vs weeks of cross-repo PR choreography.

**"Monorepos slow down CI because everything builds on every commit"**
Monorepos slow down CI if you build everything on every commit — which is a tooling failure, not a monorepo property. With path-filter CI triggers and affected-change detection, a monorepo can be *faster* than polyrepos because each PR only builds what actually changed. The problem is when teams add the repo structure without adding the tooling.

---

## Gotchas

- **Without affected-change detection, every commit rebuilds everything.** A monorepo with 15 services and naive CI is unusable within weeks. Affected-only pipelines are a requirement, not an optimization.

- **`git log` and `git blame` slow on large monorepos without the commit graph file.** Enable with `git config core.commitGraph true && git commit-graph write --reachable`. Dramatically speeds up history traversal.

- **CODEOWNERS is mandatory, not optional.** Without file-path-based ownership rules, every PR notifies everyone or notifies nobody. Ownership clarity degrades fast as the repo grows.

- **Squash merge strategies interact with affected detection.** Some tools use file-change metadata from individual commits. Squash merging loses that granularity. Test your affected detection tool with your merge strategy before committing to either.

- **Deleting a project from a monorepo doesn't shrink the clone.** The history of that project remains. Use `git filter-repo` to physically remove a project's history if needed — but coordinate carefully, as this rewrites the entire repo history.

---

## Interview Angle

**What they're really testing:** Whether you understand the real operational tradeoffs of monorepos vs. polyrepos and have thought beyond "everything in one place is convenient."

**Common question forms:**
- "What are the tradeoffs between monorepos and polyrepos?"
- "How would you set up CI for a monorepo with 10 services?"
- "How do you prevent a monorepo from becoming a CI bottleneck?"

**The depth signal:** A junior lists the benefits (atomic changes, code sharing) and surface-level drawbacks (big repo). A senior explains that the core challenge is affected-change detection in CI, describes the Git-level performance mechanisms (sparse checkout, partial clone, commit graph), knows why CODEOWNERS and dependency graphs are load-bearing infrastructure, and can articulate the specific failure mode: a monorepo without tooling is just a polyrepo with extra steps — you get the costs without the benefits.

**Follow-up questions to expect:**
- "How does sparse checkout help with monorepo developer experience?"
- "What tooling would you choose for a monorepo with C# and TypeScript projects?"

---

## Related Topics

- [git-submodules.md](git-submodules.md) — Submodules are the polyrepo approach to shared code; monorepos and submodules solve the same problem with opposite tradeoffs.
- [github-actions-integration.md](github-actions-integration.md) — Monorepo CI requires path-filter triggers and matrix builds.
- [git-large-files.md](git-large-files.md) — Monorepos accumulate assets from multiple teams faster; LFS becomes urgent at monorepo scale.
- [git-branching-strategy.md](git-branching-strategy.md) — Monorepos usually pair well with trunk-based development; Gitflow at monorepo scale adds exponential complexity.

---

## Source

[Monorepo.tools — Comparison of Monorepo Tools](https://monorepo.tools)

---
*Last updated: 2026-04-24*