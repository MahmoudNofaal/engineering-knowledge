# GitHub Discussions

> GitHub Discussions is a community forum built into a repository or organisation — supporting threaded Q&A, announcements, open-ended conversations, and polls that don't fit the structured format of issues.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A forum-style discussion system integrated with GitHub repos and orgs |
| **Use when** | Q&A, feature brainstorming, announcements, RFCs, community conversation |
| **Avoid when** | Actionable tasks or bug reports — those belong in Issues |
| **Key difference from Issues** | Discussions are open-ended conversations; Issues are actionable work items with lifecycle |
| **Key features** | Categories, Q&A format (mark answer), polls, announcements, convert to issue |
| **Enable** | Settings → Features → Discussions |

---

## Core Concept

The core distinction between Discussions and Issues is actionability. An issue has a lifecycle: open → in progress → closed (resolved). A discussion is a conversation that may or may not lead to action — a question gets answered, a brainstorm produces ideas, an RFC gets community feedback. GitHub Discussions prevents issues from being used as a general-purpose forum (which clutters the issue tracker with unanswerable or open-ended content) while providing a first-class space for community and team conversation that's searchable, categorised, and integrated with the repo.

---

## The Code

**Setting up discussion categories**
```
# Recommended category structure for a software project:

📣 Announcements     (allow only maintainers to post)
   - Release notes, important updates, policy changes

❓ Q&A               (Q&A format — answers can be marked)
   - How do I...?, Why does...?, What's the best way to...?

💡 Ideas             (open-ended)
   - Feature suggestions, architectural ideas, RFC pre-discussion

🛠️ Show and Tell     (open-ended)
   - What are you building with this? Community projects.

💬 General           (open-ended)
   - Everything else that doesn't fit other categories

🗳️ Polls             (poll format)
   - Team decisions, community preference gathering
```

**Working with discussions via API**
```bash
# List all open discussions
gh api graphql -f query='
  query($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
      discussions(first: 20, orderBy: {field: CREATED_AT, direction: DESC}) {
        nodes {
          number
          title
          category { name }
          author { login }
          createdAt
          answer { body }
        }
      }
    }
  }
' -f owner=org -f repo=repo

# Create a discussion via API (GraphQL only — no REST for discussions)
gh api graphql -f query='
  mutation($repoId: ID!, $categoryId: ID!, $title: String!, $body: String!) {
    createDiscussion(input: {
      repositoryId: $repoId
      categoryId: $categoryId
      title: $title
      body: $body
    }) {
      discussion { number url }
    }
  }
' \
  -f repoId=R_abc123 \
  -f categoryId=DIC_def456 \
  -f title="RFC: Switch from REST to GraphQL for internal API" \
  -f body="$(cat rfc-graphql.md)"

# Convert a discussion to an issue (when action is needed)
# Available in the GitHub UI: Discussion → Convert to Issue
# Via API:
gh api graphql -f query='
  mutation($discussionId: ID!) {
    convertDiscussionToIssue(input: { discussionId: $discussionId }) {
      issue { number url }
    }
  }
' -f discussionId=D_ghi789
```

**Announcement-only category**
```bash
# Set a category so only maintainers can post (community reads, maintainers announce)
# Configure: Discussion Settings → Categories → Announcements → Only maintainers can post

# Use case: release notes, policy changes, breaking change notices
# Members can still comment and react — just can't start new discussions in that category
```

**Q&A format — mark an answer**
```
# In a Q&A category discussion, the original poster (or maintainers) can mark
# one comment as "the answer" — it gets pinned to the top and the discussion
# is marked as "answered"

# This creates a searchable FAQ: future users searching for the same question
# see the accepted answer immediately without reading the thread

# Good for: "how do I configure X", "what's the difference between X and Y",
#            "why does this error happen"
```

**Polls**
```bash
# Polls are created via the GitHub UI (no API support yet)
# Settings → Discussions → Create → Polls category
# Options: multiple choice, single choice
# Visibility: all participants can see results in real time

# Good use cases:
# - "Which API style should we use for v3? (REST / GraphQL / gRPC)"
# - "What's the team's preferred release cadence?"
# - "Priority for next quarter: performance / reliability / new features?"
```

---

## Real World Example

An open source library was using Issues for everything — bug reports, feature requests, questions ("how do I...?"), and general discussion. The issue tracker had 847 open issues, 600 of which were unanswered questions or vague enhancement requests. Triaging took 3 hours/week. After enabling Discussions and migrating question-type issues to Q&A Discussions:

```
Before:
- Issues: 847 open (600 were questions/vague)
- Triage time: 3 hours/week
- Maintainer frustration: high (most "issues" weren't actionable)

After (3 months):
- Issues: 89 open (all are specific, reproducible bugs or accepted features)
- Discussions: 312 threads, 247 marked as answered
- Triage time: 45 min/week
- Community engagement: up (discussions feel less "formal" than issues)

Key changes:
1. Issue template config.yml redirects questions to Discussions
2. Maintainers close any issue that's a question with: 
   "This looks like a question — please move to Discussions: [link]"
3. Q&A Discussions answered by maintainers are marked "answered"
   → They appear in GitHub search as resolved Q&A
4. Popular questions pinned in Q&A category
```

---

## Common Misconceptions

**"Discussions are just Issues with a different label"**
Discussions and Issues have fundamentally different semantics and UI. Issues have: open/closed state, assignment, milestones, labels, and appear in project boards. Discussions have: categories, Q&A format (markable answer), polls, and community-oriented features. The key difference is that Issues drive work; Discussions drive conversation.

**"Enabling Discussions replaces the issue tracker"**
They're complementary. Issues for bugs and confirmed features; Discussions for questions, ideas, and community. Many projects use both: Discussions as the "front door" for questions and exploration, Issues for confirmed work. The conversion feature (Discussion → Issue) is the bridge: a discussion that produces a clear action item can be converted to an issue.

---

## Related Topics

- [github-issues.md](github-issues.md) — Issues for actionable, lifecycle-managed work items.
- [github-repositories.md](github-repositories.md) — Discussions is enabled at the repository settings level.
- [github-pull-requests-advanced.md](github-pull-requests-advanced.md) — PRs can reference discussions; RFCs in discussions often lead to PRs.

---

## Source

[GitHub Docs — About Discussions](https://docs.github.com/en/discussions/collaborating-with-your-community-using-discussions/about-discussions)

---
*Last updated: 2026-04-24*