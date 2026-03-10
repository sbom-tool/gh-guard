# Example: `/audit` Output

This is a representative output from running `/audit` on a Rust project with partial hardening.

---

## Supply Chain Security Audit

### Project: my-parser (0.3.1)
### Date: 2026-03-10

### Summary
- Score: 10/18 checks passing
- Hardening level: **Custom** (Minimal complete, partial Standard — 2/4 markers)

### Findings

| # | Check | Status | Finding | Recommendation |
|---|-------|--------|---------|----------------|
| 1 | Security-Policy | Pass | `SECURITY.md` present with disclosure policy | — |
| 2 | Token-Permissions | Partial | 1/2 workflows have `permissions:` | Add `permissions: read-all` to `codeql.yml` |
| 3 | Pinned-Dependencies | Partial | 8/12 actions SHA-pinned | Pin remaining 4 actions (see below) |
| 4 | Dependency-Update-Tool | Pass | `dependabot.yml` covers cargo + github-actions | — |
| 5 | Dangerous-Workflow | Pass | No dangerous patterns found | — |
| 6 | Binary-Artifacts | Pass | No committed binaries | — |
| 7 | Branch-Protection | N/A | Behavioral — check via Scorecard | Enable branch protection |
| 8 | Code-Review | N/A | Behavioral — check via Scorecard | — |
| 9 | Contributors | N/A | Organic | — |
| 10 | Maintained | N/A | Organic — last commit 3 days ago | — |
| 11 | License | Pass | MIT license detected | — |
| 12 | CII-Best-Practices | Fail | Not registered | Register at bestpractices.dev |
| 13 | Fuzzing | Fail | No fuzz targets or workflow | `/generate fuzz` |
| 14 | SAST | Partial | CodeQL present but using default setup | `/generate codeql` (disable default first) |
| 15 | Vulnerabilities | Pass | No known vulnerabilities | — |
| 16 | Signed-Releases | Fail | No SLSA provenance or signed releases | Add SLSA to publish workflow |
| 17 | Packaging | Pass | Published to crates.io | — |
| 18 | SBOM | Fail | No SBOM generation | Consider `cargo-sbom` or SLSA provenance |

### Missing Files

| File | Purpose | Generate |
|------|---------|----------|
| `.github/workflows/scorecard.yml` | Automated Scorecard monitoring | `/generate scorecard` |
| `scripts/release.sh` | PR-based release with signed tags | `/generate release-script` |
| `.github/workflows/fuzz.yml` | Coverage-guided fuzz testing | `/generate fuzz` |
| `osv-scanner.toml` | Cross-ecosystem vuln scanning | `/generate osv-scanner` |

### Unpinned Actions

```
.github/workflows/ci.yml:
  - dtolnay/rust-toolchain@stable  → pin to SHA
  - Swatinem/rust-cache@v2         → pin to SHA

.github/workflows/codeql.yml:
  - github/codeql-action/init@v3   → pin to SHA
  - github/codeql-action/analyze@v3 → pin to SHA
```

### Manual Steps Required
- [ ] Configure Trusted Publishing at crates.io/crates/my-parser/settings
- [ ] Enable branch protection on `main` (require CI status check)
- [ ] Disable CodeQL default setup in Settings > Code Security
- [ ] Set up signing key for git tags
- [ ] Register at bestpractices.coreinfrastructure.org

### Next Steps

Your project is at **Minimal** with partial Standard coverage. Run `/harden` and choose **Standard** to generate the 4 missing files and complete the Standard level. After that, consider **Hardened** for SLSA provenance and fuzz testing.
