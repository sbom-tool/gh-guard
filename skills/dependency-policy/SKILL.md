---
name: dependency-policy
description: Three-layer dependency defense — cargo-deny, Dependabot, and osv-scanner
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# Dependency Policy for Rust Projects

A robust dependency policy uses three complementary layers: cargo-deny for policy enforcement, Dependabot for automated updates, and osv-scanner for vulnerability detection.

## Three-Layer Defense

| Layer | Tool | What It Does | When It Runs |
|-------|------|-------------|-------------|
| Policy | cargo-deny | Enforce license, ban, source, and advisory rules | CI (every PR) |
| Updates | Dependabot | Auto-create PRs for dependency updates | Weekly |
| Scanning | osv-scanner | Detect known vulnerabilities | CI + scheduled |

## Layer 1: cargo-deny

### Configuration Sections

**`[graph]`** — Define which targets to check:
```toml
[graph]
targets = [
    "x86_64-unknown-linux-gnu",
    "aarch64-apple-darwin",
    "x86_64-pc-windows-msvc",
]
all-features = true
```

**`[advisories]`** — Security advisory handling:
```toml
[advisories]
unmaintained = "workspace"  # or "all"
ignore = []                  # Add RUSTSEC IDs to temporarily ignore
```

**`[licenses]`** — License allowlist:
```toml
[licenses]
confidence-threshold = 0.93
allow = [
    "MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause",
    "ISC", "MPL-2.0", "Unicode-3.0", "CC0-1.0", "Zlib",
]
```

**`[bans]`** — Dependency bans:
```toml
[bans]
multiple-versions = "warn"    # Warn on duplicate deps (different versions)
wildcards = "deny"             # Deny wildcard version requirements
highlight = "all"              # Show all duplicates, not just first
deny = [
    { name = "openssl", wrappers = [] },      # Ban openssl
    { name = "openssl-sys", wrappers = [] },   # Ban openssl-sys
]
```

**`[sources]`** — Source origin control:
```toml
[sources]
unknown-registry = "deny"     # Only allow known registries
unknown-git = "deny"           # No git dependencies
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
```

### cargo-deny v0.19 Changes

**GOTCHA:** cargo-deny v0.19 made breaking changes:
- Removed the `vulnerability` key from `[advisories]`
- Use `"all"` or `"workspace"` for unmaintained/unsound checks
- The `deny.toml` format changed — check your version

### CI Integration

Split into two matrix legs for best UX:

```yaml
deny:
  strategy:
    matrix:
      checks:
        - advisories
        - bans licenses sources
  continue-on-error: ${{ matrix.checks == 'advisories' }}
```

- Advisories: informational (new CVEs shouldn't block all PRs)
- Bans/licenses/sources: strict (policy violations must be fixed)

## Layer 2: Dependabot

### Configuration

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "cargo"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
```

**Two ecosystems:**
- `github-actions` — keeps action SHAs up to date (important for Scorecard Pinned-Dependencies)
- `cargo` — keeps Rust dependencies fresh

**`open-pull-requests-limit: 5`** — Prevents Dependabot from flooding you with PRs. The default is 5, but you can increase it for actively maintained projects.

### Grouping (Optional)

For projects with many dependencies, group minor/patch updates:

```yaml
  - package-ecosystem: "cargo"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      minor-and-patch:
        update-types:
          - "minor"
          - "patch"
```

## Layer 3: osv-scanner

### When You Need It

You need `osv-scanner.toml` when your project contains non-Rust package references that trigger false positives:
- SBOM test fixtures with npm/PyPI/Maven PURLs
- Documentation with package version examples
- Sample data files referencing external packages

### Configuration

```toml
# osv-scanner.toml
[[PackageOverrides]]
ecosystem = "npm"
ignore = true
reason = "Test fixture data, not actual dependencies"

[[PackageOverrides]]
ecosystem = "PyPI"
ignore = true
reason = "Test fixture data, not actual dependencies"
```

### Propagation Gotcha

**GOTCHA:** `osv-scanner.toml` does NOT propagate to child directories. If you have fixtures in `tests/fixtures/`, that directory needs its own `osv-scanner.toml` or the overrides won't apply to files scanned within it.

### Scorecard Interaction

The Scorecard Vulnerabilities check uses GitHub's dependency graph API, not local `osv-scanner.toml`. This means:
- `osv-scanner.toml` helps with local/CI scans but may not fix Scorecard false positives
- SBOM fixture PURLs in your repo can still appear as vulnerabilities in Scorecard
- The only fix for Scorecard false positives from fixtures is to remove the fixture files or restructure them

## Recommended Setup Order

1. **cargo-deny** first — establishes baseline policy
2. **Dependabot** second — automates staying up to date
3. **osv-scanner** last — only if you have false positive issues

## Template Files

- `templates/deny.toml` — Complete cargo-deny configuration
- `templates/dependabot.yml` — Dependabot for cargo + github-actions
- `templates/osv-scanner.toml` — osv-scanner with common ecosystem overrides
