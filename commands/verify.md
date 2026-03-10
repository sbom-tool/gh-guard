---
name: verify
description: Verify that generated supply chain configs are valid and functional
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# /verify — Post-Generation Validation

Verify that generated supply chain security configs are syntactically valid, internally consistent, and ready to deploy.

## Workflow

### Step 1: Find Generated Files

Scan for gh-guard artifacts:
- `.github/workflows/*.yml` — all workflow files
- `deny.toml` — cargo-deny configuration
- `rust-toolchain.toml` — toolchain pinning
- `.github/dependabot.yml` — Dependabot config
- `SECURITY.md` — security policy
- `scripts/release.sh` — release script
- `osv-scanner.toml` — OSV scanner config

Report which files are present.

### Step 2: YAML Syntax Validation

For each YAML file found:
1. Sanitize GitHub Actions `${{ }}` expressions (replace with safe placeholders)
2. Validate YAML structure using `python3 -c 'import yaml; yaml.safe_load(...)'` or `yq`
3. Report: valid / invalid with error location

### Step 3: Workflow Structure Validation

For each GitHub Actions workflow, check:

**Required fields:**
- `name:` is present
- `on:` trigger is defined
- `permissions:` is set at workflow level
- Each job has `runs-on:`

**SHA pinning:**
- All `uses:` lines reference a full 40-char SHA (not a tag like `@v4`)
- Exception: SLSA generator (`slsa-github-generator`) must use `@tag`
- Version comments are present (e.g., `# v6.0.2`)

**Security practices:**
- `persist-credentials: false` on checkout steps
- `fetch-depth: 0` in publish workflow (for ancestry verification)
- `--locked` flag on cargo install commands

### Step 4: cargo-deny Validation

If `deny.toml` exists:
1. Run `cargo deny check --hide-inclusion-graph 2>&1` (if cargo-deny is installed)
2. Report any license violations, banned crates, or advisory findings
3. If not installed, check TOML syntax validity only

### Step 5: Cross-File Consistency

Check relationships between files:

- **CI gate job:** Does the CI workflow have a gate job with `if: always()` and `needs:` referencing all other jobs?
- **MSRV consistency:** Does `rust-toolchain.toml` channel match the MSRV used in CI workflow?
- **Publish workflow references:** If publish workflow references an environment name, note it for user to create
- **Fuzz targets:** If fuzz workflow exists, does it reference targets that match `fuzz/Cargo.toml` `[[bin]]` entries?
- **Dependabot ecosystems:** Does dependabot.yml cover both `github-actions` and `cargo`?

### Step 6: release.sh Validation

If `scripts/release.sh` exists:
1. Check bash syntax: `bash -n scripts/release.sh`
2. Run dry-run: `scripts/release.sh --dry-run <current-version-plus-one>` (compute next patch version from Cargo.toml)
3. Report pre-flight check results

### Step 7: Generate Report

```
## Verification Report

### Files Checked
| File | Syntax | Structure | Notes |
|------|--------|-----------|-------|
| .github/workflows/ci.yml | valid | 6 jobs, gate pattern | — |
| .github/workflows/publish.yml | valid | 3 jobs, OIDC auth | Create `crates-io` environment |
| deny.toml | valid | 4 check categories | 2 advisory warnings |
| ... | ... | ... | ... |

### SHA Pin Status
- X/Y actions are SHA-pinned with version comments
- Unpinned: [list]

### Issues Found
- [ ] Issue description and fix recommendation

### Ready to Deploy
All checks passed / X issues to resolve before deploying.
```
