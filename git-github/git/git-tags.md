# Git Tags

> A tag is a named, permanent reference to a specific commit — used to mark release points in history that should be findable and stable forever.

---

## When To Use It

Use tags to mark release versions (v1.2.0, v2.0.0-rc1) and any other commit that needs a stable, human-readable name that won't move. Unlike branches, tags don't advance when you commit — they're fixed pointers. Use annotated tags for releases (they carry metadata and can be signed). Use lightweight tags for temporary local markers you don't intend to push.

---

## Core Concept

There are two tag types. A lightweight tag is just a ref file in `.git/refs/tags/` containing a commit hash — identical in structure to a branch, but it never moves. An annotated tag is a full Git object stored in `.git/objects` — it contains the tagger name, email, date, message, and an optional GPG signature, plus a pointer to the tagged commit. Annotated tags show up in `git describe`, can be signed and verified, and are what you should use for public releases. Lightweight tags are for personal local use.

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

# Signed tag — requires GPG key configured
git tag -s v1.2.0 -m "Signed release v1.2.0"
```

**Listing and inspecting tags**
```bash
# List all tags
git tag

# List with pattern matching
git tag -l "v1.*"
git tag -l "v2.0.*"

# Show tag details (annotated) and the commit it points to
git show v1.2.0

# For lightweight tags, git show just shows the commit
git show v1.2.0-lw

# Verify a signed tag
git tag -v v1.2.0
```

**Pushing tags to remote**
```bash
# Tags are NOT pushed with git push by default
git push origin main   # tags are not included

# Push a specific tag
git push origin v1.2.0

# Push all tags
git push origin --tags

# Push only annotated tags (not lightweight)
git push origin --follow-tags

# Delete a remote tag
git push origin --delete v1.2.0
git push origin :refs/tags/v1.2.0   # alternative syntax
```

**Checking out tags**
```bash
# Checking out a tag puts you in detached HEAD
git checkout v1.2.0
# HEAD is now at abc1234... Release version 1.2.0

# To work from a tagged commit, create a branch
git switch -c hotfix/v1.2.1 v1.2.0

# See which tag describes the current commit
git describe
# v1.2.0-3-gabc1234
# (nearest tag)-(commits since tag)-(g + short hash)

git describe --tags       # include lightweight tags
git describe --exact-match  # only if HEAD is exactly a tag (no trailing info)
```

**Deleting tags**
```bash
# Delete local tag
git tag -d v1.2.0

# Delete remote tag
git push origin --delete v1.2.0

# Rename a tag (delete + recreate)
git tag v1.2.0-fixed v1.2.0   # create new tag pointing to same commit
git tag -d v1.2.0              # delete old local tag
git push origin v1.2.0-fixed   # push new
git push origin --delete v1.2.0  # delete old remote
```

**Semantic versioning with tags**
```bash
# Standard release
git tag -a v2.0.0 -m "Major release: new API, breaking changes"

# Pre-release
git tag -a v2.0.0-rc1 -m "Release candidate 1"
git tag -a v2.0.0-beta.1 -m "Beta 1"
git tag -a v2.0.0-alpha.1 -m "Alpha 1"

# Patch release from a branch
git switch release/v1.x
git cherry-pick <hotfix-commit>
git tag -a v1.2.1 -m "Patch: fix null pointer in auth"
git push origin release/v1.x --follow-tags
```

---

## Gotchas

- **Tags are not pushed automatically with `git push`.** Every new developer on the team is surprised by this at least once. Set up CI to push tags explicitly after tagging, or use `git push --follow-tags` as your default push command for release workflows.
- **Annotated and lightweight tags behave differently in `git describe` and `git log --tags`.** `git describe` only finds annotated tags by default — lightweight tags are invisible unless you add `--tags`. Use annotated tags for releases if you rely on `git describe` for versioning in CI.
- **Moving a tag that was already pushed requires force-push and breaks everyone.** If you tag the wrong commit and then re-tag, you must `git push --force origin v1.2.0` to overwrite the remote. Anyone who fetched the original tag now has a different commit than what the remote says. Tags should be immutable once pushed.
- **Checking out a tag produces detached HEAD.** Any commits you make in this state are unreachable the moment you check out something else. Always create a branch from a tag before doing any work: `git switch -c <branch-name> <tag>`.
- **`git fetch` fetches new branches but not new tags unless configured.** By default `git fetch` pulls tags that point to commits it fetches, but won't pull tags on commits you don't have. `git fetch --tags` explicitly fetches all remote tags. Add this to CI pipelines that need to resolve version numbers from tags.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between annotated and lightweight tags and know that tags don't auto-push.

**Common question form:** *"How do you mark a release in Git?"* or *"What's the difference between a tag and a branch?"*

**The depth signal:** A junior says "use `git tag v1.0` to tag a release." A senior distinguishes annotated (full object with metadata, tagger, date, GPG-signable, visible to `git describe`) from lightweight (just a ref file, no metadata, invisible to `git describe` by default). They know tags don't push automatically, that `--follow-tags` pushes annotated tags alongside commits, and that moving a pushed tag requires force-push with coordination costs. They also know `git describe` output format (`v1.2.0-3-gabc1234`) and how it's used for automated versioning in CI pipelines.

---

## Related Topics

- [[git/git-internals.md]] — Annotated tags are stored as objects in `.git/objects`; lightweight tags are ref files identical in structure to branches.
- [[git/git-branches.md]] — Tags and branches are both refs — the difference is tags are fixed, branches advance with commits.
- [[git/git-commits.md]] — Tags point to commits; `git show <tag>` reveals the commit and, for annotated tags, the tag object metadata.
- [[git/git-workflows.md]] — Release tagging conventions (semver, CalVer) are part of team Git workflow decisions.

---

## Source

[Git Book — Git Basics — Tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging)

---
*Last updated: 2026-03-24*