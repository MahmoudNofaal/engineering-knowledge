# Git Sparse Checkout

> Sparse checkout lets you materialise only a subset of a repository's files on disk — while still having access to the full Git history and object store.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A checkout mode where only specified paths are written to the working directory |
| **Use when** | Working in a large monorepo where you only need a fraction of the files |
| **Avoid when** | Small repos — the overhead isn't worth it |
| **Git version** | Sparse checkout v1 since Git 1.7; sparse checkout v2 (cone mode) since Git 2.25; `git sparse-checkout` command since Git 2.25 |
| **Key location** | `.git/info/sparse-checkout` (pattern file) or `.git/sparse-checkout` (cone mode) |
| **Key commands** | `git sparse-checkout init`, `git sparse-checkout set`, `git sparse-checkout add`, `git sparse-checkout list` |

---

## When To Use It

Use sparse checkout in large monorepos where you only work in one or two directories out of potentially hundreds. A frontend developer in a monorepo with 500,000 files only needs `apps/frontend/` and `libs/shared-ui/` — sparse checkout means they materialise 50,000 files instead of 500,000, making `git status` 10× faster and the working directory much less cluttered.

---

## Core Concept

Git normally materialises every tracked file in the working directory. With sparse checkout, Git maintains a list of patterns (or directory cones) and only writes matching files to disk. The full history and all objects remain in `.git/` — you can still `git log --all` and access any file via `git show HEAD:path/to/file`. Two modes exist: **cone mode** (Git 2.26+, fast — works with directory boundaries only) and **non-cone mode** (slow — arbitrary gitignore-style patterns). Always use cone mode.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.7.0 | Sparse checkout (non-cone mode) via `.git/info/sparse-checkout` |
| Git 2.25 | `git sparse-checkout` command; cone mode introduced |
| Git 2.26 | Cone mode stabilised — dramatically faster pattern matching |
| Git 2.27 | `git clone --sparse` for initial sparse clone |
| Git 2.35 | `--no-cone` explicit flag; improved cone mode edge cases |
| Git 2.41 | Integration with partial clone improvements |

---

## The Code

**Setting up sparse checkout on an existing clone**
```bash
# Enable sparse checkout in cone mode
git sparse-checkout init --cone

# Set the directories you want (replaces current set)
git sparse-checkout set apps/api libs/shared-models

# Add more directories without replacing existing
git sparse-checkout add libs/auth infra/kubernetes/api

# List current sparse checkout configuration
git sparse-checkout list
# apps/api
# libs/auth
# libs/shared-models
# infra/kubernetes/api

# Disable sparse checkout (materialise all files again)
git sparse-checkout disable
```

**Sparse clone — combine with partial clone for maximum speed**
```bash
# Full power: partial clone (no blobs) + sparse checkout
git clone --filter=blob:none --sparse https://github.com/org/monorepo.git
cd monorepo

# Set which directories you need
git sparse-checkout set apps/api libs/shared-models

# Git downloads blobs only for files in your sparse set — on demand
# First checkout of apps/api: downloads those blobs
# Never downloads blobs for apps/frontend/* unless you add it

# Verify only specified dirs are on disk
ls
# apps/  libs/   .github/  README.md  (root files always included)
ls apps/
# api/   (not frontend/, not worker/, etc.)
```

**Cone mode rules**
```bash
# Cone mode works with directory boundaries only (fast pattern matching)
# Rules:
# - Root files (non-directory) are always included
# - Specified directories and all their children are included
# - Nothing else

# Adding a directory includes all its children recursively
git sparse-checkout set apps/api
# ✓ apps/api/Controllers/ included
# ✓ apps/api/Services/ included
# ✗ apps/frontend/ not included
# ✗ apps/worker/ not included

# If you need a specific subdirectory only — use the full path
git sparse-checkout set apps/api/Controllers
# Only apps/api/Controllers/ is materialised from apps/api
```

**Non-cone mode (legacy — use only when patterns are unavoidable)**
```bash
# Non-cone mode allows gitignore-style patterns but is much slower
git sparse-checkout init   # without --cone

# Edit patterns directly
cat > .git/info/sparse-checkout << 'EOF'
apps/api/
libs/shared-models/
!libs/shared-models/generated/   # exclude subdirectory
*.md                              # include all markdown files
EOF

git sparse-checkout reapply   # apply updated patterns
```

**GitHub Actions integration**
```yaml
- uses: actions/checkout@v4
  with:
    sparse-checkout: |
      apps/api
      libs/shared-models
      libs/auth
    sparse-checkout-cone-mode: true
    fetch-depth: 0   # full history if needed for git log/bisect
```

---

## Real World Example

A data engineering team had a monorepo with 180,000 files. Their ML engineers only worked in `ml/` (30,000 files). Without sparse checkout, `git status` took 8 seconds. With sparse clone + sparse checkout, it took 0.3 seconds — and the initial clone went from 14 minutes to 45 seconds.

```bash
# Before: full clone
time git clone https://github.com/org/data-platform.git
# real: 14m32s
# .git size: 4.2GB, working tree: 11GB

# After: sparse clone
time git clone --filter=blob:none --sparse https://github.com/org/data-platform.git
cd data-platform
git sparse-checkout set ml/ libs/data-utils
# real: 0m45s
# .git size: 420MB (object metadata only, no blobs yet)
# working tree: 1.2GB (only ml/ and libs/data-utils)

# git status time
time git status
# Before: 8.3s
# After: 0.28s
```

---

## Common Misconceptions

**"Sparse checkout means you can't access other files"** — You can still `git show HEAD:apps/frontend/index.tsx` or `cat <(git show HEAD:path)` to read any file. You just haven't materialised it to disk. `git sparse-checkout add apps/frontend` materialises it at any time.

**"Non-cone mode is more flexible so it's better"** — Non-cone mode checks every tracked file against every pattern on every `git status`. At 200,000 files with 10 patterns, this is 2,000,000 pattern-match operations. Cone mode uses directory prefix matching — O(1) per file. Always use cone mode unless you genuinely need pattern-based exclusions.

---

## Gotchas

- **Root-level files are always materialised in cone mode.** `README.md`, `package.json`, `*.sln` at the repo root are always on disk — you can't exclude them in cone mode.
- **Some tools expect all files to be present.** IDEs and language servers may not handle sparse checkouts gracefully — they expect to traverse the full repo. Test your tooling.
- **Partial clone + sparse checkout requires `git lfs pull` explicitly.** LFS files in sparse paths aren't automatically downloaded — run `git lfs pull --include="ml/**"` for LFS content in your sparse set.

---

## Related Topics

- [git-monorepo.md](git-monorepo.md) — Sparse checkout is the key Git mechanism for making monorepos practical at scale.
- [git-large-files.md](git-large-files.md) — Combine sparse checkout with LFS for repos with large binary assets.
- [git-worktrees.md](git-worktrees.md) — Each worktree can have its own sparse checkout configuration.

---

## Source

[Git Documentation — git-sparse-checkout](https://git-scm.com/docs/git-sparse-checkout)

---
*Last updated: 2026-04-24*