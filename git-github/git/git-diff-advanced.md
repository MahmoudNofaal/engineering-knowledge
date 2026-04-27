# Git Diff (Advanced)

> `git diff` compares two states of your repository — working directory vs index, index vs HEAD, or any two commits, branches, or trees — and outputs a unified diff.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A comparison engine that shows what changed between any two Git states |
| **Use when** | Reviewing changes before staging, verifying staged content, comparing branches |
| **Avoid when** | N/A — diff is always safe, always read-only |
| **Git version** | Core since Git 1.0; `--word-diff` added Git 1.7.2; `--stat` since Git 1.5 |
| **Key location** | No files created — reads from object store and working directory |
| **Key commands** | `git diff`, `git diff --staged`, `git diff HEAD`, `git diff <branch>`, `git difftool` |

---

## When To Use It

Use `git diff` constantly — before staging (to see what you changed), after staging (to verify what will be committed), between branches (to see what a PR introduces), and when reviewing production incidents (to compare deployed vs current). `git diff` is always safe — it only reads, never writes. It's one of the few Git commands where "run it more" is always the right answer.

---

## Core Concept

Git diff compares two trees (or a tree and the working directory) by finding the common ancestor and computing what changed. The three most important diff pairs correspond to Git's three trees: `git diff` (working dir vs index — what's unstaged), `git diff --staged` (index vs HEAD — what will be committed), and `git diff HEAD` (working dir vs HEAD — all uncommitted changes). Everything else is comparing two arbitrary points: commits, branches, tags. The output is always a unified diff: `---` for the old state, `+++` for the new state, `@@ -line +line @@` for hunk headers.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | `git diff` as a core command with unified diff output |
| Git 1.5 | `--stat` for summary (files changed, insertions, deletions) |
| Git 1.7.2 | `--word-diff` for inline word-level changes |
| Git 1.8.4 | `--diff-filter` for filtering by change type (A/M/D/R etc.) |
| Git 2.9 | `--submodule=diff` for showing submodule changes as diffs |
| Git 2.12 | `--color-moved` highlights moved code differently from new code |
| Git 2.17 | `--color-moved-ws` handles whitespace in moved code detection |

*`--color-moved` (Git 2.12) is genuinely useful for code reviews — it colours moved lines differently from added/deleted lines, making refactoring changes (where code is reorganised but not rewritten) instantly recognisable instead of showing as a sea of red and green.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `git diff` (working dir vs index) | O(modified files) | Reads index then stats/reads modified files |
| `git diff --staged` | O(staged files) | Compares index blobs to HEAD tree — fast |
| `git diff <commit>..<commit>` | O(diff size) | Reads two tree objects and their blobs |
| `git diff --stat` only | O(diff size) | Same underlying compute, cheaper output |
| `git diff -S "pattern"` | O(all diffs) | Must apply every diff to search — slow on large repos |

**Allocation behaviour:** `git diff` creates no objects. It reads existing blobs from the object store and compares them in memory. Even diffing two large commits uses no disk space.

**Benchmark notes:** `git diff <old-branch>..<new-branch>` on a large monorepo can be slow if the branches have diverged significantly. Use `--stat` first to get a summary without the full unified diff, then use `-- path/to/subdir` to narrow to specific files if needed.

---

## The Code

**The three essential diffs — working dir, index, HEAD**
```bash
# What have I changed but not yet staged?
git diff                          # working dir vs index (unstaged changes)

# What have I staged that will go into the next commit?
git diff --staged                 # index vs HEAD (staged changes)
git diff --cached                 # same — alias for --staged

# All uncommitted changes (staged + unstaged combined)?
git diff HEAD                     # working dir vs HEAD

# Quick mental model:
# git diff          → "what will I lose if I run git checkout -- ."
# git diff --staged → "what will go into my next commit"
# git diff HEAD     → "what's different from the last commit"
```

**Comparing branches and commits**
```bash
# What's different between two branches?
git diff main..feature/auth       # changes since branches diverged
git diff main...feature/auth      # three-dot: changes since common ancestor

# Two-dot vs three-dot:
# main..feature  = everything reachable from feature but not main
# main...feature = changes on feature since it branched off main (excludes main's changes)
# Three-dot is almost always what you want for PR review

# What did a specific commit change?
git show abc1234                  # same as git diff abc1234^..abc1234
git diff abc1234^ abc1234         # explicit parent syntax

# What changed between two tags/releases?
git diff v1.2.0..v1.3.0
git diff v1.2.0..v1.3.0 --stat   # summary only

# What changed in a file across all history?
git log -p -- src/auth.py         # full diff history for one file
```

