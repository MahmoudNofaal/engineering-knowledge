# Git Large File Storage (LFS)

> Git LFS is an extension that replaces large binary files in your repository with small text pointers, storing the actual file content on a separate server.

---

## Quick Reference

| | |
|---|---|
| **What it is** | An extension that offloads large binaries from the Git object store to a separate LFS server |
| **Use when** | Versioning binary assets (design files, ML models, media) alongside code |
| **Avoid when** | Build outputs, release binaries — use an artifact store (S3, Artifactory) instead |
| **Git version** | LFS is a Git extension, not core Git — install separately; any Git 1.8.2+ |
| **Key location** | Pointers in `.git/objects`; actual files on LFS server; `.gitattributes` defines patterns |
| **Key commands** | `git lfs install`, `git lfs track`, `git lfs ls-files`, `git lfs migrate`, `GIT_LFS_SKIP_SMUDGE=1` |

---

## When To Use It

Use Git LFS when your repo needs to version binary assets — ML model weights, design files, compiled artifacts, video, audio, or large datasets — that would otherwise bloat the repository's `.git` folder permanently. Git is terrible at storing large binaries: every version of a 100MB file adds 100MB to the repo forever, even after deletion, because Git stores full content snapshots. Without LFS, repos become slow to clone, push, and fetch over time. Don't use LFS as a substitute for a proper artifact store (S3, Azure Blob, Artifactory) for build outputs — those shouldn't be in Git at all.

---

## Core Concept

When you add a file to LFS tracking, the actual binary content is uploaded to the LFS server (GitHub, GitLab, or self-hosted) and replaced in the repo with a 130-byte text pointer containing the file's SHA-256 hash and size. When you checkout a branch, Git LFS downloads the actual file from the LFS server based on that pointer. The Git repo itself stays small because it only stores pointers. The key implication: you need LFS installed and authenticated on every machine that checks out the repo, and the LFS storage on your hosting provider has its own size and bandwidth quotas — separate from your regular repo quota.

---

## Version History

| Version | What changed |
|---|---|
| LFS 1.0 (2015) | Initial release by GitHub — pointer-based binary storage |
| LFS 1.4 | Batch API for faster transfers |
| LFS 2.0 | Locking API — prevent concurrent edits on non-mergeable files |
| LFS 2.3 | `git lfs migrate` for history rewriting |
| LFS 3.0 | SHA-256 pointer support; improved concurrent uploads |
| LFS 3.4 (2024) | Improved `--above` flag for migrate; better partial clone integration |

*File locking (LFS 2.0+) is LFS's answer to binary files that can't be merged — design files, 3D models, Photoshop files. `git lfs lock design/hero.psd` prevents anyone else from editing that file until you unlock it. Essential for design teams but adds a coordination step that slows parallel work.*

---

## Performance

| Scenario | Without LFS | With LFS |
|---|---|---|
| Clone a repo with 500MB of binaries | Download 500MB every clone | Download pointers (~65KB); binaries on demand |
| CI pipeline clone | 500MB every run | `GIT_LFS_SKIP_SMUDGE=1` = near-instant |
| Push a new 50MB binary version | 50MB added permanently | 50MB uploaded to LFS (replaceable) |
| `git log` on a binary file | Fast (only metadata) | Same — LFS doesn't affect history traversal |
| Bandwidth quota on GitHub free | N/A | 1GB/month — easily exhausted by CI |

**Allocation behaviour:** Each LFS object is stored on the LFS server by its SHA-256 hash. The Git repo stores 130-byte pointer files. If you have 100 versions of a 50MB texture, Git history holds 100 × 130 bytes of pointers — and the LFS server holds however many unique versions exist (LFS deduplicates by content hash). Storage grows only when content actually changes.

**Benchmark notes:** GitHub Free plans get 1GB/month of LFS bandwidth. A CI pipeline that clones a repo with 200MB of LFS files will exhaust that quota in 5 clone operations. For CI, always set `GIT_LFS_SKIP_SMUDGE=1` unless the build actually needs the binary files. GitHub Team/Enterprise plans get 50GB/month; additional storage and bandwidth are purchasable.

---

## The Code

**Install and initialize LFS**
```bash
# Install LFS (one-time per machine)
# macOS:
brew install git-lfs
# Ubuntu/Debian:
sudo apt-get install git-lfs
# Windows: included in Git for Windows 2.x

# Initialize in a repo (adds pre-push and post-checkout hooks)
git lfs install
```

