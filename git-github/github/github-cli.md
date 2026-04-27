# GitHub CLI (gh)

> The `gh` CLI brings GitHub's platform features — PRs, issues, releases, workflows, and the API — into the terminal, enabling scripting and automation of GitHub workflows without leaving the command line.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Official GitHub command-line tool for interacting with the GitHub platform |
| **Use when** | PR management, release automation, CI monitoring, scripting GitHub API calls |
| **Avoid when** | Simple `git` operations — `gh` wraps GitHub, not Git |
| **Install** | `brew install gh` / `winget install GitHub.cli` / `apt install gh` |
| **Auth** | `gh auth login` — prompts for browser-based OAuth or PAT |
| **Key commands** | `gh pr`, `gh issue`, `gh repo`, `gh release`, `gh workflow`, `gh api`, `gh run` |

---

## Core Concept

`gh` is the CLI for GitHub's platform layer — everything that lives on GitHub.com above the Git protocol. While `git` manages commits, branches, and history, `gh` manages PRs, issues, releases, workflows, and repository settings. The two tools are complementary, not overlapping. The most powerful `gh` feature is `gh api` — direct access to the GitHub REST and GraphQL APIs with automatic authentication, enabling scripting of any GitHub operation.

---

## The Code

**Authentication and setup**
```bash
# Login (opens browser for OAuth)
gh auth login

# Login with a PAT (for CI/headless environments)
echo $GITHUB_TOKEN | gh auth login --with-token

# Check auth status
gh auth status

# Switch between multiple accounts/orgs
gh auth login --hostname github.com
gh config set host github.com
```

**Pull request workflow**
```bash
# Create a PR from current branch
gh pr create \
  --title "feat: add OAuth support" \
  --body "$(cat .github/pull_request_template.md)" \
  --reviewer alice,org/backend-team \
  --label "backend,needs-review" \
  --draft

# Open current branch's PR in browser
gh pr view --web

# List all open PRs
gh pr list
gh pr list --author @me
gh pr list --label "needs-review"

# Check out a PR locally (creates tracking branch)
gh pr checkout 142

# Review a PR
gh pr review 142 --approve -b "LGTM — logic is sound, tests cover edge cases"
gh pr review 142 --request-changes -b "Blocking: null ref in payment path"
gh pr review 142 --comment -b "See inline comments"

# View PR status (reviews, CI status)
gh pr status
gh pr view 142
gh pr view 142 --json reviews,statusCheckRollup

# Merge a PR
gh pr merge 142 --squash --delete-branch
gh pr merge 142 --merge
gh pr merge 142 --rebase

# Enable auto-merge (merges automatically when all checks pass)
gh pr merge 142 --auto --squash

# Mark draft PR as ready for review
gh pr ready 142
```

**Issue management**
```bash
# Create an issue
gh issue create \
  --title "Bug: null ref in cart when empty" \
  --body "Steps to reproduce: ..." \
  --label "bug,high-priority" \
  --assignee alice \
  --milestone "v2.1"

# List issues
gh issue list
gh issue list --assignee @me
gh issue list --label "bug"
gh issue list --milestone "v2.1" --state open

# View and comment
gh issue view 89
gh issue comment 89 --body "Investigating now — likely related to #87"

# Close an issue
gh issue close 89 --comment "Fixed in PR #142"
```

**Repository operations**
```bash
# Create a repo
gh repo create org/new-service --private --clone

# Clone a repo (with HTTPS, not SSH by default)
gh repo clone org/service

# Fork and clone
gh repo fork org/service --clone

# View repo info
gh repo view
gh repo view org/service --json name,description,topics

# List repos in an org
gh repo list org --limit 100 --json name,isPrivate,updatedAt

# Archive a repo
gh repo archive org/old-service
```

**Workflow and CI operations**
```bash
# List all workflows
gh workflow list

# Trigger a workflow manually (requires workflow_dispatch trigger)
gh workflow run "Release" --ref main \
  --field version="v2.1.0" \
  --field environment="production"

# List recent workflow runs
gh run list
gh run list --workflow ci.yml --limit 5

# Watch a running workflow in real time
gh run watch 12345678

# View run details and logs
gh run view 12345678
gh run view 12345678 --log

# Download run artifacts
gh run download 12345678 --name build-output

# Re-run a failed workflow
gh run rerun 12345678
gh run rerun 12345678 --failed-only  # re-run only failed jobs
```

**Release management**
```bash
# Create a release from a tag
gh release create v2.1.0 \
  --title "v2.1.0 — Payment webhook support" \
  --notes "$(cat CHANGELOG.md)" \
  --target main \
  --latest

# Create a pre-release
gh release create v2.1.0-rc1 --prerelease \
  --title "v2.1.0 Release Candidate 1"

# Upload assets to a release
gh release upload v2.1.0 \
  ./dist/service-linux-amd64 \
  ./dist/service-windows-amd64.exe \
  ./dist/service-darwin-arm64

# Auto-generate release notes from merged PRs
gh release create v2.1.0 --generate-notes

# List releases
gh release list

# Download release assets
gh release download v2.1.0 --pattern "*.tar.gz"
```

