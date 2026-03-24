# Git Revert

> `git revert` creates a new commit that exactly undoes the changes introduced by a previous commit, without rewriting history.

---

## When To Use It

Use `git revert` any time you need to undo a commit that has already been pushed to a shared branch. It's the correct tool for rolling back a bad deploy, removing a feature that caused a production issue, or undoing a merge commit. Because it adds a commit rather than removing one, history stays intact and teammates' local branches don't diverge. Use `git reset` instead only when you're undoing local, unpushed commits.

---

## Core Concept

Revert works by computing the inverse diff of the target commit and applying it as a new commit. If commit `a1b2c3` added 20 lines, the revert of `a1b2c3` removes exactly those 20 lines. The original commit stays in history — you can see that the change was made, then undone, and why. This audit trail is valuable in production systems. The tricky case is reverting a merge commit: you have to specify which parent to revert to (`-m 1` means "treat the first parent as the mainline"), because a merge commit has two parents and Git needs to know which side represents the state before the merge.

---

## The Code
```bash
# ── Revert a single commit ───────────────────────────────────────────
git log --oneline             # find the commit to undo
git revert a1b2c3d            # creates a new "Revert" commit immediately

# ── Revert without auto-committing (review the diff first) ───────────
git revert --no-commit a1b2c3d
git diff --staged             # inspect what will be committed
git commit -m "revert: remove broken discount calculation (a1b2c3d)"

# ── Revert a range of commits (oldest first order matters) ───────────
git revert --no-commit HEAD~3..HEAD   # reverts last 3 commits
git commit -m "revert: roll back payment refactor"

# ── Revert a merge commit ────────────────────────────────────────────
git log --oneline --graph     # identify the merge commit hash + parents
git revert -m 1 e4f5a6b
# -m 1 = keep parent 1 (main) as the mainline
# -m 2 = keep parent 2 (the feature branch) as the mainline
# Almost always -m 1 is what you want when reverting a PR merge

# ── After reverting a merge, re-merging the branch WILL NOT work ──────
# Git sees the branch as already merged. You must revert the revert first.
git revert f7g8h9i            # revert the revert commit
git merge feat/the-branch     # now re-merge works correctly
```

---

## Gotchas

- **Reverting a merge commit and then re-merging the branch silently drops all changes.** Git considers the branch already merged. You must revert the revert commit before re-merging — this is one of the most common and costly Git mistakes in production incident response.
- **`git revert` can conflict just like a merge.** If later commits modified the same lines that the revert wants to restore, you'll get conflict markers and must resolve them manually.
- **Reverting a commit that was squash-merged is straightforward; reverting individual commits from a non-squash merge is fragile.** If you used merge commits and need to undo one commit in the middle of a merged branch, the revert diff may apply incorrectly due to later changes.
- **The auto-generated revert message loses context.** The default "Revert 'feat: add X'" is fine for the record but add a why in the commit body — "Reverting due to P0 crash in checkout when user has empty cart" is what future-you needs when reading the log.
- **Reverting a migration commit in application code doesn't roll back the database.** If the reverted commit included an `up` migration, the schema change is still in the database. You need a separate `down` migration or manual schema rollback.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between history rewriting (reset) and history appending (revert), and when each is appropriate.

**Common question form:** "What's the difference between `git revert` and `git reset`?" or "How would you roll back a bad deploy that's already been pushed?"

**The depth signal:** A junior says revert creates a new commit and reset removes the old one. A senior explains the merge commit revert trap — specifically that reverting a merge commit and then trying to re-merge the branch will silently drop all changes from that branch because Git marks it as already merged, and the correct recovery is to revert the revert — and can articulate why this makes reverting merge commits in production a deliberate, careful operation rather than a quick fix.

---

## Related Topics

- [[git/git-reset.md]] — The history-rewriting alternative; appropriate for local unpushed commits where you want to remove the commit entirely.
- [[git/git-reflog.md]] — If a revert itself goes wrong, reflog lets you find the pre-revert state and recover.
- [[git/git-workflows.md]] — Workflow determines when revert is triggered vs. a hotfix branch; some teams prefer a forward-fix to reverting.
- [[git/git-merge-conflicts.md]] — Reverts can produce conflicts for the same reason merges do: later changes overlap with the lines being un-applied.

---

## Source

[Git Documentation — git-revert](https://git-scm.com/docs/git-revert)

---
*Last updated: 2026-03-24*