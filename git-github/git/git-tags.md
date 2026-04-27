# Git Tags

> A tag is a named, permanent reference to a specific commit — used to mark release points in history that should be findable and stable forever.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A fixed ref pointing to a commit — unlike branches, tags never move |
| **Use when** | Marking releases, hotfix points, or any commit that needs a stable human-readable name |
| **Avoid when** | You need a movable pointer — that's a branch |
| **Git version** | Core since Git 1.0; `--follow-tags` push option since Git 1.8.3 |
| **Key location** | `.git/refs/tags/` (lightweight) or `.git/objects/` (annotated — a full object) |
| **Key commands** | `git tag -a`, `git push --follow-tags`, `git describe`, `git tag -v`, `git tag -d` |

---

## When To Use It

Use tags to mark release versions (v1.2.0, v2.0.0-rc1) and any other commit that needs a stable, human-readable name that won't move. Unlike branches, tags don't advance when you commit — they're fixed pointers. Use annotated tags for releases (they carry metadata and can be signed). Use lightweight tags for temporary local markers you don't intend to push.

---

## Core Concept

There are two tag types. A lightweight tag is just a ref file in `.git/refs/tags/` containing a commit hash — identical in structure to a branch, but it never moves. An annotated tag is a full Git object stored in `.git/objects` — it contains the tagger name, email, date, message, and an optional GPG signature, plus a pointer to the tagged commit. Annotated tags show up in `git describe`, can be signed and verified, and are what you should use for public releases. Lightweight tags are for personal local use.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | Tags (both lightweight and annotated) as core features |
| Git 1.8.3 | `--follow-tags` push option — push annotated tags alongside commits automatically |
| Git 2.1 | `git tag -l` pattern matching improved |
| Git 2.12 | Improved sorting: `--sort=version:refname` for proper semver tag ordering |
| Git 2.19 | `--format` option for `git tag -l` for custom output |
| Git 2.32 | SSH signing for tags (in addition to GPG) |

*`git tag -l --sort=version:refname` (Git 2.12+) sorts tags by semantic version correctly — v1.9.0 before v1.10.0. Without this, lexicographic sort puts v1.10.0 before v1.9.0, which surprises everyone who encounters it for the first time.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Create lightweight tag | O(1) | Writes a 41-byte ref file |
| Create annotated tag | O(1) + object write | Creates a tag object in `.git/objects` (~200 bytes) |
| `git push --follow-tags` | O(tags to send) | Only pushes annotated tags missing from remote |
| `git describe` | O(reachable tags) | Walks back from HEAD to find the nearest annotated tag |
| `git tag -l "v1.*"` | O(N tags) | Reads all ref files matching the pattern |

**Allocation behaviour:** Lightweight tags cost 41 bytes (a ref file). Annotated tags cost ~200–500 bytes for the tag object in `.git/objects` plus the ref file. Neither affects clone size meaningfully until you have thousands of tags — at which point `git pack-refs --all` consolidates them into a single `packed-refs` file for faster ref lookup.

**Benchmark notes:** `git describe` walks backward through commit history looking for reachable annotated tags. On a repo with a long linear history and sparse tags, this can traverse thousands of commits. Keep your tag density reasonable (one per release) and ensure annotated tags are used — lightweight tags are invisible to `git describe` by default.

---

## The Code

**Creating tags**
```bash
# Lightweight tag — just a pointer, no metadata
git tag v1.2.0

# Annotated tag — full object with metadata (use this for releases)
git tag -a v1.2.0 -m "Release version 1.2.0"

# Tag a specific past commit
git tag -a v1.1.5 -m "Hotfix release" abc1234

# Signed tag — requires GPG key or SSH key configured
git tag -s v1.2.0 -m "Signed release v1.2.0"      # GPG
git tag -s v1.2.0 -m "Signed release v1.2.0" --sign  # SSH (Git 2.32+)
```

**Listing and inspecting tags**
```bash
# List all tags
git tag

# List with pattern matching
git tag -l "v1.*"
git tag -l "v2.0.*"

# List in semantic version order (Git 2.12+)
git tag -l --sort=version:refname
git tag -l "v*" --sort=-version:refname   # descending (newest first)

# Show tag details (annotated) and the commit it points to
git show v1.2.0

# Just the commit hash a tag points to
git rev-list -n 1 v1.2.0

# Verify a signed tag
git tag -v v1.2.0
```

