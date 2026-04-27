# Git Stash

> Stash saves your uncommitted working directory and index changes onto a stack, giving you a clean working tree without committing, so you can switch context and come back later.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A local-only stack of WIP snapshots stored as commit objects |
| **Use when** | Switching branches with dirty working directory; short-term context switches |
| **Avoid when** | Work will sit for more than a day — use a WIP commit on a branch instead |
| **Git version** | Core since Git 1.5.3; `--pathspec-from-file` added Git 2.25; `-m` shorthand stable Git 2.16 |
| **Key location** | `refs/stash` (ref), `.git/logs/refs/stash` (stash log) |
| **Key commands** | `git stash push`, `git stash pop`, `git stash list`, `git stash branch`, `git stash drop` |

---

## When To Use It

Use stash when you need to switch branches or pull changes but have work in progress you're not ready to commit. It's a short-term holding area, not a backup strategy — stash entries are local, not pushed to the remote, and are easy to forget about. If you find yourself stashing the same work repeatedly for days, it should be a WIP commit on a branch instead.

---

## Core Concept

`git stash` creates two (or three) commit objects internally — one for the index state and one for the working directory state — and stores references to them on a stack at `refs/stash`. It then resets the working directory and index to match HEAD. `git stash pop` replays those changes back and removes the entry from the stack. `git stash apply` replays without removing — useful when you want to apply the same stash to multiple branches. The stash stack is LIFO but you can access any entry by index.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.5.3 | `git stash` introduced |
| Git 1.7.7 | `git stash push` added as explicit form (vs the implicit `git stash`) |
| Git 2.13 | `git stash push -- <pathspec>` for stashing specific files |
| Git 2.16 | `-m` shorthand for `--message` stabilised across platforms |
| Git 2.25 | `--pathspec-from-file` added to `git stash push` |
| Git 2.35 | `git stash show -u` to include untracked files in stash diff |

*The `git stash` command (no subcommand) is shorthand for `git stash push`. Both are equivalent. New scripts should use `git stash push` explicitly for clarity.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `git stash push` | O(staged + modified files) | Hashes and writes blob objects for each changed file |
| `git stash pop` | O(stashed files) | Applies diff and deletes the stash ref entry |
| `git stash list` | O(N stash entries) | Reads the stash reflog — fast even with many entries |
| `git stash drop` | O(1) | Removes one reflog entry; objects persist until GC |
| `git stash branch` | O(changed files) | Creates a branch + applies stash + drops entry |

**Allocation behaviour:** Each stash entry creates 2–3 commit objects in `.git/objects`: one for the index state, one for the working directory state, and optionally one for untracked files (`-u`). These are real commit objects — `git fsck --unreachable` can find them if you drop a stash accidentally.

**Benchmark notes:** On a large repo with 50,000+ tracked files, `git stash push` can be slow because it must stat every tracked file to detect modifications. Use specific paths (`git stash push -- src/`) to limit the scope and dramatically reduce stash time in focused workflows.

---

## The Code

**Basic stash operations**
```bash
# Stash everything (tracked modified files + staged changes)
git stash

# Stash with a descriptive message — findable later
git stash push -m "WIP: rate limiter — needs Redis config"

# List all stashes
git stash list
# stash@{0}: On feature/auth: WIP: rate limiter — needs Redis config
# stash@{1}: On main: experiment with new parser
# stash@{2}: WIP on feature/payments: 3c4d2e5 Add payment gateway

# Apply latest stash and remove from stack
git stash pop

# Apply latest stash but keep it on the stack (useful for applying to multiple branches)
git stash apply

# Apply a specific stash by index
git stash pop stash@{2}
git stash apply stash@{1}
```

**Controlling what gets stashed**
```bash
# Default: stashes tracked modified files + staged changes
# Does NOT stash: untracked files, ignored files

# Include untracked files (-u / --include-untracked)
git stash push -u
git stash push --include-untracked

# Include untracked AND ignored files (rarely needed — stashes node_modules etc.)
git stash push --all

# Stash only specific files or directories
git stash push -m "just the auth changes" -- src/auth/ tests/auth/

# Stash only unstaged changes — leave staged changes in the index
git stash push --keep-index
# Useful for: running tests against exactly what you're about to commit
# Pattern: stage what you want to commit, stash the rest, test, commit, pop
```

