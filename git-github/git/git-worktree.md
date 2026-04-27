# Git Worktrees

> `git worktree` lets you check out multiple branches simultaneously in separate directories — without stashing, committing, or cloning.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Multiple working directory checkouts of the same repo sharing one `.git/` |
| **Use when** | Switching contexts without losing current work; reviewing a PR while mid-feature |
| **Avoid when** | You only need to peek at another branch briefly — `git stash` is simpler |
| **Git version** | Added Git 2.5; `--orphan` flag Git 2.17; lock/unlock Git 2.6 |
| **Key location** | `.git/worktrees/` — metadata for each linked worktree |
| **Key commands** | `git worktree add`, `git worktree list`, `git worktree remove`, `git worktree prune` |

---

## When To Use It

Use worktrees when you need to work on two branches simultaneously without losing work or stashing — reviewing a colleague's PR while mid-feature, running tests on main while continuing development, or maintaining a hotfix branch alongside active development. Unlike stashing, worktrees preserve your complete working state indefinitely with no risk of accidentally losing it.

---

## Core Concept

A Git repository has one `.git/` directory but can have multiple working trees. The primary worktree is where you cloned. `git worktree add` creates a new directory linked to the same `.git/`, checked out to a different branch. Both worktrees share the object store and refs — a commit in one is immediately visible in the other. Each worktree has its own `HEAD`, index, and working directory. One constraint: the same branch can only be checked out in one worktree at a time.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 2.5 | `git worktree` introduced |
| Git 2.6 | `git worktree lock` / `unlock` for portable drives |
| Git 2.7 | `git worktree list` added |
| Git 2.17 | `--orphan` flag for unborn branch worktrees |
| Git 2.21 | Worktree-level config scope |
| Git 2.36 | `git worktree repair` for fixing broken paths |

---

## The Code

**Basic worktree workflow**
```bash
# Current state: mid-feature on feat/payment-refactor, urgent PR review needed
git branch
# * feat/payment-refactor
#   main

# Add a worktree for the PR branch (separate directory, same repo)
git worktree add ../review-pr-217 origin/feat/auth-improvements
# Preparing worktree (checking out 'origin/feat/auth-improvements')
# HEAD is now at a1b2c3d Add JWT middleware

# List all worktrees
git worktree list
# /home/ali/projects/myapp              a1b2c3d [feat/payment-refactor]
# /home/ali/projects/review-pr-217      d4e5f6g [feat/auth-improvements]

# Work in the review directory without touching current work
cd ../review-pr-217
dotnet test
# Run the PR, leave comments, come back to your work

# Remove the worktree when done
cd ../myapp
git worktree remove ../review-pr-217
```

**Create a worktree on a new branch**
```bash
# Create a new branch and worktree simultaneously
git worktree add -b hotfix/payment-null ../hotfix main
# Creates branch hotfix/payment-null at main, checks it out in ../hotfix

cd ../hotfix
# Fix the bug, commit, push
git commit -m "fix: null ref in payment processor"
git push -u origin hotfix/payment-null

# Return to feature work — completely uninterrupted
cd ../myapp
git status
# Still on feat/payment-refactor with all changes intact
```

**Worktree for parallel builds**
```bash
# Build main while working on a feature
git worktree add ../main-build main

# In one terminal: run the production build
cd ../main-build && dotnet publish -c Release

# In another terminal: continue feature development
cd ~/projects/myapp && code .

# Clean up when done
git worktree remove ../main-build
```

**Pruning stale worktrees**
```bash
# List worktrees — shows locked/prunable status
git worktree list --porcelain

# Prune worktrees whose directories no longer exist
git worktree prune

# Lock a worktree (prevents pruning — useful on external drives)
git worktree lock ../hotfix --reason "On USB drive, don't prune"
git worktree unlock ../hotfix
```

---

## Real World Example

A developer maintained two active projects in the same monorepo: a customer-facing API (actively developed) and a data pipeline (in maintenance mode). Previously, switching between them meant constant stashing and unstashing — losing flow state. With worktrees, both lived side by side:

```bash
# One-time setup
git worktree add ../api-work feat/api-v2
git worktree add ../pipeline-work feat/pipeline-fix

# Daily workflow: open both in separate editor windows
code ../api-work       # VS Code window for API
code ../pipeline-work  # VS Code window for pipeline

# Each has independent state — no stashing needed
# Commits in either are visible in both (shared object store)
```

---

## Common Misconceptions

**"Worktrees are separate clones"** — They share the same `.git/` directory and object store. A commit in one worktree is immediately available in all others. They're not independent.

**"You can check out the same branch in two worktrees"** — Git prevents this to avoid conflicts on the index. Each branch can only be the HEAD of one worktree at a time.

---

## Gotchas

- **You can't check out the same branch in two worktrees.** Git enforces this — create a new branch from the source if you need a second workspace for the same content.
- **Deleting the worktree directory doesn't clean up Git's metadata.** Use `git worktree remove` or `git worktree prune` to keep `.git/worktrees/` clean.
- **Stash is not shared across worktrees.** Each worktree has its own stash stack.

---

## Interview Angle

**Common question:** "How do you handle switching between two features in progress without losing work?"

**The depth signal:** A junior stashes. A senior knows worktrees — and can explain they share the object store, allowing commits in one to be immediately visible in the other, while maintaining fully independent working directories.

---

## Related Topics

- [git-stash.md](git-stash.md) — Simpler alternative for short context switches.
- [git-branches.md](git-branches.md) — Worktrees check out branches; branch constraints apply.
- [git-monorepo.md](git-monorepo.md) — Worktrees + sparse checkout is a powerful combination for monorepos.

---

## Source

[Git Documentation — git-worktree](https://git-scm.com/docs/git-worktree)

---
*Last updated: 2026-04-24*