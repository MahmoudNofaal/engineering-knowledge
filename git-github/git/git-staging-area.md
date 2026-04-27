# Git Staging Area

> The index — a binary file at `.git/index` — is a prepared snapshot of what your next commit will look like, sitting between your working directory and the object store.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A binary snapshot of the next commit's tree |
| **Use when** | Crafting atomic commits from a messy working directory |
| **Avoid when** | Using `git commit -a` to bypass it — you lose precision |
| **Git version** | Index since Git 1.0; `git restore --staged` added Git 2.23 |
| **Key location** | `.git/index` (binary file) |
| **Key commands** | `git add`, `git add -p`, `git restore --staged`, `git diff --staged`, `git ls-files --stage` |

---

## When To Use It

Use the staging area deliberately to craft clean, atomic commits — adding only the changes relevant to one logical unit of work, even if your working directory has multiple unrelated changes in progress. Don't bypass it with `git commit -a` when you have mixed changes that belong in separate commits — you'll regret it during code review or when bisecting a bug.

---

## Core Concept

Most people think of staging as just "marking files for commit." It's more precise than that: when you `git add` a file, Git immediately hashes the content, writes a blob object to `.git/objects`, and records that blob hash in the index. The index is a snapshot — not a list of changed files, not a diff. If you modify the file again after `git add`, the index still holds the blob from the first add. The working directory diverged from the index, which diverged from HEAD — three distinct states. Understanding these three states is the mental model for everything: `git diff` (working dir vs index), `git diff --staged` (index vs HEAD), and `git status` (both at once).

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | Index as the staging area — core three-tree model established |
| Git 1.8.3 | `git add -N` (intent to add) — stage a new file path without content |
| Git 2.0 | `git add .` unified to include deletions (previously needed `-A`) |
| Git 2.23 | `git restore --staged` introduced as unambiguous replacement for `git reset HEAD <file>` |
| Git 2.25 | `--pathspec-from-file` added to `git add` and `git restore` |
| Git 2.35 | Index v4 format improvements for large repos (faster read times) |

*Before Git 2.0, `git add .` run from a subdirectory did not stage deletions — you needed `git add -A`. From Git 2.0 onwards, both are equivalent from the repo root.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `git add <file>` | O(file size) | Hashes and compresses content, writes blob to object store |
| `git add .` (large repo) | O(modified files) | Reads mtimes from index to skip unchanged files |
| `git add -p` | O(diff size) | Runs diff internally, pauses for each hunk |
| `git diff --staged` | O(staged files) | Compares index blobs to HEAD tree — no disk I/O for unchanged files |
| `git restore --staged` | O(1) | Rewrites the index entry; no blob I/O |

**Allocation behaviour:** The index file (`.git/index`) is a binary flat file. It grows with the number of tracked files, not with file size — a 100GB file and a 1KB file each occupy roughly the same space in the index (~100 bytes per entry). On repos with 100,000+ tracked files, index reads can become a bottleneck — this is where `git sparse-checkout` and partial clones help.

**Benchmark notes:** `git status` on a large repo reads the full index and compares every entry against the filesystem. On repos with 50,000+ files, this can take several seconds without a filesystem monitor. Enable `git config core.fsmonitor true` (Git 2.37+) to use OS-level file change notifications and make `git status` near-instant.

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

# The three trees at a glance:
# HEAD       — last commit (what you committed)
# Index      — staging area (what you WILL commit)
# Working dir — filesystem (what you're editing NOW)
```

**Partial staging — adding parts of a file**
```bash
# -p (patch): interactively choose which hunks to stage
git add -p file.txt

# For each hunk Git shows:
# y = stage this hunk
# n = skip this hunk
# s = split into smaller hunks
# e = manually edit the hunk (edit the diff directly)
# q = quit

# Result: you can commit half the changes in a file
# while leaving the other half unstaged

# Verify the staged version before committing
git stash --keep-index      # stash unstaged only, leave staged
dotnet test                 # run tests against exactly what will be committed
git stash pop               # restore the unstaged work
```

**Inspecting the index directly**
```bash
# ls-files --stage: show raw index contents
git ls-files --stage