**Pushing tags to remote**
```bash
# Tags are NOT pushed with git push by default
git push origin main       # tags are NOT included

# Push a specific tag
git push origin v1.2.0

# Push all local tags
git push origin --tags     # pushes ALL tags including lightweight

# Push only annotated tags alongside commits (recommended)
git push origin --follow-tags

# Configure --follow-tags as default (add to ~/.gitconfig)
git config --global push.followTags true

# Delete a remote tag
git push origin --delete v1.2.0
git push origin :refs/tags/v1.2.0   # alternative syntax
```

**Checking out tags**
```bash
# Checking out a tag puts you in detached HEAD
git checkout v1.2.0
# HEAD is now at abc1234... Release version 1.2.0

# Always create a branch before committing in detached HEAD
git switch -c hotfix/v1.2.1 v1.2.0

# See which tag describes the current commit
git describe
# v1.2.0-3-gabc1234
# Format: (nearest tag)-(commits since tag)-(g + short hash)
# If HEAD is exactly at a tag: just "v1.2.0"

git describe --tags           # include lightweight tags
git describe --exact-match    # only if HEAD is exactly a tag (exit 1 otherwise)
git describe --abbrev=0       # just the tag name, no commit distance
```

**Semantic versioning workflow**
```bash
# Standard release
git tag -a v2.0.0 -m "Major release: new API, breaking changes in auth"

# Pre-release
git tag -a v2.0.0-rc1 -m "Release candidate 1 — feature complete"
git tag -a v2.0.0-beta.1 -m "Beta 1 — ready for wider testing"
git tag -a v2.0.0-alpha.1 -m "Alpha 1 — internal testing only"

# Patch release from a release branch
git switch release/v1.x
git cherry-pick <hotfix-commit>
git tag -a v1.2.1 -m "Patch: fix null pointer in auth (CVE-2026-0142)"
git push origin release/v1.x --follow-tags

# Deleting and replacing a tag (coordinate with team first)
git tag -d v1.2.0                          # delete locally
git push origin --delete v1.2.0            # delete from remote
git tag -a v1.2.0 -m "Corrected message"  # recreate
git push origin v1.2.0                     # push new
```

**Automating versioning with tags in CI**
```bash
# GitHub Actions: get version from tag on push
# .github/workflows/release.yml
on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0   # needed for git describe

      - name: Get version from tag
        id: version
        run: echo "version=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT
        # GITHUB_REF = "refs/tags/v1.2.0" → version = "v1.2.0"

      - name: Build with version
        run: dotnet publish -p:Version=${{ steps.version.outputs.version }}
```

---

## Real World Example

A platform team managing an internal NuGet package library needed to enforce strict semantic versioning across 40+ engineers. Lightweight tags were being pushed inconsistently, breaking the automated release pipeline's ability to determine the correct next version using `git describe`.

```bash
# Problem: engineers were using lightweight tags, breaking git describe
git tag -l --sort=version:refname
# v1.0.0    ← annotated (from old workflow)
# v1.1.0    ← lightweight (new engineer, wrong type)
# v1.2.0    ← annotated
# v1.2.1    ← lightweight

git describe HEAD
# v1.2.0-14-gabc1234  ← v1.2.1 is invisible (lightweight)!

# Fix 1: enforce annotated tags via a pre-push hook
cat > .githooks/pre-push << 'EOF'
#!/bin/bash
# Read stdin: <local_ref> <local_sha> <remote_ref> <remote_sha>
while read local_ref local_sha remote_ref remote_sha; do
  # Check if this is a tag push
  if [[ "$remote_ref" == refs/tags/* ]]; then
    tag_name="${remote_ref#refs/tags/}"
    tag_type=$(git cat-file -t "refs/tags/$tag_name" 2>/dev/null)

    if [ "$tag_type" != "tag" ]; then
      echo "ERROR: '$tag_name' is a lightweight tag."
      echo "Use 'git tag -a $tag_name -m \"message\"' for release tags."
      exit 1
    fi
  fi
done
exit 0
EOF
chmod +x .githooks/pre-push
git config core.hooksPath .githooks

# Fix 2: migrate existing lightweight tags to annotated
for tag in v1.1.0 v1.2.1; do
  commit=$(git rev-list -n 1 $tag)
  date=$(git log -1 --format="%ai" $tag)
  git tag -d $tag
  GIT_COMMITTER_DATE="$date" git tag -a $tag -m "Release $tag" $commit
  git push origin --delete $tag
  git push origin $tag
done

# Verify: git describe now sees all releases correctly
git describe HEAD
# v1.2.1-3-gabc1234  ← correct
```

