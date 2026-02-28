# GH-Guard

CI/CD supply chain hardening skill plugin for Claude Code, designed for Rust projects.

GH-Guard packages production-tested CI/CD security configurations into reusable templates and guided workflows. It helps Rust OSS maintainers achieve high OpenSSF Scorecard scores, set up Trusted Publishing, generate SLSA L3 provenance, and configure comprehensive dependency auditing.

## Installation

Add to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "plugins": [
    "~/github/gh-guard"
  ]
}
```

Or install from a specific path:

```json
{
  "plugins": [
    "/path/to/gh-guard"
  ]
}
```

## Quick Start

```
# Audit your project's supply chain security posture
/audit

# Interactively harden your project
/harden

# Generate a specific config file
/generate ci-workflow
/generate publish-workflow
/generate deny-toml
```

## Commands

### `/audit` — Gap Analysis

Scans your repository and produces a structured gap analysis:
- Checks for expected files (workflows, deny.toml, SECURITY.md, etc.)
- Scores against OpenSSF Scorecard checks
- Identifies SHA-pinning gaps, missing permissions, Cargo.lock issues
- Outputs recommendations with template references

### `/harden` — Interactive Wizard

Guides you through hardening at three levels:

| Level | Components |
|-------|-----------|
| **Minimal** | CI + cargo-deny + Dependabot + SECURITY.md |
| **Standard** | + Trusted Publishing + CodeQL + Scorecard + release script |
| **Hardened** | + SLSA provenance + fuzz testing + osv-scanner |

### `/generate <target>` — File Generator

Generates a single file with auto-detected project values:

| Target | Output Path |
|--------|------------|
| `ci-workflow` | `.github/workflows/ci.yml` |
| `publish-workflow` | `.github/workflows/publish.yml` |
| `codeql` | `.github/workflows/codeql.yml` |
| `scorecard` | `.github/workflows/scorecard.yml` |
| `fuzz` | `.github/workflows/fuzz.yml` |
| `deny-toml` | `deny.toml` |
| `rust-toolchain` | `rust-toolchain.toml` |
| `dependabot` | `.github/dependabot.yml` |
| `security-md` | `SECURITY.md` |
| `release-script` | `scripts/release.sh` |
| `osv-scanner` | `osv-scanner.toml` |

## What's Inside

### Templates

Production-tested config files parameterized with `{{PLACEHOLDER}}` syntax. Auto-detection fills in crate name, MSRV, repo owner/name from your project's `Cargo.toml` and git remote.

### Skills

Deep knowledge documents covering:

- **Scorecard Checks** — All 18 OpenSSF checks with Rust-specific implementation guidance
- **Trusted Publishing** — OIDC setup for crates.io (threat model, prerequisites, step-by-step)
- **SLSA Provenance** — Three-job publish/provenance/release pipeline architecture
- **CI Pipeline** — Gate pattern, caching, SHA pinning, permissions
- **Release Automation** — PR-based flow, signed tags, CI polling
- **Dependency Policy** — cargo-deny, Dependabot, osv-scanner layered defense

## Hardening Targets

Based on real-world experience achieving OpenSSF Scorecard 7.5/10:

- All GitHub Actions SHA-pinned with version comments
- `permissions: read-all` at workflow level, scoped per-job
- Trusted Publishing (OIDC) — no long-lived API tokens
- SLSA L3 provenance attached to GitHub Releases
- cargo-deny for license, ban, advisory, and source checks
- Dependabot for cargo + github-actions updates
- CodeQL with Rust native analysis
- Fuzz testing with cargo-fuzz
- Signed git tags (SSH ed25519 or GPG)
- SECURITY.md with coordinated disclosure policy

## License

MIT
