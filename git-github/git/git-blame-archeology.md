# Git Blame & Code Archaeology

> `git blame` annotates every line of a file with the commit and author that last changed it — combined with `git log -S`, `git log --follow`, and `git show`, it lets you trace why any piece of code exists.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A set of tools for tracing the origin and evolution of any line of code |
| **Use when** | Understanding why code exists, finding when a bug was introduced, identifying context authors |
| **Avoid when** | Using blame to assign personal blame — it shows the last editor, not the responsible party |
| **Git version** | `git blame` since Git 1.0; `-C` copy detection since Git 1.6; `--ignore-rev` since Git 2.23 |
| **Key location** | Reads from `.git/objects` — no files created |
| **Key commands** | `git blame`, `git log -S`, `git log --follow -p`, `git log -L`, `git show` |

---

## When To Use It

Use code archaeology when you encounter code you don't understand and need to know: who wrote it, when, why (commit message context), and whether it has a corresponding issue or PR. This is the most common unguided debugging activity — "I need to change this line but I don't know why it's this way." `git blame` is the starting point, but the real answers usually come from following the commit hash to the PR that introduced it.

---

## Core Concept

`git blame` shows the last commit that touched each line — but "last" is deceptive. A reformatting commit or an indentation change becomes the "blame" for a line even if the logic was written two years earlier. The `-w` flag ignores whitespace changes, `-C` detects lines moved from other files, and `--ignore-rev` skips known-noisy commits (like bulk reformatting). The deeper archaeology tools — `git log -S` (pickaxe), `git log -L` (line history), and `git log --follow` (rename tracking) — let you trace a line's full history, not just its most recent editor.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | `git blame` available |
| Git 1.6.0 | `-C` flag: detect lines copied from other files |
| Git 1.7.0 | `-L` flag for line range blame |
| Git 2.0 | `-C -C` (double `-C`): detect copies from other commits |
| Git 2.23 | `--ignore-rev` and `--ignore-revs-file` — skip reformatting commits |
| Git 2.29 | `git log -L :funcname:file` — trace a function's history |
| Git 2.32 | Porcelain output improvements for tool integration |

*`--ignore-rev` (Git 2.23) is the solution to "the whole file blames the reformatting commit." Maintain a `.git-blame-ignore-revs` file in your repo listing reformatting commits (bulk `dotnet format` runs, Prettier, Black, etc.) and set `git config blame.ignoreRevsFile .git-blame-ignore-revs`. Every `git blame` in the repo then skips those commits automatically.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `git blame <file>` | O(file size × history depth) | Must walk back through commits to assign each line |
| `git blame -L 10,20 <file>` | O(line range × history depth) | Faster — only blames the specified lines |
| `git log -S "pattern"` | O(all commits × avg diff size) | Reads every diff — slow on repos with long histories |
| `git log -L :func:file` | O(function history depth) | Traces one function — fast for shallow histories |
| `git log --follow -p <file>` | O(file history × diff size) | Reads full diff of every commit touching the file |

**Benchmark notes:** `git blame` on a heavily modified 2,000-line file with 10 years of history can take 5–15 seconds without the commit graph. Enable the commit graph (`git commit-graph write --reachable`) to speed up blame significantly. `git log -S "searchterm"` on a 500,000-commit repo can take 2–5 minutes — use `--after`, `--before`, or `-- path` filters to narrow the search.

---

## The Code

**Basic blame**
```bash
# Annotate every line with commit + author
git blame src/Auth/TokenService.cs

# Output format:
# abc1234 (Ali Hassan    2026-02-14 11:23:45 +0300  42) public string Generate(User user)
# def5678 (Sara Nour     2026-01-08 09:14:02 +0300  43) {
# abc1234 (Ali Hassan    2026-02-14 11:23:45 +0300  44)     var token = _jwtService.Create(user.Id);
# Column: hash | author | date | line number | content

# Blame a specific line range (much faster on large files)
git blame -L 40,60 src/Auth/TokenService.cs

# Ignore whitespace changes — skip reformatting commits
git blame -w src/Auth/TokenService.cs

# Detect lines moved from other files (one level of copy detection)
git blame -C src/Auth/TokenService.cs

# Maximum copy detection (across all commits, expensive)
git blame -C -C -C src/Auth/TokenService.cs

# Show the email address instead of name
git blame --show-email src/Auth/TokenService.cs
```

**Ignore reformatting commits**
```bash
# Create a file listing commits to ignore in blame
cat > .git-blame-ignore-revs << 'EOF'
# Bulk reformatting — dotnet format run 2026-01-15
a3f9d12c8b4e1a7d5c2b9e6f3a0c7d4b1e8f5a2

# Prettier run 2025-11-20
b7e2c5a8d1f4b7e2c5a8d1f4b7e2c5a8d1f4b7e2

# Black reformatting 2025-09-01
c1d4e7f0a3b6c9d2e5f8a1b4c7d0e3f6a9b2c5d8
EOF

# Configure blame to always use this file
git config blame.ignoreRevsFile .git-blame-ignore-revs

# Commit the ignore-revs file so everyone benefits
git add .git-blame-ignore-revs
git commit -m "chore: add blame ignore revs for reformatting commits"

# Now git blame skips those commits — shows the real author
git blame src/Auth/TokenService.cs
```

