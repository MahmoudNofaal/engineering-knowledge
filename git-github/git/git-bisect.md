# Git Bisect

> `git bisect` performs a binary search through commit history to find the exact commit that introduced a bug or regression.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Binary search across commit history — finds the first bad commit in O(log₂ N) steps |
| **Use when** | Something worked at commit A, is broken at commit B, and there are too many commits to check manually |
| **Avoid when** | The regression is clearly recent (1–2 commits) or is environmental, not code-related |
| **Git version** | Core since Git 1.0; `--first-parent` added Git 2.29; `bisect start <bad> <good>` shorthand since Git 2.7 |
| **Key location** | In-progress state in `.git/BISECT_*` files |
| **Key commands** | `git bisect start`, `git bisect bad`, `git bisect good`, `git bisect run <script>`, `git bisect reset` |

---

## When To Use It

Use bisect when you know something works at commit A and is broken at commit B, and there are too many commits between them to check manually. It's most useful after a large merge or after coming back to a repo after a long time and finding something broken. It's less useful when the bug is clearly new (1–2 commits ago) or when the failure is environmental rather than code-related. The payoff grows with the number of commits to search — bisect finds the culprit in `log₂(N)` steps.

---

## Core Concept

Binary search on commits: Git picks the midpoint between known-good and known-bad, you test it and tell Git the result, Git halves the remaining range, repeat. With 1000 commits between good and bad, you find the culprit in at most 10 steps. The workflow can be fully manual (you run the test, you tell Git good/bad) or fully automated (you give Git a script and it runs the whole search unattended). Automated bisect is the more powerful form — you write a script that exits 0 for good and non-zero for bad, hand it to `git bisect run`, and walk away.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | `git bisect` available as a core command |
| Git 1.7.14 | `git bisect run` automated bisect |
| Git 2.7 | Shorthand: `git bisect start <bad> <good>` in one command |
| Git 2.16 | `git bisect log` and `git bisect replay` improved |
| Git 2.29 | `--first-parent` flag — bisects only the mainline, ignores merge branch commits |
| Git 2.34 | Better output formatting for automated bisect results |

*`--first-parent` (Git 2.29) is valuable on repos that use merge commits for PRs. Without it, bisect may land on individual commits inside a merged PR, which are rarely individually deployable or testable. With `--first-parent`, bisect only considers the main branch commits — one step per merged PR — making it far more practical on merge-heavy repos.*

---

## Performance

| Commits to search | Steps needed (log₂ N) | Time (at 1 min/test) |
|---|---|---|
| 10 commits | 4 steps | ~4 minutes |
| 100 commits | 7 steps | ~7 minutes |
| 1,000 commits | 10 steps | ~10 minutes |
| 10,000 commits | 14 steps | ~14 minutes |
| 100,000 commits | 17 steps | ~17 minutes |

**The test script dominates:** Git's bisect overhead (checkout, plumbing) takes under a second per step. The total time is almost entirely determined by how long your test takes to run. A 5-second test on 10,000 commits completes in under 2 minutes. A 10-minute integration test on the same range takes 2.5 hours.

**Allocation behaviour:** Bisect state is stored in `.git/BISECT_HEAD`, `.git/BISECT_LOG`, `.git/BISECT_TERMS` and `.git/refs/bisect/` — plain text files, negligible size. The checkout operations during bisect create no new objects.

---

## The Code

**Manual bisect — step by step**
```bash
git bisect start
git bisect bad                      # current HEAD is broken
git bisect good v2.1.0              # this tag was known good

# Git shows: Bisecting: 142 revisions left to test after this
# Git checks out the midpoint commit

# Test the current state, then tell Git:
git bisect good                     # this commit is fine, bug is later
git bisect bad                      # this commit has the bug, search earlier

# Repeat until Git reports:
# "e4f5a6b is the first bad commit"
# (shows commit details and which files changed)

# Always end the session — returns to original HEAD
git bisect reset
```

**One-line start (Git 2.7+)**
```bash
# Equivalent to start + bad + good in one command
git bisect start HEAD v2.1.0
# HEAD = bad, v2.1.0 = good

# or with explicit hashes
git bisect start a1b2c3d f4e5d6c
```

**Automated bisect — the powerful form**
```bash
git bisect start
git bisect bad HEAD
git bisect good v2.1.0

# Write a test script — exit 0 = good, exit non-zero = bad, exit 125 = skip
cat > /tmp/test-regression.sh << 'EOF'
#!/bin/bash
set -e

# Build first — if build fails, skip this commit (exit 125)
dotnet build --nologo -q 2>/dev/null || exit 125

# Run the specific failing test
dotnet test \
  --filter "CheckoutTotalTest" \
  --nologo -q \
  --configuration Release
# Test exit code: 0 = pass (good commit), non-zero = fail (bad commit)
EOF
chmod +x /tmp/test-regression.sh

# Hand it off — Git runs the entire search unattended
git bisect run /tmp/test-regression.sh

# Git outputs the first bad commit and returns to HEAD
git bisect reset
```

