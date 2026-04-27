# Git Rebasing

> Rebase replays commits from one branch onto a new base commit, rewriting each commit's hash in the process — producing a linear history without merge commits.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Commit replay that produces a new, linear branch history |
| **Use when** | Updating a local feature branch or cleaning history before merging |
| **Avoid when** | Commits have been pushed to a branch others have pulled |
| **Git version** | Core since Git 1.0; `--update-refs` added Git 2.38; `--autosquash` added Git 1.7.4 |
| **Key location** | Rewrites commits in `.git/objects`; in-progress state in `.git/rebase-merge/` |
| **Key commands** | `git rebase`, `git rebase -i`, `git rebase --onto`, `git push --force-with-lease` |

---

## When To Use It

Use rebase to keep a feature branch up to date with main before merging, and to clean up messy local commit history with interactive rebase before sharing. Don't rebase commits that have been pushed to a shared branch — rewriting hashes that others have pulled forces everyone to reconcile diverged histories. The rule: rebase local, merge shared.

---

## Core Concept

Rebase takes the commits on your branch that aren't on the target, detaches them, replays them one by one on top of the target, and updates your branch ref to point to the last replayed commit. Each replayed commit gets a new hash because its parent changed — even if the content is identical. This produces a linear history where it looks like you branched off the latest main and did all your work there, even if the actual branching point was weeks ago. The original commits become unreachable and are eventually garbage collected.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | `git rebase` available as a core command |
| Git 1.7.4 | `--autosquash` and `git commit --fixup` added for automated commit cleanup |
| Git 1.8.2 | `--onto` improved with better conflict handling |
| Git 2.22 | `--rebase-merges` replaced the deprecated `--preserve-merges` |
| Git 2.26 | `--empty` flag controls how empty commits are handled during rebase |
| Git 2.38 | `--update-refs` added — automatically updates all intermediate branch refs during rebase, solving the stacked-branch maintenance problem |
| Git 2.41 | Interactive rebase `--reschedule-failed-exec` for CI-driven rebase workflows |

*`--update-refs` in Git 2.38 is a significant quality-of-life improvement for teams using stacked branches. Before it, rebasing the base of a stack required manually updating every dependent branch.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Simple rebase (no conflicts) | O(commits × diff size) | Replays each commit's diff against the new base |
| Interactive rebase | O(commits rewrit × diff) | Same as simple but pauses for user input |
| Rebase with conflicts | O(conflicts × resolution time) | Each conflicting commit pauses independently |
| `--autosquash` sort | O(N log N) | Git sorts fixup/squash commits before replaying |
| Force push after rebase | O(new commits to send) | Must send all rewritten objects to remote |

**Allocation behaviour:** Rebase creates new commit objects for every replayed commit — even if the content is identical to the original. Original commits become unreachable objects in `.git/objects` and are cleaned up by `git gc` after 30 days (configurable via `gc.reflogExpire`). On a branch with 20 commits, a rebase doubles the number of commit objects temporarily.

**Benchmark notes:** Rebasing a long-running branch (100+ commits) onto a fast-moving main can be slow due to repeated conflict checks per commit. Squash the branch to fewer commits with `git rebase -i` before rebasing onto main to reduce the number of conflict surfaces from N to 1.

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
# break  = pause without changes (useful for testing mid-rebase)

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
ls .git/rebase-merge/           # full state of in-progress rebase
```

**Stacked branches — the update-refs pattern (Git 2.38+)**
```bash
# Stacked branch setup
# main → A → B
# feature-base → C → D (based on main)
# feature-top  → E → F (based on feature-base)

# When main moves forward to G, H:
git switch feature-top
git rebase origin/main --update-refs
# Rebases feature-top AND automatically updates feature-base to match
# Without --update-refs, feature-base would still point to old C → D

# Before --update-refs existed, you had to do this manually:
git switch feature-base && git rebase origin/main
git switch feature-top && git rebase feature-base  # painful with 5+ branches in a stack
```

**After rebasing a pushed branch — force push safely**
```bash
# Rebase rewrites hashes — remote branch has different history
# Regular push is rejected
git push origin feature/auth
# ! [rejected] feature/auth -> feature/auth (non-fast-forward)

# Force push — overwrites remote history
git push --force-with-lease origin feature/auth
# --force-with-lease: fails if remote has commits you haven't seen
# Prevents silently overwriting teammates' work pushed after your last fetch

# --force-with-lease with explicit expected state (even safer)
git push --force-with-lease=feature/auth:origin/feature/auth origin feature/auth

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
# No manual reordering needed

# Configure autosquash as default so you never forget the flag
git config --global rebase.autoSquash true
```

---

## Real World Example

A backend team used stacked PRs — each feature built on the previous one. When the first PR in a stack of four got review feedback requiring changes, it rewrote three commits. Before `--update-refs`, updating the rest of the stack meant four manual rebase operations and careful ref tracking. With Git 2.38+, one command fixed the entire stack.

```bash
# Stack before review feedback:
# main
#   └─ feat/db-schema      (PR #101, 2 commits)
#       └─ feat/api-layer  (PR #102, 4 commits)
#           └─ feat/auth   (PR #103, 3 commits)
#               └─ feat/ui (PR #104, 5 commits)

