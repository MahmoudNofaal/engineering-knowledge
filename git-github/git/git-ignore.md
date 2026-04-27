# Git Ignore

> `.gitignore` is a configuration file that tells Git which files and directories to leave untracked — preventing build artifacts, secrets, and OS clutter from entering version control.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A pattern file that tells Git which paths to treat as if they don't exist |
| **Use when** | Any file that shouldn't be tracked: build outputs, secrets, IDE files, OS files |
| **Avoid when** | Trying to remove files already committed — `.gitignore` only affects untracked files |
| **Git version** | Core since Git 1.0; `.git/info/exclude` since Git 1.0; global ignore since Git 1.5.6 |
| **Key location** | `.gitignore` (repo-level), `~/.gitignore` (global), `.git/info/exclude` (local, unshared) |
| **Key commands** | `git check-ignore -v`, `git rm --cached`, `git status --ignored` |

---

## When To Use It

Use `.gitignore` immediately when creating a repo — before the first commit. Add patterns for your language's build output, your IDE's workspace files, OS-generated files, and any environment-specific files (`.env`, credentials). Never rely on `.gitignore` for secret management — it only prevents accidental staging of untracked files; it does nothing if the file was ever committed.

---

## Core Concept

Git has four places where ignore rules live, evaluated in order: `.gitignore` files at any directory level (tracked, shared with team), `.git/info/exclude` (local, unshared — for personal ignores), the global gitignore file (`~/.gitignore` or configured via `core.excludesFile`), and built-in Git patterns. When Git evaluates whether to show a file in `git status`, it checks all four layers. The most specific rule wins — a rule in a deeper `.gitignore` takes priority over a rule in a parent directory. Negation patterns (`!`) re-include files that a broader pattern excluded.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | `.gitignore` and `.git/info/exclude` established |
| Git 1.5.6 | Global `core.excludesFile` config added |
| Git 1.8.2 | `git check-ignore` added — debug which rule is ignoring a file |
| Git 2.0 | Directory-level `.gitignore` precedence clarified |
| Git 2.7 | `git status --ignored` improved output modes |
| Git 2.28 | `--pathspec-from-file` improved for large ignore lists |