# Output:
# 100644 a1b2c3d4e5f6... 0   README.md
# 100644 e5f6a7b8c9d0... 0   main.py
# 040000 (mode, blob hash, stage number, path)
# Stage number: 0 = normal, 1 = common ancestor, 2 = ours, 3 = theirs
# Stage numbers 1/2/3 appear only during a merge conflict

# Check if working dir matches the index (unstaged changes)
git diff --stat             # unstaged changes summary
git diff --staged --stat    # staged changes summary
```

**Unstaging — three ways**
```bash
# Preferred modern syntax (Git 2.23+)
git restore --staged file.txt

# Classic syntax — still works everywhere
git reset HEAD file.txt

# Unstage everything staged
git restore --staged .

# Nuclear: reset index AND working dir to HEAD (loses uncommitted work)
git restore file.txt        # new syntax — reverts working dir to index
git checkout -- file.txt    # old syntax — same effect
```

**Staging deleted and renamed files**
```bash
# git add only stages modifications and new files — not deletions by default
git rm file.txt             # stages the deletion
git rm --cached file.txt    # removes from index only — keeps file on disk
                            # use this for files accidentally committed before .gitignore

# Rename — do it as a move so Git tracks it
git mv old-name.txt new-name.txt   # stages the rename atomically

# Equivalent to the three-step manual approach:
mv old-name.txt new-name.txt
git rm old-name.txt
git add new-name.txt
# But git mv is cleaner and Git detects it as a rename, preserving history
```

**Intent to add — staging a new file's path without content**
```bash
# Stage the path only — git diff now shows the file as "new file" with pending content
git add -N new-feature.py

# Now git diff shows unstaged changes (working dir vs index)
# even though the file is brand new — useful for add -p on new files
git add -p new-feature.py   # works because the path is registered in the index
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

## Real World Example

A senior engineer was refactoring a payment service and had touched six files — three belonged to the same logical change (fee calculation fix), two were unrelated test cleanup, and one was a dependency bump. Code review at that company required small, single-purpose PRs. Using `git add -p`, she split the working directory into three separate commits in under five minutes without touching a single file on disk.

```bash
# Working directory: 6 files touched, 3 different concerns
git status
# modified: src/Payments/FeeCalculator.cs
# modified: src/Payments/FeeCalculator.Tests.cs
# modified: src/Payments/OrderService.cs
# modified: src/Orders/OrderController.Tests.cs     ← unrelated cleanup
# modified: src/Orders/OrderRepository.Tests.cs     ← unrelated cleanup
# modified: Directory.Packages.props                ← dependency bump

# === Commit 1: fee calculation fix ===
git add -p src/Payments/FeeCalculator.cs
# Select only the fee calculation hunks, skip the refactor hunks
git add src/Payments/FeeCalculator.Tests.cs
git add -p src/Payments/OrderService.cs
# Select only the lines that consume the new fee calculation
git diff --staged --stat     # verify exactly what's staged
git commit -m "fix(payments): correct percentage fee rounding for fractional amounts"

# === Commit 2: test cleanup (unrelated) ===
git add src/Orders/OrderController.Tests.cs
git add src/Orders/OrderRepository.Tests.cs
git commit -m "test(orders): remove redundant null-check assertions"

# === Commit 3: dependency bump ===
git add Directory.Packages.props
git commit -m "chore(deps): bump Stripe.net to 43.2.0"

# Result: 3 clean PRs, each reviewable in isolation
# Reviewer for commit 1 doesn't have to wade through test cleanup
# The git log tells a clear story: fix, then cleanup, then bump
```

*The key insight: the staging area lets you write history that's cleaner than how you actually worked. Real development is messy and non-linear — the index lets you tell the clean story without undoing any work.*

---

## Common Misconceptions

