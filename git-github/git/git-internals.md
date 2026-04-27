# Git Internals

> Git is a content-addressable filesystem — every piece of data is stored as an object identified by the SHA-1 hash of its content, and branches are just files containing a hash.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A content-addressed object store with four object types and a ref system |
| **Use when** | Debugging disasters, writing tooling, understanding why Git behaves as it does |
| **Avoid when** | Daily work — this is background knowledge, not a workflow |
| **Git version** | Model stable since Git 1.0; SHA-256 experimental since Git 2.29 |
| **Key location** | `.git/objects/` (objects), `.git/refs/` (branches/tags), `.git/HEAD`, `.git/index` |
| **Key commands** | `git cat-file`, `git hash-object`, `git ls-files --stage`, `git fsck`, `git gc` |

---

## When To Use It

Understanding Git internals matters when you need to recover from disasters (detached HEAD, lost commits, corrupted refs), write Git tooling or hooks, or explain why Git behaves the way it does under the hood. You don't need this for daily work, but every confusing Git behavior — why rebasing changes commit hashes, why force-pushing is destructive, why `git checkout` can do three different things — becomes obvious once you understand the object model.

---

## Core Concept

Git stores four object types in `.git/objects/`: blobs (file contents), trees (directory listings), commits (snapshot + metadata + parent pointer), and tags (annotated tag objects). Every object is identified by the SHA-1 of its content — change anything and you get a different hash. A commit doesn't store diffs; it stores a pointer to a tree that represents the full state of the repo at that moment. A branch is a file in `.git/refs/heads/` containing one commit hash. HEAD is a file in `.git/HEAD` pointing to either a branch name (attached) or a commit hash directly (detached). That's the entire model — objects, refs, and HEAD.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | Content-addressed object store with SHA-1; four object types established |
| Git 1.6 | Pack files and delta compression introduced for efficient storage |
| Git 2.11 | Improved delta compression (zstd experiments); pack-v2 refinements |
| Git 2.22 | Commit graph file introduced — speeds up `git log` traversal on large repos |
| Git 2.27 | Multi-pack index (MIDX) for repos with many pack files |
| Git 2.29 | SHA-256 object format introduced as experimental alternative to SHA-1 |
| Git 2.41 | Geometric repacking for smarter pack file management |

*The SHA-256 transition (Git 2.29+) is the biggest structural change to the object model since Git 1.0. SHA-1 has theoretical collision vulnerabilities (demonstrated by SHAttered in 2017). Git mitigates this with hardened SHA-1, but long-term the ecosystem is moving to SHA-256. Most repos will stay on SHA-1 for years.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `git cat-file -p <hash>` | O(object size) | Decompresses and prints one object |
| Object lookup by hash | O(1) amortized | First 2 chars = directory, rest = filename |
| `git log` traversal | O(commits) | Follows parent pointers; commit graph file speeds this up |
| `git gc` (full) | O(objects) | Repacks loose objects into pack files; may take minutes on large repos |
| Pack file delta lookup | O(delta chain length) | Long delta chains slow random access; `git repack --window` controls depth |

**Allocation behaviour:** Loose objects (individual files in `.git/objects/`) accumulate during normal use. Git automatically runs `git gc --auto` periodically to pack them. Each loose object is a zlib-compressed file; a pack file stores multiple objects with delta compression between similar objects, typically achieving 10–50× space savings on code repositories.

**Benchmark notes:** The commit graph file (`.git/objects/info/commit-graph`, Git 2.22+) dramatically accelerates `git log`, `git merge-base`, and `git fetch`. On a repo with 500,000 commits, `git log --oneline` drops from ~30 seconds to under 1 second with the commit graph file. Enable with `git config core.commitGraph true` and run `git commit-graph write --reachable`.

---

## The Code

**Exploring the object store directly**
```bash
# Every object lives in .git/objects/{first 2 chars of hash}/{remaining 38}
ls .git/objects/

# cat-file: the plumbing command to inspect any object
git cat-file -t 9f4d96d   # type: blob, tree, commit, or tag
git cat-file -p 9f4d96d   # pretty-print the object contents
git cat-file -s 9f4d96d   # size in bytes

# Inspect the current commit
git cat-file -p HEAD

# Output:
# tree 3c4d2f1a8b...        ← pointer to root tree
# parent 7e2a1c3f9d...      ← previous commit (absent on first commit)
# author Ali <a@b.com> 1711285200 +0300
# committer Ali <a@b.com> 1711285200 +0300
#
# Add user authentication

# Inspect the tree that commit points to
git cat-file -p 3c4d2f1a8b

# Output:
# 100644 blob a1b2c3d4...   README.md     ← regular file
# 100644 blob e5f6a7b8...   main.py
# 040000 tree c9d0e1f2...   src/          ← subdirectory = another tree object
# 100755 blob f1e2d3c4...   run.sh        ← executable file (755 mode)
```

