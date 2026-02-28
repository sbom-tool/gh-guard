---
name: harden
description: Interactive wizard to generate missing supply chain security configs
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
  - Edit
  - AskUserQuestion
---

# /harden — Interactive Supply Chain Hardening Wizard

Guide the user through hardening their Rust project's CI/CD supply chain at their chosen level.

## Workflow

### Step 1: Detect Project Context

Auto-detect from the project:
- **Crate name:** `Cargo.toml` → `name = "..."`
- **MSRV:** `Cargo.toml` → `rust-version = "..."` or `rust-toolchain.toml` → `channel = "..."`
- **Repo owner/name:** `git remote get-url origin` → parse owner/name
- **Contact email:** `Cargo.toml` → `authors = [...]`
- **Fuzz targets:** `fuzz/Cargo.toml` → `[[bin]]` entries (if fuzz/ exists)

If any value can't be detected, ask the user.

### Step 2: Ask Hardening Level

Ask the user which level they want:

| Level | What Gets Generated |
|-------|-------------------|
| **Minimal** | CI workflow, `deny.toml`, `dependabot.yml`, `SECURITY.md`, `rust-toolchain.toml` |
| **Standard** | Minimal + publish workflow (Trusted Publishing), CodeQL, Scorecard, release script |
| **Hardened** | Standard + SLSA provenance (in publish workflow), fuzz workflow, `osv-scanner.toml` |

### Step 3: Check Existing Files

For each file in the selected level:
1. Check if it already exists
2. If it exists, show the user and ask: **keep existing / overwrite / skip**
3. Never silently overwrite

### Step 4: Generate Files

For each file to generate:

1. Read the corresponding template from `chain-guard/templates/`
2. Replace all `{{PLACEHOLDER}}` values with detected/provided values:
   - `{{CRATE_NAME}}` → detected crate name
   - `{{MSRV}}` → detected MSRV
   - `{{REPO_OWNER}}` → detected repo owner
   - `{{REPO_NAME}}` → detected repo name
   - `{{CONTACT_EMAIL}}` → detected or asked email
   - `{{FUZZ_TARGETS}}` → detected or asked fuzz targets
3. Write to the correct location:
   - Workflows → `.github/workflows/`
   - `deny.toml` → project root
   - `rust-toolchain.toml` → project root
   - `dependabot.yml` → `.github/dependabot.yml`
   - `SECURITY.md` → project root
   - `release.sh` → `scripts/release.sh` (make executable)
   - `osv-scanner.toml` → project root

### Step 5: Post-Generation Checklist

After generating files, show the user a manual steps checklist based on their level:

**Minimal:**
- [ ] Review generated files and commit them
- [ ] Verify CI passes on a test PR

**Standard (adds):**
- [ ] Create `crates-io` environment in repo Settings > Environments
- [ ] Configure Trusted Publishing at `crates.io/crates/{{CRATE_NAME}}/settings`
- [ ] Set up branch protection on `main` (require the "CI" status check)
- [ ] Disable CodeQL "default setup" in repo Settings > Code Security (if using custom workflow)
- [ ] Set up a signing key for git tags:
  ```bash
  git config --global gpg.format ssh
  git config --global user.signingkey ~/.ssh/id_ed25519.pub
  ```

**Hardened (adds):**
- [ ] Initialize fuzz targets: `cargo fuzz init && cargo fuzz add <target>`
- [ ] Update fuzz workflow matrix with your target names
- [ ] Register at [bestpractices.coreinfrastructure.org](https://bestpractices.coreinfrastructure.org) for CII badge
- [ ] Review `osv-scanner.toml` — uncomment ecosystems that appear in your test fixtures

### Step 6: Summary

Show what was generated:

```
## Hardening Complete (Standard Level)

### Generated Files
- .github/workflows/ci.yml ✅
- .github/workflows/publish.yml ✅
- .github/workflows/codeql.yml ✅
- .github/workflows/scorecard.yml ✅
- .github/dependabot.yml ✅
- deny.toml ✅
- rust-toolchain.toml ✅
- SECURITY.md ✅
- scripts/release.sh ✅

### Skipped (already existed)
- LICENSE (kept existing)

### Manual Steps Required
<checklist from Step 5>
```
