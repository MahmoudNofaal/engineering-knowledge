# Git Hooks

> Git hooks are scripts that Git executes automatically before or after events like committing, pushing, or merging — used to enforce standards or automate tasks at the repository level.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Executable scripts in `.git/hooks/` triggered by Git lifecycle events |
| **Use when** | Enforcing commit message format, running linters, blocking bad pushes |
| **Avoid when** | Using client-side hooks as a security boundary — they can always be bypassed |
| **Git version** | Core since Git 1.0; `core.hooksPath` added Git 2.9 |
| **Key location** | `.git/hooks/` (local, untracked) or custom path via `core.hooksPath` |
| **Key commands** | `git config core.hooksPath`, `chmod +x`, `git commit --no-verify` (bypass) |

---

## When To Use It

Use hooks to enforce things that should never reach code review: lint failures, failing tests, missing commit message format, secrets accidentally staged. Client-side hooks (pre-commit, commit-msg, pre-push) run on the developer's machine; server-side hooks (pre-receive, post-receive) run on the remote. Server-side hooks are authoritative — they can't be bypassed by the developer. Client-side hooks can always be skipped with `--no-verify`, so never treat them as a security boundary.

---

## Core Concept

Hooks live in `.git/hooks/` as executable shell scripts named exactly after the hook event. Because `.git/` isn't tracked by Git, hooks aren't shared with teammates out of the box. The two solutions are: copy hooks into a tracked directory and symlink them, or use a tool like Husky (JavaScript) or pre-commit (Python/multi-language) that manages installation automatically. The most valuable client-side hooks are `pre-commit` (run linters/formatters) and `commit-msg` (enforce message format). The most valuable server-side hook is `pre-receive` (enforce branch protection, run tests, reject bad pushes).

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | Hooks as `.git/hooks/` shell scripts established |
| Git 1.8.2 | `post-checkout` and `post-merge` hooks added |
| Git 2.9 | `core.hooksPath` added — point to any directory for hooks, enabling team-wide sharing via a tracked folder |
| Git 2.24 | `pre-merge-commit` hook added |
| Git 2.36 | `post-index-change` hook for index monitoring |

*`core.hooksPath` (Git 2.9) is the solution to the "hooks aren't shared" problem. Set it to a tracked directory (`.githooks/`) and every checkout of the repo can use the same hooks. The only remaining step is automating `git config core.hooksPath .githooks` during onboarding — put it in a `Makefile` target or `setup.sh`.*

---

## Performance

| Hook | Acceptable max runtime | Notes |
|---|---|---|
| `pre-commit` | < 5 seconds | Developers bypass slow hooks with `--no-verify` |
| `commit-msg` | < 1 second | Regex check — should be instant |
| `pre-push` | < 30 seconds | Runs tests; longer acceptable but communicate the tradeoff |
| `pre-receive` (server) | No limit (blocking) | Runs on server; can take minutes; developers see the wait |
| `post-receive` (server) | Async is better | Long post-receive tasks should be handed off to a queue |

**Allocation behaviour:** Hooks are shell processes — each hook invocation is a subprocess fork. On fast machines, this is negligible. The bottleneck is always what the hook *does* (linting, test runs) not the hook invocation overhead itself.

**Benchmark notes:** The biggest performance win in hook design is running tools only on staged/changed files rather than the entire codebase. For linting: `git diff --cached --name-only --diff-filter=ACM | grep '\.cs$'` gives you only staged C# files. For large repos with thousands of files, this can reduce lint time from 30 seconds to under 1 second.

---

## The Code

**Hook file location and setup**
```bash
# Sample hooks live here with .sample extension — won't run until renamed
ls .git/hooks/
# applypatch-msg.sample  commit-msg.sample  pre-commit.sample ...

# Enable a sample hook by removing the .sample extension
cp .git/hooks/pre-commit.sample .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit   # must be executable — easy to forget
```

**pre-commit: run linter on staged files only**
```bash
#!/bin/bash
# .git/hooks/pre-commit  (or .githooks/pre-commit)

# Only lint staged .cs files — not the entire codebase
STAGED_CS=$(git diff --cached --name-only --diff-filter=ACM | grep '\.cs$')

if [ -n "$STAGED_CS" ]; then
  echo "Running dotnet format on staged C# files..."
  dotnet format --verify-no-changes --include $STAGED_CS 2>&1
  if [ $? -ne 0 ]; then
    echo ""
    echo "❌ dotnet format failed. Run 'dotnet format' and re-stage the files."
    exit 1
  fi
fi

# Check for debug statements accidentally staged
if git diff --cached | grep -E "^\+" | grep -E "(console\.log|debugger|TODO: remove|FIXME:)" > /dev/null; then
  echo "⚠️  Warning: staged changes contain debug code or TODO markers"
  echo "   Use 'git diff --cached' to review"
  # Non-blocking warning — exit 0 to allow commit
fi

exit 0
```

