# Git Branches

> A branch is a lightweight movable pointer — a file containing a single commit hash — that advances automatically with each new commit.

---

## When To Use It

Use branches to isolate every unit of work: features, bugfixes, experiments, releases. The cost of creating a branch is writing 41 bytes to a file — there is no excuse not to branch. Use long-lived branches (main, develop) as integration targets, not as places to work directly. The only time you work directly on a shared branch is an emergency hotfix with team agreement.

---

## Core Concept

A branch is a file in `.git/refs/heads/` containing one commit hash. That's it. When you commit, Git creates the commit object with HEAD's current commit as parent, then updates the branch file to point to the new hash. Switching branches updates HEAD to point to a different branch file, then updates the working directory and index to match that branch's commit tree. Branches are cheap because Git stores snapshots, not diffs — checking out any branch is just swapping which tree the index and working directory reflect.

---

## The Code

**Branch basics**
```bash
# Create and switch (modern)
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

**Branch strategies — naming conventions**
```bash
# Common prefixes
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

---

## Gotchas

- **Deleting a branch doesn't delete its commits.** The branch ref is deleted, but the commit objects remain in `.git/objects` until garbage collected (30 days by default). `git reflog` still shows the commit hash — you can restore with `git branch recovered abc1234`.
- **`git fetch` updates remote tracking branches but doesn't merge anything.** After `git fetch origin`, your local `main` is unchanged — `origin/main` is updated. You still need `git merge origin/main` or `git pull` to integrate. This distinction matters when you want to inspect remote changes before merging.
- **Remote tracking branches (`origin/main`) are not real branches — you can't commit to them directly.** They're read-only snapshots of the remote state at the last fetch. Checking one out puts you in detached HEAD.
- **`git push` without `-u` works once but doesn't set tracking.** Subsequent `git pull` won't know which remote branch to pull from and will ask. Set `-u` on the first push of every new branch.
- **Branch names are path-separated — `feature/auth` creates a directory in `.git/refs/heads/`.** This means you can't have both a branch named `feature` and a branch named `feature/auth` — `feature` would need to be both a file and a directory, which the filesystem doesn't allow.

---

## Interview Angle

**What they're really testing:** Whether you understand branches as refs rather than copies of code, and can reason about remote tracking vs local branches.

**Common question form:** *"What is a Git branch?"* or *"What's the difference between `git fetch` and `git pull`?"* or *"How does Git know which remote branch to push to?"*

**The depth signal:** A junior says "a branch is an isolated copy of the code." A senior says a branch is a 41-byte file containing a commit hash — creating a branch is O(1) regardless of repo size because Git stores snapshots not diffs. They explain that `git fetch` updates `origin/main` (the remote tracking ref) without touching local `main`, while `git pull` is `fetch` + `merge`. They know the upstream tracking relationship set by `-u` is stored in `.git/config` under `branch.<name>.remote` and `branch.<name>.merge`.

---

## Related Topics

- [[git/git-internals.md]] — A branch is a file in `.git/refs/heads/`; HEAD is a symref pointing to it.
- [[git/git-merging.md]] — Branches converge through merge; the merge commit records both parents.
- [[git/git-rebasing.md]] — Rebase moves a branch's commits onto a new base, rewriting their hashes.
- [[git/git-workflows.md]] — GitFlow, trunk-based development, and GitHub Flow are branch management strategies.

---

## Source

[Git Book — Git Branching — Branches in a Nutshell](https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell)

---
*Last updated: 2026-03-24*