# PR #101 got review: squash two commits + rename a column
git switch feat/db-schema
git rebase -i HEAD~2       # squash into one commit
# Also amends the commit with the column rename

# Now feat/db-schema has a new hash. Update the entire stack at once:
git switch feat/ui          # tip of the stack
git rebase origin/main --update-refs
# Git walks down: feat/ui rebased onto feat/auth
#                 feat/auth rebased onto feat/api-layer
#                 feat/api-layer rebased onto feat/db-schema
#                 feat/db-schema rebased onto main
# All four branches updated in one command.

# Force-push all updated branches
git push --force-with-lease origin \
  feat/db-schema feat/api-layer feat/auth feat/ui

# PRs #101-104 now show updated commits, GitHub marks stale reviews
# as needing re-review — intentional, since the base changed
echo "Stack updated. Re-request reviews on all four PRs."
```

*The key insight: stacked PRs let reviewers focus on one concern at a time instead of a 500-line monolith. The cost is rebase management when the base changes. `--update-refs` removes almost all of that cost — the stack becomes nearly as easy to maintain as a single branch.*

---

## Common Misconceptions

**"Never rebase — it's destructive"**
Rebase is only destructive on shared branches where others have based work on your commits. On your own local branch, before pushing, rebase is the correct tool for cleaning history. The rule is "rebase local, merge shared" — not "never rebase." Teams that never rebase have PR histories full of "fix typo", "WIP", and "add missing semicolon" commits that make `git bisect` and `git log` noisy.

**"Rebasing onto main changes my code"**
Rebase only changes your commit's *parent pointer* — not the diff it contains. Your code changes are exactly the same before and after rebasing. What changes is the base your changes are applied on top of. If conflicts arise, it's because the code you changed was also changed on main — that's a real conflict you'd have to resolve regardless of whether you merged or rebased.

**"`--force` and `--force-with-lease` are the same"**
`--force` overwrites whatever is on the remote unconditionally. If a teammate pushed to your branch between your last fetch and your force push, `--force` silently discards their commits. `--force-with-lease` checks that your remote-tracking ref matches the actual remote ref — if someone else pushed, the lease fails and you must fetch first. Always use `--force-with-lease` on shared branches.

---

## Gotchas

- **Rebasing shared branches breaks everyone who has pulled them.** Their local branch still points to the old commit hashes. When they try to push or pull, Git sees diverged histories. The golden rule: never rebase a branch that others have based work on.

- **`--force` is more dangerous than `--force-with-lease`.** `git push --force` overwrites whatever is on the remote, even if a teammate pushed since your last fetch. Always use `--force-with-lease`.

- **Conflicts during rebase must be resolved once per commit, not once total.** If ten commits each touch the same file, you might resolve the same conflict ten times. Squash related commits before rebasing onto a branch with many diverged changes.

- **`git rebase -i` with `drop` doesn't delete the content permanently.** The original commits are still in reflog for 30 days. If you drop the wrong commit, `git reflog` can retrieve it.

- **Empty commits after rebase cause `git rebase --continue` to fail.** If a commit's changes were already applied by an earlier commit in the target branch, the replay produces an empty commit. Git stops and asks what to do — `git rebase --skip` moves past it. Use `--empty=drop` to skip empty commits automatically.

- **`--rebase-merges` is not the same as `--preserve-merges`.** The old `--preserve-merges` flag was deprecated because it had correctness issues. `--rebase-merges` (Git 2.22+) is the correct replacement when you need to keep merge commits during a rebase. If you're using `--preserve-merges` in scripts, update them.

---

## Interview Angle

**What they're really testing:** Whether you understand why rebase rewrites history and can articulate the merge vs rebase tradeoff clearly.

**Common question forms:**
- "What's the difference between merge and rebase?"
- "When would you use interactive rebase?"
- "Why is force-pushing dangerous?"

**The depth signal:** A junior says "rebase makes history cleaner." A senior explains that rebase replays commits with new parent pointers, producing new SHA-1 hashes for every replayed commit — the content may be identical but the commits are different objects. They know `--force-with-lease` vs `--force` and why the distinction matters on team branches. They can describe `--onto` for moving commits between arbitrary bases, `--autosquash` with `git commit --fixup`, and `--update-refs` for stacked branch workflows.

**Follow-up questions to expect:**
- "What happens to the original commits after a rebase?"
- "How would you rebase a feature branch that's five levels deep in a stack?"

---

## Related Topics

- [git-merging.md](git-merging.md) — The alternative integration strategy; knowing both lets you choose deliberately.
- [git-internals.md](git-internals.md) — Why rebase changes hashes: each commit object includes its parent hash as input to SHA-1.
- [git-commits.md](git-commits.md) — Interactive rebase is the primary tool for rewriting local commit history.
- [git-branches.md](git-branches.md) — Rebase moves a branch's commits to a new base; the branch ref updates to the last replayed commit.
- [git-merge-conflicts.md](git-merge-conflicts.md) — Conflict resolution during rebase follows the same patterns as merge conflicts.

---

## Source

[Git Book — Git Branching — Rebasing](https://git-scm.com/book/en/v2/Git-Branching-Rebasing)

---
*Last updated: 2026-04-23*