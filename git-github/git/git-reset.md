# Git Reset

> `git reset` moves the current branch pointer to a different commit, optionally changing the staging area and working directory to match.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Branch pointer surgery with configurable index/workdir side effects |
| **Use when** | Undoing local unpushed commits, unstaging files, rewriting recent history |
| **Avoid when** | Commits have been pushed to a shared branch — use `git revert` instead |
| **Git version** | Core since Git 1.0; `git restore --staged` (2.23) is preferred for unstaging |
| **Key location** | Moves `.git/refs/heads/<branch>`; may update `.git/index` and working dir |
| **Key commands** | `git reset --soft`, `git reset --mixed`, `git reset --hard`, `git reset HEAD~N` |

---

## When To Use It

Use `git reset` to undo local commits that haven't been pushed yet, to unstage files you added by mistake, or to rewrite your branch's history before sharing it. Never use `git reset` to undo commits that already exist on a shared remote branch — other engineers' histories will diverge from yours and the repo becomes inconsistent. Once a commit is pushed and others have pulled it, use `git revert` instead.

---

## Core Concept

Reset has three modes that control how far the rollback reaches. `--soft` moves the branch pointer but leaves your changes staged — as if you never committed, but the diff is ready to re-commit. `--mixed` (the default) moves the pointer and unstages changes, but leaves the files on disk as-is. `--hard` moves the pointer and wipes both the staging area and the working directory — files revert to the target commit's state and local edits are gone. Think of it as three concentric circles: `--soft` touches only the commit history, `--mixed` touches history + staging, `--hard` touches everything.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | `git reset --soft`, `--mixed`, `--hard` established |
| Git 1.6.5 | `git reset -- <path>` (path-level reset) improved |
| Git 2.23 | `git restore --staged <file>` introduced as clearer alternative for unstaging |
| Git 2.24 | `--merge` mode improved for aborting partial merge workflows |
| Git 2.32 | Improved safety warning when `--hard` would discard untracked files |

*`git restore --staged` (Git 2.23) is now the recommended way to unstage individual files. It separates the "unstage a file" operation from "move the branch pointer" — which `git reset HEAD <file>` did with the same command. Both still work; `restore` is semantically clearer.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `git reset --soft HEAD~N` | O(1) | Only moves the branch pointer — no file I/O at all |
| `git reset --mixed HEAD~N` | O(N commits) | Rewrites index to match target commit |
| `git reset --hard HEAD~N` | O(changed files) | Updates index + rewrites every changed file on disk |
| `git reset -- <file>` | O(1) | Updates one index entry only |

**Allocation behaviour:** Reset never deletes commit objects. A `--hard` reset to HEAD~5 leaves five commits in `.git/objects` — they're unreachable from any branch but still exist until GC runs. This is why reflog recovery works: the objects are still there, just temporarily unreachable.

**Benchmark notes:** On a large working directory (50,000+ files), `--hard` reset can be slow because Git must update every file that changed between HEAD and the target commit. If you only need to move the branch pointer, `--soft` is instantaneous regardless of repo size.

---

## The Code

**Unstaging a file (most common daily use)**
```bash
# Modern — preferred (Git 2.23+)
git restore --staged src/Orders/OrderService.cs

# Classic — still works everywhere
git reset HEAD src/Orders/OrderService.cs

# Unstage all staged changes
git restore --staged .
git reset HEAD .
```

**Undoing commits — the three modes**
```bash
# --soft: undo commit(s), keep changes staged
# Use when: you want to re-commit with a better message or different split
git reset --soft HEAD~1
# Your changes are still staged — just re-run git commit

# --mixed (default): undo commit(s), keep changes in working dir but unstaged
# Use when: you want to review changes before re-staging
git reset HEAD~1           # same as git reset --mixed HEAD~1
# Files are modified on disk — review with git diff before re-adding

# --hard: undo commit(s), discard all changes
# Use when: you want to completely abandon this work
git reset --hard HEAD~3
# ⚠ Working directory changes are gone — unrecoverable without reflog
```

**Reset to a specific commit hash**
```bash
git log --oneline          # find the target hash
git reset --soft a3f92c1   # move branch here, keep everything staged
git reset a3f92c1          # move branch here, unstage (keep on disk)
git reset --hard a3f92c1   # move branch here, discard everything after
```

**Path-level reset — not a branch move**
```bash
# Reset a specific file to HEAD (unstage + restore content)
git reset HEAD -- src/config.py
# NOTE: this does NOT move the branch pointer
# It only updates the index entry for that file to match HEAD

# Reset a file to a specific commit (restores that version to the index)
git reset abc1234 -- src/config.py
# Now git diff --staged shows the diff between abc1234 and HEAD for that file
# Use git checkout -- src/config.py to also update working dir
```

**Recover from an accidental --hard reset**
```bash
# Option 1: reflog (most reliable — works within 90 days)
git reflog                 # find the commit you just lost
git reset --hard HEAD@{2}  # move back to it

# Option 2: find the dangling commit hash directly
git fsck --lost-found      # lists unreachable commits
# Then: git reset --hard <found-hash>

# Option 3: if you know the commit hash (from terminal history, etc.)
git reset --hard a3f92c1
```

**Typical pre-push cleanup workflow**
```bash
# You have 6 local commits, 3 are WIP/fixup noise
git log --oneline -6
# abc123 fix typo
# def456 WIP
# ghi789 add test
# jkl012 WIP: auth
# mno345 add auth logic
# pqr678 fix old test

# Squash them down to 2 clean commits
git reset --soft HEAD~6              # move back 6, keep everything staged
git commit -m "feat(auth): add JWT authentication middleware"
# Now selectively unstage + re-stage for the second commit
git restore --staged tests/          # unstage the test files
git commit -m "test(auth): add unit tests for JWT validation"
git add tests/
# Check the result
git log --oneline
```