**Skipping a commit — when you can't test it**
```bash
# Current bisect commit has a broken build, missing dependency, or is otherwise untestable
git bisect skip                     # skip current commit, try a nearby one

# Skip a specific commit
git bisect skip e4f5a6b

# Skip a range of commits (e.g. known-broken period in history)
git bisect skip abc123..def456

# Note: skipping too many commits reduces precision
# Git will report "first bad commit is one of:" with multiple candidates
```

**Bisect on a merge-heavy repo — first-parent mode**
```bash
# Without --first-parent, bisect lands inside individual PR commits
# which are hard to test in isolation

git bisect start --first-parent
git bisect bad HEAD
git bisect good v3.0.0

# Now bisect only considers mainline (merge) commits
# Each step corresponds to one merged PR — much more testable
git bisect run /tmp/test-regression.sh
```

**Saving and replaying a bisect session**
```bash
# Save progress in case you need to restart
git bisect log > bisect-session.log

# Inspect the log
cat bisect-session.log
# git bisect start
# # bad: [a1b2c3d] feat: add payment processor
# git bisect bad a1b2c3d
# # good: [f4e5d6c] release: v2.1.0
# git bisect good f4e5d6c
# # good: [9g8h7i6] feat: add cart validation
# git bisect good 9g8h7i6

# Replay from saved log (after a crash or fresh terminal)
git bisect replay bisect-session.log
```

**Using bisect for non-bug searches**
```bash
# Bisect works for any binary question: "does X exist/work here?"

# Find first commit where a test was added
git bisect start
git bisect new HEAD             # "new" = has the test
git bisect old v1.0.0           # "old" = doesn't have the test
git bisect run grep -q "CheckoutTotalTest" tests/CartTests.cs

# Find when a performance regression was introduced
cat > /tmp/perf-test.sh << 'EOF'
#!/bin/bash
dotnet build --nologo -q 2>/dev/null || exit 125
TIME=$(dotnet run --project src/PerfBenchmark -- 2>&1 | grep "ms" | awk '{print $1}')
[ "$TIME" -lt 500 ]   # exit 0 (good) if under 500ms, exit 1 (bad) if over
EOF
git bisect run /tmp/perf-test.sh
```

---

## Real World Example

A platform team's search functionality started returning irrelevant results after a 3-week sprint with 94 commits from 8 engineers. No single commit was obviously the culprit and the test suite didn't cover search ranking directly. They used automated bisect with a targeted integration test to find the regression in 7 steps.

```bash
# Known good: tag from 3 weeks ago
# Known bad: current HEAD
# 94 commits between them → 7 steps needed (log₂(94) ≈ 6.6)

# Step 1: write the test script
# The test calls the search API and checks that "iPhone 15" ranks above "iPhone 3"
cat > /tmp/test-search-ranking.sh << 'EOF'
#!/bin/bash

# Build — skip if broken
dotnet build --nologo -q 2>/dev/null || exit 125

# Start the app (background)
dotnet run --project src/Api -- --urls "http://localhost:5555" &
APP_PID=$!
sleep 3   # wait for startup

# Test search ranking via API
RESULT=$(curl -s "http://localhost:5555/api/search?q=iPhone" | \
  python3 -c "
import json, sys
results = json.load(sys.stdin)['items']
names = [r['name'] for r in results[:5]]
# iPhone 15 should appear before iPhone 3
i15 = next((i for i, n in enumerate(names) if '15' in n), 999)
i3  = next((i for i, n in enumerate(names) if n.endswith('3')), 999)
sys.exit(0 if i15 < i3 else 1)
")

kill $APP_PID 2>/dev/null
exit $?
EOF
chmod +x /tmp/test-search-ranking.sh

# Step 2: run automated bisect
git bisect start
git bisect bad HEAD
git bisect good v3.4.0

git bisect run /tmp/test-search-ranking.sh
# Bisecting: 46 revisions left to test after this (roughly 6 steps)
# ... (7 iterations) ...
# d7a9c31 is the first bad commit
# Author: Jordan <jordan@company.com>
# Date:   Mon Apr 14 11:23:14 2026
#
#     perf(search): cache search index in Redis with 1h TTL

git bisect reset

# Step 3: inspect the bad commit
git show d7a9c31
# The Redis caching was using the wrong cache key — it cached by query text
# but ignored the user's locale, so non-English users got English rankings
# The fix was a 2-line change: add locale to the cache key
```

