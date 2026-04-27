# Git Signing (GPG & SSH)

> Git commit signing cryptographically proves that a commit was made by the owner of a specific key — GitHub shows a "Verified" badge on signed commits, and vigilant mode rejects unsigned commits entirely.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Cryptographic signature attached to commits, tags, and pushes using GPG or SSH keys |
| **Use when** | Supply chain security requirements; regulated environments; open source maintainer workflows |
| **Avoid when** | Small internal teams where identity is already established via SSO/org membership |
| **Git version** | GPG signing since Git 1.7.9; SSH signing since Git 2.34; `--allowed-signers` file Git 2.34 |
| **Key location** | Signature embedded in commit object; verification keys in keyring or `~/.ssh/allowed_signers` |
| **Key commands** | `git config commit.gpgsign`, `git log --show-signature`, `git verify-commit`, `git tag -s` |

---

## When To Use It

Use commit signing when you need non-repudiation — cryptographic proof that a specific person authored a commit, not just that their GitHub username appeared in the author field. The author field in a commit is trivially spoofable (`git config user.email "ceo@company.com"` and commit — Git believes you). Signing proves the commit was made with a specific private key. Use it for: open source maintainers signing releases, teams with SOC 2 / compliance requirements, regulated industries, and any workflow where supply chain integrity matters.

---

## Core Concept

When you sign a commit, Git computes the commit object's content, signs it with your private key (GPG or SSH), and embeds the signature in the commit object. Verification uses the corresponding public key to confirm the signature matches the commit content. If even one byte of the commit changes (author, message, tree, parent), the signature is invalid. GitHub shows "Verified" on commits signed with a key registered in your GitHub account, and "Unverified" on commits signed with an unknown key. Vigilant mode rejects commits with no signature or an unrecognised signature.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.7.9 | GPG commit signing introduced (`-S` flag, `commit.gpgsign`) |
| Git 2.2 | Tag signing improved; `git tag -s` stabilised |
| Git 2.19 | Better error messages for missing GPG key |
| Git 2.34 | SSH commit signing introduced — no GPG needed; `gpg.format = ssh` |
| Git 2.34 | `gpg.ssh.allowedSignersFile` for SSH signature verification |
| Git 2.35 | X.509/S-MIME signing support (`gpg.format = x509`) |

*SSH signing (Git 2.34) is a major quality-of-life improvement over GPG. Most developers already have an SSH key set up for GitHub access — signing with it requires no additional tooling, no keyring management, and no web of trust. For new setups, SSH signing is almost always the right choice.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Signing a commit | ~100ms | GPG key lookup + signature computation |
| Verifying a signature | ~50ms | Key lookup + signature verification |
| `git log --show-signature` | O(commits × 50ms) | Verifies each commit — slow on long histories |
| Pushing signed commits | Same as unsigned | Signature is stored in the commit object; no push overhead |

**Allocation behaviour:** A GPG signature adds ~400–800 bytes to a commit object. An SSH signature adds ~250–400 bytes. Over thousands of commits, this is negligible. The commit object size increase is not worth worrying about.

**Benchmark notes:** `git log --show-signature` on 1,000 commits can take 50+ seconds because it verifies each signature individually. For checking recent commits only, use `git log --show-signature -10`. For bulk verification in CI, use `git verify-commit HEAD` for the latest commit rather than re-verifying the entire history.

---

## The Code

**SSH signing — the modern approach (Git 2.34+)**
```bash
# 1. Configure Git to use SSH for signing
git config --global gpg.format ssh

# 2. Specify which SSH key to sign with (use your existing GitHub key)
# Option A: specify key file directly
git config --global user.signingKey ~/.ssh/id_ed25519.pub

# Option B: let Git use any available SSH key (convenient)
git config --global user.signingKey "ssh-ed25519 AAAA..."

# 3. Enable automatic signing for all commits
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# 4. Create an allowed signers file for local verification
# Format: email keytype keydata
cat >> ~/.ssh/allowed_signers << 'EOF'
ali@company.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...
sara@company.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5BBBB...
EOF

git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers

# 5. Sign and verify
git commit -m "feat: add OAuth support"   # automatically signed
git verify-commit HEAD                     # verify the signature
git log --show-signature -3                # show signatures in log
```

