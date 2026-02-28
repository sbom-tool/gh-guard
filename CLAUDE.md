# Chain-Guard: CI/CD Supply Chain Hardening for Rust

This is a Claude Code skill plugin that helps Rust OSS maintainers harden their CI/CD supply chain.

## What This Plugin Does

Chain-Guard provides production-tested templates, guided workflows, and gap analysis for:

- **Trusted Publishing** — OIDC-based crates.io publishing (no long-lived tokens)
- **SLSA L3 Provenance** — Verifiable build provenance attached to GitHub Releases
- **OpenSSF Scorecard** — Automated security posture monitoring (18 checks)
- **CI Pipeline** — Multi-job Rust CI with gate pattern, caching, SHA-pinned actions
- **Dependency Policy** — cargo-deny + Dependabot + osv-scanner layered defense
- **Release Automation** — Branch-protection-compatible release scripts with signed tags
- **CodeQL + Fuzzing** — Static analysis and fuzz testing for Rust

## Hardening Levels

| Level | What You Get |
|-------|-------------|
| **Minimal** | CI workflow + cargo-deny + Dependabot + SECURITY.md |
| **Standard** | Minimal + Trusted Publishing + CodeQL + Scorecard + release script |
| **Hardened** | Standard + SLSA L3 provenance + fuzz testing + osv-scanner |

## Commands

- `/audit` — Scan your repo and produce a gap analysis against supply chain best practices
- `/harden` — Interactive wizard to generate missing configs at your chosen hardening level
- `/generate <target>` — Generate a single config file (e.g., `/generate ci-workflow`)

## Skills (Contextual Knowledge)

Skills are loaded automatically when relevant. They provide deep knowledge on:

- `scorecard-checks` — All 18 OpenSSF Scorecard checks with Rust-specific guidance
- `trusted-publishing` — OIDC setup for crates.io
- `slsa-provenance` — Three-job publish→provenance→release pipeline
- `ci-pipeline` — Multi-job CI design patterns for Rust
- `release-automation` — PR-based release flow with signed tags
- `dependency-policy` — cargo-deny, Dependabot, and osv-scanner configuration

## Templates

All templates use `{{PLACEHOLDER}}` syntax for project-specific values:

| Placeholder | Source | Example |
|-------------|--------|---------|
| `{{CRATE_NAME}}` | `Cargo.toml` name field | `my-tool` |
| `{{MSRV}}` | `rust-version` or `rust-toolchain.toml` | `1.82` |
| `{{REPO_OWNER}}` | Git remote URL | `my-org` |
| `{{REPO_NAME}}` | Git remote URL | `my-tool` |
| `{{CONTACT_EMAIL}}` | `Cargo.toml` authors field | `me@example.com` |
| `{{FUZZ_TARGETS}}` | `fuzz/Cargo.toml` or user input | `fuzz_parse,fuzz_decode` |

## Critical Gotchas

These are hard-won lessons — pay attention to these:

1. **SLSA generator MUST use `@tag` not SHA** — the reusable workflow requires tag references
2. **Immutable releases** — if your org has this setting, provenance must be generated BEFORE the GitHub Release is created (can't upload assets after)
3. **Tag protection** — if you push a wrong tag, you need a whole new version number
4. **`gh pr checks --watch` race** — returns immediately if checks haven't started; poll first
5. **`--depth=1` breaks ancestry checks** — publish workflows that verify tag ancestry need `fetch-depth: 0`
6. **Trusted Publishing is configured at crates.io** — not in the repo; you must visit crates.io/crates/NAME/settings
7. **osv-scanner.toml doesn't propagate** — child directories need their own copies
8. **CodeQL default setup** — must be disabled in repo Settings > Code Security before using a custom workflow
9. **cargo-audit needs `--locked`** — `cargo install cargo-audit --locked` to avoid MSRV issues from transitive deps
10. **cargo-deny v0.19** — removed the `vulnerability` key; use `"all"` or `"workspace"` for unmaintained/unsound checks
