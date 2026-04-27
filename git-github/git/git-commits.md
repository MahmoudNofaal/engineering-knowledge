# Git Commits

> A commit is an immutable snapshot of the entire repository at a point in time — a content-addressed object containing a tree pointer, parent pointer(s), author metadata, and a message.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Immutable SHA-1 object: tree + parent + author + message |
| **Use when** | You have a complete, logical, tested unit of change |
| **Avoid when** | Work is half-done, broken, or mixes unrelated concerns |
| **Git version** | Core since Git 1.0; `--fixup` added Git 1.7.4; `--trailer` added Git 2.34 |
| **Key location** | `.git/objects/<2-char>/<38-char>` |
| **Key commands** | `git commit`, `git commit --amend`, `git rebase -i`, `git log -S`, `git bisect` |

---

## When To Use It

Commit when you have a complete, logical unit of change — something that compiles, passes tests, and does one thing. Commit too rarely and you lose the ability to bisect bugs or revert specific changes. Commit too often with meaningless messages and the log becomes noise. The commit history is a communication tool for future readers — including yourself six months from now.

---

## Core Concept

When you run `git commit`, Git takes the current index (staging area), builds a tree object from it, creates a commit object that points to that tree plus the current HEAD commit as parent, then moves the branch ref forward to the new commit hash. Nothing in the working directory is touched. The commit object itself is immutable — its SHA-1 is derived from its content, so changing anything (message, author, parent, tree) produces a different hash and a different object. Amending a commit doesn't modify it — it creates a new one and moves the branch ref to point to the new one instead.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | Commit objects as the core unit of history |
| Git 1.7.4 | `--fixup` and `--squash` flags added for targeted interactive rebase prep |
| Git 1.8.3 | `--author` and `--date` flags for amend without editing the message |
| Git 2.10 | `--no-edit` became stable across platforms |
| Git 2.29 | SHA-256 object format introduced (experimental) alongside SHA-1 |
| Git 2.34 | `--trailer` flag added — append structured key:value trailers to messages |
| Git 2.41 | `--allow-empty-message` hardened with warnings in interactive workflows |

*Conventional Commits (feat:, fix:, chore:) is a community spec, not a Git feature — it emerged around 2017 and became standard in many organisations by 2019.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Create commit | O(staged files) | Hashes each staged blob; fast for small changesets |
| Amend commit | O(staged files) | Creates a new object; original stays in object store until GC |
| `git log` (linear) | O(commits traversed) | Fast for recent history; slows on very long linear chains |
| `git log -S` (pickaxe) | O(commits × diff size) | Reads every diff — slow on large repos with many commits |
| `git bisect` (automated) | O(log₂ N × test time) | The test script dominates; Git's overhead is negligible |

**Allocation behaviour:** Each commit object is a compressed zlib file in `.git/objects`. A typical commit object (metadata + tree pointer) is 200–400 bytes on disk. Large blobs live separately — the commit itself stays small regardless of how much code it touches.

**Benchmark notes:** `git log --oneline` on 100,000 commits takes under a second. `git log -S "someFunction"` on the same repo can take 10–30 seconds because it must decompress and diff every object. Use `--author`, `--since`, or `-- path/to/file` filters to narrow the search space first.

---

## The Code

**Basic commit workflow**
```bash
git add -p                      # stage intentionally
git commit -m "Add rate limiting to auth endpoint"

# Multi-line message — first line is the subject (72 char limit)
# blank line separates subject from body
git commit -m "Add rate limiting to auth endpoint

Uses Redis INCR + EXPIRE pattern. Limit is 100 requests per minute
per user ID. Returns 429 with Retry-After header on breach.

Closes #142"
```

**Conventional Commits format**
```bash
# Pattern: <type>(<scope>): <description>
# Types: feat, fix, chore, docs, style, refactor, test, ci, perf

git commit -m "feat(auth): add JWT refresh token rotation"
git commit -m "fix(cart): prevent null ref when order has no items"
git commit -m "chore(deps): upgrade to .NET 8.0.4"
git commit -m "perf(search): replace N+1 query with single JOIN"

# Breaking change — add ! after type or BREAKING CHANGE: in footer
git commit -m "feat(api)!: remove v1 endpoints

BREAKING CHANGE: /api/v1/* routes removed. Use /api/v2/* instead.
Migration guide: docs/migration-v2.md"
```

