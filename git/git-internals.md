# Git Internals

> Git is a content-addressable filesystem — every piece of data is stored as an object identified by the SHA-1 hash of its content, and branches are just files containing a hash.

---

## When To Use It

Understanding Git internals matters when you need to recover from disasters (detached HEAD, lost commits, corrupted refs), write Git tooling or hooks, or explain why Git behaves the way it does under the hood. You don't need this for daily work, but every confusing Git behavior — why rebasing changes commit hashes, why force-pushing is destructive, why `git checkout` can do three different things — becomes obvious once you understand the object model.

---

## Core Concept

Git stores four object types in `.git/objects/`: blobs (file contents), trees (directory listings), commits (snapshot + metadata + parent pointer), and tags (annotated tag objects). Every object is identified by the SHA-1 of its content — change anything and you get a different hash. A commit doesn't store diffs; it stores a pointer to a tree that represents the full state of the repo at that moment. A branch is a file in `.git/refs/heads/` containing one commit hash. HEAD is a file in `.git/HEAD` pointing to either a branch name (attached) or a commit hash directly (detached). That's the entire model — objects, refs, and HEAD.

---

## The Code

**Exploring the object store directly**
```bash
# Every object lives in .git/objects/{first 2 chars of hash}/{remaining 38}
ls .git/objects/

# cat-file: the plumbing command to inspect any object
git cat-file -t 9f4d96d   # type: blob, tree, commit, or tag
git cat-file -p 9f4d96d   # pretty-print the object contents

# Inspect the current commit
git cat-file -p HEAD

# Output:
# tree 3c4d2f1a8b...        ← pointer to root tree
# parent 7e2a1c3f9d...      ← previous commit
# author Ali <a@b.com> 1711285200 +0300
# committer Ali <a@b.com> 1711285200 +0300
#
# Add user authentication

# Inspect the tree that commit points to
git cat-file -p 3c4d2f1a8b

# Output:
# 100644 blob a1b2c3d4...   README.md
# 100644 blob e5f6a7b8...   main.py
# 040000 tree c9d0e1f2...   src/         ← subdirectory = another tree object
```

**What a branch actually is**
```bash
# A branch is just a file with a commit hash
cat .git/refs/heads/main
# 7e2a1c3f9d5b8a1e4c7f2d9b6e3a0c5f8d1b4e7a

# HEAD points to the current branch (or directly to a commit if detached)
cat .git/HEAD
# ref: refs/heads/main        ← attached HEAD (normal)
# 7e2a1c3f9d5b8a1e4c7f2d9b6e3a0c5f8d1b4e7a  ← detached HEAD

# Creating a branch is just writing a file
git branch new-feature
cat .git/refs/heads/new-feature
# same hash as current commit — branches are cheap because it's just a file
```

**Hashing objects manually**
```bash
# hash-object: compute the SHA-1 Git would use for any content
echo "hello world" | git hash-object --stdin
# 3b18e512dba79e4c8300dd08aeb37f8e728b8dad

# Write it to the object store
echo "hello world" | git hash-object --stdin -w

# Now it's a real object
git cat-file -t 3b18e512dba79e4c8300dd08aeb37f8e728b8dad
# blob

# This is how Git deduplicates — same content = same hash = stored once
# Two files with identical content share one blob object
```

**The index (staging area) is a binary file**
```bash
# .git/index is the staging area — what will become the next commit's tree
ls-files --stage  # read the index

# Output:
# 100644 a1b2c3d4... 0   README.md
# 100644 e5f6a7b8... 0   main.py
# (mode, blob hash, stage number, filename)

# When you run git add, Git:
# 1. Hashes the file content → creates a blob object
# 2. Updates .git/index to point to that blob
# When you run git commit, Git:
# 1. Builds a tree from the index
# 2. Creates a commit object pointing to that tree and the parent commit
# 3. Updates the branch ref to point to the new commit
```

