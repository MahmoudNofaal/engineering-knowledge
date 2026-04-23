# Git Bisect

> `git bisect` performs a binary search through commit history to find the exact commit that introduced a bug or regression.

---

## When To Use It

Use bisect when you know something works at commit A and is broken at commit B, and there are too many commits between them to check manually. It's most useful after a large merge or after coming back to a repo after a long time and finding something broken. It's less useful when the bug is clearly new (1–2 commits ago) or when the failure is environmental rather than code-related. The payoff grows with the number of commits to search — bisect finds the culprit in `log₂(N)` steps.

---

## Core Concept

Binary search on commits: Git picks the midpoint between known-good and known-bad, you test it and tell Git the result, Git halves the remaining range, repeat. With 1000 commits between good and bad, you find the culprit in at most 10 steps. The workflow can be fully manual (you run the test, you tell Git good/bad) or fully automated (you give Git a script and it runs the whole search unattended). Automated bisect is the more powerful form — you write a script that exits 0 for good and non-zero for bad, hand it to `git bisect run`, and walk away.

---

## The Code
```bash
# ── Manual bisect ────────────────────────────────────────────────────
git bisect start
git bisect bad                      # current HEAD is broken
git bisect good v2.1.0              # this tag was known good
# Git checks out the midpoint commit

# Test the current state, then tell Git:
git bisect good                     # this commit is fine, bug is later
git bisect bad                      # this commit has the bug, search earlier

# Repeat until Git reports:
# "e4f5a6b is the first bad commit"

# Always end the session:
git bisect reset                    # returns to original HEAD

# ── Automated bisect (preferred for repeatable test cases) ───────────
git bisect start
git bisect bad HEAD
git bisect good v2.1.0

# Write a test script — exit 0 = good, exit 1 = bad
cat > /tmp/test-regression.sh << 'EOF'
#!/bin/bash
dotnet build --nologo -q || exit 125   # exit 125 = skip this commit
dotnet test --filter "CheckoutTotalTest" --nologo -q
EOF
chmod +x /tmp/test-regression.sh

git bisect run /tmp/test-regression.sh
# Git runs the script at each midpoint automatically
# Reports the first bad commit when done

git bisect reset

# ── Skip a commit (can't test it — broken build, missing dependency) ─
git bisect skip                     # skip current commit, try another nearby

# ── View bisect log (useful if you need to restart or audit) ─────────
git bisect log                      # shows all good/bad marks so far
git bisect log > bisect.log         # save it — can replay with git bisect replay
```

---

## Gotchas

- **Exit code 125 means "skip this commit" in automated bisect — not a build error.** If your test script exits 125 for a broken build, Git skips it and tries a nearby commit. If you accidentally exit 125 on a legitimately bad commit, you'll get a wrong result. Be deliberate about exit codes.
- **Bisect tests the commit as-is, without running migrations or setup.** If your test depends on a database schema that changed between commits, your test script must handle that — bisect won't. This makes automated bisect harder on repos with migrations.
- **Don't forget `git bisect reset`.** If you close the terminal mid-session, you're left on a detached HEAD. `git bisect reset` always returns you to the original branch.
- **Flaky tests produce wrong bisect results.** If your test passes 80% of the time, bisect will mark commits incorrectly. Run the test multiple times in your script before marking good/bad, or bisect will chase a ghost.
- **Bisect finds the first bad commit — not the root cause.** The culprit commit often says "where," not "why." The commit that introduced a race condition might look innocent — bisect gets you to the right place, but the investigation still requires human judgment.

---

## Interview Angle

**What they're really testing:** Whether you have practical debugging depth — whether you can diagnose a regression systematically rather than guessing and checking.

**Common question form:** "How do you find what commit introduced a bug?" or "Walk me through how you'd debug a regression that appeared sometime in the last two weeks."

**The depth signal:** A junior knows that bisect does a binary search and can describe the manual good/bad workflow. A senior knows to write an automated bisect script with correct exit codes (0/1/125), understands the log₂(N) efficiency and why it matters for large commit ranges, and knows the failure modes — flaky tests producing wrong results, commits with broken builds needing `skip`, and the fact that the culprit commit is the start of the investigation, not the end of it.

---

## Related Topics

- [[git/git-reflog.md]] — Complementary investigation tool: bisect finds where the bug was introduced in history, reflog finds where you were before you broke something locally.
- [[git/git-workflows.md]] — Small, atomic commits make bisect dramatically more effective; a team that squashes unrelated changes into single commits makes bisect point to a 500-line diff instead of a 10-line one.
- [[git/git-reset.md]] — After bisect identifies the bad commit, reset is often used to move a branch pointer back to before that commit during a hotfix workflow.
- [[git/git-hooks.md]] — Pre-push and CI hooks that run tests prevent the kind of bad commits that bisect is used to hunt down.

---

## Source

[Git Documentation — git-bisect](https://git-scm.com/docs/git-bisect)

---
*Last updated: 2026-03-24*