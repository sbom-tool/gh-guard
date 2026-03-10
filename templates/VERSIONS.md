# Pinned Action Versions

All GitHub Actions in gh-guard templates are pinned to full commit SHAs for reproducibility and supply chain security (Scorecard Pinned-Dependencies check).

This manifest tracks each pinned action, its version, and the date it was last verified.

## Pinned Actions

| Action | Version | SHA | Templates | Last Verified |
|--------|---------|-----|-----------|---------------|
| `actions/checkout` | v6.0.2 | `de0fac2e4500dabe0009e67214ff5f5447ce83dd` | ci, codeql, fuzz, scorecard, publish | 2026-03-10 |
| `dtolnay/rust-toolchain` | master | `efa25f7f19611383d5b0ccf2d1c8914531636bf9` | ci, fuzz, publish | 2026-03-10 |
| `Swatinem/rust-cache` | v2 | `779680da715d629ac1d338a641029a2f4372abb5` | ci, fuzz, publish | 2026-03-10 |
| `EmbarkStudios/cargo-deny-action` | v2 | `3fd3802e88374d3fe9159b834c7714ec57d6c979` | ci, publish | 2026-03-10 |
| `github/codeql-action/init` | v4 | `0d579ffd059c29b07949a3cce3983f0780820c98` | codeql | 2026-03-10 |
| `github/codeql-action/analyze` | v4 | `0d579ffd059c29b07949a3cce3983f0780820c98` | codeql | 2026-03-10 |
| `github/codeql-action/upload-sarif` | v4 | `0d579ffd059c29b07949a3cce3983f0780820c98` | scorecard | 2026-03-10 |
| `ossf/scorecard-action` | v2.4.3 | `4eaacf0543bb3f2c246792bd56e8cdeffafb205a` | scorecard | 2026-03-10 |
| `actions/upload-artifact` | v7.0.0 | `bbbca2ddaa5d8feaa63e36b76fdaad77386f024f` | scorecard, fuzz | 2026-03-10 |
| `actions/download-artifact` | v4 | `d3f86a106a0bac45b974a628896c90dbdf5c8093` | publish | 2026-03-10 |
| `rust-lang/crates-io-auth-action` | v1 | `b7e9a28eded4986ec6b1fa40eeee8f8f165559ec` | publish | 2026-03-10 |
| `slsa-framework/slsa-github-generator` | v2.1.0 | *tag reference* | publish | 2026-03-10 |

## Installed CLI Tools

| Tool | Version | Template |
|------|---------|----------|
| `cargo-audit` | 0.22.1 | ci.yml |
| `cargo-fuzz` | latest (--locked) | fuzz.yml |

## Notes

- The SLSA generator **must** use a `@tag` reference (not SHA) — this is a reusable workflow requirement.
- When Dependabot opens a PR to update an action SHA, verify:
  1. The new SHA matches the claimed tag (`gh api repos/OWNER/REPO/git/ref/tags/TAG --jq '.object.sha'`)
  2. The changelog doesn't introduce breaking changes
  3. Update the version comment in the workflow file
  4. Update this manifest
