# Git Patch Format

> `git format-patch` generates email-ready patch files from commits, and `git am` applies them — enabling code contribution workflows that don't require shared repository access.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A portable commit serialisation format for sharing and applying changes across repositories |
| **Use when** | Contributing to projects without push access; offline code review; applying changes between unrelated repos |
| **Avoid when** | You have direct push access and can use normal PR workflows |
| **Git version** | `git format-patch` since Git 1.0; `git am` since Git 1.0; `git apply` since Git 1.0 |
| **Key location** | Generates `.patch` files in the current directory (or specified output) |
| **Key commands** | `git format-patch`, `git am`, `git apply`, `git apply --check`, `git send-email` |

---

## When To Use It

The patch workflow predates GitHub and pull requests — it's how the Linux kernel and many large open source projects still receive contributions. Each patch is a self-contained commit serialisation: diff + commit message + author + date. `git am` applies patches as real commits, preserving authorship. Use it when: contributing to projects hosted on mailing lists (Linux kernel, Git itself), transferring commits between air-gapped systems, applying a fix from a GitHub issue to a repository with no common history, or sending proposed changes via email to a team without shared repository access.

---

## Core Concept

`git format-patch` serialises commits into `.patch` files that contain: the full unified diff, the commit message, author name/email/date, and a threading header for email. This is more than a raw `git diff` — it includes all commit metadata so the recipient can apply it as a real commit with the original author preserved. `git am` (apply mailbox) reads these files and creates commits, while `git apply` applies only the diff without creating a commit. The format is intentionally human-readable and can be edited before applying.

---

## Version History

| Git Version | What changed |
|---|---|
| Git 1.0 | `git format-patch` and `git am` available |
| Git 1.6.0 | `--cover-letter` for multi-patch series |
| Git 1.7.6 | `git send-email` improved for Gmail/OAuth |
| Git 2.9 | `git apply --reject` improvements |
| Git 2.12 | `git am --show-current-patch` to see the failing patch |
| Git 2.26 | `git apply --3way` for smarter conflict resolution |

*`git apply --3way` (Git 2.26) attempts a three-way merge when a patch doesn't apply cleanly — instead of failing, it produces conflict markers like a normal merge. This makes patch application on diverged codebases much more practical.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| `git format-patch -N` (N commits) | O(N × diff size) | One file per commit; file I/O is the bottleneck |
| `git am <patches>` | O(patches × diff size) | Applies each patch as a commit |
| `git apply --check` | O(diff size) | Dry run — no files written |
| `git send-email` | O(patches × SMTP overhead) | Network bound |

**Allocation behaviour:** Each `.patch` file is a text file typically 2–10× the diff size (due to headers and encoding). A 100-line diff produces a ~1KB patch file. Multi-patch series create one file per commit in the output directory.

---

## The Code

**Generating patches**
```bash
# Generate a patch for the last commit
git format-patch -1 HEAD
# Produces: 0001-feat-add-OAuth-support.patch

# Generate patches for the last 3 commits (one file each)
git format-patch -3 HEAD
# 0001-feat-scaffold-OAuth-provider.patch
# 0002-feat-add-OAuth-callback-handler.patch
# 0003-test-add-OAuth-integration-tests.patch

# Generate patches for all commits since branching off main
git format-patch main..HEAD
git format-patch origin/main  # equivalent if your branch is ahead of origin/main

# Generate into a specific directory
git format-patch -3 HEAD -o /tmp/patches/

# Generate a single patch file containing all commits (not recommended for review)
git format-patch main..HEAD --stdout > all-changes.patch

# Include a cover letter (overview email for a series of patches)
git format-patch -3 HEAD --cover-letter -o /tmp/patches/
# Creates 0000-cover-letter.patch + the numbered patches
# Edit the cover letter to explain the purpose of the series
```

**Inspecting a patch file**
```bash
# A patch file looks like this:
cat 0001-feat-add-OAuth-support.patch
# From a3f9d12c Mon Sep 17 00:00:00 2001
# From: Ali Hassan <ali@company.com>
# Date: Thu, 24 Apr 2026 14:22:11 +0300
# Subject: [PATCH] feat: add OAuth support
#
# Integrates OAuth 2.0 with GitHub provider.
# Uses PKCE flow for security.
#
# ---
#  src/Auth/OAuthProvider.cs | 87 ++++++++++++++++++++++++++++++++++++++
#  1 file changed, 87 insertions(+)
#
# diff --git a/src/Auth/OAuthProvider.cs b/src/Auth/OAuthProvider.cs
# new file mode 100644
# ...

# Check if a patch applies cleanly (dry run — no files modified)
git apply --check 0001-feat-add-OAuth-support.patch
# If exit 0: applies cleanly
# If exit 1: shows where it would fail
```

