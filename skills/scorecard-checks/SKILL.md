---
name: scorecard-checks
description: OpenSSF Scorecard — all 18 checks with Rust-specific implementation guidance
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# OpenSSF Scorecard Checks for Rust Projects

The [OpenSSF Scorecard](https://scorecard.dev) evaluates 18 security checks on a 0-10 scale. This skill covers each check with Rust-specific guidance for maximizing your score.

## Quick Reference

| Check | Key Files | Scorecard Impact | Difficulty |
|-------|----------|-----------------|------------|
| Security-Policy | `SECURITY.md` | +1 | Easy |
| License | `LICENSE` | +1 | Easy |
| Binary-Artifacts | — (avoid committing binaries) | +1 | Easy |
| Dangerous-Workflow | `.github/workflows/*.yml` | +1 | Easy |
| Token-Permissions | `.github/workflows/*.yml` | +1 | Medium |
| Pinned-Dependencies | `.github/workflows/*.yml` | +1 | Medium |
| Branch-Protection | GitHub Settings | +1 | Medium |
| CI-Tests | `.github/workflows/ci.yml` | +1 | Medium |
| Dependency-Update-Tool | `.github/dependabot.yml` | +1 | Easy |
| Fuzzing | `.github/workflows/fuzz.yml`, `fuzz/` | +1 | Medium |
| SAST | `.github/workflows/codeql.yml` | +1 | Easy |
| Vulnerabilities | `osv-scanner.toml`, `Cargo.lock` | +1 | Variable |
| Code-Review | PR review settings | +1 | Behavioral |
| Contributors | — (multiple contributors) | +1 | Organic |
| Maintained | — (recent commits, issues) | +1 | Organic |
| Packaging | `publish.yml` | +1 | Medium |
| Signed-Releases | GitHub Releases + provenance | +1 | Hard |
| CII-Best-Practices | bestpractices.dev badge | +0.5 | Manual |

## Detailed Check Guidance

### 1. Security-Policy (Easy — 10/10)
**What it checks:** Presence of `SECURITY.md` in repo root or `.github/`.
**Rust action:** Use the `templates/SECURITY.md` template. Include coordinated disclosure policy and supported versions table.

### 2. License (Easy — 10/10)
**What it checks:** Recognized license file in repo root.
**Rust action:** Add `LICENSE` (MIT or Apache-2.0 are standard for Rust). Ensure `Cargo.toml` has matching `license = "MIT"`.

### 3. Binary-Artifacts (Easy — 10/10)
**What it checks:** No compiled binaries committed to the repo.
**Rust action:** Add `target/` to `.gitignore`. Never commit `.so`, `.dll`, `.dylib`, `.exe`, or `.wasm` files.

### 4. Dangerous-Workflow (Easy — 10/10)
**What it checks:** No `pull_request_target` with checkout of PR code, no `workflow_run` with untrusted input.
**Rust action:** Use `pull_request` (not `pull_request_target`) for PR workflows. Never pass PR body/title to shell commands.

### 5. Token-Permissions (Medium — 10/10)
**What it checks:** Workflows declare `permissions` at top level and don't use default broad `GITHUB_TOKEN` permissions.
**Rust action:** Add `permissions: read-all` at workflow level. Override per-job only where needed (e.g., `contents: write` for releases, `id-token: write` for OIDC).

### 6. Pinned-Dependencies (Medium — 9-10/10)
**What it checks:** GitHub Actions referenced by full commit SHA, not tags.
**Rust action:** Pin all `uses:` to SHA with version comment:
```yaml
# v6.0.2
uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
```
**Exception:** SLSA generator MUST use `@tag` (e.g., `@v2.1.0`) — it's a reusable workflow that doesn't support SHA references.

### 7. Branch-Protection (Medium — 8-10/10)
**What it checks:** Branch protection rules on default branch.
**Rust action:** Configure branch protection ruleset:
- Require PR reviews (1+ approver)
- Dismiss stale reviews on new pushes
- Require status checks (the "CI" gate job)
- Require signed commits (optional but recommended)
- Block force pushes and deletion

### 8. CI-Tests (Medium — 10/10)
**What it checks:** CI runs on PRs and checks test results.
**Rust action:** Use the `templates/workflows/ci.yml` template. The gate job pattern ensures a single required status check.

### 9. Dependency-Update-Tool (Easy — 10/10)
**What it checks:** Dependabot or Renovate configuration exists.
**Rust action:** Use `templates/dependabot.yml`. Cover both `cargo` and `github-actions` ecosystems.

### 10. Fuzzing (Medium — 10/10)
**What it checks:** Project uses a fuzzing framework (OSS-Fuzz, ClusterFuzzLite, or CI-integrated fuzzing).
**Rust action:** Set up `cargo-fuzz` with targets. Use `templates/workflows/fuzz.yml`. Even one target that fuzzes a parser or decoder counts.

### 11. SAST (Easy — 10/10)
**What it checks:** Static analysis tool runs on PRs (CodeQL, Semgrep, etc.).
**Rust action:** Use `templates/workflows/codeql.yml` with `build-mode: none` for Rust.
**Gotcha:** Disable "default setup" in repo Settings > Code Security before using a custom CodeQL workflow. They conflict.

### 12. Vulnerabilities (Variable — 0-10/10)
**What it checks:** No known vulnerabilities in dependencies (via GitHub dependency graph / OSV).
**Rust action:** Keep `Cargo.lock` updated. Run `cargo audit` regularly.
**Common false positive:** If your project contains SBOM test fixtures or sample data with package references (npm, PyPI, etc.), those PURLs will be scanned and flagged. Use `osv-scanner.toml` to suppress non-Rust ecosystems. Note: Scorecard uses GitHub's dependency graph API, not local scans, so `osv-scanner.toml` may not fully resolve this.

### 13. Code-Review (Behavioral — 0-10/10)
**What it checks:** PRs are reviewed before merge (looks at recent merge history).
**Rust action:** Always merge via reviewed PRs. Admin merges that bypass review will lower this score. This is a behavioral change, not a config file.

### 14. Contributors (Organic — 0-10/10)
**What it checks:** Multiple contributors from different organizations.
**Rust action:** No direct action. Score improves organically as the project grows.

### 15. Maintained (Organic — 0-10/10)
**What it checks:** Recent commits, issue responses, release activity within 90 days.
**Rust action:** No direct action. New repos start at 0 and improve over time. Regular commits and issue triage help.

### 16. Packaging (Medium — 10/10)
**What it checks:** Project publishes packages via CI (not local machine).
**Rust action:** Use `templates/workflows/publish.yml` with Trusted Publishing. Publishing from CI (triggered by tag push) satisfies this check.

### 17. Signed-Releases (Hard — 10/10)
**What it checks:** GitHub Releases exist with provenance or signed assets.
**Rust action:** Use the three-job publish pipeline: publish → SLSA provenance → release with `.intoto.jsonl` attached. The provenance file attached to GitHub Releases satisfies this check.

### 18. CII-Best-Practices (Manual — 5-10/10)
**What it checks:** OpenSSF Best Practices badge at bestpractices.dev.
**Rust action:** Register at [bestpractices.coreinfrastructure.org](https://bestpractices.coreinfrastructure.org/en/projects/new) and complete the Passing questionnaire. Silver and Gold badges require additional manual work.

## Score Optimization Strategy

**Quick wins (0→7):** Security-Policy, License, Dependabot, CI-Tests, Token-Permissions, Pinned-Dependencies, SAST
**Medium effort (7→9):** Fuzzing, Branch-Protection, Packaging, Signed-Releases
**Hard/organic (9→10):** Code-Review (behavioral), CII-Best-Practices (manual), Contributors/Maintained (time)
