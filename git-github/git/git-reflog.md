# Git Reflog

> The reflog is Git's internal log of every position HEAD has pointed to, giving you a recovery path after destructive operations like `reset --hard`, `rebase`, or accidental branch deletion.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A local-only time-ordered log of every HEAD movement |
| **Use when** | Recovering lost commits after reset, rebase, branch deletion, or bad amend |
| **Avoid when** | N/A — it's always running; you just query it when needed |
| **Git version** | Core since Git 1.0; `--since`/`--before` filters since Git 1.7; per-branch reflog since early versions |
| **Key location** | `.git/logs/HEAD` (HEAD reflog), `.git/logs/refs/heads/<branch>` (per-branch) |
| **Key commands** | `git reflog`, `git reflog show <branch>`, `git reset --hard HEAD@{N}`, `git fsck --unreachable` |

---

## When To Use It

Reach for the reflog any time you've lost commits that you thought were gone — after a bad `--hard` reset, a rebase gone wrong, a branch deleted before merging, or an amended commit you want to recover. The reflog is local only: it exists on your machine and is not pushed to the remote. It expires after 90 days by default. It won't help you recover files that were never committed.

---

## Core Concept

Every time HEAD moves — from a commit, checkout, reset, merge, rebase, or anything else — Git appends an entry to `.git/logs/HEAD`. The reflog is that log. Each entry has a short-form reference (`HEAD@{N}`) that you can use exactly like a commit hash in any Git command. The key insight is that in Git, commits are never immediately deleted — they become "unreachable" (no branch points to them), but they still exist in the object store until garbage collection runs. Reflog gives you the hashes of those unreachable commits so you can reach them again before GC cleans them up.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | Reflog as `.git/logs/HEAD` established |
| Git 1.6.0 | `git reflog expire` added for manual expiry management |
| Git 1.7.0 | `--since` and `--before` time filters added |
| Git 2.0 | Per-branch reflogs stabilised across platforms |
| Git 2.13 | `git reflog delete` added for removing specific entries |
| Git 2.36 | Improved `--format` options for reflog output |

*The reflog expiry is controlled by two config values: `gc.reflogExpire` (default 90 days, for reachable refs) and `gc.reflogExpireUnreachable` (default 30 days, for unreachable objects). CI environments sometimes set these to very short values to save disk space — check before relying on reflog in a pipeline.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `git reflog` | O(entries) | Reads `.git/logs/HEAD` — a flat text file; instant for normal use |
| `git reflog show <branch>` | O(entries for that branch) | Reads the branch-specific log file |
| `git reset --hard HEAD@{N}` | O(changed files) | Hash lookup is O(1); file update cost is the same as any hard reset |
| `git fsck --unreachable` | O(all objects) | Full object store scan — can be slow on large repos |

**Allocation behaviour:** The reflog is a plain text file in `.git/logs/`. Each entry is one line (~200 bytes). A developer making 20 commits/day for 90 days generates about 1,800 lines = ~350KB per reflog file. Negligible. The real storage cost of the reflog is the *commit objects* it keeps reachable — these are preserved in `.git/objects` until `gc.reflogExpireUnreachable` expires them.

**Benchmark notes:** `git fsck --unreachable` is the backup recovery tool when reflog entries have already expired. On a large repo with millions of objects, `fsck` can take several minutes. Use it only when `git reflog` doesn't show the entry you need. The commit graph file does not speed up `fsck`.

---

## The Code

**Viewing the reflog**
```bash
git reflog                    # HEAD's movement history, most recent first
git reflog show main          # reflog for a specific branch, not just HEAD
git reflog show --all         # all reflogs across all refs

# Output:
# a1b2c3d HEAD@{0}: commit: feat: add JWT refresh
# e4f5a6b HEAD@{1}: rebase finished: refs/heads/feat/auth onto f7g8h9i
# f7g8h9i HEAD@{2}: reset: moving to HEAD~3
# 9d8c7b6 HEAD@{3}: commit: fix: null check in cart service
# Column meanings: hash, ref, action description

# Filter by time
git reflog --since="2 hours ago"
git reflog --before="2026-04-20 10:00"
git reflog --since="yesterday" --before="today"
```

