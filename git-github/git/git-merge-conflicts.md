# Merge Conflicts

> A merge conflict occurs when Git cannot automatically reconcile differences between two branches because both modified the same part of the same file.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A pause in merge/rebase where Git needs human judgment to resolve overlapping changes |
| **Use when** | N/A — conflicts are encountered, not chosen |
| **Avoid when** | Keep branches short-lived and rebase frequently to minimise conflict surface |
| **Git version** | Core since Git 1.0; `zdiff3` conflict style added Git 2.35 |
| **Key location** | Conflict markers written inline into affected files |
| **Key commands** | `git status`, `git diff --diff-filter=U`, `git mergetool`, `git add`, `git merge --abort`, `git rebase --abort` |

---

## When To Use It

Merge conflicts aren't a tool you choose — they're a situation you encounter and need to resolve correctly. Understanding them matters any time you rebase, merge, or cherry-pick across branches that have diverged. The goal isn't to avoid them entirely (that's impossible on active teams) but to resolve them confidently and minimize how often they become destructive. Teams that fear conflicts tend to make them worse by avoiding rebasing and letting branches drift further apart.

---

## Core Concept

Git does a three-way merge: it looks at the common ancestor of both branches, what changed on your side, and what changed on theirs. When both sides changed the same lines differently, Git can't decide which is correct — that's a conflict. The conflict markers in the file show you both versions; your job is to produce the single correct version that incorporates both intents, not just pick one side arbitrarily. The most dangerous kind of conflict is a semantic conflict — where Git merges cleanly but the result is logically wrong because two changes interact in ways Git can't detect.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | Three-way merge with `<<<<<<<`, `=======`, `>>>>>>>` markers |
| Git 1.6.1 | `merge.conflictstyle diff3` added — shows the common ancestor in conflict markers |
| Git 2.17 | Improved rename detection reducing false conflicts on moved files |
| Git 2.33 | `ort` merge strategy became default — significantly fewer spurious conflicts |
| Git 2.35 | `zdiff3` conflict style added — cleaner ancestor display, reduces marker noise |
| Git 2.41 | Improved conflict marker context for function-level conflicts |

*`zdiff3` (Git 2.35+) is the modern conflict style. Set it globally with `git config --global merge.conflictStyle zdiff3`. It shows the ancestor content more cleanly than `diff3`, making it much easier to understand what both sides intended to change.*

---

## Performance

| Scenario | Conflict frequency | Mitigation |
|---|---|---|
| Daily rebase onto main | Low — small diffs, fresh base | Best practice — conflicts are tiny |
| Weekly merge of long branch | Medium — accumulated divergence | Rebase more frequently |
| Merging two month-old branches | High — maximum drift | Each conflict is a full negotiation |
| Semantic conflicts | Undetectable by Git | Only tests catch these |

**Resolution time:** Syntactic conflicts (marker-based) take seconds to minutes per file. Semantic conflicts (clean merge, broken logic) can take hours to discover and fix because they require understanding what both sides intended, not just what they changed.

**Benchmark notes:** The `ort` strategy (Git 2.33+) resolves many conflicts that `recursive` would have produced — particularly around file renames and moves. Upgrading Git version alone can eliminate a class of conflicts on repos with heavy rename history.

---

## The Code

**What a conflict looks like in a file**
```bash
# Standard conflict markers (default style)
<<<<<<< HEAD  (your branch)
public decimal CalculateTotal(Order order) => order.Subtotal * 1.14m;
=======
public decimal CalculateTotal(Order order) => order.Subtotal + order.ShippingCost;
>>>>>>> feature/shipping-refactor

# diff3 style — shows the common ancestor (set with merge.conflictStyle diff3)
<<<<<<< HEAD
public decimal CalculateTotal(Order order) => order.Subtotal * 1.14m;
||||||| common ancestor
public decimal CalculateTotal(Order order) => order.Subtotal;
=======
public decimal CalculateTotal(Order order) => order.Subtotal + order.ShippingCost;
>>>>>>> feature/shipping-refactor
# Now you can see: HEAD added tax (×1.14), theirs added shipping cost
# Correct resolution: order.Subtotal * 1.14m + order.ShippingCost

# zdiff3 style (Git 2.35+ — cleaner, recommended)
git config --global merge.conflictStyle zdiff3
```

