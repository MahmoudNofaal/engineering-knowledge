# Git Reset

> `git reset` moves the current branch pointer to a different commit, optionally changing the staging area and working directory to match.

---

## When To Use It

Use `git reset` to undo local commits that haven't been pushed yet, to unstage files you added by mistake, or to rewrite your branch's history before sharing it. Never use `git reset` to undo commits that already exist on a shared remote branch — other engineers' histories will diverge from yours and the repo becomes inconsistent. Once a commit is pushed and others have pulled it, use `git revert` instead.

---

## Core Concept

Reset has three modes that control how far the rollback reaches. `--soft` moves the branch pointer but leaves your changes staged — as if you never committed, but the diff is ready to re-commit. `--mixed` (the default) moves the pointer and unstages changes, but leaves the files on disk as-is. `--hard` moves the pointer and wipes both the staging area and the working directory — files revert to the target commit's state and local edits are gone. Think of it as three concentric circles: `--soft` touches only the commit history, `--mixed` touches history + staging, `--hard` touches everything.

---

## The Code
```bash
# ── Unstage a file (most common daily use) ───────────────────────────
git reset HEAD src/Orders/OrderService.cs
# or in Git 2.23+:
git restore --staged src/Orders/OrderService.cs

# ── Undo last commit, keep changes staged (--soft) ───────────────────
git reset --soft HEAD~1
# Your changes are still staged, ready to re-commit with a better message

# ── Undo last commit, keep changes unstaged (--mixed / default) ──────
git reset HEAD~1
# Files are modified on disk but not staged — review before re-adding

# ── Undo last 3 commits, discard all changes (--hard) ────────────────
git reset --hard HEAD~3
# ⚠ Working directory changes are gone — unrecoverable without reflog

# ── Reset to a specific commit hash ──────────────────────────────────
git log --oneline          # find the target hash
git reset --hard a3f92c1   # move branch here, discard everything after

# ── Recover from an accidental --hard reset (via reflog) ─────────────
git reflog                 # find the commit you just lost
git reset --hard HEAD@{2}  # move back to it
```

---

## Gotchas

- **`--hard` on uncommitted changes is permanent.** Untracked files aren't touched by `--hard`, but tracked modified files are overwritten. There is no undo except `git reflog` for commits — and `reflog` can't recover uncommitted work that was never committed.
- **Resetting a pushed branch and force-pushing breaks teammates.** Anyone who pulled before your force-push now has a diverged history. Their next `git pull` produces a merge commit that resurrects the commits you deleted.
- **`HEAD~1` vs `HEAD^` are equivalent for linear history but differ on merge commits.** `HEAD^2` means the second parent of a merge commit — not two commits back. Stick to `HEAD~N` for counting back N commits unless you deliberately need a specific merge parent.
- **`git reset` on a path (`git reset -- <file>`) does NOT move the branch pointer.** It only unstages the file. The two usages look similar but do completely different things.
- **After `--soft` reset and re-commit, you still need `--force-with-lease` to push.** The rewritten commit has a new hash even if the content is identical.

---

## Interview Angle

**What they're really testing:** Whether you understand Git's three trees (HEAD, index, working directory) and can reason about what each reset mode touches.

**Common question form:** "What's the difference between `git reset --soft`, `--mixed`, and `--hard`?" or "How would you undo the last three commits without losing your work?"

**The depth signal:** A junior recites that `--hard` deletes changes and `--soft` keeps them. A senior explains it in terms of Git's three trees — that `--soft` only moves HEAD, `--mixed` also resets the index to match HEAD, and `--hard` additionally resets the working tree — and knows that `git reset <path>` is a completely different operation that doesn't move HEAD at all, plus when to use `reflog` to recover from a bad reset.

---

## Related Topics

- [[git/git-revert.md]] — The safe alternative to reset for undoing pushed commits: creates a new commit that inverts changes instead of rewriting history.
- [[git/git-reflog.md]] — The recovery mechanism when a `--hard` reset goes wrong; tracks every position HEAD has been, including after destructive operations.
- [[git/git-merge-conflicts.md]] — `git reset --hard` is often used to abort a merge mid-conflict; understanding what it resets to matters here.
- [[git/git-workflows.md]] — Reset is only safe on unshared branches; your workflow's branch model determines when reset is appropriate vs. dangerous.

---

## Source

[Git Documentation — git-reset](https://git-scm.com/docs/git-reset)

---
*Last updated: 2026-03-24*