**Applying patches**
```bash
# Apply a single patch as a commit (preserves author and message)
git am 0001-feat-add-OAuth-support.patch

# Apply a series of patches (in order)
git am /tmp/patches/*.patch

# Apply all patches from an mbox file (email export format)
git am < patches.mbox

# If a patch fails to apply (conflicts):
git am --show-current-patch   # show the failing patch
# Resolve conflicts manually, then:
git add resolved-file.cs
git am --continue

# Or skip the failing patch:
git am --skip

# Or abort and return to pre-am state:
git am --abort

# Apply with 3-way merge on failure (Git 2.26+)
git am --3way /tmp/patches/*.patch
# Attempts merge instead of fail on conflict
```

**`git apply` — apply without committing**
```bash
# Apply patch to working directory only (no commit)
git apply 0001-feat-add-OAuth-support.patch

# Apply and stage (but don't commit)
git apply --index 0001-feat-add-OAuth-support.patch

# Apply in reverse (un-apply a patch)
git apply --reverse 0001-feat-add-OAuth-support.patch

# Apply with fuzzy matching (if context lines don't match exactly)
git apply --ignore-whitespace 0001-feat-add-OAuth-support.patch
git apply -C1 0001-feat-add-OAuth-support.patch  # reduce context requirement to 1 line
```

**Sending patches via email (Linux kernel workflow)**
```bash
# Configure git send-email (one-time setup)
git config --global sendemail.smtpserver smtp.gmail.com
git config --global sendemail.smtpserverport 587
git config --global sendemail.smtpencryption tls
git config --global sendemail.smtpuser ali@company.com

# Send a single patch to a mailing list
git send-email \
  --to=linux-kernel@vger.kernel.org \
  --cc=maintainer@example.com \
  0001-fix-memory-leak-in-driver.patch

# Send a series with cover letter
git send-email \
  --to=patches@project.org \
  --compose \   # prompts to write a cover letter
  /tmp/patches/*.patch
```

**Inter-repo patch workflow (no common history)**
```bash
# Scenario: apply a fix from repo-A to repo-B (no common history, can't cherry-pick)

# In repo-A: export the fix as a patch
cd repo-a
git format-patch -1 a3f9d12 -o /tmp/

# In repo-B: apply the patch
cd repo-b
git apply --check /tmp/0001-fix-null-ref-in-payment.patch
# Error: patch does not apply — the files differ too much

# Try with reduced context and whitespace ignore:
git apply --ignore-whitespace -C1 /tmp/0001-fix-null-ref-in-payment.patch
# Or: use --3way for conflict markers
git apply --3way /tmp/0001-fix-null-ref-in-payment.patch

# Or: apply manually using the patch as a reference
# Open the .patch file, read the diff, apply the logic manually
cat /tmp/0001-fix-null-ref-in-payment.patch | grep "^+" | grep -v "^+++"
```

---

## Real World Example

A security researcher discovered a critical memory safety bug in an embedded systems firmware project that was maintained offline — no GitHub, no network connectivity in the production environment. The fix needed to go from the researcher's machine to the firmware team's air-gapped build system via USB drive.

```bash
# Researcher's machine (has internet, found the bug in a test environment):

# Step 1: reproduce and fix the bug
git checkout -b fix/buffer-overflow-in-uart-handler
# ... fix the bug in src/drivers/uart.c ...
git commit -m "fix(uart): prevent buffer overflow on long input

The UART receive handler didn't check buffer bounds before copying
input data. An attacker sending >256 bytes could overflow the stack
buffer and overwrite the return address.

Fix: add length check before memcpy, truncate to UART_BUF_SIZE-1.
CVE-2026-0182 - CVSS 9.1 (Critical)

Reported by: Ali Hassan <ali@security-firm.com>
Tested on: STM32F4xx dev board, 2026-04-20"

# Step 2: generate the patch
git format-patch -1 HEAD -o /tmp/firmware-fix/
ls /tmp/firmware-fix/
# 0001-fix-uart-prevent-buffer-overflow-on-long-input.patch

# Step 3: include a cover letter with context
git format-patch -1 HEAD --cover-letter -o /tmp/firmware-fix/
# Edit 0000-cover-letter.patch:
# Subject: [PATCH 0/1] Critical: Buffer overflow in UART handler (CVE-2026-0182)
# Body: Reproduction steps, affected versions, test procedure, ...

# Step 4: copy to USB, deliver to firmware team
cp /tmp/firmware-fix/*.patch /media/usb-drive/

# Firmware team's air-gapped build machine:
# Step 5: verify the patch applies cleanly
cd /src/firmware
git apply --check /media/usb-drive/0001-fix-uart-prevent-buffer-overflow-on-long-input.patch
# Applies cleanly to current HEAD

# Step 6: apply and review
git am /media/usb-drive/0001-fix-uart-prevent-buffer-overflow-on-long-input.patch
git show HEAD  # review the applied fix
# Run internal test suite
make test TARGET=stm32f4
# All tests pass

# Step 7: tag the patched release
git tag -a v2.4.1-sec -m "Security patch: CVE-2026-0182 UART buffer overflow"
```

