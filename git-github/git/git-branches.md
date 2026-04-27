# Git Branches

> A branch is a lightweight movable pointer — a file containing a single commit hash — that advances automatically with each new commit.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A 41-byte file pointing to one commit |
| **Use when** | Isolating any unit of work from shared state |
| **Avoid when** | Working directly on main in a solo repo with no risk |
| **Git version** | Branches since Git 1.0; `git switch` added Git 2.23 |
| **Key location** | `.git/refs/heads/<name>` |
| **Key commands** | `git switch -c`, `git branch`, `git push -u`, `git branch -d` |

---

## When To Use It

Use branches to isolate every unit of work: features, bugfixes, experiments, releases. The cost of creating a branch is writing 41 bytes to a file — there is no excuse not to branch. Use long-lived branches (main, develop) as integration targets, not as places to work directly. The only time you work directly on a shared branch is an emergency hotfix with team agreement.

---

## Core Concept

A branch is a file in `.git/refs/heads/` containing one commit hash. That's it. When you commit, Git creates the commit object with HEAD's current commit as parent, then updates the branch file to point to the new hash. Switching branches updates HEAD to point to a different branch file, then updates the working directory and index to match that branch's commit tree. Branches are cheap because Git stores snapshots, not diffs — checking out any branch is just swapping which tree the index and working directory reflect.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | Branches as ref files in `.git/refs/heads/` — the core model |
| Git 1.7 | `git checkout -b` became the standard create-and-switch idiom |
| Git 2.5 | `git worktree` added — multiple branches checked out simultaneously |
| Git 2.23 | `git switch` and `git restore` introduced, splitting `git checkout`'s three jobs |
| Git 2.28 | `init.defaultBranch` config added — rename default from `master` to `main` |
| Git 2.38 | `--update-refs` flag for rebase — updates stacked branch refs automatically |

*Before Git 2.23, `git checkout` handled branch switching, file restoration, and detached HEAD — three different operations under one command. `git switch` exists solely to remove that ambiguity.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Create branch | O(1) | Writes 41 bytes to a file — free regardless of repo size |
| Switch branch | O(files changed) | Git only updates files that differ between branches |
| List local branches | O(n refs) | Fast for hundreds of branches; `.git/refs/` can slow on thousands |
| Delete branch | O(1) | Deletes the ref file; commit objects remain until GC |
| Push new branch | O(commits to send) | First push sends object data; subsequent pushes are incremental |

**Allocation behaviour:** Branch refs live in `.git/refs/heads/` as individual files, or get packed into `.git/packed-refs` after `git gc`. Packed-refs is a single flat file — faster to read when you have many branches.

**Benchmark notes:** Repos with thousands of stale remote-tracking branches slow down `git fetch` noticeably. Run `git remote prune origin` or `git fetch --prune` regularly on active repos. At 10,000+ refs, consider `git pack-refs --all` to consolidate into packed-refs.

---

## The Code

**Branch basics**
```bash
# Create and switch (modern — preferred)
git switch -c feature/auth

# Create and switch (classic — still works everywhere)
git checkout -b feature/auth

# Create without switching
git branch feature/auth

# Create from a specific commit or tag
git switch -c hotfix/payment-null abc1234
git switch -c release/v2.0 v1.9.0

# List branches
git branch              # local only
git branch -r           # remote tracking branches
git branch -a           # all (local + remote)
git branch -v           # with last commit hash and message
git branch --merged     # branches already merged into current
git branch --no-merged  # branches not yet merged
```

**Switching branches**
```bash
# Switch (modern — clearer intent than checkout)
git switch main

# Checkout (classic)
git checkout main

# Switch and discard uncommitted changes (dangerous)
git switch -f main

# Return to previous branch
git switch -

# Git won't switch if uncommitted changes conflict with the target branch
# Options: commit, stash, or use -f (force, discards changes)
```

**Remote branches**
```bash
# Fetch remote branches without merging
git fetch origin

# See remote tracking refs
git branch -r
# origin/main
# origin/feature/auth

# Track a remote branch — sets up push/pull target
git switch -c feature/auth origin/feature/auth   # creates local tracking branch
git switch --track origin/feature/auth           # shorthand

# Push and set upstream in one step
git push -u origin feature/auth
# -u = --set-upstream: links local branch to remote for future git push/pull

# After -u is set, just use:
git push
git pull

# Delete remote branch
git push origin --delete feature/auth
```

**Renaming and deleting**
```bash
# Rename current branch
git branch -m new-name

# Rename any branch
git branch -m old-name new-name

# Delete merged branch
git branch -d feature/auth

# Force delete unmerged branch
git branch -D feature/auth   # data isn't lost — commit is still reachable via reflog

# Delete remote tracking ref (after remote branch was deleted)
git remote prune origin
# or fetch with pruning
git fetch --prune
```

**Branch naming conventions**
```bash
# Common prefixes — enforce via CI or pre-push hook
feature/user-authentication
bugfix/null-pointer-in-payment
hotfix/critical-security-patch
release/v2.1.0
chore/upgrade-dependencies
experiment/new-search-algorithm

# Check what branch you're on
cat .git/HEAD
# ref: refs/heads/feature/auth

# See the full ref path
git symbolic-ref HEAD
```

**Viewing branch relationships**
```bash
# Visualize the commit graph
git log --oneline --graph --all

# Find common ancestor of two branches
git merge-base main feature/auth

# See commits on feature not yet on main
git log main..feature/auth --oneline

# See commits on either branch but not both (symmetric difference)
git log main...feature/auth --oneline --left-right
```

