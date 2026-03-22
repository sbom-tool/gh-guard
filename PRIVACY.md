# Privacy Policy

**Last updated:** 2026-03-21

## Overview

GH-Guard is an open-source Claude Code plugin that runs entirely within your local Claude Code session. This privacy policy explains what data GH-Guard accesses, how it is used, and what is never collected.

## Data GH-Guard Accesses

GH-Guard reads local project files to generate CI/CD configurations and perform security audits. This includes:

- **Cargo.toml** — crate name, version, MSRV, license, authors
- **rust-toolchain.toml** — pinned Rust toolchain version
- **Git remote configuration** — repository owner and name (for template placeholders)
- **Existing workflow files** — `.github/workflows/*.yml` for audit and gap analysis
- **Cargo.lock** — dependency graph for audit purposes
- **fuzz/Cargo.toml** — fuzz target names (if present)

This data is read locally within your Claude Code session to populate template placeholders and produce audit reports.

## Data GH-Guard Does Not Collect

GH-Guard does not collect, transmit, store, or share any data. Specifically:

- **No telemetry** — no usage metrics, analytics, or tracking of any kind
- **No network requests** — GH-Guard makes no outbound network connections. The `/check-updates` command uses the GitHub API via the `gh` CLI already authenticated in your environment, but GH-Guard itself does not initiate or control these requests
- **No external services** — no data is sent to any third-party service, API, or server
- **No persistent storage** — GH-Guard does not write to any location outside your project directory. Generated files (workflows, configs) are written only where you direct them
- **No credentials** — GH-Guard does not access, read, or store any secrets, tokens, API keys, or authentication credentials

## How GH-Guard Works

GH-Guard is a set of markdown skill files and YAML/TOML templates. It contains no executable code. All processing happens within the Claude Code runtime:

1. Claude Code reads GH-Guard's skill files and templates
2. You invoke commands (`/audit`, `/harden`, `/generate`, etc.)
3. Claude Code reads your project files locally to populate templates
4. Generated configs are written to your project directory
5. No data leaves your machine

## Third-Party Dependencies

GH-Guard has no runtime dependencies. The generated workflow templates reference third-party GitHub Actions (e.g., `actions/checkout`, `dtolnay/rust-toolchain`), but these are consumed by GitHub Actions infrastructure when your workflows run — not by GH-Guard itself.

## Open Source

GH-Guard is open source under the MIT license. The complete source code is available at [github.com/sbom-tool/gh-guard](https://github.com/sbom-tool/gh-guard). You can audit every file the plugin contains.

## Changes to This Policy

Changes to this privacy policy will be documented in the repository's commit history. The "Last updated" date at the top reflects the most recent revision.

## Contact

For privacy-related questions, open an issue at [github.com/sbom-tool/gh-guard/issues](https://github.com/sbom-tool/gh-guard/issues).