**Output format control**
```bash
# Summary only (files changed, lines added/removed)
git diff --stat
# src/Auth/TokenService.cs | 12 +++++++-----
# tests/Auth/TokenTests.cs |  8 ++++++++
# 2 files changed, 15 insertions(+), 5 deletions(-)

# Just the file names
git diff --name-only
git diff --name-status            # includes A/M/D status per file

# Word-level diff (highlights changes within lines, not whole lines)
git diff --word-diff
# [-old text-]{+new text+} shown inline

# Ignore whitespace changes
git diff -w                       # ignore all whitespace
git diff -b                       # ignore changes in whitespace amount

# More context lines (default is 3)
git diff -U10                     # 10 lines of context
git diff -U0                      # no context — just the changed lines

# Highlight moved code (Git 2.12+)
git diff --color-moved=zebra      # moved code shown differently from new code
```

**Filtering by file type or change type**
```bash
# Only show changes in specific files/directories
git diff -- src/Auth/            # only changes under src/Auth/
git diff -- "*.cs"               # only C# files (quote the glob)
git diff -- src/ tests/          # multiple paths

# Filter by change type
git diff --diff-filter=M         # only modified files
git diff --diff-filter=A         # only added files
git diff --diff-filter=D         # only deleted files
git diff --diff-filter=R         # only renamed files
git diff --diff-filter=AM        # added OR modified
git diff --diff-filter=d         # exclude deleted (lowercase = exclude)

# Practical: see only modified tracked files (not adds/deletes)
git diff --diff-filter=M --name-only
```

**Using difftool for visual comparison**
```bash
# Configure a visual diff tool
git config --global diff.tool vscode
git config --global difftool.vscode.cmd 'code --wait --diff $LOCAL $REMOTE'

# Launch the configured tool
git difftool                      # opens each changed file in the tool
git difftool --no-prompt          # skip "Launch tool?" prompt for each file
git difftool -- src/auth.py       # diff one specific file

# Other popular tools
git config --global diff.tool vimdiff
git config --global diff.tool meld
git config --global diff.tool "idea"   # JetBrains IDEs
```

**Generating and applying patch files**
```bash
# Save a diff as a patch file
git diff > my-changes.patch
git diff --staged > staged-changes.patch

# Apply a patch
git apply my-changes.patch
git apply --check my-changes.patch   # dry run — check if it applies cleanly
git apply --reverse my-changes.patch # reverse-apply (un-apply a patch)

# More robust: use format-patch for email/sharing
git format-patch main..feature/auth   # one .patch file per commit
git am *.patch                         # apply a series of patches
```

**Diff statistics for PR review**
```bash
# Review what a PR changes before reading the diff
gh pr diff 217 --stat             # GitHub CLI
git fetch origin pull/217/head:pr-217
git diff main...pr-217 --stat

# Find the largest changed files (review these first)
git diff main...feature/auth --stat | sort -k2 -n -r | head -10

# Count total lines changed
git diff main...feature/auth --shortstat
# 12 files changed, 234 insertions(+), 89 deletions(-)
```

---

## Real World Example

A security team was auditing a quarter's worth of changes to the authentication module — 67 PRs merged over 3 months. Rather than reading each PR individually, they used `git diff` to get a high-level view of everything that changed, then drilled into specific concerns with targeted filters.

```bash
# Step 1: what changed in auth over the last quarter?
git diff v3.0.0..v3.3.0 -- src/Auth/ --stat
# src/Auth/TokenService.cs             | 127 ++++++++++++++----------
# src/Auth/SessionManager.cs           |  89 ++++++-------
# src/Auth/PasswordHasher.cs           |  34 +++--
# src/Auth/AuthController.cs           |  56 +++++-
# src/Auth/OAuthProvider.cs            | 203 ++++++++++++++++++++++++++ (new)
# tests/Auth/                          | 312 ++++++++++++++++++++++++++++++
# 6 files changed, 512 insertions(+), 134 deletions(-)

# Step 2: focus on the files with the most churn (highest risk)
git diff v3.0.0..v3.3.0 -- src/Auth/OAuthProvider.cs
# Full diff of the 203-line new file

# Step 3: look for specific security patterns
git diff v3.0.0..v3.3.0 -- src/Auth/ | grep -E "^\+" | \
  grep -iE "(password|secret|token|hash|salt|random)"
# +        var salt = Guid.NewGuid().ToString();  ← FLAG: Guid is not a salt

# Step 4: compare password hashing approach between versions
git diff v3.0.0 v3.3.0 -- src/Auth/PasswordHasher.cs

# Step 5: verify no regression in test coverage
git diff v3.0.0..v3.3.0 --stat -- tests/Auth/
# tests/Auth/ | 312 ++++++++++  ← 312 lines added to tests, good

# Finding: Guid.NewGuid() used as a password salt (not cryptographically random)
# Fix: use RandomNumberGenerator.GetBytes(32) instead
# PR #341 opened: fix(auth): use CSPRNG for password salt generation
```

