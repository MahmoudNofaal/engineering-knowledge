# Git Commits

> A commit is an immutable snapshot of the entire repository at a point in time — a content-addressed object containing a tree pointer, parent pointer(s), author metadata, and a message.

---

## When To Use It

Commit when you have a complete, logical unit of change — something that compiles, passes tests, and does one thing. Commit too rarely and you lose the ability to bisect bugs or revert specific changes. Commit too often with meaningless messages and the log becomes noise. The commit history is a communication tool for future readers — including yourself six months from now.

---

## Core Concept

When you run `git commit`, Git takes the current index (staging area), builds a tree object from it, creates a commit object that points to that tree plus the current HEAD commit as parent, then moves the branch ref forward to the new commit hash. Nothing in the working directory is touched. The commit object itself is immutable — its SHA-1 is derived from its content, so changing anything (message, author, parent, tree) produces a different hash and a different object. Amending a commit doesn't modify it — it creates a new one and moves the branch ref to point to the new one instead.

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

**Amending — fix the last commit**
```bash
# Fix the message only
git commit --amend -m "Corrected commit message"

# Add a forgotten file to the last commit
git add forgotten-file.py
git commit --amend --no-edit    # --no-edit keeps the existing message

# Change author on last commit
git commit --amend --author="Ali <ali@example.com>" --no-edit

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

# Search by content added/removed (pickaxe)
git log -S "def authenticate"      # commits that added or removed this string
git log -G "def auth.*"            # commits where diff matches this regex
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

# Common pattern: squash WIP commits before merging a feature branch
# pick a1b2c3 Add auth endpoint
# fixup d4e5f6 fix typo
# fixup g7h8i9 forgot to add test
# → becomes one clean commit
```

**Signing commits (GPG)**
```bash
# Configure signing key
git config --global user.signingkey YOUR_GPG_KEY_ID
git config --global commit.gpgsign true   # sign all commits automatically

# Sign a specific commit
git commit -S -m "Signed commit"

# Verify a commit's signature
git verify-commit abc1234
git log --show-signature
```

**Useful commit inspection**
```bash
# Who last changed each line of a file
git blame src/auth.py
git blame -L 10,20 src/auth.py   # lines 10-20 only

# Find which commit introduced a bug — binary search
git bisect start
git bisect bad                   # current commit is broken
git bisect good v1.2.0           # this tag was working
# Git checks out the midpoint — test it, then:
git bisect good                  # or git bisect bad
# Repeat until Git identifies the first bad commit
git bisect reset                 # return to original HEAD when done
```

---

## Gotchas

- **`git commit --amend` on a pushed commit requires force-push and breaks collaborators.** Amend creates a new commit object — anyone who pulled the original commit now has a diverged history. Only amend commits that exist only on your local branch.
- **Empty commit messages are rejected by default but `--allow-empty-message` bypasses the check.** Don't. A commit with no message is useless in `git log`, `git bisect`, and code review.
- **`git commit -a` stages all tracked modified files — not untracked files.** New files you forgot to `git add` are silently excluded. Check `git status` before using `-a` to confirm nothing is missing.
- **Commit hashes are not sequential or sortable by time.** SHA-1 hashes are content-derived, not timestamps. Two commits made a second apart on different machines could have any hash values. Use `--date-order` or `--author-date-order` flags with `git log` if you need chronological sorting.
- **`git log -S` (pickaxe) searches the net change in a string's count — not the diff text.** A commit that adds and removes the same string in equal counts won't appear. Use `git log -G` with a regex when you need to search the actual diff content.

---

## Interview Angle

**What they're really testing:** Whether you treat commits as a communication tool and understand their immutability.

**Common question form:** *"What makes a good commit?"* or *"How do you fix a mistake in a recent commit?"* or *"How would you find which commit introduced a bug?"*

**The depth signal:** A junior says "commit often with descriptive messages." A senior explains that a commit is an immutable SHA-1-addressed object — amending doesn't edit it, it creates a replacement. They know `git bisect` for bug hunting (binary search across commit history), `git log -S` for finding when a specific string was introduced, and can articulate when squashing is appropriate (before merging a feature branch) vs when preserving commits matters (after merging, for audit trail). They also know the force-push consequence of amending shared commits.

---

## Related Topics

- [[git/git-internals.md]] — Commits are objects in `.git/objects`; the hash is a SHA-1 of the tree, parent, author, and message.
- [[git/git-staging-area.md]] — The index is the source of truth for what goes into a commit's tree.
- [[git/git-rebasing.md]] — Interactive rebase is how you rewrite commit history before merging.
- [[git/git-branches.md]] — A branch is just a ref pointing to a commit; committing advances that ref.

---

## Source

[Git Book — Git Basics — Viewing the Commit History](https://git-scm.com/book/en/v2/Git-Basics-Viewing-the-Commit-History)

---
*Last updated: 2026-03-24*