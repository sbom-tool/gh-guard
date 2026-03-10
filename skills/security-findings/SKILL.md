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

## Metrics to Track

- **Mean time to remediate (MTTR)** — days from finding to fix
- **Open finding count** — by severity and source
- **Dismissal rate** — high rates may indicate tool misconfiguration
- **Scorecard trend** — track score over time
