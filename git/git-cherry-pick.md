# Git Cherry-Pick

> Cherry-pick applies the changes introduced by a specific commit onto the current branch, creating a new commit with the same diff but a different hash.

---

## When To Use It

Use cherry-pick to port a specific fix from one branch to another without merging the entire branch — backporting a bugfix from main to a release branch, pulling a hotfix into multiple maintained versions, or rescuing a commit from an abandoned branch. Don't use cherry-pick as a substitute for proper branching strategy — if you find yourself cherry-picking the same commits repeatedly across many branches, your branching model needs rethinking.

---

## Core Concept

Cherry-pick computes the diff introduced by a commit (what changed between that commit and its parent), then applies that diff to the current HEAD. It creates a new commit object with the same author, message, and changes — but a different parent (your current branch's HEAD) and therefore a different hash. The original commit is untouched. If the same lines were modified differently in both branches, you get a conflict just like a merge conflict.

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

**Cherry-pick multiple commits**
```bash
# Pick several specific commits (applied in order given)
git cherry-pick abc1234 def5678 ghi9012

# Pick a range — commits from abc1234 up to and including def5678
# (oldest to newest)
git cherry-pick abc1234..def5678

# Range excluding the start commit
# abc1234 is NOT included — only commits after it up to def5678
git cherry-pick abc1234..def5678

# Range INCLUDING the start commit
git cherry-pick abc1234^..def5678
```

**Options**
```bash
# -x: append "(cherry picked from commit abc1234)" to the message
# Useful for traceability on release branches
git cherry-pick -x abc1234

# --no-commit (-n): apply changes without committing
# Lets you combine multiple cherry-picks into one commit
# or inspect changes before committing
git cherry-pick -n abc1234 def5678
git commit -m "Backport auth fixes for v1.2"

# -e: edit the commit message before committing
git cherry-pick -e abc1234

# --signoff: add a Signed-off-by trailer
git cherry-pick --signoff abc1234
```

**Handling conflicts**
```bash
# Cherry-pick stops on conflict — same markers as merge
# <<<<<<< HEAD
# current branch version
# =======
# cherry-picked version
# >>>>>>> abc1234

# 1. Resolve the conflict
# edit the file

# 2. Stage resolved files
git add src/auth.py

# 3. Continue
git cherry-pick --continue

# Skip this commit (apply nothing for it, move to next)
git cherry-pick --skip

# Abort — revert to pre-cherry-pick state
git cherry-pick --abort
```

**Backporting a bugfix — real workflow**
```bash
# Bug fixed on main with commit abc1234
# Need it in release/v1.2 and release/v1.1

git switch release/v1.2
git cherry-pick -x abc1234     # -x adds the source commit reference

git switch release/v1.1
git cherry-pick -x abc1234     # same commit, different target
                               # may have different conflicts
```

**Finding the right commit to cherry-pick**
```bash
# Find commits on main that aren't on release/v1.2
git log release/v1.2..main --oneline

# Search by message
git log --grep="fix: null pointer" --oneline main

# Search by code change (pickaxe)
git log -S "authenticate_user" --oneline main

# Show exactly what a commit changed before picking it
git show abc1234
git show abc1234 --stat
```

---

## Gotchas

- **Cherry-picked commits have different hashes than the originals.** If you cherry-pick abc1234 onto a release branch, the release branch gets a new commit xyz9876. If you later merge main into the release branch, Git sees both commits as different — it may try to apply the same change twice. Use `-x` to track the source, and be aware of this when later merging.
- **Cherry-pick applies the diff, not the final state.** If the cherry-picked commit depends on context from earlier commits that don't exist on your target branch, the diff won't apply cleanly and you'll get conflicts. You may need to cherry-pick a sequence of commits in order rather than just the final one.
- **`git cherry-pick abc..def` excludes abc.** The double-dot range is exclusive of the left side. Use `abc^..def` if you want to include abc. This is the most common cherry-pick mistake — silently missing the first commit in a range.
- **Cherry-picking merge commits requires `-m` to specify which parent is the mainline.** A merge commit has two parents — Git doesn't know which side's diff to apply. `git cherry-pick -m 1 <merge-commit>` uses parent 1 as the base. Without `-m`, cherry-picking a merge commit fails with an error.
- **Repeated cherry-picks across many branches create long-term maintenance debt.** Each cherry-picked commit is an independent copy — future changes to the original won't propagate. If a fix needs updating, you must track down every cherry-picked copy. This is the signal to reconsider your branching model.

---

## Interview Angle

**What they're really testing:** Whether you understand when to use cherry-pick vs merge, and know its limitations with commit dependencies.

**Common question form:** *"How would you apply a hotfix to multiple release branches?"* or *"What's the difference between cherry-pick and merge?"*

**The depth signal:** A junior says "cherry-pick copies a commit to another branch." A senior explains that cherry-pick computes the diff between a commit and its parent, then applies that diff — so it depends on the surrounding context existing in the target branch. They know the `abc..def` range is exclusive of the left side (`abc^..def` to include it), that cherry-picking a merge commit needs `-m 1`, and that `-x` is essential for traceability when backporting. They also know the long-term hazard: cherry-picked commits are independent copies, not linked references — divergence over time is silent.

---

## Related Topics

- [[git/git-merging.md]] — Merge integrates entire branch histories; cherry-pick takes individual commits. Know when each is appropriate.
- [[git/git-rebasing.md]] — Rebase replays a sequence of commits onto a new base — conceptually similar to many cherry-picks in order.
- [[git/git-branches.md]] — Cherry-pick is most useful when maintaining multiple long-lived branches (release branches, LTS versions).
- [[git/git-commits.md]] — `git log -S` and `git show` are the tools for finding which commit to cherry-pick.

---

## Source

[Git documentation — git-cherry-pick](https://git-scm.com/docs/git-cherry-pick)

---
*Last updated: 2026-03-24*