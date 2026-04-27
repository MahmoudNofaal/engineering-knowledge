# Git Merging

> Merging integrates the history of one branch into another by creating a merge commit with two parent pointers, or by fast-forwarding the target branch ref if no divergence exists.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Integration that preserves full branch history with a merge commit |
| **Use when** | Integrating completed branches where history topology matters |
| **Avoid when** | You need a linear history — use rebase instead |
| **Git version** | Core since Git 1.0; `ort` strategy default since Git 2.33 |
| **Key location** | Creates new commit object in `.git/objects`; no files changed |
| **Key commands** | `git merge`, `git merge --no-ff`, `git merge --squash`, `git merge --abort` |

---

## When To Use It

Use merge to integrate completed feature branches into a shared branch. Prefer merge over rebase when preserving the exact history of when and how branches diverged matters — for audit trails, release branches, or team branches where others have pulled the feature branch. Don't merge unfinished work into main. Don't merge when you want a linear history — that's what rebase is for.

---

## Core Concept

Git merge finds the common ancestor of two branches, computes what changed on each branch since that ancestor, and combines those changes. If the target branch hasn't moved since the feature branch was created, Git can fast-forward — just move the branch ref forward, no new commit needed. If both branches have diverged, Git creates a merge commit with two parents. The merge commit records that both histories happened and when they converged. Unlike rebase, merge never rewrites existing commit hashes — it only adds a new commit on top.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | Three-way merge as the core integration mechanism |
| Git 1.5 | `--squash` flag added for linear history integration |
| Git 1.7.4 | `--no-ff` became the standard flag to force a merge commit |
| Git 2.9 | Improved rename detection in three-way merge |
| Git 2.33 | `ort` (Ostensibly Recursive's Twin) strategy replaced `recursive` as default — significantly faster on large merges and complex renames |
| Git 2.34 | `ort` strategy stabilized; major correctness improvements for criss-cross merges |

*The `ort` strategy in Git 2.33 is a full rewrite of the merge algorithm. On repos with many renames and complex histories, it can be 10× faster than `recursive`. If you see `recursive` in old scripts, it still works but `ort` is preferred.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Fast-forward merge | O(1) | Just moves the branch ref — no content operation at all |
| Three-way merge (no conflicts) | O(changed files) | Reads the two branch tips and their common ancestor |
| Three-way merge (with conflicts) | O(conflicted files) | Pauses for human resolution on each conflicted file |
| `--squash` merge | O(diff size) | Computes full diff, stages it — same cost as a large `git add` |
| Octopus merge (N branches) | O(N × files) | Merges multiple branches simultaneously; no conflict resolution |

**Allocation behaviour:** A merge commit is a commit object in `.git/objects` with two parent hash pointers instead of one. The merge commit itself is typically 200–400 bytes — the same size as any other commit. No files are duplicated; Git still stores only one copy of each blob.

**Benchmark notes:** The main performance variable in merging is rename detection. The `ort` strategy (Git 2.33+) uses a smarter algorithm that avoids recomputing rename pairings multiple times on complex merges. On a repo with 50,000 files and heavy rename history, a complex merge that took 45 seconds with `recursive` completes in under 5 seconds with `ort`.

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
git diff --staged               # inspect what the merge would produce
git merge --abort               # back out cleanly
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

# Configure VS Code as the merge tool
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'

# 3. Or resolve manually, then mark as resolved
# edit the file, remove conflict markers
git add resolved-file.py

# 4. Complete the merge
git commit                 # Git pre-fills the merge commit message

# Abort the entire merge and go back to pre-merge state
git merge --abort
```

**Merge strategies and strategy options**
```bash
# Default: ort (Git 2.33+) or recursive (older) — handles most cases correctly
git merge feature/auth

# Strategy option: take our version for all conflicts
git merge -X ours feature/auth       # -X = strategy option (not -s strategy)

# Strategy option: take their version for all conflicts
git merge -X theirs feature/auth

# Strategy: ours — completely ignore the incoming branch (rare, intentional)
git merge -s ours feature/old-experiment   # records merge but keeps none of their changes

# Octopus: merge multiple branches at once (no conflict resolution possible)
git merge feature/auth feature/payments feature/notifications

# Increase rename detection threshold (default 50%)
git merge -X rename-threshold=80 feature/auth
```

**Viewing merge history**
```bash
# Show merge commits only
git log --merges --oneline

# Show commits excluding merges
git log --no-merges --oneline

# What commits came in via a specific merge
git log main..feature/auth --oneline   # commits on feature not on main

# Show the merge base (common ancestor)
git merge-base main feature/auth

# Check if a branch is already merged
git branch --merged main   # branches fully merged into main
git branch --no-merged main  # branches with unmerged commits
```

**Undoing a merge**
```bash
# Undo a merge that hasn't been pushed (moves ref back)
git reset --hard HEAD~1       # only if merge commit is the last commit

# Revert a merge commit that has been pushed
# -m 1 = keep parent 1 (main line), undo parent 2 (feature)
git revert -m 1 <merge-commit-hash>
# Creates a new commit that undoes the merge — safe for shared branches

# WARNING: after reverting a merge, re-merging that branch won't work
# Git sees the branch as already merged — revert the revert first
git revert <revert-commit-hash>   # revert the revert
git merge feature/auth             # now the re-merge works correctly
```

---

## Real World Example

A release engineering team maintained three supported versions of their API (v3.1, v3.2, v4.0). A critical auth bypass was patched on main and needed to go into all three release branches. The team used `--no-ff` on all release branches to preserve clear merge points for audit logging, combined with cherry-pick for the targeted fix.

```bash
# Patch landed on main as commit a7f3d91
git log --oneline -1
# a7f3d91 fix(auth): prevent token reuse after explicit logout (CVE-2026-0142)

# Merge into v4.0 release branch — clean, no conflicts
git switch release/v4.0
git merge --no-ff main \
  -m "merge: security patch CVE-2026-0142 into v4.0

Merging main@a7f3d91 for auth token reuse fix.
Release: v4.0.7 — patch release scheduled 2026-04-24."

# v3.2 has diverged significantly — cherry-pick the specific commit instead
git switch release/v3.2
git cherry-pick -x a7f3d91
# -x appends: "(cherry picked from commit a7f3d91)" to the message

# v3.1 needs the cherry-pick but also has a backcompat shim
git switch release/v3.1
git cherry-pick --no-commit a7f3d91
# Inspect — the patch references TokenService which has a different name in v3.1
git diff --staged
# Adjust the staged changes for the v3.1 API surface
sed -i 's/TokenService/LegacyTokenService/g' src/Auth/AuthHandler.cs
git add src/Auth/AuthHandler.cs
git commit -m "fix(auth): prevent token reuse after logout (CVE-2026-0142)

Backport of a7f3d91 for v3.1 branch. Adapted for LegacyTokenService API.
(cherry picked from commit a7f3d91)"

# Verify all three branches have the fix
git log release/v3.1..release/v4.0 --oneline --merges
git log --all --grep="CVE-2026-0142" --oneline
```

*The key insight: `--no-ff` on long-lived release branches preserves the merge topology — audit tools can scan `git log --merges` to see exactly when each security patch entered each branch. Without `--no-ff`, fast-forward merges make that history invisible.*

---

## Common Misconceptions

**"Merge is worse than rebase — you should always rebase"**
Merge and rebase solve the same problem with different tradeoffs, neither is universally better. Merge preserves the exact history of how work happened — two people worked in parallel, then their work converged at this point in time. Rebase produces a linear history that's easier to read but rewrites hashes, making it destructive on shared branches. The right choice depends on whether history accuracy or history readability matters more for your team.

**"A fast-forward merge is a different operation from a regular merge"**
Fast-forward is not a separate algorithm — it's what happens when a three-way merge has nothing to do. If the target branch is a direct ancestor of the source branch, the "merge" is just moving the branch pointer forward. No new commit is created because there's nothing to record — the history is already linear. `--no-ff` forces a merge commit even in this case, preserving the evidence that a branch existed.

**"`--squash` merges the branch"**
`git merge --squash` does not actually merge. It computes the diff from the common ancestor to the source branch tip, stages it on the target branch, and leaves the branches as separate. From Git's perspective, the branches are *not* merged — `git branch --no-merged main` will still show the feature branch. That's why squash-merged branches can be merged again — and why you should always delete the branch after a squash merge to avoid re-applying the changes.

---

## Gotchas

- **Fast-forward erases the evidence that a branch existed.** After a fast-forward, `git log` shows a linear history — you can't tell that work happened on a separate branch. Use `--no-ff` on shared feature branches if you want the merge topology preserved for audit or rollback purposes.

- **`git merge --squash` leaves the branch unmerged from Git's perspective.** Git doesn't record a merge relationship — the branch appears in `git branch --no-merged`. If you then try to merge it again, Git won't know it's already been integrated and will try to re-apply the changes.

- **Reverting a merge commit and then re-merging the branch silently drops all changes.** This is one of the most costly Git mistakes in production. Git considers the branch already merged after the revert. You must revert the revert commit before re-merging — see `git-revert.md` for the full pattern.

- **Conflict resolution is not validated by Git.** After resolving conflicts and `git add`-ing the file, Git trusts you. If you accidentally deleted a conflict marker instead of resolving it, Git won't notice. Always run tests after resolving conflicts before committing.

- **The `ort` strategy (Git 2.33+) handles criss-cross merges correctly.** The old `recursive` strategy had correctness bugs on certain complex merge topologies. If your team uses an older Git version and encounters mysterious merge results on complex histories, upgrading Git may fix the issue without any other changes.

- **Merge commits make `git bisect` harder.** Binary search during bisect can land on a merge commit — which is hard to test because it might only exist to combine histories. Use `git bisect skip` on merge commits, or maintain a linear history with rebase if bisect reliability is critical.

---

## Interview Angle

**What they're really testing:** Whether you understand fast-forward vs merge commits, and can reason about when each is appropriate.

**Common question forms:**
- "What's the difference between merge and rebase?"
- "How do you undo a merge?"
- "What's a fast-forward merge?"

**The depth signal:** A junior says "merge combines branches." A senior explains fast-forward (ref moves forward, no new commit, only possible when histories haven't diverged) vs three-way merge (merge commit with two parents, always creates a new object). They know `--no-ff` preserves branch topology, `--squash` integrates without recording the merge relationship, and `git revert -m 1` is the safe way to undo a pushed merge. They can articulate the tradeoff: merge preserves exact history at the cost of a non-linear graph; rebase produces clean linear history at the cost of rewriting hashes.

**Follow-up questions to expect:**
- "What happens if you revert a merge commit and then try to re-merge that branch?"
- "How does Git find the common ancestor for a three-way merge?"

---

## Related Topics

- [git-rebasing.md](git-rebasing.md) — The alternative to merging — same goal, linear history, different mechanism and tradeoffs.
- [git-branches.md](git-branches.md) — Merging is how diverged branch histories converge; understanding branches is prerequisite.
- [git-internals.md](git-internals.md) — A merge commit is a commit object with two parent hashes instead of one.
- [git-cherry-pick.md](git-cherry-pick.md) — Cherry-pick applies individual commits across branches without a full merge.
- [git-merge-conflicts.md](git-merge-conflicts.md) — Deep dive on the conflict resolution workflow.
- [git-revert.md](git-revert.md) — How to safely undo a pushed merge commit.

---

## Source

[Git Book — Git Branching — Basic Branching and Merging](https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging)

---
*Last updated: 2026-04-23*