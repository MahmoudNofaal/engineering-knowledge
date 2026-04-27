# GitHub Codespaces

> GitHub Codespaces is a cloud-hosted development environment that runs VS Code (or any editor via SSH/JetBrains Gateway) with your repository cloned, pre-configured, and ready to code in seconds.

---

## Quick Reference

| | |
|---|---|
| **What it is** | On-demand cloud dev environment — full Linux VM with VS Code, pre-configured per repo |
| **Use when** | Onboarding new engineers, contributing to unfamiliar repos, working from any device |
| **Avoid when** | Long-running local builds that benefit from local hardware; air-gapped environments |
| **Configuration** | `.devcontainer/devcontainer.json` — defines the container, extensions, settings |
| **Billing** | Free tier: 120 core-hours/month + 15GB storage; pay-as-you-go above that |
| **Key commands** | `gh codespace create`, `gh codespace list`, `gh codespace ssh`, `gh codespace delete` |

---

## Core Concept

A Codespace is a Docker container running on GitHub's infrastructure with your repository cloned inside it. The container definition lives in `.devcontainer/devcontainer.json` — it specifies the base Docker image, VS Code extensions to install, `postCreateCommand` to run (e.g., `dotnet restore`, `npm install`), port forwarding, and environment secrets. When a developer opens a Codespace, they get a fully configured environment identical to what the `devcontainer.json` specifies — no more "works on my machine," no setup time, no inconsistent environments.

---

## The Code

**devcontainer.json — the complete configuration**
```json
// .devcontainer/devcontainer.json
{
  "name": "Payment Service Dev",
  "image": "mcr.microsoft.com/devcontainers/dotnet:8.0",
  // OR build from a custom Dockerfile:
  // "build": { "dockerfile": "Dockerfile", "context": ".." },

  // Run after container creation
  "postCreateCommand": "dotnet restore && npm ci",

  // Run every time the container starts
  "postStartCommand": "git config --global pull.rebase true",

  // VS Code extensions to install automatically
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-dotnettools.csharp",
        "ms-dotnettools.csdevkit",
        "EditorConfig.EditorConfig",
        "streetsidesoftware.code-spell-checker",
        "GitHub.copilot",
        "ms-azuretools.vscode-docker",
        "humao.rest-client"
      ],
      "settings": {
        "editor.formatOnSave": true,
        "editor.rulers": [120],
        "dotnet.defaultSolution": "MyService.sln"
      }
    }
  },

  // Forward ports from container to browser/local machine
  "forwardPorts": [5000, 5001, 8080],
  "portsAttributes": {
    "5001": {
      "label": "API (HTTPS)",
      "onAutoForward": "openBrowser"
    },
    "8080": {
      "label": "Prometheus metrics",
      "onAutoForward": "silent"
    }
  },

  // Environment variables available in the codespace
  "containerEnv": {
    "ASPNETCORE_ENVIRONMENT": "Development",
    "DOTNET_WATCH_RESTART_ON_RULESETCHANGE": "1"
  },

  // Features: pre-built tool installers
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/node:1": { "version": "20" }
  },

  // Mount configuration
  "mounts": [
    "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
  ],

  // Run as non-root user
  "remoteUser": "vscode"
}
```

**Multi-container devcontainer (with docker-compose)**
```yaml
# .devcontainer/docker-compose.yml
version: "3.8"

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    volumes:
      - ..:/workspace:cached
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/mydb
      - REDIS_URL=redis://cache:6379
    ports:
      - "5001:5001"
    depends_on:
      - db
      - cache

  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: mydb
    volumes:
      - postgres-data:/var/lib/postgresql/data

  cache:
    image: redis:7-alpine

volumes:
  postgres-data:
```

```json
// .devcontainer/devcontainer.json (referencing docker-compose)
{
  "name": "Payment Service + Postgres + Redis",
  "dockerComposeFile": "docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",
  "postCreateCommand": "dotnet restore && dotnet ef database update"
}
```

**Codespace secrets**
```bash
# Secrets are encrypted and available as environment variables in the codespace
# Configure: Settings → Codespaces → Secrets

# Via CLI
gh secret set STRIPE_TEST_API_KEY --user  # user-level secret (available in all codespaces)
gh secret set DATABASE_URL --repos "org/payments-service"  # repo-specific

# Access in devcontainer.json:
"containerEnv": {
  "STRIPE_API_KEY": "${localEnv:STRIPE_TEST_API_KEY}"
}

# Or just use them directly in the terminal:
echo $STRIPE_TEST_API_KEY
```

**Prebuilds — eliminate cold start time**
```bash
# Prebuilds run postCreateCommand on a schedule and cache the result
# New codespaces start from the cached image — near-instant vs minutes

# Configure: Repository Settings → Codespaces → Prebuilds → Set up prebuild

# Prebuild triggers:
# - On push to main (default)
# - On push to any branch
# - On push + periodic (weekly/daily)

# Prebuild regions — cache in regions where your team is:
# US East, EU West, Asia Pacific — configure per org

# Cost: prebuilds use storage + compute to build; faster startup saves developer time
# Rule of thumb: enable prebuilds when postCreateCommand takes > 2 minutes
```

