# Git Large File Storage (LFS)

> Git LFS is an extension that replaces large binary files in your repository with small text pointers, storing the actual file content on a separate server.

---

## When To Use It

Use Git LFS when your repo needs to version binary assets — ML model weights, design files, compiled artifacts, video, audio, or large datasets — that would otherwise bloat the repository's `.git` folder permanently. Git is terrible at storing large binaries: every version of a 100MB file adds 100MB to the repo forever, even after deletion, because Git stores full content snapshots. Without LFS, repos become slow to clone, push, and fetch over time. Don't use LFS as a substitute for a proper artifact store (S3, Azure Blob, Artifactory) for build outputs — those shouldn't be in Git at all.

---

## Core Concept

When you add a file to LFS tracking, the actual binary content is uploaded to the LFS server (GitHub, GitLab, or self-hosted) and replaced in the repo with a 130-byte text pointer containing the file's SHA-256 hash and size. When you checkout a branch, Git LFS downloads the actual file from the LFS server based on that pointer. The Git repo itself stays small because it only stores pointers. The key implication: you need LFS installed and authenticated on every machine that checks out the repo, and the LFS storage on your hosting provider has its own size and bandwidth quotas — separate from your regular repo quota.

---

## The Code
```bash
# ── Install and initialize LFS ───────────────────────────────────────
git lfs install               # sets up LFS hooks in the current repo

# ── Track file patterns (updates .gitattributes) ─────────────────────
git lfs track "*.psd"
git lfs track "*.mp4"
git lfs track "models/*.bin"   # track by directory + extension
git lfs track "data/**/*.csv"  # recursive glob

# .gitattributes is updated — commit it
git add .gitattributes
git commit -m "chore: configure LFS tracking for binary assets"

# ── Adding a large file ──────────────────────────────────────────────
git add assets/hero-video.mp4
git commit -m "feat: add hero video asset"
# LFS pointer stored in Git; actual file uploaded to LFS server on push
git push origin main           # triggers LFS upload

# ── Verify a file is tracked by LFS (not stored directly in Git) ─────
git lfs ls-files               # lists all LFS-tracked files in current commit
git lfs pointer --file assets/hero-video.mp4  # shows the pointer content

# ── Clone a repo with LFS content ────────────────────────────────────
git clone https://github.com/org/repo.git     # LFS files downloaded automatically
GIT_LFS_SKIP_SMUDGE=1 git clone ...          # clone without downloading LFS files
git lfs pull                                   # then download LFS content later

# ── Migrate existing large files to LFS after the fact ───────────────
git lfs migrate import --include="*.bin" --everything
# Rewrites entire history — all collaborators must re-clone
# Coordinate this like any force-push to a shared branch
```

---

## Gotchas

- **LFS bandwidth quotas on GitHub are 1GB/month on free plans and 50GB on paid.** Every `git clone` or `git pull` that downloads LFS files counts against this quota. A CI pipeline that clones on every run can exhaust it in days on active repos.
- **Deleting a file from Git does not reduce LFS storage consumption.** The binary is still on the LFS server, still billed. To actually reclaim space, you must delete LFS objects through the hosting provider's API or admin panel.
- **Tracking patterns must be set before adding files.** If you add a 200MB file before running `git lfs track`, it goes into regular Git history as a full binary object. Fixing this requires `git lfs migrate` and a history rewrite.
- **`GIT_LFS_SKIP_SMUDGE=1` in CI saves bandwidth but means LFS files are pointers on disk.** If your build needs the actual files, it breaks silently with confusing errors — the files exist but contain pointer text instead of binary content.
- **LFS requires credentials on every machine.** In CI, you need an LFS-capable token configured. Many engineers set up LFS locally and forget to configure it in the pipeline, causing CI to check out pointer files instead of real content.

---

## Interview Angle

**What they're really testing:** Whether you understand the cost model of storing binaries in Git and can reason about alternatives for different types of large files.

**Common question form:** "How do you handle large files in Git?" or "What's wrong with committing binary files directly to a repository?"

**The depth signal:** A junior explains that LFS stores pointers instead of files. A senior knows the quota implications for CI (every pipeline clone counts against bandwidth), explains why `git lfs migrate` requires a coordinated history rewrite that forces re-clones for all teammates, can distinguish between files that belong in LFS (versioned design assets, ML model weights that need to track with code), files that belong in an artifact store (build outputs, release binaries), and files that shouldn't be in version control at all (secrets, large data dumps).

---

## Related Topics

- [[git/git-monorepo.md]] — Monorepos that house multiple domains often run into large file problems faster; LFS configuration becomes critical at that scale.
- [[git/github-actions-integration.md]] — CI workflows cloning repos with LFS must handle token configuration and bandwidth cost explicitly.
- [[devops/ci-cd-pipelines.md]] — Pipeline clone strategies (shallow clone, LFS skip) are the primary levers for controlling build time and bandwidth cost on LFS repos.
- [[git/git-submodules.md]] — Both submodules and LFS are ways to handle repo dependencies/assets that don't fit standard Git; knowing when to use each is a common architectural decision.

---

## Source

[GitHub Docs — About Git Large File Storage](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-git-large-file-storage)

---
*Last updated: 2026-03-24*