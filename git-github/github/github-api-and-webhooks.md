# GitHub API & Webhooks

> The GitHub API (REST and GraphQL) provides programmatic access to all GitHub resources; webhooks push event notifications to your systems when things happen in GitHub.

---

## Quick Reference

| | |
|---|---|
| **REST API** | `https://api.github.com` — resource-oriented, well-documented, simpler |
| **GraphQL API** | `https://api.github.com/graphql` — fetch exactly what you need in one request |
| **Webhooks** | HTTP POST events pushed to your URL on GitHub events (push, PR, issue, etc.) |
| **Authentication** | PAT (Personal Access Token), GitHub App token, `GITHUB_TOKEN` in Actions |
| **Rate limits** | 5,000 req/hour (PAT/OAuth), 15,000 req/hour (GitHub App), 1,000 req/hour (unauthenticated) |
| **Best for scripts** | `gh api` CLI wraps the REST API with auth handled automatically |

---

## Core Concept

The GitHub API gives you programmatic access to everything in the GitHub UI — repos, PRs, issues, releases, Actions, and more. REST API: simple, resource-based (`GET /repos/org/repo/pulls`), returns full objects. GraphQL API: request exactly the fields you need in one query, avoiding over-fetching and multiple round-trips. Webhooks: instead of polling the API, GitHub pushes events to your server when things happen — a push event when code is committed, a `pull_request` event when a PR is opened, a `workflow_run` event when CI completes.

---

## The Code

**REST API via `gh api`**
```bash
# GET — list resources
gh api repos/org/repo/pulls --jq '.[].number'
gh api repos/org/repo/issues?state=open&labels=bug

# POST — create resources
gh api repos/org/repo/issues \
  --method POST \
  --field title="Bug: null ref in cart" \
  --field body="Steps: ..." \
  --field labels='["bug","high-priority"]'

# PATCH — update resources
gh api repos/org/repo/issues/89 \
  --method PATCH \
  --field state=closed

# DELETE — remove resources
gh api repos/org/repo/issues/comments/12345 --method DELETE

# Pagination — get all results
gh api repos/org/repo/commits --paginate \
  --jq '.[].sha'

# Use query parameters
gh api 'repos/org/repo/commits?per_page=100&since=2026-01-01T00:00:00Z'
```

**GraphQL API — fetch exactly what you need**
```bash
# GraphQL: one request, exactly the fields you need
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        title
        state
        author { login }
        reviewDecision
        reviews(last: 10) {
          nodes {
            author { login }
            state
            submittedAt
          }
        }
        commits(last: 1) {
          nodes {
            commit {
              statusCheckRollup {
                state
                contexts(last: 10) {
                  nodes {
                    ... on CheckRun {
                      name
                      conclusion
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
' -f owner=org -f repo=repo -F number=142

# vs REST: would require 3-4 separate API calls for the same data
```

**Authentication options**
```bash
# 1. Personal Access Token (PAT) — simplest, scoped to user
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
gh api repos/org/repo/pulls  # gh uses GITHUB_TOKEN automatically

# Fine-grained PAT (recommended over classic PAT):
# - Scoped to specific repos
# - Specific permissions (read/write per resource type)
# - Expiry date
# Create: Settings → Developer settings → Personal access tokens → Fine-grained tokens

# 2. GitHub App — for production integrations
# Higher rate limits, installation-level permissions, audit trail
# Each installation gets a short-lived token
# Use libraries: Octokit.net (.NET), @octokit/app (JS)

# 3. GITHUB_TOKEN — automatic in GitHub Actions
# Available as ${{ secrets.GITHUB_TOKEN }}
# Scoped to the current repo, expires when workflow ends
# Permissions declared in workflow:
permissions:
  contents: read
  pull-requests: write
  issues: write
```

**Webhooks — receive GitHub events**
```python
# Webhook receiver (Python/Flask example)
import hmac, hashlib, json
from flask import Flask, request, abort

app = Flask(__name__)
WEBHOOK_SECRET = "your-webhook-secret"

@app.route("/github-webhook", methods=["POST"])
def webhook():
    # 1. Verify the signature (ALWAYS do this)
    signature = request.headers.get("X-Hub-Signature-256", "")
    expected = "sha256=" + hmac.new(
        WEBHOOK_SECRET.encode(),
        request.data,
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(signature, expected):
        abort(403, "Invalid signature")

    # 2. Get the event type
    event = request.headers.get("X-GitHub-Event")
    payload = json.loads(request.data)

    # 3. Handle specific events
    if event == "pull_request":
        action = payload["action"]  # opened, closed, merged, reviewed, etc.
        pr_number = payload["pull_request"]["number"]
        repo = payload["repository"]["full_name"]

        if action == "opened":
            print(f"PR #{pr_number} opened in {repo}")
            # Trigger your custom automation

        elif action == "closed" and payload["pull_request"]["merged"]:
            print(f"PR #{pr_number} merged in {repo}")
            # Trigger deployment pipeline

    elif event == "push":
        branch = payload["ref"].replace("refs/heads/", "")
        commits = len(payload["commits"])
        print(f"{commits} commits pushed to {branch}")

    return "", 200
```

