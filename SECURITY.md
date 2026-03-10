# Security Policy

## Scope

GH-Guard is a documentation-only Claude Code plugin — it generates configuration files but contains no executable code or runtime dependencies. Security issues in gh-guard primarily manifest as:

- **Template defects** — workflow templates with insecure patterns (missing permissions, unpinned actions, script injection vectors)
- **Stale SHA pins** — outdated action SHAs that miss security patches
- **Incorrect guidance** — skills or commands that recommend insecure practices

## Reporting a Vulnerability

If you discover a security issue in gh-guard templates or guidance:

1. **Preferred:** Open a [GitHub Security Advisory](https://github.com/gh-guard/gh-guard/security/advisories/new)
2. **Alternative:** Email the maintainers directly

### Response Timeline

- **Acknowledgment:** within 48 hours
- **Assessment:** within 7 days
- **Fix:** template/guidance fixes released as a patch version bump

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.2.x | Yes |
| < 0.2.0 | No |