**Pickaxe search — when was a string added or removed**
```bash
# Find commits that added or removed the exact string
git log -S "CalculateInterest" --oneline
# a3f9d12 feat(finance): add compound interest calculation
# b7e2c5a refactor(finance): rename to CalculateInterest

# Show the full diff of the matching commits
git log -S "CalculateInterest" -p

# Regex search (slower but more powerful)
git log -G "Calculate.*Interest" --oneline

# Narrow by file path (dramatically faster)
git log -S "CalculateInterest" -- src/Finance/ --oneline

# Narrow by date range
git log -S "CalculateInterest" --after="2026-01-01" --before="2026-04-01"

# Find who deleted a function
git log -S "void ProcessPayment" --diff-filter=D --oneline
```

**Line history — trace a specific line or function over time**
```bash
# Trace a line range across its full history
git log -L 42,60:src/Auth/TokenService.cs
# Shows every commit that touched lines 42-60 with full diff context

# Trace a function by name (Git knows about function boundaries)
git log -L :GenerateToken:src/Auth/TokenService.cs
# Shows every commit that touched the GenerateToken function

# Works with multiple languages — Git uses language-aware heuristics
git log -L :calculateInterest:src/Finance/Calculator.js
git log -L :CalculateInterest:src/Finance/Calculator.cs
```

**Follow renamed files**
```bash
# Track a file through renames
git log --follow -p src/Auth/TokenService.cs
# Shows full history including commits when the file was at a different path
# (e.g., when it was src/Services/TokenService.cs)

# See all renames in a commit
git show abc1234 --name-status
# R100  src/Services/TokenService.cs  src/Auth/TokenService.cs
# (R = renamed, 100 = 100% similarity)

# Find the original name of a file
git log --follow --diff-filter=R --summary -- src/Auth/TokenService.cs | grep "rename"
```

**Connect blame to PRs**
```bash
# Standard archaeology workflow:
# 1. Find the suspicious line
git blame -L 142,142 src/Orders/OrderCalculator.cs
# a7f3d91 (Jordan  2026-03-15 14:22:11  142)  return subtotal * 1.0;   ← suspicious

# 2. Get full context of that commit
git show a7f3d91

# 3. Find the PR associated with that commit (GitHub)
gh pr list --search "sha:a7f3d91"
# Or search GitHub web UI: https://github.com/org/repo/commit/a7f3d91

# 4. Read the PR discussion for context about why the change was made
# This is where you find the real reason — the commit message says what,
# the PR discussion says WHY

# One-liner: blame line, get commit, open PR
COMMIT=$(git blame -L 142,142 src/Orders/OrderCalculator.cs | awk '{print $1}')
gh pr list --search "sha:$COMMIT" --json number,title,url
```

**Advanced: annotate with original commit (not last editor)**
```bash
# git log -L shows the full history, not just the last editor
# For files where blame shows a reformatter, use log -L instead:
git log -L 142,142:src/Orders/OrderCalculator.cs
# Shows every commit that changed this specific line — full history
# First commit in the output is when the line was originally written
```

---

## Real World Example

A production bug was found in the interest calculation engine — certain account types were getting 0% interest. The bug had been in production for 11 days before a customer noticed. The team needed to find when it was introduced, who introduced it, and why the change was made.

```bash
# Step 1: find the suspicious line
# Bug: line 247 returns 0.0 instead of calculating the rate
git blame -w -L 245,250 src/Finance/InterestCalculator.cs
# fe9a2c1 (Jamie  2026-04-13 16:42:03  245) var rate = GetBaseRate(accountType);
# fe9a2c1 (Jamie  2026-04-13 16:42:03  246) if (accountType == AccountType.Premium)
# fe9a2c1 (Jamie  2026-04-13 16:42:03  247)     rate = 0.0;    ← THE BUG
# fe9a2c1 (Jamie  2026-04-13 16:42:03  248) return ApplyCompounding(principal, rate, months);

# Step 2: understand the full commit
git show fe9a2c1
# Author: Jamie Chen <jamie@company.com>
# Date:   Sun Apr 13 16:42:03 2026 +0300
#
# perf(finance): cache interest rates to reduce DB calls
#
# Uses in-memory cache for rate lookups. Falls back to DB on cache miss.
# Fixes: #892 (rate lookup causing N+1 queries on batch processing)

# Step 3: understand WHY it was 0.0 (not the commit message — the PR)
gh pr list --search "sha:fe9a2c1"
# #341 perf(finance): cache interest rates

gh pr view 341 --comments
# Jamie (2026-04-13): "Used 0.0 as the cache-miss sentinel value.
#  If GetBaseRate returns null, we default to 0.0 to avoid exceptions."
# Review comment: "Shouldn't we return the DB value on cache miss, not 0.0?"
# Jamie: "Good point, but GetBaseRate already handles the fallback..."
# ← The misunderstanding: Jamie thought GetBaseRate handled the fallback.
#   It didn't. Cache miss → rate = 0.0 → 0% interest.

# Step 4: see full evolution of this function
git log -L :CalculateInterest:src/Finance/InterestCalculator.cs --oneline
# fe9a2c1 perf(finance): cache interest rates to reduce DB calls  ← introduced bug
# d3c8b7a feat(finance): add Premium account tier handling
# a2b1c0d feat(finance): add compound interest calculation
# f9e8d7c feat(finance): initial interest calculator

# Step 5: fix and verify
git revert fe9a2c1 --no-edit
# Verify the fix
git log -L :CalculateInterest:src/Finance/InterestCalculator.cs -1
```

