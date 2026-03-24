# Git Merging

> Merging integrates the history of one branch into another by creating a merge commit with two parent pointers, or by fast-forwarding the target branch ref if no divergence exists.

---

## When To Use It

Use merge to integrate completed feature branches into a shared branch. Prefer merge over rebase when preserving the exact history of when and how branches diverged matters — for audit trails, release branches, or team branches where others have pulled the feature branch. Don't merge unfinished work into main. Don't merge when you want a linear history — that's what rebase is for.

---

## Core Concept

Git merge finds the common ancestor of two branches, computes what changed on each branch since that ancestor, and combines those changes. If the target branch hasn't moved since the feature branch was created, Git can fast-forward — just move the branch ref forward, no new commit needed. If both branches have diverged, Git creates a merge commit with two parents. The merge commit records that both histories happened and when they converged. Unlike rebase, merge never rewrites existing commit hashes — it only adds a new commit on top.

---

## The Code

**Basic merge**
```bash
# Merge feature into main
git switch main
git merge feature/auth

# Fast-forward: main hasn't moved since feature branched off
# Before: main → A → B
#                      ↘ feature → C → D
# After:  main → A → B → C → D  (feature ref moves forward, no merge commit)

# Merge commit: both branches have diverged
# Before: main → A → B → E
#                  ↘ feature → C → D
# After:  main → A → B → E → M  (M has parents E and D)
#                  ↘ feature → C → D ↗
```

**Controlling merge behavior**
```bash
# Always create a merge commit — never fast-forward
# Preserves the branch topology in history
git merge --no-ff feature/auth

# Only merge if fast-forward is possible — fail otherwise
git merge --ff-only feature/auth

# Squash all feature commits into one staged change, then commit manually
# Keeps main history linear — the feature's internal commits don't appear
git merge --squash feature/auth
git commit -m "Add auth feature (#142)"

# Dry run — see what would conflict without actually merging
git merge --no-commit --no-ff feature/auth
git merge --abort   # back out cleanly
```

**Resolving conflicts**
```bash
# Conflict markers in the file:
# <<<<<<< HEAD          ← your current branch content
# code from main
# =======
# code from feature/auth
# >>>>>>> feature/auth  ← incoming branch content

# Three-stage resolution workflow:
# 1. See which files conflict
git status
git diff --diff-filter=U   # show only unmerged (conflicted) files

# 2. Use a merge tool
git mergetool              # opens configured tool (vimdiff, VS Code, etc.)

# 3. Or resolve manually, then mark as resolved
# edit the file, remove conflict markers
git add resolved-file.py

# 4. Complete the merge
git commit                 # Git pre-fills the merge commit message

# Abort the entire merge
git merge --abort
```

**Merge strategies**
```bash
# Default: ort (previously recursive) — handles most cases correctly
git merge feature/auth

# Ours: take our version for all conflicts (ignores incoming changes entirely)
git merge -X ours feature/auth       # -X = strategy option

# Theirs: take their version for all conflicts
git merge -X theirs feature/auth

# Octopus: merge multiple branches at once (no conflict resolution)
git merge feature/auth feature/payments feature/notifications

# Subtree: merge a project into a subdirectory
git merge -s subtree external-lib
```

**Viewing merge history**
```bash
# Show merge commits only
git log --merges --oneline

# Show commits excluding merges
git log --no-merges --oneline

# What commits came in via a merge
git log main..feature/auth --oneline   # commits on feature not on main

# Show the merge base (common ancestor)
git merge-base main feature/auth

# Check if a branch is already merged
git branch --merged main   # branches fully merged into main
```

**Undoing a merge**
```bash
# Undo a merge that hasn't been pushed (moves ref back)
git reset --hard HEAD~1       # only if merge commit is the last commit

# Revert a merge commit that has been pushed
# -m 1 = keep parent 1 (main line), undo parent 2 (feature)
git revert -m 1 <merge-commit-hash>
# Creates a new commit that undoes the merge — safe for shared branches
```

---

## Gotchas

- **Fast-forward erases the evidence that a branch existed.** After a fast-forward, `git log` shows a linear history — you can't tell that work happened on a separate branch. Use `--no-ff` on shared feature branches if you want the merge topology preserved for audit or rollback purposes.
- **`git merge --squash` leaves the branch unmerged from Git's perspective.** Git doesn't record a merge relationship — the branch appears in `git branch --no-merged`. If you then try to merge it again, Git won't know it's already been integrated and will try to re-apply the changes.
- **Merge commits make `git bisect` harder.** Binary search during bisect can land on a merge commit — which is hard to test because it might only exist to combine histories. `git bisect skip` handles this, but a linear rebase history avoids the problem entirely.
- **`git revert -m 1` on a merge commit doesn't undo the branch — it adds a commit that cancels the changes.** If you later want to re-merge that branch, Git sees the revert and thinks those changes were intentionally removed. You must revert the revert first before re-merging.
- **Conflict resolution is not validated by Git.** After resolving conflicts and `git add`-ing the file, Git trusts you. If you accidentally deleted a conflict marker instead of resolving it, Git won't notice. Always run tests after resolving conflicts before committing.

---

## Interview Angle

**What they're really testing:** Whether you understand fast-forward vs merge commits, and can reason about when each is appropriate.

**Common question form:** *"What's the difference between merge and rebase?"* or *"How do you undo a merge?"* or *"What's a fast-forward merge?"*

**The depth signal:** A junior says "merge combines branches." A senior explains fast-forward (ref moves forward, no new commit, only possible when histories haven't diverged) vs three-way merge (merge commit with two parents, always creates a new object). They know `--no-ff` preserves branch topology, `--squash` integrates without recording the merge relationship, and `git revert -m 1` is the safe way to undo a pushed merge. They can articulate the tradeoff: merge preserves exact history at the cost of a non-linear graph; rebase produces clean linear history at the cost of rewriting hashes.

---

## Related Topics

- [[git/git-rebasing.md]] — The alternative to merging — same goal, linear history, different mechanism and tradeoffs.
- [[git/git-branches.md]] — Merging is how diverged branch histories converge; understanding branches is prerequisite.
- [[git/git-internals.md]] — A merge commit is a commit object with two parent hashes instead of one.
- [[git/git-cherry-pick.md]] — Cherry-pick applies individual commits across branches without a full merge.

---

## Source

[Git Book — Git Branching — Basic Branching and Merging](https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging)

---
*Last updated: 2026-03-24*