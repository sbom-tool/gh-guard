---
name: trusted-publishing
description: OIDC-based Trusted Publishing for crates.io — eliminate long-lived API tokens
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# Trusted Publishing for crates.io

Trusted Publishing uses OIDC (OpenID Connect) to authenticate GitHub Actions workflows to crates.io without long-lived API tokens. This eliminates the risk of token theft and credential leaks.

## Threat Model

| Attack Vector | API Token | Trusted Publishing |
|--------------|-----------|-------------------|
| Token leaked in logs | Vulnerable | N/A (no token) |
| Token stolen from secrets | Vulnerable | N/A (no token) |
| Compromised maintainer account | Token can be exfiltrated | OIDC scoped to repo + workflow |
| Supply chain attack on CI | Token available in env | Token scoped to specific environment |
| Token rotation burden | Manual rotation needed | Automatic, ephemeral tokens |

## Prerequisites

1. **Crate already published** — You must have done at least one `cargo publish` with a traditional token. Trusted Publishing cannot be used for the initial publish.
2. **GitHub environment created** — Create a `crates-io` environment in repo Settings > Environments.
3. **Owner access on crates.io** — You must be an owner of the crate to configure publishing settings.

## Step-by-Step Setup

### Step 1: Create GitHub Environment

1. Go to repo **Settings > Environments > New environment**
2. Name it `crates-io` (must match the `environment:` in your workflow)
3. Optionally add protection rules (required reviewers, deployment branches)
4. No secrets needed — OIDC provides the token automatically

### Step 2: Configure at crates.io

**GOTCHA: This is configured at crates.io, not in your repository.**

1. Go to `https://crates.io/crates/YOUR_CRATE/settings`
2. Under "Trusted Publishing", click "Add"
3. Fill in:
   - **Repository owner:** Your GitHub org or username
   - **Repository name:** Your repo name
   - **Workflow filename:** `publish.yml` (or whatever you named your publish workflow)
   - **Environment:** `crates-io`
4. Click "Add"

### Step 3: Update Your Publish Workflow

The workflow needs two key pieces:

1. **`id-token: write` permission** on the publish job:
```yaml
permissions:
  contents: read
  id-token: write
```

2. **The `crates-io-auth-action`** to exchange the OIDC token:
```yaml
- name: Authenticate to crates.io
  uses: rust-lang/crates-io-auth-action@b7e9a28eded4986ec6b1fa40eeee8f8f165559ec # v1
  id: auth

- name: Publish crate
  env:
    CARGO_REGISTRY_TOKEN: ${{ steps.auth.outputs.token }}
  run: cargo publish --locked
```

### Step 4: Remove Old Token

Once Trusted Publishing is working:
1. Delete the `CARGO_REGISTRY_TOKEN` secret from repo Settings > Secrets
2. Revoke the token at crates.io > Account Settings > API Tokens

## Complete Workflow Example

See `templates/workflows/publish.yml` for a complete three-job pipeline (publish → provenance → release) with Trusted Publishing.

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| "OIDC token exchange failed" | Environment name mismatch | Ensure workflow `environment:` matches crates.io config |
| "Not authorized" | Workflow filename mismatch | Check exact filename at crates.io matches workflow file |
| "No matching publisher" | Repo owner/name mismatch | Verify repo owner and name at crates.io settings |
| "Token expired" | OIDC token has short TTL | Ensure publish step runs promptly after auth step |
| First publish fails | Crate not yet registered | Do initial publish with `cargo publish` and a traditional token |

## Workspace Crates

For workspaces publishing multiple crates:
- Each crate needs its own Trusted Publishing configuration at crates.io
- All can share the same workflow file and environment
- Publish in dependency order with `cargo publish -p <crate>` for each

## OIDC Beyond crates.io

The same OIDC pattern used for crates.io Trusted Publishing works for other services:

| Service | OIDC Provider | Use Case |
|---------|--------------|----------|
| **AWS** | `aws-actions/configure-aws-credentials` | Deploy to S3, ECR, Lambda |
| **GCP** | `google-github-actions/auth` | Deploy to Cloud Run, GCS, Artifact Registry |
| **Azure** | `azure/login` | Deploy to Azure Container Apps, Blob Storage |
| **PyPI** | Native Trusted Publishing | If your project includes Python bindings (PyO3) |
| **Private registries** | Varies | Custom OIDC integration or short-lived tokens |

### Pattern

All use the same principle: request a short-lived OIDC token from GitHub, exchange it with the target service, and use the resulting credential for the operation:

```yaml
permissions:
  id-token: write  # Required for OIDC token
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@SHA
    with:
      role-to-arn: arn:aws:iam::ACCOUNT:role/deploy-role
      aws-region: us-east-1
```

The key requirement is `id-token: write` permission on the job. The service-specific action handles the token exchange.

## Security Benefits

- **No secrets to manage** — OIDC tokens are ephemeral (minutes, not months)
- **Scoped to exact workflow** — only the configured workflow + environment can publish
- **Audit trail** — every publish links back to a specific CI run
- **No token rotation** — nothing to expire or rotate
- **Defense in depth** — combine with environment protection rules (required reviewers)