**Working with Codespaces via CLI**
```bash
# Create a codespace
gh codespace create \
  --repo org/repo \
  --branch feature/my-feature \
  --machine standardLinux32gb   # 8-core, 32GB RAM

# Available machine types:
# basicLinux32gb   — 2-core, 4GB RAM, 32GB storage
# standardLinux32gb — 4-core, 8GB RAM, 32GB storage (default)
# premiumLinux     — 8-core, 16GB RAM, 64GB storage
# largePremiumLinux — 16-core, 32GB RAM, 128GB storage

# List your codespaces
gh codespace list

# Connect via SSH (terminal access, works with any SSH client or JetBrains)
gh codespace ssh

# Open in VS Code desktop (not browser)
gh codespace code

# Stop a codespace (stops billing, preserves state)
gh codespace stop my-codespace-abc

# Delete when done (or set auto-delete timeout in settings)
gh codespace delete my-codespace-abc

# Port forward from a running codespace to local machine
gh codespace ports forward 5001:5001 -c my-codespace-abc
```

---

## Real World Example

A fintech company's onboarding took 3 days — setting up the development environment required: installing specific .NET/Node versions, configuring a PostgreSQL database, setting up Redis, adding internal NuGet feeds, and getting the right environment variables. New engineers frequently had broken environments weeks later due to drift. After standardising on Codespaces with a devcontainer.json, onboarding became 4 hours and environment drift became impossible.

```json
// .devcontainer/devcontainer.json — the entire 3-day setup in one file
{
  "name": "FinTech Platform Dev",
  "dockerComposeFile": "docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",

  "postCreateCommand": [
    "dotnet restore",
    "npm ci --prefix apps/frontend",
    "dotnet ef database update --project src/Infrastructure",
    "dotnet build"
  ],

  "customizations": {
    "vscode": {
      "extensions": [
        "ms-dotnettools.csharp",
        "ms-dotnettools.csdevkit",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "GitHub.copilot",
        "mtxr.sqltools",
        "mtxr.sqltools-driver-pg"
      ]
    }
  },

  "forwardPorts": [5001, 3000, 5432, 6379],

  "secrets": {
    "STRIPE_TEST_KEY": {
      "description": "Stripe test API key — get from 1Password vault 'Development'",
      "documentationUrl": "https://wiki.internal/dev-setup#stripe"
    }
  }
}

// Result metrics after 3 months:
// Onboarding: 3 days → 4 hours
// "Broken environment" support tickets: 8/month → 0
// New hire confidence on day 1: 
//   Before: "I still can't get the tests to run"
//   After: "I submitted my first PR today"
// Environment drift incidents: eliminated
```

---

## Common Misconceptions

**"Codespaces are just for contributors without a local machine"**
Codespaces are useful for: onboarding (zero-setup), reviewing PRs (check out and run without affecting local environment), working from a different machine (nothing to install), and ensuring environment consistency. Many senior engineers use Codespaces even for their primary development when the setup/maintenance of a complex local environment outweighs cloud compute costs.

**"Codespaces are too expensive for regular use"**
The free tier (120 core-hours/month for personal accounts) covers about 15 hours/month of a 8-core machine or 30 hours/month of a 4-core machine. For professional GitHub accounts (Team, Enterprise), the free tier is higher and organisations can set spending limits. The cost should be compared against: local machine costs, setup time, and environment inconsistency debugging time.

**"devcontainer.json only works with Codespaces"**
The Dev Container specification is an open standard. `devcontainer.json` works with: GitHub Codespaces, VS Code's "Dev Containers" extension (local Docker), and other IDEs via the `devcontainer` CLI. A repo with a good `devcontainer.json` can be developed in the cloud (Codespaces), locally in Docker (VS Code Dev Containers), or in any compatible environment.

---

## Gotchas

- **Codespaces stop automatically after 30 minutes of inactivity** (default). Your uncommitted changes persist in the codespace's storage, but you'll need to restart it. Set idle timeout in Settings → Codespaces → Default idle timeout.

- **Prebuilds don't update until triggered.** If you change `devcontainer.json` and push, the prebuild doesn't update until its next scheduled trigger (or you manually trigger it). New codespaces will use the cached old image until the prebuild completes.

- **Git credentials are automatically configured** — the codespace has write access to the repo it was created from (using the `GITHUB_TOKEN`). You don't need to set up SSH keys for pushing to that repo.

- **Large files and `.gitignore` still apply.** The codespace clones the repo, so the same Git rules apply. If you've accidentally committed `node_modules/`, the codespace will also clone it — fix `.gitignore` issues before expecting fast codespace creation.

- **Secrets are user-level or repo-level — not org-level by default.** If you need secrets available in codespaces for all repos in an org, each engineer must add them to their user settings, or use a Codespaces organisation policy with pre-set secrets.

---

## Interview Angle

**What they're really testing:** Whether you understand cloud development environments and can design a reproducible developer experience.

**Common question forms:**
- "How do you ensure all developers have the same environment?"
- "How would you reduce onboarding time for new engineers?"
- "What's a devcontainer?"

**The depth signal:** A junior knows Codespaces is "VS Code in the browser." A senior can write a `devcontainer.json` that specifies the full environment (base image, extensions, `postCreateCommand`, secrets, ports), knows about prebuilds and when they're worth the cost, understands that devcontainers are an open standard not exclusive to GitHub, and can design a multi-container devcontainer for services with database/cache dependencies.

---

## Related Topics

- [github-repositories.md](github-repositories.md) — Codespaces configuration lives in the repository.
- [github-security-features.md](github-security-features.md) — Codespaces secrets are managed separately from repository secrets.
- [git-ignore.md](../git/git-ignore.md) — `.gitignore` affects what's cloned in the codespace; poorly configured ignore rules affect codespace startup time.

---

## Source

[GitHub Docs — GitHub Codespaces](https://docs.github.com/en/codespaces)

---
*Last updated: 2026-04-24*