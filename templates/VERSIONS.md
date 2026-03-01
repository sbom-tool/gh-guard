# Pinned Action Versions

All GitHub Actions in gh-guard templates are pinned to full commit SHAs for reproducibility and supply chain security (Scorecard Pinned-Dependencies check).

This manifest tracks each pinned action, its version, and the date it was last verified.

## Pinned Actions

| Action | Version | SHA | Templates | Last Verified |
|--------|---------|-----|-----------|---------------|
| `actions/checkout` | v6.0.2 | `de0fac2e4500dabe0009e67214ff5f5447ce83dd` | ci, codeql, fuzz, scorecard, publish | 2025-01-01 |
| `dtolnay/rust-toolchain` | master | `efa25f7f19611383d5b0ccf2d1c8914531636bf9` | ci, fuzz, publish | 2025-01-01 |
| `Swatinem/rust-cache` | v2 | `779680da715d629ac1d338a641029a2f4372abb5` | ci, fuzz, publish | 2025-01-01 |
| `EmbarkStudios/cargo-deny-action` | v2 | `3fd3802e88374d3fe9159b834c7714ec57d6c979` | ci, publish | 2025-01-01 |
| `github/codeql-action/init` | v4 | `89a39a4e59826350b863aa6b6252a07ad50cf83e` | codeql | 2025-01-01 |
| `github/codeql-action/analyze` | v4 | `89a39a4e59826350b863aa6b6252a07ad50cf83e` | codeql | 2025-01-01 |
| `github/codeql-action/upload-sarif` | v3 | `89a39a4e59826350b863aa6b6252a07ad50cf83e` | scorecard | 2025-01-01 |
| `ossf/scorecard-action` | v2.4.3 | `4eaacf0543bb3f2c246792bd56e8cdeffafb205a` | scorecard | 2025-01-01 |
| `actions/upload-artifact` | v6.0.0 | `b7c566a772e6b6bfb58ed0dc250532a479d7789f` | scorecard, fuzz | 2025-01-01 |
| `actions/download-artifact` | v4 | `fa0a91b85d4f404e444e00e005971372dc801d16` | publish | 2025-01-01 |
| `rust-lang/crates-io-auth-action` | v1 | `c2f7455177fbf986ee0f82f0932f8290b8769cce` | publish | 2025-01-01 |
| `slsa-framework/slsa-github-generator` | v2.1.0 | *tag reference* | publish | 2025-01-01 |

## Installed CLI Tools

| Tool | Version | Template |
|------|---------|----------|
| `cargo-audit` | 0.21.2 | ci.yml |
| `cargo-fuzz` | latest (--locked) | fuzz.yml |

## Notes

- The SLSA generator **must** use a `@tag` reference (not SHA) — this is a reusable workflow requirement.
- When Dependabot opens a PR to update an action SHA, verify:
  1. The new SHA matches the claimed tag (`gh api repos/OWNER/REPO/git/ref/tags/TAG --jq '.object.sha'`)
  2. The changelog doesn't introduce breaking changes
  3. Update the version comment in the workflow file
  4. Update this manifest