**What a branch and HEAD actually are**
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

# Remote tracking refs live separately
cat .git/refs/remotes/origin/main
# The hash your last fetch saw on the remote

# Packed refs — after git gc, many refs are consolidated here
cat .git/packed-refs
# # pack-refs with: peeled fully-peeled sorted
# 7e2a1c3f... refs/heads/main
# a3b4c5d6... refs/tags/v1.0.0
# ^f1e2d3c4... (peeled tag — the commit a tag points to)
```

**Hashing objects manually — how content-addressing works**
```bash
# hash-object: compute the SHA-1 Git would use for any content
echo "hello world" | git hash-object --stdin
# 3b18e512dba79e4c8300dd08aeb37f8e728b8dad

# Git prepends a header before hashing: "blob <size>\0<content>"
# So the actual SHA-1 input is: "blob 12\0hello world\n"
printf "blob 12\0hello world\n" | sha1sum
# 3b18e512dba79e4c8300dd08aeb37f8e728b8dad

# Write it to the object store
echo "hello world" | git hash-object --stdin -w

# Now it's a real object
git cat-file -t 3b18e512dba79e4c8300dd08aeb37f8e728b8dad
# blob

# This is how Git deduplicates — same content = same hash = stored once
# Two files with identical content share one blob object
```

**The index (staging area) as a binary file**
```bash
# .git/index is the staging area — what will become the next commit's tree
git ls-files --stage  # read the index

# Output:
# 100644 a1b2c3d4... 0   README.md
# 100644 e5f6a7b8... 0   main.py
# (mode, blob hash, stage number, filename)
# stage 0 = normal; 1/2/3 = merge conflict stages (ancestor/ours/theirs)

# When you run git add, Git:
# 1. Hashes the file content → creates a blob object in .git/objects
# 2. Updates .git/index to point to that blob

# When you run git commit, Git:
# 1. Builds a tree object from the index
# 2. Creates a commit object pointing to that tree + parent commit hash
# 3. Updates the branch ref file to point to the new commit hash
```

**Why rebase changes hashes**
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

**Pack files — how Git compresses the object store**
```bash
# Loose objects are individual files — fine for small repos
# Git periodically packs them into a single .pack file with a .idx index

ls .git/objects/pack/
# pack-abc123.idx    ← index for fast lookup
# pack-abc123.pack   ← compressed objects with delta encoding

# Trigger packing manually (also prunes unreachable objects)
git gc

# Verify pack contents — sort by size to find large blobs
git verify-pack -v .git/objects/pack/pack-abc123.idx | sort -k3 -n | tail -10
# Useful for finding accidentally committed large binaries

# Write the commit graph file to speed up log traversal
git commit-graph write --reachable
```

**Inspecting a corrupted repository**
```bash
# Check object store integrity
git fsck --full

# Output on a healthy repo:
# Checking object directories: 100% done
# Checking connectivity: done

# On a corrupted repo:
# error: sha1 mismatch for .git/objects/9f/4d96d...
# missing blob 9f4d96d...

# Find dangling (unreachable) objects — useful for recovery
git fsck --unreachable | grep commit
# dangling commit a1b2c3d...  ← could be a lost stash or dropped branch

# Inspect the dangling commit
git cat-file -p a1b2c3d
git show a1b2c3d
```

---

## Real World Example

A CI server's disk filled up mid-push, leaving the remote repository with a partially written pack file. Developers started getting "object missing" errors when cloning. Knowing the object model made diagnosis and recovery straightforward.

```bash
# On the broken remote:
cd /var/git/repo.git

# Step 1: identify the corruption
git fsck --full 2>&1 | head -20
# error: object file .git/objects/pack/pack-a3f9.pack is damaged
# error: sha1 mismatch for pack-a3f9.pack
# missing blob 3c4d2f...
# missing blob e5f6a7...

# Step 2: remove the corrupt pack (objects exist in a backup)
rm .git/objects/pack/pack-a3f9.pack
rm .git/objects/pack/pack-a3f9.idx

# Step 3: fetch from a developer's clone to restore missing objects
# (every clone is a full backup of the object store)
git remote add recovery git@dev-machine:/home/ali/projects/repo.git
git fetch recovery

# Step 4: repack cleanly
git gc --prune=now

# Step 5: verify
git fsck --full
# Checking object directories: 100% done
# Checking connectivity: done