**commit-msg: enforce Conventional Commits**
```bash
#!/bin/bash
# .git/hooks/commit-msg

COMMIT_MSG=$(cat "$1")
PATTERN='^(feat|fix|chore|docs|style|refactor|test|ci|perf|build|revert)(\(.+\))?(!)?: .{1,72}$'

# Allow merge commits and WIP commits to bypass the pattern
if echo "$COMMIT_MSG" | grep -qE "^(Merge|WIP|Revert)"; then
  exit 0
fi

if ! echo "$COMMIT_MSG" | grep -qE "$PATTERN"; then
  echo ""
  echo "❌ Commit message format invalid."
  echo "   Expected: <type>(<scope>): <description>"
  echo "   Types: feat|fix|chore|docs|style|refactor|test|ci|perf"
  echo "   Example: feat(auth): add JWT refresh token rotation"
  echo ""
  echo "   Got: $COMMIT_MSG"
  echo ""
  exit 1
fi
exit 0
```

**pre-push: run tests before push**
```bash
#!/bin/bash
# .git/hooks/pre-push
# Runs only when pushing to main or release branches

REMOTE="$1"
URL="$2"

while read local_ref local_sha remote_ref remote_sha; do
  # Only enforce on protected branches
  if echo "$remote_ref" | grep -qE "refs/heads/(main|master|release/.*)"; then
    echo "Running test suite before push to protected branch..."
    dotnet test --no-build -q 2>&1
    if [ $? -ne 0 ]; then
      echo "❌ Tests failed. Push to $remote_ref aborted."
      exit 1
    fi
  fi
done

exit 0
```

**Sharing hooks — tracked directory approach**
```bash
# Setup tracked hooks directory
mkdir -p .githooks
cp .git/hooks/pre-commit .githooks/pre-commit
chmod +x .githooks/pre-commit
git add .githooks/
git commit -m "chore: add shared git hooks"

# Configure Git to use the tracked directory (each developer runs this once)
git config core.hooksPath .githooks

# Automate with Makefile or setup script
# Makefile:
setup:
	git config core.hooksPath .githooks
	echo "Git hooks configured ✓"

# Or in package.json scripts for Node.js projects
{
  "scripts": {
    "postinstall": "git config core.hooksPath .githooks"
  }
}
```

**Husky setup (Node.js/npm projects)**
```bash
# Install Husky
npm install --save-dev husky
npx husky install

# Add to package.json
{
  "scripts": {
    "prepare": "husky install"
  }
}

# Create hooks
npx husky add .husky/pre-commit "npx lint-staged"
npx husky add .husky/commit-msg "npx --no -- commitlint --edit \$1"

# lint-staged config in package.json — runs tools only on staged files
{
  "lint-staged": {
    "*.cs": ["dotnet format --include", "git add"],
    "*.{ts,tsx}": ["eslint --fix", "prettier --write", "git add"]
  }
}
```

**pre-receive server-side hook**
```bash
#!/bin/bash
# hooks/pre-receive (server-side — in bare repo)
# Runs on the remote server before accepting any push

while read old_sha new_sha ref; do
  # Block direct pushes to main (require PR workflow)
  if [ "$ref" = "refs/heads/main" ]; then
    # Allow only fast-forward pushes (merges from CI)
    if ! git merge-base --is-ancestor "$old_sha" "$new_sha"; then
      echo "ERROR: Force pushes to main are not allowed."
      echo "       Use a feature branch and pull request."
      exit 1
    fi
  fi

  # Block commits with WIP in the message on protected branches
  if echo "$ref" | grep -qE "refs/heads/(main|release/.*)"; then
    git log --format="%s" "$old_sha..$new_sha" | grep -qi "^WIP" && {
      echo "ERROR: WIP commits cannot be pushed to $ref"
      exit 1
    }
  fi
done

exit 0
```

---

## Real World Example

A backend team of 12 engineers was spending an average of 3 hours per week on review comments about formatting and commit message style — purely mechanical feedback that shouldn't require human review time. They implemented a three-hook system that eliminated all style-related review comments within two weeks.

```bash
# The three hooks:
# 1. pre-commit: auto-format (not just check — actually fix and re-stage)
# 2. commit-msg: enforce Conventional Commits
# 3. pre-push: block WIP commits on main-targeting pushes

# Pre-commit with auto-fix (not just verify)
cat > .githooks/pre-commit << 'EOF'
#!/bin/bash
set -e

STAGED_CS=$(git diff --cached --name-only --diff-filter=ACM | grep '\.cs$')

if [ -n "$STAGED_CS" ]; then
  # Auto-format instead of just checking
  dotnet format --include $(echo $STAGED_CS | tr '\n' ' ')

  # Re-stage the formatted files
  echo "$STAGED_CS" | xargs git add

  echo "✓ dotnet format applied and files re-staged"
fi

# Secrets detection — check for common patterns
if git diff --cached | grep -E "^\+" | grep -iE "(password|secret|api_key|token)\s*=\s*['\"][^'\"]{8,}" > /dev/null 2>&1; then
  echo "❌ Possible secret detected in staged changes."
  echo "   Review with 'git diff --cached' before committing."
  exit 1
fi

exit 0
EOF

# Result after 2 weeks:
# - 0 formatting review comments (was averaging 8/PR)
# - 100% conventional commit compliance (was ~40%)
# - 3 potential secret leaks caught before they reached the remote
# - Developer feedback: "It just works. I forget the hooks are even there."
```