**Track file patterns**
```bash
# Track by extension
git lfs track "*.psd"
git lfs track "*.mp4"
git lfs track "*.zip"

# Track by directory + extension
git lfs track "models/*.bin"
git lfs track "assets/**/*.png"   # recursive glob
git lfs track "data/**/*.parquet"

# .gitattributes is updated — commit it
git add .gitattributes
git commit -m "chore: configure LFS tracking for binary assets"

# View current tracking patterns
git lfs track
```

**Adding and verifying LFS files**
```bash
git add assets/hero-video.mp4
git commit -m "feat: add hero video asset"
git push origin main           # triggers LFS upload

# Verify a file is tracked by LFS (not stored directly in Git)
git lfs ls-files               # all LFS-tracked files in current commit

# Inspect the pointer file content
git lfs pointer --file assets/hero-video.mp4
# version https://git-lfs.github.com/spec/v1
# oid sha256:a8b4c2d1e9f3...
# size 48291042

# Check what's in the Git object store vs LFS
git show HEAD:assets/hero-video.mp4
# version https://git-lfs.github.com/spec/v1  ← confirms it's a pointer
```

**Clone strategies**
```bash
# Full clone with LFS files
git clone https://github.com/org/repo.git     # LFS files downloaded automatically

# Clone without downloading LFS files (fastest — pointers only)
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/org/repo.git

# Download LFS files selectively after clone
git lfs pull --include="models/v2/*.bin"      # only what you need
git lfs pull --exclude="*.mp4"               # everything except videos

# Download all LFS files for current checkout
git lfs pull
```

**Migrate existing large files to LFS after the fact**
```bash
# Find large files in history (before migrating)
git lfs migrate info --everything --top=10
# migrate: commit ████████████████████ (100%)
# *.bin    2.3 GB   31 files
# *.psd    890 MB   14 files
# *.mp4    540 MB   8 files

# Migrate — rewrites entire history (coordinate with team: everyone must re-clone)
git lfs migrate import --include="*.bin,*.psd,*.mp4" --everything

# Force push all branches + tags
git push --force --all
git push --force --tags

# All teammates must re-clone (not pull — the history is rewritten)
# Communicate clearly before running this
```

**File locking for non-mergeable binaries**
```bash
# Lock a file before editing (prevents concurrent edits)
git lfs lock design/homepage.psd
# Locked design/homepage.psd

# List currently locked files
git lfs locks
# Path                 Owner          Server  ID
# design/homepage.psd  ali@company.com  https://...  123

# Unlock after pushing your changes
git lfs unlock design/homepage.psd

# Force unlock if the owner is unavailable
git lfs unlock --force design/homepage.psd
```

---

## Real World Example

A machine learning team stored model weights directly in Git. After 6 months of experimentation, the repo had grown to 47GB — models ranging from 200MB to 4GB each, with 30+ versions of some models. `git clone` took 25 minutes and CI was failing because the CI server was running out of disk space mid-clone.

```bash
# Before migration — diagnosis
git count-objects -v -H
# count: 1847
# size: 47.23 GiB

# Find the top offenders
git log --all --format="%H" | \
  xargs -n1 git ls-tree -r --long | \
  sort -k4 -n -r | head -20

# Models are 89% of the repo size
git lfs migrate info --everything --top=5
# *.bin    38.1 GB   models/ directory
# *.h5     6.4 GB    keras model files
# *.pt     2.1 GB    PyTorch checkpoints
# *.pkl    0.4 GB    sklearn models
# *.parquet 0.2 GB   evaluation datasets

# Migration plan:
# 1. Notify all 12 team members — they must re-clone after migration
# 2. Migrate during low-activity window (Friday evening)
# 3. Verify CI pipeline has LFS support configured

# Execute migration
git lfs migrate import \
  --include="*.bin,*.h5,*.pt,*.pkl,*.parquet" \
  --everything

# Post-migration repo size
git count-objects -v -H
# size: 1.2 MiB  ← 47GB → 1.2MB of Git objects

# Update CI pipeline
# Before: git clone (25 minutes)
# After:
# - git clone with GIT_LFS_SKIP_SMUDGE=1 (8 seconds)
# - git lfs pull --include="models/production/latest.bin" (45 seconds for just what CI needs)

# GitHub Actions updated:
cat >> .github/workflows/train.yml << 'EOF'
      - uses: actions/checkout@v4
        with:
          lfs: false             # don't auto-download all LFS files

      - name: Pull only required model
        run: |
          git lfs pull --include="models/production/latest.bin"
EOF
```

