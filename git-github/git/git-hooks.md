# Git Hooks

> Git hooks are scripts that Git executes automatically before or after events like committing, pushing, or merging — used to enforce standards or automate tasks at the repository level.

---

## When To Use It

Use hooks to enforce things that should never reach code review: lint failures, failing tests, missing commit message format, secrets accidentally staged. Client-side hooks (pre-commit, commit-msg, pre-push) run on the developer's machine; server-side hooks (pre-receive, post-receive) run on the remote. Server-side hooks are authoritative — they can't be bypassed by the developer. Client-side hooks can always be skipped with `--no-verify`, so never treat them as a security boundary.

---

## Core Concept

Hooks live in `.git/hooks/` as executable shell scripts named exactly after the hook event. Because `.git/` isn't tracked by Git, hooks aren't shared with teammates out of the box. The two solutions are: copy hooks into a tracked directory and symlink them, or use a tool like Husky (JavaScript) or pre-commit (Python/multi-language) that manages installation automatically. The most valuable client-side hooks are `pre-commit` (run linters/formatters) and `commit-msg` (enforce message format). The most valuable server-side hook is `pre-receive` (enforce branch protection, run tests, reject bad pushes).

---

## The Code
```bash
# ── Hook file location and setup ─────────────────────────────────────
ls .git/hooks/                # sample hooks live here with .sample extension
cp .git/hooks/pre-commit.sample .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit   # must be executable
```
```bash
# ── pre-commit: run linter before every commit ───────────────────────
#!/bin/bash
# .git/hooks/pre-commit

# Only lint staged .cs files
STAGED_CS=$(git diff --cached --name-only --diff-filter=ACM | grep '\.cs$')

if [ -n "$STAGED_CS" ]; then
  dotnet format --verify-no-changes --include $STAGED_CS
  if [ $? -ne 0 ]; then
    echo "❌ dotnet format failed. Run 'dotnet format' and re-stage."
    exit 1
  fi
fi
exit 0
```
```bash
# ── commit-msg: enforce Conventional Commits format ──────────────────
#!/bin/bash
# .git/hooks/commit-msg

COMMIT_MSG=$(cat "$1")
PATTERN='^(feat|fix|chore|docs|style|refactor|test|ci)(\(.+\))?: .{1,72}$'

if ! echo "$COMMIT_MSG" | grep -qE "$PATTERN"; then
  echo "❌ Commit message format invalid."
  echo "   Expected: feat(scope): short description"
  echo "   Got:      $COMMIT_MSG"
  exit 1
fi
exit 0
```
```bash
# ── pre-push: run tests before push (heavier, use selectively) ───────
#!/bin/bash
# .git/hooks/pre-push

dotnet test --no-build -q
if [ $? -ne 0 ]; then
  echo "❌ Tests failed. Push aborted."
  exit 1
fi
exit 0
```
```bash
# ── Sharing hooks with the team (tracked directory approach) ──────────
mkdir -p .githooks
cp .git/hooks/pre-commit .githooks/pre-commit
chmod +x .githooks/pre-commit

# Configure Git to use the tracked directory
git config core.hooksPath .githooks

# Add to onboarding docs or a Makefile target:
# make setup → git config core.hooksPath .githooks
```
```json
// ── Husky setup (Node.js projects) ───────────────────────────────────
// package.json
{
  "scripts": {
    "prepare": "husky install"
  },
  "devDependencies": {
    "husky": "^9.0.0"
  }
}
```
```bash
# Husky hook file (.husky/pre-commit)
#!/bin/sh
npx lint-staged          # only lint files staged for this commit
```

---

## Gotchas

- **`--no-verify` bypasses all client-side hooks.** Developers under deadline pressure use it freely. Never rely on client-side hooks as the sole enforcement for anything security-critical — that belongs in CI or server-side hooks.
- **Hooks must be executable.** Forgetting `chmod +x` is the #1 reason a hook silently doesn't run. The hook file exists, Git finds it, but nothing happens because it has no execute permission.
- **`core.hooksPath` must be set per-clone.** The setting lives in `.git/config`, not in tracked config files. Either automate it in an onboarding script (`make setup`) or use Husky/pre-commit which handle this automatically.
- **Slow hooks destroy developer experience.** A `pre-commit` hook that takes 30 seconds to run will be `--no-verify`'d immediately. Run only what's fast (lint, format check) in pre-commit. Push heavy work (tests) to CI or optionally to pre-push.
- **Exit code determines whether Git proceeds.** Exit 0 = success, proceed. Any non-zero exit = Git aborts the operation. A hook that crashes with an unhandled error returns a non-zero code and blocks commits until someone debugs the hook itself — test your hooks.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between developer-side enforcement and authoritative enforcement, and how to automate quality gates without friction.

**Common question form:** "How do you enforce code standards across a team?" or "What Git hooks do you use and why?"

**The depth signal:** A junior lists hooks they've used (pre-commit for linting, commit-msg for format). A senior explains why client-side hooks are suggestions (bypassable with `--no-verify`), why server-side `pre-receive` hooks are authoritative, how `core.hooksPath` solves the sharing problem without relying on every developer to manually copy files, and the performance principle: keep pre-commit under 5 seconds or it will be bypassed, pushing real enforcement to CI.

---

## Related Topics

- [[git/git-workflows.md]] — Hooks are the enforcement layer for whatever workflow conventions your team adopts — they turn README guidelines into actual gates.
- [[git/git-bisect.md]] — Good pre-commit and pre-push hooks prevent the bad commits that bisect is used to hunt down.
- [[git/git-branching-strategy.md]] — Branch naming conventions become enforceable with a pre-push hook that validates branch name pattern before allowing the push.
- [[devops/ci-cd-pipelines.md]] — Hooks and CI are complementary: hooks give fast local feedback, CI gives authoritative remote enforcement. Neither replaces the other.

---

## Source

[Git Documentation — githooks](https://git-scm.com/docs/githooks)

---
*Last updated: 2026-03-24*