**GPG signing — the traditional approach**
```bash
# 1. Generate a GPG key (if you don't have one)
gpg --full-generate-key
# Choose: RSA and RSA, 4096 bits, 0 (no expiry), your name and email

# 2. Get your key ID
gpg --list-secret-keys --keyid-format=long
# sec   rsa4096/3AA5C34371567BD2 2024-01-15 [SC]
# Key ID is: 3AA5C34371567BD2

# 3. Configure Git to use it
git config --global user.signingKey 3AA5C34371567BD2
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# 4. Export public key and add to GitHub
gpg --armor --export 3AA5C34371567BD2
# Copy the output → GitHub → Settings → SSH and GPG keys → New GPG key

# 5. Sign commits
git commit -m "feat: add OAuth support"    # automatically signed with -S omitted since gpgsign=true
git commit -S -m "feat: signed commit"    # explicitly signed

# Verify
git verify-commit HEAD
git log --show-signature -1
```

**Tag signing (for releases)**
```bash
# Create a signed tag
git tag -s v2.0.0 -m "Release 2.0.0 — signed by release manager"

# Verify a signed tag
git tag -v v2.0.0

# List tags showing signature status
git log --tags --simplify-by-decoration --pretty="format:%d %h %s" | head -20
```

**GitHub Vigilant Mode setup**
```bash
# Vigilant mode: GitHub shows "Unverified" on ALL commits without a valid signature
# Not just unsigned — any commit where the signature can't be verified against
# a key registered in your GitHub account

# Enable in GitHub → Settings → SSH and GPG keys → Vigilant mode

# To pass vigilant mode:
# 1. Your key must be registered in GitHub Settings
# 2. Every commit must be signed with that key
# 3. The author email must match the GitHub account

# Test your setup:
git commit --allow-empty -m "test: verify signing setup"
git push
# Check the commit on GitHub — should show green "Verified" badge
```

**CI verification — enforce signed commits in pipeline**
```bash
# .github/workflows/verify-signatures.yml
name: Verify Commit Signatures

on: [pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # need full history to verify

      - name: Set up allowed signers
        run: |
          mkdir -p ~/.ssh
          # Import team public keys from repo
          cat .github/allowed_signers >> ~/.ssh/allowed_signers
          git config gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers

      - name: Verify all commits in PR are signed
        run: |
          # Get commits in this PR
          BASE=${{ github.event.pull_request.base.sha }}
          HEAD=${{ github.event.pull_request.head.sha }}

          git log --format="%H" $BASE..$HEAD | while read commit; do
            echo "Verifying: $commit"
            git verify-commit "$commit" || {
              echo "❌ Commit $commit is not signed or signature is invalid"
              exit 1
            }
          done
          echo "✓ All commits verified"
```

**Handling signing on multiple machines**
```bash
# Export SSH key pair to another machine:
# (Copy ~/.ssh/id_ed25519 and ~/.ssh/id_ed25519.pub to the new machine)
scp ~/.ssh/id_ed25519 newmachine:~/.ssh/
scp ~/.ssh/id_ed25519.pub newmachine:~/.ssh/

# On the new machine:
git config --global gpg.format ssh
git config --global user.signingKey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true

# For GPG: export and import the key
gpg --export-secret-keys --armor 3AA5C34371567BD2 > private-key.asc
# Transfer securely, then on new machine:
gpg --import private-key.asc
git config --global user.signingKey 3AA5C34371567BD2
```

---

## Real World Example

An open source cryptography library had a security incident: a malicious PR was merged that appeared to come from a trusted maintainer. Investigation revealed their GitHub account had been compromised — the attacker changed the email on a commit to impersonate the maintainer. After the incident, the project implemented mandatory commit signing with SSH keys registered to the GitHub org.

```bash
# Post-incident: enforce signed commits on main branch

# Step 1: require signed commits via branch protection
# GitHub → Repository → Settings → Branches → main → Require signed commits
# (This is a branch protection rule — all commits to main must be GPG/SSH signed)

# Step 2: all maintainers set up SSH signing
git config --global gpg.format ssh
git config --global user.signingKey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true

# Step 3: create the team allowed_signers file in the repo
cat > .github/allowed_signers << 'EOF'
# Active maintainers — update this file when team changes
ali@company.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKey1...
sara@company.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKey2...
jordan@company.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKey3...
EOF
git add .github/allowed_signers
git commit -S -m "chore: add commit signature verification config

Following security incident on 2026-03-01 where account compromise
allowed unsigned commits from a compromised maintainer account.

All maintainers must now:
1. Sign every commit with their registered SSH key
2. Have their public key in .github/allowed_signers
3. Enable 2FA on their GitHub account

Branch protection requires signed commits on main.
CI verifies signatures on all PRs."

# Step 4: retroactive audit — which historical commits are unsigned?
git log --format="%H %aN %ae" --after="2024-01-01" | while read hash name email; do
  if ! git verify-commit "$hash" 2>/dev/null; then
    echo "UNSIGNED: $hash by $name <$email>"
  fi
done | wc -l
# Found 847 unsigned commits in 2024 (before the policy)
# All from before the policy — acceptable, documented in security log
```

