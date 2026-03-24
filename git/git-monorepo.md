# Monorepo

> A monorepo is a single Git repository that houses multiple distinct projects, services, or packages — as opposed to one repository per project.

---

## When To Use It

Consider a monorepo when you have multiple services or packages that change together frequently, share significant code, or need coordinated versioning and deployments. It's particularly effective for teams that experience "cross-repo PR hell" — where one feature requires coordinated changes across three separate repos and three separate review cycles. Avoid it when teams are truly independent with no shared code, when repo size will cause Git performance problems without investment in tooling, or when different projects have fundamentally incompatible release cadences.

---

## Core Concept

A monorepo solves the coordination cost of polyrepos by putting everything in one place — one PR can change a shared library and all its consumers atomically. The tradeoff is operational complexity: CI must be smart enough to only build what changed (otherwise every commit triggers a full rebuild of every service), tooling like Nx, Turborepo, or Bazel becomes necessary at scale, and Git itself starts to struggle with large histories and many files without configuration tuning. The most important principle in a monorepo is affected-change detection — only running tests and builds for the projects that are actually impacted by a given commit.

---

## The Code
```bash
# ── Typical monorepo folder structure ────────────────────────────────
monorepo/
├── apps/
│   ├── api/              # ASP.NET Core service
│   ├── worker/           # Background job service
│   └── frontend/         # React app
├── libs/
│   ├── shared-models/    # Shared DTOs / domain models
│   ├── auth/             # Shared auth middleware
│   └── testing/          # Shared test utilities
├── infra/                # Terraform / Docker configs
├── .github/workflows/    # CI — per-project or affected-only
└── nx.json / turbo.json  # Monorepo orchestration config
```
```json
// turbo.json — Turborepo pipeline config
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],   // build dependencies first
      "outputs": ["dist/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "inputs": ["src/**", "tests/**"]
    },
    "lint": {}
  }
}
```
```bash
# ── Affected-only builds with Nx (Node.js / TS ecosystem) ────────────
npx nx affected:build --base=main    # build only what changed vs main
npx nx affected:test --base=main     # test only affected projects
npx nx graph                         # visualize project dependency graph

# ── Git sparse checkout — only materialize part of the repo ──────────
# Useful for large monorepos where developers only work in one area
git clone --filter=blob:none --sparse https://github.com/org/monorepo.git
git sparse-checkout set apps/api libs/shared-models
# Only these directories are materialized on disk

# ── Shallow clone for CI (reduces clone time on large repos) ─────────
git clone --depth=1 https://github.com/org/monorepo.git
# Gets only the latest commit — enough for most CI builds

# ── CODEOWNERS — per-project ownership in a monorepo ─────────────────
# .github/CODEOWNERS
/apps/api/          @backend-team
/apps/frontend/     @frontend-team
/libs/shared-*/     @platform-team
/infra/             @devops-team
# PRs automatically request review from the right team based on changed paths
```

---

## Gotchas

- **Without affected-change detection, every commit rebuilds everything.** A monorepo with 10 services and a naive CI that runs all tests on every push becomes unusable within weeks. Affected-only pipelines are not an optimization — they're a requirement.
- **`git log` and `git blame` become slow on large monorepos without `--partial-clone` and sparse checkout.** GitHub itself struggles to render diffs on repos over a certain size. Git performance tuning is operational work, not a one-time setup.
- **Shared library changes require extra discipline.** Changing a shared lib is easy; knowing which of the 12 consuming apps you broke requires either good tooling (dependency graph) or discipline to run affected tests. Without tooling, breakage gets discovered at deploy time.
- **CODEOWNERS is mandatory, not optional.** Without file-path-based ownership rules, every PR in a large monorepo notifies everyone or notifies nobody. Ownership clarity degrades fast as the repo grows.
- **Merging strategies interact with affected detection in unexpected ways.** Squash-merging loses the granular file-change metadata that some tools use to determine what's affected. Test your affected detection tool with your merge strategy before committing to either.

---

## Interview Angle

**What they're really testing:** Whether you understand the real operational tradeoffs of monorepos vs. polyrepos and have thought beyond "everything in one place is convenient."

**Common question form:** "What are the tradeoffs between monorepos and polyrepos?" or "How would you set up CI for a monorepo with 10 services?"

**The depth signal:** A junior lists the benefits (atomic changes, code sharing, single PR) and the surface-level drawbacks (big repo). A senior explains that the core challenge is affected-change detection in CI — that a monorepo without it becomes a rebuild-everything disaster — and can describe the Git-level performance mechanisms (sparse checkout, partial clone, shallow clone) needed at scale, plus why CODEOWNERS and a dependency graph visualization tool are load-bearing infrastructure, not nice-to-haves.

---

## Related Topics

- [[git/git-submodules.md]] — Submodules are the polyrepo approach to shared code; monorepos and submodules solve the same problem with opposite tradeoffs.
- [[git/github-actions-integration.md]] — Monorepo CI requires path-filter triggers (`on: push: paths:`) to avoid building all projects on every commit.
- [[git/git-large-files.md]] — Monorepos accumulate assets from multiple teams faster; LFS configuration becomes urgent at monorepo scale.
- [[devops/ci-cd-pipelines.md]] — Monorepo CI pipeline design is a domain of its own: affected detection, matrix builds, per-project deployment — fundamentally different from polyrepo pipelines.

---

## Source

[Monorepo.tools — Comparison of Monorepo Tools](https://monorepo.tools)

---
*Last updated: 2026-03-24*