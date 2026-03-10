---
name: cargo-vet
description: Supply chain audits for third-party crates — human review attestation with cargo-vet
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# cargo-vet — Supply Chain Audits for Third-Party Crates

`cargo-vet` ensures third-party dependencies have been audited by you or a trusted organization. It complements `cargo-deny` (which checks licenses, advisories, bans) by adding **human review attestation**.

## When to Use

- Projects that require explicit approval of third-party code
- Organizations with compliance requirements for dependency review
- Teams wanting to build on audits from trusted peers (Mozilla, Google, etc.)

## Setup

```bash
# Install
cargo install cargo-vet --locked

# Initialize in your project (creates supply-chain/ directory)
cargo vet init
```

This creates:
```
supply-chain/
  audits.toml      # Your audits
  config.toml      # Trusted import sources
  imports.lock     # Cached audits from trusted sources
```

## Configuration

### Import trusted audit sources (`config.toml`)

```toml
[imports.mozilla]
url = "https://raw.githubusercontent.com/nickel-org/nickel.rs/main/supply-chain/audits.toml"

[imports.google]
url = "https://chromium.googlesource.com/chromium/src/+/main/third_party/rust/AuditEntry?format=TEXT"

[imports.bytecode-alliance]
url = "https://raw.githubusercontent.com/nickel-org/nickel.rs/main/supply-chain/audits.toml"
```

### Audit criteria

- `safe-to-deploy` — full review, no unsafe/unsound issues, safe for production
- `safe-to-run` — lighter review, safe to build and run tests (not ship)

## Workflow

### Check audit status
```bash
# See what needs auditing
cargo vet

# Suggest audits — shows which crates need review
cargo vet suggest
```

### Record an audit
```bash
# After reviewing a crate, record your audit
cargo vet certify CRATE VERSION

# Or record that you trust the delta between versions
cargo vet certify CRATE OLD_VERSION NEW_VERSION
```

### Handle new dependencies
```bash
# When adding a new dep, cargo vet will flag it
cargo vet

# Quick exemption for now (audit later)
cargo vet add-exemption CRATE VERSION
```

## CI Integration

Add to CI workflow after the deny check:

```yaml
  vet:
    name: cargo-vet
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@SHA # pin to current version
        with:
          persist-credentials: false
      - uses: dtolnay/rust-toolchain@SHA
        with:
          toolchain: stable
      - run: cargo install cargo-vet --locked
      - run: cargo vet --locked
```

### Advisory: CI Failure Strategy

- **Strict mode:** CI fails if any unaudited dependency is found — best for security-critical projects
- **Suggest mode:** Run `cargo vet suggest` and post results as a PR comment — better for open source
- **Exemption-based:** Allow exemptions in `supply-chain/audits.toml` for rapid iteration, audit later

## Relationship to Other Tools

| Tool | What It Checks | Overlap |
|------|---------------|---------|
| `cargo-deny` | Licenses, advisories (CVEs), banned crates, source restrictions | No overlap — complementary |
| `cargo-vet` | Human audit attestation of third-party code | No overlap — complementary |
| `cargo-audit` | Known vulnerabilities (RustSec DB) | Partially overlaps cargo-deny advisories |
| `osv-scanner` | Cross-ecosystem vulnerability database | Partially overlaps cargo-audit |

## Gotchas

1. **`supply-chain/` must be committed** — the audit database is part of your repo
2. **Import sources can go stale** — run `cargo vet fetch-imports` periodically
3. **Version bumps need re-audit** — unless you use delta certifications
4. **Not yet integrated with Scorecard** — cargo-vet doesn't directly improve Scorecard scores, but strengthens your actual security posture