# Step 6: root cause — disk monitoring and pre-receive hook to check space
cat >> hooks/pre-receive << 'EOF'
#!/bin/bash
AVAILABLE=$(df -k . | awk 'NR==2 {print $4}')
if [ "$AVAILABLE" -lt 1048576 ]; then  # less than 1GB
  echo "ERROR: Insufficient disk space on server. Push rejected."
  exit 1
fi
EOF
chmod +x hooks/pre-receive
```

*The key insight: every developer's clone is a complete backup of every object the server has. Git's content-addressed model means that if the object with hash `3c4d2f` exists anywhere, it's identical to the one that was lost — you just need to fetch it from someone who has it.*

---

## Common Misconceptions

**"Git stores diffs between versions"**
Git stores complete snapshots, not diffs. Each commit points to a tree object that represents the full state of every file at that moment. Delta compression in pack files is a storage optimization that happens after the fact — it's not part of the object model. When you `git checkout` a branch, Git has the full snapshot immediately, without reconstructing anything from a diff chain.

**"Deleting a branch deletes the commits"**
A branch is a ref file. Deleting it removes the file from `.git/refs/heads/`. The commit objects it pointed to remain in `.git/objects` until garbage collection runs (default: 30 days for unreachable objects). This is how `git reflog` and `git fsck --unreachable` can recover "deleted" work — the objects were never gone, just unreachable.

**"Two repos with the same code have the same commit hashes"**
Commit hashes depend on the full commit object: tree hash + parent hash + author + committer + timestamp + message. Two repos with identical file contents but different authors, dates, or history will have entirely different hashes. Only clones (with identical history) share hashes. This is also why `git pull --rebase` from a fork produces different hashes than the upstream, even for identical changes.

---

## Gotchas

- **Rebasing changes commit hashes even if the content is identical.** The parent pointer is part of the hash input — changing the parent (which rebase does) produces a new hash for every commit in the rebased chain. This is why you must force-push after rebasing a branch others have pulled.

- **`git reset --hard` doesn't delete commits — they become unreachable.** The objects stay in `.git/objects` until `git gc` prunes them (default: 30 days). `git reflog` still references them. This is your recovery window — use `git reflog` to find the hash and check it out before gc runs.

- **Detached HEAD is not an error state.** It means HEAD points to a commit hash directly instead of a branch ref. Commits made in detached HEAD are real objects. They become unreachable only if you checkout another branch without creating a new branch to hold them — always `git switch -c <new-branch>` before committing in detached HEAD.

- **The index is a snapshot taken at `git add` time, not at `git commit` time.** If you modify a file after `git add`, the index still holds the old blob. `git status` shows the file as both staged (old) and modified (new). This is one of the most common Git surprises for beginners.

- **Pack file delta chains can slow random access.** Git stores objects as deltas against similar objects for compression. Accessing a deeply-chained object requires reconstructing from the chain base. Run `git repack -a -d --depth=50 --window=250` to control chain depth on performance-sensitive repos.

---

## Interview Angle

**What they're really testing:** Whether you understand Git as a data structure rather than a set of commands — and can reason about why specific behaviors happen.

**Common question forms:**
- "What happens under the hood when you run `git commit`?"
- "Why does rebasing require a force push?"
- "How would you recover a commit after `git reset --hard`?"

**The depth signal:** A junior describes Git commands. A senior describes the object model: `git commit` hashes the index into a tree object, creates a commit object pointing to that tree and the current HEAD commit as parent, then moves the branch ref forward to the new commit hash. They explain that rebase produces new commit hashes because the parent pointer changes — which changes the hash input — which means the rebased commits are literally different objects than the originals. On recovery: they go straight to `git reflog` because they know objects aren't deleted until gc runs.

**Follow-up questions to expect:**
- "What are the four Git object types and what does each store?"
- "How does Git deduplicate identical files across commits?"

---

## Related Topics

- [git-rebasing.md](git-rebasing.md) — Rebase's hash-rewriting behavior is a direct consequence of the object model.
- [git-reset.md](git-reset.md) — reset, revert, and restore all manipulate refs and the index in ways that make sense once you know the object model.
- [git-hooks.md](git-hooks.md) — Hooks operate on the `.git` directory directly; understanding internals makes hook scripts easier to write correctly.
- [git-reflog.md](git-reflog.md) — The reflog works because unreachable objects persist in `.git/objects` until GC.
- [git-gc-and-maintenance.md](git-gc-and-maintenance.md) — When and how Git cleans up unreachable objects.

---

## Source

[Git Book — Git Internals chapter](https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain)

---
*Last updated: 2026-04-23*