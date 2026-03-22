# GH-Guard: CI/CD Supply Chain Hardening for Rust

This is a Claude Code skill plugin that helps Rust OSS maintainers harden their CI/CD supply chain.

## What This Plugin Does

GH-Guard provides production-tested templates, guided workflows, and gap analysis for:

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
- `/check-updates` — Check deployed workflows for outdated SHA pins and CLI tool versions
- `/verify` — Validate generated configs are syntactically correct and internally consistent

## Skills (Contextual Knowledge)

Skills are loaded automatically when relevant. They provide deep knowledge on:

- `scorecard-checks` — All 18 OpenSSF Scorecard checks with Rust-specific guidance
- `trusted-publishing` — OIDC setup for crates.io
- `slsa-provenance` — Three-job publish→provenance→release pipeline
- `ci-pipeline` — Multi-job CI design patterns for Rust
- `release-automation` — PR-based release flow with signed tags
- `dependency-policy` — cargo-deny, Dependabot, and osv-scanner configuration
- `fuzz-testing` — Coverage-guided fuzz testing with cargo-fuzz, corpus management, and CI integration
- `migration-guide` — Upgrade paths between hardening levels with detection and rollback
- `workspace-publishing` — Multi-crate workspace publishing, ordering, and Trusted Publishing
- `hardening-detection` — Shared level detection algorithm (single source of truth)
- `cargo-vet` — Supply chain audits for third-party crate reviews
- `security-findings` — SARIF triage workflow for CodeQL, Scorecard, and cargo-deny findings
- `binary-releases` — Cross-platform binary distribution via GitHub Releases
- `changelog` — Automated changelog generation with git-cliff

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
| `{{WORKSPACE_CRATES}}` | `cargo metadata --no-deps` filtered by publishable, dependency order | `core,parser,cli` |

## Versioning

GH-Guard follows semantic versioning:

- **Patch** (0.x.Y) — SHA pin updates, typo fixes, skill content updates
- **Minor** (0.X.0) — New skills, new commands, new templates, non-breaking improvements
- **Major** (X.0.0) — Breaking template changes, removed commands, restructured skills

Template versions are coupled to the plugin version. When gh-guard bumps to a new minor version, regenerating files with `/generate` may produce different output than the previous version. The `templates/versions.json` file tracks all pinned action SHAs and CLI tool versions.

To validate templates after updating gh-guard: run `tests/validate-templates.sh`.

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
11. **Workspace publish ordering** — inter-dependent crates must be published in dependency order with ~60s delay for crates.io index propagation
12. **`workflow_dispatch` retrigger** — publish.yml supports manual retrigger via `workflow_dispatch` with a tag input; the `PUBLISH_TAG` env var resolves the tag from either trigger type
13. **Tag signatures detect hijacking** — when reviewing action updates (e.g., Dependabot PRs), check that tags have GPG/SSH signatures. The Trivy tag hijacking (March 2026) was detectable because the force-pushed tags lacked the GPG signatures present on the originals, had impossible parent-child date relationships, and showed "0 commits to master since this release"