**Amending — fix the last commit**
```bash
# Fix the message only
git commit --amend -m "Corrected commit message"

# Add a forgotten file to the last commit
git add forgotten-file.py
git commit --amend --no-edit    # --no-edit keeps the existing message

# Change author on last commit
git commit --amend --author="Ali <ali@example.com>" --no-edit

# Add a trailer (Co-authored-by, Signed-off-by, Refs)
git commit --amend --trailer "Co-authored-by: Sara <sara@example.com>"

# Note: amend always produces a new commit hash
# Never amend commits that have been pushed to a shared branch
```

**Viewing commits**
```bash
# Standard log
git log --oneline

# Graph view — useful with branches
git log --oneline --graph --all

# Show what changed in a commit
git show abc1234
git show abc1234 --stat         # just filenames and line counts

# Show commits that touched a specific file
git log --follow -p src/auth.py   # --follow tracks renames

# Search commit messages
git log --grep="rate limit"
git log --grep="rate limit" --author="Ali" --since="2 weeks ago"

# Search by content added/removed (pickaxe)
git log -S "def authenticate"      # commits that added or removed this string
git log -G "def auth.*"            # commits where diff matches this regex

# Pretty format — build custom output
git log --format="%h %an %ar %s"  # hash, author, relative date, subject
git log --format="%H" -- src/     # all commit hashes touching src/
```

**Rewriting history — interactive rebase**
```bash
# Rewrite last 3 commits
git rebase -i HEAD~3

# In the editor, each commit gets a command:
# pick   = keep as-is
# reword = keep changes, edit message
# edit   = pause here to amend
# squash = merge into previous commit, combine messages
# fixup  = merge into previous commit, discard this message
# drop   = delete this commit entirely

# Common pattern: squash WIP commits before merging a PR
# pick a1b2c3 Add auth endpoint
# fixup d4e5f6 fix typo
# fixup g7h8i9 forgot to add test
# → becomes one clean commit
```

**Fixup commits — the ergonomic way to clean up as you work**
```bash
# While working, make a fixup commit targeting an earlier commit
git commit --fixup a1b2c3    # message: "fixup! original commit message"

# When ready to clean up:
git rebase -i --autosquash HEAD~5
# Git automatically orders fixups after their target and marks them 'fixup'
# No manual reordering needed
```

**Finding things in history**
```bash
# Who last changed each line of a file
git blame src/auth.py
git blame -L 10,20 src/auth.py   # lines 10–20 only
git blame -C src/auth.py         # detect lines moved from other files

# Find which commit introduced a bug — binary search
git bisect start
git bisect bad                   # current commit is broken
git bisect good v1.2.0           # this tag was working
# Git checks out the midpoint — test it, then:
git bisect good                  # or git bisect bad
# Repeat until Git identifies the first bad commit
git bisect reset                 # return to original HEAD when done

# Automated bisect — most powerful form
git bisect run dotnet test --filter "CheckoutTest" -q
```

---

## Real World Example

A payment team merged a subtle floating-point bug into main on a Friday. By Monday, the bug had been buried under 47 commits from a weekend sprint. The team had good commit hygiene — small, atomic commits with conventional messages — which made the recovery take 12 minutes instead of 12 hours.

```bash
# Step 1: bisect finds the commit in 6 steps (log₂(47) ≈ 5.6)
git bisect start
git bisect bad HEAD
git bisect good v3.12.0          # last known good release tag

# Automated with the failing test — walked away, came back with the answer
git bisect run dotnet test --filter "OrderTotal_WithTax_ReturnsCorrectAmount" \
  --configuration Release -q

# Git output:
# d4e7a91 is the first bad commit
# Author: Jamie <jamie@company.com>
# Date:   Sat Apr 19 14:32:17 2026
#
#     perf(cart): replace decimal with double for order calculations

git bisect reset

# Step 2: inspect the bad commit
git show d4e7a91

# Step 3: revert it cleanly (already pushed to main)
git revert d4e7a91 --no-edit
git push origin main

# Step 4: write the post-mortem commit
git commit --allow-empty -m "docs(postmortem): double vs decimal in order totals

Root cause: d4e7a91 changed Order.Total from decimal to double for
'performance'. IEEE 754 double loses precision at 4+ decimal places.
Payment amounts require exact decimal arithmetic.

Fix: reverted in f1a2b3c. Added type-safety lint rule.
ADR added: docs/adr/0042-no-float-for-money.md"
```

