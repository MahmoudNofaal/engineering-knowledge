# Git Cherry-Pick

> Cherry-pick applies the changes introduced by a specific commit onto the current branch, creating a new commit with the same diff but a different hash.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Targeted commit transplant — applies one commit's diff to a different base |
| **Use when** | Backporting a fix to a release branch; rescuing a commit from an abandoned branch |
| **Avoid when** | You're doing this repeatedly — it signals a broken branching strategy |
| **Git version** | Core since Git 1.0; `-x` (source reference) since Git 1.6; `--skip` added Git 2.35 |
| **Key location** | Creates new commit object in `.git/objects`; original commit is unchanged |
| **Key commands** | `git cherry-pick <hash>`, `git cherry-pick -x`, `git cherry-pick --no-commit`, `git cherry-pick -m 1` |

---

## When To Use It

Use cherry-pick to port a specific fix from one branch to another without merging the entire branch — backporting a bugfix from main to a release branch, pulling a hotfix into multiple maintained versions, or rescuing a commit from an abandoned branch. Don't use cherry-pick as a substitute for proper branching strategy — if you find yourself cherry-picking the same commits repeatedly across many branches, your branching model needs rethinking.

---

## Core Concept

Cherry-pick computes the diff introduced by a commit (what changed between that commit and its parent), then applies that diff to the current HEAD. It creates a new commit object with the same author, message, and changes — but a different parent (your current branch's HEAD) and therefore a different hash. The original commit is untouched. If the same lines were modified differently in both branches, you get a conflict just like a merge conflict.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | `git cherry-pick` available as a core command |
| Git 1.6.0 | `-x` flag added to append source commit reference to message |
| Git 1.7.2 | `--no-commit` (-n) flag stabilised |
| Git 1.7.8 | `--signoff` flag added |
| Git 2.0 | `--allow-empty` and `--allow-empty-message` added |
| Git 2.35 | `--skip` flag added — skip conflicting commits instead of aborting |
| Git 2.38 | Improved conflict markers showing cherry-pick source context |

*The `-x` flag is essential for release branch workflows. It appends `(cherry picked from commit abc1234)` to the commit message, creating a traceable link back to the origin. Without it, future engineers can't tell which main-branch commit a release-branch fix corresponds to.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Single cherry-pick | O(diff size of that commit) | Applies one patch; creates one commit |
| Range cherry-pick `A..B` | O(N commits × avg diff) | Applies patches one by one |
| Cherry-pick with conflicts | O(conflict resolution time) | One pause per conflicting commit |
| `--no-commit` batch | O(N diffs) | Applies all patches staged; skips N-1 commit operations |

**Allocation behaviour:** Each cherry-pick creates one new commit object. The original commit remains unchanged. When cherry-picking a large range, `--no-commit` reduces the number of commit objects created and is faster — though at the cost of a single squashed result rather than individual commits.

**Benchmark notes:** Cherry-pick on a commit that touched many files is slower than on a commit with a small diff, because Git must apply the diff to the current index. On monorepos with 100,000+ files, limit cherry-picks to commits with focused changes to keep operation time under a second.

---

## The Code

**Basic cherry-pick**
```bash
# Apply a single commit to current branch
git switch release/v1.2
git cherry-pick abc1234

# The result: a new commit on release/v1.2 with the same changes as abc1234
# but a different hash because the parent is different
```

**Cherry-pick with source reference (-x) — essential for traceability**
```bash
# Append "(cherry picked from commit abc1234)" to the commit message
git cherry-pick -x abc1234

# Result message:
# fix(auth): prevent token reuse after logout
#
# (cherry picked from commit abc1234)
```

**Cherry-pick multiple commits**
```bash
# Pick several specific commits (applied in order given)
git cherry-pick abc1234 def5678 ghi9012

# Pick a range — commits AFTER abc1234 up to and including def5678
# (abc1234 is EXCLUDED — this is the most common gotcha)
git cherry-pick abc1234..def5678

# Pick a range INCLUDING the start commit
git cherry-pick abc1234^..def5678

# Pick a range without auto-committing (produce one squashed commit)
git cherry-pick --no-commit abc1234^..def5678
git commit -m "backport: auth security fixes for v1.2 release"
```

**Handling conflicts during cherry-pick**
```bash
# Cherry-pick stops on conflict — same markers as merge
# <<<<<<< HEAD
# current branch version
# =======
# cherry-picked version
# >>>>>>> abc1234

# 1. Resolve the conflict
# edit the file...

# 2. Stage resolved files
git add src/auth.py

# 3. Continue to the next commit in the cherry-pick sequence
git cherry-pick --continue

# Skip this commit (apply nothing for it, move to next)
git cherry-pick --skip      # Git 2.35+

# Abort — revert to pre-cherry-pick state
git cherry-pick --abort
```

**Cherry-picking a merge commit**
```bash
# Cherry-picking a merge commit requires specifying the mainline parent
git log --oneline --graph
# * e4f5a6b Merge branch 'feat/payment-refactor' into main
# |\
# | * d3c2b1a Add Stripe webhook handler
# | * c2b1a0f Add payment retry logic
# |/
# * a9b8c7d Previous commit on main

# -m 1 = use parent 1 (main) as the base — apply what the merge brought in
git cherry-pick -m 1 e4f5a6b
# Applies the full diff of the feature branch relative to main
```

**Finding the right commit to cherry-pick**
```bash
# Find commits on main that aren't on release/v1.2
git log release/v1.2..main --oneline

# Search by message keyword
git log --grep="fix: null pointer" --oneline main

# Search by code change (pickaxe) — find when a specific string was added/removed
git log -S "authenticate_user" --oneline main

# Show exactly what a commit changed before picking it
git show abc1234
git show abc1234 --stat

# Preview if cherry-pick will conflict (dry run)
git cherry-pick --no-commit abc1234
git status                  # see what conflicts before committing
git cherry-pick --abort     # abort after inspection
```

**Backporting a bugfix — multi-version workflow**
```bash
# Bug fixed on main with commit abc1234
# Need it in release/v1.2 and release/v1.1

git switch release/v1.2
git cherry-pick -x abc1234     # -x adds the source commit reference
git push origin release/v1.2

git switch release/v1.1
git cherry-pick -x abc1234     # same commit, different target — may have different conflicts
git push origin release/v1.1

# Tag the patch releases
git switch release/v1.2
git tag -a v1.2.1 -m "Patch: backport auth fix from main (abc1234)"
git push origin v1.2.1

git switch release/v1.1
git tag -a v1.1.5 -m "Patch: backport auth fix from main (abc1234)"
git push origin v1.1.5
```

---

## Real World Example

A SaaS company maintained three active API versions: v2 (legacy, maintenance only), v3 (current), and v4 (beta). A critical SQL injection vulnerability was discovered in their query builder — the same code existed in all three versions but had diverged enough that a simple cherry-pick wouldn't work cleanly for all of them.

```bash
# Vulnerability patched on main as commit f9a3d12
git show f9a3d12 --stat
# src/Database/QueryBuilder.cs | 18 ++++++++++--------
# tests/Database/QueryBuilderTests.cs | 24 ++++++++++++++++++++++++

# === v4 (beta branch — closest to main) ===
git switch release/v4-beta
git cherry-pick -x f9a3d12
# Auto-merging src/Database/QueryBuilder.cs — clean
git push origin release/v4-beta

# === v3 (current — minor divergence) ===
git switch release/v3
git cherry-pick --no-commit f9a3d12
# CONFLICT in src/Database/QueryBuilder.cs
# v3 uses a slightly different method signature: BuildQuery() vs Build()
git diff --staged
# Resolve: adapt the patch to v3's method names
sed -i 's/\.Build(params)/\.BuildQuery(params)/g' src/Database/QueryBuilder.cs
git add src/Database/QueryBuilder.cs
git commit -m "fix(db): prevent SQL injection in query builder

Backport of main@f9a3d12 adapted for v3 method naming.
(cherry picked from commit f9a3d12)"

# === v2 (legacy — significant divergence) ===
git switch release/v2
git cherry-pick --no-commit f9a3d12
# CONFLICT — v2 uses a completely different ORM layer
# The fix logic is correct but the implementation surface is different
git cherry-pick --abort

# For v2, apply the fix manually using the logic from f9a3d12 as a guide
git show f9a3d12 -- src/Database/QueryBuilder.cs    # read the fix logic
# Implement the equivalent fix for v2's ORM
vim src/LegacyDatabase/QueryHelper.cs
git add src/LegacyDatabase/QueryHelper.cs
git commit -m "fix(db): prevent SQL injection in legacy query helper

Equivalent of main@f9a3d12 for v2 LegacyDatabase layer.
v2 uses QueryHelper (not QueryBuilder) — full reimplementation of the fix.
(cherry picked from commit f9a3d12)"

# Verify all three have the fix before tagging
git log --all --grep="f9a3d12" --oneline
# f1a2b3c (release/v4-beta) fix(db): prevent SQL injection in query builder
# d4e5f6g (release/v3) fix(db): prevent SQL injection in query builder
# h7i8j9k (release/v2) fix(db): prevent SQL injection in legacy query helper
```

*The key insight: cherry-pick is a starting point, not a guarantee. When branches have diverged significantly, treat cherry-pick output as a template — the logic is correct, but the implementation surface may need adaptation. The `-x` flag ties all three backports back to the single canonical fix, making security audit trails clean.*

---

## Common Misconceptions

**"Cherry-picking the same commit to two branches keeps them in sync"**
Cherry-picked commits are independent copies with different hashes. If the original commit is later amended or if a follow-up fix touches the same code, neither cherry-picked copy receives that update automatically. You must track and re-cherry-pick manually. Repeated cherry-picking across many branches is a maintenance debt that compounds — consider whether a monorepo or package extraction solves the root problem.

**"git cherry-pick abc..def includes abc"**
The double-dot range is exclusive of the left side — `abc..def` means "commits reachable from def but not from abc," which excludes abc itself. To include abc, use `abc^..def` (abc's parent to def). This is the most common cherry-pick mistake and silently skips the first commit in the intended range.

**"Cherry-picking a merge commit is the same as cherry-picking the feature branch commits"**
`git cherry-pick -m 1 <merge-commit>` applies the full combined diff of the merge — what the merge brought in as a whole. `git cherry-pick <feature-commit-1> <feature-commit-2>` applies each feature commit individually, which can produce different results if the feature commits interact with each other. For most backport scenarios, cherry-picking individual commits gives you more control over conflicts.

---

## Gotchas

- **Cherry-picked commits have different hashes than the originals.** If you cherry-pick abc1234 onto a release branch and later merge main into that branch, Git sees two different commits — it may try to apply the change twice, producing a conflict. Use `-x` to track the source, and be aware of this when later merging.

- **`git cherry-pick abc..def` excludes abc.** Use `abc^..def` to include it. This is the most common cherry-pick range mistake — silently missing the first commit.

- **Cherry-picking depends on the surrounding context existing in the target branch.** If a commit adds a method call but the method definition doesn't exist in the target branch (it was added in a different commit), the cherry-pick may apply cleanly but produce broken code. Always run tests after cherry-picking.

- **Cherry-picking merge commits requires `-m` to specify the mainline.** Without `-m`, cherry-picking a merge commit fails with an error. Use `-m 1` to apply what the merge brought in relative to the main parent.

- **Repeated cherry-picks across many branches create long-term maintenance debt.** Each cherry-picked commit is an independent copy — future changes to the original won't propagate. If a fix needs updating, you must track down every cherry-picked copy. This is the signal to reconsider your branching model.

- **`--no-commit` on a range applies all patches before stopping.** If any commit in the range conflicts, the entire sequence stops at that point with partial changes staged. Run `git status` carefully to understand what was and wasn't applied before committing.

---

## Interview Angle

**What they're really testing:** Whether you understand when to use cherry-pick vs merge, and know its limitations with commit dependencies.

**Common question forms:**
- "How would you apply a hotfix to multiple release branches?"
- "What's the difference between cherry-pick and merge?"
- "What are the risks of cherry-picking?"

**The depth signal:** A junior says "cherry-pick copies a commit to another branch." A senior explains that cherry-pick computes the diff between a commit and its parent, then applies that diff — so it depends on the surrounding context existing in the target branch. They know the `abc..def` range is exclusive of the left side (`abc^..def` to include it), that cherry-picking a merge commit needs `-m 1`, that `-x` is essential for traceability when backporting, and the long-term hazard: cherry-picked commits are independent copies — divergence over time is silent and cumulative.

**Follow-up questions to expect:**
- "What happens if you cherry-pick a commit and then later merge the original branch?"
- "When would you use cherry-pick vs a full merge vs a rebase?"

---

## Related Topics

- [git-merging.md](git-merging.md) — Merge integrates entire branch histories; cherry-pick takes individual commits. Know when each is appropriate.
- [git-rebasing.md](git-rebasing.md) — Rebase replays a sequence of commits onto a new base — conceptually similar to many cherry-picks in order.
- [git-branches.md](git-branches.md) — Cherry-pick is most useful when maintaining multiple long-lived branches (release branches, LTS versions).
- [git-commits.md](git-commits.md) — `git log -S` and `git show` are the tools for finding which commit to cherry-pick.
- [git-tags.md](git-tags.md) — Cherry-pick is typically paired with tagging a patch release after backporting.

---

## Source

[Git documentation — git-cherry-pick](https://git-scm.com/docs/git-cherry-pick)

---
*Last updated: 2026-04-24*