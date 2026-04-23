# Merge Conflicts

> A merge conflict occurs when Git cannot automatically reconcile differences between two branches because both modified the same part of the same file.

---

## When To Use It

Merge conflicts aren't a tool you choose — they're a situation you encounter and need to resolve correctly. Understanding them matters any time you rebase, merge, or cherry-pick across branches that have diverged. The goal isn't to avoid them entirely (that's impossible on active teams) but to resolve them confidently and minimize how often they become destructive. Teams that fear conflicts tend to make them worse by avoiding rebasing and letting branches drift further apart.

---

## Core Concept

Git does a three-way merge: it looks at the common ancestor of both branches, what changed on your side, and what changed on theirs. When both sides changed the same lines differently, Git can't decide which is correct — that's a conflict. The conflict markers in the file show you both versions; your job is to produce the single correct version that incorporates both intents, not just pick one side arbitrarily. The most dangerous kind of conflict is a semantic conflict — where Git merges cleanly but the result is logically wrong because two changes interact in ways Git can't detect.

---

## The Code
```bash
# ── What a conflict looks like in a file ────────────────────────────

<<<<<<< HEAD (your branch)
public decimal CalculateTotal(Order order) => order.Subtotal * 1.14m;
=======
public decimal CalculateTotal(Order order) => order.Subtotal + order.ShippingCost;
>>>>>>> origin/main (incoming branch)

# HEAD = your current branch's version
# The block after ======= = what's coming in from the other branch
# You must edit this to one correct result and remove all three marker lines
```
```bash
# ── Resolving a conflict during rebase ──────────────────────────────

git fetch origin
git rebase origin/main        # conflict surfaces here

# Git pauses — edit the file, resolve the markers
# Then:
git add src/Orders/OrderService.cs
git rebase --continue         # moves to next commit in the rebase

# To abort and go back to where you started:
git rebase --abort
```
```bash
# ── Resolving a conflict during merge ───────────────────────────────

git merge origin/main         # conflict surfaces here

git status                    # shows all conflicted files
# Edit each file, remove conflict markers
git add .
git commit                    # Git pre-fills a merge commit message
```
```bash
# ── Using a merge tool ───────────────────────────────────────────────

git mergetool                 # opens configured diff tool

# Configure VS Code as merge tool:
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'

# Common visual tools: VS Code, IntelliJ, vimdiff, Beyond Compare
# VS Code shows: current | incoming | result — edit result pane directly
```
```bash
# ── Accepting one side entirely (when you know which is right) ───────

# Take the incoming version for a specific file
git checkout --theirs src/Config/AppSettings.json
git add src/Config/AppSettings.json

# Take your version
git checkout --ours src/Config/AppSettings.json
git add src/Config/AppSettings.json

# Use with caution — only when the change is completely independent
# Do not use this as a shortcut when both changes need to be preserved
```

---

## Gotchas

- **Choosing `--ours` or `--theirs` on a file that needed both changes is silent data loss.** Git won't warn you. The file will look resolved, tests may still pass, and you've quietly dropped a teammate's work.
- **Semantic conflicts don't show up as markers.** Two branches can both rename a function — one at the call site, one at the definition — and Git merges cleanly to broken code. This is why running tests after every merge/rebase is not optional.
- **Rebasing rewrites commits, so conflicts can surface once per commit.** If you're rebasing 10 commits onto main and each one touches the same area, you may resolve the same conflict 10 times. Squash your branch first with `git rebase -i` to reduce it to one conflict resolution.
- **Conflict markers left in code that passes CI means your tests don't cover that file.** Add a CI step that greps for `<<<<<<<` — it's a one-liner and catches the most embarrassing possible production incident.
- **`git rerere` (reuse recorded resolution) can auto-resolve repeated conflicts but silently applies wrong resolutions if the context changed.** It's useful on long-running rebase-heavy workflows but must be audited — don't enable it and forget it.

---

## Interview Angle

**What they're really testing:** Whether you understand how Git's merge algorithm actually works and whether you can be trusted to resolve conflicts without silently losing code.

**Common question form:** "How do you handle merge conflicts?" or "What's the difference between a merge and a rebase when conflicts are involved?"

**The depth signal:** A junior describes opening the file, picking a side, and removing the markers. A senior explains the three-way merge algorithm and why Git can't resolve semantic conflicts, the difference in conflict experience between `merge` and `rebase` (rebase surfaces conflicts per-commit, merge surfaces them once at the end), and why running the full test suite after conflict resolution is the only reliable way to detect semantic conflicts that passed the syntactic merge check.

---

## Related Topics

- [[git/git-workflows.md]] — Workflow choice directly determines conflict frequency: trunk-based with daily merges produces small, frequent conflicts; Gitflow with long-lived branches produces large, infrequent, painful ones.
- [[git/git-branching-strategy.md]] — Branch lifetime is the primary variable controlling conflict severity — longer branches mean more divergence.
- [[git/git-pull-requests.md]] — PR size and age determine how many conflicts reviewers inherit; keeping branches short reduces conflict surface area.
- [[git/merge-vs-rebase.md]] — The choice between merge and rebase changes how conflicts surface during integration — one conflict at the end vs. one per commit.

---

## Source

[Git Documentation — Basic Merge Conflicts](https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging#_basic_merge_conflicts)

---
*Last updated: 2026-03-24*