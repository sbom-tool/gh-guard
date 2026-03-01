---
name: generate
description: Generate a single supply chain security config file
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
  - AskUserQuestion
---

# /generate <target> — Single File Generator

Generate a single supply chain security config file from a template, with auto-detected project values.

## Usage

```
/generate <target>
```

## Available Targets

| Target | Template | Output Path |
|--------|----------|------------|
| `ci-workflow` | `templates/workflows/ci.yml` | `.github/workflows/ci.yml` |
| `publish-workflow` | `templates/workflows/publish.yml` | `.github/workflows/publish.yml` |
| `codeql` | `templates/workflows/codeql.yml` | `.github/workflows/codeql.yml` |
| `scorecard` | `templates/workflows/scorecard.yml` | `.github/workflows/scorecard.yml` |
| `fuzz` | `templates/workflows/fuzz.yml` | `.github/workflows/fuzz.yml` |
| `deny-toml` | `templates/deny.toml` | `deny.toml` |
| `rust-toolchain` | `templates/rust-toolchain.toml` | `rust-toolchain.toml` |
| `dependabot` | `templates/dependabot.yml` | `.github/dependabot.yml` |
| `security-md` | `templates/SECURITY.md` | `SECURITY.md` |
| `release-script` | `templates/release.sh` | `scripts/release.sh` |
| `osv-scanner` | `templates/osv-scanner.toml` | `osv-scanner.toml` |

## Workflow

### Step 1: Parse Target

Parse the argument to determine which template to use. If no argument or invalid target, show the available targets table above and ask the user to choose.

### Step 2: Auto-Detect Values

Read project files to fill in placeholders:

| Placeholder | Detection Method |
|-------------|-----------------|
| `{{CRATE_NAME}}` | `sed -nE 's/^name = "([^"]+)"/\1/p' Cargo.toml \| head -1` |
| `{{MSRV}}` | `sed -nE 's/^rust-version = "([^"]+)"/\1/p' Cargo.toml \| head -1` or `sed -nE 's/^channel = "([^"]+)"/\1/p' rust-toolchain.toml` |
| `{{REPO_OWNER}}` | `git remote get-url origin \| sed -E 's|.*[:/]([^/]+)/[^/]+(\.git)?$|\1|'` |
| `{{REPO_NAME}}` | `git remote get-url origin \| sed -E 's|.*[:/][^/]+/([^/]+)(\.git)?$|\1|'` |
| `{{CONTACT_EMAIL}}` | `sed -nE 's/^authors = \["[^<]*<([^>]+)>.*$/\1/p' Cargo.toml` |
| `{{FUZZ_TARGETS}}` | Parse `fuzz/Cargo.toml` for `[[bin]] name = "..."` entries |
| `{{WORKSPACE_CRATES}}` | `cargo metadata --no-deps` filtered by publishable crates, in dependency order (e.g., `core,parser,cli`) |

If a required value can't be detected, ask the user.

### Step 3: Check for Existing File and Show Diff

If the output file does NOT exist, proceed to Step 4.

If the output file already exists:

1. **Generate the new content in memory** — read the template, replace all `{{PLACEHOLDER}}` tokens with detected values (but do not write yet)
2. **Compare existing vs generated:**
   - If the files are identical, tell the user: "File already matches the template — no changes needed." Skip to Step 5.
   - If the files differ, show a **unified diff** in a fenced code block so the user can see exactly what would change:
     ```diff
     --- existing .github/workflows/ci.yml
     +++ generated from template
     @@ -1,4 +1,4 @@
     -old line
     +new line
     ```
3. **Ask the user:** **Apply (overwrite with generated)** / **Keep existing** / **Show full generated file**
   - If "Apply" — proceed to Step 4 (write the generated content)
   - If "Keep existing" — skip to Step 5
   - If "Show full generated file" — display the full generated content, then ask again: **Apply / Keep existing**
4. Never silently overwrite

### Step 4: Generate

1. Read the template from the gh-guard plugin directory
2. Replace all `{{PLACEHOLDER}}` tokens with detected values
3. Create parent directories if needed (e.g., `.github/workflows/`, `scripts/`)
4. Write the file
5. For `release-script`: make executable (`chmod +x`)

### Step 5: Post-Generation Notes

Show target-specific notes:

**ci-workflow:**
- Set "CI" as the required status check in branch protection

**publish-workflow:**
- Create `crates-io` environment in repo Settings > Environments
- Configure Trusted Publishing at crates.io/crates/{{CRATE_NAME}}/settings
- **Workspace:** configure Trusted Publishing for EACH publishable crate separately
- Ensure Cargo.toml version matches tag before pushing
- To retrigger a failed publish: `gh workflow run publish.yml -f tag=vX.Y.Z`

**codeql:**
- Disable "default setup" in repo Settings > Code Security first

**scorecard:**
- Results appear in repo's Security tab after first run
- Badge available at `api.securityscorecards.dev`

**fuzz:**
- Update the `matrix.target` list with your actual fuzz target names
- Initialize targets: `cargo fuzz init && cargo fuzz add <target_name>`

**deny-toml:**
- Review the license allowlist — add any licenses your dependencies use
- Review the ban list — add crates you want to prohibit

**rust-toolchain:**
- This pins your toolchain for all contributors
- Update when bumping MSRV

**dependabot:**
- PRs will start appearing within a week

**security-md:**
- Update the supported versions table
- Verify the Security Advisories link works

**release-script:**
- Requires `gh` CLI installed and authenticated
- Requires a signing key configured (`git config user.signingkey`)
- Run with: `scripts/release.sh X.Y.Z`

**osv-scanner:**
- Uncomment ecosystem overrides for ecosystems in your test fixtures
- Copy to subdirectories that contain fixture files (doesn't propagate)