*GitHub maintains a repository of `.gitignore` templates at [github.com/github/gitignore](https://github.com/github/gitignore) — one for every major language and framework. Using these as a starting point prevents the "forgot to ignore node_modules" problems that plague every new project.*

---

## Performance

| Scenario | Performance impact |
|---|---|
| Large `node_modules/` not ignored | `git status` takes 10–30 seconds on every run |
| Build output (`bin/`, `obj/`) not ignored | `git add .` stages thousands of unwanted files |
| `.gitignore` with many patterns on large repo | Small CPU cost per pattern per file; negligible in practice |
| `git status --ignored` | Scans all ignored files — slow on repos with large ignored dirs |

**Allocation behaviour:** `.gitignore` is read fresh on every Git operation that needs to evaluate paths. It's a plain text file — no caching, no preprocessing. Performance impact is O(patterns × files evaluated). In practice, Git's internal optimisation makes this negligible unless you have thousands of patterns.

**Benchmark notes:** The single biggest performance win from `.gitignore` is keeping large directories like `node_modules/`, `.gradle/`, `bin/`, `obj/`, and `__pycache__/` out of the tracked file set. `git status` on a Node.js project that forgot to ignore `node_modules/` (200,000 files) can take 30+ seconds. With the ignore in place: under 0.1 seconds.

---

## The Code

**Basic patterns**
```gitignore
# Comments start with #

# Ignore a specific file
.env
secrets.json
*.pem

# Ignore a file type everywhere in the repo
*.log
*.tmp
*.DS_Store

# Ignore a directory and all its contents
node_modules/
bin/
obj/
dist/
build/
.gradle/

# Ignore files in a specific directory only (relative path)
src/generated/
tools/cache/
```

**Pattern syntax**
```gitignore
# * matches anything except /
*.log           # matches any .log file in any directory
/TODO           # matches TODO only in repo root (not src/TODO)
doc/*.txt       # matches doc/notes.txt but not doc/server/notes.txt

# ** matches across directories
logs/**         # matches everything inside logs/
**/logs         # matches logs/ anywhere in the repo
**/logs/*.log   # matches any .log in any logs/ directory

# ? matches any single character (except /)
?.txt           # matches a.txt, b.txt, etc.

# Ranges
*.[oa]          # matches .o and .a files (compiled/archive)

# Negation — re-include a file excluded by a broader pattern
*.log           # ignore all .log files
!important.log  # except this one

# Ignore everything in a directory, but keep the directory itself
logs/*
!logs/.gitkeep  # the .gitkeep file keeps the empty directory in Git
```

**Common real-world `.gitignore` patterns**

```gitignore
# === .NET / C# ===
bin/
obj/
*.user
*.suo
.vs/
*.nupkg
publish/

# === Node.js ===
node_modules/
npm-debug.log*
yarn-error.log
.npm
dist/
.cache/

# === Python ===
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
dist/
*.pyc

# === Environment and secrets ===
.env
.env.*
!.env.example     # keep the template
*.pem
*.key
secrets/

# === OS files ===
.DS_Store         # macOS
Thumbs.db         # Windows
Desktop.ini       # Windows
.Spotlight-V100/  # macOS

# === IDE files ===
.idea/            # JetBrains
*.iml
.vscode/          # VS Code (often kept — depends on team preference)
*.sublime-project
*.sublime-workspace

# === CI/temp ===
.nyc_output/
coverage/
TestResults/
*.trx
```

**Debugging ignored files**
```bash
# Why is this file being ignored?
git check-ignore -v src/generated/output.cs
# .gitignore:12:src/generated/   src/generated/output.cs
# (file:line:pattern  matched-path)

# List all currently ignored files
git status --ignored

# Is this specific file ignored?
git check-ignore -v path/to/file.txt
# Exit code 0 = ignored, exit code 1 = not ignored

# Show all ignore rules currently in effect
git check-ignore --verbose --non-matching *
```

**Stop tracking a file that was already committed**
```bash
# The file is in Git history — .gitignore alone won't hide it now
# Step 1: add to .gitignore
echo "appsettings.Development.json" >> .gitignore

# Step 2: remove from the index (keeps the file on disk)
git rm --cached appsettings.Development.json

# For a directory:
git rm --cached -r secrets/

# Step 3: commit the removal
git commit -m "chore: stop tracking appsettings.Development.json

Added to .gitignore. File remains on developer machines
but will no longer be tracked by Git."

# Note: the file still exists in Git HISTORY — if it contained secrets,
# rotate those secrets immediately and use git filter-repo to purge history
```

**Global ignore — personal patterns that don't belong in the repo**
```bash
# Create or edit your global gitignore
# macOS/Linux:
git config --global core.excludesFile ~/.gitignore

cat >> ~/.gitignore << 'EOF'
# My personal ignores (not shared with team)
.DS_Store
*.swp
*.swo
.idea/
*.iml
.vscode/settings.json
*.local
EOF

# These patterns apply to every repo on your machine
# without polluting the repo's own .gitignore
```

**Local exclude — repo-specific but not shared**
```bash
# .git/info/exclude has the same syntax as .gitignore
# but is never committed or pushed

cat >> .git/info/exclude << 'EOF'
# My local development overrides for this repo
local-scratch/
notes.md
temp-test-data/
EOF

# Use when: you have local files specific to your machine
# that wouldn't apply to teammates (your scratch notes, local test data, etc.)
```

**.gitkeep convention — track an empty directory**
```bash
# Git doesn't track empty directories
# Convention: add a .gitkeep file to force Git to track the directory

mkdir -p logs
touch logs/.gitkeep

# Add a .gitignore in the directory to ignore its contents but keep itself
cat > logs/.gitignore << 'EOF'
# Ignore everything in this directory
*
# Except this file
!.gitignore
EOF

git add logs/.gitignore
git commit -m "chore: add logs directory structure"
# logs/ is now tracked (the .gitignore file) but its contents are ignored
```

---

## Real World Example

A startup's API keys for SendGrid, Stripe, and AWS appeared in GitHub's secret scanning alerts two hours after a new engineer pushed their first commit. The `.env` file wasn't in `.gitignore` — and because it wasn't, the new engineer had staged it with `git add .`. Three keys were live on GitHub for 2 hours before the alert.

```bash
# Incident response:
# 1. Rotate all three keys IMMEDIATELY (before anything else)
# 2. Remove from Git history using git-filter-repo

pip install git-filter-repo

# Remove the .env file from all branches and history
git filter-repo --path .env --invert-paths --force

# Verify it's gone
git log --all --full-history -- .env
# (no output = removed from all history)

# Force push all branches
git push origin --force --all
git push origin --force --tags

# 3. Set up proper .gitignore
cat >> .gitignore << 'EOF'
# Secrets and environment files — NEVER commit these
.env
.env.*
!.env.example
*.pem
*.key
*.p12
*.pfx
EOF

git add .gitignore
git commit -m "chore: add .gitignore for secrets (incident prevention)"

# 4. Create .env.example as documentation
cat > .env.example << 'EOF'
# Copy this to .env and fill in your values
# DO NOT commit .env — it's in .gitignore
SENDGRID_API_KEY=your_key_here
STRIPE_SECRET_KEY=sk_test_...
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
EOF

git add .env.example
git commit -m "docs: add .env.example template"

# 5. Add pre-commit hook to catch secrets
cat > .githooks/pre-commit << 'EOF'
#!/bin/bash
# Check for common secret patterns in staged files
if git diff --cached | grep -iE "^\+(.*)(api_key|secret_key|password|access_token)\s*=\s*['\"][^'\"]{8,}" > /dev/null 2>&1; then
  echo "❌ Possible secret detected in staged changes."
  echo "   Review with 'git diff --cached' before committing."
  exit 1
fi
exit 0
EOF
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

*The key insight: `.gitignore` is your first line of defence against accidental secret exposure, but it only works for files that have never been committed. The `.env.example` pattern — committing a template with placeholder values — both documents required configuration AND signals to every engineer that `.env` is the local override that should stay untracked.*

---

## Common Misconceptions

**"Adding a file to .gitignore removes it from Git"**
`.gitignore` only prevents *untracked* files from being staged. If a file is already tracked (was previously committed), `.gitignore` has no effect on it — Git will continue tracking it and showing changes in `git status`. To stop tracking a committed file, you must use `git rm --cached <file>` to remove it from the index, then commit that change. The file stays on disk but Git stops watching it.

**"gitignore only works at the repo root"**
`.gitignore` files work at any directory level. A `.gitignore` in `src/` applies patterns relative to `src/`. More specific (deeper) `.gitignore` files take precedence over less specific (shallower) ones. You can also negate a parent pattern in a child `.gitignore`. This hierarchical system lets libraries or modules define their own ignore rules without touching the root `.gitignore`.

**"Ignored files are deleted when someone else clones"**
Ignored files are untracked — they were never committed, so they don't exist in Git history. When someone clones the repo, they don't get those files at all. The `.env` file stays on your machine only. This is both the feature (secrets stay local) and the constraint (developer-specific config must be set up on each machine — document this in README).

---

## Gotchas

- **`.gitignore` has no effect on already-committed files.** If `secrets.json` is in Git history, adding it to `.gitignore` does nothing. You need `git rm --cached secrets.json` + a commit, then rotate any secrets that were exposed.

- **Trailing spaces in patterns break matching.** `node_modules/ ` (with a trailing space) does not ignore `node_modules/`. These bugs are invisible to the naked eye — use `git check-ignore -v` to debug.

- **Negation patterns only work if the directory containing the file isn't already excluded.** `!important.log` won't un-ignore `logs/important.log` if `logs/` is ignored — Git doesn't descend into ignored directories at all. You must explicitly allow the directory: `!logs/` then `logs/*` then `!logs/important.log`.

- **`.gitignore` patterns are relative to the file's location, not the repo root.** A `*.log` pattern in `src/.gitignore` ignores log files in `src/`, not in the repo root. A `/` prefix anchors the pattern to the location of that `.gitignore` file.

- **Collaborators may have different OS files cluttering their `git status`.** Don't put OS-specific patterns in the repo `.gitignore` — that's noise for everyone on other OS. Put `.DS_Store`, `Thumbs.db`, etc. in your global `~/.gitignore` instead.

---

## Interview Angle

**What they're really testing:** Whether you understand the difference between ignoring and removing files, and the correct workflow when secrets are accidentally committed.

**Common question forms:**
- "A developer accidentally committed a `.env` file with API keys. What do you do?"
- "How does `.gitignore` work under the hood?"
- "Why is it that adding a file to `.gitignore` doesn't seem to do anything?"

**The depth signal:** A junior says "add the file to `.gitignore`." A senior explains that `.gitignore` only affects untracked files — for committed files, you need `git rm --cached` — and immediately notes that if the file contained secrets, rotating the credentials comes before any Git cleanup. They know `git check-ignore -v` for debugging, the global ignore for OS/IDE files, and the `.env.example` pattern for documenting required configuration.

**Follow-up questions to expect:**
- "How would you prevent this from happening again?"
- "What's the difference between `.gitignore`, `.git/info/exclude`, and a global gitignore?"

---

## Related Topics

- [git-staging-area.md](git-staging-area.md) — `.gitignore` affects what `git add .` sees; understanding the index helps explain why ignored files aren't staged.
- [git-hooks.md](git-hooks.md) — pre-commit hooks are the second line of defence after `.gitignore` for preventing secrets from being staged.
- [git-commits.md](git-commits.md) — `git rm --cached` + commit is the correct workflow for stopping tracking of a previously committed file.
- [github-security-features.md](../github/github-security-features.md) — GitHub secret scanning catches credentials even if `.gitignore` fails — a safety net, not a substitute.

---

## Source

[Git Documentation — gitignore](https://git-scm.com/docs/gitignore)

---
*Last updated: 2026-04-24*