**Interactive stash — partial stash**
```bash
# Choose which hunks to stash (like git add -p but for stashing)
git stash push -p
# y = stash this hunk
# n = leave this hunk in working directory
# s = split into smaller hunks
# e = manually edit the hunk
```

**Inspecting stash contents**
```bash
# Show a summary of what's in a stash
git stash show stash@{0}
git stash show stash@{0} --stat

# Show the full diff
git stash show stash@{0} -p

# Show including untracked files (Git 2.35+)
git stash show stash@{0} -p -u

# Most readable: turn stash into a branch
git stash branch temp-branch stash@{0}
# Creates a new branch at the commit where the stash was made
# and applies the stash on top — avoids conflicts from branch drift
# Also drops the stash entry on success
```

**Cleaning up stashes**
```bash
# Drop a specific stash
git stash drop stash@{1}

# Clear all stashes (no recovery path after GC runs)
git stash clear

# Recover a dropped stash — objects are still in the object store briefly
git fsck --unreachable | grep commit
# Find dangling commits, inspect them with git show
git show <dangling-commit-hash>
# Looks like a stash? Re-apply it:
git stash apply <dangling-commit-hash>
```

**Common pattern — pull with a dirty working directory**
```bash
# Can't pull because you have uncommitted changes
git pull
# error: Your local changes to the following files would be overwritten by merge

# Option 1: manual stash, pull, pop
git stash
git pull
git stash pop

# Option 2: one command (Git 2.6+)
git pull --autostash   # stash, pull, pop automatically — handles conflicts too
```

**The WIP commit pattern — better than long-lived stashes**
```bash
# Instead of leaving a stash for more than a day:
git add -A
git commit -m "WIP: payment form validation — incomplete, do not merge"
git push origin feature/payments   # backed up on remote, visible to teammates

# When returning to the work:
git switch feature/payments
git reset --soft HEAD~1    # undo the WIP commit, changes go back to staged
# OR:
git rebase -i HEAD~1       # and drop/squash when done
```

---

## Real World Example

A DevOps engineer was halfway through a Kubernetes config migration when a P0 alert fired — the production payment processor was returning 500s. She needed to switch branches immediately and fix the issue without losing 90 minutes of work, some of which was across new files not yet tracked by Git.

```bash
# Working state: 4 modified files, 3 new untracked files (new k8s manifests)
git status
# modified:   k8s/deployments/api-deployment.yaml
# modified:   k8s/services/api-service.yaml
# modified:   k8s/configmaps/api-config.yaml
# modified:   k8s/ingress/api-ingress.yaml
# Untracked:  k8s/hpa/api-hpa.yaml
# Untracked:  k8s/pdb/api-pdb.yaml
# Untracked:  k8s/networkpolicies/api-netpol.yaml

# Stash everything including untracked k8s files
git stash push -u -m "WIP: k8s migration — HPA + PDB + netpol not complete"

# Verify clean working directory
git status
# nothing to commit, working tree clean

# Switch to main and fix the production issue
git switch main
git switch -c hotfix/payment-500-null-ref
# ... investigate, find NullReferenceException in PaymentController ...
# ... fix, test, commit, PR, merge ...

# Two hours later, back to the migration
git switch feature/k8s-migration
git stash list
# stash@{0}: On feature/k8s-migration: WIP: k8s migration — HPA + PDB + netpol not complete

# Before popping, check if main moved under us
git fetch origin
git log --oneline feature/k8s-migration..origin/main
# abc1234 hotfix: fix null ref in payment controller

# Rebase first, then pop to minimize conflicts
git rebase origin/main
git stash pop
# Auto-merging k8s/configmaps/api-config.yaml — clean
# All 7 files restored

# The stash applied cleanly — continue migration
git status
# 4 modified + 3 untracked restored exactly as left
```

*The key insight: `-u` (include untracked) is essential when your WIP includes new files. Without it, the untracked k8s manifests would have stayed in the working directory across the branch switch — potentially confusing and at risk of accidental staging.*

