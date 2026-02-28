---
name: audit
description: Scan a Rust project and produce a supply chain security gap analysis
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
---

# /audit — Supply Chain Security Gap Analysis

Scan the current Rust project and produce a structured gap analysis against CI/CD supply chain best practices.

## Workflow

### Step 1: Discover Project Context

Read these files to understand the project:
- `Cargo.toml` — crate name, version, MSRV (`rust-version`), license
- `rust-toolchain.toml` — pinned toolchain version
- `.git/config` or run `git remote get-url origin` — repo owner/name

### Step 2: Check for Expected Files

Check for the presence of each file. For each, report: present/missing/partial.

| Category | Expected File | Location |
|----------|--------------|----------|
| CI Pipeline | CI workflow | `.github/workflows/` (any file with `cargo test`) |
| CI Pipeline | Gate job | CI workflow with `if: always()` + `needs:` pattern |
| Publishing | Publish workflow | `.github/workflows/` (triggered by `tags: ["v*"]`) |
| Publishing | Trusted Publishing | Publish workflow with `crates-io-auth-action` |
| Provenance | SLSA provenance | Publish workflow with `slsa-github-generator` |
| Provenance | GitHub Release | Publish workflow with `gh release create` |
| Security | `SECURITY.md` | Root or `.github/` |
| Security | CodeQL workflow | `.github/workflows/` with `codeql-action` |
| Security | Scorecard workflow | `.github/workflows/` with `scorecard-action` |
| Dependencies | `deny.toml` | Root |
| Dependencies | `dependabot.yml` | `.github/dependabot.yml` |
| Dependencies | `osv-scanner.toml` | Root |
| Toolchain | `rust-toolchain.toml` | Root |
| Toolchain | `Cargo.lock` | Root (should be committed for binaries/apps) |
| Testing | Fuzz targets | `fuzz/` directory |
| Testing | Fuzz workflow | `.github/workflows/` with `cargo-fuzz` |
| Release | Release script | `scripts/release.sh` or similar |
| License | `LICENSE` | Root |

### Step 3: Analyze Workflow Quality

For each workflow found, check:

**SHA Pinning:**
- Scan all `uses:` lines — are they pinned to SHA or using tags?
- Count: `X/Y actions are SHA-pinned`
- List any unpinned actions

**Permissions:**
- Does the workflow have `permissions:` at the top level?
- Are per-job permissions scoped minimally?

**Security Practices:**
- `persist-credentials: false` on checkout steps?
- `fetch-depth: 0` where ancestry checks are needed?
- `--locked` flag on cargo commands?

### Step 4: Score Against Scorecard Checks

Map findings to the 18 OpenSSF Scorecard checks. For each:
- **Pass** — requirement fully met
- **Partial** — some elements present but incomplete
- **Fail** — not present
- **N/A** — not applicable (organic/behavioral checks)

### Step 5: Generate Report

Output a structured report with:

```
## Supply Chain Security Audit

### Project: <crate-name> (<version>)
### Date: <today>

### Summary
- Score: X/18 checks passing
- Hardening level: Minimal | Standard | Hardened | Custom

### Findings

| # | Check | Status | Finding | Recommendation |
|---|-------|--------|---------|----------------|
| 1 | Security-Policy | ✅ Pass | SECURITY.md present | — |
| 2 | Token-Permissions | ⚠️ Partial | 2/3 workflows have permissions | Add permissions to codeql.yml |
| ... | ... | ... | ... | ... |

### Missing Files
For each missing file, include:
- What it does
- Template reference: `chain-guard/templates/<file>`
- Generation command: `/generate <target>`

### Manual Steps Required
List actions that can't be automated:
- [ ] Configure Trusted Publishing at crates.io/crates/<name>/settings
- [ ] Enable branch protection on main
- [ ] Disable CodeQL default setup (if using custom workflow)
- [ ] Register at bestpractices.dev for CII badge

### Next Steps
Recommend the appropriate `/harden` level based on current state.
```
