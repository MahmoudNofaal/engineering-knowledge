# GitHub Projects

> GitHub Projects (v2) is a flexible project management tool that aggregates issues and PRs from any repository into a table, board, or roadmap view with custom fields, filters, and workflow automation.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A project management layer on top of GitHub issues and PRs — table, board, and roadmap views |
| **Version** | Projects v2 (2022+) — significantly more powerful than the original Projects |
| **Use when** | Planning sprints, tracking epics, visualising cross-repo work, managing team backlogs |
| **Avoid when** | You need Gantt charts, time tracking, or advanced resource management — use Jira/Linear |
| **Key features** | Custom fields, multiple views, automation, cross-repo, organisation-level projects |
| **Key commands** | `gh project create`, `gh project item-add`, `gh project list`, `gh project view` |

---

## Core Concept

GitHub Projects v2 is built on a database model: every issue and PR added to a project becomes a row, and you add custom fields (text, number, date, single-select, iteration) as columns. Unlike the original Projects, v2 supports: multiple views of the same data (table, board, roadmap, all on the same underlying dataset), cross-repository items (items from any repo in the org), organisation-level projects (not just per-repo), saved filters and field grouping, and built-in workflow automation (auto-add items, auto-set status on PR merge). The project is the source of truth for planning; the issues/PRs remain in their repositories.

---

## Version History

| Year | Feature |
|---|---|
| 2016 | GitHub Projects v1 — basic kanban board per repo |
| 2022 | Projects v2 beta — new database model, custom fields |
| 2022 | Projects v2 GA — table view, board view, custom fields |
| 2023 | Roadmap view (timeline), iteration fields, project workflows |
| 2024 | Project templates, bulk editing, sub-issues (beta) |

---

## The Code

**Creating and managing projects**
```bash
# Create an organisation-level project
gh project create \
  --owner myorg \
  --title "Q2 2026 Engineering Roadmap" \
  --format json

# Create a user-level project
gh project create \
  --owner @me \
  --title "Personal backlog"

# List projects
gh project list --owner myorg

# View a project
gh project view 5 --owner myorg

# Add an issue to a project
gh project item-add 5 \
  --owner myorg \
  --url https://github.com/org/repo/issues/89

# Add a PR to a project
gh project item-add 5 \
  --owner myorg \
  --url https://github.com/org/repo/pull/142
```

**Custom fields via API**
```bash
# Projects v2 is primarily managed via GraphQL API

# Get project ID and field IDs
gh api graphql -f query='
  query($org: String!, $number: Int!) {
    organization(login: $org) {
      projectV2(number: $number) {
        id
        fields(first: 20) {
          nodes {
            ... on ProjectV2Field {
              id
              name
              dataType
            }
            ... on ProjectV2SingleSelectField {
              id
              name
              options { id name }
            }
          }
        }
      }
    }
  }
' -f org=myorg -F number=5

# Update a custom field value on a project item
gh api graphql -f query='
  mutation($project: ID!, $item: ID!, $field: ID!, $value: String!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $project
      itemId: $item
      fieldId: $field
      value: { text: $value }
    }) {
      projectV2Item { id }
    }
  }
' -f project=PVT_abc123 -f item=PVTI_def456 -f field=PVTF_ghi789 -f value="In Progress"
```

**Workflow automation**
```yaml
# Built-in automations (configured in UI: Project Settings → Workflows):
# "Auto-add to project" — when an issue/PR is created in a repo, add it to the project
# "Item closed" — when issue is closed, set Status to "Done"
# "Pull request merged" — when PR merges, set Status to "Done"
# "Pull request opened" — set Status to "In Progress"
# "Code review requested" — set Status to "In Review"

# Custom automation via Actions (for workflows not covered by built-in)
# .github/workflows/project-automation.yml
name: Add to Project

on:
  issues:
    types: [opened, labeled]
  pull_request:
    types: [opened]

jobs:
  add-to-project:
    if: github.event.label.name == 'needs-triage' || github.event_name == 'issues'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/add-to-project@v1
        with:
          project-url: https://github.com/orgs/myorg/projects/5
          github-token: ${{ secrets.ADD_TO_PROJECT_PAT }}
          # Requires a PAT with project scope — GITHUB_TOKEN doesn't have it
```

**Useful project queries via GraphQL**
```bash
# Get all items in a project with their status
gh api graphql -f query='
  query($org: String!, $number: Int!) {
    organization(login: $org) {
      projectV2(number: $number) {
        items(first: 100) {
          nodes {
            id
            content {
              ... on Issue {
                title
                number
                state
                repository { name }
              }
              ... on PullRequest {
                title
                number
                state
                repository { name }
              }
            }
            fieldValues(first: 10) {
              nodes {
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                  field { ... on ProjectV2SingleSelectField { name } }
                }
                ... on ProjectV2ItemFieldTextValue {
                  text
                  field { ... on ProjectV2Field { name } }
                }
              }
            }
          }
        }
      }
    }
  }
' -f org=myorg -F number=5 | \
  jq '.data.organization.projectV2.items.nodes[] | {
    title: .content.title,
    repo: .content.repository.name,
    status: (.fieldValues.nodes[] | select(.field.name == "Status") | .name)
  }'
```

