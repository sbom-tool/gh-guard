---
name: security-findings
description: SARIF triage and response for CodeQL, Scorecard, cargo-deny, and Dependabot findings
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# Security Findings — SARIF Triage and Response

Multiple gh-guard components produce security findings: CodeQL (static analysis), Scorecard (supply chain posture), cargo-deny (dependency policy), and cargo-audit (vulnerability advisories). This skill covers how to consume, triage, and act on these findings.

## Finding Sources

| Source | Format | Destination | Update Frequency |
|--------|--------|-------------|-----------------|
| CodeQL | SARIF | GitHub Security > Code scanning | Push to main, PRs, weekly |
| Scorecard | SARIF + JSON | GitHub Security > Code scanning + api.securityscorecards.dev | Push to main, weekly |
| cargo-deny | CI output | PR checks (fail/pass) | Every PR |
| cargo-audit | CI output | PR checks (fail/pass) | Every PR |
| Dependabot | Alerts + PRs | GitHub Security > Dependabot | Continuous |

## GitHub Security Tab

All SARIF-producing tools upload to GitHub's Code Scanning interface:

- **Security > Code scanning alerts** — consolidated view of all findings
- Each alert has: severity, description, file location, rule ID
- Alerts track across commits — if you fix the issue, the alert auto-closes
- Dismiss with reason: false positive, won't fix, used in tests

## Triage Workflow

### Priority Matrix

| Severity | Source | SLA | Action |
|----------|--------|-----|--------|
| Critical/High | cargo-audit (CVE) | Fix within 7 days | Upgrade dependency or apply patch |
| Critical/High | CodeQL | Fix within 14 days | Code change to resolve the finding |
| Medium | Any | Fix in next release | Plan the fix, track in issues |
| Low/Informational | Any | Backlog | Review periodically |
| Scorecard check | Scorecard | Best effort | Improve configuration |

### Dismissal Policy

Legitimate reasons to dismiss a finding:
1. **False positive** — the tool's analysis is incorrect for your context
2. **Won't fix** — accepted risk with documented justification
3. **Used in tests** — finding is in test code only, not production
4. **Not applicable** — the code path is unreachable or the dependency is unused

Always add a comment explaining why when dismissing.

## CodeQL-Specific Guidance

### Common Rust Findings

| Rule | Description | Typical Fix |
|------|------------|------------|
| `rust/sql-injection` | User input in SQL queries | Use parameterized queries |
| `rust/unsafe-block` | Unsafe code blocks | Add SAFETY comments, minimize unsafe scope |
| `rust/uncontrolled-format-string` | Format string from user input | Use `{}` with explicit arguments |

### Suppressing False Positives

In Rust code, use comments (CodeQL doesn't have Rust-specific suppression yet):
```rust
// codeql[rust/unsafe-block]: Required for FFI interop with libfoo — see SAFETY comment above
```

## Scorecard-Specific Guidance

Scorecard findings appear as informational alerts. Focus on:
1. Checks scored 0-3: highest priority
2. Checks scored 4-6: medium priority
3. Checks scored 7+: maintenance

See the `scorecard-checks` skill for detailed guidance on improving each check.

## cargo-deny Findings

### Advisory Findings (Informational)

When the advisory leg of cargo-deny reports a finding:
1. Check if a patch is available: `cargo update -p <crate>`
2. If no patch, evaluate the risk and timeline
3. If acceptable risk, add an exception in `deny.toml`:
   ```toml
   [advisories]
   ignore = ["RUSTSEC-2024-XXXX"]  # Reason: not in our code path, fix pending upstream
   ```

### License/Ban/Source Findings (Blocking)

These block PRs. Fix by:
- **License:** Add to allowlist if acceptable, or find alternative crate
- **Ban:** Remove the banned dependency
- **Source:** Dependencies must come from crates.io (no git deps)

## Automated Response

### Dependabot Auto-Merge

For low-risk updates, configure auto-merge:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: cargo
    directory: "/"
    schedule:
      interval: weekly
    open-pull-requests-limit: 5
```

Then in a workflow:
```yaml
# Auto-merge patch-level Dependabot PRs
- name: Auto-merge
  if: github.actor == 'dependabot[bot]'
  run: gh pr merge --auto --squash "$PR_URL"
  env:
    PR_URL: ${{ github.event.pull_request.html_url }}
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Compromised Action Response

When a GitHub Action you depend on is compromised (e.g., the March 2026 Trivy tag hijacking), follow this playbook:

### Detect
1. **Check security advisories** — monitor GitHub Advisory Database, Socket.dev, and the action's repo for incident reports
2. **Verify your pins** — if you use SHA pinning, confirm your pinned SHA matches a known-good commit, not a malicious one. Compare against the action repo's git history
3. **Audit CI logs** — search workflow run logs for the affected time window. Look for unexpected network connections, unusual step durations, or modified entrypoints
4. **Check for exfiltration indicators** — search your GitHub org for repositories named `tpcp-docs` or similar (the Trivy attacker used victim PATs to create exfil repos)

### Rotate
5. **Rotate ALL secrets immediately** — if any workflow ran a compromised action, assume all secrets accessible to that workflow are leaked:
   - Repository secrets and environment secrets
   - `GITHUB_TOKEN` (auto-rotates, but check for any PATs used)
   - Cloud provider credentials (AWS, GCP, Azure)
   - Crates.io API tokens (if not using OIDC Trusted Publishing — another reason to migrate)
   - SSH deploy keys
   - Any secrets passed via environment variables
6. **Revoke and reissue deploy keys and PATs** — do not just rotate; revoke the old ones first

### Audit
7. **Identify the blast radius** — list every workflow that references the compromised action. Check if any ran during the compromised window
8. **Review self-hosted runners** — if you use self-hosted runners, audit for persistence mechanisms (cron jobs, systemd services, modified shell profiles). The Trivy payload swept filesystems for SSH keys, k8s configs, cloud credentials, and even crypto wallets on self-hosted runners
9. **Check for supply chain propagation** — if your repo publishes an action or reusable workflow consumed by others, you may need to notify downstream users

### Report
10. **File an incident report** — document timeline, affected workflows, rotated credentials
11. **Notify downstream users** — if your project was potentially affected, disclose transparently
12. **Update your pins** — once the action maintainer publishes a verified-clean release, update your SHA pin to the new known-good commit

### Prevention
- **SHA pinning** prevents tag hijacking entirely — this is the single most effective defense
- **OIDC Trusted Publishing** limits the blast radius by eliminating long-lived crates.io tokens
- **Least-privilege permissions** (`permissions: read-all` + per-job scoping) limits what a compromised action can access
- **`persist-credentials: false`** on checkout steps prevents the action from using the git credential

## Metrics to Track

- **Mean time to remediate (MTTR)** — days from finding to fix
- **Open finding count** — by severity and source
- **Dismissal rate** — high rates may indicate tool misconfiguration
- **Scorecard trend** — track score over time