**Direct API access**
```bash
# REST API — any GitHub endpoint
gh api repos/org/repo/branches
gh api orgs/org/members --jq '.[].login'

# POST/PATCH with data
gh api repos/org/repo/issues \
  --method POST \
  --field title="Automated issue" \
  --field body="Created by script" \
  --field labels='["automated"]'

# Paginate through all results
gh api repos/org/repo/pulls \
  --paginate \
  --jq '.[].number'

# GraphQL API
gh api graphql -f query='
  query($org: String!) {
    organization(login: $org) {
      repositories(first: 100) {
        nodes { name, isPrivate, updatedAt }
      }
    }
  }
' -f org=myorg

# Use in scripts — set default fields and output format
gh api repos/org/repo/commits \
  --jq '.[0] | {sha: .sha, author: .commit.author.name, message: .commit.message}'
```

**Scripting GitHub operations**
```bash
#!/bin/bash
# scripts/bulk-update-branch-protection.sh
# Apply the same branch protection to all repos in an org

ORG="myorg"
PROTECTION_CONFIG=$(cat << 'EOF'
{
  "required_status_checks": {"strict": true, "contexts": ["CI / build"]},
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false
}
EOF
)

gh repo list $ORG --json name --jq '.[].name' | while read repo; do
  echo "Protecting main branch in: $repo"
  echo "$PROTECTION_CONFIG" | \
    gh api "repos/$ORG/$repo/branches/main/protection" \
      --method PUT \
      --input - \
      --silent && echo "✓ $repo" || echo "✗ $repo (may not have a main branch)"
done
```

---

## Common Misconceptions

**"`gh` replaces `git`"**
`gh` and `git` are complementary. `gh` manages GitHub's platform features (PRs, issues, releases, Actions). `git` manages the repository itself (commits, branches, history). You need both. `gh pr checkout 142` uses `git` under the hood to fetch and checkout the branch.

**"`gh api` is rate-limited to unusable levels"**
GitHub's API rate limit is 5,000 requests/hour for authenticated requests — sufficient for almost all scripting. For bulk operations on hundreds of repos, add `--paginate` and `sleep` between requests. For high-volume automation, GitHub Apps have higher rate limits than PATs.

**"`gh` only works on the command line"**
`gh` has a JSON output mode (`--json`) and a jq integration (`--jq`) that makes it composable with other CLI tools. It's designed for scripting, not just interactive use. Every `gh` command can output structured JSON, making it usable in shell pipelines, Python scripts, or CI workflows.

---

## Gotchas

- **`gh pr checkout` creates a local branch named after the PR head branch — not the PR number.** If you've checked out the branch before, `gh pr checkout` may just switch to the existing local branch, which might be stale. Run `git pull` after checkout.

- **`gh auth login` stores credentials in the system keychain.** On headless servers, use `--with-token` and set `GITHUB_TOKEN` environment variable. In Actions, `GITHUB_TOKEN` is automatically available.

- **`gh api --paginate` can be slow for large result sets.** GitHub returns 30 items per page by default. Add `--jq 'length'` to count, then use `?per_page=100` query param to reduce round trips: `gh api 'repos/org/repo/commits?per_page=100' --paginate`.

- **`gh` doesn't handle all GitHub features.** Some settings (repository topics, some branch protection options, organization settings) require direct `gh api` calls to the GitHub REST/GraphQL API. The `gh api` subcommand is your escape hatch for anything `gh`'s surface commands don't cover.

---

## Interview Angle

**What they're really testing:** Whether you use the terminal efficiently and can automate GitHub operations — vs. clicking through the GitHub UI for everything.

**Common question forms:**
- "How do you manage PRs from the command line?"
- "How would you automate a GitHub operation across 50 repos?"
- "What's `gh api` used for?"

**The depth signal:** A junior uses the GitHub web interface for everything. A senior has `gh pr create`, `gh pr checkout`, and `gh run watch` in daily use, uses `gh api` with `--jq` for one-off queries and bulk operations, and knows how to use `gh workflow run` to trigger deployments and `gh release create --generate-notes` for automated release publishing.

---

## Related Topics

- [github-repositories.md](github-repositories.md) — `gh repo` manages repositories.
- [github-pull-requests-advanced.md](github-pull-requests-advanced.md) — `gh pr` is the CLI for the PR workflow.
- [github-releases.md](github-releases.md) — `gh release` manages the full release lifecycle.
- [github-actions-advanced.md](github-actions-advanced.md) — `gh workflow run` and `gh run` manage Actions.

---

## Source

[GitHub CLI Documentation](https://cli.github.com/manual/)

---
*Last updated: 2026-04-24*