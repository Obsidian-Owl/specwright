#!/usr/bin/env bash
#
# Tests for the Codex installer script.
#
# Validates:
# - user-scoped install writes ~/plugins/specwright and ~/.agents/plugins/marketplace.json
# - repo-scoped install writes <repo>/plugins/specwright and <repo>/.agents/plugins/marketplace.json
# - existing marketplace entries are preserved
# - re-running install/update does not duplicate the specwright marketplace entry
#
# Dependencies: bash, jq, python3, curl, tar
# Usage: ./tests/test-codex-install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/build/build.sh"
INSTALLER="$ROOT_DIR/scripts/install-codex.sh"

PASS=0
FAIL=0
TMP_DIR=""

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
}

assert_file() {
  local path="$1"
  local label="$2"
  if [ -f "$path" ]; then
    pass "$label"
  else
    fail "$label"
  fi
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label (expected '$expected', got '$actual')"
  fi
}

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

echo "=== Codex installer tests ==="
echo ""

for cmd in jq python3 curl tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ABORT: $cmd is required but not installed"
    exit 1
  fi
done

if [ ! -x "$BUILD_SCRIPT" ]; then
  echo "ABORT: build script not executable at $BUILD_SCRIPT"
  exit 1
fi

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t specwright-codex-test)"
ASSET_DIR="$TMP_DIR/asset"
HOME_DIR="$TMP_DIR/home"
REPO_DIR="$TMP_DIR/repo"
ASSET_PATH="$ASSET_DIR/specwright-codex.tar.gz"

mkdir -p "$ASSET_DIR" "$HOME_DIR" "$REPO_DIR"

echo "--- Build release bundle fixture ---"
rm -rf "$ROOT_DIR/dist"
if "$BUILD_SCRIPT" codex >/dev/null 2>&1; then
  pass "build.sh codex exits successfully"
else
  fail "build.sh codex exits successfully"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
fi

tar -czf "$ASSET_PATH" -C "$ROOT_DIR/dist" codex
assert_file "$ASSET_PATH" "fixture asset archive exists"

echo "--- User install ---"
mkdir -p "$HOME_DIR/.agents/plugins"
python3 - "$HOME_DIR/.agents/plugins/marketplace.json" <<'PY'
import json
import sys
from pathlib import Path

payload = {
    "name": "existing-marketplace",
    "interface": {"displayName": "Existing Marketplace"},
    "plugins": [
        {
            "name": "existing-plugin",
            "source": {"source": "local", "path": "./plugins/existing-plugin"},
            "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
            "category": "Coding",
        }
    ],
}
Path(sys.argv[1]).write_text(json.dumps(payload, indent=2) + "\n")
PY

HOME="$HOME_DIR" \
SPECWRIGHT_CODEX_ASSET_URL="file://$ASSET_PATH" \
bash "$INSTALLER" --user >/dev/null 2>&1
pass "user install command exits successfully"

assert_file "$HOME_DIR/plugins/specwright/.codex-plugin/plugin.json" "user install writes plugin bundle"
assert_file "$HOME_DIR/.agents/plugins/marketplace.json" "user install writes marketplace manifest"
assert_eq "$(jq -r '.plugins[] | select(.name == "specwright") | .source.path' "$HOME_DIR/.agents/plugins/marketplace.json")" "./plugins/specwright" "user marketplace path points at bundled plugin"
assert_eq "$(jq -r '.plugins[] | select(.name == "specwright") | .version' "$HOME_DIR/.agents/plugins/marketplace.json")" "latest" "user marketplace records installed version"
assert_eq "$(jq '[.plugins[] | select(.name == "specwright")] | length' "$HOME_DIR/.agents/plugins/marketplace.json")" "1" "user install adds one specwright marketplace entry"
assert_eq "$(jq '[.plugins[] | select(.name == "existing-plugin")] | length' "$HOME_DIR/.agents/plugins/marketplace.json")" "1" "user install preserves existing marketplace entries"

HOME="$HOME_DIR" \
SPECWRIGHT_CODEX_ASSET_URL="file://$ASSET_PATH" \
bash "$INSTALLER" --update --user >/dev/null 2>&1
pass "user update command exits successfully"

assert_eq "$(jq '[.plugins[] | select(.name == "specwright")] | length' "$HOME_DIR/.agents/plugins/marketplace.json")" "1" "user update stays idempotent"

if HOME="$HOME_DIR" SPECWRIGHT_CODEX_ASSET_URL="file://$ASSET_PATH" bash "$INSTALLER" --user >/dev/null 2>&1; then
  fail "user install without --update must fail when bundle already exists"
else
  pass "user install without --update fails when bundle already exists"
fi

if HOME="$HOME_DIR" SPECWRIGHT_CODEX_ASSET_URL="file://$ASSET_PATH" bash "$INSTALLER" --update --repo --repo-root "$TMP_DIR/missing-repo" >/dev/null 2>&1; then
  fail "repo update must fail when no prior install exists"
else
  pass "repo update fails when no prior install exists"
fi

echo "--- Repo install ---"
mkdir -p "$REPO_DIR/.agents/plugins"
python3 - "$REPO_DIR/.agents/plugins/marketplace.json" <<'PY'
import json
import sys
from pathlib import Path

payload = {
    "name": "repo-marketplace",
    "interface": {"displayName": "Repo Marketplace"},
    "plugins": [],
}
Path(sys.argv[1]).write_text(json.dumps(payload, indent=2) + "\n")
PY

HOME="$HOME_DIR" \
SPECWRIGHT_CODEX_ASSET_URL="file://$ASSET_PATH" \
bash "$INSTALLER" --repo --repo-root "$REPO_DIR" >/dev/null 2>&1
pass "repo install command exits successfully"

assert_file "$REPO_DIR/plugins/specwright/.codex-plugin/plugin.json" "repo install writes plugin bundle"
assert_file "$REPO_DIR/.agents/plugins/marketplace.json" "repo install writes marketplace manifest"
assert_eq "$(jq -r '.plugins[] | select(.name == "specwright") | .source.path' "$REPO_DIR/.agents/plugins/marketplace.json")" "./plugins/specwright" "repo marketplace path points at bundled plugin"
assert_eq "$(jq -r '.plugins[] | select(.name == "specwright") | .version' "$REPO_DIR/.agents/plugins/marketplace.json")" "latest" "repo marketplace records installed version"
assert_eq "$(jq '[.plugins[] | select(.name == "specwright")] | length' "$REPO_DIR/.agents/plugins/marketplace.json")" "1" "repo install adds one specwright marketplace entry"

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