*The key insight: commit signing is not about preventing bad code — code review handles that. It's about preventing identity spoofing. In the incident, the attacker could impersonate any maintainer by setting `git config user.email`. With SSH signing, impersonation requires stealing the private key, not just the email address.*

---

## Common Misconceptions

**"The author field in a commit proves who made it"**
The author and committer fields in a commit object are plain text — any engineer can set them to any value with `git config user.email "ceo@company.com"`. GitHub displays whatever is in those fields without verification. Only a cryptographic signature, verified against a key registered to a GitHub account, proves the commit actually came from that person. This is exactly how supply chain attacks via commit impersonation work.

**"GPG is required for commit signing"**
SSH signing (Git 2.34+) is a full alternative to GPG. Most developers already have SSH keys configured for GitHub access, making SSH signing zero-setup overhead. GPG has a more complex trust model (web of trust, keyservers) but provides no meaningful additional security for most signing use cases. For new setups, SSH signing is simpler and sufficient.

**"Signed commits mean the code is safe"**
A signed commit proves the commit was made with a specific key. It says nothing about the code quality, security vulnerabilities, or correctness of the changes. A maintainer can sign and merge a commit that introduces a security vulnerability — the signature proves it was them, not that it was correct. Signing is identity assurance, not code assurance.

---

## Gotchas

- **GPG signing fails if the GPG agent isn't running.** On headless servers or CI environments, GPG needs `export GPG_TTY=$(tty)` and the agent must be running. SSH signing doesn't have this problem — it's stateless.

- **Expired GPG keys make old signatures "unverified."** A commit signed 3 years ago with a key that has since expired shows as unverified on GitHub even though it was valid at signing time. This is a known pain point with GPG key management.

- **`commit.gpgsign = true` with no key configured causes every commit to fail.** If you set automatic signing but forget to configure the signing key, every `git commit` errors out. Always verify your setup with a test commit before configuring `gpgsign = true`.

- **SSH signing verification requires the allowed_signers file.** `git verify-commit` with SSH signing needs `gpg.ssh.allowedSignersFile` to know which keys are trusted. Without it, verification always fails even for valid signatures.

- **Rebase rewrites commit hashes, invalidating signatures.** After an interactive rebase, all rebased commits have new hashes — their signatures, which were computed over the old content, are now invalid. You must re-sign after rebasing: `git rebase --exec "git commit --amend --no-edit --gpg-sign" -i HEAD~N`.

---

## Interview Angle

**What they're really testing:** Whether you understand Git's identity model and the supply chain security implications.

**Common question forms:**
- "How do you prevent commit impersonation in Git?"
- "What does commit signing prove?"
- "What's the difference between GPG signing and SSH signing?"

**The depth signal:** A junior knows commit signing exists and that GitHub shows a "Verified" badge. A senior explains that the author field is trivially spoofable (any string, no verification), that signing provides cryptographic proof of key ownership (not identity per se — the key must be registered and trusted), knows SSH signing as the simpler modern alternative to GPG, understands that signing doesn't validate code quality, and knows the rebase-invalidates-signatures gotcha.

**Follow-up questions to expect:**
- "How is SSH commit signing different from SSH authentication to GitHub?"
- "What happens to commit signatures after an interactive rebase?"

---

## Related Topics

- [git-commits.md](git-commits.md) — Signing is a property of commit objects; understanding commit internals explains what exactly gets signed.
- [git-tags.md](git-tags.md) — Annotated tags can also be signed; `git tag -s` for release signing is common in open source.
- [git-internals.md](git-internals.md) — The signature is embedded in the commit object; understanding the object model shows exactly where it lives.
- [github-security-features.md](../github/github-security-features.md) — GitHub's vigilant mode, branch protection with required signatures, and the broader supply chain security ecosystem.

---

## Source

[Git Documentation — Signing Your Work](https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work)

---
*Last updated: 2026-04-24*