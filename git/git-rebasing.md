# Git Rebasing

> Rebase replays commits from one branch onto a new base commit, rewriting each commit's hash in the process — producing a linear history without merge commits.

---

## When To Use It

Use rebase to keep a feature branch up to date with main before merging, and to clean up messy local commit history with interactive rebase before sharing. Don't rebase commits that have been pushed to a shared branch — rewriting hashes that others have pulled forces everyone to reconcile diverged histories. The rule: rebase local, merge shared.

---

## Core Concept

Rebase takes the commits on your branch that aren't on the target, detaches them, replays them one by one on top of the target, and updates your branch ref to point to the last replayed commit. Each replayed commit gets a new hash because its parent changed — even if the content is identical. This produces a linear history where it looks like you branched off the latest main and did all your work there, even if the actual branching point was weeks ago. The original commits become unreachable and are eventually garbage collected.

---

## The Code

**Standard rebase — update feature branch from main**
```bash
# Before:
# main:    A → B → C → D
# feature:       ↘ E → F

git switch feature
git rebase main

# After:
# main:    A → B → C → D
# feature:               → E' → F'
# E' and F' are NEW commits with different hashes than E and F
# The branch looks like it was started from D, not B
```

**Interactive rebase — rewrite local history**
```bash
# Rewrite the last 4 commits
git rebase -i HEAD~4

# Editor opens with one line per commit, oldest first:
# pick a1b2c3 WIP: start auth
# pick d4e5f6 add tests
# pick g7h8i9 fix typo
# pick j0k1l2 actually fix the bug

# Commands:
# pick   = keep commit as-is
# reword = keep changes, edit message
# edit   = pause to amend (add files, split commit)
# squash = merge into previous commit, combine messages
# fixup  = merge into previous commit, discard this message
# drop   = delete commit entirely
# s      = shorthand for squash

# Common cleanup before merging a PR:
# pick a1b2c3 Add auth endpoint
# fixup d4e5f6 WIP: start auth
# fixup g7h8i9 fix typo
# fixup j0k1l2 add missing import
# → one clean commit
```

**Rebase onto a specific commit**
```bash
# Move commits to a completely different base
git rebase --onto new-base old-base feature

# Example: feature branched from develop, move it to main
# Before:
# main:    A → B
# develop:       → C → D
# feature:               → E → F

git rebase --onto main develop feature

# After:
# main:    A → B → E' → F'  (feature rebased onto main, C and D excluded)
```

**Handling conflicts during rebase**
```bash
# Rebase stops at the conflicting commit
# CONFLICT (content): Merge conflict in src/auth.py

# 1. Resolve conflicts in the file (same markers as merge)
# 2. Stage resolved files
git add src/auth.py

# 3. Continue rebase
git rebase --continue

# Skip this commit entirely (rare — use when commit becomes empty after resolution)
git rebase --skip

# Abort — return to state before rebase started
git rebase --abort

# See where you are during rebase
cat .git/rebase-merge/msgnum    # current commit number
cat .git/rebase-merge/end       # total commits to replay
```

**Preserve merge commits during rebase**
```bash
# --rebase-merges: keep merge commits in the rebased history
# Without it: rebase linearizes everything, merge commits are lost
git rebase --rebase-merges main
```

**After rebasing a pushed branch — force push**
```bash
# Rebase rewrites hashes — remote branch has different history
# Regular push is rejected
git push origin feature/auth
# ! [rejected] feature/auth -> feature/auth (non-fast-forward)

# Force push — overwrites remote history
git push --force-with-lease origin feature/auth
# --force-with-lease: safer than --force
# Fails if someone else pushed to the branch since your last fetch
# Prevents silently overwriting others' work

# Never use --force on main or any shared long-lived branch
```

**Autosquash — fixup commits marked at creation time**
```bash
# Create a fixup commit targeting a specific earlier commit
git commit --fixup a1b2c3    # message: "fixup! original commit message"
git commit --squash a1b2c3   # message: "squash! original commit message"

# Interactive rebase automatically orders and marks these
git rebase -i --autosquash HEAD~5
# fixup commits are automatically placed after their target and marked 'fixup'
```

---

## Gotchas

- **Rebasing shared branches breaks everyone who has pulled them.** Their local branch still points to the old commit hashes. When they try to push or pull, Git sees diverged histories and they must `git pull --rebase` or reset. The golden rule: never rebase a branch that others have based work on.
- **`--force` is more dangerous than `--force-with-lease`.** `git push --force` overwrites whatever is on the remote, even if a teammate pushed since your last fetch. `--force-with-lease` checks that your remote tracking ref matches the actual remote — it fails if the remote has moved, giving you a chance to incorporate the new commits first.
- **Conflicts during rebase must be resolved once per commit, not once total.** If ten commits each touch the same file, you might resolve the same conflict ten times. Squash related commits before rebasing onto a branch with many diverged changes.
- **`git rebase -i` with `drop` doesn't delete the content permanently.** The original commits are still in reflog for 30 days. If you drop the wrong commit, `git reflog` can retrieve it.
- **Empty commits after rebase cause `git rebase --continue` to fail until you `--skip`.** If a commit's changes were already applied by an earlier commit in the target branch, the replay produces an empty commit. Git stops and asks what to do — `git rebase --skip` moves past it.

---

## Interview Angle

**What they're really testing:** Whether you understand why rebase rewrites history and can articulate the merge vs rebase tradeoff clearly.

**Common question form:** *"What's the difference between merge and rebase?"* or *"When would you use interactive rebase?"* or *"Why is force-pushing dangerous?"*

**The depth signal:** A junior says "rebase makes history cleaner." A senior explains that rebase replays commits with new parent pointers, producing new SHA-1 hashes for every replayed commit — the content may be identical but the commits are different objects. They know `--force-with-lease` vs `--force` and why the distinction matters on team branches. They can describe `--onto` for moving commits between arbitrary bases, and know that `--autosquash` with `git commit --fixup` is the ergonomic way to clean up history as you work rather than all at once before merging.

---

## Related Topics

- [[git/git-merging.md]] — The alternative integration strategy; knowing both lets you choose deliberately.
- [[git/git-internals.md]] — Why rebase changes hashes: each commit object includes its parent hash as input to SHA-1.
- [[git/git-commits.md]] — Interactive rebase is the primary tool for rewriting local commit history.
- [[git/git-branches.md]] — Rebase moves a branch's commits to a new base; the branch ref updates to the last replayed commit.

---

## Source

[Git Book — Git Branching — Rebasing](https://git-scm.com/book/en/v2/Git-Branching-Rebasing)

---
*Last updated: 2026-03-24*