**Sprint/iteration planning setup**
```
# Recommended custom fields for a sprint board:

# 1. Status (single-select)
#    Options: Backlog, Ready, In Progress, In Review, Done

# 2. Priority (single-select)
#    Options: P0 - Critical, P1 - High, P2 - Medium, P3 - Low

# 3. Sprint (iteration field)
#    - Set sprint length (e.g., 2 weeks)
#    - GitHub auto-advances iterations

# 4. Story Points (number field)
#    For effort estimation

# 5. Team (single-select)
#    If project spans multiple teams

# Views to create:
# - "Sprint Board" (board view, grouped by Status, filtered to current sprint)
# - "Backlog" (table view, grouped by Priority, no sprint filter)
# - "Roadmap" (timeline view, grouped by Team, date field = Sprint end date)
# - "By Team" (table view, grouped by Team, current sprint)
```

---

## Real World Example

A 40-person engineering department had four squads, each using a different project management tool (Jira, Trello, Notion, GitHub Issues). Cross-squad dependencies were invisible, and engineering managers couldn't get a single view of all engineering work. They migrated to a single GitHub Organisation Project with per-squad views.

```bash
# One org-level project: "Engineering — All Work"
# URL: https://github.com/orgs/myorg/projects/1

# Custom fields:
# - Status: Backlog / Ready / In Progress / In Review / Blocked / Done
# - Squad: Platform / Payments / Frontend / Mobile
# - Priority: P0 / P1 / P2 / P3
# - Sprint: (iteration field, 2-week sprints)
# - Effort: (number, story points)

# Four views (each squad's "board"):
# 1. Platform Board: Status=Kanban, filter=Squad:Platform, sprint=current
# 2. Payments Board: Status=Kanban, filter=Squad:Payments, sprint=current
# 3. Frontend Board: Status=Kanban, filter=Squad:Frontend, sprint=current
# 4. Mobile Board: Status=Kanban, filter=Squad:Mobile, sprint=current

# Two management views:
# 5. All Work - Table: all items, grouped by Squad, sorted by Priority
# 6. Roadmap: timeline view, grouped by Squad, shows sprint-level planning

# Auto-add items from all repos in the org:
# Project Settings → Workflows → "Auto-add to project"
# When: issue labeled "tracked" → add to project
# When: PR opened targeting main in any org repo → add to project

# Result:
# - Single source of truth across 4 squads
# - Cross-squad blocking visible in "All Work" view
# - Engineering managers get roadmap without asking individual squads
# - No migration cost — issues stay in repos, project aggregates them
```

---

## Common Misconceptions

**"Projects v2 replaced Projects v1"**
Projects v2 and v1 can coexist on the same repository. v2 is the modern, recommended system; v1 (the simple kanban board per-repo) is legacy but not removed. If you see "Projects (classic)" in the UI, that's v1. New projects should always be created as v2.

**"You need to move issues into the project"**
Issues and PRs remain in their repositories — the project doesn't "contain" them, it aggregates them. An issue in `org/payments-service` repo is still filed there; the project simply references it. Closing the issue in the repo is reflected in the project immediately. You can add the same issue to multiple projects.

**"GitHub Projects competes with Jira"**
For simple to medium project management, GitHub Projects v2 is competitive. For complex enterprise PM (time tracking, resource planning, custom Gantt, advanced reporting, fine-grained permission models), Jira has much deeper features. The decision is usually: if your team lives in GitHub, start with Projects; add Jira if you hit specific limitations.

---

## Gotchas

- **Project automation requires a PAT, not `GITHUB_TOKEN`.** The built-in `GITHUB_TOKEN` in Actions doesn't have project scope. You need a Personal Access Token (PAT) with `project` scope to add items programmatically. Store it as a repository secret.

- **Archived items are hidden from views but not deleted.** "Archiving" a project item removes it from the board/table view but keeps it in the project's database. Use "remove from project" to actually delete the association.

- **Roadmap view requires a date field.** The roadmap (timeline) view needs a date or iteration field to know where to position items on the timeline. Without it, items float at the top without dates.

- **Cross-repo items don't appear in the repo's Issues tab.** If you add an issue from another repo to your project, it appears in the project but not in your repo. This is correct — the issue lives in its origin repo.

---

## Interview Angle

**What they're really testing:** Whether you can design a project management system for a team using GitHub-native tools — and know the limits of GitHub Projects vs dedicated PM tools.

**Common question forms:**
- "How do you manage sprint planning in GitHub?"
- "How do you get visibility into work across multiple repositories?"
- "When would you use GitHub Projects vs Jira?"

**The depth signal:** A junior knows GitHub has a Projects feature. A senior knows v2's database model (custom fields, multiple views on same data), cross-repository aggregation, automation limitations (PAT required, not `GITHUB_TOKEN`), and when to recommend GitHub Projects (simpler workflows, GitHub-native teams) vs Jira (complex enterprise needs, time tracking, advanced reporting).

---

## Related Topics

- [github-issues.md](github-issues.md) — Issues are the primary items in GitHub Projects.
- [github-pull-requests-advanced.md](github-pull-requests-advanced.md) — PRs can also be project items.
- [github-actions-advanced.md](github-actions-advanced.md) — Actions can automate project management (adding items, updating fields).

---

## Source

[GitHub Docs — About GitHub Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects)

---
*Last updated: 2026-04-24*