*The key insight: 94 commits × manual testing would have taken the better part of a day. Automated bisect with a 6-second API test found the commit in 7 × 10 seconds = 70 seconds of actual test time plus setup. The hard part was writing the test script — bisect itself was trivial.*

---

## Common Misconceptions

**"Bisect only works for finding bugs"**
Bisect works for any binary question you can answer with an exit code. "When was this test added?" "When did this endpoint start returning 200 instead of 201?" "When did build time exceed 2 minutes?" "When did this function stop existing?" If you can write a script that exits 0 for the state you want and non-zero for the state you don't, bisect finds the first commit that crossed that threshold.

**"Exit code 125 means the build failed"**
Exit code 125 is a special Git bisect signal meaning "skip this commit." It does not mean "build failed." If your script exits 125 when the build fails, Git skips that commit and tries nearby ones. If you accidentally exit 125 on a legitimately bad commit, you'll get an incorrect result. Use `set -e` in your script and reserve 125 explicitly for "can't test this commit" — not for "something went wrong."

**"git bisect reset undoes the commits bisect tested"**
Bisect only checks out different commits during the search — it never creates commits. `git bisect reset` simply checks out the branch you were on before starting bisect. No commits are created, modified, or deleted during a bisect session.

---

## Gotchas

- **Exit code 125 means "skip this commit" in automated bisect — not a build error.** If your test script exits 125 for a broken build, Git skips that commit and tries nearby ones. If you accidentally exit 125 on a legitimately bad commit, you'll get a wrong result. Reserve 125 explicitly for "can't test this commit."

- **Don't forget `git bisect reset`.** If you close the terminal mid-session, you're left on a detached HEAD at whatever commit bisect checked out last. `git bisect reset` always returns you to the original branch. Your `git status` showing "HEAD detached" after a crash is a sign bisect wasn't reset.

- **Flaky tests produce wrong bisect results.** If your test passes 80% of the time, bisect will mark commits incorrectly and converge on the wrong commit. Run the test multiple times in your script before marking good/bad, or add a retry loop.

- **Bisect finds the first bad commit — not the root cause.** The culprit commit often says "where," not "why." The commit that introduced a race condition might look innocent. Bisect gets you to the right place; the investigation still requires human judgment.

- **Bisecting on merge-heavy repos without `--first-parent` lands inside PR branches.** Individual commits inside a merged PR are often not independently testable (they may reference changes from earlier commits in the same PR). Use `--first-parent` to bisect only mainline commits.

- **Automated bisect with a slow test times out or leaves orphan processes.** If your test script starts a server, always kill it before exiting — even on test failure. Use `trap "kill $APP_PID 2>/dev/null" EXIT` in your script to ensure cleanup.

---

## Interview Angle

**What they're really testing:** Whether you have practical debugging depth — whether you can diagnose a regression systematically rather than guessing and checking.

**Common question forms:**
- "How do you find what commit introduced a bug?"
- "Walk me through how you'd debug a regression that appeared sometime in the last two weeks."
- "What's `git bisect` and how does it work?"

**The depth signal:** A junior knows that bisect does a binary search and can describe the manual good/bad workflow. A senior knows to write an automated bisect script with correct exit codes (0/1/125), understands the log₂(N) efficiency and why it matters for large commit ranges, knows `--first-parent` for merge-heavy repos, and understands the failure modes — flaky tests producing wrong results, commits with broken builds needing `skip`, and that the culprit commit is the start of the investigation, not the end of it.

**Follow-up questions to expect:**
- "What does exit code 125 mean in a bisect script?"
- "What's the risk of using bisect with a flaky test?"

---

## Related Topics

- [git-reflog.md](git-reflog.md) — Complementary investigation tool: bisect finds where the bug was introduced in history, reflog finds where you were before you broke something locally.
- [git-commits.md](git-commits.md) — Small, atomic commits make bisect dramatically more effective; a squashed 500-line commit is much harder to diagnose than 5 focused commits.
- [git-workflows.md](git-workflows.md) — Trunk-based development with small commits is ideal for bisect; long-lived feature branches produce large, hard-to-bisect merge commits.
- [git-hooks.md](git-hooks.md) — Pre-push hooks that run tests prevent the kind of bad commits that bisect is used to hunt down.

---

## Source

[Git Documentation — git-bisect](https://git-scm.com/docs/git-bisect)

---
*Last updated: 2026-04-24*