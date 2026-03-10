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
- **Workspace crates:** if `[workspace]` in root `Cargo.toml`, detect publishable members via `cargo metadata --no-deps` filtered by `publish != false`, ordered by dependency graph. Ask user to confirm the list and order.

If any value can't be detected, ask the user.

### Step 2: Ask Hardening Level

Ask the user which level they want:

| Level | What Gets Generated |
|-------|-------------------|
| **Minimal** | CI workflow, `deny.toml`, `dependabot.yml`, `SECURITY.md`, `rust-toolchain.toml` |
| **Standard** | Minimal + publish workflow (Trusted Publishing), CodeQL, Scorecard, release script |
| **Hardened** | Standard + SLSA provenance (in publish workflow), fuzz workflow, `osv-scanner.toml` |

### Step 2a: Detect Current Hardening Level

Use the detection algorithm from the `hardening-detection` skill (single source of truth for marker definitions and classification rules) to determine the project's current level.

Show the user: "Your project is currently at **[Level]** (X/Y markers present)"
- If Custom (partial): show "Your project is at **Minimal** with partial Standard coverage (2/4 markers). Missing: CodeQL workflow, Scorecard workflow."
- Recommend completing the current effective level's gaps before upgrading, or offer to fill them as part of the upgrade

**Upgrade mode:** If the detected level is below the chosen level:
   - Show what will be added (delta only, not the full level)
   - Example: "Upgrading from **Minimal** → **Standard**: 4 files to generate"
   - Only iterate over the delta files in subsequent steps
   - If the detected level equals or exceeds the chosen level: suggest `/audit` for a detailed gap analysis instead

### Step 3: Check Existing Files

For each file in the selected level (or delta set if in upgrade mode):
1. Check if it already exists
2. If it exists, show the user and ask: **keep existing / overwrite / skip**
3. Never silently overwrite

### Step 4: Generate Files

Show progress as each file is generated (e.g., "Generating file 3/7: `.github/workflows/codeql.yml`..."). This gives the user visibility into the process, especially when generating 5-11 files at the Hardened level.

For each file to generate:

1. Read the corresponding template from `gh-guard/templates/`
2. Replace all `{{PLACEHOLDER}}` values with detected/provided values:
   - `{{CRATE_NAME}}` → detected crate name
   - `{{MSRV}}` → detected MSRV
   - `{{REPO_OWNER}}` → detected repo owner
   - `{{REPO_NAME}}` → detected repo name
   - `{{CONTACT_EMAIL}}` → detected or asked email
   - `{{FUZZ_TARGETS}}` → detected or asked fuzz targets
   - `{{WORKSPACE_CRATES}}` → detected publishable crates in dependency order (workspace only)
3. Write to the correct location:
   - Workflows → `.github/workflows/`
   - `deny.toml` → project root
   - `rust-toolchain.toml` → project root
   - `dependabot.yml` → `.github/dependabot.yml`
   - `SECURITY.md` → project root
   - `release.sh` → `scripts/release.sh` (make executable)
   - `osv-scanner.toml` → project root

### Step 5: Post-Generation Checklist

After generating files, show the user a manual steps checklist based on their level. In upgrade mode, show only the NEW manual steps for the target level (skip steps already completed at the current level):

**Minimal:**
- [ ] Review generated files and commit them
- [ ] Verify CI passes on a test PR

**Standard (adds):**
- [ ] Create `crates-io` environment in repo Settings > Environments
- [ ] Configure Trusted Publishing at `crates.io/crates/{{CRATE_NAME}}/settings` (workspace: configure for EACH publishable crate)
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

Show what was generated. In upgrade mode, include the upgrade context:

```
## Hardening Complete (Minimal → Standard Upgrade)

### Generated Files (delta)
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