**Resolving a conflict during merge**
```bash
git merge feature/shipping-refactor   # conflict surfaces here

# Step 1: see which files conflict
git status
# both modified: src/Orders/OrderCalculator.cs
# both modified: src/Orders/OrderService.cs

git diff --diff-filter=U              # show only conflicted (unmerged) files

# Step 2: resolve each file
# Edit manually, removing all <<<, ===, >>> markers
# OR use a merge tool:
git mergetool                         # opens configured tool

# Configure VS Code as merge tool (one-time setup)
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'
# VS Code shows: Current | Incoming | Result — edit the Result pane

# Step 3: stage resolved files
git add src/Orders/OrderCalculator.cs
git add src/Orders/OrderService.cs

# Step 4: complete the merge
git commit                            # Git pre-fills the merge commit message

# Abort if it's getting too complex — start fresh
git merge --abort
```

**Resolving conflicts during rebase**
```bash
git rebase origin/main               # conflict surfaces at a specific commit

# Git shows which commit caused the conflict:
# CONFLICT (content): Merge conflict in src/Orders/OrderCalculator.cs
# error: could not apply a1b2c3d... Add tax calculation

# Resolve the file
# git add src/Orders/OrderCalculator.cs

git rebase --continue                 # move to the next commit
# Repeat for each conflicting commit in the rebase

git rebase --skip                     # skip this commit entirely (rare)
git rebase --abort                    # go back to pre-rebase state
```

**Accepting one side entirely**
```bash
# Take the incoming version for a specific file (dangerous — review first)
git checkout --theirs src/Config/AppSettings.json
git add src/Config/AppSettings.json

# Take your version
git checkout --ours src/Config/AppSettings.json
git add src/Config/AppSettings.json

# Modern syntax (Git 2.23+)
git restore --source=MERGE_HEAD -- src/Config/AppSettings.json  # theirs
git restore --source=HEAD -- src/Config/AppSettings.json        # ours

# Use only when the change is completely independent
# Never use as a shortcut when both changes need to be preserved
```

**Using rerere — reuse recorded resolutions**
```bash
# Enable rerere (reuse recorded resolution)
git config --global rerere.enabled true

# When you resolve a conflict, Git records the resolution
# Next time Git sees the same conflict (on rebase, or if you reset + retry)
# it applies the recorded resolution automatically

# See what rerere has recorded
git rerere status              # files with recorded resolutions
git rerere diff                # show the recorded resolution

# Clear rerere cache if a resolution was wrong
git rerere forget src/Orders/OrderCalculator.cs
```

**CI guard — detect unresolved conflict markers**
```bash
# Add to CI or pre-commit hook to catch conflict markers that slipped through
grep -rn "^<<<<<<< \|^=======$\|^>>>>>>> " --include="*.cs" --include="*.ts" .
if [ $? -eq 0 ]; then
  echo "ERROR: Conflict markers found in source files"
  exit 1
fi

# Or as a pre-commit hook (faster — only checks staged files)
git diff --cached --name-only | xargs grep -l "^<<<<<<< " 2>/dev/null
```

---

## Real World Example

Two teams were working in parallel on an e-commerce platform — the backend team refactoring `OrderService` for performance, and the payments team adding support for multi-currency orders. Both touched `OrderCalculator.cs` and `OrderService.cs`. The merge looked clean on the surface but had a semantic conflict that only surfaced in production.

```bash
# The merge appeared clean — no conflict markers
git merge feature/multi-currency
# Auto-merging src/Orders/OrderCalculator.cs
# Merge made by the 'ort' strategy.

# But production started showing wrong totals for EUR orders
# The root cause: both teams changed CalculateTotal in incompatible ways
# Backend team: changed method to take pre-computed subtotal (decimal)
# Payments team: added currencyCode parameter but called the OLD signature

# What Git merged (no markers, but logically broken):
public decimal CalculateTotal(decimal subtotal, string currencyCode)
{
    // Backend's new logic — expects pre-computed subtotal
    return subtotal * GetTaxRate(currencyCode);
    // Payments team's call site still passes Order object to the old signature
    // C# overload resolution silently chose the wrong overload
}

# Detection: integration tests with non-USD currencies would have caught it
# Lesson: the merge was syntactically clean, semantically broken

# Recovery:
git revert -m 1 <merge-commit>           # immediate rollback
# Full test suite with EUR/GBP/JPY test cases added
# Branches resynchronised, conflict resolved by team discussion
# Re-merged with explicit test coverage for multi-currency + new signature

# Prevention going forward:
# 1. Interface contract tests — any change to IOrderCalculator fails tests
# 2. Architecture review required for public API changes
# 3. Shorter branch lifetime — this drift took 3 weeks to accumulate
```

