# Git Config

> `git config` reads and writes configuration values that control Git's behaviour — at the system, global (user), local (repo), or worktree level.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A layered key-value configuration system with four scope levels |
| **Use when** | Setting up identity, editor, signing, aliases, hooks path, merge tools |
| **Avoid when** | Storing secrets — git config values are plain text in readable files |
| **Git version** | Core since Git 1.0; worktree scope added Git 2.21; `--show-origin` added Git 2.8 |
| **Key locations** | `/etc/gitconfig` (system), `~/.gitconfig` (global), `.git/config` (local) |
| **Key commands** | `git config --global`, `git config --local`, `git config --list --show-origin` |

---

## When To Use It

Configure Git immediately after installing it on a new machine — at minimum, set your name, email, and default branch. Configure merge tools, signing keys, and aliases once globally so they apply to every repo. Use local config (`.git/config`) for repo-specific overrides — a different email for work repos, a different signing key, or repo-specific hooks paths.

---

## Core Concept

Git config is a layered system with four scopes. Lower scopes override higher ones: **system** (`/etc/gitconfig`) → **global** (`~/.gitconfig`) → **local** (`.git/config`) → **worktree** (`.git/config.worktree`). When you run `git config user.name`, Git reads from all layers and returns the most specific value. When you run `git config --global user.name "Ali"`, Git writes to `~/.gitconfig`. The local `.git/config` is what makes per-repo overrides possible without touching your global settings.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | System, global, local config levels established |
| Git 1.7.3 | `--show-origin` (draft); `includeIf` for conditional includes |
| Git 2.8 | `--show-origin` stabilised — shows which file each value comes from |
| Git 2.13 | `includeIf "gitdir:..."` for directory-based conditional includes |
| Git 2.21 | Worktree-level config scope added |
| Git 2.26 | `--show-scope` — shows the scope level alongside values |
| Git 2.35 | `--type=` flag for typed get/set operations (bool, int, path) |

*`includeIf "gitdir:~/work/"` (Git 2.13+) is the canonical solution to "use my work email for work repos and my personal email for personal repos." It conditionally includes another config file based on the repository path — no more forgetting to set the right email on a new work repo.*

---

## Performance

Git config reads are extremely fast — they're simple file reads of small INI-format files. There is no meaningful performance consideration for config operations themselves. The performance-relevant config *values* are covered below.

| Config key | Performance impact |
|---|---|
| `core.fsmonitor = true` | Major: makes `git status` near-instant on large repos (Git 2.37+) |
| `core.commitGraph = true` | Major: speeds up `git log` traversal |
| `core.preloadIndex = true` | Moderate: parallel index preload (default true on modern Git) |
| `gc.auto = 0` | Disables automatic GC — speeds up individual operations, risks large object store |
| `fetch.parallel = N` | Moderate: parallel submodule/remote fetches |

---

## The Code

**First-time setup — minimum viable config**
```bash
# Identity — required for commits
git config --global user.name "Ali Hassan"
git config --global user.email "ali@example.com"

# Default branch name for new repos (avoids 'master' on older Git)
git config --global init.defaultBranch main

# Editor for commit messages, interactive rebase, etc.
git config --global core.editor "code --wait"   # VS Code
git config --global core.editor "vim"
git config --global core.editor "nano"

# Default pull behaviour: rebase instead of merge
git config --global pull.rebase true

# Credential helper — cache credentials so you don't re-enter password
git config --global credential.helper store      # stores on disk (persistent)
git config --global credential.helper cache      # in-memory (expires)
git config --global credential.helper osxkeychain  # macOS Keychain
git config --global credential.helper manager      # Windows Credential Manager
```

**Viewing config**
```bash
# List all config and where each value comes from
git config --list --show-origin

# Output:
# file:/etc/gitconfig     core.repositoryformatversion=0
# file:~/.gitconfig       user.name=Ali Hassan
# file:~/.gitconfig       user.email=ali@example.com
# file:.git/config        core.bare=false

# Show scope level (system/global/local/worktree)
git config --list --show-scope

# Get a specific value
git config user.name         # returns most specific value
git config --global user.email

# Check which file a value comes from
git config --show-origin user.email
# file:~/.gitconfig    ali@example.com
```