*The key insight: auto-fix hooks (format and re-stage) are far better than check-and-fail hooks for style enforcement. Failing the commit and telling the developer to run a command adds friction. Silently fixing and re-staging the change adds zero friction — the developer doesn't even notice.*

---

## Common Misconceptions

**"Client-side hooks enforce team standards"**
Client-side hooks are suggestions, not enforcement. Any developer can bypass them with `git commit --no-verify` or `git push --no-verify`. They can also be corrupted, misconfigured, or simply not set up on new machines. Real enforcement requires server-side hooks (pre-receive) or CI pipeline checks. Client-side hooks are for fast local feedback, not authoritative gatekeeping.

**"Hooks in `.git/hooks/` are shared when you clone"**
`.git/` is not tracked by Git — it's never cloned. When a new developer clones the repo, their `.git/hooks/` contains only the default `.sample` files. The actual hooks the team uses are invisible to them until they manually configure `core.hooksPath` or run a setup script. This is why hook setup automation (Makefile, npm `prepare` script, Husky) is not optional for team adoption.

**"A slow pre-commit hook is fine because it only runs on commit"**
A pre-commit hook that takes 30 seconds will be bypassed with `--no-verify` by every developer under deadline pressure — within the first week. The utility of a hook is inversely proportional to its friction. If your linting takes more than 5 seconds, scope it to staged files only, parallelize it, or move it to pre-push or CI.

---

## Gotchas

- **`--no-verify` bypasses all client-side hooks.** Developers under deadline pressure use it freely. Never rely on client-side hooks as the sole enforcement for anything security-critical.

- **Hooks must be executable.** Forgetting `chmod +x` is the #1 reason a hook silently doesn't run. The hook file exists, Git finds it, but nothing happens because it has no execute permission.

- **`core.hooksPath` must be set per-clone.** The setting lives in `.git/config`, not in tracked config files. Either automate it in an onboarding script or use Husky/pre-commit which handle this automatically.

- **Slow hooks destroy developer experience.** Run only what's fast (lint, format check) in pre-commit. Push heavy work (full test suite) to CI or optionally to pre-push with clear communication about the tradeoff.

- **Exit code determines whether Git proceeds.** Exit 0 = success, proceed. Any non-zero exit = Git aborts the operation. A hook that crashes with an unhandled error returns a non-zero code and blocks commits until someone debugs the hook itself — always test your hooks before deploying them.

- **Windows path handling breaks shell scripts.** If your team includes Windows developers, shell-based hooks require Git Bash or WSL. Consider cross-platform hook tools (Husky, pre-commit) for mixed-OS teams.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between developer-side enforcement and authoritative enforcement, and how to automate quality gates without friction.

**Common question forms:**
- "How do you enforce code standards across a team?"
- "What Git hooks do you use and why?"
- "What's the difference between a pre-commit hook and a pre-receive hook?"

**The depth signal:** A junior lists hooks they've used (pre-commit for linting, commit-msg for format). A senior explains why client-side hooks are suggestions (bypassable with `--no-verify`), why server-side `pre-receive` hooks are authoritative, how `core.hooksPath` solves the sharing problem without relying on every developer to manually copy files, and the performance principle: keep pre-commit under 5 seconds or it will be bypassed — pushing real enforcement to CI or server-side hooks.

**Follow-up questions to expect:**
- "How do you share hooks across a team?"
- "What happens if a developer uses `--no-verify`? Is there a backup enforcement?"

---

## Related Topics

- [git-workflows.md](git-workflows.md) — Hooks are the enforcement layer for whatever workflow conventions your team adopts.
- [git-commits.md](git-commits.md) — commit-msg hooks enforce the commit message format that makes `git log`, `git bisect`, and changelogs useful.
- [git-branching-strategy.md](git-branching-strategy.md) — Branch naming conventions become enforceable with a pre-push hook that validates the pattern before allowing the push.
- [github-actions-integration.md](github-actions-integration.md) — Hooks and CI are complementary: hooks give fast local feedback, CI gives authoritative remote enforcement.

---

## Source

[Git Documentation — githooks](https://git-scm.com/docs/githooks)

---
*Last updated: 2026-04-24*