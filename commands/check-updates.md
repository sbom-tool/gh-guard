---
name: check-updates
description: Check for outdated GitHub Action SHAs and CLI tool versions in deployed workflows
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# /check-updates — SHA Pin Staleness Checker

Check deployed GitHub Actions workflow files for outdated SHA pins by comparing against the latest tags.

## Workflow

### Step 1: Find Deployed Workflows

Load `templates/versions.json` from the gh-guard plugin directory as the source of truth for expected versions. Then scan `.github/workflows/*.yml` for all `uses:` lines that reference SHA-pinned actions.

Extract each action reference into a list:
```
actions/checkout@de0fac2e...  (comment: v6.0.2)
dtolnay/rust-toolchain@efa25f...  (no version comment)
```

### Step 2: Check Each Action for Updates

For each unique action, query the latest release or tag:

```bash
# Get latest release tag
gh api repos/OWNER/REPO/releases/latest --jq '.tag_name' 2>/dev/null

# Get the SHA for a tag
gh api repos/OWNER/REPO/git/ref/tags/TAG --jq '.object.sha' 2>/dev/null
```

Compare the pinned SHA against the latest tag's SHA.

**Rate limiting:** GitHub API has rate limits. Cache results for actions that appear in multiple workflows. If rate-limited, show what was checked and suggest re-running later.

### Step 3: Check CLI Tool Versions

For workflows that install CLI tools (e.g., `cargo install cargo-audit --version X.Y.Z`):
- Extract the pinned version
- Check latest version on crates.io: `cargo search cargo-audit --limit 1`
- Flag if a newer version exists

### Step 4: Generate Report

```
## SHA Pin Status Report

### Actions

| Action | Pinned | Current | Latest | Status |
|--------|--------|---------|--------|--------|
| actions/checkout | de0fac2... | v6.0.2 | v6.0.2 | ✅ Up to date |
| dtolnay/rust-toolchain | efa25f7... | master | master | ✅ Up to date |
| ossf/scorecard-action | 4eaacf0... | v2.4.3 | v2.5.0 | ⚠️ Update available |

### CLI Tools

| Tool | Pinned | Latest | Status |
|------|--------|--------|--------|
| cargo-audit | 0.21.2 | 0.22.0 | ⚠️ Update available |

### Update Instructions

For each outdated action:
1. Verify the changelog: `gh api repos/OWNER/REPO/releases/latest --jq '.body' | head -20`
2. Get the new SHA: `gh api repos/OWNER/REPO/git/ref/tags/TAG --jq '.object.sha'`
3. Update the `uses:` line and version comment in the workflow
4. Update `templates/VERSIONS.md` if using gh-guard templates
```

### Step 5: Offer Fixes

For each outdated action, offer to update the workflow file:
- Show the diff (old SHA → new SHA, old comment → new comment)
- Ask: **Apply update / Skip / Show changelog first**
- Never auto-update without user confirmation

**Exception:** The SLSA generator (`slsa-framework/slsa-github-generator`) uses a tag reference, not SHA. Check if a newer tag exists but warn that updating may change the attestation format.