**Conditional includes — work vs personal email**
```bash
# ~/.gitconfig
[user]
    name = Ali Hassan
    email = ali@personal.com    # default email

[includeIf "gitdir:~/work/"]
    path = ~/.gitconfig-work    # override for repos under ~/work/

[includeIf "gitdir:~/clients/acme/"]
    path = ~/.gitconfig-acme    # different config for client work

# ~/.gitconfig-work
[user]
    email = ali@company.com
[commit]
    gpgsign = true
    gpgkey = YOUR_WORK_GPG_KEY

# Verify the right email is active in a repo
cd ~/work/my-project
git config user.email
# ali@company.com   ← correct work email applied automatically
```

**Useful aliases**
```bash
# Add these to ~/.gitconfig
git config --global alias.st "status -sb"
git config --global alias.lg "log --oneline --graph --all --decorate"
git config --global alias.last "log -1 HEAD --stat"
git config --global alias.unstage "restore --staged"
git config --global alias.undo "reset --soft HEAD~1"
git config --global alias.amend "commit --amend --no-edit"
git config --global alias.branches "branch -a -vv"
git config --global alias.aliases "config --get-regexp alias"

# Complex aliases with shell commands
git config --global alias.cleanup '!git branch --merged | grep -v "\*\|main\|master\|develop" | xargs git branch -d'
# Usage: git cleanup  (deletes all locally merged branches except main/develop)
```

**Merge and diff tool configuration**
```bash
# VS Code as merge tool
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'
git config --global mergetool.keepBackup false   # don't keep .orig files

# VS Code as diff tool
git config --global diff.tool vscode
git config --global difftool.vscode.cmd 'code --wait --diff $LOCAL $REMOTE'
git config --global difftool.prompt false        # don't ask before launching

# IntelliJ / Rider
git config --global merge.tool intellij
git config --global mergetool.intellij.cmd 'idea merge "$LOCAL" "$REMOTE" "$BASE" "$MERGED"'
git config --global mergetool.intellij.trustExitCode true
```

**GPG / SSH commit signing**
```bash
# GPG signing
git config --global user.signingkey YOUR_GPG_KEY_ID
git config --global commit.gpgsign true   # sign all commits by default
git config --global tag.gpgsign true      # sign all tags by default

# SSH signing (Git 2.34+ — simpler than GPG)
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true

# Create an allowed signers file (for verification)
echo "$(git config user.email) namespaces=\"git\" $(cat ~/.ssh/id_ed25519.pub)" \
  >> ~/.ssh/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers

# Verify a commit's signature
git verify-commit HEAD
git log --show-signature -1
```

**Performance-related config**
```bash
# Faster git status on large repos (requires a filesystem monitor daemon)
git config --global core.fsmonitor true          # Git 2.37+ built-in
git config core.untrackedCache true              # cache untracked file results

# Speed up git log on repos with long history
git config --global core.commitGraph true
git commit-graph write --reachable               # build the graph file

# Parallel fetching for repos with many remotes or submodules
git config --global fetch.parallel 4

# Reuse recorded merge conflict resolutions
git config --global rerere.enabled true
```

**Shared team config via tracked file**
```bash
# Teams can ship recommended config in a tracked .gitconfig file
# (developers opt-in by including it)

# .gitconfig-team (tracked in repo)
[core]
    hooksPath = .githooks
[pull]
    rebase = true
[push]
    followTags = true
[merge]
    conflictStyle = zdiff3

# Developer includes it after cloning:
git config --local include.path ../.gitconfig-team
# or add to their global config:
# [includeIf "gitdir:~/work/this-org/"]
#     path = ~/work/this-org/.gitconfig-team
```

---

## Real World Example

An engineering team of 22 had an inconsistent developer environment problem — some used rebase-on-pull, others used merge; some had commit signing, others didn't; some used different editors causing CRLF chaos on Windows. They standardised via a checked-in `.gitconfig-team` file and an automated setup script.

```bash
# setup.sh — run once after cloning
#!/bin/bash
set -e

echo "Setting up Git configuration..."

# Core identity (prompt if not already set)
if [ -z "$(git config --global user.name)" ]; then
  read -p "Your full name: " name
  git config --global user.name "$name"
fi

if [ -z "$(git config --global user.email)" ]; then
  read -p "Your work email (@company.com): " email
  git config --global user.email "$email"
fi

# Include team config
git config --local include.path ../.gitconfig-team
echo "✓ Team config included"

# Configure hooks
git config --local core.hooksPath .githooks
echo "✓ Git hooks configured"

# SSH signing setup
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ -f "$SSH_KEY" ]; then
  git config --global gpg.format ssh
  git config --global user.signingkey "${SSH_KEY}.pub"
  git config --global commit.gpgsign true

  # Add to allowed signers
  ALLOWED="$HOME/.ssh/allowed_signers"
  EMAIL=$(git config user.email)
  echo "$EMAIL namespaces=\"git\" $(cat ${SSH_KEY}.pub)" >> "$ALLOWED"
  git config --global gpg.ssh.allowedSignersFile "$ALLOWED"
  echo "✓ SSH signing configured"
fi

# Performance tuning
git config --global core.fsmonitor true
git config --global fetch.parallel 4
echo "✓ Performance settings applied"

echo ""
echo "Setup complete. Verify with: git config --list --show-origin"
```

