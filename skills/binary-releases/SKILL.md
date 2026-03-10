---
name: binary-releases
description: Cross-platform binary distribution for Rust — cargo-dist, cross, and manual CI matrix
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# Binary Releases — Cross-Platform Distribution for Rust

Many Rust projects ship pre-compiled binaries alongside crates.io publishing. This skill covers building, signing, and distributing binaries via GitHub Releases.

## Tools

| Tool | Use Case | Pros |
|------|----------|------|
| `cargo-dist` | Full release automation | Auto-generates CI, installers, Homebrew formula; opinionated |
| `cross` | Cross-compilation | Docker-based, supports many targets |
| `cargo-zigbuild` | Cross-compilation with Zig | Faster than cross, no Docker, good glibc compat |
| Manual matrix | Custom CI build matrix | Full control, no extra tools |

## Target Matrix

Common targets for Rust CLI tools:

| Target | OS | Arch | Notes |
|--------|-----|------|-------|
| `x86_64-unknown-linux-gnu` | Linux | x64 | Most common |
| `x86_64-unknown-linux-musl` | Linux | x64 | Static binary, portable |
| `aarch64-unknown-linux-gnu` | Linux | ARM64 | Graviton, Raspberry Pi |
| `x86_64-apple-darwin` | macOS | x64 | Intel Macs |
| `aarch64-apple-darwin` | macOS | ARM64 | Apple Silicon |
| `x86_64-pc-windows-msvc` | Windows | x64 | Most common Windows |

## Workflow Template: Manual Matrix

```yaml
name: Release binaries

on:
  release:
    types: [published]

permissions: read-all

jobs:
  build:
    name: Build ${{ matrix.target }}
    runs-on: ${{ matrix.os }}
    permissions:
      contents: write
    strategy:
      fail-fast: false
      matrix:
        include:
          - target: x86_64-unknown-linux-gnu
            os: ubuntu-latest
          - target: x86_64-unknown-linux-musl
            os: ubuntu-latest
          - target: aarch64-unknown-linux-gnu
            os: ubuntu-latest
          - target: x86_64-apple-darwin
            os: macos-latest
          - target: aarch64-apple-darwin
            os: macos-latest
          - target: x86_64-pc-windows-msvc
            os: windows-latest
    steps:
      - uses: actions/checkout@SHA
        with:
          persist-credentials: false

      - uses: dtolnay/rust-toolchain@SHA
        with:
          toolchain: stable
          targets: ${{ matrix.target }}

      - name: Install cross-compilation tools
        if: matrix.target == 'aarch64-unknown-linux-gnu'
        run: sudo apt-get install -y gcc-aarch64-linux-gnu

      - name: Install musl tools
        if: matrix.target == 'x86_64-unknown-linux-musl'
        run: sudo apt-get install -y musl-tools

      - name: Build
        run: cargo build --release --locked --target ${{ matrix.target }}

      - name: Package (Unix)
        if: runner.os != 'Windows'
        run: |
          cd target/${{ matrix.target }}/release
          tar czf ../../../CRATE_NAME-${{ github.ref_name }}-${{ matrix.target }}.tar.gz CRATE_NAME
          cd ../../../
          sha256sum CRATE_NAME-${{ github.ref_name }}-${{ matrix.target }}.tar.gz > CRATE_NAME-${{ github.ref_name }}-${{ matrix.target }}.tar.gz.sha256

      - name: Package (Windows)
        if: runner.os == 'Windows'
        shell: pwsh
        run: |
          Compress-Archive -Path target/${{ matrix.target }}/release/CRATE_NAME.exe -DestinationPath CRATE_NAME-${{ github.ref_name }}-${{ matrix.target }}.zip
          (Get-FileHash CRATE_NAME-${{ github.ref_name }}-${{ matrix.target }}.zip).Hash.ToLower() | Out-File CRATE_NAME-${{ github.ref_name }}-${{ matrix.target }}.zip.sha256

      - name: Upload to release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: gh release upload ${{ github.ref_name }} CRATE_NAME-${{ github.ref_name }}-${{ matrix.target }}.*
```

## cargo-dist Integration

For a more opinionated setup:

```bash
# Install
cargo install cargo-dist --locked

# Initialize (generates CI config)
cargo dist init

# Preview what would be built
cargo dist plan
```

cargo-dist automatically:
- Generates GitHub Actions workflow
- Creates platform installers (shell script, PowerShell)
- Generates Homebrew formula
- Computes checksums
- Uploads to GitHub Releases

## SLSA Provenance for Binaries

Extend the existing SLSA provenance to cover binary artifacts:

```yaml
provenance:
  needs: [build]
  permissions:
    actions: read
    id-token: write
    contents: write
  uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
  with:
    base64-subjects: "${{ needs.build.outputs.hashes }}"
    upload-assets: true  # Attach .intoto.jsonl to the release
```

The build job must output base64-encoded SHA-256 hashes of all binary artifacts.

## Gotchas

1. **macOS universal binaries** — Consider `lipo` to combine x64 + ARM64 into one binary
2. **Linux glibc version** — Target musl for maximum portability, or use `cargo-zigbuild` for glibc 2.17+ compat
3. **Windows code signing** — Requires a certificate; without it, Windows Defender may flag the binary
4. **Release trigger timing** — Use `on: release: types: [published]` so binaries upload to the existing release created by the publish workflow
5. **Archive naming convention** — Use `CRATE-VERSION-TARGET.tar.gz` for consistency
6. **`persist-credentials: false`** — Always set on checkout for Scorecard compliance
