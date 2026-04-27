# Git Fetch, Pull, and Push

> `git fetch` downloads remote changes without integrating; `git pull` fetches and integrates; `git push` uploads local commits to a remote.

---

## Quick Reference

| | |
|---|---|
| **What it is** | The three commands that synchronise your local repo with a remote |
| **Use when** | Syncing with teammates, publishing work, checking remote state |
| **Avoid when** | `git pull` with uncommitted changes — fetch first, then decide how to integrate |
| **Git version** | Core since Git 1.0; `--force-with-lease` since Git 1.8.5; `--autostash` since Git 2.6 |
| **Key remotes location** | `.git/refs/remotes/` (remote tracking refs), `.git/config` (remote URLs) |
| **Key commands** | `git fetch`, `git fetch --prune`, `git pull --rebase`, `git push -u`, `git push --force-with-lease` |

---

## When To Use It

Use `git fetch` to see what changed on the remote without affecting your local work. Use `git pull` to fetch and integrate in one step — but understand what integration strategy it will use (merge vs rebase). Use `git push` to share your commits. On shared branches, never use `git push --force`; always use `--force-with-lease`.

---

## Core Concept

A remote is a named URL stored in `.git/config`. When you fetch, Git downloads new objects and updates remote tracking refs (`origin/main`, `origin/feat/auth`) — these are read-only snapshots of the remote's branches at the time of fetch. Your local branches are untouched. `git pull` is `git fetch` followed by `git merge` (or `git rebase` if configured). `git push` uploads objects to the remote and asks it to advance a branch ref — the remote will reject this if it's not a fast-forward (i.e., the remote has commits you don't have), which is why you must fetch and integrate before pushing.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | fetch/pull/push established with the remote protocol |
| Git 1.8.5 | `--force-with-lease` added — safer than `--force` |
| Git 2.0 | `push.default = simple` became the default (push only current branch) |
| Git 2.6 | `--autostash` for `git pull` — stash, pull, pop automatically |
| Git 2.27 | `--set-upstream` shorthand added to push |
| Git 2.29 | `--negotiate-only` for partial clone negotiations |
| Git 2.39 | Bundle URIs for faster initial clone via CDN |

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `git fetch` | O(new objects) | Only downloads objects not already local |
| `git pull` | O(fetch + merge/rebase) | Fetch cost + integration cost |
| `git push` (new commits) | O(new objects) | Only uploads objects not on remote |
| `git push` (first push of large repo) | O(entire repo) | Initial push sends all objects |
| `git fetch --prune` | O(remote refs) | Small overhead to check and remove stale refs |

---

## The Code

**Fetching**
```bash
# Fetch all remotes
git fetch

# Fetch a specific remote
git fetch origin

# Fetch a specific branch
git fetch origin main

# Fetch and prune deleted remote branches
git fetch --prune
git fetch -p   # shorthand

# Fetch all remotes and prune (alias this — run regularly)
git fetch --all --prune

# Fetch a specific PR from GitHub (without checking out)
git fetch origin pull/217/head:pr-217
git switch pr-217    # now you can check it out
```

**Understanding remote tracking refs**
```bash
# After git fetch, see what changed on the remote
git log HEAD..origin/main --oneline    # commits on remote not in local main
git diff HEAD origin/main              # diff between local and remote main

# See all remote tracking refs
git branch -r
# origin/main
# origin/feat/auth
# origin/HEAD -> origin/main

# Remote tracking refs are read-only
git switch origin/main    # detached HEAD — can't commit here
# Always create a local branch: git switch -c local-main origin/main
```

**Pulling**
```bash
# Pull with merge (default — creates a merge commit if branches diverged)
git pull

# Pull with rebase (cleaner — replays your commits on top of remote)
git pull --rebase

# Configure rebase as the default pull strategy (recommended)
git config --global pull.rebase true

# Pull with autostash (stash dirty work, pull, pop)
git pull --autostash
git pull --rebase --autostash  # rebase + autostash

# Pull a specific branch into current
git pull origin main

# Fetch without merging, then decide
git fetch origin
git log HEAD..origin/main --oneline   # see what's coming
git rebase origin/main                # integrate with rebase
# OR
git merge origin/main                 # integrate with merge
```

**Pushing**
```bash
# Push and set upstream tracking (first push of a new branch)
git push -u origin feat/auth
# After -u: git push and git pull work without specifying remote/branch

# Push current branch (after upstream is set)
git push

# Push a specific branch explicitly
git push origin feat/auth

# Push all local branches
git push --all origin

# Push with tags (annotated only — recommended)
git push --follow-tags origin main

# Delete a remote branch
git push origin --delete feat/old-feature
git push origin :feat/old-feature    # alternative syntax
```

**Force push safely**
```bash
# NEVER use --force on shared branches
# git push --force origin main  ← DANGEROUS

# ALWAYS use --force-with-lease
git push --force-with-lease origin feat/auth
# Fails if remote has commits you haven't fetched
# Protects against overwriting teammates' work

# With explicit expected state (even safer)
git push --force-with-lease=feat/auth:origin/feat/auth origin feat/auth
# Explicitly states what you expect the remote to be at
```

**Refspecs — what actually moves data**
```bash
# git push/fetch use refspecs: <source>:<destination>
# Push local main to remote main
git push origin main:main

# Push local feature branch to a differently-named remote branch
git push origin feat/local:feat/remote

# Fetch a remote branch into a local branch with a different name
git fetch origin main:local-main-copy

# Delete a remote branch using an empty source
git push origin :feat/old-branch   # empty source = delete destination
```

---

## Real World Example

A team lead discovered that three engineers had been using `git pull` (merge strategy) while two used `git pull --rebase`, creating inconsistent history with unnecessary merge commits. The fix was a `git config --global pull.rebase true` in the team setup script and educating the team on the difference.

```bash
# Before: mixed pull strategies producing messy history
git log --oneline --graph
# *   a1b2c3d Merge branch 'main' of github.com/org/repo
# |\
# | * d4e5f6g feat: add search
# * | g7h8i9j fix: null ref
# |/
# * j0k1l2m feat: add dashboard   ← unnecessary merge commits

# After: consistent rebase strategy
git config --global pull.rebase true

git log --oneline --graph
# * a1b2c3d fix: null ref    ← replayed on top of remote
# * d4e5f6g feat: add search ← from remote
# * j0k1l2m feat: add dashboard
# Linear history — no unnecessary merge commits
```

---

## Common Misconceptions

**"`git pull` is just `git fetch` + `git merge`"** — Only by default. `git pull --rebase` does `git fetch` + `git rebase`. Configure `pull.rebase = true` globally and `git pull` will always rebase.

**"`git fetch` is safe, `git pull` is risky"** — `git fetch` is always safe (read-only on your local branches). `git pull` is also safe as long as you understand which integration strategy it will use and you have no uncommitted changes that would conflict.

**"`git push --force` is fine on my own branch"** — Until a reviewer pushed a suggested-change commit to your branch between your last fetch and your force push, silently deleting their work. Always use `--force-with-lease`.

---

## Gotchas

- **`git push` without `-u` doesn't set tracking.** Future `git pull` asks which remote/branch to use. Set `-u` on every first push.
- **`git fetch --prune` is not run automatically.** Stale remote tracking refs accumulate. Run regularly or alias it.
- **`pull.rebase = true` with uncommitted changes will pause.** Use `pull.rebase = true` with `rebase.autoStash = true` for smoother daily workflow.
- **Pushing to a non-fast-forward remote requires knowing why.** If `git push` is rejected, always fetch and inspect before force-pushing — the remote may have legitimate commits.

---

## Interview Angle

**What they're really testing:** Whether you understand the remote protocol and can reason about tracking refs, integration strategies, and safe force-push patterns.

**Common question forms:** "What's the difference between `git fetch` and `git pull`?" / "When would you use `--force-with-lease`?"

**The depth signal:** A junior says "`git fetch` downloads, `git pull` downloads and merges." A senior explains remote tracking refs (`origin/main` as a read-only snapshot updated by fetch), that `git pull` is configurable (merge vs rebase), and that `--force-with-lease` protects against overwriting teammates' work on a shared branch in a way `--force` does not.

---

## Related Topics

- [git-branches.md](git-branches.md) — Remote tracking refs and upstream configuration.
- [git-rebasing.md](git-rebasing.md) — `pull --rebase` is the most common use of rebase.
- [git-merging.md](git-merging.md) — `pull` without rebase does a merge.
- [git-config.md](git-config.md) — `pull.rebase`, `push.followTags`, `push.default` are key config settings.

---

## Source

[Git Book — Working with Remotes](https://git-scm.com/book/en/v2/Git-Basics-Working-with-Remotes)

---
*Last updated: 2026-04-24*