*The key insight: `git blame` found who and when in 10 seconds. The PR discussion found the why in 2 minutes. Without the PR link, the team would have needed to guess at the intent of "cache-miss sentinel value" — with it, the exact misunderstanding was documented. This is why commit messages should reference PR/issue numbers, and why PR discussions should be preserved.*

---

## Common Misconceptions

**"git blame shows who wrote the code"**
`git blame` shows who *last modified* each line. A line could have been written by engineer A, refactored by engineer B (reformatting), and then `git blame` shows engineer B as the "author." Use `-w` to ignore whitespace, `-C` to detect moves, and `--ignore-revs-file` to skip known reformatting commits. Even then, blame is a starting point — the real author context comes from following the commit to its PR.

**"git blame assigns responsibility"**
Using blame to figure out "who to blame" for a bug is counterproductive and usually inaccurate — the engineer shown in blame may have done nothing wrong, and the actual error in judgment may have been made in a PR review or design decision by someone not shown in blame at all. `git blame` is an *archaeology* tool, not a *blame* tool despite its name. Use it to understand context, not to assign fault.

**"`git log -S` searches commit messages"**
`-S` (pickaxe) searches the *diff content* — it finds commits where the count of occurrences of the string changed (i.e., a line containing that string was added or removed). To search commit messages, use `--grep`. To search diff content with a regex, use `-G`. These answer three completely different questions and return completely different results for the same search term.

---

## Gotchas

- **A reformatting commit ruins blame for the whole file.** A single `dotnet format` or Prettier run makes `git blame` point to that commit for every line. Set up `--ignore-revs-file` proactively and add bulk reformatting commits to it immediately when they happen.

- **`git blame` on a moved file shows no history before the move.** Use `git log --follow -p` to track the file through renames. Without `--follow`, history stops at the most recent rename.

- **`git log -S` is slow on large repos.** It must read every commit's diff. Narrow with `--after`, `--before`, and `-- path` to keep it under 10 seconds on large codebases.

- **`-C` copy detection only checks the same commit by default.** `-C -C` checks across commits, `-C -C -C` is even more aggressive. Each level is significantly more expensive. Use `-C` for normal blame, `-C -C` only when you suspect code was copied from another file in an earlier commit.

- **Line numbers in blame output shift with file edits.** If you blame line 247 today, and someone inserts lines above it, tomorrow the same code is at line 250. Always blame a line and use the commit hash — not the line number — as the reference.

---

## Interview Angle

**What they're really testing:** Whether you know how to navigate a codebase you didn't write — and whether you understand the difference between "who touched this last" and "who is responsible for this decision."

**Common question forms:**
- "How do you understand code you didn't write?"
- "You found a bug — how do you trace when it was introduced?"
- "What tools do you use to investigate an unfamiliar codebase?"

**The depth signal:** A junior says "I use `git blame` to see who wrote it." A senior describes the full archaeology workflow: `git blame` to find the commit, `git show` to understand the change, following the commit to the PR for the design context, `git log -S` to find when a specific piece of logic was introduced, `git log -L :funcname:file` to see a function's full evolution, and `--ignore-revs-file` to skip noisy reformatting commits. They also know blame shows the last editor, not the decision-maker.

**Follow-up questions to expect:**
- "What does `git log -S` search and how is it different from `--grep`?"
- "How would you trace a file through a rename in Git history?"

---

## Related Topics

- [git-commits.md](git-commits.md) — `git show` is the most common next step after finding a blame commit hash.
- [git-log-advanced.md](git-log-advanced.md) — `git log -S`, `-G`, `--follow`, `-L` are the deeper archaeology tools that complement blame.
- [git-diff-advanced.md](git-diff-advanced.md) — `git diff` shows what changed between states; blame shows who changed what and when.
- [git-bisect.md](git-bisect.md) — When blame gives you a plausible suspect commit but you're not sure, bisect can confirm it programmatically.

---

## Source

[Git Documentation — git-blame](https://git-scm.com/docs/git-blame)

---
*Last updated: 2026-04-24*