**Recover from accidental `--hard` reset**
```bash
git reset --hard HEAD~3       # oops — lost 3 commits

git reflog                    # find the hash before the reset
# a1b2c3d HEAD@{0}: reset: moving to HEAD~3    ← the bad reset
# e4f5a6b HEAD@{1}: commit: feat: auth complete ← this is what we want

git reset --hard HEAD@{1}     # go back to where we were
# or equivalently:
git reset --hard e4f5a6b
```

**Recover a deleted branch**
```bash
git branch -D feat/payments   # deleted before merging

git reflog                    # find the last commit on that branch
# b3c4d5e HEAD@{4}: checkout: moving from feat/payments to main
#   ↑ this shows where HEAD was when we were on that branch

# Or search the reflog more specifically
git reflog show feat/payments 2>/dev/null || \
  git reflog | grep "feat/payments" | head -5

# Recreate the branch at that commit
git checkout -b feat/payments b3c4d5e
```

**Recover a lost commit after rebase**
```bash
git rebase origin/main        # went wrong — some commits disappeared

git reflog                    # shows each step of the rebase
# HEAD@{0}: rebase finished: refs/heads/feat/auth onto abc123
# HEAD@{1}: rebase: fix: handle null customer
# HEAD@{2}: rebase: feat: add customer validation        ← this one is missing from result
# HEAD@{3}: rebase: feat: add auth endpoint
# HEAD@{4}: checkout: moving from feat/auth to abc123

# Apply the missing commit to current branch
git cherry-pick HEAD@{2}
```

**Recover an amended commit**
```bash
# You amended a commit but the old version had something important
git commit --amend            # old commit is now unreachable

git reflog
# a1b2c3d HEAD@{0}: commit (amend): feat: add auth endpoint (v2)
# e4f5a6b HEAD@{1}: commit: feat: add auth endpoint (original) ← want this

# Create a branch at the original commit to inspect it
git checkout -b recovery/original-commit e4f5a6b
git show HEAD                 # verify it's what you want
# Then cherry-pick the piece you need back onto your branch
git switch feat/auth
git cherry-pick e4f5a6b -- src/specific-file.cs   # just one file if needed
```

**Deeper recovery — when reflog entries have expired**
```bash
# Find dangling commits directly from the object store
git fsck --lost-found          # lists unreachable objects
# dangling commit a1b2c3d...
# dangling commit e4f5a6b...

# Inspect each one to find what you lost
git show a1b2c3d
git log --oneline a1b2c3d

# Restore by creating a branch at the dangling commit
git branch recovered-work a1b2c3d

# git fsck also copies objects to .git/lost-found/commit/
ls .git/lost-found/commit/    # each file is named after the hash
```

**Managing reflog expiry**
```bash
# View current expiry settings
git config gc.reflogExpire           # default: 90 days
git config gc.reflogExpireUnreachable  # default: 30 days

# Extend expiry for important repos (add to ~/.gitconfig)
git config --global gc.reflogExpire "180 days"
git config --global gc.reflogExpireUnreachable "60 days"

# Manually expire old reflog entries
git reflog expire --expire=30.days refs/heads/main

# Delete a specific reflog entry (rare)
git reflog delete HEAD@{5}
```

---

## Real World Example

A senior engineer was preparing a release branch for a major version cut. During an interactive rebase to clean up 15 commits into 5 logical ones, their terminal crashed mid-rebase. When they reconnected, the branch appeared to have only 3 commits — 12 had vanished. No backup, no pushed copy, no stash.

```bash
# State after the crash: only 3 commits visible
git log --oneline
# a1b2c3d Add deployment config
# e4f5a6b Update dependencies
# f7g8h9i Initial project setup

# Step 1: check reflog for the pre-rebase state
git reflog
# a1b2c3d HEAD@{0}: rebase (finish): returning to refs/heads/release/v4
# 9d8c7b6 HEAD@{1}: rebase (squash): Add deployment config
# c2d3e4f HEAD@{2}: rebase (squash): Update dependencies
# ...
# f9a3d12 HEAD@{13}: rebase (start): checkout abc1234  ← rebase started here
# b8e7d6c HEAD@{14}: commit: feat: final feature for v4  ← pre-rebase tip!

# Step 2: the original branch tip was HEAD@{14}
git show b8e7d6c --stat
# Yes — this is the full 15-commit history before rebase

# Step 3: recover by resetting to the pre-rebase state
git reset --hard b8e7d6c

git log --oneline
# b8e7d6c feat: final feature for v4
# a7f6e5d feat: add feature X
# 9c8b7a6 fix: edge case in Y
# ... (all 15 commits back)

# Step 4: redo the rebase more carefully (in a safe terminal this time)
git rebase -i HEAD~15

echo "All 15 commits recovered. Rebase completed without data loss."
```

