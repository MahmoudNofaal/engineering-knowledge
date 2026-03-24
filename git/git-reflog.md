# Git Reflog

> The reflog is Git's internal log of every position HEAD has pointed to, giving you a recovery path after destructive operations like `reset --hard`, `rebase`, or accidental branch deletion.

---

## When To Use It

Reach for the reflog any time you've lost commits that you thought were gone — after a bad `--hard` reset, a rebase gone wrong, a branch deleted before merging, or an amended commit you want to recover. The reflog is local only: it exists on your machine and is not pushed to the remote. It expires after 90 days by default. It won't help you recover files that were never committed.

---

## Core Concept

Every time HEAD moves — from a commit, checkout, reset, merge, rebase, or anything else — Git appends an entry to `.git/logs/HEAD`. The reflog is that log. Each entry has a short-form reference (`HEAD@{N}`) that you can use exactly like a commit hash in any Git command. The key insight is that in Git, commits are never immediately deleted — they become "unreachable" (no branch points to them), but they still exist in the object store until garbage collection runs. Reflog gives you the hashes of those unreachable commits so you can reach them again before GC cleans them up.

---

## The Code
```bash
# ── View the reflog ──────────────────────────────────────────────────
git reflog                    # HEAD's movement history, most recent first
git reflog show main          # reflog for a specific branch, not just HEAD

# Output looks like:
# a1b2c3d HEAD@{0}: commit: feat: add JWT refresh
# e4f5a6b HEAD@{1}: rebase finished: refs/heads/feat/auth onto f7g8h9i
# f7g8h9i HEAD@{2}: reset: moving to HEAD~3
# 9d8c7b6 HEAD@{3}: commit: fix: null check in cart service

# ── Recover from accidental --hard reset ─────────────────────────────
git reset --hard HEAD~3       # oops — lost 3 commits
git reflog                    # find the hash before the reset
git reset --hard HEAD@{1}     # or use the actual hash: git reset --hard a1b2c3d

# ── Recover a deleted branch ─────────────────────────────────────────
git branch -D feat/payments   # deleted before merging
git reflog                    # find the last commit on that branch
git checkout -b feat/payments a1b2c3d   # recreate branch at that commit

# ── Recover a lost commit after rebase ───────────────────────────────
git rebase origin/main        # went wrong, some commits seem missing
git reflog                    # entries show each step of the rebase
git cherry-pick e4f5a6b       # pick the lost commit back onto current branch

# ── Inspect what happened in a time window ───────────────────────────
git reflog --since="2 hours ago"
git reflog --before="2026-03-24 10:00"

# ── Find dangling commits directly (alternative to reflog) ───────────
git fsck --lost-found          # lists unreachable commit objects
# Commits appear in .git/lost-found/commit/ — inspect with git show <hash>
```

---

## Gotchas

- **The reflog is local and not cloned.** If a teammate force-pushed and overwrote commits, your reflog shows your history — not theirs. You can't use your reflog to recover their overwritten remote commits.
- **`git gc --prune=now` immediately expires unreachable objects, making reflog entries that point to them useless.** Never run aggressive GC on a repo where you suspect you need to recover something.
- **Reflog doesn't track untracked files or the working directory.** If you ran `--hard` on files you never committed, those changes are gone. Reflog only recovers committed work.
- **The 90-day expiry is the default but can be changed.** Check `git config gc.reflogExpire` — some CI environments set this to a very short value to save disk space, eliminating your recovery window.
- **`HEAD@{N}` counts back in HEAD movements, not commits.** A rebase of 10 commits produces 10+ HEAD movements. `HEAD@{5}` after a large rebase may not be where you expect — always read the reflog action column before resetting to it.

---

## Interview Angle

**What they're really testing:** Whether you understand how Git's object model works — specifically that "deleted" commits aren't immediately gone — and whether you can recover from production mistakes confidently.

**Common question form:** "Have you ever lost work in Git? How did you recover it?" or "What is the reflog and when would you use it?"

**The depth signal:** A junior knows that reflog exists and that you can use it to undo a bad reset. A senior explains why it works — that Git commits are content-addressed immutable objects that remain in the object store until GC runs, that reflog is just a log of hash pointers to those objects, and that `git fsck --lost-found` is the deeper tool when reflog entries have already expired but GC hasn't run yet.

---

## Related Topics

- [[git/git-reset.md]] — The most common operation that makes reflog necessary; `--hard` resets are recoverable via reflog if caught before GC.
- [[git/git-revert.md]] — The safer alternative that doesn't require reflog recovery because it doesn't remove commits from history.
- [[git/git-bisect.md]] — Both tools navigate Git history for investigative purposes; bisect finds where a bug was introduced, reflog finds where you were before you broke something locally.
- [[git/git-workflows.md]] — Force-pushes in shared-branch workflows are the team-level version of the problem reflog solves individually.

---

## Source

[Git Documentation — git-reflog](https://git-scm.com/docs/git-reflog)

---
*Last updated: 2026-03-24*