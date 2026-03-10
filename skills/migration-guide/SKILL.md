---
name: migration-guide
description: Upgrade paths between hardening levels — detection, delta generation, and rollback
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# Hardening Level Migration Guide

This guide covers upgrading between gh-guard hardening levels (Minimal → Standard → Hardened), including detecting your current level, generating only the delta files, and rolling back individual components.

## Level Summary

| Upgrade | New Files | New Manual Steps |
|---------|-----------|-----------------|
| **None → Minimal** | CI workflow, `deny.toml`, `dependabot.yml`, `SECURITY.md`, `rust-toolchain.toml` | Verify CI passes, review deny allowlist |
| **Minimal → Standard** | Publish workflow, CodeQL workflow, Scorecard workflow, release script | Create crates-io env, configure Trusted Publishing, disable CodeQL default, set up signing key, branch protection |
| **Standard → Hardened** | Fuzz workflow, `osv-scanner.toml` + modify publish workflow (add SLSA jobs) | Init fuzz targets, register CII badge, review osv-scanner overrides |

## Detecting Current Level

Use the `hardening-detection` skill for the full marker list and classification algorithm. It is the single source of truth for level detection, shared by `/audit`, `/harden`, and this guide.

In brief: check for marker files across three tiers (Minimal: 4 markers, Standard: +4, Hardened: +3). The effective level is the highest tier where ALL markers are present. "Custom" means partial coverage — recommend filling gaps before upgrading.

## Minimal → Standard Upgrade

### Prerequisites
- [ ] CI workflow is passing on `main`
- [ ] At least one version published to crates.io (for Trusted Publishing setup)
- [ ] `gh` CLI installed and authenticated
- [ ] Git signing key configured

### Files to Add
1. **Publish workflow** — `.github/workflows/publish.yml` (from `templates/workflows/publish.yml`)
2. **CodeQL workflow** — `.github/workflows/codeql.yml` (from `templates/workflows/codeql.yml`)
3. **Scorecard workflow** — `.github/workflows/scorecard.yml` (from `templates/workflows/scorecard.yml`)
4. **Release script** — `scripts/release.sh` (from `templates/release.sh`)

### Manual Steps
1. **Create `crates-io` environment** — repo Settings > Environments > New environment > name it `crates-io`
2. **Configure Trusted Publishing** — visit `crates.io/crates/<name>/settings`, add publisher: repo, workflow `publish.yml`, environment `crates-io`
3. **Disable CodeQL default setup** — repo Settings > Code Security > Code scanning > disable "Default setup" (required before custom workflow works)
4. **Branch protection** — Settings > Branches > Add rule for `main`: require status check "CI", require PR reviews
5. **Signing key** — `git config --global gpg.format ssh && git config --global user.signingkey ~/.ssh/id_ed25519.pub`

### Testing Strategy
1. Commit all new files on a branch, open a PR
2. Verify CodeQL and Scorecard workflows trigger (CodeQL on PR, Scorecard on default branch push)
3. Test release flow with a pre-release version: `scripts/release.sh X.Y.Z-rc.1`
4. Verify Trusted Publishing: the publish workflow should authenticate via OIDC without a `CARGO_REGISTRY_TOKEN` secret

### Common Issues
- **CodeQL "already enabled"** — disable default setup first (Settings > Code Security)
- **Scorecard badge 404** — wait 24h after first run for the API to index
- **Release script merge fails** — ensure branch protection allows admin merge or use `--admin` flag

## Standard → Hardened Upgrade

### Prerequisites
- [ ] Standard-level workflows all passing
- [ ] Trusted Publishing working (at least one OIDC-authenticated publish)
- [ ] Familiar with `cargo fuzz` basics

### Changes to Existing Files
- **Publish workflow** — already has the SLSA provenance and release jobs if generated from gh-guard template. If not, add the `provenance` and `release` jobs from the template.

