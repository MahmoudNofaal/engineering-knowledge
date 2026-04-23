# Git Stash

> Stash saves your uncommitted working directory and index changes onto a stack, giving you a clean working tree without committing, so you can switch context and come back later.

---

## When To Use It

Use stash when you need to switch branches or pull changes but have work in progress you're not ready to commit. It's a short-term holding area, not a backup strategy — stash entries are local, not pushed to the remote, and are easy to forget about. If you find yourself stashing the same work repeatedly for days, it should be a WIP commit on a branch instead.

---

## Core Concept

`git stash` creates two (or three) commit objects internally — one for the index state and one for the working directory state — and stores references to them on a stack at `refs/stash`. It then resets the working directory and index to match HEAD. `git stash pop` replays those changes back and removes the entry from the stack. `git stash apply` replays without removing — useful when you want to apply the same stash to multiple branches. The stash stack is LIFO but you can access any entry by index.

---

## The Code

**Basic stash operations**
```bash
# Stash everything (tracked modified files + staged changes)
git stash

# Stash with a descriptive message (findable later)
git stash push -m "WIP: rate limiter — needs Redis config"

# List all stashes
git stash list
# stash@{0}: On feature/auth: WIP: rate limiter — needs Redis config
# stash@{1}: On main: experiment with new parser

# Apply latest stash and remove from stack
git stash pop

# Apply latest stash but keep it on the stack
git stash apply

# Apply a specific stash by index
git stash pop stash@{2}
git stash apply stash@{1}
```

**What gets stashed — controlling scope**
```bash
# Default: stashes tracked modified files + staged changes
# Does NOT stash: untracked files, ignored files

# Include untracked files
git stash push -u
git stash push --include-untracked

# Include untracked AND ignored files (rarely needed)
git stash push --all

# Stash only specific files
git stash push -m "just the auth changes" src/auth.py tests/test_auth.py

# Stash only unstaged changes — leave staged changes in index
git stash push --keep-index
# Useful for: testing only what you're about to commit
```

**Interactive stash — partial stash**
```bash
# Choose which hunks to stash (like git add -p but for stashing)
git stash push -p
# y = stash this hunk
# n = leave this hunk in working directory
# s = split into smaller hunks
```

**Inspecting stash contents**
```bash
# Show summary of what's in a stash
git stash show stash@{0}
git stash show stash@{0} --stat

# Show the full diff
git stash show stash@{0} -p

# See stash as a branch (most readable)
git stash branch temp-branch stash@{0}
# Creates a new branch at the commit where the stash was made
# and applies the stash on top — avoids conflicts from branch drift
```

**Cleaning up stashes**
```bash
# Drop a specific stash
git stash drop stash@{1}

# Clear all stashes (no recovery — they're removed from reflog too)
git stash clear

# Recover a dropped stash — it's still in the object store briefly
git fsck --unreachable | grep commit
# Find dangling commits, inspect them with git show
# Then: git stash apply <dangling-commit-hash>
```

**Common pattern — pull with dirty working directory**
```bash
# Can't pull because you have uncommitted changes
git pull
# error: Your local changes to the following files would be overwritten by merge

# Option 1: stash, pull, pop
git stash
git pull
git stash pop

# Option 2: one command
git pull --autostash   # stash, pull, pop automatically
```

---

## Gotchas

- **Stash entries are local — they're never pushed to the remote.** If you stash on your laptop and then need the work on another machine, the stash isn't there. For sharing WIP across machines, use a WIP commit on a personal branch (`git commit -m "WIP"`) and push it.
- **`git stash pop` on a conflicting stash doesn't remove the stash entry.** If applying the stash causes conflicts, the stash stays in the list — you need to resolve conflicts, then `git stash drop stash@{0}` manually. Many people forget this and end up with duplicate stash entries.
- **Stashing without `-u` leaves untracked files in the working directory.** If your WIP includes new files you haven't added yet, they stay behind when you stash. The next branch you switch to will have those files sitting in its working directory. Always use `-u` if your work involves new files.
- **`git stash clear` is not recoverable.** Unlike most Git operations, clearing the stash doesn't leave reflog entries in the normal way. The objects may linger in the object store briefly, but there's no guaranteed recovery path. Use `git stash drop` to remove individual entries instead.
- **Stash entries become harder to apply as the target branch drifts.** A stash from two weeks ago on a fast-moving branch will likely conflict when applied. The longer a stash sits, the more it should be a WIP commit on a branch instead.

---

## Interview Angle

**What they're really testing:** Whether you know stash's limitations (local-only, no untracked files by default) and when a WIP commit is a better choice.

**Common question form:** *"How do you save work in progress without committing?"* or *"How do you handle switching branches mid-feature?"*

**The depth signal:** A junior says "use `git stash` to save your work." A senior knows the default stash misses untracked files (`-u` flag required), that `stash pop` doesn't remove the entry on conflict, that stashes are local and not pushed, and that `git stash branch` is the clean way to apply a stash that conflicts with the current branch state. They also know when NOT to use stash: anything that lives longer than a day should be a WIP commit on a personal branch and pushed — stash is ephemeral working memory, not durable storage.

---

## Related Topics

- [[git/git-staging-area.md]] — Stash saves both the index and working directory; `--keep-index` separates them deliberately.
- [[git/git-branches.md]] — A WIP commit on a branch is often better than a long-lived stash for multi-day in-progress work.
- [[git/git-commits.md]] — `git commit --fixup` + interactive rebase is the alternative to stash for work-in-progress that you want to fold into an earlier commit.
- [[git/git-internals.md]] — Stash creates real commit objects internally; `git fsck --unreachable` can recover dropped stashes from the object store.

---

## Source

[Git documentation — git-stash](https://git-scm.com/docs/git-stash)

---
*Last updated: 2026-03-24*