# Git Revert

> `git revert` creates a new commit that exactly undoes the changes introduced by a previous commit, without rewriting history.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A forward commit that inverts a previous commit's diff |
| **Use when** | Undoing commits that have been pushed to a shared branch |
| **Avoid when** | Commits are local only — use `git reset` for that |
| **Git version** | Core since Git 1.0; `--no-edit` improved Git 1.7.8; `-m` for merges since early versions |
| **Key location** | Creates new commit object in `.git/objects`; never removes existing objects |
| **Key commands** | `git revert <hash>`, `git revert -m 1 <merge-hash>`, `git revert --no-commit`, `git revert HEAD~3..HEAD` |

---

## When To Use It

Use `git revert` any time you need to undo a commit that has already been pushed to a shared branch. It's the correct tool for rolling back a bad deploy, removing a feature that caused a production issue, or undoing a merge commit. Because it adds a commit rather than removing one, history stays intact and teammates' local branches don't diverge. Use `git reset` instead only when you're undoing local, unpushed commits.

---

## Core Concept

Revert works by computing the inverse diff of the target commit and applying it as a new commit. If commit `a1b2c3` added 20 lines, the revert of `a1b2c3` removes exactly those 20 lines. The original commit stays in history — you can see that the change was made, then undone, and why. This audit trail is valuable in production systems. The tricky case is reverting a merge commit: you have to specify which parent to revert to (`-m 1` means "treat the first parent as the mainline"), because a merge commit has two parents and Git needs to know which side represents the state before the merge.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | `git revert` available as a core command |
| Git 1.7.2 | `--no-commit` (-n) flag to stage revert without committing |
| Git 1.7.8 | `--no-edit` flag to skip the editor and use the default message |
| Git 1.8.4 | Range revert (`git revert A..B`) stabilised |
| Git 2.13 | `--signoff` flag added to append `Signed-off-by` trailer |
| Git 2.34 | Improved conflict markers during revert to include more context |

*Range revert (`git revert A..B`) reverses commits from oldest to newest by default, which is usually correct — it's the opposite of how you applied them. Reversing them in the wrong order can produce unnecessary conflicts.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `git revert <hash>` | O(diff size of that commit) | Applies the inverse patch; creates one new commit |
| `git revert A..B` (range) | O(N commits × avg diff size) | Applies inverse patches one by one; one commit per revert by default |
| `git revert --no-commit A..B` | O(N commits × avg diff size) | Same patch application; skips N-1 commit operations |
| Reverting a merge commit | O(diff of merged branch) | Must read both parents to compute the inverse; can be large |

**Allocation behaviour:** Each revert creates one new commit object. No objects are modified or removed. The original commit remains unchanged in `.git/objects`. On large-scale history rewrites (reverting many commits), `--no-commit` followed by a single `git commit` is more efficient and produces a cleaner history than N individual revert commits.

**Benchmark notes:** Reverting a commit that touched many files triggers a full index update. On repos with 50,000+ files, even a small revert can take several seconds due to index writes. Use `--no-commit` and batch multiple reverts into one commit to reduce index churn.

---

## The Code

**Revert a single commit**
```bash
git log --oneline             # find the commit to undo
git revert a1b2c3d            # creates a new "Revert" commit immediately

# Git opens the editor with a pre-filled message:
# Revert "Add discount calculation for bulk orders"
#
# This reverts commit a1b2c3d...

# Skip the editor (use the default message)
git revert --no-edit a1b2c3d
```

**Revert without auto-committing — inspect first**
```bash
git revert --no-commit a1b2c3d    # -n for short
git diff --staged                 # inspect what will be reverted
# Satisfied? Commit with a better message than the default
git commit -m "revert: remove broken discount calculation

Reverting a1b2c3d — the bulk discount formula was applying 
the percentage twice for orders over $1000. Caused ~$40k in 
under-charging over 72 hours. Fix tracked in issue #891."

# Or abort the revert
git revert --abort
```

