---
name: ci-pipeline
description: Rust CI best practices — multi-job design, gate pattern, caching, SHA pinning
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# Rust CI Pipeline Best Practices

This skill covers the design patterns for a robust Rust CI pipeline, based on production experience with multi-job workflows.

## Six-Job Architecture

```
lint ──┐
msrv ──┤
test ──┼──→ ci (gate)
deny ──┤
audit ─┘
```

| Job | Purpose | Blocking? |
|-----|---------|-----------|
| `lint` | `cargo fmt --check` + `cargo clippy` (default + all features) | Yes |
| `msrv` | `cargo check --locked` with pinned MSRV toolchain | Yes |
| `test` | `cargo test` across OS matrix (Linux/macOS/Windows) + beta | Yes |
| `deny` | cargo-deny for advisories, bans, licenses, sources | Mixed* |
| `audit` | `cargo audit` for known vulnerabilities | Yes |
| `ci` | Gate job — single required status check | Always runs |

*`deny` uses `continue-on-error` for advisories (informational) but blocks on bans/licenses/sources.

## Gate Job Pattern

The `ci` gate job is the only required status check in branch protection settings:

```yaml
ci:
  name: CI
  if: always()
  needs: [lint, msrv, test, deny, audit]
  runs-on: ubuntu-latest
  steps:
    - name: Evaluate results
      run: |
        result="${{ contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled') }}"
        [[ "$result" == "false" ]] || exit 1
```

**Why this pattern:**
- Adding/removing jobs doesn't require updating branch protection
- `if: always()` ensures the gate runs even if upstream jobs are cancelled
- Single check to configure in GitHub Settings

## Action SHA Pinning

All actions MUST be pinned to full commit SHA with a version comment:

```yaml
# v6.0.2
uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
```

**Why SHA not tag:**
- Tags can be moved (force-pushed) by the action owner
- SHA is immutable — ensures reproducible builds
- Scorecard checks for this (Pinned-Dependencies)

**Finding the SHA for a tag:**
```bash
# Get the commit SHA for a specific tag
gh api repos/actions/checkout/git/ref/tags/v4 --jq '.object.sha'

# Or browse to the tag on GitHub and copy the full SHA
```

**Exception:** SLSA generator must use `@tag` — see slsa-provenance skill.

## Caching Strategy

```yaml
- name: Cache
  uses: Swatinem/rust-cache@779680da715d629ac1d338a641029a2f4372abb5 # v2
  with:
    save-if: ${{ github.ref == 'refs/heads/main' }}     # Only save on main
    shared-key: msrv                                      # Share across MSRV jobs
```

**Key decisions:**
- `save-if: main` — PRs read the cache but don't write, preventing cache pollution
- `shared-key` — MSRV and stable builds share caches when possible
- Fuzz targets use `workspaces: fuzz -> target` and per-target keys

## Permissions

Always set `permissions: read-all` at the workflow level:

```yaml
permissions: read-all
```

Override per-job only where needed:

```yaml
jobs:
  publish:
    permissions:
      contents: read
      id-token: write  # For OIDC Trusted Publishing
```

This satisfies the Scorecard Token-Permissions check and follows least privilege.

## Concurrency Control

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

- Groups by workflow + branch/tag ref
- Cancels in-progress runs only for PRs (not main pushes)
- Prevents redundant CI runs on rapid PR updates

## Advisory Handling

Advisories (CVE disclosures in dependencies) should NOT block PRs:

```yaml
deny:
  strategy:
    matrix:
      checks:
        - advisories
        - bans licenses sources
  continue-on-error: ${{ matrix.checks == 'advisories' }}
```

**Why:** A new advisory can appear at any time, blocking all PRs until a dependency is updated. The advisory check runs but failures are informational. The bans/licenses/sources check is strict.

## cargo-audit Installation

```yaml
- name: Install cargo-audit
  run: cargo install cargo-audit --version 0.21.2 --locked
```

**Gotcha:** Without `--locked`, transitive dependencies (e.g., `smol_str`) may require a newer Rust version than CI provides, causing build failures. Always use `--locked`. Pin `--version` to avoid pulling untested new releases in CI — update intentionally when ready.

## Test Matrix

```yaml
strategy:
  fail-fast: false
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]
    toolchain: [stable]
    include:
      - os: ubuntu-latest
        toolchain: beta
```

- `fail-fast: false` — don't cancel other OS tests if one fails
- Beta toolchain on Linux catches upcoming breakage early
- All tests use `--locked` to ensure reproducible builds

## MSRV Verification

```yaml
msrv:
  name: MSRV (1.82)
  steps:
    - uses: dtolnay/rust-toolchain@SHA
      with:
        toolchain: "1.82"
    - run: cargo check --locked
    - run: cargo check --locked --all-features
```

- Uses `cargo check` (not `cargo test`) — faster, only verifies compilation
- Tests both default and all-features configurations
- Pin MSRV in `rust-toolchain.toml` for contributor consistency

## Template

See `templates/workflows/ci.yml` for the complete implementation.