*The key insight: `git bisect run` + a focused test found the needle in a 47-commit haystack automatically. The team's atomic commit discipline — one logical change per commit — meant the bad commit contained exactly the problem and nothing else, making the revert surgical.*

---

## Common Misconceptions

**"git commit --amend edits the commit"**
Amend creates a brand new commit object with a different SHA-1. The original commit still exists in `.git/objects` — it just becomes unreachable because the branch ref now points to the new one. That's why amending a pushed commit requires a force push: the remote has the old hash, you're trying to push a new one, and Git correctly rejects the non-fast-forward.

**"The commit hash is based on the diff"**
The SHA-1 is computed from the full commit object: tree hash + parent hash(es) + author name/email/timestamp + committer name/email/timestamp + message. Two commits with identical diffs but different parents will have completely different hashes. This is why rebasing rewrites hashes even when no content changes — the parent pointer changed, which changes the hash input.

**"git log -S searches the commit messages"**
`-S` (pickaxe) searches the *diff content* — specifically, it finds commits where the number of occurrences of the string changed (a line was added or removed containing that string). To search commit messages, use `--grep`. To search the diff text with a regex, use `-G`. These three flags answer three completely different questions.

---

## Gotchas

- **`git commit --amend` on a pushed commit requires force-push and breaks collaborators.** Amend creates a new commit object — anyone who pulled the original commit now has a diverged history. Only amend commits that exist only on your local branch.

- **`git commit -a` stages all tracked modified files — not untracked files.** New files you forgot to `git add` are silently excluded. Check `git status` before using `-a` to confirm nothing is missing.

- **Commit hashes are not sequential or sortable by time.** SHA-1 hashes are content-derived, not timestamps. Two commits made a second apart on different machines could have any hash values. Use `--date-order` or `--author-date-order` flags with `git log` if you need chronological sorting.

- **`git log -S` (pickaxe) searches the net change in a string's count — not the diff text.** A commit that adds and removes the same string in equal counts won't appear. Use `git log -G` with a regex when you need to search the actual diff content.

- **Empty commit messages are rejected by default but `--allow-empty-message` bypasses the check.** A commit with no message is useless in `git log`, `git bisect`, and code review. The only legitimate use is post-mortem marker commits — document that use in the body.

- **`git bisect bad/good` terminology is confusing when the "bug" is a performance regression or missing feature.** Use `git bisect new`/`git bisect old` instead for non-bug bisects — they're semantic aliases that make the intent clearer.

---

## Interview Angle

**What they're really testing:** Whether you treat commits as a communication tool and understand their immutability.

**Common question forms:**
- "What makes a good commit?"
- "How do you fix a mistake in a recent commit?"
- "How would you find which commit introduced a bug?"

**The depth signal:** A junior says "commit often with descriptive messages." A senior explains that a commit is an immutable SHA-1-addressed object — amending doesn't edit it, it creates a replacement. They know `git bisect` for bug hunting (binary search across commit history), `git log -S` for finding when a specific string was introduced, and can articulate when squashing is appropriate (before merging a feature branch) vs when preserving commits matters (after merging, for audit trail). They also know the force-push consequence of amending shared commits.

**Follow-up questions to expect:**
- "What's in a commit object — what does Git actually store?"
- "Why does rebasing change commit hashes even if the content is the same?"

---

## Related Topics

- [git-internals.md](git-internals.md) — Commits are objects in `.git/objects`; the hash is a SHA-1 of the tree, parent, author, and message.
- [git-staging-area.md](git-staging-area.md) — The index is the source of truth for what goes into a commit's tree.
- [git-rebasing.md](git-rebasing.md) — Interactive rebase is how you rewrite commit history before merging.
- [git-branches.md](git-branches.md) — A branch is just a ref pointing to a commit; committing advances that ref.
- [git-bisect.md](git-bisect.md) — Binary search through commit history to find regressions.

---

## Source

[Git Book — Git Basics — Viewing the Commit History](https://git-scm.com/book/en/v2/Git-Basics-Viewing-the-Commit-History)

---
*Last updated: 2026-04-23*