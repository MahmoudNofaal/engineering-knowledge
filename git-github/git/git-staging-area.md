# Git Staging Area

> The index — a binary file at `.git/index` — is a prepared snapshot of what your next commit will look like, sitting between your working directory and the object store.

---

## When To Use It

Use the staging area deliberately to craft clean, atomic commits — adding only the changes relevant to one logical unit of work, even if your working directory has multiple unrelated changes in progress. Don't bypass it with `git commit -a` when you have mixed changes that belong in separate commits — you'll regret it during code review or when bisecting a bug.

---

## Core Concept

Most people think of staging as just "marking files for commit." It's more precise than that: when you `git add` a file, Git immediately hashes the content, writes a blob object to `.git/objects`, and records that blob hash in the index. The index is a snapshot — not a list of changed files, not a diff. If you modify the file again after `git add`, the index still holds the blob from the first add. The working directory diverged from the index, which diverged from HEAD — three distinct states. Understanding these three states is the mental model for everything: `git diff` (working dir vs index), `git diff --staged` (index vs HEAD), and `git status` (both at once).

---

## The Code

**The three states — seeing them clearly**
```bash
echo "version 1" > file.txt
git add file.txt            # index = "version 1", working dir = "version 1"

echo "version 2" > file.txt  # working dir = "version 2", index still = "version 1"

git diff                    # working dir vs index → shows "version 1" → "version 2"
git diff --staged           # index vs HEAD → shows nothing added yet to HEAD
git status                  # shows both: staged changes and unstaged changes
```

**Partial staging — adding parts of a file**
```bash
# -p (patch): interactively choose which hunks to stage
git add -p file.txt

# For each hunk Git shows:
# y = stage this hunk
# n = skip this hunk
# s = split into smaller hunks
# e = manually edit the hunk
# q = quit

# Result: you can commit half the changes in a file
# while leaving the other half unstaged
```

**Inspecting the index directly**
```bash
# ls-files --stage: show what's in the index
git ls-files --stage

# Output:
# 100644 a1b2c3d4e5f6... 0   README.md
# 100644 e5f6a7b8c9d0... 0   main.py
# (file mode, blob hash, stage number, path)
# stage number 0 = normal; 1/2/3 = merge conflict stages

# Check if working dir matches the index
git diff --stat             # unstaged changes
git diff --staged --stat    # staged changes
```

**Unstaging — three ways**
```bash
# Remove from index, keep working dir changes (modern syntax)
git restore --staged file.txt

# Same result, older syntax (still works everywhere)
git reset HEAD file.txt

# Unstage everything
git restore --staged .

# Nuclear: reset index AND working dir to HEAD (loses uncommitted work)
git checkout -- file.txt   # old syntax
git restore file.txt       # new syntax
```

**Staging deleted and renamed files**
```bash
# git add only stages modifications and new files — not deletions
git rm file.txt             # stages the deletion
git rm --cached file.txt    # removes from index only — keeps file on disk
                            # useful for files you forgot to .gitignore

# Rename — do it as a move so Git tracks it
git mv old-name.txt new-name.txt   # stages the rename atomically
# equivalent to: mv + git rm + git add, but Git detects it as a rename
```

**Stashing vs staging — when to use which**
```bash
# Staging: changes you WANT in the next commit
# Stash: changes you want to set aside temporarily without committing

# Scenario: mid-feature, need to make an urgent fix on main
git add feature-progress.py   # stage what you want to keep visible
git stash --keep-index        # stash unstaged changes only
                              # staged changes stay staged
git checkout main
# make fix, commit, return
git checkout feature
git stash pop
```

---

## Gotchas

- **`git add .` stages deletions in Git 2.x but not in older versions.** In Git < 2.0, `git add .` didn't stage deleted files — you needed `git add -A`. In modern Git, `git add .` and `git add -A` are equivalent from the repo root. Running from a subdirectory changes behavior: `git add .` only stages changes under the current directory; `git add -A` stages everything repo-wide.
- **Modifying a file after `git add` doesn't update the staged version.** The index holds the blob from the time of `git add`. `git status` will show the file as both staged (the old version) and modified (the new version). You must `git add` again to stage the updated content.
- **`git rm --cached` removes the file from the index but leaves it on disk.** If the file isn't in `.gitignore`, the next `git status` will show it as untracked. This is the correct way to stop tracking a file that was accidentally committed — remove from index, add to `.gitignore`, then commit.
- **Partial staging with `-p` can produce a staged version that doesn't compile.** If you stage half a function and leave the other half unstaged, the staged snapshot is an intermediate state. `git stash --keep-index` lets you test exactly what you're about to commit.
- **The index is a single flat snapshot, not a stack.** Every `git add` overwrites the previous entry for that path. There's no "undo last add" for individual files — `git restore --staged` reverts to HEAD, discarding the staged content.

---

## Interview Angle

**What they're really testing:** Whether you understand Git's three-tree model (HEAD, index, working directory) and can use it to craft intentional commits.

**Common question form:** *"What's the difference between `git add` and `git commit`?"* or *"How would you commit only part of a file's changes?"*

**The depth signal:** A junior says "`git add` stages files and `git commit` saves them." A senior explains that `git add` immediately writes a blob object to the object store and updates the index — the snapshot is taken at add time, not commit time. They know `git diff` vs `git diff --staged` measures different pairs of the three trees, can use `git add -p` to stage individual hunks, and understand why modifying a file after staging requires a second `git add`.

---

## Related Topics

- [[git/git-internals.md]] — The index is a binary file in `.git/index`; blob objects written by `git add` live in `.git/objects`.
- [[git/git-commits.md]] — A commit turns the current index snapshot into a commit object and advances the branch ref.
- [[git/git-reset-revert-restore.md]] — reset, restore, and revert all manipulate the index and working directory in specific combinations.
- [[git/git-stash.md]] — Stash saves both the index and working directory state; `--keep-index` interacts with staging deliberately.

---

## Source

[Git Book — Recording Changes to the Repository](https://git-scm.com/book/en/v2/Git-Basics-Recording-Changes-to-the-Repository)

---
*Last updated: 2026-03-24*