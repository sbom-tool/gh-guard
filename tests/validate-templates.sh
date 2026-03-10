#!/usr/bin/env bash
# Validate that all gh-guard templates produce valid output with no leftover placeholders.
#
# Usage: ./tests/validate-templates.sh
#
# Requirements: yq (or python3 -c 'import yaml'), jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/templates"
VERSIONS_JSON="$TEMPLATE_DIR/versions.json"

PASS=0
FAIL=0
WARN=0

# Test placeholder values (matching the fixture project)
CRATE_NAME="my-tool"
MSRV="1.82"
REPO_OWNER="test-org"
REPO_NAME="my-tool"
CONTACT_EMAIL="test@example.com"
FUZZ_TARGETS="fuzz_parse"
WORKSPACE_CRATES="core,parser,cli"

pass() { ((PASS++)); echo "  PASS: $1"; }
fail() { ((FAIL++)); echo "  FAIL: $1"; }
warn() { ((WARN++)); echo "  WARN: $1"; }

replace_placeholders() {
  sed \
    -e "s/{{CRATE_NAME}}/$CRATE_NAME/g" \
    -e "s/{{MSRV}}/$MSRV/g" \
    -e "s/{{REPO_OWNER}}/$REPO_OWNER/g" \
    -e "s/{{REPO_NAME}}/$REPO_NAME/g" \
    -e "s/{{CONTACT_EMAIL}}/$CONTACT_EMAIL/g" \
    -e "s/{{FUZZ_TARGETS}}/$FUZZ_TARGETS/g" \
    -e "s/{{WORKSPACE_CRATES}}/$WORKSPACE_CRATES/g" \
    "$1"
}

echo "=== gh-guard Template Validation ==="
echo ""

# ── Test 1: No leftover placeholders after substitution ─────────────
echo "Test 1: Placeholder substitution completeness"
for template in "$TEMPLATE_DIR"/workflows/*.yml "$TEMPLATE_DIR"/*.toml "$TEMPLATE_DIR"/*.sh "$TEMPLATE_DIR"/SECURITY.md "$TEMPLATE_DIR"/dependabot.yml; do
  [ -f "$template" ] || continue
  name="$(basename "$template")"
  leftover=$(replace_placeholders "$template" | grep -o '{{[A-Z_]*}}' | sort -u || true)
  if [ -n "$leftover" ]; then
    fail "$name has leftover placeholders: $leftover"
  else
    pass "$name — all placeholders resolved"
  fi
done
echo ""

# ── Test 2: YAML validity ──────────────────────────────────────────
echo "Test 2: YAML validity"
yaml_checker=""
if command -v yq &>/dev/null; then
  yaml_checker="yq"
elif python3 -c 'import yaml' 2>/dev/null; then
  yaml_checker="python3"
fi

for template in "$TEMPLATE_DIR"/workflows/*.yml "$TEMPLATE_DIR"/dependabot.yml; do
  [ -f "$template" ] || continue
  name="$(basename "$template")"
  rendered=$(replace_placeholders "$template")

  # GitHub Actions ${{ }} expressions aren't valid YAML — replace with placeholders
  sanitized=$(echo "$rendered" | sed -E 's/\$\{\{[^}]*\}\}/PLACEHOLDER/g')

  if [ "$yaml_checker" = "yq" ]; then
    if echo "$sanitized" | yq '.' >/dev/null 2>&1; then
      pass "$name — valid YAML"
    else
      fail "$name — invalid YAML"
    fi
  elif [ "$yaml_checker" = "python3" ]; then
    if echo "$sanitized" | python3 -c 'import sys, yaml; yaml.safe_load(sys.stdin)' 2>/dev/null; then
      pass "$name — valid YAML"
    else
      fail "$name — invalid YAML"
    fi
  else
    warn "$name — no YAML validator available (install yq or PyYAML)"
  fi
done
echo ""

# ── Test 3: TOML validity ─────────────────────────────────────────
echo "Test 3: TOML validity"
toml_checker=""
if command -v taplo &>/dev/null; then
  toml_checker="taplo"
elif python3 -c 'import tomllib' 2>/dev/null; then
  toml_checker="python3"
fi

for template in "$TEMPLATE_DIR"/*.toml; do
  [ -f "$template" ] || continue
  name="$(basename "$template")"
  rendered=$(replace_placeholders "$template")

  if [ "$toml_checker" = "taplo" ]; then
    if echo "$rendered" | taplo check --stdin 2>/dev/null; then
      pass "$name — valid TOML"
    else
      fail "$name — invalid TOML"
    fi
  elif [ "$toml_checker" = "python3" ]; then
    if echo "$rendered" | python3 -c 'import sys, tomllib; tomllib.loads(sys.stdin.read())' 2>/dev/null; then
      pass "$name — valid TOML"
    else
      fail "$name — invalid TOML"
    fi
  else
    warn "$name — no TOML validator available (install taplo or use Python 3.11+)"
  fi
done
echo ""

# ── Test 4: versions.json consistency ──────────────────────────────
echo "Test 4: versions.json ↔ template SHA consistency"
if command -v jq &>/dev/null && [ -f "$VERSIONS_JSON" ]; then
  # Check each action SHA in versions.json exists in at least one template
  jq -r '.actions | to_entries[] | select(.value.sha != null) | "\(.key) \(.value.sha)"' "$VERSIONS_JSON" | while read -r action sha; do
    # Handle sub-paths (e.g., github/codeql-action has /init, /analyze, /upload-sarif)
    base_action="$action"
    found=false
    for wf in "$TEMPLATE_DIR"/workflows/*.yml; do
      if grep -q "$sha" "$wf" 2>/dev/null; then
        found=true
        break
      fi
    done
    if $found; then
      pass "$base_action SHA matches templates"
    else
      fail "$base_action SHA $sha not found in any template"
    fi
  done
else
  warn "jq not available or versions.json missing — skipping consistency check"
fi
echo ""

# ── Test 5: release.sh syntax check ───────────────────────────────
echo "Test 5: release.sh bash syntax"
release_template="$TEMPLATE_DIR/release.sh"
if [ -f "$release_template" ]; then
  rendered=$(replace_placeholders "$release_template")
  if echo "$rendered" | bash -n 2>/dev/null; then
    pass "release.sh — valid bash syntax"
  else
    fail "release.sh — bash syntax error"
  fi
else
  warn "release.sh not found"
fi
echo ""

# ── Summary ────────────────────────────────────────────────────────
echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Warnings: $WARN"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
