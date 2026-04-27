# GitHub Packages

> GitHub Packages is a package registry integrated with GitHub — hosting Docker images (ghcr.io), NuGet packages, npm packages, Maven artifacts, and more, with authentication tied to GitHub tokens.

---

## Quick Reference

| | |
|---|---|
| **What it is** | GitHub-hosted package registries for containers and language packages |
| **Supported registries** | Container (ghcr.io), NuGet, npm, Maven, Gradle, RubyGems |
| **Use when** | Publishing internal packages/images accessible to GitHub org members |
| **Avoid when** | Public packages with large download volumes — GitHub has bandwidth limits |
| **Authentication** | GitHub token (`GITHUB_TOKEN` in Actions, PAT for local access) |
| **Pricing** | Free for public packages; private packages use storage/data transfer quotas |

---

## Core Concept

GitHub Packages provides a package registry that lives alongside your code — same authentication, same org membership, same permissions model. Packages and container images are scoped to a user or org and can be linked to a specific repository. The key advantage over external registries (Docker Hub, NuGet.org) for internal packages: no separate authentication system, no separate access control — if someone has access to your GitHub org, they can pull your packages using their GitHub token.

---

## The Code

**Publishing Docker images to ghcr.io**
```yaml
# .github/workflows/publish-image.yml
name: Publish Docker Image

on:
  push:
    branches: [main]
    tags: ["v*"]

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write    # required to push to GitHub Packages

    steps:
      - uses: actions/checkout@v4

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}    # automatic in Actions

      - name: Extract metadata for Docker
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}        # v2.1.0 → 2.1.0
            type=semver,pattern={{major}}.{{minor}} # v2.1.0 → 2.1
            type=sha,prefix=sha-                   # sha-abc1234
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

**Pulling from ghcr.io**
```bash
# Authenticate (one-time — uses a PAT with read:packages scope)
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Pull an image
docker pull ghcr.io/org/repo/image-name:latest
docker pull ghcr.io/org/repo/image-name:v2.1.0

# In docker-compose.yml
services:
  api:
    image: ghcr.io/myorg/my-service:latest
```

**Publishing NuGet packages**
```yaml
# .github/workflows/publish-nuget.yml
name: Publish NuGet Package

on:
  push:
    tags: ["v*"]

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      packages: write

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "8.0.x"

      - name: Add GitHub NuGet source
        run: |
          dotnet nuget add source \
            "https://nuget.pkg.github.com/${{ github.repository_owner }}/index.json" \
            --name github \
            --username ${{ github.actor }} \
            --password ${{ secrets.GITHUB_TOKEN }} \
            --store-password-in-clear-text

      - name: Build and pack
        run: |
          VERSION=${GITHUB_REF#refs/tags/v}
          dotnet pack --configuration Release \
            -p:PackageVersion=$VERSION \
            -o ./nupkg

      - name: Publish to GitHub Packages
        run: dotnet nuget push ./nupkg/*.nupkg --source github
```

**Consuming GitHub NuGet packages**
```xml
<!-- nuget.config — add to repo root -->
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
    <add key="github" value="https://nuget.pkg.github.com/OWNER/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <github>
      <add key="Username" value="%GITHUB_USER%" />
      <add key="ClearTextPassword" value="%GITHUB_TOKEN%" />
    </github>
  </packageSourceCredentials>
</configuration>
```

```bash
# Local authentication (one-time per developer machine)
dotnet nuget add source \
  "https://nuget.pkg.github.com/OWNER/index.json" \
  --name github \
  --username YOUR_GITHUB_USERNAME \
  --password YOUR_PAT_WITH_READ_PACKAGES
```

---

## Common Misconceptions

**"GITHUB_TOKEN in Actions has packages write permission by default"**
You must explicitly grant `packages: write` in the workflow's `permissions:` block. Without it, the automatic `GITHUB_TOKEN` only has `packages: read`. The `contents: read` and `packages: write` pattern is the standard for publishing workflows.

**"Public packages are completely free to serve"**
Storage for public packages is free. Data transfer (downloads) for public packages has limits that GitHub manages. For high-traffic public packages (popular open source libraries with millions of downloads), external registries (Docker Hub, NuGet.org) have better CDN coverage and no practical bandwidth limits.

---

## Related Topics

- [github-releases.md](github-releases.md) — Releases and packages are complementary: releases for source tarballs, packages for compiled artifacts.
- [github-actions-advanced.md](github-actions-advanced.md) — Package publishing is almost always automated via Actions.
- [github-security-features.md](github-security-features.md) — Container image scanning can be integrated with ghcr.io images.

---

## Source

[GitHub Docs — GitHub Packages](https://docs.github.com/en/packages)

---
*Last updated: 2026-04-24*