**Stacked branches (dependent feature chains)**
```bash
# Branch B depends on branch A
git switch -c feature/auth-base
# ... work ...
git switch -c feature/auth-jwt feature/auth-base

# Keep feature/auth-jwt current when feature/auth-base changes
git switch feature/auth-jwt
git rebase feature/auth-base

# Git 2.38+: rebase --update-refs updates all stacked branches at once
git rebase origin/main --update-refs
# Updates every branch in the stack that sits between origin/main and HEAD
```

---

## Real World Example

A platform team at a mid-sized SaaS company had 40 engineers committing to a monorepo. Their old workflow had everyone working directly on `develop`, causing constant broken builds and "who broke the pipeline?" Slack threads. The fix was strict branch-per-feature enforcement with automated cleanup.

```bash
# .github/workflows/branch-cleanup.yml excerpt
# Auto-deletes merged branches older than 7 days

name: Cleanup merged branches
on:
  schedule:
    - cron: '0 9 * * MON'

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0   # need full history to check merge status

      - name: Delete stale merged branches
        run: |
          git fetch --prune origin

          # Find branches merged into main more than 7 days ago
          git branch -r --merged origin/main \
            | grep -v 'origin/main' \
            | grep -v 'origin/release/' \
            | sed 's|origin/||' \
            | while read branch; do
                # Check last commit date on that branch
                last_commit=$(git log -1 --format="%ct" "origin/$branch" 2>/dev/null)
                cutoff=$(date -d '7 days ago' +%s)

                if [ -n "$last_commit" ] && [ "$last_commit" -lt "$cutoff" ]; then
                  echo "Deleting stale merged branch: $branch"
                  git push origin --delete "$branch"
                fi
              done
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

*The key insight: branch protection on `main` + automated cleanup changed the culture from "Git is a mess" to "Git is invisible." Engineers stopped thinking about branch management and started thinking about code. Stale branch count dropped from 300+ to under 20 within a month.*

---

## Common Misconceptions

**"Switching branches copies all the files to a new location"**
Git doesn't copy anything. A branch is a 41-byte ref file. Switching branches tells Git to update the working directory to match a different commit's tree — only files that differ between the two commits are touched on disk. A 50,000-file repo doesn't do 50,000 file operations on every `git switch`.

**"Deleting a branch deletes the commits"**
Deleting a branch deletes the ref file pointing to the tip commit. The commit objects remain in `.git/objects` and are still reachable via `git reflog` until garbage collection runs (default 30 days). `git branch -D feature/auth` followed immediately by `git branch recovered abc1234` gets all the work back.

**"`git fetch` updates my local branches"**
`git fetch origin` updates remote-tracking refs (`origin/main`, `origin/feature/auth`) but never touches your local branches. Your local `main` is completely unchanged after a fetch. That's why `git status` can say "Your branch is behind 'origin/main' by 3 commits" — fetch knows the remote moved, but your local branch is still where you left it.

---

## Gotchas

- **Deleting a branch doesn't delete its commits.** The branch ref is deleted, but commit objects remain in `.git/objects` until garbage collected (30 days by default). `git reflog` still shows the commit hash — restore with `git branch recovered abc1234`.

- **`git fetch` updates remote tracking branches but doesn't merge anything.** After `git fetch origin`, your local `main` is unchanged — `origin/main` is updated. You still need `git merge origin/main` or `git pull` to integrate. This distinction matters when you want to inspect remote changes before merging.

- **Remote tracking branches (`origin/main`) are read-only snapshots.** They're not real branches — you can't commit to them directly. Checking one out puts you in detached HEAD. Always create a local tracking branch to do work: `git switch -c feature/auth origin/feature/auth`.

- **`git push` without `-u` works once but doesn't set tracking.** Subsequent `git pull` won't know which remote branch to pull from and will ask. Set `-u` on the first push of every new branch — add it to muscle memory.

- **Branch names with `/` create directory structure in `.git/refs/heads/`.** You can't have both a branch named `feature` and a branch named `feature/auth` — `feature` would need to be both a file and a directory, which the filesystem doesn't allow. The error message ("cannot lock ref") is cryptic unless you know this.

- **`git branch -m` on the current branch renames locally but not on the remote.** After renaming, push the new name with `-u` and delete the old remote branch manually: `git push origin --delete old-name && git push -u origin new-name`.

---

## Interview Angle

**What they're really testing:** Whether you understand branches as refs rather than copies of code, and can reason about remote tracking vs local branches.

**Common question forms:**
- "What is a Git branch at the implementation level?"
- "What's the difference between `git fetch` and `git pull`?"
- "How does Git know which remote branch to push to?"

**The depth signal:** A junior says "a branch is an isolated copy of the code." A senior says a branch is a 41-byte file containing a commit hash — creating a branch is O(1) regardless of repo size because Git stores snapshots not diffs. They explain that `git fetch` updates `origin/main` (the remote tracking ref) without touching local `main`, while `git pull` is `fetch` + `merge`. They know the upstream tracking relationship set by `-u` is stored in `.git/config` under `branch.<name>.remote` and `branch.<name>.merge`.

**Follow-up questions to expect:**
- "What happens to the commits when you delete a branch?"
- "How would you recover a branch you accidentally deleted?"

---

## Related Topics

- [git-internals.md](git-internals.md) — A branch is a file in `.git/refs/heads/`; HEAD is a symref pointing to it.
- [git-merging.md](git-merging.md) — Branches converge through merge; the merge commit records both parents.
- [git-rebasing.md](git-rebasing.md) — Rebase moves a branch's commits onto a new base, rewriting their hashes.
- [git-workflows.md](git-workflows.md) — GitFlow, trunk-based development, and GitHub Flow are branch management strategies.
- [git-worktrees.md](git-worktrees.md) — Work on multiple branches simultaneously without stashing or switching.

---

## Source

[Git Book — Git Branching — Branches in a Nutshell](https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell)

---
*Last updated: 2026-04-23*