**Rebase changes hashes — why**
```bash
# Original commit C:
# tree: abc123
# parent: def456
# author: Ali
# message: "fix bug"
# hash: 9f4d96d  ← SHA-1 of all the above

# After rebase onto a different parent:
# tree: abc123       ← same tree (same file contents)
# parent: 999111     ← DIFFERENT parent
# author: Ali
# message: "fix bug"
# hash: 7a2b3c4  ← DIFFERENT hash because parent changed

# The commit content changed (different parent),
# so it gets a different hash — it's a new object.
# This is why rebasing "rewrites history" and force-push is required.
```

**Recovering lost commits with reflog**
```bash
# reflog records every position HEAD has been at
git reflog

# Output:
# 7e2a1c3 HEAD@{0}: commit: Add auth
# 9f4d96d HEAD@{1}: rebase: fast-forward
# 3b18e51 HEAD@{2}: checkout: moving from feature to main
# a1b2c3d HEAD@{3}: commit: Initial setup

# Recover a commit after accidental reset
git reset --hard HEAD@{2}   # go back to where HEAD was 2 moves ago

# Or create a branch pointing to the lost commit
git branch recovered-work a1b2c3d
```

**Pack files — how Git compresses objects**
```bash
# Loose objects are individual files — fine for small repos
# Git periodically packs them into a single .pack file with a .idx index

ls .git/objects/pack/
# pack-abc123.idx    ← index for fast lookup
# pack-abc123.pack   ← compressed objects

# Trigger packing manually
git gc

# Verify pack contents
git verify-pack -v .git/objects/pack/pack-abc123.idx | sort -k3 -n | tail -10
# Shows objects sorted by size — useful for finding large binary objects
```

---

## Gotchas

- **Rebasing changes commit hashes even if the content is identical.** The parent pointer is part of the hash input — changing the parent (which rebase does) produces a new hash for every commit in the rebased chain. This is why you must force-push after rebasing a branch others have pulled.
- **`git reset --hard` doesn't delete commits — they become unreachable.** The objects stay in `.git/objects` until `git gc` prunes them (default: 30 days). `git reflog` still references them. This is your recovery window — use `git reflog` to find the hash and check it out before gc runs.
- **Detached HEAD is not an error state — it's just HEAD pointing to a commit directly instead of a branch ref.** Commits made in detached HEAD are real objects. They become unreachable (and eventually garbage collected) only if you checkout another branch without creating a new branch to hold them.
- **The index (staging area) is a snapshot, not a diff.** When you `git add` a file, Git hashes and stores the full content as a blob object immediately. If you modify the file again before committing, you have to `git add` again — the index still points to the blob from the first add.
- **Pack files store deltas, not full snapshots for every object.** Git chooses a delta base heuristically — not necessarily the previous version of the same file. This is why `git log -p` on an old commit can be slow on large repos: Git has to reconstruct the object by applying a chain of deltas from the pack file.

---

## Interview Angle

**What they're really testing:** Whether you understand Git as a data structure rather than a set of commands — and can reason about why specific behaviors happen.

**Common question form:** *"What happens under the hood when you run git commit?"* or *"Why does rebasing require a force push?"* or *"How would you recover a commit after git reset --hard?"*

**The depth signal:** A junior describes Git commands. A senior describes the object model: `git commit` hashes the index into a tree object, creates a commit object pointing to that tree and the current HEAD commit as parent, then moves the branch ref forward to the new commit hash. They explain that rebase produces new commit hashes because the parent pointer changes — which changes the hash input — which means the rebased commits are literally different objects than the originals. On recovery: they go straight to `git reflog` because they know objects aren't deleted until gc runs, and the reflog is the complete history of where HEAD has pointed.

---

## Related Topics

- [[git/git-rebase-vs-merge.md]] — Rebase's hash-rewriting behavior is a direct consequence of the object model explained here.
- [[git/git-reset-revert-restore.md]] — reset, revert, and restore all manipulate refs and the index in specific ways that make sense once you know the object model.
- [[git/git-hooks.md]] — Hooks operate on the `.git` directory directly; understanding internals makes hook scripts easier to write correctly.
- [[git/git-workflows.md]] — Force-push policies and branch protection rules exist because of the hash-rewriting consequences described here.

---

## Source

[Git Book — Git Internals chapter](https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain)

---
*Last updated: 2026-03-24*