*The key insight: `git diff` between release tags is one of the most powerful security and quality review tools available. It gives you the ground truth of exactly what changed between any two states of the codebase — no PR descriptions to misread, no commit messages to misinterpret, just the exact diff.*

---

## Common Misconceptions

**"`git diff` shows all my changes"**
`git diff` (no flags) only shows *unstaged* changes — the diff between the working directory and the index. If you've already staged everything, `git diff` shows nothing, even if you have significant uncommitted work. Use `git diff --staged` for staged changes, or `git diff HEAD` for everything since the last commit. This surprises almost every Git beginner.

**"Two-dot and three-dot diff are the same"**
`git diff main..feature` shows everything reachable from `feature` but not from `main` — including commits on `feature` from before it diverged from `main`. `git diff main...feature` shows only the changes on `feature` since it branched off main, excluding main's subsequent changes. For PR review, `...` (three-dot) is almost always what you want: "what did this branch add?"

**"`git diff` is slow on large repos"**
`git diff` between two commits is fast — it reads two tree objects and computes the diff. What's slow is `git diff` with pattern-based search (`-S`, `-G`) because those must apply every commit's diff. Also slow: diffing when the working directory has many untracked files (Git must stat them all). Neither is an inherent diff limitation — they're specific usage patterns.

---

## Gotchas

- **`git diff` without flags shows nothing if all changes are staged.** After `git add .`, your entire working diff is in the index. `git diff` compares working dir to index — if they're the same, nothing shows. This is correct but surprising. Use `git diff --staged` to see what you just staged.

- **Quotes are required for glob patterns to prevent shell expansion.** `git diff -- *.cs` may expand `*.cs` to the actual .cs files in your current directory before Git sees it. Use `git diff -- "*.cs"` to pass the glob to Git itself.

- **`git difftool` opens one file at a time by default.** Use `--dir-diff` to open the entire diff in a directory comparison tool if your tool supports it (e.g., meld, Beyond Compare).

- **`--color-moved` can produce false positives on short moved lines.** A 2-line comment moved from one file to another might match another 2-line comment that wasn't actually moved. Use `--color-moved-ws` to handle whitespace normalization.

- **`git diff` between branches compares tips, not merge bases.** `git diff main feature` shows the difference between the current tips of main and feature — not what feature would add if merged. Use `git diff main...feature` (three dots) for the PR-style view.

---

## Interview Angle

**What they're really testing:** Whether you know which diff to run in which situation, and understand the three-tree model behind the different diff commands.

**Common question forms:**
- "What's the difference between `git diff` and `git diff --staged`?"
- "How would you see what a PR adds without checking it out?"
- "How do you compare two branches?"

**The depth signal:** A junior knows `git diff` shows changes. A senior explains the three-tree model — `git diff` is working dir vs index, `git diff --staged` is index vs HEAD, `git diff HEAD` is working dir vs HEAD — and knows when to use two-dot vs three-dot branch comparison, `--diff-filter` for targeted review, `--word-diff` for in-line change clarity, and `git difftool` for visual comparison in complex merges.

**Follow-up questions to expect:**
- "How do you see what changed between two releases?"
- "What's the difference between `git diff main..feature` and `git diff main...feature`?"

---

## Related Topics

- [git-staging-area.md](git-staging-area.md) — Understanding the three trees is prerequisite to knowing which `git diff` to run.
- [git-commits.md](git-commits.md) — `git show` is `git diff` on a single commit vs its parent.
- [git-log-advanced.md](git-log-advanced.md) — `git log -p` combines log and diff; `git log -S` searches diffs.
- [git-merge-conflicts.md](git-merge-conflicts.md) — During conflict resolution, `git diff --diff-filter=U` shows only conflicted files.
- [git-blame-and-archaeology.md](git-blame-and-archaeology.md) — diff and blame complement each other: diff shows what changed, blame shows who changed it and when.

---

## Source

[Git Documentation — git-diff](https://git-scm.com/docs/git-diff)

---
*Last updated: 2026-04-24*