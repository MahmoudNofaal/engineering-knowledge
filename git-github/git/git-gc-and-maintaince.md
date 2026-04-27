# Git GC and Maintenance

> Git's garbage collection and maintenance commands manage the object store — packing loose objects, pruning unreachable ones, and optimising repo performance over time.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Background repo health management: packing, pruning, and performance optimisation |
| **Use when** | Repo is slow, disk usage is high, or as part of server-side maintenance |
| **Avoid when** | You suspect you need to recover recently deleted work — GC makes recovery impossible |
| **Git version** | `git gc` since Git 1.0; `git maintenance` added Git 2.29 |
| **Key location** | `.git/objects/` (pack files), `.git/packed-refs` (packed refs) |
| **Key commands** | `git gc`, `git gc --prune=now`, `git maintenance start`, `git count-objects -vH` |

---

## When To Use It

Git runs `git gc --auto` automatically when certain thresholds are hit (default: 6700 loose objects). On developer machines, you rarely need to run it manually. On servers (bare repos receiving many pushes), schedule `git maintenance` to run nightly. Run `git gc` manually when: a repo is unusually slow, disk usage seems high, or after a `git filter-repo` history rewrite.

---

## Core Concept

Git stores objects in two formats: **loose objects** (individual files in `.git/objects/`) created by normal operations, and **pack files** (`.git/objects/pack/*.pack`) that bundle many objects with delta compression. `git gc` packs loose objects into pack files, runs delta compression between similar objects, prunes unreachable objects (respecting the reflog expiry window), and consolidates `packed-refs`. The result: smaller disk usage and faster object lookup.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | `git gc` for manual maintenance |
| Git 1.6 | `gc.auto` threshold for automatic triggering |
| Git 2.7 | `gc.writeCommitGraph` to auto-write commit graph |
| Git 2.22 | Commit graph file for faster log traversal |
| Git 2.27 | Multi-pack index (MIDX) for repos with many pack files |
| Git 2.29 | `git maintenance` — scheduled background maintenance |
| Git 2.41 | Geometric repacking strategy |

---

## The Code

**Checking repo health and size**
```bash
# Count objects and show size
git count-objects -vH
# count: 847          ← loose objects
# size: 12.45 MiB     ← loose object size
# in-pack: 24891      ← packed objects
# packs: 3            ← number of pack files
# size-pack: 48.72 MiB ← pack file size
# prune-packable: 0   ← loose objects already in packs (can be pruned)
# garbage: 0          ← unreachable objects

# Verify object store integrity
git fsck --full

# Find the largest objects in history
git verify-pack -v .git/objects/pack/*.idx \
  | sort -k3 -n \
  | tail -20 \
  | while read oid type size rest; do
      echo "$size $(git rev-list --objects --all | grep $oid | head -1)"
    done
```

**Running GC**
```bash
# Standard GC (auto-determines what to do)
git gc

# Aggressive GC — more compression, takes longer
git gc --aggressive    # can take 10× longer; use rarely

# Prune all unreachable objects immediately (skips reflog window)
# WARNING: run only when you're sure you don't need to recover anything
git gc --prune=now

# Prune objects older than a custom date
git gc --prune="7 days ago"

# GC without pruning (pack only)
git gc --no-prune
```

**git maintenance — scheduled background maintenance (Git 2.29+)**
```bash
# Enable background maintenance (runs as OS-level scheduled task)
git maintenance start
# Schedules:
# - hourly: commit-graph update, loose-objects pack
# - daily: prefetch remote objects
# - weekly: pack-refs consolidation

# Run a specific maintenance task manually
git maintenance run --task=gc
git maintenance run --task=commit-graph
git maintenance run --task=incremental-repack
git maintenance run --task=loose-objects
git maintenance run --task=pack-refs

# Stop background maintenance
git maintenance stop

# Check maintenance status
git maintenance list
```

**Commit graph — speed up log traversal**
```bash
# Write the commit graph file (speeds up git log, git merge-base, etc.)
git commit-graph write --reachable

# Verify the commit graph
git commit-graph verify

# Configure to auto-update on GC
git config core.commitGraph true
git config gc.writeCommitGraph true

# Check if commit graph exists
ls .git/objects/info/commit-graph
```

---

## Real World Example

A bare repo on a CI server had accumulated 2.3GB of loose objects over 6 months of continuous pushing. `git push` was taking 45 seconds due to object lookup inefficiency. Scheduled maintenance reduced push time to under 3 seconds.

```bash
# Before: 2.3GB loose objects, 3-second status/push
git count-objects -vH
# count: 847,293    loose objects: 2.3GB

# Run aggressive GC
git gc --aggressive --prune=now

# After: 180MB in pack files
git count-objects -vH
# count: 0
# size-pack: 180.4 MiB

# Enable scheduled maintenance going forward
git maintenance start

# Push time: 45s → 2.8s
```

---

## Gotchas

- **`git gc --prune=now` makes unreachable objects unrecoverable.** If you recently did a `git reset --hard` or deleted a branch and might want to recover, do NOT run with `--prune=now`. Use the default (respects reflog expiry window).
- **`git gc --aggressive` is rarely the right answer.** It re-compresses everything with higher effort but provides diminishing returns after the first run. The default GC is sufficient for almost all cases.
- **Large pack files slow down specific operations.** `git verify-pack` on a 10GB pack can take minutes. The geometric repacking strategy (Git 2.41+) maintains multiple appropriately-sized packs.

---

## Related Topics

- [git-internals.md](git-internals.md) — Object store, pack files, and the content-addressed model.
- [git-reflog.md](git-reflog.md) — GC respects reflog expiry — reflog entries keep objects alive.
- [git-large-files.md](git-large-files.md) — Accidentally committed large binaries cause GC to still carry them; use filter-repo to remove.

---

## Source

[Git Documentation — git-gc](https://git-scm.com/docs/git-gc)

---
*Last updated: 2026-04-24*