### New Files
1. **Fuzz workflow** — `.github/workflows/fuzz.yml` (from `templates/workflows/fuzz.yml`)
2. **osv-scanner config** — `osv-scanner.toml` (from `templates/osv-scanner.toml`)

### Manual Steps
1. **Initialize fuzz targets** — `cargo fuzz init && cargo fuzz add <target_name>` for each target
2. **Update fuzz workflow matrix** — replace placeholder target names with actual target names
3. **Register CII badge** — [bestpractices.coreinfrastructure.org](https://bestpractices.coreinfrastructure.org)
4. **Review osv-scanner.toml** — uncomment ecosystem overrides for ecosystems in your test fixtures

### Testing Strategy
1. Run `cargo +nightly fuzz run <target> -- -max_total_time=60` locally to verify targets work
2. Commit fuzz workflow, verify it triggers on schedule or with a manual `workflow_dispatch`
3. If modifying publish workflow for SLSA: test with a pre-release tag (`v0.0.0-test.1`) on a fork
4. Verify SLSA provenance appears as a GitHub Release asset after publish

### Common Issues
- **SLSA generator fails** — must use `@tag` reference, not SHA (reusable workflow requirement)
- **Fuzz build fails** — requires nightly toolchain, ensure workflow uses `toolchain: nightly`
- **osv-scanner false positives** — configure ecosystem overrides for test fixture directories

## Rollback Procedures

Each component can be rolled back independently:

| Component | Rollback | Notes |
|-----------|----------|-------|
| CI workflow | Delete `.github/workflows/ci.yml` | Remove "CI" from required status checks first |
| cargo-deny | Delete `deny.toml` | Remove deny step from CI workflow |
| Dependabot | Delete `.github/dependabot.yml` | Close any open Dependabot PRs |
| SECURITY.md | Delete `SECURITY.md` | Consider keeping — low cost, high value |
| Trusted Publishing | Remove `crates-io-auth-action` from publish workflow, add `CARGO_REGISTRY_TOKEN` secret | Revoke OIDC publisher at crates.io settings, generate a new API token at crates.io > Account Settings > API Tokens, add it as `CARGO_REGISTRY_TOKEN` in repo Settings > Secrets |
| CodeQL | Delete `.github/workflows/codeql.yml` | Re-enable default setup if desired |
| Scorecard | Delete `.github/workflows/scorecard.yml` | Badge will go stale, then 404 |
| Release script | Delete `scripts/release.sh` | Switch to manual tag-and-push workflow |
| SLSA provenance | Remove `provenance` and `release` jobs from publish workflow | Existing releases keep their provenance |
| Fuzz testing | Delete `.github/workflows/fuzz.yml` and optionally `fuzz/` | Keep `fuzz/` if you run locally |
| osv-scanner | Delete `osv-scanner.toml` | Scorecard Vulnerabilities check unaffected |

## Common Migration Issues

| Issue | Level | Symptom | Fix |
|-------|-------|---------|-----|
| CodeQL default blocks custom | Minimal → Standard | "Code scanning is already enabled" | Disable default setup in Settings > Code Security |
| Missing crates-io environment | Minimal → Standard | Publish workflow fails with "environment not found" | Create environment in repo Settings > Environments |
| Trusted Publishing not configured | Minimal → Standard | `crates-io-auth-action` fails with 403 | Configure at crates.io/crates/NAME/settings |
| SLSA tag reference | Standard → Hardened | Provenance job fails "must use tag" | Change SLSA generator reference from SHA to `@v2.1.0` |
| Fuzz nightly missing | Standard → Hardened | `cargo fuzz` errors about `-Z` flags | Ensure workflow specifies `toolchain: nightly` |
| osv-scanner false positives | Standard → Hardened | CI fails on test fixture vulnerabilities | Add ecosystem overrides in `osv-scanner.toml` |
| Branch protection blocks merge | Any upgrade | PR can't merge without reviews/checks | Use `--admin` flag or temporarily adjust protection rules |