---

## Real World Example

A junior engineer pushed a commit containing a `.env` file with production credentials — a classic Friday afternoon incident. The file contained three API keys and a database password. The team needed to rotate credentials AND scrub the file from Git history. Reset was the first tool, but not the only one.

```bash
# Immediate triage — was it pushed?
git log --oneline -3
# a7f1d9c Add user onboarding flow   ← pushed
# b3e2f4a Fix null ref in payment    ← pushed
# c9d8e1f Update configuration       ← pushed (contains .env!)

# Step 1: rotate all credentials FIRST — history is already public
# (done out-of-band: Stripe, SendGrid, AWS rotated)

# Step 2: remove from history using filter-repo (reset alone can't rewrite pushed history)
# git-filter-repo is the modern replacement for BFG / filter-branch
pip install git-filter-repo
git filter-repo --path .env --invert-paths

# Step 3: force push all affected branches (coordinate with team first)
git push origin main --force-with-lease

# Step 4: ensure .gitignore prevents recurrence
echo ".env" >> .gitignore
echo ".env.*" >> .gitignore
echo "!.env.example" >> .gitignore
git add .gitignore
git commit -m "chore: add .env to gitignore (prevent secret exposure)"

# Step 5: add a pre-commit hook to catch secrets before they're committed
# (see git-hooks.md for the full hook implementation)

# If the commit hadn't been pushed yet — much simpler:
git reset --soft HEAD~1          # undo the commit, keep changes staged
echo ".env" >> .gitignore        # add to gitignore
git restore --staged .env        # unstage the .env file
git commit -m "Update configuration"  # re-commit without it
```

*The key insight: `git reset` is only a complete solution when the commit is local. Once a commit is pushed, objects are on GitHub's servers and must be treated as compromised — reset + force push is not sufficient because the data was accessible to anyone with repo access during the window.*

---

## Common Misconceptions

**"`git reset --hard` permanently deletes the commits"**
Nothing is deleted immediately. The commits become unreachable from any branch but remain as objects in `.git/objects`. `git reflog` tracks every position HEAD has pointed to, typically for 90 days. You can recover from any `--hard` reset with `git reset --hard HEAD@{N}` as long as GC hasn't run. What IS permanently lost: uncommitted changes in the working directory and staging area that `--hard` wipes.

**"`git reset HEAD <file>` and `git checkout -- <file>` do the same thing"**
`git reset HEAD <file>` (or `git restore --staged <file>`) updates the index to match HEAD — it unstages the file. The working directory is untouched. `git checkout -- <file>` (or `git restore <file>`) updates the working directory to match the index — it discards unstaged changes. They modify different trees. Run them in order to fully revert a file: first unstage, then restore the working dir.

**"`git reset` on a path moves the branch pointer"**
`git reset -- <path>` does not move the branch pointer at all. It only updates the index for the specified path. The branch stays exactly where it is. This is a completely different operation from `git reset HEAD~1` despite using the same command name.

---

## Gotchas

- **`--hard` on uncommitted changes is permanent.** Untracked files aren't touched by `--hard`, but tracked modified files are overwritten. There is no undo except `git reflog` for commits — and reflog can't recover uncommitted work that was never committed.

- **Resetting a pushed branch and force-pushing breaks teammates.** Anyone who pulled before your force-push now has a diverged history. Their next `git pull` produces a merge commit that resurrects the commits you deleted. Coordinate before any force-push to a shared branch.

- **`HEAD~1` vs `HEAD^` are equivalent for linear history but differ on merge commits.** `HEAD^2` means the second parent of a merge commit — not two commits back. Stick to `HEAD~N` for counting back N commits unless you deliberately need a specific merge parent.

- **After `--soft` reset and re-commit, you still need `--force-with-lease` to push.** The rewritten commit has a new hash even if the content is identical — the remote has the old hash and will reject a normal push.

- **`git reset` won't unstage files from the very first commit.** Before the first commit, there is no HEAD. Use `git rm --cached <file>` to unstage files in an empty repo.

---

## Interview Angle

**What they're really testing:** Whether you understand Git's three trees (HEAD, index, working directory) and can reason about what each reset mode touches.

**Common question forms:**
- "What's the difference between `git reset --soft`, `--mixed`, and `--hard`?"
- "How would you undo the last three commits without losing your work?"
- "What's the difference between `git reset` and `git revert`?"

**The depth signal:** A junior recites that `--hard` deletes changes and `--soft` keeps them. A senior explains it in terms of Git's three trees — `--soft` only moves HEAD, `--mixed` also resets the index to match HEAD, and `--hard` additionally resets the working tree. They know `git reset <path>` is a completely different operation that doesn't move HEAD at all, when to use `git reflog` to recover from a bad reset, and why `git revert` is the correct tool for pushed commits.

**Follow-up questions to expect:**
- "Can you recover from `git reset --hard`? How?"
- "Why should you use `git revert` instead of `git reset` on a shared branch?"

---

## Related Topics

- [git-revert.md](git-revert.md) — The safe alternative for undoing pushed commits: creates a new commit that inverts changes instead of rewriting history.
- [git-reflog.md](git-reflog.md) — The recovery mechanism when a `--hard` reset goes wrong; tracks every position HEAD has been.
- [git-staging-area.md](git-staging-area.md) — Understanding the three trees makes reset's modes immediately obvious.
- [git-merge-conflicts.md](git-merge-conflicts.md) — `git reset --hard` is often used to abort a merge mid-conflict; understanding what it resets to matters here.

---

## Source

[Git Documentation — git-reset](https://git-scm.com/docs/git-reset)

---
*Last updated: 2026-04-23*