*The key insight: annotated vs lightweight tags is not just a metadata question — it controls visibility to `git describe`, which drives automated versioning in most CI/CD pipelines. Enforcing annotated tags via a pre-push hook catches the mistake before it breaks the pipeline.*

---

## Common Misconceptions

**"Tags and branches are the same thing"**
Both are ref files containing a commit hash — that's where the similarity ends. A branch moves forward with every commit on it. A tag never moves — it permanently points to the exact commit it was created on. Checking out a tag puts you in detached HEAD because there's no branch to advance. Deleting a branch has no effect on the commits; neither does deleting a tag.

**"All tags appear in `git describe`"**
`git describe` only searches for *annotated* tags by default. Lightweight tags are invisible. This is the most common source of "git describe isn't finding my tag" confusion. Add `--tags` flag to include lightweight tags: `git describe --tags`. For release workflows, always use annotated tags so `git describe` works without flags.

**"Tags are automatically pushed with `git push`"**
Tags are never pushed automatically — not with `git push`, not with `git push origin main`, not with `git push --all`. You must explicitly push tags: `git push origin v1.2.0` (specific), `git push --follow-tags` (annotated only), or `git push --tags` (all). Configure `push.followTags = true` in `.gitconfig` to push annotated tags automatically alongside commits.

---

## Gotchas

- **Tags are not pushed automatically with `git push`.** Every new developer on the team is surprised by this at least once. Set `git config --global push.followTags true` to push annotated tags automatically, or add it to your release checklist.

- **Annotated and lightweight tags behave differently in `git describe` and `git log --tags`.** `git describe` only finds annotated tags by default — lightweight tags are invisible unless you add `--tags`. Use annotated tags for releases if you rely on `git describe` for versioning in CI.

- **Moving a tag that was already pushed requires force-push and breaks everyone.** If you tag the wrong commit and then re-tag, you must `git push --force origin v1.2.0` to overwrite the remote. Anyone who fetched the original tag now has a different commit. Tags should be immutable once pushed.

- **Checking out a tag produces detached HEAD.** Any commits you make in this state are unreachable the moment you checkout something else. Always create a branch from a tag before doing any work: `git switch -c <branch-name> <tag>`.

- **`git fetch` fetches tags that point to commits you fetch, but not all remote tags.** `git fetch --tags` explicitly fetches all remote tags. Add this to CI pipelines that need to resolve version numbers from tags, or they may miss newly pushed tags.

- **Lexicographic tag sorting breaks semantic version order.** `v1.10.0` sorts before `v1.9.0` alphabetically. Always use `git tag -l --sort=version:refname` for semantic version ordering.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between annotated and lightweight tags and know that tags don't auto-push.

**Common question forms:**
- "How do you mark a release in Git?"
- "What's the difference between a tag and a branch?"
- "How does `git describe` work?"

**The depth signal:** A junior says "use `git tag v1.0` to tag a release." A senior distinguishes annotated (full object with metadata, tagger, date, GPG-signable, visible to `git describe`) from lightweight (just a ref file, no metadata, invisible to `git describe` by default). They know tags don't push automatically, that `--follow-tags` pushes annotated tags alongside commits, and that moving a pushed tag requires force-push with coordination costs. They know `git describe` output format (`v1.2.0-3-gabc1234`) and how it's used for automated versioning in CI.

**Follow-up questions to expect:**
- "Why would `git describe` not find a tag you just created?"
- "How would you enforce annotated tags across a team?"

---

## Related Topics

- [git-internals.md](git-internals.md) — Annotated tags are stored as objects in `.git/objects`; lightweight tags are ref files identical in structure to branches.
- [git-branches.md](git-branches.md) — Tags and branches are both refs — the difference is tags are fixed, branches advance with commits.
- [git-commits.md](git-commits.md) — Tags point to commits; `git show <tag>` reveals the commit and, for annotated tags, the tag object metadata.
- [git-workflows.md](git-workflows.md) — Release tagging conventions (semver, CalVer) are part of team Git workflow decisions.
- [github-releases.md](../github/github-releases.md) — GitHub Releases build on top of Git tags, adding release notes and downloadable assets.

---

## Source

[Git Book — Git Basics — Tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging)

---
*Last updated: 2026-04-24*