*The key insight: Git's conflict detection is purely syntactic — it looks at lines of text. Two changes that compile, pass unit tests, and merge cleanly can still be semantically incompatible. The only defence against semantic conflicts is integration tests that exercise the interaction between the two changed subsystems.*

---

## Common Misconceptions

**"A clean merge means no problems"**
A clean merge means Git resolved all *syntactic* conflicts automatically. It says nothing about whether the merged code is *correct*. Semantic conflicts — where two changes interact logically but not textually — can produce a clean merge with broken behavior. This is why "merge passed CI" is not the same as "merge is correct." Integration tests and domain knowledge are required.

**"Conflicts are caused by bad teamwork"**
Conflicts are caused by two people working on the same codebase, which is normal and healthy. The frequency and severity of conflicts can be reduced by short-lived branches, frequent rebasing, and clear module ownership — but a zero-conflict team is usually a team where only one person commits. Some conflicts are just the cost of parallelism.

**"Choosing --ours or --theirs resolves the conflict correctly"**
`--ours` and `--theirs` resolve the syntactic conflict by picking one version — they don't assess which version is correct. Silently dropping one side's changes is the fastest way to introduce a semantic bug after a conflict. Only use these flags when you've verified that the two changes are completely independent (e.g., two teams each adding a new method to a class — no interaction).

---

## Gotchas

- **Semantic conflicts don't show up as markers.** Two branches can both rename a function — one at the call site, one at the definition — and Git merges cleanly to broken code. Run tests after every merge/rebase — not optional.

- **Rebasing replays commits, so conflicts surface once per commit.** If you're rebasing 10 commits onto main and each touches the same area, you may resolve the same conflict 10 times. Squash your branch first with `git rebase -i` to reduce it to one conflict resolution.

- **Choosing `--ours` or `--theirs` on a file that needed both changes is silent data loss.** Git won't warn you. The file will look resolved, tests may still pass, and you've quietly dropped a teammate's work.

- **Conflict markers left in committed code means your CI doesn't check for them.** Add a `grep` step for `<<<<<<<` to your CI pipeline — it's a one-liner and catches the most embarrassing possible production incident.

- **`git rerere` silently applies old resolutions.** If enabled and the context changed (same conflicting lines, different surrounding code), rerere may apply a resolution that was correct before but is wrong now. Always verify rerere-resolved files before committing.

- **After resolving, `git status` shows the file as modified, not unmerged — don't forget `git add`.** A common mistake: resolve the conflict, see the markers are gone, and go to `git commit` without staging. Git will complain that the merge isn't complete because the file is still listed as unmerged in the index.

---

## Interview Angle

**What they're really testing:** Whether you understand how Git's merge algorithm actually works and whether you can be trusted to resolve conflicts without silently losing code.

**Common question forms:**
- "How do you handle merge conflicts?"
- "What's the difference between a merge conflict and a semantic conflict?"
- "How do conflicts work differently in `git merge` vs `git rebase`?"

**The depth signal:** A junior describes opening the file, picking a side, and removing the markers. A senior explains the three-way merge algorithm and why Git can't resolve semantic conflicts, the difference in conflict experience between `merge` and `rebase` (rebase surfaces conflicts per-commit, merge surfaces them once at the end), why running the full test suite after conflict resolution is the only reliable way to detect semantic conflicts, and tools like `merge.conflictStyle zdiff3` and `rerere` that make the resolution workflow faster.

**Follow-up questions to expect:**
- "How do you prevent the same conflict from appearing repeatedly during a rebase?"
- "What is a semantic conflict and how do you detect one?"

---

## Related Topics

- [git-merging.md](git-merging.md) — The merge operation that produces conflicts when both branches change the same lines.
- [git-rebasing.md](git-rebasing.md) — Rebase surfaces conflicts per-commit rather than all at once; understanding both contexts matters.
- [git-workflows.md](git-workflows.md) — Workflow choice directly determines conflict frequency: trunk-based with daily merges vs. Gitflow with long-lived branches.
- [git-branching-strategy.md](git-branching-strategy.md) — Branch lifetime is the primary variable controlling conflict severity.
- [git-hooks.md](git-hooks.md) — Pre-commit hooks that check for leftover conflict markers prevent the worst-case scenario.

---

## Source

[Git Documentation — Basic Merge Conflicts](https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging#_basic_merge_conflicts)

---
*Last updated: 2026-04-24*