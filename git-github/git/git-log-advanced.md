# Git Log (Advanced)

> `git log` traverses the commit graph and outputs commit history — with dozens of flags to filter, format, and visualise exactly what you need.

---

## Quick Reference

| | |
|---|---|
| **What it is** | The primary tool for navigating and querying commit history |
| **Use when** | Investigating history, finding regressions, understanding code evolution |
| **Avoid when** | You need current file state — use `git show` or `git diff` instead |
| **Git version** | Core since Git 1.0; `--format` custom formats since Git 1.7; `-G` regex since Git 1.7.4 |
| **Key commands** | `git log --oneline --graph`, `git log -S`, `git log -G`, `git log --follow`, `git log --format` |

---

## Core Concept

`git log` walks the commit graph backward from a starting point (default: HEAD), applying filters and formatting output. Every filter reduces the set of commits shown; every format option changes how they're displayed. The most powerful combination is filtering by content change (`-S`, `-G`) combined with path filtering (`-- path/`) — this answers "when was this specific code introduced or removed?"

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | `git log` as core history viewer |
| Git 1.5.3 | `--graph` added for visual branch topology |
| Git 1.7.0 | `--format="%H %s"` custom format strings |
| Git 1.7.4 | `-G <regex>` to search diff content with regex |
| Git 2.12 | `--date=human` format added |
| Git 2.33 | `--remerge-diff` for merge commit diffs |

---

## The Code

**Common filtering patterns**
```bash
# By author and date
git log --author="Ali" --since="2 weeks ago" --until="yesterday"
git log --author="ali@company.com" --oneline

# By message content
git log --grep="fix:" --oneline
git log --grep="CVE" --grep="security" --all-match  # must match BOTH

# By file/directory
git log -- src/Payments/
git log --follow -- src/old-name.py   # track renames

# By content change (pickaxe) — when was this code added/removed?
git log -S "CalculateTotal"           # commits that added or removed this string
git log -G "CalculateTotal.*"        # commits where diff matches this regex
git log -S "CalculateTotal" --patch  # show the full diff alongside

# By commit range
git log main..feature/auth --oneline  # commits on feature not in main
git log v1.0..v2.0 --oneline         # commits between two tags
git log HEAD~10..HEAD --oneline       # last 10 commits

# Combined filters — when did Ali add the CalculateTotal function?
git log -S "CalculateTotal" --author="Ali" --since="6 months ago" --oneline
```

**Graph and topology**
```bash
# Standard graph view — best for understanding branch history
git log --oneline --graph --all --decorate

# Compact graph with dates
git log --graph --format="%C(auto)%h%d %s %C(dim white)%an, %ar"

# Show only merge commits
git log --merges --oneline

# Show commits reachable from any branch
git log --all --oneline --graph
```

**Custom formatting**
```bash
# Placeholders:
# %H = full hash, %h = short hash
# %an = author name, %ae = author email, %ar = author date (relative)
# %s = subject (first line), %b = body
# %D = ref names (branch/tag), %d = with parentheses

# One-line with hash, author, date, message
git log --format="%h %an %ar %s"

# CSV output for tooling
git log --format="%H,%an,%ae,%ai,%s" --no-merges > commits.csv

# Just commit hashes (useful for scripting)
git log --format="%H" -- src/Payments/

# Show what files changed in each commit
git log --stat --oneline -10

# Show the actual diff for each commit
git log --patch -10                  # all diffs for last 10 commits
git log --patch -S "CalculateTotal"  # diff only for commits touching this string
```

**Blame and annotation**
```bash
# Who last changed each line of a file
git blame src/Payments/Calculator.cs

# Blame a specific line range
git blame -L 45,65 src/Payments/Calculator.cs

# Detect lines moved from other files (-C) or copied (-CC)
git blame -C -C src/Payments/Calculator.cs

# Blame at a specific commit
git blame abc1234 -- src/Payments/Calculator.cs

# Find the original author ignoring reformatting commits
git blame --ignore-rev abc1234 src/Payments/Calculator.cs

# List commits to ignore for blame (e.g., formatting-only commits)
echo "abc1234" >> .git-blame-ignore-revs
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

---

## Real World Example

A tech lead needed to answer: "When did we start using `double` instead of `decimal` for money calculations, and who changed it?" — a question that would have taken 30 minutes of manual log reading, resolved in 5 seconds:

```bash
git log -S "double" -- src/Finance/ --author-date-order --oneline
# d7a9c31 perf(cart): replace decimal with double for performance
# (Sat Apr 14, Jordan)

git show d7a9c31 -- src/Finance/OrderCalculator.cs
# Shows exactly which lines changed from decimal to double

# Follow-up: did we ever use decimal here before?
git log -S "decimal" -- src/Finance/OrderCalculator.cs --oneline
# Yes — the original author used decimal; Jordan changed it 3 months ago
```

---

## Common Misconceptions

**"`git log` shows all commits"** — By default, `git log` only shows commits reachable from HEAD. Commits on other branches require `--all` or explicit branch names.

**"`-S` searches commit messages"** — `-S` (pickaxe) searches the diff content — lines added or removed containing that string. For commit messages, use `--grep`.

---

## Gotchas

- **`--follow` only works with a single file path.** You can't `--follow` a directory.
- **`-S` counts net occurrences.** A commit that adds and removes the same string equally won't appear. Use `-G` for regex content matching.
- **`git log -- path` must come after `--`.** Without `--`, Git may interpret the path as a branch name.

---

## Interview Angle

**Common question forms:** "How would you find which commit introduced a bug?" / "How do you search commit history for a specific code change?"

**The depth signal:** A junior uses `git log` for history browsing. A senior uses `-S` for content search, `--follow` for renamed files, `--format` for scripting, and `blame -C` for detecting moved code.

---

## Related Topics

- [git-bisect.md](git-bisect.md) — Binary search when you know the bug exists but not where.
- [git-commits.md](git-commits.md) — `git log -S` and `git show` are the tools for commit archaeology.
- [git-blame-and-archaeology.md](git-blame-and-archaeology.md) — Deeper dive on blame, move detection, and code history.

---

## Source

[Git Documentation — git-log](https://git-scm.com/docs/git-log)

---
*Last updated: 2026-04-24*