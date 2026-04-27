# GitHub Releases

> A GitHub Release is a deployable snapshot of your project at a tagged commit — combining a Git tag, release notes, and downloadable binary assets into a discoverable, versioned artifact.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A packaged snapshot combining a Git tag + notes + downloadable assets |
| **Use when** | Publishing versioned software, libraries, CLI tools, or Docker images |
| **Avoid when** | Internal deployment artifacts — use an artifact registry (Artifactory, ECR) |
| **Key location** | Repository → Releases tab |
| **Key commands** | `gh release create`, `gh release upload`, `gh release download` |
| **Relation to tags** | Every release is backed by a Git tag; not every tag needs a release |

---

## Core Concept

A GitHub Release extends a Git tag with: a human-readable title, formatted release notes (Markdown), downloadable binary assets, and a pre-release flag. The Git tag provides the immutable pointer to a commit; the release provides the human-facing metadata and files. Releases appear on the repo's Releases page, in the GitHub API, and via `gh release list` — making them discoverable in a way that raw tags are not. Automated releases from CI/CD pipelines (triggered by `on: push: tags: - 'v*'`) are the production pattern.

---

## The Code

**Automated release pipeline**
```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - "v*"     # triggers on any tag like v1.2.3, v2.0.0-rc1

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0    # needed for git describe and changelog generation

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "8.0.x"

      - name: Get version from tag
        id: version
        run: |
          VERSION=${GITHUB_REF#refs/tags/}
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "version_num=${VERSION#v}" >> $GITHUB_OUTPUT

      - name: Build and publish
        run: |
          dotnet publish src/MyApp \
            --configuration Release \
            --output ./publish \
            -p:Version=${{ steps.version.outputs.version_num }}

      - name: Create release archives
        run: |
          cd publish
          tar -czf ../myapp-${{ steps.version.outputs.version }}-linux-x64.tar.gz .

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.version.outputs.version }}
          name: "Release ${{ steps.version.outputs.version }}"
          generate_release_notes: true   # auto-generate from merged PRs
          draft: false
          prerelease: ${{ contains(steps.version.outputs.version, '-') }}
          files: |
            myapp-*.tar.gz
            publish/myapp.exe
```

**Manual release via GitHub CLI**
```bash
# Create a release with auto-generated notes (from merged PRs since last release)
gh release create v2.1.0 \
  --generate-notes \
  --title "v2.1.0 — Payment Webhook Support"

# Create with custom notes
gh release create v2.1.0 \
  --notes-file CHANGELOG.md \
  --title "v2.1.0"

# Create a pre-release (rc, beta, alpha)
gh release create v2.1.0-rc1 \
  --prerelease \
  --title "v2.1.0 Release Candidate 1" \
  --notes "Testing release candidate. Do not use in production."

# Upload assets to an existing release
gh release upload v2.1.0 \
  ./dist/myapp-linux-amd64 \
  ./dist/myapp-windows-amd64.exe \
  ./dist/myapp-darwin-arm64

# Download a release asset
gh release download v2.1.0 --pattern "*.tar.gz" --dir ./downloads

# List all releases
gh release list

# View release details
gh release view v2.1.0
```

**Auto-generated release notes configuration**
```yaml
# .github/release.yml — configure auto-generated changelog categories
changelog:
  exclude:
    labels:
      - ignore-for-release       # PRs with this label are excluded
    authors:
      - dependabot[bot]          # exclude Dependabot PRs from notes

  categories:
    - title: "🚀 New Features"
      labels:
        - "feat"
        - "enhancement"

    - title: "🐛 Bug Fixes"
      labels:
        - "bug"
        - "fix"

    - title: "🔒 Security"
      labels:
        - "security"

    - title: "📦 Dependencies"
      labels:
        - "dependencies"

    - title: "🔧 Other Changes"
      labels:
        - "*"    # catch-all for unlabelled PRs
```

---

## Common Misconceptions

**"Creating a release creates the Git tag"**
You can create a release and have GitHub create a new tag, or create a release from an existing tag. Either works. But: if you create a tag locally with `git tag -a v1.2.0` and push it, the release doesn't exist until you create it (via UI, CLI, or API). Tags and releases are related but separate.

**"Pre-releases are invisible to users"**
Pre-releases are visible on the Releases page but marked as pre-release. GitHub's "latest release" API (`/releases/latest`) skips pre-releases — it only returns the latest non-pre-release. This is the key behavioral difference: tools that fetch "latest" (like Homebrew formulas or Dependabot) will skip pre-releases automatically.

---

## Related Topics

- [git-tags.md](../git/git-tags.md) — Every GitHub Release is backed by a Git tag.
- [github-actions-advanced.md](github-actions-advanced.md) — Release automation via the `on: push: tags:` trigger.
- [github-packages.md](github-packages.md) — Publishing container images and packages alongside releases.

---

## Source

[GitHub Docs — About Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)

---
*Last updated: 2026-04-24*