*The key insight: a setup script that takes 30 seconds to run eliminates entire categories of "it works on my machine" problems. The combination of `includeIf "gitdir:..."` for automatic email selection and a shared `.gitconfig-team` file for consistent behaviour removes the cognitive overhead of per-repo configuration maintenance.*

---

## Common Misconceptions

**"git config --global affects all repos on the machine"**
Global config is the default for all repos, but any local config (`.git/config`) overrides it for that specific repo. A `user.email` set in `.git/config` takes precedence over the global `user.email`. The layering is: worktree > local > global > system. Global means "default for everything that doesn't override it," not "forced on everything."

**"git config stores settings securely"**
Git config files are plain text with no encryption. `.git/config` is readable by any process that can read the filesystem. `~/.gitconfig` is readable by any process running as your user. Never store passwords, API keys, or other secrets in git config — use a credential helper that delegates to your OS keychain, or environment variables.

**"Aliases are just shortcuts for commands"**
Git aliases can run full shell commands by prefixing with `!`. `git config --global alias.cleanup '!git branch --merged | grep -v main | xargs git branch -d'` is a complete shell pipeline. This makes aliases powerful scripting tools — not just shortened command names. Any `!`-prefixed alias runs in the repo root directory.

---

## Gotchas

- **`--global` writes to `~/.gitconfig`, not the repo.** Running `git config user.email "wrong@email.com"` without a scope flag writes to `.git/config` (local) — it looks like a global change but only affects the current repo. Always specify `--global` for settings you want everywhere.

- **`includeIf "gitdir:..."` requires a trailing `/` for directory matching.** `gitdir:~/work` matches a repo literally named `work`; `gitdir:~/work/` matches any repo inside the `~/work/` directory. The missing slash is a silent non-match.

- **Windows CRLF handling requires `core.autocrlf` configuration.** Set `core.autocrlf = true` on Windows (convert CRLF → LF on commit, LF → CRLF on checkout), `core.autocrlf = input` on macOS/Linux (convert CRLF → LF on commit, leave as-is on checkout). Mismatched settings across the team cause spurious diffs in every file.

- **SSH signing requires Git 2.34+ and a configured `allowedSignersFile`.** SSH signing is simpler than GPG but needs the allowed signers file for verification. Without it, `git verify-commit` shows "No principal matched" even for valid signatures.

- **Config values set without `--global` are lost when the repo is deleted.** Local config lives in `.git/config` — if you delete the repo directory and re-clone, those settings are gone. Put anything you want to persist in `~/.gitconfig`.

---

## Interview Angle

**What they're really testing:** Whether you have a production-ready Git environment and can set up a team's Git configuration consistently.

**Common question forms:**
- "How do you set up Git on a new machine?"
- "How do you use different Git identities for work and personal projects?"
- "How do you share Git configuration settings across a team?"

**The depth signal:** A junior runs `git config --global user.name/email` and calls it done. A senior configures signing, merge tools, performance settings, and a credential helper; uses `includeIf` for automatic work/personal identity switching; ships a `.gitconfig-team` file and `setup.sh` so every new team member gets the same environment; and knows `git config --list --show-origin` to debug where any value is coming from.

**Follow-up questions to expect:**
- "What's the difference between global, local, and system config?"
- "How would you enforce consistent Git configuration across a team of 30 engineers?"

---

## Related Topics

- [git-hooks.md](git-hooks.md) — `core.hooksPath` in git config is how you share hooks with the team.
- [git-commits.md](git-commits.md) — `user.signingkey` and `commit.gpgsign` configure signed commits.
- [git-ignore.md](git-ignore.md) — `core.excludesFile` in global config points to your personal global gitignore.
- [git-merging.md](git-merging.md) — `merge.conflictStyle = zdiff3` is a config setting that significantly improves conflict resolution.
- [git-branching-strategy.md](git-branching-strategy.md) — `init.defaultBranch` sets the default branch name for new repos — a config setting with team-wide implications.

---

## Source

[Git Documentation — git-config](https://git-scm.com/docs/git-config)

---
*Last updated: 2026-04-24*