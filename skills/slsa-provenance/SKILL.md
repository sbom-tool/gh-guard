---
name: slsa-provenance
description: SLSA L3 build provenance for Rust crates — three-job publish/provenance/release pipeline
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# SLSA L3 Provenance for Rust Crates

[SLSA](https://slsa.dev) (Supply-chain Levels for Software Artifacts) Level 3 provides verifiable build provenance — a signed attestation of what was built, from what source, by which builder. This skill covers the three-job pipeline architecture for Rust crates.

## Architecture

The publish workflow uses three sequential jobs:

```
publish ──→ provenance ──→ release
  │              │              │
  ├─ Tests       ├─ SLSA L3     ├─ Download provenance
  ├─ Verify tag  │  generator   ├─ Create GitHub Release
  ├─ Package     │  (reusable)  └─ Attach .intoto.jsonl
  ├─ Hash .crate │
  ├─ Auth OIDC   │
  └─ Publish     │
                 │
          Generates signed
          .intoto.jsonl
          attestation
```

### Job 1: `publish`

- Checks out code with `fetch-depth: 0` (needed for ancestry verification)
- Verifies tag matches `Cargo.toml` version
- Verifies tagged commit is ancestor of `origin/main`
- Runs tests and cargo-deny
- Packages the crate (`cargo package --locked`)
- Generates SHA-256 hash of the `.crate` file
- Authenticates via OIDC and publishes

**Output:** `hashes` — base64-encoded SHA-256 subject hashes

### Job 2: `provenance`

- Uses the SLSA GitHub generator reusable workflow
- Takes the hash subjects from the publish job
- Generates a signed `.intoto.jsonl` attestation (DSSE envelope)
- Uploads as a workflow artifact

**Critical constraints:**
- **MUST use `@tag` reference** (e.g., `@v2.1.0`), not SHA — the reusable workflow requires this
- Uses `upload-assets: false` because we attach provenance to the release ourselves (needed for immutable releases)

### Job 3: `release`

- Downloads the provenance artifact from the previous job
- Creates a GitHub Release with the `.intoto.jsonl` file attached
- Uses `--verify-tag` to ensure the tag exists

**Critical constraint for immutable releases:**
If your GitHub org has "immutable releases" enabled, you CANNOT upload assets after a release is created. The provenance file must be attached AT creation time, which is why this job downloads the artifact first, then creates the release with it in a single `gh release create` call.

## Hash Generation

The `.crate` file hash is the subject of the SLSA attestation:

```yaml
- name: Build crate archive for provenance
  run: cargo package --locked

- name: Generate subject hashes
  id: hash
  run: |
    echo "hashes=$(sha256sum target/package/my-crate-*.crate | base64 -w0)" >> "$GITHUB_OUTPUT"
```

The wildcard `*` matches the version in the filename (e.g., `my-crate-0.1.5.crate`).

## SLSA Generator Configuration

```yaml
provenance:
  needs: [publish]
  permissions:
    actions: read
    id-token: write
    contents: write
  # CRITICAL: Must use @tag, not SHA
  uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
  with:
    base64-subjects: "${{ needs.publish.outputs.hashes }}"
    upload-assets: false
    provenance-name: my-crate.intoto.jsonl
```

### Why `@tag` and not SHA?

The SLSA generator is a [reusable workflow](https://docs.github.com/en/actions/using-workflows/reusing-workflows). GitHub's security model for reusable workflows verifies their identity differently than regular actions. The generator's verification requires a tag reference to validate the signing identity. SHA pinning here would break the attestation.

## Verification

Users can verify provenance with `slsa-verifier`:

```bash
# Install
go install github.com/slsa-framework/slsa-verifier/v2/cli/slsa-verifier@latest

# Verify
slsa-verifier verify-artifact my-crate-0.1.5.crate \
  --provenance-path my-crate.intoto.jsonl \
  --source-uri github.com/owner/repo \
  --source-tag v0.1.5
```

## Common Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| SHA reference for generator | Workflow error: "invalid ref" | Use `@v2.1.0` tag reference |
| `fetch-depth: 1` (default) | Ancestry check fails: "not on origin/main" | Use `fetch-depth: 0` |
| `upload-assets: true` with immutable releases | Release exists but provenance upload fails | Set `upload-assets: false`, download artifact in release job |
| Missing `id-token: write` | OIDC token exchange fails | Add to provenance job permissions |
| Missing `contents: write` on provenance | Cannot write attestation | Add to provenance job permissions |
| Wrong provenance filename | Download artifact step fails | Ensure `provenance-name` matches `download-artifact name:` |
| Shallow clone for ancestry | `merge-base --is-ancestor` fails | `fetch-depth: 0` on checkout |

## Template

See `templates/workflows/publish.yml` for the complete implementation.