---

## Common Misconceptions

**"git stash is backed up to the remote"**
Stash entries live in `refs/stash` and `.git/logs/refs/stash` — local-only structures that are never pushed. `git push` does not send stashes. If your laptop dies with a 3-day-old stash, that work is gone unless you have other backups. Anything worth keeping for more than a few hours should be a WIP commit on a pushed branch.

**"git stash pop always works cleanly"**
`git stash pop` can conflict just like a merge. If the branch has changed since you stashed — especially if the same files were modified — the pop will produce conflict markers and stop. Crucially, when `stash pop` hits a conflict, it does not remove the stash entry. Many engineers don't notice this, resolve the conflicts, and end up with the stash still in the list. After resolving, manually run `git stash drop stash@{0}`.

**"git stash only saves uncommitted changes in tracked files"**
By default, yes — but `-u` includes untracked files and `--all` includes ignored files too. The default is correct 90% of the time, but when your WIP includes new files you haven't `git add`ed yet, the default stash leaves those files behind in the working directory.

---

## Gotchas

- **Stash entries are local and not cloned.** If you stash on your laptop and need the work on another machine, the stash isn't there. For cross-machine WIP, use a WIP commit on a personal branch and push it.

- **`git stash pop` on a conflicting stash doesn't remove the stash entry.** If applying the stash causes conflicts, the stash stays in the list. Resolve the conflicts, then `git stash drop stash@{0}` manually. Many people forget this and end up with duplicate stash entries.

- **Stashing without `-u` leaves untracked files in the working directory.** If your WIP includes new files you haven't added yet, they stay behind when you stash. The next branch you switch to will have those files sitting in its working directory — confusing and risky.

- **`git stash clear` is not recoverable after GC.** Unlike most Git operations, clearing the stash removes reflog entries. The objects may linger briefly in the object store, but there's no guaranteed recovery path. Use `git stash drop` to remove individual entries instead.

- **Stash entries become harder to apply as the target branch drifts.** A stash from two weeks ago on a fast-moving branch will likely conflict when applied. The longer a stash sits, the more it should be a WIP commit on a branch instead.

- **`git stash branch` is the cleanest way to apply a stash that conflicts.** It creates a branch at the exact commit the stash was made on, applies the stash on top (which can't conflict because that's the exact state it was in), and drops the stash entry. Resolving the conflict then becomes a normal rebase onto main.

---

## Interview Angle

**What they're really testing:** Whether you know stash's limitations (local-only, no untracked files by default, conflict behaviour) and when a WIP commit is a better choice.

**Common question forms:**
- "How do you save work in progress without committing?"
- "How do you handle switching branches mid-feature?"
- "What's the difference between `git stash pop` and `git stash apply`?"

**The depth signal:** A junior says "use `git stash` to save your work." A senior knows the default stash misses untracked files (`-u` flag required), that `stash pop` doesn't remove the entry on conflict, that stashes are local and not pushed, and that `git stash branch` is the clean way to apply a stash that conflicts with current branch state. They also know when NOT to use stash: anything that lives longer than a day should be a WIP commit on a personal branch and pushed — stash is ephemeral working memory, not durable storage.

**Follow-up questions to expect:**
- "What happens to the stash entry if `git stash pop` encounters a conflict?"
- "How would you recover a stash entry you accidentally dropped?"

---

## Related Topics

- [git-staging-area.md](git-staging-area.md) — Stash saves both the index and working directory; `--keep-index` separates them deliberately.
- [git-branches.md](git-branches.md) — A WIP commit on a branch is often better than a long-lived stash for multi-day in-progress work.
- [git-commits.md](git-commits.md) — `git commit --fixup` + interactive rebase is the alternative to stash for work-in-progress you want to fold into an earlier commit.
- [git-internals.md](git-internals.md) — Stash creates real commit objects internally; `git fsck --unreachable` can recover dropped stashes from the object store.

---

## Source

[Git documentation — git-stash](https://git-scm.com/docs/git-stash)

---
*Last updated: 2026-04-23*