**Revert a range of commits**
```bash
# Revert the last 3 commits (creates 3 separate revert commits)
git revert HEAD~3..HEAD

# Revert to a single squashed commit (cleaner history)
git revert --no-commit HEAD~3..HEAD
git commit -m "revert: roll back payment refactor (a1b..d4e)

Rolling back the payment service refactor that introduced
a race condition under high load. Will re-attempt with
proper locking — see issue #904."

# Revert a specific range of older commits
git log --oneline               # find start and end hashes
git revert --no-commit abc123..def456
git commit -m "revert: remove experimental search feature"
```

**Revert a merge commit**
```bash
git log --oneline --graph       # identify the merge commit and its parents
# * e4f5a6b  Merge pull request #217 from feat/payment-refactor
# |\
# | * d3c2b1a Add new payment processor integration
# | * c2b1a0f Refactor PaymentService to use strategy pattern
# |/
# * a9b8c7d Previous main commit

git revert -m 1 e4f5a6b
# -m 1 = keep parent 1 (main line, the left side) as the mainline
# -m 2 = keep parent 2 (the feature branch) as the mainline
# Almost always -m 1 when reverting a PR merge

# After reverting a merge: re-merging the branch WILL NOT work
# Git considers the branch already merged and silently drops all changes
# To re-merge after a revert, you must FIRST revert the revert:
git revert f7g8h9i              # revert the revert commit
git merge feat/payment-refactor # now the re-merge works correctly
```

**Revert with cherry-pick style — multiple targets**
```bash
# Revert specific non-contiguous commits
git revert --no-commit a1b2c3
git revert --no-commit d4e5f6
git revert --no-commit g7h8i9
git commit -m "revert: remove three experimental features for v2.0 release"

# Check the result before committing
git diff HEAD
```

**Emergency rollback pattern**
```bash
# Production is down — fastest safe rollback
LAST_GOOD_TAG="v3.11.2"
BAD_MERGE_COMMIT=$(git log --merges --oneline origin/main | head -1 | awk '{print $1}')

echo "Rolling back to state before: $BAD_MERGE_COMMIT"

git switch main
git pull origin main

# Revert the bad merge
git revert -m 1 --no-edit $BAD_MERGE_COMMIT

# Push immediately
git push origin main

echo "Rollback committed. Monitor deployment pipeline."
echo "Root cause investigation: git show $BAD_MERGE_COMMIT"
```

---

## Real World Example

A fintech team merged a PR that refactored their interest calculation engine on a Thursday evening. By Friday morning, customer support had received 200 complaints about incorrect account balances. The merge had passed all tests because the interest model tests used rounded values — the bug only appeared on accounts with balances above $500,000 where floating-point precision diverged.

```bash
# The bad merge commit
git log --oneline --merges -3
# f3a9c12 Merge pull request #334 from feat/interest-engine-refactor
# a7d2e89 Merge pull request #331 from feat/dashboard-improvements  ← fine
# b1c4f67 Merge pull request #328 from fix/login-throttle            ← fine

# Step 1: immediate rollback — revert just the bad merge
git switch main
git pull origin main
git revert -m 1 --no-edit f3a9c12
# Auto-merging src/Finance/InterestCalculator.cs — clean
# [main 9e1d4a5] Revert "Merge pull request #334 from feat/interest-engine-refactor"

# Step 2: push and notify
git push origin main
# Pipeline deploys automatically — back to pre-refactor behaviour in ~4 minutes

# Step 3: communicate clearly in the revert commit message (amend while fresh)
git commit --amend -m "revert: roll back interest engine refactor (#334)

Root cause: floating-point precision loss on balances > $500k.
The refactor replaced decimal arithmetic with double — a correctness regression
that passed tests because test fixtures used values < $10k.

Impact: ~200 accounts affected, Friday 09:00–09:47 UTC.
Recalculation job scheduled: ops/recalculate-interest-2026-04-18.sh

PR #334 reopened with fix required: use decimal throughout.
Do not re-merge until reviewed by @finance-lead."

git push --force-with-lease origin main  # amend requires force

# Step 4: the re-merge path (after fix is implemented)
# 1. Fix the bug in feat/interest-engine-refactor
# 2. Revert the revert:
git revert 9e1d4a5   # revert commit from step 1
# 3. Re-merge the fixed branch
git merge feat/interest-engine-refactor
```

