---
name: changelog
description: Automated changelog generation with git-cliff and conventional commits
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# Changelog — Automated Release Notes for Rust Projects

Automated changelog generation from conventional commits, integrated with the release workflow.

## Tools

| Tool | Language | Approach |
|------|----------|----------|
| `git-cliff` | Rust | Highly configurable, template-based, conventional commits |
| `cargo-release` | Rust | Combines version bump + changelog + publish |
| GitHub "Generate release notes" | N/A | Built into `gh release create --generate-notes` |

## git-cliff Setup

### Install

```bash
cargo install git-cliff --locked
```

### Configuration (`cliff.toml`)

```toml
[changelog]
header = "# Changelog\n\nAll notable changes to this project will be documented in this file.\n"
body = """
{% if version %}\
    ## [{{ version | trim_start_matches(pat="v") }}] - {{ timestamp | date(format="%Y-%m-%d") }}
{% else %}\
    ## [unreleased]
{% endif %}\
{% for group, commits in commits | group_by(attribute="group") %}
    ### {{ group | striptags | trim | upper_first }}
    {% for commit in commits %}
        - {% if commit.scope %}**{{ commit.scope }}:** {% endif %}\
            {{ commit.message | upper_first }}\
    {% endfor %}
{% endfor %}\n
"""
footer = ""
trim = true

[git]
conventional_commits = true
filter_unconventional = true
split_commits = false
commit_parsers = [
    { message = "^feat", group = "Features" },
    { message = "^fix", group = "Bug Fixes" },
    { message = "^doc", group = "Documentation" },
    { message = "^perf", group = "Performance" },
    { message = "^refactor", group = "Refactoring" },
    { message = "^style", group = "Styling" },
    { message = "^test", group = "Testing" },
    { message = "^chore\\(release\\)", skip = true },
    { message = "^chore", group = "Miscellaneous" },
    { message = "^ci", group = "CI/CD" },
]
filter_commits = false
tag_pattern = "v[0-9].*"
sort_commits = "oldest"
```

### Usage

```bash
# Generate full changelog
git cliff -o CHANGELOG.md

# Generate changelog for latest tag only
git cliff --latest

# Generate since last tag (for release notes)
git cliff --unreleased --strip header
```

## Integration with release.sh

Add changelog generation to the release script before the version bump:

```bash
# In release.sh, after local checks and before branch creation:
echo "==> Generating changelog..."
if command -v git-cliff &>/dev/null; then
    git cliff --tag "v$VERSION" -o CHANGELOG.md
    git add CHANGELOG.md
fi
```

## Integration with GitHub Releases

The publish workflow uses `gh release create --generate-notes` by default. To use git-cliff instead:

```yaml
- name: Generate release notes
  run: |
    git cliff --latest --strip header > RELEASE_NOTES.md

- name: Create GitHub Release
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    gh release create "$TAG_NAME" \
      --title "$TAG_NAME" \
      --notes-file RELEASE_NOTES.md \
      --verify-tag
```

## Conventional Commit Format

For git-cliff to work well, use conventional commits:

```
feat: add support for workspace publishing
fix: correct SHA pin for codeql-action
docs: update migration guide for v0.19
feat(ci): add MSRV check job
fix(publish): handle workspace crate ordering
chore: bump cargo-audit to 0.22.1
```

### Prefixes

| Prefix | Changelog Section | Semver Impact |
|--------|------------------|---------------|
| `feat:` | Features | Minor |
| `fix:` | Bug Fixes | Patch |
| `feat!:` or `BREAKING CHANGE:` | Breaking Changes | Major |
| `docs:` | Documentation | None |
| `perf:` | Performance | Patch |
| `refactor:` | Refactoring | None |
| `test:` | Testing | None |
| `ci:` | CI/CD | None |
| `chore:` | Miscellaneous | None |

## Gotchas

1. **git-cliff needs tags** — it parses from tag to tag; first run may produce a large changelog
2. **`--generate-notes` vs git-cliff** — GitHub's built-in notes are PR-based, git-cliff is commit-based; choose one approach
3. **Workspace changelogs** — consider one unified CHANGELOG.md or per-crate changelogs; git-cliff supports `--include-path` to filter by directory
4. **Pre-release tags** — git-cliff handles `v1.0.0-rc.1` etc. but your `tag_pattern` must accommodate them