*The key insight: the reflog entry `HEAD@{14}` captured the exact state of the branch one step before the rebase began. The rebase didn't delete anything — it just moved HEAD away from the original commits, making them temporarily unreachable. The 30-day GC window gave a comfortable recovery window.*

---

## Common Misconceptions

**"The reflog is pushed to the remote"**
The reflog exists only in `.git/logs/` on your local machine. It is never pushed, fetched, or cloned. If a teammate force-pushes over commits on the remote, your reflog shows your local history — not their overwritten remote commits. You can't use your reflog to recover commits that only existed on a remote that has since been overwritten.

**"git gc immediately deletes unreachable objects"**
`git gc` runs `git reflog expire` first, which marks old reflog entries for removal, and then prunes objects that are unreachable from both the current refs AND the reflog. Objects referenced by any reflog entry — even an old one — are not pruned. The default `gc.reflogExpireUnreachable` of 30 days means you have a 30-day window to recover any unreachable commit, even after branch deletion.

**"HEAD@{N} counts back N commits"**
`HEAD@{N}` counts back N *HEAD movements*, not N commits. A rebase of 10 commits produces 10+ HEAD movements (one per replayed commit, plus the start and finish). `HEAD@{5}` after a large rebase may point to a mid-rebase state rather than a commit you made. Always read the action column in `git reflog` output before using `HEAD@{N}` in a reset.

---

## Gotchas

- **The reflog is local and not cloned.** If a teammate force-pushed and overwrote commits, your reflog shows your history — not theirs. You can't use your reflog to recover their overwritten remote commits.

- **`git gc --prune=now` immediately expires unreachable objects, making reflog entries that point to them useless.** Never run aggressive GC on a repo where you suspect you need to recover something.

- **Reflog doesn't track untracked files or the working directory.** If you ran `--hard` on files you never committed, those changes are gone. Reflog only recovers committed work.

- **The 90-day expiry is the default but can be changed.** Check `git config gc.reflogExpire` — some CI environments set this to a very short value to save disk space, eliminating your recovery window.

- **`HEAD@{N}` counts back in HEAD movements, not commits.** A rebase of 10 commits produces 10+ HEAD movements. Always read the reflog action column before resetting to a specific entry.

- **Per-branch reflogs (`git reflog show main`) and HEAD reflog (`git reflog`) are separate files.** After switching branches, `git reflog` (HEAD) shows the checkout event, but the branch-specific reflog still contains every commit made while on that branch. Both are useful for different recovery scenarios.

---

## Interview Angle

**What they're really testing:** Whether you understand how Git's object model works — specifically that "deleted" commits aren't immediately gone — and whether you can recover from production mistakes confidently.

**Common question forms:**
- "Have you ever lost work in Git? How did you recover it?"
- "What is the reflog and when would you use it?"
- "How would you recover a branch that was accidentally deleted?"

**The depth signal:** A junior knows that reflog exists and that you can use it to undo a bad reset. A senior explains why it works — that Git commits are content-addressed immutable objects that remain in the object store until GC runs, that reflog is just a log of hash pointers to those objects, and that `git fsck --lost-found` is the deeper tool when reflog entries have already expired but GC hasn't run yet. They also know reflog is local-only and what that means for team recovery scenarios.

**Follow-up questions to expect:**
- "How long do you have to recover a commit after an accidental `git reset --hard`?"
- "What's the difference between the HEAD reflog and a branch-specific reflog?"

---

## Related Topics

- [git-reset.md](git-reset.md) — The most common operation that makes reflog necessary; `--hard` resets are recoverable via reflog if caught before GC.
- [git-revert.md](git-revert.md) — The safer alternative that doesn't require reflog recovery because it doesn't remove commits from history.
- [git-internals.md](git-internals.md) — The reflog works because unreachable objects persist in `.git/objects` until GC; understanding the object model explains why recovery is possible.
- [git-bisect.md](git-bisect.md) — Both tools navigate Git history for investigative purposes; bisect finds where a bug was introduced, reflog finds where you were before you broke something locally.

---

## Source

[Git Documentation — git-reflog](https://git-scm.com/docs/git-reflog)

---
*Last updated: 2026-04-24*