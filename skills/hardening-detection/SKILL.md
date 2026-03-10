---
name: hardening-detection
description: Shared hardening level detection algorithm — single source of truth for /audit, /harden, and migration-guide
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Hardening Level Detection

Single source of truth for detecting a Rust project's current supply chain hardening level. Referenced by `/audit`, `/harden`, and the `migration-guide` skill.

## Detection Algorithm

### File Markers

| Marker | How to Detect |
|--------|--------------|
| CI workflow | `.github/workflows/` contains a YAML file with `cargo test` |
| Gate job | CI workflow has a job with `if: always()` + `needs:` pattern |
| `deny.toml` | Exists at project root |
| Dependency update tool | `.github/dependabot.yml` OR `renovate.json` / `.github/renovate.json` exists |
| `SECURITY.md` | Exists at root or `.github/SECURITY.md` |
| Publish workflow | `.github/workflows/` contains a YAML triggered by `tags: ["v*"]` |
| Trusted Publishing | Publish workflow contains `crates-io-auth-action` |
| CodeQL workflow | `.github/workflows/` contains a YAML with `codeql-action` |
| Scorecard workflow | `.github/workflows/` contains a YAML with `scorecard-action` |
| Release script | `scripts/release.sh` or similar executable in `scripts/` |
| SLSA provenance | Publish workflow contains `slsa-github-generator` |
| Fuzz workflow / OSS-Fuzz | `.github/workflows/` contains a YAML with `cargo-fuzz` or `cargo fuzz`, OR project is listed in `google/oss-fuzz` (check via `gh api repos/google/oss-fuzz/contents/projects/<name>`) |
| `osv-scanner.toml` | Exists at project root |

### Level Classification

**Minimal** — ALL of these present:
1. CI workflow with `cargo test`
2. `deny.toml` exists
3. Dependency update tool present: `.github/dependabot.yml` OR `renovate.json` / `.github/renovate.json`
4. `SECURITY.md` exists

**Standard** — ALL Minimal markers + ALL of these:
5. Publish workflow with `crates-io-auth-action` (Trusted Publishing)
6. CodeQL workflow present
7. Scorecard workflow present
8. Release script exists

**Hardened** — ALL Standard markers + ALL of these:
9. `slsa-github-generator` in publish workflow
10. Fuzz workflow present OR project listed in `google/oss-fuzz`
11. `osv-scanner.toml` exists

### Classification Rules

1. **Hardened** — all 11 markers present
2. **Standard** — markers 1-8 present
3. **Minimal** — markers 1-4 present
4. **Custom** — partial coverage; report the highest complete level and list missing markers for the next level up

### Workspace Detection

If `[workspace]` is present in root `Cargo.toml`, additionally check:
- Publish workflow handles all publishable members (not just one crate)
- Crates are published in dependency order with propagation delays
- Release script bumps versions in all publishable `Cargo.toml` files
- Trusted Publishing is noted as per-crate (each crate needs separate crates.io config)

### Output Format

When reporting detection results, use:

```
Current level: **[Level]** ([X]/[total] markers for next level)
Missing for [next level]: [comma-separated list of missing markers]
```

Example: `Current level: **Minimal** (2/4 Standard markers). Missing for Standard: CodeQL workflow, Scorecard workflow.`