*The key insight: LFS migration is a one-time surgery that pays compounding dividends. Every developer's `git clone` went from 25 minutes to 8 seconds. Every CI run saved 24 minutes. The repo became collaborative again — previously, engineers with slow connections had stopped pulling frequently because cloning was so painful.*

---

## Common Misconceptions

**"Deleting a large file from Git and committing removes it from the repo"**
Deleting a file removes it from the working directory and from future checkouts — but the blob object remains in Git history. Every clone still downloads every historical version. The repo size doesn't shrink. To actually remove a large file from history, you need `git filter-repo --path <file> --invert-paths` (and then LFS migration if you want to keep it tracked).

**"LFS is just for very large files"**
LFS is appropriate for any binary file that Git can't delta-compress effectively — design files (PSD, Sketch, Figma exports), compiled binaries, SQLite databases, Excel files, audio, video. A 500KB PSD file that gets re-exported weekly is a better LFS candidate than a 5MB minified JS bundle that Git can diff. The question isn't "is it big?" but "does Git benefit from diffing it?"

**"Setting `GIT_LFS_SKIP_SMUDGE=1` means LFS files aren't needed"**
`GIT_LFS_SKIP_SMUDGE=1` skips the automatic download of LFS content at checkout — files appear as their 130-byte pointer text instead of the actual binary. This is correct for CI pipelines that don't need the binaries. But if your build process tries to use a file that's actually a pointer, it will fail with confusing errors (e.g., trying to open a "video file" that's 130 bytes of text). Explicitly download what you need with `git lfs pull --include="pattern"`.

---

## Gotchas

- **LFS bandwidth quotas on GitHub are 1GB/month on free plans.** Every `git clone` or `git pull` that downloads LFS files counts against this. A CI pipeline that clones on every run can exhaust it in days.

- **Tracking patterns must be set before adding files.** If you add a 200MB file before running `git lfs track`, it goes into regular Git history. Fixing this requires `git lfs migrate` and a history rewrite.

- **`GIT_LFS_SKIP_SMUDGE=1` means LFS files are pointers on disk.** If your build needs the actual files, it breaks silently with confusing errors — the files exist but contain pointer text instead of binary content.

- **LFS requires credentials on every machine.** In CI, you need an LFS-capable token. Many engineers set up LFS locally and forget to configure it in the pipeline, causing CI to check out pointer files instead of real content.

- **`git lfs migrate` rewrites history and requires everyone to re-clone.** Coordinate like any force-push to a shared branch — nobody should have uncommitted work when you run this.

---

## Interview Angle

**What they're really testing:** Whether you understand the cost model of storing binaries in Git and can reason about alternatives for different types of large files.

**Common question forms:**
- "How do you handle large files in Git?"
- "Our repo is 40GB and clone takes 20 minutes — what would you do?"
- "What's wrong with committing binary files directly to a repository?"

**The depth signal:** A junior explains that LFS stores pointers instead of files. A senior knows the quota implications for CI, explains why `git lfs migrate` requires a coordinated history rewrite, and can distinguish: files that belong in LFS (versioned assets), files that belong in an artifact store (build outputs), and files that shouldn't be in version control at all (secrets, large data dumps). They also know `GIT_LFS_SKIP_SMUDGE=1` for CI optimization and the bandwidth math.

**Follow-up questions to expect:**
- "How would you reduce CI clone time for a repo with large LFS objects?"
- "What's the difference between LFS storage quota and LFS bandwidth quota?"

---

## Related Topics

- [git-monorepo.md](git-monorepo.md) — Monorepos accumulate assets from multiple teams faster; LFS configuration becomes critical at monorepo scale.
- [github-actions-integration.md](github-actions-integration.md) — CI workflows cloning repos with LFS must handle the `lfs:` checkout option and bandwidth costs.
- [git-submodules.md](git-submodules.md) — Both submodules and LFS handle assets that don't fit standard Git; knowing when to use each is a common architectural decision.
- [git-internals.md](git-internals.md) — Understanding Git's object store explains why binary files are expensive: no delta compression, full content stored per version.

---

## Source

[GitHub Docs — About Git Large File Storage](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-git-large-file-storage)

---
*Last updated: 2026-04-24*