```bash
# Configure webhook via CLI
gh api repos/org/repo/hooks \
  --method POST \
  --field name=web \
  --field active=true \
  --field events='["push","pull_request","issues"]' \
  --field config.url="https://your-server.com/github-webhook" \
  --field config.content_type=json \
  --field config.secret="your-webhook-secret"

# List webhooks
gh api repos/org/repo/hooks

# Redeliver a webhook (for debugging)
gh api repos/org/repo/hooks/HOOK_ID/deliveries \
  --jq '.[0].id' | \
  xargs -I{} gh api repos/org/repo/hooks/HOOK_ID/deliveries/{}/attempts \
    --method POST
```

**GitHub Apps — production-grade integrations**
```csharp
// .NET example using Octokit.net
using Octokit;

// Generate a JWT for GitHub App authentication
var generator = new GitHubJwt.GitHubJwtFactory(
    new GitHubJwt.FilePrivateKeySource("/path/to/private-key.pem"),
    new GitHubJwt.GitHubJwtFactoryOptions
    {
        AppIntegrationId = 12345,   // your GitHub App ID
        ExpirationSeconds = 600
    }
);

var jwtToken = generator.CreateEncodedJwtToken();

// Exchange JWT for installation token
var client = new GitHubClient(new ProductHeaderValue("MyApp"))
{
    Credentials = new Credentials(jwtToken, AuthenticationType.Bearer)
};

var installations = await client.GitHubApps.GetAllInstallationsForCurrent();
var installationToken = await client.GitHubApps.CreateInstallationToken(installations[0].Id);

// Use installation token for API calls
var appClient = new GitHubClient(new ProductHeaderValue("MyApp"))
{
    Credentials = new Credentials(installationToken.Token)
};

var prs = await appClient.PullRequest.GetAllForRepository("org", "repo");
```

---

## Common Misconceptions

**"REST and GraphQL are interchangeable"**
They have different strengths. REST: simpler, well-understood, good for single-resource operations, better caching. GraphQL: efficient for fetching related data (PRs + their reviews + CI status in one request), avoids over-fetching, better for dashboard/reporting use cases. GitHub's REST API is more complete (some resources only exist in REST); GraphQL has better efficiency for complex queries.

**"PATs are suitable for production integrations"**
PATs are tied to a user account — if that user leaves, the integration breaks. For production: use GitHub Apps (installation-scoped tokens, not user-scoped, higher rate limits, proper audit trail) or OIDC (for CI/CD). PATs are appropriate for personal scripts and development tooling, not production systems.

**"Webhooks deliver events exactly once"**
GitHub webhooks guarantee at-least-once delivery — if your endpoint doesn't respond with 2xx, GitHub retries up to 3 times over several hours. Your webhook handler must be idempotent: processing the same event twice shouldn't cause double-actions. Use the delivery ID (`X-GitHub-Delivery` header) to detect and skip duplicates.

---

## Gotchas

- **Always verify webhook signatures.** `X-Hub-Signature-256` must be checked before processing. An endpoint without signature verification accepts requests from anyone — a critical security hole.

- **Rate limits are per-token, not per-IP.** All requests using the same PAT share the rate limit. For high-volume integrations, use GitHub Apps (15,000 req/hour per installation).

- **Webhooks time out after 10 seconds.** If your handler takes longer, GitHub marks it as failed and retries. For long-running operations, respond immediately with 200 and process asynchronously (queue the event, process in background).

- **GraphQL queries count against rate limits differently.** GraphQL has a separate "points" system based on query complexity, not request count. A single complex GraphQL query can cost 10–100 rate limit points.

---

## Related Topics

- [github-actions-advanced.md](github-actions-advanced.md) — `GITHUB_TOKEN` and OIDC are the Actions-native authentication mechanisms.
- [github-repositories.md](github-repositories.md) — Webhooks are configured at the repository or organisation level.
- [github-security-features.md](github-security-features.md) — GitHub Apps and fine-grained PATs are more secure than classic PATs.

---

## Source

[GitHub REST API Documentation](https://docs.github.com/en/rest) | [GitHub GraphQL API](https://docs.github.com/en/graphql)

---
*Last updated: 2026-04-24*