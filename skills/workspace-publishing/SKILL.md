---
name: workspace-publishing
description: Multi-crate workspace publishing — ordering, Trusted Publishing, and release automation
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# Workspace Publishing for Rust

Multi-crate Rust workspaces require careful publish ordering, per-crate Trusted Publishing configuration, and coordinated version bumps. This skill covers the patterns and gotchas for publishing workspace projects.

## Detecting Workspace Projects

A workspace is identified by `[workspace]` in the root `Cargo.toml`:

```toml
[workspace]
members = ["core", "parser", "cli"]
```

Use `cargo metadata` to list publishable members:

```bash
cargo metadata --no-deps --format-version 1 \
  | jq -r '.packages[] | select(.publish == null or (.publish | length == 0) or (.publish | index("false") | not)) | .name'
```

Crates with `publish = false` in their `Cargo.toml` are not publishable and should be excluded from the publish workflow.

## Publish Ordering

Workspace crates must be published in dependency order — a crate's dependencies must be available on crates.io before it can be published.

### Determining Order

Use `cargo metadata` to build the dependency graph:

```bash
cargo metadata --no-deps --format-version 1 \
  | jq -r '.packages[] | "\(.name): \([.dependencies[] | select(.path != null) | .name] | join(", "))"'
```

Example output and ordering:
```
core: (no local deps)        → publish first
parser: core                 → publish second
cli: core, parser            → publish third
```

### Index Propagation Delay

After publishing a crate, crates.io needs ~60 seconds to index it before dependents can find it. The publish workflow must include a sleep between crates:

```bash
cargo publish -p core --locked
sleep 60
cargo publish -p parser --locked
sleep 60
cargo publish -p cli --locked
```

### Retry Pattern

If a publish fails due to index delay, retry after a longer wait. Limit retries to avoid masking real failures in CI:

```bash
for attempt in 1 2 3; do
  cargo publish -p "$crate" --locked && break
  if [[ $attempt -eq 3 ]]; then
    echo "Failed after 3 attempts — this may not be an index delay issue."
    exit 1
  fi
  echo "Attempt $attempt failed, waiting 30s..."
  sleep 30
done
```

## Trusted Publishing for Workspaces

**Each crate needs its own Trusted Publishing configuration at crates.io.** This is the most commonly missed step.

For a workspace with crates `core`, `parser`, `cli`:
1. Visit `crates.io/crates/core/settings` → add publisher
2. Visit `crates.io/crates/parser/settings` → add publisher
3. Visit `crates.io/crates/cli/settings` → add publisher

All three use the same workflow file (`publish.yml`) and environment (`crates-io`).

## Workspace Publish Workflow

Workspace publishing uses a **sequential single-job** approach (not matrix), because ordering matters:

```yaml
- name: Verify tag matches workspace version
  shell: bash
  run: |
    set -euo pipefail
    TAG_VERSION="${GITHUB_REF_NAME#v}"
    # {{WORKSPACE_CRATES}} is a comma-separated list: core,parser,cli
    for crate in {{WORKSPACE_CRATES//,/ }}; do
      CRATE_DIR="$(cargo metadata --no-deps --format-version 1 \
        | jq -r --arg name "$crate" '.packages[] | select(.name == $name) | .manifest_path' \
        | xargs dirname)"
      CRATE_VERSION="$(sed -nE 's/^version = "([^"]+)"/\1/p' "$CRATE_DIR/Cargo.toml" | head -n1)"
      if [[ "${TAG_VERSION}" != "${CRATE_VERSION}" ]]; then
        echo "::error::Tag version (${TAG_VERSION}) does not match $crate version (${CRATE_VERSION})"
        exit 1
      fi
    done
```

Publish step with ordering and delay:

```yaml
- name: Publish workspace crates
  env:
    CARGO_REGISTRY_TOKEN: ${{ steps.auth.outputs.token }}
  run: |
    # Publish in dependency order with index propagation delay
    CRATES=({{WORKSPACE_CRATES//,/ }})
    LAST_INDEX=$(( ${#CRATES[@]} - 1 ))
    for i in "${!CRATES[@]}"; do
      echo "Publishing ${CRATES[$i]}..."
      cargo publish -p "${CRATES[$i]}" --locked
      if [[ $i -lt $LAST_INDEX ]]; then
        echo "Waiting 60s for crates.io index propagation..."
        sleep 60
      fi
    done
```

Hash generation for all crates:

```yaml
- name: Generate subject hashes
  id: hash
  run: |
    echo "hashes=$(sha256sum target/package/*.crate | base64 -w0)" >> "$GITHUB_OUTPUT"
```

## Workspace cargo-deny

`deny.toml` at the workspace root covers all members automatically. Key settings:

```toml
[graph]
all-features = true    # Check all features across all workspace members

# Per-crate exceptions if needed:
# [[bans.deny]]
# name = "some-crate"
# wrappers = ["my-workspace-member"]
```

No per-member `deny.toml` files are needed — the root config applies to the entire workspace graph.

## Workspace Release Script

The release script must handle multiple `Cargo.toml` files:

1. **Version verification** — check that all publishable members have the same version
2. **Version bump** — update version in all publishable `Cargo.toml` files
3. **Inter-crate dependency bump** — update path dependencies that also specify a version:
   ```toml
   # In cli/Cargo.toml
   [dependencies]
   my-core = { version = "=0.1.0", path = "../core" }  # ← bump this version too
   ```
4. **Workspace check** — use `cargo check --workspace` instead of `cargo check`
5. **Git add** — stage all modified `Cargo.toml` files and `Cargo.lock`

## Workspace Dependabot

For workspaces, Dependabot's `cargo` ecosystem entry with `directory: "/"` covers the root `Cargo.lock`. If workspace members have separate lockfiles (unusual but possible with `resolver = "2"` and per-member builds), add additional entries:

```yaml
# Only needed if members have separate Cargo.lock files
- package-ecosystem: "cargo"
  directory: "/crates/my-lib"
  schedule:
    interval: "weekly"
```

In most workspaces, the root-level Dependabot entry is sufficient.

## Common Gotchas

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| Wrong publish order | `cargo publish` fails: "dependency not found" | Publish in dependency order (leaf crates first) |
| Index propagation delay | Dependent crate can't find just-published dependency | Add `sleep 60` between publishes |
| Missing per-crate Trusted Publishing | OIDC auth fails for second/third crate | Configure Trusted Publishing at crates.io for EACH crate |
| `publish = false` crate in list | Publish fails: "crate cannot be published" | Filter out `publish = false` crates from `{{WORKSPACE_CRATES}}` |
| Root `deny.toml` not applied | cargo-deny misses workspace members | Ensure `all-features = true` in `[graph]`, run from workspace root |
| Version mismatch across members | Tag doesn't match all crate versions | Bump all publishable `Cargo.toml` files in the release script |
| Inter-crate dep version not bumped | Publish fails: version requirement not met | Update `version = "=X.Y.Z"` in path dependencies |

## Templates

- `templates/workflows/publish.yml` — includes commented workspace variant sections
- `templates/release.sh` — includes workspace detection and multi-crate version bumping
