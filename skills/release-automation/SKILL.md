---
name: release-automation
description: PR-based release flow with signed tags, branch protection compatibility, and CI polling
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# Release Automation for Rust Crates

This skill covers a PR-based release flow that works with branch protection rules, signed tags, and CI-triggered publishing.

## Release Flow

```
Developer                    GitHub                         crates.io
   │                           │                               │
   ├─ scripts/release.sh 0.2.0 │                               │
   │                           │                               │
   ├─ Local checks (deny,      │                               │
   │   test, clippy, dry-run)  │                               │
   │                           │                               │
   ├─ Create release/v0.2.0 ──→│                               │
   ├─ Bump Cargo.toml ────────→│                               │
   ├─ Push branch ────────────→│                               │
   ├─ gh pr create ───────────→│── CI runs on PR               │
   │                           │                               │
   ├─ Poll for checks start    │                               │
   ├─ gh pr checks --watch ───→│── Waits for CI                │
   │                           │                               │
   ├─ gh pr merge ────────────→│── Squash merge                │
   ├─ git pull origin main     │                               │
   ├─ git tag -s v0.2.0 ──────→│                               │
   ├─ git push origin v0.2.0 ─→│── Tag push triggers:          │
   │                           │   1. publish (crates.io) ────→│
   │                           │   2. provenance (SLSA L3)     │
   │                           │   3. release (GitHub)         │
   │                           │                               │
```

## Pre-flight Checks

The release script verifies before doing anything:

1. **Version format** — Must be valid semver `X.Y.Z`
2. **Signing key** — `git config user.signingkey` must be set
3. **Clean working tree** — No uncommitted changes
4. **On main branch** — Must be on `main`
5. **Up to date** — Local HEAD matches `origin/main`
6. **Version not already set** — `Cargo.toml` version differs from target
7. **Tag doesn't exist** — `v${VERSION}` tag not already present

## Local Quality Gates

Before creating the PR, run local checks to catch issues early:

```bash
cargo deny check advisories bans licenses sources
cargo test --locked --all-features --quiet
cargo clippy --all-features -- -D warnings
cargo publish --dry-run --locked
```

This avoids wasting CI time on PRs that would fail basic checks.

## CI Polling Race Condition

**GOTCHA:** `gh pr checks --watch` has a race condition — it returns immediately with success if no checks have been registered yet (which happens in the few seconds between PR creation and GitHub processing the workflow triggers).

**Solution:** Poll for check existence before watching:

```bash
echo "Waiting for CI checks to start..."
for i in $(seq 1 30); do
    if gh pr checks "$PR_NUMBER" --json name --jq '.[0].name' &>/dev/null 2>&1; then
        break
    fi
    sleep 2
done

echo "Waiting for CI checks to complete..."
gh pr checks "$PR_NUMBER" --watch
```

## Signed Tags

Tags should be signed to verify the release was created by an authorized maintainer:

```bash
git tag -s "v$VERSION" -m "Release v$VERSION"
```

**SSH signing setup (recommended):**
```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global tag.gpgSign true
```

**GPG signing setup:**
```bash
git config --global user.signingkey <GPG_KEY_ID>
git config --global tag.gpgSign true
```

## Branch Protection Compatibility

The release script handles branch protection gracefully:

```bash
if ! gh pr merge "$PR_NUMBER" --squash --delete-branch; then
    echo "Standard merge failed, trying with --admin..."
    gh pr merge "$PR_NUMBER" --squash --delete-branch --admin
fi
```

- First tries standard merge (works if CI passes and reviews are satisfied)
- Falls back to `--admin` merge (bypasses protection — requires admin access)

**Note:** Admin merges lower the Scorecard Code-Review score. For best scores, have another maintainer review the version bump PR.

## Tag Protection Gotchas

If your org or repo has tag protection rules:

- **Wrong tag = new version** — You cannot delete or update existing tags
- **Always bump Cargo.toml BEFORE tagging** — The publish workflow verifies the tag matches `Cargo.toml`
- **Tag must be on main** — The publish workflow verifies the tagged commit is an ancestor of `origin/main`

## `gh run rerun` Gotcha

If a publish workflow fails and you use `gh run rerun`:
- It re-runs with the **original workflow file** from the commit, not the current one
- If you fixed a bug in the workflow file, the rerun will use the old buggy version
- Solution: push a new tag (which means a new version number)

## Post-Tag Pipeline

After the signed tag is pushed, CI handles everything:

1. **Publish job:** Verify tag → test → package → hash → authenticate (OIDC) → publish
2. **Provenance job:** Generate SLSA L3 attestation from hashes
3. **Release job:** Download provenance → create GitHub Release with `.intoto.jsonl` attached

Monitor the pipeline:
```bash
gh run watch $(gh run list --limit 1 --workflow publish.yml --json databaseId -q '.[0].databaseId')
```

## Template

See `templates/release.sh` for the complete release script.