*The key insight: patch files are the original "pull request" mechanism — self-contained, portable, verifiable, and independent of any hosting platform. In air-gapped, regulated, or platform-independent environments, the patch workflow is the only option. Understanding it separates engineers who are platform-dependent from engineers who understand Git fundamentally.*

---

## Common Misconceptions

**"`git apply` and `git am` do the same thing"**
`git apply` applies the diff to the working directory (and optionally stages it) but does not create a commit. `git am` (apply mailbox) reads the full patch format including author, date, and commit message, and creates a real commit preserving all that metadata. Use `git apply` when you want the changes without the commit; use `git am` when you want to reproduce the original commit exactly.

**"Patch files only work on identical codebases"**
Patch files require that the context lines (the unchanged lines around each change) match. If the file has changed significantly, the patch won't apply. But `--3way` and `-C1` (reduced context requirement) make patch application much more flexible. `--3way` turns failed patches into merge conflicts you can resolve rather than hard failures.

**"`git diff` output and `git format-patch` output are interchangeable"**
`git diff` output can be applied with `git apply` but not with `git am`. `git format-patch` output includes the email headers (From, Date, Subject) and commit message that `git am` needs to reconstruct the original commit. A `git diff` patch loses author and commit message; a `format-patch` patch preserves everything. Always use `format-patch` when you want the recipient to be able to apply your commits with full metadata.

---

## Gotchas

- **Patches fail if the context lines don't match.** Even a whitespace-only change to a nearby line can prevent patch application. Use `--ignore-whitespace` and `-C1` (minimum 1 context line instead of 3) to make patches more tolerant.

- **`git am` on Windows may fail due to line ending differences.** Add `--keep-cr` flag or configure `core.autocrlf` consistently. Linux patches applied on Windows repos frequently hit this.

- **The patch series order matters.** `git am *.patch` relies on lexicographic ordering, which matches the `0001-`, `0002-` numbering from `format-patch`. Don't rename patch files.

- **Cover letters are not applied by `git am`.** The `0000-cover-letter.patch` is a pure email communication — `git am` skips it. Start `git am` from `0001-*.patch`.

- **Signatures in signed commits are lost in patch format.** `git format-patch` doesn't include GPG/SSH signatures. The recipient's applied commits will be unsigned. This is a known limitation — if signatures matter, use cherry-pick or merge instead.

---

## Interview Angle

**What they're really testing:** Whether you understand Git's origins and have worked in environments beyond GitHub/GitLab — and whether you understand the distinction between `git apply` and `git am`.

**Common question forms:**
- "How do you contribute to a project you don't have push access to?"
- "How would you transfer commits between two unrelated repositories?"
- "What's the difference between `git apply` and `git am`?"

**The depth signal:** A junior may have never used the patch workflow. A senior can describe when it's necessary (kernel workflow, air-gapped systems, inter-repo changes), knows the difference between `git apply` (diff only, no commit) and `git am` (full commit reconstruction), understands `--3way` for diverged codebases, and has a mental model of what the patch file contains (diff + email headers + commit message).

**Follow-up questions to expect:**
- "How do you apply a patch that doesn't apply cleanly due to context mismatch?"
- "Why is `git format-patch` better than `git diff` for sharing commits?"

---

## Related Topics

- [git-commits.md](git-commits.md) — Patch files are serialised commits; understanding commit objects explains what `git am` reconstructs.
- [git-diff-advanced.md](git-diff-advanced.md) — `git diff` output is the core of a patch file; understanding diff format helps with reading and editing patches.
- [git-cherry-pick.md](git-cherry-pick.md) — Cherry-pick is the modern alternative to patch workflow when repos share history.
- [git-signing-gpg.md](git-signing-gpg.md) — Commit signatures are not preserved in patch format — an important limitation to know.

---

## Source

[Git Documentation — git-format-patch](https://git-scm.com/docs/git-format-patch)

---
*Last updated: 2026-04-24*