*The key insight: the revert commit message is not a technical artifact — it's the incident record. Write it for the engineer who gets paged at 2am six months from now and needs to understand what happened, why this revert exists, and whether it's safe to re-merge the original branch.*

---

## Common Misconceptions

**"git revert undoes the commit — it's gone from history"**
Revert adds a commit, never removes one. The original commit stays in history permanently. `git log` will show: the original commit, then the revert commit that undoes it. This is by design — production systems need audit trails. If you want the commit genuinely gone from history, you need `git reset` + force push (local only) or `git filter-repo` (destructive history rewrite, requires coordination).

**"After reverting a merge, I can just re-merge the branch once it's fixed"**
This is the most dangerous merge commit misconception. After `git revert -m 1 <merge-commit>`, Git records that the branch's changes were intentionally removed. When you try to re-merge the feature branch, Git sees the commits as already integrated — it merges with an empty diff, silently dropping everything from the original branch. You must revert the revert commit first, then re-merge. Always.

**"git revert --no-commit means the revert doesn't happen"**
`--no-commit` means the inverse patch is applied to the staging area but not committed yet. The changes are staged and real — you can see them with `git diff --staged`. It's useful for batching multiple reverts into one commit or reviewing the revert before committing. It does not skip or delay the revert — it just lets you control when the commit happens.

---

## Gotchas

- **Reverting a merge commit and then re-merging the branch silently drops all changes.** This is one of the most costly Git mistakes in production incident response. Always revert the revert before re-merging. See the Real World Example for the full pattern.

- **`git revert` can conflict just like a merge.** If later commits modified the same lines that the revert wants to restore, you'll get conflict markers and must resolve them manually. Don't assume revert is always clean.

- **The auto-generated revert message loses context.** The default "Revert 'feat: add X'" is fine for the record but add a `why` in the commit body — write it for the future on-call engineer, not for yourself right now.

- **Reverting a migration commit in application code doesn't roll back the database.** If the reverted commit included an `up` migration, the schema change is still in the database. You need a separate `down` migration or manual schema rollback coordinated with the code revert.

- **Range revert `A..B` applies reverts from newest to oldest by default in some Git versions.** Verify with `git log --oneline A..B` which commits are in the range and in what order before running the range revert. Reversing in the wrong order can create unnecessary conflicts.

- **`git revert --abort` only works while a conflict is unresolved.** Once you've run `git commit` after resolving conflicts, the revert is done — there's nothing to abort. If you committed a bad revert, you need to revert the revert.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between history rewriting (reset) and history appending (revert), and the re-merge trap after reverting a merge commit.

**Common question forms:**
- "What's the difference between `git revert` and `git reset`?"
- "How would you roll back a bad deploy that's already been pushed?"
- "What happens if you revert a merge commit and then try to re-merge the branch?"

**The depth signal:** A junior says revert creates a new commit and reset removes the old one. A senior explains the merge commit revert trap — specifically that reverting a merge commit and then trying to re-merge the branch will silently drop all changes because Git marks it as already merged, and the correct recovery is to revert the revert. They also know `--no-commit` for batching reverts, `-m 1` for merge commits, and that database migrations need a separate rollback step that git revert alone doesn't handle.

**Follow-up questions to expect:**
- "How do you re-merge a branch after reverting its merge commit?"
- "When would you use `git revert` vs `git reset` vs `git filter-repo`?"

---

## Related Topics

- [git-reset.md](git-reset.md) — The history-rewriting alternative; appropriate for local unpushed commits where you want to remove the commit entirely.
- [git-reflog.md](git-reflog.md) — If a revert itself goes wrong, reflog lets you find the pre-revert state and recover.
- [git-merging.md](git-merging.md) — Understanding merge commits (two-parent commits) is prerequisite to understanding `-m 1` when reverting them.
- [git-merge-conflicts.md](git-merge-conflicts.md) — Reverts can produce conflicts for the same reason merges do: later changes overlap with the lines being un-applied.

---

## Source

[Git Documentation — git-revert](https://git-scm.com/docs/git-revert)

---
*Last updated: 2026-04-24*