**"git add marks files for commit — the snapshot happens at commit time"**
The snapshot happens at `git add` time, not at `git commit` time. When you `git add` a file, Git immediately hashes the content, writes a blob object to `.git/objects`, and stores that blob hash in the index. If you modify the file again before committing, the index still holds the old blob. `git status` will show the file as both staged (old version) and modified (new version). This is often surprising the first time someone sees it.

**"git diff shows all my changes"**
`git diff` without flags shows only *unstaged* changes — the difference between the working directory and the index. If you've already staged everything, `git diff` shows nothing, even if you have uncommitted changes. To see staged changes (what will go into the next commit), use `git diff --staged`. To see all changes since the last commit, use `git diff HEAD`.

**"git reset HEAD <file> deletes my staged changes"**
`git reset HEAD <file>` (or `git restore --staged <file>`) only removes the file from the index — it does not touch the working directory. Your changes on disk are completely safe. The file goes from "staged" back to "modified but not staged." Nothing is lost.

---

## Gotchas

- **`git add .` stages deletions in Git 2.x but not in older versions.** In Git < 2.0, `git add .` didn't stage deleted files — you needed `git add -A`. In modern Git, both are equivalent from the repo root. Running from a subdirectory changes behavior: `git add .` only stages changes under the current directory; `git add -A` stages everything repo-wide.

- **Modifying a file after `git add` doesn't update the staged version.** The index holds the blob from the time of `git add`. `git status` will show the file as both staged (the old version) and modified (the new version). You must `git add` again to stage the updated content.

- **`git rm --cached` removes the file from the index but leaves it on disk.** If the file isn't in `.gitignore`, the next `git status` will show it as untracked. This is the correct way to stop tracking a file that was accidentally committed — remove from index, add to `.gitignore`, then commit.

- **Partial staging with `-p` can produce a staged version that doesn't compile.** If you stage half a function and leave the other half unstaged, the staged snapshot is an intermediate state. Use `git stash --keep-index` to test exactly what you're about to commit before committing.

- **The index is a single flat snapshot, not a stack.** Every `git add` overwrites the previous entry for that path in the index. There's no "undo last add" for individual files — `git restore --staged` reverts to HEAD, discarding the staged content entirely.

- **`git add -N` (intent to add) creates an empty entry in the index.** Until you `git add` the actual content, `git diff --staged` shows the file as new with zero lines. Some tools behave unexpectedly with intent-to-add entries — if things seem off, check `git ls-files --stage` for zero-byte entries.

---

## Interview Angle

**What they're really testing:** Whether you understand Git's three-tree model (HEAD, index, working directory) and can use it to craft intentional commits.

**Common question forms:**
- "What's the difference between `git add` and `git commit`?"
- "How would you commit only part of a file's changes?"
- "What does `git diff` show vs `git diff --staged`?"

**The depth signal:** A junior says "`git add` stages files and `git commit` saves them." A senior explains that `git add` immediately writes a blob object to the object store and updates the index — the snapshot is taken at add time, not commit time. They know `git diff` vs `git diff --staged` measures different pairs of the three trees, can use `git add -p` to stage individual hunks, and understand why modifying a file after staging requires a second `git add`.

**Follow-up questions to expect:**
- "If you stage a file and then modify it again, what does `git status` show?"
- "How would you test exactly what's staged before committing?"

---

## Related Topics

- [git-internals.md](git-internals.md) — The index is a binary file in `.git/index`; blob objects written by `git add` live in `.git/objects`.
- [git-commits.md](git-commits.md) — A commit turns the current index snapshot into a commit object and advances the branch ref.
- [git-reset.md](git-reset.md) — reset, restore, and revert all manipulate the index and working directory in specific combinations.
- [git-stash.md](git-stash.md) — Stash saves both the index and working directory state; `--keep-index` interacts with staging deliberately.
- [git-diff-advanced.md](git-diff-advanced.md) — Deep dive on diff flags, ranges, word-level diff, and external diff tools.

---

## Source

[Git Book — Recording Changes to the Repository](https://git-scm.com/book/en/v2/Git-Basics-Recording-Changes-to-the-Repository)

---
*Last updated: 2026-04-23*